'use strict';
const {spawnSync}=require('node:child_process');
function parse(pandoc,markdown){
  const result=spawnSync(pandoc,['--from=markdown+fenced_divs+header_attributes','--to=json'],{input:markdown,encoding:'utf8',windowsHide:true,maxBuffer:20*1024*1024});
  if(result.status!==0)throw Error('Could not inspect book structure: '+result.stderr);
  return JSON.parse(result.stdout);
}
function collect(value,type,found=[]){
  if(Array.isArray(value))for(const child of value)collect(child,type,found);
  else if(value&&typeof value==='object'){
    if(value.t===type)found.push(value.c);
    for(const child of Object.values(value))collect(child,type,found);
  }
  return found;
}
function parallelHeadings(pandoc,english,french){
  const en=collect(parse(pandoc,english),'Header'),fr=collect(parse(pandoc,french),'Header');
  if(en.length!==fr.length||en.some((header,index)=>header[0]!==fr[index][0]))throw Error('English and French must have the same headings in the same order.');
  let index=0;
  const markdown=french.replace(/^(#{1,6}) (.+)$/gm,(line,prefix,title)=>{
    const expected=en[index++][1][0],explicit=title.match(/\{#([^\s}]+)/);
    if(explicit&&explicit[1]!==expected)throw Error('French heading anchor differs from English: '+expected);
    return explicit?line:prefix+' '+title+' {#'+expected+'}';
  });
  if(index!==en.length)throw Error('Unsupported heading format in translated book.');
  return markdown;
}
function structure(pandoc,markdown){
  const document=parse(pandoc,markdown);
  return {
    headings:collect(document,'Header').map(value=>({level:value[0],id:value[1][0]})),
    codeBlocks:collect(document,'CodeBlock').map(value=>value[1]),
    code:collect(document,'Code').map(value=>value[1]),
    images:collect(document,'Image').map(value=>({id:value[0][0],file:value[2][0]})),
    numberedLists:collect(document,'OrderedList').map(value=>value[1].length),
    bulletLists:collect(document,'BulletList').map(value=>value.length),
    paragraphs:collect(document,'Para').length,
    tables:collect(document,'Table').map(value=>({columns:value[2].length,
      rows:collect(value,'Row').length,cells:collect(value,'Cell').length,
      // Pandoc represents table rows and cells as tuples rather than tagged
      // nodes in recent JSON versions. Retain their shape without prose.
      head:value[3][1].map(row=>row[1].length),
      body:value[4].map(body=>({head:body[2].map(row=>row[1].length),rows:body[3].map(row=>row[1].length)})),
      foot:value[5][1].map(row=>row[1].length)})),
    links:collect(document,'Link').map(value=>value[2][0])
  };
}
function assertParity(pandoc,english,french){
  const en=structure(pandoc,english),fr=structure(pandoc,french);
  const normalizeLink=value=>value.replace('https://woodtho.github.io/IndividualGuide/fr-CA/','https://woodtho.github.io/IndividualGuide/');
  en.links=en.links.map(normalizeLink);fr.links=fr.links.map(normalizeLink);
  for(const key of Object.keys(en))if(JSON.stringify(en[key])!==JSON.stringify(fr[key])){
    throw Error('French handbook differs from English in '+key+'. Keep the same content, order and examples.');
  }
  return {ok:true,headings:en.headings.length,codeBlocks:en.codeBlocks.length,images:en.images.length,
    numberedLists:en.numberedLists.length,tables:en.tables.length,links:en.links.length};
}
module.exports={parse,collect,parallelHeadings,structure,assertParity};
