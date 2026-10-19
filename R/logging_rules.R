# Pure logging helpers are also embedded in exported pipeline scripts.
ig_log_levels <- function() c("DEBUG", "INFO", "WARN", "ERROR")

ig_log_triggers <- function() c("Task starts" = "start", "Task completes" = "success",
  "Warning raised" = "warning", "Task fails" = "error", "Task skipped" = "skipped",
  "Waiting for input" = "waiting",
  "R message" = "message", "Console output" = "console", "Script log_event()" = "custom")

ig_log_fields <- function() c("Task ID" = "task", "Task name" = "task_name",
  "Task type" = "type", "Status" = "status", "Input names" = "inputs",
  "Output names" = "outputs", "Input rows (total)" = "rows_in",
  "Input columns (total)" = "columns_in", "Output rows (total)" = "rows_out",
  "Output columns (total)" = "columns_out", "Elapsed seconds" = "elapsed",
  "Original message" = "message", "Source" = "source", "Destination" = "destination",
  "File format" = "format", "Flow ID" = "flow_id", "Loop iteration" = "iteration")

ig_logging_defaults <- function(type = "task") {
  label <- paste(vapply(strsplit(type %||% "task", "_", fixed = TRUE)[[1L]],
    function(x) paste0(toupper(substr(x, 1L, 1L)), substring(x, 2L)), character(1)), collapse = " ")
  start <- switch(type,
    import_data = "Import Data {task}: reading {source}",
    export = "Export {task}: writing {inputs} to {destination}",
    export_log = "Export Log {task}: writing retained logs to {destination}",
    report = "Report {task}: rendering {format} report from {inputs}",
    script = "Script {task}: running R code",
    branch = "Branch {task}: evaluating routes",
    loop = "Loop {task}: starting iterations",
    paste0(label, " {task}: starting with {inputs}"))
  success <- switch(type,
    import_data = "Import Data {task}: imported {rows_out} rows and {columns_out} columns into {outputs} ({elapsed}s)",
    export = "Export {task}: wrote {inputs} to {destination} ({elapsed}s)",
    export_log = "Export Log {task}: wrote retained logs to {destination} ({elapsed}s)",
    report = "Report {task}: created {format} report {outputs} ({elapsed}s)",
    script = "Script {task}: completed; outputs {outputs} ({elapsed}s)",
    branch = "Branch {task}: routes evaluated ({elapsed}s)",
    loop = "Loop {task}: iterations completed ({elapsed}s)",
    if (type %in% c("query_builder", "append_table", "filter_sort", "stack_columns",
      "split_columns", "transpose", "rank", "standardize", "random_sample", "remove_dups",
      "keep_drop_cols", "rename_cols", "first_last_n", "replace_missing", "derive_cols", "recode_values", "change_types"))
      paste0(label, " {task}: {rows_in} input rows; {rows_out} rows, {columns_out} columns in {outputs} ({elapsed}s)")
    else paste0(label, " {task}: completed; outputs {outputs} ({elapsed}s)"))
  list(enabled = TRUE, min_level = "INFO", console = TRUE,
    start_message = start, success_message = success, rules = NULL)
}

ig_logging_rules <- function(config = NULL, type = "task") {
  config <- ig_logging_config(config, type)
  if (!is.null(config$rules)) return(config$rules)
  rule <- function(id, event, level, template) list(id = id, enabled = TRUE,
    event = event, level = level, template = template)
  list(rule("start", "start", "INFO", config$start_message),
    rule("inputs", "start", "DEBUG", "{task}: inputs {inputs}; {rows_in} rows, {columns_in} columns; outputs {outputs}"),
    rule("success", "success", "INFO", config$success_message),
    rule("warning", "warning", "WARN", "{message}"),
    rule("error", "error", "ERROR", "{message}"),
    rule("skipped", "skipped", "WARN", "{task} skipped: {message}"),
    rule("waiting", "waiting", "INFO", "{task} waiting: {message}"),
    rule("message", "message", "INFO", "{message}"),
    rule("console", "console", "DEBUG", "{message}"),
    rule("custom", "custom", "EVENT", "{message}"))
}

ig_logging_normalize_rules <- function(rules) {
  if (!is.list(rules)) return(list())
  ids <- character(0)
  lapply(utils::head(rules, 64L), function(rule) {
    if (!is.list(rule)) rule <- list()
    scalar <- function(value, fallback) if (is.character(value) && length(value) == 1L && !is.na(value)) value else fallback
    id <- scalar(rule$id, paste0("rule_", length(ids) + 1L))
    if (!grepl("^[A-Za-z][A-Za-z0-9_]*$", id) || id %in% ids) {
      id <- paste0("rule_", length(ids) + 1L)
      while (id %in% ids) id <- paste0(id, "_new")
    }
    ids <<- c(ids, id)
    event <- scalar(rule$event, "success")
    if (!event %in% unname(ig_log_triggers())) event <- "success"
    level <- scalar(rule$level, "INFO")
    if (!level %in% c(ig_log_levels(), "EVENT")) level <- "INFO"
    list(id = id, enabled = !identical(rule$enabled, FALSE), event = event,
      level = level, template = scalar(rule$template, "{message}"))
  })
}

# Never collect a lazy SQL table or inspect individual data values for logging.
ig_log_context <- function(task, tables = list(), objects = list(), result = NULL) {
  p <- task[["params"]] %||% list()
  inputs <- unique(task[["inputs"]] %||% character(0))
  outputs <- unique(c(task[["output"]] %||% character(0),
    vapply(task[["outputs"]] %||% list(), function(x) x[["name"]] %||% "", character(1))))
  inputs <- inputs[nzchar(inputs)]; outputs <- outputs[nzchar(outputs)]
  values <- c(tables, objects[setdiff(names(objects), names(tables))])
  dimensions <- function(ids, dimension) {
    if (!length(ids)) return("0")
    data <- values[ids]
    if (!all(vapply(data, function(x) is.data.frame(x) && !inherits(x, "tbl_sql"), logical(1)))) return("n/a")
    as.character(sum(vapply(data, function(x) dim(x)[[dimension]], integer(1))))
  }
  out_rows <- dimensions(outputs, 1L); out_cols <- dimensions(outputs, 2L)
  if (!is.null(result) && is.data.frame(result[["data"]])) {
    out_rows <- as.character(nrow(result[["data"]])); out_cols <- as.character(ncol(result[["data"]]))
  }
  joined <- function(x) if (length(x)) paste(x, collapse = ", ") else "(none)"
  destination <- if (identical(task[["type"]], "export")) {
    tryCatch(ig_export_path(p[["dir"]] %||% "", p[["filename"]] %||% "", p[["format"]] %||% "csv"), error = function(e) "")
  } else if (identical(task[["type"]], "export_log")) p[["path"]] %||% "" else ""
  source <- if (identical(task[["type"]], "import_data")) {
    if (identical(p[["source_kind"]], "db")) {
      if (isTRUE(p[["db_use_query"]])) "database query" else p[["db_table"]] %||% "(not configured)"
    } else p[["path"]] %||% "(not configured)"
  } else p[["source"]] %||% joined(inputs)
  text <- function(value, fallback) {
    if (!is.atomic(value) || !length(value)) return(fallback)
    value <- as.character(value); value <- value[!is.na(value) & nzchar(value)]
    if (length(value)) paste(value, collapse = ", ") else fallback
  }
  list(task_name = text(task[["label"]], task[["id"]] %||% ""),
    inputs = joined(inputs), outputs = joined(outputs), rows_in = dimensions(inputs, 1L),
    columns_in = dimensions(inputs, 2L), rows_out = out_rows, columns_out = out_cols,
    source = text(source, "(not configured)"),
    destination = text(destination, "(not configured)"), format = text(p[["format"]] %||% p[["type"]], "(default)"))
}

ig_log_task_spec <- function(task) {
  task <- task[intersect(names(task), c("id", "type", "label", "inputs", "output", "outputs", "params"))]
  task$params <- task$params[intersect(names(task$params), c("path", "dir", "filename", "source", "source_kind", "db_use_query", "db_table", "format", "type"))]
  task
}

ig_log_template_fields <- function(text) {
  unique(regmatches(text, gregexpr("\\{[a-z_]+\\}", text, perl = TRUE))[[1L]])
}

ig_log_render_rules <- function(rules, event, level, message, meta, status, context = list(), elapsed = 0) {
  values <- utils::modifyList(context, c(meta, list(task = meta$task_id %||% "", status = status,
    message = message, elapsed = format(round(elapsed, 3L), trim = TRUE, scientific = FALSE))))
  lapply(Filter(function(rule) isTRUE(rule$enabled) && identical(rule$event, event), rules), function(rule)
    list(level = if (identical(rule$level, "EVENT")) level else rule$level,
      message = ig_log_template(rule$template, values, status), rule_id = rule$id))
}
