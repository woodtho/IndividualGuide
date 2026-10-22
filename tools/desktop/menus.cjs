'use strict';
const { Menu } = require('electron');
module.exports = function desktopMenus({ command, restart, openLog, openLogs, saveLog, close, about, preferences, openProject, pinProject, unpinProject, clearRecent, translate = value=>value, setLanguage = ()=>{} }) {
  const roles = {undo:'Undo',redo:'Redo',cut:'Cut',copy:'Copy',paste:'Paste',selectAll:'Select all',resetZoom:'Actual Size',zoomIn:'Zoom In',zoomOut:'Zoom Out',togglefullscreen:'Toggle Full Screen'};
  const localize = entry => ({...entry,
    ...(entry.label || roles[entry.role] ? {label:translate(entry.label || roles[entry.role])} : {}),
    ...(entry.submenu ? {submenu:entry.submenu.map(localize)} : {})});
  const item = (id, label, accelerator) => ({ id, label, accelerator, enabled: false, click: () => command(id) });
  let recentSnapshot;
  function install() {
  const recent = preferences.recent;
  recentSnapshot = JSON.stringify([recent,preferences.language]);
  const recentItems = [...recent.filter(x => x.pinned), ...recent.filter(x => !x.pinned)].map((entry, index) => ({
    id: 'recent-' + index, label: (entry.pinned ? '★ ' : '') + entry.path.replace(/&/g, '&&'), enabled: false,
    click: () => openProject(entry.path)
  }));
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    { label: 'File', submenu: [item('new','New project','CmdOrCtrl+N'), item('open','Open project...','CmdOrCtrl+O'),
      { id: 'recent-projects', label: 'Recent projects', submenu: recentItems.length ? recentItems : [{ label: 'No recent projects', enabled: false }] },
      { id: 'pin-project', label: 'Pin current project', enabled: false, click: pinProject },
      { label:'Unpin a project', submenu: recent.some(x=>x.pinned) ? recent.filter(x=>x.pinned).map((entry,index)=>({
        id:'unpin-recent-'+index, label:entry.path.replace(/&/g,'&&'), click:()=>unpinProject(entry.path)
      })) : [{label:'No pinned projects',enabled:false}] },
      { label: 'Clear unpinned recent projects', click: clearRecent },
      item('close-project','Close project','CmdOrCtrl+W'), { type:'separator' }, item('save','Save project','CmdOrCtrl+S'),
      item('save-as','Save project as...','CmdOrCtrl+Shift+S'), { type: 'separator' },
      item('versions','Saved project versions...'), item('files','Project files and portability...'), { type: 'separator' },
      item('settings','Settings...'), { type: 'separator' }, { label: 'Close Individual Guide', click: close }] },
    { label: 'Edit', submenu: [{ role: 'undo' }, { role: 'redo' }, { type: 'separator' },
      { role: 'cut' }, { role: 'copy' }, { role: 'paste' }, { role: 'selectAll' }, { type: 'separator' },
      item('undo','Undo project change','CmdOrCtrl+Alt+Z'), item('search','Search project...','CmdOrCtrl+Shift+F')] },
    { label: 'View', submenu: [{id:'workspace',label:'Individual Guide workspace',accelerator:'CmdOrCtrl+Alt+I',click:()=>command('workspace')},
      item('flow','Process flow','CmdOrCtrl+Alt+F'), item('code','Generated R code','CmdOrCtrl+Alt+K'),
      item('console','R console','CmdOrCtrl+Alt+C'),
      item('tasks','Task list','CmdOrCtrl+Alt+L'),
      item('history','Change history...'), item('comments','Comments...'), item('review','Review dashboard...'),
      { type: 'separator' }, { role: 'resetZoom' }, { role: 'zoomIn' }, { role: 'zoomOut' },
      { type: 'separator' }, { role: 'togglefullscreen' }] },
    { label: 'Apps', submenu: [item('shiny-apps','Open Shiny app...','CmdOrCtrl+Shift+O'),
      { ...item('running-shiny-app','Return to running app','CmdOrCtrl+Alt+A'), type:'checkbox', checked:false,
        click:entry=>{entry.checked=true;command('running-shiny-app');} },
      { type:'separator' }, { ...item('shiny-app-log','App log'), type:'checkbox', checked:false },
      item('close-shiny-app','Close Shiny app')] },
    { label: 'Task', submenu: [item('add-task','Add task...','CmdOrCtrl+Alt+N'), item('validate','Validate active flow...'), item('runs','Run records...'), { type:'separator' },
      item('run','Run active flow','CmdOrCtrl+Alt+R'), item('stop','Stop run','CmdOrCtrl+Shift+F5')] },
    { label: 'Session', submenu: [{ id: 'restart-r', label: 'Restart R server...', accelerator: 'CmdOrCtrl+Shift+R', enabled: false, click: restart },
      { type: 'separator' }, { label: 'Open startup log', click: openLog },
      { label: 'Open logs folder', click: openLogs }, { label: 'Save diagnostic log...', click: saveLog }] },
    { label: 'Help', submenu: [item('help','Application help','F1'), item('shortcuts','Keyboard shortcuts...'), {type:'separator'}, { id:'about', label:'About Individual Guide...', click:about }] },
    { label:'Language', submenu:[
      {id:'language-en-CA',label:'English',type:'radio',checked:preferences.language !== 'fr-CA',click:()=>setLanguage('en-CA')},
      {id:'language-fr-CA',label:'Français (Canada)',type:'radio',checked:preferences.language === 'fr-CA',click:()=>setLanguage('fr-CA')}
    ]}
  ].map(localize)));
  }
  install();
  return function update(state, backend) {
    if (recentSnapshot !== JSON.stringify([preferences.recent,preferences.language])) install();
    const menu = Menu.getApplicationMenu();
    const ready = state.connected && state.startupReady && backend.phase === 'ready' && !state.pending;
    for (const id of ['new','close-project','open','save','save-as','settings','undo','search','flow','code','console','tasks','versions','files','runs','validate','history','comments','review','add-task','help','shortcuts','run','stop']) {
      let enabled = ready && !state.modal && !state.welcome && !state.appHost;
      if (['new','close-project','open'].includes(id)) enabled = ready && (!state.modal || state.welcome) && (!state.welcome || state.welcomeVisible) && !state.recovery && !state.running && !state.appHost;
      if (id === 'run') enabled = enabled && !state.running && state.canRun;
      if (id === 'stop') enabled = state.connected && backend.phase === 'ready' && state.running;
      if (id === 'undo') enabled = enabled && state.canUndo && !state.running;
      menu.getMenuItemById(id).enabled = Boolean(enabled);
    }
    menu.getMenuItemById('shiny-apps').enabled = Boolean(ready && (!state.modal || state.welcome) && !state.recovery);
    const runningApp = menu.getMenuItemById('running-shiny-app');
    runningApp.enabled = Boolean(ready && state.appHostRunning && (!state.modal || state.welcome));
    runningApp.checked = Boolean(state.appHost && state.appHostRunning);
    runningApp.label = translate('Return to running app') + (state.appHostRunning && state.hostName ? ' — ' + state.hostName.slice(0,80).replace(/&/g,'&&') : '');
    menu.getMenuItemById('shiny-app-log').enabled = Boolean(ready && !state.recovery && (!state.modal || state.welcome));
    menu.getMenuItemById('shiny-app-log').checked = Boolean(state.appHost && state.appHostLog);
    menu.getMenuItemById('close-shiny-app').enabled = Boolean(ready && state.appHostRunning);
    const canOpen = ready && (!state.modal || state.welcome) && (!state.welcome || state.welcomeVisible) && !state.recovery && !state.running && !state.appHost;
    for (let i = 0; i < preferences.recent.length; i++) menu.getMenuItemById('recent-' + i).enabled = Boolean(canOpen);
    const pinned = preferences.recent.some(item => item.path.toLowerCase() === state.projectPath?.toLowerCase() && item.pinned);
    menu.getMenuItemById('pin-project').enabled = Boolean(ready && state.projectPath && (pinned || preferences.recent.filter(x=>x.pinned).length < 10));
    menu.getMenuItemById('pin-project').label = translate(pinned ? 'Unpin current project' : 'Pin current project');
    menu.getMenuItemById('save').label = translate(state.dirty ? 'Save project *' : 'Save project');
    for (const id of ['comments','review']) {
      const count = /^\d{1,4}$/.test(state[id] || '') ? ` (${state[id]})` : '';
      menu.getMenuItemById(id).label = translate((id === 'comments' ? 'Comments' : 'Review dashboard') + count + '...');
    }
    menu.getMenuItemById('restart-r').enabled = backend.phase !== 'starting';
  };
};
