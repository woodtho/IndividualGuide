# mod_task_nonlinear_regression.R — Nonlinear Regression (Phase 3 analysis)
#
# Execute + code generation for this analysis. The UI/server is the shared
# generic Phase-3 module (phase3_task_ui / phase3_task_server in
# mod_phase3_tasks.R); shared analysis helpers live in task_helpers_phase3.R.


# Build the nls call for a preset curve. Returns the fitted model.
.p3_fit_nls <- function(dat, xcol, ycol, curve) {
  x <- dat[[xcol]]; y <- dat[[ycol]]
  bx <- r_ident(xcol); by <- r_ident(ycol)
  switch(curve,
    logistic = stats::nls(
      stats::as.formula(paste0(by, " ~ SSlogis(", bx, ", Asym, xmid, scal)")),
      data = dat),
    asymptotic = stats::nls(
      stats::as.formula(paste0(by, " ~ SSasymp(", bx, ", Asym, R0, lrc)")),
      data = dat),
    exponential = {
      start <- if (all(y > 0)) {
        cf <- stats::coef(stats::lm(log(y) ~ x))
        list(a = exp(unname(cf[1])), b = unname(cf[2]))
      } else list(a = mean(y), b = 0.01)
      stats::nls(stats::as.formula(paste0(by, " ~ a * exp(b * ", bx, ")")),
                 data = dat, start = start)
    },
    power = {
      if (any(x <= 0) || any(y <= 0))
        stop("Power curves require strictly positive x and y values.")
      cf <- stats::coef(stats::lm(log(y) ~ log(x)))
      stats::nls(stats::as.formula(paste0(by, " ~ a * ", bx, "^b")),
                 data = dat, start = list(a = exp(unname(cf[1])), b = unname(cf[2])))
    },
    stop("Unknown curve preset: ", curve)
  )
}

execute_nonlinear_regression <- function(p, df) {
  ycol <- p$response %||% ""
  xcol <- (p$predictors %||% character(0))[1] %||% ""
  if (is.na(xcol)) xcol <- ""
  .p3_require_numeric(df, ycol, "response")
  .p3_require_numeric(df, xcol, "predictor")
  curve <- p$curve %||% "logistic"

  dat <- df[!is.na(df[[xcol]]) & !is.na(df[[ycol]]), , drop = FALSE]
  if (nrow(dat) < 5L) stop("Need at least 5 complete (x, y) pairs.")

  fit <- .p3_fit_nls(dat, xcol, ycol, curve)
  tidy_df    <- broom::tidy(fit)
  glance_df  <- tryCatch(broom::glance(fit), error = function(e) NULL)
  augment_df <- tryCatch(broom::augment(fit, data = dat), error = function(e) NULL)

  grid_x <- if (identical(curve, "power")) {
    seq(max(min(dat[[xcol]]), .Machine$double.eps), max(dat[[xcol]]),
        length.out = 200)
  } else {
    seq(min(dat[[xcol]]), max(dat[[xcol]]), length.out = 200)
  }
  grid <- stats::setNames(data.frame(grid_x), xcol)
  grid$.fitted <- as.numeric(stats::predict(fit, newdata = grid))

  gp <- ggplot2::ggplot(dat, ggplot2::aes(x = .data[[xcol]], y = .data[[ycol]])) +
    ggplot2::geom_point(colour = "#4361ee",
      alpha = max(0.1, min(1, as.numeric(p$point_alpha %||% 0.78)))) +
    ggplot2::geom_line(data = grid,
      ggplot2::aes(x = .data[[xcol]], y = .fitted),
      colour = "#8b1a4a",
      linewidth = max(0.2, as.numeric(p$line_width %||% 1.05))) +
    ggplot2::labs(
      title = .p3_title(p, "nonlinear_regression",
        paste0("Nonlinear fit (", curve, ") \u2014 ", ycol, " ~ ", xcol)),
      x = if (nzchar(p$x_label %||% "")) p$x_label else xcol,
      y = if (nzchar(p$y_label %||% "")) p$y_label else ycol,
      subtitle = p$subtitle %||% NULL, caption = p$caption %||% NULL)
  fin <- .p3_finish_plot(gp, p, "nonlinear_regression")

  list(data = tidy_df, plot = fin$plot,
       objects = list(plot = fin$plot, image = fin$image, model = fit,
                      glance = glance_df, augment = augment_df),
       error = NULL)
}

p3_code_nls <- function(p, tbl, out, plot_name, image_name, model_name, q) {
  ycol <- p$response %||% ""
  xcol <- (p$predictors %||% character(0))[1] %||% ""
  curve <- p$curve %||% "logistic"
  bx <- paste0("`", xcol, "`"); by <- paste0("`", ycol, "`")
  fit_line <- switch(curve,
    logistic    = paste0(model_name, " <- nls(", by, " ~ SSlogis(", bx,
      ", Asym, xmid, scal), data = .d)\n"),
    asymptotic  = paste0(model_name, " <- nls(", by, " ~ SSasymp(", bx,
      ", Asym, R0, lrc), data = .d)\n"),
    exponential = paste0(
      ".cf <- coef(lm(log(.d[[", q(ycol), "]]) ~ .d[[", q(xcol), "]]))\n",
      model_name, " <- nls(", by, " ~ a * exp(b * ", bx, "), data = .d,\n",
      "  start = list(a = exp(.cf[1]), b = .cf[2]))\n"),
    power       = paste0(
      ".cf <- coef(lm(log(.d[[", q(ycol), "]]) ~ log(.d[[", q(xcol), "]])))\n",
      model_name, " <- nls(", by, " ~ a * ", bx, "^b, data = .d,\n",
      "  start = list(a = exp(.cf[1]), b = .cf[2]))\n"),
    paste0(model_name, " <- nls(", by, " ~ SSlogis(", bx,
      ", Asym, xmid, scal), data = .d)\n")
  )
  paste0(
    "library(broom)\nlibrary(ggplot2)\nlibrary(ggiraph)\n",
    ".d <- ", tbl, "[!is.na(", tbl, "[[", q(xcol), "]]) & !is.na(", tbl,
    "[[", q(ycol), "]]), ]\n",
    fit_line,
    out, " <- broom::tidy(", model_name, ")\n",
    ".grid <- setNames(data.frame(seq(min(.d[[", q(xcol), "]]), max(.d[[",
    q(xcol), "]]), length.out = 200)), ", q(xcol), ")\n",
    ".grid$.fitted <- predict(", model_name, ", newdata = .grid)\n",
    image_name, " <- ggplot(.d, aes(.data[[", q(xcol), "]], .data[[", q(ycol), "]])) +\n",
    "  geom_point(alpha = 0.7) +\n",
    "  geom_line(data = .grid, aes(.data[[", q(xcol), "]], .fitted), colour = \"#8b1a4a\") +\n",
    "  labs(title = ", q(paste0("Nonlinear fit (", curve, ")")), ") +\n",
    "  theme_minimal(base_size = 12)\n",
    plot_name, " <- ggiraph::girafe(ggobj = ", image_name, ")\n"
  )
}
