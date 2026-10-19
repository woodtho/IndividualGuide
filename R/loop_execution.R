#' Tables available as iteration sources, excluding this loop's prior results.
#' @keywords internal
#' @param store Session reactive store created by make_store().
#' @param task_id Task identifier; NULL when no stored task is being edited.
#' @param tables Named list of available in-memory or lazy database tables.
loop_source_tables <- function(store, task_id, tables) {
  tasks <- isolate(store$tasks)
  body <- store_task_descendants(tasks, task_id)
  excluded <- unlist(lapply(tasks[c(task_id, body)], task_output_names), use.names = FALSE)
  tables[setdiff(names(tables), excluded)]
}

#' Produce a collision-checkable name for one retained iteration output.
#' @keywords internal
#' @param p Configured task parameter list.
#' @param task_id Task identifier; NULL when no stored task is being edited.
#' @param output Primary output name.
#' @param record Typed iteration record containing its label, value and optional data.
#' @param index One-based iteration index.
#' @param extra Whether this is an additional output of the task.
#' @param prefix Parent loop prefix used to distinguish nested iteration outputs.
loop_result_name <- function(p, task_id, output, record, index, extra = FALSE, prefix = "") {
  label <- gsub("[^[:alnum:]_.-]", "_", record$label)
  rule <- p$naming_rule %||% "{task}_{item}"
  if (!nzchar(rule)) stop("Loop output naming rule is required.")
  has_output <- grepl("{output}", rule, fixed = TRUE)
  replacements <- list("{task}" = task_id, "{item}" = label,
    "{index}" = as.character(index), "{output}" = output)
  for (token in names(replacements)) rule <- gsub(token, replacements[[token]], rule, fixed = TRUE)
  if (extra && !has_output) rule <- paste0(rule, "_", output)
  paste0(prefix, rule)
}

#' Substitute iteration placeholders in existing scalar task settings.
#' @keywords internal
#' @param x Input value, column or nested configuration to transform.
#' @param record Typed iteration record containing its label, value and optional data.
#' @param index One-based iteration index.
#' @param field Configuration field being inspected or substituted.
loop_substitute_params <- function(x, record, index, field = "") {
  if (is.list(x)) {
    for (i in seq_along(x)) {
      key <- if (is.null(names(x))) field else names(x)[[i]]
      x[i] <- list(loop_substitute_params(x[[i]], record, index, key))
    }
  } else if (is.character(x) && !field %in% c("code", "expr", "custom_expr", "naming_rule")) {
    value <- if (is.atomic(record$value) && length(record$value) == 1L) as.character(record$value) else record$label
    x <- gsub("{item}", value, x, fixed = TRUE)
    x <- gsub("{index}", as.character(index), x, fixed = TRUE)
  }
  x
}

#' Execute a loop's dependent subgraph for each typed iteration record.
#' @param store The session store.
#' @param task_id The loop task identifier.
#' @param records Validated iteration records from execute_loop().
#' @return TRUE when all attempted iterations succeeded.
#' @keywords internal
store_run_loop <- function(store, task_id, records) {
  tasks <- isolate(store$tasks)
  loop <- tasks[[task_id]]
  p <- loop$params
  body_ids <- store_task_descendants(tasks, task_id)
  body_ids <- Filter(function(id) !identical(tasks[[id]]$type, "export_log") ||
    length(tasks[[id]]$control_inputs %||% character(0)) > 0L, body_ids)
  body_ids <- store_topo_order(tasks, isolate(store$task_order))[
    store_topo_order(tasks, isolate(store$task_order)) %in% body_ids]
  loop$loop_body_ids <- body_ids
  loop$loop_completed_iterations <- 0L
  loop$iteration_outputs <- list()
  store_set_task(store, loop)
  source_tables <- loop_source_tables(store, task_id, isolate(store$tables))
  original_tables <- isolate(store$tables)
  original_objects <- isolate(store$objects)
  parent_context <- isolate(store$execution_context) %||% list()
  prefix <- parent_context$.ig_loop_prefix %||% ""
  mappings <- lapply(seq_along(records), function(i) {
    mapping <- character(0)
    for (id in body_ids) {
      outs <- task_output_names(tasks[[id]])
      for (j in seq_along(outs)) {
        mapping[[outs[[j]]]] <- loop_result_name(p, id, outs[[j]], records[[i]], i, j > 1L, prefix)
      }
    }
    mapping
  })
  planned <- unlist(mappings, use.names = FALSE)
  if (anyDuplicated(planned)) {
    return(store_task_failed(store, task_id,
      "Loop output names collide. Include {index} or {output} in the output naming rule."))
  }
  reserved <- unique(c(names(source_tables), unlist(lapply(tasks[setdiff(names(tasks), c(task_id, body_ids))], task_output_names), use.names = FALSE)))
  if (length(intersect(planned, reserved)))
    return(store_task_failed(store, task_id, "Loop output names conflict with existing project data. Change the naming rule."))
  retained <- list()
  outcomes <- setNames(vector("list", length(body_ids)), body_ids)
  failures <- character(0)
  completed <- 0L
  for (i in seq_along(records)) {
    record <- records[[i]]
    work <- make_store()
    flow <- make_flow("Loop iteration")
    work$flows <- setNames(list(flow), flow$id)
    work$active_flow <- flow$id
    work$log_flow_id <- isolate(store$log_flow_id) %||% isolate(store$active_flow)
    work$settings <- isolate(store$settings)
    work$db_passwords <- isolate(store$db_passwords)
    work$tables <- original_tables
    work$objects <- original_objects
    all_tasks <- store_all_tasks(store)
    for (id in body_ids) {
      task <- store_remap_task(tasks[[id]], mappings[[i]])
      task$params <- loop_substitute_params(task$params, record, i)
      task$status <- "pending"
      task$run_time <- NULL
      task$error_msg <- NULL
      task$invalidated <- FALSE
      task$log_events <- list()
      all_tasks[[id]] <- task
    }
    all_tasks[[task_id]]$outputs <- loop_output_specs(p)
    work$tasks <- all_tasks
    work$task_order <- names(all_tasks)
    context <- parent_context
    context[[p$variable]] <- record$value
    context$.ig_loop_prefix <- paste0(prefix, task_id, "_", gsub("[^[:alnum:]_.-]", "_", record$label), "_")
    if (!is.null(record$data)) {
      context$.loop_data <- record$data
      if (nzchar(p$source %||% "")) {
        tables <- isolate(work$tables)
        tables[[p$source]] <- record$data
        work$tables <- tables
      }
    }
    work$execution_context <- context
    queue <- body_ids
    while (length(queue)) {
      id <- queue[[1]]
      queue <- queue[-1L]
      ok <- run_task_from_store(work, id)
      current <- isolate(work$tasks[[id]])
      if (identical(current$type, "branch") && isTRUE(ok)) {
        skipped <- store_apply_branch_decision(work, id)
        queue <- setdiff(queue, skipped)
      }
      if (identical(current$type, "loop")) queue <- setdiff(queue, current$loop_body_ids %||% character(0))
      if (!isTRUE(ok)) {
        failures <- c(failures, sprintf("Iteration %d (%s), %s: %s", i, record$label, id, current$error_msg %||% "failed"))
        if (isTRUE(isolate(store$settings)$stop_on_error)) break
      }
    }
    iteration_tasks <- isolate(work$tasks)
    logged_tasks <- isolate(store$tasks)
    for (id in body_ids) logged_tasks[[id]]$log_events <- utils::tail(c(
      logged_tasks[[id]]$log_events %||% list(), iteration_tasks[[id]]$log_events %||% list()), 1000L)
    store$tasks <- logged_tasks
    store$run_records <- utils::tail(c(isolate(store$run_records), isolate(work$run_records)), 200L)
    for (id in body_ids) {
      current <- iteration_tasks[[id]]
      outcomes[[id]] <- c(outcomes[[id]], list(list(iteration = i, label = record$label,
        status = current$status, error = current$error_msg)))
      if (!identical(current$status, "success")) next
      for (spec in task_output_specs(current)) {
        name <- spec$name
        if (identical(spec$kind, "report") && file.exists(spec$path %||% "")) {
          retained[[name]] <- spec
        } else if (name %in% names(isolate(work$tables))) {
          value <- isolate(work$tables)[[name]]
          if (inherits(value, "tbl_sql")) value <- as.data.frame(dplyr::collect(value))
          store_add_table(store, name, value)
          retained[[name]] <- spec
        } else if (name %in% names(isolate(work$objects))) {
          object <- isolate(work$objects)[[name]]
          store_add_object(store, name, object$value, object$meta)
          retained[[name]] <- spec
        }
      }
    }
    store_close_connections(work)
    completed <- i
    if (length(failures) && isTRUE(isolate(store$settings)$stop_on_error)) break
  }
  # Keep each template's last result under its established name for previews
  # and compatibility; retained iteration names are owned by the Loop node.
  main_tables <- isolate(store$tables)
  main_objects <- isolate(store$objects)
  if (completed > 0L) {
    last_mapping <- mappings[[completed]]
    for (original in names(last_mapping)) {
      name <- last_mapping[[original]]
      if (name %in% names(main_tables)) main_tables[[original]] <- main_tables[[name]]
      if (name %in% names(main_objects)) main_objects[[original]] <- main_objects[[name]]
    }
  }
  store$tables <- main_tables
  store$objects <- main_objects
  final_tasks <- isolate(store$tasks)
  finished_at <- Sys.time()
  for (id in body_ids) {
    logs <- outcomes[[id]]
    errors <- Filter(function(x) identical(x$status, "error"), logs)
    successful <- any(vapply(logs, function(x) identical(x$status, "success"), logical(1)))
    final_tasks[[id]]$status <- if (length(errors)) "error" else if (successful) "success" else "skipped"
    final_tasks[[id]]$error_msg <- if (length(errors)) errors[[1]]$error else NULL
    final_tasks[[id]]$run_time <- if (successful) finished_at else NULL
    final_tasks[[id]]$invalidated <- FALSE
    final_tasks[[id]]$execution_log <- c(final_tasks[[id]]$execution_log %||% list(), logs)
    last_task <- iteration_tasks[[id]]
    if (identical(last_task$status, "success") && identical(last_task$type, "report")) {
      reverse <- setNames(names(mappings[[completed]]), unname(mappings[[completed]]))
      final_tasks[[id]]$outputs <- lapply(last_task$outputs, function(spec) {
        spec$name <- reverse[[spec$name]] %||% spec$name
        spec
      })
    }
    if (identical(last_task$status, "success") && last_task$type %in% c("export", "export_log"))
      final_tasks[[id]]$export_file <- last_task$export_file
  }
  loop <- final_tasks[[task_id]]
  loop$outputs <- c(loop_output_specs(p), unname(retained))
  loop$iteration_outputs <- unname(retained)
  loop$loop_completed_iterations <- completed
  loop$loop_body_ids <- body_ids
  loop$run_time <- finished_at
  loop$status <- if (length(failures)) "error" else "success"
  loop$error_msg <- if (length(failures)) paste(failures, collapse = " | ") else NULL
  loop$invalidated <- FALSE
  final_tasks[[task_id]] <- loop
  store$tasks <- final_tasks
  for (id in c(body_ids, task_id)) {
    result <- if (identical(final_tasks[[id]]$status, "success")) store_cached_result(store, id) else
      if (!is.null(final_tasks[[id]]$error_msg)) list(error = final_tasks[[id]]$error_msg) else NULL
    store_update_preview(store, id, result)
  }
  store$dirty <- TRUE
  invisible(!length(failures))
}
