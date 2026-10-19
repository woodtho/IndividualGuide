# Your first complete project {#first-project}

This exercise builds a small analysis from original observations to a report and audit log. It uses `datasets::iris`, which is distributed with R, so no download or external file is needed. The source-edition Iris example performs the same kind of workflow and can be opened from Help when you want a completed version to compare against.

The goal is to understand what each action commits. You will create a source table, a numeric summary, a species comparison, a chart, a report and external result files. Choose a working folder before beginning, such as `C:\IG-Projects\First-Iris`. Use a folder where you can write files, and keep the same folder available for the export steps.

## Create the source task

Choose a fresh project from the welcome screen, or File > New project in the desktop shell. In a normal browser, use the equivalent in-app action. A new project starts with a process flow. Choose **Add Task**, find **Script** in General and add it.

Give the task a descriptive label such as “Load original flowers.” In its input/output settings, declare a table output named `flowers`. Enter this code:

```r
flowers <- datasets::iris
log_event(sprintf("Loaded %d flowers", nrow(flowers)), "INFO")
```

The Script task runs code in its own execution environment. The declared output tells the app which value to retain. An assignment in the code alone is not a substitute for the output declaration. There is no input table for this first task because it creates its input from a bundled R dataset.

Run the task with its header Run button or its task-specific run action. The project tree should show `flowers`. Open the dataset and check **150 rows** and five columns: four numeric measurements and `Species`. Its species values are `setosa`, `versicolor` and `virginica`, with 50 observations each.

If the task fails, inspect its status message and code before proceeding. Common first mistakes are a mismatch between `flowers` in the code and the declared output name, or placing code in the console instead of the Script task. The console is useful for exploration but does not commit a pipeline output automatically.

## Add a numeric summary

Add **Summary Statistics** from Describe. Set the input table to `flowers`, select the four measurement columns and name the result `measurement_summary`. Preview it if that task offers Preview. Then use Run & Save or the task header Run button to retain it.

You should obtain a row per selected numeric variable, including nonmissing/missing counts, location and spread statistics. A useful reference is the mean of `Sepal.Length`, approximately **5.8433**. The exact number of displayed digits depends on formatting; formatting a number is different from changing the underlying calculation.

Notice the connection between the source task's `flowers` output and the summary task. You did not have to draw a line to establish data dependency. The input/output names establish that dependency; the canvas represents it.

## Compare species

Add **Summary Tables**. Use `flowers` as input, `Species` as the row variable, `Petal.Length` as the value variable and **mean** as the statistic. Name the output `species_summary`.

The three mean petal lengths should be approximately:

| Species | Mean petal length |
| --- | ---: |
| setosa | 1.462 |
| versicolor | 4.260 |
| virginica | 5.552 |

These are descriptive summaries of the observations in this table. They do not prove why species differ or establish a predictive model. The table is useful for checking both the dataset and your grouping configuration.

## Make a chart

Add **Scatter Plot** from Graph. Set input `flowers`, X `Sepal.Length`, Y `Petal.Length` and colour/group `Species`. Use a title such as “Iris measurements by species.” Choose useful output names in the task's output controls.

Graph tasks distinguish the table of plotting data, the interactive plot and a static image object. Enable a static image output, for example `iris_scatter_image`, if you want to use a PNG Export task later. A static image here is a retained ggplot-style value, not necessarily a PNG file already written to disk.

Run the task and inspect its Results. Hovering an interactive chart can reveal observations. The static output is better for portable raster export and many report uses. The bundled examples disable retaining interactive widgets where machine-specific font state could make cached widgets less portable; you can enable and regenerate them locally.

## Write a results file

Add **Export**. Select `species_summary`, choose CSV, select your working folder, and enter a filename such as `species-summary.csv`. Enable Overwrite only if you want reruns to replace that specific file.

Run the Export task and verify the file exists. Open it in a text editor or spreadsheet application and check the three species rows. Export is a sink: it writes an external file and does not create another transformation table. Saving the project is a separate action.

For a chart file, add another Export task, select the static image output and choose PNG. Set dimensions, units and DPI deliberately. Eight inches at 150 DPI is a different raster resolution from eight centimetres at 150 DPI. The graph chapter explains how plot output types determine the available formats.

## Assemble the report

Add **Report** from Output. In Content, add `measurement_summary`, `species_summary` and the static chart. Give each item a readable heading. In Appearance, choose HTML and provide a title.

In the current source edition, enable **Include pipeline log in the report** and leave minimum severity at INFO for this exercise. This appends retained events recorded before report generation. The report's own completion cannot appear in that pre-generation snapshot; the final log export will capture it.

Generate the report. Open or download it and verify the two tables, chart and log appendix. If you use an older installed snapshot without the appendix option, the result content still works; export a separate task log instead. A Word report is another task setting, but requires Pandoc. HTML has a fallback renderer if Pandoc is unavailable.

## Add a final audit export

Add **Export Log**. Choose the preceding tasks to include and wait for, select TXT, CSV or JSON, and provide an absolute file path in your working folder. Set Overwrite deliberately. A final audit is often easiest to inspect as CSV, because fields such as task ID, severity, event and elapsed seconds remain separate columns.

Run the full flow using the active flow's play button or Ctrl+Alt+R outside a text editor. The source should run before its consumers. The report should run after the data and chart it uses. Export Log should run after the selected tasks, including the report.

Inspect its file. It should contain the custom “Loaded 150 flowers” event and a report-completion event. It may contain entries from your earlier single-task runs as well. The log is retained history, bounded per task, rather than an automatic one-run-only trace. Use run IDs and timestamps to distinguish executions.

## Save, reopen and change something

Save the project as `first-iris.igpx`. In the desktop shell, Save As uses a native Windows file dialog. In the browser launch, use the app's file-picker workflow. Reopen the saved file and check that retained tables and the report are available before rerunning.

Now change the Scatter Plot's Y variable to `Petal.Width`, change its title accordingly, and run it. The old downstream report is no longer a reliable representation of the current chart. Rerun the report and any affected exports. The app's stale/invalidated states make this relationship visible, but they do not update every external document without an execution.

Finish by adding a note explaining the change and saving again. You now have an analysis that carries original observations, reproducible configuration, named results, a report and an audit trail. The following chapters explain the choices that become important as this workflow grows.

## Exercise answers and checks

After the source runs, `nrow(flowers)` is 150 and `table(flowers$Species)` has three counts of 50. The mean-sepal and mean-petal values above can be checked independently in an R console:

```r
mean(datasets::iris$Sepal.Length)
aggregate(Petal.Length ~ Species, datasets::iris, mean)
```

If those match but your saved table does not, compare the selected input and grouping fields. If a preview matches but the tree does not, make sure you committed the task with Run rather than stopping at Preview. If an external file does not change, rerun its Export task and check its destination and Overwrite setting. If the project opens but an external source file is missing in another exercise, review normal versus portable project saving.

# The workspace and its data model {#workspace}

The workspace gives you three complementary views: a tree for navigation, a flow diagram for relationships and task panels for configuration and results. The permanent Code and R Console tabs support inspection and exploration. None replaces the others.

## Tree, flows and tabs

The left sidebar groups data sources and process flows. Expanding a flow reveals datasets and steps, with declared inputs and outputs under tasks. Select a task to open its panel; select a dataset to inspect its values. A project can contain several flows, and one flow can use outputs produced by another. Choose output names that stay unique across the project rather than relying on two flows to hide a naming collision.

The active flow supplies the visible task list and canvas. Flow actions include run, rename, copy and delete. Copying a flow creates another editable workflow; it is not a way to schedule parallel production runs or isolate writes to identical external filenames. Inspect the copied tasks' output names, dependencies and destinations before execution.

Each open task has a tab. Closing a task tab closes its panel, not the task definition in the project. Deleting a task removes the task itself and can affect dependent results. The interface distinguishes these actions, and the destructive-action confirmation setting applies to deletion rather than ordinary tab navigation.

Permanent tabs include Flow, Code and R Console. Switching among panels retains settings. Saved settings can execute even when their task panel has never been opened during the current session. This is why you can load a prepared example and run its flow without visiting every form first.

## Read the canvas as a dependency diagram

Dataset nodes are boxes; task nodes are ellipses. Arrows represent declared relationships. A successful task is indicated with a green state, an error with red and stale results with amber. Hover a node for details such as dataset dimensions, run state or an explanation of staleness.

Moving a node changes layout, not analytical order. A task's inputs, outputs and control paths determine what must run first. Use Fit view to bring the graph into view and Re-arrange to tidy it. Manually arranged positions are useful for communicating the workflow, and project saving retains layout information.

Right-click a task for actions such as notes, Run from here and Run to here. Run from here selects the task and its descendants; Run to here selects its prerequisites and the task. These commands are dependency selections, not “run everything to the left of this shape.” If you create a task later but make it an input producer, it can still execute first.

For large graphs, use the tree or **Project tools > Task list**. That list provides searchable, keyboard-operable task opening without requiring you to select a small canvas shape. Reducing graph zoom makes more content visible but does not reduce the dataset's size or calculation cost.

## What a task panel tells you

A common panel header shows the task's identity, status, Run action, Code toggle and delete action. The task label can describe business intent. The task type tells you the operation. The last run time or error indicates the most recent retained execution state, not a statistical assessment of the result.

Most transformation and analysis panels separate Setup from Results. Setup holds input names, columns and options; Results holds tables, plots and previews. Report uses Content and Appearance because its job is to assemble existing outputs. Branch and Loop have their own setup and preview language. Do not expect every task to expose the same footer buttons.

The shared **Logging** section sits with the task. Expand it to inspect/customize event rules and message previews. Leaving it collapsed does not disable log recording; preview work is deferred while hidden. Similarly, switching away from a code view does not change the configured task.

## Finding tasks and inspecting outputs

Add Task opens a searchable catalogue grouped by category. Search for the operation, then select its entry to create a configured task in the active flow. A star adds/removes a task type from favourites; favourites appear near the top and are saved with the project. Favouriting a type does not create another task or change an existing task's parameters.

Opening a dataset from the tree shows its dimensions and a bounded preview, with ad hoc CSV, tab-delimited text, XLSX and RDS download choices. These downloads write the selected retained value, not just the visible ten-row page. They do not add a repeatable Export task to the flow. Use an Export task when the file write must rerun and appear in pipeline execution evidence.

Object previews adapt to the value: a static ggplot can offer PNG, an interactive girafe can offer HTML, and an RDS download preserves the object. The quick static PNG uses the preview action's fixed size of 16 by 10 centimetres at 150 DPI; choose Export for controlled dimensions, units and other formats. For a lazy database result, prefer the supported materialized/Export workflow when a local file is needed rather than assuming every ad hoc reader/writer handles a live connection identically.

Statistical panels can show both a formatted Results view and a Data view, plus Plot/Code where applicable. Formatted p-values, significance stars and rounded estimates are presentation aids. Inspect the retained data/model for the underlying values, and do not interpret a display such as `< .001` as an exactly zero probability. A formatted result is not an independent second analysis.

## Tables, objects and report artifacts

Tables carry rows and columns, including R classes such as factors and dates. A numeric-looking character field is still character until you convert it. A factor carries levels that may affect model coding. A Date is not interchangeable with arbitrary date-looking text. Use Characterize Data and explicit conversion tasks when you need to establish these facts.

Objects carry non-table R values: models, static plots, interactive widgets and comparison results. Model tasks can produce both tables and objects. For example, regression coefficients are a table, while the fitted `lm` value is a model object. Downstream options and export formats depend on the actual value kind.

A Report task produces a document artifact and companion rendering material. Those assets are retained in a saved project so a completed report remains available after reopening. An Export task writes a file to a destination; its file is not a replacement for a named table in the project.

Lazy database tables are another important kind. They describe a query backed by a live connection. Some operations, especially Query Builder, can stay in the database. Other calculations materialize needed values in memory. A preview limit does not imply that the full analytical operation has been limited to that many rows.

## Naming, dependency safety and renaming

Use descriptive, stable output names such as `sales_raw`, `sales_valid`, `sales_monthly` and `sales_model`. Avoid using the same output name for different producers. Keep original inputs separate from cleaned/derived outputs so an error can be traced back to source observations.

Selectors hide a task's own outputs and descendants when those would create a cycle. The store also validates dependency structure. A cycle is a logical problem: task A needs B's result while B needs A's result. Moving shapes or repeatedly pressing Run cannot solve it. Introduce a genuine source or split the calculation into ordered stages.

Changing an output name retires the old retained value. It may also require repairing downstream references. Check the consumer tasks rather than assuming a label edit and a data-name edit are equivalent. Changing a task's descriptive label is usually the right way to improve readability without changing a data contract.

## Keyboard and display behavior

Tab moves through controls, and focused tabs support arrow-key navigation, Home/End and closing task tabs with Delete. Enter or Space activates focused controls where appropriate. App-wide Ctrl+Alt shortcuts are ignored while editing ordinary input fields and code editors, so they do not unexpectedly hijack text entry. Desktop native menu accelerators form a second layer; the shortcut appendix lists both.

Settings provides dark/light appearance and defaults for new graph themes/palettes. Browser/desktop zoom can help with display size. The app has accessible task-list and keyboard workflows, but this book does not claim manual screen-reader certification across every browser and assistive-technology combination. Use the alternative tree/task-list route when a graph interaction is inconvenient.

# Saving, recovery and portable projects {#projects}

A reliable project workflow distinguishes a saved project file, its automatic recovery snapshot, previous saved versions and external files. They protect different kinds of work and are not interchangeable backups.

## Explicit saving

Save writes the current project to its chosen `.igpx` path. Save As chooses another path. Settings in open task panels are synchronized before save, so you do not need to run every task just to preserve a configuration edit. A task can be saved in an unrun or invalidated state.

The archive includes flows, task settings and statuses, materialized tables, supported R objects, report artifacts, layout, favourites, project settings, collaboration records, retained task logs and run records. Data classes are preserved through JSON-compatible or native R payloads. Treat `.igpx` as an application project, not a text interchange format for another analytical tool.

The loader also accepts legacy `.igp` and `.rds` project snapshots through a compatibility path. These are project snapshots, not a promise that an arbitrary RDS data file is a complete project. Open a trusted legacy file, inspect restored flows/settings/results and Save As a new `.igpx` rather than assuming its old filename describes the current archive format.

The serializer stages a replacement and uses verified/atomic replacement logic rather than deliberately overwriting a working archive piecemeal. An explicit save can preserve the previous file as a saved version first. If writing fails, the app should report the failure; do not interpret dismissing a dialog as evidence that a file exists. Verify the destination when storage is unreliable or permissions have changed.

The desktop title and Save menu indicate unsaved changes. A browser launch also warns on closing when relevant. Save/Discard/Cancel protections apply when replacing current work with another project or example. A failed or cancelled save leaves the workspace available. Read the choice literally: Discard means the current in-memory changes will not be kept in the project you are leaving.

## Normal projects and external dependencies

An ordinary saved project can retain computed data even if its original import file is elsewhere. That does not make the original file portable. Reopening a saved result and rerunning its Import task are separate operations. The former may work from the retained payload; the latter needs the configured source.

Relative local paths are resolved in relation to the project where supported by the serializer/loader. Absolute paths identify a specific filesystem location. Neither convention guarantees another computer has the file. A path under a personal Downloads folder is particularly easy to lose or change.

Use **Project tools > Project files and portability** to inspect local imports and missing files. Relinking selects an existing replacement file, with a matching reader/file extension. If the format changes, configure the Import task's reader rather than forcing a CSV reader to consume an Excel workbook. After relinking, rerun the import and check the resulting schema before rerunning its consumers.

Live database connections must be re-established after loading. Passwords entered through the supported session-password fields are not saved in the project. The database server, account permissions and vendor drivers remain external requirements. A custom R connection script can contain arbitrary text, so do not hard-code secrets into that script and assume a password-field protection will remove them.

## Portable project export

Use the portable project download in Project tools when you need a transferable archive. It bundles supported local import files and retained exports, as well as the ordinary saved project content. This is a different product from the portable Windows application executable.

Before handing a portable project to someone else, inspect the files it includes. Bundling makes data easier to share, which also means the recipient receives those data. It does not package every file mentioned inside arbitrary Script code, every installed package, external database contents or vendor drivers. Scripts that read extra paths still need those paths or a deliberate packaging change.

On restoration, bundled imports are copied to owned project assets and exports are restored into writable output locations. Existing destination files are not indiscriminately overwritten by opening an older snapshot. Inspect an Export task's resolved destination before rerunning it, especially when moving work to a different computer.

Opening a bundled example is similarly protective: each opening creates a fresh writable working folder, copies its output guide/files, rebases exports and prepares an editable project. Use Save As for a project you want to keep. Do not rely on the example's original installed location as a working export folder.

## Autosave recovery

Recovery is a periodic snapshot of dirty work. It does not rename your project, clear its dirty marker or replace the meaning of an explicit Save. Recovery can still consume time when substantial data must be serialized and written. A lower-cost compression strategy and reuse of stored layout reduce unnecessary work, but large snapshots are not instant.

When startup offers recovery, choose whether to restore or discard it before opening unrelated work. Restoring gives you a working recovery state to inspect and save. Discard only when you are sure the saved project or another copy is the version you want. If the R server has crashed, do not start deleting profile files before checking the offered snapshot and startup log.

Recovery cannot undo an external side effect. If a Script deleted a file or an Export replaced a CSV before the crash, restoring `.igpx` state does not reconstruct that external file automatically. Keep independent backups of original input data and important deliverables.

## Saved versions

By default, explicit saves retain **20 previous saved versions**. Settings allows a whole number from **0 to 100**. These versions live in the app's backup storage, keyed to the project path. Save As creates another project identity/path rather than moving every previous backup history into a single universal timeline.

Open **Project tools > Saved versions** to choose a retained version. Restoring opens it as an **unsaved working copy** associated with the project; Save commits that state back to the chosen project. If the current project is dirty, deal with its Save/Discard/Cancel protection first. Inspect the restored results before saving over the current version.

These application backups complement a separate file backup strategy. They share the machine/profile's storage risks. Uninstalling the program preserves user data, but deleting the profile or losing the disk can remove the versions as well.

## Concurrency, review and project state

Finish a running flow before switching/relinking project files. Read-only review mode blocks mutation/execution paths that would change the reviewed project. It is a workflow safeguard, not encryption or a filesystem permission boundary. Someone with the archive and R can still inspect its serialized data.

Comments, review items and change history are saved with the project. They are useful context for a handoff: why a variable was recoded, which model needs review, or which output a reviewer questioned. They are not a cloud collaboration service. Coordinate who is editing a shared project file and keep separate copies when making competing changes.

## A dependable handoff

Save your working project. Validate and rerun the intended workflow. Check that external outputs are present and contain the expected results. Export a portable project if local files must travel. Include a completed report, an appropriate log and, when reproducibility matters, the run manifest and generated R bundle. Reopen the delivered copy in a fresh session and verify its inputs/outputs before considering the handoff finished.
