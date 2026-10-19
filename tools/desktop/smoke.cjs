'use strict';
// Runs only when the executable is launched with --smoke-test. It exercises the
// real packaged renderer and Shiny session, without relying on an installed R,
// an external browser, a development checkout or a test package.
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
module.exports = async function ({ window, state, runtime, pause }) {
  const checks = {};
  const js = source => window.webContents.executeJavaScript(source, true);
  const quote = JSON.stringify;
  async function wait(source, label, timeout = 45000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      if (await js(source)) return;
      await pause(150);
    }
    throw new Error(`Desktop smoke test timed out: ${label}`);
  }
  async function click(id) {
    await wait(`document.getElementById(${quote(id)})?.classList.contains('shiny-bound-input')`, id);
    await js(`document.getElementById(${quote(id)}).click()`);
  }
  async function ready(id) {
    await wait(`(() => { const panel=document.getElementById(${quote('panel_' + id)}); return panel?.dataset.igReadyToken && Object.entries(Shiny.shinyapp.$inputValues).some(([k,v])=>k.endsWith(${quote('_' + id + '-ig_ready')}) && v===panel.dataset.igReadyToken); })()`, `${id} ready`);
  }
  async function add(type, id) {
    await click('btn_add_task');
    await wait(`document.querySelector('[onclick*="picker_select"][onclick*=${quote(type)}]') !== null`, `${type} picker`);
    await js(`document.querySelector('[onclick*="picker_select"][onclick*=${quote(type)}]').click()`);
    await ready(id);
  }
  async function download(id, destination) {
    return new Promise((resolve, reject) => {
      const session = window.webContents.session;
      const timer = setTimeout(() => { session.removeListener('will-download', receive); reject(new Error(`Download timed out: ${id}`)); }, 45000);
      function receive(_event, item) {
        item.setSavePath(destination);
        item.once('done', (_event, status) => {
          clearTimeout(timer);
          if (status === 'completed') resolve(destination);
          else reject(new Error(`Download ${id}: ${status}`));
        });
      }
      session.once('will-download', receive);
      js(`document.getElementById(${quote(id)}).click()`).catch(error => {
        clearTimeout(timer); session.removeListener('will-download', receive); reject(error);
      });
    });
  }
  await wait(`window.Shiny?.shinyapp?.$socket?.readyState===1 && document.getElementById('splash_fresh')?.classList.contains('shiny-bound-input')`, 'connected workspace');
  await click('splash_fresh');
  await wait(`document.querySelector('.modal-backdrop') === null`, 'new project');
  checks.workspace = true;
  await js(`(() => { const style=document.createElement('style');style.textContent='*,*::before,*::after{animation:none!important;transition:none!important}';document.head.appendChild(style); })()`);
  await js(`Promise.all([document.fonts.load('16px Inter'), document.fonts.load('16px "JetBrains Mono"')])`);
  checks.localFonts = await js(`document.fonts.check('16px Inter') && document.fonts.check('16px "JetBrains Mono"')`);
  if (!checks.localFonts) throw new Error('Bundled fonts did not load.');
  await add('script', 'script_1');
  await wait(`document.getElementById('log_script_1-success_template')?.classList.contains('shiny-bound-input')`, 'logging builder');
  await click('log_script_1-add_rule');
  await wait(`document.getElementById('log_script_1-rule_1_template')?.classList.contains('shiny-bound-input')`, 'new log rule');
  await js(`(() => {
    const set=(id,value)=>{const input=document.getElementById(id);input.value=value;input.dispatchEvent(new Event('input',{bubbles:true}));input.dispatchEvent(new Event('change',{bubbles:true}));};
    set('scr_script_1-output_name','desktop_rows');set('scr_script_1-output_defs','desktop_rows: table');
    ace.edit('scr_script_1-code').setValue("log_event('Standalone checkpoint'); desktop_rows <- data.frame(x=1:5)",-1);
    set('log_script_1-success_template','Desktop finished {rows_out} rows');
    set('log_script_1-rule_1_template','Desktop built rule {task}: {rows_out} rows');
    document.getElementById('log_script_1-rule_1_level').selectize.setValue('WARN');
  })()`);
  await pause(600); await click('panel_run_btn_script_1');
  await wait(`document.querySelector('#panel_status_script_1 .ig-status-success') !== null`, 'script execution');
  checks.script = true;
  await js(`document.querySelector('#panel_script_1 details > summary').click()`);
  await wait(`document.getElementById('log_script_1-preview_entries').innerText.includes('Desktop finished 5 rows')`, 'current logging preview');
  await js(`(() => {
    document.querySelector('input[name="log_script_1-preview_source"][value="example"]').click();
    const rows=document.getElementById('log_script_1-preview_rows_out');rows.value=12;rows.dispatchEvent(new Event('change',{bubbles:true}));
    document.getElementById('log_script_1-preview_format').selectize.setValue('json');
  })()`);
  await wait(`(() => {try {return JSON.parse(document.getElementById('log_script_1-preview_file').innerText).some(e=>e.message==='Desktop finished 12 rows');} catch {return false;}})()`, 'example JSON logging preview');
  if (!(await js(`document.getElementById('log_script_1-preview_inputs').innerText.includes('{rows_out}')`)))
    throw new Error('Logging preview inputs are missing their field tokens.');
  checks.loggingVisualPreview = true;
  await add('first_last_n', 'firstlastn_1');
  await js(`(() => {
    document.getElementById('fl_firstlastn_1-input_table').selectize.setValue('desktop_rows');
    const n=document.getElementById('fl_firstlastn_1-n');n.value='2';n.dispatchEvent(new Event('change',{bubbles:true}));
  })()`);
  await pause(600); await click('panel_run_btn_firstlastn_1');
  await wait(`document.querySelector('#panel_status_firstlastn_1 .ig-status-success') !== null`, 'data task execution');
  checks.dataTask = true;
  const dataOutput = await js(`document.getElementById('fl_firstlastn_1-output_name').value`);
  await add('export_log', 'exportlog_1');
  const destination = path.join(state, 'desktop-smoke-log.csv');
  await js(`(() => { const e=document.getElementById('elog_exportlog_1-path');e.value=${quote(destination)};e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));document.getElementById('elog_exportlog_1-format').selectize.setValue('csv');document.getElementById('elog_exportlog_1-overwrite').click();})()`);
  await pause(600); await click('elog_exportlog_1-run');
  await wait(`document.querySelector('#panel_status_exportlog_1 .ig-status-success') !== null`, 'log export');
  if (!fs.readFileSync(destination, 'utf8').includes('Standalone checkpoint')) throw new Error('The exported log is missing the Script checkpoint.');
  const exported = fs.readFileSync(destination, 'utf8');
  if (!exported.includes('Desktop finished 5 rows') ||
      !exported.split('\n').some(line => line.includes('Desktop built rule script_1: 5 rows') && line.includes('"WARN"')))
    throw new Error('The interactive logging rules were not applied to the exported log.');
  checks.loggingBuilder = true;
  checks.logExport = true;
  await wait(`document.getElementById('elog_exportlog_1-preview_file').innerText.includes('Standalone checkpoint')`, 'export file preview');
  const preview = await js(`document.getElementById('elog_exportlog_1-preview_file').innerText`);
  if (preview.replace(/\r\n/g, '\n') !== exported.replace(/\r\n/g, '\n').trimEnd())
    throw new Error('Export Log preview differs from the written CSV.');
  checks.logFilePreview = true;
  await js(`document.getElementById('tabpill_code').click()`);
  await wait(`document.getElementById('code-code_display').innerText.includes('# Pipeline ----')`, 'pipeline code view');
  const pipeline = await js(`document.getElementById('code-code_display').innerText`);
  if (!pipeline.includes('pipeline_support.R') || pipeline.includes('ig_capture_task_log <-'))
    throw new Error('The default code view does not separate pipeline and support.');
  fs.writeFileSync(path.join(state, 'desktop-smoke-code.png'), (await window.webContents.capturePage()).toPNG());
  await js(`Shiny.addCustomMessageHandler('ig_copy_text', text => window.smokeCopiedCode = text)`);
  await click('code-copy_r');
  await wait(`window.smokeCopiedCode === document.getElementById('code-code_display').innerText`, 'copy selected code');
  await js(`document.querySelector('input[name="code-view"][value="support"]').click()`);
  await wait(`document.getElementById('code-code_display').innerText.includes('ig_capture_task_log <-')`, 'support code view');
  await js(`document.querySelector('input[name="code-view"][value="complete"]').click()`);
  await wait(`document.getElementById('code-code_display').innerText.includes('# Pipeline ----') && document.getElementById('code-code_display').innerText.includes('ig_capture_task_log <-')`, 'complete code view');
  const single = await download('code-dl_r', path.join(state, 'downloaded.R'));
  const bundle = await download('code-dl_bundle', path.join(state, 'downloaded.zip'));
  const directory = path.join(state, 'Code bundle Ω');
  const verification = path.join(state, 'verify-exports.R');
  fs.writeFileSync(verification, [
    `zip::unzip(${quote(bundle)}, exdir=${quote(directory)})`,
    `for (file in c(${quote(single)}, file.path(${quote(directory)}, 'pipeline.R'))) {`,
    `  environment <- new.env(parent=globalenv()); source(file, local=environment)`,
    `  stopifnot(nrow(environment$desktop_rows)==5L, nrow(get(${quote(dataOutput)}, environment))==2L)`,
    `  stopifnot(all(vapply(environment$.task_status, identical, logical(1), 'success')))`,
    `}`, `stopifnot(!'IndividualGuide' %in% loadedNamespaces())`
  ].join('\n'), 'utf8');
  const environment = { ...process.env };
  for (const name of Object.keys(environment)) if (/^(R_HOME|R_LIBS.*|R_PROFILE.*|R_ENVIRON.*|RSTUDIO.*|ELECTRON_RUN_AS_NODE|PATH)$/i.test(name)) delete environment[name];
  const rHome = path.join(runtime, 'R');
  Object.assign(environment, { R_HOME: rHome, R_LIBS_USER: path.join(rHome, 'library'), R_LIBS_SITE: '',
    R_ENVIRON_USER: 'NUL', R_PROFILE_USER: 'NUL', LC_ALL: 'English_Canada.utf8', LANG: 'English_Canada.utf8',
    PATH: [path.join(rHome, 'bin', 'x64'), path.join(process.env.SystemRoot, 'System32'), process.env.SystemRoot].join(';') });
  await new Promise((resolve, reject) => {
    const child = spawn(path.join(rHome, 'bin', 'x64', 'Rscript.exe'), ['--vanilla', verification],
      { cwd: state, env: environment, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    let output = '';
    child.stdout.on('data', data => { output += data; }); child.stderr.on('data', data => { output += data; });
    child.once('error', reject);
    child.once('exit', code => {
      fs.writeFileSync(path.join(state, 'verify-exports.log'), output);
      if (code === 0) resolve(); else reject(new Error(`Fresh bundled-R export execution failed (${code}): ${output}`));
    });
  });
  checks.codeViewsAndCopy = true;
  checks.codeDownloads = true;
  checks.freshCodeExecution = true;
  await js(`document.getElementById('tabpill_exportlog_1').click()`);
  await wait(`document.getElementById('panel_exportlog_1').classList.contains('ig-panel-active')`, 'return to export task');
  const errors = await js(`Array.from(document.querySelectorAll('.shiny-output-error:not(.shiny-output-error-validation)')).filter(e=>e.getClientRects().length).map(e=>e.innerText)`);
  if (errors.length) throw new Error(`Renderer errors: ${errors.join('; ')}`);
  checks.noVisibleErrors = true;
  const layout = await js(`Array.from(document.querySelectorAll('.ig-task-panel')).map(e=>({id:e.id,active:e.classList.contains('ig-panel-active'),display:getComputedStyle(e).display,opacity:getComputedStyle(e).opacity,width:e.getBoundingClientRect().width,height:e.getBoundingClientRect().height}))`);
  checks.activePanelVisible = layout.some(panel => panel.id === 'panel_exportlog_1' && panel.active && panel.display === 'flex' && Number(panel.opacity) > 0.9 && panel.width > 300 && panel.height > 200);
  if (!checks.activePanelVisible) throw new Error(`The active task panel is not visible: ${JSON.stringify(layout)}`);
  checks.rendererSandbox = await js(`typeof require==='undefined' && typeof process==='undefined'`);
  if (!checks.rendererSandbox) throw new Error('The app renderer has access to Node.');
  fs.writeFileSync(path.join(state, 'desktop-smoke.png'), (await window.webContents.capturePage()).toPNG());
  await wait(`window._igDirty === true`, 'unsaved project indicator');
  return { checks, runtimeDirectory: runtime, exportedLog: destination };
};
