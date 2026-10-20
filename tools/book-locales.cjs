'use strict';
const fs=require('node:fs'),path=require('node:path');
const language=process.env.BOOK_LANGUAGE||'en-CA';
if(!['en-CA','fr-CA'].includes(language))throw Error('BOOK_LANGUAGE must be en-CA or fr-CA.');
const french=language==='fr-CA';
const root=path.resolve(__dirname,'..'),sharedSource=path.join(root,'docs/book');
const source=french?path.join(sharedSource,'fr-CA'):sharedSource;
const catalog=require('../inst/app/www/i18n/fr-CA.json');
const app=require('../inst/app/www/i18n/core.js').create(catalog,language);
const strings=french?JSON.parse(fs.readFileSync(path.join(source,'data/book-text.json'),'utf8')):{};
function text(value){
  if(!french||!value)return value;
  if(Object.hasOwn(strings,value))return strings[value];
  if(/^\|(?:\s*---\s*\|)+$/.test(value))return value;
  throw Error('Missing French book text: '+value);
}
const ui=value=>{
  const result=app.translate(value);
  if(french&&value&&result===value&&!Object.hasOwn(catalog.strings,value))throw Error('Missing French app text used in the book: '+value);
  return result;
};
const lines=values=>values.map(text);
const labels={
  'en-CA':{title:'Individual Guide: A Friendly Guide',subtitle:'Start here, learn by doing, and find the task you need',
    author:'Individual Guide project documentation',friendly:'A friendly guide',skip:'Skip contents and read the book',contents:'Contents',
    contentsAria:'Book contents',find:'Find a chapter or task',search:'Search contents…',matching:'matching sections',print:'Print / save PDF',
    cover:'58 task types · 22 real projects · No R experience needed',downloads:'Download this guide',keep:'Keep a copy:',offline:'Offline HTML',
    printContents:'Print contents',footer:'Find downloads and help through the public links in this guide.',
    description:'A friendly guide to Individual Guide. Start with the public download, explore real examples, and use the app without learning R.'},
  'fr-CA':{title:'Individual Guide : Guide pratique',subtitle:'Commencez ici, apprenez par la pratique et trouvez la tâche qu’il vous faut',
    author:'Documentation du projet Individual Guide',friendly:'Un guide pratique',skip:'Passer la table des matières et lire le guide',contents:'Table des matières',
    contentsAria:'Table des matières du guide',find:'Trouver un chapitre ou une tâche',search:'Rechercher dans le guide…',matching:'sections correspondantes',print:'Imprimer / enregistrer en PDF',
    cover:'58 types de tâches · 22 projets réels · Aucune expérience de R nécessaire',downloads:'Télécharger ce guide',keep:'Gardez une copie :',offline:'HTML hors ligne',
    printContents:'Table des matières pour l’impression',footer:'Les liens publics de ce guide donnent accès aux téléchargements et à l’aide.',
    description:'Un guide pratique d’Individual Guide. Téléchargez la version publique, explorez des exemples réels et utilisez l’application sans apprendre R.'}
}[language];
module.exports={language,french,source,sharedSource,text,ui,lines,labels};
