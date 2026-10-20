/* Desktop menu adapter. The hosted Shiny app keeps its ordinary controls. */
(function () {
  'use strict';
  var desktop = window.igDesktop;
  if (!desktop) return;
  document.documentElement.classList.add('ig-desktop');
  var project = { name: 'Untitled', path: '', running: false, startupReady: false, recoveryPending: true, welcome: true }, pending = false, serial = 0, snapshot = '', requests = new Map();
  var appHost = {visible:false,running:false,name:''};
  function connected() { return window.Shiny?.shinyapp?.$socket?.readyState === 1; }
  function publish() {
    var value = { connected: connected(), dirty: !!window._igDirty,
      projectName: project.name, projectPath: project.path, running: !!project.running,
      appHost:appHost.visible, appHostRunning:appHost.running, hostName:appHost.name,
      canRun: !!project.canRun, recovery: project.recoveryPending === true, startupReady: project.startupReady === true,
      canUndo: !!document.getElementById('btn_undo') && !document.getElementById('btn_undo').disabled,
      pending: pending, modal: !!document.querySelector('.modal.show'), welcome: project.welcome === true,
      welcomeVisible: !!document.querySelector('.modal.show #splash_fresh'),
      comments: document.querySelector('#btn_comments .ig-header-badge')?.textContent || '',
      review: document.querySelector('#btn_review .ig-header-badge')?.textContent || '' };
    var next = JSON.stringify(value);
    if (next !== snapshot) { snapshot = next; desktop.publishState(value); }
  }
  function flush() {
    if (typeof window.igFlushEditors === 'function') window.igFlushEditors();
    var active = document.activeElement;
    if (active?.matches('input,textarea,select')) active.dispatchEvent(new Event('change', { bubbles: true }));
  }
  function dismissModal() {
    var modal = document.querySelector('.modal.show');
    if (modal && window.jQuery) window.jQuery(modal).modal('hide');
  }
  function request(action, path) {
    return new Promise(function (resolve, reject) {
      var id = String(++serial);
      var timer = setTimeout(function () { requests.delete(id); reject(new Error('R did not respond to the project command.')); }, 60000);
      requests.set(id, function (result) { clearTimeout(timer); resolve(result); });
      Shiny.setInputValue('desktop_file_command', { id: id, action: action, path: path || '' }, { priority: 'event' });
    });
  }
  async function fileCommand(action, suppliedPath) {
    if (pending || !connected()) return { ok: false };
    if (['new','close','open','example'].includes(action) && project.recoveryPending) return { ok: false };
    flush(); pending = true; publish();
    try {
      // Ask R after flushing edits: its current path/dirty state is authoritative.
      var prepared = await request('prepare');
      if (!prepared.ok || !connected()) return { ok: false };
      if (prepared.recoveryPending && action !== 'exit') return { ok: false };
      if (prepared.running && ['new','close','open','example'].includes(action)) return { ok: false };
      if (['new','close','open','example','exit'].includes(action) && (prepared.dirty || (action === 'exit' && prepared.running))) {
        var choice = await desktop.confirmChanges(action === 'example' ? 'open' : action);
        if (choice === 'cancel' || !connected()) return { ok: false };
        if (choice === 'save') {
          var savePath = prepared.path || await desktop.chooseProjectFile('save', prepared.name, false);
          if (!savePath || !connected()) return { ok: false };
          var saved = await request('save', savePath);
          if (!saved.ok) return { ok: false };
          desktop.projectUsed(saved.path || savePath);
          flush();
          var afterSave = await request('prepare');
          if (!afterSave.ok || afterSave.dirty) return { ok: false };
        }
      }
      if (action === 'exit') {
        if (choice === 'discard') {
          if (prepared.running) Shiny.setInputValue('stop_run', Date.now(), { priority: 'event' });
          // Retire modules and recovery data without displaying a welcome modal.
          return await request('new');
        }
        return { ok: true };
      }
      if (action === 'new' || action === 'close') {
        dismissModal(); return await request(action);
      }
      if (action === 'example') {
        dismissModal(); return await request('example', suppliedPath);
      }
      var filename = action === 'save' ? prepared.path : '';
      if (action === 'open' && suppliedPath) filename = suppliedPath;
      if ((action === 'open' && !suppliedPath) || action === 'save-as' || !filename) {
        filename = await desktop.chooseProjectFile(action === 'open' ? 'open' : 'save', prepared.path || prepared.name, prepared.dirty);
        if (!filename || !connected()) return { ok: false };
      }
      dismissModal();
      var result = await request(action === 'open' ? 'open' : 'save', filename);
      if (result.ok) desktop.projectUsed(action === 'open' ? filename : result.path || filename);
      desktop.report('project.command.complete', { action: action, ok: result.ok });
      return result;
    } catch (error) {
      desktop.report('command.error', { action: action, message: String(error.message).slice(0, 500) });
      return { ok: false };
    } finally { pending = false; publish(); }
  }
  desktop.onCommand(async function (command) {
    var action = typeof command === 'string' ? command : command.action;
    if (!connected()) { if (command.id) desktop.commandResult({ id: command.id, ok: false }); return; }
    if (['open','save','save-as','new','close','exit'].includes(action)) {
      var result = await fileCommand(action, command.path);
      if (command.id) desktop.commandResult({ id: command.id, ok: result?.ok === true });
      return;
    }
    if (action === 'stop') { document.getElementById('ig-stop-run')?.click(); return; }
    if (action === 'shiny-apps') { window.igShinyApps?.open(); return; }
    if (action === 'workspace') { window.igShinyApps?.back(); return; }
    if (action === 'close-shiny-app') { window.igShinyApps?.close(); return; }
    if (action === 'run') { flush(); Shiny.setInputValue('shortcut_run_flow', Date.now(), { priority: 'event' }); return; }
    if (['versions','files','runs','tasks','validate'].includes(action)) {
      flush(); Shiny.setInputValue('product_action', action, { priority: 'event' }); return;
    }
    flush();
    var buttons = { undo: 'btn_undo', search: 'btn_search', history: 'btn_history', settings: 'btn_settings',
      help: 'btn_help', shortcuts: 'btn_shortcuts', comments: 'btn_comments', review: 'btn_review', 'add-task': 'btn_add_task' };
    if (['flow','code','console'].includes(action)) Shiny.setInputValue('shortcut_open_tab', action, { priority: 'event' });
    else document.getElementById(buttons[action])?.click();
  });
  window.addEventListener('DOMContentLoaded', function () {
    Shiny.addCustomMessageHandler('ig_desktop_project', function (value) { project = value; publish(); });
    Shiny.addCustomMessageHandler('ig_desktop_result', function (result) {
      if (result.project) project = result.project;
      if (typeof result.dirty === 'boolean') window._igDirty = result.dirty;
      var complete = requests.get(result.id);
      if (complete) { requests.delete(result.id); complete(result); }
    });
    // Existing keyboard shortcuts and welcome-screen Open use the native picker too.
    document.addEventListener('click', function (event) {
      var example = event.target.closest?.('[data-ig-example]');
      if (example) {
        event.preventDefault(); event.stopImmediatePropagation();
        fileCommand('example', example.dataset.igExample); return;
      }
      var button = event.target.closest?.('#btn_save,#btn_open,#sf_open,#sf_save_as,#splash_open');
      if (!button) return;
      event.preventDefault(); event.stopImmediatePropagation();
      fileCommand(['btn_open','sf_open','splash_open'].includes(button.id) ? 'open' : button.id === 'sf_save_as' ? 'save-as' : 'save');
    }, true);
    window.jQuery(document).on('shiny:connected shiny:disconnected', function (event) {
      if (event.type === 'shiny:disconnected') {
        requests.forEach(function (complete) { complete({ ok: false, disconnected: true }); }); requests.clear();
      }
      pending = false; publish();
    });
    window.jQuery(document).on('shown.bs.modal hidden.bs.modal', publish);
    // Observe only the small header, not task inputs or the whole document.
    var header = document.querySelector('.ig-desktop-menu-controls');
    if (header) new MutationObserver(publish).observe(header, { childList: true, subtree: true, attributes: true, attributeFilter: ['disabled','class'] });
    window.addEventListener('ig:dirty', publish);
    window.addEventListener('ig:app-host', function(event) { appHost=event.detail;publish(); });
    window.addEventListener('ig:app-frame-retired', event => {
      desktop.releaseShinyApp(event.detail.url).catch(error=>console.warn(error));
    });
    window.addEventListener('ig:run-state', function (event) { project.running = event.detail.running; publish(); });
    publish();
  });
})();
