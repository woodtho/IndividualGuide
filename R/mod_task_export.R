# mod_export.R — Export task: write a dataset, object, or plot to disk.
#
# A flow SINK. Pick one upstream output, a format (offered to match the output's
# type), a destination folder + file name, then Export. Runs in-app and as part
# of Run Flow; the generated code reproduces the export outside the app. Heavy
# lifting lives in export_writers.R (execute_export / ig_write_* / build_export_code).

default_export_params <- function(output_name = "export_out") {
  list(
    source      = "",
    format      = "csv",
    value_kind  = "data",
    dir         = "",
    filename    = "",
    overwrite   = FALSE,
    append      = FALSE,
    columns     = character(0),
    width       = 8,
    height      = 6,
    dpi         = 300,
    units       = "in",
    bg          = "white",
    transparent = FALSE
  )
}

export_ui <- function(id) {
  ns <- NS(id)
  bslib::card(
    class = "ig-task-card",
    full_screen = TRUE,
    bslib::card_header(
      class = "d-flex align-items-center gap-2",
      icon("file-export"), " Export"
    ),
    bslib::card_body(
      padding = 0, class = "ig-task-tabs",
      bslib::navset_tab(
        id = ns("task_tabs"),
        bslib::nav_panel(
          tagList(icon("sliders"), " Setup"), value = "setup",
          div(class = "ig-setup-pane",
            div(class = "row g-3",
              div(class = "col-md-6",
                selectInput(ns("source"), "Output to export",
                  choices = character(0), width = "100%"),
                div(class = "small text-muted", uiOutput(ns("source_info")))
              ),
              div(class = "col-md-6",
                selectInput(ns("format"), "Format",
                  choices = c("CSV" = "csv"), width = "100%"),
                div(class = "small text-muted", uiOutput(ns("format_hint")))
              )
            ),
            # Format-specific options
            uiOutput(ns("format_options")),
            tags$hr(),
            # Destination
            tags$label(class = "form-label small fw-semibold", "Destination"),
            div(class = "d-flex align-items-center gap-2 mb-2",
              shinyFiles::shinyDirButton(ns("dir_pick"), "Choose folder\u2026",
                title = "Choose export folder", icon = icon("folder-open"),
                class = "btn btn-sm btn-outline-secondary"),
              span(class = "small text-muted", textOutput(ns("dir_display"), inline = TRUE))
            ),
            div(class = "row g-2 align-items-end",
              div(class = "col-md-8",
                textInput(ns("filename"), "File name (without extension)",
                  width = "100%", placeholder = "my_export")),
              div(class = "col-md-4",
                div(class = "small text-muted mb-1", "Will be saved as"),
                tags$code(textOutput(ns("final_name"), inline = TRUE)))
            ),
            div(class = "form-check mt-2",
              tags$input(type = "checkbox", class = "form-check-input", id = ns("overwrite")),
              tags$label(class = "form-check-label small", `for` = ns("overwrite"),
                "Overwrite if the file already exists")
            ),
            # Preview
            div(class = "ig-export-preview mt-3 p-2",
              uiOutput(ns("preview"))
            )
          )
        ),
        bslib::nav_panel(
          tagList(icon("circle-check"), " Result"), value = "results",
          div(class = "ig-results-pane p-3",
            uiOutput(ns("result_ui"))
          )
        )
      )
    ),
    bslib::card_footer(
      class = "d-flex align-items-center gap-2",
      actionButton(ns("btn_run"), "Export", icon = icon("file-export"),
        class = "btn btn-sm btn-primary"),
      span(class = "ms-auto text-muted small",
        role = "status", `aria-live` = "polite",
        textOutput(ns("run_status"), inline = TRUE))
    )
  )
}

export_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    ns <- session$ns
    volumes <- ig_volumes(refresh = TRUE)
    shinyFiles::shinyDirChoose(input, "dir_pick", roots = volumes, session = session)

    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_export_params()
      else default_export_params()
    })

    run_status_msg <- reactiveVal("")
    chosen_dir     <- reactiveVal(init_p$dir %||% "")
    last_result    <- reactiveVal(NULL)

    # Resolve the current source's value + kind from the store.
    src_value <- reactive({
      nm <- input$source %||% ""
      if (!nzchar(nm)) return(NULL)
      tbls <- store$tables
      if (nm %in% names(tbls)) return(tbls[[nm]])
      objs <- store$objects
      if (nm %in% names(objs)) return(objs[[nm]]$value)
      NULL
    })

    # Declared kind for sources not yet computed (from task output specs).
    declared_kind <- reactive({
      nm <- input$source %||% ""
      if (!nzchar(nm)) return(NA_character_)
      for (t in store$tasks) {
        for (spec in task_output_specs(t)) {
          if (identical(spec$name, nm)) return(spec$kind %||% "table")
        }
      }
      NA_character_
    })

    src_kind <- reactive({
      v <- src_value()
      if (!is.null(v)) return(ig_export_value_kind(v))
      # Fall back to the declared kind when the output hasn't been computed yet.
      dk <- declared_kind()
      if (is.na(dk)) return("data")
      switch(dk, table = "data", plot = "plot_interactive",
             image = "plot_gg", "object")
    })

    # ── Populate the source list, restoring the saved selection ─────────────────
    session$onFlushed(function() {
      outs <- isolate(store_available_outputs(store, task_id = task_id))
      sel  <- if (nzchar(init_p$source %||% "") && init_p$source %in% outs)
                init_p$source else outs[1] %||% ""
      updateSelectInput(session, "source", choices = outs, selected = sel)
      updateTextInput(session, "filename",
        value = init_p$filename %||% sel %||% "export")
      session$sendInputMessage("overwrite", list(value = isTRUE(init_p$overwrite)))
    }, once = TRUE)

    observe({
      outs <- store_available_outputs(store, task_id = task_id)   # reactive dep
      updateSelectInput(session, "source", choices = outs,
        selected = isolate(input$source))
    })

    # ── Keep the format menu in step with the source kind ───────────────────────
    observeEvent(src_kind(), {
      fmts <- IG_EXPORT_FORMATS[[src_kind()]] %||% IG_EXPORT_FORMATS$object
      named <- stats::setNames(fmts, vapply(fmts, ig_format_label, character(1)))
      keep  <- if ((init_p$format %||% "") %in% fmts) init_p$format
               else if ((input$format %||% "") %in% fmts) input$format else fmts[1]
      updateSelectInput(session, "format", choices = named, selected = keep)
    }, ignoreNULL = FALSE)

    # ── Destination folder via shinyFiles ───────────────────────────────────────
    observeEvent(input$dir_pick, {
      path <- tryCatch(shinyFiles::parseDirPath(volumes, input$dir_pick),
                       error = function(e) character(0))
      if (length(path) == 1L && nzchar(path)) chosen_dir(as.character(path))
    })
    output$dir_display <- renderText({
      d <- chosen_dir(); if (nzchar(d)) d else "No folder chosen yet."
    })

    output$final_name <- renderText({
      ig_export_path("", input$filename %||% (input$source %||% "export"),
                     input$format %||% "csv") |> basename()
    })

    output$source_info <- renderUI({
      v <- src_value()
      if (is.null(v)) {
        return(tagList(icon("circle-info"),
          " Not computed yet \u2014 run upstream first to preview and pick formats."))
      }
      k <- ig_export_value_kind(v)
      lbl <- switch(k, data = "dataset", plot_gg = "static plot",
                    plot_interactive = "interactive plot", "object")
      if (is.data.frame(v))
        tagList(icon("table"), sprintf(" %s \u00b7 %s rows \u00d7 %d cols", lbl,
          formatC(nrow(v), format = "d", big.mark = ","), ncol(v)))
      else
        tagList(icon("cube"), sprintf(" %s (%s)", lbl, class(v)[1]))
    })

    output$format_hint <- renderUI({
      if (identical(src_kind(), "plot_interactive"))
        tagList(icon("circle-info"),
          " Interactive plot \u2014 export as HTML or SVG.")
      else NULL
    })

    # ── Format-specific option panels ───────────────────────────────────────────
    output$format_options <- renderUI({
      k <- src_kind()
      if (k %in% c("plot_gg", "plot_interactive")) {
        if (identical(k, "plot_interactive")) return(NULL)
        div(class = "row g-2 mt-1",
          div(class = "col-6 col-md-2",
            numericInput(ns("width"), "Width", value = init_p$width %||% 8, min = 1)),
          div(class = "col-6 col-md-2",
            numericInput(ns("height"), "Height", value = init_p$height %||% 6, min = 1)),
          div(class = "col-6 col-md-2",
            numericInput(ns("dpi"), "DPI", value = init_p$dpi %||% 300, min = 36)),
          div(class = "col-6 col-md-2",
            selectInput(ns("units"), "Units",
              choices = c("in", "cm", "mm", "px"), selected = init_p$units %||% "in")),
          div(class = "col-6 col-md-2",
            textInput(ns("bg"), "Background", value = init_p$bg %||% "white")),
          div(class = "col-6 col-md-2 d-flex align-items-end",
            div(class = "form-check",
              tags$input(type = "checkbox", class = "form-check-input",
                id = ns("transparent")),
              tags$label(class = "form-check-label small", `for` = ns("transparent"),
                "Transparent")))
        )
      } else if (identical(k, "data")) {
        v <- src_value()
        cols <- if (is.data.frame(v)) names(v) else character(0)
        fmt  <- input$format %||% "csv"
        tagList(
          if (length(cols))
            selectInput(ns("columns"), "Columns to export (blank = all)",
              choices = cols, selected = intersect(init_p$columns %||% character(0), cols),
              multiple = TRUE, width = "100%"),
          if (fmt %in% c("csv", "tsv"))
            div(class = "form-check",
              tags$input(type = "checkbox", class = "form-check-input", id = ns("append")),
              tags$label(class = "form-check-label small", `for` = ns("append"),
                "Append to an existing file"))
        )
      } else NULL
    })

    # ── Live preview ────────────────────────────────────────────────────────────
    output$preview <- renderUI({
      v   <- src_value()
      dir <- chosen_dir()
      path <- if (nzchar(dir))
        ig_export_path(dir, input$filename %||% (input$source %||% "export"),
                       input$format %||% "csv") else "(choose a folder)"
      est <- if (is.null(v)) "\u2014" else ig_fmt_bytes(as.numeric(utils::object.size(v)))
      dims <- if (is.data.frame(v))
        sprintf("%s rows \u00d7 %d cols",
          formatC(nrow(v), format = "d", big.mark = ","), ncol(v)) else "\u2014"
      tagList(
        tags$div(tags$strong("Path: "), tags$code(path)),
        tags$div(class = "small text-muted mt-1",
          sprintf("Source size: %s \u00b7 Dimensions: %s", est, dims))
      )
    })

    # ── Collect params ──────────────────────────────────────────────────────────
    collect_p <- reactive({
      list(
        source      = input$source %||% "",
        format      = input$format %||% "csv",
        value_kind  = src_kind(),
        dir         = chosen_dir(),
        filename    = trimws(input$filename %||% ""),
        overwrite   = isTRUE(input$overwrite),
        append      = isTRUE(input$append) && input$format %in% c("csv", "tsv"),
        columns     = input$columns %||% character(0),
        width       = input$width %||% 8,
        height      = input$height %||% 6,
        dpi         = input$dpi %||% 300,
        units       = input$units %||% "in",
        bg          = input$bg %||% "white",
        transparent = isTRUE(input$transparent)
      )
    })

    do_run <- function() {
      p       <- collect_p()
      tables  <- isolate(store$tables)
      objects <- lapply(isolate(store$objects), `[[`, "value")
      res     <- execute_export(p, tables, objects)

      .desc_goto_results(session)
      last_result(res)

      if (!is.null(res$error)) {
        run_status_msg(paste("Error:", res$error))
        showNotification(res$error, type = "error", duration = 8)
        if (!is.null(task_id)) {
          task <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, "export")
          task$inputs    <- if (nzchar(p$source)) p$source else character(0)
          task$params    <- p
          task$error_msg <- res$error
          store_set_task(store, task)
        }
        return(invisible(FALSE))
      }

      run_status_msg(sprintf("\u2713 Exported to %s", basename(res$file)))
      showNotification(sprintf("Exported to %s (%s).", res$file,
        ig_fmt_bytes(res$info$size)), type = "message", duration = 4)

      if (!is.null(task_id)) {
        task <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, "export")
        task$inputs    <- if (nzchar(p$source)) p$source else character(0)
        task$output    <- ""           # sink — produces a file, no flow output
        task$outputs   <- list()
        task$params    <- p
        task$export_file <- res$file   # remembered for the download shortcut
        task$r_code    <- build_export_code(p)
        task$run_time  <- Sys.time()
        task$error_msg <- NULL
        store_set_task(store, task)
      }
      invisible(TRUE)
    }

    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })

    store_register_result_fn(store, task_id, function(result) {
      last_result(result); run_status_msg(ig_preview_status(result))
    }, session = session)
    store_register_params_fn(store, task_id, collect_p, session = session)
    if (!is.null(task_id)) session$onFlushed(function() {
      store_register_runner(store, task_id, do_run)
    }, once = TRUE)
    store_register_code_fn(store, task_id, function() build_export_code(collect_p()))

    # ── Result tab ──────────────────────────────────────────────────────────────
    output$result_ui <- renderUI({
      res <- last_result()
      if (is.null(res)) return(p(class = "text-muted", "Run the export to see results here."))
      if (!is.null(res$error))
        return(div(class = "text-danger", icon("circle-xmark"), " ", res$error))
      div(
        div(class = "text-success mb-2", icon("circle-check"),
          " Export complete."),
        tags$dl(class = "row small mb-2",
          tags$dt(class = "col-3", "File"),     tags$dd(class = "col-9", tags$code(res$file)),
          tags$dt(class = "col-3", "Format"),   tags$dd(class = "col-9", ig_format_label(res$info$format)),
          tags$dt(class = "col-3", "Size"),     tags$dd(class = "col-9", ig_fmt_bytes(res$info$size)),
          if (!is.null(res$info$rows)) tagList(
            tags$dt(class = "col-3", "Rows \u00d7 Cols"),
            tags$dd(class = "col-9", sprintf("%s \u00d7 %d",
              formatC(res$info$rows, format = "d", big.mark = ","), res$info$cols)))
        ),
        downloadButton(ns("dl"), "Download a copy", class = "btn btn-sm btn-outline-secondary")
      )
    })

    output$dl <- downloadHandler(
      filename = function() basename(last_result()$file %||% "export"),
      content  = function(file) {
        src <- last_result()$file
        if (!is.null(src) && file.exists(src)) file.copy(src, file, overwrite = TRUE)
      }
    )

    output$run_status <- renderText(run_status_msg())
  })
}

# export_writers.R — Format catalogue and writers for the Export task.
#
# The Export task is a flow SINK: it reads one upstream output (a dataset, an
# object, or a plot) and writes it to disk in a chosen format. execute_export()
# is the headless entry point (used by the panel Run button AND Run Flow); the
# ig_write_* helpers do the actual writing and are mirrored by build_export_code()
# so the generated script reproduces the export outside Individual Guide.

# ── Format catalogue ──────────────────────────────────────────────────────────

# Per-kind format menus. plot_gg = static ggplot / "image" outputs (full raster +
# vector via ggsave); plot_interactive = girafe/htmlwidget outputs (HTML + SVG).
IG_EXPORT_FORMATS <- list(
  data             = c("csv", "tsv", "parquet", "feather", "xlsx", "json", "rds", "rdata"),
  object           = c("rds", "rdata"),
  plot_gg          = c("png", "jpeg", "tiff", "svg", "pdf"),
  plot_interactive = c("html", "svg")
)

ig_format_meta <- list(
  csv     = list(ext = "csv",     label = "CSV (comma-separated)"),
  tsv     = list(ext = "tsv",     label = "TSV (tab-separated)"),
  parquet = list(ext = "parquet", label = "Parquet (Apache Arrow)"),
  feather = list(ext = "feather", label = "Feather / Arrow IPC"),
  xlsx    = list(ext = "xlsx",    label = "Excel workbook (.xlsx)"),
  json    = list(ext = "json",    label = "JSON"),
  rds     = list(ext = "rds",     label = "R serialized object (.rds)"),
  rdata   = list(ext = "RData",   label = "R data file (.RData)"),
  png     = list(ext = "png",     label = "PNG image"),
  jpeg    = list(ext = "jpg",     label = "JPEG image"),
  tiff    = list(ext = "tiff",    label = "TIFF image"),
  svg     = list(ext = "svg",     label = "SVG vector"),
  pdf     = list(ext = "pdf",     label = "PDF document"),
  html    = list(ext = "html",    label = "Interactive HTML")
)

ig_format_ext   <- function(fmt) (ig_format_meta[[fmt]] %||% list(ext = "out"))$ext
ig_format_label <- function(fmt) (ig_format_meta[[fmt]] %||% list(label = fmt))$label

# Classify a value into one of: "data", "object", "plot_gg", "plot_interactive".
ig_export_value_kind <- function(value) {
  if (inherits(value, c("girafe", "htmlwidget"))) return("plot_interactive")
  if (inherits(value, "ggplot"))                  return("plot_gg")
  if (is.data.frame(value) || inherits(value, "tbl_sql")) return("data")
  "object"
}

# The format menu to show for a value (and, for tables, the data menu).
ig_export_formats_for_value <- function(value) {
  IG_EXPORT_FORMATS[[ig_export_value_kind(value)]] %||% IG_EXPORT_FORMATS$object
}

# ── Writers ───────────────────────────────────────────────────────────────────

ig_write_data <- function(df, file, fmt, name = "data", append = FALSE) {
  df <- as.data.frame(df)
  switch(fmt,
    csv     = readr::write_csv(df, file, append = isTRUE(append)),
    tsv     = readr::write_tsv(df, file, append = isTRUE(append)),
    parquet = arrow::write_parquet(df, file),
    feather = arrow::write_feather(df, file),
    xlsx    = writexl::write_xlsx(
                stats::setNames(list(df), substr(make.names(name), 1, 31)), file),
    json    = jsonlite::write_json(df, file, dataframe = "rows",
                auto_unbox = TRUE, na = "null", pretty = TRUE),
    rds     = saveRDS(df, file),
    rdata   = { e <- new.env(); assign(name, df, envir = e)
                save(list = name, envir = e, file = file) },
    stop("Unsupported data format: ", fmt))
  invisible(file)
}

ig_write_object <- function(obj, file, fmt, name = "object") {
  switch(fmt,
    rds   = saveRDS(obj, file),
    rdata = { e <- new.env(); assign(name, obj, envir = e)
              save(list = name, envir = e, file = file) },
    stop("Unsupported object format: ", fmt))
  invisible(file)
}

# Extract the embedded <svg> markup from a girafe / htmlwidget.
ig_girafe_svg <- function(g) {
  h <- tryCatch(g$x$html, error = function(e) NULL)
  txt <- paste(as.character(h %||% ""), collapse = "\n")
  if (!grepl("<svg", txt, fixed = TRUE))
    stop("Could not extract SVG from the interactive plot.")
  txt
}

ig_write_plot <- function(plot, file, fmt, opts = list()) {
  w     <- suppressWarnings(as.numeric(opts$width  %||% 8));  if (is.na(w)) w <- 8
  h     <- suppressWarnings(as.numeric(opts$height %||% 6));  if (is.na(h)) h <- 6
  dpi   <- suppressWarnings(as.numeric(opts$dpi    %||% 300)); if (is.na(dpi)) dpi <- 300
  units <- opts$units %||% "in"
  bg    <- if (isTRUE(opts$transparent)) "transparent" else (opts$bg %||% "white")

  if (inherits(plot, c("girafe", "htmlwidget"))) {
    if (identical(fmt, "html")) {
      writeLines(ig_report_widget_html(plot), file, useBytes = TRUE)
    } else if (identical(fmt, "svg")) {
      writeLines(ig_girafe_svg(plot), file, useBytes = TRUE)
    } else {
      stop("Interactive plots export to HTML or SVG. For ", toupper(fmt),
           ", export the static plot ('image') output instead.")
    }
    return(invisible(file))
  }

  if (inherits(plot, "ggplot")) {
    ggplot2::ggsave(filename = file, plot = plot, width = w, height = h,
                    dpi = dpi, units = units, bg = bg,
                    device = if (identical(fmt, "jpeg")) "jpeg" else fmt)
    return(invisible(file))
  }

  # Generic printable / recorded plot → open the right device and draw it.
  switch(fmt,
    png  = grDevices::png(file, width = w, height = h, units = units, res = dpi, bg = bg),
    jpeg = grDevices::jpeg(file, width = w, height = h, units = units, res = dpi, bg = bg),
    tiff = grDevices::tiff(file, width = w, height = h, units = units, res = dpi, bg = bg),
    svg  = svglite::svglite(file, width = w, height = h, bg = bg),
    pdf  = grDevices::pdf(file, width = w, height = h, bg = bg),
    stop("Unsupported plot format: ", fmt))
  on.exit(grDevices::dev.off(), add = TRUE)
  if (inherits(plot, "recordedplot")) grDevices::replayPlot(plot) else print(plot)
  invisible(file)
}

# ── Path helpers ──────────────────────────────────────────────────────────────

# Compose the full destination path from a directory, base name and format.
ig_export_path <- function(dir, base, fmt) {
  base <- trimws(base %||% "")
  if (grepl("[/\\\\]", base)) stop("File name must not contain directory separators.")
  extensions <- unique(vapply(ig_format_meta, `[[`, character(1), "ext"))
  base <- sub(paste0("\\.(", paste(extensions, collapse = "|"), ")$"), "", base, ignore.case = TRUE)
  if (!nzchar(base)) base <- "export"
  file.path(dir, paste0(base, ".", ig_format_ext(fmt)))
}

# ── Headless execution ────────────────────────────────────────────────────────

#' Execute an Export task.
#'
#' @param p       params list (source, format, dir, filename, overwrite,
#'                columns, append, width/height/dpi/units/bg/transparent)
#' @param tables  named list of data frames
#' @param objects named list of object VALUES (already unwrapped from $value)
#' @return list(error, file, info) — info has rows/cols/size where applicable.
execute_export <- function(p, tables = list(), objects = list()) {
  src <- trimws(p$source %||% "")
  if (!nzchar(src))
    return(list(error = "No source selected \u2014 choose a dataset, object, or plot to export."))

  value <- if (src %in% names(tables)) tables[[src]]
           else if (src %in% names(objects)) objects[[src]]
           else NULL
  if (!src %in% c(names(tables), names(objects)))
    return(list(error = sprintf(
      "Source '%s' is not available yet \u2014 run the task that produces it first.", src)))

  if (inherits(value, "tbl_sql")) {
    value <- tryCatch(as.data.frame(dplyr::collect(value)), error = function(e) e)
    if (inherits(value, "error")) return(list(error = conditionMessage(value)))
  }
  vkind <- ig_export_value_kind(value)
  fmt   <- p$format %||% (ig_export_formats_for_value(value)[1])
  if (isTRUE(p$append) && !fmt %in% c("csv", "tsv")) return(list(error = "Append is supported only for CSV and TSV exports."))
  if (!fmt %in% ig_export_formats_for_value(value)) return(list(error = if (vkind == "plot_interactive")
    "Interactive plots export to HTML or SVG; choose the static image output for raster formats." else paste("Unsupported format for this output:", fmt)))
  dir   <- p$dir %||% ""
  if (!nzchar(dir))
    return(list(error = "No destination folder chosen."))
  if (!dir.exists(dir))
    return(list(error = sprintf("Destination folder does not exist: %s", dir)))

  file <- tryCatch(ig_export_path(dir, p$filename %||% src, fmt), error = function(e) e)
  if (inherits(file, "error")) return(list(error = conditionMessage(file)))
  if (file.exists(file) && !isTRUE(p$overwrite) && !isTRUE(p$append))
    return(list(error = sprintf(
      "File already exists (enable Overwrite to replace it): %s", file)))

  temporary <- tempfile(".ig_export_", tmpdir = normalizePath(dir), fileext = paste0(".", ig_format_ext(fmt)))
  on.exit(unlink(temporary), add = TRUE)
  if (isTRUE(p$append) && file.exists(file) && !file.copy(file, temporary))
    return(list(error = "Could not prepare the existing export for append."))
  append_existing <- isTRUE(p$append) && file.exists(file)
  exported_columns <- if (is.data.frame(value)) ncol(value) else NULL
  err <- tryCatch({
    if (vkind %in% c("plot_gg", "plot_interactive")) {
      ig_write_plot(value, temporary, fmt, p)
    } else if (vkind == "object") {
      ig_write_object(value, temporary, fmt, make.names(src))
    } else {
      df <- as.data.frame(value)
      cols <- p$columns %||% character(0)
      missing <- setdiff(cols, names(df))
      if (length(missing)) stop("Columns not found: ", paste(missing, collapse = ", "))
      if (length(cols)) df <- df[, cols, drop = FALSE]
      exported_columns <- ncol(df)
      ig_write_data(df, temporary, fmt, name = make.names(src), append = append_existing)
    }
    ig_replace_file(temporary, file)
    NULL
  }, error = function(e) conditionMessage(e))

  if (!is.null(err)) return(list(error = err))

  size <- tryCatch(file.info(file)$size, error = function(e) NA_real_)
  info <- list(file = file, format = fmt, size = size)
  if (vkind == "data") {
    df <- as.data.frame(value)
    info$rows <- nrow(df); info$cols <- exported_columns
  }
  list(error = NULL, file = file, info = info)
}

# ── Code generation ───────────────────────────────────────────────────────────

build_export_plot_code <- function(src, fmt, p) {
  if (identical(fmt, "html"))
    return(sprintf('htmlwidgets::saveWidget(%s, export_path, selfcontained = TRUE)', src))
  if (identical(p$value_kind %||% "", "plot_interactive") && identical(fmt, "svg"))
    return(sprintf('writeLines(%s$x$html, export_path)', src))
  bg <- if (isTRUE(p$transparent)) "transparent" else (p$bg %||% "white")
  sprintf(paste0('ggplot2::ggsave(export_path, plot = %s,\n',
                 '  width = %s, height = %s, dpi = %s, units = "%s", bg = "%s")'),
          src, p$width %||% 8, p$height %||% 6, p$dpi %||% 300,
          p$units %||% "in", bg)
}

#' Generate reproducible R code for an Export task (stored in task$r_code).
#' @param p Configured task parameter list.
build_export_code <- function(p) {
  src   <- p$source %||% "data"
  fmt   <- p$format %||% "csv"
  file  <- ig_export_path(p$dir %||% ".", p$filename %||% src, fmt)
  literal <- code_literal
  plot_format <- fmt %in% c(IG_EXPORT_FORMATS$plot_gg, IG_EXPORT_FORMATS$plot_interactive)
  body <- if (plot_format) c(code_helper_definitions("ig_write_plot"),
    sprintf(".ig_codegen$ig_write_plot(.ig_value, export_path, %s, %s)", literal(fmt), literal(p))) else switch(fmt,
    csv = "readr::write_csv(.ig_value, export_path, append = .ig_append)",
    tsv = "readr::write_tsv(.ig_value, export_path, append = .ig_append)",
    parquet = "arrow::write_parquet(.ig_value, export_path)",
    feather = "arrow::write_feather(.ig_value, export_path)",
    xlsx = sprintf("writexl::write_xlsx(setNames(list(.ig_value), %s), export_path)", literal(substr(make.names(src), 1, 31))),
    json = 'jsonlite::write_json(.ig_value, export_path, dataframe = "rows", auto_unbox = TRUE, na = "null", pretty = TRUE)',
    rdata = c(".ig_saved <- new.env()", sprintf("assign(%s, .ig_value, envir = .ig_saved)", literal(make.names(src))),
      sprintf("save(list = %s, envir = .ig_saved, file = export_path)", literal(make.names(src)))),
    rds = "saveRDS(.ig_value, export_path)",
    "stop('Unsupported export format.')")
  cols <- p$columns %||% character(0)
  lines <- c(sprintf("# Export %s to %s", literal(src), ig_format_label(fmt)), ".ig_export_file <- local({",
    paste0(".ig_replace_file <- ", paste(deparse(ig_replace_file), collapse = "\n")),
    sprintf("export_path <- %s", literal(file)),
    "if (!dir.exists(dirname(export_path))) stop('Destination folder does not exist.')",
    if (isTRUE(p$append) && !fmt %in% c("csv", "tsv")) "stop('Append is supported only for CSV and TSV exports.')",
    if (!isTRUE(p$overwrite) && !isTRUE(p$append)) "if (file.exists(export_path)) stop('File already exists; enable Overwrite to replace it.')",
    sprintf(".ig_value <- %s", r_ident(src)),
    "if (inherits(.ig_value, 'tbl_sql')) .ig_value <- as.data.frame(dplyr::collect(.ig_value))",
    sprintf(".ig_formats <- %s", literal(IG_EXPORT_FORMATS)),
    ".ig_kind <- if (inherits(.ig_value, c('girafe', 'htmlwidget'))) 'plot_interactive' else if (inherits(.ig_value, 'ggplot')) 'plot_gg' else if (is.data.frame(.ig_value)) 'data' else 'object'",
    sprintf("if (!%s %%in%% .ig_formats[[.ig_kind]]) stop('Unsupported format for this output.')", literal(fmt)),
    if (length(cols)) c(sprintf("if (is.data.frame(.ig_value)) .ig_value <- dplyr::select(.ig_value, dplyr::all_of(%s))", literal(cols))),
    "if (is.data.frame(.ig_value)) .ig_value <- as.data.frame(.ig_value)",
    sprintf(".ig_append <- %s && file.exists(export_path)", if (isTRUE(p$append)) "TRUE" else "FALSE"),
    sprintf(".ig_temporary <- tempfile('.ig_export_', tmpdir = normalizePath(dirname(export_path)), fileext = %s)", literal(paste0(".", ig_format_ext(fmt)))),
    "on.exit(unlink(.ig_temporary), add = TRUE)",
    "if (.ig_append && !file.copy(export_path, .ig_temporary)) stop('Could not prepare the existing export for append.')",
    ".ig_destination <- export_path", "export_path <- .ig_temporary", body,
    ".ig_replace_file(.ig_temporary, .ig_destination)", ".ig_destination", "})")
  paste(lines, collapse = "\n")
}

# Human-readable file size.
ig_fmt_bytes <- function(n) {
  if (is.na(n) || !is.finite(n)) return("\u2014")
  units <- c("B", "KB", "MB", "GB", "TB")
  i <- if (n <= 0) 1L else min(length(units), floor(log(n, 1024)) + 1L)
  sprintf("%.1f %s", n / 1024^(i - 1L), units[i])
}
