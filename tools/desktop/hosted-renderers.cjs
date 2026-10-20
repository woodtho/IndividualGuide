'use strict';
// Only renderers observed in our named, local, cross-site app iframe qualify.
// Birth times prevent a recycled OS PID from targeting a different process.
module.exports=({window,app,log,kill=pid=>process.kill(pid)})=>{
 const records=new Map();
 const contents=window.webContents;
 function remember(){
  if(contents.isDestroyed())return;
  const main=contents.mainFrame;
  for(const frame of main.frames){
   if(frame.name!=='ig-hosted-shiny-app'||frame.parent!==main||frame.osProcessId===main.osProcessId)continue;
   try{
    const url=new URL(frame.url);
    if(url.protocol!=='http:'||!url.hostname.startsWith('127.'))continue;
    const metric=app.getAppMetrics().find(value=>value.pid===frame.osProcessId&&value.type==='Tab');
    if(metric&&Number.isFinite(metric.creationTime))records.set(url.origin,{pid:metric.pid,birth:metric.creationTime});
   }catch{}
  }
 }
 contents.on('did-frame-navigate',remember);
 function release(value){
  if(typeof value!=='string'||value.length>4096)return false;
  let key;try{key=new URL(value).origin;}catch{return false;}
  const record=records.get(key);records.delete(key);
  if(!record||contents.isDestroyed())return false;
  const mainPid=contents.mainFrame.osProcessId;
  const metric=app.getAppMetrics().find(value=>value.pid===record.pid);
  if(record.pid===mainPid||record.pid===process.pid||!metric||metric.type!=='Tab'||metric.creationTime!==record.birth)return false;
  try{kill(record.pid);log('shiny-app.renderer.closed',{pid:record.pid});return true;}
  catch(error){log('shiny-app.renderer.close.failed',{pid:record.pid,code:error.code},'WARN');return false;}
 }
 return{release,dispose(){for(const key of [...records.keys()])release(key);}};
};
