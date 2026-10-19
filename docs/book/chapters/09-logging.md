# Keep a useful log {#logging}

A log helps answer three questions: What ran? What changed? What went wrong? The app records task events, and you can add messages that explain your own checks.

## Choose how much to record

Open a configured task and expand **Logging**, near the top of its panel. Keep **Record task logs** enabled, then choose **Minimum severity to record**. Severity means how serious a message is. The app calls these choices levels.

| Level | Use it for |
| --- | --- |
| DEBUG | Extra details while finding a problem |
| INFO | Normal progress and results |
| WARN | Something to check, even if the task continues |
| ERROR | A failure or serious problem |

INFO is a useful starting point. A minimum of WARN keeps warnings and errors but leaves out normal INFO messages. This choice affects which new messages are kept; raising the detail later cannot recover messages that were never recorded.

## Customize a task's message

1. Expand **Logging**. Find the rule whose **When** setting is the event you need, such as task completion.
2. Check **Enable this rule** and choose its **Level**. The level must also pass **Minimum severity to record**.
3. Edit **Message**. Use **Field to insert into a message** and the rule's insertion button for values such as task name or output row count.
4. Set **Preview an event** to the same event. Use **Example values** to try sample counts, then read **Rendered log entries**. This preview does not run the task.
5. Run the task and inspect its recorded entries under Logging. Check the timestamp so you read the new entry.

![Task Logging lets you choose events, levels, and message fields. Test the wording in the preview before running the task.](assets/ui-logging.png){#fig-logging}

For a table-cleaning task, you could use:

```text
{task_name}: {rows_in} rows in; {rows_out} rows out.
```

The words in braces are placeholders. The app fills them with values from the run. Use the picker so you do not need to memorize their spelling. An output count may not exist at task start, so use it in a completion message.

![Read the rendered entry before running the task. File output preview lets you inspect Text, CSV, or JSON without writing a file.](assets/ui-logging-preview.png){#fig-logging-preview}

Keep the original-message field in warning and error rules. That way, your friendly wording does not hide the reason something failed. If a placeholder stays visible, check the field and event in the preview.

## Add a message inside a Script

This is optional. A Script can add a plain message with the supplied `log_event()` helper:

```r
log_event("Checked the source data before making the report", "INFO")
```

Use messages to explain decisions, such as a filter or missing-value choice. Avoid printing private row-level information just to show that a step ran. The **Cars - a report with an execution audit** example includes a custom warning you can inspect.

A warning message alone does not stop a Script. If you need a quality condition to choose a different path, use a Branch. If you need code to fail on a bad condition, ask the code's author to make that check explicit.

## Export Log {#task-export_log}

Use **Export Log** to write selected task logs to a file as part of your flow.

1. Add Export Log from Output.
2. Choose the tasks in **Run after and include these tasks**. Include Report if you want its completion recorded. Blank means all other tasks in the active flow.
3. Choose **Text**, **CSV**, or **JSON** in **Format**, then set **Minimum severity to export**. Leave **Show example entries instead of retained logs** off when checking your own run.
4. Enter a full **Destination file path** in a folder you can write to. Include the matching file ending, such as `/pipeline-log.csv` after the folder address for CSV.
5. Check **Overwrite an existing file** only if reruns should replace it. Select **Export log**, or **Run** in the task header. Open the file outside the app and check its dates and messages.

![Export Log needs a complete file path, a format, and the tasks to wait for. Its severity filter applies to messages already retained by those tasks.](assets/ui-export-log.png){#fig-export-log}

TXT is easiest to read as plain text. CSV opens in a spreadsheet with separate fields. JSON is useful when another program will read the records. Export Log writes a file rather than making a new data table.

If the flow stopped at an earlier error, run Export Log by itself afterwards when possible. It can help you collect the error messages. Its file cannot include the exporter's own later completion message.

## Put the log in a report

1. Open a Report task after running the tasks whose logs you need.
2. Under **Appearance**, check **Include pipeline log in the report**. Set **Minimum log level** to INFO for normal progress, or WARN for warnings and errors only.
3. Select **Generate Report**, then **Download HTML** or **Download DOCX**. Open the file and look for **Pipeline execution log**.

![Report Appearance controls the log appendix and its minimum level. Generate the report again after changing this setting.](assets/ui-report-log.png){#fig-report-log}

The report takes a snapshot of other tasks' available logs before it is made. It cannot include its own completion at that point. Add Export Log after Report if you need that event in a separate file. You can also make a report containing only a log by enabling the log option without selecting ordinary report items.

## Read dates as well as messages

Tasks keep up to 1,000 recent entries each, across runs. A saved project keeps those available entries. Running a flow again does not erase its older messages.

Use the timestamps and run identifiers to compare runs. Old warnings may still appear after you fix a problem. Long or very chatty runs can push old entries out of the retained log, so export important logs in time.

## Use startup logs for startup problems

The desktop **Session** menu offers **Open startup log**, **Open logs folder**, and **Save diagnostic log** for connection and startup problems. Task logs help with the analysis itself. Before sharing a log, remove private data, passwords, and file paths you do not want to publish.
