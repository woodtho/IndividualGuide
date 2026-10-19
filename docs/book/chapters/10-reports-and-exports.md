# Delivering reports and files {#reports-and-exports}

A finished analytical result is often a package: a saved project for editing, a report for readers, data/figure exports for other tools, logs for execution evidence and generated code for repeat runs. Choose each artifact deliberately. A single screenshot cannot serve all those purposes.

## Report reference {#task-report}

Report assembles selected tables and objects into **HTML** or **Word**. In Content, add outputs from the available list, reorder items and set each heading, note and render style. The same output can appear more than once with different presentation. In Appearance, set title, subtitle, author, format and the source-edition log-appendix options.

Selected items establish data dependencies, so producers should run before the report. Uncomputed items are marked in the panel and skipped with warnings if no current value is available. A report that generated successfully can therefore still be missing a requested section. Inspect warnings and the document itself.

The output is a retained report artifact with rendering companions, not a general-purpose editable word processor. Download saves the rendered HTML/DOCX. Saving the project preserves the retained report assets so the document can be reopened later. If a source table or plot changes, regenerate the report; opening an old artifact is not an automatic refresh.

Use the Iris example for a mixed table/figure report and **Cars - a report with an execution audit** for logging. The appendix and minimum severity are included in release 0.4.0.

## Content render styles

| Render style | Intended use |
| --- | --- |
| Auto | Dispatch on the actual runtime value class |
| Table/kable | Static tabular rendering for data frames |
| Interactive table/datatable | Searchable browser table for HTML |
| Figure | A retained static plot/grob or supported widget |
| Print | A text/monospace representation of an object |

Auto treats data frames as tables, static ggplots/grobs as figures, widgets as interactive HTML where supported and other objects as printed values. The actual value matters more than an old saved kind label. If an upstream Script changes what a name refers to, inspect the report's result rather than assuming the old presentation is still appropriate.

Word cannot reproduce browser interaction. Interactive table/widget selections receive an explanatory treatment rather than a false claim that their behavior survived in DOCX. Select static figures/tables for a document that must work consistently across HTML and Word. A model object printed into a report is also different from a curated coefficient/fit table.

Report headings and notes should explain analysis context: dataset/subset, units, missing-data handling and model specification. Do not use a polished title to imply a broader population, time period or causal interpretation than the underlying data support.

## Rendering prerequisites and portability

When Pandoc/reporting support is available, the task writes companion R Markdown/data and renders with the selected format. Word requires Pandoc. HTML can fall back to a built-in renderer, which embeds static figures and local widget dependencies where supported to keep downloaded files portable.

Fallback HTML and Pandoc HTML need not be visually identical. Both should carry the intended content, but pagination, table presentation and styling can differ. A fallback warning explains which path produced the file. If exact publication formatting matters, select and verify a controlled rendering environment.

After downloading, open the document outside the running app. Check that figures load with no dependency on a temporary localhost URL, that large tables remain usable, and that headings/units are complete. For Word, inspect the DOCX in your intended reader. Neither the app's preview nor a successful file write guarantees the final reader will show an acceptable page layout.

## Report logging boundary

The appendix is headed **Pipeline execution log**. It captures other tasks' retained events before generation. It may contain previous runs and excludes the report's own completion. The minimum level affects the appendix, not what all tasks originally recorded. A WARN-only appendix can be empty in an otherwise healthy run; that is a filter result, not proof that logging was broken.

For a report that documents its own creation, run Export Log afterwards and deliver that file alongside the document. If you need a tightly scoped one-run audit, inspect timestamps/run IDs and design your logging/retention procedure accordingly rather than describing an accumulated project log as an exclusive one-run trace.

## Export reference {#task-export}

Export writes a selected table, object or plot to disk. Choose the source output, compatible format, destination folder and filename. Table exports can select columns; static image exports expose dimensions, units, DPI/background/transparent options where relevant. Configure Overwrite or supported Append explicitly.

The task validates the actual value kind and format. It writes through a temporary replacement so a failed serialization should not deliberately leave a half-written target as the successful result. It is still an external side effect: restoring a project does not rewind the contents of an overwritten external file.

The destination folder must exist and be writable. Append is supported only for CSV/TSV; it is not a hidden Excel-sheet append or schema reconciliation feature. A loop exporting to one filename with overwrite can leave only the last file. Use iteration placeholders in destinations when every iteration needs its own artifact.

Export creates no new named analytical table. Keep its producer's table for downstream work. Use the task's resolved output path and file information to verify what was written, rather than looking in a remembered Downloads folder that was never the chosen destination.

## Table export formats

| Format | Suitable use | Important limitation/choice |
| --- | --- | --- |
| CSV/TSV | Broad tabular interchange and text inspection | Types/labels/leading zeroes can be interpreted differently by another reader; Append only applies here |
| Parquet/Feather | Typed columnar exchange through Arrow-capable tools | Requires compatible readers; not every arbitrary R attribute is an interchange contract |
| XLSX | Spreadsheet delivery | Check sheet/readback behavior and spreadsheet display/type interpretation |
| JSON | Structured exchange | Decide how the receiving tool interprets dates, missingness and row records |
| RDS | One R value with R structure/classes | Needs R and relevant class/method support |
| RData | Named R value(s) for R workflows | Object names and classes matter on loading |

For machine-to-machine exchange, choose the schema and receiving reader together. A CSV that looks correct in a text editor can be reinterpreted by a spreadsheet application; the app cannot force every external tool to preserve an identifier's leading zeroes.

## Plot and object export formats

Static ggplot-style values export to PNG, JPEG, TIFF, SVG or PDF. Raster files need appropriate dimensions and DPI. SVG/PDF are vector-oriented where the plot components support it, useful for scaling in documents. Background and transparency need to suit the final page/background.

Interactive plot values export to HTML or SVG in the supported implementation. Choose the static image output for PNG/JPEG/TIFF/PDF. Renaming an interactive HTML file to `.png` does not render it to pixels. HTML can retain interaction, while SVG is a static vector representation of the available plot content.

General R objects export as RDS or RData. A fitted model is not a CSV table just because its coefficient summary is tabular. Export the coefficient/fit table when another tool needs readable rows, and the model object when an R workflow needs its methods and fitted structure.

## Naming and overwrite discipline

Use filenames that identify the analysis and purpose, such as `iris-species-summary.csv`, `iris-petal-scatter.png` and `iris-report.html`. Include a period/run identifier when you need to retain several deliveries. Avoid one generic `output.csv` used by unrelated tasks in the same folder.

Overwrite is a deliberate reproducible-output policy when a flow owns a destination. It is a poor default for a folder containing hand-edited deliverables that should be preserved. Append can duplicate prior rows on reruns, so design idempotence explicitly: rerunning the same pipeline should not accidentally add the same extract twice.

Before a handoff, inspect the exported file's content and compare a count or known value with the retained result. Save the project after the intended run so task configuration, logs and run records describe the delivered files. Use portable project export to carry supported inputs/results when the recipient needs to reproduce the analysis, and the generated-code chapter for execution outside the app.
