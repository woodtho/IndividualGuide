'use strict';
const { app, BrowserWindow, Menu, dialog, shell, ipcMain, screen } = require('electron');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const net = require('node:net');
const http = require('node:http');
const crypto = require('node:crypto');
const option = name => process.argv.find(value => value.startsWith(`${name}=`))?.slice(name.length + 1);
const restartTest = process.argv.includes('--smoke-restart');
const startupOnly = process.argv.includes('--smoke-startup');
const lifecycleTest = process.argv.includes('--smoke-lifecycle');
const consoleTest = process.argv.includes('--smoke-console');
const examplesTest = process.argv.includes('--smoke-examples');
const productTest = process.argv.includes('--smoke-product');
const languageTest = process.argv.includes('--smoke-language');
const shinyAppsTest = process.argv.includes('--smoke-shiny-apps');
const smoke = process.argv.includes('--smoke-test') || startupOnly || restartTest || process.argv.includes('--smoke-menus') || lifecycleTest || consoleTest || examplesTest || productTest || languageTest || shinyAppsTest;
const startedAt = Date.now();
const smokeResult = option('--smoke-result');
const menuTest = process.argv.includes('--smoke-menus');
app.setAppUserModelId('ca.individualguide.desktop');
if (option('--data-dir')) app.setPath('userData', path.resolve(option('--data-dir')));
// Acquire the lock before touching the running instance's log or creating work
// directories. Installed launches reuse files on disk; portable launches extract.
const ownsInstance = app.requestSingleInstanceLock();
if (!ownsInstance) app.exit(0);
const state = app.getPath('userData');
const diagnostics = require('./diagnostics.cjs')(path.join(state, 'logs'));
const logPath = diagnostics.file;
const eventLog = diagnostics.write;
const { preferences: loadPreferences, windowBounds, projectArgument, projectPath } = require('./preferences.cjs');
const preferences = loadPreferences(path.join(state, 'desktop-settings.json'), eventLog);
const languageSupport = require('./i18n.cjs');
const installation = languageSupport.installationLanguage(path.dirname(process.execPath));
const localization = languageSupport.create(languageSupport.catalog, languageSupport.initialLanguage(
  {language:preferences.language,installation:preferences.installation}, installation,
  Intl.DateTimeFormat().resolvedOptions().locale, option('--language')));
preferences.saveLanguage(localization.locale, installation?.installation || preferences.installation);
const translate = value => localization.translate(value);
app.commandLine.appendSwitch('lang',localization.locale === 'fr-CA' ? 'fr' : 'en-US');
function localizedDialog(options) {
  return languageSupport.localizedDialog(options,translate);
}
const showMessageBox = (window, options) => dialog.showMessageBox(window,localizedDialog(options));
const showMessageBoxSync = (window, options) => dialog.showMessageBoxSync(window,localizedDialog(options));
const showOpenDialog = (window, options) => dialog.showOpenDialog(window,localizedDialog(options));
const showSaveDialog = (window, options) => dialog.showSaveDialog(window,localizedDialog(options));
function languageState() { return {locale:localization.locale,strings:languageSupport.catalog.strings}; }
function setLanguage(locale) {
  if(!languageSupport.supported.includes(locale))return false;
  localization.setLanguage(locale);
  preferences.saveLanguage(locale,installation?.installation || preferences.installation);
  eventLog('desktop.language',{locale});
  refreshMenus();
  if(window&&!window.isDestroyed())window.webContents.send('ig:language',languageState());
  if(window&&!window.isDestroyed())window.webContents.send('ig:backend-state',{...backendState,localizedMessage:translate(backendState.message)});
  return true;
}
const desktopToken = crypto.randomBytes(32).toString('hex');
const projectTrust = require('./security.cjs')({ file: path.join(state, 'trusted-projects.json'),
  confirm: async file => (await showMessageBox(window, { type: 'warning', title: 'Trust this project?',
    message: 'Open a project from a trusted source?', detail: 'Projects can contain R code and serialized R objects. Opening or running a project can access files and execute code with your Windows permissions.\n\n' + file,
    buttons: ['Cancel', 'Trust and open'], defaultId: 0, cancelId: 0, noLink: true })).response === 1 });
const log = text => eventLog('desktop.message', String(text));
eventLog('desktop.start', { version: app.getVersion(), electron: process.versions.electron, chrome: process.versions.chrome,
  node: process.versions.node, platform: process.platform, arch: process.arch, osRelease: os.release(),
  cpus: os.cpus().length, totalMemoryMiB: Math.round(os.totalmem()/1048576), freeMemoryMiB: Math.round(os.freemem()/1048576),
  pid: process.pid, packaged: app.isPackaged, executable: process.execPath, userData: state,
  launchMode: process.env.PORTABLE_EXECUTABLE_FILE ? 'portable' : app.isPackaged ? 'installed' : 'development' });
let window, rProcess, stopping = false, finished = false, appURL, hostedRenderers;
let smokeEvidence, updateMenu;
let workspace = { connected: false, dirty: false, projectName: 'Untitled', projectPath: '' };
let attempt = 0, attemptStarted = 0, projectDialogOpen = false;
let allowClose = false, closing = false, commandSerial = 0, openingProject = false;
const commandRequests = new Map(), pendingProjects = [];
const initialProject = projectArgument(process.argv);
if (initialProject) pendingProjects.push(initialProject);
function rendererCommand(action, file) {
  if (!workspace.connected || workspace.pending || stopping || !window || window.isDestroyed()) return Promise.resolve(false);
  if (action === 'open' && file) return projectTrust.trust(file).then(ok => ok ? rendererCommand('open-trusted', file) : false);
  if (action === 'open-trusted') action = 'open';
  return new Promise(resolve => {
    const id = String(++commandSerial);
    const timer = setTimeout(() => { commandRequests.delete(id); resolve(false); eventLog('command.timeout', { action }, 'WARN'); }, 70000);
    commandRequests.set(id, ok => { clearTimeout(timer); resolve(ok); });
    window.webContents.send('ig:command', { id, action, path: file || '' });
  });
}
function queueProject(file) {
  if (!projectPath(file)) return;
  if (!pendingProjects.includes(file)) pendingProjects.push(file);
  pumpProjects();
}
async function pumpProjects() {
  if (openingProject || !pendingProjects.length || !workspace.connected || !workspace.startupReady || workspace.pending || workspace.running ||
      (workspace.welcome && !workspace.welcomeVisible) ||
      workspace.recovery || (workspace.modal && !workspace.welcome) || backendState.phase !== 'ready' || stopping) return;
  openingProject = true;
  const file = pendingProjects.shift();
  try {
    if(workspace.appHost) window.webContents.send('ig:command','workspace');
    if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {
      await showMessageBox(window, { type: 'error', title: 'Project unavailable', message: 'This project could not be found.', detail: file });
      return;
    }
    const ok = await rendererCommand('open', file);
    eventLog('project.external.open', { ok });
  } catch (error) { eventLog('project.external.failed',error.message,'WARN'); }
  finally { openingProject = false; if (pendingProjects.length) setTimeout(pumpProjects, 100); }
}
async function requestClose() {
  if (closing || stopping || !window || window.isDestroyed()) return false;
  closing = true;
  try {
    if(workspace.appHostRunning) {
      const answer=await showMessageBox(window,{type:'question',title:'Close the loaded Shiny app?',
        message:'Save any work in the loaded app first. Closing stops its R process.',
        buttons:['Keep open','Close Individual Guide'],defaultId:0,cancelId:0,noLink:true});
      if(answer.response!==1)return false;
    }
    let ok;
    if (workspace.connected) ok = await rendererCommand('exit');
    else if (workspace.dirty) {
      const choice = await showMessageBox(window, { type: 'warning', title: 'R server unavailable',
        message: 'Close without saving?', detail: 'The R server is disconnected, so this workspace cannot save. Keep the window open to use the restart and recovery controls.',
        buttons: ['Keep open','Close without saving'], defaultId: 0, cancelId: 0, noLink: true });
      ok = choice.response === 1;
    } else ok = true;
    if (ok && !window.isDestroyed()) { allowClose = true; window.close(); }
    return ok;
  } finally { closing = false; }
}
function refreshMenus() {
  updateMenu?.(workspace, backendState);
  if (window && !window.isDestroyed()) window.setTitle('Individual Guide' + (workspace.connected ? ' - ' + (workspace.projectName || translate('Untitled')) + (workspace.dirty ? ' *' : '') : backendState.phase === 'stopped' ? ' - '+translate('R server stopped') : ''));
  pumpProjects();
}
let backendState = { phase: 'starting', message: 'Starting your workspace...' };
let restartPromise, leavingForRestart = false;
const expectedStops = new WeakSet();
const loadingFile = path.join(__dirname, 'loading.html');
const runtime = process.env.IG_RUNTIME_OVERRIDE || path.join(process.resourcesPath, 'runtime');
let exitCode = 0;
let secondInstanceCount = 0;
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'individual-guide-'));
const stopFile = path.join(work, 'stop');
const runtimeResult = path.join(work, 'runtime-result.json');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const alive = () => rProcess && rProcess.exitCode === null && !rProcess.signalCode;

function recordSmoke(value) {
  if (!smokeResult) return;
  fs.mkdirSync(path.dirname(path.resolve(smokeResult)), { recursive: true });
  fs.writeFileSync(smokeResult, JSON.stringify(value, null, 2));
}
async function stopR() {
  try { hostedRenderers?.dispose(); }
  catch(error) { eventLog('shiny-app.renderer.cleanup.failed',{message:error.message},'WARN'); }
  const child = rProcess;
  if (!child || child.exitCode !== null || child.signalCode) return;
  expectedStops.add(child);
  eventLog('r.stop.request', { pid: child.pid, attempt });
  fs.writeFileSync(stopFile, 'stop');
  const running = () => child.exitCode === null && !child.signalCode;
  for (let i = 0; i < 30 && running(); i++) await pause(100);
  if (running()) {
    eventLog('r.stop.force', { pid: child.pid }, 'WARN');
    await new Promise(resolve => {
      const killer = spawn(path.join(process.env.SystemRoot, 'System32', 'taskkill.exe'),
        ['/PID', String(child.pid), '/T', '/F'], { windowsHide: true });
      killer.once('exit', resolve); killer.once('error', resolve);
    });
    for (let i = 0; i < 30 && running(); i++) await pause(100);
  }
  if (running()) throw new Error('The previous R server could not be stopped. Try restarting again.');
}
function setBackendState(phase, message) {
  backendState = { phase, message };
  eventLog('backend.state', { phase, message, attempt, elapsedMs: Date.now() - attemptStarted });
  if (phase !== 'ready') workspace.connected = false;
  refreshMenus();
  if (window && !window.isDestroyed()) window.webContents.send('ig:backend-state', {...backendState,localizedMessage:translate(backendState.message)});
  const item = Menu.getApplicationMenu()?.getMenuItemById('restart-r');
  if (item) item.enabled = phase !== 'starting';
}
async function recovery(error) {
  if (stopping || !window || window.isDestroyed()) return;
  eventLog('backend.recovery', error.stack || String(error), 'ERROR');
  // Offer retry only after navigation finishes; an early click could otherwise
  // race this navigation against the next server's loading page.
  setBackendState('starting', 'Preparing server recovery...');
  leavingForRestart = true;
  try { await window.loadFile(loadingFile); }
  finally { leavingForRestart = false; }
  if (!stopping) setBackendState('stopped', error.message);
}
async function requestRestart() {
  if (stopping || restartPromise || backendState.phase === 'starting') { eventLog('restart.ignored', { phase: backendState.phase }); return false; }
  eventLog('restart.request', { rPid: rProcess?.pid, alive: Boolean(alive()), attempt });
  // Serialize the confirmation too so repeated clicks cannot spawn extra servers.
  restartPromise = (async () => {
    if (alive()) {
      const { response } = await showMessageBox(window, { type: 'warning',
        title: 'Restart R server?', message: 'Restart the R server?',
        detail: 'Running tasks will stop and unsaved changes may be lost. Save your project first. After restart you can reopen a saved project or restore the latest available autosave.' +
          (workspace.appHostRunning ? '\n\nRestarting also closes the loaded Shiny app. Save its work first.' : ''),
        buttons: ['Cancel', 'Restart R server'], defaultId: 0, cancelId: 0, noLink: true });
      if (response !== 1 || stopping) { eventLog('restart.cancelled'); return false; }
      eventLog('restart.confirmed');
    }
    return launchR();
  })();
  try { return await restartPromise; } finally { restartPromise = undefined; }
}
async function fail(error) {
  if (stopping) return;
  exitCode = 1;
  eventLog('desktop.fatal', error.stack || String(error), 'ERROR');
  if (smoke) recordSmoke({ ok: false, error: error.message, stack: error.stack,
    checks: error.smokeChecks, startupLog: logPath });
  else await showMessageBox(window, { type: 'error', title: 'Individual Guide could not start',
    message: error.message, detail: `Startup details are saved in:\n${logPath}` });
  app.quit();
}
function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer(); server.once('error', reject);
    server.listen(0, '127.0.0.1', () => { const port = server.address().port; server.close(() => resolve(port)); });
  });
}
function responds(url) {
  return new Promise(resolve => {
    const request = http.get(url, response => { response.resume(); resolve(response.statusCode === 200); });
    request.setTimeout(2000, () => request.destroy()); request.once('error', () => resolve(false));
  });
}
function permitted(url) {
  try { return new URL(url).origin === new URL(appURL).origin; } catch { return false; }
}
function sendCommand(command) {
  const item = Menu.getApplicationMenu()?.getMenuItemById(command);
  if (!item?.enabled || !workspace.connected || stopping) return;
  eventLog('menu.command', { command });
  if (['new','close-project','open','save','save-as'].includes(command)) {
    rendererCommand(command === 'close-project' ? 'close' : command).catch(error => log(error.message));
  } else window.webContents.send('ig:command', command);
}
async function openLocal(file) {
  const error = await shell.openPath(file);
  if (error) eventLog('desktop.open.failed', { error }, 'ERROR');
}
async function chooseProjectFile(request) {
  if (projectDialogOpen || stopping || !workspace.connected || backendState.phase !== 'ready' ||
      !request || !['open','save'].includes(request.kind) || typeof request.defaultPath !== 'string' || request.defaultPath.length > 4096) return '';
  projectDialogOpen = true;
  try {
    const defaults = request.defaultPath || 'project';
    const defaultPath = path.isAbsolute(defaults) ? defaults : path.join(app.getPath('documents'), path.basename(defaults).replace(/[<>:"/\\|?*\x00-\x1f]/g,'_').replace(/[. ]+$/, '') || 'project');
    if (request.kind === 'open') {
      const result = await showOpenDialog(window, { title: 'Open Individual Guide project',
        defaultPath, filters: [{ name: 'Individual Guide projects', extensions: ['igpx','igp','rds'] }], properties: ['openFile'] });
      eventLog('project.open.dialog', { cancelled: result.canceled });
      const target = result.canceled || stopping ? '' : result.filePaths[0] || '';
      return target && await projectTrust.trust(target) ? target : '';
    }
    const result = await showSaveDialog(window, { title: 'Save Individual Guide project',
      defaultPath: /\.igpx$/i.test(defaultPath) ? defaultPath : defaultPath + '.igpx',
      filters: [{ name: 'Individual Guide project', extensions: ['igpx'] }], properties: ['showOverwriteConfirmation'] });
    eventLog('project.save.dialog', { cancelled: result.canceled });
    if (result.canceled || !result.filePath || stopping) return '';
    let target = result.filePath;
    if (!/\.igpx$/i.test(target)) {
      target += '.igpx';
      if (fs.existsSync(target)) {
        const { response } = await showMessageBox(window, { type: 'warning', title: 'Replace project?',
          message: 'A project with this name already exists. Replace it?', buttons: ['Cancel','Replace'], defaultId: 0, cancelId: 0, noLink: true });
        if (response !== 1) return '';
      }
    }
    return target;
  } finally { projectDialogOpen = false; }
}
async function saveDiagnosticLog() {
  if (stopping) return;
  const result = await showSaveDialog(window, { title: 'Save diagnostic log',
    defaultPath: path.join(app.getPath('documents'), 'IndividualGuide-diagnostics.log'),
    filters: [{ name: 'Log file', extensions: ['log','txt'] }], properties: ['showOverwriteConfirmation'] });
  if (result.canceled || !result.filePath) { eventLog('diagnostics.export.cancelled'); return; }
  eventLog('diagnostics.export');
  const files = [5,4,3,2,1].map(index => path.join(path.dirname(logPath), `startup.${index}.log`)).concat(logPath);
  if (files.some(file => path.resolve(file).toLowerCase() === path.resolve(result.filePath).toLowerCase()))
    throw new Error('Choose a destination outside the managed startup log files.');
  const contents = files.filter(file => fs.existsSync(file)).map(file => `=== ${path.basename(file)} ===\n${fs.readFileSync(file,'utf8')}`).join('\n');
  await fs.promises.writeFile(result.filePath, contents, 'utf8');
}
async function start() {
  eventLog('desktop.ready', { elapsedMs: Date.now() - startedAt, appPath: app.getAppPath() });
  updateMenu = require('./menus.cjs')({ command: sendCommand,
    translate, setLanguage,
    preferences, openProject: queueProject,
    about: async () => {
      let info = {};
      try { info = JSON.parse(fs.readFileSync(path.join(runtime, 'R/library/IndividualGuide/build-info.json'), 'utf8')); } catch {}
      await showMessageBox(window, { type: 'info', title: 'About Individual Guide', message: 'Individual Guide ' + app.getVersion(),
        detail: ['Build: ' + (info.built_at || translate('development')), 'Source: ' + (info.commit || translate('source checkout')) + (info.dirty ? ' ('+translate('modified')+')' : ''),
          'R: ' + (info.R || translate('bundled runtime')), 'Electron: ' + process.versions.electron, 'Chromium: ' + process.versions.chrome,
          'MIT © Thomas Wood. Bundled components retain their own licenses.'].join('\n'), buttons: ['Close'] });
    },
    pinProject: () => { preferences.pin(workspace.projectPath); refreshMenus(); },
    unpinProject: file => { preferences.pin(file); refreshMenus(); },
    clearRecent: () => { preferences.clear(); refreshMenus(); },
    restart: () => requestRestart().catch(recovery),
    openLog: () => openLocal(logPath), openLogs: () => openLocal(path.dirname(logPath)),
    saveLog: () => saveDiagnosticLog().catch(async error => {
      eventLog('diagnostics.export.failed', error.message, 'ERROR');
      if (!stopping) await showMessageBox(window, { type: 'error', title: 'Could not save diagnostic log', message: error.message });
    }), close: () => window.close() });
  const displays = [screen.getPrimaryDisplay(), ...screen.getAllDisplays().filter(d => d.id !== screen.getPrimaryDisplay().id)];
  const bounds = windowBounds(preferences.window, displays);
  window = new BrowserWindow({ title: 'Individual Guide', ...bounds,
    icon: path.join(__dirname, 'assets', 'icon.png'),
    show: !smoke, backgroundColor: '#171a27', autoHideMenuBar: false,
    webPreferences: { preload: path.join(__dirname, 'preload.cjs'), nodeIntegration: false, contextIsolation: true, sandbox: true, webSecurity: true,
      spellcheck: false, backgroundThrottling: false } });
  eventLog('window.created', { sandbox: true, contextIsolation: true, width: 1440, height: 960 });
  hostedRenderers = require('./hosted-renderers.cjs')({window,app,log:eventLog});
  if (preferences.window?.maximized === true) window.maximize();
  let boundsTimer;
  const saveBounds = () => {
    clearTimeout(boundsTimer);
    if (!window.isDestroyed() && !window.isMinimized() && !window.isFullScreen())
      preferences.saveWindow({ ...window.getNormalBounds(), maximized: window.isMaximized() });
  };
  for (const name of ['resize','move','maximize','unmaximize']) window.on(name, () => {
    clearTimeout(boundsTimer); boundsTimer = setTimeout(saveBounds, 400);
  });
  window.on('close', event => {
    saveBounds();
    event.preventDefault();
    if (stopping) return;
    // Keep the last window alive while asynchronous R shutdown drains. Closing
    // it first can suspend Chromium's main loop before child-exit callbacks run.
    if (allowClose || (smoke && finished)) { app.quit(); return; }
    requestClose().catch(error => log(error.message));
  });
  window.on('page-title-updated', event => { event.preventDefault(); refreshMenus(); });
  window.on('unresponsive', () => eventLog('renderer.unresponsive', undefined, 'WARN'));
  window.on('responsive', () => eventLog('renderer.responsive'));
  const trustedSender = event => event.sender === window.webContents && event.senderFrame === window.webContents.mainFrame &&
    (permitted(event.senderFrame.url) || event.senderFrame.url === require('node:url').pathToFileURL(loadingFile).href);
  ipcMain.handle('ig:release-shiny-app', (event,url) => trustedSender(event) && hostedRenderers.release(url));
  ipcMain.handle('ig:backend-state', event => trustedSender(event) ? {...backendState,localizedMessage:translate(backendState.message)} : undefined);
  ipcMain.handle('ig:language', event => trustedSender(event) ? languageState() : undefined);
  ipcMain.handle('ig:set-language', (event, locale) => trustedSender(event) ? setLanguage(locale) : false);
  ipcMain.handle('ig:restart-r', event => trustedSender(event) ? requestRestart() : false);
  ipcMain.handle('ig:open-log', event => trustedSender(event) ? openLocal(logPath) : undefined);
  ipcMain.handle('ig:project-dialog', (event, request) => trustedSender(event) ? chooseProjectFile(request) : undefined);
  ipcMain.handle('ig:confirm-changes', async (event, action) => {
    if (!trustedSender(event) || !['new','close','open','exit'].includes(action) || projectDialogOpen) return 'cancel';
    projectDialogOpen = true;
    try {
      const result = await showMessageBox(window, { type:'warning', title:'Unsaved changes',
        message: 'Save your project before ' + ({ new:'creating a new project', close:'closing the project', open:'opening another project', exit:'closing Individual Guide' }[action]) + '?',
        detail: action === 'exit' && workspace.running ? 'Closing will also stop running tasks.' : 'Discard continues without saving the current changes.',
        buttons:['Cancel','Discard','Save'], defaultId:2, cancelId:0, noLink:true });
      return ['cancel','discard','save'][result.response] || 'cancel';
    } finally { projectDialogOpen = false; }
  });
  ipcMain.on('ig:command-result', (event, value) => {
    if (!trustedSender(event) || !value || typeof value.id !== 'string') return;
    const complete = commandRequests.get(value.id);
    if (complete) { commandRequests.delete(value.id); complete(value.ok === true); }
  });
  ipcMain.on('ig:project-used', (event, file) => {
    if (!trustedSender(event) || !projectPath(file) || !fs.existsSync(file)) return;
    projectTrust.remember(file).catch(error=>eventLog('project.trust.remember.failed',error.message,'WARN'));
    preferences.used(file); app.addRecentDocument(file); refreshMenus();
  });
  ipcMain.on('ig:workspace-state', (event, value) => {
    if (!trustedSender(event) || !value || typeof value !== 'object') return;
    const previous = workspace.connected;
    for (const key of ['connected','dirty','canUndo','pending','modal','welcome','welcomeVisible','running','canRun','recovery','startupReady','appHost','appHostRunning','appHostLog']) workspace[key] = value[key] === true;
    for (const key of ['projectName','projectPath','comments','review','hostName']) workspace[key] = typeof value[key] === 'string' ? value[key].slice(0,4096) : '';
    if (workspace.connected !== previous) eventLog(workspace.connected ? 'workspace.connected' : 'workspace.disconnected',
      { attempt, elapsedMs: Date.now() - attemptStarted, rPid: rProcess?.pid, memoryMiB: Math.round(process.memoryUsage().rss/1048576) });
    refreshMenus();
  });
  ipcMain.on('ig:renderer-event', (event, value) => {
    if (!trustedSender(event) || !value || !['command.error','project.command.complete'].includes(value.event)) return;
    const details = value.details || {};
    eventLog(value.event, { action: String(details.action || '').slice(0,40), ok: details.ok === true,
      message: value.event === 'command.error' ? String(details.message || '').slice(0,500) : undefined });
    if (value.event === 'command.error' && workspace.connected && !stopping)
      showMessageBox(window, { type: 'error', title: 'Project command failed', message: String(details.message || 'R could not complete the command.').slice(0,500) }).catch(error => log(error.message));
  });
  window.webContents.on('did-fail-load', (_event, code, description, _url, mainFrame) => {
    if (mainFrame) eventLog('renderer.load.failed', { code, description, attempt }, 'ERROR');
  });
  window.webContents.on('console-message', details => {
    if (['warning','error'].includes(details.level)) eventLog('renderer.console', { level: details.level,
      message: String(details.message).slice(0,2000), line: details.lineNumber }, details.level === 'error' ? 'ERROR' : 'WARN');
  });
  window.webContents.setWindowOpenHandler(({ url }) => {
    if (permitted(url)) return { action: 'allow', overrideBrowserWindowOptions: {
      icon: path.join(__dirname, 'assets', 'icon.png'),
      autoHideMenuBar: true, webPreferences: { nodeIntegration: false, contextIsolation: true, sandbox: true } } };
    if (/^https?:\/\//i.test(url)) shell.openExternal(url).catch(error => log(error.message));
    return { action: 'deny' };
  });
  window.webContents.on('will-navigate', event => {
    if (appURL && !permitted(event.url)) {
      event.preventDefault();
      if (/^https?:\/\//i.test(event.url)) shell.openExternal(event.url).catch(error => log(error.message));
    }
  });
  const permit = (contents, permission) => contents === window.webContents && permitted(contents.getURL()) &&
    ['clipboard-sanitized-write', 'fullscreen'].includes(permission);
  window.webContents.session.setPermissionCheckHandler((contents, permission) => permit(contents, permission));
  window.webContents.session.setPermissionRequestHandler((contents, permission, callback) => callback(permit(contents, permission)));
  window.webContents.session.webRequest.onBeforeSendHeaders((details, callback) => {
    const headers = { ...details.requestHeaders };
    for (const key of Object.keys(headers)) if (key.toLowerCase() === 'x-ig-desktop-token') delete headers[key];
    let own = false;
    try { const target = new URL(details.url), source = new URL(appURL); own = ['http:','ws:'].includes(target.protocol) && target.hostname === source.hostname && target.port === source.port; } catch {}
    const sourceURL=details.frame?.url || headers.Origin || headers.origin || details.referrer;
    const fromWorkspace=details.webContentsId===window.webContents.id &&
      (details.resourceType==='mainFrame' || permitted(sourceURL));
    if (own && fromWorkspace) headers['X-IG-Desktop-Token'] = desktopToken;
    callback({ requestHeaders: headers });
  });
  const blockedRequests = [];
  if (smoke) window.webContents.session.webRequest.onBeforeRequest((details, callback) => {
    const allowed = /^(file:|data:|blob:|devtools:)/.test(details.url) || /^(https?|wss?):\/\/(127(?:\.[0-9]{1,3}){3}|localhost)(:|\/)/.test(details.url);
    if (!allowed) blockedRequests.push(details.url);
    callback({ cancel: !allowed });
  });
  window.webContents.session.on('will-download', (_event, item) => {
    eventLog('download.started', { filename: path.basename(item.getFilename()) });
    item.once('done', (_event, status) => eventLog('download.finished', { status }));
    item.setSaveDialogOptions({ defaultPath: path.join(app.getPath('downloads'), path.basename(item.getFilename())) });
  });
  window.webContents.on('render-process-gone', (_event, details) => {
    if (!stopping) fail(new Error(`The application window stopped (${details.reason}).`));
  });
  window.webContents.on('will-prevent-unload', event => {
    if (leavingForRestart || allowClose) { event.preventDefault(); return; }
    if (smoke) {
      if (!smokeEvidence) { event.preventDefault(); return; }
      smokeEvidence.checks.unsavedClosePrompt = true;
      recordSmoke(smokeEvidence);
      event.preventDefault();
      return;
    }
    const choice = showMessageBoxSync(window, { type: 'question', title: 'Unsaved changes',
      message: 'Close Individual Guide without saving your project?',
      detail: 'Choose Keep open to save your work first.', buttons: ['Keep open', 'Close without saving'],
      defaultId: 0, cancelId: 0, noLink: true });
    // Electron uses preventDefault here to permit leaving a page whose
    // beforeunload handler requested confirmation.
    if (choice === 1) event.preventDefault();
  });
  window.on('closed', () => {
    if (smokeEvidence) { smokeEvidence.checks.windowClosed = true; recordSmoke(smokeEvidence); }
  });
  if (!(await launchR())) {
    if (smoke) throw new Error('The test R server did not start.');
    return;
  }
  if (languageTest) {
    const evidence=await require('./language-smoke.cjs')({window,pause,state,preferences,getProcess:()=>rProcess,getState:()=>backendState,requestRestart});
    evidence.runtimeDirectory=runtime;evidence.desktop={packaged:app.isPackaged,executable:process.execPath,rPid:rProcess.pid};
    smokeEvidence=evidence;recordSmoke(evidence);finished=true;window.close();return;
  }
  if (shinyAppsTest) {
    const evidence=await require('./shiny-apps-smoke.cjs')({window,pause,state,runtime,getProcess:()=>rProcess});
    evidence.runtimeDirectory=runtime;evidence.desktop={packaged:app.isPackaged,executable:process.execPath,rPid:rProcess.pid};
    smokeEvidence=evidence;recordSmoke(evidence);finished=true;window.close();return;
  }
  if (productTest) {
    const evidence = await require('./product-smoke.cjs')({window,pause,state,rendererCommand,appURL});
    evidence.runtimeDirectory=runtime; evidence.desktop={packaged:app.isPackaged,executable:process.execPath,rPid:rProcess.pid};
    smokeEvidence=evidence;recordSmoke(evidence);finished=true;window.close();return;
  }
  if (examplesTest) {
    const evidence = await require('./examples-smoke.cjs')({ window, pause, state, rendererCommand });
    evidence.runtimeDirectory = runtime;
    evidence.desktop = { packaged: app.isPackaged, executable: process.execPath, rPid: rProcess.pid };
    smokeEvidence = evidence; recordSmoke(evidence); finished = true; window.close(); return;
  }
  if (consoleTest) {
    const evidence = await require('./console-smoke.cjs')({ window, pause, state });
    evidence.runtimeDirectory = runtime;
    evidence.desktop = { packaged: app.isPackaged, executable: process.execPath, rPid: rProcess.pid };
    smokeEvidence = evidence; recordSmoke(evidence); finished = true; window.close(); return;
  }
  if (lifecycleTest) {
    const evidence = await require('./lifecycle-smoke.cjs')({ window, pause, state, logPath, sendCommand, saveDiagnosticLog, preferences, rendererCommand, queueProject, requestClose });
    evidence.runtimeDirectory = runtime; evidence.desktop = { packaged:app.isPackaged, executable:process.execPath, rPid:rProcess.pid, startupLog:logPath };
    smokeEvidence = evidence; recordSmoke(evidence); await evidence.finishClose(); recordSmoke(evidence); finished = true; return;
  }
  if (menuTest) {
    const evidence = await require('./menu-smoke.cjs')({ window, pause, state, logPath, sendCommand, saveDiagnosticLog });
    evidence.runtimeDirectory = runtime; evidence.desktop = { packaged: app.isPackaged, executable: process.execPath, rPid: rProcess.pid, startupLog: logPath };
    smokeEvidence = evidence; recordSmoke(evidence); finished = true; window.close(); return;
  }
  if (restartTest) {
    const evidence = await require('./restart-smoke.cjs')({ window, pause, getProcess: () => rProcess,
      getState: () => backendState, requestRestart, getURL: () => appURL });
    if (blockedRequests.length) throw new Error(`Unexpected external browser requests: ${blockedRequests.join(', ')}`);
    evidence.checks.offline = true;
    evidence.desktop = { packaged: app.isPackaged, executable: process.execPath, rPid: rProcess.pid, startupLog: logPath };
    evidence.runtimeDirectory = runtime;
    smokeEvidence = evidence; recordSmoke(evidence); finished = true; window.close(); return;
  }
  if (startupOnly) {
    const deadline = Date.now() + 60000;
    const recoveryCheck = process.argv.includes('--smoke-recovery-discard');
    if (recoveryCheck) {
      while (!workspace.connected || !workspace.recovery || !(await window.webContents.executeJavaScript("Boolean(document.getElementById('recover_discard')?.classList.contains('shiny-bound-input'))"))) {
        if (Date.now() > deadline) throw new Error('The recovery prompt was not shown.');
        await pause(100);
      }
      if (workspace.projectPath || !pendingProjects.includes(initialProject) || Menu.getApplicationMenu().getMenuItemById('open').enabled)
        throw new Error('A project launch bypassed recovery protection.');
      await window.webContents.executeJavaScript("document.getElementById('recover_discard').click()");
    }
    const startupReady = async () => initialProject ? workspace.connected && !workspace.pending &&
      workspace.projectPath.toLowerCase() === initialProject.toLowerCase() :
      await window.webContents.executeJavaScript("Boolean(window.Shiny?.shinyapp?.$socket?.readyState===1 && document.getElementById('splash_fresh')?.classList.contains('shiny-bound-input'))");
    while (!(await startupReady())) {
      if (Date.now() > deadline) throw new Error('The startup test could not connect to the workspace.');
      await pause(100);
    }
    if (blockedRequests.length) throw new Error(`Unexpected external browser requests: ${blockedRequests.join(', ')}`);
    smokeEvidence = { ok: true, readyAt: new Date().toISOString(), readyMilliseconds: Date.now() - startedAt,
      windowState: { bounds:window.getNormalBounds(), maximized:window.isMaximized() },
      checks: { workspace: true, offline: true }, runtimeDirectory: runtime,
      desktop: { packaged: app.isPackaged, executable: process.execPath, rPid: rProcess.pid, startupLog: logPath } };
    if (initialProject) smokeEvidence.checks.openProjectArgument = true;
    if (recoveryCheck) smokeEvidence.checks.recoveryBeforeProjectOpening = true;
    recordSmoke(smokeEvidence); finished = true; window.close(); return;
  }
  if (smoke) {
    const evidence = await require('./smoke.cjs')({ window, appURL, state, runtime, pause });
    if (process.argv.includes('--smoke-second-launch')) {
      const launcher = process.env.PORTABLE_EXECUTABLE_FILE || process.execPath;
      const asset = path.join(runtime, 'R', 'library', 'IndividualGuide', 'R', 'IndividualGuide.rdb');
      const original = crypto.createHash('sha256').update(fs.readFileSync(asset)).digest('hex');
      await new Promise((resolve, reject) => {
        const child = spawn(launcher, [`--data-dir=${state}`], { windowsHide: true, stdio: 'ignore' });
        const timeout = setTimeout(() => {
          const killer = spawn(path.join(process.env.SystemRoot, 'System32', 'taskkill.exe'),
            ['/PID', String(child.pid), '/T', '/F'], { windowsHide: true });
          killer.once('error', () => {});
          reject(new Error('The second launch did not exit within five minutes.'));
        }, 300000);
        child.once('error', error => { clearTimeout(timeout); reject(error); });
        child.once('exit', code => {
          clearTimeout(timeout);
          if (code === 0) resolve();
          else reject(new Error(`The second launch exited with code ${code}.`));
        });
      });
      if (secondInstanceCount !== 1 || !alive() || !(await responds(appURL)) ||
          crypto.createHash('sha256').update(fs.readFileSync(asset)).digest('hex') !== original)
        throw new Error('A second launch disturbed the running application.');
      evidence.checks.secondLaunch = true;
    }
    if (blockedRequests.length) throw new Error(`Unexpected external browser requests: ${blockedRequests.join(', ')}`);
    evidence.checks.offline = true;
    evidence.runtime = JSON.parse(fs.readFileSync(runtimeResult, 'utf8'));
    evidence.desktop = { electron: process.versions.electron, chrome: process.versions.chrome,
      packaged: app.isPackaged, executable: process.execPath, portableExecutable: process.env.PORTABLE_EXECUTABLE_FILE,
      startupLog: logPath, rPid: rProcess.pid };
    evidence.ok = true;
    smokeEvidence = evidence;
    recordSmoke(evidence);
    finished = true;
    window.close();
  }
}
async function launchR() {
  if (stopping) return false;
  try {
    attempt++; attemptStarted = Date.now();
    eventLog('r.start.attempt', { attempt, previousPid: rProcess?.pid, runtime });
    setBackendState('starting', 'Starting your workspace...');
    leavingForRestart = true;
    try { await window.loadFile(loadingFile); } finally { leavingForRestart = false; }
    await stopR();
    if (stopping) return false;
    fs.rmSync(stopFile, { force: true });
    const rHome = path.join(runtime, 'R');
    const manifest = JSON.parse(fs.readFileSync(path.join(runtime, 'runtime.json'), 'utf8'));
    eventLog('runtime.manifest', { ...manifest, library: path.join(rHome, 'library'), pandoc: path.join(runtime, 'pandoc'), userLibrary: path.join(state, 'packages') });
    const executable = path.join(rHome, 'bin', 'x64', 'Rscript.exe');
    if (!fs.existsSync(executable)) throw new Error('The bundled R runtime is missing. Reinstall Individual Guide to repair it.');
    const port = await freePort();
    if (stopping) return false;
    appURL = `http://127.0.0.1:${port}/`;
    const environment = { ...process.env };
    for (const name of Object.keys(environment)) {
      if (/^(R_HOME|R_LIBS.*|R_PROFILE.*|R_ENVIRON.*|RSTUDIO.*|ELECTRON_RUN_AS_NODE|PATH)$/i.test(name)) delete environment[name];
    }
    Object.assign(environment, { R_HOME: rHome, R_LIBS_USER: '', R_LIBS_SITE: '',
      R_ENVIRON_USER: 'NUL', R_PROFILE_USER: 'NUL', RSTUDIO_PANDOC: path.join(runtime, 'pandoc'),
      PATH: [path.dirname(executable), path.join(runtime, 'pandoc'),
        path.join(process.env.SystemRoot, 'System32', 'WindowsPowerShell', 'v1.0'),
        path.join(process.env.SystemRoot, 'System32'), process.env.SystemRoot].join(';'),
      LC_ALL: 'English_Canada.utf8', LANG: 'English_Canada.utf8', IG_LANGUAGE: localization.locale, IG_RUNTIME_DIR: runtime,
      IG_USER_DATA: state, IG_WORK_DIR: app.getPath('documents'), IG_STOP_FILE: stopFile, IG_PORT: String(port), IG_DESKTOP_TOKEN: desktopToken,
      IG_SMOKE_TEST: smoke && !startupOnly && !restartTest && !menuTest && !lifecycleTest && !consoleTest && !examplesTest && !productTest && !shinyAppsTest ? '1' : '0', IG_RUNTIME_RESULT: runtimeResult });
    if (smoke) {
      for (const name of Object.keys(environment)) if (/^(https?_proxy|all_proxy|no_proxy)$/i.test(name)) delete environment[name];
      Object.assign(environment, { http_proxy: 'http://127.0.0.1:9', https_proxy: 'http://127.0.0.1:9', no_proxy: '127.0.0.1,127.0.0.2,localhost' });
    }
    rProcess = spawn(executable, ['--vanilla', path.join(runtime, 'startup.R')],
      { cwd: state, env: environment, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    const child = rProcess;
    const childAttempt = attempt, childStarted = attemptStarted;
    eventLog('r.spawn', { attempt, pid: rProcess.pid, executable, port, cwd: state, hostProfilesDisabled: true });
    diagnostics.stream(rProcess.stdout, 'r.stdout');
    diagnostics.stream(rProcess.stderr, 'r.stderr');
    child.once('error', error => {
      eventLog('r.spawn.error', error.stack || String(error), 'ERROR');
      if (backendState.phase === 'ready' && !stopping && !expectedStops.has(child) && child === rProcess)
        recovery(error).catch(fail);
    });
    child.once('exit', (code, signal) => {
      eventLog('r.exit', { pid: child.pid, code, signal, expected: stopping || expectedStops.has(child), attempt: childAttempt, elapsedMs: Date.now() - childStarted }, stopping || expectedStops.has(child) ? 'INFO' : 'WARN');
      if (!stopping && !finished && !expectedStops.has(child) && child === rProcess && backendState.phase === 'ready')
        recovery(new Error('The R server stopped. You can restart it below.')).catch(fail);
    });
    const deadline = Date.now() + 180000;
    let httpReady = false;
    while (!stopping && alive() && Date.now() < deadline && !(httpReady = await responds(appURL))) await pause(250);
    if (stopping) return false;
    if (!alive()) throw new Error('The bundled runtime could not start. See startup.log for details.');
    if (!httpReady) throw new Error('The workspace took too long to start. See startup.log for details.');
    eventLog('r.http.ready', { attempt, elapsedMs: Date.now() - attemptStarted, port });
    await window.loadURL(appURL);
    eventLog('renderer.loaded', { attempt, elapsedMs: Date.now() - attemptStarted });
    if (stopping) return false;
    if (!alive()) throw new Error('The R server stopped while opening the workspace. Try restarting again.');
    setBackendState('ready', 'R server is running.');
    return true;
  } catch (error) {
    await recovery(error);
    return false;
  }
}

if (ownsInstance) {
  app.on('second-instance', (_event, argv, workingDirectory) => {
    secondInstanceCount++;
    const file = projectArgument(argv, workingDirectory);
    if (file) queueProject(file);
    if (window) { if (window.isMinimized()) window.restore(); if (!smoke) window.show(); window.focus(); }
  });
  app.on('open-file', (event, file) => { event.preventDefault(); queueProject(path.resolve(file)); });
  app.on('window-all-closed', () => app.quit());
  app.on('before-quit', event => {
    event.preventDefault();
    if (stopping) return;
    stopping = true;
    eventLog('desktop.shutdown.request', { exitCode, rPid: rProcess?.pid, uptimeMs: Date.now() - startedAt });
    stopR().catch(error => log(error.stack || String(error))).finally(() => {
      try { fs.rmSync(work, { recursive: true, force: true }); } catch (error) { log(error.message); }
      eventLog('desktop.shutdown.complete', { exitCode, uptimeMs: Date.now() - startedAt }); app.exit(exitCode);
    });
  });
  app.whenReady().then(start).catch(fail);
}
