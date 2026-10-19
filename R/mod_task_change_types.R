# mod_task_change_types.R — Change Column Types
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


TYPE_CHOICES <- c("Numeric" = "numeric", "Integer" = "integer", "Character" = "character",
  "Logical" = "logical", "Factor" = "factor", "Date" = "Date")
AS_FN <- c(numeric = "as.numeric", integer = "as.integer", character = "as.character",
  logical = "as.logical", factor = "as.factor", Date = "as.Date")

default_change_types_params <- function(output_name = "retype_out") {
  list(input_table = NULL, type_changes = list(), output_name = output_name)
}

change_types_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "right-left", "Change Column Types", "retype_out",
    p(class = "text-muted small mb-1",
      "Convert column storage types (", code("as.numeric"), ", ",
      code("as.character"), ", etc.)"),
    selectInput(ns("input_table"), "Input table", choices = character(0), width = "100%"),
    div(class = "d-flex align-items-center gap-2 mb-2",
      strong("Type conversions"),
      actionButton(ns("add_type"), "Add", icon = icon("plus"),
        class = "btn btn-xs btn-outline-secondary")),
    uiOutput(ns("type_rows_ui"))
  )
}

change_types_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    ns <- session$ns
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_change_types_params()
      else default_change_types_params(paste0(task_id %||% "changetype", "_out"))
    })
    run_status_msg <- reactiveVal(""); preview_df <- reactiveVal(NULL)
    type_ctr  <- reactiveVal(0L)
    type_ids  <- reactiveVal(character(0))
    type_init <- reactiveVal(list())

    session$onFlushed(function() {
      updateTextInput(session, "output_name", value = init_p$output_name)
      saved <- init_p$type_changes %||% list()
      if (length(saved)) {
        ids <- vapply(seq_along(saved), function(i) paste0("tc", i), character(1))
        type_ctr(length(saved))
        type_init(setNames(saved, ids))
        type_ids(ids)
      }
    }, once = TRUE)

    observeEvent(input$add_type, {
      n <- type_ctr() + 1L; type_ctr(n)
      tid <- paste0("tc", n)
      type_ids(c(type_ids(), tid))
    })

    observeEvent(input$remove_type_row, {
      type_ids(setdiff(type_ids(), input$remove_type_row))
    })

    observe({
      tbls <- c("", store_available_tables(store, task_id = task_id))
      cur  <- isolate(input$input_table) %||% init_p$input_table %||% ""
      updateSelectInput(session, "input_table", choices = tbls,
        selected = if (cur %in% store_available_tables(store, task_id = task_id)) cur else "")
    })

    output$type_rows_ui <- renderUI({
      ids  <- type_ids()
      if (!length(ids))
        return(p(class = "text-muted small", "No conversions yet. Click 'Add'."))
      tbl  <- input$input_table %||% ""
      ci   <- if (nzchar(tbl)) store_col_schema(store, tbl) else data.frame(column = character(0))
      col_choices <- ci$column

      rows <- lapply(ids, function(tid) {
        saved    <- type_init()[[tid]] %||% list(col = "", type = "character")
        cur_col  <- isolate(input[[paste0("tcol_",  tid)]]) %||% saved$col
        cur_type <- isolate(input[[paste0("ttype_", tid)]]) %||% saved$type
        div(class = "d-flex align-items-center gap-2 mb-1",
          div(style = "flex:2;",
            selectInput(ns(paste0("tcol_", tid)), sr_label("Column to convert"),
              choices  = c("", col_choices),
              selected = cur_col,
              width    = "100%")),
          span(`aria-hidden` = "true", "\u2192"),
          div(style = "flex:2;",
            selectInput(ns(paste0("ttype_", tid)), sr_label("Target type"),
              choices  = TYPE_CHOICES,
              selected = cur_type,
              width    = "100%")),
          actionButton(ns(paste0("rmtc_", tid)), "",
            icon         = icon("xmark"),
            class        = "btn btn-xs btn-outline-danger",
            title        = "Remove type conversion",
            `aria-label` = "Remove type conversion",
            onclick      = ig_input_event_js(ns("remove_type_row"), tid))
        )
      })
      tagList(rows)
    })

    collect_p <- reactive({
      ids <- type_ids()
      changes <- lapply(ids, function(tid) {
        list(col  = input[[paste0("tcol_",  tid)]] %||% "",
             type = input[[paste0("ttype_", tid)]] %||% "character")
      })
      list(
        input_table  = input$input_table %||% "",
        type_changes = changes,
        output_name  = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })


    observeEvent(input$btn_preview, {
      p <- collect_p()
      result <- execute_change_types(p, isolate(store$tables))
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_change_types(p, isolate(store$tables))
      .dt_save(store, task_id, "change_types", p, p$input_table,
               result, build_changetype_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_changetype_code(collect_p()))
    output$run_status <- renderText(run_status_msg())
    .dt_render_preview(output, preview_df, session, store)
    store_register_result_fn(store, task_id, function(result) {
      preview_df(ig_preview_data(result$data)); run_status_msg(ig_preview_status(result))
    }, session = session)
    store_register_params_fn(store, task_id, collect_p, session = session)
    if (!is.null(task_id)) session$onFlushed(function() {
      store_register_runner(store, task_id, do_run)
    }, once = TRUE)
  })
}

execute_change_types <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  changes <- Filter(function(r) nzchar(r$col %||% "") && nzchar(r$type %||% ""),
                    p$type_changes %||% list())
  if (!length(changes)) return(list(data = NULL, error = "Add at least one type change."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  tryCatch({
    result <- df
    for (r in changes) {
      if (!r$col %in% names(result)) stop("Column not found: ", r$col)
      result[[r$col]] <- ig_convert_column(result[[r$col]], r$type)
    }
    list(data = result, error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_changetype_code <- function(p) {
  valid <- Filter(function(r) nzchar(r$col) && nzchar(r$type), p$type_changes %||% list())
  if (!length(valid)) return("")
  tbl  <- r_ident(p$input_table); out <- r_ident(p$output_name)
  exprs <- paste(vapply(valid, function(r)
    paste0(r_ident(r$col), " = .ig_convert_column(", r_ident(r$col), ", ", r_val(r$type, "character"), ")"),
    character(1)), collapse = ",\n  ")
  paste0("library(dplyr)\n.ig_convert_column <- ", paste(deparse(ig_convert_column), collapse = "\n"),
    "\n", out, " <- mutate(", tbl, ",\n  ", exprs, ")")
}

#' Convert an existing column using the task's supported storage types.
#' @keywords internal
#' @param type Registered task type identifier.
#' @param x Input value, column or nested configuration to transform.
ig_convert_column <- function(x, type) {
  if (type == "Date") {
    if (inherits(x, "Date")) return(x)
    chr <- as.character(x)
    formats <- c("%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y", "%Y/%m/%d",
      "%d-%m-%Y", "%m-%d-%Y", "%Y%m%d", "%d.%m.%Y")
    first <- chr[!is.na(chr) & nzchar(chr)]
    if (!length(first)) return(as.Date(rep(NA_character_, length(x))))
    for (format in formats) {
      if (!is.na(suppressWarnings(as.Date(first[[1]], format = format))))
        return(as.Date(chr, format = format))
    }
    stop("No supported date format matched the column.")
  }
  switch(type,
    numeric = as.numeric(as.character(x)),
    integer = as.integer(as.character(x)),
    character = as.character(x),
    logical = as.logical(toupper(trimws(as.character(x)))),
    factor = as.factor(x),
    stop("Unsupported column type: ", type))
}
