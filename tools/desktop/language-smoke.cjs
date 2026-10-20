'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {Menu,dialog}=require('electron');
module.exports=async({window,pause,state,preferences,getProcess,getState,requestRestart})=>{
 const checks={},js=source=>window.webContents.executeJavaScript(source,true);
 const menu=id=>Menu.getApplicationMenu().getMenuItemById(id);
 const option=name=>process.argv.find(value=>value.startsWith(name+'='))?.slice(name.length+1);
 const expected=option('--expect-language')||preferences.language;
 const finish=option('--finish-language')||'fr-CA';
 async function wait(test,label){
  const deadline=Date.now()+90000;
  while(Date.now()<deadline){if(await test())return;await pause(100);}
  fs.writeFileSync(path.join(state,'language-failure.png'),(await window.webContents.capturePage()).toPNG());
  fs.writeFileSync(path.join(state,'language-failure.txt'),await js('document.body.innerText'));
  throw Error('Language test timed out: '+label);
 }
 const ready=()=>wait(async()=>{
  if(await js("Boolean(document.querySelector('.modal.show #recover_discard')?.classList.contains('shiny-bound-input'))"))await js("document.querySelector('.modal.show #recover_discard').click()");
  return js("Boolean(window.igI18n&&Shiny.shinyapp.$socket.readyState===1&&document.getElementById('splash_fresh')?.classList.contains('shiny-bound-input'))");
 },'welcome');
 await ready();assert.equal(await js('igI18n.locale'),expected);assert.equal(preferences.language,expected);
 checks.installedOrRememberedLanguage=true;
 await js("document.getElementById('splash_fresh').click()");
 await wait(()=>menu('save').enabled,'editable workspace');
 await js("document.getElementById('btn_add_task').click()");
 await wait(()=>js("Boolean(document.querySelector('[onclick*=picker_select][onclick*=script]'))"),'script picker');
 await js("document.querySelector('[onclick*=picker_select][onclick*=script]').click()");
 await wait(()=>js("(()=>{const panel=document.getElementById('panel_script_1');return Boolean(panel?.dataset.igReadyToken)&&Object.entries(Shiny.shinyapp.$inputValues).some(([key,value])=>key.endsWith('_script_1-ig_ready')&&value===panel.dataset.igReadyToken)&&document.getElementById('scr_script_1-output_name')?.value==='script_1_out'&&document.getElementById('scr_script_1-output_defs')?.value.includes('script_1_out');})()"),'initialized Script inputs');
 const server=getProcess();
 await js("(()=>{window.languageSocket=Shiny.shinyapp.$socket;const e=document.getElementById('scr_script_1-output_name');e.value='Mean';e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));e.focus();e.setSelectionRange(1,3);})()");
 const change=async locale=>{
  menu('language-'+locale).click();
  await wait(async()=>await js('(window.igI18n?.locale||document.documentElement.lang)==='+JSON.stringify(locale))&&preferences.language===locale,'language '+locale);
 };
 await change('fr-CA');
 assert.equal(Menu.getApplicationMenu().items[0].label,'Fichier');
 assert.equal(await js("document.getElementById('panel_run_btn_script_1').textContent.trim()"),'Exécuter');
 assert.equal(await js("document.getElementById('scr_script_1-output_name').value"),'Mean');
 assert.equal(await js("document.activeElement.id==='scr_script_1-output_name'&&document.activeElement.selectionStart===1&&document.activeElement.selectionEnd===3"),true);
 await change('en-CA');assert.equal(Menu.getApplicationMenu().items[0].label,'File');
 assert.equal(await js("document.getElementById('scr_script_1-output_name').value"),'Mean');
 assert.equal(await js('Shiny.shinyapp.$socket===languageSocket&&languageSocket.readyState===1'),true);
 assert.equal(getProcess(),server);checks.switchKeepsProcessConnectionAndInput=true;
 await js("(()=>{const e=document.getElementById('ig-language-choice');e.value='fr-CA';e.dispatchEvent(new Event('change',{bubbles:true}));})()");
 await wait(()=>preferences.language==='fr-CA'&&Menu.getApplicationMenu().items[0].label==='Fichier','header updates native menu');
 checks.headerUpdatesNativeLanguage=true;
 await js("(()=>{const e=document.getElementById('scr_script_1-output_defs');e.value='Mean: table';e.dispatchEvent(new Event('change',{bubbles:true}));ace.edit('scr_script_1-code').setValue('Mean <- data.frame(value = 21 * 2)',-1);})()");
 await pause(600);await js("document.getElementById('panel_run_btn_script_1').click()");
 await wait(()=>js("Boolean(document.querySelector('#panel_status_script_1 .ig-status-success'))"),'real R task in French');
 assert.equal(await js("document.getElementById('scr_script_1-output_name').value"),'Mean');
 checks.realRTaskWithFrenchInterface=true;
 await js("document.getElementById('btn_add_task').click()");
 await wait(()=>js("Boolean(document.querySelector('[onclick*=picker_select][onclick*=summary_stats]'))"),'summary task picker');
 await js("document.querySelector('[onclick*=picker_select][onclick*=summary_stats]').click()");
 await wait(()=>menu('tasks').enabled,'task list available');
 menu('tasks').click();
 await wait(()=>js("Boolean(document.getElementById('project_tools-task_search'))"),'task list');
 await js("$('#project_tools-task_search').val('statistiques').trigger('input').trigger('change')");
 await wait(()=>js("document.getElementById('project_tools-tasks')?.textContent.includes('Statistiques descriptives')&&!document.getElementById('project_tools-tasks')?.textContent.includes('script_1')"),'French task list search');
 checks.frenchTaskListSearch=true;
 await js("document.querySelector('.modal.show .modal-footer [data-bs-dismiss=modal],.modal.show .modal-footer [data-dismiss=modal]').click()");
 await wait(()=>menu('about').enabled,'close task list');
 const originalDialog=dialog.showMessageBox;
 try{
  let about;dialog.showMessageBox=async(_window,options)=>{about=options;return {response:1};};
  await menu('about').click();assert.equal(about.title,'À propos d’Individual Guide');assert.ok(about.detail.includes('Source :'));
  checks.nativeDialogsFrench=true;
  assert.equal(await requestRestart(),true);await ready();assert.equal(await js('igI18n.locale'),'fr-CA');
  // A late duplicate recovery action must not stack another welcome dialog.
  await js("Shiny.setInputValue('recover_discard',987654,{priority:'event'})");await pause(400);
  assert.equal(await js("document.querySelectorAll('.ig-splash').length"),1);
  checks.duplicateRecoveryActionIgnored=true;
  checks.languageSurvivesServerRestart=true;
  const crashed=getProcess();crashed.kill();
  await wait(()=>getState().phase==='stopped'&&js("Boolean(document.getElementById('ig-restart-r')&&!document.getElementById('ig-desktop-recovery').hidden)"),'French server recovery');
  assert.equal(await js("document.getElementById('ig-restart-r').textContent"),'Redémarrer le serveur R');
  await change('en-CA');
  await wait(()=>js("document.getElementById('ig-restart-r').textContent==='Restart R server'"),'English recovery without R');
  await change('fr-CA');
  await wait(()=>js("document.getElementById('ig-restart-r').textContent==='Redémarrer le serveur R'"),'French recovery without R');
  checks.languageMenuWorksWithoutR=true;
  assert.equal(await requestRestart(),true);await ready();assert.equal(await js('igI18n.locale'),'fr-CA');
  assert.equal(await js("typeof require==='undefined'&&typeof process==='undefined'&&!window.ipcRenderer"),true);
  checks.recoveryAndRendererSandbox=true;
  await change(finish);
  assert.equal(JSON.parse(fs.readFileSync(path.join(state,'desktop-settings.json'),'utf8')).language,finish);
  checks.choiceSavedOnComputer=true;
 }finally{dialog.showMessageBox=originalDialog;}
 return {ok:true,language:{initial:expected,final:finish},checks};
};
