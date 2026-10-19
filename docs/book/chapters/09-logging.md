# Keep a useful log {#logging}

A log helps answer three questions: What ran? What changed? What went wrong? The app records task events, and you can add messages that explain your own checks.

## Choose how much to record

Open a task's **Logging** section. Keep logging enabled, then choose a minimum level.

| Level | Use it for |
| --- | --- |
| DEBUG | Extra details while finding a problem |
| INFO | Normal progress and results |
| WARN | Something to check, even if the task continues |
| ERROR | A failure or serious problem |

INFO is a useful starting point. A minimum of WARN keeps warnings and errors but leaves out normal INFO messages. This choice affects which new messages are kept; raising the detail later cannot recover messages that were never recorded.

## Customize a task's message

1. Open Logging and find the rule for the event you want, such as task completion.
2. Leave the rule enabled. Choose a level that fits the message.
3. Edit the message. Use the field picker and insertion buttons to add values, such as task name or output row count.
4. Open the logging preview and check the wording.
5. Run the task once and read the actual log entry.

For a table-cleaning task, you could use:

```text
{task_name}: {rows_in} rows in; {rows_out} rows out.
```

The words in braces are placeholders. The app fills them with values from the run. Use the picker so you do not need to memorize their spelling. An output count may not exist at task start, so use it in a completion message.

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
2. Select the tasks to include and wait for. Include Report if you want its completion recorded.
3. Choose TXT, CSV, or JSON and the minimum level.
4. Choose a full destination path in a folder you can write to. Match the file ending to the format.
5. Set Overwrite only if reruns should replace that file. Run the task and open the file to check it.

TXT is easiest to read as plain text. CSV opens in a spreadsheet with separate fields. JSON is useful when another program will read the records. Export Log writes a file rather than making a new data table.

If the flow stopped at an earlier error, run Export Log by itself afterwards when possible. It can help you collect the error messages. Its file cannot include the exporter's own later completion message.

## Put the log in a report

In **Report > Appearance**, turn on **Include pipeline log in the report**. Choose INFO to include normal progress, or WARN for warnings and errors only. Run the report and look for **Pipeline execution log**.

The report takes a snapshot of other tasks' available logs before it is made. It cannot include its own completion at that point. Add Export Log after Report if you need that event in a separate file. You can also make a report containing only a log by enabling the log option without selecting ordinary report items.

## Read dates as well as messages

Tasks keep up to 1,000 recent entries each, across runs. A saved project keeps those available entries. Running a flow again does not erase its older messages.

Use the timestamps and run identifiers to compare runs. Old warnings may still appear after you fix a problem. Long or very chatty runs can push old entries out of the retained log, so export important logs in time.

## Use startup logs for startup problems

The desktop **Session** menu offers **Open startup log**, **Open logs folder**, and **Save diagnostic log**. These help when the window cannot connect or the R server stops. Task logs help with the analysis itself.

Before sharing any log, check it for private data, passwords, and file paths you do not want to publish. Send the relevant file and a short description of what you were doing.
