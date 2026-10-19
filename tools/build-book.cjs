'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const source = path.join(root, 'docs/book');
const out = path.resolve(process.env.BOOK_OUTPUT_DIR || path.join(root, 'build/book'));
const metadata = JSON.parse(fs.readFileSync(path.join(source, 'data/app-reference.json'), 'utf8'));
const arr = value => value == null ? [] : Array.isArray(value) ? value : [value];
const md = value => String(value == null ? '' : value).replace(/\|/g, '\\|').replace(/\r?\n/g, '<br>');
const inline = value => '`' + String(value).replace(/`/g, '') + '`';
const label = type => metadata.registry.find(task => task.id === type).label;
const taskLink = type => `[${label(type)}](#task-${type})`;
const exampleLink = example => `[${example.title}](#example-${example.id})`;
const digest = (file, algorithm = 'sha256') => crypto.createHash(algorithm).update(fs.readFileSync(file)).digest('hex');
for (const [relative, expected] of Object.entries(metadata.source_md5)) {
  if (digest(path.join(root, relative), 'md5') !== expected) throw new Error('Book metadata is stale: ' + relative);
}
const chapterFiles = fs.readdirSync(path.join(source, 'chapters')).filter(name => name.endsWith('.md')).sort();
const authored = chapterFiles.map(name => fs.readFileSync(path.join(source, 'chapters', name), 'utf8')).join('\n\n');
for (const task of metadata.registry) {
  const token = '{#task-' + task.id + '}';
  if (authored.split(token).length !== 2) throw new Error('Expected exactly one authored task entry: ' + task.id);
}
const lessons = {
  iris: ['Start with the source Script and check 150 rows and three species of 50. Follow numeric and grouped summaries before reading the chart/report.', 'Change the chart mapping in a saved copy; rerun the chart, report and exports. Compare the report appendix with the final text log.'],
  'air-quality': ['Inspect missing_audit before air_clean. The raw table preserves the original missing measurements; mean imputation is an explicit teaching choice.', 'Change the missing-value method in a copy and compare before/after summaries. Explain why a complete-looking table is not proof of an appropriate missing-data analysis.'],
  'fuel-economy': ['Inspect mpg_model coefficients, fit, augment and the retained lm object. The input has 32 cars and wt is in thousands of pounds.', 'Remove one predictor in a copy and rerun all consumers. Compare model terms/run fingerprints rather than interpreting a change as an unexplained reload.'],
  'data-cleaning': ['The source intentionally appends one duplicate to the 32-car dataset. Deduplication leaves 32 analysis rows from 33 source rows.', 'Cross-tabulate am against transmission and inspect factor class after conversion. Explain why renaming weight is different from changing its units.'],
  'query-joins': ['The import is a genuine bundled CSV with 50 states. The source Script supplies the state/region lookup; the left join must not lose states or create missing regions.', 'Check Income >= 4500 and descending Income order. Raise/lower the threshold and explain the difference between filtering before and after an aggregate.'],
  reshape: ['The four measurement columns become 600 long-form rows. flower_id distinguishes observations when widening back.', 'Inspect the round-trip comparison, including column order/class differences. The two appended species give 100 rows; the transpose intentionally uses a small numeric subset.'],
  sampling: ['Inspect dense ranks and transformed predictors before the ten-row sample. Seed 2026 is explicit.', 'Repeat the sample, then change its seed in a copy. Compare row identifiers, not just the number of rows, and discuss how row order/input changes affect reproducibility.'],
  descriptive: ['The 60-row ToothGrowth source treats dose as a factor. Compare the supplementary frequency and dose-by-supplement design table.', 'Distinguish counts, percentages, distribution summary and formal chi-square output. Changing a display percentage does not turn the retained count table into percentages.'],
  'category-charts': ['Compare the same 150 flowers through counts, shares and group distributions. The bar/pie counts each species as 50.', 'Change the category order/style in a copy and inspect the static report figures. A pie counts observations; it does not use an arbitrary numeric weight column.'],
  'numeric-charts': ['Bubble, contour, histogram, scatter and matrix views all use the same original measurements. Compare what their result tables represent.', 'Change bins or matrix mode and explain the first-1,000-row display/output caps. Use Bubble Plot for visible size encoding rather than relying on Scatter Plot\'s shared Size field.'],
  'time-charts': ['The source creates 240 monthly temperature rows with dates. A separate Script derives annual mean and range for the combined chart.', 'Read the second-axis label and verify units. A line chart is not a forecast, and the annual range is not a confidence interval.'],
  anova: ['The original PlantGrowth table has 30 observations in three groups. A separate subset creates the control-versus-treatment-2 t test.', 'Compare the ANOVA, t Test and additive linear model without pretending they answer identical multiplicity questions. Inspect group coding and the model observation count.'],
  'binary-model': ['The model uses am as the binary response and mpg as predictor. Check that 1 means manual transmission in these data.', 'Inspect response-scale fitted probabilities and coefficient scale. Try a changed predictor only in a copy and inspect convergence/separation warnings.'],
  'count-model': ['The 54-row warpbreaks source feeds a Poisson model with wool and tension. Preserve the distinction between counts and rates.', 'Inspect fit diagnostics and discuss overdispersion. A successful Poisson fit is not an automatic justification of its variance assumptions.'],
  nonlinear: ['Filter the real Puromycin data to treated observations before the power fit. The model requires positive concentration/rate.', 'Inspect the curve over the observed range and its coefficients. Another preset is a modelling change, not a guaranteed repair for convergence or a biochemical mechanism.'],
  multivariate: ['The four numeric Iris measurements feed correlations, scaled PCA and seeded clustering. Species is held aside from the selected predictors.', 'Compare PCA\'s internal scaling with clustering\'s lack of automatic scaling. Inspect loadings, assignments and fit outputs before interpreting clusters as species.'],
  survival: ['The 228-row original lung data are preserved. The preparation maps original status 2 to event 1 and documents complete-case selection.', 'Check time/event coding before Kaplan–Meier or Cox output. Relative risk predictions are not time-specific absolute survival probabilities.'],
  forecast: ['The input contains 144 ordered AirPassengers values; the forecast horizon is 12 steps.', 'Inspect the retained engine/order summary and intervals. The task does not infer a tuned seasonal-frequency model merely from the dataset\'s historical monthly origin.'],
  'quality-control': ['The 100-row Nile sequence supports order-sensitive control diagnostics alongside CDF/normality displays.', 'Inspect flagged rules and the estimated limits. Historical river observations are not a controlled manufacturing process or a source of externally specified tolerance limits.'],
  branching: ['The quality gate checks for at least 100 Iris observations, then enables its summary path through quality_gate_true.', 'Raise the threshold in a copy and inspect skipped tasks and branch decisions. A data dependency alone does not attach a task to the branch token.'],
  looping: ['The group loop executes one summary Script per species and retains species_summary_1, _2 and _3, each summarizing 50 observations.', 'Inspect iteration-aware log entries and ordinary last-template values. Verify that the final report/log export sits outside the repeated body.'],
  'report-audit': ['The source emits an explicit teaching WARN, and a numeric summary feeds the report with its log appendix enabled.', 'Compare TXT, CSV and JSON exports. The final log includes report completion; the report\'s own pre-generation appendix cannot include that completion event.']
};
function valueText(value, key = '') {
  if (value === null) return 'automatic / blank';
  if (typeof value === 'string') {
    if (value.startsWith('@project/')) return key === 'dir' ? 'the opened example\'s writable output folder' : 'bundled/resolved file: ' + inline(path.posix.basename(value));
    if (!value) return '(blank)';
    return inline(value);
  }
  if (typeof value === 'number' || typeof value === 'boolean') return inline(value);
  if (Array.isArray(value) && value.every(item => typeof item !== 'object')) return value.length ? value.map(inline).join(', ') : '(none)';
  return inline(JSON.stringify(value));
}
const atlas = [
  '# The worked-example atlas {#examples}',
  '',
  'This atlas describes the **22 actual source-edition projects**, not hypothetical templates. The settings below were read from their bundled project archives. All 165 configured task instances had successful retained runs when the examples were built. Later rerun/save/reopen checks are recorded in the application\'s completion evidence.',
  '',
  'Open **Help > Example projects**, search or filter by task type/category, then Open example. Each opening prepares a separate writable copy. Save As before editing work you want to keep. Read each project\'s README and source notes. Release 0.4.0 includes this complete atlas in the source package and rebuilt installer.',
  '',
  '![The source-edition Help library filtered to the Survival Analysis category. The live count and task labels explain which project matches.](assets/example-filters.png)',
  '',
  '## Choose a learning route',
  '',
  '- **First analysis:** Iris, air quality, fuel economy, report audit.',
  '- **Data preparation:** car cleaning, state imports/joins, reshaping, ranking/scaling/sampling.',
  '- **Exploration:** descriptive analysis and the categorical/numeric/time chart galleries.',
  '- **Statistics:** plant-group comparisons, binary/count/nonlinear models, multivariate, survival, forecasting and stability diagnostics.',
  '- **Automation:** conditional quality gates and repeated species summaries.',
  '',
  'The recipes list settings changed from their constructor defaults, plus actual input/output declarations. Shared defaults and every saved field are in the parameter appendix. Internal field names are shown precisely, while the task reference explains their visible meaning. `@project/...` strings are archive references: open the example to resolve them; do not paste them as literal operating-system paths.',
  ''
];
for (const example of metadata.examples) {
  if (!lessons[example.id]) throw new Error('Missing teaching/checkpoints for ' + example.id);
  atlas.push(`## ${example.title} {#example-${example.id}}`, '', example.description, '', `**Data provenance:** ${example.source}`, '', `**Practise:** ${example.learn}`, '',
    `**Tasks:** ${arr(example.task_types).map(taskLink).join(' · ')}`, '',
    '**Read and check:** ' + lessons[example.id][0], '', '**Experiment in a saved copy:** ' + lessons[example.id][1], '',
    '### Reconstruct the pipeline', '');
  if (example.id === 'query-joins') atlas.push('The Help copy resolves its bundled CSV automatically. If rebuilding from a blank project, create the same local CSV with the following R preparation, then select that file in Import Data:', '',
    '```r', 'states <- as.data.frame(datasets::state.x77)', 'states$state <- rownames(states)', 'rownames(states) <- NULL', 'utils::write.csv(states, "state-statistics.csv", row.names = FALSE)', '```', '');
  example.tasks.forEach((task, index) => {
    const dataInputs = arr(task.inputs).filter(name => !arr(task.control_inputs).includes(name));
    atlas.push(`### Step ${index + 1}: ${task.label} — ${taskLink(task.type)} {#recipe-${example.id}-${task.id}}`, '',
      `Task ID: ${inline(task.id)}.`, '',
      `Data inputs: ${dataInputs.length ? dataInputs.map(inline).join(', ') : 'none declared'}.`);
    if (arr(task.control_inputs).length) atlas.push(`Control path: **${arr(task.control_inputs).map(inline).join(', ')}**. Configure this in Run after branch/loop path; it is essential to the recipe.`);
    if (task.note) atlas.push('', task.note);
    const settings = Object.entries(task.changed_params || {}).filter(([key]) => !['code', 'input_tables', 'input_table', 'output_defs', 'items', 'paths'].includes(key));
    if (settings.length) {
      atlas.push('', '| Setting | Recipe value |', '| --- | --- |');
      for (const [key, value] of settings) atlas.push(`| ${inline(key)} | ${md(valueText(value, key))} |`);
    }
    if (task.type === 'script') atlas.push('', 'Enter the following Script code and declare the outputs shown below:', '', '```r', task.params.code || '', '```');
    if (task.type === 'branch') {
      atlas.push('', 'Configure these branch paths (Else runs only when no ordinary path matches):', '', '| Label | Token | Condition |', '| --- | --- | --- |');
      for (const branch of arr(task.params.paths)) {
        const conditions = arr(branch.condition?.rules).map(rule => rule.kind === 'row_count' ? `row count of ${rule.table} ${rule.op} ${rule.value}` : rule.kind === 'custom' ? rule.expr : JSON.stringify(rule));
        atlas.push(`| ${md(branch.label)} | ${inline(branch.token)} | ${branch.else_path ? 'Else' : md(conditions.join(' AND '))} |`);
      }
    }
    if (task.type === 'report') {
      atlas.push('', 'Add report items in this order:', '');
      for (const item of arr(task.params.items)) atlas.push(`- ${inline(item.name)} — ${item.heading || item.name}`);
    }
    const outputs = arr(task.outputs).map(output => inline(output.name) + ' (' + output.kind + ')');
    atlas.push('', '**Declared retained outputs:** ' + (outputs.join(', ') || 'external file / control operation; no ordinary table output') + '.', '');
    if (task.params.output_enabled && typeof task.params.output_enabled === 'object') atlas.push('Output switches: ' + Object.entries(task.params.output_enabled).map(([key, value]) => key + '=' + value).join(', ') + '.', '');
  });
  atlas.push('### Retained-table checkpoints', '', 'These dimensions were read from the saved project. A table with a graph-oriented name may be plotting data, a summary or a capped subset; read its task\'s semantics before using it as full analytical input.', '', '| Table | Rows | Columns |', '| --- | ---: | --- |');
  for (const table of example.tables) atlas.push(`| ${inline(table.name)} | ${table.rows} | ${arr(table.columns).map(inline).join(', ')} |`);
  atlas.push('', '**Files supplied with the example:** ' + arr(example.exports).map(inline).join(', ') + '.', '',
    'Run the flow, inspect its Results and report, and check the resolved Export/Export Log destinations. Save a `.igpx` copy, reopen it and verify the retained table/report before relying on a rerun elsewhere. Existing logs can include earlier runs; use task-run IDs and timestamps when comparing.', '');
}
const defaults = [
  '# Parameter and output reference {#parameter-reference}', '',
  'This appendix is an exact snapshot of each current constructor, using `result` as an illustrative output-name argument. It is a reference for saved configuration and generated R, not an instruction to edit an archive by hand. Blank/NULL/NA, empty vectors and FALSE have different meanings. New task creation can also apply project style defaults or a task-specific output name.', '',
  'The shared graph/statistical schema contains fields for several task families. Only the relevant controls are exposed/applied by a given task. Consult its substantive reference entry for applicability and behavior; a shared `size`, `family`, `paired` or `horizon` field is not proof every task implements it.', '',
  '## Task index', '', '| Task | Category | Examples |', '| --- | --- | --- |'
];
for (const task of metadata.registry) defaults.push(`| ${taskLink(task.id)} | ${task.category} | ${metadata.examples.filter(example => arr(example.task_types).includes(task.id)).map(exampleLink).join('; ')} |`);
for (const task of metadata.registry) {
  defaults.push(`\n## ${task.label}: saved defaults {#defaults-${task.id}}`, '', `[Read the task explanation](#task-${task.id}). Internal type: ${inline(task.id)}.`, '', '```r', task.defaults_r, '```');
  if (task.output_definitions) {
    defaults.push('', '| Output key | Kind | Meaning | Constructor enabled |', '| --- | --- | --- | --- |');
    for (const output of task.output_definitions) defaults.push(`| ${inline(output.key)} | ${output.kind} | ${output.label} | ${task.defaults.output_enabled[output.key]} |`);
  }
}
const reference = [
  '# Keyboard, menus and working references {#working-reference}', '',
  '## App-wide shortcuts', '',
  'App Ctrl+Alt shortcuts are ignored in ordinary text/select/code editing contexts. Native desktop accelerators and console shortcuts are separate layers; use the app\'s shortcut reference for the currently running build.', '',
  '| Keys | Action |', '| --- | --- |',
  '| Ctrl+Alt+Left/Right | Previous/next tab |', '| Ctrl+Alt+W | Close active task tab |',
  '| Ctrl+Alt+F | Process Flow |', '| Ctrl+Alt+K | Code |', '| Ctrl+Alt+C | R Console |',
  '| Ctrl+Alt+N | Add Task |', '| Ctrl+Alt+R | Run active flow |', '| Ctrl+Alt+S | Save |',
  '| Ctrl+Alt+Z | Undo supported project deletion/change |', '| Ctrl+Alt+/ | Shortcut reference |',
  '| Tab / Shift+Tab | Focus navigation |', '| Left/Right, Home/End on a focused tab | Activate adjacent/first/last tab |',
  '| Delete on a focused task tab | Close its panel, not delete its task |', '',
  '## Desktop menus', '',
  '| Menu | Commands |', '| --- | --- |',
  '| File | New, Open, recent/pinned projects, clear unpinned recents, Close project, Save, Save As, saved versions, files/portability, Settings, close app |',
  '| Edit | Text Undo/Redo/Cut/Copy/Paste/Select All, project Undo, project Search |',
  '| View | Flow, Code, Console, Task list, History, Comments, Review, zoom/reset zoom, fullscreen |',
  '| Task | Add task, Validate active flow, Run records, Run active flow, Stop run |',
  '| Session | Restart R server, Open startup log, Open logs folder, Save diagnostic log |',
  '| Help | Application help, Keyboard shortcuts, About |', '',
  '| Native desktop keys | Action |', '| --- | --- |',
  '| Ctrl+N / Ctrl+O | New/Open project |', '| Ctrl+W | Close project |',
  '| Ctrl+S / Ctrl+Shift+S | Save / Save As |', '| Ctrl+Shift+F | Search project |',
  '| Ctrl+Alt+L | Task list |', '| Ctrl+Shift+F5 | Stop flow run |',
  '| Ctrl+Shift+R | Restart R server |', '| F1 | Application help |', '',
  'Menu enablement reflects connection, welcome/recovery/modal/run state. Restart and diagnostics remain desktop-shell actions. In a normal browser, use the visible Shiny controls rather than assuming the native menus exist.', '',
  '## Logging field tokens', '', '| Visible field | Template token |', '| --- | --- |'
];
// Named vectors lose their labels in JSON unless explicitly represented; token order is stable.
const fieldNames = ['Task ID','Task name','Task type','Status','Input names','Output names','Input rows (total)','Input columns (total)','Output rows (total)','Output columns (total)','Elapsed seconds','Original message','Source','Destination','File format','Flow ID','Loop iteration'];
arr(metadata.logging_fields).forEach((token, index) => reference.push(`| ${fieldNames[index] || token} | ${inline('{' + token + '}')} |`));
reference.push('', '## Format compatibility', '', '| Value kind | Export formats |', '| --- | --- |');
for (const [kind, formats] of Object.entries(metadata.export_formats)) reference.push(`| ${inline(kind)} | ${arr(formats).map(inline).join(', ')} |`);
reference.push('', '## Version and retention quick reference', '',
  `Package ${metadata.package_version}; project archive format ${metadata.project_format}; ${metadata.task_count} task types; ${metadata.examples.length} source-edition examples.`, '',
  '| Record/display | Current bound/default |', '| --- | --- |',
  '| Retained task events | Latest 1,000 per task across runs |', '| Run records | Latest 200 task runs |',
  '| Saved project versions | Default 20; configurable 0–100 |', '| Recovery timer | About 30 seconds, scheduled after I/O |',
  '| Desktop diagnostic rotation | 5 MiB current file, five earlier files |', '| Ordinary recent / pinned projects | Up to ten each |',
  '| Dataset/task preview | Common first-1,000-row display cap, with separate page length |',
  '| Graph table/display limits | See graph chapter; many retained graph tables and matrix displays cap at 1,000 |',
  '| Console history / plots | Recent 200 commands / 12 plots |',
  '| Console command / transcript | 100,000-character command; bounded transcript tail |', '',
  '# Glossary and source notes {#glossary}', '',
  ...Object.entries({
    'Active flow': 'The flow currently presented and used by active-flow execution/code export. Other flows can supply dependencies but are not automatically one universal scheduler.',
    'Artifact': 'A retained file such as a report, with companion assets when required. An external Export file and a project payload have different persistence rules.',
    'Background worker': 'An isolated R process that computes transferable tasks and returns results. It cannot safely transfer every live handle or environment.',
    'Branch token': 'A named control output indicating an activated route. It is not an ordinary table.',
    'Cached result': 'A previously calculated retained value. Its presence does not prove it matches changed settings or refreshed inputs.',
    'Complete case': 'A row observed on the fields required by a particular operation. Different models can select different complete-case subsets.',
    'Dependency': 'A declared prerequisite established by input/output names, explicit status references or control paths.',
    'Dirty project': 'A working project with changes not committed to its explicit saved file.',
    'Event level': 'In survival tasks, the value meaning an observed event. In logging, severity is a different concept.',
    'Export': 'An external file write. It does not automatically become another named analytical table.',
    'Fingerprint': 'A content/configuration identifier with recorded completeness limits. It is evidence about values, not a copy of every external source.',
    'Flow': 'A named collection of tasks and their dependency/layout information within a project.',
    'Generated bundle': 'pipeline.R plus pipeline_support.R and a README, executable without the application when packages/inputs are supplied.',
    'Lazy table': 'A database-backed query/table whose values depend on a live connection and remote contents.',
    'Loop body': 'The dependent task subgraph repeated for each loop record; it receives iteration context.',
    'Materialization': 'Collecting database-backed values into an in-memory dataset suitable for local operations.',
    'Model object': 'The fitted R value with methods/state, distinct from its coefficient or fit-summary table.',
    'Output name': 'The data/object contract a producer declares and consumers reference. It differs from the descriptive task label.',
    'Portable application': 'The executable edition that extracts its bundled runtime per launch. It is distinct from a portable analytical project.',
    'Portable project': 'A .igpx export bundling supported local imports and retained exports, not every arbitrary script/package/database dependency.',
    'Preview': 'A calculation/display without committing that retained task result; it is not a sandbox for arbitrary code.',
    'Recovery': 'A dirty-work snapshot offered after interruption. It does not replace explicit Save or reverse external writes.',
    'Run record': 'Retained configuration/input/output/environment evidence for a task execution, separate from textual log events.',
    'Schema': 'Column names, classes and relevant structure. A changed schema can invalidate downstream configuration.',
    'Seed': 'A configured input to random-number generation. Reproducibility still depends on data, ordering, code and environment.',
    'Stale': 'A retained result whose settings or upstream inputs have changed and needs appropriate recomputation.',
    'Task': 'A configured pipeline operation with declared inputs/outputs, execution state and logging.',
    'Trust decision': 'Acceptance of a project source/content for opening; it is not isolation from the filesystem or proof of analytical correctness.'
  }).map(([word, meaning]) => `**${word}.** ${meaning}\n`), '',
  '## Source and dataset acknowledgements', '',
  'Individual Guide is the R/Shiny project by Thomas Wood, distributed under the project\'s MIT license. R, packages, Pandoc, Electron/Chromium, fonts and other bundled components retain their own licenses. The app\'s share-nodes glyph is Font Awesome Free; the desktop attribution identifies Fonticons and CC BY 4.0. This handbook uses screenshots of the application with tutorial data and a chart from its actual Iris example.', '',
  'The example sources are the R datasets package and survival::lung. Their original observations, authors, units and references are documented in the corresponding local R help pages, for example `help("iris", package="datasets")`, `help("state", package="datasets")` and `help("lung", package="survival")`. Prepared fields and teaching limitations are described in source tasks, notes and the example atlas. No external data download is required for these projects.', '',
  'The handbook describes the inspected source rather than promising that every old binary has its newest options. Source identities are recorded in app-reference.json and the build manifest. The following map identifies the implementation used for factual review:', '',
  '| Topic | Primary source files |', '| --- | --- |',
  '| Catalogue/defaults/results | R/task_registry.R; task constructors/execution modules; R/phase3_integrity.R |',
  '| Projects/recovery/assets | R/project.R; R/project_artifacts.R; R/project_product.R; R/project_tools.R |',
  '| Runs/controls/workers | R/executor.R; R/run_control.R; R/task_execution.R; R/background_execution.R; R/loop_execution.R |',
  '| Console/code | R/console.R; R/console_tools.R; inst/app/www/ig_console*.js; R/code_gen.R; R/code_runtime.R; R/code_bundle.R |',
  '| Log/report/export | R/task_logging.R; R/logging_rules.R; R/mod_task_logging.R; R/mod_task_report.R; R/mod_task_export.R |',
  '| Menus/install/security | tools/desktop/menus.cjs; tools/desktop/main.cjs; tools/desktop/security.cjs; tools/desktop/BUILD-README.md; tools/build-standalone.ps1 |',
  '| Examples | R/examples.R; tools/example-recipes.R; actual inst/examples/*/project.igpx archives |', '',
  '## Maintaining the edition', '',
  'When a task, example or runtime behavior changes, refresh the metadata and review its narrative entry. Coverage and source-hash checks can detect missing/stale snapshots, but an editor must still review meaning and rendered layout. Keep source and release distinctions explicit until an actual new installer is built and tested.', ''
);
fs.mkdirSync(out, {recursive: true});
fs.mkdirSync(path.join(out, 'generated'), {recursive: true});
fs.cpSync(path.join(source, 'assets'), path.join(out, 'assets'), {recursive: true});
const generated = {'14-examples.md': atlas.join('\n'), '15-parameters.md': defaults.join('\n'), '16-reference.md': reference.join('\n')};
for (const [file, content] of Object.entries(generated)) fs.writeFileSync(path.join(out, 'generated', file), content + '\n');
const illustrations = '\n\n![A project separates original data, calculation and reader-facing deliverables; task events can be collected in a final audit export.](assets/workflow.png)\n\n';
let complete = authored.replace('## What a project contains', illustrations + '## What a project contains');
complete = complete.replace('## A useful first session', '\n![The real source-edition R Console with retained output, command composer and project-data controls.](assets/r-console.png)\n\n## A useful first session');
complete = complete.replace('## Write a results file', '\n![The actual Iris example plots sepal length against petal length by species.](assets/iris-chart.png)\n\n## Write a results file');
complete += '\n\n' + Object.values(generated).join('\n\n');
fs.writeFileSync(path.join(out, 'Individual-Guide-Handbook.md'), complete);
const args = process.argv.slice(2);
const custom = args.indexOf('--pandoc');
const candidates = [custom >= 0 ? args[custom + 1] : '', process.env.PANDOC,
  path.join(process.env.LOCALAPPDATA || '', 'Pandoc/pandoc.exe'), 'pandoc'].filter(Boolean);
const pandoc = candidates.find(command => spawnSync(command, ['--version'], {encoding:'utf8', windowsHide:true}).status === 0);
if (!pandoc) throw new Error('Pandoc not found; set PANDOC or --pandoc.');
const common = [path.join(out, 'Individual-Guide-Handbook.md'), '--from=markdown+fenced_divs+header_attributes', '--standalone', '--toc', '--toc-depth=2', '--number-sections',
  '--metadata=title:Individual Guide: The Complete Handbook', '--metadata=subtitle:Installation, every task, complete projects and daily operation',
  '--metadata=author:Individual Guide project documentation', '--metadata=date:Release 0.4.0 · 19 October 2026', '--metadata=lang:en-CA',
  '--resource-path=' + source, '--syntax-highlighting=pygments'];
function convert(extra, name) {
  const result = spawnSync(pandoc, [...common, ...extra, '-o', path.join(out, name)], {encoding:'utf8', windowsHide:true, maxBuffer:10*1024*1024});
  fs.writeFileSync(path.join(out, name + '.build.log'), (result.stdout || '') + (result.stderr || ''));
  if (result.status !== 0) throw new Error('Pandoc failed for ' + name + ': ' + result.stderr);
  console.log('Rendered', name);
}
convert(['--to=html5','--embed-resources','--template=' + path.join(source, 'assets/book-template.html'), '--css=' + path.join(source, 'assets/book.css')], 'Individual-Guide-Handbook.html');
convert(['--to=epub3','--split-level=1','--css=' + path.join(source, 'assets/epub.css')], 'Individual-Guide-Handbook.epub');
convert(['--to=docx'], 'Individual-Guide-Handbook.docx');
const wordCount = (complete.match(/\S+/g) || []).length;
const manifest = {title: metadata.title, edition: metadata.edition, packageVersion:metadata.package_version,
  projectFormat:metadata.project_format, tasks:metadata.registry.map(task=>task.id), examples:metadata.examples.map(example=>example.id),
  exampleSteps:metadata.examples.reduce((n,example)=>n+example.tasks.length,0), words:wordCount,
  chapters:chapterFiles.map(name=>({name,sha256:digest(path.join(source,'chapters',name))})), source_md5:metadata.source_md5,
  metadataSha256:digest(path.join(source,'data/app-reference.json')), outputs:[], builtAt:new Date().toISOString()};
for (const file of fs.readdirSync(out).filter(name=>/^Individual-Guide-Handbook\.(md|html|epub|docx)$/.test(name))) manifest.outputs.push({file,bytes:fs.statSync(path.join(out,file)).size,sha256:digest(path.join(out,file))});
fs.writeFileSync(path.join(out,'manifest.json'), JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({words:wordCount,tasks:metadata.registry.length,examples:metadata.examples.length,exampleSteps:manifest.exampleSteps,out},null,2));
