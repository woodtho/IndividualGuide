# mod_task_list_data.R — List Data
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_list_data_params <- function(output_name = "") {
  list(input_table = NULL, page_length = 25L, output_name = output_name, output_enabled = FALSE)
}

list_data_ui <- function(id) {
  ns <- NS(id)
  .desc_task_shell(ns, "list", "List Data", "Load",
    results = task_preview_tabset(ns),
    bslib::layout_columns(
      col_widths = c(8, 4),
      selectInput(ns("input_table"), "Input table",
        choices = character(0), width = "100%"),
      numericInput(ns("page_length"), "Rows per page",
        value = 25L, min = 5L, max = 500L, step = 5L, width = "100%")
    ),
    output_save_ui(ns, "output_name", "Save a copy as", placeholder = "data_copy",
                   toggle = TRUE, enabled = FALSE)
  )
}

list_data_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_list_data_params()
      else default_list_data_params()
    })
    run_status_msg <- reactiveVal("")
    current_df     <- reactiveVal(NULL)

    observe({
      tbls <- c("",store_available_tables(store, task_id = task_id))
      cur  <- isolate(input$input_table) %||% init_p$input_table %||% ""
      updateSelectInput(session, "input_table", choices = tbls,
        selected = if (cur %in% store_available_tables(store, task_id = task_id)) cur else "")
    })

    session$onFlushed(function() {
      updateNumericInput(session,  "page_length",    value = init_p$page_length %||% 25L)
      updateTextInput(session,     "output_name",    value = init_p$output_name %||% "")
      updateCheckboxInput(session, "output_enabled", value = isTRUE(init_p$output_enabled %||% FALSE))
    }, once = TRUE)

    do_run <- function() {
      tbl <- input$input_table %||% ""
      req(nzchar(tbl))
      df <- isolate(store_get_table(store, tbl))
      if (is.null(df)) { run_status_msg("Table not found"); return() }
      current_df(df)
      enabled  <- isTRUE(input$output_enabled %||% FALSE)
      out_name <- trimws(input$output_name %||% "")
      if (enabled && nzchar(out_name)) store_add_table(store, out_name, df)
      run_status_msg(sprintf("\u2713 %d rows \u00d7 %d cols%s", nrow(df), ncol(df),
        if (enabled && nzchar(out_name)) paste0(" \u2192 ", out_name) else ""))
      p <- list(input_table = tbl, page_length = input$page_length %||% 25L,
                output_name = out_name, output_enabled = enabled)
      if (!is.null(task_id)) {
        task <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, "list_data")
        task$inputs   <- tbl
        task$output   <- if (enabled) out_name else ""
        task$params   <- p
        task$r_code   <- paste0("# View: ", r_ident(tbl))
        task$run_time <- Sys.time()
        store_set_task(store, task)
      }
      .desc_goto_results(session)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    collect_p <- reactive(.desc_collect_params(input, init_p))
    store_register_result_fn(store, task_id, function(result) {
      current_df(ig_preview_data(result$data)); run_status_msg(ig_preview_status(result))
    }, session = session)
    store_register_params_fn(store, task_id, collect_p, session = session)
    if (!is.null(task_id)) session$onFlushed(function() {
      store_register_runner(store, task_id, do_run)
    }, once = TRUE)

    output$run_status <- renderText(run_status_msg())
    register_preview_visible(output, run_status_msg)
    output$result_dt  <- DT::renderDT({
      req(current_df())
      pg <- max(5L, min(500L, as.integer(input$page_length %||% 25L)))
      DT::datatable(current_df(),
        filter  = "top",
        options = list(scrollX = TRUE, pageLength = pg, dom = "lfrtip"),
        rownames = FALSE)
    })
    output$result_gt <- ig_render_gt({ NULL })
    output$task_code_view <- renderText({
      tbl <- isolate(input$input_table) %||% ""
      sprintf("# List Data\n%s", if (nzchar(tbl)) paste0("View(", r_ident(tbl), ")") else "# select a table")
    })
  })
}

# list_data just exposes the table — returns it as-is (no persistent output name usually)
execute_list_data <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  list(data = df, error = NULL)
}
