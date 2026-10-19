# mod_task_table_analysis.R — Table Analysis
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_table_analysis_params <- function(output_name = "table_analysis_out") {
  list(input_table = NULL, row_col = NULL, col_col = NULL,
       show_pct = "none", output_name = output_name, output_enabled = TRUE,
       output_chi = paste0(output_name, "_chisq"), output_chi_enabled = TRUE)
}

table_analysis_ui <- function(id) {
  ns <- NS(id)
  .desc_task_shell(ns, "table", "Table Analysis", "Analyze",
    results = tagList(
      conditionalPanel(
        condition = sprintf("!output['%s']", ns("result_visible")),
        .dt_results_placeholder()),
      conditionalPanel(
        condition = sprintf("output['%s']", ns("result_visible")),
        bslib::navset_tab(
          id = ns("result_tabs"),
          bslib::nav_panel(tagList(icon("chart-bar"), " Results"), value = "Results",
            div(class = "ig-result-panel ig-formatted-results",
              ig_gt_output(ns("result_gt")),
              div(class = "mt-3", ig_gt_output(ns("chisq_gt"))))),
          bslib::nav_panel(tagList(icon("table"), " Data"), value = "Data",
            div(class = "ig-result-panel",
              h6(class = "px-3 pt-2 text-muted small", "Contingency table"),
              DT::DTOutput(ns("result_dt")))),
          bslib::nav_panel(tagList(icon("code"), " Code"), value = "Code",
            div(class = "ig-result-panel ig-code-panel",
              verbatimTextOutput(ns("task_code_view"))))
        ))
    ),
    selectInput(ns("input_table"), "Input table",
      choices = character(0), width = "100%"),
    bslib::layout_columns(
      col_widths = c(4, 4, 4),
      selectInput(ns("row_col"), "Row variable",
        choices = character(0), width = "100%"),
      selectInput(ns("col_col"), "Column variable",
        choices = character(0), width = "100%"),
      selectInput(ns("show_pct"), "Show percentages",
        choices = c("Counts only" = "none", "Row %" = "row",
                    "Column %" = "col", "Total %" = "total"),
        width = "100%")
    ),
    bslib::layout_columns(
      col_widths = c(6, 6),
      output_save_ui(ns, "output_name", "Contingency table",
                     placeholder = "table_analysis_out"),
      output_save_ui(ns, "output_chi", "Chi-square stats",
                     placeholder = "table_analysis_chisq", toggle_id = "output_chi_enabled")
    )
  )
}

table_analysis_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_table_analysis_params()
      else default_table_analysis_params(paste0(task_id %||% "tableanalysis", "_out"))
    })
    run_status_msg <- reactiveVal("")
    result_df      <- reactiveVal(NULL)
    display_df     <- reactiveVal(NULL)
    chisq_result   <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session,     "output_name",        value = init_p$output_name)
      updateTextInput(session,     "output_chi",         value = init_p$output_chi %||%
                                                           paste0(init_p$output_name, "_chisq"))
      updateSelectInput(session,   "show_pct",           selected = init_p$show_pct %||% "none")
      updateCheckboxInput(session, "output_enabled",     value = isTRUE(init_p$output_enabled %||% TRUE))
      updateCheckboxInput(session, "output_chi_enabled", value = isTRUE(init_p$output_chi_enabled %||% TRUE))
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
      cur_row <- isolate(input$row_col) %||% ""
      cur_col <- isolate(input$col_col) %||% ""
      updateSelectInput(session, "row_col", choices = c("",ci),
        selected = store_preserve_choice(cur_row, init_p$row_col, c("", ci), initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "col_col", choices = c("",ci),
        selected = store_preserve_choice(cur_col, init_p$col_col, c("", ci), initialized = store_inputs_ready(store, task_id)))
    })


    do_run <- function() {
      p <- collect_p()
      tables <- setNames(list(isolate(store_get_table(store, p$input_table))), p$input_table)
      result <- execute_table_analysis(p, tables)
      if (!is.null(result$error)) {
        run_status_msg(paste("Error:", result$error))
        showNotification(result$error, type = "error", duration = 8)
        return(store_task_failed(store, task_id, result$error))
      }
      result_df(result$data)
      display_df(result$display)
      chisq_result(result$test)
      specs <- list()
      enabled <- !identical(p$output_enabled, FALSE)
      if (enabled && nzchar(p$output_name)) specs <- list(list(name = p$output_name, kind = "table"))
      if (isTRUE(p$output_chi_enabled) && nzchar(p$output_chi) && !is.null(result$chi_table)) {
        store_add_table(store, p$output_chi, result$chi_table)
        specs <- c(specs, list(list(name = p$output_chi, kind = "table", label = "Chi-square test")))
      }
      ig_log_result(result)
      if (length(result$warnings)) showNotification(paste(result$warnings, collapse = " | "), type = "warning", duration = 8)
      run_status_msg(sprintf("\u2713 %d rows \u00d7 %d cols", nrow(result$data), ncol(result$data)))
      .desc_save(store, task_id, "table_analysis", p, p$input_table, result$data,
        build_table_analysis_code(p), run_status_msg, enabled = enabled, output_specs = specs)
      .desc_goto_results(session)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    collect_p <- reactive(.desc_collect_params(input, init_p))
    store_register_result_fn(store, task_id, function(result) {
      result_df(result$data); display_df(result$display); chisq_result(result$test); run_status_msg(ig_preview_status(result))
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
        options = list(scrollX = TRUE, pageLength = ig_page_len(store), dom = "tip"))
    })

    output$result_gt <- ig_render_gt({
      req(result_df())
      tryCatch({
        d <- display_df() %||% result_df()
        pct <- input$show_pct %||% "none"
        table <- gt::gt(d, rownames_to_stub = TRUE) |>
          gt::tab_header(title = switch(pct, row = "Row percentages (%)", col = "Column percentages (%)", total = "Total percentages (%)", "Contingency Table"))
        if (pct == "none") {
          table <- table |> gt::fmt_integer(columns = dplyr::everything()) |> gt::grand_summary_rows(
            columns  = dplyr::everything(),
            fns      = list(Total = ~ sum(.)),
            fmt      = list(~ gt::fmt_integer(.))
          )
        } else table <- gt::fmt_number(table, columns = dplyr::everything(), decimals = 2)
        table |> gt::tab_style(
            style     = gt::cell_text(weight = "bold"),
            locations = gt::cells_stub()
          ) |>
          ig_gt_theme()
      }, error = function(e) NULL)
    })

    output$chisq_gt <- ig_render_gt({
      chi <- chisq_result(); req(!is.null(chi), is.null(chi$error))
      tryCatch(format_chisq_result(chi), error = function(e) NULL)
    })

    output$task_code_view <- renderText({
      p <- collect_p()
      tryCatch(build_table_analysis_code(p), error = function(e) "# configure the task first")
    })
  })
}

execute_table_analysis <- function(p, tables) {
  tbl <- p$input_table %||% ""
  rc  <- p$row_col %||% ""; cc <- p$col_col %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  if (!nzchar(rc) || !nzchar(cc))
    return(list(data = NULL, error = "Select row and column variables."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  if (!rc %in% names(df) || !cc %in% names(df))
    return(list(data = NULL, error = "Column not found."))
  ct  <- table(df[[rc]], df[[cc]])
  pct <- p$show_pct %||% "none"
  if (!pct %in% c("none", "row", "col", "total")) return(list(error = "Unsupported percentage display."))
  display <- switch(pct, row = prop.table(ct, 1) * 100, col = prop.table(ct, 2) * 100,
    total = prop.table(ct) * 100, ct)
  warnings <- character(0)
  test <- tryCatch(withCallingHandlers(stats::chisq.test(ct), warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  }), error = function(e) list(error = conditionMessage(e)))
  chi_table <- if (is.null(test$error)) data.frame(statistic = unname(test$statistic),
    df = unname(test$parameter), p_value = test$p.value, method = test$method, stringsAsFactors = FALSE) else NULL
  if (!is.null(test$error)) warnings <- c(warnings, paste("Chi-square test unavailable:", test$error))
  list(data = as.data.frame.matrix(ct), display = as.data.frame.matrix(display),
    test = test, chi_table = chi_table, warnings = warnings, error = NULL)
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_table_analysis_code <- function(p) {
  tbl <- r_ident(p$input_table); out <- r_ident(p$output_name)
  rc  <- r_val(p$row_col, "character"); cc <- r_val(p$col_col, "character")
  paste0(
    "ct <- table(", tbl, "[[", rc, "]], ", tbl, "[[", cc, "]])\n",
    out, " <- as.data.frame.matrix(ct)\n",
    ".table_test <- tryCatch(stats::chisq.test(ct), error = function(e) { warning(conditionMessage(e)); NULL })\n",
    if (isTRUE(p$output_chi_enabled) && nzchar(p$output_chi %||% "")) paste0(
      "if (!is.null(.table_test)) ", r_ident(p$output_chi), " <- data.frame(statistic = unname(.table_test$statistic), df = unname(.table_test$parameter), p_value = .table_test$p.value, method = .table_test$method, stringsAsFactors = FALSE)\n") else "",
    switch(p$show_pct %||% "none", row = ".table_display <- prop.table(ct, 1) * 100", col = ".table_display <- prop.table(ct, 2) * 100", total = ".table_display <- prop.table(ct) * 100", ".table_display <- ct")
  )
}
