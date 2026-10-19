# Preview callbacks belong to live task modules, never to saved projects.
# A headless run updates an already-open panel without rerunning calculations.
store_register_result_fn <- function(store, task_id, fn, session = shiny::getDefaultReactiveDomain()) {
  if (is.null(task_id)) return(invisible(NULL))
  callbacks <- isolate(store$result_fns)
  callbacks[[task_id]] <- fn
  store$result_fns <- callbacks
  session$onEnded(function() {
    callbacks <- isolate(store$result_fns)
    if (identical(callbacks[[task_id]], fn)) {
      callbacks[[task_id]] <- NULL
      store$result_fns <- callbacks
    }
  })
  cached <- store_cached_result(store, task_id)
  if (!is.null(cached)) fn(cached)
  invisible(NULL)
}

store_update_preview <- function(store, task_id, result = NULL) {
  fn <- isolate(store$result_fns[[task_id]])
  if (is.function(fn)) fn(result)
  invisible(NULL)
}

ig_preview_status <- function(result) {
  if (is.null(result)) return("")
  if (!is.null(result$error)) return(paste("Error:", result$error))
  if (is.data.frame(result$data)) return(sprintf("\u2713 Complete: %d rows \u00d7 %d columns", nrow(result$data), ncol(result$data)))
  "\u2713 Complete"
}

ig_preview_data <- function(data, n = 1000L) {
  if (is.null(data)) return(NULL)
  data <- utils::head(data, n)
  if (inherits(data, "tbl_sql")) data <- dplyr::collect(data)
  data
}

store_cached_result <- function(store, task_id) {
  task <- store_all_tasks(store)[[task_id]]
  if (is.null(task) || !identical(task$status, "success") || isTRUE(task$invalidated)) return(NULL)
  tables <- isolate(store$tables)
  objects <- isolate(store$objects)
  value <- function(name) {
    if (name %in% names(tables)) tables[[name]] else objects[[name]]$value
  }
  out <- task$output %||% ""
  primary <- if (nzchar(out)) value(out) else NULL
  result <- list(data = if (is.data.frame(primary) || inherits(primary, "tbl_sql")) primary else NULL,
    error = NULL, specs = task$outputs %||% list())
  p <- task$params %||% list()
  if (task$type %in% PHASE3_TYPES) {
    result$objects <- list()
    for (def in phase3_return_defs(task$type)) if (def$key != "table") {
      name <- p$output_names[[def$key]] %||% ""
      if (nzchar(name)) result$objects[def$key] <- list(value(name))
    }
    result$plot <- result$objects$plot
  } else if (task$type == "script") {
    result$outputs <- list()
    for (spec in task_output_specs(task)) result$outputs[spec$name] <- list(list(kind = spec$kind, value = value(spec$name)))
    result$primary_output <- out
  } else if (task$type == "compare_data") {
    result$object <- primary
  } else if (task$type == "distribution") {
    source <- tables[[p$input_table %||% ""]]
    result$values <- if (is.data.frame(source)) source[[p$col %||% ""]] else NULL
  } else if (task$type == "table_analysis") {
    if (!is.null(result$data)) {
      counts <- as.matrix(result$data)
      result$display <- as.data.frame.matrix(switch(p$show_pct %||% "none",
        row = prop.table(counts, 1) * 100, col = prop.table(counts, 2) * 100,
        total = prop.table(counts) * 100, counts))
    }
    chi <- tables[[p$output_chi %||% ""]]
    if (is.data.frame(chi) && nrow(chi)) result$test <- list(statistic = chi$statistic,
      parameter = chi$df, p.value = chi$p_value, method = "Pearson's Chi-squared test")
  } else if (task$type == "report") {
    reports <- Filter(function(spec) identical(spec$kind, "report") && file.exists(spec$path %||% ""), task$outputs)
    if (length(reports)) result$report_path <- reports[[1]]$path
  } else if (task$type %in% c("export", "export_log")) {
    result$file <- task$export_file
    if (!is.null(result$file) && file.exists(result$file)) result$info <- list(file = result$file, size = file.info(result$file)$size, format = p$format)
  } else if (task$type == "branch") {
    result <- task$branch_decision %||% result
  }
  result
}
