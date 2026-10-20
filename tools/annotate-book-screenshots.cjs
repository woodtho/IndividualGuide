'use strict';
// Add clearly identified callouts to a real capture. The underlying interface
// is preserved at its original resolution; the raw capture remains in evidence.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {Resvg}=require('./desktop/node_modules/@resvg/resvg-js');
const root=path.resolve(__dirname,'..'),language=process.env.BOOK_LANGUAGE||'en-CA';
if(!['en-CA','fr-CA'].includes(language))throw Error('Unsupported book language.');
const book=path.join(root,'docs/book',language==='fr-CA'?'fr-CA':'');
const evidence=path.join(root,'artifacts/book-review',language==='fr-CA'?'fr-CA':'');
const file=path.join(book,'data/screenshots.json');
const metadata=JSON.parse(fs.readFileSync(file,'utf8'));
const shot=metadata.screenshots.find(shot=>shot.id==='workspace');
if(!shot)throw new Error('Capture the real workspace before annotating it.');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const target=path.join(book,shot.file);let original=fs.readFileSync(target);
if(sha(original)!==shot.sha256)throw new Error('The workspace capture differs from its provenance.');
if(process.argv.includes('--refresh')&&shot.annotations){
  const raw=fs.readFileSync(path.join(evidence,'raw-ui-workspace.png'));
  if(sha(raw)!==shot.annotations.originalSha256)throw new Error('The raw workspace capture differs from its provenance.');
  original=raw;delete shot.annotations;
}
if(!shot.annotations){
  fs.mkdirSync(evidence,{recursive:true});
  fs.writeFileSync(path.join(evidence,'raw-ui-workspace.png'),original);
  const {width,height}=shot.pixels;
  const markers=[{number:1,x:.257,y:.188,toX:.20,toY:.188,label:'Project tree'},
    {number:2,x:.79,y:.375,toX:.79,toY:.475,label:'Connected flow'},
    {number:3,x:.70,y:.09,toX:.63,toY:.155,label:'Flow, Code, and R Console tabs'}];
  const overlay=markers.map(marker=>{
    const x=marker.x*width,y=marker.y*height,tx=marker.toX*width,ty=marker.toY*height;
    return `<path d="M ${x} ${y} L ${tx} ${ty}" stroke="white" stroke-width="12"/><path d="M ${x} ${y} L ${tx} ${ty}" stroke="#3654c8" stroke-width="6"/><circle cx="${tx}" cy="${ty}" r="8" fill="#3654c8" stroke="white" stroke-width="3"/><circle cx="${x}" cy="${y}" r="46" fill="#3654c8" stroke="white" stroke-width="7"/><text x="${x}" y="${y+21}" text-anchor="middle" font-family="Arial" font-weight="700" font-size="62" fill="white">${marker.number}</text>`;
  }).join('');
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${width}" height="${height}"><image width="${width}" height="${height}" xlink:href="data:image/png;base64,${original.toString('base64')}"/>${overlay}</svg>`;
  const annotated=new Resvg(svg).render().asPng();fs.writeFileSync(target,annotated);
  shot.annotations={kind:'Numbered callouts over an unchanged live screenshot',originalSha256:sha(original),markers};
  shot.sha256=sha(annotated);
  fs.writeFileSync(file,JSON.stringify(metadata,null,2)+'\n');
  const progress=path.join(evidence,'screenshots-in-progress.json');
  if(fs.existsSync(progress)){
    const shots=JSON.parse(fs.readFileSync(progress,'utf8')),index=shots.findIndex(value=>value.id===shot.id);
    if(index>=0){shots[index]=shot;fs.writeFileSync(progress,JSON.stringify(shots,null,2)+'\n');}
  }
}
console.log('Workspace callouts verified: project tree, connected flow, and view tabs.');
