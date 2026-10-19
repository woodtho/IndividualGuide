test_that("analytical panels and code collect lazy model and prediction tables consistently", {
  skip_if_not_installed("RSQLite")
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbWriteTable(con, "cars", datasets::mtcars)
  lazy <- dplyr::tbl(con, "cars")
  p <- default_phase3_params("linear_regression", "fit")
  p$input_table <- "raw"; p$response <- "mpg"; p$predictors <- "wt"
  p$pred_table <- "newdata"; p$output_enabled$predictions <- TRUE
  tables <- list(raw = lazy, newdata = lazy)
  expected <- execute_phase3_task("linear_regression", p, tables)
  expect_null(expected$error)
  expect_equal(nrow(expected$objects$predictions), nrow(datasets::mtcars))
  env <- list2env(tables, parent = globalenv())
  eval(parse(text = build_phase3_code("linear_regression", p)), env)
  expect_equal(env$fit, expected$data)
  expect_equal(env$fit_predictions, expected$objects$predictions)
  store <- new_test_store(tables)
  add_test_task(store, "fit", "linear_regression", inputs = c("raw", "newdata"), params = p)
  shiny::testServer(phase3_task_server,
    args = list(store = store, task_id = "fit", type_id = "linear_regression"), {
      session$setInputs(input_table = "raw", response = "mpg", predictors = "wt", pred_table = "newdata",
        output_name = "fit", output_table = "fit", output_predictions = "fit_predictions", output_glance = "fit_glance",
        output_enabled_predictions = TRUE, ig_ready = module_ready_value(store, "fit"))
      session$flushReact()
      expect_true(do_run())
      session$flushReact()
      expect_equal(shiny::isolate(store$tables$fit_predictions), expected$objects$predictions)
      expect_match(output$result_gt$html, "gt_table", fixed = TRUE)
      expect_false(grepl("gt_shiny", output$result_gt$html, fixed = TRUE))
    })
})
