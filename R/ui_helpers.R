# ui_helpers.R — Shared UI widget helpers used across task modules

# Formatted previews are static gt tables; selection uses the separate Data
# tab. Avoid gt's interactive input binding/global bindAll for these previews,
# which otherwise duplicates unrelated output registrations during undo.
ig_gt_output <- function(id) shiny::uiOutput(id)

ig_render_gt <- function(expr, env = parent.frame(), quoted = FALSE) {
  force(env)
  expression <- if (quoted) expr else substitute(expr)
  shiny::renderUI({
    table <- eval(expression, envir = env)
    if (!is.null(table)) shiny::HTML(gt::as_raw_html(table))
  })
}

# ── Output-name widget ─────────────────────────────────────────────────────────

#' Compact output-name row: labelled text field + save/suppress toggle switch.
#'
#' Drop-in for any bare textInput() used to name a task's output table.
#' The Bootstrap form-switch lets the user suppress the output entirely without
#' deleting the name. Server side: check `isTRUE(input[[toggle_id]])` before
#' calling store_add_table() / .desc_save(..., enabled = ...).
#'
#' @param ns          Shiny module namespace function
#' @param id          Input id for the text field          (default "output_name")
#' @param label       Human label shown in the header      (default "Output table")
#' @param placeholder Placeholder text for the text field
#' @param toggle      Whether to show the Save toggle switch
#' @param toggle_id   Input id for the checkbox; auto-derived from id when NULL
#' @param enabled     Initial toggle state (TRUE = Save on by default)
output_save_ui <- function(ns, id = "output_name", label = "Output table",
                            placeholder = NULL, toggle = TRUE,
                            toggle_id = NULL, enabled = TRUE) {
  if (toggle && is.null(toggle_id)) toggle_id <- paste0(id, "_enabled")
  if (is.null(placeholder)) placeholder <- id

  # checkboxInput() creates a div.form-check; tagAppendAttributes adds form-switch
  save_switch <- if (toggle) {
    cb <- checkboxInput(ns(toggle_id),
      label = span("Save", class = "text-muted small"),
      value = enabled)
    cb <- tagAppendAttributes(cb, class = "form-switch ms-auto mb-0")
    cb
  }

  div(class = "ig-output-row",
    div(class = "ig-output-row-head",
      span(class = "ig-output-label", `aria-hidden` = "true",
        icon("table-list"), "\u2009", label),
      save_switch
    ),
    # Real (visually hidden) label gives the field an accessible name; the
    # decorative header span above is aria-hidden to avoid double reading.
    textInput(ns(id), sr_label(label), width = "100%",
      placeholder = placeholder)
  )
}

# ── Multi-output info badge ────────────────────────────────────────────────────

#' Inline note listing auto-generated secondary output names.
#' Pass a reactive primary name as a character string (already resolved).
#' @param primary Label for the primary result table.
#' @param types Names of additional result types to describe.
broom_outputs_note <- function(primary, types = c("tidy", "glance", "augment")) {
  badges <- lapply(types, function(t) {
    tags$code(class = "ig-output-badge", paste0(primary, "_", t))
  })
  div(class = "ig-broom-note text-muted small mt-1",
    icon("wand-magic-sparkles"),
    " Also saves: ",
    tagList(interleave_tags(badges, ", "))
  )
}

interleave_tags <- function(lst, sep) {
  if (!length(lst)) return(tagList())
  out <- vector("list", 2L * length(lst) - 1L)
  for (i in seq_along(lst)) {
    out[[2L * i - 1L]] <- lst[[i]]
    if (i < length(lst)) out[[2L * i]] <- sep
  }
  tagList(out)
}

# ── Shared task preview visibility helper ─────────────────────────────────────

#' Register a result_visible output binding so conditionalPanel can hide/show
#' the preview pane.  Call once in any describe/data task server after the
#' status or result reactiveVal is defined.
#'
#' @param output      The module output list
#' @param status_rv   A reactiveVal or reactive that returns non-empty when results exist.
#'                    Typically run_status_msg or result_df.
register_preview_visible <- function(output, status_rv) {
  output$result_visible <- reactive({
    val <- status_rv()
    if (is.null(val)) return(FALSE)
    if (is.character(val)) return(nzchar(val))
    TRUE
  })
  outputOptions(output, "result_visible", suspendWhenHidden = FALSE)
}

# ── Shared task preview tabset ────────────────────────────────────────────────

#' Standard three-tab preview panel used across all stat task modules.
#' Tabs: Results (gt) | Data (DT) | Code (verbatim).
#' Pass include_plot = TRUE for tasks that also render a ggiraph plot.
#' The whole tabset is wrapped in a conditionalPanel keyed on `output['result_visible']`
#' so the pane collapses to zero height until analysis has been run.
#' @param ns Shiny module namespace function.
#' @param include_plot Whether to include the interactive plot preview tab.
task_preview_tabset <- function(ns, include_plot = FALSE) {
  result_tab <- bslib::nav_panel(
    title = tagList(icon("chart-bar"), " Results"),
    value = "Results",
    div(class = "ig-result-panel ig-formatted-results",
      ig_gt_output(ns("result_gt")))
  )
  data_tab <- bslib::nav_panel(
    title = tagList(icon("table"), " Data"),
    value = "Data",
    div(class = "ig-result-panel",
      DT::DTOutput(ns("result_dt")))
  )
  code_tab <- bslib::nav_panel(
    title = tagList(icon("code"), " Code"),
    value = "Code",
    div(class = "ig-result-panel ig-code-panel",
      verbatimTextOutput(ns("task_code_view")))
  )

  build_navset <- function(...) {
    tagList(
      # Friendly empty state until the first analysis has run
      conditionalPanel(
        condition = sprintf("!output['%s']", ns("result_visible")),
        .dt_results_placeholder()
      ),
      conditionalPanel(
        condition = sprintf("output['%s']", ns("result_visible")),
        do.call(bslib::navset_tab, list(...))
      )
    )
  }

  if (include_plot) {
    plot_tab <- bslib::nav_panel(
      title = tagList(icon("image"), " Plot"),
      value = "Plot",
      div(class = "ig-result-panel",
        ggiraph::girafeOutput(ns("plot_out"), width = "100%", height = "340px"))
    )
    build_navset(
      id = ns("result_tabs"),
      plot_tab, result_tab, data_tab, code_tab
    )
  } else {
    build_navset(
      id = ns("result_tabs"),
      result_tab, data_tab, code_tab
    )
  }
}
