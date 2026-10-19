# Preview and export share one formatter; previews never create files or run R.
ig_log_file_lines <- function(data, format = "txt") {
  if (!format %in% c("txt", "csv", "json")) stop("Log format must be text, CSV, or JSON.")
  lines <- switch(format,
    txt = if (nrow(data)) sprintf("%s [%s] %s%s %s: %s", data$time, data$level,
      data$task_id, ifelse(nzchar(data$iteration), paste0(" (", data$iteration, ")"), ""),
      data$event, data$message) else character(0),
    csv = utils::capture.output(utils::write.csv(data, row.names = FALSE)),
    json = strsplit(as.character(jsonlite::toJSON(data, dataframe = "rows", auto_unbox = TRUE,
      pretty = TRUE)), "\n", fixed = TRUE)[[1L]])
  if (!length(lines)) return(character(0))
  enc2utf8(unlist(strsplit(paste0(lines, "\n"), "\n", fixed = TRUE), use.names = FALSE))
}

ig_log_preview_text <- function(data, format = "txt", max_chars = 20000L) {
  text <- paste(ig_log_file_lines(data, format), collapse = "\n")
  if (nchar(text) > max_chars) paste0(substr(text, 1L, max_chars), "\n... [preview truncated]") else text
}

ig_log_example_records <- function() {
  data.frame(time = c("2026-01-01T12:00:00.000+0000", "2026-01-01T12:00:00.120+0000", "2026-01-01T12:00:01.234+0000"),
    run_id = "example-run", flow_id = "example-flow", task_id = "clean_data", type = "filter_sort", iteration = "",
    level = c("INFO", "WARN", "INFO"), event = c("start", "warning", "success"),
    message = c("Filter and Sort clean_data: starting with source_data", "Example warning: some rows contain missing values",
      "Filter and Sort clean_data: 100 input rows; 80 rows, 6 columns in cleaned_data (1.234s)"),
    elapsed_seconds = c(0, 0.12, 1.234), stringsAsFactors = FALSE)
}

ig_log_preview_scenario <- function(config, task, tables = list(), objects = list(),
    event = "success", example = FALSE, example_rows_in = 100, example_rows_out = 80,
    example_message = "", elapsed = 1.234, flow_id = "", iteration = "") {
  config <- ig_logging_config(config, task$type %||% "task")
  context <- ig_log_context(task, tables, objects)
  if (example) {
    context$rows_in <- as.character(example_rows_in); context$rows_out <- as.character(example_rows_out)
    context$columns_in <- "8"; context$columns_out <- "6"
    replace <- function(value, sample) if (value %in% c("", "(none)", "(not configured)", "(default)")) sample else value
    context$inputs <- replace(context$inputs, "source_data"); context$outputs <- replace(context$outputs, "cleaned_data")
    context$source <- replace(context$source, "input.csv"); context$destination <- replace(context$destination, "output.csv")
    context$format <- replace(context$format, "csv"); iteration <- "example iteration"
  }
  examples <- c(warning = "Example warning", error = "Example error", skipped = "An upstream task was unavailable",
    waiting = "Required inputs are not available yet", message = "Example R message", console = "Example console output",
    custom = "Example script log entry")
  message <- if (nzchar(example_message)) example_message else if (event %in% names(examples)) examples[[event]] else ""
  status <- switch(event, start = "running", success = "success", error = "error", skipped = "skipped", waiting = "waiting", "running")
  level <- switch(event, warning = "WARN", error = "ERROR", console = "DEBUG", "INFO")
  meta <- list(task_id = task$id %||% "", type = task$type %||% "task", flow_id = flow_id, iteration = iteration)
  values <- utils::modifyList(context, c(meta, list(task = meta$task_id, status = status, message = message,
    elapsed = format(round(elapsed, 3L), trim = TRUE, scientific = FALSE))))
  entries <- if (isTRUE(config$enabled) && (!identical(event, "console") || isTRUE(config$console)))
    ig_log_render_rules(ig_logging_rules(config, task$type %||% "task"), event, level, message, meta,
      status, context, elapsed) else list()
  ranks <- stats::setNames(seq_along(ig_log_levels()), ig_log_levels())
  entries <- Filter(function(x) ranks[[x$level]] >= ranks[[config$min_level]] && nzchar(x$message), entries)
  records <- lapply(entries, function(x) c(list(time = "2026-01-01T12:00:01.234+0000", run_id = "example-run"),
    meta, list(level = x$level, event = event, message = x$message, elapsed_seconds = elapsed)))
  list(values = values, entries = ig_log_records(list(preview = list(log_events = records))),
    example = example, enabled = isTRUE(config$enabled), console = isTRUE(config$console))
}

ig_log_entries_ui <- function(data) {
  if (!nrow(data)) return(shiny::p(class = "text-muted small", "No entry matches the current rules and minimum severity."))
  shiny::tagList(lapply(seq_len(nrow(data)), function(i) shiny::div(class = "ig-log-preview-entry",
    shiny::div(class = "d-flex align-items-center gap-2 mb-1",
      shiny::span(class = paste0("ig-log-level ig-log-level-", tolower(data$level[[i]])), data$level[[i]]),
      shiny::span(class = "small text-muted", data$task_id[[i]], " / ", data$event[[i]])),
    shiny::div(class = "ig-log-preview-message", data$message[[i]]))))
}
