'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const {parallelHeadings,assertParity}=require('./book-parity.cjs');
const {spawnSync}=require('node:child_process');
const pandoc=[process.env.PANDOC,'pandoc',process.platform==='win32'&&path.join(process.env.LOCALAPPDATA||'','Pandoc/pandoc.exe')]
 .filter(Boolean).find(command=>spawnSync(command,['--version'],{windowsHide:true}).status===0);
if(!pandoc)throw Error('Pandoc is required to compare the handbook editions.');
const english='# Start {#start}\n\n## Run a task\n\n1. Select `flowers`.\n2. Run it.\n\n```r\n2 + 3\n```\n\n![A real view](assets/ui-test.png){#fig-test}\n\n| Setting | Choice |\n| --- | --- |\n| Input | `flowers` |\n\n[Help](#start)\n';
const draft='# Départ {#start}\n\n## Exécuter une tâche\n\n1. Choisissez `flowers`.\n2. Exécutez-la.\n\n```r\n2 + 3\n```\n\n![Une vraie vue](assets/ui-test.png){#fig-test}\n\n| Paramètre | Choix |\n| --- | --- |\n| Entrée | `flowers` |\n\n[Aide](#start)\n';
test('matching translations share section anchors and reject lost steps, code, images or links',()=>{
 const french=parallelHeadings(pandoc,english,draft);
 assert.ok(french.includes('## Exécuter une tâche {#run-a-task}'));
 assert.equal(assertParity(pandoc,english,french).ok,true);
 for(const [changed,type]of [
  [french.replace('2. Exécutez-la.\n',''),'numberedLists'],
  [french.replace('2 + 3','2 + 4'),'codeBlocks'],
  [french.replace('assets/ui-test.png','assets/ui-other.png'),'images'],
  [french.replace('[Aide](#start)','[Aide](#absent)'),'links'],
  [french.replace('| Entrée | `flowers` |','| Entrée | `flowers` |\n| Autre | Choix |'),'tables']
 ])assert.throws(()=>assertParity(pandoc,english,changed),new RegExp(type));
 assert.throws(()=>parallelHeadings(pandoc,english,draft.replace('## Exécuter une tâche','### Exécuter une tâche')),/same headings/);
});
test('all authored French chapters preserve the same procedures, examples and identifiers',()=>{
 const book=path.join(__dirname,'../docs/book');
 for(const name of fs.readdirSync(path.join(book,'chapters')).filter(name=>name.endsWith('.md'))){
  const english=fs.readFileSync(path.join(book,'chapters',name),'utf8');
  const french=fs.readFileSync(path.join(book,'fr-CA/chapters',name),'utf8');
  assert.equal(assertParity(pandoc,english,parallelHeadings(pandoc,english,french)).ok,true,name);
 }
});
