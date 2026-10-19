test_that("specialized analyses reproduce all saved tables and plot layers in exported R", {
  set.seed(472)
  df <- data.frame(x = seq(0.1, 5, length.out = 60), y = 2 * exp(seq(0.1, 5, length.out = 60) * 0.3) * exp(rnorm(60, 0, 0.03)),
    time = rexp(60, 0.1), event = rbinom(60, 1, 0.7), arm = rep(c("a", "b"), 30))
  specs <- list(cdf_plots = list(response = "y", group = "arm"),
    probability_plots = list(response = "y"), control_charts = list(response = "y"),
    arima_forecast = list(response = "y", horizon = 4L),
    life_tables = list(response = "time", group = "event", predictors = "arm"),
    proportional_hazards = list(response = "time", group = "event", predictors = "x", pred_table = "data"),
    nonlinear_regression = list(response = "y", predictors = "x", curve = "exponential"),
    pca = list(predictors = c("x", "y"), pred_table = "data"),
    correlations = list(predictors = c("x", "y")),
    one_way_anova = list(response = "y", group = "arm", pred_table = "data", pred_conf_int = TRUE))
  for (type in names(specs)) {
    p <- do.call(set_params, c(list(default_phase3_params(type, "result")), list(input_table = "data"), specs[[type]]))
    for (def in phase3_return_defs(type)) p$output_enabled[[def$key]] <- def$key != "predictions" || nzchar(p$pred_table %||% "")
    result <- execute_phase3_task(type, p, list(data = df))
    expect_null(result$error, info = type)
    if (!is.null(result$error)) next
    env <- list2env(list(data = df), parent = globalenv())
    eval(parse(text = build_phase3_code(type, p)), env)
    expect_equal(env$result, result$data, info = type)
    for (key in names(result$objects)) {
      expected <- result$objects[[key]]
      if (is.null(expected)) next
      actual <- get(p$output_names[[key]], envir = env)
      if (is.data.frame(expected)) expect_equal(actual, expected, info = paste(type, key))
      else if (key == "image") expect_equal(ggplot2::ggplot_build(actual)$data, ggplot2::ggplot_build(expected)$data, info = type)
      else expect_identical(class(actual), class(expected), info = paste(type, key))
    }
  }
})

test_that("a full analytical script runs in vanilla R without IndividualGuide", {
  directory <- tempfile("clean_analysis_"); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  store <- new_test_store(list(raw = mtcars))
  p <- default_phase3_params("linear_regression", "coefficients")
  p$input_table <- "raw"; p$response <- "mpg"; p$predictors <- c("wt", "hp")
  add_test_task(store, "fit", "linear_regression", inputs = "raw", params = p)
  g <- default_phase3_params("scatter_plot", "points")
  g$input_table <- "raw"; g$x <- "wt"; g$y <- "mpg"
  add_test_task(store, "graph", "scatter_plot", inputs = "raw", params = g)
  saveRDS(mtcars, file.path(directory, "input.rds"))
  script <- file.path(directory, "pipeline.R")
  result_file <- file.path(directory, "result.rds")
  writeLines(c('if (.Platform$OS.type == "windows") Sys.setlocale("LC_CTYPE", ".UTF-8")',
    paste0('raw <- readRDS(', code_literal(file.path(directory, "input.rds")), ')'),
    build_full_r_script(store),
    paste0('saveRDS(list(data = coefficients, points = points, widget_class = class(points_plot), statuses = .task_status, namespaces = loadedNamespaces()), ', code_literal(result_file), ')')), script, useBytes = TRUE)
  executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  output <- system2(executable, c("--vanilla", shQuote(script)), stdout = TRUE, stderr = TRUE)
  expect_null(attr(output, "status"), info = paste(output, collapse = "\n"))
  expect_true(file.exists(result_file))
  if (!file.exists(result_file)) return(invisible(NULL))
  result <- readRDS(result_file)
  expect_false("IndividualGuide" %in% result$namespaces)
  expect_true(all(vapply(result$statuses, identical, logical(1), "success")))
  expect_equal(result$data, execute_phase3_task("linear_regression", p, list(raw = mtcars))$data)
  expect_equal(result$points, mtcars)
  expect_true("girafe" %in% result$widget_class)
})
