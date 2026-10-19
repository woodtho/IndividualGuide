# Responsiveness investigation — 2026-10-19

The goal is responsive editing and less unnecessary rendering across the app.
These are testable hypotheses, not ten assumed bugs. The baseline is commit
`5c699e4`; the same drivers exercise its frozen source and the updated checkout.

| # | Hypothesis | Experiment and evidence | Decision |
|---|---|---|---|
| 1 | Changing table values or saving derived flow snapshots redraws graph cards and the project tree unnecessarily. | Replace values in a 200,000-row, 12-column table while the graph is visible. Count `canvas_build_network` calls and Shiny output messages; separately rename columns, change dimensions, add/remove tables and snapshot the active flow. | Publish distinct table names and graph metadata; omit the active flow's duplicate saved task snapshot from tree metadata. Previews and schema selectors still read current data. |
| 2 | Editing a task pays for logging previews inside its collapsed Logging section. | Type 12 numeric edits in a 102-task project; record `log_*-preview*` messages. Open Logging afterwards and verify current preview content. | Gate preview work on the native details element's open state. Recording logs and saving rules remain independent of this gate. |
| 3 | Invalidating a long chain creates a reactive context for every unused preview. | CPU/allocation profiles of a 200-task chain edit and invalidation, plus 40-task execution. Check consumer order, stale outputs and mounted preview callbacks. | Read the callback registry once per invalidation wave; invoke only mounted callbacks. |
| 4 | Recovery rebuilds the canvas and blocks the shared R thread on ZIP compression longer than necessary. | Three paired level-9/level-1 trials of a 19 MB table, exact extraction checks, real timer autosave with websocket pings, and save/reopen/layout tests. | Recovery uses level 1 and retains stored layout without regenerating graph cards. Explicit saves retain level 9 and existing atomic replacement/backups. |
| 5 | Long console drafts rebuild unchanged tokens, force layout and send unused draft inputs to R per character. | Chrome CPU profile, input-handler/animation-frame timings for 20 edits over 20,000 characters, DOM identity, literal text and server-input checks. | Reuse unchanged highlighted prefixes; observe composer size after layout, retain capped editor heights on append, and keep drafts/history search in the browser. |
| 6 | Column dropdowns repeatedly scan every row to calculate statistics. | Twenty schema reads of 200,000 rows × 12 columns; CPU/allocation profiles and real query-editor schema replacement. | Retain the existing bounded schema cache; guard live database freshness and session isolation. No speculative replacement. |
| 7 | Hidden code panels regenerate the complete pipeline while typing. | Instrument `build_full_r_script` during the 12 edits while Code is hidden. | Require zero builds. Existing output suspension already handles this case. |
| 8 | Every background task starts another R process and freezes the UI. | Run actual 6,000-row hierarchical clustering twice; record completion, worker PID, cold/warm duration and concurrent server ping latency. | Require the same worker PID and real output. Keep startup/transfer/parent-render delays visible separately from worker reuse. |
| 9 | Capturing package/environment metadata dominates ordinary runs. | Profile 100 environment captures and 20 run records with a 100,000-row input; preserve complete hashes and recorded versions. | Measure before introducing a cache that could hide newly loaded packages or changed versions. |
| 10 | Eagerly loading every bundled package makes startup unnecessarily slow. | Three fresh private-R processes for normal namespace loading and three for eager loading; record namespaces, CPU/wall time and resident memory. Browser connection time is recorded separately. | Preserve deferred loading. This experiment uses the shipped private runtime; it does not measure installer extraction or an updated executable. |

## Run the measurements

From the repository root on Windows:

```powershell
./tools/test-responsiveness.ps1 -BaselineRef <baseline-ref> -IncludeStartup
```

The runner executes baseline and updated workloads sequentially, freezes the
baseline with `git archive`, freezes each driver before execution, and stops on a
failed process. It never installs over the user's app or opens their projects.
Browser/recovery/catalogue state lives in temporary test directories. The
browser driver needs the existing development dependencies `shinytest2`,
`chromote`, and Microsoft Edge. Startup profiling needs `build/staging/runtime`.
Use `-Rscript` for another Rscript path or `-SkipBrowser` for backend-only work.

Results are under `artifacts/performance/responsiveness/<run-id>/comparison.md`
and `.json`, with raw workload timings and allocation profiles in the matching
`artifacts/performance/<run-id>-before` and `-after` directories. Browser JSON,
screenshots, R CPU stacks and Chrome `.cpuprofile` files are under matching
`artifacts/performance/responsiveness/browser-<run-id>-before` and `-after`
directories. Load a `.cpuprofile` in Chromium DevTools' Performance panel. R
profiles include `summaryRprof` totals/self summaries and raw `Rprofmem` records.

Ten backend workloads use three independent timed trials and separate CPU and
allocation passes. Browser timing uses `performance.now()` through actual Shiny
websockets; it excludes AppDriver's fixed idle-wait padding. Initial widget
hydration is recorded separately from steady editing. Recovery autosave stays
enabled, including during typing and background calculations. Long-task entries
and visible errors are retained. The heavy result's run timestamp and row count
prove that both worker runs completed, rather than accepting an old success.

## Regression checks and interpretation

```powershell
Rscript --vanilla tools/test-focused.R 'responsiveness|ui-reactivity|performance-invalidation|task-logging-preview|project-integrity|project-artifacts|readiness-reload'
Rscript --vanilla tools/browser-console.R --source
```

The browser's `--check` mode enforces zero graph reloads during steady numeric
edits/value-only changes, zero hidden full-code builds, zero collapsed log
preview messages, preserved editor focus/DOM, correct large-draft highlighting,
working on-demand log previews, schema refresh, real recovery writes, complete
worker output and worker reuse, and console drafts absent from server input.
Unit regressions cover dimension changes, lazy
database metadata without collection, adding/removing tables, session isolation,
ordered preview invalidation, reopening log previews and exact recovery of data
and model predictions without changing project identity or manual layout. The
source-console browser suite also runs real commands, Enter/Shift+Enter/history,
interrupt/copy, plots, scrollback, dark/light themes and responsive layouts.

300 ms editing/worker ping p95 and 50 ms warm console-handler p95 are explicitly
reported advisory targets. They do not silently become passing assertions if
the machine misses them. Functional gates are deterministic; timing changes
must be reviewed with their absolute values, profiler stacks and host load.
Three-trial medians are local observations, not guarantees for other hardware.
The initial compression experiment was interleaved; the main comparison runs
the full baseline and updated suites sequentially.

## Measured results

Historical development comparison (raw evidence is local and is not published): full table (`artifacts/performance/responsiveness/responsiveness-20261019-084705/comparison.md`, local evidence),
machine-readable results (`artifacts/performance/responsiveness/responsiveness-20261019-084705/comparison.json`, local evidence),
and run metadata (`artifacts/performance/responsiveness/responsiveness-20261019-084705/metadata.json`, local evidence).
All ten backend workloads completed three timing trials and allocation profiles
per source version; nine also have CPU profiles. All eight main-browser
functional gates passed.

| Measurement | Baseline | Updated source |
|---|---:|---:|
| Numeric edit median / p95 | 371.6 / 535.5 ms | 246.2 / 505.6 ms |
| Hidden logging preview messages across 12 edits | 48 | 0 |
| Graph builds for a value-only replacement | 1 | 0 |
| Graph builds / tree replacements during steady editing | 1 / 1 | 0 / 0 |
| Console input-handler median, draft over 20,000 characters | 1,014.5 ms | 63.2 ms |
| Console animation-frame median in that workload | 1,134.7 ms | 85.5 ms |
| Invalidate 200 tasks, median | 0.39 s | 0.18 s |
| Edit first task in a 200-task chain, median | 0.56 s | 0.28 s |
| Execute 40 tasks, median | 9.22 s | 7.61 s |
| Actual dirty autosave: ping p95 / maximum | 10,232 / 11,596 ms | 2,780 / 4,071 ms |
| Actual dirty autosave: graph builds | 1 | 0 |

The isolated dirty-window probes each recorded a real timer save, reopened its
archive, recovered the latest numeric setting (31), and verified identical full
200,000 × 12 data. They ran sequentially after the main comparison; their logs
and exit files are `autosave-before` / `autosave-after` in the run directory.
The main browser's idle-window pings keep autosave enabled but do not guarantee
a write within that window; use the dirty-window measurements for autosave claims.
The runner now includes these explicit probes by default. Its `--autosave-only`
browser-driver mode can also run them separately.

The independent compression experiment (CSV (`artifacts/performance/responsiveness/compression.csv`, local evidence))
measured medians of 2.36 s at level 9 and 1.36 s at level 1 for the same 19 MB
table. The extracted data was identical; level-1 archives were 0.12% larger in
this experiment. Actual project size and save time depend on their contents.

Startup controls used three fresh processes per mode against the existing private
runtime: normal namespace/UI construction took a median 6.27 s with 46 namespaces
and 144 MiB resident memory; eager loading took 11.25 s with 148 namespaces and
438 MiB. Deferred loading was already implemented and is preserved. These times
exclude installer extraction and browser/server connection.

Several controls were noisy or slower in the first comparison: 20 schema reads
changed from 0.05 to 0.06 s, 100 environment captures from 0.34 to 0.72 s, and
save/reopen from 0.86 to 1.26 s. No speedup is claimed for these paths. A separate
fresh-process repeat in reverse order narrowed save/reopen to 0.96 versus 1.00 s
and environment capture to 0.38 versus 0.42 s (`control-before` / `control-after`
logs and matching `-controls-*` CSVs). Both the original and repeat results remain
available. R allocation totals were unchanged in the main measured workloads;
the evidence supports less redundant UI/CPU work, not an allocation-reduction claim.

Final affected R suites passed (`focused-verified.log`, exit 0), including 46 new
responsiveness assertions. All 18 source-console browser checks passed
(`console-source-verified.log`, exit 0;
browser results (`artifacts/review/console-terminal-20261019-084624/result.json`, local evidence)).
A broad R run passed the existing regressions but exposed two assertions using
an unobservable primitive test counter in the new fixture. The counter was fixed
and the complete affected suites rerun successfully; that first broad run is
retained as a failed diagnostic, not represented as a clean full-suite run.
Its one skip exercises missing Pandoc on a machine where Pandoc is installed.

**Remaining limits:** the 300 ms edit/worker-ping p95 and 50 ms warm long-draft
handler targets were not met. Recovery still performs synchronous I/O, initial
long-draft highlighting can pause, and real graph refreshes remain expensive.
Worker run durations include serialization, UI and recovery delays; they do not
prove a faster clustering algorithm. The stress fixtures and headless Edge
measurements describe this machine, not every project or PC.

Earlier exploratory browser runs were interrupted by edits to their running
driver; their process failures remain diagnostic. Drivers are now frozen before
execution. The new focus regression also caught and fixed repeated tab activation
stealing console tab-strip focus.

These source changes do not replace the previously built 0.3.0 installer. To try
the source app from this checkout, run `pkgload::load_all(); run_app()` in R.
