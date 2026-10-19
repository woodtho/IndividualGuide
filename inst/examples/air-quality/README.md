# Air quality - clean and compare

Clean 153 daily New York air-quality observations, inspect missing values and compare ozone measurements with temperature.

R datasets::airquality — New York daily measurements, May–September 1973.
Data source: R's datasets package or survival::lung (the survival package is included with R). Use the named dataset's R help page for original references, units and variable definitions. No downloaded or synthetic observations are used. Some recipes add identifiers, derive fields or deliberately duplicate a row to demonstrate cleaning; the source task documents preparation.

## Try this workflow

Missing-value audit, Replace Missing Values, before/after summaries, charts and a JSON task log. Mean imputation is an illustration, not an analytical recommendation.

All tasks have already been executed. Inspect intermediate datasets, saved figures and the HTML report in the project tree. The report includes a Pipeline execution log appendix containing retained events available before report generation. The final Export Log includes the report completion event as well. Repeated runs accumulate retained events (up to 1,000 per task); use run_id to distinguish them. In Report > Appearance, disable the appendix or choose its minimum severity.

Open any task's Logging panel to customize templates and severity. Source and iteration scripts demonstrate log_event(). The report-audit example additionally exports all three log formats (TXT, CSV, JSON).

Run the full flow to reproduce the results, report and exports. Export paths are rebased into a fresh private examples folder when opened from Help. Overwrite is enabled only for those example output filenames. Edit the Export/Export Log destinations to save elsewhere.

Use Save As to keep a project copy. The bundled project is never overwritten. Independent openings have separate output folders.
