'use strict';
const fs = require('node:fs'), path = require('node:path');
const directory = fs.existsSync(path.join(__dirname,'i18n/core.js'))
  ? path.join(__dirname,'i18n') : path.resolve(__dirname,'../../inst/app/www/i18n');
const core = require(path.join(directory,'core.js'));
const catalog = JSON.parse(fs.readFileSync(path.join(directory,'fr-CA.json'),'utf8'));
function installationLanguage(directory) {
  try {
    const value = JSON.parse(fs.readFileSync(path.join(directory,'installation-language.json'),'utf8'));
    if (!core.supported.includes(value.locale) || typeof value.installation !== 'string' || !value.installation.length || value.installation.length > 100) return null;
    return { locale:value.locale, installation:value.installation };
  } catch { return null; }
}
function initialLanguage(saved, installation, systemLanguage, override) {
  if (override && core.supported.includes(override)) return override;
  if (installation && installation.installation !== saved.installation) return installation.locale;
  return core.supported.includes(saved.language) ? saved.language : installation?.locale || core.normalize(systemLanguage);
}
function localizedDialog(options,translate){
  const text=value=>value.split('\n').map(translate).join('\n');
  const result={...options};
  for(const key of ['title','message','detail','buttonLabel'])if(typeof result[key]==='string')result[key]=text(result[key]);
  if(result.buttons)result.buttons=result.buttons.map(translate);
  if(result.filters)result.filters=result.filters.map(filter=>({...filter,name:translate(filter.name)}));
  return result;
}
module.exports = { ...core, catalog, installationLanguage, initialLanguage, localizedDialog };
