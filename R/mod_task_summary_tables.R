# mod_task_summary_tables.R — Summary Tables
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_summary_tables_params <- function(output_name = "summary_tbl_out") {
  list(input_table = NULL, row_var = NULL, col_var = NULL,
       value_var = NULL, stat_fn = "mean", output_name = output_name, output_enabled = TRUE)
}

summary_tables_ui <- function(id) {
  ns <- NS(id)
  .desc_task_shell(ns, "table-cells", "Summary Tables", "Analyze",
    results = task_preview_tabset(ns),
    p(class = "text-muted small mb-1",
      "Cross-tabulate a numeric measure by row and column grouping variables."),
    selectInput(ns("input_table"), "Input table",
      choices = character(0), width = "100%"),
    bslib::layout_columns(
      col_widths = c(4, 4, 4),
      selectInput(ns("row_var"), "Row variable",
        choices = character(0), width = "100%"),
      selectInput(ns("col_var"), "Column variable (optional)",
        choices = character(0), width = "100%"),
      selectInput(ns("value_var"), "Value variable",
        choices = character(0), width = "100%")
    ),
    bslib::layout_columns(
      col_widths = 4,
      selectInput(ns("stat_fn"), "Summary statistic",
        choices = SUMMARY_TABLE_STATS, width = "100%")
    ),
    output_save_ui(ns, "output_name", "Output table", placeholder = "summary_tbl_out")
  )
}

summary_tables_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_summary_tables_params()
      else default_summary_tables_params(paste0(task_id %||% "summarytables", "_out"))
    })
    run_status_msg <- reactiveVal("")
    result_df      <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session,     "output_name",    value = init_p$output_name)
      updateSelectInput(session,   "stat_fn",        selected = init_p$stat_fn %||% "mean")
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
      ci  <- store_col_schema(store, tbl)
      all_cols <- ci$column
      num_cols <- ci$column[ci$class %in% c("numeric", "integer", "double")]
      cur_row <- isolate(input$row_var) %||% ""
      cur_col <- isolate(input$col_var) %||% ""
      cur_val <- isolate(input$value_var) %||% ""
      updateSelectInput(session, "row_var",   choices = c("",all_cols),
        selected = store_preserve_choice(cur_row, init_p$row_var, c("", all_cols), initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "col_var",   choices = c("(none)" = "", all_cols),
        selected = store_preserve_choice(cur_col, init_p$col_var, c("", all_cols), initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "value_var", choices = c("",num_cols),
        selected = store_preserve_choice(cur_val, init_p$value_var, c("", num_cols), initialized = store_inputs_ready(store, task_id)))
    })

    execute_summary_table <- function(p) {
      tbl <- p$input_table
      if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
      if (!nzchar(p$row_var %||% "")) return(list(data = NULL, error = "Select a row variable."))
      df <- isolate(store_get_table(store, tbl))
      if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
      tryCatch({
        stat_fn <- switch(p$stat_fn,
          mean = function(x) mean(x, na.rm = TRUE),
          sum  = function(x) sum(x, na.rm = TRUE),
          median = function(x) median(x, na.rm = TRUE),
          n    = length,
          min  = function(x) min(x, na.rm = TRUE),
          max  = function(x) max(x, na.rm = TRUE),
          sd   = function(x) sd(x, na.rm = TRUE),
          mean
        )
        if (nzchar(p$col_var %||% "") && nzchar(p$value_var %||% "")) {
          ct <- tapply(df[[p$value_var]], list(df[[p$row_var]], df[[p$col_var]]), stat_fn)
          result <- as.data.frame(ct)
          result <- cbind(setNames(data.frame(rownames(result)), p$row_var), result)
          rownames(result) <- NULL
        } else if (nzchar(p$value_var %||% "")) {
          vals <- tapply(df[[p$value_var]], df[[p$row_var]], stat_fn)
          stat_col_name <- paste0(p$stat_fn, "_", p$value_var)
          result <- data.frame(setNames(list(names(vals)), p$row_var),
                               setNames(list(as.numeric(vals)), stat_col_name),
                               stringsAsFactors = FALSE)
        } else {
          ct <- table(df[[p$row_var]])
          result <- data.frame(setNames(list(names(ct)), p$row_var),
                               n = as.integer(ct), stringsAsFactors = FALSE)
        }
        list(data = result, error = NULL)
      }, error = function(e) list(data = NULL, error = conditionMessage(e)))
    }


    do_run <- function() {
      p <- list(
        input_table = input$input_table %||% "",
        row_var     = input$row_var %||% "",
        col_var     = input$col_var %||% "",
        value_var   = input$value_var %||% "",
        stat_fn     = input$stat_fn %||% "mean",
        output_name = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
      result <- execute_summary_table(p)
      if (!is.null(result$error)) {
        showNotification(result$error, type = "error", duration = 8)
        run_status_msg(paste("Error:", result$error))
        return()
      }
      result_df(result$data)
      enabled <- isTRUE(input$output_enabled %||% TRUE)
      p$output_enabled <- enabled
      run_status_msg(sprintf("\u2713 %d rows \u00d7 %d cols%s", nrow(result$data), ncol(result$data),
        if (!enabled) " (not saved)" else ""))
      .desc_save(store, task_id, "summary_tables", p, p$input_table,
                 result$data, build_st_code(p), run_status_msg, enabled = enabled)
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
      tryCatch(format_summary_stats_result(result_df()), error = function(e) NULL)
    })
    output$task_code_view <- renderText({
      p <- list(input_table = isolate(input$input_table) %||% "",
                row_var     = isolate(input$row_var)   %||% "",
                col_var     = isolate(input$col_var)   %||% "",
                value_var   = isolate(input$value_var) %||% "",
                stat_fn     = isolate(input$stat_fn)   %||% "mean",
                output_name = isolate(input$output_name) %||% "")
      tryCatch(build_st_code(p), error = function(e) "# configure the task first")
    })
  })
}

# Top-level version (modules define their own local version that closes over store)
execute_summary_table <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl))               return(list(data = NULL, error = "Select an input table."))
  if (!nzchar(p$row_var %||% "")) return(list(data = NULL, error = "Select a row variable."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  tryCatch({
    stat_fn <- switch(p$stat_fn %||% "mean",
      mean   = function(x) mean(x, na.rm = TRUE),
      sum    = function(x) sum(x,  na.rm = TRUE),
      median = function(x) median(x, na.rm = TRUE),
      n      = length,
      min    = function(x) min(x, na.rm = TRUE),
      max    = function(x) max(x, na.rm = TRUE),
      sd     = function(x) sd(x,  na.rm = TRUE),
      mean
    )
    if (nzchar(p$col_var %||% "") && nzchar(p$value_var %||% "")) {
      ct     <- tapply(df[[p$value_var]], list(df[[p$row_var]], df[[p$col_var]]), stat_fn)
      result <- as.data.frame(ct)
      result <- cbind(setNames(data.frame(rownames(result)), p$row_var), result)
      rownames(result) <- NULL
    } else if (nzchar(p$value_var %||% "")) {
      vals          <- tapply(df[[p$value_var]], df[[p$row_var]], stat_fn)
      stat_col_name <- paste0(p$stat_fn %||% "mean", "_", p$value_var)
      result <- data.frame(
        setNames(list(names(vals)),        p$row_var),
        setNames(list(as.numeric(vals)),   stat_col_name),
        stringsAsFactors = FALSE
      )
    } else {
      ct     <- table(df[[p$row_var]])
      result <- data.frame(
        setNames(list(names(ct)),       p$row_var),
        n = as.integer(ct),
        stringsAsFactors = FALSE
      )
    }
    list(data = result, error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_st_code <- function(p) {
  tbl <- r_ident(p$input_table); out <- r_ident(p$output_name)
  rv  <- r_val(p$row_var, "character")
  value <- p$value_var %||% ""
  column <- p$col_var %||% ""
  fn <- p$stat_fn %||% "mean"
  summary <- if (fn == "n") "length" else paste0("function(x) ", fn, "(x, na.rm = TRUE)")
  if (nzchar(value) && nzchar(column)) {
    return(paste0(".summary <- tapply(", tbl, "[[", r_val(value, "character"), "]], list(",
      tbl, "[[", rv, "]], ", tbl, "[[", r_val(column, "character"), "]]), ", summary, ")\n",
      ".summary <- as.data.frame(.summary)\n", out,
      " <- cbind(setNames(data.frame(rownames(.summary)), ", rv, "), .summary)\nrownames(", out, ") <- NULL"))
  }
  if (nzchar(value)) {
    return(paste0(".summary <- tapply(", tbl, "[[", r_val(value, "character"), "]], ", tbl, "[[", rv, "]], ", summary, ")\n",
      out, " <- data.frame(setNames(list(names(.summary)), ", rv, "), setNames(list(as.numeric(.summary)), ",
      r_val(paste0(fn, "_", value), "character"), "), stringsAsFactors = FALSE)"))
  }
  paste0(".summary <- table(", tbl, "[[", rv, "]])\n", out,
    " <- data.frame(setNames(list(names(.summary)), ", rv, "), n = as.integer(.summary), stringsAsFactors = FALSE)")
}
