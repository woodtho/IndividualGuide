# Shared fixtures for the before/after export audit. No application internals
# are needed when the resulting scripts run in fresh R processes.
code_readability_fixtures <- function(root) {
  store <- function() {
    value <- make_store(); flow <- make_flow("Readable export audit")
    value$flows <- stats::setNames(list(flow), flow$id); value$active_flow <- flow$id
    value
  }
  add <- function(store, task) shiny::isolate(store_set_task(store, task))
  pipeline <- store()
  p <- default_script_params("raw")
  p$code <- "# Keep user-written code exactly as entered.\nraw <- datasets::mtcars"
  p$output_defs <- list(list(name = "raw", kind = "table"))
  add(pipeline, task_def("source", "script", output = "raw", params = p))
  tasks <- list()
  p <- default_summary_stats_params("summary"); p$input_table <- "raw"; p$cols <- c("mpg", "wt")
  tasks$summary <- store_task_from_params(task_def("summary", "summary_stats"), p)
  p <- default_random_sample_params("sampled"); p$input_table <- "raw"; p$n <- 12L; p$seed <- 17L
  tasks$sample <- store_task_from_params(task_def("sample", "random_sample"), p)
  p <- default_phase3_params("linear_regression", "coefficients")
  p$input_table <- "raw"; p$response <- "mpg"; p$predictors <- c("wt", "hp")
  tasks$fit <- store_task_from_params(task_def("fit", "linear_regression"), p)
  p <- default_phase3_params("scatter_plot", "points")
  p$input_table <- "raw"; p$x <- "wt"; p$y <- "mpg"
  tasks$graph <- store_task_from_params(task_def("graph", "scatter_plot"), p)
  for (task in tasks) add(pipeline, task)
  p <- default_export_log_params(); p$path <- file.path(root, "pipeline.csv"); p$format <- "csv"; p$overwrite <- TRUE
  p$after_tasks <- names(shiny::isolate(pipeline$tasks))
  add(pipeline, task_def("logs", "export_log", params = p))
  loop <- store()
  p <- default_script_params("raw"); p$code <- "raw <- data.frame(x = 1:4)"
  p$output_defs <- list(list(name = "raw", kind = "table"))
  add(loop, task_def("source", "script", output = "raw", params = p))
  p <- default_loop_params("repeat"); p$values <- "2\n3"
  task <- task_def("repeat", "loop", params = p); task$outputs <- loop_output_specs(p)
  add(loop, task)
  task <- task_def("multiply", "script", inputs = "raw", output = "scaled",
    params = list(code = "scaled <- transform(raw, x = x * as.numeric(item))", input_tables = "raw",
      output_defs = list(list(name = "scaled", kind = "table"))))
  task$control_inputs <- p$output_token; add(loop, task)
  edge <- store()
  p <- default_script_params(".pipeline")
  p$code <- paste0('.pipeline <- data.frame(x = 1:12, check.names = FALSE)\n',
    '.pipeline[["log value Ω"]] <- c(NA, 3, 5, 4, 7, 8, 6, 10, 12, 9, 14, 13)\n',
    '.pipeline[["group label"]] <- factor(rep(c("A", "B"), 6))\n',
    'literal <- "first\n  second\nlast"\n.pipeline$literal <- literal')
  p$output_defs <- list(list(name = ".pipeline", kind = "table"))
  add(edge, task_def("source", "script", output = ".pipeline", params = p))
  p <- default_summary_stats_params("summary Ω"); p$input_table <- ".pipeline"; p$cols <- "log value Ω"
  add(edge, store_task_from_params(task_def("summary", "summary_stats"), p))
  p <- default_random_sample_params("sample Ω"); p$input_table <- ".pipeline"; p$method <- "prop"; p$prop <- 0.5; p$seed <- 41L
  add(edge, store_task_from_params(task_def("sample", "random_sample"), p))
  p <- default_phase3_params("linear_regression", "model Ω")
  p$input_table <- ".pipeline"; p$response <- "log value Ω"; p$predictors <- c("x", "group label")
  add(edge, store_task_from_params(task_def("fit", "linear_regression"), p))
  list(pipeline = pipeline, loop = loop, edge = edge, tasks = tasks)
}
