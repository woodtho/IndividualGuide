# mod_task_split_columns.R — Split Columns (pivot wider)
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_split_columns_params <- function(output_name = "split_out") {
  list(input_table = NULL, id_cols = character(0),
       names_from = NULL, values_from = NULL, output_name = output_name)
}

split_columns_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "table-columns", "Split Columns", "split_out",
    p(class = "text-muted small mb-1",
      "Pivot long \u2192 wide using ", code("tidyr::pivot_wider()"), "."),
    selectInput(ns("input_table"), "Input table",
      choices = character(0), width = "100%"),
    selectInput(ns("id_cols"), "ID columns (keep as rows)",
      choices = character(0), multiple = TRUE, width = "100%"),
    bslib::layout_columns(
      col_widths = c(6, 6),
      selectInput(ns("names_from"), "Names from (column whose values become headers)",
        choices = character(0), width = "100%"),
      selectInput(ns("values_from"), "Values from",
        choices = character(0), width = "100%")
    )
  )
}

split_columns_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_split_columns_params()
      else default_split_columns_params(paste0(task_id %||% "split", "_out"))
    })
    run_status_msg <- reactiveVal("")
    preview_df     <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session, "output_name", value = init_p$output_name)
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
      cur_id <- isolate(input$id_cols)
      cur_names <- isolate(input$names_from) %||% ""
      cur_values <- isolate(input$values_from) %||% ""
      updateSelectInput(session, "id_cols",
        choices = ci, selected = store_preserve_choices(cur_id,
          init_p$id_cols %||% character(0), ci, initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "names_from",
        choices = c("",ci), selected = store_preserve_choice(cur_names,
          init_p$names_from, c("", ci), initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "values_from",
        choices = c("",ci), selected = store_preserve_choice(cur_values,
          init_p$values_from, c("", ci), initialized = store_inputs_ready(store, task_id)))
    })

    collect_p <- reactive({
      list(
        input_table  = input$input_table %||% "",
        id_cols      = input$id_cols %||% character(0),
        names_from   = input$names_from %||% "",
        values_from  = input$values_from %||% "",
        output_name  = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })

    execute_split <- function(p) {
      tbl <- p$input_table
      if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
      if (!nzchar(p$names_from))  return(list(data = NULL, error = "Select the names_from column."))
      if (!nzchar(p$values_from)) return(list(data = NULL, error = "Select the values_from column."))
      df <- isolate(store_get_table(store, tbl))
      if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
      tryCatch({
        args <- list(data = df, names_from = p$names_from, values_from = p$values_from)
        if (length(p$id_cols)) args$id_cols <- p$id_cols
        result <- do.call(tidyr::pivot_wider, args)
        list(data = as.data.frame(result), error = NULL)
      }, error = function(e) list(data = NULL, error = conditionMessage(e)))
    }


    observeEvent(input$btn_preview, {
      result <- execute_split(collect_p())
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_split(p)
      .dt_save(store, task_id, "split_columns", p, p$input_table,
               result, build_split_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_split_code(collect_p()))

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

execute_split <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl))
    return(list(data = NULL, error = "Select an input table."))
  if (!nzchar(p$names_from  %||% ""))
    return(list(data = NULL, error = "Select the names_from column."))
  if (!nzchar(p$values_from %||% ""))
    return(list(data = NULL, error = "Select the values_from column."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  tryCatch({
    args <- list(data = df,
                 names_from  = p$names_from,
                 values_from = p$values_from)
    if (length(p$id_cols %||% character(0))) args$id_cols <- p$id_cols
    list(data = as.data.frame(do.call(tidyr::pivot_wider, args)), error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_split_code <- function(p) {
  id_str <- if (length(p$id_cols))
    paste0(",\n  id_cols = c(", paste(vapply(p$id_cols, r_ident, character(1)),
      collapse = ", "), ")") else ""
  paste0("library(tidyr)\n", r_ident(p$output_name), " <- pivot_wider(\n  ",
    r_ident(p$input_table), id_str,
    ",\n  names_from = ", r_val(p$names_from, "character"),
    ",\n  values_from = ", r_val(p$values_from, "character"), "\n)")
}
