# mod_task_control_charts.R — Control Charts (Phase 3 analysis)
#
# Execute + code generation for this analysis. The UI/server is the shared
# generic Phase-3 module (phase3_task_ui / phase3_task_server in
# mod_phase3_tasks.R); shared analysis helpers live in task_helpers_phase3.R.


# Western Electric run rules. Returns a character vector (one element per
# point): comma-joined rule labels, or "" when the point triggers nothing.
#   Rule 1 — point beyond 3 sigma
#   Rule 2 — 2 of 3 consecutive points beyond 2 sigma, same side
#   Rule 3 — 4 of 5 consecutive points beyond 1 sigma, same side
#   Rule 4 — 8 consecutive points on the same side of the centre line
# Rules 2-4 flag the point that completes the pattern.
.p3_we_rules <- function(x, center, sigma) {
  n <- length(x)
  if (!is.finite(sigma) || sigma <= 0) sigma <- .Machine$double.eps
  dev  <- (x - center) / sigma
  side <- sign(dev)

  rule1 <- abs(dev) > 3

  window_rule <- function(width, needed, threshold) {
    out <- logical(n)
    for (i in seq_len(n)) {
      if (i < width) next
      idx <- (i - width + 1L):i
      for (s in c(-1, 1)) {
        if (sum(side[idx] == s & abs(dev[idx]) > threshold) >= needed) {
          out[i] <- TRUE
        }
      }
    }
    out
  }
  rule2 <- window_rule(3L, 2L, 2)
  rule3 <- window_rule(5L, 4L, 1)

  rule4 <- logical(n)
  run <- 0L; prev <- 0
  for (i in seq_len(n)) {
    if (side[i] != 0 && side[i] == prev) run <- run + 1L
    else { run <- if (side[i] != 0) 1L else 0L; prev <- side[i] }
    if (run >= 8L) rule4[i] <- TRUE
  }

  vapply(seq_len(n), function(i) {
    hits <- c(if (rule1[i]) "1", if (rule2[i]) "2",
              if (rule3[i]) "3", if (rule4[i]) "4")
    if (length(hits)) paste(hits, collapse = ",") else ""
  }, character(1))
}

execute_control_chart <- function(p, df) {
  col <- p$response %||% ""
  .p3_require_numeric(df, col, "measurement")
  subgroup <- p$group %||% ""
  if (nzchar(subgroup) && !subgroup %in% names(df))
    stop("Column not found: ", subgroup)

  if (nzchar(subgroup)) {
    # ── Xbar chart on subgroup means ──────────────────────────────────────────
    keep <- !is.na(df[[col]]) & !is.na(df[[subgroup]])
    d <- df[keep, , drop = FALSE]
    grp <- factor(d[[subgroup]], levels = unique(d[[subgroup]]))  # keep order
    means <- tapply(d[[col]], grp, mean)
    sizes <- tapply(d[[col]], grp, length)
    if (length(means) < 2L) stop("Need at least two subgroups.")
    center <- mean(d[[col]])
    n_mode <- as.integer(names(sort(table(sizes), decreasing = TRUE))[1L])
    if (n_mode >= 2L && n_mode <= 10L && all(sizes == n_mode)) {
      rbar  <- mean(tapply(d[[col]], grp, function(v) diff(range(v))))
      delta <- .A2[[as.character(n_mode)]] * rbar
      method <- sprintf("Xbar-R (n = %d, A2 * Rbar limits)", n_mode)
    } else {
      delta <- 3 * sd(as.numeric(means))
      method <- "Xbar (3 * SD of subgroup means; unequal subgroup sizes)"
    }
    tbl <- data.frame(
      subgroup  = names(means),
      n         = as.integer(sizes),
      mean      = as.numeric(means),
      center    = center,
      lcl       = center - delta,
      ucl       = center + delta,
      stringsAsFactors = FALSE
    )
    chart_values <- tbl$mean
    y_lab <- paste("Subgroup mean of", col)
  } else {
    # ── Individuals (I) chart, sigma from the average moving range ────────────
    x <- df[[col]][!is.na(df[[col]])]
    if (length(x) < 3L) stop("Need at least 3 non-missing values.")
    center <- mean(x)
    sigma  <- mean(abs(diff(x))) / 1.128
    delta  <- 3 * sigma
    method <- "Individuals (moving-range sigma)"
    tbl <- data.frame(
      index  = seq_along(x),
      value  = x,
      center = center,
      lcl    = center - delta,
      ucl    = center + delta
    )
    chart_values <- tbl$value
    y_lab <- col
  }

  lcl <- center - delta; ucl <- center + delta
  # Violations: rule 1 (beyond limits) always; Western Electric run rules 2-4
  # optionally (default on).
  if (!identical(p$run_rules, FALSE)) {
    rules <- .p3_we_rules(chart_values, center, delta / 3)
    tbl$violation <- nzchar(rules)
    tbl$rule      <- rules
  } else {
    tbl$violation <- chart_values < lcl | chart_values > ucl
    tbl$rule      <- ifelse(tbl$violation, "1", "")
  }
  plot_df <- data.frame(index = seq_along(chart_values),
                        value = chart_values,
                        violation = tbl$violation)
  gp <- ggplot2::ggplot(plot_df, ggplot2::aes(x = index, y = value)) +
    ggplot2::geom_hline(yintercept = center, colour = "#2d6a4f", linewidth = 0.6) +
    ggplot2::geom_hline(yintercept = c(lcl, ucl), colour = "#8b1a4a",
      linetype = "dashed", linewidth = 0.6) +
    ggplot2::geom_line(colour = "#4361ee",
      linewidth = max(0.2, as.numeric(p$line_width %||% 1.05))) +
    ggplot2::geom_point(ggplot2::aes(colour = violation), size = 2) +
    ggplot2::scale_colour_manual(values = c(`FALSE` = "#4361ee", `TRUE` = "#ef4444"),
      guide = "none") +
    ggplot2::labs(
      title = .p3_title(p, "control_charts", paste("Control Chart \u2014", col)),
      subtitle = if (nzchar(p$subtitle %||% "")) p$subtitle else method,
      x = if (nzchar(p$x_label %||% "")) p$x_label else "Observation",
      y = if (nzchar(p$y_label %||% "")) p$y_label else y_lab,
      caption = p$caption %||% NULL)
  # scale already set manually above — bypass the shared discrete palette
  fin <- .p3_finish_plot(gp, p, "control_charts")

  list(data = tbl, plot = fin$plot,
       objects = list(plot = fin$plot, image = fin$image,
         summary = list(method = method, center = center, lcl = lcl, ucl = ucl,
                        sigma = delta / 3,
                        n_violations = sum(tbl$violation))),
       error = NULL)
}

p3_code_control_chart <- function(p, tbl, out, plot_name, image_name, q) {
  col <- p$response %||% ""
  subgroup <- p$group %||% ""
  core <- if (nzchar(subgroup)) paste0(
    ".d <- ", tbl, "[!is.na(", tbl, "[[", q(col), "]]) & !is.na(", tbl, "[[", q(subgroup), "]]), ]\n",
    ".grp <- factor(.d[[", q(subgroup), "]], levels = unique(.d[[", q(subgroup), "]]))\n",
    ".means <- tapply(.d[[", q(col), "]], .grp, mean)\n",
    ".sizes <- tapply(.d[[", q(col), "]], .grp, length)\n",
    ".center <- mean(.d[[", q(col), "]])\n",
    "# Xbar-R limits (A2 * Rbar) for balanced subgroups of size 2-10;\n",
    "# otherwise fall back to 3 * SD of the subgroup means.\n",
    ".A2 <- c(`2` = 1.880, `3` = 1.023, `4` = 0.729, `5` = 0.577, `6` = 0.483,\n",
    "         `7` = 0.419, `8` = 0.373, `9` = 0.337, `10` = 0.308)\n",
    ".n1 <- .sizes[[1]]\n",
    ".delta <- if (all(.sizes == .n1) && .n1 >= 2 && .n1 <= 10) {\n",
    "  .rbar <- mean(tapply(.d[[", q(col), "]], .grp, function(v) diff(range(v))))\n",
    "  .A2[[as.character(.n1)]] * .rbar\n",
    "} else {\n",
    "  3 * sd(as.numeric(.means))\n",
    "}\n",
    out, " <- data.frame(subgroup = names(.means), n = as.integer(.sizes),\n",
    "  mean = as.numeric(.means),\n",
    "  center = .center, lcl = .center - .delta, ucl = .center + .delta)\n"
  ) else paste0(
    ".x <- na.omit(", tbl, "[[", q(col), "]])\n",
    ".center <- mean(.x)\n",
    ".sigma <- mean(abs(diff(.x))) / 1.128   # moving-range estimate\n",
    out, " <- data.frame(index = seq_along(.x), value = .x, center = .center,\n",
    "  lcl = .center - 3 * .sigma, ucl = .center + 3 * .sigma)\n"
  )
  val <- if (nzchar(subgroup)) "mean" else "value"
  idx <- if (nzchar(subgroup)) "seq_along(.means)" else "index"
  violation_txt <- if (!identical(p$run_rules, FALSE)) paste0(
    "# Western Electric run rules: 1 = beyond 3s, 2 = 2-of-3 beyond 2s (same\n",
    "# side), 3 = 4-of-5 beyond 1s (same side), 4 = 8 in a row on one side.\n",
    ".we_rules <- function(x, c0, s) {\n",
    "  n <- length(x); dev <- (x - c0) / s; side <- sign(dev)\n",
    "  win <- function(w, k, t) {\n",
    "    o <- logical(n)\n",
    "    for (i in seq_len(n)) if (i >= w) {\n",
    "      idx <- (i - w + 1):i\n",
    "      for (sd in c(-1, 1))\n",
    "        if (sum(side[idx] == sd & abs(dev[idx]) > t) >= k) o[i] <- TRUE\n",
    "    }\n",
    "    o\n",
    "  }\n",
    "  r4 <- logical(n); run <- 0; prev <- 0\n",
    "  for (i in seq_len(n)) {\n",
    "    if (side[i] != 0 && side[i] == prev) run <- run + 1\n",
    "    else { run <- if (side[i] != 0) 1 else 0; prev <- side[i] }\n",
    "    if (run >= 8) r4[i] <- TRUE\n",
    "  }\n",
    "  abs(dev) > 3 | win(3, 2, 2) | win(5, 4, 1) | r4\n",
    "}\n",
    out, "$violation <- .we_rules(", out, "$", val,
    ", ", out, "$center[1], (", out, "$ucl[1] - ", out, "$center[1]) / 3)\n"
  ) else paste0(
    out, "$violation <- ", out, "$", val, " < ", out, "$lcl | ", out, "$",
    val, " > ", out, "$ucl\n"
  )
  paste0(
    "library(ggplot2)\nlibrary(ggiraph)\n",
    core,
    violation_txt,
    image_name, " <- ggplot(", out, ", aes(x = ", idx, ", y = ", val, ")) +\n",
    "  geom_hline(aes(yintercept = center), colour = \"#2d6a4f\") +\n",
    "  geom_hline(aes(yintercept = lcl), colour = \"#8b1a4a\", linetype = \"dashed\") +\n",
    "  geom_hline(aes(yintercept = ucl), colour = \"#8b1a4a\", linetype = \"dashed\") +\n",
    "  geom_line(colour = \"#4361ee\") +\n",
    "  geom_point(aes(colour = violation), size = 2) +\n",
    "  scale_colour_manual(values = c(`FALSE` = \"#4361ee\", `TRUE` = \"#ef4444\"), guide = \"none\") +\n",
    "  labs(title = ", q(paste("Control Chart \u2014", col)), ") +\n",
    "  theme_minimal(base_size = 12)\n",
    plot_name, " <- ggiraph::girafe(ggobj = ", image_name, ")\n"
  )
}
