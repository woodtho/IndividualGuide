'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { NtExecutable, NtExecutableResource, Resource, Data } = require('resedit');
const asar = require('@electron/asar');
const root = path.resolve(__dirname, '../..');
const [executable, setup] = process.argv.slice(2);
assert.ok(executable && setup, 'Supply the installed executable and Setup paths.');
const installed = path.dirname(path.resolve(executable));
const icon = Data.IconFile.from(fs.readFileSync(path.join(__dirname, 'assets/icon.ico')));
const expected = icon.icons.map(item => Buffer.from(item.data.bin));
for (const file of [executable, setup]) {
  const entries = NtExecutableResource.from(NtExecutable.from(fs.readFileSync(file), { ignoreCert: true })).entries;
  assert.ok(Resource.IconGroupEntry.fromEntries(entries).some(group => {
    const actual = group.getIconItemsFromEntries(entries);
    return actual.length === expected.length && expected.every(frame => actual.some(item => item.isRaw() && Buffer.from(item.bin).equals(frame)));
  }), `The app icon differs: ${file}`);
}
const archive = path.join(installed, 'resources/app.asar');
for (const file of ['main.cjs', 'preload.cjs', 'diagnostics.cjs', 'preferences.cjs', 'security.cjs', 'menus.cjs', 'smoke.cjs', 'menu-smoke.cjs', 'lifecycle-smoke.cjs', 'restart-smoke.cjs', 'console-smoke.cjs', 'examples-smoke.cjs', 'product-smoke.cjs', 'loading.html', 'assets/icon.png', 'assets/icon-LICENSE.txt']) {
  assert.ok(asar.extractFile(archive, file).equals(fs.readFileSync(path.join(__dirname, file))), `Installed desktop source differs: ${file}`);
}
for (const file of ['startup.R', 'package-library.R', 'options-bootstrap.R', 'runtime.json', 'R/library/IndividualGuide/DESCRIPTION', 'R/library/IndividualGuide/build-info.json',
  'R/library/IndividualGuide/R/IndividualGuide.rdb', 'R/library/IndividualGuide/R/IndividualGuide.rdx',
  'R/library/IndividualGuide/app/www/styles.css', 'R/library/IndividualGuide/app/www/ig_desktop.js', 'R/library/IndividualGuide/app/www/ig_run.js', 'R/library/IndividualGuide/app/www/ig_console.js', 'R/library/IndividualGuide/app/www/ig_console_tools.js']) {
  assert.ok(fs.readFileSync(path.join(installed, 'resources/runtime', file)).equals(
    fs.readFileSync(path.join(root, 'build/staging/runtime', file))), `Installed runtime differs: ${file}`);
}
const checksum = crypto.createHash('sha256').update(fs.readFileSync(setup)).digest('hex').toUpperCase();
const examples = path.join(root, 'inst/examples');
for (const file of fs.readdirSync(examples, { recursive: true, withFileTypes: true }).filter(x=>x.isFile())) {
  const relative = path.relative(examples, path.join(file.parentPath, file.name));
  assert.ok(fs.readFileSync(path.join(examples, relative)).equals(fs.readFileSync(path.join(installed,
    'resources/runtime/R/library/IndividualGuide/examples', relative))), `Bundled example differs: ${relative}`);
}
assert.equal(fs.readFileSync(setup + '.sha256', 'utf8').trim().split(/\s+/)[0], checksum);
const result = { ok: true, installedExecutable: executable, setup, setupSha256: checksum, bundledExamplesMatch: true,
  iconSizes: icon.icons.map(item => item.data.width), desktopSourceMatches: true, runtimeMatches: true, checksumMatches: true };
fs.writeFileSync(path.join(root, 'artifacts/review/installed-resources.json'), JSON.stringify(result, null, 2));
console.log(JSON.stringify(result, null, 2));
