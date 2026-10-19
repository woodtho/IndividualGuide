# mod_task_derive_cols.R — Derive Columns
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_derive_cols_params <- function(output_name = "derive_out") {
  list(input_table = NULL, derives = list(), output_name = output_name)
}

derive_cols_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "wand-magic-sparkles", "Derive Columns", "derive_out",
    p(class = "text-muted small mb-1",
      "Add new computed columns using R expressions (", code("dplyr::mutate"), ").",
      " Existing column names are available as variables."),
    selectInput(ns("input_table"), "Input table", choices = character(0), width = "100%"),
    div(class = "d-flex align-items-center gap-2 mb-2",
      strong("Derived columns"),
      actionButton(ns("add_derive"), "Add", icon = icon("plus"),
        class = "btn btn-xs btn-outline-secondary")),
    uiOutput(ns("derive_rows_ui"))
  )
}

derive_cols_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    ns <- session$ns
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_derive_cols_params()
      else default_derive_cols_params(paste0(task_id %||% "derive", "_out"))
    })
    run_status_msg <- reactiveVal(""); preview_df <- reactiveVal(NULL)
    derive_ctr  <- reactiveVal(0L)
    derive_ids  <- reactiveVal(character(0))
    derive_init <- reactiveVal(list())

    session$onFlushed(function() {
      updateTextInput(session, "output_name", value = init_p$output_name)
      saved <- init_p$derives %||% list()
      if (length(saved)) {
        ids <- vapply(seq_along(saved), function(i) paste0("dr", i), character(1))
        derive_ctr(length(saved))
        derive_init(setNames(saved, ids))
        derive_ids(ids)
      }
    }, once = TRUE)

    observeEvent(input$add_derive, {
      n <- derive_ctr() + 1L; derive_ctr(n)
      did <- paste0("dr", n)
      derive_ids(c(derive_ids(), did))
    })

    observeEvent(input$remove_derive_row, {
      derive_ids(setdiff(derive_ids(), input$remove_derive_row))
    })

    observe({
      tbls <- c("", store_available_tables(store, task_id = task_id))
      cur  <- isolate(input$input_table) %||% init_p$input_table %||% ""
      updateSelectInput(session, "input_table", choices = tbls,
        selected = if (cur %in% store_available_tables(store, task_id = task_id)) cur else "")
    })

    output$derive_rows_ui <- renderUI({
      ids <- derive_ids()
      if (!length(ids))
        return(p(class = "text-muted small", "No derived columns yet. Click 'Add'."))

      rows <- lapply(ids, function(did) {
        saved    <- derive_init()[[did]] %||% list(name = "", expr = "")
        cur_name <- isolate(input[[paste0("dname_", did)]]) %||% saved$name
        cur_expr <- isolate(input[[paste0("dexpr_", did)]]) %||% saved$expr
        div(class = "d-flex align-items-center gap-2 mb-1",
          div(style = "flex:1;",
            textInput(ns(paste0("dname_", did)), sr_label("New column name"),
              value       = cur_name,
              placeholder = "new_col_name",
              width       = "100%")),
          span(`aria-hidden` = "true", "="),
          div(style = "flex:3;",
            textInput(ns(paste0("dexpr_", did)),
              sr_label("R expression for new column"),
              value       = cur_expr,
              placeholder = "e.g. price * quantity",
              width       = "100%")),
          actionButton(ns(paste0("rmdr_", did)), "",
            icon         = icon("xmark"),
            class        = "btn btn-xs btn-outline-danger",
            title        = "Remove derived column",
            `aria-label` = "Remove derived column",
            onclick      = ig_input_event_js(ns("remove_derive_row"), did))
        )
      })
      tagList(rows)
    })

    collect_p <- reactive({
      ids <- derive_ids()
      derives <- lapply(ids, function(did) {
        list(name = trimws(input[[paste0("dname_", did)]] %||% ""),
             expr = trimws(input[[paste0("dexpr_", did)]] %||% ""))
      })
      list(
        input_table = input$input_table %||% "",
        derives     = derives,
        output_name = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })


    observeEvent(input$btn_preview, {
      p <- collect_p()
      result <- execute_derive_cols(p, isolate(store$tables))
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_derive_cols(p, isolate(store$tables))
      .dt_save(store, task_id, "derive_cols", p, p$input_table,
               result, build_derive_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_derive_code(collect_p()))
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

execute_derive_cols <- function(p, tables, context = list()) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  derives <- Filter(function(r) nzchar(r$name %||% "") && nzchar(r$expr %||% ""),
                    p$derives %||% list())
  if (!length(derives)) return(list(data = NULL, error = "Add at least one derived column."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  tryCatch({
    # Build mutate() call and eval in an env that has df columns + dplyr helpers
    exprs_txt <- paste(
      vapply(derives, function(r) paste0(r_ident(r$name), " = ", r$expr), character(1)),
      collapse = ",\n    ")
    code <- paste0("df <- dplyr::mutate(df, ", exprs_txt, ")")
    env <- new.env(parent = baseenv())
    env$df <- df
    for (name in names(context)) env[[name]] <- context[[name]]
    # Expose dplyr + tidyr helpers
    for (pkg_fn in c(
      # dplyr helpers
      "dplyr::mutate", "dplyr::if_else", "dplyr::case_when", "dplyr::coalesce",
      "dplyr::lag", "dplyr::lead", "dplyr::cumsum", "dplyr::cummean",
      "dplyr::dense_rank", "dplyr::min_rank", "dplyr::row_number",
      "dplyr::n", "dplyr::n_distinct", "dplyr::across", "dplyr::all_of",
      # tidyr helpers
      "tidyr::replace_na",
      # lubridate helpers
      "lubridate::ymd", "lubridate::ymd_hms", "lubridate::year",
      "lubridate::month", "lubridate::day", "lubridate::hour",
      "lubridate::minute", "lubridate::second", "lubridate::floor_date",
      "lubridate::ceiling_date", "lubridate::today", "lubridate::now",
      # stats helpers — not in baseenv(), must be forwarded explicitly
      "stats::sd", "stats::var", "stats::median", "stats::quantile",
      "stats::IQR", "stats::cor", "stats::cov", "stats::weighted.mean",
      "stats::approx", "stats::spline", "stats::dnorm", "stats::pnorm",
      "stats::qnorm", "stats::runif", "stats::rnorm",
      # utils helpers
      "utils::head", "utils::tail"
    )) {
      parts <- strsplit(pkg_fn, "::")[[1]]
      try(assign(parts[2], getExportedValue(parts[1], parts[2]), envir = env), silent = TRUE)
    }
    eval(parse(text = code), envir = env)
    list(data = as.data.frame(env$df), error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_derive_code <- function(p) {
  valid <- Filter(function(r) nzchar(r$name) && nzchar(r$expr), p$derives %||% list())
  if (!length(valid)) return("")
  tbl  <- r_ident(p$input_table); out <- r_ident(p$output_name)
  exprs <- paste(vapply(valid, function(r)
    paste0(r_ident(r$name), " = ", r$expr), character(1)),
    collapse = ",\n  ")
  paste0("library(dplyr)\nlibrary(tidyr)\nlibrary(lubridate)\n", out,
    " <- mutate(", tbl, ",\n  ", exprs, ")")
}
