'use strict';
// The sandbox exposes only fixed desktop operations, never Node or arbitrary IPC.
const { ipcRenderer, contextBridge } = require('electron');
contextBridge.exposeInMainWorld('igDesktop', {
  getLanguage: () => ipcRenderer.invoke('ig:language'),
  setLanguage: locale => ipcRenderer.invoke('ig:set-language', locale),
  onLanguage: callback => { ipcRenderer.on('ig:language', (_event, value) => callback({locale:value.locale})); },
  publishState: value => ipcRenderer.send('ig:workspace-state', value),
  chooseProjectFile: (kind, defaultPath, dirty) => ipcRenderer.invoke('ig:project-dialog', { kind, defaultPath, dirty }),
  confirmChanges: action => ipcRenderer.invoke('ig:confirm-changes', action),
  commandResult: value => ipcRenderer.send('ig:command-result', value),
  projectUsed: file => ipcRenderer.send('ig:project-used', file),
  report: (event, details) => ipcRenderer.send('ig:renderer-event', { event, details }),
  onCommand: callback => { ipcRenderer.on('ig:command', (_event, command) => callback(command)); }
});
let state, language = {locale:'en-CA',strings:{}};
const translate = value => typeof value === 'string' && language.locale === 'fr-CA' ? language.strings[value.trim()] || value : value;
ipcRenderer.on('ig:language', (_event, value) => {language=value;render();});
ipcRenderer.on('ig:backend-state', (_event, value) => { state = value; render(); });
let panel, message, restart, logButton, title, detail;
function render() {
  if (!panel || !state) return;
  document.documentElement.lang=language.locale;
  panel.setAttribute('aria-label',translate('R server recovery'));
  title.textContent=translate('Reconnect your workspace');
  detail.textContent=translate('Restarting stops running tasks. Unsaved changes may be lost. You can reopen a saved project or restore the latest available autosave after restarting.');
  restart.textContent=translate('Restart R server');
  logButton.textContent=translate('Open startup log');
  const disconnected = Boolean(document.getElementById('shiny-disconnected-overlay'));
  const loading = document.body.dataset.desktopLoading === 'true';
  const show = state.phase === 'stopped' || (disconnected && state.phase === 'ready');
  panel.hidden = !show;
  message.textContent = state.phase === 'stopped' ? state.localizedMessage || translate(state.message) : translate('The workspace lost its connection to R.');
  restart.disabled = state.phase === 'starting';
  if (loading) {
    document.getElementById('desktop-status').textContent = state.phase === 'starting' ? state.localizedMessage || translate(state.message) : translate('The R server is unavailable.');
    document.querySelector('.spinner').setAttribute('aria-label',translate('Starting'));
    document.querySelector('.spinner').hidden = state.phase !== 'starting';
  }
}
window.addEventListener('DOMContentLoaded', async () => {
  const style = document.createElement('style');
  style.textContent = '#ig-desktop-recovery[hidden]{display:none!important}#ig-desktop-recovery{position:fixed;z-index:2147483647;left:50%;top:50%;transform:translate(-50%,-50%);width:min(520px,85vw);box-sizing:border-box;padding:28px;border:1px solid #596179;border-radius:12px;background:#202537;color:#eef0fa;font:15px/1.6 system-ui,sans-serif;box-shadow:0 8px 50px #0009}#ig-desktop-recovery h2{color:#eef0fa;font-size:21px;margin:0 0 10px}#ig-desktop-recovery p{color:#cbd1e2}#ig-desktop-recovery button{font:inherit;border:1px solid #7783a6;border-radius:6px;padding:9px 14px;margin:8px 10px 0 0;cursor:pointer;background:#4361ee;color:white}#ig-desktop-recovery button+button{background:transparent}#ig-desktop-recovery button:focus-visible{outline:3px solid #aecaff;outline-offset:3px}';
  document.head.append(style);
  panel = document.createElement('section');
  panel.id = 'ig-desktop-recovery'; panel.hidden = true;
  panel.setAttribute('role', 'alert'); panel.setAttribute('aria-label', 'R server recovery');
  title = document.createElement('h2'); title.textContent = 'Reconnect your workspace';
  message = document.createElement('p');
  detail = document.createElement('p');
  detail.textContent = 'Restarting stops running tasks. Unsaved changes may be lost. You can reopen a saved project or restore the latest available autosave after restarting.';
  restart = document.createElement('button'); restart.id = 'ig-restart-r'; restart.type = 'button'; restart.textContent = 'Restart R server';
  logButton = document.createElement('button'); logButton.type = 'button'; logButton.textContent = 'Open startup log';
  restart.addEventListener('click', async () => {
    restart.disabled = true;
    try { await ipcRenderer.invoke('ig:restart-r'); }
    finally { restart.disabled = false; }
  });
  logButton.addEventListener('click', () => ipcRenderer.invoke('ig:open-log'));
  panel.append(title, message, detail, restart, logButton); document.body.append(panel);
  // Shiny adds/removes its overlay on disconnection/reconnection. This does not
  // poll R, reload the workspace, or interrupt a busy but connected server.
  new MutationObserver(records => {
    if (records.some(record => [...record.addedNodes, ...record.removedNodes]
      .some(node => node.id === 'shiny-disconnected-overlay'))) render();
  }).observe(document.body, { childList: true });
  language = await ipcRenderer.invoke('ig:language') || language;
  state = await ipcRenderer.invoke('ig:backend-state'); render();
});
