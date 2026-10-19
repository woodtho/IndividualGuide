'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path');
const { spawn } = require('node:child_process');
const { dialog, Menu } = require('electron');
module.exports = async options => {
  const { window, pause, state, preferences, rendererCommand, requestClose } = options;
  const evidence = await require('./menu-smoke.cjs')(options);
  const checks = evidence.checks, js = source => window.webContents.executeJavaScript(source,true);
  const menu = id => Menu.getApplicationMenu().getMenuItemById(id);
  async function wait(read, label) {
    const deadline = Date.now()+60000;
    while (Date.now()<deadline) { if(await read()) return; await pause(50); }
    throw new Error('Lifecycle test timed out: '+label);
  }
  const idle = () => wait(()=>menu('save').enabled,'idle');
  const edit = value => js(`ace.edit('scr_script_1-code').setValue(${JSON.stringify(value)},-1)`);
  async function addScript(id) {
    await idle(); menu('add-task').click();
    await wait(()=>js("Boolean(document.querySelector('[onclick*=\"picker_select\"][onclick*=\"script\"]'))"),'script picker');
    await js("document.querySelector('[onclick*=\"picker_select\"][onclick*=\"script\"]').click()");
    await wait(()=>js(`Boolean(document.getElementById('panel_${id}')?.dataset.igReadyToken && document.getElementById('scr_${id}-output_name')?.classList.contains('shiny-bound-input'))`),'script ready');
    await idle();
  }
  const originalMessage=dialog.showMessageBox, originalSave=dialog.showSaveDialog;
  try {
    assert.ok(preferences.recent.some(item=>item.path===evidence.projectFiles[0]));
    menu('pin-project').click(); assert.ok(preferences.recent.some(item=>item.pinned));
    assert.ok(require('./preferences.cjs').preferences(path.join(state,'desktop-settings.json')).recent.some(item=>item.pinned));
    checks.recentPinnedPersistence=true;
    menu('unpin-recent-0').click(); assert.equal(preferences.recent.some(item=>item.pinned),false);
    menu('pin-project').click(); checks.unpinWithoutOpeningProject=true;
    const recovery=path.join(state,'recovery','recovery.igpx');
    fs.mkdirSync(path.dirname(recovery),{recursive:true});
    fs.copyFileSync(evidence.projectFiles[0],recovery);
    const invalid=path.join(state,'Corrupt project.igpx'); fs.writeFileSync(invalid,'invalid');
    dialog.showMessageBox=async()=>({response:1});
    assert.equal(await rendererCommand('open',invalid),false); assert.ok(fs.existsSync(recovery));
    checks.failedOpenPreservesRecovery=true;
    assert.equal(await rendererCommand('open',evidence.projectFiles[0]),true); await idle();
    assert.equal(fs.existsSync(recovery),false); checks.successfulOpenClearsOldRecovery=true;
    await js("Shiny.setInputValue('tree_task_click','script_1',{priority:'event'})");
    await wait(()=>js("Boolean(document.getElementById('panel_script_1')?.dataset.igReadyToken)"),'script for discarded close');
    await edit('discard_rows <- data.frame(value=999)');
    fs.copyFileSync(evidence.projectFiles[0],recovery);
    assert.equal(await rendererCommand('exit'),true); assert.equal(fs.existsSync(recovery),false);
    checks.discardExitRetiresRecovery=true;
    assert.equal(await rendererCommand('open',evidence.projectFiles[0]),true); await idle();
    await js("Shiny.setInputValue('tree_task_click','script_1',{priority:'event'})");
    await wait(()=>js("Boolean(document.getElementById('panel_script_1')?.dataset.igReadyToken)"),'script after discarded exit');
    await edit('menu_rows <- data.frame(value=101)');
    dialog.showMessageBox=async()=>({response:0});
    assert.equal(await rendererCommand('new'),false); assert.ok(!window.isDestroyed());
    assert.equal(await js("ace.edit('scr_script_1-code').getValue()"),'menu_rows <- data.frame(value=101)');
    checks.cancelNewPreservesEdits=true;
    dialog.showMessageBox=async()=>({response:1});
    assert.equal(await rendererCommand('new'),true); await idle();
    assert.equal(await js("document.querySelectorAll('.ig-task-panel[id^=panel_script_]').length"),0);
    assert.equal(menu('run').enabled,false); assert.equal(window.getTitle().endsWith('*'),false);
    checks.newProjectClearsWorkspace=true;
    await addScript('script_1'); await edit('close_rows <- data.frame(value=201)');
    dialog.showMessageBox=async()=>({response:2});
    dialog.showSaveDialog=async()=>({canceled:true});
    assert.equal(await requestClose(),false); assert.ok(!window.isDestroyed());
    checks.cancelSaveAsKeepsWindow=true;
    const blocker=path.join(state,'not-a-directory'); fs.writeFileSync(blocker,'block');
    dialog.showSaveDialog=async()=>({canceled:false,filePath:path.join(blocker,'blocked.igpx')});
    assert.equal(await requestClose(),false); assert.ok(!window.isDestroyed());
    checks.failedSaveKeepsWindow=true;
    const savedBeforeNew=path.join(state,'Saved before new Ω.igpx');
    dialog.showSaveDialog=async()=>({canceled:false,filePath:savedBeforeNew});
    assert.equal(await rendererCommand('new'),true); await idle(); assert.ok(fs.existsSync(savedBeforeNew));
    checks.saveBeforeNew=true;
    // A real second process delivers a Unicode/spaced filename to this instance.
    await new Promise((resolve,reject)=>{
      const args=process.defaultApp ? [__dirname] : [];
      const child=spawn(process.execPath,[...args,`--data-dir=${state}`,savedBeforeNew],{windowsHide:true,stdio:'ignore'});
      child.once('error',reject); child.once('exit',code=>code===0?resolve():reject(new Error('Second launch '+code)));
    });
    await wait(()=>window.getTitle().includes('Saved before new'),'second process project');
    await idle(); checks.secondInstanceOpensProject=true;
    await js("Shiny.setInputValue('tree_task_click','script_1',{priority:'event'})");
    await wait(()=>js("Boolean(document.getElementById('panel_script_1')?.dataset.igReadyToken)"),'reopened script');
    assert.equal(await js("ace.edit('scr_script_1-code').getValue()"),'close_rows <- data.frame(value=201)');
    checks.savedImmediateEditRestored=true;
    assert.equal(await rendererCommand('close'),true);
    await wait(()=>js("Boolean(document.getElementById('splash_fresh'))"),'closed project welcome');
    checks.closeProjectReturnsWelcome=true;
    assert.equal(await rendererCommand('new'),true); await idle(); await addScript('script_1');
    const firstMarker=path.join(state,'first-task.txt').replace(/\\/g,'/'), secondMarker=path.join(state,'second-task.txt').replace(/\\/g,'/');
    await edit(`Sys.sleep(1); writeLines('first', ${JSON.stringify(firstMarker)}); task_rows <- data.frame(value=1)`);
    await addScript('script_2');
    await js(`ace.edit('scr_script_2-code').setValue(${JSON.stringify(`writeLines('second', ${JSON.stringify(secondMarker)}); task_rows <- data.frame(value=2)`)},-1)`);
    await wait(()=>menu('run').enabled,'run enabled'); menu('run').click();
    await wait(()=>js("window.igRunState?.running && window.igRunState?.task==='script_1'"),'first task status');
    assert.equal(await js("!document.getElementById('ig-run-status').hidden && !document.getElementById('ig-stop-run').hidden"),true);
    menu('stop').click();
    await wait(()=>js("window.igRunState?.outcome==='stopped'"),'stopped');
    await pause(300);
    assert.equal(fs.existsSync(secondMarker),false); assert.equal(menu('run').enabled,true);
    checks.stopPreventsRemainingTasks=true; checks.visibleRunStatus=true;
    // Run both normally after stopping to prove the queue can be used again.
    menu('run').click(); await wait(()=>js("window.igRunState?.outcome==='finished'"),'rerun finished');
    assert.ok(fs.existsSync(firstMarker)); assert.ok(fs.existsSync(secondMarker));
    assert.equal(await js('window.igRunState.completed'),2); checks.rerunAfterStop=true;
    window.setBounds({x:20,y:20,width:1100,height:760}); await pause(600);
    assert.equal(preferences.window.width,window.getNormalBounds().width);
    window.maximize(); await pause(600); assert.equal(preferences.window.maximized,true);
    window.unmaximize(); await pause(500); checks.windowStatePersists=true;
    let closePrompts=0;
    dialog.showMessageBox=async()=>{closePrompts++;return {response:0};};
    window.close(); await wait(()=>closePrompts===1 && menu('save').enabled,'native Close cancelled');
    assert.ok(!window.isDestroyed()); checks.cancelCloseKeepsWindow=true;
    const saveOnClose=path.join(state,'Saved on close.igpx');
    dialog.showMessageBox=async()=>({response:2});
    dialog.showSaveDialog=async()=>({canceled:false,filePath:saveOnClose});
    // The caller records evidence first, then uses the real window-close path.
    evidence.finishClose=async()=>{
      window.close(); await wait(()=>window.isDestroyed(),'native Close saves and exits');
      assert.ok(fs.existsSync(saveOnClose)); checks.saveOnClose=true;
      dialog.showMessageBox=originalMessage; dialog.showSaveDialog=originalSave;
    };
    fs.writeFileSync(path.join(state,'lifecycle.png'),(await window.webContents.capturePage()).toPNG());
    return evidence;
  } catch(error) { dialog.showMessageBox=originalMessage; dialog.showSaveDialog=originalSave; throw error; }
};
