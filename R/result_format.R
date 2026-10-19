# result_format.R — Polished gt output for Individual Guide task results.

# ── Helpers ───────────────────────────────────────────────────────────────────

.sig_stars <- function(p) {
  dplyr::case_when(
    is.na(p)  ~ "",
    p < 0.001 ~ "***",
    p < 0.01  ~ "**",
    p < 0.05  ~ "*",
    p < 0.1   ~ ".",
    TRUE      ~ ""
  )
}

.fmt_p <- function(x) {
  ifelse(is.na(x), "\u2014",
    ifelse(x < 0.001, "< .001",
      sprintf("%.3f", as.numeric(x))))
}

# ── Shared gt theme (clean light output, like printed statistical reports) ─────
ig_gt_theme <- function(gt_tbl) {
  gt_tbl |>
    gt::tab_options(
      table.font.size                   = "0.82rem",
      table.width                       = "100%",
      table.border.top.color            = "#ced4da",
      table.border.bottom.color         = "#ced4da",
      column_labels.border.bottom.color = "#6c757d",
      column_labels.border.bottom.width = "2px",
      column_labels.font.weight         = "600",
      column_labels.background.color    = "#f1f3f5",
      row.striping.background_color     = "#f8f9fa",
      row.striping.include_table_body   = TRUE,
      heading.border.bottom.color       = "#ced4da",
      heading.title.font.size           = "0.92rem",
      heading.title.font.weight         = "700",
      heading.subtitle.font.size        = "0.76rem",
      heading.align                     = "left",
      heading.background.color          = "#f1f3f5",
      table_body.hlines.color           = "#e9ecef",
      table_body.vlines.color           = "transparent",
      source_notes.font.size            = "0.72rem",
      footnotes.font.size               = "0.72rem",
      grand_summary_row.background.color = "#e9ecef",
      grand_summary_row.text_transform  = "uppercase"
    ) |>
    gt::opt_table_font(
      font = list(gt::google_font("Inter"), gt::default_fonts())
    )
}

# ── Regression / GLM / logistic ───────────────────────────────────────────────

format_regression_result <- function(tidy_df, glance_df = NULL,
                                      type_id = "linear_regression") {
  d <- as.data.frame(tidy_df)
  if (is.null(d) || nrow(d) == 0L) return(NULL)

  model_label <- switch(type_id,
    linear_regression    = "Linear Regression",
    linear_models        = "Linear Model",
    logistic_regression  = "Logistic Regression",
    glm                  = "Generalised Linear Model",
    proportional_hazards = "Cox Proportional Hazards",
    nonlinear_regression = "Nonlinear Regression (nls)",
    "Regression"
  )

  d$sig <- .sig_stars(d$p.value)
  d$p_fmt <- .fmt_p(d$p.value)

  has_ci <- all(c("conf.low", "conf.high") %in% names(d))
  # Wald statistics are z for likelihood-based models, t for least squares
  stat_lbl <- if (type_id %in% c("logistic_regression", "glm",
                                 "proportional_hazards")) "z" else "t"

  cols_sel <- c("term", "estimate",
                if ("hazard_ratio" %in% names(d)) "hazard_ratio",
                "std.error", "statistic",
                if (has_ci) c("conf.low", "conf.high"),
                "p_fmt", "sig")
  d_sel <- d[, intersect(cols_sel, names(d)), drop = FALSE]

  lbl <- list(term = "Term", estimate = "Estimate",
              hazard_ratio = "Hazard Ratio", std.error = "Std. Error",
              statistic = stat_lbl, p_fmt = "p-value", sig = "",
              conf.low = "CI low", conf.high = "CI high")

  sub <- if (!is.null(glance_df)) .glance_subtitle(glance_df, type_id) else NULL

  gt_tbl <- d_sel |>
    gt::gt() |>
    gt::tab_header(title = paste(model_label, "\u2014 Coefficient Estimates"),
                   subtitle = sub) |>
    gt::cols_label(.list = lbl[intersect(names(lbl), names(d_sel))]) |>
    gt::fmt_number(columns = dplyr::any_of(c("estimate","hazard_ratio",
                                              "std.error","statistic",
                                              "conf.low","conf.high")),
                   decimals = 4) |>
    gt::cols_align("right", columns = dplyr::any_of(
      c("estimate","hazard_ratio","std.error","statistic",
        "conf.low","conf.high","p_fmt"))) |>
    gt::cols_align("left",  columns = dplyr::any_of(c("term","sig"))) |>
    gt::tab_style(
      style     = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(rows = d_sel$sig %in% c("*","**","***"))
    ) |>
    gt::tab_footnote(
      footnote  = "Signif. codes:  0 '***'  0.001 '**'  0.01 '*'  0.05 '.'  0.1",
      locations = gt::cells_column_labels(columns = "sig")
    )

  ig_gt_theme(gt_tbl)
}

.glance_subtitle <- function(g, type_id) {
  g <- as.data.frame(g)[1L, , drop = FALSE]
  parts <- character(0)
  if (!is.null(g$r.squared) && !is.na(g$r.squared))
    parts <- c(parts, sprintf("R\u00b2 = %.3f", g$r.squared))
  if (!is.null(g$adj.r.squared) && !is.na(g$adj.r.squared))
    parts <- c(parts, sprintf("Adj. R\u00b2 = %.3f", g$adj.r.squared))
  if (!is.null(g$statistic) && !is.na(g$statistic) &&
      !is.null(g$df) && !is.na(g$df)) {
    df2 <- g$df.residual %||% NA_real_
    parts <- c(parts, sprintf("F(%g, %g) = %.2f, p %s",
                              g$df, df2, g$statistic, .fmt_p(g$p.value %||% NA)))
  }
  if (!is.null(g$AIC) && !is.na(g$AIC))
    parts <- c(parts, sprintf("AIC = %.1f", g$AIC))
  if (!is.null(g$nobs) && !is.na(g$nobs))
    parts <- c(parts, sprintf("n = %g", g$nobs))
  paste(parts, collapse = "  \u2502  ")
}

# ── ANOVA ─────────────────────────────────────────────────────────────────────

format_anova_result <- function(tidy_df, glance_df = NULL) {
  d <- as.data.frame(tidy_df)
  if (is.null(d) || nrow(d) == 0L) return(NULL)

  d$sig   <- .sig_stars(d$p.value)
  d$p_fmt <- .fmt_p(d$p.value)

  sub <- if (!is.null(glance_df)) {
    g <- as.data.frame(glance_df)[1L, , drop = FALSE]
    parts <- character(0)
    if (!is.null(g$r.squared) && !is.na(g$r.squared))
      parts <- c(parts, sprintf("R\u00b2 = %.3f", g$r.squared))
    paste(parts, collapse = "  |  ")
  } else NULL

  d_sel <- d[, c("term",
    intersect(c("df","sumsq","meansq","statistic"), names(d)),
    "p_fmt", "sig"), drop = FALSE]

  lbl <- list(term = "Source", df = "df", sumsq = "Sum Sq",
              meansq = "Mean Sq", statistic = "F", p_fmt = "p-value", sig = "")

  d_sel |>
    gt::gt() |>
    gt::tab_header(title = "One-Way ANOVA", subtitle = sub) |>
    gt::cols_label(.list = lbl[intersect(names(lbl), names(d_sel))]) |>
    gt::fmt_number(columns = dplyr::any_of(c("sumsq","meansq","statistic")),
                   decimals = 3) |>
    gt::cols_align("right",
      columns = dplyr::any_of(c("df","sumsq","meansq","statistic","p_fmt"))) |>
    gt::cols_align("left", columns = dplyr::any_of(c("term","sig"))) |>
    gt::tab_style(
      style     = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(rows = d_sel$sig %in% c("*","**","***"))
    ) |>
    gt::tab_footnote(
      "Signif. codes:  0 '***'  0.001 '**'  0.01 '*'  0.05 '.'  0.1",
      locations = gt::cells_column_labels("sig")
    ) |>
    ig_gt_theme()
}

format_tukey_result <- function(tukey_df) {
  if (is.null(tukey_df) || nrow(tukey_df) == 0L) return(NULL)
  d <- as.data.frame(tukey_df)
  p_col <- intersect(c("p adj","p.adj","p.value"), names(d))[1]
  if (!is.na(p_col)) {
    d$sig   <- .sig_stars(d[[p_col]])
    d$p_fmt <- .fmt_p(d[[p_col]])
  }
  keep <- c("comparison",
    intersect(c("diff","lwr","upr"), names(d)),
    if (!is.na(p_col)) c("p_fmt","sig"))
  d[, keep, drop = FALSE] |>
    gt::gt() |>
    gt::tab_header(title = "Tukey HSD \u2014 Pairwise Comparisons") |>
    gt::cols_label(comparison = "Comparison", p_fmt = "adj. p-value", sig = "",
                   diff = "Difference", lwr = "Lower", upr = "Upper") |>
    gt::fmt_number(columns = dplyr::any_of(c("diff","lwr","upr")), decimals = 3) |>
    gt::cols_align("right", columns = dplyr::any_of(c("diff","lwr","upr","p_fmt"))) |>
    gt::cols_align("left",  columns = dplyr::any_of(c("comparison","sig"))) |>
    gt::tab_style(
      style = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(rows = d$sig %in% c("*","**","***"))
    ) |>
    ig_gt_theme()
}

# ── t-test ────────────────────────────────────────────────────────────────────

format_ttest_result <- function(tidy_df) {
  d <- as.data.frame(tidy_df)[1L, , drop = FALSE]
  if (nrow(d) == 0L) return(NULL)

  sig <- .sig_stars(d$p.value %||% NA)
  sub <- sprintf("p-value %s  %s", .fmt_p(d$p.value %||% NA), sig)

  rows <- Filter(function(r) !is.na(r[[2]]), list(
    c("Test method",  d$method     %||% "t-test"),
    c("Statistic",    sprintf("t = %.4f", as.numeric(d$statistic %||% NA))),
    c("df",           sprintf("%.2f",    as.numeric(d$parameter  %||% NA))),
    c("p-value",      .fmt_p(d$p.value %||% NA)),
    c("95% CI",       if (!is.null(d$conf.low) && !is.na(d$conf.low))
                        sprintf("[%.4f,  %.4f]", d$conf.low, d$conf.high) else "\u2014"),
    c("Estimate",     sprintf("%.4f", as.numeric(d$estimate %||% NA))),
    c("Alternative",  as.character(d$alternative %||% "\u2014"))
  ))
  display <- as.data.frame(do.call(rbind, lapply(rows, function(r)
    data.frame(stat = r[1], value = r[2], stringsAsFactors = FALSE))))

  display |>
    gt::gt() |>
    gt::tab_header(title = "t-Test Results", subtitle = sub) |>
    gt::cols_label(stat = "", value = "") |>
    gt::cols_width(stat ~ gt::px(160)) |>
    gt::cols_align("left",  columns = "stat") |>
    gt::cols_align("right", columns = "value") |>
    gt::tab_style(
      style = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(rows = display$stat == "p-value")
    ) |>
    gt::opt_stylize(style = 1) |>
    ig_gt_theme()
}

# ── PCA ───────────────────────────────────────────────────────────────────────

format_pca_result <- function(tidy_df) {
  d <- as.data.frame(tidy_df)
  if (is.null(d) || nrow(d) == 0L) return(NULL)

  lbl <- c(PC = "PC", std.dev = "Std. Dev.", percent = "% Variance",
           cumulative = "Cumulative %")
  keep <- intersect(names(lbl), names(d))

  gt_tbl <- d[, keep, drop = FALSE] |>
    gt::gt() |>
    gt::tab_header(title = "PCA \u2014 Explained Variance") |>
    gt::cols_label(.list = as.list(lbl[keep])) |>
    gt::fmt_number(columns = dplyr::any_of("std.dev"), decimals = 3) |>
    gt::fmt_percent(columns = dplyr::any_of(c("percent","cumulative")),
                    decimals = 1) |>
    gt::cols_align("right",
      columns = dplyr::any_of(c("std.dev","percent","cumulative"))) |>
    gt::cols_align("left", columns = dplyr::any_of("PC"))

  if ("percent" %in% keep)
    gt_tbl <- gt_tbl |>
      gt::tab_style(
        style = gt::cell_text(weight = "bold"),
        locations = gt::cells_body(rows = d$percent > 0.10)
      )

  ig_gt_theme(gt_tbl)
}

# ── Cluster analysis ──────────────────────────────────────────────────────────

format_cluster_result <- function(tidy_df, glance_df = NULL) {
  d <- as.data.frame(tidy_df)
  if (is.null(d) || nrow(d) == 0L) return(NULL)

  sub <- if (!is.null(glance_df)) {
    g <- as.data.frame(glance_df)[1L, , drop = FALSE]
    parts <- character(0)
    if (!is.null(g$tot.withinss) && !is.na(g$tot.withinss))
      parts <- c(parts, sprintf("Total within-SS = %.2f", g$tot.withinss))
    if (!is.null(g$totss) && !is.na(g$totss))
      parts <- c(parts, sprintf("Total SS = %.2f", g$totss))
    if (!is.null(g$iter) && !is.na(g$iter))
      parts <- c(parts, sprintf("Iterations = %g", g$iter))
    paste(parts, collapse = "  |  ")
  } else NULL

  num_cols <- names(d)[vapply(d, is.numeric, logical(1))]

  d |>
    gt::gt() |>
    gt::tab_header(title = "k-Means \u2014 Cluster Centres", subtitle = sub) |>
    gt::fmt_number(columns = dplyr::any_of(num_cols), decimals = 3) |>
    gt::cols_align("right", columns = dplyr::any_of(num_cols)) |>
    gt::cols_align("left",  columns = dplyr::any_of(c("cluster","x1"))) |>
    ig_gt_theme()
}

# ── Correlations ──────────────────────────────────────────────────────────────

format_correlation_result <- function(tidy_df, matrix_obj = NULL) {
  if (!is.null(matrix_obj) && is.matrix(matrix_obj)) {
    d <- as.data.frame(round(matrix_obj, 3))
    d |>
      gt::gt(rownames_to_stub = TRUE) |>
      gt::tab_header(title = "Correlation Matrix") |>
      gt::fmt_number(decimals = 3) |>
      gt::data_color(
        columns  = dplyr::everything(),
        method   = "numeric",
        palette  = c("#c0392b", "#ffffff", "#27ae60"),
        domain   = c(-1, 1),
        na_color = "#f8f9fa"
      ) |>
      gt::tab_style(
        style     = gt::cell_text(weight = "bold"),
        locations = gt::cells_stub()
      ) |>
      ig_gt_theme()
  } else {
    if (is.null(tidy_df)) return(NULL)
    as.data.frame(tidy_df) |>
      gt::gt() |>
      gt::tab_header(title = "Correlation Pairs") |>
      gt::fmt_number(columns = dplyr::any_of("Freq"), decimals = 3) |>
      ig_gt_theme()
  }
}

# ── Summary statistics (describe tasks) ───────────────────────────────────────

format_summary_stats_result <- function(result_df) {
  d <- as.data.frame(result_df)
  if (nrow(d) == 0L) return(NULL)

  num_cols <- names(d)[vapply(d, is.numeric, logical(1))]

  gt_tbl <- d |>
    gt::gt() |>
    gt::tab_header(title = "Summary Statistics") |>
    gt::fmt_number(columns = dplyr::any_of(num_cols), decimals = 3) |>
    gt::cols_align("left",  columns = dplyr::any_of("column")) |>
    gt::cols_align("right", columns = dplyr::any_of(num_cols))

  # Colour-scale the mean column if present
  if ("mean" %in% names(d))
    gt_tbl <- gt_tbl |>
      gt::data_color(columns = "mean", method = "numeric",
                     palette = c("#dbeafe","#1d4ed8"), na_color = "#f8f9fa")

  ig_gt_theme(gt_tbl)
}

format_freq_result <- function(result_df, col_name = NULL) {
  d <- as.data.frame(result_df)
  if (nrow(d) == 0L) return(NULL)

  count_col <- intersect(c("n","Freq","count","N"), names(d))[1]
  if (is.na(count_col)) return(NULL)
  cat_col <- col_name %||% setdiff(names(d),
    c(count_col, "percent","Percent","pct","cum_percent","cumulative"))[1]
  if (is.na(cat_col)) return(NULL)

  d$pct <- 100 * as.numeric(d[[count_col]]) /
    sum(as.numeric(d[[count_col]]), na.rm = TRUE)

  d_sel <- d[, c(cat_col, count_col, "pct"), drop = FALSE]
  names(d_sel) <- c("category", "n", "pct")

  total <- sum(d_sel$n, na.rm = TRUE)

  d_sel |>
    gt::gt() |>
    gt::tab_header(title = "One-Way Frequency Table",
                   subtitle = sprintf("Variable: %s  \u2502  Total n = %s",
                     cat_col, format(total, big.mark = ","))) |>
    gt::cols_label(category = cat_col, n = "Count", pct = "%") |>
    gt::fmt_integer(columns = "n") |>
    gt::fmt_number(columns = "pct", decimals = 1) |>
    gt::cols_align("left",  columns = "category") |>
    gt::cols_align("right", columns = c("n","pct")) |>
    gt::grand_summary_rows(
      columns = "n",
      fns     = list(Total = ~ sum(.)),
      fmt     = list(~ gt::fmt_integer(.))
    ) |>
    gt::data_color(columns = "n", method = "numeric",
                   palette = c("#f0f9ff","#0369a1"), na_color = "#f8f9fa") |>
    ig_gt_theme()
}

format_chisq_result <- function(chi_obj) {
  if (is.null(chi_obj) || !is.null(chi_obj$error)) return(NULL)
  sig <- .sig_stars(chi_obj$p.value)
  sub <- sprintf("\u03c7\u00b2(%g) = %.4f,  p %s  %s",
    chi_obj$parameter, chi_obj$statistic, .fmt_p(chi_obj$p.value), sig)
  rows <- data.frame(
    stat  = c("\u03c7\u00b2 statistic", "df", "p-value", "Method"),
    value = c(sprintf("%.4f", chi_obj$statistic),
              as.character(chi_obj$parameter),
              .fmt_p(chi_obj$p.value),
              chi_obj$method %||% "Pearson's Chi-squared"),
    stringsAsFactors = FALSE
  )
  rows |>
    gt::gt() |>
    gt::tab_header(title = "Chi-Square Test of Independence", subtitle = sub) |>
    gt::cols_label(stat = "", value = "") |>
    gt::cols_width(stat ~ gt::px(180)) |>
    gt::cols_align("left",  columns = "stat") |>
    gt::cols_align("right", columns = "value") |>
    gt::tab_style(
      style = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(rows = rows$stat == "p-value")
    ) |>
    ig_gt_theme()
}

format_dist_stats_result <- function(result_df) {
  format_summary_stats_result(result_df)
}

# ── Phase 3 main dispatcher ───────────────────────────────────────────────────

# ── Generic numeric-table formatter for the plot-centric analyses ─────────────

format_generic_stat_result <- function(result_df, title, subtitle = NULL) {
  d <- as.data.frame(result_df)
  if (is.null(d) || nrow(d) == 0L) return(NULL)
  num_cols <- names(d)[vapply(d, is.numeric, logical(1))]
  chr_cols <- setdiff(names(d), num_cols)
  d |>
    gt::gt() |>
    gt::tab_header(title = title, subtitle = subtitle) |>
    gt::fmt_number(columns = dplyr::any_of(num_cols), decimals = 4) |>
    gt::cols_align("right", columns = dplyr::any_of(num_cols)) |>
    gt::cols_align("left",  columns = dplyr::any_of(chr_cols)) |>
    ig_gt_theme()
}

#' Return a gt table for the given phase3 task result, or NULL.
#' @param type_id Registered task type identifier.
#' @param data Tabular value to store.
#' @param objects Named list of non-tabular analysis outputs.
format_phase3_result <- function(type_id, data, objects = list()) {
  if (is.null(data)) return(NULL)
  tryCatch({
    if (type_id %in% c("linear_regression","linear_models","glm",
                        "logistic_regression","proportional_hazards",
                        "nonlinear_regression"))
      return(format_regression_result(data, objects$glance, type_id))
    if (identical(type_id, "one_way_anova"))
      return(format_anova_result(data, objects$glance))
    if (identical(type_id, "t_test"))
      return(format_ttest_result(data))
    if (identical(type_id, "pca"))
      return(format_pca_result(data))
    if (identical(type_id, "cluster_analysis"))
      return(format_cluster_result(data, objects$glance))
    if (identical(type_id, "correlations"))
      return(format_correlation_result(data, objects$matrix))
    if (identical(type_id, "cdf_plots"))
      return(format_generic_stat_result(data, "Empirical CDF \u2014 Quantiles"))
    if (identical(type_id, "probability_plots"))
      return(format_generic_stat_result(data, "Normality Assessment",
        "Shapiro-Wilk test and moments"))
    if (identical(type_id, "control_charts")) {
      s <- objects$summary %||% list()
      sub <- if (length(s)) sprintf("%s  |  CL = %.4g  [%.4g, %.4g]  |  %d violation(s)",
        s$method %||% "", s$center, s$lcl, s$ucl, s$n_violations) else NULL
      return(format_generic_stat_result(data, "Control Chart \u2014 Points & Limits", sub))
    }
    if (identical(type_id, "arima_forecast")) {
      s <- objects$summary %||% list()
      sub <- if (length(s)) sprintf("ARIMA(%d,%d,%d)  |  AIC = %.1f  |  n = %d",
        s$order[1], s$order[2], s$order[3], s$aic, s$n) else NULL
      return(format_generic_stat_result(data, "Forecast", sub))
    }
    if (identical(type_id, "life_tables"))
      return(format_generic_stat_result(data, "Life Table (Kaplan\u2013Meier)"))
    NULL
  }, error = function(e) NULL)
}
