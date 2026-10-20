'use strict';
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),catalog=require('../inst/app/www/i18n/fr-CA.json');
const engine=require('../inst/app/www/i18n/core.js').create(catalog,'fr-CA');
const argument=process.argv.indexOf('--inventory');
const file=argument>=0?process.argv[argument+1]:path.join(root,'artifacts/i18n/source-inventory.json');
const inventory=JSON.parse(fs.readFileSync(file,'utf8'));
const invariant=value=>Object.hasOwn(catalog.invariants||{},value);
const translatingPatterns=(catalog.patterns||[]).filter(pattern=>pattern.translateCaptures).map(pattern=>new RegExp(pattern.expression,'u'));
const covered=value=>{
  if(Object.hasOwn(catalog.strings,value)||invariant(value))return true;
  for(const pattern of translatingPatterns){
    const match=value.match(pattern);
    // Fixed source labels must have translated words after a translated prefix.
    // Runtime captures can still be arbitrary user names; source coverage must
    // not accept "Save current project" solely because "Save" was translated.
    if(match)return match.slice(1).every(part=>!/[A-Za-z]/.test(part)||/%(?:[0-9]+\$)?[sdifg]/.test(part)||covered(part));
  }
  return(value.includes(' · ')&&value.split(' · ').every(covered))||engine.translate(value)!==value;
};
const missing=inventory.strings.filter(value=>!covered(value));
const registry=require('../docs/book/data/app-reference.json').registry;
if(Object.keys(catalog.taskTypes||{}).length!==registry.length||registry.some(task=>catalog.taskTypes[task.id]!==task.label))throw Error('French flow-card labels must match the actual task registry.');
const invalid=Object.entries(catalog.strings).filter(([key,value])=>!key.trim()||typeof value!=='string'||!value.trim()||
  (key===value&&key.length>80&&/\s/.test(key)&&!invariant(key)));
if(missing.length||invalid.length)throw Error('French catalog incomplete: '+JSON.stringify({missing,invalid},null,2));
const report={ok:true,language:'fr-CA',sourceStrings:inventory.strings.length,
  translations:Object.keys(catalog.strings).length,technicalInvariants:Object.keys(catalog.invariants).length};
fs.mkdirSync(path.join(root,'artifacts/i18n'),{recursive:true});
fs.writeFileSync(path.join(root,'artifacts/i18n/catalog-verification.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));
