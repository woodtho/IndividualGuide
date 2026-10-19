# An adapter presents one job to the scheduler while reusing its session's R
# worker between jobs. Cancellation retires the entire owned worker process.
ig_reusable_task_process <- function(job) {
  state <- job$state
  if (is.null(state$worker) || !state$worker$is_alive()) state$worker <- callr::r_session$new(
    options = callr::r_session_options(libpath = .libPaths(), system_profile = FALSE,
      user_profile = FALSE, supervise = TRUE), wait = FALSE)
  worker <- state$worker
  request <- list(type = job$type, task_id = job$task_id, params = job$params,
    tables = job$tables, objects = job$objects, object_records = job$object_records,
    tasks = job$tasks, flows = job$flows, order = job$order, flow_id = job$flow_id,
    sources = job$sources, settings = job$settings, branch_tokens = job$branch_tokens,
    context = job$context, register = job$register, logging = job$logging, meta = job$meta,
    started = job$started, log_spec = job$log_spec, options = job$options,
    seed = job$settings$run_seed, rng_kind = job$rng_kind, artifacts = job$artifacts)
  app_path <- getNamespaceInfo(asNamespace("IndividualGuide"), "path")
  source <- !file.exists(file.path(app_path, "R", "IndividualGuide.rdb"))
  fn <- ig_background_worker; environment(fn) <- baseenv()
  adapter <- new.env(parent = emptyenv())
  adapter$sent <- FALSE; adapter$value <- NULL; adapter$error <- NULL
  adapter$is_alive <- function() {
    if (!is.null(adapter$value) || !is.null(adapter$error)) return(FALSE)
    tryCatch({
      if (!worker$is_alive()) stop("The task worker stopped. Run again to start a new worker.")
      if (!adapter$sent && as.numeric(difftime(Sys.time(), job$started, units = "secs")) > 60)
        stop("The task worker took too long to start.")
      for (i in seq_len(20L)) {
        if (!identical(unname(worker$poll_process(0)), "ready")) break
        message <- worker$read()
        if (is.null(message)) break
        if (identical(message$code, 200L)) adapter$value <- message$result
        if (message$code >= 500L) stop(message$error %||% "Task worker failed.")
      }
      if (!adapter$sent && identical(worker$get_state(), "idle")) {
        worker$call(fn, args = list(request = request, app_path = app_path, source = source))
        adapter$sent <- TRUE
      }
      is.null(adapter$value)
    }, error = function(error) { adapter$error <- error; FALSE })
  }
  adapter$get_result <- function() {
    if (!is.null(adapter$error)) stop(adapter$error)
    adapter$value
  }
  adapter$kill <- function() {
    try(worker$kill(), silent = TRUE)
    if (identical(state$worker, worker)) state$worker <- NULL
    invisible(TRUE)
  }
  adapter$wait <- function(timeout = -1) {
    deadline <- if (timeout < 0) Inf else as.numeric(Sys.time()) + timeout / 1000
    while (adapter$is_alive() && as.numeric(Sys.time()) < deadline) Sys.sleep(.05)
    invisible(adapter)
  }
  adapter$get_pid <- function() worker$get_pid()
  adapter
}
