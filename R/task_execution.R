# The interactive executor and isolated workers share exactly one dispatch.
ig_execute_task <- function(type, p, tables, objects = list(), context = list(),
                            tasks = list(), task_id = NULL, pwd = NULL, output_dir = NULL) {
  if (type %in% PHASE3_TYPES) return(execute_phase3_task(type, p, tables))
  switch(type,
    import_data = execute_import(p, pwd = pwd),
    query_builder = execute_query(p, tables, context = context),
    append_table = execute_append(p, tables), compare_data = execute_compare(p, tables),
    filter_sort = execute_fs(p, tables), stack_columns = execute_stack(p, tables),
    split_columns = execute_split(p, tables), transpose = execute_transpose(p, tables),
    rank = execute_rank(p, tables), standardize = execute_std(p, tables),
    random_sample = execute_sample(p, tables), remove_dups = execute_remove_dups(p, tables),
    keep_drop_cols = execute_keep_drop(p, tables), rename_cols = execute_rename_cols(p, tables),
    first_last_n = execute_first_last(p, tables), replace_missing = execute_replace_missing(p, tables),
    derive_cols = execute_derive_cols(p, tables, context = context),
    recode_values = execute_recode_values(p, tables), change_types = execute_change_types(p, tables),
    characterize = execute_characterize(p, tables), list_data = execute_list_data(p, tables),
    one_way_freq = execute_one_way_freq(p, tables), summary_stats = execute_summary_stats(p, tables),
    table_analysis = execute_table_analysis(p, tables), summary_tables = execute_summary_table(p, tables),
    distribution = execute_distribution(p, tables),
    script = execute_script(p, c(tables, objects), context = context),
    branch = execute_branch(p, tables, c(objects, context), tasks, task_id),
    loop = execute_loop(p, tables, objects),
    report = execute_report(p, tables, objects, output_dir = output_dir,
      log_records = if (isTRUE(p$include_log)) ig_log_records(tasks,
        setdiff(names(tasks), task_id), p$log_min_level %||% "INFO") else NULL),
    export = execute_export(p, tables, objects), export_log = execute_export_log(p, tasks, task_id),
    stop("Unknown task type '", type, "'."))
}

ig_transferable <- function(value) {
  if (inherits(value, c("tbl_sql", "DBIConnection", "connection")) ||
      typeof(value) %in% c("externalptr", "weakref", "environment")) return(FALSE)
  if (is.list(value)) return(all(vapply(value, ig_transferable, logical(1))))
  if (isS4(value)) return(all(vapply(methods::slotNames(value), function(slot) ig_transferable(methods::slot(value, slot)), logical(1))))
  TRUE
}

ig_task_configuration <- function(tasks) {
  lapply(tasks, function(task) task[c("type", "params", "inputs", "output", "control_inputs")])
}

ig_worker_loop <- function(request) {
  store <- make_store()
  store$tables <- request$tables; store$objects <- request$object_records
  store$sources <- request$sources; store$settings <- request$settings
  store$flows <- request$flows; store$active_flow <- request$flow_id
  store$tasks <- request$tasks; store$task_order <- request$order
  store$branch_tokens <- request$branch_tokens; store$execution_context <- request$context
  ok <- run_task_from_store_impl(store, request$task_id)
  store_snapshot_flow(store)
  values <- isolate(list(tables = store$tables, objects = store$objects, sources = store$sources,
    flows = store$flows, records = store$run_records, branch_tokens = store$branch_tokens))
  if (!ig_transferable(values$tables) || !ig_transferable(lapply(values$objects, `[[`, "value")))
    return(list(error = "The loop produced process-local connections or environments. Return materialized data or disable background tasks for this workflow."))
  list(error = if (!isTRUE(ok)) isolate(store$tasks[[request$task_id]])$error_msg %||% "Loop failed." else NULL,
    loop_store = values)
}

ig_apply_loop_snapshot <- function(store, job, snapshot) {
  flows <- isolate(store$flows); active <- isolate(store$active_flow)
  for (id in intersect(names(flows), names(snapshot$flows))) {
    flows[[id]]$tasks <- snapshot$flows[[id]]$tasks
    flows[[id]]$task_order <- snapshot$flows[[id]]$task_order
  }
  store$tables <- snapshot$tables; store$objects <- snapshot$objects; store$sources <- snapshot$sources
  store$flows <- flows; store$tasks <- flows[[active]]$tasks; store$task_order <- flows[[active]]$task_order
  store$branch_tokens <- snapshot$branch_tokens
  store$run_records <- utils::tail(c(isolate(store$run_records), snapshot$records), 200L)
  store$dirty <- TRUE
  for (id in names(isolate(store$tasks))) store_update_preview(store, id, store_cached_result(store, id))
  invisible(TRUE)
}
