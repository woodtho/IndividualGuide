'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path');
const { Menu, dialog } = require('electron');
module.exports = async ({ window, pause, state, rendererCommand }) => {
  const checks = {}, js = source => window.webContents.executeJavaScript(source,true);
  const menu = id => Menu.getApplicationMenu().getMenuItemById(id);
  async function wait(test,label) {
    const deadline=Date.now()+60000;
    while(Date.now()<deadline) { if(await test()) return; await pause(75); }
    const details=await js("({connected:Shiny.shinyapp.$socket?.readyState,modals:Array.from(document.querySelectorAll('.modal')).map(e=>({id:e.id,classes:e.className,display:getComputedStyle(e).display})),console:document.getElementById('r_console-transcript')?.textContent,status:document.getElementById('r_console-status')?.textContent})");
    fs.writeFileSync(path.join(state,'failure-dom.json'),JSON.stringify(details,null,2));
    fs.writeFileSync(path.join(state,'failure.png'),(await window.webContents.capturePage()).toPNG());
    throw new Error('Examples test timed out: '+label+'; '+JSON.stringify(details));
  }
  const click = id => js(`document.getElementById(${JSON.stringify(id)}).click()`);
  const idle = () => wait(()=>menu('save').enabled,'idle workspace');
  async function help() {
    await idle(); menu('help').click();
    await wait(()=>js("Boolean(document.getElementById('help_example_iris'))"),'Help example cards');
    await js("document.querySelector('[data-value=\"examples\"]').click()");
    await wait(()=>js("document.getElementById('help_example_iris').getClientRects().length>0"),'Examples tab');
    assert.equal(await js("document.querySelector('.modal.show .modal-footer').getBoundingClientRect().bottom<=innerHeight"),true);
  }
  const originalMessage=dialog.showMessageBox, originalSave=dialog.showSaveDialog;
  try {
    dialog.showMessageBox=async()=>({response:1});
    await wait(()=>menu('open').enabled && js("Boolean(document.getElementById('splash_fresh')?.classList.contains('shiny-bound-input'))"),'startup');
    await click('splash_fresh'); await help();
    assert.equal(await js("document.querySelectorAll('[data-ig-example]').length"),3); checks.helpCatalog=true;
    await click('help_example_iris'); await idle();
    assert.ok(window.getTitle().includes('Iris exploration')); checks.loadFromHelp=true;
    await js("Shiny.setInputValue('tree_task_click','example_source',{priority:'event'})");
    await wait(()=>js("Boolean(document.getElementById('panel_example_source')?.dataset.igReadyToken)"),'source panel');
    assert.match(await js("ace.edit('scr_example_source-code').getValue()"), /datasets::iris/);
    await help();
    dialog.showMessageBox=async()=>({response:0});
    await click('help_example_air-quality');
    await wait(()=>js("!document.querySelector('.ig-desktop-menu-controls') || Boolean(document.getElementById('help_example_iris'))"),'cancelled replacement');
    await pause(300); assert.ok(window.getTitle().includes('Iris exploration')); checks.cancelPreservesExample=true;
    // Save must use the real native picker, never the installed example path.
    const saved=path.join(state,'My iris example.igpx');
    dialog.showMessageBox=async()=>({response:2}); dialog.showSaveDialog=async()=>({canceled:false,filePath:saved});
    await click('help_example_air-quality'); await idle();
    assert.ok(fs.existsSync(saved)); assert.ok(window.getTitle().includes('Air quality')); checks.saveBeforeReplacement=true;
    dialog.showMessageBox=async()=>({response:1});
    const directories=[];
    for (const [id,title,rows] of [['air-quality','Air quality',153],['fuel-economy','Fuel economy',32],['iris','Iris',150]]) {
      if(id!=='air-quality') { await help(); await click('help_example_'+id); await idle(); }
      assert.ok(window.getTitle().includes(title));
      const source=id==='iris'?'flowers':id==='air-quality'?'air_raw':'cars';
      menu('console').click();
      await wait(()=>js("document.getElementById('panel_console').classList.contains('ig-panel-active') && !document.getElementById('r_console-run').disabled"),'console');
      const command=`cat('EXAMPLE_ROWS=',nrow(${source}),sep='')`;
      await js(`document.getElementById('r_console-editor').value=${JSON.stringify(command)}; document.getElementById('r_console-run').click()`);
      await wait(()=>js(`document.getElementById('r_console-transcript').textContent.includes('EXAMPLE_ROWS=${rows}') && document.querySelector('.ig-console').dataset.busy==='false'`),'real project rows');
      const oldPlot=await js("document.querySelector('#object_preview_ggplot img')?.src || ''");
      await js("Shiny.setInputValue('tree_object_click','chart_data_image',{priority:'event'})");
      await wait(()=>js(`(() => { const img=document.querySelector('.modal.show #object_preview_ggplot img'); return Boolean(img?.naturalWidth && img.src!==${JSON.stringify(oldPlot)}); })()`),'saved chart renders');
      await wait(()=>js("Boolean(document.querySelector('.modal.show [data-dismiss=\"modal\"],.modal.show [data-bs-dismiss=\"modal\"]'))"),'preview close button');
      await wait(()=>js("(() => { const el=document.querySelector('.modal.show'); const modal=window.bootstrap?.Modal?.getInstance(el) || jQuery(el).data('bs.modal'); return modal && !modal._isTransitioning; })()"),'preview opening animation');
      await js("document.querySelector('.modal.show [data-dismiss=\"modal\"],.modal.show [data-bs-dismiss=\"modal\"]').click()");
      await idle(); checks.savedChartsRender=true;
      await js("Shiny.setInputValue('tree_task_click','example_log',{priority:'event'})");
      await wait(()=>js("Boolean(document.getElementById('panel_example_log')?.dataset.igReadyToken && document.getElementById('elog_example_log-path')?.classList.contains('shiny-bound-input'))"),'log task');
      const destination=await js("document.getElementById('elog_example_log-path').value");
      assert.ok(fs.existsSync(destination)); assert.ok(fs.statSync(destination).size>0); directories.push(path.dirname(destination));
      await idle(); menu('run').click();
      await wait(()=>js("window.igRunState?.outcome==='finished' && window.igRunState.completed===window.igRunState.total && !window.igRunState.running"),'rerun '+id);
      assert.equal(await js("Boolean(document.querySelector('.ig-tab-dot-error,.ig-status-error'))"),false);
      assert.ok(fs.statSync(destination).size>0); checks[id+'DataLogsAndRerun']=true;
    }
    assert.equal(new Set(directories).size,3); checks.separateWritableOutputs=true;
    assert.ok(directories.every(dir=>path.resolve(dir).startsWith(path.resolve(state,'examples')+path.sep)));
    // A saved user copy restores both data and all report artifacts.
    assert.equal(await rendererCommand('open',saved),true); await idle();
    assert.ok(window.getTitle().includes('My iris example')); checks.reopenSavedCopy=true;
    await help();
    fs.writeFileSync(path.join(state,'examples.png'),(await window.webContents.capturePage()).toPNG());
    return {ok:true,checks,outputDirectories:directories,savedProject:saved};
  } finally { dialog.showMessageBox=originalMessage; dialog.showSaveDialog=originalSave; }
};
