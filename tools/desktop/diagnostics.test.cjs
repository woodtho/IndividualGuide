'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { PassThrough } = require('node:stream');
const createDiagnostics = require('./diagnostics.cjs');
test('startup logs retain bounded history across launches and size rotation', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'ig-diagnostics-test-'));
  try {
    let log = createDiagnostics(directory, { maxBytes: 400, history: 2 });
    log.write('old.session', { ok: true });
    log = createDiagnostics(directory, { maxBytes: 400, history: 2 });
    assert.match(fs.readFileSync(path.join(directory,'startup.1.log'),'utf8'), /old.session/);
    for (let index=0; index<30; index++) log.write('new.session', { index });
    assert.deepEqual(fs.readdirSync(directory).sort(), ['startup.1.log','startup.2.log','startup.log']);
    for (const file of fs.readdirSync(directory)) assert.ok(fs.statSync(path.join(directory,file)).size <= 400);
    assert.match(fs.readFileSync(log.file,'utf8'), /\d{4}-\d{2}-\d{2}T.* \+\d+ms \[INFO\] new.session/);
  } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});
test('R streams preserve split Unicode, line boundaries and the final partial line', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'ig-diagnostics-test-'));
  try {
    const log = createDiagnostics(directory);
    const stream = new PassThrough(); log.stream(stream, 'r.stderr');
    const input = Buffer.from('first Ω\r\nsecond 😀\nlast');
    const completed = new Promise(resolve => stream.once('end',resolve));
    for (const byte of input) stream.write(Buffer.from([byte]));
    stream.end(); await completed;
    const lines = fs.readFileSync(log.file,'utf8').trim().split('\n');
    assert.equal(lines.length,3);
    assert.match(lines[0],/r.stderr first Ω$/); assert.match(lines[1],/r.stderr second 😀$/); assert.match(lines[2],/r.stderr last$/);
    assert.ok(!lines.join('').includes('\uFFFD'));
  } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});
