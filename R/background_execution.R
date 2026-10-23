# Transferable tasks run outside Shiny's shared R thread in a reusable worker.
# Requests/results belong to one session; scheduling slots are process-wide.
# Live database handles retain their explicit synchronous compatibility path.
.ig_background <- local({
  state <- new.env(parent = emptyenv())
  state$active <- list(); state$queue <- list(); state$next_id <- 0L
  state$scheduled <- FALSE; state$polling <- FALSE
  state
})

ig_background_limit <- function() {
  limit <- suppressWarnings(as.integer(getOption("ig.background_workers", 2L)))
  if (length(limit) != 1L || is.na(limit) || limit < 0L) 2L else limit
}

ig_background_retire_worker <- function(store) {
  state <- isolate(store$background)
  if (!is.null(state) && !is.null(state$worker)) {
    try(state$worker$kill(), silent = TRUE)
    state$worker <- NULL
  }
  invisible(NULL)
}

store_init_background <- function(store, session) {
  state <- new.env(parent = emptyenv())
  state$session <- session; state$closed <- FALSE; state$job <- NULL; state$worker <- NULL; state$artifacts <- character()
  store$background <- state
  session$onEnded(function() {
    state$closed <- TRUE
    ig_background_cancel(store, notify = FALSE, change_status = FALSE)
    if (!is.null(state$worker)) try(state$worker$kill(), silent = TRUE)
    state$worker <- NULL
    root <- paste0(normalizePath(tempdir(), winslash = "/", mustWork = TRUE), "/")
    for (path in state$artifacts) {
      resolved <- normalizePath(path, winslash = "/", mustWork = FALSE)
      if (startsWith(resolved, root) && startsWith(basename(resolved), "ig_task_results_")) unlink(resolved, recursive = TRUE)
    }
  })
  invisible(state)
}

ig_background_tables <- function(store, p, track = FALSE, task_id = NULL) {
  names <- unique(c(p[["input_table"]] %||% "", p[["pred_table"]] %||% ""))
  names <- names[nzchar(names)]
  tables <- if (track) store$tables else isolate(store$tables)
  task <- if (!is.null(task_id)) store_all_tasks(store, track = track)[[task_id]] else NULL
  if (!is.null(task)) {
    if (task$type %in% c("script", "loop")) return(tables)
    names <- unique(c(names, task$inputs %||% character(), p$input_tables %||% character()))
    names <- intersect(names, names(tables))
  }
  tables[names]
}

ig_background_options <- function(store = NULL) {
  keys <- c("contrasts", "na.action", "digits", "scipen", "OutDec", "matprod", "warn", "width", "max.print")
  settings <- stats::setNames(lapply(keys, getOption), keys)
  managed <- ig_options_r_values(store)
  inherited <- settings[setdiff(names(settings), names(managed))]
  if (any(vapply(inherited, function(x) !is.null(x) && !is.atomic(x), logical(1)))) return(NULL)
  # User-defined contrast/missing-value functions and nonlinear expressions
  # can depend on the parent process's global environment.
  if (!"contrasts" %in% names(managed) && length(settings$contrasts) && any(!settings$contrasts %in%
      c("contr.treatment", "contr.SAS", "contr.sum", "contr.helmert", "contr.poly"))) return(NULL)
  if (!"na.action" %in% names(managed) && length(settings$na.action) && !settings$na.action %in% c("na.omit", "na.exclude", "na.fail", "na.pass")) return(NULL)
  settings <- ig_options_merge(settings, managed)
  if (!ig_transferable(settings)) return(NULL)
  settings
}

ig_background_eligible <- function(store, task_id, params = NULL, register = TRUE) {
  state <- isolate(store$background)
  if (is.null(state) || isTRUE(state$closed) || ig_background_limit() == 0L || is.null(task_id) ||
      isFALSE(isolate(store$settings)$background_tasks) || length(isolate(store$execution_context))) return(FALSE)
  task <- store_all_tasks(store)[[task_id]]
  if (is.null(task) || !task$type %in% IG_ENABLED_TASK_IDS || task$type == "branch") return(FALSE)
  if (register && (isTRUE(isolate(store$review_mode)) || !is.null(store_upstream_problem(store, task_id)))) return(FALSE)
  reader <- isolate(store$params_fns[[task_id]])
  p <- if (!is.null(params)) params else if (is.function(reader))
    tryCatch(isolate(reader()), error = function(error) NULL) else task$params
  if (is.null(p) || is.null(ig_background_options(store))) return(FALSE)
  input <- p[["input_table"]] %||% ""
  if (length(input) > 1L || anyNA(input)) return(FALSE)
  if (length(input) && nzchar(input) && !input %in% names(isolate(store$tables))) return(FALSE)
  if (task$type == "import_data" && !identical(p$source_kind %||% "file", "file")) return(FALSE)
  tables <- ig_background_tables(store, p, task_id = task_id)
  if (!ig_transferable(tables) || !ig_transferable(p)) return(FALSE)
  if (task$type %in% c("script", "report", "export", "loop") &&
      !ig_transferable(lapply(isolate(store$objects), `[[`, "value"))) return(FALSE)
  if (task$type == "loop") {
    tasks <- store_all_tasks(store)
    if (any(vapply(tasks, function(t) t$type == "import_data" &&
        !identical(t$params$source_kind %||% "file", "file"), logical(1)))) return(FALSE)
  }
  TRUE
}

ig_background_current <- function(store, job, track = FALSE) {
  review <- if (track) store$review_mode else isolate(store$review_mode)
  if (isTRUE(job$register) && isTRUE(review)) return(FALSE)
  task <- store_all_tasks(store, track = track)[[job$task_id]]
  if (is.null(task) || !store_equivalent_parameters(job$task, task)) return(FALSE)
  if (isTRUE(job$register) && !identical(task$status, "running")) return(FALSE)
  if (!identical(ig_background_tables(store, job$params, track, job$task_id), job$tables)) return(FALSE)
  objects <- if (track) store$objects else isolate(store$objects)
  if (job$type %in% c("script", "report", "export", "loop") && !identical(objects, job$object_records)) return(FALSE)
  if (job$type == "loop" && !identical(ig_task_configuration(store_all_tasks(store, track)), job$loop_config)) return(FALSE)
  TRUE
}

# This function's environment is changed to baseenv() before serialization, so
# a development namespace need not be installed to deserialize the request.
ig_background_worker <- function(request, app_path, source) {
  configured <- c(request$options, list(IndividualGuide.report_root = request$artifacts))
  old_options <- stats::setNames(lapply(names(configured), getOption), names(configured))
  on.exit(options(old_options), add = TRUE)
  options(configured)
  if (source && !"IndividualGuide" %in% loadedNamespaces()) pkgload::load_all(app_path, export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
  else loadNamespace("IndividualGuide")
  for (table in request$tables) {
    if (inherits(table, "tbl_df")) loadNamespace("tibble")
    if (any(vapply(table, function(column) inherits(column, "haven_labelled"), logical(1)))) loadNamespace("haven")
  }
  ns <- asNamespace("IndividualGuide")
  old_seed <- if (exists(".Random.seed", globalenv(), inherits = FALSE)) get(".Random.seed", globalenv()) else NULL
  if (length(request$rng_kind)) suppressWarnings(do.call(RNGkind, as.list(request$rng_kind)))
  if (!is.null(request$seed)) {
    set.seed(request$seed)
    on.exit(if (is.null(old_seed)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old_seed, globalenv()), add = TRUE)
  } else if (is.null(old_seed)) set.seed(NULL)
  rng_state <- get(".Random.seed", globalenv())
  input_fingerprints <- get("ig_run_inputs", ns)(request$tasks[[request$task_id]], request$tables, request$objects)
  execute <- get("ig_execute_task", ns)
  events <- list()
  value <- NULL
  calculate <- function() {
    value <<- if (request$type == "loop") get("ig_worker_loop", ns)(request) else
      tryCatch(execute(request$type, request$params, request$tables, request$objects,
        context = request$context, tasks = request$tasks, task_id = request$task_id,
        output_dir = file.path(request$artifacts, "report")), error = function(error) list(error = conditionMessage(error)))
    if (!get("ig_transferable", ns)(value)) value <<- list(error = "The task returned process-local connections or environments. Return materialized data or disable background tasks for this workflow.")
    if (request$type != "script") get("ig_log_result", ns)(value)
    value
  }
  result <- if (request$register) get("ig_capture_task_log", ns)(calculate, request$logging,
    request$meta, emit = function(value) events <<- value,
    context = function() get("ig_log_context", ns)(if (is.null(request$log_spec)) list() else request$log_spec, request$tables, result = value),
    outcome = function(value) list(status = if (is.null(value$error)) "success" else "error", message = value$error),
    started = request$started) else calculate()
  list(result = result, events = events, rng_state = rng_state, rng_kind = RNGkind(), inputs = input_fingerprints,
    environment = get("ig_environment_info", ns)())
}

ig_background_process <- function(job) {
  ig_reusable_task_process(job)
}

ig_background_schedule <- function() {
  if (isTRUE(.ig_background$scheduled)) return(invisible(NULL))
  .ig_background$scheduled <- TRUE
  later::later(ig_background_poll, delay = 0.05)
  invisible(NULL)
}

ig_background_release <- function(job, kill = FALSE) {
  if (!is.null(job$observer)) job$observer$destroy()
  if (is.function(job$module_cleanup)) job$module_cleanup()
  if (kill && !is.null(job$process)) try(job$process$kill(), silent = TRUE)
  .ig_background$active[[job$id]] <- NULL
  .ig_background$queue[[job$id]] <- NULL
  if (identical(job$state$job, job)) job$state$job <- NULL
  job$store$background_revision <- isolate(job$store$background_revision) + 1L
  unlink(c(job$stdout, job$stderr))
  invisible(NULL)
}

ig_background_resume <- function(store, task_id) {
  if (identical(isolate(store$run_waiting), task_id)) {
    store$run_waiting <- NULL
    store$run_resumed <- task_id
    store$run_task_done_n <- isolate(store$run_task_done_n) + 1L
  }
}

ig_background_cancel <- function(store, task_id = NULL, notify = TRUE, change_status = TRUE) {
  state <- isolate(store$background)
  job <- if (!is.null(state)) state$job else NULL
  if (is.null(job) || (!is.null(task_id) && !identical(task_id, job$task_id))) return(invisible(FALSE))
  ig_background_release(job, kill = TRUE)
  if (!isTRUE(state$closed)) {
    task <- store_all_tasks(store)[[job$task_id]]
    if (change_status && isTRUE(job$register) && !is.null(task) && identical(task$status, "running"))
      store_invalidate_outputs(store, character(0), include = job$task_id)
    if (isTRUE(job$register)) ig_run_finish(store, job$record, status = "stopped")
    ig_background_resume(store, job$task_id)
    if (!length(isolate(store$run_ids))) store$run_outcome <- "stopped"
    if (notify) ig_notify("Analysis canceled because its task or inputs changed. Run it again when ready.", type = "message")
  }
  ig_background_schedule()
  invisible(TRUE)
}

# Commit through the existing executor, even if the user has moved to another
# flow. The live window is restored before Shiny can render, including any
# cross-flow invalidations caused by the completed task's new outputs.
ig_background_apply <- function(store, job, result) {
  if (!is.null(result$loop_store)) return(ig_apply_loop_snapshot(store, job, result$loop_store))
  active <- isolate(store$active_flow)
  if (!identical(active, job$flow_id)) {
    store_snapshot_flow(store)
    flow <- isolate(store$flows[[job$flow_id]])
    if (is.null(flow)) return(invisible(FALSE))
    store$active_flow <- job$flow_id; store$tasks <- flow$tasks; store$task_order <- flow$task_order
    on.exit({
      store_snapshot_flow(store)
      original <- isolate(store$flows[[active]])
      store$active_flow <- active; store$tasks <- original$tasks; store$task_order <- original$task_order
    }, add = TRUE)
  }
  result$background_run <- TRUE
  run_task_from_store_impl(store, job$task_id, precomputed = result)
}

ig_background_finish <- function(job, value) {
  store <- job$store
  if (!is.list(value) || !is.list(value$result))
    value <- list(result = list(error = "Background analysis returned an invalid result."), events = list())
  # Read any last browser edits before accepting a result. No task, project or
  # input version can be replaced by a result computed against an older state.
  isolate(store_sync_parameters(store, job$task_id))
  valid <- identical(job$state$job, job) && !isTRUE(job$state$closed) && ig_background_current(store, job)
  if (!valid) {
    if (identical(job$state$job, job)) ig_background_cancel(store, job$task_id)
    else ig_background_release(job)
    return(invisible(NULL))
  }
  value$result <- ig_restore_object_namespaces(value$result)
  ig_background_release(job)
  old <- options(IndividualGuide.log_callback = NULL)
  on.exit(options(old), add = TRUE)
  if (job$register) {
    if (!length(value$events) && !is.null(value$result$error)) {
      ig_capture_task_log(function() value$result, job$logging, job$meta,
        emit = function(events) value$events <<- events,
        context = function() ig_log_context(job$log_spec %||% list(), job$tables, result = value$result),
        outcome = function(result) list(status = "error", message = result$error), started = job$started)
    }
    if (length(value$events)) {
      tasks <- isolate(store$tasks)
      # For inactive flows, append logs after their executor window is opened.
      if (job$task_id %in% names(tasks)) {
        tasks[[job$task_id]]$log_events <- utils::tail(c(tasks[[job$task_id]]$log_events, value$events), 1000L)
        store$tasks <- tasks
      } else {
        flows <- isolate(store$flows)
        flows[[job$flow_id]]$tasks[[job$task_id]]$log_events <- utils::tail(c(
          flows[[job$flow_id]]$tasks[[job$task_id]]$log_events, value$events), 1000L)
        store$flows <- flows
      }
    }
    if (!is.null(value$result$loop_store) && length(value$events)) {
      loop_task <- value$result$loop_store$flows[[job$flow_id]]$tasks[[job$task_id]]
      loop_task$log_events <- utils::tail(c(loop_task$log_events, value$events), 1000L)
      value$result$loop_store$flows[[job$flow_id]]$tasks[[job$task_id]] <- loop_task
    }
    ig_background_apply(store, job, value$result)
    job$record$inputs <- value$inputs %||% job$record$inputs
    job$record$environment <- value$environment %||% job$record$environment
    job$record$rng_state <- value$rng_state %||% job$record$rng_state
    job$record$rng_kind <- value$rng_kind %||% job$record$rng_kind
    ig_run_finish(store, job$record)
  } else job$complete(value$result)
  if (!length(isolate(store$run_ids))) {
    store$run_completed <- 1L
    store$run_outcome <- if (!is.null(value$result$error)) "failed" else "finished"
  }
  ig_background_resume(store, job$task_id)
  invisible(NULL)
}

ig_background_deliver <- function(job, value) {
  shiny::withReactiveDomain(job$state$session, {
    tryCatch(ig_background_finish(job, value), error = function(error) {
      ig_background_release(job)
      if (!isTRUE(job$state$closed)) {
        try(ig_background_apply(job$store, job, list(error = conditionMessage(error))), silent = TRUE)
        ig_background_resume(job$store, job$task_id)
      }
    })
  })
}

ig_background_poll <- function() {
  .ig_background$scheduled <- FALSE
  if (isTRUE(.ig_background$polling)) return(invisible(NULL))
  .ig_background$polling <- TRUE
  on.exit(.ig_background$polling <- FALSE, add = TRUE)
  for (job in .ig_background$active) {
    if (job$process$is_alive()) next
    value <- tryCatch(job$process$get_result(), error = function(error)
      list(result = list(error = paste("Background analysis failed:", conditionMessage(error))), events = list()))
    ig_background_deliver(job, value)
  }
  while (length(.ig_background$queue) && length(.ig_background$active) < max(1L, ig_background_limit())) {
    id <- names(.ig_background$queue)[[1L]]
    job <- .ig_background$queue[[id]]; .ig_background$queue[[id]] <- NULL
    if (isTRUE(job$state$closed)) { ig_background_release(job); next }
    process <- tryCatch(ig_background_process(job), error = identity)
    if (inherits(process, "error")) {
      ig_background_deliver(job, list(result = list(error = conditionMessage(process)), events = list()))
    } else {
      job$process <- process; .ig_background$active[[id]] <- job
    }
  }
  if (length(.ig_background$active) || length(.ig_background$queue)) ig_background_schedule()
  invisible(NULL)
}

ig_background_start <- function(store, task_id, params = NULL, register = TRUE,
                                complete = NULL, module_session = NULL) {
  state <- isolate(store$background)
  if (!is.null(state$job)) {
    ig_notify("A task is already running in this session. Wait for it to finish before starting another.", type = "message")
    return(invisible(FALSE))
  }
  isolate(store_sync_parameters(store, task_id))
  task <- store_all_tasks(store)[[task_id]]
  p <- params %||% task$params
  record <- if (register) ig_run_begin(store, task_id, task, fingerprint = FALSE) else NULL
  if (!is.null(record)) record$rng_state <- NULL
  if (register) {
    task$status <- "running"; task$error_msg <- NULL
    store_set_task(store, task)
    task <- store_all_tasks(store)[[task_id]]
    # Legacy/directly restored records may be normalized by store_set_task,
    # which retires old outputs and marks the configuration pending. Start
    # the normalized record so cancellation observes the actual running state.
    if (!identical(task$status, "running")) {
      task$status <- "running"; task$error_msg <- NULL
      store_set_task(store, task)
      task <- store_all_tasks(store)[[task_id]]
    }
  }
  .ig_background$next_id <- .ig_background$next_id + 1L
  job <- new.env(parent = emptyenv())
  job$id <- paste0("analysis_", Sys.getpid(), "_", .ig_background$next_id)
  job$store <- store; job$state <- state; job$task_id <- task_id; job$type <- task$type
  job$task <- task[c("type", "params", "inputs", "output", "control_inputs")]
  job$params <- p; job$tables <- ig_background_tables(store, p, task_id = task_id); job$register <- register
  job$record <- record
  job$object_records <- if (task$type %in% c("script", "report", "export", "loop")) isolate(store$objects) else list()
  job$objects <- lapply(job$object_records, `[[`, "value")
  job$tasks <- isolate(store$tasks); job$flows <- isolate(store$flows); job$order <- isolate(store$task_order)
  job$loop_config <- ig_task_configuration(store_all_tasks(store))
  job$sources <- isolate(store$sources); job$settings <- isolate(store$settings)
  job$context <- isolate(store$execution_context); job$branch_tokens <- isolate(store$branch_tokens)
  job$artifacts <- tempfile("ig_task_results_"); dir.create(job$artifacts)
  state$artifacts <- c(state$artifacts, job$artifacts)
  job$options <- ig_background_options(store); job$rng_kind <- RNGkind()
  job$started <- Sys.time()
  if (!length(isolate(store$run_ids))) {
    store$run_started <- job$started; store$run_total <- 1L
    store$run_completed <- 0L; store$run_outcome <- "running"
  }
  job$flow_id <- isolate(store$active_flow); job$logging <- task$logging
  job$log_spec <- ig_log_task_spec(task)
  job$meta <- list(task_id = task_id, type = task$type, flow_id = job$flow_id,
    iteration = isolate(store$execution_context)$.ig_loop_prefix %||% "")
  job$stdout <- tempfile("ig-analysis-stdout-"); job$stderr <- tempfile("ig-analysis-stderr-")
  job$process <- NULL; job$observer <- NULL; job$module_cleanup <- NULL; job$complete <- complete
  state$job <- job; .ig_background$queue[[job$id]] <- job
  store$background_revision <- isolate(store$background_revision) + 1L
  job$observer <- shiny::observe({
    if (!ig_background_current(store, job, track = TRUE)) ig_background_cancel(store, task_id)
  }, domain = state$session, priority = 250)
  if (!register && !is.null(module_session)) job$module_cleanup <- module_session$onEnded(function()
    ig_background_cancel(store, task_id, notify = FALSE, change_status = FALSE))
  ig_background_schedule()
  structure(list(id = job$id, task_id = task_id), class = "ig_async_task")
}
