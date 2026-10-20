'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
function numberFigures(markdown,source) {
  const figures=[];
  const numbered=markdown.replace(/!\[([^\]]+)\]\((assets\/[^)]+)\)\{#(fig-[\w-]+)([^}]*)\}/g,(_match,caption,file,id,attributes)=>{
    if(figures.some(figure=>figure.id===id))throw new Error('Duplicate figure: '+id);
    const figure={number:figures.length+1,id,file,caption,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(source,file))).digest('hex')};
    figures.push(figure);
    return `![Figure ${figure.number}. ${caption}](${file}){#${id}${attributes||' width=15.5cm'}}`;
  });
  if((numbered.match(/!\[/g)||[]).length!==figures.length)throw new Error('Every book image needs a caption and fig- ID.');
  const complete=numbered.replace(/\[Figure\]\(#(fig-[\w-]+)\)/gi,(_match,id)=>{
    const figure=figures.find(figure=>figure.id===id);
    if(!figure)throw new Error('Unknown figure reference: '+id);
    return `[Figure ${figure.number}](#${id})`;
  });
  return {markdown:complete,figures};
}
module.exports={numberFigures};
