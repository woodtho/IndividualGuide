# mod_task_compare_data.R — Compare Data
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_compare_data_params <- function(output_name = "compare_out") {
  list(table_a = NULL, table_b = NULL, by_cols = character(0),
       output_name = output_name)
}

compare_data_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "code-branch", "Compare Data", "compare_out",
    p(class = "text-muted small mb-1",
      "Compare two tables using ", code("waldo::compare()"), "."),
    bslib::layout_columns(
      col_widths = c(6, 6),
      selectInput(ns("table_a"), "Table A (baseline)",
        choices = character(0), width = "100%"),
      selectInput(ns("table_b"), "Table B (comparison)",
        choices = character(0), width = "100%")
    ),
    selectInput(ns("by_cols"), "Key columns (blank = compare all columns)",
      choices = character(0), multiple = TRUE, width = "100%"),
    p(class = "text-muted small",
      "When key columns are selected, both tables are sorted by those keys before comparison. ",
      "The saved output is the raw ", code("waldo::compare()"),
      " result object; the Results tab pretty-prints that object.")
  )
}

compare_data_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_compare_data_params()
      else default_compare_data_params(paste0(task_id %||% "compare", "_out"))
    })
    run_status_msg <- reactiveVal("")
    preview_df     <- reactiveVal(NULL)
    preview_obj    <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session, "output_name", value = init_p$output_name)
    }, once = TRUE)

    observe({
      tbls <- c("",store_available_tables(store, task_id = task_id))
      cur_a <- isolate(input$table_a) %||% ""
      cur_b <- isolate(input$table_b) %||% ""
      updateSelectInput(session, "table_a", choices = tbls,
        selected = store_preserve_choice(cur_a, init_p$table_a, tbls, initialized = store_inputs_ready(store, task_id)))
      updateSelectInput(session, "table_b", choices = tbls,
        selected = store_preserve_choice(cur_b, init_p$table_b, tbls, initialized = store_inputs_ready(store, task_id)))
    })

    observe({
      a <- input$table_a; b <- input$table_b
      req(nzchar(a %||% ""), nzchar(b %||% ""))
      ci_a <- store_col_schema(store, a)$column
      ci_b <- store_col_schema(store, b)$column
      common <- intersect(ci_a, ci_b)
      sel <- intersect(init_p$by_cols %||% character(0), common)
      updateSelectInput(session, "by_cols", choices = common, selected = sel)
    })

    collect_p <- reactive({
      list(
        table_a     = input$table_a %||% "",
        table_b     = input$table_b %||% "",
        by_cols     = input$by_cols %||% character(0),
        output_name = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })

    execute_compare <- function(p) {
      if (!nzchar(p$table_a) || !nzchar(p$table_b))
        return(list(data = NULL, error = "Select both tables."))
      df_a <- store_get_table(store, p$table_a)
      df_b <- store_get_table(store, p$table_b)
      if (is.null(df_a) || is.null(df_b))
        return(list(data = NULL, error = "One or both tables not found."))
      tryCatch({
        if (!requireNamespace("waldo", quietly = TRUE))
          stop("The waldo package is required for Compare Data.")
        by <- intersect(p$by_cols %||% character(0), intersect(names(df_a), names(df_b)))
        if (length(by)) {
          df_a <- dplyr::arrange(df_a, dplyr::across(dplyr::all_of(by)))
          df_b <- dplyr::arrange(df_b, dplyr::across(dplyr::all_of(by)))
        }
        diffs <- waldo::compare(df_a, df_b, x_arg = p$table_a, y_arg = p$table_b)
        list(data = NULL, object = diffs, error = NULL)
      }, error = function(e) list(data = NULL, error = conditionMessage(e)))
    }


    observeEvent(input$btn_preview, {
      result <- execute_compare(collect_p())
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_obj(result$object)
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_compare(p)
      if (!is.null(result$error)) {
        run_status_msg(paste("Error:", result$error))
        showNotification(result$error, type = "error", duration = 8)
        return(store_task_failed(store, task_id, result$error))
      }
      out <- p$output_name %||% ""
      if (!nzchar(out)) {
        showNotification("Output name is required.", type = "warning")
        return(invisible(FALSE))
      }
      if (out %in% names(isolate(store$tables))) store_remove_table(store, out)
      store_add_object(store, out, result$object,
        meta = list(kind = "object", task_type = "compare_data"))
      if (!is.null(task_id)) {
        task <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, "compare_data")
        task$inputs    <- c(p$table_a, p$table_b)
        task$output    <- out
        task$outputs   <- list(list(
          name = out,
          kind = "object",
          label = "Waldo comparison"
        ))
        task$params    <- p
        task$r_code    <- build_compare_code(p)
        task$run_time  <- Sys.time()
        task$error_msg <- NULL
        store_set_task(store, task)
      }
      preview_obj(result$object)
      run_status_msg(sprintf("\u2713 %s: waldo comparison object", out))
      showNotification(sprintf("'%s' comparison object created.", out),
        type = "message", duration = 3)
      invisible(TRUE)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_compare_code(collect_p()))

    output$run_status <- renderText(run_status_msg())
    observeEvent(preview_obj(), {
      if (!is.null(preview_obj()))
        bslib::nav_select("task_tabs", "results", session = session)
    }, ignoreInit = TRUE)
    output$preview_pane_ui <- renderUI({
      obj <- preview_obj()
      if (is.null(obj)) return(.dt_results_placeholder())
      tagList(
        div(class = "ig-preview-header",
          span(icon("code-compare"), " Comparison Preview")),
        waldo_compare_html(obj)
      )
    })
    store_register_result_fn(store, task_id, function(result) {
      preview_df(NULL); preview_obj(result$object); run_status_msg(ig_preview_status(result))
    }, session = session)
    store_register_params_fn(store, task_id, collect_p, session = session)
    if (!is.null(task_id)) session$onFlushed(function() {
      store_register_runner(store, task_id, do_run)
    }, once = TRUE)
  })
}

waldo_compare_html <- function(x) {
  strip_ansi <- function(text) {
    gsub("\033\\[[0-9;]*m", "", text)
  }
  lines <- if (length(x)) {
    unlist(strsplit(strip_ansi(as.character(x)), "\n", fixed = TRUE),
      use.names = FALSE)
  } else {
    "No differences found."
  }
  line_nodes <- lapply(lines, function(line) {
    kind <- if (grepl("^-", line)) {
      "removed"
    } else if (grepl("^\\+", line)) {
      "added"
    } else if (grepl("^`[^`]+`", line)) {
      "detail"
    } else if (grepl("\\bvs\\b", line)) {
      "header"
    } else {
      "context"
    }
    shiny::tags$div(class = paste("ig-waldo-line", paste0("ig-waldo-", kind)),
      shiny::tags$code(line))
  })
  shiny::div(class = "ig-waldo-preview", line_nodes)
}

execute_compare <- function(p, tables) {
  a <- p$table_a %||% ""; b <- p$table_b %||% ""
  if (!nzchar(a) || !nzchar(b))
    return(list(data = NULL, error = "Select both tables."))
  df_a <- tables[[a]]; df_b <- tables[[b]]
  if (is.null(df_a) || is.null(df_b))
    return(list(data = NULL, error = "One or both tables not found."))
  tryCatch({
    if (!requireNamespace("waldo", quietly = TRUE))
      stop("The waldo package is required for Compare Data.")
    # Same semantics as the Compare Data panel: sort by the key columns first,
    # then return the raw waldo comparison object (stored as a special output).
    by <- intersect(p$by_cols %||% character(0), intersect(names(df_a), names(df_b)))
    if (length(by)) {
      df_a <- dplyr::arrange(df_a, dplyr::across(dplyr::all_of(by)))
      df_b <- dplyr::arrange(df_b, dplyr::across(dplyr::all_of(by)))
    }
    diffs <- waldo::compare(df_a, df_b, x_arg = a, y_arg = b)
    list(data = NULL, object = diffs, object_kind = "object", error = NULL)
  }, error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_compare_code <- function(p) {
  a <- r_ident(p$table_a); b <- r_ident(p$table_b); out <- r_ident(p$output_name)
  by_code <- if (length(p$by_cols)) {
    paste0(
      "by_cols <- c(",
      paste(vapply(p$by_cols, function(x) r_val(x, "character"), character(1)),
        collapse = ", "),
      ")\n",
      ".compare_left <- arrange(", a, ", across(all_of(by_cols)))\n",
      ".compare_right <- arrange(", b, ", across(all_of(by_cols)))\n"
    )
  } else {
    paste0(".compare_left <- ", a, "\n.compare_right <- ", b, "\n")
  }
  paste0(
    "library(dplyr)\n",
    "library(waldo)\n",
    by_code,
    out, " <- compare(.compare_left, .compare_right, x_arg = ",
      r_val(p$table_a, "character"), ", y_arg = ",
      r_val(p$table_b, "character"), ")"
  )
}
