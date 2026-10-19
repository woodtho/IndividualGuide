'use strict';
// Stage only verified reader files. --check validates the committed Pages tree.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const output = path.resolve(process.env.BOOK_OUTPUT_DIR || path.join(root,'build/book'));
const site = path.resolve(process.env.BOOK_SITE_DIR || path.join(root,'docs/handbook'));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const fail = message => { throw new Error(message); };
const read = relative => fs.readFileSync(path.join(root, relative));
const {inputFiles,inputHash,snapshot} = require('./book-inputs.cjs');
const formats = ['pdf','html','epub','docx'];
const downloads = formats.map(ext=>'Individual-Guide-Handbook.'+ext);
function verifySite() {
  const manifest = JSON.parse(fs.readFileSync(path.join(site,'manifest.json'),'utf8'));
  if (manifest.schema !== 1 || manifest.taskTypes !== 58 || manifest.exampleProjects !== 22 || manifest.checksPassed < 400) fail('Invalid book verification summary.');
  const inputs = inputFiles();
  if (JSON.stringify(inputs) !== JSON.stringify(Object.keys(manifest.inputs).sort())) fail('Book source list changed. Rebuild and publish the book.');
  for (const relative of inputs) if (inputHash(relative) !== manifest.inputs[relative]) fail('Published book is stale: '+relative);
  const expected = [...downloads, 'index.html'].sort();
  if (JSON.stringify(manifest.files.map(file=>file.name).sort()) !== JSON.stringify(expected)) fail('Missing or unexpected book format.');
  for (const file of manifest.files) {
    const bytes = fs.readFileSync(path.join(site,file.name));
    if (bytes.length !== file.bytes || sha(bytes) !== file.sha256) fail('Book download differs from manifest: '+file.name);
  }
  const html = fs.readFileSync(path.join(site,'index.html'),'utf8');
  if (html !== fs.readFileSync(path.join(site,downloads[1]),'utf8')) fail('Online and offline HTML editions differ.');
  const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match=>match[1]);
  if (new Set(ids).size !== ids.length) fail('Duplicate HTML anchors.');
  for (const match of html.matchAll(/href="#([^"]+)"/g)) if (!ids.includes(decodeURIComponent(match[1]))) fail('Broken book anchor: '+match[1]);
  for (const ext of formats) if (!html.includes('https://woodtho.github.io/IndividualGuide/Individual-Guide-Handbook.'+ext)) fail('Missing download link: '+ext);
  if (/<(?:script|link|img)\b[^>]*(?:src|href)=["']https?:\/\//i.test(html)) fail('The offline book has a remote resource.');
  if (/(?:aThom|OneDrive|C:[\\/]Users[\\/])/i.test(html)) fail('The book contains a private machine path.');
  return manifest;
}
if (!process.argv.includes('--check')) {
  const verification = JSON.parse(fs.readFileSync(path.join(output,'verification.json'),'utf8'));
  const build = JSON.parse(fs.readFileSync(path.join(output,'manifest.json'),'utf8'));
  if (verification.ok !== true || verification.taskTypes !== 58 || verification.exampleProjects !== 22) fail('Run the full book verification before publishing.');
  if (JSON.stringify(build.bookInputs) !== JSON.stringify(snapshot())) fail('Book sources or rendering tools changed. Rebuild and verify before publishing.');
  // Validate current source identity and the complete reviewed output, not just
  // a success flag left over from an earlier render.
  for (const chapter of build.chapters) if (sha(read('docs/book/chapters/'+chapter.name)) !== chapter.sha256) fail('Stale chapter: '+chapter.name);
  for (const [relative, expected] of Object.entries(build.source_md5)) {
    if (crypto.createHash('md5').update(read(relative)).digest('hex') !== expected) fail('Stale app reference: '+relative);
  }
  if (sha(read('docs/book/data/app-reference.json')) !== build.metadataSha256 || sha(read('docs/book/data/example-lessons.json')) !== build.lessonsSha256) fail('Stale book metadata.');
  fs.mkdirSync(site,{recursive:true});
  for (const name of downloads) {
    const bytes = fs.readFileSync(path.join(output,name));
    const reviewed = verification.artifacts.find(file=>file.file===name);
    if (!reviewed || reviewed.sha256 !== sha(bytes) || reviewed.bytes !== bytes.length) fail('Unverified book output: '+name);
    fs.writeFileSync(path.join(site,name),bytes);
  }
  fs.copyFileSync(path.join(site,downloads[1]),path.join(site,'index.html'));
  fs.writeFileSync(path.join(site,'.nojekyll'),'');
  const manifest = {schema:1,title:verification.title,edition:verification.edition,
    words:verification.words,PDFPages:verification.PDFPages,taskTypes:verification.taskTypes,
    exampleProjects:verification.exampleProjects,checksPassed:verification.checksPassed,
    readability:verification.readability,
    inputs:Object.fromEntries(inputFiles().map(relative=>[relative,inputHash(relative)])),
    files:[...downloads,'index.html'].map(name=>{const bytes=fs.readFileSync(path.join(site,name));return{name,bytes:bytes.length,sha256:sha(bytes)};})};
  fs.writeFileSync(path.join(site,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
}
const verified = verifySite();
console.log(JSON.stringify({ok:true,page:'https://woodtho.github.io/IndividualGuide/',downloads:formats,
  words:verified.words,pages:verified.PDFPages,checks:verified.checksPassed},null,2));
