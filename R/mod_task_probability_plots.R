# mod_task_probability_plots.R — Probability Plots (Phase 3 analysis)
#
# Execute + code generation for this analysis. The UI/server is the shared
# generic Phase-3 module (phase3_task_ui / phase3_task_server in
# mod_phase3_tasks.R); shared analysis helpers live in task_helpers_phase3.R.


execute_probability_plot <- function(p, df) {
  col <- p$response %||% ""
  .p3_require_numeric(df, col, "numeric")
  x <- df[[col]][!is.na(df[[col]])]
  if (length(x) < 3L) stop("Need at least 3 non-missing values.")

  qq <- qqnorm(x, plot.it = FALSE)
  d <- data.frame(theoretical = qq$x, sample = qq$y)
  # Reference line through the quartiles (same convention as qqline()).
  qy <- quantile(x, c(0.25, 0.75), names = FALSE)
  qx <- stats::qnorm(c(0.25, 0.75))
  slope <- diff(qy) / diff(qx)
  intercept <- qy[1L] - slope * qx[1L]

  sw <- if (length(x) >= 3L && length(x) <= 5000L) {
    tryCatch(stats::shapiro.test(x), error = function(e) NULL)
  } else NULL
  mu <- mean(x); s <- sd(x)
  z  <- if (s > 0) (x - mu) / s else NULL
  tbl <- data.frame(
    column    = col,
    n         = length(x),
    mean      = round(mu, 4),
    sd        = round(s, 4),
    skewness  = if (!is.null(z)) round(mean(z^3), 4) else NA_real_,
    excess_kurtosis = if (!is.null(z)) round(mean(z^4) - 3, 4) else NA_real_,
    shapiro_w = if (!is.null(sw)) round(unname(sw$statistic), 4) else NA_real_,
    shapiro_p = if (!is.null(sw)) round(sw$p.value, 4) else NA_real_,
    stringsAsFactors = FALSE
  )

  gp <- ggplot2::ggplot(d, ggplot2::aes(x = theoretical, y = sample)) +
    ggplot2::geom_point(colour = "#4361ee",
      alpha = max(0.1, min(1, as.numeric(p$point_alpha %||% 0.78))), size = 1.6) +
    ggplot2::geom_abline(slope = slope, intercept = intercept,
      colour = "#8b1a4a", linewidth = max(0.2, p$line_width %||% 1.05)) +
    ggplot2::labs(
      title = .p3_title(p, "probability_plots", paste("Normal Q-Q Plot \u2014", col)),
      x = if (nzchar(p$x_label %||% "")) p$x_label else "Theoretical quantiles",
      y = if (nzchar(p$y_label %||% "")) p$y_label else "Sample quantiles",
      subtitle = p$subtitle %||% NULL, caption = p$caption %||% NULL)
  fin <- .p3_finish_plot(gp, p, "probability_plots")

  list(data = tbl, plot = fin$plot,
       objects = list(plot = fin$plot, image = fin$image), error = NULL)
}

p3_code_probability_plot <- function(p, tbl, out, plot_name, image_name, q) {
  col <- p$response %||% ""
  paste0(
    "library(ggplot2)\nlibrary(ggiraph)\n",
    ".x <- na.omit(", tbl, "[[", q(col), "]])\n",
    ".qq <- qqnorm(.x, plot.it = FALSE)\n",
    ".qy <- quantile(.x, c(0.25, 0.75)); .qx <- qnorm(c(0.25, 0.75))\n",
    ".slope <- diff(.qy) / diff(.qx); .int <- .qy[1] - .slope * .qx[1]\n",
    ".sw <- shapiro.test(.x)\n",
    out, " <- data.frame(n = length(.x), mean = mean(.x), sd = sd(.x),\n",
    "  shapiro_w = unname(.sw$statistic), shapiro_p = .sw$p.value)\n",
    image_name, " <- ggplot(data.frame(theoretical = .qq$x, sample = .qq$y),\n",
    "    aes(theoretical, sample)) +\n",
    "  geom_point(alpha = 0.7) +\n",
    "  geom_abline(slope = .slope, intercept = .int, colour = \"#8b1a4a\") +\n",
    "  labs(title = ", q(paste("Normal Q-Q Plot \u2014", col)), ") +\n",
    "  theme_minimal(base_size = 12)\n",
    plot_name, " <- ggiraph::girafe(ggobj = ", image_name, ")\n"
  )
}
