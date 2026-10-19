# mod_task_one_way_freq.R — One-Way Frequencies
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_one_way_freq_params <- function(output_name = "freq_out") {
  list(input_table = NULL, col = NULL, sort_desc = TRUE, output_name = output_name, output_enabled = TRUE)
}

one_way_freq_ui <- function(id) {
  ns <- NS(id)
  .desc_task_shell(ns, "percent", "One-Way Frequencies", "Analyze",
    results = task_preview_tabset(ns),
    bslib::layout_columns(
      col_widths = c(5, 4, 3),
      selectInput(ns("input_table"), "Input table",
        choices = character(0), width = "100%"),
      selectInput(ns("col"), "Variable",
        choices = character(0), width = "100%"),
      div(class = "pt-4",
        checkboxInput(ns("sort_desc"), "Sort by frequency", value = TRUE))
    ),
    output_save_ui(ns, "output_name", "Output table", placeholder = "freq_out")
  )
}

one_way_freq_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_one_way_freq_params()
      else default_one_way_freq_params(paste0(task_id %||% "freq", "_out"))
    })
    run_status_msg <- reactiveVal("")
    result_df      <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session,     "output_name",    value = init_p$output_name)
      updateCheckboxInput(session, "sort_desc",      value = isTRUE(init_p$sort_desc))
      updateCheckboxInput(session, "output_enabled", value = isTRUE(init_p$output_enabled %||% TRUE))
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
      cur <- isolate(input$col) %||% ""
      updateSelectInput(session, "col", choices = c("",ci),
        selected = store_preserve_choice(cur, init_p$col, c("", ci), initialized = store_inputs_ready(store, task_id)))
    })

    build_freq_df <- function(df, col, sort_desc) {
      x   <- df[[col]]
      tbl <- as.data.frame(table(x, useNA = "ifany"), stringsAsFactors = FALSE)
      names(tbl) <- c(col, "n")
      total <- sum(tbl$n)
      tbl$percent     <- round(tbl$n / total * 100, 2)
      tbl$cum_percent <- round(cumsum(tbl$percent), 2)
      if (isTRUE(sort_desc)) tbl <- tbl[order(-tbl$n), ]
      tbl$cum_percent <- round(cumsum(tbl$percent), 2)  # recalc after sort
      rownames(tbl) <- NULL
      tbl
    }


    do_run <- function() {
      tbl <- input$input_table %||% ""; col <- input$col %||% ""
      req(nzchar(tbl), nzchar(col))
      df <- isolate(store_get_table(store, tbl))
      if (is.null(df)) { run_status_msg("Table not found"); return() }
      if (!col %in% names(df)) { run_status_msg(paste("Column not found:", col)); return() }
      fdf <- build_freq_df(df, col, input$sort_desc)
      result_df(fdf)
      enabled <- isTRUE(input$output_enabled %||% TRUE)
      p <- list(input_table = tbl, col = col, sort_desc = isTRUE(input$sort_desc),
                output_name    = trimws(input$output_name %||% paste0(task_id, "_out")),
                output_enabled = enabled)
      run_status_msg(sprintf("\u2713 %d levels%s", nrow(fdf), if (!enabled) " (not saved)" else ""))
      .desc_save(store, task_id, "one_way_freq", p, tbl, fdf, build_freq_code(p),
                 run_status_msg, enabled = enabled)
      .desc_goto_results(session)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    collect_p <- reactive(.desc_collect_params(input, init_p))
    store_register_result_fn(store, task_id, function(result) {
      result_df(result$data); run_status_msg(ig_preview_status(result))
    }, session = session)
    store_register_params_fn(store, task_id, collect_p, session = session)
    if (!is.null(task_id)) session$onFlushed(function() {
      store_register_runner(store, task_id, do_run)
    }, once = TRUE)

    output$run_status <- renderText(run_status_msg())
    register_preview_visible(output, run_status_msg)
    output$result_dt  <- DT::renderDT({
      req(result_df())
      DT::datatable(result_df(),
        options = list(scrollX = TRUE, pageLength = ig_page_len(store), dom = "tip"),
        rownames = FALSE)
    })
    output$result_gt <- ig_render_gt({
      req(result_df())
      col_name <- isolate(input$col) %||% NULL
      tryCatch(format_freq_result(result_df(), col_name), error = function(e) NULL)
    })
    output$task_code_view <- renderText({
      p <- list(input_table = isolate(input$input_table) %||% "",
                col         = isolate(input$col) %||% "",
                sort_desc   = isTRUE(isolate(input$sort_desc)),
                output_name = isolate(input$output_name) %||% "")
      tryCatch(build_freq_code(p), error = function(e) "# configure the task first")
    })
  })
}

execute_one_way_freq <- function(p, tables) {
  tbl <- p$input_table %||% ""; col <- p$col %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  if (!nzchar(col)) return(list(data = NULL, error = "Select a variable."))
  df <- tables[[tbl]]
  if (is.null(df))         return(list(data = NULL, error = paste("Table not found:", tbl)))
  if (!col %in% names(df)) return(list(data = NULL, error = paste("Column not found:", col)))
  x       <- df[[col]]
  tbl_out <- as.data.frame(table(x, useNA = "ifany"), stringsAsFactors = FALSE)
  names(tbl_out) <- c(col, "n")
  total          <- sum(tbl_out$n)
  tbl_out$percent <- round(tbl_out$n / total * 100, 2)
  if (isTRUE(p$sort_desc)) tbl_out <- tbl_out[order(-tbl_out$n), ]
  tbl_out$cum_percent <- round(cumsum(tbl_out$percent), 2)
  rownames(tbl_out) <- NULL
  list(data = tbl_out, error = NULL)
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_freq_code <- function(p) {
  tbl <- r_ident(p$input_table); col <- r_val(p$col, "character")
  out <- r_ident(p$output_name)
  sort_str <- if (isTRUE(p$sort_desc)) "\n.tbl <- .tbl[order(-.tbl$n), , drop = FALSE]\nrownames(.tbl) <- NULL" else ""
  paste0(
    ".tbl <- as.data.frame(table(", tbl, "[[", col, "]], useNA = 'ifany'), stringsAsFactors = FALSE)\n",
    "names(.tbl) <- c(", col, ", 'n')\n",
    ".tbl$percent <- round(.tbl$n / sum(.tbl$n) * 100, 2)", sort_str, "\n",
    ".tbl$cum_percent <- round(cumsum(.tbl$percent), 2)\n",
    out, " <- .tbl"
  )
}
