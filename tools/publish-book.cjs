'use strict';
// Publish matching, verified English and Canadian French reader editions.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const output=path.resolve(process.env.BOOK_OUTPUT_DIR||path.join(root,'build/book'));
const site=path.resolve(process.env.BOOK_SITE_DIR||path.join(root,'docs/handbook'));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const fail=message=>{throw Error(message);};
const read=relative=>fs.readFileSync(path.join(root,relative));
const {inputFiles,inputHash,snapshot}=require('./book-inputs.cjs');
const editions=[{language:'en-CA',directory:''},{language:'fr-CA',directory:'fr-CA'}];
const formats=['pdf','html','epub','docx'];
const downloads=formats.map(ext=>'Individual-Guide-Handbook.'+ext);
function verifyEdition(directory,language){
  const manifest=JSON.parse(fs.readFileSync(path.join(directory,'manifest.json'),'utf8'));
  if(manifest.schema!==2||manifest.language!==language||manifest.taskTypes!==58||manifest.exampleProjects!==22||manifest.checksPassed<400)fail('Invalid book verification summary: '+language);
  const inputs=inputFiles();
  if(JSON.stringify(inputs)!==JSON.stringify(Object.keys(manifest.inputs).sort()))fail('Book source list changed. Rebuild and publish both editions.');
  for(const relative of inputs)if(inputHash(relative)!==manifest.inputs[relative])fail('Published book is stale: '+relative);
  const expected=[...downloads,'index.html'].sort();
  if(JSON.stringify(manifest.files.map(file=>file.name).sort())!==JSON.stringify(expected))fail('Missing or unexpected book format: '+language);
  for(const file of manifest.files){
    const bytes=fs.readFileSync(path.join(directory,file.name));
    if(bytes.length!==file.bytes||sha(bytes)!==file.sha256)fail('Book download differs from manifest: '+language+'/'+file.name);
  }
  const html=fs.readFileSync(path.join(directory,'index.html'),'utf8');
  if(html!==fs.readFileSync(path.join(directory,downloads[1]),'utf8'))fail('Online and offline HTML editions differ: '+language);
  if(!new RegExp('<html[^>]*lang="'+language+'"').test(html))fail('Wrong handbook language: '+language);
  const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(match=>match[1]);
  if(new Set(ids).size!==ids.length)fail('Duplicate HTML anchors: '+language);
  for(const match of html.matchAll(/href="#([^"]+)"/g))if(!ids.includes(decodeURIComponent(match[1])))fail('Broken book anchor: '+match[1]);
  const base='https://woodtho.github.io/IndividualGuide/'+(language==='fr-CA'?'fr-CA/':'');
  for(const ext of formats)if(!html.includes(base+'Individual-Guide-Handbook.'+ext))fail('Missing download link: '+language+'/'+ext);
  for(const edition of editions)if(!html.includes('https://woodtho.github.io/IndividualGuide/'+(edition.directory?edition.directory+'/':'')))fail('Missing language link: '+edition.language);
  if(/<(?:script|link|img)\b[^>]*(?:src|href)=["']https?:\/\//i.test(html))fail('The offline book has a remote resource.');
  // Search readable content and paths, not coincidental letters in encoded PNG bytes.
  const readableHTML=html.replace(/data:[\w.+/-]+;base64,[A-Za-z0-9+/=\s]+/g,'data:embedded');
  if(/(?:aThom|OneDrive|C:[\\/]Users[\\/])/i.test(readableHTML))fail('The book contains a private machine path.');
  return manifest;
}
function verifySite(){
  const english=verifyEdition(site,'en-CA');
  if(english.translations?.['fr-CA']?.directory!=='fr-CA')fail('The matching French handbook is required.');
  const frenchFile=path.join(site,'fr-CA/manifest.json');
  if(sha(fs.readFileSync(frenchFile))!==english.translations['fr-CA'].manifestSha256)fail('The French handbook manifest differs from the reviewed publication.');
  const french=verifyEdition(path.join(site,'fr-CA'),'fr-CA');
  if(english.packageVersion!==french.packageVersion||english.savedExampleSteps!==french.savedExampleSteps)fail('The language editions describe different app versions or examples.');
  return [english,french];
}
if(!process.argv.includes('--check')){
  const inputs=snapshot();
  // Preflight both complete builds before replacing any published reader file.
  const prepared=editions.map(edition=>{
    const directory=path.join(output,edition.directory);
    const verification=JSON.parse(fs.readFileSync(path.join(directory,'verification.json'),'utf8'));
    const build=JSON.parse(fs.readFileSync(path.join(directory,'manifest.json'),'utf8'));
    if(verification.ok!==true||verification.language!==edition.language||verification.taskTypes!==58||verification.exampleProjects!==22)fail('Run the full book verification: '+edition.language);
    if(JSON.stringify(build.bookInputs)!==JSON.stringify(inputs))fail('Book sources or rendering tools changed. Rebuild and verify both editions.');
    for(const chapter of build.chapters)if(sha(read(build.sourceDirectory+'/chapters/'+chapter.name))!==chapter.sha256)fail('Stale chapter: '+chapter.name);
    for(const [relative,expected]of Object.entries(build.source_md5))if(crypto.createHash('md5').update(read(relative)).digest('hex')!==expected)fail('Stale app reference: '+relative);
    if(sha(read('docs/book/data/app-reference.json'))!==build.metadataSha256||sha(read(build.sourceDirectory+'/data/example-lessons.json'))!==build.lessonsSha256)fail('Stale book metadata.');
    const files=downloads.map(name=>{
      const bytes=fs.readFileSync(path.join(directory,name));
      const reviewed=verification.artifacts.find(file=>file.file===name);
      if(!reviewed||reviewed.sha256!==sha(bytes)||reviewed.bytes!==bytes.length)fail('Unverified book output: '+edition.language+'/'+name);
      return {name,bytes};
    });
    files.push({name:'index.html',bytes:files.find(file=>file.name.endsWith('.html')).bytes});
    const manifest={schema:2,title:verification.title,edition:verification.edition,language:edition.language,packageVersion:build.packageVersion,
      words:verification.words,PDFPages:verification.PDFPages,taskTypes:verification.taskTypes,exampleProjects:verification.exampleProjects,
      savedExampleSteps:verification.savedExampleSteps,checksPassed:verification.checksPassed,readability:verification.readability,inputs,
      files:files.map(file=>({name:file.name,bytes:file.bytes.length,sha256:sha(file.bytes)}))};
    return {edition,files,manifest};
  });
  const french=prepared[1];
  const serialize=value=>Buffer.from(JSON.stringify(value,null,2)+'\n');
  prepared[0].manifest.translations={'fr-CA':{directory:'fr-CA',manifestSha256:sha(serialize(french.manifest))}};
  for(const {edition,files,manifest}of prepared){
    const directory=path.join(site,edition.directory);fs.mkdirSync(directory,{recursive:true});
    for(const file of files)fs.writeFileSync(path.join(directory,file.name),file.bytes);
    fs.writeFileSync(path.join(directory,'manifest.json'),serialize(manifest));
  }
  fs.writeFileSync(path.join(site,'.nojekyll'),'');
}
const verified=verifySite();
console.log(JSON.stringify({ok:true,editions:verified.map(book=>({language:book.language,page:'https://woodtho.github.io/IndividualGuide/'+(book.language==='fr-CA'?'fr-CA/':''),
  downloads:formats,words:book.words,pages:book.PDFPages,checks:book.checksPassed}))},null,2));
