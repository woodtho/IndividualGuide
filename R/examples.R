# Bundled examples are ordinary saved projects. Opening from Help prepares a
# writable copy before the live project is replaced.
ig_example_catalog <- function() {
  examples <- list(
    list(id = "iris", title = "Iris exploration", rows = 150L,
      description = "Explore measurements from 150 flowers: species summaries, a scatter plot, an HTML report and exported results.",
      source = "R datasets::iris — Anderson's iris measurements, as used by Fisher.",
      learn = "Script inputs, Summary Statistics, grouped charts, custom logging, CSV/PNG export and reports."),
    list(id = "air-quality", title = "Air quality - clean and compare", rows = 153L,
      description = "Clean 153 daily New York air-quality observations, inspect missing values and compare ozone measurements with temperature.",
      source = "R datasets::airquality — New York daily measurements, May–September 1973.",
      learn = "Missing-value audit, Replace Missing Values, before/after summaries, charts and a JSON task log. Mean imputation is an illustration, not an analytical recommendation."),
    list(id = "fuel-economy", title = "Fuel economy model", rows = 32L,
      description = "Use 32 Motor Trend cars to model fuel economy from weight and horsepower, inspect coefficients, fitted values and a model report.",
      source = "R datasets::mtcars — data extracted from the 1974 Motor Trend US magazine.",
      learn = "Linear Regression, saved model objects and diagnostics, charts, an HTML report and a CSV task log.")
  )
  originals <- list(iris = c("summary_stats", "summary_tables", "scatter_plot"),
    `air-quality` = c("summary_stats", "replace_missing", "scatter_plot"),
    `fuel-economy` = c("summary_stats", "linear_regression", "scatter_plot"))
  for (i in seq_along(examples)) examples[[i]]$task_types <- originals[[examples[[i]]$id]]
  entry <- function(id, title, dataset, rows, description, types, learn) {
    list(id = id, title = title, dataset = dataset, rows = rows, description = description,
      source = paste0("Bundled R data: ", dataset, ". See the project README for preparation and interpretation notes."),
      task_types = types, learn = learn)
  }
  examples <- c(examples, list(
    entry("data-cleaning", "Cars - prepare an analysis table", "datasets::mtcars", 32L,
      "Turn car measurements into a labelled, deduplicated analysis table and inspect each intermediate result.",
      c("remove_dups", "keep_drop_cols", "rename_cols", "derive_cols", "recode_values", "change_types", "first_last_n", "characterize"),
      "Remove duplicates, choose and rename columns, compute power-to-weight, recode transmission and convert types."),
    entry("query-joins", "US states - import, join and filter", "datasets::state.x77 and state.region", 50L,
      "Import a bundled CSV of state statistics, join a regional lookup, filter and sort the result.",
      c("import_data", "query_builder", "filter_sort"), "Local-file imports, a left join, numeric filters and descending sorts. No database connection required."),
    entry("reshape", "Iris - reshape and compare", "datasets::iris", 150L,
      "Pivot flower measurements to long form and back, compare the round trip, append species subsets and transpose a small table.",
      c("stack_columns", "split_columns", "transpose", "compare_data", "append_table"),
      "Wide/long layouts, row identifiers, round-trip validation, stacking tables and matrix orientation."),
    entry("sampling", "Cars - rank, scale and sample", "datasets::mtcars", 32L,
      "Rank fuel economy, standardize predictors and draw a reproducible sample with an explicit seed.",
      c("rank", "standardize", "random_sample"), "Ranking methods, z-scores and deterministic sampling. Compare the sample with the full dataset."),
    entry("descriptive", "Tooth growth - descriptive analysis", "datasets::ToothGrowth", 60L,
      "Inspect column structure, list observations, count supplement groups, cross-tabulate dose and summarize tooth lengths.",
      c("characterize", "list_data", "one_way_freq", "summary_stats", "summary_tables", "table_analysis", "distribution"),
      "Frequencies, contingency tests, grouped summaries and distribution diagnostics. The balanced design is not an association finding."),
    entry("category-charts", "Flowers - categorical chart gallery", "datasets::iris", 150L,
      "Compare species with bars, a pie chart and grouped box plots, then collect the figures into a report.",
      c("bar_chart", "pie_chart", "box_plot"), "Counts versus numeric summaries, categories, box plots and portable static figures."),
    entry("numeric-charts", "Flowers - numeric chart gallery", "datasets::iris", 150L,
      "Explore numeric relationships with bubbles, density contours, histograms, scatter plots and a scatter matrix.",
      c("bubble_plot", "contour_plot", "histogram_graph", "scatter_plot", "scatter_matrix"),
      "Colour and size mappings, density contours, histogram bins and pairwise numeric comparisons."),
    entry("time-charts", "Nottingham temperatures - time charts", "datasets::nottem", 240L,
      "Chart twenty years of monthly temperatures and compare annual averages with their observed range.",
      c("line_plot", "bar_line_chart"), "Chronological ordering, line charts and an explicitly labelled secondary axis."),
    entry("anova", "Plant growth - compare experimental groups", "datasets::PlantGrowth", 30L,
      "Compare plant weights across control and treatment groups, with ANOVA, a two-group t test and a general linear model.",
      c("one_way_anova", "t_test", "linear_models"), "ANOVA and post-hoc results, independent-sample t tests and model coefficients. Inspect assumptions before drawing conclusions."),
    entry("binary-model", "Cars - binary outcome model", "datasets::mtcars", 32L,
      "Model manual versus automatic transmission with a logistic regression and retain fitted probabilities and coefficients.",
      "logistic_regression", "Binary response coding, predictor choice and model diagnostics. This small observational dataset is a teaching example."),
    entry("count-model", "Loom breaks - a count model", "datasets::warpbreaks", 54L,
      "Fit a Poisson model to counts of loom breaks by wool and tension, and retain model diagnostics.",
      "glm", "A generalized linear model with Poisson family and categorical predictors. Check overdispersion before using Poisson inference."),
    entry("nonlinear", "Puromycin - fit a nonlinear curve", "datasets::Puromycin", 23L,
      "Fit a power curve to enzyme reaction rates in the treated sample and compare it with the observations.",
      c("nonlinear_regression", "filter_sort"), "Nonlinear fitting with a documented curve preset. A power curve illustrates fitting; it is not a biochemical mechanism."),
    entry("multivariate", "Flowers - multivariate structure", "datasets::iris", 150L,
      "Explore correlations, principal components and three clusters using the four flower measurements.",
      c("correlations", "pca", "cluster_analysis"), "Correlation matrices, scaled PCA, loadings, scores and seeded k-means. Species labels are held aside from clustering."),
    entry("survival", "Lung cancer - survival analysis", "survival::lung", 228L,
      "Prepare complete cases, translate the event code, inspect Kaplan-Meier estimates and fit an illustrative Cox model.",
      c("life_tables", "proportional_hazards"), "Time-to-event data, censoring, grouped survival curves and Cox coefficients. Educational analysis, not clinical guidance."),
    entry("forecast", "Air passengers - forecast a monthly series", "datasets::AirPassengers", 144L,
      "Forecast twelve months of airline passengers with the app's ARIMA task, retaining point forecasts and intervals.",
      "arima_forecast", "Time ordering, forecast horizon and uncertainty intervals. The task uses its basic ARIMA selection, not a tuned seasonal forecasting workflow."),
    entry("quality-control", "Nile flow - distribution and stability", "datasets::Nile", 100L,
      "Inspect annual river flow with an individuals chart, empirical CDF and normal probability plot.",
      c("control_charts", "cdf_plots", "probability_plots"), "Control limits, flagged observations, quantiles and normality diagnostics. The river series is historical data, not a controlled manufacturing process."),
    entry("branching", "Flowers - conditional quality gate", "datasets::iris", 150L,
      "Use a row-count condition to activate a summary path and record the gate decision in the audit log.",
      c("branch", "summary_stats"), "Branch tokens, data-dependent routing and explicit logging of the selected path. Change the threshold to try the fallback."),
    entry("looping", "Flowers - repeat by species", "datasets::iris", 150L,
      "Loop over the three species, compute a separate summary per iteration and keep iteration-aware logs.",
      "loop", "Group iteration, loop context, output naming and per-iteration log events."),
    entry("report-audit", "Cars - a report with an execution audit", "datasets::mtcars", 32L,
      "Create a results report with a pipeline-log appendix, a custom warning and separate text, CSV and JSON log files.",
      "summary_stats", "Report Appearance: Include pipeline log, severity filtering, custom task messages and machine-readable audit exports.")
  ))
  lapply(examples, function(example) {
    example$task_types <- unique(c("script", example$task_types, "export", "report", "export_log"))
    example$categories <- unique(vapply(example$task_types, function(type) task_type_info(type)$category, character(1)))
    example
  })
}

ig_example_info <- function(id) {
  if (!is.character(id) || length(id) != 1L || is.na(id)) stop("Choose a listed example project.")
  matches <- Filter(function(example) identical(example$id, id), ig_example_catalog())
  if (!length(matches)) stop("Unknown example project.")
  matches[[1L]]
}

ig_prepare_example <- function(id) {
  info <- ig_example_info(id)
  source <- system.file("examples", id, package = "IndividualGuide")
  if (!nzchar(source) || !file.exists(file.path(source, "project.igpx")))
    stop("The bundled example is missing. Reinstall the app to restore it.")
  root <- getOption("ig.examples_dir")
  if (is.null(root)) {
    desktop <- Sys.getenv("IG_USER_DATA", unset = "")
    root <- file.path(if (nzchar(desktop)) desktop else tools::R_user_dir("IndividualGuide", "data"), "examples")
  }
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  workspace <- tempfile(paste0(id, "-"), tmpdir = root)
  if (!dir.create(workspace)) stop("Could not create an example project folder.")
  workspace <- normalizePath(workspace, winslash = "/", mustWork = TRUE)
  complete <- FALSE
  on.exit(if (!complete) unlink(workspace, recursive = TRUE), add = TRUE)
  files <- list.files(file.path(source, "outputs"), full.names = TRUE)
  if (length(files) && !all(file.copy(files, workspace, recursive = TRUE)))
    stop("Could not copy the example outputs.")
  readme <- file.path(source, "README.md")
  if (file.exists(readme) && !file.copy(readme, workspace)) stop("Could not copy the example guide.")
  staged <- make_store()
  on.exit(project_release_assets(staged), add = TRUE)
  loaded <- project_load(staged, file.path(source, "project.igpx"))
  if (!isTRUE(loaded$ok)) stop("The example project could not be restored completely.")
  flows <- isolate(staged$flows)
  for (fid in names(flows)) for (tid in names(flows[[fid]]$tasks)) {
    task <- flows[[fid]]$tasks[[tid]]
    if (identical(task$type, "export")) task$params$dir <- workspace
    if (identical(task$type, "export_log")) task$params$path <- file.path(workspace, basename(task$params$path))
    if (task$type %in% c("export", "export_log")) {
      task$portable_export <- NULL
      task$export_file <- if (identical(task$type, "export_log")) task$params$path else
        ig_export_path(workspace, task$params$filename, task$params$format)
      task$r_code <- build_task_code(task)
    }
    flows[[fid]]$tasks[[tid]] <- task
  }
  staged$flows <- flows
  active <- isolate(staged$active_flow)
  staged$tasks <- flows[[active]]$tasks; staged$task_order <- flows[[active]]$task_order
  path <- file.path(workspace, paste0(info$id, ".igpx"))
  project_save(staged, path)
  complete <- TRUE
  list(path = path, directory = workspace, title = info$title)
}

help_examples_tab <- function() {
  tagList(
    .help_p("Open a complete project with real data, configured tasks, retained logs and saved outputs. ",
      "Everything is bundled and works offline. Each opening creates a separate writable copy; Save As keeps your own project file."),
    div(id = "ig-example-library",
      div(class = "ig-example-filters",
        div(tags$label(`for` = "ig-example-search", "Search examples"),
          tags$input(id = "ig-example-search", type = "search", `data-shiny-no-bind-input` = NA, class = "form-control", placeholder = "Data, workflow or task…")),
        div(tags$label(`for` = "ig-example-type", "Task type"),
          tags$select(id = "ig-example-type", class = "form-select", `data-shiny-no-bind-input` = NA,
            tags$option(value = "", "All task types"), lapply(TASK_REGISTRY, function(type)
              tags$option(value = type$id, paste(type$category, "—", type$label))))),
        div(tags$label(`for` = "ig-example-category", "Task category"),
          tags$select(id = "ig-example-category", class = "form-select", `data-shiny-no-bind-input` = NA,
            tags$option(value = "", "All categories"), lapply(unique(vapply(TASK_REGISTRY, `[[`, character(1), "category")), function(category)
              tags$option(value = category, category))))),
      p(id = "ig-example-count", role = "status", `aria-live` = "polite"),
      p(id = "ig-example-empty", hidden = NA, "No examples match. Clear the search or choose another task type."),
      tagList(lapply(ig_example_catalog(), function(example) {
      div(class = "ig-example-card",
        `data-tasks` = paste(example$task_types, collapse = "|"),
        `data-categories` = paste(example$categories, collapse = "|"),
        tags$h4(example$title), p(example$description),
        p(class = "small text-muted", example$source),
        p(class = "small", strong("Try: "), example$learn),
        p(class = "ig-example-tasks small", paste(vapply(example$task_types, function(type) task_type_info(type)$label, character(1)), collapse = " · ")),
        tags$button(type = "button", class = "btn btn-primary btn-sm",
          `data-ig-example` = example$id, id = paste0("help_example_", example$id),
          onclick = ig_input_event_js("help_example", example$id), icon("folder-open"), " Open example"))
    })), tags$script(HTML("(() => {
      const root = document.getElementById('ig-example-library');
      const search = root.querySelector('#ig-example-search'), type = root.querySelector('#ig-example-type'), category = root.querySelector('#ig-example-category');
      const cards = Array.from(root.querySelectorAll('.ig-example-card'));
      function filter() {
        const words = search.value.toLocaleLowerCase().trim().split(/\\s+/).filter(Boolean);
        let count = 0;
        cards.forEach(card => {
          const match = (!type.value || card.dataset.tasks.split('|').includes(type.value)) &&
            (!category.value || card.dataset.categories.split('|').includes(category.value)) &&
            words.every(word => card.textContent.toLocaleLowerCase().includes(word));
          card.hidden = !match; if (match) count++;
        });
        root.querySelector('#ig-example-count').textContent = count + ' of ' + cards.length + ' examples';
        root.querySelector('#ig-example-empty').hidden = count !== 0;
      }
      search.addEventListener('input', filter); type.addEventListener('change', filter); category.addEventListener('change', filter); filter();
    })();"))),
    .help_p("After opening, inspect datasets and charts in the project tree, open a task's Logging tab, ",
      "or run the full flow to regenerate the outputs. File exports are written into that example's own folder; ",
      "the Export and Export Log tasks show their destinations. The included README explains the data and workflow.")
  )
}
