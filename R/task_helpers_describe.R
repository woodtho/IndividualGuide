# mod_describe_tasks.R — Phase 2 Describe task modules
# Tasks: characterize_data, distribution_analysis, list_data,
#        one_way_freq, summary_stats, summary_tables, table_analysis
#
# Depends on (already sourced): store.R, qb_build.R (r_ident, r_val)

# ── Shared describe-task helpers ───────────────────────────────────────────────

#' Collect the existing simple describe controls using their parameter schema.
#' @keywords internal
#' @param input Shiny module input values.
#' @param initial Saved parameter defaults used before controls are bound.
.desc_collect_params <- function(input, initial) {
  params <- lapply(names(initial), function(key) {
    value <- input[[key]]
    if (key == "cols" && is.null(value)) return(character(0))
    value %||% initial[[key]] %||% ""
  })
  names(params) <- names(initial)
  if (!is.null(params$output_name)) params$output_name <- trimws(params$output_name)
  params
}

.desc_header <- function(ns, icon_name, title) {
  bslib::card_header(
    class = "d-flex align-items-center gap-2",
    icon(icon_name), " ", title
  )
}

.desc_analyze_footer <- function(ns, btn_label = "Analyze") {
  bslib::card_footer(
    class = "d-flex align-items-center gap-2",
    actionButton(ns("btn_run"), btn_label, icon = icon("play"),
      class = "btn btn-sm btn-primary"),
    span(class = "ms-auto text-muted small",
      role = "status", `aria-live` = "polite", `aria-atomic` = "true",
      textOutput(ns("run_status"), inline = TRUE))
  )
}

# Standard describe-task card: a Setup tab holding only the configuration,
# and a Results tab holding the result tabset. do_run switches to Results.
.desc_task_shell <- function(ns, icon_name, title, btn_label, results, ...) {
  bslib::card(
    class = "ig-task-card",
    full_screen = TRUE,
    .desc_header(ns, icon_name, title),
    bslib::card_body(
      padding = 0, class = "ig-task-tabs",
      bslib::navset_tab(
        id = ns("task_tabs"),
        bslib::nav_panel(tagList(icon("sliders"), " Setup"), value = "setup",
          div(class = "ig-setup-pane", ...)),
        bslib::nav_panel(tagList(icon("chart-bar"), " Results"), value = "results",
          div(class = "ig-results-pane", results))
      )
    ),
    .desc_analyze_footer(ns, btn_label)
  )
}

# Switch a describe panel to its Results tab after a successful run
.desc_goto_results <- function(session) {
  bslib::nav_select("task_tabs", "results", session = session)
}

# Save analysis result (data frame) to store and update task definition.
# enabled = FALSE suppresses store_add_table but still saves params/code.
.desc_save <- function(store, task_id, type_id, params, input_tables,
                        result_df, r_code, run_status_msg, enabled = TRUE, output_specs = NULL) {
  out <- params$output_name %||% ""
  if (nzchar(out) && !is.null(result_df) && isTRUE(enabled)) {
    store_add_table(store, out, result_df)
  }
  if (!is.null(task_id)) {
    task <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, type_id)
    task$inputs    <- input_tables
    task$output    <- if (isTRUE(enabled)) out else ""
    task$params    <- params
    task <- store_task_from_params(task, params)
    if (!is.null(output_specs)) task$outputs <- output_specs
    task$r_code    <- r_code %||% ""
    task$run_time  <- Sys.time()
    task$error_msg <- NULL
    store_set_task(store, task)
  }
  invisible(NULL)
}

# ══════════════════════════════════════════════════════════════════════════════
# 1. CHARACTERIZE DATA
# ══════════════════════════════════════════════════════════════════════════════




# ══════════════════════════════════════════════════════════════════════════════
# 2. LIST DATA
# ══════════════════════════════════════════════════════════════════════════════




# ══════════════════════════════════════════════════════════════════════════════
# 3. ONE-WAY FREQUENCIES
# ══════════════════════════════════════════════════════════════════════════════




# ══════════════════════════════════════════════════════════════════════════════
# 4. SUMMARY STATISTICS
# ══════════════════════════════════════════════════════════════════════════════




# ══════════════════════════════════════════════════════════════════════════════
# 5. TABLE ANALYSIS  (two-way contingency + chi-square)
# ══════════════════════════════════════════════════════════════════════════════




# ══════════════════════════════════════════════════════════════════════════════
# 6. SUMMARY TABLES  (cross-tabulated summary)
# ══════════════════════════════════════════════════════════════════════════════


SUMMARY_TABLE_STATS <- c(
  "Mean"   = "mean", "Sum"    = "sum",
  "Median" = "median", "Count" = "n",
  "Min"    = "min", "Max"    = "max",
  "SD"     = "sd"
)



# ══════════════════════════════════════════════════════════════════════════════
# 7. DISTRIBUTION ANALYSIS
# ══════════════════════════════════════════════════════════════════════════════
