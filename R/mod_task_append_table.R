# mod_task_append_table.R — Append Table
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_append_table_params <- function(output_name = "append_out") {
  list(
    input_tables = character(0),
    table_names = list(),
    id_col = "",
    fill = FALSE,
    output_name = output_name
  )
}

append_table_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "table", "Append Table", "append_out",
    p(class = "text-muted small mb-1",
      "Stack two or more tables row-wise using ", code("dplyr::bind_rows()"), "."),
    selectInput(ns("input_tables"), "Tables to append",
      choices = character(0), multiple = TRUE, width = "100%"),
    textInput(ns("id_col"), "Source ID column (.id)",
      value = "", placeholder = "Leave blank to omit"),
    uiOutput(ns("table_names_ui")),
    checkboxInput(ns("fill"), "Fill missing columns with NA", value = FALSE)
  )
}

append_table_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_append_table_params()
      else default_append_table_params(paste0(task_id %||% "append", "_out"))
    })
    run_status_msg <- reactiveVal("")
    preview_df     <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session, "output_name", value = init_p$output_name)
      updateTextInput(session, "id_col", value = init_p$id_col %||% "")
      updateCheckboxInput(session, "fill", value = isTRUE(init_p$fill))
    }, once = TRUE)

    observe({
      tbls <- store_available_tables(store, task_id = task_id)
      sel  <- store_preserve_choices(isolate(input$input_tables),
        init_p$input_tables %||% character(0), tbls, initialized = store_inputs_ready(store, task_id))
      updateSelectInput(session, "input_tables", choices = tbls, selected = sel)
    })

    output$table_names_ui <- renderUI({
      tbls <- input$input_tables %||% character(0)
      if (!length(tbls)) return(NULL)
      saved <- init_p$table_names %||% list()
      div(class = "ig-function-palette mt-2",
        tags$strong(class = "small d-block mb-2", "Source ID values"),
        tagList(lapply(seq_along(tbls), function(i) {
          nm <- tbls[[i]]
          textInput(session$ns(paste0("table_name_", i)),
            label = nm,
            value = saved[[nm]] %||% nm,
            width = "100%")
        }))
      )
    })

    append_table_labels <- reactive({
      tbls <- input$input_tables %||% character(0)
      vals <- lapply(seq_along(tbls), function(i) {
        val <- trimws(input[[paste0("table_name_", i)]] %||% "")
        if (!nzchar(val)) val <- tbls[[i]]
        val
      })
      names(vals) <- tbls
      vals
    })

    collect_p <- reactive({
      list(
        input_tables = input$input_tables %||% character(0),
        table_names  = append_table_labels(),
        id_col       = trimws(input$id_col %||% ""),
        fill         = isTRUE(input$fill),
        output_name  = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })

    execute_append <- function(p) {
      tbls <- p$input_tables
      if (length(tbls) < 2L) return(list(data = NULL, error = "Select at least two tables."))
      miss <- setdiff(tbls, names(isolate(store$tables)))
      if (length(miss)) return(list(data = NULL, error = paste("Not found:", paste(miss, collapse = ", "))))
      tryCatch({
        df_list <- lapply(tbls, function(nm) store_get_table(store, nm))
        labels <- unlist(p$table_names %||% list(), use.names = FALSE)
        if (length(labels) == length(df_list)) names(df_list) <- labels
        args <- df_list
        if (nzchar(p$id_col %||% "")) args$.id <- p$id_col
        list(data = do.call(dplyr::bind_rows, args), error = NULL)
      }, error = function(e) list(data = NULL, error = conditionMessage(e)))
    }


    observeEvent(input$btn_preview, {
      result <- execute_append(collect_p())
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_append(p)
      .dt_save(store, task_id, "append_table", p, p$input_tables,
               result, build_append_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_append_code(collect_p()))

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

execute_append <- function(p, tables) {
  tbls <- p$input_tables %||% character(0)
  if (length(tbls) < 2L)
    return(list(data = NULL, error = "Select at least two tables."))
  miss <- setdiff(tbls, names(tables))
  if (length(miss))
    return(list(data = NULL, error = paste("Not found:", paste(miss, collapse = ", "))))
  tryCatch({
    df_list <- lapply(tbls, function(nm) tables[[nm]])
    # Match the panel behaviour: honour custom source labels and the .id column
    labels <- unlist(p$table_names %||% list(), use.names = FALSE)
    if (length(labels) == length(df_list)) names(df_list) <- labels
    args <- df_list
    if (nzchar(p$id_col %||% "")) args$.id <- p$id_col
    list(data = do.call(dplyr::bind_rows, args), error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_append_code <- function(p) {
  tbls <- p$input_tables %||% character(0)
  if (nzchar(p$id_col %||% "")) {
    labels <- unlist(p$table_names %||% list(), use.names = FALSE)
    if (length(labels) != length(tbls)) labels <- tbls
    paste0(
      "library(dplyr)\n",
      r_ident(p$output_name), " <- bind_rows(\n",
      "  setNames(list(\n    ",
      paste(vapply(tbls, r_ident, character(1)), collapse = ",\n    "),
      "\n  ), c(",
      paste(vapply(labels, r_val, character(1), col_class = "character"), collapse = ", "),
      ")),\n",
      "  .id = ", r_val(p$id_col, "character"), "\n",
      ")"
    )
  } else {
    tbl_code <- paste(vapply(tbls, r_ident, character(1)), collapse = ",\n  ")
    paste0("library(dplyr)\n", r_ident(p$output_name), " <- bind_rows(\n  ", tbl_code, "\n)")
  }
}
