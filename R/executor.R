# executor.R — Centralized task runner for the Run Flow button
#
# run_task_from_store(store, task_id)
#   Reads params from store$tasks[[task_id]], calls the appropriate
#   execute_* function from execute_fns.R (which don't require an open panel),
#   writes the result back to store$tables, and updates the task record.
#
# Returns: TRUE (success) or FALSE (error/skipped); side-effects on store.

run_task_from_store <- function(store, task_id) {
  if (ig_background_eligible(store, task_id)) return(ig_background_start(store, task_id))
  ig_task_logged(store, task_id, function() run_task_from_store_impl(store, task_id))
}

run_task_from_store_impl <- function(store, task_id, precomputed = NULL) {
  if (store_review_blocked(store, "run tasks")) return(invisible(FALSE))
  task <- isolate(store$tasks[[task_id]])
  if (is.null(task)) {
    ig_notify(sprintf("Task '%s' not found in store.", task_id),
              type = "warning", duration = 5)
    return(invisible(FALSE))
  }
  problem <- store_upstream_problem(store, task_id)
  if (isTRUE(attr(problem, "skip"))) return(store_task_skipped(store, task_id, problem))
  if (!is.null(problem)) return(store_task_failed(store, task_id, problem))

  p      <- task$params %||% list()
  type   <- task$type   %||% ""
  tables <- isolate(store$tables)
  objects <- lapply(isolate(store$objects), `[[`, "value")
  tasks_snapshot <- isolate(store$tasks)
  if (identical(type, "loop")) tables <- loop_source_tables(store, task_id, tables)

  # Materialise lazy tbl_sql objects for all task types that assume in-memory
  # data frames.  QB and Script intentionally receive the raw tbl_sql:
  #   • QB: dplyr verbs translate to SQL (pushdown), collected at end of execute_query
  #   • Script: power users can call dplyr verbs or collect() themselves
  if (!type %in% c("query_builder", "script")) {
    needed <- unique(c(task$inputs %||% character(0), p$pred_table %||% character(0)))
    tables <- setNames(lapply(names(tables), function(name) {
      x <- tables[[name]]
      if (!name %in% needed && !identical(type, "branch")) return(x)
      if (!inherits(x, "tbl_sql")) return(x)
      tryCatch(
        as.data.frame(dplyr::collect(x)),
        error = function(e) {
          warning("Run Flow: could not collect lazy tbl for task '", task_id,
                  "': ", e$message)
          NULL
        }
      )
    }), names(tables))
  }

  # Mark task as running so canvas shows the correct state
  task$status <- "running"
  task$error_msg <- NULL
  store_set_task(store, task)

  # Dispatch ─────────────────────────────────────────────────────────────────
  result <- if (!is.null(precomputed)) precomputed else tryCatch(
    ig_execute_task(type, p, tables, objects, context = isolate(store$execution_context),
      tasks = tasks_snapshot, task_id = task_id, pwd = store_db_password(store, task_id)),
    error = function(e) list(data = NULL, error = conditionMessage(e)))

  if (!identical(type, "script")) ig_log_result(result)
  if (!is.null(result$error)) {
    ig_notify(
      sprintf("Task '%s' (%s): %s", task_id, type, result$error),
      type = "error", duration = 8)
    # Mark error in task record
    return(store_task_failed(store, task_id, result$error))
  }
  if (length(result$warnings %||% character(0))) {
    ig_notify(
      sprintf("Task '%s' warnings: %s", task_id, paste(result$warnings, collapse = " | ")),
      type = "warning", duration = 8)
  }
  if (identical(type, "import_data"))
    store_register_connection(store, task_id, result$con)

  # Persist output table ─────────────────────────────────────────────────────
  out_name     <- p$output_name %||% task$output %||% ""
  # Describe tasks expose a Save toggle; respect it when running headless too.
  save_enabled <- !identical(p$output_enabled, FALSE)
  if (type %in% PHASE3_TYPES) {
    store_phase3_outputs(store, p, result)
    task$outputs <- phase3_output_specs(p, result)
  } else if (identical(type, "branch")) {
    task$output <- ""
    task$outputs <- branch_output_specs(p)
    task$inputs <- p$dependencies %||% character(0)
    task$branch_decision <- result
  } else if (identical(type, "loop")) {
    task$output <- ""
    task$outputs <- loop_output_specs(p)
    task$inputs <- if (nzchar(p$source %||% "")) p$source else character(0)
    task$loop_iterations <- result$iterations
  } else if (identical(type, "script")) {
    store_script_outputs(store, p, result)
    task$outputs <- script_result_specs(p, result)
    task$output <- result$primary_output %||% ""
  } else if (identical(type, "report") && !is.null(result$report_path)) {
    # Report tasks produce a file, not a table — store path in task outputs only
    task$output  <- out_name
    task$outputs <- list(list(
      name  = out_name,
      kind  = "report",
      label = "Rendered report",
      path  = result$report_path
    ))
  } else if (type %in% c("export", "export_log")) {
    # Export is a SINK: writes a file, produces no flow output.
    task$output      <- ""
    task$outputs     <- list()
    task$export_file <- result$file
    task$inputs      <- if (nzchar(p$source %||% "")) p$source else character(0)
  } else if (!is.null(result$object) && nzchar(out_name)) {
    # Object-producing tasks (e.g. compare_data → waldo comparison)
    store_add_object(store, out_name, result$object,
      meta = list(kind = result$object_kind %||% "object", task_type = type))
    task$output  <- out_name
    task$outputs <- list(list(name = out_name,
      kind = result$object_kind %||% "object", label = "Output object"))
  } else if (nzchar(out_name) && !is.null(result$data) && save_enabled) {
    store_add_table(store, out_name, result$data,
      source_meta = if (identical(type, "import_data")) import_source_meta(p, task_id, result$data) else NULL)
    task$output <- out_name
    task$outputs <- list(list(name = out_name, kind = "table", label = "Output table"))
  }
  if (identical(type, "table_analysis") && isTRUE(p$output_chi_enabled) &&
      nzchar(p$output_chi %||% "") && !is.null(result$chi_table)) {
    store_add_table(store, p$output_chi, result$chi_table)
    task$outputs <- c(if (save_enabled) task$outputs else list(),
      list(list(name = p$output_chi, kind = "table", label = "Chi-square test")))
    if (!save_enabled) task$output <- ""
  }
  if (!save_enabled && !type %in% c(PHASE3_TYPES, "script", "report", "export")) {
    task$output <- ""
    if (!(identical(type, "table_analysis") && !is.null(result$chi_table) && isTRUE(p$output_chi_enabled)))
      task$outputs <- list()
  }

  # Update task record ────────────────────────────────────────────────────────
  task$run_time  <- Sys.time()
  task$error_msg <- NULL
  task$status    <- "success"
  if (type %in% PHASE3_TYPES)
    task$r_code <- build_phase3_code(type, p)
  if (identical(type, "branch"))
    task$r_code <- build_branch_code(p)
  if (identical(type, "loop"))
    task$r_code <- build_loop_code(p)
  if (identical(type, "export"))
    task$r_code <- build_export_code(p)
  task$r_code <- tryCatch(build_task_code(task), error = function(e)
    paste0("stop(", r_val(paste("Code generation:", conditionMessage(e)), "character"), ")"))
  if (!identical(type, "script") && !identical(type, "report") &&
      !identical(type, "export") && nzchar(out_name) && save_enabled)
    task$output <- out_name
  task$execution_log <- c(task$execution_log %||% list(), list(list(
    time = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    event = if (identical(type, "branch")) "branch" else if (identical(type, "loop")) "loop" else "run",
    status = "success",
    matched = if (identical(type, "branch")) result$matched_tokens else NULL,
    skipped = if (identical(type, "branch")) result$skipped_tokens else NULL,
    iterations = if (identical(type, "loop")) result$iterations else NULL
  )))
  store_set_task(store, task)
  store_update_preview(store, task_id, result)
  if (identical(type, "loop")) return(store_run_loop(store, task_id, result$records))
  invisible(TRUE)
}
