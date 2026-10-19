'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { dialog, Menu } = require('electron');
module.exports = async ({ window, pause, getProcess, getState, requestRestart, getURL }) => {
  const checks = {}, pids = [];
  const js = source => window.webContents.executeJavaScript(source, true);
  async function wait(predicate, label) {
    const end = Date.now() + 60000;
    while (Date.now() < end) {
      if (await predicate()) return;
      await pause(100);
    }
    throw new Error(`Restart test timed out: ${label}`);
  }
  const connected = () => wait(() => js("Boolean(window.Shiny?.shinyapp?.$socket?.readyState===1 && document.querySelector('.shiny-bound-input'))"), 'connected workspace');
  const dead = child => child.exitCode !== null || Boolean(child.signalCode);
  await connected();
  assert.ok(Menu.getApplicationMenu().getMenuItemById('restart-r').enabled);
  assert.equal(await js("typeof require === 'undefined' && typeof process === 'undefined' && !window.ipcRenderer"), true);
  checks.desktopControlSandbox = true;
  // Drop only the websocket while leaving R alive. The desktop control must
  // remain usable when Shiny itself cannot handle a click.
  const originalDialog = dialog.showMessageBox;
  try {
    await js('Shiny.shinyapp.$socket.close()');
    await wait(() => js("Boolean(document.getElementById('shiny-disconnected-overlay') && !document.getElementById('ig-desktop-recovery').hidden)"), 'disconnection control');
    const initial = getProcess(); pids.push(initial.pid);
    dialog.showMessageBox = async () => ({ response: 0 });
    assert.equal(await requestRestart(), false);
    assert.equal(getProcess(), initial); assert.equal(dead(initial), false);
    checks.cancelPreservesServer = true;
    dialog.showMessageBox = async () => ({ response: 1 });
    await js("document.getElementById('ig-restart-r').click()");
    await wait(() => getProcess() !== initial && getState().phase === 'ready', 'manual restart');
    await connected(); assert.ok(dead(initial));
    checks.disconnectedRestart = true;
    // Abrupt process termination must preserve the shell and offer recovery.
    const crashed = getProcess(); pids.push(crashed.pid); crashed.kill();
    await wait(() => getState().phase === 'stopped' && js("Boolean(document.getElementById('ig-restart-r') && !document.getElementById('ig-desktop-recovery').hidden)"), 'crash recovery');
    checks.shellSurvivesCrash = !window.isDestroyed();
    await pause(350); // Let the newly navigated recovery page paint before capture.
    const resultArg = process.argv.find(x => x.startsWith('--smoke-result='));
    if (resultArg) fs.writeFileSync(path.join(path.dirname(resultArg.slice('--smoke-result='.length)), 'recovery.png'), (await window.webContents.capturePage()).toPNG());
    // A broken runtime should leave a retry control, then recover when fixed.
    const failedAttempt = requestRestart();
    await wait(() => getProcess() !== crashed, 'new server starting');
    const failedChild = getProcess(); pids.push(failedChild.pid); failedChild.kill();
    assert.equal(await failedAttempt, false);
    assert.equal(getState().phase, 'stopped');
    checks.failedRestartCanRetry = true;
    const oldURL = getURL();
    await js("document.getElementById('ig-restart-r').click();document.getElementById('ig-restart-r').click()");
    await wait(() => getState().phase === 'ready', 'crash restart');
    await connected();
    assert.notEqual(getProcess().pid, crashed.pid); assert.notEqual(getURL(), oldURL);
    assert.ok(dead(crashed)); checks.crashRestart = true;
    const current = getProcess(); pids.push(current.pid);
    const before = pids.length;
    // Launching a second restart during confirmation must be ignored.
    let release;
    dialog.showMessageBox = () => new Promise(resolve => { release = resolve; });
    const pending = requestRestart();
    assert.equal(await requestRestart(), false);
    release({ response: 0 }); assert.equal(await pending, false);
    assert.equal(getProcess(), current); assert.equal(pids.length, before);
    checks.repeatedRestartSerialized = true;
    // Exercise graceful replacement with the stop sentinel, then execute a
    // real R expression through a new Shiny session.
    dialog.showMessageBox = async () => ({ response: 1 });
    assert.equal(await requestRestart(), true); await connected();
    assert.ok(dead(current)); checks.gracefulRestart = true;
    await js("document.getElementById('splash_fresh')?.click()");
    await wait(() => js("document.querySelector('.modal-backdrop') === null"), 'workspace after restart');
    await js("document.getElementById('btn_add_task').click()");
    await wait(() => js("Boolean(document.querySelector('[onclick*=\"picker_select\"][onclick*=\"script\"]'))"), 'script picker');
    await js("document.querySelector('[onclick*=\"picker_select\"][onclick*=\"script\"]').click()");
    await wait(() => js("Boolean(document.getElementById('panel_script_1')?.dataset.igReadyToken && document.getElementById('scr_script_1-output_name')?.classList.contains('shiny-bound-input'))"), 'script panel');
    await js(`(() => {
      for (const [id,value] of [['scr_script_1-output_name','restart_result'],['scr_script_1-output_defs','restart_result: table']]) {
        const element=document.getElementById(id);element.value=value;element.dispatchEvent(new Event('change',{bubbles:true}));
      }
      ace.edit('scr_script_1-code').setValue('restart_result <- data.frame(value = 21 * 2)',-1);
    })()`);
    await pause(600);
    await js("document.getElementById('panel_run_btn_script_1').click()");
    await wait(() => js("Boolean(document.querySelector('#panel_status_script_1 .ig-status-success'))"), 'R task after restart');
    checks.taskExecutesAfterRestart = true;
    pids.push(getProcess().pid);
    checks.workspaceAfterRestart = true;
    return { ok: true, checks, rPids: pids };
  } finally { dialog.showMessageBox = originalDialog; }
};
