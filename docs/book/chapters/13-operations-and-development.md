# Keeping the app responsive {#performance}

Responsiveness has several components: browser input handling, Shiny reactive updates, R calculations, serialization, disk writes and startup/package loading. A slow task is not automatically a browser rendering bug, and a fast model does not guarantee a large project saves instantly.

The current source reduces unnecessary canvas/tree updates when only values or saved metadata change, defers hidden code/log previews, reuses workers, keeps console drafts local, and reduces redundant layout/highlighting work for long drafts. Recovery uses a lower compression level and stored layout instead of rebuilding graph cards. These changes reduce work without deliberately dropping analytical rows or weakening saved-data fidelity.

## Practical choices for everyday work

Keep raw and derived tables clearly named, but remove genuinely unnecessary intermediates when they no longer support reproducibility or review. Retained large objects and per-row model outputs increase memory and project I/O. Enable an augment/scores/model output because you need it, not simply because a checkbox is available.

Filter/select remote data before materializing it for a local model when the question permits. Use a seeded sample for exploratory plotting if a full display is unnecessary, and state that choice in its title/caption. Do not silently replace a full analysis with a sample just to improve perceived speed.

Collapse logging/code panels you are not using. Reduce console printing of giant tables. Use the tree/task list to find tasks on a large canvas. Remember that preview pagination and the first-1,000-row display cap do not reduce the full dataset stored in memory or the work needed by a full-data model.

The dataset preview modal and many task previews show at most the first **1,000 rows**. Their metadata can still report the full row count. Download/export and analytical execution use the underlying value according to the chosen operation; a ten-row page is not a ten-row dataset. Graph data-output caps and scatter-matrix display caps are additional, explicitly documented behaviors.

## When editing feels slow

Identify the trigger: typing in an output name, changing a column selector, opening a large result, autosave, starting a worker or writing a report. Record whether the issue occurs before or during a run. A lag that appears every thirty seconds may involve recovery I/O rather than the expression currently being typed.

Recovery checks dirty work on an approximately **30-second** timer, scheduled after the prior I/O completes. Large tables can still make that synchronous snapshot noticeable. Save important milestones explicitly and use an appropriate local working disk. Synchronized/network folders can add external I/O cost; do not move a project in the middle of a run, and retain backups before changing storage locations.

For an app developer, use profiling evidence before introducing caches that might hide a changed schema or package version. The repository's `PERFORMANCE.md` records ten tested hypotheses and the corresponding experiments. Its remaining latency budgets are visible; the report does not claim that every pause has been eliminated or that allocation totals fell.

## Profiling and regression tools

The repeatable Windows comparison runner is:

```powershell
./tools/test-responsiveness.ps1 -BaselineRef 5c699e4 -IncludeStartup
```

It compares a frozen baseline and current source with R CPU/allocation profiles, Chromium measurements, functional output/update gates, worker checks and recovery reopen tests. Startup tests of the private runtime are identified separately from browser connection and installer extraction. Local timings are measurements under a particular workload, not universal speed guarantees.

When changing performance behavior, check data/state correctness alongside timing. An empty output is fast but not an optimization. A cache that hides a database schema refresh is wrong even if a dropdown becomes instant. Reopen saved data, preserve complete fingerprints where required and verify that the actual working result matches the baseline calculation.

# Troubleshooting by symptom {#troubleshooting}

Start by classifying the failure: startup/connection, project I/O, task configuration, data/schema, numerical method, external export or temporary console state. Capture the relevant error and context before restarting. A restart can recover a process but also erase the transient state needed to understand the cause.

## The executable appears not to open

Confirm you launched the installed shortcut rather than Setup or an older portable snapshot. Allow preparation/startup stages to finish, especially on a first run. Check whether an existing installed workspace has been focused behind another window. If the shell reports failure, open its startup log.

Look for the last completed stage: runtime/dependency check, R process start, HTTP readiness or browser connection. Check the recorded paths and error text. Avoid repeatedly launching many copies as a diagnostic; that adds disk/process activity and makes the evidence harder to read. A self-contained installed release should not require installing random host-R packages to satisfy its ordinary bundled dependencies.

## The workspace disconnects or R stops

Use the desktop's Restart R server control or Session > Restart R server. It operates outside Shiny and can handle an unresponsive backend. Restart stops the server/active work and may lose unsaved changes. Reopen the saved project or inspect an offered recovery snapshot after reconnecting.

If restart fails, keep the log and retry information. A normal-browser launch must be restarted from its hosting R process instead. Do not confuse a stopped console worker with a stopped Shiny backend; running another console command can start a new console workspace without needing an app-server restart.

## A menu command is disabled

Check startup/connection, welcome/recovery state, modal dialogs, read-only review and active flow execution. File replacement commands are restricted during a run or pending operation. Dismiss or finish the relevant state rather than attempting to bypass it through a different button.

If the desktop integration is absent because the app was launched in a normal browser, use the visible in-app controls. If the in-app global buttons are hidden in the EXE, use the native menus. That difference is intentional.

## A file will not import

Check existence and reader format, then delimiter/sheet/range/skip/type/encoding choices. A CSV parsed into one column usually suggests delimiter/quoting choices. An RData file may require the intended object name. A labelled variable from a statistical package may need explicit interpretation rather than blind numeric conversion.

For a moved project, inspect Project files and portability and relink the Import. For an ODBC problem, inspect system driver, network, account and database permissions as well as R configuration. A saved connection preset cannot supply a missing vendor driver or an expired password.

## An input or column is missing

Run the producer, verify its output name and inspect its current schema. A rename retires an old name; downstream tasks may need repair. A field can be absent because a prior Keep/Drop step deliberately removed it. A model's prediction table needs its own required columns, not only the training table's schema.

If the task uses a Loop variable or `.loop_data`, verify its control-path wiring and iteration type. Those are context values, not necessarily ordinary global tables. If it uses a value from another flow, run/provide that producer rather than assuming every active-flow run refreshes the whole project.

## A result looks old or empty

Distinguish Preview from Run, a current table from an old report artifact, and a display limit from a changed dataset. Rerun affected downstream tasks after changing an upstream result. Check whether a Branch skipped the path or whether the current minimum log level filtered out all events.

An empty table can be the correct outcome of a filter; inspect its condition and missing-value handling. A successful Summary Statistics with no numeric fields can return an explanatory table. A Report may succeed while skipping uncomputed requested items with warnings. Read result messages rather than interpreting every empty panel as a reload issue.

## A model fails or produces surprising estimates

Check response/predictor types, missingness, constant variables, factor levels, complete-case sample size and nonfinite values. For nonlinear power curves, X/Y must be positive and sufficient complete pairs are needed. For logistic models, separation can cause instability. For PCA, constant columns conflict with internal scaling. For clustering, check K against the number of complete observations and whether scaling was intended.

Do not repair an error by choosing a method solely because it returns a result. Compare the data and specification with the method's intended assumptions. Use the specific task reference and underlying R help for a deeper method-specific investigation.

## A report is missing a chart or Word fails

Ensure the selected retained plot/image output is enabled and has run. Prefer static images for Word; browser widgets do not carry their live behavior into DOCX. Inspect skipped-item warnings and actual output classes. A cached interactive widget can need local regeneration when fonts/resources differ.

Word requires Pandoc and report packages. HTML has a fallback renderer. Check the recorded warning to see which renderer was used. Open the downloaded document outside the app to distinguish a missing external resource from an in-app viewer problem.

## An export fails or overwrites the wrong file

Inspect source kind, chosen format, resolved folder/filename and Overwrite/Append. The folder must exist and be writable. Only CSV/TSV support Append. Interactive plot raster export requires choosing the static plot output. A file open in another application can prevent replacement.

In a Loop, inspect substituted `{item}`/`{index}` paths. A fixed filename plus Overwrite can intentionally leave only the last iteration. In a portable project, destinations relocate; do not assume they still point to the original author's folder. External writes already completed before Stop or failure are not rolled back.

## A project will not save or load

Verify path permissions, disk space, file availability and whether another application is holding the target. Preserve the original archive and diagnostic message. Try an appropriate Save As location when the current path is unavailable. Inspect retained saved versions/recovery before deleting anything.

The loader checks archive structure and limits; an invalid/incomplete archive is not fixed by renaming its extension. Older supported formats and native serialization need the relevant application/R compatibility. Treat unfamiliar archives as potentially executable R content and use the actual trust workflow.

## The console forgot variables or completion is incomplete

Stop/Reset/project switching can clear the console workspace. Refresh data replaces project copies. The next command may start a fresh worker. Use Script tasks for persistent analytical work. Completion does not evaluate arbitrary expressions and only offers captured/known metadata, including already loaded namespace exports.

## Reporting a useful defect

Give the app/build identity, source-versus-installer distinction, operating environment, minimal steps, expected result and actual message. Include a small shareable project/input, task log and, for startup, desktop diagnostic log. Keep failed artifacts long enough to investigate. State which workaround helped, if any, without presenting it as proof of the underlying cause.

# Extending, building and verifying the application {#development}

This chapter is for maintainers. Ordinary desktop users do not need to compile R packages or run Electron tooling. The repository is an R package with a Shiny interface and a desktop wrapper, not two separate analytical engines.

## Architecture map

| Area | Main source locations | Responsibility |
| --- | --- | --- |
| Entry/workspace | `R/run_app.R`, `R/app_ui.R`, `R/app_server.R` | Construct app, route project/UI actions |
| Store and dependencies | `R/store.R`, `R/ui_reactivity.R` | Tables/objects/tasks/flows, dependency and UI snapshots |
| Task calculations/forms | `R/mod_task_*.R`, `R/mod_phase3_tasks.R`, `R/phase3_integrity.R` | Parameters, panels, calculations and common analytical helpers |
| Execution | `R/executor.R`, `R/task_execution.R`, `R/background_execution.R`, `R/task_worker.R`, `R/loop_execution.R` | Guarded synchronous/worker execution and loops |
| Code export | `R/task_code.R`, `R/flow_code.R`, `R/code_gen.R`, `R/code_runtime.R`, `R/code_bundle.R` | Standalone task/pipeline/support code |
| Project I/O | `R/project.R`, `R/project_artifacts.R`, `R/project_product.R` | Archives, reports, portable files, versions/run records |
| Logs/console | `R/task_logging.R`, `R/logging_rules.R`, `R/mod_task_logging.R`, `R/console*.R` | Retained events, rule UI and console worker |
| Desktop shell | `tools/desktop/` | Menus, restricted bridge, startup, lifecycle and packaging |
| Examples | `R/examples.R`, `tools/build-examples.R`, `tools/example-recipes.R`, `inst/examples/` | Catalogue, recipes and executed project assets |
| Book | `docs/book/`, `tools/book-*`, `tools/build-book.cjs` | Source-backed handbook and rendered artifacts |

Preserve shared execution/code-generation parity. A task added only to a panel but not to the headless dispatcher or generated pipeline is incomplete. Parameter changes must be saved without forcing execution. Unopened panels must still run from saved configuration. New results should update open previews without recomputing them solely for display.

## Source development and dependencies

Install package dependencies from `DESCRIPTION`, then load the source with `pkgload::load_all()`. Use a suitable current library and record versions when reproducing numerical or serialization problems. The desktop runtime's dependency lock/manifests serve a different purpose from a developer's arbitrary global R library.

The release tooling checks `renv.lock` and refuses mismatched dependency closures rather than silently updating the lock during packaging. Intentional dependency changes need the explicit lock-maintenance workflow (`tools/lock-runtime.R`) and verification. Do not describe a build that happened to find packages on your computer as a reproducible standalone distribution.

### State paths and development overrides

The desktop supplies `IG_USER_DATA` and its runtime/port settings; normal users should use its installer/profile controls. A source launch can override these documented R options for development and isolated tests:

| Option/environment | Purpose |
| --- | --- |
| `IG_USER_DATA` | Root for supported project-output/backup/example state; the desktop sets its profile root |
| `options(ig.examples_dir = ...)` | Root for writable example copies |
| `options(ig.recovery_dir = ...)` | Recovery storage; source fallback uses R's app cache directory |
| `options(ig.catalogue_dir = ...)` | Connection catalogue directory; source default is `~/.rIG`, desktop uses its profile's connections directory |
| `options(ig.backup_dir = ...)` | Override saved-version storage |
| `options(ig.background_workers = 2L)` | Process-wide worker-slot limit; zero disables worker scheduling |
| `options(ig.max_project_bytes = 8 * 1024^3)` | Project archive expanded-byte bound; the loader also limits archive entry count to 50,000 |
| `IG_AUTHOR` | Preferred local author label for collaboration records |

These are development/session controls, not extra hidden GUI settings promised in every release. A process-wide worker limit does not turn one flow into an unrestricted parallel scheduler. Use separate temporary state directories for tests, and do not point destructive test scenarios at a user's real profile. The desktop's normal healthy startup is offline; its explicit dependency-recovery flag is not a substitute for packaging a complete verified runtime.

## Building the desktop package

The Windows build machine needs R, Pandoc and Node/npm. From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build-standalone.ps1
```

The default target is the installer. `-Target portable` selects the optional portable build. `-RHome` and `-Pandoc` override build-machine paths. `-SkipRuntime` and `-SkipNpm` reuse prepared inputs only when their verification passes; they are not permission to ship stale source.

The script prepares a private R/runtime closure, installs the current app, retains required fonts/native libraries/templates/licenses, creates matching icon resources and packages the minimal browser shell. It records build metadata and verifies staged functions/resources against source. Test/development/manual material can be omitted from the reduced runtime; arbitrary user scripts may still need extra packages/tools separately.

Build intermediates under staging/win-unpacked are not required beside a complete distributable. Do not replace the user's installed app as an incidental test step. Use isolated data profiles and unpacked test copies, and identify exactly which source snapshot the final installer contains. The 0.4.0 release rebuilds the installer from matching committed source.

## Test layers

Run package tests from the repository root:

```powershell
Rscript --vanilla tools/test-focused.R
```

An optional filename filter narrows a focused investigation:

```powershell
Rscript --vanilla tools/test-focused.R "examples|report-logging|report-integrity"
```

The suites cover calculation, parameter/store/dependency behavior, import/query semantics, code generation, logs, report portability, project round trips, controls and workers. A focused pass supports its tested scope; it is not automatically a full-suite or clean-machine certification.

Real-browser drivers exercise task panels, file dialogs, workflows, console interaction, logging and examples. They need their documented development dependencies, including `chromote`/`shinytest2` and an available Chromium browser. Desktop smoke drivers additionally exercise native menus, lifecycle, restart and bundled-runtime behavior. A green source-browser test does not prove a stale staged installer has the same code.

Use `tools/test-installed.ps1` against an installed executable when intentionally testing that installation, and the standalone/clean-machine/sandbox helpers for their documented environments. These can launch actual applications or interact with a test installation; inspect their parameters and isolate state. `tools/package-check.R` performs the package/manual/build checks. Keep acceptance evidence and failures clearly identified in audit/completion records.

## Rebuilding examples

Run:

```powershell
Rscript --vanilla tools/build-examples.R
```

The builder executes the real configured tasks, checks catalogue task types, bundles inputs and saves `.igpx` archives with completed results/reports/logs. Optional example IDs rebuild selected projects. It is not a generator of empty placeholder diagrams. Follow with example round-trip/rerun and browser checks. If a recipe changes, refresh the handbook's extracted metadata and rendered atlas.

## Rebuilding and reviewing this book

The book's README gives the current build commands. Refresh its source-backed metadata, assemble narrative plus generated task/parameter/example references, render offline HTML/EPUB/PDF, and run the book verification. Inspect the rendered result at a desktop and narrow viewport and inspect representative PDF pages, not only a word count.

Coverage checks require each enabled task and example, but coverage is only one part of accuracy. Read source when UI text and implementation differ. For this edition that matters for scatter sizing, first-1,000-row graph outputs, PCA/clustering scaling, survival event coding, default t-test behavior and source-versus-installer capabilities.

Do not mark a documentation goal complete merely because a converter produced a file. Verify working links/navigation, local assets, Unicode, code blocks, table/page layout, example values and every named deliverable. Retain a source/coverage manifest so a later maintainer can tell whether the book still describes the app they are shipping.
