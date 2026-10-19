# mod_task_rename_cols.R — Rename Columns
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_rename_cols_params <- function(output_name = "rename_out") {
  list(input_table = NULL, renames = list(), output_name = output_name)
}

rename_cols_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "i-cursor", "Rename Columns", "rename_out",
    p(class = "text-muted small mb-1",
      "Rename one or more columns using ", code("dplyr::rename()"), "."),
    selectInput(ns("input_table"), "Input table", choices = character(0), width = "100%"),
    div(class = "d-flex align-items-center gap-2 mb-2",
      strong("Rename pairs"),
      actionButton(ns("add_rename"), "Add", icon = icon("plus"),
        class = "btn btn-xs btn-outline-secondary")),
    uiOutput(ns("rename_rows_ui"))
  )
}

rename_cols_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    ns <- session$ns
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_rename_cols_params()
      else default_rename_cols_params(paste0(task_id %||% "rename", "_out"))
    })
    run_status_msg <- reactiveVal(""); preview_df <- reactiveVal(NULL)
    rename_ctr  <- reactiveVal(0L)
    rename_ids  <- reactiveVal(character(0))
    rename_init <- reactiveVal(list())

    session$onFlushed(function() {
      updateTextInput(session, "output_name", value = init_p$output_name)
      saved <- init_p$renames %||% list()
      if (length(saved)) {
        ids <- vapply(seq_along(saved), function(i) paste0("rr", i), character(1))
        rename_ctr(length(saved))
        rename_init(setNames(saved, ids))
        rename_ids(ids)
      }
    }, once = TRUE)

    observeEvent(input$add_rename, {
      n <- rename_ctr() + 1L; rename_ctr(n)
      rid <- paste0("rr", n)
      rename_ids(c(rename_ids(), rid))
    })

    observeEvent(input$remove_rename_row, {
      rename_ids(setdiff(rename_ids(), input$remove_rename_row))
    })

    observe({
      tbls <- c("", store_available_tables(store, task_id = task_id))
      cur  <- isolate(input$input_table) %||% init_p$input_table %||% ""
      updateSelectInput(session, "input_table", choices = tbls,
        selected = if (cur %in% store_available_tables(store, task_id = task_id)) cur else "")
    })

    output$rename_rows_ui <- renderUI({
      ids <- rename_ids()
      if (!length(ids))
        return(p(class = "text-muted small", "No renames yet. Click 'Add'."))
      tbl <- input$input_table %||% ""
      ci  <- if (nzchar(tbl)) store_col_schema(store, tbl) else data.frame(column = character(0))
      col_choices <- ci$column

      rows <- lapply(ids, function(rid) {
        saved   <- rename_init()[[rid]] %||% list(old = "", new = "")
        cur_old <- isolate(input[[paste0("rold_", rid)]]) %||% saved$old
        cur_new <- isolate(input[[paste0("rnew_", rid)]]) %||% saved$new
        div(class = "d-flex align-items-center gap-2 mb-1",
          div(style = "flex:2;",
            selectInput(ns(paste0("rold_", rid)), sr_label("Column to rename"),
              choices  = c("", col_choices),
              selected = cur_old,
              width    = "100%")),
          span(`aria-hidden` = "true", "\u2192"),
          div(style = "flex:2;",
            textInput(ns(paste0("rnew_", rid)), sr_label("New column name"),
              value       = cur_new,
              placeholder = "new name",
              width       = "100%")),
          actionButton(ns(paste0("rmrr_", rid)), "",
            icon         = icon("xmark"),
            class        = "btn btn-xs btn-outline-danger",
            title        = "Remove rename rule",
            `aria-label` = "Remove rename rule",
            onclick      = ig_input_event_js(ns("remove_rename_row"), rid))
        )
      })
      tagList(rows)
    })

    collect_p <- reactive({
      ids <- rename_ids()
      renames <- lapply(ids, function(rid) {
        list(old = input[[paste0("rold_", rid)]] %||% "",
             new = trimws(input[[paste0("rnew_", rid)]] %||% ""))
      })
      renames <- Filter(function(r) nzchar(r$old) && nzchar(r$new) && !identical(r$old, r$new),
                        renames)
      list(
        input_table = input$input_table %||% "",
        renames     = renames,
        output_name = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })


    observeEvent(input$btn_preview, {
      p <- collect_p()
      result <- execute_rename_cols(p, isolate(store$tables))
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_rename_cols(p, isolate(store$tables))
      .dt_save(store, task_id, "rename_cols", p, p$input_table,
               result, build_rename_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_rename_code(collect_p()))
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

execute_rename_cols <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  renames <- Filter(function(r) nzchar(r$old %||% "") && nzchar(r$new %||% "") &&
                      !identical(r$old, r$new),
                    p$renames %||% list())
  if (!length(renames)) return(list(data = NULL, error = "Add at least one rename pair."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  tryCatch({
    map <- setNames(vapply(renames, `[[`, character(1), "old"),
                   vapply(renames, `[[`, character(1), "new"))
    list(data = as.data.frame(dplyr::rename(df, !!!map)), error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_rename_code <- function(p) {
  renames <- Filter(function(r) nzchar(r$old %||% "") && nzchar(r$new %||% "") &&
    !identical(r$old, r$new), p$renames %||% list())
  if (!length(renames)) return("stop('Add at least one rename pair.')")
  tbl <- r_ident(p$input_table); out <- r_ident(p$output_name)
  pairs <- paste(vapply(renames, function(r)
    paste0(r_ident(r$new), " = ", r_ident(r$old)), character(1)),
    collapse = ",\n  ")
  paste0("library(dplyr)\n", out, " <- rename(", tbl, ",\n  ", pairs, ")")
}
