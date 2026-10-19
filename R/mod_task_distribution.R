# mod_task_distribution.R — Distribution Analysis
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_distribution_params <- function(output_name = "distribution_out") {
  list(input_table = NULL, col = NULL, bins = 30L, show_density = TRUE,
       show_qq = FALSE, plot_width = 8, plot_height = 4,
       output_name = output_name, output_enabled = TRUE)
}

distribution_analysis_ui <- function(id) {
  ns <- NS(id)
  .desc_task_shell(ns, "chart-area", "Distribution Analysis", "Analyze",
    results = tagList(
      conditionalPanel(
        condition = sprintf("!output['%s']", ns("result_visible")),
        .dt_results_placeholder()),
      conditionalPanel(
        condition = sprintf("output['%s']", ns("result_visible")),
        bslib::navset_tab(
        id = ns("result_tabs"),
        bslib::nav_panel(tagList(icon("chart-bar"), " Results"), value = "Results",
          div(class = "ig-result-panel ig-formatted-results",
            ig_gt_output(ns("result_gt")))),
        bslib::nav_panel(tagList(icon("image"), " Plot"), value = "Plot",
          div(class = "ig-result-panel",
            div(class = "d-flex gap-2 mb-2 px-2 pt-2",
              downloadButton(ns("download_hist_png"),  "PNG",
                class = "btn btn-sm btn-outline-secondary"),
              downloadButton(ns("download_hist_html"), "HTML",
                class = "btn btn-sm btn-outline-secondary")
            ),
            ggiraph::girafeOutput(ns("hist_plot"), height = "340px"),
            conditionalPanel(
              condition = sprintf("input['%s']", ns("show_qq")),
              div(class = "d-flex gap-2 mb-2 px-2 pt-2",
                downloadButton(ns("download_qq_png"),  "Q-Q PNG",
                  class = "btn btn-sm btn-outline-secondary"),
                downloadButton(ns("download_qq_html"), "Q-Q HTML",
                  class = "btn btn-sm btn-outline-secondary")
              ),
              ggiraph::girafeOutput(ns("qq_plot"), height = "340px")
            )
          )
        ),
        bslib::nav_panel(tagList(icon("table"), " Data"), value = "Data",
          div(class = "ig-result-panel", DT::DTOutput(ns("stats_dt")))),
        bslib::nav_panel(tagList(icon("code"), " Code"), value = "Code",
          div(class = "ig-result-panel ig-code-panel",
            verbatimTextOutput(ns("task_code_view"))))
        )
      )
    ),
    bslib::layout_columns(
      col_widths = c(4, 3, 3, 2),
      selectInput(ns("input_table"), "Input table",
        choices = character(0), width = "100%"),
      selectInput(ns("col"), "Variable",
        choices = character(0), width = "100%"),
      numericInput(ns("bins"), "Bins", value = 30L, min = 5L, max = 200L, step = 1L,
        width = "100%"),
      div(class = "pt-4",
        checkboxInput(ns("show_density"), "Density",    value = TRUE),
        checkboxInput(ns("show_qq"),      "Q-Q plot",   value = FALSE))
    ),
    bslib::layout_columns(
      col_widths = c(6, 6),
      numericInput(ns("plot_width"),  "Plot width (in)",  value = 8, min = 3, max = 20, step = 0.5),
      numericInput(ns("plot_height"), "Plot height (in)", value = 4, min = 2, max = 16, step = 0.5)
    ),
    output_save_ui(ns, "output_name", "Summary stats table",
                   placeholder = "distribution_out")
  )
}

distribution_analysis_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_distribution_params()
      else default_distribution_params(paste0(task_id %||% "distribution", "_out"))
    })
    run_status_msg <- reactiveVal("")
    plot_data      <- reactiveVal(NULL)   # numeric vector for plotting
    stats_df       <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session,     "output_name",    value = init_p$output_name)
      updateNumericInput(session,  "bins",           value = init_p$bins %||% 30L)
      updateNumericInput(session,  "plot_width",     value = init_p$plot_width  %||% 8)
      updateNumericInput(session,  "plot_height",    value = init_p$plot_height %||% 4)
      updateCheckboxInput(session, "show_density",   value = isTRUE(init_p$show_density))
      updateCheckboxInput(session, "show_qq",        value = isTRUE(init_p$show_qq))
      updateCheckboxInput(session, "output_enabled", value = isTRUE(init_p$output_enabled %||% TRUE))
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
      cur <- isolate(input$col) %||% ""
      updateSelectInput(session, "col", choices = c("",num_cols),
        selected = store_preserve_choice(cur, init_p$col, c("", num_cols), initialized = store_inputs_ready(store, task_id)))
    })

    build_dist_stats <- function(x, col_name) {
      ig_distribution_stats(x, col_name)
    }


    do_run <- function() {
      tbl <- input$input_table %||% ""; col <- input$col %||% ""
      req(nzchar(tbl), nzchar(col))
      df <- isolate(store_get_table(store, tbl))
      if (is.null(df)) { run_status_msg("Table not found"); return() }
      if (!col %in% names(df)) { run_status_msg(paste("Column not found:", col)); return() }
      x <- df[[col]]
      if (!is.numeric(x)) { run_status_msg("Select a numeric column."); return() }
      sdf <- build_dist_stats(x, col)
      plot_data(x)
      stats_df(sdf)
      bslib::nav_select("result_tabs", "Plot", session = session)
      enabled <- isTRUE(input$output_enabled %||% TRUE)
      p <- list(input_table = tbl, col = col, bins = input$bins %||% 30L,
                show_density = isTRUE(input$show_density), show_qq = isTRUE(input$show_qq),
                plot_width   = input$plot_width  %||% 8,
                plot_height  = input$plot_height %||% 4,
                output_name    = trimws(input$output_name %||% paste0(task_id, "_out")),
                output_enabled = enabled)
      run_status_msg(sprintf("\u2713 n=%d, mean=%.3f, sd=%.3f%s", sdf$n, sdf$mean, sdf$sd,
        if (!enabled) " (not saved)" else ""))
      .desc_save(store, task_id, "distribution", p, tbl, sdf, build_dist_code(p),
                 run_status_msg, enabled = enabled)
      .desc_goto_results(session)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    collect_p <- reactive(.desc_collect_params(input, init_p))
    store_register_result_fn(store, task_id, function(result) {
      plot_data(result$values); stats_df(result$data); run_status_msg(ig_preview_status(result))
    }, session = session)
    store_register_params_fn(store, task_id, collect_p, session = session)
    if (!is.null(task_id)) session$onFlushed(function() {
      store_register_runner(store, task_id, do_run)
    }, once = TRUE)

    output$run_status <- renderText(run_status_msg())
    register_preview_visible(output, run_status_msg)

    hist_ggplot <- reactive({
      x <- plot_data(); req(!is.null(x))
      x <- x[is.finite(x)]
      validate(need(length(x) > 0L, "No finite observations to plot."))
      col <- input$col %||% "value"
      bins <- max(5L, min(200L, as.integer(input$bins %||% 30L)))
      p <- ggplot2::ggplot(data.frame(x = x), ggplot2::aes(x = x)) +
        ggplot2::geom_histogram(bins = bins, fill = "#4361ee", alpha = 0.75,
          colour = "#2b4acb") +
        ggplot2::labs(x = col, y = "Count",
          title = paste("Distribution of", col)) +
        ggplot2::theme_minimal(base_size = 12)
      if (isTRUE(input$show_density) && length(x) >= 2L) {
        p <- p + ggplot2::geom_density(
          ggplot2::aes(y = ggplot2::after_stat(count)),
          colour = "#e0e0f0", linewidth = 0.8)
      }
      p
    })

    qq_ggplot <- reactive({
      req(isTRUE(input$show_qq))
      x <- plot_data(); req(!is.null(x))
      x <- x[is.finite(x)]
      validate(need(length(x) >= 2L, "Q-Q plots require at least two finite observations."))
      col <- input$col %||% "value"
      qq  <- qqnorm(x, plot.it = FALSE)
      df  <- data.frame(theoretical = qq$x, sample = qq$y)
      p   <- ggplot2::ggplot(df, ggplot2::aes(x = theoretical, y = sample)) +
        ggplot2::geom_point(colour = "#4361ee", alpha = 0.6, size = 1.5) +
        ggplot2::geom_abline(intercept = mean(x, na.rm = TRUE),
          slope = sd(x, na.rm = TRUE), colour = "#e0e0f0") +
        ggplot2::labs(x = "Theoretical quantiles", y = "Sample quantiles",
          title = paste("Q-Q Plot:", col)) +
        ggplot2::theme_minimal(base_size = 12)
      p
    })

    output$hist_plot <- ggiraph::renderGirafe({
      w <- max(3, input$plot_width  %||% 8)
      h <- max(2, input$plot_height %||% 4)
      ggiraph::girafe(ggobj = hist_ggplot(), width_svg = w, height_svg = h)
    })

    output$qq_plot <- ggiraph::renderGirafe({
      w <- max(3, input$plot_width  %||% 8)
      h <- max(2, input$plot_height %||% 4)
      ggiraph::girafe(ggobj = qq_ggplot(), width_svg = w, height_svg = h)
    })

    output$download_hist_png <- downloadHandler(
      filename = function() paste0(input$col %||% "histogram", "_histogram.png"),
      content = function(file) {
        w <- max(3, input$plot_width %||% 8); h <- max(2, input$plot_height %||% 4)
        ggplot2::ggsave(file, hist_ggplot(), width = w, height = h, units = "in", dpi = 150)
      }
    )
    output$download_hist_html <- downloadHandler(
      filename = function() paste0(input$col %||% "histogram", "_histogram.html"),
      content = function(file) {
        w <- max(3, input$plot_width %||% 8); h <- max(2, input$plot_height %||% 4)
        writeLines(ig_report_widget_html(ggiraph::girafe(ggobj = hist_ggplot(), width_svg = w, height_svg = h)),
          file, useBytes = TRUE)
      }
    )
    output$download_qq_png <- downloadHandler(
      filename = function() paste0(input$col %||% "qq", "_qq.png"),
      content = function(file) {
        w <- max(3, input$plot_width %||% 8); h <- max(2, input$plot_height %||% 4)
        ggplot2::ggsave(file, qq_ggplot(), width = w, height = h, units = "in", dpi = 150)
      }
    )
    output$download_qq_html <- downloadHandler(
      filename = function() paste0(input$col %||% "qq", "_qq.html"),
      content = function(file) {
        w <- max(3, input$plot_width %||% 8); h <- max(2, input$plot_height %||% 4)
        writeLines(ig_report_widget_html(ggiraph::girafe(ggobj = qq_ggplot(), width_svg = w, height_svg = h)),
          file, useBytes = TRUE)
      }
    )

    output$stats_dt <- DT::renderDT({
      req(stats_df())
      DT::datatable(stats_df(),
        options = list(scrollX = TRUE, dom = "t"), rownames = FALSE)
    })

    output$result_gt <- ig_render_gt({
      req(stats_df())
      tryCatch(format_dist_stats_result(stats_df()), error = function(e) NULL)
    })
    output$task_code_view <- renderText({
      p <- list(input_table = isolate(input$input_table) %||% "",
                col         = isolate(input$col) %||% "",
                bins        = isolate(input$bins) %||% 30L,
                show_density = isTRUE(isolate(input$show_density)),
                show_qq      = isTRUE(isolate(input$show_qq)),
                plot_width   = isolate(input$plot_width)  %||% 8,
                plot_height  = isolate(input$plot_height) %||% 4,
                output_name  = isolate(input$output_name) %||% "")
      tryCatch(build_dist_code(p), error = function(e) "# configure the task first")
    })
  })
}

execute_distribution <- function(p, tables) {
  tbl <- p$input_table %||% ""; col <- p$col %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  if (!nzchar(col)) return(list(data = NULL, error = "Select a variable."))
  df <- tables[[tbl]]
  if (is.null(df))          return(list(data = NULL, error = paste("Table not found:", tbl)))
  if (!col %in% names(df))  return(list(data = NULL, error = paste("Column not found:", col)))
  x <- df[[col]]
  if (!is.numeric(x)) return(list(data = NULL, error = "Select a numeric column."))
  tryCatch(list(data = ig_distribution_stats(x, col), values = x, error = NULL),
    error = function(e) list(data = NULL, error = conditionMessage(e)))
}

#' Summarize a numeric distribution, including empty and all-missing columns.
#' @keywords internal
#' @param x Input value, column or nested configuration to transform.
#' @param column Source column name used in the result description.
ig_distribution_stats <- function(x, column) {
  if (any(is.infinite(x))) stop("Remove infinite values before distribution analysis.")
  values <- x[!is.na(x)]
  quantiles <- stats::quantile(values, c(0, .25, .75, 1), na.rm = TRUE)
  data.frame(
    column  = column,
    n       = sum(!is.na(x)),
    n_miss  = sum(is.na(x)),
    mean    = if (length(values)) round(mean(values), 4) else NA_real_,
    sd      = round(sd(x,   na.rm = TRUE), 4),
    min     = round(quantiles[[1]], 4),
    q25     = round(quantiles[[2]], 4),
    median  = round(stats::median(values), 4),
    q75     = round(quantiles[[3]], 4),
    max     = round(quantiles[[4]], 4),
    stringsAsFactors = FALSE
  )
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_dist_code <- function(p) {
  tbl <- r_ident(p$input_table)
  out <- r_ident(p$output_name)
  paste0(
    "library(ggplot2)\n",
    ".ig_distribution_stats <- ", paste(deparse(ig_distribution_stats), collapse = "\n"), "\n",
    ".x <- ", tbl, "[[", r_val(p$col, "character"), "]]\n",
    out, " <- .ig_distribution_stats(.x, ", r_val(p$col, "character"), ")\n",
    ".x <- .x[is.finite(.x)]\nif (length(.x)) {\n",
    ".ig_histogram <- ggplot(data.frame(x = .x), aes(x = x)) +\n",
    "  geom_histogram(bins = ", max(5L, min(200L, as.integer(p$bins %||% 30L))), ", fill = '#4361ee', alpha = 0.75, colour = '#2b4acb') +\n",
    if (isTRUE(p$show_density))
      "  { if (length(.x) >= 2L) geom_density(aes(y = after_stat(count)), colour = '#e0e0f0', linewidth = 0.8) else NULL } +\n"
    else "",
    "  labs(x = ", r_val(p$col, "character"), ", y = 'Count', title = ",
    r_val(paste("Distribution of", p$col), "character"), ") +\n  theme_minimal(base_size = 12)\n",
    ".ig_distribution_plot <- ggiraph::girafe(ggobj = .ig_histogram, width_svg = ", max(3, p$plot_width %||% 8), ", height_svg = ", max(2, p$plot_height %||% 4), ")\n}",
    if (isTRUE(p$show_qq)) paste0("\nif (length(.x) >= 2L) {\n.qq <- stats::qqnorm(.x, plot.it = FALSE)\n",
      ".ig_qq_plot <- ggplot(data.frame(theoretical = .qq$x, sample = .qq$y), aes(x = theoretical, y = sample)) + geom_point(colour = '#4361ee', alpha = 0.6, size = 1.5) + geom_abline(intercept = mean(.x), slope = stats::sd(.x), colour = '#e0e0f0') + labs(x = 'Theoretical quantiles', y = 'Sample quantiles', title = ",
      r_val(paste("Q-Q Plot:", p$col), "character"), ") + theme_minimal(base_size = 12)\n}") else ""
  )
}
