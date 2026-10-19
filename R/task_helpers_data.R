# mod_data_tasks.R — Shared helpers for the Phase 2 data task modules.
#
# The individual task modules were split out for maintainability:
#   mod_data_reshape.R — append_table, compare_data, stack_columns, split_columns, transpose
#   mod_data_rows.R     — filter_sort, rank, standardize, random_sample, remove_dups, first_last_n
#   mod_data_columns.R  — keep_drop_cols, rename_cols, replace_missing, derive_cols, recode_values, change_types
#
# All four files load together as part of the package, so these helpers remain
# in scope for every module.
#
# Depends on (already sourced):
#   qb_build.R, mod_query_builder.R, store.R

# ── Shared UI helpers ──────────────────────────────────────────────────────────

.dt_header <- function(ns, icon_name, title, placeholder = "output_table") {
  bslib::card_header(
    class = "d-flex align-items-center gap-2",
    icon(icon_name), " ", title,
    div(class = "ms-auto d-flex align-items-center gap-2",
      span("Returns table:", class = "text-muted small"),
      textInput(ns("output_name"), sr_label("Output table name"),
        width = "160px", placeholder = placeholder))
  )
}

.dt_footer <- function(ns, preview = TRUE) {
  bslib::card_footer(
    class = "d-flex align-items-center gap-2",
    if (isTRUE(preview))
      actionButton(ns("btn_preview"), "Preview", icon = icon("eye"),
        class = "btn btn-sm btn-outline-secondary"),
    actionButton(ns("btn_run"), "Run & Save", icon = icon("play"),
      class = "btn btn-sm btn-primary"),
    span(class = "ms-auto text-muted small",
      role = "status", `aria-live` = "polite", `aria-atomic` = "true",
      textOutput(ns("run_status"), inline = TRUE))
  )
}

# Standard task card: a Setup tab holding only the configuration inputs, and
# a Results tab holding the preview. Running or previewing the task switches
# to Results automatically (see .dt_render_preview).
.dt_task_shell <- function(ns, icon_name, title, placeholder, ...) {
  bslib::card(
    class = "ig-task-card",
    full_screen = TRUE,
    .dt_header(ns, icon_name, title, placeholder),
    bslib::card_body(
      padding = 0, class = "ig-task-tabs",
      bslib::navset_tab(
        id = ns("task_tabs"),
        bslib::nav_panel(tagList(icon("sliders"), " Setup"), value = "setup",
          div(class = "ig-setup-pane", ...)),
        bslib::nav_panel(tagList(icon("table"), " Results"), value = "results",
          div(class = "ig-results-pane", uiOutput(ns("preview_pane_ui"))))
      )
    ),
    .dt_footer(ns)
  )
}

# Friendly empty state shown on the Results tab before the first run
.dt_results_placeholder <- function() {
  div(class = "ig-results-empty",
    icon("circle-play", class = "ig-results-empty-icon"),
    p("No results yet."),
    p(class = "text-muted small",
      "Configure the task on the Setup tab, then use Preview or Run & Save.")
  )
}

# Save run result into store; update run_status_msg and preview_df reactiveVals.
.dt_save <- function(store, task_id, type_id, params, input_tables,
                     result, r_code, run_status_msg, preview_df) {
  if (!is.null(result$error)) {
    run_status_msg(paste("Error:", result$error))
    showNotification(result$error, type = "error", duration = 8)
    return(store_task_failed(store, task_id, result$error))
  }
  out <- params$output_name %||% ""
  if (!nzchar(out)) {
    showNotification("Output name is required.", type = "warning")
    return(store_task_failed(store, task_id, "Output name is required."))
  }
  store_add_table(store, out, result$data)
  if (!is.null(task_id)) {
    task <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, type_id)
    task$inputs    <- input_tables
    task$output    <- out
    task$params    <- params
    task$r_code    <- r_code %||% ""
    task$run_time  <- Sys.time()
    task$error_msg <- NULL
    store_set_task(store, task)
  }
  nr <- nrow(result$data); nc <- ncol(result$data)
  run_status_msg(sprintf("\u2713 %s: %d \u00d7 %d", out, nr, nc))
  preview_df(head(result$data, 1000L))
  showNotification(sprintf("'%s' created \u2014 %d rows \u00d7 %d cols.", out, nr, nc),
    type = "message", duration = 3)
  invisible(TRUE)
}

.dt_render_preview <- function(output, preview_df, session, store = NULL) {
  ns <- session$ns
  observeEvent(session$input$close_preview, {
    preview_df(NULL)
    bslib::nav_select("task_tabs", "setup", session = session)
  })
  # New results swap the panel to the Results tab; errors leave the user on
  # Setup where the problem is.
  observeEvent(preview_df(), {
    if (!is.null(preview_df()))
      bslib::nav_select("task_tabs", "results", session = session)
  }, ignoreInit = TRUE)
  # Render the pane: a placeholder before the first run, the DT afterwards.
  output$preview_pane_ui <- renderUI({
    df <- preview_df()
    if (is.null(df)) return(.dt_results_placeholder())
    dims <- sprintf("Preview \u2014 %s row%s \u00d7 %d column%s%s",
      formatC(nrow(df), format = "d", big.mark = ","),
      if (nrow(df) == 1L) "" else "s",
      ncol(df), if (ncol(df) == 1L) "" else "s",
      if (nrow(df) >= 1000L) " (first 1,000 shown)" else "")
    tagList(
      div(class = "ig-preview-header",
        span(icon("table"), " ", dims),
        div(class = "ms-auto d-flex align-items-center gap-2",
          downloadButton(ns("dl_preview"), "CSV",
            class = "btn btn-xs btn-outline-secondary",
            title = "Download this preview as CSV"),
          actionButton(ns("close_preview"), "Close preview",
            icon = icon("xmark"),
            class = "btn btn-xs btn-outline-secondary",
            `aria-label` = "Close preview")
        )
      ),
      DT::DTOutput(ns("preview_dt"))
    )
  })
  output$dl_preview <- downloadHandler(
    filename = function() {
      paste0("preview_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
    },
    content = function(file) {
      readr::write_csv(preview_df() %||% data.frame(), file)
    }
  )
  output$preview_dt <- DT::renderDT({
    req(preview_df())
    pg <- if (is.null(store)) 10L else ig_page_len(store)
    DT::datatable(preview_df(),
      options = list(scrollX = TRUE, pageLength = pg, dom = "tip"),
      rownames = FALSE)
  })
}
