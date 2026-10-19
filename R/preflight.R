# Validate configuration without executing user code or contacting databases.
ig_preflight <- function(store, task_ids = NULL) {
  tasks <- store_all_tasks(store)
  task_ids <- task_ids %||% names(isolate(store$tasks))
  tables <- isolate(store$tables); objects <- isolate(store$objects)
  rows <- list()
  add <- function(id, level, field, message) {
    rows[[length(rows) + 1L]] <<- data.frame(task = id, severity = level, field = field, message = message, stringsAsFactors = FALSE)
  }
  outputs <- unlist(lapply(tasks, task_output_names), use.names = FALSE)
  duplicates <- unique(outputs[duplicated(outputs) & nzchar(outputs)])
  producers <- lapply(unique(outputs), function(name) names(Filter(function(task) name %in% task_output_names(task), tasks)))
  names(producers) <- unique(outputs)
  order <- isolate(store$task_order)
  problem <- store_dependency_problem(isolate(store$tasks), order)
  if (!is.null(problem)) add("", "error", "dependencies", problem)
  columns <- c("cols", "col", "x", "y", "group", "row_var", "col_var", "value_var", "group_cols", "id_cols", "pred_cols", "response", "predictors", "time_col", "value_col")
  for (id in intersect(task_ids, names(tasks))) {
    task <- tasks[[id]]; p <- task$params %||% list()
    if (is.null(task_type_info(task$type))) { add(id, "error", "type", "This task type is unavailable in this release."); next }
    if (any(task_output_names(task) %in% duplicates)) add(id, "error", "output", "An output name is shared by multiple tasks; give each producer a unique name.")
    for (input in task$inputs %||% character()) {
      if (input %in% c(names(tables), names(objects))) next
      owners <- setdiff(producers[[input]] %||% character(), id)
      if (!any(owners %in% task_ids)) {
        in_loop <- any(vapply(tasks[task_ids], function(x) identical(x$type, "loop"), logical(1))) && length(task$control_inputs %||% character())
        add(id, if (in_loop) "warning" else "error", "input", paste0("Input '", input, "' is unavailable", if (in_loop) "; it must be supplied by the loop's iteration context." else "; run or include its producer."))
      }
    }
    if (task$type == "import_data") {
      if (identical(p$source_kind %||% "file", "file")) {
        if (!nzchar(p$path %||% "")) add(id, "error", "path", "Choose an input file.")
        else if (!file.exists(p$path) || dir.exists(p$path)) {
          contextual <- length(task$control_inputs %||% character()) > 0L && grepl("\\{[^}]+\\}", p$path)
          add(id, if (contextual) "warning" else "error", "path", if (contextual) "The loop supplies this file path during each iteration." else paste("Missing input file:", p$path))
        }
        else if (!tolower(tools::file_ext(p$path)) %in% IMPORT_TYPES) add(id, "error", "path", "This input file format is unsupported.")
      } else add(id, "warning", "database", "Database connectivity, permissions and live schema are checked when the import runs.")
    }
    input <- p[["input_table"]] %||% ""
    if (length(input) != 1L || is.na(input)) input <- ""
    table <- if (nzchar(input)) tables[[input]] else NULL
    owners <- if (nzchar(input)) producers[[input]] %||% character() else character()
    # Selected producers rerun even when their cached result was successful.
    # An external file or Script may therefore produce a new schema this time.
    future <- length(intersect(setdiff(owners, id), task_ids)) > 0L
    if (is.data.frame(table) && !future) {
      for (field in intersect(columns, names(p))) {
        values <- p[[field]]
        if (!is.character(values)) next
        values <- values[nzchar(values) & !values %in% c("(None)", "None", "", ".", "1")]
        missing <- setdiff(values, names(table))
        if (length(missing)) add(id, "error", field, paste0("Unavailable column", if (length(missing) > 1L) "s" else "", ": ", paste(missing, collapse = ", "), "."))
      }
    } else if (future) add(id, "info", "schema", "Upstream tasks will produce this input; its new column schema is checked during execution.")
    for (field in intersect(c("code", "formula", "condition"), names(p))) {
      value <- p[[field]]
      if (!is.character(value) || length(value) != 1L || !nzchar(trimws(value))) {
        if (field == "code" && task$type == "script") add(id, "error", field, "Enter R code for this Script task.")
        next
      }
      error <- tryCatch({ parse(text = value); NULL }, error = conditionMessage)
      if (!is.null(error)) add(id, "error", field, paste("Invalid R syntax:", error))
    }
    if (task$type %in% c("export", "export_log")) {
      path <- if (task$type == "export_log") p$path %||% "" else
        tryCatch(ig_export_path(p$dir %||% ".", p$filename, p$format), error = function(e) "")
      if (!nzchar(path)) add(id, "error", "destination", "Choose an export filename and destination.")
      else if (!dir.exists(dirname(path))) add(id, "error", "destination", paste("Export folder is missing:", dirname(path)))
      else if (file.access(dirname(path), 2L) != 0L) add(id, "error", "destination", "The export folder is not writable.")
      else if (file.exists(path) && !isTRUE(p$overwrite) && !isTRUE(p$append)) add(id, "error", "destination", "The export file exists; choose a new filename or enable Overwrite/Append.")
    }
  }
  if (!length(rows)) return(data.frame(task = character(), severity = character(), field = character(), message = character()))
  unique(do.call(rbind, rows))
}

ig_preflight_ui <- function(result, title = "Flow validation", allow_run = FALSE) {
  modalDialog(title = title, size = "l", easyClose = TRUE,
    if (!nrow(result)) div(class = "alert alert-success", "No configuration problems found. Data-dependent checks still run with each task.") else
      tagList(lapply(seq_len(nrow(result)), function(i) {
        row <- result[i, ]
        div(class = paste("ig-preflight-row alert", switch(row$severity, error = "alert-danger", warning = "alert-warning", "alert-info")),
          strong(paste0(toupper(row$severity), if (nzchar(row$task)) paste0(" · ", row$task), " · ", row$field)),
          p(row$message), if (nzchar(row$task)) tags$button(type = "button", class = "btn btn-sm btn-outline-secondary",
            onclick = ig_input_event_js("preflight_open_task", row$task), "Open task"))
      })),
    footer = tagList(modalButton("Close"), if (allow_run && !any(result$severity == "error"))
      actionButton("preflight_run", "Run flow", class = "btn-primary")))
}
