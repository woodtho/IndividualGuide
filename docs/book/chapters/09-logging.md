# Logging an analysis and a desktop session {#logging}

Individual Guide has several records because different questions need different evidence. A startup log diagnoses the desktop/server. Task logs describe analytical execution and custom messages. Run records compare configurations, inputs, outputs and environment fingerprints. Change history/comments explain decisions. A console transcript records temporary interactive work. Keep those purposes distinct when troubleshooting or sharing evidence.

## Task logging controls

Every task has a Logging section. It provides an enabled setting, a minimum severity, console-capture control and editable rules. A rule chooses a trigger/event, whether it is enabled, a severity choice and a message template. Defaults are task-specific: an Import talks about its source and dimensions; Report talks about rendering a format; Export talks about a destination.

Levels, in increasing severity, are **DEBUG**, **INFO**, **WARN** and **ERROR**. A minimum of WARN retains WARN/ERROR entries, not INFO/DEBUG. A rule can use its configured severity or preserve the event severity where the rule interface offers that choice. A lower-level event may therefore be omitted even though the task otherwise ran normally.

Supported event triggers include task starts, completes, fails, skipped, waiting, warning, R message, console output and Script `log_event()`. Logging is an execution record, not an always-on recording of every keystroke or every variable's contents. The app deliberately keeps console drafts/example filters local instead of transmitting their text as unnecessary live Shiny input.

## Message templates

Use the field picker and insertion buttons to build a template. Available message inputs include task ID/name/type, status, input/output names and dimensions, elapsed seconds, original message, source, destination, file format, flow ID and loop iteration. The appendix lists exact placeholder tokens.

Examples of useful templates are:

```text
{task_name}: {rows_in} rows in; {rows_out} rows in {outputs} ({elapsed}s)
{task_name}: wrote {inputs} to {destination}
{task_name}: {message}
```

A field must make sense at the event time. Output dimensions may not exist at task start. An object-producing model/report may not have the same row/column meaning as a table transformation. Preserve the original message in warning/error rules if you want to retain the diagnostic cause.

Unknown/unavailable template fields can remain visible rather than becoming a fabricated value. Inspect previews and actual records. Copying a table-specific success message to a report can produce an unhelpful “output rows” phrase; use a task-specific template that describes what the task really does.

## Previewing rules without running work

Logging previews can show current values or an editable example scenario, rendered entries and text/CSV/JSON representations. They do not execute the analysis or write a destination file. The Message inputs view makes token values inspectable, which helps diagnose a template that looked correct but lacked a value at the chosen event.

Collapsed previews are deferred for responsiveness; recording remains independent. Disabling a particular preview is not the same as disabling logging. Reset task rules restores the sensible defaults for that task type; inspect the reset before saving if you had custom audit requirements.

Test a template with both ordinary and error-like message text, including commas, line breaks and angle brackets. Structured CSV/JSON exports retain fields without requiring a person to parse a prettified line. A preview cannot guarantee that future code will emit the event you expected, so inspect one actual run as well.

## Explicit Script events

Use `log_event()` inside a Script for facts and decisions that generic start/success messages cannot know:

```r
log_event(sprintf("Read %d rows from the selected extract", nrow(raw)), "INFO")
log_event(sprintf("Missing amounts: %d", sum(is.na(raw$amount))), "WARN")
log_event("Using seed 2026 for the sampling exercise", "DEBUG")
```

Choose severity by consequence. A custom WARN can explain an intentional teaching limitation; an ERROR-level message does not by itself throw an R error. Use `stop("reason")` when a quality rule should fail the task. Use a Branch if a valid condition should route to a different path rather than signal a failure.

Avoid logging confidential record-level values just to demonstrate that code ran. Useful counts, paths and summaries are often enough. Review logs before sharing: although the desktop does not dump the entire environment or every input form, task messages and user scripts can contain whatever text they emit.

## Retention and chronology

Each task retains its latest **1,000 entries** across runs. The project saves those entries. Rerunning a flow does not automatically erase all prior task events. A log can therefore include several source loads, older warnings and multiple successful reports.

Structured records contain time, task-run ID, flow ID, task ID/type, loop iteration, level, event, message and elapsed seconds. Task-run IDs distinguish retained executions; they are not a promise that every task in a flow shares one universal run ID. Use timestamps, task identifiers and iteration context together when reconstructing a pipeline run.

Retention is bounded. A long simulation that emits thousands of lines can evict its oldest events. If a complete external audit is required, design exports/checkpoints and message volume accordingly. A project log is not an unlimited append-only compliance archive, and changing a logging threshold cannot recover events that were never retained.

## Export Log reference {#task-export_log}

Choose a destination file path, TXT/CSV/JSON format, minimum severity and the tasks to include/wait for. Configure Overwrite explicitly. The task writes the retained selected records and acts as an external-output sink; it does not create a new table producer.

Selecting tasks establishes status dependencies so their logs are available first. Failed selected tasks do not inherently block this export. If Stop on error stopped the whole flow before the exporter was scheduled, run Export Log manually afterwards. A final exporter does not include its own completion event in the file it has already written.

TXT is convenient for a readable narrative. CSV preserves a rectangular record for spreadsheets and filtering. JSON preserves structured entries for programmatic processing. Match the file extension to the chosen format and check that the folder exists and is writable. Existing files require Overwrite.

Use the **report-audit** example to compare all three formats. Its last log export includes the Report completion event, while the report's own appendix snapshots earlier events. In a Loop, choose whether the exporter runs once after the loop or explicitly inside the loop, and provide per-iteration paths when it should create several files.

## Logs inside reports

Release 0.4.0 includes **Report > Appearance > Include pipeline log in the report**, with a minimum level. This appends an execution-log table built from other tasks' retained events in the current flow before rendering begins. It can also produce a log-only report when no ordinary content items are selected.

This is a snapshot, not a live widget that keeps updating after the document is generated. It can contain earlier runs. Disabled logging, filtered-out levels and evicted records are absent. The report's own completion happens afterwards and belongs in a subsequent Export Log if required.

The feature works in HTML, Word, headless/background execution and generated full pipelines. Update older 0.3.0 installations to use this option. A standalone report snippet that requests pipeline logs must run in the generated pipeline's logging context; it cannot magically read logs from a closed app session.

## Desktop diagnostics

The standalone shell supplies **Session > Open startup log**, **Open logs folder** and **Save diagnostic log** even when Shiny is disconnected. These records include timestamp/elapsed stage information, runtime versions, paths, dependency checks, process/port and HTTP readiness, window connection, browser warnings/errors, R stdout/stderr and restart/shutdown decisions.

The current log rotates at **5 MiB**, with **five preceding files** retained. Diagnostic export combines retained files in chronological order. It preserves split UTF-8 and partial output lines rather than treating every chunk as a complete character line. It does not add a full environment/form-input dump.

Use these logs for “the window cannot connect” or “R stopped,” not as the only record of which analysis rows were excluded. Use task logs/run records for analytical execution. A normal browser launch has the hosting R session's output and task logs, but not the independent desktop Session menu.

## A practical failure packet

When asking someone to reproduce a problem, record the app/build identity and whether you used the source or installer. Include the relevant task error, a selected task-log export and, for startup/disconnection, the diagnostic log. Include a minimal project or portable copy when the data can be shared. Mention the last action and whether a flow was running.

Do not send a large profile directory blindly. It may contain connections, paths, recovery work or data. A focused packet is easier to inspect and less likely to disclose unrelated material. The run manifest and generated script can add reproducibility context without replacing the original problem description.
