(function (root, factory) {
  'use strict';
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.IGLocale = factory();
})(typeof globalThis === 'object' ? globalThis : this, function () {
  'use strict';
  const supported = ['en-CA', 'fr-CA'];
  function normalize(value) {
    return typeof value === 'string' && /^fr(?:[-_]|$)/i.test(value) ? 'fr-CA' : 'en-CA';
  }
  function create(catalog, language) {
    const strings = catalog.strings || catalog;
    const canonical = text => text.replace(/\s+/g, ' ').trim();
    const entries = new Map(Object.entries(strings).map(([key, value]) => [canonical(key), value]));
    const escape = value => value.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
    const formats = [...entries].filter(([key])=>/%(?:[0-9]+\$)?[sdifg]/.test(key)).map(([key,translation])=>{
      const parts=key.split(/(%(?:[0-9]+\$)?[sdifg])/g);
      const expression=new RegExp('^'+parts.map((part,index)=>index%2 ? (/[difg]$/.test(part)?'([-+0-9.,eE]+)':'(.*?)') : escape(part)).join('')+'$','u');
      return {expression,translation};
    });
    const sentences=new Map();
    for(const [key,value] of entries)if(key.length>12&&/[.!?]$/.test(key)&&!key.includes('%')){
      const first=key.split(' ')[0],items=sentences.get(first)||[];
      items.push({source:key,translation:value});sentences.set(first,items);
    }
    for(const items of sentences.values())items.sort((a,b)=>b.source.length-a.source.length);
    const patterns = (catalog.patterns || []).map(entry => ({
      expression: new RegExp(entry.expression, 'u'), translation: entry.translation, translateCaptures:entry.translateCaptures === true
    }));
    let locale = normalize(language);
    function translate(value) {
      if (typeof value !== 'string' || locale === 'en-CA' || !value.trim()) return value;
      const key = canonical(value);
      const original=value.trim();
      let result = entries.get(key);
      if (result === undefined) {
        for (const pattern of patterns) {
          const candidate=pattern.expression.test(original)?original:key;
          if (pattern.expression.test(candidate)) {
            result = candidate.replace(pattern.expression, function () {
              const captures = arguments;
              return pattern.translation.replace(/\$(\d+)/g, (_token, index) => {
                const capture = captures[Number(index)] || '';
                return pattern.translateCaptures ? translate(capture) : capture;
              });
            }); break;
          }
        }
      }
      if (result === undefined) for(const format of formats){
        const match=original.match(format.expression)||key.match(format.expression);
        if(!match)continue;
        let index=0;
        result=format.translation.replace(/%(?:([0-9]+)\$)?[sdifg]/g,(_token,position)=>match[position?Number(position):++index]||'');
        break;
      }
      if(result === undefined)for(const sentence of sentences.get(key.split(' ')[0])||[]){
        if(key.startsWith(sentence.source+' ')){
          result=sentence.translation+' '+translate(key.slice(sentence.source.length+1));break;
        }
      }
      if(result === undefined && key.includes(' · ')){
        const parts=key.split(' · '),localized=parts.map(translate);
        if(parts.some((part,index)=>part!==localized[index]))result=localized.join(' · ');
      }
      return result === undefined ? value : value.replace(/\S[\s\S]*\S|\S/u, () => result);
    }
    return { translate, get locale() { return locale; }, setLanguage(value) { locale = normalize(value); return locale; } };
  }
  return { supported, normalize, create };
});
