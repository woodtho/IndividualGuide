'use strict';
// Development-only integration extension; the packaged menu smoke stays fixed.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFile } = require('node:child_process');
const { Menu, dialog } = require('electron');
const target = require.resolve('./menu-smoke.cjs');
const base = require(target);
require.cache[target].exports = async options => {
  const evidence = await base(options);
  const { window, pause } = options;
  const checks = evidence.checks;
  const js = source => window.webContents.executeJavaScript(source,true);
  const menu = id => Menu.getApplicationMenu().getMenuItemById(id);
  const command = id => { assert.ok(menu(id).enabled); menu(id).click(); };
  async function wait(predicate,label) {
    const deadline=Date.now()+60000;
    while(Date.now()<deadline){if(await predicate())return;await pause(100);}
    throw new Error('Extra menu check timed out: '+label);
  }
    await js("Shiny.setInputValue('tree_delete_task','script_1',{priority:'event'})");
    await wait(() => js("Boolean(document.getElementById('delete_task_confirm'))"), 'delete confirmation');
    await js("document.getElementById('delete_task_confirm').click()");
    await wait(() => menu('undo').enabled, 'native project Undo enabled');
    command('undo');
    await wait(() => !menu('undo').enabled && js("Boolean(document.querySelector('[onclick*=\"tree_task_click\"][onclick*=\"script_1\"]'))"), 'native Undo restores task');
    checks.nativeProjectUndo = true;

  const legacy = path.join(options.state,'Legacy project.igp');
  const rHome=path.join(process.env.IG_RUNTIME_OVERRIDE,'R');
  await new Promise((resolve,reject) => execFile(path.join(rHome,'bin/x64/Rscript.exe'),
    ['--vanilla','-e','saveRDS(list(tasks=list(),task_order=character(),tables=list(),sources=list()),commandArgs(TRUE)[1])',legacy],
    { windowsHide:true, env:{...process.env,R_HOME:rHome,LC_ALL:'English_Canada.utf8',LANG:'English_Canada.utf8'} },
    error => error ? reject(error) : resolve()));
  const saved = fs.readFileSync(legacy);
  const originalOpen = dialog.showOpenDialog, originalMessage = dialog.showMessageBox, originalSave=dialog.showSaveDialog;
  try {
    dialog.showOpenDialog = async () => ({ canceled:false, filePaths:[legacy] });
    dialog.showMessageBox = async () => ({ response:1 });
    command('open');
    await wait(() => menu('save').enabled && window.getTitle().includes('Legacy project'),'legacy project opened');
    const converted=path.join(options.state,'Converted project.igpx');
    let saves=0;
    dialog.showSaveDialog=async()=>{saves++;return { canceled:false,filePath:converted };};
    command('save');
    await wait(() => saves===1 && fs.existsSync(converted) && menu('save').enabled && !window.getTitle().endsWith('*'),'legacy migration Save As');
    assert.ok(fs.readFileSync(legacy).equals(saved));
    assert.equal(fs.existsSync(legacy+'.igpx'),false);
    checks.legacySaveAsPreservesOriginal = true;
  } finally { dialog.showOpenDialog=originalOpen; dialog.showMessageBox=originalMessage; dialog.showSaveDialog=originalSave; }
  return evidence;
};
require('./main.cjs');
