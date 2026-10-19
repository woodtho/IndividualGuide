'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const source = path.join(root, 'docs/book');
const out = path.resolve(process.env.BOOK_OUTPUT_DIR || path.join(root, 'build/book'));
const metadataPath = path.join(source, 'data/app-reference.json');
const lessonsPath = path.join(source, 'data/example-lessons.json');
const metadata = JSON.parse(fs.readFileSync(metadataPath, 'utf8'));
const bookInputs = require('./book-inputs.cjs').snapshot();
const lessons = JSON.parse(fs.readFileSync(lessonsPath, 'utf8'));
const arr = value => value == null ? [] : Array.isArray(value) ? value : [value];
const md = value => String(value).replace(/\|/g, '\\|').replace(/\r?\n/g, ' ');
const digest = (file, algorithm = 'sha256') => crypto.createHash(algorithm).update(fs.readFileSync(file)).digest('hex');
const taskLink = type => {
  const task = metadata.registry.find(task => task.id === type);
  if (!task) throw new Error('Unknown example task: ' + type);
  return `[${task.label}](#task-${type})`;
};
const exampleLink = example => `[${example.title}](#example-${example.id})`;
for (const [relative, expected] of Object.entries(metadata.source_md5)) {
  if (digest(path.join(root, relative), 'md5') !== expected) throw new Error('Book metadata is stale: ' + relative);
}
const chapterFiles = fs.readdirSync(path.join(source, 'chapters')).filter(name => name.endsWith('.md')).sort();
const authored = chapterFiles.map(name => fs.readFileSync(path.join(source, 'chapters', name), 'utf8')).join('\n\n');
for (const task of metadata.registry) {
  if (authored.split('{#task-' + task.id + '}').length !== 2) throw new Error('Expected one task guide: ' + task.id);
}
if (Object.keys(lessons).sort().join() !== metadata.examples.map(example => example.id).sort().join()) {
  throw new Error('Example lessons must match the actual example catalogue.');
}
const atlas = [
  '# Choose an example project {#examples}', '',
  'All 22 projects below come with data, configured tasks, saved results, logging, and output files. They use public sample data supplied with R or its packages. You do not need a separate data download to explore them.', '',
  '## Find an example by task', '',
  '1. Open **Help > Example projects** in the app.',
  '2. Search for a title or topic. Use the **task type** filter to find a specific task, such as Rename Columns or Cluster Analysis.',
  '3. Use the **category** filter to narrow the list to a group, such as Graph or Survival Analysis.',
  '4. Choose **Open example**, then use **Save As** to keep your own copy.', '',
  'If nothing appears, clear the search and filters, then try just one filter. You can also use the Task finder at the end of this guide to see which projects contain a task.', '',
  '![Example projects filtered to the Survival Analysis category in Help.](assets/example-filters.png)', '',
  '## A simple learning route', '',
  'Start with **Iris exploration**. Next try **Cars - prepare an analysis table** for cleaning, **Flowers - categorical chart gallery** for charts, and **Cars - a report with an execution audit** for reporting and logs. Choose models and control-flow examples when you need them.', '',
  '## Before you rerun an example', '',
  'Read its notes and inspect its saved results first. Check Export and Export Log destinations before running the flow. Each opened example gets a separate working copy, but you should still choose folders and Overwrite settings that suit your own work.', '',
  'These projects teach app controls. Their model and cleaning choices are examples, not a claim that those choices fit every dataset.', ''
];
for (const example of metadata.examples) {
  const lesson = lessons[example.id];
  for (const field of ['data', 'check', 'try']) if (!lesson[field]) throw new Error('Missing lesson: ' + example.id + '/' + field);
  atlas.push(`## ${example.title} {#example-${example.id}}`, '',
    example.description, '', `**Data:** ${lesson.data}`, '',
    '**Tasks to find:** ' + arr(example.task_types).map(taskLink).join(', ') + '.', '',
    `**Check the result:** ${lesson.check}`, '', `**Try this next:** ${lesson.try}`, '',
    'Open its report and log exports, then save your project copy if you want to keep your changes.', '');
}
const finder = [
  '# Task finder {#task-finder}', '',
  'Find a task below, then follow its link for setup steps. The example links show up to three projects you can open from Help. Use the app\'s task filter to find all matches. Start by inspecting a completed example rather than rebuilding it from scratch.', '',
  '| Task | Where to find it in Add Task | Examples to open |', '| --- | --- | --- |'
];
for (const task of metadata.registry) finder.push(`| ${taskLink(task.id)} | ${md(task.category)} | ${metadata.examples.filter(example => arr(example.task_types).includes(task.id)).slice(0,3).map(exampleLink).join('; ')} |`);
const reference = [
  '# Shortcuts and everyday terms {#working-reference}', '',
  '## Useful Windows desktop shortcuts', '',
  'Use the menus while learning. These keys can save time once the actions feel familiar. A text editor or open dialog may use a key for its own controls.', '',
  '| Keys | Action |', '| --- | --- |',
  '| Ctrl+N | New project |', '| Ctrl+O | Open project |',
  '| Ctrl+S | Save project |', '| Ctrl+Shift+S | Save As |',
  '| Ctrl+Shift+F | Search project |', '| Ctrl+Alt+L | Open Task list |',
  '| Ctrl+Alt+R | Run active flow, when focus is outside an editor |',
  '| Ctrl+Shift+F5 | Stop the flow run |', '| Ctrl+Shift+R | Restart R server; save first if possible |',
  '| F1 | Open app help |', '| Tab / Shift+Tab | Move focus through controls |', '',
  'For more keys, open **Help > Keyboard shortcuts**. If you run in a normal web browser, use the app buttons; the browser may use these same keys for its own actions.', '',
  '## A few more terms', '',
  '| Term | Plain meaning |', '| --- | --- |',
  '| Column type | The kind of value stored, such as text, number, date, or category |',
  '| CSV | A text data file whose columns are separated by commas |',
  '| Input | A table or result that a task needs |',
  '| Missing value | An unknown entry; not automatically zero |',
  '| Object | A saved result that is not an ordinary table, such as a model |',
  '| Overwrite | Replace an existing file with a new one |',
  '| Package | An add-on that gives R more features |',
  '| Path | The address of a file or folder |',
  '| Predictor | A column used to help explain or predict a response |',
  '| Response | The outcome a model tries to explain or predict |',
  '| Seed | A setting for repeating a random choice with the same inputs |',
  '| Stale | A result that needs to be rerun after a change |', '',
  '## Public downloads and help', '',
  '- [Individual Guide releases](https://github.com/woodtho/IndividualGuide/releases/latest): Windows Setup, R package files, and downloadable handbook editions.',
  '- [Release 0.4.0](https://github.com/woodtho/IndividualGuide/releases/tag/v0.4.0): the version used by this guide.',
  '- [Report an app issue](https://github.com/woodtho/IndividualGuide/issues): include the version and exact error; check attachments for private information.',
  '- [Download R](https://cran.r-project.org/): needed only for the optional R installation route.',
  '- [Install Pandoc](https://pandoc.org/installing.html): for Word reporting when using your own R installation.', '',
  'The example data come from R\'s datasets package and the survival package. The example notes describe prepared fields and teaching choices. Individual Guide is an open-source project by Thomas Wood.', ''
];
fs.mkdirSync(out, {recursive: true});
fs.mkdirSync(path.join(out, 'generated'), {recursive: true});
fs.cpSync(path.join(source, 'assets'), path.join(out, 'assets'), {recursive: true});
const generated = {'14-examples.md': atlas.join('\n'), '15-task-finder.md': finder.join('\n'), '16-reference.md': reference.join('\n')};
// Only the current generated chapters belong in the reader edition.
for (const file of fs.readdirSync(path.join(out, 'generated'))) {
  if (/^\d{2}-[\w-]+\.md$/.test(file) && !Object.hasOwn(generated, file)) fs.unlinkSync(path.join(out, 'generated', file));
}
for (const [file, content] of Object.entries(generated)) fs.writeFileSync(path.join(out, 'generated', file), content + '\n');
const complete = authored + '\n\n' + Object.values(generated).join('\n\n');
fs.writeFileSync(path.join(out, 'Individual-Guide-Handbook.md'), complete);
const args = process.argv.slice(2), custom = args.indexOf('--pandoc');
const candidates = [custom >= 0 ? args[custom + 1] : '', process.env.PANDOC,
  path.join(process.env.LOCALAPPDATA || '', 'Pandoc/pandoc.exe'), 'pandoc'].filter(Boolean);
const pandoc = candidates.find(command => spawnSync(command, ['--version'], {encoding:'utf8', windowsHide:true}).status === 0);
if (!pandoc) throw new Error('Pandoc not found; set PANDOC or --pandoc.');
const common = [path.join(out, 'Individual-Guide-Handbook.md'), '--from=markdown+fenced_divs+header_attributes', '--standalone', '--toc', '--toc-depth=2', '--number-sections',
  '--metadata=title:Individual Guide: A Friendly Guide', '--metadata=subtitle:Start here, learn by doing, and find the task you need',
  '--metadata=author:Individual Guide project documentation', '--metadata=date:Beginner edition for release 0.4.0 · 19 October 2026', '--metadata=lang:en-CA',
  '--resource-path=' + source, '--syntax-highlighting=pygments'];
function convert(extra, name) {
  const result = spawnSync(pandoc, [...common, ...extra, '-o', path.join(out, name)], {encoding:'utf8', windowsHide:true, maxBuffer:10*1024*1024});
  fs.writeFileSync(path.join(out, name + '.build.log'), (result.stdout || '') + (result.stderr || ''));
  if (result.status !== 0) throw new Error('Pandoc failed for ' + name + ': ' + result.stderr);
  if (name.endsWith('.html')) {
    const rendered = path.join(out,name);
    // Pandoc emits platform-specific line endings and CSS trailing spaces.
    // Normalize before hashing so Git checkouts serve the exact reviewed bytes.
    fs.writeFileSync(rendered,fs.readFileSync(rendered,'utf8').replace(/\r\n/g,'\n').replace(/[ \t]+$/gm,''));
  }
  console.log('Rendered', name);
}
convert(['--to=html5','--embed-resources','--template=' + path.join(source, 'assets/book-template.html'), '--css=' + path.join(source, 'assets/book.css')], 'Individual-Guide-Handbook.html');
convert(['--to=epub3','--split-level=1','--css=' + path.join(source, 'assets/epub.css')], 'Individual-Guide-Handbook.epub');
convert(['--to=docx'], 'Individual-Guide-Handbook.docx');
const wordCount = (complete.match(/\S+/g) || []).length;
const manifest = {title: metadata.title, edition: metadata.edition, audience:'New app users; no R knowledge required',
  packageVersion:metadata.package_version, projectFormat:metadata.project_format,
  tasks:metadata.registry.map(task=>task.id), examples:metadata.examples.map(example=>example.id),
  exampleSteps:metadata.examples.reduce((n,example)=>n+example.tasks.length,0), words:wordCount,
  chapters:chapterFiles.map(name=>({name,sha256:digest(path.join(source,'chapters',name))})), source_md5:metadata.source_md5,
  metadataSha256:digest(metadataPath), lessonsSha256:digest(lessonsPath), bookInputs, outputs:[], builtAt:new Date().toISOString()};
for (const file of fs.readdirSync(out).filter(name=>/^Individual-Guide-Handbook\.(md|html|epub|docx)$/.test(name))) manifest.outputs.push({file,bytes:fs.statSync(path.join(out,file)).size,sha256:digest(path.join(out,file))});
fs.writeFileSync(path.join(out,'manifest.json'), JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({words:wordCount,tasks:metadata.registry.length,examples:metadata.examples.length,out},null,2));
