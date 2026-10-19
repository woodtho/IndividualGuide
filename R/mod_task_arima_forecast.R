# mod_task_arima_forecast.R — ARIMA / Basic Forecasting (Phase 3 analysis)
#
# Execute + code generation for this analysis. The UI/server is the shared
# generic Phase-3 module (phase3_task_ui / phase3_task_server in
# mod_phase3_tasks.R); shared analysis helpers live in task_helpers_phase3.R.


# Fit an ARIMA model. Prefers forecast::auto.arima (proper unit-root tests
# and order selection); falls back to a small AIC-selected grid when the
# forecast package is not installed. Returns list(fit, order, engine).
.p3_fit_arima <- function(y) {
  if (requireNamespace("forecast", quietly = TRUE)) {
    fit <- forecast::auto.arima(y)
    return(list(fit = fit,
                order = unname(forecast::arimaorder(fit)[1:3]),
                engine = "forecast::auto.arima"))
  }
  # crude integration check: difference once when it reduces spread
  d <- if (length(y) > 3L && sd(diff(y)) < sd(y)) 1L else 0L
  best <- NULL; best_aic <- Inf; best_order <- c(0L, d, 0L)
  for (ar in 0:2) for (ma in 0:2) {
    fit <- tryCatch(
      suppressWarnings(stats::arima(y, order = c(ar, d, ma))),
      error = function(e) NULL)
    if (!is.null(fit) && isTRUE(fit$code == 0L) && is.finite(fit$aic) && fit$aic < best_aic) {
      best <- fit; best_aic <- fit$aic; best_order <- c(ar, d, ma)
    }
  }
  if (is.null(best)) stop("ARIMA estimation failed for this series.")
  list(fit = best, order = best_order, engine = "AIC grid (stats::arima)")
}

execute_arima_forecast <- function(p, df) {
  col <- p$response %||% ""
  .p3_require_numeric(df, col, "series value")
  y <- as.numeric(df[[col]])
  if (anyNA(y)) stop("Fill missing series values before forecasting; rows must retain their time spacing.")
  if (length(y) < 8L) stop("Need at least 8 non-missing observations.")
  h <- p$horizon %||% 12L
  if (length(h) != 1L || !is.finite(h) || h < 1 || h > .Machine$integer.max || h != as.integer(h))
    stop("Forecast horizon must be a positive whole number.")
  h <- as.integer(h)

  sel <- .p3_fit_arima(y)
  tbl <- if (identical(sel$engine, "forecast::auto.arima")) {
    fc <- forecast::forecast(sel$fit, h = h, level = c(80, 95))
    data.frame(
      step     = seq_len(h),
      forecast = as.numeric(fc$mean),
      lo80 = as.numeric(fc$lower[, 1]), hi80 = as.numeric(fc$upper[, 1]),
      lo95 = as.numeric(fc$lower[, 2]), hi95 = as.numeric(fc$upper[, 2])
    )
  } else {
    fc  <- stats::predict(sel$fit, n.ahead = h)
    z80 <- stats::qnorm(0.90); z95 <- stats::qnorm(0.975)
    data.frame(
      step     = seq_len(h),
      forecast = as.numeric(fc$pred),
      lo80 = as.numeric(fc$pred - z80 * fc$se),
      hi80 = as.numeric(fc$pred + z80 * fc$se),
      lo95 = as.numeric(fc$pred - z95 * fc$se),
      hi95 = as.numeric(fc$pred + z95 * fc$se)
    )
  }

  hist_df <- data.frame(t = seq_along(y), value = y)
  fc_df   <- cbind(t = length(y) + tbl$step, tbl)
  gp <- ggplot2::ggplot() +
    ggplot2::geom_ribbon(data = fc_df,
      ggplot2::aes(x = t, ymin = lo95, ymax = hi95), fill = "#4361ee", alpha = 0.15) +
    ggplot2::geom_ribbon(data = fc_df,
      ggplot2::aes(x = t, ymin = lo80, ymax = hi80), fill = "#4361ee", alpha = 0.25) +
    ggplot2::geom_line(data = hist_df, ggplot2::aes(x = t, y = value),
      colour = "#1f2937", linewidth = 0.7) +
    ggplot2::geom_line(data = fc_df, ggplot2::aes(x = t, y = forecast),
      colour = "#4361ee", linewidth = max(0.2, p$line_width %||% 1.05)) +
    ggplot2::labs(
      title = .p3_title(p, "arima_forecast",
        sprintf("ARIMA(%d,%d,%d) forecast \u2014 %s", sel$order[1], sel$order[2],
                sel$order[3], col)),
      x = if (nzchar(p$x_label %||% "")) p$x_label else "Time index",
      y = if (nzchar(p$y_label %||% "")) p$y_label else col,
      subtitle = p$subtitle %||% NULL, caption = p$caption %||% NULL)
  fin <- .p3_finish_plot(gp, p, "arima_forecast")

  list(data = tbl, plot = fin$plot,
       objects = list(plot = fin$plot, image = fin$image, model = sel$fit,
         summary = list(order = sel$order, aic = sel$fit$aic, n = length(y),
                        engine = sel$engine)),
       error = NULL)
}

p3_code_arima <- function(p, tbl, out, plot_name, image_name, model_name, q) {
  col <- p$response %||% ""
  h <- max(1L, as.integer(p$horizon %||% 12L))
  paste0(
    "library(forecast)\nlibrary(ggplot2)\nlibrary(ggiraph)\n",
    ".y <- na.omit(as.numeric(", tbl, "[[", q(col), "]]))\n",
    "# Order selected by forecast::auto.arima (unit-root tests + AICc search)\n",
    model_name, " <- forecast::auto.arima(.y)\n",
    ".fc <- forecast::forecast(", model_name, ", h = ", h, ", level = c(80, 95))\n",
    out, " <- data.frame(step = 1:", h, ", forecast = as.numeric(.fc$mean),\n",
    "  lo80 = as.numeric(.fc$lower[, 1]), hi80 = as.numeric(.fc$upper[, 1]),\n",
    "  lo95 = as.numeric(.fc$lower[, 2]), hi95 = as.numeric(.fc$upper[, 2]))\n",
    image_name, " <- ggplot() +\n",
    "  geom_line(data = data.frame(t = seq_along(.y), value = .y), aes(t, value)) +\n",
    "  geom_ribbon(data = cbind(t = length(.y) + ", out, "$step, ", out, "),\n",
    "    aes(x = t, ymin = lo95, ymax = hi95), fill = \"#4361ee\", alpha = 0.2) +\n",
    "  geom_line(data = cbind(t = length(.y) + ", out, "$step, ", out, "),\n",
    "    aes(t, forecast), colour = \"#4361ee\") +\n",
    "  labs(title = \"ARIMA forecast\") + theme_minimal(base_size = 12)\n",
    plot_name, " <- ggiraph::girafe(ggobj = ", image_name, ")\n"
  )
}
