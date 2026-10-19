'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname,'..');
function inputFiles() {
  const meta = JSON.parse(fs.readFileSync(path.join(root,'docs/book/data/app-reference.json'),'utf8'));
  return [...new Set([
    ...Object.keys(meta.source_md5),
    ...fs.readdirSync(path.join(root,'docs/book/chapters')).filter(f=>f.endsWith('.md')).map(f=>'docs/book/chapters/'+f),
    ...fs.readdirSync(path.join(root,'docs/book/assets')).map(f=>'docs/book/assets/'+f),
    'docs/book/data/app-reference.json', 'docs/book/data/example-lessons.json',
    'tools/book-metadata.R', 'tools/build-book.cjs', 'tools/render-book.R',
    'tools/test-book.R', 'tools/verify-book.cjs', 'tools/book-readability.cjs',
    'tools/book-inputs.cjs', 'tools/publish-book.cjs'
  ])].sort();
}
function inputHash(relative) {
  const bytes = fs.readFileSync(path.join(root,relative));
  // Git and Windows can use different line endings for text sources.
  const content = /\.(?:png|ico)$/.test(relative) ? bytes : Buffer.from(bytes.toString('utf8').replace(/\r\n/g,'\n'));
  return crypto.createHash('sha256').update(content).digest('hex');
}
const snapshot = () => Object.fromEntries(inputFiles().map(relative=>[relative,inputHash(relative)]));
module.exports = {inputFiles,inputHash,snapshot};
