'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
test('publication accepts verified books and rejects altered downloads or stale sources', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(),'ig-book-site-'));
  assert.equal(path.dirname(path.resolve(directory)),path.resolve(os.tmpdir()));
  t.after(()=>fs.rmSync(directory,{recursive:true,force:true}));
  fs.cpSync(path.join(__dirname,'../docs/handbook'),directory,{recursive:true});
  const run = () => spawnSync(process.execPath,[path.join(__dirname,'publish-book.cjs'),'--check'],
    {env:{...process.env,BOOK_SITE_DIR:directory},encoding:'utf8',windowsHide:true});
  assert.equal(run().status,0);
  const pdf = path.join(directory,'Individual-Guide-Handbook.pdf');
  const original = fs.readFileSync(pdf);
  fs.appendFileSync(pdf,'tampered');
  let result=run();
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/download differs from manifest/);
  fs.writeFileSync(pdf,original);
  const frenchPDF=path.join(directory,'fr-CA/Individual-Guide-Handbook.pdf');
  const originalFrench=fs.readFileSync(frenchPDF);
  fs.appendFileSync(frenchPDF,'tampered');
  result=run();
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/download differs from manifest: fr-CA/);
  fs.writeFileSync(frenchPDF,originalFrench);
  // Embedded image bytes may coincidentally contain a username; readable paths must fail.
  const manifestPath=path.join(directory,'manifest.json');
  const originalManifest=fs.readFileSync(manifestPath);
  const originalHTML=fs.readFileSync(path.join(directory,'index.html'));
  const privateHTML=Buffer.from(originalHTML.toString('utf8').replace('</body>','<p>C:/Users/private/Documents</p></body>'));
  const privacyManifest=JSON.parse(originalManifest);
  for(const name of ['index.html','Individual-Guide-Handbook.html']){
    fs.writeFileSync(path.join(directory,name),privateHTML);
    const file=privacyManifest.files.find(file=>file.name===name);
    file.bytes=privateHTML.length;
    file.sha256=crypto.createHash('sha256').update(privateHTML).digest('hex');
  }
  fs.writeFileSync(manifestPath,JSON.stringify(privacyManifest));
  result=run();
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/private machine path/);
  for(const name of ['index.html','Individual-Guide-Handbook.html'])fs.writeFileSync(path.join(directory,name),originalHTML);
  fs.writeFileSync(manifestPath,originalManifest);
  const manifestFile=path.join(directory,'manifest.json');
  const manifest=JSON.parse(fs.readFileSync(manifestFile,'utf8'));
  manifest.inputs['docs/book/chapters/00-reading-this-book.md']='0'.repeat(64);
  fs.writeFileSync(manifestFile,JSON.stringify(manifest));
  result=run();
  assert.notEqual(result.status,0);
  assert.match(result.stderr,/Published book is stale/);
});
