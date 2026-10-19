# mod_task_first_last_n.R — First / Last N
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_first_last_params <- function(output_name = "firstlast_out") {
  list(input_table = NULL, which = "head", n = 10L, output_name = output_name)
}

first_last_n_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "list-ol", "First / Last N Rows", "firstlast_out",
    p(class = "text-muted small mb-1",
      "Keep only the first or last N rows of a table."),
    selectInput(ns("input_table"), "Input table", choices = character(0), width = "100%"),
    bslib::layout_columns(
      col_widths = c(6, 6),
      radioButtons(ns("which"), "Rows to keep",
        choices  = c("First N (head)" = "head", "Last N (tail)" = "tail"),
        selected = "head"),
      numericInput(ns("n"), "N", value = 10L, min = 1L, step = 1L, width = "100%")
    )
  )
}

first_last_n_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_first_last_params()
      else default_first_last_params(paste0(task_id %||% "firstlast", "_out"))
    })
    run_status_msg <- reactiveVal(""); preview_df <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session,    "output_name", value = init_p$output_name)
      updateRadioButtons(session, "which",       selected = init_p$which %||% "head")
      updateNumericInput(session, "n",            value = init_p$n %||% 10L)
    }, once = TRUE)

    observe({
      tbls <- c("", store_available_tables(store, task_id = task_id))
      cur  <- isolate(input$input_table) %||% init_p$input_table %||% ""
      updateSelectInput(session, "input_table", choices = tbls,
        selected = if (cur %in% store_available_tables(store, task_id = task_id)) cur else "")
    })

    collect_p <- reactive({
      list(
        input_table = input$input_table %||% "",
        which       = input$which %||% "head",
        n           = input$n %||% 10L,
        output_name = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })


    observeEvent(input$btn_preview, {
      p <- collect_p()
      result <- execute_first_last(p, isolate(store$tables))
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_first_last(p, isolate(store$tables))
      .dt_save(store, task_id, "first_last_n", p, p$input_table,
               result, build_firstlast_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_firstlast_code(collect_p()))
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

execute_first_last <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  tryCatch({
    n <- p$n %||% 10L
    if (length(n) != 1L || !is.finite(n) || n < 1 || n != floor(n))
      stop("Number of rows must be a positive whole number.")
    if (!(p$which %||% "head") %in% c("head", "tail")) stop("Choose first or last rows.")
    result <- if (identical(p$which %||% "head", "head"))
      utils::head(df, n)
    else
      utils::tail(df, n)
    list(data = as.data.frame(result), error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_firstlast_code <- function(p) {
  tbl <- r_ident(p$input_table); out <- r_ident(p$output_name)
  n <- p$n %||% 10L
  if (length(n) != 1L || !is.finite(n) || n < 1 || n != floor(n))
    return("stop('Number of rows must be a positive whole number.')")
  if (!(p$which %||% "head") %in% c("head", "tail")) return("stop('Choose first or last rows.')")
  fn  <- if (identical(p$which %||% "head", "head")) "head" else "tail"
  paste0(out, " <- as.data.frame(utils::", fn, "(", tbl, ", ", code_literal(n), "))")
}
