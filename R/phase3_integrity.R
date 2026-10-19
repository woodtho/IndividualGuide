# Pure shared calculations used by both the analytical tasks and exported R.
.p3_model_formula <- function(response, predictors) {
  stats::as.formula(paste(r_ident(response), "~",
    paste(vapply(predictors, r_ident, character(1)), collapse = " + ")))
}

.p3_secondary_scale <- function(primary, secondary, include_zero = FALSE) {
  if (!any(is.finite(primary)) || !any(is.finite(secondary))) stop("Both Y columns need finite observations.")
  r1 <- range(primary[is.finite(primary)])
  r2 <- range(secondary[is.finite(secondary)])
  if (isTRUE(include_zero)) r1 <- range(c(0, r1))
  width1 <- diff(r1); width2 <- diff(r2)
  if (!width1) width1 <- max(1, abs(r1))
  slope <- if (width2 > 0) width1 / width2 else 1
  list(slope = slope, intercept = r1[[1L]] - slope * r2[[1L]])
}

.p3_numeric_columns <- function(df, selected, label) {
  cols <- if (length(selected)) selected else names(df)[vapply(df, is.numeric, logical(1))]
  missing <- setdiff(cols, names(df))
  if (length(missing)) stop("Column not found: ", paste(missing, collapse = ", "))
  if (length(cols) < 2L) stop(label, " requires at least two numeric variables.")
  if (!all(vapply(df[cols], is.numeric, logical(1)))) stop(label, " requires numeric variables.")
  if (any(vapply(df[cols], function(value) any(is.infinite(value)), logical(1))))
    stop(label, " cannot use infinite values.")
  cols
}

.p3_prediction_data <- function(p, tables, required) {
  name <- p$pred_table %||% ""
  if (!nzchar(name)) return(NULL)
  df <- tables[[name]]
  if (inherits(df, "tbl_sql")) df <- as.data.frame(dplyr::collect(df))
  if (!is.data.frame(df)) stop("Prediction table not found: ", name)
  missing <- setdiff(required, names(df))
  if (length(missing)) stop("Prediction columns not found: ", paste(missing, collapse = ", "))
  df
}

.p3_predict_model <- function(fit, newdata, conf_int = FALSE) {
  if (is.null(newdata)) return(NULL)
  if (inherits(fit, "aov")) class(fit) <- setdiff(class(fit), "aov")
  if (!inherits(fit, "glm")) return(broom::augment(fit, newdata = newdata,
    interval = if (isTRUE(conf_int)) "confidence" else "none"))
  result <- broom::augment(fit, newdata = newdata, type.predict = "response")
  if (isTRUE(conf_int)) {
    prediction <- stats::predict(fit, newdata = newdata, type = "link", se.fit = TRUE)
    result$.lower <- fit$family$linkinv(prediction$fit - stats::qnorm(0.975) * prediction$se.fit)
    result$.upper <- fit$family$linkinv(prediction$fit + stats::qnorm(0.975) * prediction$se.fit)
  }
  result
}

.p3_t_test <- function(p, df) {
  response <- p$response %||% ""
  .p3_require_numeric(df, response, "response")
  group <- p$group %||% ""
  if (isTRUE(p$paired)) {
    second <- p$paired_column %||% ""
    .p3_require_numeric(df, second, "second paired measurement")
    if (identical(response, second)) stop("Choose two different paired measurement columns.")
    return(stats::t.test(df[[response]], df[[second]], paired = TRUE))
  }
  if (nzchar(group)) {
    if (!group %in% names(df)) stop("Column not found: ", group)
    return(stats::t.test(.p3_model_formula(response, group), data = df))
  }
  stats::t.test(df[[response]])
}

.p3_cluster <- function(p, df) {
  cols <- .p3_numeric_columns(df, p$predictors, "Cluster analysis")
  data <- stats::na.omit(df[cols])
  k <- p$k %||% 3L
  if (length(k) != 1L || !is.finite(k) || k != as.integer(k) || k < 1 || k > nrow(data))
    stop("Clusters must be a whole number between 1 and the number of complete observations.")
  method <- p$cluster_method %||% "kmeans"
  if (identical(method, "kmeans")) {
    seed <- p$cluster_seed %||% 1L
    if (length(seed) != 1L || !is.finite(seed) || seed < 0 || seed > .Machine$integer.max || seed != as.integer(seed))
      stop("Random seed must be a nonnegative whole number.")
    had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
    if (had_seed) old_seed <- get(".Random.seed", envir = globalenv())
    on.exit(if (had_seed) assign(".Random.seed", old_seed, envir = globalenv())
      else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) rm(".Random.seed", envir = globalenv()), add = TRUE)
    set.seed(as.integer(seed))
    model <- stats::kmeans(data, centers = as.integer(k))
    return(list(data = broom::tidy(model), plot = NULL,
      objects = list(model = model, clusters = broom::augment(model, data), glance = broom::glance(model)), error = NULL))
  }
  if (!identical(method, "hierarchical")) stop("Choose k-means or hierarchical clustering.")
  if (nrow(data) < 2L) stop("Hierarchical clustering requires at least two complete observations.")
  linkage <- p$cluster_linkage %||% "complete"
  if (!linkage %in% c("complete", "single", "average", "ward.D2")) stop("Unsupported clustering linkage: ", linkage)
  model <- stats::hclust(stats::dist(data), method = linkage)
  clusters <- stats::cutree(model, k = as.integer(k))
  summary <- stats::aggregate(data, list(cluster = clusters), mean)
  summary$size <- as.integer(table(clusters)[as.character(summary$cluster)])
  assignments <- as.data.frame(data)
  assignments$.cluster <- clusters
  list(data = summary, plot = NULL, objects = list(model = model, clusters = assignments,
    glance = data.frame(nobs = nrow(data), nclusters = k, method = linkage)), error = NULL)
}

.p3_scatter_pairs <- function(df, cols) {
  df <- utils::head(df[cols], 1000L)
  pairs <- expand.grid(x_variable = cols, y_variable = cols, stringsAsFactors = FALSE)
  do.call(rbind, lapply(seq_len(nrow(pairs)), function(i) {
    data.frame(x_variable = factor(pairs$x_variable[[i]], levels = cols),
      y_variable = factor(pairs$y_variable[[i]], levels = cols),
      x_value = df[[pairs$x_variable[[i]]]], y_value = df[[pairs$y_variable[[i]]]],
      row = seq_len(nrow(df)))
  }))
}

# Export the same pure calculation used by the panel, with private helper names
# and only the requested outputs copied back to the user's script environment.
build_phase3_shared_code <- function(type_id, p) {
  graph <- type_id %in% PHASE3_GRAPH_TYPES
  helper <- if (graph) "execute_phase3_graph" else switch(type_id,
    correlations = ".p3_correlations", pca = ".p3_pca", cluster_analysis = ".p3_cluster",
    linear_regression = , linear_models = , glm = , logistic_regression = ".p3_regression",
    one_way_anova = ".p3_anova", t_test = ".p3_t_test_result", cdf_plots = "execute_cdf_plot",
    probability_plots = "execute_probability_plot", control_charts = "execute_control_chart",
    arima_forecast = "execute_arima_forecast", life_tables = "execute_life_tables",
    proportional_hazards = "execute_cox", nonlinear_regression = "execute_nonlinear_regression",
    stop("Unknown analytical task: ", type_id))
  backend <- code_task_backend(helper, type_id, task_type_info(type_id)$label)
  overrides <- stats::setNames(list(backend$fn), backend$name)
  settings <- code_backend_parameters(p, backend$name, overrides)
  arguments <- list(settings = "settings", data = "data", tables = "prediction_tables",
    type_id = code_literal(type_id), default_title = code_literal(task_type_info(type_id)$label))
  invocation <- paste0(".ig_codegen$", backend$name, "(",
    paste(unlist(arguments[names(formals(backend$fn))], use.names = FALSE), collapse = ", "), ")")
  prediction_table <- p$pred_table %||% ""
  names <- p$output_names %||% phase3_default_output_names(type_id, p$output_name %||% paste0(type_id, "_out"))
  exports <- character(0)
  for (def in phase3_return_defs(type_id)) {
    key <- def$key
    name <- names[[key]] %||% ""
    if (identical(p$output_enabled[[key]], FALSE) || !nzchar(name)) next
    value <- if (key == "table") 'result$data' else paste0('result$objects[[', code_literal(key), ']]')
    exports <- c(exports, paste0('  if (!is.null(', value, ')) assign(', code_literal(name), ', ', value, ', envir = output_environment)'))
  }
  paste(c('local({', '  output_environment <- parent.env(environment())',
    paste0('  data <- get(', code_literal(p$input_table %||% "input_table"), ', envir = output_environment, inherits = TRUE)'),
    '  if (inherits(data, "tbl_sql")) data <- dplyr::collect(data)',
    '  if (!is.data.frame(data) || !nrow(data)) stop("The input table has no observations.")',
    paste0('  settings <- ', code_literal(settings)),
    '  prediction_tables <- list()',
    if (nzchar(prediction_table)) c(paste0('  prediction_tables[', code_literal(prediction_table), '] <- list(get(',
      code_literal(prediction_table), ', envir = output_environment, inherits = TRUE))'),
      paste0('  if (inherits(prediction_tables[[', code_literal(prediction_table), ']], "tbl_sql")) prediction_tables[[',
        code_literal(prediction_table), ']] <- dplyr::collect(prediction_tables[[', code_literal(prediction_table), ']])')),
    if (isTRUE(p$output_enabled$predictions) && !nzchar(prediction_table)) '  stop("Select a new data table to save predictions.")',
    code_helper_definitions(backend$name, overrides = overrides),
    if (type_id %in% c("cdf_plots", "probability_plots", "control_charts", "arima_forecast")) c(
      '  if (is.null(settings$response) || !nzchar(settings$response)) {',
      '    numeric_columns <- names(data)[vapply(data, is.numeric, logical(1))]',
      '    settings$response <- if (length(numeric_columns)) numeric_columns[[1L]] else ""', '  }'),
    paste0('  result <- ', invocation),
    '  if (!is.null(result$error)) stop(result$error, call. = FALSE)', exports, '})'), collapse = '\n')
}

.p3_t_test_result <- function(p, df) {
  test <- .p3_t_test(p, df)
  list(data = broom::tidy(test), plot = NULL, objects = list(test = test), error = NULL)
}

.p3_correlations <- function(p, df, tables = list()) {
    preds <- p$predictors %||% character(0)
    cols <- .p3_numeric_columns(df, preds, "Correlations")
    mat <- stats::cor(df[cols], use = "pairwise.complete.obs")
    return(list(data = as.data.frame(as.table(mat)), plot = NULL, objects = list(matrix = mat), error = NULL))
}

.p3_pca <- function(p, df, tables = list()) {
    preds <- p$predictors %||% character(0)
    cols <- .p3_numeric_columns(df, preds, "PCA")
    pc_data <- stats::na.omit(df[cols])
    pc <- stats::prcomp(pc_data, scale. = TRUE)
    scree_df <- broom::tidy(pc, matrix = "pcs")
    loadings_df <- broom::tidy(pc, matrix = "loadings")
    scores_df <- tryCatch(broom::augment(pc, data = pc_data), error = function(e) NULL)
    pred_df <- .p3_prediction_data(p, tables, cols)
    predictions_df <- if (!is.null(pred_df))
        as.data.frame(stats::predict(pc, newdata = pred_df[cols]))
    else NULL
    return(list(data = scree_df, plot = NULL, objects = list(model = pc, loadings = loadings_df, scores = scores_df,
        predictions = predictions_df), error = NULL))
}

.p3_regression <- function(type_id, p, df, tables = list()) {
    response <- p$response %||% ""
    preds <- p$predictors %||% character(0)
    if (!nzchar(response) || !length(preds))
        stop("Select a response and at least one predictor.")
    f <- .p3_model_formula(response, preds)
    fit <- if (type_id == "linear_regression" || type_id == "linear_models") {
        stats::lm(f, data = df)
    }
    else if (type_id == "logistic_regression") {
        stats::glm(f, data = df, family = stats::binomial())
    }
    else {
        stats::glm(f, data = df, family = p$family %||% "gaussian")
    }
    tidy_df <- broom::tidy(fit, conf.int = TRUE)
    glance_df <- broom::glance(fit)
    augment_df <- tryCatch(broom::augment(fit), error = function(e) NULL)
    predictions_df <- .p3_predict_model(fit, .p3_prediction_data(p, tables, preds), p$pred_conf_int)
    return(list(data = tidy_df, plot = NULL, objects = list(model = fit, glance = glance_df, augment = augment_df,
        predictions = predictions_df), error = NULL))
}

.p3_anova <- function(p, df, tables = list()) {
    response <- p$response %||% ""
    group <- p$group %||% ""
    if (!nzchar(response) || !nzchar(group))
        stop("Select numeric response and group variable.")
    .p3_require_numeric(df, response, "response")
    if (!group %in% names(df))
        stop("Column not found: ", group)
    anova_data <- df
    anova_data[[group]] <- factor(anova_data[[group]])
    fit <- stats::aov(.p3_model_formula(response, group), data = anova_data)
    tidy_df <- broom::tidy(fit)
    glance_df <- broom::glance(fit)
    tukey_df <- tryCatch({
        tk <- stats::TukeyHSD(fit)
        do.call(rbind, lapply(names(tk), function(nm) {
            d <- as.data.frame(tk[[nm]])
            d$comparison <- rownames(d)
            d$variable <- nm
            d
        }))
    }, error = function(e) NULL)
    pred_df <- .p3_prediction_data(p, tables, group)
    if (!is.null(pred_df)) {
        levels <- fit$xlevels[[group]] %||% levels(anova_data[[group]])
        unseen <- setdiff(unique(as.character(pred_df[[group]][!is.na(pred_df[[group]])])), levels)
        if (length(unseen)) stop("Prediction groups not seen in training: ", paste(unseen, collapse = ", "))
        pred_df[[group]] <- factor(pred_df[[group]], levels = levels)
    }
    predictions_df <- .p3_predict_model(fit, pred_df, p$pred_conf_int)
    return(list(data = tidy_df, plot = NULL, objects = list(model = fit, glance = glance_df, tukey = tukey_df,
        predictions = predictions_df), error = NULL))
}
