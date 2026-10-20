'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {Menu,app}=require('electron');
module.exports=async({window,pause,state,runtime,getProcess})=>{
 const checks={},pids=[],js=code=>window.webContents.executeJavaScript(code,true);
 const menu=id=>Menu.getApplicationMenu().getMenuItemById(id);
 async function wait(test,label){
  const deadline=Date.now()+90000;
  while(Date.now()<deadline){if(await test())return;await pause(100);}
  fs.writeFileSync(path.join(state,'shiny-apps-failure.png'),(await window.webContents.capturePage()).toPNG());
  fs.writeFileSync(path.join(state,'shiny-apps-failure.txt'),await js('document.body.innerText'));
  throw Error('Shiny app desktop test timed out: '+label);
 }
 const mainPid=getProcess().pid;
 let guestURL='';
 await wait(()=>menu('shiny-apps').enabled&&js("Boolean(document.getElementById('splash_shiny_apps'))"),'startup');
 await js('window._hostSocket=Shiny.shinyapp.$socket');
 menu('shiny-apps').click();
 await wait(()=>js("!document.getElementById('ig-shiny-apps').hidden&&!document.getElementById('shiny-modal')"),'native opener');
 const examples=path.join(state,'External apps é with spaces');
 fs.cpSync(path.join(runtime,'R/library/IndividualGuide/shiny-apps'),examples,{recursive:true});
 const marker=path.join(examples,'iris-explorer','token.txt');
 const entry=path.join(examples,'iris-explorer','app.R');
 fs.writeFileSync(entry,`writeLines(Sys.getenv('IG_DESKTOP_TOKEN'), ${JSON.stringify(marker.replaceAll('\\','/'))})\n`+fs.readFileSync(entry,'utf8'));
 async function choose(target,folder=false){
  const root=path.parse(target).root.replace(/[\\/]$/,'');
  const parts=path.relative(path.parse(target).root,target).split(path.sep);
  const payload=folder?{root,path:['',...parts]}:{root,files:[parts]};
  await js(`Shiny.setInputValue(${JSON.stringify(folder?'sf_shiny_folder':'sf_shiny_app')},${JSON.stringify(payload)},{priority:'event'})`);
  await wait(()=>js(`document.getElementById('ig-app-path').textContent===${JSON.stringify((folder?target:path.dirname(target)).replaceAll('\\','/'))}`),'selection');
 }
 async function run(){
  await js("document.getElementById('ig-app-trust').checked=true;document.getElementById('ig-app-trust').dispatchEvent(new Event('change'));document.getElementById('ig-app-run').click()");
  await wait(()=>js("!igShinyApps.pending&&igShinyApps.state.phase==='ready'"),'guest ready');
  pids.push(await js('igShinyApps.state.pid'));
  guestURL=await js('igShinyApps.state.url');
 }
 const frame=()=>window.webContents.mainFrame.frames.find(f=>guestURL&&f.url.startsWith(guestURL));
 const guest=code=>frame()?.executeJavaScript(code,true);
 await choose(entry);await run();
 await wait(()=>guest("document.getElementById('count')?.textContent==='150 flowers'"),'guest reactive output');
 assert.notEqual(frame().processId,window.webContents.mainFrame.processId,
   'The loaded app must not share the main workspace renderer.');
 checks.independentGuestRenderer=true;
 assert.equal(await guest("typeof window.igDesktop==='undefined'&&typeof require==='undefined'&&typeof process==='undefined'"),true);
 assert.equal(fs.readFileSync(marker,'utf8').trim(),'');checks.guestHasNoDesktopBridgeOrToken=true;
 await guest("document.getElementById('species').value='setosa';document.getElementById('species').dispatchEvent(new Event('change',{bubbles:true}))");
 await wait(()=>guest("document.getElementById('count').textContent==='50 flowers'"),'guest input');
 menu('workspace').click();
 await wait(()=>menu('open').enabled&&js("document.getElementById('ig-shiny-apps').hidden"),'main remains available');
  await js("Shiny.setInputValue('help_example','iris',{priority:'event'})");
  await wait(()=>js("document.getElementById('project_tree_ui').textContent.includes('example_source')"),'real main project with saved task results');
  await js("document.getElementById('ig-tree-search-input').value='keep my project'");
  const projectTree=await js("document.getElementById('project_tree_ui').textContent");
 menu('shiny-apps').click();
 await wait(()=>guest("document.getElementById('species').value==='setosa'&&document.getElementById('count').textContent==='50 flowers'"),'guest kept across switch');
 assert.equal(getProcess().pid,mainPid);assert.equal(await js('Shiny.shinyapp.$socket===_hostSocket'),true);
 checks.workspaceAndGuestPreserveProcessAndInput=true;
 await js("document.getElementById('ig-app-open').click()");
 await choose(path.join(examples,'local-sales'),true);await run();
 await wait(()=>guest("document.getElementById('total')?.textContent==='Total: 450'"),'two-file app and relative helper/data');
  const download=path.join(state,'guest-sales.csv');
  let downloaded=false;
  window.webContents.session.once('will-download',(_event,item)=>{
    item.setSavePath(download);item.once('done',(_event,status)=>{downloaded=status==='completed';});
  });
  await guest("document.getElementById('download').click()");
  await wait(()=>downloaded&&fs.existsSync(download),'guest download');
  assert.match(fs.readFileSync(download,'utf8'),/January.*120/);
  checks.guestDownloadWorks=true;
 checks.bothFormatsAndAppSwitch=true;
 menu('close-shiny-app').click();
 await wait(()=>js("document.getElementById('ig-app-confirm').open"),'native close control');
 await js("document.getElementById('ig-app-cancel-close').click()");
 assert.equal(await js("igShinyApps.state.phase==='ready'"),true);
 menu('close-shiny-app').click();
 await wait(()=>js("document.getElementById('ig-app-confirm').open"),'second close confirmation');
 menu('workspace').click();
 await wait(()=>js("document.getElementById('ig-shiny-apps').hidden"),'workspace from confirmation');
 assert.equal(await js("document.getElementById('ig-app-confirm').open"),false,'Returning to the workspace must cancel the close dialog.');
 checks.workspaceCancelsCloseDialog=true;
 menu('close-shiny-app').click();await js("document.getElementById('ig-app-confirm-close').click()");
 await wait(()=>js("igShinyApps.state.phase==='idle'&&!igShinyApps.pending"),'close app');
 checks.nativeCloseAndCancel=true;
 await choose(entry);await run();
 await wait(()=>guest("document.getElementById('count')?.textContent==='150 flowers'"),'guest before intentional JS hang');
 const frozenRenderer=app.getAppMetrics().find(value=>value.pid===frame().osProcessId);
 assert.ok(frozenRenderer);
 guest('while(true){}').catch(()=>{});
 await pause(250);
 menu('workspace').click();
 await wait(()=>js("document.getElementById('ig-shiny-apps').hidden&&Shiny.shinyapp.$socket===_hostSocket"),'workspace responsive during guest JS hang');
 menu('close-shiny-app').click();
 await js("document.getElementById('ig-app-confirm-close').click()");
 await wait(()=>js("igShinyApps.state.phase==='idle'&&!igShinyApps.pending&&!document.getElementById('ig-app-frame')"),'close hung guest');
 await wait(()=>!app.getAppMetrics().some(value=>value.pid===frozenRenderer.pid&&value.creationTime===frozenRenderer.creationTime),'frozen renderer terminated');
 checks.closedGuestRendererStops=true;
 checks.workspaceSurvivesHungGuest=true;
 await choose(entry);await run();
 await wait(()=>guest("document.getElementById('count')?.textContent==='150 flowers'"),'new guest responds after closing the frozen app');
 await js("document.getElementById('ig-app-back').click()");
 assert.equal(await js("document.getElementById('ig-tree-search-input').value==='keep my project'"),true);
  assert.equal(await js("document.getElementById('project_tree_ui').textContent"),projectTree);
  checks.mainProjectAndSavedResultsPreserved=true;
 checks.mainWorkspaceNeverReloaded=true;
 // Deliberately leave one child running: the enclosing clean-account test
 // verifies all recorded PIDs are gone after the desktop process exits.
 return {ok:true,checks,hostedAppPids:pids};
};
