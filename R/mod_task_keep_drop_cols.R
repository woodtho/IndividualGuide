# mod_task_keep_drop_cols.R — Keep / Drop Columns
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_keep_drop_params <- function(output_name = "select_out") {
  list(input_table = NULL, action = "keep", cols = character(0), output_name = output_name)
}

keep_drop_cols_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "table-columns", "Keep / Drop Columns", "select_out",
    p(class = "text-muted small mb-1",
      "Keep or remove a set of columns using ", code("dplyr::select()"), "."),
    selectInput(ns("input_table"), "Input table", choices = character(0), width = "100%"),
    radioButtons(ns("action"), "Action",
      choices  = c("Keep selected columns" = "keep", "Drop selected columns" = "drop"),
      selected = "keep", inline = TRUE),
    selectInput(ns("cols"), "Columns",
      choices = character(0), multiple = TRUE, width = "100%")
  )
}

keep_drop_cols_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_keep_drop_params()
      else default_keep_drop_params(paste0(task_id %||% "keepdrop", "_out"))
    })
    run_status_msg <- reactiveVal(""); preview_df <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session,    "output_name", value = init_p$output_name)
      updateRadioButtons(session, "action",      selected = init_p$action %||% "keep")
    }, once = TRUE)

    observe({
      tbls <- c("", store_available_tables(store, task_id = task_id))
      cur  <- isolate(input$input_table) %||% init_p$input_table %||% ""
      updateSelectInput(session, "input_table", choices = tbls,
        selected = if (cur %in% store_available_tables(store, task_id = task_id)) cur else "")
    })

    observe({
      tbl <- input$input_table; req(nzchar(tbl %||% ""))
      ci  <- store_col_schema(store, tbl)
      cur <- isolate(input$cols)
      updateSelectInput(session, "cols", choices = ci$column,
        selected = store_preserve_choices(cur,
          init_p$cols %||% character(0), ci$column, initialized = store_inputs_ready(store, task_id)))
    })

    collect_p <- reactive({
      list(
        input_table = input$input_table %||% "",
        action      = input$action %||% "keep",
        cols        = input$cols %||% character(0),
        output_name = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })


    observeEvent(input$btn_preview, {
      p <- collect_p()
      result <- execute_keep_drop(p, isolate(store$tables))
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_keep_drop(p, isolate(store$tables))
      .dt_save(store, task_id, "keep_drop_cols", p, p$input_table,
               result, build_keepdrop_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_keepdrop_code(collect_p()))
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

execute_keep_drop <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  if (!length(p$cols %||% character(0)))
    return(list(data = NULL, error = "Select at least one column."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  tryCatch({
    result <- if (identical(p$action %||% "keep", "keep"))
      dplyr::select(df, dplyr::all_of(p$cols))
    else
      dplyr::select(df, -dplyr::all_of(p$cols))
    list(data = as.data.frame(result), error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_keepdrop_code <- function(p) {
  tbl <- r_ident(p$input_table); out <- r_ident(p$output_name)
  cols_r <- paste0("c(", paste(vapply(p$cols, r_val, character(1), col_class = "character"), collapse = ", "), ")")
  sel_expr <- if (identical(p$action, "keep"))
    paste0("select(", tbl, ", all_of(", cols_r, "))")
  else
    paste0("select(", tbl, ", -all_of(", cols_r, "))")
  paste0("library(dplyr)\n", out, " <- ", sel_expr)
}
