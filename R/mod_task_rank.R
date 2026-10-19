# mod_task_rank.R — Rank
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


RANK_METHODS <- c("Minimum rank" = "min_rank", "Dense rank" = "dense_rank",
  "Percent rank" = "percent_rank", "Cumulative distribution" = "cume_dist",
  "Row number" = "row_number")

default_rank_params <- function(output_name = "rank_out") {
  list(input_table = NULL, rank_col = NULL,
       method = "min_rank", new_col_name = "rank",
       group_by_cols = character(0), output_name = output_name)
}

rank_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "sort", "Rank", "rank_out",
    selectInput(ns("input_table"), "Input table",
      choices = character(0), width = "100%"),
    bslib::layout_columns(
      col_widths = c(5, 4, 3),
      selectInput(ns("rank_col"), "Column to rank",
        choices = character(0), width = "100%"),
      selectInput(ns("method"), "Method",
        choices = RANK_METHODS, width = "100%"),
      textInput(ns("new_col_name"), "New column name",
        value = "rank", width = "100%")
    ),
    selectInput(ns("group_by_cols"), "Group by (optional)",
      choices = character(0), multiple = TRUE, width = "100%")
  )
}

rank_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_rank_params()
      else default_rank_params(paste0(task_id %||% "rank", "_out"))
    })
    run_status_msg <- reactiveVal("")
    preview_df     <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session,  "output_name",   value = init_p$output_name)
      updateTextInput(session,  "new_col_name",  value = init_p$new_col_name %||% "rank")
      updateSelectInput(session, "method", selected = init_p$method %||% "min_rank")
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
      cur_rank <- isolate(input$rank_col) %||% ""
      cur_group <- isolate(input$group_by_cols)
      updateSelectInput(session, "rank_col", choices = c("",ci),
        selected = store_preserve_choice(cur_rank, init_p$rank_col, c("", ci), initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "group_by_cols", choices = ci,
        selected = store_preserve_choices(cur_group,
          init_p$group_by_cols %||% character(0), ci, initialized = store_inputs_ready(store, task_id)))
    })

    collect_p <- reactive({
      list(
        input_table    = input$input_table %||% "",
        rank_col       = input$rank_col %||% "",
        method         = input$method %||% "min_rank",
        new_col_name   = trimws(input$new_col_name %||% "rank"),
        group_by_cols  = input$group_by_cols %||% character(0),
        output_name    = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })

    execute_rank <- function(p) {
      tbl <- p$input_table
      if (!nzchar(tbl))        return(list(data = NULL, error = "Select an input table."))
      if (!nzchar(p$rank_col)) return(list(data = NULL, error = "Select a column to rank."))
      df <- isolate(store_get_table(store, tbl))
      if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
      tryCatch({
        fn      <- getExportedValue("dplyr", p$method)
        new_col <- p$new_col_name
        grp     <- p$group_by_cols %||% character(0)
        if (length(grp)) {
          result <- dplyr::group_by(df, dplyr::across(dplyr::all_of(grp)))
          result <- dplyr::mutate(result, .ig_rank_ = fn(.data[[p$rank_col]]))
          result <- as.data.frame(dplyr::ungroup(result))
          names(result)[names(result) == ".ig_rank_"] <- new_col
        } else {
          result <- df
          result[[new_col]] <- fn(df[[p$rank_col]])
        }
        list(data = result, error = NULL)
      }, error = function(e) list(data = NULL, error = conditionMessage(e)))
    }


    observeEvent(input$btn_preview, {
      result <- execute_rank(collect_p())
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_rank(p)
      .dt_save(store, task_id, "rank", p, p$input_table,
               result, build_rank_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_rank_code(collect_p()))

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

execute_rank <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl))               return(list(data = NULL, error = "Select an input table."))
  if (!nzchar(p$rank_col %||% "")) return(list(data = NULL, error = "Select a column to rank."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  tryCatch({
    fn      <- getExportedValue("dplyr", p$method %||% "min_rank")
    new_col <- p$new_col_name %||% "rank"
    grp     <- p$group_by_cols %||% character(0)
    if (length(grp)) {
      result <- dplyr::group_by(df, dplyr::across(dplyr::all_of(grp)))
      result <- dplyr::mutate(result, .ig_rank_ = fn(.data[[p$rank_col]]))
      result <- as.data.frame(dplyr::ungroup(result))
      names(result)[names(result) == ".ig_rank_"] <- new_col
    } else {
      result <- df
      result[[new_col]] <- fn(df[[p$rank_col]])
    }
    list(data = result, error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_rank_code <- function(p) {
  tbl <- r_ident(p$input_table); out <- r_ident(p$output_name)
  col <- r_ident(p$rank_col);    new <- r_ident(p$new_col_name)
  fn  <- p$method
  grp <- if (length(p$group_by_cols))
    paste0(" |>\n  group_by(", paste(vapply(p$group_by_cols, r_ident, character(1)),
      collapse = ", "), ")") else ""
  ungrp <- if (length(p$group_by_cols)) " |>\n  ungroup()" else ""
  paste0("library(dplyr)\n", out, " <- ", tbl, grp,
         " |>\n  mutate(", new, " = ", fn, "(", col, "))", ungrp)
}
