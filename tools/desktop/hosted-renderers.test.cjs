'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {EventEmitter}=require('node:events');
const create=require('./hosted-renderers.cjs');
function fixture(){
 const main={osProcessId:101,frames:[]},contents=new EventEmitter();
 contents.mainFrame=main;contents.isDestroyed=()=>false;
 const metrics=[{pid:202,type:'Tab',creationTime:1234}],killed=[];
 const window={webContents:contents};
 const manager=create({window,app:{getAppMetrics:()=>metrics},log:()=>{},kill:pid=>killed.push(pid)});
 const frame={name:'ig-hosted-shiny-app',parent:main,osProcessId:202,url:'http://127.52.3.4:1234/'};
 main.frames.push(frame);
 return{manager,main,frame,contents,metrics,killed,window};
}
test('retiring an observed hosted app stops only its renderer, once',()=>{
 const f=fixture();f.contents.emit('did-frame-navigate');
 assert.equal(f.manager.release('http://127.52.3.4:1234/'),true);
 assert.deepEqual(f.killed,[202]);
 assert.equal(f.manager.release('http://127.52.3.4:1234/'),false);
 assert.equal(f.manager.release('http://other.example/'),false);
});
test('main renderer and unrelated frames cannot be terminated',()=>{
 for(const change of [f=>{f.frame.osProcessId=101;},f=>{f.frame.name='other-widget';},f=>{f.frame.url='https://other.example/';}]){
  const f=fixture();change(f);f.contents.emit('did-frame-navigate');f.manager.dispose();
  assert.deepEqual(f.killed,[]);
 }
 const f=fixture();f.contents.emit('did-frame-navigate');f.main.osProcessId=202;f.manager.dispose();
 assert.deepEqual(f.killed,[]);
});
test('recycled process IDs and changed process types cannot be terminated',()=>{
 for(const change of [f=>{f.metrics[0].creationTime++;},f=>{f.metrics[0].type='Utility';},f=>{f.metrics.length=0;}]){
  const f=fixture();f.contents.emit('did-frame-navigate');change(f);f.manager.dispose();
  assert.deepEqual(f.killed,[]);
 }
});
test('a destroyed window does not interrupt server shutdown',()=>{
 const f=fixture();f.contents.emit('did-frame-navigate');
 f.contents.isDestroyed=()=>true;
 Object.defineProperty(f.window,'webContents',{get(){throw Error('Object has been destroyed');}});
 assert.doesNotThrow(()=>f.manager.dispose());assert.deepEqual(f.killed,[]);
});
