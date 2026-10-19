# mod_task_loop.R -- Loop configuration and iteration sources.

default_loop_params <- function(output_name = "loop_out") {
  list(
    iteration_type = "parameter_list",
    source = "",
    values = "item1\nitem2",
    variable = "item",
    output_token = paste0(output_name, "_each"),
    naming_rule = "{task}_{item}",
    group_col = ""
  )
}

loop_output_specs <- function(p) {
  token <- p$output_token %||% ""
  if (!nzchar(token)) return(list())
  list(list(name = token, kind = "branch", label = "Each iteration"))
}

loop_preview_iterations <- function(p, tables = list()) {
  tryCatch(vapply(loop_iteration_records(p, tables), `[[`, character(1), "label"),
    error = function(e) character(0))
}

execute_loop <- function(p, tables = list(), objects = list()) {
  tryCatch({
    variable <- p$variable %||% "item"
    if (length(variable) != 1L || !nzchar(variable) || !identical(make.names(variable), variable))
      stop("Loop variable must be a valid R variable name.")
    if (!nzchar(p$output_token %||% "")) stop("Loop path token is required.")
    records <- loop_iteration_records(p, tables)
    if (!length(records)) stop("Loop has no iterations to run.")
    list(data = NULL, records = records,
      iterations = vapply(records, `[[`, character(1), "label"),
      outputs = loop_output_specs(p), error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Materialize the six existing loop sources as typed iteration records.
#' @keywords internal
#' @param p Configured task parameter list.
#' @param tables Named list of available in-memory or lazy database tables.
loop_iteration_records <- function(p, tables = list()) {
  type <- p$iteration_type %||% "parameter_list"
  lines <- trimws(strsplit(p$values %||% "", "\n", fixed = TRUE)[[1]])
  lines <- lines[nzchar(lines)]
  record <- function(label, value, data = NULL) list(label = label, value = value, data = data)
  if (type == "parameter_list") return(lapply(lines, function(x) record(x, x)))
  if (type == "files") {
    files <- unlist(lapply(lines, function(pattern) {
      found <- if (file.exists(pattern)) pattern else Sys.glob(pattern)
      found <- found[file.exists(found) & !dir.exists(found)]
      if (!length(found)) stop("No files match: ", pattern)
      normalizePath(found, winslash = "/", mustWork = TRUE)
    }), use.names = FALSE)
    return(lapply(files, function(x) record(basename(x), x)))
  }
  if (type == "datasets") return(lapply(names(tables), function(name) record(name, name, tables[[name]])))
  if (type %in% c("groups", "database_query")) {
    source <- p$source %||% ""
    df <- tables[[source]]
    if (is.null(df)) {
      if (type == "database_query" && !nzchar(source)) return(lapply(lines, function(x) record(x, x)))
      stop("Choose an available source dataset for the loop.")
    }
    if (inherits(df, "tbl_sql")) df <- as.data.frame(dplyr::collect(df))
    col <- p$group_col %||% ""
    if (nzchar(col) && !col %in% names(df)) stop("Loop source column not found: ", col)
    if (type == "groups") {
      if (!nzchar(col)) stop("Choose a group column.")
      values <- sort(unique(df[[col]]), na.last = TRUE)
      return(lapply(seq_along(values), function(i) {
        value <- values[[i]]
        mask <- if (is.na(value)) is.na(df[[col]]) else !is.na(df[[col]]) & df[[col]] == value
        record(if (is.na(value)) "NA" else as.character(value), value, df[mask, , drop = FALSE])
      }))
    }
    return(lapply(seq_len(nrow(df)), function(i) {
      value <- if (nzchar(col)) df[[col]][[i]] else as.list(df[i, , drop = FALSE])
      record(paste0("row_", i), value, df[i, , drop = FALSE])
    }))
  }
  if (type == "date_ranges") {
    return(lapply(lines, function(line) {
      parts <- strsplit(line, "/", fixed = TRUE)[[1]]
      if (!length(parts) || length(parts) > 2L || any(!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", parts)))
        stop("Invalid date or date range: ", line)
      dates <- as.Date(parts, format = "%Y-%m-%d")
      if (anyNA(dates) || any(format(dates, "%Y-%m-%d") != parts) || (length(dates) == 2L && dates[[1]] > dates[[2]]))
        stop("Invalid date or date range: ", line)
      value <- if (length(dates) == 1L) dates[[1]] else list(start = dates[[1]], end = dates[[2]])
      record(line, value)
    }))
  }
  stop("Unsupported loop iteration type: ", type)
}

build_loop_code <- function(p) {
  # Node preview reproduces the iteration source. Full-flow assembly supplies
  # and repeats the real dependent task bodies, including nested loops.
  paste(c("# Loop iteration source; the full pipeline script includes its task body.",
    code_helper_definitions("loop_iteration_records"),
    paste0(".ig_loop_params <- ", code_literal(p)),
    ".ig_loop_tables <- Filter(function(x) is.data.frame(x) || inherits(x, 'tbl_sql'), mget(ls(envir = environment()), envir = environment()))",
    ".ig_loop_records <- .ig_codegen$loop_iteration_records(.ig_loop_params, .ig_loop_tables)",
    paste0(r_ident(paste0(p$variable %||% "item", "_values")), " <- lapply(.ig_loop_records, function(record) record$value)")), collapse = "\n")
}

loop_ui <- function(id) {
  ns <- NS(id)
  bslib::card(
    class = "ig-task-card",
    full_screen = TRUE,
    bslib::card_header(class = "d-flex align-items-center gap-2",
      icon("repeat"), " Loop"),
    bslib::card_body(
      padding = 0, class = "ig-task-tabs",
      bslib::navset_tab(
        id = ns("task_tabs"),
        bslib::nav_panel(tagList(icon("sliders"), " Setup"), value = "setup",
          div(class = "ig-setup-pane",
            div(class = "alert alert-info small mb-3",
              tags$strong("How loops work"),
              tags$ol(class = "mb-0 mt-2",
                tags$li("Choose what defines the iterations: values, datasets, groups, dates, files, or query rows."),
                tags$li("Name the loop variable. Scripts and computed expressions receive its value for each iteration."),
                tags$li("Keep the path token as a control dependency for downstream tasks that belong inside the loop."),
                tags$li("Use Preview loop to validate the source and see the iterations before running the flow.")
              )
            ),
            selectInput(ns("iteration_type"), "Iteration type",
              choices = c("Files" = "files", "Datasets" = "datasets",
                          "Groups" = "groups", "Parameter list" = "parameter_list",
                          "Date ranges" = "date_ranges",
                          "Database query results" = "database_query")),
            uiOutput(ns("source_note")),
            conditionalPanel(condition = sprintf("['groups','datasets','database_query'].includes(input['%s'])", ns("iteration_type")),
              selectInput(ns("source"), "Source dataset / input alias", choices = character(0))),
            conditionalPanel(condition = sprintf("['groups','database_query'].includes(input['%s'])", ns("iteration_type")),
              selectInput(ns("group_col"), "Group / value column", choices = character(0))),
            textInput(ns("variable"), "Loop variable", value = "item"),
            textInput(ns("output_token"), "Path token", value = ""),
            textInput(ns("naming_rule"), "Output naming rule", value = "{task}_{item}"),
            p(class = "small text-muted", "Use {task}, {item}, {index}, and {output}. Add {index} when iteration labels repeat. Dataset, group and query-row data are also available to scripts as .loop_data."),
            textAreaInput(ns("values"), "Iteration values",
              rows = 6, width = "100%")
          )
        ),
        bslib::nav_panel(tagList(icon("list"), " Preview"), value = "preview",
          div(class = "ig-results-pane p-3",
            div(class = "alert alert-light border small",
              tags$strong("Downstream wiring"),
              tags$p(class = "mb-0",
                "The loop emits one path token. Downstream tasks that should run per iteration should depend on that token plus their normal dataset inputs.")),
            uiOutput(ns("loop_summary")),
            verbatimTextOutput(ns("iteration_preview"), placeholder = TRUE),
            verbatimTextOutput(ns("code_preview"), placeholder = TRUE)
          )
        )
      )
    ),
    bslib::card_footer(
      class = "d-flex align-items-center gap-2",
      actionButton(ns("btn_run"), "Preview loop", icon = icon("play"),
        class = "btn btn-sm btn-primary"),
      span(class = "ms-auto text-muted small", role = "status",
        `aria-live` = "polite", textOutput(ns("run_status"), inline = TRUE))
    )
  )
}

loop_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_loop_params()
      else default_loop_params(paste0(task_id %||% "loop", "_out"))
    })
    run_status_msg <- reactiveVal("")

    session$onFlushed(function() {
      updateSelectInput(session, "iteration_type", selected = init_p$iteration_type)
      updateTextInput(session, "variable", value = init_p$variable)
      updateTextInput(session, "output_token", value = init_p$output_token)
      updateTextInput(session, "naming_rule", value = init_p$naming_rule)
      updateTextAreaInput(session, "values", value = init_p$values)
      updateSelectInput(session, "group_col", selected = init_p$group_col %||% "")
    }, once = TRUE)

    observe({
      choices <- c("", store_available_tables(store, task_id = task_id))
      selected <- store_preserve_choice(isolate(input$source), init_p$source, choices, initialized = store_inputs_ready(store, task_id))
      updateSelectInput(session, "source", choices = choices, selected = selected)
    })
    observe({
      src <- input$source %||% init_p$source %||% ""
      columns <- store_col_schema(store, src)$column
      choices <- if (length(columns)) c("", columns) else ""
      updateSelectInput(session, "group_col", choices = choices,
        selected = store_preserve_choice(isolate(input$group_col), init_p$group_col, choices, initialized = store_inputs_ready(store, task_id)))
    })

    output$source_note <- renderUI({
      type <- input$iteration_type %||% init_p$iteration_type %||% "parameter_list"
      text <- switch(type,
        files = "Enter one file path or glob-like value per line. Each line becomes one iteration.",
        datasets = "Each loaded input dataset becomes an iteration. Choose a source dataset as the input alias for visual tasks; scripts receive the dataset name and .loop_data.",
        groups = "Choose a source dataset and group column. Each unique group value becomes one iteration.",
        parameter_list = "Enter one parameter value per line. Each line becomes one iteration.",
        date_ranges = "Enter one date or date range per line, for example 2026-01-01 or 2026-01-01/2026-01-31.",
        database_query = "Choose an imported database-query result table. Each row is an iteration; choose a value column for scalar values, or leave it blank for named rows. Legacy pasted values also work when no source is selected.",
        "Choose an iteration source."
      )
      div(class = "alert alert-light border small mb-3", text)
    })

    collect_p <- reactive({
      list(
        iteration_type = input$iteration_type %||% "parameter_list",
        source = input$source %||% "",
        values = input$values %||% "",
        variable = input$variable %||% "item",
        output_token = input$output_token %||% paste0(task_id %||% "loop", "_each"),
        naming_rule = input$naming_rule %||% "{task}_{item}",
        group_col = input$group_col %||% ""
      )
    })

    output$iteration_preview <- renderText({
      vals <- loop_preview_iterations(collect_p(), store$tables)
      if (!length(vals)) return("No iterations found. Check the loop source.")
      paste(sprintf("%02d  %s", seq_along(vals), vals), collapse = "\n")
    })
    output$code_preview <- renderText(build_loop_code(collect_p()))
    output$loop_summary <- renderUI({
      p <- collect_p()
      vals <- loop_preview_iterations(p, isolate(store$tables))
      tags$ul(
        tags$li(tags$strong("Iteration type: "), p$iteration_type),
        tags$li(tags$strong("Loop variable: "), p$variable),
        tags$li(tags$strong("Path token: "), p$output_token),
        tags$li(tags$strong("Output naming rule: "), p$naming_rule),
        tags$li(tags$strong("Iterations found: "), length(vals))
      )
    })
    output$run_status <- renderText(run_status_msg())

    do_run <- function() {
      p <- collect_p()
      result <- execute_loop(p, isolate(store$tables), isolate(store$objects))
      if (!is.null(result$error)) {
        run_status_msg(paste("Error:", result$error))
        return(invisible(FALSE))
      }
      if (!is.null(task_id)) {
        task <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, "loop")
        task$inputs <- if (nzchar(p$source %||% "")) p$source else character(0)
        task$params <- p
        task$r_code <- build_loop_code(p)
        task$loop_iterations <- result$iterations
        task$execution_log <- c(task$execution_log %||% list(), list(list(
          time = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
          event = "loop_preview",
          iterations = result$iterations
        )))
        store_set_task(store, task)
      }
      run_status_msg(sprintf("%d iteration(s) ready", length(result$iterations)))
      invisible(TRUE)
    }

    observeEvent(input$btn_run, {
      if (!store_review_blocked(store, "preview loops")) do_run()
    })
    store_register_result_fn(store, task_id, function(result) {
      run_status_msg(ig_preview_status(result))
    }, session = session)
    store_register_params_fn(store, task_id, collect_p, session = session)
    if (!is.null(task_id)) {
      store_register_runner(store, task_id, function() {
        store_sync_parameters(store, task_id)
        run_task_from_store(store, task_id)
      })
      store_register_code_fn(store, task_id, function() build_loop_code(collect_p()))
    }
  })
}
