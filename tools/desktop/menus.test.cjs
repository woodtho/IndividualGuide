'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

test('the package manager is a Session command and respects workspace state', () => {
  const commands = [];
  const restarts = [];
  const build = entries => {
    const items = entries.map(entry => ({ ...entry, ...(entry.submenu ? { submenu: build(entry.submenu) } : {}) }));
    return { items, getMenuItemById(id) {
      for (const item of items) {
        if (item.id === id) return item;
        const child = item.submenu?.getMenuItemById(id);
        if (child) return child;
      }
    } };
  };
  let menu;
  const Menu = { buildFromTemplate: build, setApplicationMenu(value) { menu = value; }, getApplicationMenu() { return menu; } };
  const module = { exports: {} };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, 'menus.cjs'), 'utf8'), {
    module, require(name) { assert.equal(name, 'electron'); return { Menu }; }
  });
  const update = module.exports({ command: id => commands.push(id), restart: defaults => restarts.push(defaults), preferences: { recent: [], language: 'en-CA' } });
  assert.ok(menu.items.find(item => item.label === 'Session').submenu.getMenuItemById('packages'));
  const ready = { connected: true, startupReady: true };
  update(ready, { phase: 'ready' });
  assert.equal(menu.getMenuItemById('packages').enabled, true);
  menu.getMenuItemById('packages').click();
  assert.deepEqual(commands, ['packages']);
  assert.equal(menu.getMenuItemById('restart-r-default-options').enabled, true);
  menu.getMenuItemById('restart-r-default-options').click();
  assert.deepEqual(restarts, [true]);
  for (const state of [{ connected: false }, { modal: true }, { running: true }, { recovery: true }, { appHost: true }]) {
    update({ ...ready, ...state }, { phase: 'ready' });
    assert.equal(menu.getMenuItemById('packages').enabled, false);
  }
  update(ready, { phase: 'starting' });
  assert.equal(menu.getMenuItemById('packages').enabled, false);
  assert.equal(menu.getMenuItemById('restart-r-default-options').enabled, false);
});

test('a project presentation language is shown without replacing the global preference', () => {
  let menu, active = 'fr-CA';
  const build = entries => ({items:entries.map(entry=>({...entry,...(entry.submenu?{submenu:build(entry.submenu)}:{})})),
    getMenuItemById(id) { for(const item of this.items) {if(item.id===id)return item;const found=item.submenu?.getMenuItemById(id);if(found)return found;} }});
  const Menu = {buildFromTemplate:build,setApplicationMenu(value){menu=value;},getApplicationMenu(){return menu;}};
  const module = {exports:{}};
  vm.runInNewContext(fs.readFileSync(path.join(__dirname,'menus.cjs'),'utf8'),{module,require:()=>({Menu})});
  const preferences = {recent:[],language:'en-CA'};
  const update = module.exports({command:()=>{},preferences,activeLanguage:()=>active});
  update({connected:true,startupReady:true},{phase:'ready'});
  assert.equal(menu.getMenuItemById('language-fr-CA').checked,true);
  assert.equal(preferences.language,'en-CA');
  active='en-CA';
  update({connected:true,startupReady:true},{phase:'ready'});
  assert.equal(menu.getMenuItemById('language-en-CA').checked,true);
  assert.equal(preferences.language,'en-CA');
});
