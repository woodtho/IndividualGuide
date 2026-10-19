'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { preferences, windowBounds, projectArgument } = require('./preferences.cjs');
test('recent projects persist, deduplicate, pin and bound ordinary history', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(),'ig-preferences-'));
  try {
    const file = path.join(dir,'settings.json'), state = preferences(file);
    const project = path.join(dir,'Unicode Ω project.igpx');
    state.used(project); state.pin(project);
    for (let i=0;i<20;i++) state.used(path.join(dir,i+'.igpx'));
    assert.equal(state.recent.length,11);
    state.used(project); assert.equal(state.recent.length,11); assert.equal(state.recent[0].pinned,true);
    state.clear(); assert.deepEqual(preferences(file).recent,[{path:project,pinned:true}]);
    fs.writeFileSync(file,'corrupt'); assert.deepEqual(preferences(file).recent,[]);
    fs.writeFileSync(file,'null'); assert.deepEqual(preferences(file).recent,[]);
  } finally { fs.rmSync(dir,{recursive:true,force:true}); }
});
test('bounds remain reachable on small or disconnected monitors', () => {
  const displays = [{workArea:{x:0,y:0,width:1280,height:680}}];
  for (const saved of [null,{}, {x:7000,y:-5000,width:8000,height:4000}, {x:10,y:10,width:-1,height:-1}]) {
    const value = windowBounds(saved,displays);
    assert.ok(value.x>=0 && value.y>=0 && value.x+value.width<=1280 && value.y+value.height<=680);
    assert.ok(value.width>=value.minWidth && value.height>=value.minHeight);
  }
  assert.equal(projectArgument(['app.exe','--data-dir=C:\\profile','Unicode Ω.igpx'], 'C:\\Projects'), 'C:\\Projects\\Unicode Ω.igpx');
});
