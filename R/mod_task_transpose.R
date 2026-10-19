# mod_task_transpose.R — Transpose
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_transpose_params <- function(output_name = "transpose_out") {
  list(input_table = NULL, id_col = NULL, output_name = output_name)
}

transpose_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "right-left", "Transpose", "transpose_out",
    p(class = "text-muted small mb-1",
      "Swap rows and columns using ", code("t()"), ". All non-ID columns are coerced to character."),
    selectInput(ns("input_table"), "Input table",
      choices = character(0), width = "100%"),
    selectInput(ns("id_col"), "Row ID column (optional \u2014 becomes column headers)",
      choices = character(0), width = "100%")
  )
}

transpose_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_transpose_params()
      else default_transpose_params(paste0(task_id %||% "transpose", "_out"))
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
      cur <- isolate(input$id_col) %||% ""
      updateSelectInput(session, "id_col",
        choices = c("(none)" = "", ci),
        selected = store_preserve_choice(cur, init_p$id_col, c("", ci), initialized = store_inputs_ready(store, task_id)))
    })

    collect_p <- reactive({
      list(
        input_table = input$input_table %||% "",
        id_col      = input$id_col %||% "",
        output_name = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })

    execute_transpose <- function(p) {
      tbl <- p$input_table
      if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
      df <- isolate(store_get_table(store, tbl))
      if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
      tryCatch({
        if (nzchar(p$id_col %||% "") && p$id_col %in% names(df)) {
          col_names <- as.character(df[[p$id_col]])
          mat <- t(as.matrix(df[, setdiff(names(df), p$id_col), drop = FALSE]))
          result <- as.data.frame(mat, stringsAsFactors = FALSE)
          names(result) <- col_names
        } else {
          result <- as.data.frame(t(df), stringsAsFactors = FALSE)
        }
        rownames(result) <- NULL
        list(data = result, error = NULL)
      }, error = function(e) list(data = NULL, error = conditionMessage(e)))
    }


    observeEvent(input$btn_preview, {
      result <- execute_transpose(collect_p())
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_transpose(p)
      .dt_save(store, task_id, "transpose", p, p$input_table,
               result, build_transpose_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_transpose_code(collect_p()))

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

execute_transpose <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  tryCatch({
    if (nzchar(p$id_col %||% "") && p$id_col %in% names(df)) {
      col_names <- as.character(df[[p$id_col]])
      mat    <- t(as.matrix(df[, setdiff(names(df), p$id_col), drop = FALSE]))
      result <- as.data.frame(mat, stringsAsFactors = FALSE)
      names(result) <- col_names
    } else {
      result <- as.data.frame(t(df), stringsAsFactors = FALSE)
    }
    rownames(result) <- NULL
    list(data = result, error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_transpose_code <- function(p) {
  tbl <- r_ident(p$input_table); out <- r_ident(p$output_name)
  if (nzchar(p$id_col %||% "")) {
    paste0(
      "col_nms <- as.character(", tbl, "[[", r_val(p$id_col, "character"), "]])\n",
      "mat <- t(as.matrix(", tbl, "[, setdiff(names(", tbl, "), ", r_val(p$id_col, "character"),
      "), drop = FALSE]))\n",
      out, " <- as.data.frame(mat, stringsAsFactors = FALSE)\n",
      "names(", out, ") <- col_nms\nrownames(", out, ") <- NULL"
    )
  } else {
    paste0(out, " <- as.data.frame(t(", tbl, "), stringsAsFactors = FALSE)\n",
           "rownames(", out, ") <- NULL")
  }
}
