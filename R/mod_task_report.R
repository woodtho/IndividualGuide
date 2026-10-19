# mod_report.R — Report task module (SAS ODS equivalent)
#
# Assembles selected store tables into a formatted HTML or Word document using
# rmarkdown::render().  The rendered file is available for download via a
# dynamic downloadButton in the panel footer.
#
# Depends on: execute_fns.R (execute_report, build_report_rmd), store.R

REPORT_FORMATS <- c("HTML (.html)" = "html", "Word (.docx)" = "word")

# ══════════════════════════════════════════════════════════════════════════════
# UI
# ══════════════════════════════════════════════════════════════════════════════

report_ui <- function(id) {
  ns <- NS(id)

  bslib::card(
    full_screen = TRUE,
    bslib::card_header(
      class = "d-flex align-items-center gap-3",
      icon("file-lines"), span(" Report"),
      div(class = "ms-auto d-flex align-items-center gap-2",
        span("Output name:", class = "text-muted small"),
        textInput(ns("output_name"), sr_label("Report output name"),
          width = "160px", placeholder = "e.g. report_1_out"))
    ),

    bslib::card_body(
      padding = 0,
      bslib::navset_tab(
        id = ns("rpt_tabs"),

        # ── Tab 1: Content ──────────────────────────────────────────────────
        bslib::nav_panel("Content",
          bslib::card_body(
            bslib::layout_columns(
              col_widths = c(4, 8),
              style = "height: calc(100vh - 260px); overflow: hidden;",

              # LEFT — available outputs
              bslib::card(
                bslib::card_header(
                  class = "d-flex align-items-center gap-2 py-1",
                  "Available outputs",
                  span(class = "ms-auto text-muted small",
                    "Click + to add (can add more than once)")
                ),
                bslib::card_body(
                  padding = "4px",
                  style   = "overflow-y:auto; height:100%;",
                  uiOutput(ns("avail_items_ui"))
                )
              ),

              # RIGHT — report contents (ordered)
              bslib::card(
                bslib::card_header(
                  class = "d-flex align-items-center gap-2 py-1",
                  "Report contents",
                  div(class = "ms-auto d-flex gap-1",
                    actionButton(ns("clear_items"), "Clear",
                      class = "btn btn-xs btn-outline-secondary"))
                ),
                bslib::card_body(
                  padding = "4px",
                  style   = "overflow-y:auto; height:100%;",
                  uiOutput(ns("items_ui"))
                )
              )
            )
          )
        ),

        # ── Tab 2: Appearance ───────────────────────────────────────────────
        bslib::nav_panel("Appearance",
          bslib::card_body(
            bslib::layout_columns(
              col_widths = c(6, 6),
              textInput(ns("rpt_title"),  "Report title",
                placeholder = "My Report"),
              textInput(ns("rpt_author"), "Author",
                placeholder = "Your name (optional)")
            ),
            bslib::layout_columns(
              col_widths = c(6, 6),
              textInput(ns("rpt_subtitle"), "Subtitle",
                placeholder = "(optional)"),
              selectInput(ns("rpt_format"), "Output format",
                choices = REPORT_FORMATS)
            ),
            checkboxInput(ns("include_log"), "Include pipeline log in the report", FALSE),
            selectInput(ns("log_min_level"), "Minimum log level",
              choices = c("DEBUG", "INFO", "WARN", "ERROR"), selected = "INFO"),
            p(class = "small text-muted", "Includes retained events recorded before this report starts, across all tasks in the current flow. The report's own completion event is available in Export Log after it finishes. Use report content dependencies to run the required tasks first.")
          )
        )
      ) # end navset_tab
    ), # end card_body

    # ── Footer: Generate + Download ─────────────────────────────────────────
    bslib::card_footer(
      class = "d-flex align-items-center gap-2",
      actionButton(ns("btn_generate"), "Generate Report",
        icon  = icon("file-export"),
        class = "btn btn-sm btn-primary"),
      span(class = "ms-auto text-muted small",
        role = "status", `aria-live` = "polite", `aria-atomic` = "true",
        textOutput(ns("gen_status"), inline = TRUE)),
      uiOutput(ns("download_ui"))
    )
  ) # end card
}

# ══════════════════════════════════════════════════════════════════════════════
# SERVER
# ══════════════════════════════════════════════════════════════════════════════

report_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    ns <- session$ns

    # ── Initialise from saved params ──────────────────────────────────────
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_report_params()
      else
        default_report_params(output_name = paste0(task_id %||% "report", "_out"))
    })

    updateTextInput(session,   "output_name",  value = init_p$output_name %||% "report_out")
    updateTextInput(session,   "rpt_title",    value = init_p$title    %||% "")
    updateTextInput(session,   "rpt_author",   value = init_p$author   %||% "")
    updateTextInput(session,   "rpt_subtitle", value = init_p$subtitle %||% "")
    updateSelectInput(session, "rpt_format",   selected = init_p$format %||% "html")
    updateCheckboxInput(session, "include_log", value = isTRUE(init_p$include_log))
    updateSelectInput(session, "log_min_level", selected = init_p$log_min_level %||% "INFO")

    # ── Report items state ────────────────────────────────────────────────
    rv_items <- reactiveVal(init_p$items %||% list())

    # Available tables and objects left panel. Each row has a "+" button
    # (mirroring the Query Builder's "add column" affordance) that appends the
    # output to the report contents on the right — the same output can be
    # added multiple times, e.g. once as a table and again as a plot.
    output$avail_items_ui <- renderUI({
      outs <- store_available_outputs(store, task_id = task_id)
      if (length(outs) == 0L)
        return(tags$p(class = "text-muted small p-2", "No outputs loaded yet."))
      objs <- store$objects
      obj_names <- names(objs)
      counts <- table(vapply(rv_items(), `[[`, character(1), "name"))
      lapply(outs, function(nm) {
        kind <- if (nm %in% obj_names) {
          objs[[nm]]$meta$kind %||% "object"
        } else {
          "table"
        }
        cnt_raw <- counts[nm]
        cnt <- if (!is.na(cnt_raw)) as.integer(cnt_raw) else 0L
        div(
          class = paste("ig-col-row d-flex align-items-center gap-2",
                        if (cnt > 0L) "ig-col-row-selected" else ""),
          actionButton(ns(paste0("add_out_", nm)), "",
            icon  = icon("plus"),
            class = "btn btn-xs btn-outline-secondary",
            title = paste0("Add ", nm, " to report"),
            onclick = ig_input_event_js(ns("add_avail_out"), nm)),
          tags$code(style = "font-size:0.82rem;", `aria-hidden` = "true", nm),
          span(class = "ig-type-badge", kind),
          if (cnt > 0L)
            span(class = "ms-auto badge bg-secondary rounded-pill",
              title = paste0(nm, " added ", cnt, "x to the report"),
              as.character(cnt))
        )
      })
    })

    # Per-item inputs (heading, note, render) are indexed by position, so any
    # change to the item list re-binds them. Snapshot the user's current edits
    # back into rv_items first, or they would silently revert on
    # add/remove/reorder.
    sync_item_inputs <- function(items) {
      lapply(seq_along(items), function(j) {
        it <- items[[j]]
        h <- input[[paste0("heading_", j)]]
        n <- input[[paste0("note_", j)]]
        r <- input[[paste0("render_", j)]]
        if (!is.null(h)) it$heading <- h
        if (!is.null(n)) it$note    <- n
        if (!is.null(r)) it$render  <- r
        it
      })
    }

    # Add an output entry when the user clicks its "+" button in the left
    # panel. The same output can be added multiple times — each occurrence
    # gets its own heading/note/render-style row in the right panel.
    observeEvent(input$add_avail_out, {
      nm <- input$add_avail_out
      if (!nzchar(nm %||% "")) return()
      outs <- store_available_outputs(store, task_id = task_id)
      if (!nm %in% outs) return()
      objs <- isolate(store$objects)
      obj_names <- names(objs)
      cur <- sync_item_inputs(rv_items())
      cur <- c(cur, list(list(
        name = nm,
        kind = if (nm %in% obj_names) objs[[nm]]$meta$kind %||% "object" else "table",
        heading = nm,
        note = "",
        render = "auto"
      )))
      rv_items(cur)
    })

    observeEvent(input$clear_items, { rv_items(list()) })

    observeEvent(input$rm_item, {
      i <- input$rm_item
      cur <- sync_item_inputs(rv_items())
      cur[[i]] <- NULL
      rv_items(cur)
    })

    # Reorder items — sections render in list order
    observeEvent(input$item_up, {
      i <- input$item_up
      cur <- sync_item_inputs(rv_items())
      if (i > 1L && i <= length(cur)) {
        cur[c(i - 1L, i)] <- cur[c(i, i - 1L)]
        rv_items(cur)
      }
    })
    observeEvent(input$item_dn, {
      i <- input$item_dn
      cur <- sync_item_inputs(rv_items())
      if (i >= 1L && i < length(cur)) {
        cur[c(i, i + 1L)] <- cur[c(i + 1L, i)]
        rv_items(cur)
      }
    })

    # Keep task$inputs in sync with the report's content list so the canvas
    # edges and topo-sort always know which outputs this report depends on —
    # this guarantees those tasks run (and their outputs are computed) before
    # the report does, even on a "Run Flow" that never opens this panel.
    observeEvent(rv_items(), {
      if (is.null(task_id)) return()
      item_names <- unique(Filter(nzchar,
        vapply(rv_items(), function(x) x$name %||% "", character(1))))
      task <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, "report")
      if (!identical(task$inputs %||% character(0), item_names)) {
        task$inputs <- item_names
        store_set_task(store, task)
      }
    })

    # Selected items right panel (ordered, with editable headings).
    # Items whose output is not currently computed are flagged so the user
    # knows the report will silently skip them until the producing task runs.
    output$items_ui <- renderUI({
      items <- rv_items()
      if (length(items) == 0L)
        return(tags$p(class = "text-muted small p-3",
          "Click '+' next to an output on the left to add it to the report."))
      computed <- c(names(store$tables), names(store$objects))

      n_items <- length(items)
      lapply(seq_along(items), function(i) {
        item <- items[[i]]
        is_missing <- !item$name %in% computed
        div(class = "ig-report-item border-bottom pb-2 mb-2",
          # Row 1: order controls, name, status, renderer, remove
          div(class = "d-flex align-items-center gap-2",
            span(class = "text-muted small",
              style = "min-width:18px; text-align:right;", i),
            div(style = "display:flex; flex-direction:column; gap:1px;",
              tags$button(
                class = paste("btn btn-xs btn-outline-secondary",
                              if (i == 1L) "disabled"),
                title = "Move up", `aria-label` = paste("Move", item$name, "up"),
                disabled = if (i == 1L) NA else NULL,
                onclick = if (i > 1L) ig_input_event_js(ns("item_up"), i),
                icon("chevron-up")),
              tags$button(
                class = paste("btn btn-xs btn-outline-secondary",
                              if (i == n_items) "disabled"),
                title = "Move down",
                `aria-label` = paste("Move", item$name, "down"),
                disabled = if (i == n_items) NA else NULL,
                onclick = if (i < n_items) ig_input_event_js(ns("item_dn"), i),
                icon("chevron-down"))
            ),
            tags$code(style = "flex:0 0 auto; font-size:0.8rem; max-width:120px;
                      overflow:hidden; text-overflow:ellipsis; white-space:nowrap;",
              item$name),
            if (is_missing) {
              span(class = "badge bg-danger",
                title = paste0("'", item$name, "' has no data yet \u2014 run the task ",
                               "that produces it, or it will be skipped."),
                "not computed")
            } else {
              span(class = "ig-type-badge", item$kind %||% "table")
            },
            div(class = "ms-auto", style = "width:170px;",
              selectInput(ns(paste0("render_", i)),
                sr_label(paste("Render style for", item$name)),
                choices = REPORT_RENDER_CHOICES,
                selected = item$render %||% "auto", width = "100%")),
            actionButton(ns(paste0("rmitem_", i)), "",
              `aria-label` = paste("Remove", item$name, "from report"),
              title        = paste("Remove", item$name),
              icon  = icon("xmark"),
              class = "btn btn-xs btn-outline-danger",
              onclick = ig_input_event_js(ns("rm_item"), i))
          ),
          # Row 2: heading + optional note shown under the section heading
          div(class = "d-flex align-items-center gap-2 mt-1",
            tagAppendAttributes(
              textInput(ns(paste0("heading_", i)),
                sr_label(paste("Section heading for", item$name)),
                value = item$heading %||% item$name,
                width = "100%",
                placeholder = "Section heading"),
              style = "flex:1;"
            ),
            tagAppendAttributes(
              textInput(ns(paste0("note_", i)),
                sr_label(paste("Note for", item$name)),
                value = item$note %||% "",
                width = "100%",
                placeholder = "Optional note (shown under the heading)"),
              style = "flex:1;"
            )
          )
        )
      })
    })

    # ── Collect params ────────────────────────────────────────────────────
    collect_params <- reactive({
      items <- rv_items()
      items <- lapply(seq_along(items), function(i) {
        it <- items[[i]]
        it$heading <- input[[paste0("heading_", i)]] %||% it$heading %||% it$name
        it$note    <- input[[paste0("note_", i)]]    %||% it$note    %||% ""
        it$render  <- input[[paste0("render_", i)]]  %||% it$render  %||% "auto"
        it
      })
      list(
        title       = trimws(input$rpt_title    %||% ""),
        subtitle    = trimws(input$rpt_subtitle %||% ""),
        author      = trimws(input$rpt_author   %||% ""),
        format      = input$rpt_format          %||% "html",
        items       = items,
        include_log = input$include_log %||% isTRUE(init_p$include_log),
        log_min_level = input$log_min_level %||% init_p$log_min_level %||% "INFO",
        output_name = trimws(input$output_name %||%
                               paste0(task_id %||% "report", "_out"))
      )
    })

    # ── Generate ──────────────────────────────────────────────────────────
    gen_status  <- reactiveVal("")
    report_path <- reactiveVal(NULL)

    output$gen_status <- renderText({ gen_status() })

    do_generate <- function() {
      p       <- collect_params()
      tables  <- isolate(store$tables)
      objects <- lapply(isolate(store$objects), `[[`, "value")

      gen_status("Generating report\u2026")
      result <- execute_report(p, tables, objects,
        log_records = if (isTRUE(p$include_log)) ig_log_records(isolate(store$tasks),
          setdiff(names(isolate(store$tasks)), task_id), p$log_min_level %||% "INFO") else NULL)
      ig_log_result(result)

      if (!is.null(result$error)) {
        gen_status(paste0("\u2717 ", result$error))
        showNotification(paste("Report error:", result$error), type = "error", duration = 8)
        if (!is.null(task_id)) {
          task <- isolate(store$tasks[[task_id]])
          if (!is.null(task)) {
            task$error_msg <- result$error
            task$status    <- "error"
            store_set_task(store, task)
          }
        }
        report_path(NULL)
        return()
      }

      report_path(result$report_path)
      ext <- if (p$format == "word") "docx" else "html"
      gen_status(sprintf("\u2713 Ready \u2014 %s", basename(result$report_path)))
      if (length(result$warnings %||% character(0))) {
        showNotification(paste(result$warnings, collapse = "\n"),
          type = "warning", duration = 8)
      }

      if (!is.null(task_id)) {
        out_name <- p$output_name
        task <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, "report")
        task$params    <- p
        task$r_code    <- build_report_code(p)
        task$run_time  <- Sys.time()
        task$error_msg <- NULL
        task$status    <- "success"
        task$output    <- out_name
        task$outputs   <- list(list(
          name  = out_name,
          kind  = "report",
          label = "Rendered report",
          path  = result$report_path
        ))
        store_set_task(store, task)
      }
      showNotification("Report generated. Click 'Download' to save.", type = "message", duration = 4)
    }

    observeEvent(input$btn_generate, {
      store_run_guarded(store, do_generate, action = "generate reports", task_id = task_id)
    })
    store_register_result_fn(store, task_id, function(result) {
      report_path(result$report_path); gen_status(ig_preview_status(result))
    }, session = session)
    store_register_params_fn(store, task_id, collect_params, session = session)
    if (!is.null(task_id)) session$onFlushed(function() {
      store_register_runner(store, task_id, do_generate)
    }, once = TRUE)

    # ── Download ──────────────────────────────────────────────────────────
    output$download_ui <- renderUI({
      if (is.null(report_path())) return(NULL)
      p   <- collect_params()
      ext <- if (p$format == "word") "docx" else "html"
      downloadButton(ns("dl_report"),
        label = paste("Download", toupper(ext)),
        class = "btn btn-sm btn-outline-secondary")
    })

    output$dl_report <- downloadHandler(
      filename = function() {
        p   <- collect_params()
        ext <- if (p$format == "word") "docx" else "html"
        paste0(gsub("[^A-Za-z0-9_-]", "_", p$output_name %||% "report"), ".", ext)
      },
      content = function(file) {
        path <- report_path()
        if (!is.null(path) && file.exists(path)) {
          file.copy(path, file)
        } else {
          writeLines("Report not yet generated.", file)
        }
      }
    )
  })
}

# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════

default_report_params <- function(output_name = "report_out") {
  list(
    title       = "",
    subtitle    = "",
    author      = "",
    format      = "html",
    items       = list(),
    include_log = FALSE,
    log_min_level = "INFO",
    output_name = output_name
  )
}

#' Generate standalone R code that renders the configured report.
#' @param p Configured task parameter list.
build_report_code <- function(p) {
  items <- Filter(function(x) nzchar(x$name %||% ""), p$items %||% list())
  nms <- unique(vapply(items, `[[`, character(1), "name"))
  out <- r_ident(p$output_name %||% "report_out")
  paste(c(paste0("# Render ", toupper(p$format %||% "html"), " report and companion Rmd/data"),
    paste0(out, " <- local({"),
    code_helper_definitions(c("execute_report", "ig_code_report_log")),
    paste0("  .names <- ", code_literal(nms)),
    "  .available <- .names[vapply(.names, exists, logical(1), inherits = TRUE)]",
    "  .values <- mget(.available, inherits = TRUE)",
    paste0("  .directory <- tempfile(pattern = ", code_literal(paste0("ig_report_", make.names(substr(p$output_name %||% "report_out", 1L, 24L)), "_")), ", tmpdir = getwd())"),
    paste0("  .result <- .ig_codegen$execute_report(", code_literal(p), ", .values, output_dir = .directory",
      if (isTRUE(p$include_log)) paste0(", log_records = .ig_codegen$ig_code_report_log(", code_literal(p$log_min_level %||% "INFO"), ")") else "", ")"),
    "  if (!is.null(.result$error)) stop(.result$error, call. = FALSE)",
    "  if (length(.result$warnings)) warning(paste(.result$warnings, collapse = '\\n'), call. = FALSE)",
    "  .result$report_path", "})"), collapse = "\n")
}

#' Build an Rmd document string from a report params list.
#'
#' @param p        Report params (title, subtitle, author, format, items).
#' @param report_data Named list of tables and objects to embed.
#' @param data_rds Absolute path to the RDS file that carries tbl_data to knitr.
#' @return Single character string — the full .Rmd source.
build_report_rmd <- function(p, report_data, data_rds) {
  title    <- p$title    %||% "Report"
  subtitle <- p$subtitle %||% ""
  author   <- p$author   %||% ""
  fmt      <- p$format   %||% "html"
  items    <- Filter(function(x) nzchar(x$name %||% ""), p$items %||% list())

  out_yaml <- switch(fmt,
    html = "html_document:\n    toc: true\n    toc_float: true\n    df_print: paged\n    mathjax: null",
    word = "word_document:\n    toc: true",
    "html_document:\n    toc: true\n    toc_float: true\n    df_print: paged")

  yaml_string <- function(s) as.character(jsonlite::toJSON(s %||% "", auto_unbox = TRUE))

  header <- paste0(
    '---\ntitle: ', yaml_string(title), '\n',
    if (nzchar(subtitle)) paste0('subtitle: ', yaml_string(subtitle), '\n') else "",
    if (nzchar(author))   paste0('author: ',   yaml_string(author),   '\n') else "",
    'date: "`r format(Sys.Date(), \'%B %d, %Y\')`"\n',
    'output:\n  ', out_yaml, '\n---\n\n',
    '```{r setup, include=FALSE}\n',
    'knitr::opts_chunk$set(echo = FALSE, warning = FALSE, message = FALSE)\n',
    '.ig_restore_object_namespaces <- ', paste(deparse(ig_restore_object_namespaces), collapse = '\n'), '\n',
    '.ig_report_values <- .ig_restore_object_namespaces(readRDS(', code_literal(data_rds), '))\n',
    '```\n\n'
  )

  sections <- paste(vapply(items, function(item) {
    nm      <- item$name    %||% ""
    heading <- item$heading %||% nm
    if (!nzchar(nm) || !nm %in% names(report_data)) return("")
    value <- report_data[[nm]]
    ref <- paste0('.ig_report_values[[', code_literal(nm), ']]')
    body <- ig_report_section_body(item$render %||% "auto", value, ref,
                                   heading, fmt)
    note <- trimws(item$note %||% "")
    paste0(
      "## ", heading, "\n\n",
      if (nzchar(note)) paste0("*", note, "*\n\n") else "",
      body
    )
  }, character(1)), collapse = "")

  paste0(header, sections)
}

#' Build the Rmd body for one report section.
#'
#' `render` is the user's per-item override; "auto" dispatches on the value's
#' ACTUAL class (not the declared item kind, which can go stale when an
#' upstream task changes what it produces):
#'   data frame    -> knitr::kable
#'   ggplot / grob -> figure chunk
#'   htmlwidget    -> chunk value so knitr registers its HTML dependencies
#'                    (HTML output only; Word gets an explanatory note)
#'   anything else -> monospace print() capture, ANSI stripped
#' @keywords internal
#' @param value Value supplied to the helper.
#' @param render Per-section rendering override, or auto for class-based rendering.
#' @param ref R expression referencing the section value in the companion data file.
#' @param esc_h Section heading used in captions and explanatory text.
#' @param fmt Report output format identifier.
ig_report_section_body <- function(render, value, ref, esc_h, fmt) {
  kable_chunk <- paste0(
    "```{r}\n",
    "knitr::kable(", ref, ", caption = ", code_literal(esc_h), ", digits = 4)\n",
    "```\n\n"
  )
  figure_chunk <- paste0(
    "```{r, fig.width = 7.5, fig.height = 4.5}\n",
    ref, "\n",
    "```\n\n"
  )
  # The widget must be the chunk's value — explicit print() inside a
  # results='asis' chunk skips knitr's dependency handling.
  widget_chunk <- paste0("```{r}\n", ref, "\n```\n\n")
  word_note <- function(what) {
    paste0("*", esc_h, " is ", what, " and can only be embedded in HTML ",
           "reports. Choose HTML output to include it.*\n\n")
  }
  dt_chunk <- paste0(
    "```{r}\n",
    "DT::datatable(", ref, ", options = list(pageLength = 10, scrollX = TRUE),",
    " rownames = FALSE)\n",
    "```\n\n"
  )
  print_chunk <- paste0(
    "```{r, results='asis'}\n",
    ".ig_obj <- ", ref, "\n",
    ".ig_strip_ansi <- function(x) gsub('\\033\\\\[[0-9;]*m', '', x)\n",
    "cat('```\\n')\n",
    "if (is.character(.ig_obj)) cat(paste(.ig_strip_ansi(.ig_obj), collapse = '\\n')) else cat(paste(.ig_strip_ansi(capture.output(print(.ig_obj))), collapse = '\\n'))\n",
    "cat('\\n```')\n",
    "rm(.ig_obj, .ig_strip_ansi)\n",
    "```\n\n"
  )

  if (identical(render, "kable") && is.data.frame(value)) return(kable_chunk)
  if (identical(render, "datatable")) {
    if (!is.data.frame(value)) return(print_chunk)
    return(if (identical(fmt, "word")) word_note("an interactive table")
           else dt_chunk)
  }
  if (identical(render, "figure") &&
      inherits(value, c("ggplot", "grob"))) return(figure_chunk)
  if (identical(render, "print")) return(print_chunk)

  # auto — dispatch on class
  if (is.data.frame(value)) return(kable_chunk)
  if (inherits(value, c("ggplot", "grob"))) return(figure_chunk)
  if (inherits(value, c("girafe", "htmlwidget"))) {
    return(if (identical(fmt, "word")) word_note("an interactive widget")
           else widget_chunk)
  }
  print_chunk
}

ig_report_html_escape <- function(x) {
  x <- as.character(x %||% "")
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

ig_report_html_table <- function(x) {
  df <- as.data.frame(x)
  header <- paste0(
    "<tr>",
    paste0("<th>", ig_report_html_escape(names(df)), "</th>", collapse = ""),
    "</tr>"
  )
  rows <- if (nrow(df)) {
    paste(vapply(seq_len(nrow(df)), function(i) {
      vals <- vapply(df[i, , drop = FALSE], function(v) {
        if (is.na(v)) "" else as.character(v)
      }, character(1))
      paste0("<tr>",
             paste0("<td>", ig_report_html_escape(vals), "</td>", collapse = ""),
             "</tr>")
    }, character(1)), collapse = "\n")
  } else {
    paste0("<tr><td colspan=\"", ncol(df), "\">(0 rows)</td></tr>")
  }
  paste0("<table>\n<thead>", header, "</thead>\n<tbody>\n", rows,
         "\n</tbody>\n</table>")
}

ig_report_print_text <- function(x) {
  txt <- if (is.character(x)) {
    x
  } else {
    capture.output(print(x))
  }
  gsub("\033\\[[0-9;]*m", "", txt)
}

# Embed local widget dependencies so a downloaded HTML file is portable even
# when Pandoc is unavailable. Remote URLs remain the widget's own dependencies.
ig_report_resource_uri <- function(path, ancestors = character(0)) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (path %in% ancestors) stop("Circular report resource: ", basename(path))
  ext <- tolower(tools::file_ext(path))
  mime <- switch(ext, css = "text/css", js = "application/javascript",
    png = "image/png", jpg = , jpeg = "image/jpeg", gif = "image/gif",
    svg = "image/svg+xml", woff = "font/woff", woff2 = "font/woff2",
    ttf = "font/ttf", "application/octet-stream")
  if (ext == "css") {
    css <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    matches <- unique(regmatches(css, gregexpr("url\\([^)]+\\)", css, perl = TRUE))[[1]])
    for (match in matches) {
      ref <- trimws(substring(match, 5L, nchar(match) - 1L))
      ref <- sub("^['\"]", "", sub("['\"]$", "", ref))
      if (!nzchar(ref) || grepl("^([[:alpha:]][[:alnum:]+.-]*:|//|#)", ref)) next
      resource <- file.path(dirname(path), utils::URLdecode(sub("[?#].*$", "", ref)))
      uri <- ig_report_resource_uri(resource, c(ancestors, path))
      css <- gsub(match, paste0('url("', uri, '")'), css, fixed = TRUE)
    }
    bytes <- charToRaw(enc2utf8(css))
  } else bytes <- readBin(path, "raw", n = file.info(path)$size)
  paste0("data:", mime, ";base64,", gsub("[\r\n]", "", jsonlite::base64_enc(bytes)))
}

ig_report_widget_html <- function(value) {
  directory <- tempfile("ig_widget_")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  path <- file.path(directory, "widget.html")
  htmlwidgets::saveWidget(value, path, selfcontained = FALSE)
  html <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  attrs <- unique(regmatches(html, gregexpr("(?:src|href)=[\"'][^\"']+[\"']", html, perl = TRUE))[[1]])
  for (attr in attrs) {
    ref <- sub("^[^=]+=[\"']", "", sub("[\"']$", "", attr))
    if (grepl("^([[:alpha:]][[:alnum:]+.-]*:|//|#)", ref)) next
    uri <- ig_report_resource_uri(file.path(directory, utils::URLdecode(ref)))
    replacement <- paste0(sub("=.*$", "", attr), '=\"', uri, '\"')
    html <- gsub(attr, replacement, html, fixed = TRUE)
  }
  sub("</head>", paste0("<style>body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;",
    "font-size:14px;margin:16px}</style></head>"), html, fixed = TRUE)
}

ig_report_write_html <- function(p, report_data, out_file) {
  title    <- p$title    %||% "Report"
  subtitle <- p$subtitle %||% ""
  author   <- p$author   %||% ""
  items    <- Filter(function(x) nzchar(x$name %||% ""), p$items %||% list())
  out_dir  <- dirname(out_file)

  section_html <- vapply(seq_along(items), function(i) {
    item <- items[[i]]
    nm <- item$name %||% ""
    if (!nzchar(nm) || !nm %in% names(report_data)) return("")
    value <- report_data[[nm]]
    heading <- item$heading %||% nm
    note <- trimws(item$note %||% "")
    render <- item$render %||% "auto"
    body <- NULL
    frame_height <- 520L

    if (identical(render, "datatable") && is.data.frame(value)) {
      frame_height <- min(520L, 190L + min(10L, nrow(value)) * 33L)
      value <- DT::datatable(value, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
      render <- "auto"
    }
    if ((identical(render, "auto") || identical(render, "kable")) &&
        is.data.frame(value)) {
      body <- ig_report_html_table(value)
    } else if ((identical(render, "auto") || identical(render, "figure")) &&
               inherits(value, c("ggplot", "grob"))) {
      img_name <- paste0("figure_", i, ".png")
      img_file <- file.path(out_dir, img_name)
      local({
        if (inherits(value, "ggplot")) {
          ggplot2::ggsave(img_file, plot = value, width = 7.5, height = 4.5,
                          dpi = 120)
        } else {
          grDevices::png(img_file, width = 900, height = 540, res = 120)
          on.exit(grDevices::dev.off(), add = TRUE)
          grid::grid.draw(value)
        }
      })
      if (file.exists(img_file)) {
        body <- paste0("<img class=\"figure\" src=\"", ig_report_resource_uri(img_file), "\" alt=\"",
                       ig_report_html_escape(heading), "\">")
      }
    } else if ((identical(render, "auto") || identical(render, "figure")) &&
               inherits(value, c("girafe", "htmlwidget")) &&
               requireNamespace("htmlwidgets", quietly = TRUE)) {
        body <- paste0("<iframe class=\"widget\" srcdoc=\"",
                       ig_report_html_escape(ig_report_widget_html(value)),
                       "\" style=\"height:", frame_height, "px\" title=\"", ig_report_html_escape(heading),
                       "\"></iframe>")
    }

    if (is.null(body)) {
      body <- paste0("<pre>",
        ig_report_html_escape(paste(ig_report_print_text(value), collapse = "\n")),
        "</pre>")
    }

    paste0(
      "<section>",
      "<h2>", ig_report_html_escape(heading), "</h2>",
      if (nzchar(note)) paste0("<p class=\"note\">",
                               ig_report_html_escape(note), "</p>") else "",
      body,
      "</section>"
    )
  }, character(1))

  html <- paste0(
    "<!doctype html>\n<html><head><meta charset=\"utf-8\">",
    "<title>", ig_report_html_escape(title), "</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;",
    "margin:32px;color:#1f2933;line-height:1.45}",
    "h1{margin-bottom:4px}h2{margin-top:32px;border-bottom:1px solid #d9e2ec;",
    "padding-bottom:6px}.meta,.note{color:#52606d}",
    "table{border-collapse:collapse;width:100%;margin-top:12px;font-size:14px}",
    "th,td{border:1px solid #d9e2ec;padding:6px 8px;text-align:left}",
    "th{background:#f0f4f8}pre{background:#f5f7fa;border:1px solid #d9e2ec;",
    "padding:12px;overflow:auto}.figure{max-width:100%;height:auto}",
    ".widget{width:100%;height:520px;border:1px solid #d9e2ec}",
    "</style></head><body>",
    "<h1>", ig_report_html_escape(title), "</h1>",
    if (nzchar(subtitle)) paste0("<p class=\"meta\">",
                                 ig_report_html_escape(subtitle), "</p>") else "",
    if (nzchar(author)) paste0("<p class=\"meta\">",
                               ig_report_html_escape(author), "</p>") else "",
    "<p class=\"meta\">", format(Sys.Date(), "%B %d, %Y"), "</p>",
    paste(section_html, collapse = "\n"),
    "</body></html>"
  )
  writeLines(html, out_file, useBytes = TRUE)
  out_file
}

ig_report_pandoc_available <- function() {
  if (!requireNamespace("rmarkdown", quietly = TRUE)) return(FALSE)
  if (isTRUE(rmarkdown::pandoc_available())) return(TRUE)

  candidates <- unique(Filter(nzchar, c(
    Sys.getenv("RSTUDIO_PANDOC"),
    file.path(Sys.getenv("LOCALAPPDATA"), "Pandoc"),
    file.path(Sys.getenv("ProgramFiles"), "Pandoc")
  )))
  for (dir in candidates) {
    if (file.exists(file.path(dir, "pandoc.exe")) ||
        file.exists(file.path(dir, "pandoc"))) {
      Sys.setenv(RSTUDIO_PANDOC = dir)
      info <- rmarkdown::find_pandoc(cache = FALSE)
      return(!is.null(info$dir) && nzchar(info$dir %||% "") &&
               package_version(as.character(info$version)) >= "1.12.3")
    }
  }
  FALSE
}

#' Execute a report task: build Rmd, render, return file path.
#'
#' @param p       Report params list (title, format, items, ...).
#' @param tables  Named list of data frames from the store.
#' @param objects Named list of object values from the store.
#' @param output_dir Optional persistent destination for generated scripts.
#' @param log_records Optional task log snapshot, included when include_log is enabled.
#' @return List with $report_path (chr path) and $error (chr or NULL).
execute_report <- function(p, tables, objects = list(), output_dir = NULL, log_records = NULL) {
  if (isTRUE(p$include_log)) {
    if (is.null(log_records)) log_records <- ig_log_records(list())
    nm <- ".ig_pipeline_log"
    while (nm %in% c(names(tables), names(objects))) nm <- paste0(nm, "_")
    tables[[nm]] <- log_records
    p$items <- c(p$items, list(list(name = nm, heading = "Pipeline execution log",
      note = "Retained events recorded before report generation; report completion is recorded afterwards. This snapshot can include earlier runs. Disabled logging and events below the selected level are not included.", render = "kable")))
  }
  items <- Filter(function(x) nzchar(x$name %||% ""), p$items %||% list())
  fmt   <- p$format %||% "html"

  if (!fmt %in% c("html", "word"))
    return(list(data = NULL, error = "Choose HTML or Word report format."))

  if (length(items) == 0L)
    return(list(data = NULL, error = "Add at least one output to the report."))

  # Resolve selected names against actual runtime outputs. Saved report params
  # may have stale kinds if an upstream non-table output was selected before it
  # existed in store$objects, so do not trust item$kind for lookup.
  report_data <- list()
  resolved_items <- list()
  for (item in items) {
    nm <- item$name %||% ""
    if (nm %in% names(tables)) {
      value <- tables[[nm]]
      if (inherits(value, "tbl_sql")) {
        value <- tryCatch(dplyr::collect(value), error = function(e) e)
        if (inherits(value, "error")) return(list(data = NULL, error = conditionMessage(value)))
      }
      report_data[nm] <- list(value)
      item$kind <- "table"
      resolved_items <- c(resolved_items, list(item))
    } else if (nm %in% names(objects)) {
      obj <- objects[[nm]]
      report_data[nm] <- list(obj)
      if (is.data.frame(obj)) item$kind <- "table"
      else if (inherits(obj, "girafe")) item$kind <- "plot"
      else if (inherits(obj, "ggplot")) item$kind <- "image"
      else if (inherits(obj, c("lm", "glm", "aov", "kmeans", "prcomp", "nls"))) item$kind <- "model"
      else item$kind <- item$kind %||% "object"
      resolved_items <- c(resolved_items, list(item))
    }
  }

  if (length(report_data) == 0L)
    return(list(data = NULL, error = "No valid output data found for selected items."))

  # Items with no computed value are skipped — tell the caller which ones.
  skipped <- setdiff(vapply(items, `[[`, character(1), "name"),
                     names(report_data))
  warnings <- if (length(skipped)) {
    sprintf("Skipped (no data yet \u2014 run the producing task): %s",
            paste(skipped, collapse = ", "))
  } else character(0)

  # Temp directory per render
  tmp_dir <- output_dir %||% tempfile(pattern = "ig_report_", tmpdir = getOption("IndividualGuide.report_root", tempdir()))
  if (!dir.exists(tmp_dir)) dir.create(tmp_dir, recursive = TRUE)
  tmp_dir <- normalizePath(tmp_dir, winslash = "/", mustWork = TRUE)
  data_rds <- file.path(tmp_dir, "data.rds")
  saveRDS(report_data, data_rds)

  p$items <- resolved_items
  rmd_text <- build_report_rmd(p, report_data, "data.rds")
  rmd_file <- file.path(tmp_dir, "report.Rmd")
  writeLines(rmd_text, rmd_file, useBytes = TRUE)
  pandoc_available <- ig_report_pandoc_available()

  if (!isTRUE(pandoc_available)) {
    if (identical(fmt, "word")) {
      return(list(data = NULL,
        error = paste(
          "Word reports require Pandoc 1.12.3 or newer.",
          "Install Pandoc or choose HTML output."
        )))
    }
    out_file <- file.path(tmp_dir, "report.html")
    out_file <- tryCatch(
      ig_report_write_html(p, report_data, out_file),
      error = function(e) structure(list(error = conditionMessage(e)), class = "render_error")
    )
    if (inherits(out_file, "render_error"))
      return(list(data = NULL, error = out_file$error))
    if (!file.exists(out_file))
      return(list(data = NULL, error = "Rendered report file not found."))
    return(list(data = NULL, report_path = out_file, format = "html",
      warnings = c(warnings,
        "Pandoc was not found; generated HTML with the built-in report renderer."),
      error = NULL))
  }

  out_format <- switch(fmt,
    html = rmarkdown::html_document(toc = TRUE, toc_float = TRUE,
      df_print = "paged", mathjax = NULL),
    word = rmarkdown::word_document(toc = TRUE))

  out_file <- tryCatch(
    rmarkdown::render(
      rmd_file,
      output_format = out_format,
      output_dir    = tmp_dir,
      quiet         = TRUE,
      envir         = new.env(parent = globalenv())
    ),
    error = function(e) structure(list(error = conditionMessage(e)), class = "render_error")
  )

  if (inherits(out_file, "render_error"))
    return(list(data = NULL, error = out_file$error))
  if (!file.exists(out_file))
    return(list(data = NULL, error = "Rendered report file not found."))

  list(data = NULL, report_path = out_file, format = fmt,
       warnings = warnings, error = NULL)
}
