# mod_task_recode_values.R — Recode Values
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_recode_values_params <- function(output_name = "recode_out") {
  list(input_table = NULL, col = "", new_col_name = "",
       rules = list(), else_val = "", output_name = output_name)
}

recode_values_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "arrows-left-right", "Recode Values", "recode_out",
    p(class = "text-muted small mb-1",
      "Map column values to new values using a rule table (", code("dplyr::case_when"), ")."),
    bslib::layout_columns(
      col_widths = c(6, 6),
      selectInput(ns("input_table"), "Input table",
        choices = character(0), width = "100%"),
      selectInput(ns("col"), "Column to recode",
        choices = character(0), width = "100%")
    ),
    textInput(ns("new_col_name"), "Output column name",
      placeholder = "same as source column to overwrite", width = "100%"),
    div(class = "d-flex align-items-center gap-2 mb-1",
      strong("Recode rules"),
      actionButton(ns("add_rule"), "Add rule", icon = icon("plus"),
        class = "btn btn-xs btn-outline-secondary")),
    div(class = "d-flex gap-2 mb-1",
      div(style = "flex:2;", em(class = "text-muted small", "From (old value)")),
      div(style = "flex:2;", em(class = "text-muted small", "To (new value)"))),
    uiOutput(ns("rule_rows_ui")),
    bslib::layout_columns(
      col_widths = c(4, 8),
      em(class = "text-muted small mt-1", "Else (unmatched)"),
      textInput(ns("else_val"), sr_label("Else value for unmatched rows"),
        placeholder = "(leave blank to keep original)",
        width = "100%")
    )
  )
}

recode_values_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    ns <- session$ns
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_recode_values_params()
      else default_recode_values_params(paste0(task_id %||% "recode", "_out"))
    })
    run_status_msg <- reactiveVal(""); preview_df <- reactiveVal(NULL)
    rule_ctr  <- reactiveVal(0L)
    rule_ids  <- reactiveVal(character(0))
    rule_init <- reactiveVal(list())

    session$onFlushed(function() {
      updateTextInput(session, "output_name",  value = init_p$output_name)
      updateTextInput(session, "new_col_name", value = init_p$new_col_name %||% "")
      updateTextInput(session, "else_val",     value = init_p$else_val %||% "")
      saved <- init_p$rules %||% list()
      if (length(saved)) {
        ids <- vapply(seq_along(saved), function(i) paste0("rc", i), character(1))
        rule_ctr(length(saved))
        rule_init(setNames(saved, ids))
        rule_ids(ids)
      }
    }, once = TRUE)

    observeEvent(input$add_rule, {
      n <- rule_ctr() + 1L; rule_ctr(n)
      rid <- paste0("rc", n)
      rule_ids(c(rule_ids(), rid))
    })

    observeEvent(input$remove_rule_row, {
      rule_ids(setdiff(rule_ids(), input$remove_rule_row))
    })

    observe({
      tbls <- c("", store_available_tables(store, task_id = task_id))
      cur  <- isolate(input$input_table) %||% init_p$input_table %||% ""
      updateSelectInput(session, "input_table", choices = tbls,
        selected = if (cur %in% store_available_tables(store, task_id = task_id)) cur else "")
    })

    observe({
      tbl <- input$input_table; req(nzchar(tbl %||% ""))
      ci  <- store_col_schema(store, tbl)
      cur_col <- isolate(input$col) %||% init_p$col %||% ""
      updateSelectInput(session, "col", choices = c("", ci$column),
        selected = if (cur_col %in% ci$column) cur_col else "")
    })

    observe({
      col <- input$col; req(nzchar(col %||% ""))
      if (!nzchar(trimws(isolate(input$new_col_name) %||% "")))
        updateTextInput(session, "new_col_name", value = col)
    })

    output$rule_rows_ui <- renderUI({
      ids <- rule_ids()
      if (!length(ids))
        return(p(class = "text-muted small", "No rules yet. Click 'Add rule'."))

      rows <- lapply(ids, function(rid) {
        saved    <- rule_init()[[rid]] %||% list(from = "", to = "")
        cur_from <- isolate(input[[paste0("rfrom_", rid)]]) %||% saved$from
        cur_to   <- isolate(input[[paste0("rto_",   rid)]]) %||% saved$to
        div(class = "d-flex align-items-center gap-2 mb-1",
          div(style = "flex:2;",
            textInput(ns(paste0("rfrom_", rid)), sr_label("Value to match"),
              value = cur_from, placeholder = "value to match", width = "100%")),
          span(`aria-hidden` = "true", "\u2192"),
          div(style = "flex:2;",
            textInput(ns(paste0("rto_", rid)), sr_label("Replacement value"),
              value = cur_to, placeholder = "replacement value", width = "100%")),
          actionButton(ns(paste0("rmrc_", rid)), "",
            icon         = icon("xmark"),
            class        = "btn btn-xs btn-outline-danger",
            title        = "Remove recode rule",
            `aria-label` = "Remove recode rule",
            onclick      = ig_input_event_js(ns("remove_rule_row"), rid))
        )
      })
      tagList(rows)
    })

    collect_p <- reactive({
      ids <- rule_ids()
      rules <- lapply(ids, function(rid) {
        list(from = input[[paste0("rfrom_", rid)]] %||% "",
             to   = input[[paste0("rto_",   rid)]] %||% "")
      })
      list(
        input_table  = input$input_table %||% "",
        col          = input$col %||% "",
        new_col_name = trimws(input$new_col_name %||% input$col %||% ""),
        rules        = rules,
        else_val     = trimws(input$else_val %||% ""),
        output_name  = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })


    observeEvent(input$btn_preview, {
      p <- collect_p()
      result <- execute_recode_values(p, isolate(store$tables))
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_recode_values(p, isolate(store$tables))
      .dt_save(store, task_id, "recode_values", p, p$input_table,
               result, build_recode_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_recode_code(collect_p()))
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

execute_recode_values <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl))                     return(list(data = NULL, error = "Select an input table."))
  if (!nzchar(p$col %||% ""))           return(list(data = NULL, error = "Select a column to recode."))
  if (!nzchar(p$new_col_name %||% ""))  return(list(data = NULL, error = "Enter an output column name."))
  rules <- Filter(function(r) nzchar(r$from %||% ""), p$rules %||% list())
  if (!length(rules))                   return(list(data = NULL, error = "Add at least one recode rule."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  if (!p$col %in% names(df)) return(list(data = NULL, error = paste("Column not found:", p$col)))
  tryCatch({
    x       <- df[[p$col]]
    is_num  <- is.numeric(x)
    # Work entirely in character space — recoded values are always strings.
    # This avoids silent coercion failures (e.g. recode 1 → "one" on a numeric column).
    new_col <- as.character(x)

    na_sentinels <- c("NA", "na", "N/A")

    for (r in rules) {
      from_str <- r$from %||% ""
      to_val   <- r$to   %||% ""
      if (from_str %in% na_sentinels) {
        new_col[is.na(x)] <- to_val
      } else {
        if (is_num) {
          from_val <- suppressWarnings(as.numeric(from_str))
          if (is.na(from_val)) stop("Recode source value is not numeric: ", from_str)
          mask <- !is.na(x) & (x == from_val)
        } else {
          mask <- !is.na(x) & (x == from_str)
        }
        new_col[mask] <- to_val
      }
    }

    else_raw <- p$else_val %||% ""
    if (nzchar(else_raw)) {
      from_strs <- vapply(rules, function(r) r$from %||% "", character(1))
      has_na_rule <- any(from_strs %in% na_sentinels)
      non_na_froms <- setdiff(from_strs, na_sentinels)
      if (is_num) {
        matched_nums <- suppressWarnings(as.numeric(non_na_froms))
        matched_nums <- matched_nums[!is.na(matched_nums)]
        mask_matched <- (!is.na(x) & x %in% matched_nums) | (is.na(x) & has_na_rule)
      } else {
        mask_matched <- (!is.na(x) & x %in% non_na_froms) | (is.na(x) & has_na_rule)
      }
      new_col[!mask_matched] <- else_raw
    }

    result <- df
    result[[p$new_col_name]] <- new_col
    list(data = result, error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_recode_code <- function(p) {
  paste(c(code_helper_definitions("execute_recode_values"),
    paste0(".ig_recode_result <- .ig_codegen$execute_recode_values(", code_literal(p),
      ", setNames(list(", r_ident(p$input_table), "), ", code_literal(p$input_table), "))"),
    "if (!is.null(.ig_recode_result$error)) stop(.ig_recode_result$error)",
    paste0(r_ident(p$output_name), " <- .ig_recode_result$data")), collapse = "\n")
}
