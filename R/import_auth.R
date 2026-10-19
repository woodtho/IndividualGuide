ig_import_needs_password <- function(p) {
  identical(p$source_kind %||% "file", "db") &&
    identical(p$db_conn_mode %||% "form", "form") &&
    !identical(p$db_driver %||% "odbc", "sqlite") && nzchar(p$db_uid %||% "")
}

ig_pending_task <- function(task_id) structure(list(task_id = task_id), class = "ig_pending_task")

# Resume the queue's post-run processing exactly once after a modal action.
store_resume_run_queue <- function(store, task_id) {
  if (!identical(isolate(store$run_waiting), task_id)) return(invisible(NULL))
  store$run_waiting <- NULL
  store$run_resumed <- task_id
  store$run_task_done_n <- isolate(store$run_task_done_n) + 1L
  invisible(NULL)
}

store_db_password <- function(store, task_id) {
  if (is.null(task_id)) return("")
  get0(task_id, envir = isolate(store$db_passwords), inherits = FALSE, ifnotfound = "")
}
