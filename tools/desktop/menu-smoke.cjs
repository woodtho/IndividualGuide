'use strict';
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { dialog, Menu } = require('electron');
module.exports = async ({ window, pause, state, logPath, sendCommand, saveDiagnosticLog }) => {
  const checks = {}, js = source => window.webContents.executeJavaScript(source, true);
  const menu = id => Menu.getApplicationMenu().getMenuItemById(id);
  async function wait(predicate, label) {
    const deadline = Date.now() + 60000;
    while (Date.now() < deadline) { if (await predicate()) return; await pause(100); }
    throw new Error('Menu test timed out: ' + label);
  }
  const idle = () => wait(() => menu('save').enabled, 'project command complete');
  const command = id => { assert.ok(menu(id).enabled, 'Menu is disabled: '+id); menu(id).click(); };
  const closeModal = async () => {
    await wait(() => !menu('save').enabled, 'modal menu state');
    await js("document.querySelector('.modal.show [data-dismiss=\"modal\"],.modal.show [data-bs-dismiss=\"modal\"]')?.click()");
    await wait(() => js("!document.querySelector('.modal.show')"), 'modal closed'); await idle();
  };
  await wait(() => menu('open').enabled && js("Boolean(document.getElementById('splash_fresh')?.classList.contains('shiny-bound-input'))"), 'connected desktop');
  assert.equal(await js("Boolean(window.igDesktop && document.documentElement.classList.contains('ig-desktop') && !document.getElementById('btn_save').getClientRects().length && !document.getElementById('btn_open').getClientRects().length)"), true);
  assert.equal(await js("typeof require === 'undefined' && typeof process === 'undefined' && !window.ipcRenderer"), true);
  checks.desktopMenusReplaceHeader = true; checks.sandbox = true;
  await js("document.getElementById('splash_fresh').click()"); await idle();
  command('packages');
  await wait(() => js("Boolean(document.getElementById('packages-install')?.classList.contains('shiny-bound-input'))"), 'native package manager');
  checks.nativePackageManager = true;
  await closeModal();
  command('add-task');
  await wait(() => js("Boolean(document.querySelector('[onclick*=\"picker_select\"][onclick*=\"script\"]'))"), 'script picker');
  await js("document.querySelector('[onclick*=\"picker_select\"][onclick*=\"script\"]').click()");
  await wait(() => js("Boolean(document.getElementById('panel_script_1')?.dataset.igReadyToken && document.getElementById('scr_script_1-output_name')?.classList.contains('shiny-bound-input'))"), 'script ready');
  const first = path.join(state,'Native project Ω.igpx'), second = path.join(state,'Second project.igpx');
  const originalSave = dialog.showSaveDialog, originalOpen = dialog.showOpenDialog, originalMessage = dialog.showMessageBox;
  let saveDialogs = 0, openDialogs = 0;
  try {
    dialog.showSaveDialog = async () => { saveDialogs++; return { canceled: true }; };
    command('save'); await wait(() => saveDialogs === 1 && menu('save').enabled, 'cancel Save As');
    assert.equal(fs.existsSync(first),false); checks.cancelNativeDialog = true;
    await js("ace.edit('scr_script_1-code').setValue('menu_rows <- data.frame(value = 42)',-1)");
    dialog.showSaveDialog = async () => { saveDialogs++; return { canceled: false, filePath: first }; };
    command('save'); await wait(() => fs.existsSync(first) && !window.getTitle().endsWith('*') && menu('save').enabled, 'native first save');
    checks.nativeSave = true;
    const saved = fs.readFileSync(first);
    await js("ace.edit('scr_script_1-code').setValue('menu_rows <- data.frame(value = 99)',-1)");
    command('save'); await wait(() => {
      // Windows replaces the previous project through a temporary file. The
      // destination can briefly be absent while that save is still pending.
      if (!menu('save').enabled || window.getTitle().endsWith('*')) return false;
      try { return !fs.readFileSync(first).equals(saved); }
      catch (error) { if (error.code === 'ENOENT') return false; throw error; }
    }, 'save existing path');
    assert.equal(saveDialogs,2); checks.saveOverwritesSameFile = true;
    dialog.showSaveDialog = async () => { saveDialogs++; return { canceled: false, filePath: second }; };
    command('save-as'); await wait(() => fs.existsSync(second) && menu('save').enabled && window.getTitle().includes('Second project'), 'native Save As');
    checks.nativeSaveAs = true;
    await js("ace.edit('scr_script_1-code').setValue('menu_rows <- data.frame(value = 7)',-1)");
    await wait(() => window.getTitle().endsWith('*'), 'native dirty title');
    let confirmations = 0;
    dialog.showMessageBox = async () => { confirmations++; return { response: 0 }; };
    dialog.showOpenDialog = async () => { openDialogs++; return { canceled: false, filePaths: [first] }; };
    command('open'); await wait(() => confirmations === 1 && menu('open').enabled, 'unsaved Open cancelled');
    assert.equal(openDialogs,0); assert.equal(await js("ace.edit('scr_script_1-code').getValue()"),'menu_rows <- data.frame(value = 7)');
    checks.unsavedOpenCancel = true;
    dialog.showMessageBox = async () => ({ response: 1 });
    dialog.showOpenDialog = async () => { openDialogs++; return { canceled: true, filePaths: [] }; };
    command('open'); await wait(() => openDialogs===1 && menu('save').enabled, 'cancel native Open');
    assert.equal(await js("ace.edit('scr_script_1-code').getValue()"),'menu_rows <- data.frame(value = 7)');
    dialog.showOpenDialog = async () => { openDialogs++; return { canceled: false, filePaths: [first] }; };
    command('open'); await wait(() => openDialogs===2 && menu('save').enabled && !window.getTitle().endsWith('*'), 'native Open');
    await js("Shiny.setInputValue('tree_task_click','script_1',{priority:'event'})");
    await wait(() => js("Boolean(document.getElementById('panel_script_1')?.dataset.igReadyToken)"), 'reopened task');
    assert.equal(await js("ace.edit('scr_script_1-code').getValue()"),'menu_rows <- data.frame(value = 99)');
    checks.nativeOpenPreservesImmediateEdits = true;
    for (const [id,selector] of [['settings','#settings_apply'],['help','#help_task_search'],['shortcuts','.ig-shortcuts-modal'],['history','#history_dt'],['comments','#shiny-modal'],['review','#shiny-modal']]) {
      await idle(); command(id); await wait(() => js(`Boolean(document.querySelector(${JSON.stringify(selector)}))`), id+' modal'); await closeModal();
    }
    checks.globalMenuCommands = true;
    command('code'); await wait(() => js("document.getElementById('tabpill_code')?.getAttribute('aria-selected')==='true' || document.getElementById('panel_code')?.classList.contains('ig-panel-active')"), 'code view');
    command('flow'); checks.workspaceMenuViews = true;
    const exported = path.join(state,'diagnostic-export.log');
    dialog.showSaveDialog = async () => ({ canceled: false, filePath: exported });
    await saveDiagnosticLog();
    const contents = fs.readFileSync(exported,'utf8');
    for (const event of ['desktop.start','runtime.manifest','r.spawn','r.http.ready','workspace.connected','project.command.complete','diagnostics.export']) assert.ok(contents.includes(event), 'Missing diagnostic event: '+event);
    assert.match(contents,/\[R startup\]/); assert.match(contents,/"r_version"/);
    checks.diagnosticExport = true;
    assert.ok(!contents.includes('ELECTRON_RUN_AS_NODE='));
    await js("console.error('Desktop diagnostic smoke marker')");
    await wait(() => fs.readFileSync(logPath,'utf8').includes('Desktop diagnostic smoke marker'), 'renderer errors logged');
    checks.rendererDiagnostics = true;
    await pause(300);
    fs.writeFileSync(path.join(state,'native-menus.png'),(await window.webContents.capturePage()).toPNG());
    return { ok:true, checks, projectFiles:[first,second], exportedDiagnostics:exported };
  } finally { dialog.showSaveDialog = originalSave; dialog.showOpenDialog = originalOpen; dialog.showMessageBox = originalMessage; }
};
