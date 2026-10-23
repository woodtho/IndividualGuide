'use strict';
// Called by an isolated copy of the real desktop shell, never by normal app use.
// Screens are captured from live windows. No interface is drawn or substituted.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {Menu,dialog,desktopCapturer,screen}=require('electron');
module.exports=async({window,pause,state,rendererCommand})=>{
  const root=process.env.IG_BOOK_ROOT || path.resolve(__dirname,'..');
  const language=process.env.IG_BOOK_LANGUAGE||'en-CA';
  if(!['en-CA','fr-CA'].includes(language))throw Error('Unsupported capture language.');
  const french=language==='fr-CA';
  const book=path.join(root,'docs/book',french?'fr-CA':'');
  const assets=path.join(book,'assets');
  const evidence=path.join(root,'artifacts/book-review',french?'fr-CA':'');
  fs.mkdirSync(assets,{recursive:true});fs.mkdirSync(path.join(book,'data'),{recursive:true});
  const translate=require('./i18n.cjs').create(require('./i18n.cjs').catalog,language).translate;
  fs.mkdirSync(evidence,{recursive:true});
  const reference=JSON.parse(fs.readFileSync(path.join(root,'docs/book/data/app-reference.json'),'utf8'));
  const resume=process.env.IG_BOOK_RESUME==='1';
  const records=resume&&fs.existsSync(path.join(evidence,'screenshots-in-progress.json'))?JSON.parse(fs.readFileSync(path.join(evidence,'screenshots-in-progress.json'),'utf8')).filter(record=>record.language===language&&record.packageVersion===reference.package_version&&fs.existsSync(path.join(book,record.file))):[];
  const panels=resume&&fs.existsSync(path.join(evidence,'ui-inventory.json'))?JSON.parse(fs.readFileSync(path.join(evidence,'ui-inventory.json'),'utf8')):[];
  const practice=process.env.IG_BOOK_PRACTICE;
  if(!practice||!fs.existsSync(practice))throw Error('Supply an existing, isolated IG_BOOK_PRACTICE folder.');
  const practiceName=path.basename(practice);
  const drive=path.parse(practice).root.replace(/[\\/]+$/,'');
  const practiceParts=path.relative(path.parse(practice).root,practice).split(/[\\/]+/);
  const js=async code=>{
    // A navigation can strand an evaluation submitted to the old document.
    // Bound each attempt so the existing wait deadline can retry or report it.
    let timer;
    try{return await Promise.race([window.webContents.executeJavaScript(code,true),
      new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Capture JavaScript context unavailable')),6000);})]);}
    finally{clearTimeout(timer);}
  };
  const menu=id=>Menu.getApplicationMenu().getMenuItemById(id);
  const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
  let openedExample=false;
  async function wait(test,label){
    const deadline=Date.now()+120000;
    while(Date.now()<deadline){
      try{if(await test())return;}catch(error){
        if(!/Execution context.*destroyed|Cannot execute JavaScript before document|Capture JavaScript context unavailable/i.test(error.message))throw error;
      }
      await pause(100);
    }
    fs.writeFileSync(path.join(evidence,'capture-failure.png'),(await window.webContents.capturePage()).toPNG());
    fs.writeFileSync(path.join(evidence,'capture-failure.txt'),await js('document.body.innerText'));
    throw Error('Book capture timed out: '+label);
  }
  const idle=()=>wait(()=>menu('save').enabled,'editable workspace');
  async function settle(){await js('document.fonts.ready.then(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))))');await pause(350);}
  async function shot(name,{selector,description,example,task,tab,zoom=1.2,nativeMenu}={}){
    if(records.some(record=>record.id===name))return;
    if(window.isMaximized())window.unmaximize();
    window.setBounds({x:area.x,y:area.y,width:Math.min(1180,area.width),height:Math.min(860,area.height)});
    window.webContents.setZoomFactor(zoom);await settle();
    if(['script-outputs','logging-preview'].includes(name)){
      await js(`document.querySelector(${JSON.stringify(selector)}).scrollIntoView({block:'center'})`);await settle();
    }
    await js("document.activeElement?.blur();document.documentElement.style.scrollBehavior='auto';document.querySelectorAll('.shiny-notification-close').forEach(b=>b.click())");
    await wait(()=>js("document.querySelectorAll('#shiny-notification-panel .shiny-notification').length===0"),'dismiss transient notifications');
    const privatePaths=await js(`(()=>{const root=document.querySelector(${JSON.stringify(selector||'body')});const text=root.innerText+' '+[...root.querySelectorAll('input,textarea')].filter(e=>e.getClientRects().length).map(e=>e.value).join(' ');return /[A-Za-z]:[\\\\/]Users[\\\\/]/i.test(text);})()`);
    if(privatePaths){
      fs.writeFileSync(path.join(evidence,'private-path-context.txt'),await js(`document.querySelector(${JSON.stringify(selector||'body')}).innerText`));
      throw Error('Private path visible in capture '+name+'; choose the practice folder first.');
    }
    let image,region;
    if(nativeMenu){
      const item=Menu.getApplicationMenu().items.find(item=>item.label.replaceAll('&','')===translate(nativeMenu));
      if(!item?.submenu)throw Error('Missing native menu: '+nativeMenu);
      window.setAlwaysOnTop(true);window.show();window.moveTop();window.focus();await pause(600);item.submenu.popup({window,x:8,y:2});await pause(500);
      const display=screen.getDisplayMatching(window.getBounds());
      const sources=await desktopCapturer.getSources({types:['screen'],thumbnailSize:{width:Math.round(display.size.width*display.scaleFactor),height:Math.round(display.size.height*display.scaleFactor)}});
      const source=sources.find(source=>source.display_id===String(display.id))||sources[0];
      const size=source.thumbnail.getSize(),bounds=window.getBounds(),sx=size.width/display.bounds.width,sy=size.height/display.bounds.height;
      region={x:Math.max(0,Math.round((bounds.x-display.bounds.x)*sx)),y:Math.max(0,Math.round((bounds.y-display.bounds.y)*sy)),width:Math.round(bounds.width*sx),height:Math.round(bounds.height*sy)};
      region.width=Math.min(region.width,size.width-region.x);region.height=Math.min(region.height,size.height-region.y);
      image=source.thumbnail.crop(region);
      // Keep the real native menu and its title bar; omit the distant canvas.
      const crop={x:0,y:0,width:Math.min(french?800:620,image.getSize().width),height:Math.min(nativeMenu==='File'?1060:440,image.getSize().height)};
      image=image.crop(crop);region={...region,menuCrop:crop};
      item.submenu.closePopup(window);
    }else{
      if(selector){
        region=await js(`(()=>{const e=document.querySelector(${JSON.stringify(selector)});if(!e)throw Error('Capture target missing');const r=e.getBoundingClientRect();return{x:Math.max(0,Math.floor(r.x)),y:Math.max(0,Math.floor(r.y)),width:Math.min(innerWidth-Math.max(0,Math.floor(r.x)),Math.ceil(r.width)),height:Math.min(innerHeight-Math.max(0,Math.floor(r.y)),Math.ceil(r.height))};})()`);
        if(region.width<100||region.height<100)throw Error('Capture target is hidden: '+selector);
        const factor=window.webContents.getZoomFactor();
        region={x:Math.round(region.x*factor),y:Math.round(region.y*factor),width:Math.round(region.width*factor),height:Math.round(region.height*factor)};
        image=await window.webContents.capturePage(region);
      }else image=await window.webContents.capturePage();
    }
    const bytes=image.toPNG(),size=image.getSize();
    const file='ui-'+name+'.png';fs.writeFileSync(path.join(assets,file),bytes);
    records.push({id:name,file:'assets/'+file,description,example:example||null,task:task||null,tab:tab||null,
      source:'live Individual Guide desktop application',packageVersion:reference.package_version,language,
      pixels:size,zoom,region:region||null,sha256:hash(bytes),capturedAt:new Date().toISOString()});
    fs.writeFileSync(path.join(evidence,'screenshots-in-progress.json'),JSON.stringify(records,null,2)+'\n');
    console.log('Captured '+name+' '+size.width+'x'+size.height);
  }
  async function openExample(example){
    console.log('Review example '+example.id);
    if(openedExample){
      // Keep form observers and unsaved practice edits from one example out
      // of the next capture. This restarts only the isolated book profile.
      menu('restart-r').click();
      let discarded=false;
      await wait(async()=>{
        if(!discarded&&await js("Boolean(document.querySelector('.modal.show #recover_discard')?.classList.contains('shiny-bound-input'))")){
          await js("document.querySelector('.modal.show #recover_discard').click()");discarded=true;
        }
        return menu('open').enabled&&await js("Boolean(document.querySelector('.modal.show #splash_fresh')?.classList.contains('shiny-bound-input'))&&!bootstrap.Modal.getInstance(document.querySelector('.modal.show'))?._isTransitioning");
      },'fresh example session');
      await js("document.querySelector('.modal.show #splash_fresh').click()");await idle();
    }
    await idle();menu('help').click();
    await wait(()=>js("Boolean(document.querySelector('.modal.show #help_example_iris'))&&!bootstrap.Modal.getInstance(document.querySelector('.modal.show'))?._isTransitioning"),'example catalogue visible');
    await js(`document.querySelector('[data-value="examples"]').click();document.getElementById(${JSON.stringify('help_example_'+example.id)}).click()`);
    await wait(()=>window.getTitle().includes(example.title)&&menu('save').enabled,'example '+example.id);
    openedExample=true;
    await pause(300);
  }
  async function openTask(task){
    console.log('Review task '+task.type+'/'+task.id);
    await js(`Shiny.setInputValue('tree_task_click',${JSON.stringify(task.id)},{priority:'event'})`);
    await wait(()=>js(`(()=>{const p=document.getElementById(${JSON.stringify('panel_'+task.id)});return p?.getClientRects().length&&p.dataset.igReadyToken&&Object.entries(Shiny.shinyapp.$inputValues).some(([key,value])=>key.endsWith(${JSON.stringify('_'+task.id+'-ig_ready')})&&value===p.dataset.igReadyToken);})()`),'task '+task.id);
    await pause(800);await idle();
    await wait(()=>js("!document.documentElement.classList.contains('shiny-busy')&&Shiny.shinyapp.$socket.readyState===1"),'task inputs settled');
    if(task.params?.input_table)await wait(()=>js(`(()=>{const e=document.querySelector('#panel_${task.id} select[id$="-input_table"]');return !e||e.value===${JSON.stringify(task.params.input_table)}})()`),'selected input '+task.id);
    await settle();
  }
  async function freshFilter(){
    await js("document.getElementById('btn_add_task').click()");
    await wait(()=>js("Boolean(document.querySelector('[onclick*=picker_select][onclick*=filter_sort]'))"),'Filter and Sort picker');
    await js("document.querySelector('[onclick*=picker_select][onclick*=filter_sort]').click()");
    const task={id:'filtersort_1',type:'filter_sort'};await openTask(task);
    await wait(()=>js("Boolean(document.querySelector('#panel_filtersort_1 select[id$=\"-input_table\"]')?.selectize.options.states)"),'fresh filter source available');
    await js("(()=>{const e=document.querySelector('#panel_filtersort_1 select[id$=\"-input_table\"]');e.selectize.setValue('states');})()");await settle();
    await js("document.querySelector('#panel_filtersort_1 button[id$=\"-add_filter\"]').click()");await settle();
    await wait(()=>js("document.querySelector('#panel_filtersort_1 select[id*=\"-ffcol_\"]')?.value==='Population'&&!document.documentElement.classList.contains('shiny-busy')"),'fresh filter columns');
    await wait(()=>js("(()=>{const e=document.querySelector('#panel_filtersort_1 input[id*=\"-fval_\"]');return e?.classList.contains('shiny-bound-input')&&Object.keys(Shiny.shinyapp.$inputValues).some(key=>key.split(':')[0]===e.id);})()"),'bound filter value');
    // The initial column/operator bindings can replace the first value input.
    // Wait for their reactive flush and the final numeric element before typing.
    await wait(()=>js("(()=>{const p=document.getElementById('panel_filtersort_1'),e=p.querySelector('input[id*=\"-fval_\"]'),c=p.querySelector('select[id*=\"-ffcol_\"]'),o=p.querySelector('select[id*=\"-ffop_\"]'),v=Shiny.shinyapp.$inputValues;return e?.type==='number'&&c?.value==='Population'&&[c,o].every(n=>Object.entries(v).some(([k,x])=>k.split(':')[0]===n.id&&x===n.value))&&!document.documentElement.classList.contains('shiny-busy');})()"),'numeric filter column and operator acknowledged');
    await js("window._bookFilterValue=document.querySelector('#panel_filtersort_1 input[id*=\"-fval_\"]')");
    await pause(1200);
    await wait(()=>js("window._bookFilterValue===document.querySelector('#panel_filtersort_1 input[id*=\"-fval_\"]')&&!document.documentElement.classList.contains('shiny-busy')"),'stable filter value element');
    await js("(()=>{const e=document.querySelector('#panel_filtersort_1 input[id*=\"-fval_\"]');e.value='3615';e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));})()");await settle();
    await wait(()=>js("(()=>{const e=document.querySelector('#panel_filtersort_1 input[id*=\"-fval_\"]');return e?.value==='3615'&&Object.entries(Shiny.shinyapp.$inputValues).some(([key,value])=>key.split(':')[0]===e.id&&String(value)==='3615')&&!document.documentElement.classList.contains('shiny-busy');})()"),'filter value settled and sent');
    await js("document.getElementById('panel_run_btn_filtersort_1').click()");
    await wait(()=>js("Boolean(document.querySelector('#panel_status_filtersort_1 .ig-status-success'))"),'fresh filter run');
    await tab(task,'Results');
    await wait(()=>js("[...document.querySelectorAll('#panel_filtersort_1 table.dataTable')].some(table=>jQuery.fn.dataTable.isDataTable(table)&&jQuery(table).DataTable().page.info()?.recordsTotal===1)"),'one state matches Population 3615');
    await tab(task,'Filter Data');
    await wait(()=>js("document.querySelector('#panel_filtersort_1 input[id*=\"-fval_\"]')?.value==='3615'"),'filter condition retained');
    return task;
  }
  async function tab(task,text){
    const found=await js(`(()=>{const p=document.getElementById(${JSON.stringify('panel_'+task.id)});const a=[...p.querySelectorAll('a[data-bs-toggle="tab"],a[data-toggle="tab"]')].find(a=>a.getAttribute('data-value')===${JSON.stringify(text)}||a.textContent.trim()===${JSON.stringify(translate(text))});if(!a)return false;a.click();return true;})()`);
    if(!found)throw Error('Missing task tab: '+task.type+'/'+text);
    await settle();
  }
  async function setLogDestination(task){
    await js(`document.querySelector('#panel_${task.id} select[id$="-format"]').selectize.setValue('csv');document.querySelector('#panel_${task.id} select[id$="-min_level"]').selectize.setValue('INFO')`);
    await js(`(()=>{const e=document.querySelector('#panel_${task.id} input[id$="-path"]');e.value=${JSON.stringify(path.join(practice,'pipeline-log.csv'))};e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));document.querySelector('#panel_${task.id} .ig-log-export-preview').open=false;})()`);
    await settle();await js(`document.getElementById('panel_run_btn_${task.id}').click()`);
    await wait(()=>js(`document.querySelector('#panel_${task.id} [id$="-result"]')?.textContent.includes('pipeline-log.csv')`),'log exported to public practice path');
  }
  async function closeModal(){
    await wait(()=>js("Boolean(document.querySelector('.modal.show'))&&!bootstrap.Modal.getInstance(document.querySelector('.modal.show'))?._isTransitioning"),'dialog opening animation');
    await js("document.querySelector('.modal.show .modal-footer [data-bs-dismiss=modal],.modal.show .modal-footer [data-dismiss=modal]')?.click()");
    await wait(()=>js("!document.querySelector('.modal.show')"),'close dialog');await idle();
  }
  const area=screen.getPrimaryDisplay().workArea;
  window.setBounds({x:area.x,y:area.y,width:Math.min(1180,area.width),height:Math.min(860,area.height)});
  window.webContents.setZoomFactor(1.2);
  window.webContents.setBackgroundThrottling(false);
  window.setAlwaysOnTop(true);window.show();window.moveTop();
  const originalMessage=dialog.showMessageBox,originalSave=dialog.showSaveDialog;
  dialog.showMessageBox=async()=>({response:1});
  try{
    await wait(()=>menu('open').enabled&&js("Boolean(document.getElementById('splash_fresh')?.classList.contains('shiny-bound-input'))"),'welcome');
    await wait(()=>js(`Boolean(document.querySelector('.modal.show .ig-splash'))&&window.igI18n?.locale===${JSON.stringify(language)}&&!bootstrap.Modal.getInstance(document.querySelector('.modal.show'))?._isTransitioning`),'welcome dialog visible in '+language);
    await shot('welcome',{selector:'.modal.show .modal-dialog',description:'Welcome choices before opening a project'});
    await js("document.getElementById('splash_fresh').click()");await idle();
    const iris=reference.examples.find(example=>example.id==='iris');await openExample(iris);
    dialog.showSaveDialog=async()=>({canceled:false,filePath:path.join(practice,'flower-practice.igpx')});
    await rendererCommand('save');await idle();dialog.showSaveDialog=originalSave;
    await shot('workspace',{description:'Project tree, active flow, and task navigation',example:'iris'});
    await shot('file-menu',{description:'Actual Windows File menu with Save and Save As',example:'iris',nativeMenu:'File'});
    await shot('session-menu',{description:'Actual Windows Session menu with restart and diagnostic commands',example:'iris',nativeMenu:'Session'});
    menu('help').click();await wait(()=>js("Boolean(document.getElementById('help_example_iris'))"),'Help');
    await js("document.querySelector('[data-value=\"examples\"]').click();const t=document.getElementById('ig-example-type');t.value='summary_stats';t.dispatchEvent(new Event('change'))");
    await shot('examples',{selector:'.modal.show .modal-dialog',description:'Find working projects with the Task type filter',example:'iris'});await closeModal();
    const selected={
      summary_stats:'summary-settings',summary_tables:'group-summary',scatter_plot:'chart-settings',
      remove_dups:'cleaning',import_data:'import',query_builder:'query',filter_sort:'filter',
      stack_columns:'reshape',random_sample:'sample',one_way_freq:'frequencies',bar_chart:'bar-chart',
      linear_regression:'regression',life_tables:'survival',arima_forecast:'forecast',
      control_charts:'control-chart',branch:'branch',loop:'loop',report:'report-content',export_log:'export-log',export:'export'
    };
    const seen=new Set(panels.map(panel=>panel.type));
    const needs=task=>!seen.has(task.type)||(selected[task.type]&&!records.some(record=>record.id===selected[task.type]))||(task.type==='summary_stats'&&!records.some(record=>record.id==='summary-result'));
    for(const example of reference.examples){
      if(!example.tasks.some(needs))continue;
      await openExample(example);
      for(const savedTask of example.tasks){
        if(!needs(savedTask))continue;
        // The 0.4.0 query-joins example has a saved filter without row IDs.
        // Opening it disconnects Shiny. Review the unchanged app's fresh form
        // instead, and record the limitation in the editorial review.
        const task=savedTask.type==='filter_sort'?await freshFilter():savedTask;
        if(task===savedTask)await openTask(task);seen.add(task.type);
        if(task.type==='import_data'){
          await js(`(()=>{const e=document.querySelector('#panel_${task.id} [id$="-file_picker"]');Shiny.setInputValue(e.id,{root:${JSON.stringify(drive)},files:[${JSON.stringify([...practiceParts,'state-statistics.csv'])}]},{priority:'event'});})()`);
          await wait(()=>js(`document.getElementById('panel_${task.id}').innerText.includes(${JSON.stringify(practiceName)})`),'public practice import path');
          await js(`(()=>{const e=document.querySelector('#panel_${task.id} input[id$="-output_name"]');e.value='states';e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));})()`);
          await settle();
          await js(`document.querySelector('#panel_${task.id} button[id$="-btn_refresh"]').click()`);
          await wait(()=>js(`[...document.querySelectorAll('#panel_${task.id} table.dataTable')].some(table=>jQuery.fn.dataTable.isDataTable(table)&&jQuery(table).DataTable().page.info()?.recordsTotal===50)`),'50 state rows imported');
          await tab(task,'Setup');
        }
        if(task.type==='query_builder'){
          await wait(()=>js(`document.querySelector('#panel_${task.id} select[id$="-src_table"]')?.value==='states'`),'query source selected');
          await js(`document.querySelector('#panel_${task.id} button[id$="-sel_all"]').click()`);
          await wait(()=>js(`document.querySelectorAll('#panel_${task.id} [id*="alias_"]').length>0`),'query columns selected');
        }
        if(task.type==='export'){
          await js(`(()=>{const e=document.querySelector('#panel_${task.id} [id$="-dir_pick"]');Shiny.setInputValue(e.id,{root:${JSON.stringify(drive)},path:${JSON.stringify(practiceParts)}},{priority:'event'});})()`);
          await wait(()=>js(`document.getElementById('panel_${task.id}').innerText.includes(${JSON.stringify(practiceName)})`),'public practice export path');
        }
        if(task.type==='export_log'){
          await setLogDestination(task);
        }
        const inventory=await js(`(()=>{const p=document.getElementById(${JSON.stringify('panel_'+task.id)});return {title:p.querySelector('h1,h2,h3,h4,.card-header')?.textContent.trim(),tabs:[...p.querySelectorAll('a[data-bs-toggle="tab"],a[data-toggle="tab"]')].map(a=>a.textContent.trim()),labels:[...p.querySelectorAll('label')].map(l=>l.textContent.trim()).filter(Boolean),buttons:[...p.querySelectorAll('button')].map(b=>({text:b.textContent.trim(),title:b.title,aria:b.getAttribute('aria-label')})).filter(b=>b.text||b.title||b.aria)};})()`);
        const old=panels.findIndex(panel=>panel.type===task.type);
        const reviewed={type:task.type,example:example.id,task:task.id,...inventory};
        if(old<0)panels.push(reviewed);else panels[old]=reviewed;
        fs.writeFileSync(path.join(evidence,'ui-inventory.json'),JSON.stringify(panels,null,2)+'\n');
        if(selected[task.type])await shot(selected[task.type],{selector:'#panel_'+task.id,description:'Configured '+reference.registry.find(t=>t.id===task.type).label+' task',example:example.id,task:task.id});
        if(task.type==='summary_stats'){
          await tab(task,'Results');await tab(task,'Data');
          await wait(()=>js(`Boolean(document.querySelector('#panel_${task.id} .dataTables_wrapper tbody tr,#panel_${task.id} .dt-container tbody tr')?.innerText.includes('Sepal'))`),'summary data rendered');
          await shot('summary-result',{selector:'#panel_'+task.id,description:'Check the summary table after running',example:example.id,task:task.id,tab:'Results > Data'});
        }
        if(task.type==='report'){
          await tab(task,'Appearance');await shot('report-log',{selector:'#panel_'+task.id,description:'Output format, report title, and pipeline-log appendix',example:example.id,task:task.id,tab:'Appearance'});
        }
      }
    }
    await openExample(iris);
    for(const task of iris.tasks.filter(task=>task.type==='export')){
      await openTask(task);
      await js(`(()=>{const e=document.querySelector('#panel_${task.id} [id$="-dir_pick"]');Shiny.setInputValue(e.id,{root:${JSON.stringify(drive)},path:${JSON.stringify(practiceParts)}},{priority:'event'});})()`);
      await wait(()=>js(`document.getElementById('panel_${task.id}').innerText.includes(${JSON.stringify(practiceName)})`),'public export destination');
    }
    const logTask=iris.tasks.find(task=>task.type==='export_log');await openTask(logTask);await setLogDestination(logTask);
    await openTask(iris.tasks[0]);
    await js("document.querySelector('#panel_example_source textarea[id$=\"-output_defs\"]').parentElement.scrollIntoView({block:'center'})");
    await shot('script-outputs',{selector:'#panel_example_source .shiny-input-container:has(> textarea[id$="-output_defs"])',description:'Declare the named table created by the copied Script',example:'iris',task:'example_source'});
    await js("const d=document.querySelector('#panel_example_source details');d.querySelector('summary').scrollIntoView({block:'start'});d.open=true");
    await shot('logging',{selector:'#panel_example_source details',description:'Task logging rules and message-field controls',example:'iris',task:'example_source'});
    await js("document.querySelector('#panel_example_source .ig-log-preview-grid').scrollIntoView({block:'center'})");
    await shot('logging-preview',{selector:'#panel_example_source .ig-log-preview-grid > div:last-child',description:'Preview a rendered entry and file format without running the task',example:'iris',task:'example_source'});
    menu('console').click();await wait(()=>js("Boolean(document.querySelector('#panel_console')?.getClientRects().length)&&!document.querySelector('#r_console-run').disabled"),'console');
    await js("document.getElementById('r_console-editor').value='2 + 3';document.getElementById('r_console-run').click()");
    await wait(()=>js("document.getElementById('r_console-transcript').textContent.includes('[1] 5')&&document.querySelector('.ig-console').dataset.busy==='false'"),'console result 5');
    await shot('console',{selector:'#panel_console .ig-console',description:'R Console command area and project-data controls',example:'iris'});
    menu('tasks').click();await wait(()=>js("Boolean(document.querySelector('.ig-accessible-task-row'))"),'task list');
    await shot('task-list',{selector:'.modal.show .modal-dialog',zoom:1.5,description:'Search and open tasks without selecting canvas shapes',example:'iris'});await closeModal();
    menu('validate').click();await wait(()=>js("Boolean(document.querySelector('.modal.show .ig-preflight-row,.modal.show .alert-success'))"),'validation');
    await shot('validation',{selector:'.modal.show .modal-dialog',zoom:1.5,description:'Validate the flow before a run',example:'iris'});await closeModal();
    menu('settings').click();await wait(()=>js("Boolean(document.querySelector('#preferences-search'))"),'Settings');
    await shot('settings',{selector:'.modal.show .modal-dialog',description:'Settings for appearance, previews, saved versions, and task runs',example:'iris'});await closeModal();
    menu('review').click();await wait(()=>js("Boolean(document.querySelector('.modal.show .ig-review-dashboard'))"),'Review dashboard');
    await shot('review',{selector:'.modal.show .modal-dialog',zoom:1.5,description:'Review status, notes, and outstanding issues',example:'iris'});await closeModal();
    menu('code').click();await wait(()=>js("Boolean(document.querySelector('#code-dl_bundle')?.getClientRects().length)"),'Code export');
    await js("document.querySelector('#code-view input[value=complete]').click()");
    await wait(()=>js("document.getElementById('code-code_display')?.textContent.includes('Generated by Individual Guide')&&Boolean(document.getElementById('code-dl_bundle')?.getAttribute('href'))"),'complete generated script and download ready');
    await shot('code',{selector:'#panel_code',description:'Download the complete script or a bundle with supporting functions',example:'iris'});
    menu('shiny-apps').click();
    await wait(()=>js("!document.getElementById('ig-shiny-apps').hidden"),'Shiny app browser');
    await shot('shiny-app-picker',{selector:'#ig-shiny-apps',description:'Choose an app.R file or a two-file app folder; the main workspace stays open',example:null});
    const shinyApp=path.join(root,'inst/shiny-apps/iris-explorer/app.R');
    const shinyRoot=path.parse(shinyApp).root.replace(/[\\/]$/,'');
    const shinyParts=path.relative(path.parse(shinyApp).root,shinyApp).split(path.sep);
    await js(`Shiny.setInputValue('sf_shiny_app',${JSON.stringify({root:shinyRoot,files:[shinyParts]})},{priority:'event'})`);
    await wait(()=>js("document.getElementById('ig-app-path').textContent.endsWith('iris-explorer')"),'practice Shiny app selected');
    await js("document.getElementById('ig-app-trust').checked=true;document.getElementById('ig-app-trust').dispatchEvent(new Event('change'));document.getElementById('ig-app-run').click()");
    await wait(()=>js("!igShinyApps.pending&&igShinyApps.state.phase==='ready'"),'practice app running');
    const guestURL=await js('igShinyApps.state.url');
    const guest=()=>window.webContents.mainFrame.frames.find(frame=>frame.url.startsWith(guestURL));
    await wait(()=>guest()?.executeJavaScript("document.getElementById('count')?.textContent==='150 flowers'"),'practice app output');
    if(language==='fr-CA') {
      await guest().executeJavaScript("document.getElementById('language').value='fr';document.getElementById('language').dispatchEvent(new Event('change',{bubbles:true}))");
      await wait(()=>guest()?.executeJavaScript("document.getElementById('count')?.textContent==='150 fleurs'&&!document.documentElement.classList.contains('shiny-busy')"),'French practice app');
    }
    await wait(()=>guest()?.executeJavaScript("Boolean(document.querySelector('#chart img')?.naturalWidth)&&!document.querySelector('#chart.recalculating')"),'practice chart rendered');
    await shot('shiny-app-running',{selector:'#ig-shiny-apps',description:'A real interactive app inside Individual Guide, with workspace, switch, log and close controls',example:null});
    await js("document.getElementById('ig-app-close').click();document.getElementById('ig-app-confirm-close').click()");
    await wait(()=>js("igShinyApps.state.phase==='idle'&&!igShinyApps.pending"),'practice app closed');
    await js("document.getElementById('ig-app-back').click()");
    fs.writeFileSync(path.join(book,'data/screenshots.json'),JSON.stringify({packageVersion:reference.package_version,language,referenceSha256:hash(fs.readFileSync(path.join(root,'docs/book/data/app-reference.json'))),source:'Real application captures with public tutorial data',screenshots:records,reviewedTaskPanels:panels},null,2)+'\n');
    return{ok:true,checks:{screenshots:true,allTaskPanels:seen.size===58},screenshots:records.length,taskPanels:seen.size};
  }finally{window.setAlwaysOnTop(false);dialog.showMessageBox=originalMessage;dialog.showSaveDialog=originalSave;}
};
