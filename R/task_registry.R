# task_registry.R — Static catalog of every task Individual Guide will support.
#
# Each entry:
#   id        — snake_case type string, matches task_def()$type
#   label     — display name shown in picker and tab
#   category  — grouping header in the picker
#   icon      — Font Awesome 6 icon name (without "fa-" prefix)
#   desc      — one-line description shown in picker detail pane
#   phase     — implementation phase (1 / 2 / 3)
#   available — TRUE when the Shiny module is implemented and wired in

TASK_REGISTRY <- list(

  # ── General ────────────────────────────────────────────────────────────────
  list(id = "import_data",        label = "Import Data",
       category = "Data",         icon  = "database",
       phase = 1, available = TRUE,
       desc  = "Import or refresh local files and database tables as pipeline steps."),

  list(id = "query_builder",      label = "Query Builder",
       category = "Data",         icon  = "filter",
       phase = 1, available = TRUE,
       desc  = "Select, filter, sort, join, and compute columns \u2014 full SQL-like interface."),

  list(id = "script",             label = "Script",
       category = "General",      icon  = "code",
       phase = 1, available = TRUE,
       desc  = "Run arbitrary R code as a pipeline step. All flow tables are available as variables."),

  list(id = "branch",             label = "Branch",
       category = "Control Flow",  icon  = "code-branch",
       phase = 4, available = TRUE,
       desc  = "Evaluate conditions and route execution to one or more downstream paths."),

  list(id = "loop",               label = "Loop",
       category = "Control Flow",  icon  = "repeat",
       phase = 4, available = TRUE,
       desc  = "Define repeated execution over files, datasets, groups, parameters, dates, or queries."),

  # ── Data ───────────────────────────────────────────────────────────────────

  list(id = "append_table",       label = "Append Table",
       category = "Data",         icon  = "table",
       phase = 2, available = TRUE,
       desc  = "Stack two or more tables row-wise (dplyr::bind_rows)."),

  list(id = "compare_data",       label = "Compare Data",
       category = "Data",         icon  = "code-branch",
       phase = 2, available = TRUE,
       desc  = "Compare two tables using waldo and return readable differences."),

  list(id = "filter_sort",        label = "Filter and Sort",
       category = "Data",         icon  = "filter",
       phase = 2, available = TRUE,
       desc  = "Lightweight filter + sort without joins or computed columns."),

  list(id = "stack_columns",      label = "Stack Columns",
       category = "Data",         icon  = "layer-group",
       phase = 2, available = TRUE,
       desc  = "Pivot wide \u2192 long (tidyr::pivot_longer)."),

  list(id = "split_columns",      label = "Split Columns",
       category = "Data",         icon  = "table-columns",
       phase = 2, available = TRUE,
       desc  = "Pivot long \u2192 wide (tidyr::pivot_wider)."),

  list(id = "transpose",          label = "Transpose",
       category = "Data",         icon  = "right-left",
       phase = 2, available = TRUE,
       desc  = "Transpose rows and columns (t())."),

  list(id = "rank",               label = "Rank",
       category = "Data",         icon  = "sort",
       phase = 2, available = TRUE,
       desc  = "Add rank, dense rank, or percentile rank columns."),

  list(id = "standardize",        label = "Standardize Data",
       category = "Data",         icon  = "sliders",
       phase = 2, available = TRUE,
       desc  = "Z-score or min-max scale numeric columns."),

  list(id = "random_sample",      label = "Random Sample",
       category = "Data",         icon  = "shuffle",
       phase = 2, available = TRUE,
       desc  = "Draw a random sample by row count or proportion."),

  list(id = "remove_dups",        label = "Remove Duplicates",
       category = "Data",         icon  = "clone",
       phase = 2, available = TRUE,
       desc  = "Remove duplicate rows, optionally scoped to key columns (dplyr::distinct)."),

  list(id = "keep_drop_cols",     label = "Keep / Drop Columns",
       category = "Data",         icon  = "table-columns",
       phase = 2, available = TRUE,
       desc  = "Keep or drop a selected set of columns (dplyr::select)."),

  list(id = "rename_cols",        label = "Rename Columns",
       category = "Data",         icon  = "i-cursor",
       phase = 2, available = TRUE,
       desc  = "Rename one or more columns by providing old \u2192 new name pairs (dplyr::rename)."),

  list(id = "first_last_n",       label = "First / Last N Rows",
       category = "Data",         icon  = "list-ol",
       phase = 2, available = TRUE,
       desc  = "Keep only the first or last N rows of a table (head / tail)."),

  list(id = "replace_missing",    label = "Replace Missing Values",
       category = "Data",         icon  = "fill",
       phase = 2, available = TRUE,
       desc  = "Fill NA values with a fixed value, column mean, median, or mode."),

  list(id = "derive_cols",        label = "Derive Columns",
       category = "Data",         icon  = "wand-magic-sparkles",
       phase = 2, available = TRUE,
       desc  = "Add new computed columns using R expressions (dplyr::mutate)."),

  list(id = "recode_values",      label = "Recode Values",
       category = "Data",         icon  = "arrows-left-right",
       phase = 2, available = TRUE,
       desc  = "Map old column values to new ones using a rule table (dplyr::case_when)."),

  list(id = "change_types",       label = "Change Column Types",
       category = "Data",         icon  = "right-left",
       phase = 2, available = TRUE,
       desc  = "Convert column types: numeric, integer, character, logical, factor, Date."),

  # ── Describe ───────────────────────────────────────────────────────────────
  list(id = "characterize",       label = "Characterize Data",
       category = "Describe",     icon  = "magnifying-glass",
       phase = 2, available = TRUE,
       desc  = "Column types, n distinct, n missing \u2014 rendered as a structured table."),

  list(id = "distribution",       label = "Distribution Analysis",
       category = "Describe",     icon  = "chart-area",
       phase = 2, available = TRUE,
       desc  = "Histogram + density curve + optional Q-Q plot for numeric columns."),

  list(id = "list_data",          label = "List Data",
       category = "Describe",     icon  = "list",
       phase = 2, available = TRUE,
       desc  = "Paginated, searchable table view of any dataset (DT)."),

  list(id = "one_way_freq",       label = "One-Way Frequencies",
       category = "Describe",     icon  = "percent",
       phase = 2, available = TRUE,
       desc  = "Frequency counts and cumulative percentages."),

  list(id = "summary_stats",      label = "Summary Statistics",
       category = "Describe",     icon  = "calculator",
       phase = 2, available = TRUE,
       desc  = "Mean, SD, median, quartiles, skewness for numeric columns."),

  list(id = "summary_tables",     label = "Summary Tables",
       category = "Describe",     icon  = "table-cells",
       phase = 2, available = TRUE,
       desc  = "Cross-tabulated summary: row \u00d7 column grouping with a summary statistic."),

  list(id = "table_analysis",     label = "Table Analysis",
       category = "Describe",     icon  = "table",
       phase = 2, available = TRUE,
       desc  = "Two-way contingency table with chi-square test."),

  # ── Graph ──────────────────────────────────────────────────────────────────
  list(id = "bar_chart",          label = "Bar Chart",
       category = "Graph",        icon  = "chart-bar",
       phase = 3, available = TRUE,
       desc  = "Vertical or horizontal bar chart (ggplot2 + ggiraph)."),

  list(id = "bar_line_chart",     label = "Bar-Line Chart",
       category = "Graph",        icon  = "chart-bar",
       phase = 3, available = TRUE,
       desc  = "Combined bar and line chart with dual Y axes."),

  list(id = "box_plot",           label = "Box Plot",
       category = "Graph",        icon  = "chart-column",
       phase = 3, available = TRUE,
       desc  = "Box-and-whisker plot by group."),

  list(id = "bubble_plot",        label = "Bubble Plot",
       category = "Graph",        icon  = "circle-dot",
       phase = 3, available = TRUE,
       desc  = "Scatter plot with bubble size encoding a third variable."),

  list(id = "contour_plot",       label = "Contour Plot",
       category = "Graph",        icon  = "mountain",
       phase = 3, available = TRUE,
       desc  = "2D density contour or filled contour plot."),

  list(id = "histogram_graph",    label = "Histogram",
       category = "Graph",        icon  = "chart-bar",
       phase = 3, available = TRUE,
       desc  = "Frequency histogram with optional density overlay."),

  list(id = "line_plot",          label = "Line Plot",
       category = "Graph",        icon  = "chart-line",
       phase = 3, available = TRUE,
       desc  = "Line chart with optional grouping and secondary Y axis."),

  list(id = "pie_chart",          label = "Pie Chart",
       category = "Graph",        icon  = "chart-pie",
       phase = 3, available = TRUE,
       desc  = "Pie or donut chart."),

  list(id = "scatter_plot",       label = "Scatter Plot",
       category = "Graph",        icon  = "expand",
       phase = 3, available = TRUE,
       desc  = "XY scatter with colour, size, and facet variables."),

  list(id = "scatter_matrix",     label = "Scatter Plot Matrix",
       category = "Graph",        icon  = "table-cells-large",
       phase = 3, available = TRUE,
       desc  = "Pairwise scatterplots or faceted distributions of numeric columns."),

  # ── ANOVA ──────────────────────────────────────────────────────────────────
  list(id = "one_way_anova",      label = "One-Way ANOVA",
       category = "ANOVA",        icon  = "chart-simple",
       phase = 3, available = TRUE,
       desc  = "aov() with TukeyHSD post-hoc and group box plots."),

  list(id = "t_test",             label = "t Test",
       category = "ANOVA",        icon  = "equals",
       phase = 3, available = TRUE,
       desc  = "One-sample, two-sample, or paired t-test."),

  list(id = "linear_models",      label = "Linear Models",
       category = "ANOVA",        icon  = "table-list",
       phase = 3, available = TRUE,
       desc  = "General linear model with formula builder (lm)."),

  # ── Capability ─────────────────────────────────────────────────────────────
  list(id = "cdf_plots",          label = "CDF Plots",
       category = "Capability",   icon  = "chart-area",
       phase = 3, available = TRUE,
       desc  = "Empirical CDF plot with optional grouping plus a quantile table."),

  list(id = "probability_plots",  label = "Probability Plots",
       category = "Capability",   icon  = "bullseye",
       phase = 3, available = TRUE,
       desc  = "Normal Q-Q plot with reference line and Shapiro-Wilk test."),

  # ── Control Charts ─────────────────────────────────────────────────────────
  list(id = "control_charts",     label = "Control Charts",
       category = "Control Charts", icon = "chart-line",
       phase = 3, available = TRUE,
       desc  = "Individuals or Xbar control charts with 3-sigma limits and violation flags."),

  # ── Regression ─────────────────────────────────────────────────────────────
  list(id = "linear_regression",  label = "Linear Regression",
       category = "Regression",   icon  = "chart-line",
       phase = 3, available = TRUE,
       desc  = "lm() with formula builder, coefficients, R\u00b2, residual plots."),

  list(id = "logistic_regression",label = "Logistic Regression",
       category = "Regression",   icon  = "arrow-trend-up",
       phase = 3, available = TRUE,
       desc  = "glm(family=binomial) with formula builder."),

  list(id = "glm",                label = "Generalized Linear Models",
       category = "Regression",   icon  = "superscript",
       phase = 3, available = TRUE,
       desc  = "glm() with family selector (Gaussian, Binomial, Poisson, Gamma)."),

  list(id = "nonlinear_regression",label = "Nonlinear Regression",
       category = "Regression",   icon  = "bezier-curve",
       phase = 3, available = TRUE,
       desc  = "nls() with common curve presets (exponential, power, logistic)."),

  # ── Multivariate ───────────────────────────────────────────────────────────
  list(id = "correlations",       label = "Correlations",
       category = "Multivariate", icon  = "sitemap",
       phase = 3, available = TRUE,
       desc  = "Correlation matrix with colour-scaled table output."),

  list(id = "pca",                label = "Principal Components",
       category = "Multivariate", icon  = "compress",
       phase = 3, available = TRUE,
       desc  = "prcomp() with explained variance, loadings, and scores tables."),

  list(id = "cluster_analysis",   label = "Cluster Analysis",
       category = "Multivariate", icon  = "share-nodes",
       phase = 3, available = TRUE,
       desc  = "k-means and hierarchical clustering (hclust)."),

  # ── Survival Analysis ──────────────────────────────────────────────────────
  list(id = "life_tables",        label = "Life Tables",
       category = "Survival Analysis", icon = "heart-pulse",
       phase = 3, available = TRUE,
       desc  = "Kaplan-Meier survival curves (survival package)."),

  list(id = "proportional_hazards",label = "Proportional Hazards",
       category = "Survival Analysis", icon = "chart-area",
       phase = 3, available = TRUE,
       desc  = "Cox proportional hazards regression (survival::coxph) with broom outputs."),

  # ── Time Series ────────────────────────────────────────────────────────────
  list(id = "arima_forecast",     label = "ARIMA / Basic Forecasting",
       category = "Time Series",  icon  = "clock",
       phase = 3, available = TRUE,
       desc  = "AIC-selected ARIMA model with point forecasts and 80/95% intervals."),

  # ── Output ─────────────────────────────────────────────────────────────────
  list(id = "export_log",         label = "Export Log",
       category = "Output",       icon = "file-lines",
       phase = 3, available = TRUE,
       desc = "Write collected task logs to a text, CSV, or JSON file."),

  list(id = "export",             label = "Export",
       category = "Output",       icon  = "file-export",
       phase = 3, available = TRUE,
       desc  = "Export a dataset, object, or plot to disk (CSV, Parquet, Excel, RDS, PNG, SVG, PDF, \u2026)."),

  list(id = "report",             label = "Report",
       category = "Output",       icon  = "file-lines",
       phase = 3, available = TRUE,
       desc  = "Assemble selected tables into a formatted HTML or Word report (rmarkdown).")
)

# Gate for task creation. All declared tasks are implemented and enabled;
# remove ids from this vector to hide a task from the picker without deleting
# its registry entry (saved projects referencing it can still be inspected).
IG_ENABLED_TASK_IDS <- vapply(TASK_REGISTRY, `[[`, character(1), "id")

TASK_REGISTRY <- lapply(TASK_REGISTRY, function(task) {
  task$available <- task$id %in% IG_ENABLED_TASK_IDS
  task
})

# ── Lookup helpers ─────────────────────────────────────────────────────────────

#' Get the registry entry for a task type id
#' @param type_id Registered task type identifier.
task_type_info <- function(type_id) {
  hits <- Filter(function(x) x$id == type_id, TASK_REGISTRY)
  if (length(hits) == 0L) return(NULL)
  hits[[1]]
}

#' Unique categories in declaration order
task_categories <- function() unique(vapply(TASK_REGISTRY, `[[`, character(1), "category"))

#' All tasks for a given category
#' @param cat Task category label to look up.
tasks_for_category <- function(cat) Filter(function(x) x$category == cat, TASK_REGISTRY)
