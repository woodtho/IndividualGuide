'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {Resvg}=require('./desktop/node_modules/@resvg/resvg-js');
const root=path.resolve(__dirname,'..');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const evidence=[];
for(const language of ['en-CA','fr-CA']){
 const assets=path.join(root,'docs/book',language==='fr-CA'?'fr-CA':'','assets');
 const svg=fs.readFileSync(path.join(assets,'workflow.svg'));
 const png=new Resvg(svg,{fitTo:{mode:'width',value:2000}}).render().asPng();
 fs.writeFileSync(path.join(assets,'workflow.png'),png);
 evidence.push({language,source:'workflow.svg',svgSha256:sha(svg),pngSha256:sha(png),
   chartSha256:sha(fs.readFileSync(path.join(assets,'iris-chart.png')))});
}
fs.writeFileSync(path.join(root,'docs/book/data/illustrations.json'),JSON.stringify(evidence,null,2)+'\n');
console.log('Rendered both editable workflow diagrams with matching geometry.');
