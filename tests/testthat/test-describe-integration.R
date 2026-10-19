balanced_counts <- function() {
  data.frame(row = rep(c("A", "B"), each = 20), column = rep(c("X", "Y"), 20))
}

test_that("table analysis displays requested percentages while saving counts and chi-square", {
  p <- default_table_analysis_params("counts")
  p$input_table <- "data"
  p$row_col <- "row"
  p$col_col <- "column"
  p$show_pct <- "row"
  tables <- list(data = balanced_counts())
  result <- execute_table_analysis(p, tables)
  expect_null(result$error)
  expect_equal(rowSums(result$display), c(A = 100, B = 100))
  expect_equal(sum(as.matrix(result$data)), 40)
  expect_equal(result$chi_table$df, 1)
  store <- new_test_store(tables)
  add_test_task(store, "analysis", "table_analysis", inputs = "data", params = p)
  expect_true(shiny::isolate(run_task_from_store(store, "analysis")))
  expect_identical(shiny::isolate(store$tables$counts_chisq), result$chi_table)
  env <- list2env(tables, parent = globalenv())
  eval(parse(text = build_table_analysis_code(p)), env)
  expect_identical(env$counts_chisq, result$chi_table)
  expect_identical(env$counts, result$data)
  expect_equal(rowSums(env$.table_display), c(A = 100, B = 100))
})

test_that("chi-square-only outputs retain lineage without a phantom primary table", {
  store <- new_test_store(list(data = balanced_counts()))
  p <- default_table_analysis_params("counts")
  p$input_table <- "data"
  p$row_col <- "row"
  p$col_col <- "column"
  p$output_enabled <- FALSE
  task <- store_task_from_params(task_def("analysis", "table_analysis"), p)
  shiny::isolate(store_set_task(store, task))
  expect_true(shiny::isolate(run_task_from_store(store, "analysis")))
  expect_identical(task_output_names(shiny::isolate(store$tasks$analysis)), "counts_chisq")
  expect_false("counts" %in% names(shiny::isolate(store$tables)))
  expect_true("counts_chisq" %in% names(shiny::isolate(store$tables)))
})

test_that("distribution code matches statistics and includes configured plots and dimensions", {
  p <- default_distribution_params("stats")
  p$input_table <- "data"
  p$col <- "value's column"
  p$show_qq <- TRUE
  p$plot_width <- 7
  p$plot_height <- 3
  tables <- list(data = setNames(data.frame(value = c(1, 2, 3, 4, NA)), p$col))
  expected <- execute_distribution(p, tables)
  expect_null(expected$error)
  env <- list2env(tables, parent = globalenv())
  eval(parse(text = build_dist_code(p)), env)
  expect_identical(env$stats, expected$data)
  expect_s3_class(env$.ig_qq_plot, "ggplot")
  expect_s3_class(env$.ig_distribution_plot, "girafe")
  expect_match(build_dist_code(p), "width_svg = 7", fixed = TRUE)
  for (values in list(numeric(0), c(NA_real_, NA_real_))) {
    result <- execute_distribution(p, list(data = setNames(data.frame(value = values), p$col)))
    expect_null(result$error)
    expect_equal(result$data$n, 0)
    expect_true(is.na(result$data$min))
    expect_true(is.na(result$data$max))
  }
})
