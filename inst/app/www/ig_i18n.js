/* Translate presentation in place. Values, bindings and analytical data stay put. */
(function () {
  'use strict';
  const key = 'IndividualGuideLanguage';
  const texts = new WeakMap(), attributes = new WeakMap(), choices = new WeakMap();
  const searchSources=new WeakMap();
  const pending = new Set();
  const skip = 'script,style,pre,code,.ace_editor,.ig-console-editor,.ig-console-transcript,' +
    '.html-widget svg,.html-widget canvas,.vis-tooltip,' +
    '.ig-tree-label,.ig-tree-project-title strong,.ig-tab-label,'+
    '.ig-console-completions button,.ig-console-history-item,'+
    '.ig-comment-title,.ig-comment-text,.ig-comment-byline strong,.ig-collab-target,.ig-avatar,'+
    '.ig-issue-title,.ig-issue-detail,.ig-accessible-task-row strong,.ig-preflight-row strong,'+
    '.ig-log-preview-message,.ig-log-input-table tbody td:last-child,'+
    '.sF-fileList .sF-file:not(.sF-file-header),.sF-fileList .sF-directory,'+
    '.sF-dirList .sF-file-name,.sF-dirContent .sF-file-name,.sF-breadcrumps,'+
    '[data-ig-user-content],[data-ig-no-translate]';
  const metadataTables='#history_dt,#global_search_dt,#project_tools-files,#project_tools-runs';
  function metadataHeader(element){return Boolean((element?.closest('.dataTable thead')&&element.closest(metadataTables))||element?.closest('.sF-file-header'));}
  let engine, frame, applying = false, observer;
  let canvasTypes = {};
  const canvasStates=new WeakMap(),canvasImages=new Map();
  const cookie = () => document.cookie.split(';').map(value=>value.trim()).find(value=>value.startsWith(key+'='))?.slice(key.length+1);
  function stored() { try { return cookie() || localStorage.getItem(key); } catch { return cookie(); } }
  function save(locale) {
    try { localStorage.setItem(key,locale); } catch {}
    document.cookie = key+'='+locale+';path=/;max-age=31536000;SameSite=Strict';
  }
  function excluded(element) {
    if (!element || element.closest(skip)) return true;
    if(element.closest('.dataTable')&&!metadataHeader(element))return true;
    const dropdown=element.closest('.selectize-input,.selectize-dropdown');
    if(dropdown && !dropdown.closest('[data-ig-choice-labels="true"]'))return true;
    if (element.closest('option,optgroup')) return true;
    const choice = element.closest('[data-ig-choice-labels="false"]');
    return Boolean(choice && element.closest('.shiny-options-group'));
  }
  function text(node) {
    if (!node.parentElement || node.parentElement.closest('input,textarea') || excluded(node.parentElement) || !node.data.trim()) return;
    let state = texts.get(node);
    if (!state || node.data !== state.rendered) state = { source:node.data };
    const headings={when:'Time',user:'User',type:'Type',id:'ID',action:'Action',summary:'Summary',task:'Task',file:'File',exists:'Exists',bundled:'Bundled',name:'Name',size:'Size',modified:'Modified',created:'Created',accessed:'Accessed'};
    const source=engine.locale==='fr-CA'&&metadataHeader(node.parentElement)?headings[state.source.trim()]||state.source:state.source;
    state.rendered = engine.translate(source);
    texts.set(node,state);
    if (node.data !== state.rendered) node.data = state.rendered;
  }
  function element(node) {
    if (excluded(node) && !node.matches('input,textarea')) return;
    let state = attributes.get(node);
    if (!state) { state = {}; attributes.set(node,state); }
    for (const name of ['title','aria-label','aria-description','placeholder','alt']) {
      const current = node.getAttribute(name);
      if (current == null) continue;
      let item = state[name];
      if (!item || current !== item.rendered) item = {source:current};
      item.rendered = engine.translate(item.source); state[name] = item;
      if (current !== item.rendered) node.setAttribute(name,item.rendered);
    }
  }
  function localizeChoices(root) {
    const containers = root.matches?.('[data-ig-choice-labels="true"]') ? [root] : [];
    containers.push(...root.querySelectorAll?.('[data-ig-choice-labels="true"]') || []);
    for (const container of containers) for (const select of (container.matches('select') ? [container] : container.querySelectorAll('select'))) {
      let state = choices.get(select);
      if (!state) { state = new Map(); choices.set(select,state); }
      const control = select.selectize;
      let changed = false;
      const values=control ? Object.keys(control.options) : Array.from(select.options,option=>option.value);
      for (const id of values) {
        const option=Array.from(select.options).find(option=>option.value===id),live=control?.options[id];
        const current = live ? live[control.settings.labelField] : option.textContent;
        let item = state.get(id);
        if (!item || (current !== item.rendered && current !== item.source)) item = {source:current};
        item.rendered = engine.translate(item.source); state.set(id,item);
        if (!control && option && option.textContent !== item.rendered) option.textContent = item.rendered;
        if (live && live.igLocaleSearch !== item.rendered) {
          live.igLocaleSearch=item.rendered; changed=true;
        }
      }
      if (control) {
        // Render canonical option labels as ordinary translated text. Keep the
        // plugin's labels/values unchanged, adding only a French search field.
        // This avoids rebuilding selected items or disturbing an active editor.
        for(const node of [control.$control[0],control.$dropdown[0]])if(node){
          if(node.getAttribute('data-ig-choice-labels')!=='true')node.setAttribute('data-ig-choice-labels','true');
          queue(node);
        }
        if(changed){
          control.settings.searchField=[...new Set([].concat(control.settings.searchField||[], 'igLocaleSearch'))];
          control.lastQuery=null;control.refreshOptions(false);
        }
      }
    }
  }
  function apply(root) {
    if (!engine || !root?.isConnected) return;
    if (root.nodeType === Node.TEXT_NODE) { text(root); return; }
    if (root.nodeType !== Node.ELEMENT_NODE || (root.closest(skip) && !root.matches('input,textarea'))) return;
    element(root);
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT|NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node=walker.currentNode;
      if (node.nodeType===Node.TEXT_NODE) text(node); else element(node);
    }
    localizeChoices(root);
    localizeSearch(root);
  }
  function localizeSearch(root){
    const selector='.ig-task-item[data-label],.ig-help-task[data-label]';
    const rows=root.matches?.(selector)?[root]:[];
    rows.push(...root.querySelectorAll?.(selector)||[]);
    for(const row of rows){
      let source=searchSources.get(row);
      if(source===undefined){source=row.getAttribute('data-label');searchSources.set(row,source);}
      row.setAttribute('data-label',(source+' '+row.textContent).replace(/\s+/g,' ').toLocaleLowerCase());
    }
  }
  function queue(root) {
    if (!root || !engine) return;
    const element=root.nodeType===Node.TEXT_NODE?root.parentElement:root;
    // Code highlighting and console output can change many times per second.
    // They contain user content, so they need no translation or graph scan.
    if(element?.closest?.(skip)&&!element.matches?.('input,textarea'))return;
    if(root.nodeType===Node.TEXT_NODE&&element?.closest('.dataTable')&&!metadataHeader(element))return;
    pending.add(root);
    if (frame) return;
    frame=requestAnimationFrame(()=>{
      frame=null; applying=true;
      try { for (const node of pending) apply(node); pending.clear(); localizeCanvases(); }
      finally { applying=false; }
    });
  }
  function localizeCanvases(){
    for(const element of document.querySelectorAll('.visNetwork')){
      const network=element.chart||document.getElementById('graph'+element.id)?.chart;
      const data=network?.body?.data?.nodes;
      if(!data?.get||!data?.update)continue;
      let state=canvasStates.get(data);
      if(!state){
        state=new Map();canvasStates.set(data,state);
        data.on('*',(event,properties,sender)=>{
          if(sender==='ig-language')return;
          if(event==='remove')for(const id of properties.items||[])state.delete(id);
          queue(element);
        });
      }
      const updates=[];
      for(const node of data.get()){
        if(typeof node.image!=='string'||!node.image.startsWith('data:image/svg+xml;base64,'))continue;
        let item=state.get(node.id);
        if(!item||node.image!==item.rendered)item={source:node.image};
        let rendered=item.source;
        if(engine.locale==='fr-CA'){
          const key=engine.locale+' '+item.source;
          rendered=canvasImages.get(key);
          if(!rendered){
            const bytes=Uint8Array.from(atob(item.source.split(',')[1]),value=>value.charCodeAt(0));
            const svg=new DOMParser().parseFromString(new TextDecoder().decode(bytes),'image/svg+xml');
            // Only the app's flow-card slots are labels. Names above the card,
            // badge values, IDs, links and positions retain their source values.
            const type=svg.querySelector('text[x="100"][y="124"]');
            const status=svg.querySelector('text[x="100"][y="182"]');
            if(svg.documentElement.getAttribute('viewBox')==='0 0 200 198'&&!svg.querySelector('parsererror')){
              if(type&&canvasTypes[node.group]){
                const label=engine.translate(canvasTypes[node.group]),characters=Array.from(label);
                type.textContent=characters.length>18?characters.slice(0,17).join('')+'…':label;
                type.setAttribute('font-size',characters.length>13?'16':'19');
              }
              if(status){
                status.textContent=engine.translate(status.textContent);
                if(Array.from(status.textContent).length>20)status.setAttribute('font-size','14');
              }
              const encoded=new TextEncoder().encode(new XMLSerializer().serializeToString(svg.documentElement));
              rendered='data:image/svg+xml;base64,'+btoa(String.fromCharCode(...encoded));
            }else rendered=item.source;
            if(canvasImages.size>=4096)canvasImages.delete(canvasImages.keys().next().value);
            canvasImages.set(key,rendered);
          }
        }
        item.rendered=rendered;state.set(node.id,item);
        if(node.image!==rendered)updates.push({id:node.id,image:rendered});
      }
      if(updates.length)data.update(updates,'ig-language');
    }
  }
  function controls() {
    for (const id of ['ig-language-choice','ig-welcome-language','settings_language']) {
      const field = document.getElementById(id);
      if (!field) continue;
      if (field.selectize && field.selectize.getValue() !== engine.locale) field.selectize.setValue(engine.locale,true);
      else if (field.value !== engine.locale) field.value=engine.locale;
    }
  }
  async function setLanguage(value, fromDesktop) {
    const locale = IGLocale.normalize(value);
    engine.setLanguage(locale); save(locale);
    document.documentElement.lang=locale;
    applying=true; try { apply(document.body); controls(); localizeCanvases(); } finally { applying=false; }
    for(const id of ['task_search','help_task_search']){
      const field=document.getElementById(id);
      if(field?.value)field.dispatchEvent(new Event('input',{bubbles:true}));
    }
    if (window.Shiny?.setInputValue) Shiny.setInputValue('ig_language',locale,{priority:'event'});
    if (!fromDesktop && window.igDesktop?.setLanguage) await window.igDesktop.setLanguage(locale);
    window.dispatchEvent(new CustomEvent('ig:language-changed',{detail:{locale}}));
    return locale;
  }
  async function start() {
    const response = await fetch('www/i18n/fr-CA.json');
    if (!response.ok) throw new Error('The language file could not be loaded.');
    const catalog = await response.json();
    canvasTypes=catalog.taskTypes||{};
    const desktop = await window.igDesktop?.getLanguage?.();
    const language = desktop?.locale || stored() || navigator.languages?.[0] || navigator.language;
    engine=IGLocale.create(catalog,language);
    window.igI18n={translate:value=>engine.translate(value),setLanguage,
      get locale(){return engine.locale;},refresh:()=>queue(document.body)};
    await setLanguage(engine.locale,true);
    observer=new MutationObserver(records=>{
      if (applying) return;
      for (const record of records) {
        if (record.type==='childList') for (const node of record.addedNodes) queue(node);
        else queue(record.target);
      }
      controls();
    });
    observer.observe(document.body,{subtree:true,childList:true,characterData:true,attributes:true,
      attributeFilter:['title','aria-label','aria-description','placeholder','alt']});
    document.addEventListener('change',event=>{
      if (event.target.matches('.ig-language-picker')) setLanguage(event.target.value);
    });
    window.jQuery?.(document).on('change','#settings_language',function(){setLanguage(this.value);});
    window.jQuery?.(document).on('shiny:connected',()=>setLanguage(engine.locale,true));
    window.jQuery?.(document).on('shiny:bound',event=>queue(event.target.closest?.('[data-ig-choice-labels]') || event.target));
    window.igDesktop?.onLanguage?.(value=>setLanguage(value.locale,true));
  }
  function ready() { start().catch(error=>{
    console.error('Individual Guide language:',error.message);
    const field=document.getElementById('ig-language-choice');
    if(field){field.disabled=true;field.title='Language file unavailable / Fichier de langue non disponible';}
  }); }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',ready,{once:true}); else ready();
})();
