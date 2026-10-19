# Working in the R Console {#console}

The permanent R Console tab is an exploratory workspace with a terminal-style composer, history, output, plots and completions. It runs in a separate persistent R process for the current app session. It is useful for investigating a retained dataset or trying a calculation before turning it into a task.

Open it from View > R console in the desktop shell, click its permanent tab or use Ctrl+Alt+C outside a text field. Project tables/objects are copied into the console and also exposed through `.project$tables` and `.project$objects`. Changing one of these copies does not commit a change back into the pipeline store.

## A useful first session

After opening the Iris project, try:

```r
names(.project$tables)
head(flowers)
summary(flowers$Petal.Length)
plot(flowers$Sepal.Length, flowers$Petal.Length)
```

Use the copied data to investigate, then put reproducible work into a Script task. A model created only as `fit <- lm(...)` in this console will not automatically appear as a saved project model output. Declare it in a Script or use a configured model task when it belongs to the project.

**Refresh data** replaces the imported project-variable copies with the project's latest retained values and keeps unrelated console variables. If you edited a console copy named `flowers`, refreshing can replace that copy. Live database handles are skipped rather than passed unsafely into the console process; materialize a suitable table if you need to inspect database-derived values there.

## Composer and keyboard

| Action | Console key/control |
| --- | --- |
| Run a command | Enter or Run |
| Insert a newline | Shift+Enter |
| Run multiline code | Ctrl+Enter |
| Run selected text | Ctrl+Shift+Enter or Selection |
| Recall commands | Up/Down at the editor boundary; Alt+Up/Down anywhere |
| Request completion | Ctrl+Space |
| Clear output/plots while keeping variables | Ctrl+L or Clear output |
| Copy selected output | Ctrl+C with text selected |
| Interrupt a running command and clear console workspace | Ctrl+C with no selected text, or Stop |

History recall preserves the unsent draft so you can return to it. The history panel searches retained commands locally and lets you recall whole commands. History is bounded to the recent 200 commands in the current browser/session behavior; it is not a permanent project notebook.

The composer supports R-oriented highlighting and grows to a capped editor area. Draft typing does not send the whole textarea to Shiny on each keystroke. Highlighting of long drafts uses a bounded styled prefix to keep typing responsive; a lack of colour far into an unusually long command is not evidence that those characters were omitted from the submitted command.

## Completions

Completion uses known names and captured column metadata without evaluating the expression being typed. It can offer project/console symbols, exposed package names/functions and `$` fields. Package `::` completion is limited to namespaces already loaded. It does not dynamically install packages or execute an arbitrary expression to discover its result.

For an object name with spaces, insert/keep R backticks. If the console has changed a table, captured worker fields can take precedence for its ordinary variable, while `.project` remains an explicit view of the supplied project snapshot. Refresh data when you want the newest project values.

Completions are a convenience, not a parser guarantee. A suggested field can still be inappropriate for a function or unavailable after a later reset. Read errors in the transcript and inspect `names()`/classes when the distinction matters.

## Output, plots and transcript limits

Printed values, messages, warnings and errors stream above the editor. Scrollback stays where you are reading as output arrives; **Latest output** returns to the bottom. Literal output text is rendered as text rather than trusted HTML instructions.

The console displays the most recent **12 plots**, generated as raster output by its worker. Saving a transcript downloads retained text; it is not a project save, plot bundle or complete image archive. Retain important plots through a Script/graph task and Export when they are deliverables.

Transcript text is bounded: after it grows beyond about 300,000 characters, the retained tail is reduced to roughly 250,000 with a trimming notice. A command also has a 100,000-character input limit. Do not use this console as an unlimited logging sink; save an appropriate external log or produce an explicit task result for long-running work.

## Clear, Stop, Reset and Restart

Clear output removes displayed output and plots while retaining variables. Stop terminates the console's R process, including a long native call, and clears its R workspace; the next run starts a fresh workspace with current project copies. Output/history and an unsent draft are kept according to the Stop workflow.

Reset R also clears console output, plots and history. New/Open/Close project and app-server restart clear console work. These behaviors keep a variable from one project from silently masquerading as an input in another.

Restart R server is a desktop-shell action affecting the Shiny backend and its session. It is stronger than resetting only the console. Save project work first when possible. Console filesystem/database commands still access those external resources with your permissions; isolation from the project store does not make arbitrary code reversible.

## Create Script

Create Script can use selected code, the draft or the last command. The helper identifies straightforward assignments and references to project values to propose input/output declarations. Review those declarations and any missing-symbol warning before running the new task.

Inference is intentionally limited. A local console variable that was created by an earlier command is not automatically a project input. A complex assignment inside a function or an object fetched dynamically may not be inferred as an output. Put all required setup in the Script or retain the required values through explicit upstream tasks.

Once promoted, run the Script from the pipeline and inspect its retained outputs. Delete or rename temporary exploratory variables only after the task reproduces the intended result. A saved task plus its generated pipeline is a stronger handoff than an unrecorded console state.

# Generated R and execution outside the app {#generated-code}

Readable code is part of the application's design. A task's Code toggle shows its current configured operation; the permanent Code tab assembles the **active flow** into a pipeline. Saved cached results are not automatically inlined as a universal replacement for all upstream tasks.

## Three code views

**Pipeline** is the concise sequence of named steps. **Supporting functions** contains shared calculations, validation, task metadata and logging support. **Complete script** combines them. Copy R copies the selected view, so copying Pipeline alone is not the same as downloading the complete standalone script.

Download .R provides one self-contained R script. Download bundle provides `pipeline.R`, `pipeline_support.R` and a README. Keep both R files together. The loader locates the support file relative to the script even when started from another directory; it deliberately does not change the working directory that your input/output paths use.

Run a downloaded complete script or extracted bundle with:

```powershell
Rscript --vanilla pipeline.R
```

Or from an R session:

```r
source("pipeline.R")
```

The application package itself is not required by the generated export. Referenced R packages, input files, database access and system dependencies still are. A script that includes a user-written `library(specialPackage)` needs that package, even if the app's own configured tasks normally use a smaller dependency set.

## Scope and dependencies

The Code tab exports the active flow. If it consumes a table produced only in another flow, arrange to generate/provide that prerequisite in the execution environment or consolidate/export the necessary workflow deliberately. Do not describe an active-flow export as a guaranteed project-wide scheduler for every flow.

Task settings are synchronized and code is rebuilt from configuration. Dependency order, branch decisions, loop bodies, configured output names, logging and seeds are carried into the full pipeline. A Loop node's individual snippet mainly describes iteration-source construction; the full export includes the repeated dependent body.

File paths remain file paths. A project that can display a cached table after reopening may still fail to rerun outside the app if its original import is missing. Portable `.igpx` export is also not the same thing as a code bundle that packages every arbitrary Script dependency. Inspect the paths in the downloaded code and supply the necessary files.

## Settings preserved and settings not implied

The script records configured random seeds, RNG kind, model contrasts and missing-value option. An optional project seed is applied to task/loop execution. User-written Script code is retained and can explicitly choose its own seed or package behavior.

These settings improve reproducibility without freezing all external state. Database contents can change; a library version can change; system fonts can change a rendered figure. For important work, retain the run manifest/environment information and the actual delivered outputs as well.

Generated logging uses its own runtime context. An Export Log task or a Report appendix reads events collected in that generated pipeline run, not task history from a closed Shiny session. Existing project history is saved in `.igpx`; standalone execution starts its own execution evidence.

## Verify a code handoff

Extract a bundle into a new folder. Install its referenced packages in an appropriate R library. Supply inputs and writable destinations, then run from the intended working directory in a fresh R process. Check expected table values, report sections and file/log outputs. A script that parses has passed a syntax check, not a complete reproducibility test.

For ordinary deterministic examples, compare known counts and summaries. For a stochastic method, compare configured seeds and relevant environment before interpreting differences. For a database flow, record the query/extract conditions and whether a frozen local input is needed to reproduce the exact historical result.

Keep the generated file with the saved project and final report. If you edit the downloaded R by hand, it becomes a separate analytical artifact; those edits do not automatically update the app's task forms. Document which artifact is authoritative before a later maintainer tries to rerun both.
