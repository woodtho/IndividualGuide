# Shared orchestration for exported scripts. The generated pipeline contains
# one readable run_task() call per step; this support is emitted only once.
code_indent_lines <- function(lines, n = 2L) {
  lines <- unlist(strsplit(lines, "\n", fixed = TRUE), use.names = FALSE)
  parsed <- tryCatch(parse(text = lines, keep.source = TRUE), error = function(e) NULL)
  data <- if (!is.null(parsed)) utils::getParseData(parsed) else NULL
  preserve <- integer(0)
  if (!is.null(data)) {
    multiline <- data[data$terminal & data$line2 > data$line1, , drop = FALSE]
    preserve <- unique(unlist(Map(function(from, to) seq.int(from + 1L, to), multiline$line1, multiline$line2)))
  }
  ifelse(seq_along(lines) %in% preserve, lines, paste0(strrep(" ", n), lines))
}

code_runtime_name <- function(tasks) {
  symbols <- unique(c(unlist(lapply(tasks, task_output_names), use.names = FALSE),
    unlist(lapply(tasks, `[[`, "inputs"), use.names = FALSE),
    unlist(lapply(Filter(function(task) identical(task$type, "script"), tasks), function(task)
      tryCatch(all.names(parse(text = task$params$code %||% "")), error = function(e) character(0))), use.names = FALSE)))
  name <- ".pipeline"
  while (name %in% symbols) name <- paste0(name, "_export")
  name
}

code_use_namespace <- function(source, to = getOption("IndividualGuide.codegen_namespace", ".ig_codegen")) {
  if (identical(to, ".ig_codegen") || !grepl(".ig_codegen", source, fixed = TRUE)) return(source)
  parsed <- tryCatch(parse(text = source, keep.source = TRUE), error = function(e) NULL)
  if (is.null(parsed)) return(source)
  tokens <- utils::getParseData(parsed)
  protected <- unique(tokens$text[tokens$token %in% c("STR_CONST", "COMMENT") & nzchar(tokens$text)])
  protected <- protected[order(nchar(protected), decreasing = TRUE)]
  prefix <- ".__CODE_LITERAL__"
  while (grepl(prefix, source, fixed = TRUE)) prefix <- paste0(prefix, "_")
  markers <- paste0(prefix, seq_along(protected), "__")
  renamed <- source
  for (i in seq_along(protected)) renamed <- gsub(protected[[i]], markers[[i]], renamed, fixed = TRUE)
  renamed <- gsub("(?<![[:alnum:]_.])\\Q.ig_codegen\\E(?![[:alnum:]_.])", to, renamed, perl = TRUE)
  for (i in seq_along(protected)) renamed <- gsub(markers[[i]], protected[[i]], renamed, fixed = TRUE)
  # A lexical rename must preserve every string, quoted expression and field.
  expected <- as.expression(lapply(as.list(parse(text = source, keep.source = FALSE)),
    code_replace_symbols, replacements = list(.ig_codegen = as.name(to))))
  actual <- tryCatch(parse(text = renamed, keep.source = FALSE), error = function(e) NULL)
  if (identical(actual, expected)) renamed else source
}

ig_code_summary_statistics <- function(data, columns = character(0)) {
  result <- execute_summary_stats(list(input_table = "data", cols = columns), list(data = data))
  if (!is.null(result$error)) stop(result$error, call. = FALSE)
  result$data
}

ig_code_sample_rows <- function(data, n = NULL, prop = NULL, replace = FALSE, seed = NA_integer_) {
  ig_sample_data(data, list(method = if (is.null(prop)) "n" else "prop", n = n, prop = prop, replace = replace, seed = seed))
}

ig_code_completed <- function(ids, envir = parent.frame()) {
  statuses <- get(".task_status", envir = envir, inherits = TRUE)
  all(vapply(ids, function(id) identical(statuses[[id]], "success"), logical(1)))
}

ig_code_report_log <- function(min_level = "INFO", envir = parent.frame()) {
  if (!exists(".ig_task_logs", envir = envir, inherits = TRUE))
    stop("Run this report as part of the generated pipeline to collect logs.", call. = FALSE)
  logs <- get(".ig_task_logs", envir = envir, inherits = TRUE)
  ig_log_records(logs$tasks, min_level = min_level)
}

ig_code_write_log <- function(path, format = "txt", tasks = character(0), min_level = "DEBUG", overwrite = FALSE, envir = parent.frame()) {
  if (!exists(".ig_task_logs", envir = envir, inherits = TRUE))
    stop("Run this task as part of the generated pipeline to collect logs.", call. = FALSE)
  logs <- get(".ig_task_logs", envir = envir, inherits = TRUE)
  if (!length(tasks)) tasks <- names(logs$tasks)
  entries <- ig_log_records(logs$tasks, tasks, min_level)
  ig_write_log(entries, list(path = path, format = format, overwrite = overwrite))
}

ig_code_run_task <- function(id, code, when = TRUE, in_loop = FALSE, envir = parent.frame()) {
  runtime <- environment(sys.function())
  task <- runtime$steps[[id]]
  task$id <- id
  outputs <- unique(c(task[["output"]] %||% character(0),
    vapply(task[["outputs"]] %||% list(), function(x) x$name, character(1))))
  if (length(outputs)) rm(list = intersect(outputs, ls(envir, all.names = TRUE)), envir = envir)
  set_status <- function(status) {
    statuses <- get(".task_status", envir, inherits = TRUE)
    statuses[[id]] <- status
    assign(".task_status", statuses, envir = envir)
  }
  meta <- list(task_id = id, type = task$type, flow_id = "generated",
    iteration = if (exists(".ig_loop_prefix", envir, inherits = TRUE)) get(".ig_loop_prefix", envir, inherits = TRUE) else "")
  context <- function() {
    spec <- task
    if (in_loop) spec$params <- runtime$substitute_params(spec$params,
      get(".ig_record", envir, inherits = TRUE), get(".ig_index", envir, inherits = TRUE))
    names <- unique(c(spec$inputs, outputs))
    ig_log_context(spec, mget(names, envir = envir, ifnotfound = list(NULL), inherits = TRUE))
  }
  emit <- function(events) {
    logs <- get(".ig_task_logs", envir, inherits = TRUE)
    logs$tasks[[id]]$log_events <- utils::tail(c(logs$tasks[[id]]$log_events, events), 1000L)
  }
  if (!isTRUE(when)) {
    set_status("skipped")
    ig_capture_task_log(function() NULL, task$logging, meta, emit,
      outcome = function(value) list(status = "skipped", message = "Upstream dependency unavailable or inactive branch."), context = context)
    return(invisible(NULL))
  }
  expression <- substitute(code)
  seed <- runtime$project_seed
  if (!is.null(seed)) {
    present <- exists(".Random.seed", globalenv(), inherits = FALSE)
    previous <- if (present) get(".Random.seed", globalenv()) else NULL
    on.exit(if (present) assign(".Random.seed", previous, globalenv()) else
      if (exists(".Random.seed", globalenv(), inherits = FALSE)) rm(".Random.seed", envir = globalenv()), add = TRUE)
    set.seed(seed)
  }
  set_status("running")
  tryCatch(ig_capture_task_log(function() {
    eval(expression, envir = envir)
    set_status("success")
  }, task$logging, meta, emit, outcome = function(value) list(status = "success"), context = context),
    error = function(error) {
      set_status("error")
      warning(paste0("Task '", id, "' failed: ", conditionMessage(error)), call. = FALSE)
      if (isTRUE(get(".ig_stop_on_error", envir, inherits = TRUE))) stop(error)
    })
  invisible(NULL)
}

code_compact_logging <- function(config, type) {
  config <- ig_logging_config(config, type)
  defaults <- ig_logging_config(NULL, type)
  config[!vapply(names(config), function(name) identical(config[[name]], defaults[[name]]), logical(1))]
}

code_step_definitions <- function(tasks) {
  lapply(tasks, function(task) {
    spec <- ig_log_task_spec(task)
    spec$id <- NULL
    logging <- code_compact_logging(task$logging, task$type)
    if (length(logging)) spec$logging <- logging
    spec <- Filter(function(value) !is.null(value) && length(value) > 0L && !identical(value, ""), spec)
    spec
  })
}
