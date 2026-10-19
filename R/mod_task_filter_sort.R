# mod_task_filter_sort.R — Filter and Sort
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_filter_sort_params <- function(output_name = "filter_sort_out") {
  list(input_table = NULL, filters = list(), sorts = list(), output_name = output_name)
}

filter_sort_ui <- function(id) {
  ns <- NS(id)
  bslib::card(
    class = "ig-filter-sort-card",
    full_screen = TRUE,
    bslib::card_header(
      class = "d-flex align-items-center gap-2",
      icon("filter"), " Filter and Sort",
      div(class = "ms-auto d-flex align-items-center gap-3",
        div(class = "d-flex align-items-center gap-1",
          span("Input:", class = "text-muted small"),
          selectInput(ns("input_table"), sr_label("Input table"),
            choices = character(0), width = "160px")),
        div(class = "d-flex align-items-center gap-1",
          span("Output:", class = "text-muted small"),
          textInput(ns("output_name"), sr_label("Output table name"),
            width = "160px", placeholder = "filter_sort_out"))
      )
    ),
    bslib::card_body(
      padding = 0, class = "ig-task-tabs",
      bslib::navset_tab(
        id = ns("task_tabs"),
        bslib::nav_panel(tagList(icon("filter"), " Filter Data"), value = "setup",
          div(class = "ig-setup-pane",
            actionButton(ns("add_filter"), "Add condition",
              icon = icon("plus"), class = "btn btn-sm btn-outline-secondary mb-2"),
            uiOutput(ns("filter_rows_ui"))
          )
        ),
        bslib::nav_panel(tagList(icon("sort"), " Sort Data"), value = "sorting",
          div(class = "ig-setup-pane",
            actionButton(ns("add_sort"), "Add sort",
              icon = icon("plus"), class = "btn btn-sm btn-outline-secondary mb-2"),
            uiOutput(ns("sort_rows_ui"))
          )
        ),
        bslib::nav_panel(tagList(icon("table"), " Results"), value = "results",
          div(class = "ig-results-pane", uiOutput(ns("preview_pane_ui"))))
      )
    ),
    .dt_footer(ns)
  )
}

filter_sort_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    ns <- session$ns
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_filter_sort_params()
      else default_filter_sort_params(paste0(task_id %||% "filter_sort", "_out"))
    })
    run_status_msg <- reactiveVal("")
    preview_df     <- reactiveVal(NULL)

    # Filter row state
    .fl <- init_p$filters %||% list()
    .fi <- if (length(.fl)) vapply(.fl, `[[`, character(1), "id") else character(0)
    filter_ids  <- reactiveVal(.fi)
    filter_ctr  <- reactiveVal(length(.fl))
    filter_init <- reactiveVal(if (length(.fl)) setNames(.fl, .fi) else list())

    # Sort row state
    .sl <- init_p$sorts %||% list()
    .si <- if (length(.sl)) vapply(.sl, `[[`, character(1), "id") else character(0)
    sort_ids  <- reactiveVal(.si)
    sort_ctr  <- reactiveVal(length(.sl))
    sort_init <- reactiveVal(if (length(.sl)) setNames(.sl, .si) else list())

    session$onFlushed(function() {
      updateTextInput(session, "output_name", value = init_p$output_name)
    }, once = TRUE)

    observe({
      tbls <- c("",store_available_tables(store, task_id = task_id))
      cur  <- isolate(input$input_table) %||% init_p$input_table %||% ""
      updateSelectInput(session, "input_table", choices = tbls,
        selected = if (cur %in% store_available_tables(store, task_id = task_id)) cur else "")
    })

    col_info <- reactive({
      tbl <- input$input_table
      req(nzchar(tbl %||% ""), tbl %in% store_table_names(store))
      store_col_schema(store, tbl)
    })

    col_class_map <- reactive({
      ci <- col_info()
      setNames(as.list(ci$class), ci$column)
    })

    # ── Filter UI (same pattern as QB) ────────────────────────────────────────
    observeEvent(input$add_filter, {
      n <- filter_ctr() + 1L; filter_ctr(n)
      fid <- paste0("ffr", n)
      fi  <- filter_init(); fi[[fid]] <- new_filter_row(fid); filter_init(fi)
      filter_ids(c(filter_ids(), fid))
    })

    observeEvent(input$remove_filter_row, {
      filter_ids(setdiff(filter_ids(), input$remove_filter_row))
    })

    output$filter_rows_ui <- renderUI({
      ids <- filter_ids()
      if (!length(ids)) return(p(class = "text-muted small", "No conditions yet."))
      ci  <- col_info()
      col_choices <- if (nrow(ci) > 0) setNames(ci$column, ci$column) else character(0)
      rows <- lapply(seq_along(ids), function(i) {
        fid    <- ids[i]
        fi     <- filter_init()[[fid]] %||% new_filter_row(fid)
        cur_col   <- input[[paste0("ffcol_", fid)]] %||% fi$col
        cur_class <- col_class_map()[[cur_col]] %||% "character"
        cur_op    <- input[[paste0("ffop_",  fid)]] %||% fi$op
        cur_join  <- isolate(input[[paste0("ffjoin_", fid)]]) %||% fi$join %||% "AND"
        cur_val   <- isolate(input[[paste0("fval_f",  fid)]]) %||% fi$val  %||% ""
        cur_val2  <- isolate(input[[paste0("fval2_f", fid)]]) %||% fi$val2 %||% ""
        div(class = "d-flex align-items-start gap-2 mb-2",
          if (i > 1)
            div(style = "width:70px; padding-top:4px;",
              selectInput(ns(paste0("ffjoin_", fid)),
                sr_label("Combine with previous condition"),
                choices = c("AND", "OR"), selected = cur_join, width = "70px"))
          else div(style = "width:70px;"),
          div(style = "flex:2;",
            selectInput(ns(paste0("ffcol_", fid)), sr_label("Filter column"),
              choices = col_choices, selected = cur_col, width = "100%")),
          div(style = "flex:2;",
            selectInput(ns(paste0("ffop_", fid)), sr_label("Filter operator"),
              choices = ops_for_class(cur_class), selected = cur_op, width = "100%")),
          div(style = "flex:3;",
            filter_value_ui(ns, paste0("f", fid), cur_val, cur_val2, cur_op, cur_class)),
          div(style = "padding-top:4px;",
            actionButton(ns(paste0("rmffr_", fid)), "",
              icon         = icon("xmark"),
              class        = "btn btn-xs btn-outline-danger",
              title        = "Remove filter condition",
              `aria-label` = paste("Remove filter condition", fid),
              onclick      = ig_input_event_js(ns("remove_filter_row"), fid)))
        )
      })
      tagList(rows)
    })

    # ── Sort UI ───────────────────────────────────────────────────────────────
    observeEvent(input$add_sort, {
      n <- sort_ctr() + 1L; sort_ctr(n)
      sid <- paste0("fsr", n)
      si  <- sort_init(); si[[sid]] <- list(id = sid, col = "", dir = "ASC"); sort_init(si)
      sort_ids(c(sort_ids(), sid))
    })

    observeEvent(input$remove_sort_row, {
      sort_ids(setdiff(sort_ids(), input$remove_sort_row))
    })

    output$sort_rows_ui <- renderUI({
      ids <- sort_ids()
      if (!length(ids)) return(p(class = "text-muted small", "No sort criteria."))
      ci  <- col_info()
      col_choices <- if (nrow(ci) > 0) setNames(ci$column, ci$column) else character(0)
      rows <- lapply(ids, function(sid) {
        si <- sort_init()[[sid]] %||% list(id = sid, col = "", dir = "ASC")
        cur_col <- isolate(input[[paste0("fscol_", sid)]]) %||% si$col
        cur_dir <- isolate(input[[paste0("fsdir_", sid)]]) %||% si$dir %||% "ASC"
        div(class = "d-flex align-items-center gap-2 mb-2",
          div(style = "flex:3;",
            selectInput(ns(paste0("fscol_", sid)), sr_label("Sort column"),
              choices = col_choices, selected = cur_col, width = "100%")),
          div(style = "flex:2;",
            selectInput(ns(paste0("fsdir_", sid)), sr_label("Sort direction"),
              choices = c("ASC" = "ASC", "DESC" = "DESC"),
              selected = cur_dir, width = "100%")),
          actionButton(ns(paste0("rmfsr_", sid)), "",
            icon         = icon("xmark"),
            class        = "btn btn-xs btn-outline-danger",
            title        = "Remove sort rule",
            `aria-label` = paste("Remove sort rule", sid),
            onclick      = ig_input_event_js(ns("remove_sort_row"), sid))
        )
      })
      tagList(rows)
    })

    collect_p <- reactive({
      fids <- filter_ids(); sids <- sort_ids()
      filter_list <- lapply(fids, function(fid) {
        col  <- input[[paste0("ffcol_", fid)]] %||% ""
        op   <- input[[paste0("ffop_",  fid)]] %||% "="
        val  <- input[[paste0("fval_f",  fid)]] %||% ""
        val2 <- input[[paste0("fval2_f", fid)]] %||% ""
        join <- input[[paste0("ffjoin_", fid)]] %||% "AND"
        cls  <- col_class_map()[[col]] %||% "character"
        new_filter_row(fid, col, op, val, val2, join, cls)
      })
      sort_list <- lapply(sids, function(sid) {
        list(id  = sid,
             col = input[[paste0("fscol_", sid)]] %||% "",
             dir = input[[paste0("fsdir_", sid)]] %||% "ASC")
      })
      list(
        input_table = input$input_table %||% "",
        filters     = filter_list,
        sorts       = sort_list,
        output_name = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })

    execute_fs <- function(p) {
      tbl <- p$input_table
      if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
      df <- isolate(store_get_table(store, tbl))
      if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))

      filters <- Filter(function(f) nzchar(f$col %||% ""), p$filters)
      sorts   <- Filter(function(s) nzchar(s$col %||% ""), p$sorts)

      code <- sub("^library\\(dplyr\\)\\n", "", build_fs_code(p))
      env  <- new.env(parent = baseenv())
      env[[tbl]] <- df
      for (fn in c("filter","arrange","desc","between","if_else","case_when"))
        assign(fn, getExportedValue("dplyr", fn), envir = env)
      tryCatch({
        eval(parse(text = code), envir = env)
        list(data = get(p$output_name, envir = env), error = NULL)
      }, error = function(e) list(data = NULL, error = conditionMessage(e)))
    }


    observeEvent(input$btn_preview, {
      result <- execute_fs(collect_p())
      if (!is.null(result$error)) {
        run_status_msg(paste("Preview error:", result$error))
        showNotification(result$error, type = "error", duration = 8)
      } else {
        preview_df(head(result$data, 1000L))
        run_status_msg(sprintf("Preview ready: %d x %d", nrow(result$data), ncol(result$data)))
      }
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_fs(p)
      .dt_save(store, task_id, "filter_sort", p, p$input_table,
               result, build_fs_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_fs_code(collect_p()))

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

# Internal helper — build dplyr filter+arrange code string.
# (Same logic as the module-local build_fs_code; kept here so execute_fs is self-contained.)
.exec_fs_build_code <- function(p) {
  chain   <- r_ident(p$input_table)
  filters <- Filter(function(f) nzchar(f$col %||% ""), p$filters %||% list())
  sorts   <- Filter(function(s) nzchar(s$col %||% ""), p$sorts   %||% list())
  if (length(filters))
    chain <- paste0(chain, " |>\n  filter(\n    ", build_filter_r(filters), "\n  )")
  if (length(sorts)) {
    arr <- paste(vapply(sorts, function(s) {
      col <- r_ident(s$col)
      if ((s$dir %||% "ASC") == "DESC") paste0("desc(", col, ")") else col
    }, character(1)), collapse = ", ")
    chain <- paste0(chain, " |>\n  arrange(", arr, ")")
  }
  paste0("library(dplyr)\n", r_ident(p$output_name), " <- ", chain)
}

execute_fs <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  # Strip the library() header — the verbs are injected into env below, and
  # evaluating library(dplyr) here would attach dplyr as a side effect.
  code <- sub("^library\\(dplyr\\)\\n", "", .exec_fs_build_code(p))
  env  <- new.env(parent = baseenv())
  env[[tbl]] <- df
  for (fn in c("filter", "arrange", "desc", "between", "if_else", "case_when"))
    assign(fn, getExportedValue("dplyr", fn), envir = env)
  tryCatch({
    eval(parse(text = code), envir = env)
    list(data = get(p$output_name, envir = env), error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_fs_code <- function(p) {
  chain  <- r_ident(p$input_table)
  filters <- Filter(function(f) nzchar(f$col %||% ""), p$filters)
  sorts   <- Filter(function(s) nzchar(s$col %||% ""), p$sorts)
  if (length(filters))
    chain <- paste0(chain, " |>\n  filter(\n    ", build_filter_r(filters), "\n  )")
  if (length(sorts)) {
    arr <- paste(vapply(sorts, function(s) {
      col <- r_ident(s$col)
      if ((s$dir %||% "ASC") == "DESC") paste0("desc(", col, ")") else col
    }, character(1)), collapse = ", ")
    chain <- paste0(chain, " |>\n  arrange(", arr, ")")
  }
  paste0("library(dplyr)\n", r_ident(p$output_name), " <- ", chain)
}
