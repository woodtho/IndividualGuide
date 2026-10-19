# Rebuild the shipped projects by running their real tasks, then saving .igpx.
.libPaths(c("build/staging/runtime/R/library", .libPaths()))
Sys.setlocale("LC_CTYPE", ".UTF-8")
pkgload::load_all(quiet = TRUE)
env <- new.env(parent = asNamespace("IndividualGuide"))
sys.source("R/examples.R", envir = env)
sys.source("tools/example-recipes.R", envir = env)
evalq({
  alter <- function(p, ...) { values <- list(...); for (name in names(values)) p[[name]] <- values[[name]]; p }
  build_example <- function(info, destination) {
    store <- make_store()
    flow <- make_flow(info$title); flow$id <- paste0("example_", gsub("-", "_", info$id))
    store$flows <- setNames(list(flow), flow$id); store$active_flow <- flow$id
    work <- tempfile("ig-example-build-"); dir.create(work)
    old <- setwd(work); on.exit(setwd(old), add = TRUE)
    on.exit(unlink(work, recursive = TRUE), add = TRUE)
    on.exit(project_release_assets(store), add = TRUE)
    add <- function(id, type, p, label, note = "") {
      task <- store_task_from_params(task_def(id, type), p)
      task$label <- label; task$note <- note
      task$logging <- alter(ig_logging_config(type = type), min_level = "DEBUG",
        success_message = paste0(info$title, " | {task_name}: {rows_out} output rows; {outputs} ({elapsed}s)"))
      store_set_task(store, task)
    }
    script <- function(id, code, name, label, inputs = character(), defs = NULL, note = "") {
      add(id, "script", alter(default_script_params(name), code = code, input_tables = inputs,
        output_defs = defs %||% list(list(name = name, kind = "table"))), label, note)
    }
    graph <- function(input, x, y, group = "", title) {
      p <- alter(default_phase3_params("scatter_plot", "chart_data"), input_table = input,
        x = x, y = y, group = group, title = title)
      p$output_enabled$image <- TRUE
      # Cached girafe widgets retain machine-specific gdtools font directories.
      # Ship the portable ggplot image; a live run still produces the task's
      # interactive preview using the current machine's font dependencies.
      p$output_enabled$plot <- FALSE
      add("example_chart", "scatter_plot", p, "Explore relationships", "Inspect the saved static image, or run the task for a fresh interactive preview. Enable the plot output to save that preview locally.")
    }
    report_items <- list()
    item <- function(name, heading) list(name = name, heading = heading)
    if (info$id == "iris") {
      script("example_source", paste(
        "# Real bundled data; no downloads or external input files.",
        "flowers <- datasets::iris",
        "log_event(sprintf('Loaded %d iris observations across %d species', nrow(flowers), nlevels(flowers$Species)))",
        "print(table(flowers$Species))", sep = "\n"), "flowers", "Load 150 iris measurements", note = info$source)
      add("example_summary", "summary_stats", alter(default_summary_stats_params("measurement_summary"),
        input_table = "flowers", cols = c("Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width")), "Summarize measurements")
      add("example_groups", "summary_tables", alter(default_summary_tables_params("species_summary"),
        input_table = "flowers", row_var = "Species", value_var = "Petal.Length", stat_fn = "mean"), "Compare mean petal length by species")
      graph("flowers", "Sepal.Length", "Petal.Length", "Species", "Iris measurements by species")
      export_source <- "species_summary"
      report_items <- list(item("measurement_summary", "Measurement summaries"), item("species_summary", "Species comparison"), item("chart_data_image", "Sepal and petal lengths"))
    } else if (info$id == "air-quality") {
      script("example_source", paste("# Original observations, including their missing values.",
        "air_raw <- datasets::airquality", "log_event(sprintf('Loaded %d daily air-quality records', nrow(air_raw)))", sep = "\n"),
        "air_raw", "Load original daily observations", note = info$source)
      script("example_audit", paste(
        "missing_audit <- data.frame(column=names(air_raw), missing=vapply(air_raw, function(x) sum(is.na(x)), integer(1)))",
        "log_event(sprintf('Missing-value audit: %d missing measurements; raw data is preserved', sum(missing_audit$missing)), 'WARN')",
        "print(missing_audit)", sep = "\n"), "missing_audit", "Audit missing measurements", "air_raw")
      add("example_before", "summary_stats", alter(default_summary_stats_params("raw_summary"),
        input_table = "air_raw", cols = c("Ozone", "Solar.R", "Wind", "Temp")), "Summarize original measurements")
      add("example_clean", "replace_missing", alter(default_replace_missing_params("air_clean"),
        input_table = "air_raw", cols = c("Ozone", "Solar.R"), method = "mean"), "Demonstrate mean imputation",
        "Teaching example: mean imputation changes the distribution and is not a general recommendation. The original data and missing-value audit are retained.")
      add("example_summary", "summary_stats", alter(default_summary_stats_params("clean_summary"),
        input_table = "air_clean", cols = c("Ozone", "Solar.R", "Wind", "Temp")), "Compare cleaned summaries")
      graph("air_clean", "Temp", "Ozone", title = "Temperature and ozone after illustrative imputation")
      export_source <- "air_clean"
      report_items <- list(item("missing_audit", "Missing-value audit"), item("raw_summary", "Original summaries"), item("clean_summary", "After mean imputation (illustration)"), item("chart_data_image", "Temperature and ozone"))
    } else if (info$id == "fuel-economy") {
      script("example_source", paste("# Real Motor Trend observations; retain car names as a column.",
        "cars <- datasets::mtcars", "cars$car <- rownames(cars)", "rownames(cars) <- NULL",
        "log_event(sprintf('Loaded %d cars; modelling mpg using wt and hp', nrow(cars)))", sep = "\n"),
        "cars", "Load 32 Motor Trend cars", note = info$source)
      add("example_summary", "summary_stats", alter(default_summary_stats_params("car_summary"),
        input_table = "cars", cols = c("mpg", "wt", "hp")), "Summarize fuel economy and predictors")
      model <- alter(default_phase3_params("linear_regression", "mpg_model"), input_table = "cars", response = "mpg", predictors = c("wt", "hp"))
      model$output_enabled$model <- TRUE; model$output_enabled$augment <- TRUE
      add("example_model", "linear_regression", model, "Fit mpg ~ weight + horsepower",
        "Inspect coefficients, model fit, fitted values and residuals. Observational associations do not establish causation.")
      graph("cars", "wt", "mpg", title = "Fuel economy and car weight")
      export_source <- "mpg_model"
      report_items <- list(item("car_summary", "Input summaries"), item("mpg_model", "Regression coefficients"), item("mpg_model_glance", "Model fit"), item("mpg_model_augment", "Fitted values and residuals"), item("chart_data_image", "Observed weight and fuel economy"))
    } else {
      recipe <- build_extended_example(info, add, script, work)
      export_source <- recipe$source
      report_items <- recipe$items
    }
    add("example_csv", "export", alter(default_export_params(), source = export_source,
      dir = ".", filename = paste0(info$id, "-results.csv"), overwrite = TRUE), "Export results to CSV")
    if (info$id %in% c("iris", "air-quality", "fuel-economy"))
      add("example_png", "export", alter(default_export_params(), source = "chart_data_image", format = "png", value_kind = "image",
        dir = ".", filename = paste0(info$id, "-chart.png"), overwrite = TRUE, dpi = 100), "Export chart to PNG")
    add("example_report", "report", alter(default_report_params("example_report"), title = info$title,
      subtitle = info$source, items = report_items, include_log = TRUE), "Read the completed HTML report and execution log")
    if (info$id == "report-audit") for (format in c("txt", "json"))
      add(paste0("example_log_", format), "export_log", alter(default_export_log_params(),
        path = paste0(info$id, "-task-log.", format), format = format, overwrite = TRUE,
        after_tasks = isolate(store$task_order)), paste("Export", toupper(format), "audit log"))
    log_format <- switch(info$id, iris = "txt", `air-quality` = "json", "csv")
    add("example_log", "export_log", alter(default_export_log_params(), path = paste0(info$id, "-task-log.", log_format),
      format = log_format, overwrite = TRUE, after_tasks = isolate(store$task_order)), "Export the pipeline log",
      "This final task depends on every preceding task. Inspect Logging to customize templates and severity, then run the flow again.")
    if (info$id %in% c("branching", "looping")) {
      id <- if (info$id == "branching") "example_summary_stats" else "example_iteration"
      task <- isolate(store$tasks[[id]])
      task$control_inputs <- if (info$id == "branching") "quality_gate_true" else "species_loop_each"
      store_set_task(store, task)
    }
    actual <- unique(vapply(isolate(store$tasks), `[[`, character(1), "type"))
    if (!setequal(actual, info$task_types)) stop("Catalog/recipe task mismatch: ", info$id)
    order <- store_topo_order(isolate(store$tasks), isolate(store$task_order))
    loop_body <- character()
    for (id in order) {
      if (id %in% loop_body) next
      if (!isTRUE(run_task_from_store(store, id))) stop("Example failed: ", info$id, "/", id, ": ", isolate(store$tasks[[id]]$error_msg))
      if (identical(isolate(store$tasks[[id]]$type), "loop")) loop_body <- c(loop_body, isolate(store$tasks[[id]]$loop_body_ids))
    }
    file.copy(isolate(store$tasks$example_report$outputs[[1]]$path), file.path(work, paste0(info$id, "-report.html")), overwrite = TRUE)
    for (path in list.files(work, pattern = "\\.txt$", full.names = TRUE))
      writeLines(sub("[ \t]+$", "", readLines(path, warn = FALSE, encoding = "UTF-8")), path, useBytes = TRUE)
    dir.create(destination, recursive = TRUE, showWarnings = FALSE)
    out_dir <- file.path(destination, "outputs"); dir.create(out_dir, showWarnings = FALSE)
    output_files <- list.files(work, full.names = TRUE)
    if (!all(file.copy(output_files, out_dir, recursive = TRUE, overwrite = TRUE))) stop("Could not copy example exports")
    project_save(store, file.path(destination, "project.igpx"), portable = TRUE)
    writeLines(c(paste0("# ", info$title), "", info$description, "", info$source,
      "Data source: R's datasets package or survival::lung (the survival package is included with R). Use the named dataset's R help page for original references, units and variable definitions. No downloaded or synthetic observations are used. Some recipes add identifiers, derive fields or deliberately duplicate a row to demonstrate cleaning; the source task documents preparation.",
      "", "## Try this workflow", "", info$learn,
      "", "All tasks have already been executed. Inspect intermediate datasets, saved figures and the HTML report in the project tree. The report includes a Pipeline execution log appendix containing retained events available before report generation. The final Export Log includes the report completion event as well. Repeated runs accumulate retained events (up to 1,000 per task); use run_id to distinguish them. In Report > Appearance, disable the appendix or choose its minimum severity.",
      "", "Open any task's Logging panel to customize templates and severity. Source and iteration scripts demonstrate log_event(). The report-audit example additionally exports all three log formats (TXT, CSV, JSON).",
      "", "Run the full flow to reproduce the results, report and exports. Export paths are rebased into a fresh private examples folder when opened from Help. Overwrite is enabled only for those example output filenames. Edit the Export/Export Log destinations to save elsewhere.",
      "", "Use Save As to keep a project copy. The bundled project is never overwritten. Independent openings have separate output folders.",
      if (info$id == "air-quality") c("", "Mean imputation is solely a demonstration; the original incomplete data is preserved."),
      if (info$id == "fuel-economy") c("", "The fuel-economy model demonstrates an observational association.")),
      file.path(destination, "README.md"), useBytes = TRUE)
    list(id = info$id, tasks = length(order), rows = info$rows,
      log_events = nrow(ig_log_records(isolate(store$tasks))),
      task_types = actual, outputs = basename(output_files), project_bytes = file.info(file.path(destination, "project.igpx"))$size)
  }
}, envir = env)
root <- normalizePath(".", winslash = "/")
selected <- commandArgs(TRUE)
catalog <- env$ig_example_catalog()
if (length(selected)) catalog <- Filter(function(info) info$id %in% selected, catalog)
results <- lapply(catalog, function(info) {
  cat("Building", info$id, "\n")
  env$build_example(info, file.path(root, "inst/examples", info$id))
})
source("tools/sanitize-examples.R", local = TRUE)
dir.create("artifacts/review", recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(list(ok = TRUE, examples = results), "artifacts/review/examples-build.json", pretty = TRUE, auto_unbox = TRUE)
