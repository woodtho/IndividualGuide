# Review, history and reproducibility records {#review}

An analytical project should explain decisions as well as produce numbers. Individual Guide includes comments, review items/decisions, change history, project search and run records. These features are stored with the project; they are local collaboration aids, not a hosted multiuser editing system.

## Notes and comments

Use a task note for its purpose, units, assumptions and preparation. Use comment threads when a discussion belongs to a project, task, dataset or output. Threads have an author, title, body and replies, and can be resolved or reopened.

Choose the target carefully. “Why were these rows excluded?” belongs near the filtering step or resulting table, not in an unrelated chart's comment. A resolved thread means the discussion was resolved by the workflow participants, not that the underlying statistical question is mathematically settled.

The author comes from the configured/operating-system identity where available. It is a label for local workflow records, not cryptographic authentication. When sharing project copies, agree how authors identify themselves and which copy holds the current discussion.

## Review dashboard

Review tracks outstanding items and decisions such as Draft, Changes requested, Approved and Rejected. Items can have scope, target, title, detail, severity and resolution state. Use them for concrete requests: define the event coding, justify a missing-data method, rerun a changed report, or verify an export's units.

Read-only review mode blocks editing/execution actions that would mutate the reviewed project. It is useful while inspecting a candidate delivery. Leave review mode before making the requested changes. An approval label is part of the project's workflow history; it does not digitally sign the archive or independently certify its contents.

Review the data and code behind a report, not only the formatted document. An output table may be retained from an earlier run or a different source schema. Check statuses, run records and comments. Resolve an issue when the actual condition has been addressed and verified, not merely when the request has been acknowledged.

## Change history and Undo

Change history records supported project actions and before/after information. It helps explain configuration, deletion or review changes. Project Undo is distinct from text-editor Undo/Redo: one concerns supported project/destructive actions, the other concerns typed text in a focused control.

Do not assume the app provides an unlimited general transaction history for arbitrary R code. Deleting a task can preserve outputs still referenced by survivors and may materialize needed lazy values before disconnecting a producer. Undoing a deleted database import may still require reconnection; an old serialized connection is not automatically alive.

Save earlier versions when you need recoverable project milestones. Use independent backups for external data/files. A project history entry describing a write cannot undo a file changed by a Script or an external program.

## Search and accessible task navigation

Project search can find task labels/types/code/notes, datasets and variable names, output kinds, comments and review items in the indexed current project context. Search is literal case-insensitive matching rather than a semantic assistant that infers every synonym.

The sidebar filter helps navigate tasks/data. Project tools > Task list searches task name, type, status or output and opens a selected task directly. This is especially useful for large canvases and keyboard navigation. Example-library search is separate: it finds bundled projects rather than searching the current project's observations.

Do not treat project search as a full-data content scan. A dataset named `customers` and its column names can be indexed without every customer value becoming searchable project metadata. Use a dataset viewer or an explicit query for record-level questions.

## Run records

Project tools retains the latest **200 task runs**. A run record includes task/configuration identity, input/output fingerprints where available, relevant file hashes, seed/random-state information, elapsed time, status/error and environment details. Select a run to inspect it and compare it with an earlier retained run of the same task.

The comparison identifies changes in configuration, inputs, outputs, files, seed or environment. It is not an explanatory model that can tell you why a coefficient changed. Use the indicated differences to guide investigation: a schema refresh, changed filter, model predictor change or package version may be the cause.

Export run manifest downloads structured records without the raw dataset values. Paths, names and other metadata can still be informative, so review it before sharing. A fingerprint identifies content under its recorded completeness conditions; it is not an automatic copy of that content.

Lazy database inputs are a key limitation. Their fingerprints can represent query text without snapshotting live database rows. Process-local objects can also have incomplete/unavailable fingerprints. Read completeness/reason fields before making a broad claim that two runs used identical real-world data.

Environment comparisons record package/runtime information. Equivalent R version spellings such as `2.1-4` and `2.1.4` are compared semantically in the current source. Actual changed/missing packages still deserve investigation. A matching environment plus input hash strengthens reproducibility evidence but does not validate the analytical question.

## A review handoff procedure

Save a candidate project and completed outputs. Validate the intended flow, rerun what must be current and inspect logs/warnings. Export a portable copy if supported source files must travel, plus the run manifest and generated code when relevant. Add comments identifying deliberate teaching/analysis limitations and any unresolved issues.

The reviewer opens the delivered copy, inspects the report and its data/code lineage, checks run/environment differences, and records concrete changes or approval. Keep competing edits in separate copies rather than two processes silently saving over one shared `.igpx`. A final handoff identifies the accepted artifact and the environment used to produce it.

# Settings and desktop preferences {#settings}

Settings changes project behavior and is saved with the project. Desktop window/recent-file preferences belong to the desktop profile. Do not assume a change in one category applies globally to every existing graph or every independently opened project.

| Setting | Default/current choice range | Effect |
| --- | --- | --- |
| Appearance | Dark or Light | Changes application appearance |
| Preview rows per page | Default 10; choices 10, 15, 25, 50, 100 | Changes preview pagination, not analytical row count |
| Default plot theme | Clean | Starting style for newly configured graphs |
| Default palette | Individual Guide | Starting palette for new graphs |
| Stop at first failing task | Off | Controls flow failure scheduling |
| Confirm task/flow deletion | On | Controls destructive-action confirmation dialogs |
| Previous saved versions | 20; whole number 0–100 | Retains earlier explicit saves |
| Fixed project seed | Off; valid nonnegative integer when enabled | Seeds supported task/loop execution reproducibly |
| Background supported tasks | On | Uses transferable isolated-worker execution where available |

Apply commits settings; Cancel closes without applying the new choices. A plot default is a default for new graph configuration, not necessarily a bulk restyling operation on every already saved task. Set an individual graph's style when its appearance matters to a report.

The desktop profile remembers window position/size/maximized state and adjusts bounds for available displays. It keeps recent projects, with up to ten ordinary recent entries and up to ten pinned entries. Pinning makes an entry easier to find; it does not copy or back up the project. Clearing unpinned recent entries does not delete the project files themselves.

Menus can be disabled during startup, recovery, a modal operation or a running flow. This reflects current state rather than a missing installation feature. Finish/cancel the active dialog and wait for connection before retrying commands. Session diagnostics/restart remain separate so they can help when Shiny is unavailable.

## Opening projects and trust

The app warns that projects can contain R code and serialized R objects. Opening or running one can access files and execute code with the current user's permissions. Desktop trust decisions are associated with file content hashes, so a changed file may require a fresh decision. A browser launch also has an explicit trust/open workflow.

Trust means you accept the file/source for this workflow. It is not a sandbox that prevents Script code from using the filesystem, nor a verification that every stored analysis is correct. Inspect unfamiliar project provenance and obtain a suitable review copy before executing work you do not understand. Read-only review controls app actions but does not turn arbitrary serialized R content into an inert interchange format.

The desktop browser uses a restricted integration surface and a local R server, but the analytical runtime remains real R. Keep passwords in the supported session fields or external credential mechanisms; hard-coded credentials in custom code remain code text in the saved/exported artifact.
