# Individual Guide

A low-code analytical pipeline builder, packaged as the R package
**IndividualGuide**. It replicates the core workflow of GUI analytics tools
(SAS Enterprise Guide-style): you import data, chain tasks together on a
visual process-flow canvas, and every task generates readable R code behind
the scenes.

## Complete handbook

The [complete app handbook](docs/book/README.md) covers installation, every task,
all 22 example projects, execution, logging/reports, the console, code exports,
review, troubleshooting and desktop development. Editable chapter sources and a
source-backed reference are in `docs/book/`; offline HTML, PDF, EPUB and Word
editions are built into `build/book/`. The 0.4.0 edition covers the current source and rebuilt desktop release.

## Installation

```r
# Install from GitHub, including dependencies
install.packages("remotes")
remotes::install_github("woodtho/IndividualGuide", dependencies = TRUE)

# from a local checkout
install.packages("devtools")
devtools::install_deps()   # install package dependencies from DESCRIPTION
devtools::install()        # install the package itself
```

## Running the app

```r
IndividualGuide::run_app()
```

During development (without installing):

```r
pkgload::load_all()
run_app()
# or simply shiny::runApp() from the package root — app.R handles load_all()
```

## Standalone Windows executable

Download the latest **Setup-Windows-x64.exe** from [GitHub Releases](https://github.com/woodtho/IndividualGuide/releases/latest). Run Setup once, then launch **Individual Guide** from its Start menu or desktop shortcut. The 0.4.0 installer includes the current Shiny app, reduced R runtime/packages, Pandoc and Electron browser. Windows 10/11 x64 is required; allow roughly 1.5 GB for installation. No separate R installation, administrator access or dependency download is needed for normal use.

Later launches reuse the installed runtime. Updating with a newer Setup preserves projects and settings. If R disconnects, choose **Session > Restart R server** or **Ctrl+Shift+R**. File, Edit, View, Task and Help menus provide desktop commands; ordinary Shiny/browser launches retain the in-app toolbar. Use **Session** to inspect or export startup diagnostics.

The release also provides the R source package and Windows R binary, SHA256 checksums and a manifest identifying the exact source commit. The installer is unsigned. [Release instructions](RELEASING.md) explain tagging, automatic builds and publishing. Local build outputs stay in the ignored `build/` folder.

Build it from source with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build-standalone.ps1
```

The build machine needs R, Pandoc, and Node/npm. Runtime dependencies are
resolved from the package metadata and source, staged in a private library, and
checked by `tools/desktop/startup.R`. See
[desktop build instructions](tools/desktop/BUILD-README.md) for paths, retained
user data, dependency recovery, and the executable smoke test.

## What's inside

| Layer | Files | Role |
|---|---|---|
| Entry point | `R/run_app.R`, `R/app_ui.R`, `R/app_server.R` | `run_app()`, top-level UI and server |
| Shared state | `R/store.R` | Reactive store: tables, objects, tasks, multi-flow registry, topological run ordering |
| Task modules | `R/mod_*.R` | One Shiny module per task family (import, query builder, data, describe, phase-3 stats/graphs, script, report) |
| Headless execution | `R/mod_task_*.R`, `R/executor.R`, `R/loop_execution.R` | Shared calculations, guarded execution, dependency ordering and repeated loop bodies |
| Code generation | `R/task_code.R`, `R/flow_code.R`, `R/code_gen.R` | Current task settings and standalone full-flow scripts, including branch gates and loop bodies |
| Canvas | `R/canvas.R` | visNetwork process-flow visualizer with staleness tracking |
| Persistence | `R/project.R`, `R/project_artifacts.R`, `R/connection_catalogue.R` | Transactional `.igpx` projects, report artifacts and saved DB connection settings |
| Module lifecycle | `R/module_lifecycle.R`, `R/preview_lifecycle.R` | Unrun settings, disposable observers and synchronized cached previews |
| Assets | `inst/app/www/` | styles.css / ig_tree.js |

## Task catalogue

- **Data**: Import, Query Builder, Append, Compare, Filter & Sort, Stack /
  Split Columns, Transpose, Rank, Standardize, Random Sample, Remove
  Duplicates, Keep/Drop, Rename, First/Last N, Replace Missing, Derive,
  Recode, Change Types
- **Describe**: Characterize, List Data, One-Way Frequencies, Summary
  Statistics, Summary Tables, Table Analysis, Distribution Analysis
- **Graphs**: bar, bar-line, box, bubble, contour, histogram, line, pie,
  scatter, scatter matrix
- **Models**: linear/logistic/GLM regression, ANOVA, t-test, PCA,
  clustering, correlations, and more
- **General**: Script (arbitrary R as a pipeline step), Report (rmarkdown
  HTML/Word export)
- **Control Flow**: Branch (conditional paths) and Loop (files, datasets,
  groups, parameters, dates, or database-query iterations)

## Working with a project

Add an Import task and choose a local file or database connection. Other
tasks select named inputs and declare named outputs; the canvas derives
connections from those declarations. Header Run executes one task. Run Flow
uses dependency order and reports successes, failures and skipped tasks.
Editing inputs or settings invalidates dependent results across flows.
Unrun settings are saved without requiring a preliminary run.

Use a task's control-flow selector to attach it to a Branch path or Loop
iteration token. A loop repeats its dependent tasks, retains named iteration
outputs, and makes the final successful values available under the ordinary
output names. Include `{index}` or `{output}` in its naming rule when needed
to distinguish results. The Code tab exports the current configuration as a
standalone R script; its installed R packages must also be available wherever
the script is run.

The Code tab opens a concise **Pipeline** view with named steps and shared
support defined once. Switch to **Supporting functions** or **Complete script**
to inspect the calculations and execution details. **Copy R** copies the selected
view. **Download .R** exports a self-contained script; **Download bundle** exports
`pipeline.R`, `pipeline_support.R`, and a README. Keep the two R files together;
run `Rscript --vanilla pipeline.R` or `source("pipeline.R")`. The bundle locates
its support file even when started from another working directory, without
changing the working directory used by your input/output paths.

Exports preserve task settings, dependency/branch/loop behavior, output names,
custom logging and configured random seeds. They record the current RNG kind,
model contrasts and missing-value option. User-written Script steps retain their
code. Optional project seeds apply separately to every task and loop body;
Script steps can also set their own seed. The app itself is not required to
run either export, but referenced R packages, input files and database access are.

Save writes an `.igpx` archive; Save As establishes its new path. Format
0.5.0 reads earlier archives, bundles optional file inputs/exports and run records,
and retains native RDS companions for models,
plots and other values whose environments or attributes JSON cannot preserve.
Numeric archive entry names preserve case-distinct and unusual R names on
Windows. Rendered reports and their Rmd/data companions are included.
Password fields and live connections remain session-only. Custom connection
code is saved as written; use environment variables for credentials. Lazy imports
retain their schema but need reconnection after reopening; affected tasks are
marked for rerun while saved downstream snapshots remain inspectable.

Release 0.3.0 adds previous saved versions, portable file projects and missing-file
relinking, flow validation, reusable task workers, persisted run comparisons and
optional project seeds. Project tools includes a searchable keyboard task list.
The console adds highlighting, safe completion, searchable history, Run selection
and Create Script. Desktop Help reports build information; unfamiliar projects
require trust and desktop sessions authenticate privately on localhost.
See [release notes](NEWS.md) and the [desktop guide](tools/desktop/BUILD-README.md).

The connection form supports SQLite (`RSQLite`) and ODBC (`odbc` plus an
installed driver/DSN). DuckDB uses the existing custom connection-code option
and requires `duckdb`. HTML/Word report rendering uses `rmarkdown`,
`knitr` and Pandoc. When full rendering is unavailable, the application offers
its existing HTML fallback with a diagnostic. Interactive HTML report and
chart exports embed their local dependencies so the files can be moved.

Comments, review decisions, change history, favourites, settings and recovery
are available from the workspace controls. Read-only review blocks execution
and project edits. Delete actions offer Undo; restored disconnected database
inputs need rerunning. The keyboard button lists the existing shortcuts.

## Task logging

Open **Logging** above a task's settings to build its log rules. Each rule has
an event (start, completion, warning, failure, skipped/waiting, R message,
console output or Script `log_event()`), a DEBUG/INFO/WARN/ERROR level, a
message template and an enable switch. Add or remove rules, or use **Reset task
rules** to restore that task type's defaults. Multiple rules can match one event.
Changes save automatically without rerunning the task.
Rules are captured when a run starts; edits during background work apply to the
next run.

Choose a field and use **+** beside a message to insert it at the cursor.
Fields include `{task}`, `{task_name}`, `{type}`, `{status}`, `{inputs}`,
`{outputs}`, `{rows_in}`, `{rows_out}`, `{columns_in}`, `{columns_out}`,
`{elapsed}`, `{message}`, `{source}`, `{destination}`, `{format}`, `{flow_id}`
and `{iteration}`. **Preview an event** shows how the rules and minimum
severity interact without executing the task. Unknown fields stay literal.
Row/column totals describe declared in-memory tables; unavailable or lazy SQL
dimensions display `n/a` and logging never fetches database data for counts.
Templates substitute text only and do not evaluate R code.

The preview shows a **Message inputs** table with each field, token and value,
alongside **Rendered log entries**. Choose current task values or an explicitly
labelled example scenario; example row counts, duration and message can be edited
without changing task settings or executing the pipeline. The **File output
preview** uses the same formatter as the text, CSV and JSON writer. Export Log
also previews the selected retained entries and severity filter, with an example
option for an empty log. Large previews are limited and labelled; exports retain
all selected entries. Previewing never writes the destination file.

Defaults record lifecycle messages at INFO, conditions/skips at WARN, failures
at ERROR, and input diagnostics/console output at DEBUG. Import and data-task
messages include dimensions; output tasks describe their destination or report;
analysis and control-flow tasks have their own lifecycle messages. INFO is the
default minimum severity. Console capture has a separate switch, and its rules
can assign a different severity. **Keep event's level** preserves the severity
passed to Script `log_event()`. Old saved start/completion messages remain valid.
Changing a log entry's severity does not change the task's execution outcome.
Expand Logging to view the latest 100 entries for that task.

Script tasks can add entries at any point:

```r
log_event("Finished cleaning the source", "INFO")
log_event("Some records need review", "WARN")
```

Add **Output > Export Log**, choose the tasks to wait for and include, a full
destination file path, and Text, CSV, or JSON. The task runs in a flow and can
also run alone; it offers a download of the exported file. Failed or skipped
selected tasks do not block this export. If **Stop on error** stops the flow,
run Export Log manually afterward. Put it after a Loop to export all iteration
logs once; attach it to a control path to export within iterations.

The initial selection includes the tasks already in the flow. Add later tasks
to that selection to wait for their new logs. Leaving the selection blank
exports all currently available flow logs without adding ordering dependencies.

Logs retain the latest 1,000 entries per task across runs and are saved in the
project. Copied flows keep logging settings and start with empty logs. Exports
are snapshots of entries already collected, excluding the current export's own
entries. Generated full-flow R scripts collect their own execution logs and
perform the same log export.

## Tests

Run the automated suite from a source checkout:

```r
devtools::test()
# or, with testthat and pkgload installed:
system2("Rscript", "tools/test-focused.R")
```

Suites cover the data/describe/phase-3 execute functions, the query builder
code generator, import readers, the script and report tasks, store/topology
logic, project save-load round trips, the canvas builder, and the headless
Run Flow executor.

`tools/browser-workflow.R` exercises real file/project pickers, execution,
save/reopen, error correction and workspace controls in Edge.
`tools/browser-smoke.R` opens every registered task panel.
`tools/browser-task-logging.R` checks logging controls, log export, and Save/Open.
`tools/browser-portable-artifacts.R` checks moved HTML artifacts.
`tools/package-check.R` regenerates manuals, builds and checks the package.
Browser verification requires `shinytest2` and `chromote`; adjust the Edge path
in the browser scripts for another installation. GitHub Actions retains build and
verification evidence as workflow artifacts; see [release instructions](RELEASING.md).

## License

MIT © Thomas Wood
# Desktop project and run controls

The Windows File menu includes New Project (Ctrl+N), Close Project (Ctrl+W), Recent Projects, and pin/unpin for saved projects. Up to ten unpinned and ten pinned entries are retained in the desktop profile. Clearing recents preserves pinned entries. New and Close clear the workspace without restarting R; Close returns to the welcome screen. Project switches and window closing offer Cancel, Discard, or Save. Cancelled or failed saves leave the current project open.

The installer registers `.igpx` project files. Opening one through Explorer or passing its path to the EXE opens it in the existing instance, or after startup. Requests wait for running work and ordinary modals to finish; recovery prompts are resolved first. Windows may require choosing Individual Guide in “Open with” if another application is already the default.

Task → Run active flow (Ctrl+Alt+R) and Stop run (Ctrl+Shift+F5) complement the visible run status and Stop button in both desktop and ordinary Shiny launches. Status shows the current task, completed/total tasks, and elapsed time. Stop cancels background analyses and queued work. A task executing directly in R finishes its current call before Stop can take effect; restarting R remains available for an unresponsive server. Stopping does not roll back completed tasks or external file/database writes.

Window position, normal size, and maximized state are stored separately from projects. Restored bounds are adjusted to available monitor work areas.

## R console

Open the **R Console** tab, or desktop **View → R console** (Ctrl+Alt+C). The terminal surface keeps output above an expanding command prompt, with colored commands, warnings and errors. **Enter** runs; **Shift+Enter** adds a newline; **Ctrl+Enter** also runs multiline code. **Up/Down** recalls history at the first/last editor line; **Alt+Up/Down** works anywhere and restores your unsent draft. **Ctrl+L** clears output. **Ctrl+C** interrupts a command when no text is selected, retaining ordinary text copying otherwise. Reading earlier output keeps your scroll position; Latest output returns to the bottom. Printed values, messages, warnings, errors and the latest 12 plots appear above the prompt. Save transcript downloads literal text; Clear output removes text and plots while keeping variables. About this session explains data copies, Refresh, Stop and Reset.

The console starts a separate persistent R process on first use. Project tables and saved objects load as named variables and as `.project$tables` / `.project$objects`. **Refresh data** replaces these imported copies with the current project results, including removing retired names, and keeps your other console variables. Live database tables, connections and environments are skipped; collect database results in a task first. Changes made to console copies do not change pipeline outputs.

**Stop** terminates the console process, including long native calls, and clears its variables while keeping output, command history and your unsent draft. The next command starts a fresh workspace. **Reset R** also clears output, plots and history. New/Open/Close project, application exit and server restart clear console work. Commands are noninteractive; use explicit function arguments rather than terminal input prompts. File operations still access your filesystem. To keep reproducible code and results in a project, use a **Script** task.
## Example projects

Open **Help → Example projects** to choose from **22 complete, editable projects** covering every enabled task type. Search by data or workflow, select a task type, or combine it with a task-category filter. Filtering happens in the browser without reloading the app. See [EXAMPLES.md](EXAMPLES.md) for the full task coverage and verification commands.

- **Iris exploration:** 150 real flower measurements; species summaries, a grouped scatter plot and an HTML report.
- **Air quality - clean and compare:** 153 daily observations; missing-value audit, illustrative mean imputation, before/after summaries and a chart.
- **Fuel economy model:** 32 Motor Trend cars; a linear regression, coefficients, fitted values, saved model and report.
- **Data preparation:** car cleaning, state CSV imports and joins, iris reshaping/comparisons, ranking, scaling and seeded sampling.
- **Exploration and charts:** tooth-growth descriptive analysis; categorical, numeric and time-chart galleries covering all ten graph tasks.
- **Models and statistics:** plant-growth ANOVA and t tests; logistic, Poisson and nonlinear models; correlations, PCA and clustering; survival analysis, forecasting and distribution/control diagnostics.
- **Control flow and reporting:** conditional quality gates, iteration by species, and a report with an execution audit plus TXT/CSV/JSON log exports.

Each project includes real input data, executed tasks, saved results, custom logging, a completed HTML report and CSV/log exports. Chart examples retain portable static images; the original three also export PNG files. Everything works offline using data distributed with R, including `survival::lung`. The project README and source-task notes identify the dataset, preparation and interpretation limits.

In any **Report → Appearance**, enable **Include pipeline log in the report** and choose the minimum severity. The appendix snapshots retained events from other tasks in the current flow before report generation. It can contain earlier runs; `run_id` distinguishes them. Export Log after the report to include its completion event. All bundled reports enable the appendix; **Cars - a report with an execution audit** demonstrates a custom warning and all three log-export formats.

Open a task's Logging panel to customize its messages, inspect saved outputs in the project tree, or Run Flow to reproduce all results. Each opening creates a separate writable output folder. Export and Export Log tasks show their destination paths; rerunning overwrites only their example files. Use **Save As** to keep your own project copy. Unsaved work is protected before replacement; the installed examples remain unchanged.

## Performance development

[PERFORMANCE.md](PERFORMANCE.md) records ten hypotheses, measured changes and
repeatable profiling tests. Run `./tools/test-responsiveness.ps1 -BaselineRef
<baseline-ref> -IncludeStartup` for sequential source comparisons with R CPU/allocation
and real-browser profiles. Functional gates and advisory latency targets are
reported separately. Use `Rscript --vanilla tools/browser-console.R --source`
to check the current source console. Release 0.4.0 includes these changes in
the rebuilt installer. Historical baseline commits remain in the local private
history; choose an available baseline ref for a new public comparison.
