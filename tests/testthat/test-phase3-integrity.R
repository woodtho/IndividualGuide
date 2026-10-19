phase3_config <- function(type, ...) {
  p <- set_params(default_phase3_params(type, "result"), ...)
  for (def in phase3_return_defs(type)) p$output_enabled[[def$key]] <- def$key != "predictions" || nzchar(p$pred_table %||% "")
  p
}

test_that("paired t-tests use complete row pairs and match exported R", {
  df <- data.frame(before = c(10, 12, 9, 14, NA, 8), after = c(9, 10, 10, 10, 6, 7))
  p <- phase3_config("t_test", input_table = "data", response = "before", paired = TRUE, paired_column = "after")
  result <- execute_phase3_task("t_test", p, list(data = df))
  expect_null(result$error)
  expect_equal(result$objects$test$statistic, stats::t.test(df$before, df$after, paired = TRUE)$statistic)
  env <- new.env(parent = globalenv()); env$data <- df
  eval(parse(text = build_phase3_code("t_test", p)), env)
  expect_equal(env$result, result$data)
  expect_match(env$result_test$method, "Paired")
  p$paired_column <- "before"
  expect_match(execute_phase3_task("t_test", p, list(data = df))$error, "different")
})

test_that("clustering supports hierarchical linkage and reproducible k-means without changing RNG", {
  df <- mtcars[c("mpg", "wt", "hp")]
  for (method in c("kmeans", "hierarchical")) {
    p <- phase3_config("cluster_analysis", input_table = "data", predictors = names(df), cluster_method = method, k = 3L)
    set.seed(41); rng <- .Random.seed
    result <- execute_phase3_task("cluster_analysis", p, list(data = df))
    expect_null(result$error)
    expect_identical(.Random.seed, rng)
    env <- new.env(parent = globalenv()); env$data <- df
    eval(parse(text = build_phase3_code("cluster_analysis", p)), env)
    expect_equal(env$result, result$data)
    expect_equal(env$result_clusters, result$objects$clusters)
    expect_s3_class(env$result_model, if (method == "kmeans") "kmeans" else "hclust")
    expect_equal(length(unique(env$result_clusters$.cluster)), 3L)
  }
  p$k <- 100
  expect_match(execute_phase3_task("cluster_analysis", p, list(data = df))$error, "Clusters must")
})

test_that("graph settings and data agree with exported calculations", {
  df <- mtcars
  df$category <- factor(df$cyl)
  specs <- list(
    bar_chart = list(x = "category"),
    bar_line_chart = list(x = "wt", y = "mpg", y2 = "hp"),
    line_plot = list(x = "wt", y = "mpg", y2 = "hp"),
    box_plot = list(x = "cyl", y = "mpg"),
    bubble_plot = list(x = "wt", y = "mpg", size = "hp"),
    contour_plot = list(x = "wt", y = "mpg"),
    histogram_graph = list(x = "mpg", bins = 8L, density_overlay = TRUE),
    pie_chart = list(x = "category", donut = TRUE),
    scatter_plot = list(x = "wt", y = "mpg", group = "category"),
    scatter_matrix = list(cols = c("mpg", "wt", "hp")))
  for (type in names(specs)) {
    p <- do.call(phase3_config, c(list(type, input_table = "data", title = 'A "quoted" title',
      plot_width = 9, plot_height = 5, palette = "okabe_ito", show_grid = FALSE), specs[[type]]))
    result <- execute_phase3_task(type, p, list(data = df))
    expect_null(result$error, info = type)
    if (!is.null(result$error)) next
    env <- new.env(parent = globalenv()); env$data <- df
    eval(parse(text = build_phase3_code(type, p)), env)
    expect_equal(env$result, result$data, info = type)
    expect_equal(ggplot2::ggplot_build(env$result_image)$data,
      ggplot2::ggplot_build(result$objects$image)$data, info = type)
    expect_equal(env$result_image$labels$title, 'A "quoted" title')
    expect_s3_class(env$result_plot, "girafe")
    if (type == "scatter_matrix") {
      expect_equal(nrow(env$result_image$data), nrow(df) * 9L)
      expect_s3_class(env$result_image$facet, "FacetGrid")
    }
    if (type %in% c("bar_line_chart", "line_plot")) {
      scale <- .p3_secondary_scale(df$mpg, df$hp, type == "bar_line_chart")
      drawn <- ggplot2::ggplot_build(env$result_image)$data
      expect_equal(sort(tail(drawn, 1)[[1]]$y), sort(df$hp * scale$slope + scale$intercept))
    }
    if (type == "histogram_graph") expect_equal(sum(env$result$count), nrow(df))
  }
  p <- phase3_config("scatter_matrix", input_table = "data", matrix_view = "distributions", cols = c("mpg", "wt"))
  expect_s3_class(execute_phase3_task("scatter_matrix", p, list(data = df))$objects$image$facet, "FacetWrap")
})

test_that("model prediction confidence intervals and special column names survive code export", {
  df <- mtcars
  names(df)[names(df) == "mpg"] <- "response ` \\ name"
  names(df)[names(df) == "wt"] <- "predictor ` name"
  p <- phase3_config("linear_regression", input_table = "data", response = names(df)[[1]],
    predictors = "predictor ` name", pred_table = "newdata", pred_conf_int = TRUE)
  for (type in c("linear_regression", "linear_models", "glm")) {
    result <- execute_phase3_task(type, p, list(data = df, newdata = df[1:5, ]))
    expect_null(result$error, info = type)
    env <- new.env(parent = globalenv()); env$data <- df; env$newdata <- df[1:5, ]
    eval(parse(text = build_phase3_code(type, p)), env)
    expect_equal(env$result, result$data)
    expect_equal(env$result_predictions, result$objects$predictions)
    expect_true(all(c(".lower", ".upper") %in% names(env$result_predictions)))
  }
  bad <- df[1:5, setdiff(names(df), p$predictors)]
  expect_match(execute_phase3_task("linear_regression", p, list(data = df, newdata = bad))$error, "Prediction columns")
})

test_that("disabled analytical outputs stay absent from store and exported environment", {
  p <- default_phase3_params("linear_regression", "result")
  p$input_table <- "data"; p$response <- "mpg"; p$predictors <- "wt"
  result <- execute_phase3_task("linear_regression", p, list(data = mtcars))
  store <- new_test_store(list(data = mtcars))
  shiny::isolate(store_phase3_outputs(store, p, result))
  expect_false("result_model" %in% names(shiny::isolate(store$objects)))
  expect_false("result_augment" %in% names(shiny::isolate(store$tables)))
  expect_setequal(vapply(phase3_output_specs(p, result), `[[`, character(1), "name"), c("result", "result_glance"))
  env <- new.env(parent = globalenv()); env$data <- mtcars
  eval(parse(text = build_phase3_code("linear_regression", p)), env)
  expect_setequal(ls(env), c("data", "result", "result_glance"))
})

test_that("analytical edge cases reject invalid predictions and time spacing", {
  p <- default_phase3_params("one_way_anova", "out")
  p$input_table <- "data"; p$response <- "y"; p$group <- "g"; p$pred_table <- "new"
  df <- data.frame(y = c(1, 2, 4, 3, 5, 7), g = c(1, 1, 1, 2, 2, 2))
  result <- execute_phase3_task("one_way_anova", p, list(data = df, new = data.frame(g = 3)))
  expect_match(result$error, "not seen in training")
  p <- default_phase3_params("arima_forecast", "out"); p$input_table <- "data"; p$response <- "y"
  expect_match(execute_phase3_task("arima_forecast", p, list(data = data.frame(y = c(1:9, NA))))$error, "time spacing")
  p$horizon <- 2.5
  expect_match(execute_phase3_task("arima_forecast", p, list(data = data.frame(y = 1:10)))$error, "whole number")
  p <- default_phase3_params("correlations", "out"); p$input_table <- "data"
  expect_match(execute_phase3_task("correlations", p, list(data = data.frame(x = c(1, Inf), y = 1:2)))$error, "infinite")
})
