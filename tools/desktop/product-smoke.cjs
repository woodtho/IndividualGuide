'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path');
const { Menu, dialog, app } = require('electron');
module.exports = async ({ window, pause, state, rendererCommand, appURL }) => {
  const checks={}, js=source=>window.webContents.executeJavaScript(source,true);
  const menu=id=>Menu.getApplicationMenu().getMenuItemById(id);
  async function wait(test,label) {
    const deadline=Date.now()+90000;
    while(Date.now()<deadline) { if(await test()) return; await pause(80); }
    fs.writeFileSync(path.join(state,'product-failure.png'),(await window.webContents.capturePage()).toPNG());
    fs.writeFileSync(path.join(state,'product-failure.txt'),await js("document.body.innerText+'\\nRUN STATE '+JSON.stringify(window.igRunState)"));
    throw Error('Product test timed out: '+label);
  }
  const idle=()=>wait(()=>menu('save').enabled,'workspace ready');
  async function closeModal() {
    await wait(()=>js("(() => {const m=document.querySelector('.modal.show');return m && !bootstrap.Modal.getInstance(m)?._isTransitioning})()"),'modal transition');
    await js("document.querySelector('.modal.show .modal-footer [data-bs-dismiss=modal], .modal.show .modal-footer [data-dismiss=modal]').click()");
    await idle();
  }
  await wait(()=>menu('open').enabled && js("Boolean(document.getElementById('splash_fresh')?.classList.contains('shiny-bound-input'))"),'startup');
  await js("document.getElementById('splash_fresh').click()"); await idle();
  const originalMessage=dialog.showMessageBox;
  try {
    let about;
    dialog.showMessageBox=async(_window,options)=>{about=options;return {response:0};};
    assert.ok(menu('about').enabled); await menu('about').click();
    assert.match(about.message,new RegExp(app.getVersion().replaceAll('.','\\.')));
    assert.match(about.detail,/Source: .+\nR: R version/); checks.aboutBuildIdentity=true;
    await js("Shiny.setInputValue('help_example','iris',{priority:'event'})");
    await wait(()=>window.getTitle().includes('Iris exploration') && menu('save').enabled,'example loaded');
    // Save twice so the previous complete archive is available from the UI.
    const saved=path.join(state,'Versioned iris.igpx');
    const originalSave=dialog.showSaveDialog;
    try {
      dialog.showSaveDialog=async()=>({canceled:false,filePath:saved});
      menu('save').click(); await wait(()=>fs.existsSync(saved) && menu('save').enabled,'first save');
      menu('save').click();
      await wait(()=>fs.existsSync(path.join(state,'project-backups')) && fs.readdirSync(path.join(state,'project-backups'),{recursive:true}).some(name=>name.endsWith('.igpx')) && menu('save').enabled,'backup retained');
    } finally {dialog.showSaveDialog=originalSave;}
    menu('versions').click();
    await wait(()=>js("Boolean(document.querySelector('#project_tools-backup option'))"),'backup picker');
    assert.ok(await js("document.querySelector('#project_tools-backup option').value.endsWith('.igpx')")); checks.savedVersionsUI=true;
    await closeModal();
    menu('tasks').click(); await wait(()=>js("Boolean(document.querySelector('.ig-accessible-task-row button'))"),'task list');
    await js("const e=document.getElementById('project_tools-task_search');e.value='example_source';e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}))");
    await wait(()=>js("document.querySelectorAll('.ig-accessible-task-row').length===1"),'task search');
    await js("document.querySelector('.ig-accessible-task-row button').focus();document.activeElement.click()");
    await wait(()=>js("Boolean(document.getElementById('panel_example_source')?.dataset.igReadyToken)"),'task opened'); await idle(); checks.keyboardTaskList=true;
    menu('validate').click(); await wait(()=>js("document.querySelector('.modal.show')?.textContent.includes('Flow validation')"),'preflight');
    assert.equal(await js("Boolean(document.querySelector('.ig-preflight-row.alert-danger'))"),false); checks.preflightExample=true; await closeModal();
    menu('run').click(); await wait(()=>js("window.igRunState?.outcome==='finished' && !igRunState.running"),'background flow'); await idle(); checks.backgroundWholeFlow=true;
    menu('runs').click(); await wait(()=>js("Boolean(document.querySelector('#project_tools-runs tbody tr td')) && !document.querySelector('#project_tools-runs .dataTables_empty')"),'run records');
    assert.match(await js("document.getElementById('project_tools-runs').textContent"),/success/); checks.runRecordsUI=true; await closeModal();
    menu('files').click(); await wait(()=>js("Boolean(document.querySelector('.modal.show #project_tools-portable'))"),'portable project UI');
    assert.match(await js("document.querySelector('.modal.show').textContent"),/Portable copies include/); checks.portabilityUI=true; await closeModal();
    // A changed archive needs an explicit trust decision. Cancel leaves the
    // current project intact; acceptance goes through the normal open command.
    const external=path.join(state,'External project.igpx');
    fs.copyFileSync(saved,external);fs.appendFileSync(external,Buffer.from([0]));
    const title=window.getTitle(); let trustPrompts=0;
    dialog.showMessageBox=async(_window,options)=>{if(options.title==='Trust this project?') trustPrompts++;return {response:0};};
    assert.equal(await rendererCommand('open',external),false);assert.equal(window.getTitle(),title);assert.equal(trustPrompts,1);
    dialog.showMessageBox=async(_window,options)=>{if(options.title==='Trust this project?') trustPrompts++;return {response:1};};
    assert.equal(await rendererCommand('open',external),true,'trusted project opens');await idle();assert.equal(trustPrompts,2); checks.projectTrustCancelAndOpen=true;
    menu('tasks').click();await wait(()=>js("Boolean(document.querySelector('.modal.show .ig-accessible-task-row'))"),'scaled task list');
    for(const scale of [1.25,1.5,2]) {
      window.webContents.setZoomFactor(scale);
      // Zoom and modal layout settle asynchronously on a busy Windows runner.
      // Keep the same visibility requirement, waiting for actual layout rather
      // than assuming every machine can finish a resize within 200 ms.
      await wait(()=>js("document.documentElement.scrollWidth<=innerWidth && document.querySelector('.modal.show .modal-footer').getBoundingClientRect().bottom<=innerHeight+1"),'task list layout at zoom '+scale);
      assert.equal(await js("document.documentElement.scrollWidth<=innerWidth && document.querySelector('.modal.show .modal-footer').getBoundingClientRect().bottom<=innerHeight+1"),true,'task list fits at zoom '+scale);
      fs.writeFileSync(path.join(state,'tasks-zoom-'+scale+'.png'),(await window.webContents.capturePage()).toPNG());
    }
    window.webContents.setZoomFactor(1);await closeModal();checks.desktopDisplayScaling=true;
    // An independent local WebSocket receives no private desktop header and
    // must be closed before it can initialize an executable Shiny session.
    const endpoint=await js("Shiny.shinyapp.$socket.url");
    await new Promise((resolve,reject)=>{
      const socket=new WebSocket(endpoint), timer=setTimeout(()=>{socket.close();reject(Error('Unauthenticated Shiny connection remained open'));},10000);
      socket.addEventListener('open',()=>socket.send(JSON.stringify({method:'init',data:{}})));
      socket.addEventListener('close',()=>{clearTimeout(timer);resolve();}); socket.addEventListener('error',()=>{});
    });
    assert.equal(await js("Shiny.shinyapp.$socket.readyState===1 && typeof require==='undefined' && typeof process==='undefined'"),true,'private desktop session stays connected and isolated'); checks.privateDesktopSession=true;
    assert.equal(new URL(appURL).hostname,'127.0.0.1'); checks.localhostOnly=true;
    fs.writeFileSync(path.join(state,'product.png'),(await window.webContents.capturePage()).toPNG());
    return {ok:true,checks,project:saved};
  } catch (error) {
    error.smokeChecks=checks;
    try {
      fs.writeFileSync(path.join(state,'product-failure.png'),(await window.webContents.capturePage()).toPNG());
      fs.writeFileSync(path.join(state,'product-failure.txt'),await js("document.body.innerText+'\\nLAYOUT '+JSON.stringify({width:innerWidth,height:innerHeight,scrollWidth:document.documentElement.scrollWidth,zoom:devicePixelRatio,footer:document.querySelector('.modal.show .modal-footer')?.getBoundingClientRect().toJSON()})"));
    } catch (_) { /* Preserve the original assertion if the window disconnected. */ }
    throw error;
  } finally {dialog.showMessageBox=originalMessage;}
};
