# mod_task_stack_columns.R — Stack Columns (pivot longer)
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_stack_columns_params <- function(output_name = "stack_out") {
  list(input_table = NULL, cols = character(0),
       names_to = "variable", values_to = "value", output_name = output_name)
}

stack_columns_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "layer-group", "Stack Columns", "stack_out",
    p(class = "text-muted small mb-1",
      "Pivot wide \u2192 long using ", code("tidyr::pivot_longer()"), "."),
    selectInput(ns("input_table"), "Input table",
      choices = character(0), width = "100%"),
    selectInput(ns("cols"), "Columns to pivot (stack)",
      choices = character(0), multiple = TRUE, width = "100%"),
    bslib::layout_columns(
      col_widths = c(6, 6),
      textInput(ns("names_to"), "New names column", value = "variable", width = "100%"),
      textInput(ns("values_to"), "New values column", value = "value", width = "100%")
    )
  )
}

stack_columns_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_stack_columns_params()
      else default_stack_columns_params(paste0(task_id %||% "stack", "_out"))
    })
    run_status_msg <- reactiveVal("")
    preview_df     <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session, "output_name", value = init_p$output_name)
      updateTextInput(session, "names_to",    value = init_p$names_to  %||% "variable")
      updateTextInput(session, "values_to",   value = init_p$values_to %||% "value")
    }, once = TRUE)

    observe({
      tbls <- c("",store_available_tables(store, task_id = task_id))
      cur  <- isolate(input$input_table) %||% init_p$input_table %||% ""
      updateSelectInput(session, "input_table", choices = tbls,
        selected = if (cur %in% store_available_tables(store, task_id = task_id)) cur else "")
    })

    observe({
      tbl <- input$input_table; req(nzchar(tbl %||% ""))
      ci  <- store_col_schema(store, tbl)$column
      sel <- intersect(init_p$cols %||% character(0), ci)
      updateSelectInput(session, "cols", choices = ci, selected = sel)
    })

    collect_p <- reactive({
      list(
        input_table = input$input_table %||% "",
        cols        = input$cols %||% character(0),
        names_to    = trimws(input$names_to  %||% "variable"),
        values_to   = trimws(input$values_to %||% "value"),
        output_name = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })

    execute_stack <- function(p) {
      tbl <- p$input_table
      if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
      if (!length(p$cols)) return(list(data = NULL, error = "Select columns to pivot."))
      df <- isolate(store_get_table(store, tbl))
      if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
      tryCatch({
        result <- tidyr::pivot_longer(df, cols = p$cols,
          names_to = p$names_to, values_to = p$values_to)
        list(data = as.data.frame(result), error = NULL)
      }, error = function(e) list(data = NULL, error = conditionMessage(e)))
    }


    observeEvent(input$btn_preview, {
      result <- execute_stack(collect_p())
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_stack(p)
      .dt_save(store, task_id, "stack_columns", p, p$input_table,
               result, build_stack_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_stack_code(collect_p()))

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

execute_stack <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  if (!length(p$cols %||% character(0)))
    return(list(data = NULL, error = "Select columns to pivot."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  tryCatch({
    result <- tidyr::pivot_longer(df, cols = p$cols,
      names_to  = p$names_to  %||% "variable",
      values_to = p$values_to %||% "value")
    list(data = as.data.frame(result), error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_stack_code <- function(p) {
  cols_r <- paste0("c(", paste(vapply(p$cols, r_ident, character(1)), collapse = ", "), ")")
  paste0("library(tidyr)\n",
    r_ident(p$output_name), " <- pivot_longer(\n  ",
    r_ident(p$input_table), ",\n  cols = ", cols_r, ",\n  names_to = ",
    r_val(p$names_to, "character"), ",\n  values_to = ",
    r_val(p$values_to, "character"), "\n)")
}
