# Execution controls share the existing queue and worker lifecycle. Synchronous
# tasks finish their current call; the queue yields before starting the next.
store_stop_run <- function(store) {
  job <- isolate(store$background$job)
  running <- length(isolate(store$run_ids)) > 0L || !is.null(job)
  if (!running) return(invisible(FALSE))
  store$run_generation <- isolate(store$run_generation) + 1L
  store$run_queue <- character(0)
  store$run_ids <- character(0)
  store$run_waiting <- NULL
  store$run_resumed <- NULL
  store$run_current <- NULL
  ig_background_cancel(store, notify = FALSE)
  store$run_outcome <- "stopped"
  invisible(TRUE)
}

store_run_state <- function(store) {
  store$background_revision
  job <- store$background$job
  ids <- store$run_ids
  current <- store$run_current
  running <- length(ids) > 0L || !is.null(job)
  task_id <- if (!is.null(job)) job$task_id else current %||% ""
  task <- store_all_tasks(store)[[task_id]]
  started <- if (length(ids)) store$run_started else if (!is.null(job)) job$started else store$run_started
  list(running = running, task = task_id, label = task$label %||% task_id,
    total = if (length(ids)) store$run_total else if (!is.null(job)) 1L else store$run_total,
    completed = if (length(ids)) store$run_completed else if (!is.null(job)) 0L else store$run_completed,
    started = if (is.null(started)) NULL else as.numeric(started) * 1000,
    outcome = if (running) "running" else store$run_outcome,
    interruptible = !is.null(job))
}
