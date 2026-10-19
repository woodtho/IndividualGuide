# mod_task_characterize.R — Characterize Data
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_characterize_params <- function(output_name = "characterize_out") {
  list(input_table = NULL, output_name = output_name, output_enabled = TRUE)
}

characterize_data_ui <- function(id) {
  ns <- NS(id)
  .desc_task_shell(ns, "magnifying-glass", "Characterize Data", "Analyze",
    results = task_preview_tabset(ns),
    selectInput(ns("input_table"), "Input table",
      choices = character(0), width = "100%"),
    p(class = "text-muted small mb-1",
      "Column types, missingness, distinct counts, and sample values for every column."),
    output_save_ui(ns, "output_name", "Output table", placeholder = "characterize_out")
  )
}

characterize_data_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_characterize_params()
      else default_characterize_params(paste0(task_id %||% "characterize", "_out"))
    })
    run_status_msg <- reactiveVal("")
    result_df      <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session,    "output_name",    value = init_p$output_name)
      updateCheckboxInput(session,"output_enabled", value = isTRUE(init_p$output_enabled %||% TRUE))
    }, once = TRUE)

    observe({
      tbls <- c("",store_available_tables(store, task_id = task_id))
      cur  <- isolate(input$input_table) %||% init_p$input_table %||% ""
      updateSelectInput(session, "input_table", choices = tbls,
        selected = if (cur %in% store_available_tables(store, task_id = task_id)) cur else "")
    })

    build_char_df <- function(df) {
      sample_val <- function(x) {
        vals <- unique(x[!is.na(x)])
        if (length(vals) == 0L) return("(all NA)")
        paste(head(vals, 3L), collapse = ", ")
      }
      data.frame(
        column     = names(df),
        type       = vapply(df, function(x) class(x)[1L], character(1)),
        n_rows     = nrow(df),
        n_missing  = vapply(df, function(x) sum(is.na(x)), integer(1)),
        pct_missing = round(vapply(df, function(x) mean(is.na(x)) * 100, numeric(1)), 1),
        n_distinct = vapply(df, function(x) length(unique(x)), integer(1)),
        sample_values = vapply(df, sample_val, character(1)),
        stringsAsFactors = FALSE
      )
    }


    do_run <- function() {
      tbl <- input$input_table %||% ""
      req(nzchar(tbl))
      df <- isolate(store_get_table(store, tbl))
      if (is.null(df)) {
        run_status_msg("Table not found"); return()
      }
      cdf <- build_char_df(df)
      result_df(cdf)
      enabled <- isTRUE(input$output_enabled %||% TRUE)
      p <- list(input_table = tbl,
                output_name    = trimws(input$output_name %||% paste0(task_id, "_out")),
                output_enabled = enabled)
      run_status_msg(sprintf("\u2713 %d columns characterised%s", nrow(cdf),
        if (!enabled) " (not saved)" else ""))
      showNotification("Characterize complete.", type = "message", duration = 2)
      .desc_save(store, task_id, "characterize", p, tbl, cdf, build_char_code(p),
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
                output_name = isolate(input$output_name)  %||% "")
      build_char_code(p)
    })
  })
}

execute_characterize <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  sample_val <- function(x) {
    vals <- unique(x[!is.na(x)])
    if (!length(vals)) return("(all NA)")
    paste(head(as.character(vals), 3L), collapse = ", ")
  }
  result <- data.frame(
    column        = names(df),
    type          = vapply(df, function(x) class(x)[1L], character(1)),
    n_rows        = nrow(df),
    n_missing     = vapply(df, function(x) sum(is.na(x)), integer(1)),
    pct_missing   = round(vapply(df, function(x) mean(is.na(x)) * 100, numeric(1)), 1),
    n_distinct    = vapply(df, function(x) length(unique(x)), integer(1)),
    sample_values = vapply(df, sample_val, character(1)),
    stringsAsFactors = FALSE
  )
  list(data = result, error = NULL)
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_char_code <- function(p) {
  tbl <- r_ident(p$input_table); out <- r_ident(p$output_name)
  paste0(
    out, " <- data.frame(\n",
    "  column = names(", tbl, "),\n",
    "  type   = vapply(", tbl, ", function(x) class(x)[1], character(1)),\n",
    "  n_rows = rep(nrow(", tbl, "), ncol(", tbl, ")),\n",
    "  n_missing = vapply(", tbl, ", function(x) sum(is.na(x)), integer(1)),\n",
    "  pct_missing = round(vapply(", tbl, ", function(x) mean(is.na(x)) * 100, numeric(1)), 1),\n",
    "  n_distinct = vapply(", tbl, ", function(x) length(unique(x)), integer(1)),\n",
    "  sample_values = vapply(", tbl, ", function(x) { vals <- unique(x[!is.na(x)]); if (!length(vals)) '(all NA)' else paste(head(as.character(vals), 3L), collapse = ', ') }, character(1)),\n",
    "  stringsAsFactors = FALSE\n)"
  )
}
