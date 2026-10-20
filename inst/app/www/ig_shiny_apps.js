/* The host chrome stays in Individual Guide; guest code stays in its own origin. */
(function () {
  'use strict';
  let state = {phase:'idle'}, selecting = true, selected, pending, serial = 0, lastFocus, inerted=[];
  const byId = id => document.getElementById(id);
  const text = value => window.igI18n?.translate(value) || value;
  const connected = () => window.Shiny?.shinyapp?.$socket?.readyState === 1;
  const active = () => ['starting','ready'].includes(state.phase);
  function retireFrame(frame) {
    const url=frame.getAttribute('src');
    if(url)window.dispatchEvent(new CustomEvent('ig:app-frame-retired',{detail:{url}}));
    frame.remove();
  }
  function workspaceInert(value) {
    if(!value) {inerted.forEach(node=>{node.inert=false;});inerted=[];return;}
    if(inerted.length)return;
    for(let node=byId('ig-shiny-apps');node&&node!==document.body;node=node.parentElement)
      for(const sibling of node.parentElement.children)
        if(sibling!==node && !sibling.inert && 'inert' in sibling && !sibling.matches('script,style,link,.modal,.modal-backdrop')) {
          sibling.inert=true;inerted.push(sibling);
        }
  }
  function showLog(value) {
    const panel=byId('ig-app-log-panel'),changed=panel.hidden===value;
    panel.hidden=!value;byId('ig-app-log').setAttribute('aria-expanded',String(value));
    if(changed&&connected())Shiny.setInputValue('app_host_log',value,{priority:'event'});
  }
  function action(name, extra) {
    if (!connected()) { byId('ig-app-error').textContent=text('Individual Guide is disconnected. Reconnect before opening another app.'); return; }
    pending=String(++serial);
    Shiny.setInputValue('app_host_action', {action:name,...extra,nonce:pending}, {priority:'event'});
    render();
  }
  function publish() { window.dispatchEvent(new CustomEvent('ig:app-host', {detail:{visible:!byId('ig-shiny-apps').hidden,running:active(),name:state.name||''}})); }
  function open() {
    if (!connected() || byId('recover_restore')) return;
    if (byId('ig-shiny-apps').hidden) lastFocus=document.activeElement;
    byId('ig-shiny-apps').hidden=false;
    workspaceInert(true);
    document.body.classList.add('ig-host-active');
    Shiny.setInputValue('app_host_open',Date.now(),{priority:'event'});
    render(); byId('ig-app-open').focus(); publish();
  }
  function leave() {
    if(byId('ig-app-confirm').open)byId('ig-app-confirm').close();
    byId('ig-shiny-apps').hidden=true;
    workspaceInert(false);
    document.body.classList.remove('ig-host-active');
    (lastFocus?.isConnected ? lastFocus : byId('btn_shiny_apps')).focus(); publish();
  }
  function close() {
    if (active()) byId('ig-app-confirm').showModal();
    else { selecting=true; render(); }
  }
  function render() {
    const running=active();
    byId('btn_shiny_apps').classList.toggle('ig-app-running',running);
    byId('btn_shiny_apps').setAttribute('title',text(running?'Return to Shiny app':'Open Shiny apps'));
    byId('btn_shiny_apps').setAttribute('aria-label',text(running?'Return to Shiny app':'Open Shiny apps'));
    byId('ig-app-name').textContent=state.name || text('Shiny apps');
    byId('ig-app-status').textContent=text(state.message || 'Choose a Shiny app to begin.');
    byId('ig-app-close').disabled=pending || !running;
    byId('ig-app-run').disabled=pending || !selected || !byId('ig-app-trust').checked;
    byId('ig-app-selection').hidden=!selected;
    byId('ig-app-replace-note').hidden=!running;
    byId('ig-app-path').textContent=selected?.directory || '';
    byId('ig-app-resume').hidden=!running;
    byId('ig-app-empty').hidden=!selecting && running;
    byId('ig-app-starting').hidden=selecting || state.phase!=='starting';
    let frame=byId('ig-app-frame');
    if(state.phase==='ready' && state.url) {
      if(frame && frame.getAttribute('src')!==state.url) {retireFrame(frame);frame=null;}
      if(!frame) {
        frame=document.createElement('iframe');frame.id='ig-app-frame';
        frame.name='ig-hosted-shiny-app';
        frame.title=text('Hosted Shiny app');
        frame.setAttribute('sandbox','allow-scripts allow-same-origin allow-forms allow-downloads allow-modals allow-popups');
        byId('ig-app-starting').before(frame);
      }
      // Never reset src on a poll, log update, or language change.
      if(frame.getAttribute('src')!==state.url) frame.src=state.url;
      frame.hidden=selecting;
    } else if(frame)retireFrame(frame);
    byId('ig-app-log-text').textContent=state.log || text('No app messages yet.');
    byId('ig-app-error').textContent=state.phase==='failed' ? text(state.message) : '';
    publish();
  }
  window.addEventListener('DOMContentLoaded', () => {
    if(!byId('ig-shiny-apps')) return;
    byId('btn_shiny_apps').addEventListener('click',open);
    byId('ig-app-open').addEventListener('click',()=>{selecting=true;render();byId('sf_shiny_app').focus();});
    byId('ig-app-back').addEventListener('click',leave);
    byId('ig-app-close').addEventListener('click',close);
    byId('ig-app-cancel-close').addEventListener('click',()=>byId('ig-app-confirm').close());
    byId('ig-app-confirm-close').addEventListener('click',()=>{byId('ig-app-confirm').close();action('stop');});
    byId('ig-app-resume').addEventListener('click',()=>{selecting=false;render();});
    byId('ig-app-trust').addEventListener('change',render);
    byId('ig-app-run').addEventListener('click',()=>{if(selected&&byId('ig-app-trust').checked){selecting=false;action('start',{trusted:true});}});
    byId('ig-app-log').addEventListener('click',()=>showLog(byId('ig-app-log-panel').hidden));
    Shiny.addCustomMessageHandler('ig_shiny_app',value=>{
      if(value.ack===pending)pending=undefined;
      if(value.clearSelection) {selected=undefined;byId('ig-app-trust').checked=false;}
      if(value.selection) {selected=value.selection;byId('ig-app-trust').checked=false;selecting=true;}
      if(value.state) {
        state=value.state;
        if(state.phase==='failed' || state.phase==='stopped') {selecting=true;showLog(true);}
        if(state.phase==='idle') selecting=true;
      }
      if(value.error) selecting=true;
      render();
      if(value.error) byId('ig-app-error').textContent=text(value.error);
    });
    document.addEventListener('click',event=>{if(event.target.closest('#splash_shiny_apps'))open();});
    // shinyFiles nests a new picker in an existing Shiny modal. Wait for the
    // outgoing welcome modal to be removed, so it cannot take the picker with it.
    document.addEventListener('click',event=>{
      const button=event.target.closest('#sf_shiny_app,#sf_shiny_folder');
      if(!button || !byId('shiny-modal'))return;
      event.preventDefault();event.stopImmediatePropagation();
      let attempts=0;
      const retry=()=>{if(!byId('shiny-modal'))button.click();else if(++attempts<40)setTimeout(retry,50);};
      setTimeout(retry,50);
    },true);
    window.addEventListener('ig:language-changed',render);
    window.igShinyApps={open,back:leave,close:()=>{open();close();},get state(){return {...state};},get pending(){return Boolean(pending);}};
  });
})();
