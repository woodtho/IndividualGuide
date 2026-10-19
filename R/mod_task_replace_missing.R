# mod_task_replace_missing.R — Replace Missing
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_replace_missing_params <- function(output_name = "fillna_out") {
  list(input_table = NULL, cols = character(0), method = "fixed",
       fixed_value = "0", output_name = output_name)
}

replace_missing_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "fill", "Replace Missing Values", "fillna_out",
    p(class = "text-muted small mb-1",
      "Replace NA values with a constant or computed value."),
    selectInput(ns("input_table"), "Input table", choices = character(0), width = "100%"),
    selectInput(ns("cols"), "Columns to fill (blank = all)",
      choices = character(0), multiple = TRUE, width = "100%"),
    radioButtons(ns("method"), "Fill with",
      choices  = c("Fixed value"    = "fixed",
                   "Column mean"    = "mean",
                   "Column median"  = "median",
                   "Column mode"    = "mode"),
      selected = "fixed", inline = TRUE),
    conditionalPanel(
      condition = sprintf("input['%s'] == 'fixed'", ns("method")),
      textInput(ns("fixed_value"), "Replacement value", value = "0", width = "100%")
    )
  )
}

replace_missing_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_replace_missing_params()
      else default_replace_missing_params(paste0(task_id %||% "fillna", "_out"))
    })
    run_status_msg <- reactiveVal(""); preview_df <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session,    "output_name",  value = init_p$output_name)
      updateRadioButtons(session, "method",       selected = init_p$method %||% "fixed")
      updateTextInput(session,    "fixed_value",  value = init_p$fixed_value %||% "0")
    }, once = TRUE)

    observe({
      tbls <- c("", store_available_tables(store, task_id = task_id))
      cur  <- isolate(input$input_table) %||% init_p$input_table %||% ""
      updateSelectInput(session, "input_table", choices = tbls,
        selected = if (cur %in% store_available_tables(store, task_id = task_id)) cur else "")
    })

    observe({
      tbl <- input$input_table; req(nzchar(tbl %||% ""))
      ci  <- store_col_schema(store, tbl)
      cur <- isolate(input$cols)
      updateSelectInput(session, "cols", choices = ci$column,
        selected = store_preserve_choices(cur,
          init_p$cols %||% character(0), ci$column, initialized = store_inputs_ready(store, task_id)))
    })

    collect_p <- reactive({
      list(
        input_table = input$input_table %||% "",
        cols        = input$cols %||% character(0),
        method      = input$method %||% "fixed",
        fixed_value = trimws(input$fixed_value %||% "0"),
        output_name = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })


    observeEvent(input$btn_preview, {
      p <- collect_p()
      result <- execute_replace_missing(p, isolate(store$tables))
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_replace_missing(p, isolate(store$tables))
      .dt_save(store, task_id, "replace_missing", p, p$input_table,
               result, build_fillna_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_fillna_code(collect_p()))
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

execute_replace_missing <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  tryCatch({
    cols <- if (length(p$cols %||% character(0))) p$cols else names(df)
    missing <- setdiff(cols, names(df))
    if (length(missing)) stop("Columns not found: ", paste(missing, collapse = ", "))
    method <- p$method %||% "fixed"
    result <- df
    for (col in cols) {
      result[[col]] <- ig_fill_missing_column(result[[col]], method, p$fixed_value %||% "")
    }
    list(data = result, error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_fillna_code <- function(p) {
  tbl  <- r_ident(p$input_table); out <- r_ident(p$output_name)
  cols <- if (length(p$cols))
    paste0("all_of(c(", paste(vapply(p$cols, r_val, character(1), col_class = "character"), collapse = ", "), "))") else
    "everything()"
  fill_expr <- paste0("function(x) .ig_fill_missing_column(x, ", r_val(p$method %||% "fixed", "character"),
    ", ", r_val(p$fixed_value %||% "", "character"), ")")
  paste0("library(dplyr)\n.ig_fill_missing_column <- ", paste(deparse(ig_fill_missing_column), collapse = "\n"),
    "\n", out, " <- mutate(", tbl, ", across(", cols, ", ", fill_expr, "))")
}

#' Fill missing elements without dropping column classes or factor levels.
#' @keywords internal
#' @param x Input value, column or nested configuration to transform.
#' @param method Selected transformation method.
#' @param fixed_value Replacement value for fixed-value missing-data filling.
ig_fill_missing_column <- function(x, method, fixed_value = "") {
  if (!anyNA(x)) return(x)
  observed <- x[!is.na(x)]
  if (method %in% c("mean", "median") && (!is.numeric(x) || !length(observed))) return(x)
  fill <- switch(method,
    fixed = {
      if (inherits(x, "Date")) as.Date(fixed_value)
      else if (is.numeric(x)) suppressWarnings(as.numeric(fixed_value))
      else if (is.logical(x)) as.logical(toupper(fixed_value))
      else as.character(fixed_value)
    },
    mean = mean(observed),
    median = stats::median(observed),
    mode = {
      if (!length(observed)) return(x)
      values <- sort(unique(observed))
      values[[which.max(tabulate(match(observed, values)))]]
    },
    stop("Unsupported replacement method: ", method))
  if (length(fill) != 1L || is.na(fill)) stop("Replacement value is invalid for the column type.")
  if (is.factor(x) && !as.character(fill) %in% levels(x)) levels(x) <- c(levels(x), as.character(fill))
  x[is.na(x)] <- fill
  x
}
