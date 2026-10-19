# help.R — In-app Help: app overview, workspace tour, and a reference entry
# for every task. The task list is generated from TASK_REGISTRY (so it cannot
# drift from what the picker offers) and enriched with the extended details
# below. A test asserts that every registry id has a details entry.

# ── Extended per-task help ─────────────────────────────────────────────────────

#' Extended help text for every task type, keyed by registry id.
#' Each entry: 1-3 sentences covering what the task does, its key options,
#' and what it produces. The one-line summary comes from TASK_REGISTRY.
ig_task_help_details <- function() {
  list(
    # ── Phase 1 ────────────────────────────────────────────────────────────────
    import_data = paste(
      "Reads CSV (with delimiter, skip, NA markers, column types and more),",
      "Excel (sheet/range), RDS/RData, SAS, SPSS, and Stata files, or connects",
      "to databases via ODBC, SQLite, or custom DBI connection code.",
      "Database imports can stay lazy \u2014 queries then run inside the database",
      "via dbplyr \u2014 or be collected into memory. Passwords are requested per",
      "session and never written to project files. Saved connections live in",
      "a reusable catalogue."),
    query_builder = paste(
      "The full query interface: pick output columns with aliases and",
      "aggregate functions (selecting any aggregate switches to GROUP BY",
      "mode), build AND/OR filter conditions with type-aware operators",
      "(BETWEEN, IN, LIKE, NULL checks), add HAVING conditions on aggregated",
      "columns, sort by multiple keys, join additional tables (left, inner,",
      "right, full, cross), define computed columns with R expressions, and",
      "toggle DISTINCT. Generates a readable dplyr pipeline."),
    script = paste(
      "Runs arbitrary R code as a pipeline step. Declare input tables to",
      "control run order; they become variables in the script environment.",
      "Declare any number of outputs as 'name: kind' lines (table, model,",
      "plot, image, object, or auto-detected) \u2014 each is saved to the flow and",
      "available downstream. Console output is captured and shown."),
    branch = paste(
      "Routes execution through named path tokens. In Setup, choose the inputs",
      "the branch reads, set the number of outgoing paths, and configure each",
      "path with a label, token, and condition type such as row count, column",
      "value, task status, parameter value, or custom R expression.",
      "Downstream task panels show a 'Run after branch/loop path' selector;",
      "choose the matching path token there. Run Flow evaluates the branch",
      "and marks non-matching downstream paths as skipped."),
    loop = paste(
      "Defines repeated execution over files, datasets, groups, parameter",
      "lists, date ranges, or database query results. In Setup, choose the",
      "iteration type, fill in the source-specific fields, name the loop",
      "variable, and keep the path token for downstream tasks inside the loop.",
      "Use the downstream task's 'Run after branch/loop path' selector to",
      "attach that task to the loop token.",
      "Preview loop validates the source and lists the iterations before the",
      "flow is run."),

    # ── Data tasks ─────────────────────────────────────────────────────────────
    append_table = paste(
      "Stacks two or more tables row-wise with dplyr::bind_rows(). Optionally",
      "adds a source-ID column (with editable labels per table) so you can",
      "trace which table each row came from; mismatched columns are filled",
      "with NA."),
    compare_data = paste(
      "Compares two tables with waldo::compare(), optionally sorting both by",
      "key columns first so row order differences don't mask real changes.",
      "The result is a comparison object with a colour-coded added/removed",
      "preview \u2014 useful for validating a refactored step or a data refresh."),
    filter_sort = paste(
      "Row filtering and ordering without the full Query Builder: build",
      "AND/OR conditions with operators that adapt to each column's type,",
      "then sort by any number of columns ascending or descending."),
    stack_columns = paste(
      "Wide to long: choose the columns to stack and the names for the new",
      "key/value pair (tidyr::pivot_longer). The classic first step before",
      "grouped summaries or faceted plots."),
    split_columns = paste(
      "Long to wide: values of one column become new column headers, filled",
      "from a value column (tidyr::pivot_wider); optional ID columns define",
      "the rows."),
    transpose = paste(
      "Swaps rows and columns with t(). An optional ID column supplies the",
      "new column headers. Because a matrix has one type, mixed-type tables",
      "are coerced to character."),
    rank = paste(
      "Adds a rank column using min_rank, dense_rank, row_number,",
      "percent_rank, or cume_dist, optionally ranked within groups."),
    standardize = paste(
      "Rescales chosen numeric columns: z-score (mean 0, sd 1) or min-max",
      "(0-1). Optional grouping standardises within each group \u2014 handy before",
      "clustering or PCA."),
    random_sample = paste(
      "Draws a random sample by row count or proportion, with or without",
      "replacement. Set the seed for a reproducible sample (the seed is also",
      "written into the generated code)."),
    remove_dups = paste(
      "Removes duplicate rows with dplyr::distinct(): whole-row duplicates,",
      "or duplicates of selected key columns (the first row per key wins and",
      "all columns are kept)."),
    keep_drop_cols = paste(
      "Keeps only a chosen set of columns, or drops them and keeps the rest",
      "(dplyr::select) \u2014 trim wide tables down to what downstream steps",
      "actually need."),
    rename_cols = paste(
      "Renames any number of columns through old-to-new pairs",
      "(dplyr::rename); pick each source column from a dropdown and type its",
      "replacement name."),
    first_last_n = paste(
      "Keeps only the first or last N rows (head/tail) \u2014 quick subsets and",
      "spot checks."),
    replace_missing = paste(
      "Fills NA values in selected columns (or all) with a fixed value, the",
      "column mean, median, or mode. Mean/median apply to numeric columns",
      "only; factors gain the fill value as a new level when needed."),
    derive_cols = paste(
      "Adds computed columns from R expressions (dplyr::mutate). Existing",
      "columns are available by name, along with common dplyr, tidyr,",
      "lubridate and stats helpers (if_else, case_when, lag, year, sd, ...)."),
    recode_values = paste(
      "Maps old values to new ones via a rule table, with an optional NA rule",
      "('NA' as the match value) and an else value for unmatched entries.",
      "The recoded column is always character, which avoids silent type",
      "coercion surprises."),
    change_types = paste(
      "Converts column storage types: numeric, integer, character, logical,",
      "factor, or Date. Date conversion auto-detects common formats",
      "(ISO, slashed, dotted, compact) from the first parseable value."),

    # ── Describe tasks ─────────────────────────────────────────────────────────
    characterize = paste(
      "Profiles every column: type, row count, missing count and percent,",
      "distinct values, and example values. The fastest first look at an",
      "unfamiliar table."),
    distribution = paste(
      "Histogram with optional density overlay and optional normal Q-Q plot",
      "for one numeric column, plus a summary-statistics table. Plots are",
      "interactive and downloadable as PNG or HTML."),
    list_data = paste(
      "A searchable, sortable data browser (with per-column filters) for any",
      "table \u2014 no transformation, just inspection. Optionally saves a copy",
      "under a new name."),
    one_way_freq = paste(
      "Frequency table for one variable: counts, percentages, and cumulative",
      "percentages, optionally sorted by frequency. Missing values are",
      "counted as their own level."),
    summary_stats = paste(
      "Per-column numeric summaries: n, missing, mean, sd, min, quartiles,",
      "median, max, and skewness. Leave the column selection blank to",
      "summarise every numeric column."),
    summary_tables = paste(
      "Cross-tabulated summaries: a row variable (optionally crossed with a",
      "column variable) summarising a value column with mean, sum, median,",
      "count, min, max, or sd. With no value column it produces counts."),
    table_analysis = paste(
      "Two-way contingency table with optional row, column, or total",
      "percentages, plus a chi-square test of independence. The chi-square",
      "statistics can be saved as their own tidy table."),

    # ── Graph tasks ────────────────────────────────────────────────────────────
    bar_chart = paste(
      "Bar chart of category counts, or of values when a numeric Y is",
      "mapped. Supports fill grouping, horizontal layout, and hover tooltips.",
      "The result table contains the plotted counts, not raw rows."),
    bar_line_chart = paste(
      "Bars and a line over the same X \u2014 e.g. monthly volume as bars with a",
      "trend line. Grouping colours the line series."),
    box_plot = paste(
      "Box-and-whisker plots by category; numeric X values are treated as",
      "categories. Supports fill grouping and horizontal layout."),
    bubble_plot = paste(
      "Scatter plot whose point size encodes a third numeric variable, with",
      "optional colour grouping and per-point tooltips."),
    contour_plot = paste(
      "Filled 2D density contours for two numeric variables \u2014 where the data",
      "concentrates when a scatter plot would overplot."),
    histogram_graph = paste(
      "Frequency histogram of one numeric column with adjustable bin count",
      "and optional fill grouping. The result table is the binned summary",
      "(bin edges, midpoints, counts, densities)."),
    line_plot = paste(
      "Line chart over a numeric or date X, with optional colour grouping",
      "for multiple series."),
    pie_chart = paste(
      "Pie chart of category shares; the result table holds the category",
      "counts that were plotted."),
    scatter_plot = paste(
      "XY scatter with optional colour grouping, size mapping, faceting, and",
      "per-point hover tooltips."),
    scatter_matrix = paste(
      "Distribution overview of several numeric columns at once as faceted",
      "histograms \u2014 a quick scan for skew, outliers, and scale differences."),

    # ── ANOVA ─────────────────────────────────────────────────────────────────
    one_way_anova = paste(
      "One-way analysis of variance (aov): does a numeric response differ",
      "across groups? Produces the tidy ANOVA table, fit statistics, Tukey",
      "HSD pairwise comparisons, optional predictions on new data, and the",
      "model object."),
    t_test = paste(
      "One-sample t-test of a numeric column, or a two-sample test when a",
      "two-level group variable is selected. Returns the tidy test table",
      "with a formatted summary card."),
    linear_models = paste(
      "General linear model (lm) with a response and any number of",
      "predictors. Broom outputs: coefficients with confidence intervals,",
      "fit statistics, fitted values, optional predictions on a new-data",
      "table (with optional confidence intervals), and the model object."),

    # ── Capability ─────────────────────────────────────────────────────────────
    cdf_plots = paste(
      "Empirical cumulative distribution plot for one numeric variable, with",
      "optional group colouring, plus a quantile table at 5% steps \u2014 read",
      "off any percentile directly."),
    probability_plots = paste(
      "Normal Q-Q plot with a quartile-based reference line, plus a",
      "normality table: Shapiro-Wilk test, skewness, and excess kurtosis."),

    # ── Control charts ─────────────────────────────────────────────────────────
    control_charts = paste(
      "Individuals chart (sigma from the average moving range) or, when a",
      "subgroup column is set, an Xbar chart (A2 x Rbar limits for balanced",
      "subgroups of 2-10). Western Electric run rules 1-4 flag",
      "out-of-control points beyond simple limit breaches; the result table",
      "records which rule each point triggered."),

    # ── Regression ─────────────────────────────────────────────────────────────
    linear_regression = paste(
      "Least-squares regression (lm) of a numeric response on chosen",
      "predictors, with the full broom output set: tidy coefficients with",
      "confidence intervals, glance fit statistics, augment fitted values,",
      "optional new-data predictions, and the model object."),
    logistic_regression = paste(
      "Binomial GLM for a 0/1 response. Coefficients are log-odds with",
      "z statistics; fit statistics, fitted values, predictions, and the",
      "model object are all available as outputs."),
    glm = paste(
      "Generalized linear model with a family selector (gaussian, binomial,",
      "poisson, Gamma) for counts, rates, and other non-normal responses.",
      "Same broom output set as the other regression tasks."),
    nonlinear_regression = paste(
      "Curve fitting with nls using presets: logistic and asymptotic",
      "(self-starting, robust), exponential, and power (log-regression",
      "starting values). Shows the fitted curve over the data and returns",
      "tidy coefficients, fit statistics, fitted values, and the model."),

    # ── Multivariate ───────────────────────────────────────────────────────────
    correlations = paste(
      "Pairwise-complete correlation matrix of chosen numeric variables",
      "(blank = all numeric), rendered as a colour-scaled table; the raw",
      "matrix and a tidy long-format pairs table are both available."),
    pca = paste(
      "Principal components (prcomp, scaled): explained-variance table,",
      "variable loadings, per-row component scores, and optional scores for",
      "a new-data table. The prcomp object can be saved for downstream use."),
    cluster_analysis = paste(
      "k-means clustering on chosen numeric variables with a configurable",
      "number of clusters: cluster centres, per-row assignments, and fit",
      "statistics (within/total sums of squares)."),

    # ── Survival ───────────────────────────────────────────────────────────────
    life_tables = paste(
      "Kaplan-Meier survival estimation (survival::survfit) from a",
      "time-to-event column and an event indicator (0/1, TRUE/FALSE, or pick",
      "the event level for factor columns), with optional strata. Outputs:",
      "the step-curve table with confidence bounds, a median-survival",
      "summary per stratum, the survival plot, and the survfit object."),
    proportional_hazards = paste(
      "Cox proportional-hazards regression (survival::coxph) of",
      "time-to-event on covariates. Coefficients come with hazard ratios",
      "(exp coef) beside the estimates, plus fit statistics, fitted values,",
      "risk predictions on new data, and the model object."),

    # ── Time series ────────────────────────────────────────────────────────────
    arima_forecast = paste(
      "Fits an ARIMA model to a value column (rows in time order) \u2014 via",
      "forecast::auto.arima when available, otherwise an AIC-selected grid \u2014",
      "and forecasts a chosen number of steps ahead with 80% and 95%",
      "intervals, plotted as ribbons after the observed series."),

    # ── Output ────────────────────────────────────────────────────────────────
    export_log = paste(
      "Export collected task logs to a text, CSV, or JSON file. Choose the tasks",
      "to include and wait for, a minimum severity, and a destination path.",
      "Failed tasks do not block this export. Logs include prior runs (up to",
      "1,000 entries per task) and are saved with the project. Configure logging",
      "in each task's Logging section: add rules, select events and severity, insert",
      "fields into messages and preview them. Reset task rules restores sensible",
      "defaults. Message inputs lists tokens and values; current/example previews",
      "show rendered entries and text/CSV/JSON without running tasks or writing files.",
      "Use log_event('message', 'INFO') in Script.",
      "Console capture and minimum severity apply to the rules. Run this task manually if Stop on error halted the flow."),
    export = paste(
      "Writes a flow output to disk \u2014 a sink step (no downstream output). Pick",
      "any dataset, object, or plot; the format menu adapts to its type:",
      "datasets export to CSV, TSV, Parquet, Feather, Excel, JSON, RDS, or",
      "RData (with optional column selection and CSV/TSV append); objects",
      "(models, PCA, clustering, Script outputs, \u2026) to RDS or RData; static",
      "plots to PNG, JPEG, TIFF, SVG, or PDF with width/height/DPI/background",
      "controls; interactive plots to self-contained HTML or SVG. Choose the",
      "destination folder and file name, then Export \u2014 it runs standalone or",
      "via Run Flow, goes stale when its source changes, and the generated",
      "code reproduces the write outside Individual Guide.",
      "Marked a favourite for quick access."),

    report = paste(
      "Assembles any flow outputs \u2014 tables, model summaries, plots, script",
      "results \u2014 into an HTML or Word document via R Markdown. Each item has",
      "an editable section heading, an optional note, a render override",
      "(auto by type, static table, interactive table, figure, or text",
      "print), and can be reordered. Items whose data has not been computed",
      "are flagged and skipped with a warning. The generated .Rmd preserves",
      "full reproducibility.")
  )
}

# ── Help modal ─────────────────────────────────────────────────────────────────

.help_p  <- function(...) p(class = "ig-help-p", ...)
.help_h  <- function(...) h5(class = "ig-help-h", ...)
.help_kbd <- function(...) {
  keys <- list(...)
  tagList(lapply(seq_along(keys), function(i) {
    tagList(tags$kbd(keys[[i]]), if (i < length(keys)) "+")
  }))
}

help_overview_tab <- function() {
  tagList(
    .help_h("What Individual Guide is"),
    .help_p(
      "Individual Guide is a low-code analytical pipeline builder in the",
      "spirit of SAS Enterprise Guide. You import data, chain tasks together",
      "on a visual process flow, and every task writes readable R code",
      "behind the scenes \u2014 copy or download the script at any time and run",
      "it anywhere R runs."),
    .help_h("The basic workflow"),
    tags$ol(class = "ig-help-p",
      tags$li(strong("Import"), " \u2014 bring in files or database tables with",
        " the Import Data task (or the Import button on the empty canvas)."),
      tags$li(strong("Transform & analyse"), " \u2014 add tasks from ",
        strong("Add Task"), "; each task takes input tables, produces named",
        " outputs, and those outputs immediately become available as inputs",
        " to later tasks."),
      tags$li(strong("Run"), " \u2014 run a single task from its panel, or run",
        " the whole flow in dependency order from the sidebar's play button",
        " (tasks never opened in a panel still run from their saved",
        " settings)."),
      tags$li(strong("Report"), " \u2014 assemble outputs into an HTML or Word",
        " document with the Report task."),
      tags$li(strong("Save"), " \u2014 projects save as .igpx files containing",
        " flows, task settings, computed tables, model objects, layout, and",
        " preferences; everything restores exactly on load.")
    ),
    .help_h("Code first, always"),
    .help_p(
      "Every task panel has a Code button showing the R it will run with the",
      "current settings, and the permanent Code tab assembles the whole",
      "pipeline in a readable Pipeline view, with Supporting functions and Complete",
      "script views. Copy R copies the selected view. Download .R includes everything;",
      "Download bundle provides pipeline.R and pipeline_support.R to keep together.")
  )
}

help_workspace_tab <- function() {
  tagList(
    .help_h("R Console"),
    .help_p("Open the permanent R Console tab (desktop: View > R console). ",
      "Enter runs a command; Shift+Enter adds a newline, and Ctrl+Enter runs multiline code. ",
      "Up/Down recalls commands at the first/last editor line; Alt+Up/Down works anywhere. ",
      "Ctrl+L clears output; Ctrl+C interrupts a running command when no text is selected. ",
      "Scrollback stays in place as output arrives; Latest output returns to the bottom. ",
      "Tables and objects load as named variables and in .project$tables and .project$objects. ",
      "Refresh data replaces these copies with the project's latest results, keeping other variables. ",
      "Live database handles are skipped. Printed output, messages, warnings, errors and plots appear above the editor. ",
      "Save transcript downloads text; the most recent 12 plots are displayed. ",
      "Stop terminates the console R process and clears its workspace. Reset R also clears history and output. ",
      "Console work is temporary and clears when you open, create or close a project, or restart R. ",
      "Use a Script task to keep reproducible code and outputs in your pipeline. ",
      "The console runs in a separate process; filesystem commands still access your files."),
    .help_h("Project tree (left sidebar)"),
    .help_p(
      "Data sources, process flows, and each flow's steps with their input",
      "and output datasets. Click a task to open its panel, a dataset to",
      "preview and export it. Flow actions: run (play), copy, rename,",
      "delete. A project can hold multiple flows, and a flow can use tables",
      "produced by another flow \u2014 the tree shows those dependencies."),
    .help_h("Flow tab (canvas)"),
    .help_p(
      "Datasets are boxes, tasks are ellipses, arrows show data lineage.",
      "Border colours: ", span(class = "ig-help-dot ig-help-dot-green"),
      " success, ", span(class = "ig-help-dot ig-help-dot-red"), " error, ",
      span(class = "ig-help-dot ig-help-dot-amber"),
      " stale (an upstream task was re-run more recently). Hover any node",
      " for details \u2014 dataset sizes, stale explanations, run hints.",
      " Right-click a task for notes and 'Run from / to here'. Use Fit view",
      " and Re-arrange (top right) to tidy the layout."),
    .help_h("Task panels"),
    .help_p(
      "Each opened task gets its own tab; panels stay alive so switching",
      "tabs never loses settings. The header bar above every panel shows",
      "the task's identity, a live status chip (not run / ran at a time /",
      "failed with the error on hover), a Run button, a Code toggle with",
      "the live generated R, and delete. Tabs show green/red status dots."),
    .help_p(
      "Inside a panel, the ", strong("Setup"), " tab holds all of the task's",
      " inputs and options, and the ", strong("Results"), " tab holds the",
      " output \u2014 tables, plots, and code. Running or previewing a task",
      " switches to Results automatically; switch back to Setup at any time",
      " to adjust and re-run."),
    .help_h("Code tab"),
    .help_p(
      "Pipeline view shows named steps in dependency order. Supporting functions",
      "contains shared calculations and logging; Complete script combines both.",
      "Download .R is self-contained. Download bundle provides pipeline.R and",
      "pipeline_support.R: keep them together and run Rscript --vanilla pipeline.R.",
      "Exports preserve configured seeds and controls. Referenced packages and input",
      "data must be available; no Individual Guide installation is needed."),
    .help_h("Header bar"),
    .help_p(
      "Add Task opens the searchable picker (star favourites to pin them to",
      "the top). Save shows an amber dot when there are unsaved changes \u2014",
      "the browser also warns before closing. Settings holds the theme,",
      "preview row count, plot defaults, run behaviour, and delete",
      "confirmations; all are saved with the project.")
  )
}

help_tasks_tab <- function() {
  details <- ig_task_help_details()
  sections <- lapply(task_categories(), function(cat) {
    entries <- lapply(tasks_for_category(cat), function(t) {
      div(class = "ig-help-task", `data-label` = tolower(t$label),
        div(class = "ig-help-task-head",
          icon(t$icon %||% "circle"), strong(t$label)),
        .help_p(t$desc),
        if (!is.null(details[[t$id]])) {
          p(class = "ig-help-task-details", details[[t$id]])
        }
      )
    })
    div(class = "ig-help-cat",
      h5(class = "ig-help-cat-title", cat,
        span(class = "ig-picker-count", length(entries))),
      entries
    )
  })
  tagList(
    div(class = "mb-2",
      textInput("help_task_search", sr_label("Search task reference"),
        placeholder = "Filter tasks\u2026", width = "100%")),
    sections
  )
}

help_running_tab <- function() {
  tagList(
    .help_h("Running a single task"),
    .help_p(
      strong("Preview"), " executes without saving anything \u2014 inspect the",
      " result first. ", strong("Run & Save"), " (or the header Run button)",
      " executes and writes the outputs into the project so downstream",
      " tasks and reports can use them."),
    .help_h("Running flows"),
    .help_p(
      "The play button on a flow (or ", .help_kbd("Ctrl", "Alt", "R"),
      ") runs every task in dependency order \u2014 producers always before",
      " consumers, regardless of creation order. Tasks whose panels were",
      " never opened run from their saved settings. Right-click a canvas",
      " node for ", em("Run from here"), " (the node and everything",
      " downstream) or ", em("Run to here"), " (everything it depends on,",
      " then itself). A summary reports successes and names any failures;",
      " optionally stop at the first failure via Settings."),
    .help_h("Statuses and staleness"),
    .help_p(
      "A task is ", strong("stale"), " when something upstream was re-run",
      " more recently \u2014 its canvas border turns amber with an explanation in",
      " the tooltip, including transitively (a stale parent makes children",
      " stale). Re-run the task (or 'Run from' the upstream node) to",
      " refresh. Errors turn the border red; the message is stored on the",
      " task and shown in the panel header chip's tooltip."),
    .help_h("Output names"),
    .help_p(
      "Every output has an editable name; renaming retires the old table so",
      " stale copies never linger. A task cannot use its own output (or a",
      " descendant's) as input \u2014 the selectors hide them, and cycles are",
      " rejected with a message. Model tasks expose extra outputs (fit",
      " statistics, fitted values, predictions, the model object) that can",
      " be individually renamed and toggled on or off.")
  )
}

help_projects_tab <- function() {
  tagList(
    .help_h("Projects (.igpx)"),
    .help_p(
      "A project file is a zip of JSON documents: flows and task",
      " definitions, computed tables (with their R types preserved), model",
      " and plot objects, canvas layout, favourites, theme, and settings.",
      " Lazy database tables are not persisted \u2014 re-run their Import task",
      " after loading to re-establish the connection."),
    .help_h("Settings"),
    tags$ul(class = "ig-help-p",
      tags$li(strong("Appearance"), " \u2014 dark or light theme."),
      tags$li(strong("Preview rows per page"), " \u2014 applies to every result",
        " and preview table."),
      tags$li(strong("Default plot theme / palette"), " \u2014 starting style for",
        " new graph tasks."),
      tags$li(strong("Stop Run Flow at first failing task"), " \u2014 fail fast",
        " instead of running the remaining tasks."),
      tags$li(strong("Confirm before deleting"), " \u2014 turn off to skip the",
        " task/flow delete dialogs.")
    ),
    .help_h("Keyboard"),
    .help_p(
      "The app is fully keyboard-operable: a skip link, roving-tabindex",
      " tabs (arrow keys move and activate, Delete closes), Enter/Space",
      " activate tree items and collapsible groups. App-wide shortcuts",
      " (", .help_kbd("Ctrl", "Alt", "R"), " run, ",
      .help_kbd("Ctrl", "Alt", "S"), " save, ",
      .help_kbd("Ctrl", "Alt", "N"), " add task, and more) are listed under",
      " the keyboard icon in the header.")
  )
}

#' Build the Help modal. Opened from the header's question-mark button.
help_modal_ui <- function() {
  modalDialog(
    title = div(icon("circle-question"), " Help \u2014 Individual Guide"),
    size = "l",
    easyClose = TRUE,
    footer = modalButton("Close"),
    div(class = "ig-help-body",
      bslib::navset_tab(
        id = "help_tabs",
        bslib::nav_panel("Overview",  div(class = "ig-help-pane", help_overview_tab())),
        bslib::nav_panel("Example projects", value = "examples", div(class = "ig-help-pane", help_examples_tab())),
        bslib::nav_panel("Workspace", div(class = "ig-help-pane", help_workspace_tab())),
        bslib::nav_panel("Tasks",     div(class = "ig-help-pane", help_tasks_tab())),
        bslib::nav_panel("Running",   div(class = "ig-help-pane", help_running_tab())),
        bslib::nav_panel("Projects & settings",
          div(class = "ig-help-pane", help_projects_tab()))
      )
    )
  )
}
