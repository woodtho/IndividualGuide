# Share reports and files {#reports-and-exports}

Choose what your reader needs. Send a report for reading, a CSV for working with data, or a project for editing the flow. You can send more than one when each has a clear purpose.

## Report {#task-report}

Use **Report** to bring tables, charts, and notes into an HTML or Word document.

First run the tasks that supply the results. For a chart in Word, keep its static image output enabled and run the chart again if needed.

1. Add Report from Output.
2. Under **Content**, use the plus button beside a result in **Available outputs**. Check that it appears under **Report contents**. Add items in the order you want readers to see them.
3. For each item, fill in **Section heading** and **Note**. Explain the data source, units, and important choices. Leave **Render style** at Auto unless you need a specific display.
4. Under **Appearance**, choose HTML or Word in **Output format** and enter **Report title**.
5. Turn on **Include pipeline log in the report** if you want an execution-log section.
6. Select **Generate Report**. When it finishes, select **Download HTML** or **Download DOCX**. Save the document and open it outside the app.

![Add outputs on the left to build Report contents on the right. Each item can have its own heading, note, and render style.](assets/ui-report-content.png){#fig-report-content}

Check the document itself before sharing it. A missing result can lead to a warning and an incomplete section. Run its source task, then regenerate the report. **Iris exploration** shows tables and a chart together. **Cars - a report with an execution audit** focuses on logging.

## Choose HTML or Word

HTML opens in a web browser. It is a good first choice and can include interactive tables where supported. Download it and check it outside the running app.

Word produces a .docx file that you can edit in a compatible word processor. Use static charts and tables; a Word page cannot keep browser hover controls. If your chart is missing, enable its static image output, run the chart, and select that output in the report.

The Windows Setup includes the normal report tools. An R-only installation needs extra reporting packages, and Word also needs Pandoc. See [Optional: install with R](#install-with-r) if that is how you run the app.

## Pick a content style

Start with **Auto**. It chooses a display based on the actual result. Use a table style for a table and a figure style for a static chart. Print style shows an object's text when that is what you need.

Give a reader enough context to understand a result. For example: **Mean petal length by species, 150 flowers, measurements in centimetres** is more useful than **Output 2**. If you change the data or chart, run Report again; a previously saved document will not update on its own.

## Export {#task-export}

Use **Export** to write a table, chart, or supported object to an outside file.

Before starting, run the task that creates the result you want to export.

1. Select **Add Task > Output > Export**. Under **Setup**, choose **Output to export**, then a compatible **Format**.
2. Select **Choose folder…** and choose a destination you can find again.
3. In **File name (without extension)**, enter a name such as `species-summary`. Check the full file address shown by the app; it adds the format's file ending.
4. For an image, check its dimensions and **DPI**. Check **Overwrite if the file already exists** only if you mean to replace that file.
5. Select **Export**. Open the finished file from the chosen folder and check its contents.

![Export separates the destination folder from the filename. Check the complete file address before writing or replacing a file.](assets/ui-export.png){#fig-export}

Start with CSV for data and PNG for a still chart. The source must be the right kind of result: exporting chart data as CSV is different from exporting the chart's static image as PNG.

Check Overwrite before rerunning. Append is available for CSV and TSV when supported; it adds rows to an existing file. It is not a general way to add a sheet to Excel. An Export task writes a file and does not create a new table for later tasks. The original result remains the source for those tasks.

## Choose an export format

| What you need | A useful choice | What to check |
| --- | --- | --- |
| Data for many other apps | CSV or TSV | Dates, text IDs, and missing values after opening |
| A spreadsheet | XLSX | Column types and the receiving spreadsheet's limits |
| A still chart | PNG | Readable labels, dimensions, and resolution |
| A chart that can scale | PDF or SVG, when offered | That the receiving app can open it |
| Typed data for compatible tools | Parquet or Feather | Support in the receiving tool |
| Structured data for a program | JSON | The format expected by that program |
| An R result for another R user | RDS or RData | The recipient's R and package support |

You do not need to learn every format. Choose the one your reader or next tool can use. If leading zeros disappear in a spreadsheet, import the ID column as text in that spreadsheet. If a CSV opens as one column, use the spreadsheet's text/CSV import command and choose comma as the separator.

## Check a finished delivery

Save the project. Open the exported report and data files outside the app. Check titles, units, row counts, charts, and the log's dates. Make sure you are sending the latest files from the folder you actually chose.

If you need a record that the report finished, send a final Export Log made after Report. Its events are later than the snapshot inside the report.
