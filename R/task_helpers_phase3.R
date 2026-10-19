# phase3_analyses.R — Real implementations for the capability, control-chart,
# time-series, survival, and nonlinear-regression task types.
#
# Each execute_* function takes the phase3 params list `p` and the input data
# frame `df`, and returns list(data, plot, objects, error = NULL). Errors are
# raised with stop() — execute_phase3_task() wraps the call in tryCatch.
#
# The matching p3_code_* functions emit the standalone R script for the task
# (used by build_phase3_code and the Code tab / full-pipeline script).

# Stat task types that produce a plot (the preview pane gets a Plot tab).
PHASE3_PLOTTING_STATS <- c(
  "cdf_plots", "probability_plots", "control_charts",
  "arima_forecast", "life_tables", "nonlinear_regression"
)

# ── Shared helpers ─────────────────────────────────────────────────────────────

.p3_require_numeric <- function(df, col, what = "value") {
  if (!nzchar(col %||% "")) stop("Select a ", what, " column.")
  if (!col %in% names(df)) stop("Column not found: ", col)
  if (!is.numeric(df[[col]])) stop("'", col, "' must be numeric.")
  if (any(!is.finite(df[[col]]) & !is.na(df[[col]]))) stop("'", col, "' contains infinite values.")
  invisible(TRUE)
}

# Apply the shared plot styling and wrap in a girafe widget.
.p3_finish_plot <- function(gp, p, type_id, discrete_n = 0L) {
  uds <- discrete_n > 0L
  if (uds) attr(uds, "n_levels") <- discrete_n
  gp <- phase3_apply_plot_style(gp, p, type_id, uses_discrete_scale = uds)
  w <- max(3, as.numeric(p$plot_width  %||% 8))
  h <- max(2, as.numeric(p$plot_height %||% 4.2))
  list(plot = ggiraph::girafe(ggobj = gp, width_svg = w, height_svg = h),
       image = gp)
}

.p3_title <- function(p, type_id, fallback) {
  t <- p$title %||% ""
  if (nzchar(t)) t else fallback
}

# Coerce an event/censoring column to 0/1 integers.
# event_level: explicit value (for factor/character columns) that counts as
# the event. When blank: numeric must be 0/1, logical maps directly, and
# two-level factors/characters use the second sorted level.
.p3_event_vector <- function(x, col, event_level = "") {
  if (is.logical(x)) return(as.integer(x))
  if (is.numeric(x)) {
    vals <- unique(x[!is.na(x)])
    if (!all(vals %in% c(0, 1)))
      stop("Event column '", col, "' must contain only 0/1 (or TRUE/FALSE).")
    return(as.integer(x))
  }
  chr <- as.character(x)
  lv  <- sort(unique(chr[!is.na(chr)]))
  if (nzchar(event_level %||% "")) {
    if (!event_level %in% lv)
      stop("Event level '", event_level, "' not found in column '", col, "'.")
    return(as.integer(chr == event_level))
  }
  if (length(lv) != 2L)
    stop("Event column '", col, "' has ", length(lv),
         " levels \u2014 pick which one counts as the event in 'Event level'.")
  # second sorted level is treated as the event
  as.integer(chr == lv[2L])
}

# ── CDF Plots ──────────────────────────────────────────────────────────────────



# ── Probability (Q-Q) Plots ────────────────────────────────────────────────────



# ── Control Charts ─────────────────────────────────────────────────────────────

# Xbar A2 factors for subgroup sizes 2..10
.A2 <- c(`2` = 1.880, `3` = 1.023, `4` = 0.729, `5` = 0.577, `6` = 0.483,
         `7` = 0.419, `8` = 0.373, `9` = 0.337, `10` = 0.308)




# ── ARIMA / Basic Forecasting ──────────────────────────────────────────────────




# ── Life Tables (Kaplan–Meier) ─────────────────────────────────────────────────

# Build the survfit / coxph data + formula pieces shared by both survival tasks.
.p3_surv_data <- function(p, df) {
  if (!requireNamespace("survival", quietly = TRUE))
    stop("Package 'survival' is required. Install it with install.packages('survival').")
  time_col  <- p$response %||% ""
  event_col <- p$group %||% ""
  .p3_require_numeric(df, time_col, "time-to-event")
  if (!nzchar(event_col)) stop("Select an event indicator column (1 = event, 0 = censored).")
  if (!event_col %in% names(df)) stop("Column not found: ", event_col)

  dat <- df
  dat$.ig_time  <- dat[[time_col]]
  dat$.ig_event <- .p3_event_vector(dat[[event_col]], event_col,
                                    event_level = p$event_level %||% "")
  keep <- !is.na(dat$.ig_time) & !is.na(dat$.ig_event)
  dat <- dat[keep, , drop = FALSE]
  if (nrow(dat) < 2L) stop("Not enough complete observations for survival analysis.")
  dat
}

# Median-survival summary per stratum from a survfit object — the headline
# numbers (n, events, median survival + 95% CI) most reports quote.
.p3_survfit_glance <- function(sf) {
  tb <- summary(sf)$table
  strata_names <- NULL
  if (is.null(dim(tb))) {
    tb <- matrix(tb, nrow = 1L, dimnames = list(NULL, names(tb)))
  } else {
    strata_names <- sub("^.*=", "", rownames(tb))
  }
  keep <- intersect(c("records", "events", "median", "0.95LCL", "0.95UCL"),
                    colnames(tb))
  d <- as.data.frame(tb[, keep, drop = FALSE], optional = TRUE)
  rownames(d) <- NULL
  nice <- c(records = "records", events = "events",
            median = "median_survival",
            `0.95LCL` = "median_conf_low", `0.95UCL` = "median_conf_high")
  names(d) <- unname(nice[keep])
  if (!is.null(strata_names)) d <- cbind(strata = strata_names, d)
  d
}



# ── Proportional Hazards (Cox) ─────────────────────────────────────────────────



# ── Nonlinear Regression (nls with curve presets) ──────────────────────────────

NLS_CURVES <- c(
  "Logistic  y = Asym / (1 + exp((xmid - x)/scal))" = "logistic",
  "Exponential  y = a * exp(b x)"                   = "exponential",
  "Power  y = a * x^b"                              = "power",
  "Asymptotic  y = Asym + (R0 - Asym) exp(-exp(lrc) x)" = "asymptotic"
)
