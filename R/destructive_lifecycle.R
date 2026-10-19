# Preserve outputs used by surviving tasks before retiring their producer.
# Lazy snapshots must be materialized while the producer still owns a live
# connection. Stage every collection before changing project state.
store_detach_task_outputs <- function(store, ids) {
  tasks <- store_all_tasks(store)
  deleting <- tasks[intersect(ids, names(tasks))]
  surviving <- tasks[setdiff(names(tasks), ids)]
  referenced <- unique(unlist(lapply(surviving, function(task) task$inputs), use.names = FALSE))
  outputs <- unique(unlist(lapply(deleting, task_output_names), use.names = FALSE))
  keep <- intersect(outputs, referenced)
  tables <- isolate(store$tables)
  for (name in intersect(keep, names(tables))) if (inherits(tables[[name]], "tbl_sql"))
    tables[[name]] <- as.data.frame(dplyr::collect(tables[[name]]))
  store$tables <- tables
  sources <- isolate(store$sources)
  for (name in keep) if (!is.null(sources[[name]])) sources[[name]]$task_id <- NULL
  store$sources <- sources
  for (name in setdiff(outputs, keep)) store_remove_output(store, name)
  invisible(keep)
}

# Undo snapshots may contain a lazy table whose deleted import was disconnected.
# Retain other saved results, require reconnection, and retire unused connections.
store_restore_valid_tables <- function(store) {
  tables <- isolate(store$tables)
  used <- list()
  for (name in names(tables)) if (inherits(tables[[name]], "tbl_sql")) {
    con <- tryCatch(dbplyr::remote_con(tables[[name]]), error = function(e) NULL)
    valid <- tryCatch(!is.null(con) && DBI::dbIsValid(con), error = function(e) FALSE)
    if (!valid) tables[[name]] <- NULL else used[[name]] <- con
  }
  store$tables <- tables
  connections <- isolate(store$db_connections)
  unused <- names(Filter(function(con) !any(vapply(used, identical, logical(1), y = con)), connections))
  store_close_connections(store, unused)
  store_snapshot_flow(store)
  project_normalize_restored_tasks(store)
  flow <- isolate(store$flows[[store$active_flow]])
  store$tasks <- flow$tasks
  invisible(NULL)
}
