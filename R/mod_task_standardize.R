# mod_task_standardize.R — Standardize Data
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_standardize_params <- function(output_name = "standardize_out") {
  list(input_table = NULL, cols = character(0),
       method = "zscore", group_by_cols = character(0), output_name = output_name)
}

standardize_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "sliders", "Standardize Data", "standardize_out",
    selectInput(ns("input_table"), "Input table",
      choices = character(0), width = "100%"),
    selectInput(ns("cols"), "Numeric columns to standardize",
      choices = character(0), multiple = TRUE, width = "100%"),
    radioButtons(ns("method"), "Method",
      choices  = c("Z-score  (mean=0, sd=1)" = "zscore",
                   "Min-Max  (range 0\u20131)"    = "minmax"),
      selected = "zscore", inline = TRUE),
    selectInput(ns("group_by_cols"), "Group by (optional \u2014 standardize within groups)",
      choices = character(0), multiple = TRUE, width = "100%")
  )
}

standardize_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_standardize_params()
      else default_standardize_params(paste0(task_id %||% "standardize", "_out"))
    })
    run_status_msg <- reactiveVal("")
    preview_df     <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session, "output_name", value = init_p$output_name)
      updateRadioButtons(session, "method", selected = init_p$method %||% "zscore")
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
      all_cols <- ci$column
      cur_cols <- isolate(input$cols)
      cur_group <- isolate(input$group_by_cols)
      updateSelectInput(session, "cols", choices = num_cols,
        selected = store_preserve_choices(cur_cols,
          init_p$cols %||% character(0), num_cols, initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "group_by_cols", choices = all_cols,
        selected = store_preserve_choices(cur_group,
          init_p$group_by_cols %||% character(0), all_cols, initialized = store_inputs_ready(store, task_id)))
    })

    collect_p <- reactive({
      list(
        input_table   = input$input_table %||% "",
        cols          = input$cols %||% character(0),
        method        = input$method %||% "zscore",
        group_by_cols = input$group_by_cols %||% character(0),
        output_name   = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })

    execute_std <- function(p) {
      tbl <- p$input_table
      if (!nzchar(tbl))     return(list(data = NULL, error = "Select an input table."))
      if (!length(p$cols))  return(list(data = NULL, error = "Select columns to standardize."))
      df <- isolate(store_get_table(store, tbl))
      if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
      tryCatch({
        if (identical(p$method, "zscore")) {
          scale_fn <- function(x) as.numeric(scale(x))
        } else {
          scale_fn <- function(x) {
            mn <- min(x, na.rm = TRUE); mx <- max(x, na.rm = TRUE)
            if (isTRUE(all.equal(mn, mx))) return(x * 0)
            (x - mn) / (mx - mn)
          }
        }
        if (length(p$group_by_cols)) {
          result <- dplyr::group_by(df, dplyr::across(dplyr::all_of(p$group_by_cols)))
          result <- dplyr::mutate(result, dplyr::across(dplyr::all_of(p$cols), scale_fn))
          result <- dplyr::ungroup(result)
        } else {
          result <- dplyr::mutate(df, dplyr::across(dplyr::all_of(p$cols), scale_fn))
        }
        list(data = as.data.frame(result), error = NULL)
      }, error = function(e) list(data = NULL, error = conditionMessage(e)))
    }


    observeEvent(input$btn_preview, {
      result <- execute_std(collect_p())
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_std(p)
      .dt_save(store, task_id, "standardize", p, p$input_table,
               result, build_std_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_std_code(collect_p()))

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

execute_std <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl))                      return(list(data = NULL, error = "Select an input table."))
  if (!length(p$cols %||% character(0))) return(list(data = NULL, error = "Select columns to standardize."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  tryCatch({
    scale_fn <- if (identical(p$method %||% "zscore", "zscore")) {
      function(x) as.numeric(scale(x))
    } else {
      function(x) {
        mn <- min(x, na.rm = TRUE); mx <- max(x, na.rm = TRUE)
        if (isTRUE(all.equal(mn, mx))) return(x * 0)
        (x - mn) / (mx - mn)
      }
    }
    grp <- p$group_by_cols %||% character(0)
    if (length(grp)) {
      result <- dplyr::group_by(df, dplyr::across(dplyr::all_of(grp)))
      result <- dplyr::mutate(result, dplyr::across(dplyr::all_of(p$cols), scale_fn))
      result <- dplyr::ungroup(result)
    } else {
      result <- dplyr::mutate(df, dplyr::across(dplyr::all_of(p$cols), scale_fn))
    }
    list(data = as.data.frame(result), error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_std_code <- function(p) {
  tbl <- r_ident(p$input_table); out <- r_ident(p$output_name)
  cols_r <- paste0("c(", paste(vapply(p$cols, r_ident, character(1)), collapse = ", "), ")")
  fn_body <- if (identical(p$method, "zscore")) {
    "as.numeric(scale(.x))"
  } else {
    "(if (diff(range(.x, na.rm=TRUE))==0) .x*0 else (.x - min(.x, na.rm=TRUE)) / diff(range(.x, na.rm=TRUE)))"
  }
  grp <- if (length(p$group_by_cols))
    paste0(" |>\n  group_by(", paste(vapply(p$group_by_cols, r_ident, character(1)),
      collapse = ", "), ")") else ""
  ungrp <- if (length(p$group_by_cols)) " |>\n  ungroup()" else ""
  paste0("library(dplyr)\n", out, " <- ", tbl, grp,
         " |>\n  mutate(across(", cols_r, ", function(.x) ", fn_body, "))", ungrp)
}
