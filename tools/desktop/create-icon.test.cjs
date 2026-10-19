'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {createIcons} = require('./create-icon.cjs');

test('headless icon generation produces a deterministic PNG and seven valid ICO frames', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'ig-icon-'));
  t.after(() => fs.rmSync(directory, {recursive: true, force: true}));
  fs.copyFileSync(path.join(__dirname,'assets/icon.svg'), path.join(directory,'icon.svg'));
  const sizes = createIcons(directory);
  const png = fs.readFileSync(path.join(directory,'icon.png'));
  assert.equal(png.readUInt32BE(16), 512);
  assert.equal(png.readUInt32BE(20), 512);
  assert.equal(png[25], 6, 'RGBA preserves transparent padding');
  const ico = fs.readFileSync(path.join(directory,'icon.ico'));
  assert.equal(ico.readUInt16LE(2), 1);
  assert.equal(ico.readUInt16LE(4), sizes.length);
  for (const [index, size] of sizes.entries()) {
    const entry = 6 + index * 16;
    const offset = ico.readUInt32LE(entry + 12), bytes = ico.readUInt32LE(entry + 8);
    assert.ok(offset + bytes <= ico.length);
    assert.equal(ico.readUInt16LE(entry + 6), 32);
    assert.equal(ico[offset + 1], 80, 'frame is PNG');
    assert.equal(ico.readUInt32BE(offset + 16), size);
    assert.equal(ico.readUInt32BE(offset + 20), size);
  }
  createIcons(directory);
  assert.deepEqual(fs.readFileSync(path.join(directory,'icon.png')), png);
  assert.deepEqual(fs.readFileSync(path.join(directory,'icon.ico')), ico);
});
