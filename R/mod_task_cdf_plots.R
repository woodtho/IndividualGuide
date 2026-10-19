# mod_task_cdf_plots.R — CDF Plots (Phase 3 analysis)
#
# Execute + code generation for this analysis. The UI/server is the shared
# generic Phase-3 module (phase3_task_ui / phase3_task_server in
# mod_phase3_tasks.R); shared analysis helpers live in task_helpers_phase3.R.


execute_cdf_plot <- function(p, df) {
  col <- p$response %||% ""
  .p3_require_numeric(df, col, "numeric")
  group <- p$group %||% ""
  if (nzchar(group) && !group %in% names(df))
    stop("Column not found: ", group)

  keep <- !is.na(df[[col]])
  if (nzchar(group)) keep <- keep & !is.na(df[[group]])
  d <- df[keep, , drop = FALSE]
  if (nrow(d) == 0L) stop("No non-missing values in '", col, "'.")

  probs <- seq(0, 1, by = 0.05)
  tbl <- if (nzchar(group)) {
    pieces <- lapply(split(d[[col]], d[[group]], drop = TRUE), function(v)
      data.frame(prob = probs, value = unname(quantile(v, probs))))
    do.call(rbind, Map(function(piece, g)
      cbind(setNames(data.frame(g, stringsAsFactors = FALSE), group), piece),
      pieces, names(pieces)))
  } else {
    data.frame(prob = probs, value = unname(quantile(d[[col]], probs)))
  }
  rownames(tbl) <- NULL

  mapping <- if (nzchar(group)) {
    ggplot2::aes(x = .data[[col]], colour = factor(.data[[group]]))
  } else {
    ggplot2::aes(x = .data[[col]])
  }
  gp <- ggplot2::ggplot(d, mapping) +
    ggplot2::stat_ecdf(linewidth = max(0.2, p$line_width %||% 1.05), pad = FALSE) +
    ggplot2::labs(
      title = .p3_title(p, "cdf_plots", paste("Empirical CDF \u2014", col)),
      x = if (nzchar(p$x_label %||% "")) p$x_label else col,
      y = if (nzchar(p$y_label %||% "")) p$y_label else "F(x)",
      colour = if (nzchar(group)) group else NULL,
      subtitle = p$subtitle %||% NULL, caption = p$caption %||% NULL)
  fin <- .p3_finish_plot(gp, p, "cdf_plots",
    discrete_n = if (nzchar(group)) length(unique(d[[group]])) else 0L)

  list(data = tbl, plot = fin$plot,
       objects = list(plot = fin$plot, image = fin$image), error = NULL)
}

p3_code_cdf_plot <- function(p, tbl, out, plot_name, image_name, q) {
  col <- p$response %||% ""
  group <- p$group %||% ""
  aes_txt <- if (nzchar(group)) {
    paste0("aes(x = .data[[", q(col), "]], colour = factor(.data[[", q(group), "]]))")
  } else {
    paste0("aes(x = .data[[", q(col), "]])")
  }
  filter_txt <- if (nzchar(group)) {
    paste0(".d <- ", tbl, "[!is.na(", tbl, "[[", q(col), "]]) & !is.na(", tbl,
           "[[", q(group), "]]), ]\n")
  } else {
    paste0(".d <- ", tbl, "[!is.na(", tbl, "[[", q(col), "]]), ]\n")
  }
  table_txt <- if (nzchar(group)) {
    # Per-group quantiles, matching the in-app result table
    paste0(
      ".qs <- lapply(split(.d[[", q(col), "]], .d[[", q(group), "]]), function(v)\n",
      "  data.frame(prob = seq(0, 1, 0.05), value = quantile(v, seq(0, 1, 0.05))))\n",
      out, " <- do.call(rbind, Map(function(d, g) cbind(`", group,
      "` = g, d), .qs, names(.qs)))\n",
      "rownames(", out, ") <- NULL\n"
    )
  } else {
    paste0(
      out, " <- data.frame(prob = seq(0, 1, 0.05),\n",
      "  value = quantile(.d[[", q(col), "]], seq(0, 1, 0.05)))\n"
    )
  }
  paste0(
    "library(ggplot2)\nlibrary(ggiraph)\n",
    filter_txt,
    table_txt,
    image_name, " <- ggplot(.d, ", aes_txt, ") +\n",
    "  stat_ecdf(linewidth = 0.9, pad = FALSE) +\n",
    "  labs(title = ", q(paste("Empirical CDF \u2014", col)), ", y = \"F(x)\") +\n",
    "  theme_minimal(base_size = 12)\n",
    plot_name, " <- ggiraph::girafe(ggobj = ", image_name, ")\n"
  )
}
