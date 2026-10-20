'use strict';
const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),output=path.resolve(process.argv[2]||path.join(root,'build/release'));
const verified=spawnSync(process.execPath,[path.join(__dirname,'publish-book.cjs'),'--check'],{encoding:'utf8',windowsHide:true});
if(verified.status!==0)throw Error('Publish and verify both handbook editions before staging release books.\n'+verified.stderr);
fs.mkdirSync(output,{recursive:true});
for(const language of ['en-CA','fr-CA'])for(const format of ['html','pdf','epub','docx']){
 const source=path.join(root,'docs/handbook',language==='fr-CA'?'fr-CA':'','Individual-Guide-Handbook.'+format);
 const destination=path.join(output,'Individual-Guide-Handbook-'+language+'.'+format);
 fs.copyFileSync(source,destination);
}
console.log('Staged eight verified English and French handbook downloads.');
