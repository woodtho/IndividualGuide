test_that("unrun configured import and chained tasks export a runnable pipeline", {
  path <- tempfile(fileext = ".csv")
  readr::write_csv(sample_sales(), path)
  store <- new_test_store()
  p <- default_import_params("raw")
  p$path <- path
  p$type <- "csv"
  add_test_task(store, "imp", "import_data", output = "raw", params = p)
  p <- default_filter_sort_params("clean data")
  p$input_table <- "raw"
  p$sorts <- list(list(col = "qty", dir = "DESC"))
  add_test_task(store, "filter", "filter_sort", inputs = "raw", output = "clean data", params = p)
  p <- default_first_last_params("first rows")
  p$input_table <- "clean data"
  p$n <- 2
  add_test_task(store, "head", "first_last_n", inputs = "clean data", output = "first rows", params = p)
  script <- build_full_r_script(store)
  expect_match(script, "readr::read_delim", fixed = TRUE)
  expect_match(script, "`first rows` <-", fixed = TRUE)
  env <- new.env(parent = globalenv())
  eval(parse(text = script), env)
  for (id in shiny::isolate(store$task_order)) expect_true(shiny::isolate(run_task_from_store(store, id)))
  expect_equal(as.data.frame(env$`first rows`), as.data.frame(shiny::isolate(store$tables$`first rows`)))
})
