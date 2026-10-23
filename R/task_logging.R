# Task logs are bounded, persisted task data. Runtime callbacks are scoped to a
# synchronous execution and restored on exit, including nested loop executions.
ig_logging_config <- function(config = NULL, type = "task") {
  defaults <- ig_logging_defaults(type)
  if (!is.list(config)) config <- list()
  config <- utils::modifyList(defaults, config %||% list())
  if (length(config$min_level) != 1L || is.na(config$min_level) || !config$min_level %in% ig_log_levels()) config$min_level <- "INFO"
  if (!is.null(config$rules)) config$rules <- ig_logging_normalize_rules(config$rules)
  config
}

ig_log_template <- function(text, meta, status) {
  values <- utils::modifyList(meta, list(task = meta$task_id %||% meta$task %||% "", status = status))
  matches <- gregexpr("\\{[a-z_]+\\}", text, perl = TRUE)
  tokens <- regmatches(text, matches)[[1L]]
  if (length(tokens)) regmatches(text, matches) <- list(vapply(tokens, function(token) {
    value <- values[[substring(token, 2L, nchar(token) - 1L)]]
    if (is.null(value)) token else paste(as.character(value), collapse = ", ")
  }, character(1)))
  text
}

ig_log_event <- function(message, level = "INFO") {
  level <- toupper(level)
  if (length(level) != 1L || is.na(level) || !level %in% c("DEBUG", "INFO", "WARN", "ERROR"))
    stop("Log level must be DEBUG, INFO, WARN, or ERROR.")
  callback <- getOption("IndividualGuide.log_callback")
  if (is.function(callback)) callback(paste(as.character(message), collapse = "\n"), level, "custom")
  invisible(NULL)
}

ig_capture_task_log <- function(fn, config, meta, emit, outcome, started = Sys.time(), context = function() list()) {
  config <- ig_logging_config(config, meta$type %||% "task")
  rules <- ig_logging_rules(config, meta$type %||% "task")
  run_id <- paste0(meta$task_id, "-", format(started, "%Y%m%dT%H%M%OS6"))
  events <- list()
  current_status <- "running"
  write <- function(message, level = "INFO", event = "message") {
    if (identical(event, "console") && !isTRUE(config$console)) return(invisible(NULL))
    ranks <- c(DEBUG = 1L, INFO = 2L, WARN = 3L, ERROR = 4L)
    if (!isTRUE(config$enabled)) return(invisible(NULL))
    elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
    status <- switch(event, start = "running", success = "success", error = "error", skipped = "skipped", current_status)
    entries <- ig_log_render_rules(rules, event, level, message, meta, status, context(), elapsed)
    for (entry in entries) {
      if (ranks[[entry$level]] < ranks[[config$min_level]] || !nzchar(entry$message)) next
      events[[length(events) + 1L]] <<- c(list(
      time = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z"), run_id = run_id), meta,
      list(level = entry$level, event = event, message = entry$message, rule_id = entry$rule_id,
        elapsed_seconds = elapsed))
    }
    if (length(events) > 1000L) events <<- utils::tail(events, 1000L)
    invisible(NULL)
  }
  previous <- options(IndividualGuide.log_callback = write)
  on.exit(options(previous), add = TRUE)
  console <- character(0)
  ranks <- stats::setNames(seq_along(ig_log_levels()), ig_log_levels())
  keep_console <- isTRUE(config$enabled) && isTRUE(config$console) && any(vapply(rules,
    function(rule) isTRUE(rule$enabled) && identical(rule$event, "console") &&
      ranks[[if (identical(rule$level, "EVENT")) "DEBUG" else rule$level]] >= ranks[[config$min_level]], logical(1)))
  connection <- if (keep_console) textConnection("console", "w", local = TRUE) else file(base::nullfile(), "w")
  depth <- sink.number()
  sink(connection)
  # Flush even when the task throws. Leave any surrounding caller's sinks alone.
  on.exit({
    while (sink.number() > depth) sink()
    close(connection)
    if (isTRUE(config$console) && length(console)) write(paste(console, collapse = "\n"), "DEBUG", "console")
    emit(events)
  }, add = TRUE)
  write("", "INFO", "start")
  value <- tryCatch(withCallingHandlers(fn(),
    message = function(m) write(trimws(conditionMessage(m)), "INFO", "message"),
    warning = function(w) write(conditionMessage(w), "WARN", "warning")),
    error = function(e) {
      current_status <<- "error"
      write(conditionMessage(e), "ERROR", "error")
      stop(e)
    })
  state <- outcome(value)
  status <- state$status %||% "success"
  current_status <- status
  if (status == "success") write("", "INFO", "success")
  else write(state$message %||% paste("Task", status),
    if (status == "error") "ERROR" else "INFO", status)
  value
}

ig_task_logged <- function(store, task_id, fn) {
  ig_with_options(store, function() ig_task_logged_impl(store, task_id, fn))
}

ig_task_logged_impl <- function(store, task_id, fn) {
  task <- shiny::isolate(store$tasks[[task_id]])
  if (is.null(task) || isTRUE(shiny::isolate(store$review_mode))) return(fn())
  record <- ig_run_begin(store, task_id)
  on.exit({ record$environment <- ig_environment_info(); ig_run_finish(store, record) }, add = TRUE)
  # Scheduling measurements remain available when user-facing logs are off.
  clock <- proc.time()[["elapsed"]]
  on.exit({
    cache <- shiny::isolate(store$performance_cache)
    if (!is.null(cache) && task$type %in% PHASE3_TYPES) {
      durations <- cache$task_durations %||% list()
      if (!task_id %in% names(durations) && length(durations) >= 128L) durations <- durations[-1L]
      durations[[task_id]] <- list(type = task$type, elapsed = proc.time()[["elapsed"]] - clock)
      cache$task_durations <- durations
    }
  }, add = TRUE)
  meta <- list(task_id = task_id, type = task$type,
    flow_id = shiny::isolate(store$log_flow_id) %||% shiny::isolate(store$active_flow) %||% "",
    iteration = shiny::isolate(store$execution_context)$.ig_loop_prefix %||% "")
  ig_capture_task_log(function() ig_with_project_seed(store, function() {
    if (!exists(".Random.seed", globalenv(), inherits = FALSE)) set.seed(NULL)
    record$rng_state <<- get(".Random.seed", globalenv())
    record$rng_kind <<- RNGkind()
    fn()
  }), task$logging, meta, emit = function(events) {
    if (!length(events)) return(invisible(NULL))
    tasks <- shiny::isolate(store$tasks)
    tasks[[task_id]]$log_events <- utils::tail(c(tasks[[task_id]]$log_events %||% list(), events), 1000L)
    store$tasks <- tasks
    store$dirty <- TRUE
  }, context = function() {
    current <- shiny::isolate(store$tasks[[task_id]]) %||% task
    ig_log_context(current, shiny::isolate(store$tables),
      lapply(shiny::isolate(store$objects), `[[`, "value"))
  }, outcome = function(value) {
    after <- shiny::isolate(store$tasks[[task_id]])
    list(status = after$status, message = after$error_msg %||% after$skip_reason)
  })
}

ig_log_result <- function(result) {
  callback <- getOption("IndividualGuide.log_callback")
  if (!is.function(callback)) return(invisible(NULL))
  output <- result[["output"]]
  if (is.character(output) && length(output) && any(nzchar(output))) callback(paste(output, collapse = "\n"), "DEBUG", "console")
  for (message in result$warnings %||% character(0)) callback(message, "WARN", "warning")
  invisible(NULL)
}

ig_log_records <- function(tasks, task_ids = names(tasks), min_level = "DEBUG", limit = NULL) {
  fields <- c("time", "run_id", "flow_id", "task_id", "type", "iteration", "level", "event", "message", "elapsed_seconds")
  records <- unlist(lapply(tasks[intersect(task_ids, names(tasks))], function(task) task$log_events %||% list()), recursive = FALSE)
  ranks <- c(DEBUG = 1L, INFO = 2L, WARN = 3L, ERROR = 4L)
  records <- Filter(function(x) (ranks[[x$level]] %||% 0L) >= ranks[[min_level]], records)
  if (!is.null(limit) && length(records)) {
    times <- vapply(records, function(x) x$time %||% "", character(1))
    records <- utils::head(records[order(times, seq_along(records))], limit)
  }
  if (!length(records)) return(as.data.frame(stats::setNames(rep(list(character(0)), length(fields)), fields)))
  rows <- lapply(records, function(x) as.data.frame(stats::setNames(lapply(fields, function(f) x[[f]] %||% ""), fields), stringsAsFactors = FALSE))
  data <- do.call(rbind, rows)
  data <- data[order(data$time, seq_len(nrow(data))), , drop = FALSE]
  rownames(data) <- NULL
  data
}

default_export_log_params <- function(output_name = "") {
  list(path = "", format = "txt", overwrite = FALSE, min_level = "DEBUG", after_tasks = character(0))
}

ig_write_log <- function(data, p) {
  path <- trimws(p$path %||% "")
  if (!nzchar(path)) stop("Choose a destination file for the log.")
  if (!dir.exists(dirname(path))) stop("Destination folder does not exist.")
  if (dir.exists(path)) stop("The destination is a folder; enter a file path.")
  if (file.exists(path) && !isTRUE(p$overwrite)) stop("File already exists; enable Overwrite to replace it.")
  format <- p$format %||% "txt"
  if (!format %in% c("txt", "csv", "json")) stop("Log format must be text, CSV, or JSON.")
  temporary <- tempfile(".ig_log_", tmpdir = dirname(path))
  on.exit(unlink(temporary), add = TRUE)
  writeLines(ig_log_file_lines(data, format), temporary, useBytes = TRUE)
  ig_replace_file(temporary, path)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

execute_export_log <- function(p, tasks = list(), task_id = NULL) {
  tryCatch({
    ids <- p$after_tasks %||% character(0)
    if (!length(ids)) ids <- setdiff(names(tasks), task_id)
    data <- ig_log_records(tasks, ids, p$min_level %||% "DEBUG")
    list(file = ig_write_log(data, p), entries = nrow(data), error = NULL)
  }, error = function(e) list(error = conditionMessage(e)))
}

build_export_log_code <- function(p) {
  helpers <- code_helper_definitions("write_task_log", overrides = list(write_task_log = ig_code_write_log))
  arguments <- c(paste0("path = ", code_literal(p$path %||% "")),
    paste0("format = ", code_literal(p$format %||% "txt")),
    if (length(p$after_tasks)) paste0("tasks = ", code_literal(p$after_tasks)),
    if (!identical(p$min_level %||% "DEBUG", "DEBUG")) paste0("min_level = ", code_literal(p$min_level)),
    if (isTRUE(p$overwrite)) "overwrite = TRUE")
  call <- c(".ig_codegen$write_task_log(",
    paste0("  ", paste(arguments, collapse = ",\n  ")), ")")
  if (length(helpers)) paste(c("local({", helpers, call, "})"), collapse = "\n") else
    paste(call, collapse = "\n")
}
