'use strict';
const fs = require('node:fs');
const path = require('node:path');
const projectPath = value => typeof value === 'string' && value.length <= 4096 && path.isAbsolute(value) && /\.(igpx|igp|rds)$/i.test(value);
const key = value => path.resolve(value).toLowerCase();
function projectArgument(argv, cwd = process.cwd()) {
  const candidate = argv.find(value => typeof value === 'string' && !value.startsWith('-') && /\.(igpx|igp|rds)$/i.test(value));
  return candidate ? path.resolve(cwd, candidate) : '';
}
function windowBounds(saved, displays) {
  const primary = displays[0].workArea;
  const valid = saved && ['x','y','width','height'].every(k => Number.isFinite(saved[k]));
  const area = valid && displays.find(({ workArea: a }) => saved.x + Math.min(saved.width, 100) > a.x && saved.x < a.x + a.width && saved.y + 40 > a.y && saved.y < a.y + a.height)?.workArea || primary;
  const width = Math.max(Math.min(1000, area.width), Math.min(valid ? saved.width : 1440, area.width));
  const height = Math.max(Math.min(700, area.height), Math.min(valid ? saved.height : 960, area.height));
  return { x: Math.round(valid ? Math.max(area.x, Math.min(saved.x, area.x + area.width - width)) : area.x + (area.width - width)/2),
    y: Math.round(valid ? Math.max(area.y, Math.min(saved.y, area.y + area.height - height)) : area.y + (area.height - height)/2),
    width: Math.round(width), height: Math.round(height), minWidth: Math.min(1000, area.width), minHeight: Math.min(700, area.height) };
}
function preferences(file, log = () => {}) {
  let data = { recent: [], window: null };
  try { const saved = JSON.parse(fs.readFileSync(file,'utf8')); if (saved && typeof saved === 'object') data = saved; } catch (error) { if (error.code !== 'ENOENT') log('preferences.read.failed', error.message, 'WARN'); }
  data.recent = Array.isArray(data.recent) ? data.recent.filter(item => item && projectPath(item.path)).map(item => ({ path: path.resolve(item.path), pinned: item.pinned === true })) : [];
  function persist() {
    try { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file + '.tmp', JSON.stringify(data,null,2)); fs.renameSync(file + '.tmp',file); }
    catch (error) { log('preferences.write.failed',error.message,'WARN'); }
  }
  return {
    get recent() { return data.recent; }, get window() { return data.window; },
    get language() { return ['en-CA','fr-CA'].includes(data.language) ? data.language : undefined; },
    get installation() { return typeof data.installation === 'string' ? data.installation : ''; },
    saveLanguage(language, installation) {
      if (!['en-CA','fr-CA'].includes(language)) return false;
      data.language = language;
      if (typeof installation === 'string' && installation.length <= 100) data.installation = installation;
      persist(); return true;
    },
    used(file) {
      if (!projectPath(file)) return;
      const previous = data.recent.find(item => key(item.path) === key(file));
      data.recent = [{ path:path.resolve(file), pinned:previous?.pinned === true }, ...data.recent.filter(item => key(item.path) !== key(file))];
      let ordinary = 0;
      data.recent = data.recent.filter(item => item.pinned || ++ordinary <= 10);
      persist();
    },
    pin(file) {
      if (!projectPath(file)) return;
      const found = data.recent.find(item => key(item.path) === key(file));
      if (!found) return;
      if (!found.pinned && data.recent.filter(item => item.pinned).length >= 10) return;
      found.pinned = !found.pinned; persist();
    },
    clear() { data.recent = data.recent.filter(item => item.pinned); persist(); },
    saveWindow(value) { data.window = value; persist(); }
  };
}
module.exports = { preferences, windowBounds, projectArgument, projectPath };
