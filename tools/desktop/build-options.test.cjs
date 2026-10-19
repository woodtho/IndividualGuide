'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const os = require('node:os');
const { getConfig } = require('app-builder-lib/out/util/config/config.js');
const buildOptions = require('./build-options.cjs');

test('the builder resolves exactly one selected runtime without mixing old staging', async () => {
  const runtime = path.join(os.tmpdir(), 'Individual Guide selected runtime');
  const options = buildOptions([`--runtime=${runtime}`, '--target=installer']);
  const resolved = await getConfig(__dirname, null, options.config);
  assert.deepEqual(resolved.extraResources, [{ from: runtime, to: 'runtime' }]);
  assert.equal(resolved.productName, 'Individual Guide');
  assert.equal(resolved.nsis.runAfterFinish, false);
});

test('the portable build resolves one default runtime and rejects unknown targets', async () => {
  const options = buildOptions(['--target=portable']);
  const resolved = await getConfig(__dirname, null, options.config);
  assert.equal(resolved.extraResources.length, 1);
  assert.equal(resolved.extraResources[0].from, path.resolve(__dirname, '../../build/staging/runtime'));
  assert.equal(options.target, 'portable');
  assert.throws(() => buildOptions(['--target=invalid']), /Unknown desktop target/);
});
