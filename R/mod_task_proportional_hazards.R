# mod_task_proportional_hazards.R — Cox Proportional Hazards (Phase 3 analysis)
#
# Execute + code generation for this analysis. The UI/server is the shared
# generic Phase-3 module (phase3_task_ui / phase3_task_server in
# mod_phase3_tasks.R); shared analysis helpers live in task_helpers_phase3.R.


execute_cox <- function(p, df, tables = list()) {
  dat <- .p3_surv_data(p, df)
  preds <- p$predictors %||% character(0)
  preds <- preds[nzchar(preds)]
  if (!length(preds)) stop("Select at least one covariate.")
  missing_cols <- setdiff(preds, names(dat))
  if (length(missing_cols))
    stop("Column not found: ", paste(missing_cols, collapse = ", "))

  rhs <- paste(vapply(preds, r_ident, character(1)), collapse = " + ")
  f <- stats::as.formula(paste("survival::Surv(.ig_time, .ig_event) ~", rhs))
  fit <- survival::coxph(f, data = dat)

  tidy_df <- as.data.frame(broom::tidy(fit, conf.int = TRUE))
  # Practitioners read Cox results as hazard ratios — surface exp(coef)
  # right next to the log-hazard estimate.
  est_pos <- match("estimate", names(tidy_df))
  tidy_df <- cbind(
    tidy_df[, seq_len(est_pos), drop = FALSE],
    hazard_ratio = exp(tidy_df$estimate),
    tidy_df[, -seq_len(est_pos), drop = FALSE]
  )
  glance_df  <- broom::glance(fit)
  augment_df <- tryCatch(broom::augment(fit, data = dat), error = function(e) NULL)
  pred_df <- .p3_prediction_data(p, tables, preds)
  predictions_df <- if (!is.null(pred_df)) cbind(pred_df,
    .risk = as.numeric(stats::predict(fit, newdata = pred_df, type = "risk"))) else NULL
  list(data = tidy_df, plot = NULL,
       objects = list(model = fit, glance = glance_df, augment = augment_df,
                      predictions = predictions_df),
       error = NULL)
}

p3_code_cox <- function(p, tbl, out, model_name, glance_line, q) {
  time_col  <- p$response %||% ""
  event_col <- p$group %||% ""
  preds <- p$predictors %||% character(0)
  rhs <- paste(paste0("`", preds, "`"), collapse = " + ")
  ev_line <- if (nzchar(p$event_level %||% "")) {
    paste0(".d$.ig_event <- as.integer(as.character(.d[[", q(event_col),
           "]]) == ", q(p$event_level), ")\n")
  } else {
    paste0(".d$.ig_event <- as.integer(.d[[", q(event_col), "]])\n")
  }
  paste0(
    "library(survival)\nlibrary(broom)\n",
    ".d <- ", tbl, "\n",
    ev_line,
    model_name, " <- coxph(Surv(.d[[", q(time_col), "]], .d$.ig_event) ~ ",
    rhs, ", data = .d)\n",
    out, " <- broom::tidy(", model_name, ", conf.int = TRUE)\n",
    out, "$hazard_ratio <- exp(", out, "$estimate)   # HR = exp(coef)\n",
    glance_line
  )
}
