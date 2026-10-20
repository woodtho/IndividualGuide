'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const i18n=require('./i18n.cjs');
const {preferences}=require('./preferences.cjs');
test('Canadian French preserves identifiers and literal replacement characters',()=>{
  const t=i18n.create(i18n.catalog,'fr-CA');
  assert.equal(t.translate('  Save project  '),'  Enregistrer le projet  ');
  assert.equal(t.translate('Input table'),'Table d’entrée');
  assert.equal(t.translate('Add $& to report'),'Ajouter $& au rapport');
  assert.equal(t.translate('Add two  spaces to report'),'Ajouter two  spaces au rapport');
  assert.equal(t.translate('Opened a  name. Outputs: C:/two  spaces. Use Save As to keep your project.'),'Ouvert : a  name. Sorties : C:/two  spaces. Utilisez Enregistrer sous pour conserver le projet.');
  assert.equal(t.translate('Save Component scores (augment)'),'Enregistrer : Scores des composantes (augment)');
  assert.equal(t.translate('Output name for Model object'),'Nom de la sortie : Objet du modèle');
  assert.equal(t.translate('table: Model fit (glance)'),'table : Ajustement du modèle (glance)');
  assert.equal(t.translate('model: Model object'),'modèle : Objet du modèle');
  assert.equal(t.translate('✓ Complete: 3 rows × 7 columns'),'✓ Terminé : 3 lignes × 7 colonnes');
  assert.equal(t.translate('150 rows  ×  5 columns'),'150 lignes × 5 colonnes');
  assert.equal(t.translate('6 of 22 examples'),'6 exemples sur 22');
  assert.equal(t.translate('Draft'),'Brouillon');
  assert.equal(t.translate('Save transcript'),'Enregistrer la transcription');
  assert.equal(t.translate('Save current project…'),'Enregistrer le projet actuel…');
  assert.equal(t.translate('Error: Mean'),'Erreur : Mean');
  assert.equal(t.translate('✗ Error'),'✗ Erreur');
  assert.equal(t.translate('Not run'),'Non exécuté');
  assert.equal(t.translate('Loaded'),'Chargé');
  assert.equal(t.translate('Flow validation'),'Validation du flux');
  assert.equal(t.translate("Input 'Mean' is unavailable; run or include its producer."),"L’entrée 'Mean' n’est pas disponible; exécutez ou ajoutez la tâche qui la produit.");
  assert.equal(t.translate('Unavailable column: Mean.'),'Colonne non disponible : Mean.');
  assert.equal(t.translate('Species'),'Species');
  assert.equal(t.translate('flowers_clean'),'flowers_clean');
  assert.equal(t.translate('1 data source · 3 flows'),'1 source de données · 3 flux');
  assert.equal(t.translate("'Keep $& Mean' created — 150 rows × 5 cols."),"'Keep $& Mean' créé — 150 lignes × 5 colonnes.");
  assert.equal(t.translate('Explore relationships · 2/5 completed'),'Explore relationships · 2/5 terminées');
  assert.equal(t.translate('3 issues, 2 errors'),'3 problèmes, 2 erreurs');
  assert.equal(t.translate('1 issue, 1 error'),'1 problème, 1 erreur');
  assert.equal(t.translate('Input table · Summary Statistics'),'Table d’entrée · Statistiques descriptives');
  t.setLanguage('en-CA');assert.equal(t.translate('Save project'),'Save project');
});
test('native dialogs translate prose and keep paths, filters and choices intact',()=>{
  const engine=i18n.create(i18n.catalog,'fr-CA');
  const file='C:\\Private  folder\\Run $&.igpx';
  const detail='Projects can contain R code and serialized R objects. Opening or running a project can access files and execute code with your Windows permissions.';
  const options={title:'Trust this project?',message:'Open a project from a trusted source?',detail:detail+'\n\n'+file,
    buttons:['Cancel','Trust and open'],defaultId:0,cancelId:0,defaultPath:file,
    filters:[{name:'Individual Guide project',extensions:['igpx']}]};
  const translated=i18n.localizedDialog(options,value=>engine.translate(value));
  assert.equal(translated.title,'Faire confiance à ce projet?');
  assert.ok(!translated.detail.includes('Projects can contain'));
  assert.ok(translated.detail.endsWith('\n\n'+file));
  assert.equal(translated.defaultPath,file);
  assert.deepEqual(translated.filters[0].extensions,['igpx']);
  assert.deepEqual(translated.buttons,['Annuler','Faire confiance et ouvrir']);
  assert.equal(options.title,'Trust this project?');
  engine.setLanguage('en-CA');
  assert.deepEqual(i18n.localizedDialog(options,value=>engine.translate(value)),options);
});
test('new installer choice wins once; later app choices survive reopening',()=>{
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'ig-language-'));
  try{
    const file=path.join(directory,'settings.json'),prefs=preferences(file);
    const install={locale:'fr-CA',installation:'new-install'};
    assert.equal(i18n.initialLanguage(prefs,install,'en-US'),'fr-CA');
    prefs.saveLanguage('fr-CA',install.installation);
    prefs.saveLanguage('en-CA');
    const restored=preferences(file);
    assert.equal(i18n.initialLanguage(restored,install,'fr-CA'),'en-CA');
    assert.equal(i18n.initialLanguage(restored,{locale:'fr-CA',installation:'another-install'},'en-US'),'fr-CA');
    assert.equal(restored.saveLanguage('../../invalid'),false);
    assert.equal(restored.language,'en-CA');
    assert.equal(i18n.initialLanguage({},null,'fr-CA'),'fr-CA');
    assert.equal(i18n.initialLanguage({},null,'en-CA'),'en-CA');
    fs.writeFileSync(path.join(directory,'installation-language.json'),JSON.stringify(install));
    assert.deepEqual(i18n.installationLanguage(directory),install);
    for(const invalid of [{locale:'fr-FR',installation:'x'},{locale:'fr-CA',installation:{}},{locale:'fr-CA',installation:''},{locale:'fr-CA',installation:'x'.repeat(101)},null]){
      fs.writeFileSync(path.join(directory,'installation-language.json'),JSON.stringify(invalid));
      assert.equal(i18n.installationLanguage(directory),null);
    }
  }finally{fs.rmSync(directory,{recursive:true,force:true});}
});
