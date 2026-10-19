# Bundled pipeline examples

Help > Example projects contains 22 offline projects, with 165 executed task instances covering all 58 enabled task types. Search and task/category filters run locally in the browser. Each opening creates an independent writable copy.

Every project includes an HTML report with a pipeline-log appendix, CSV results and a separate task log. Reports snapshot retained events before generation; the final exported log includes report completion. Earlier runs can remain in the retained log; use run_id to distinguish them. Configure the appendix in Report > Appearance.

| Project | Task types demonstrated | Tasks |
| --- | --- | --- |
| [iris](inst/examples/iris/README.md) | script, summary_stats, summary_tables, scatter_plot, export, report, export_log | 8 |
| [air-quality](inst/examples/air-quality/README.md) | script, summary_stats, replace_missing, scatter_plot, export, report, export_log | 10 |
| [fuel-economy](inst/examples/fuel-economy/README.md) | script, summary_stats, linear_regression, scatter_plot, export, report, export_log | 8 |
| [data-cleaning](inst/examples/data-cleaning/README.md) | script, remove_dups, keep_drop_cols, rename_cols, derive_cols, recode_values, change_types, first_last_n, characterize, export, report, export_log | 12 |
| [query-joins](inst/examples/query-joins/README.md) | script, import_data, query_builder, filter_sort, export, report, export_log | 7 |
| [reshape](inst/examples/reshape/README.md) | script, stack_columns, split_columns, compare_data, append_table, transpose, export, report, export_log | 10 |
| [sampling](inst/examples/sampling/README.md) | script, rank, standardize, random_sample, export, report, export_log | 7 |
| [descriptive](inst/examples/descriptive/README.md) | script, characterize, list_data, one_way_freq, summary_stats, summary_tables, table_analysis, distribution, export, report, export_log | 11 |
| [category-charts](inst/examples/category-charts/README.md) | script, bar_chart, pie_chart, box_plot, export, report, export_log | 7 |
| [numeric-charts](inst/examples/numeric-charts/README.md) | script, bubble_plot, contour_plot, histogram_graph, scatter_plot, scatter_matrix, export, report, export_log | 9 |
| [time-charts](inst/examples/time-charts/README.md) | script, line_plot, bar_line_chart, export, report, export_log | 7 |
| [anova](inst/examples/anova/README.md) | script, one_way_anova, t_test, linear_models, export, report, export_log | 8 |
| [binary-model](inst/examples/binary-model/README.md) | script, logistic_regression, export, report, export_log | 5 |
| [count-model](inst/examples/count-model/README.md) | script, glm, export, report, export_log | 5 |
| [nonlinear](inst/examples/nonlinear/README.md) | script, filter_sort, nonlinear_regression, export, report, export_log | 6 |
| [multivariate](inst/examples/multivariate/README.md) | script, correlations, pca, cluster_analysis, export, report, export_log | 7 |
| [survival](inst/examples/survival/README.md) | script, life_tables, proportional_hazards, export, report, export_log | 7 |
| [forecast](inst/examples/forecast/README.md) | script, arima_forecast, export, report, export_log | 5 |
| [quality-control](inst/examples/quality-control/README.md) | script, control_charts, cdf_plots, probability_plots, export, report, export_log | 7 |
| [branching](inst/examples/branching/README.md) | script, branch, summary_stats, export, report, export_log | 6 |
| [looping](inst/examples/looping/README.md) | script, loop, export, report, export_log | 6 |
| [report-audit](inst/examples/report-audit/README.md) | script, summary_stats, export, report, export_log | 7 |

Rebuild the archived examples with `Rscript --vanilla tools/build-examples.R`. Optional example IDs rebuild only selected projects. The builder runs genuine tasks, checks catalogue metadata against actual tasks, bundles local import files, and writes `artifacts/review/examples-build.json`.

Verify with `Rscript --vanilla tools/test-focused.R "examples|report-logging|report-integrity"` and `Rscript --vanilla tools/browser-examples.R`. The browser driver runs the current source in an isolated profile.

These examples are educational demonstrations with dataset references and interpretation notes in each README. The source checkout contains this expanded library; the existing Windows installer has not been rebuilt.
