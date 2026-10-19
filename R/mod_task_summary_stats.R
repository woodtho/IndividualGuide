# mod_task_summary_stats.R — Summary Statistics
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_summary_stats_params <- function(output_name = "summary_stats_out") {
  list(input_table = NULL, cols = character(0), output_name = output_name, output_enabled = TRUE)
}

summary_stats_ui <- function(id) {
  ns <- NS(id)
  .desc_task_shell(ns, "calculator", "Summary Statistics", "Analyze",
    results = task_preview_tabset(ns),
    selectInput(ns("input_table"), "Input table",
      choices = character(0), width = "100%"),
    selectInput(ns("cols"), "Numeric columns (blank = all numeric)",
      choices = character(0), multiple = TRUE, width = "100%"),
    output_save_ui(ns, "output_name", "Output table", placeholder = "summary_stats_out")
  )
}

summary_stats_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_summary_stats_params()
      else default_summary_stats_params(paste0(task_id %||% "summarystats", "_out"))
    })
    run_status_msg <- reactiveVal("")
    result_df      <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session,     "output_name",    value = init_p$output_name)
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
      num_cols <- ci$column[ci$class %in% c("numeric", "integer", "double")]
      cur <- isolate(input$cols)
      updateSelectInput(session, "cols", choices = num_cols,
        selected = store_preserve_choices(cur,
          init_p$cols %||% character(0), num_cols, initialized = store_inputs_ready(store, task_id)))
    })

    build_stats_df <- function(df, cols) {
      execute_summary_stats(list(input_table = "data", cols = cols), list(data = df))$data
    }

    do_run <- function() {
      tbl <- input$input_table %||% ""; req(nzchar(tbl))
      df <- isolate(store_get_table(store, tbl))
      if (is.null(df)) { run_status_msg("Table not found"); return() }
      cols <- input$cols %||% character(0)
      sdf  <- build_stats_df(df, cols)
      result_df(sdf)
      enabled <- isTRUE(input$output_enabled %||% TRUE)
      p <- list(input_table = tbl, cols = cols,
                output_name    = trimws(input$output_name %||% paste0(task_id, "_out")),
                output_enabled = enabled)
      run_status_msg(sprintf("\u2713 %d columns summarised%s", nrow(sdf),
        if (!enabled) " (not saved)" else ""))
      .desc_save(store, task_id, "summary_stats", p, tbl, sdf, build_stats_code(p),
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
      tryCatch(format_summary_stats_result(result_df()), error = function(e) NULL)
    })
    output$task_code_view <- renderText({
      p <- list(input_table = isolate(input$input_table) %||% "",
                cols        = isolate(input$cols) %||% character(0),
                output_name = isolate(input$output_name) %||% "")
      tryCatch(build_stats_code(p), error = function(e) "# configure the task first")
    })
  })
}

execute_summary_stats <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  cols <- p$cols %||% character(0)
  if (!length(cols)) cols <- names(df)[vapply(df, is.numeric, logical(1))]
  cols <- intersect(cols, names(df))
  cols <- cols[vapply(df[cols], is.numeric, logical(1))]
  if (!length(cols))
    return(list(data = data.frame(message = "No numeric columns selected."), error = NULL))
  qs <- function(x, prob) quantile(x, prob, na.rm = TRUE)
  stats <- lapply(cols, function(col) {
    x  <- df[[col]]
    n  <- sum(!is.na(x)); mu <- mean(x, na.rm = TRUE); s <- sd(x, na.rm = TRUE)
    data.frame(
      column   = col,
      n        = n, n_miss = sum(is.na(x)),
      mean     = round(mu, 4), sd = round(s, 4),
      min      = round(qs(x, 0),   4), q25    = round(qs(x, .25), 4),
      median   = round(qs(x, .5),  4), q75    = round(qs(x, .75), 4),
      max      = round(qs(x, 1),   4),
      skewness = round(tryCatch(
        if (s == 0) NA_real_ else mean(((x - mu) / s)^3, na.rm = TRUE),
        error = function(e) NA_real_), 4),
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, stats)
  rownames(result) <- NULL
  list(data = result, error = NULL)
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_stats_code <- function(p) {
  helper <- "summarise_numeric_columns"
  paste(c(code_helper_definitions(helper, overrides = stats::setNames(list(ig_code_summary_statistics), helper)),
    paste0(r_ident(p$output_name), " <- .ig_codegen$", helper, "(", r_ident(p$input_table),
      if (length(p$cols)) paste0(", columns = ", code_literal(p$cols)) else "", ")")), collapse = "\n")
}
