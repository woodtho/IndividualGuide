# mod_task_life_tables.R — Life Tables (Phase 3 analysis)
#
# Execute + code generation for this analysis. The UI/server is the shared
# generic Phase-3 module (phase3_task_ui / phase3_task_server in
# mod_phase3_tasks.R); shared analysis helpers live in task_helpers_phase3.R.


execute_life_tables <- function(p, df) {
  dat <- .p3_surv_data(p, df)
  strata_col <- (p$predictors %||% character(0))[1] %||% ""
  if (!is.na(strata_col) && nzchar(strata_col) && !strata_col %in% names(dat))
    stop("Column not found: ", strata_col)
  has_strata <- !is.na(strata_col) && nzchar(strata_col)

  rhs <- if (has_strata) r_ident(strata_col) else "1"
  f <- stats::as.formula(paste("survival::Surv(.ig_time, .ig_event) ~", rhs))
  sf <- survival::survfit(f, data = dat)
  tbl <- as.data.frame(broom::tidy(sf))
  if ("strata" %in% names(tbl))
    tbl$strata <- sub("^.*=", "", tbl$strata)
  glance_df <- tryCatch(.p3_survfit_glance(sf), error = function(e) NULL)

  mapping <- if (has_strata) {
    ggplot2::aes(x = time, y = estimate, colour = strata)
  } else {
    ggplot2::aes(x = time, y = estimate)
  }
  gp <- ggplot2::ggplot(tbl, mapping) +
    ggplot2::geom_step(linewidth = max(0.2, p$line_width %||% 1.05)) +
    ggplot2::geom_step(ggplot2::aes(y = conf.low), linetype = "dotted",
      linewidth = 0.5, na.rm = TRUE) +
    ggplot2::geom_step(ggplot2::aes(y = conf.high), linetype = "dotted",
      linewidth = 0.5, na.rm = TRUE) +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::labs(
      title = .p3_title(p, "life_tables", "Kaplan\u2013Meier Survival"),
      x = if (nzchar(p$x_label %||% "")) p$x_label else "Time",
      y = if (nzchar(p$y_label %||% "")) p$y_label else "Survival probability",
      colour = if (has_strata) strata_col else NULL,
      subtitle = p$subtitle %||% NULL, caption = p$caption %||% NULL)
  fin <- .p3_finish_plot(gp, p, "life_tables",
    discrete_n = if (has_strata) length(unique(tbl$strata)) else 0L)

  list(data = tbl, plot = fin$plot,
       objects = list(plot = fin$plot, image = fin$image, model = sf,
                      glance = glance_df),
       error = NULL)
}

p3_code_life_tables <- function(p, tbl, out, plot_name, image_name, model_name,
                                glance_name, q) {
  time_col  <- p$response %||% ""
  event_col <- p$group %||% ""
  strata_col <- (p$predictors %||% character(0))[1] %||% ""
  has_strata <- !is.na(strata_col) && nzchar(strata_col)
  rhs <- if (has_strata) paste0("`", strata_col, "`") else "1"
  aes_txt <- if (has_strata) "aes(time, estimate, colour = strata)"
             else "aes(time, estimate)"
  ev_line <- if (nzchar(p$event_level %||% "")) {
    paste0(".d$.ig_event <- as.integer(as.character(.d[[", q(event_col),
           "]]) == ", q(p$event_level), ")\n")
  } else {
    paste0(".d$.ig_event <- as.integer(.d[[", q(event_col), "]])\n")
  }
  paste0(
    "library(survival)\nlibrary(broom)\nlibrary(ggplot2)\nlibrary(ggiraph)\n",
    ".d <- ", tbl, "\n",
    ev_line,
    model_name, " <- survfit(Surv(.d[[", q(time_col), "]], .d$.ig_event) ~ ",
    rhs, ", data = .d)\n",
    out, " <- as.data.frame(broom::tidy(", model_name, "))\n",
    "# Median survival summary (records, events, median + 95% CI)\n",
    ".tb <- summary(", model_name, ")$table\n",
    glance_name, " <- if (is.matrix(.tb)) {\n",
    "  cbind(strata = sub(\"^.*=\", \"\", rownames(.tb)),\n",
    "        as.data.frame(.tb, optional = TRUE))\n",
    "} else {\n",
    "  as.data.frame(as.list(.tb), optional = TRUE)\n",
    "}\n",
    image_name, " <- ggplot(", out, ", ", aes_txt, ") +\n",
    "  geom_step(linewidth = 0.9) +\n",
    "  coord_cartesian(ylim = c(0, 1)) +\n",
    "  labs(title = \"Kaplan-Meier Survival\", y = \"Survival probability\") +\n",
    "  theme_minimal(base_size = 12)\n",
    plot_name, " <- ggiraph::girafe(ggobj = ", image_name, ")\n"
  )
}
