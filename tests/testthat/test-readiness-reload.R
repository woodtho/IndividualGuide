test_that("reloading cached tasks ignores acknowledgements and inputs from old modules", {
  old_options <- options(ig.recovery_dir = tempfile("reload-recovery-"), ig.catalogue_dir = tempfile("reload-catalogue-"))
  on.exit(options(old_options), add = TRUE)
  incoming <- new_test_store(list(raw = data.frame(x = 1:5)))
  p <- default_first_last_params("rows"); p$input_table <- "raw"; p$n <- 1L
  add_test_task(incoming, "head", "first_last_n", inputs = "raw", params = p)
  expect_true(shiny::isolate(run_task_from_store(incoming, "head")))
  path <- tempfile(fileext = ".igpx"); project_save(incoming, path)
  shiny::testServer(app_server, {
    root <- session$rootScope()
    store$tables <- list(raw = data.frame(x = 1:5))
    p$n <- 2L
    add_test_task(store, "head", "first_last_n", inputs = "raw", params = p)
    open_task_panel("head")
    root$flushReact()
    old_ready <- module_ready_value(store, "head")
    root$setInputs(`fl_head-input_table` = "raw", `fl_head-output_name` = "rows", `fl_head-which` = "head",
      `fl_head-n` = 2L, `fl_head-ig_ready` = old_ready)
    root$flushReact()
    load_from_local_path(path)
    open_task_panel("head")
    root$flushReact()
    expect_equal(shiny::isolate(store$tasks$head$params$n), 1L)
    expect_identical(shiny::isolate(store$tasks$head$status), "success")
    expect_equal(shiny::isolate(store$tables$rows), data.frame(x = 1L))
    new_ready <- module_ready_value(store, "head")
    expect_false(identical(old_ready, new_ready))
    root$setInputs(`fl_head-input_table` = "raw", `fl_head-output_name` = "rows", `fl_head-which` = "head",
      `fl_head-n` = 1L, `fl_head-ig_ready` = new_ready)
    root$flushReact()
    expect_equal(shiny::isolate(store$tasks$head$params$n), 1L)
    expect_identical(shiny::isolate(store$tasks$head$status), "success")
    expect_equal(shiny::isolate(store$tables$rows), data.frame(x = 1L))
  })
})

test_that("opening a cached model preserves successful outputs after browser normalization", {
  store <- new_test_store(list(raw = datasets::mtcars))
  p <- default_phase3_params("linear_regression", "fit")
  p$input_table <- "raw"; p$response <- "mpg"; p$predictors <- "wt"
  add_test_task(store, "model", "linear_regression", inputs = "raw", params = p)
  expect_true(shiny::isolate(run_task_from_store(store, "model")))
  saved <- shiny::isolate(store$tables$fit)
  shiny::testServer(phase3_task_server,
    args = list(store = store, task_id = "model", type_id = "linear_regression"), {
      session$setInputs(input_table = "raw", response = "mpg", predictors = "wt", output_name = "fit",
        output_table = "fit", output_glance = "fit_glance", output_augment = "fit_augment",
        ig_ready = module_ready_value(store, "model"))
      session$flushReact()
      expect_identical(shiny::isolate(store$tasks$model$status), "success")
      expect_equal(shiny::isolate(store$tables$fit), saved)
      session$setInputs(predictors = c("wt", "hp"))
      session$flushReact()
      expect_identical(shiny::isolate(store$tasks$model$status), "pending")
      expect_null(shiny::isolate(store$tables$fit))
    })
})

test_that("reader defaults and inactive import controls preserve cached results", {
  path <- tempfile(fileext = ".csv"); write.csv(data.frame(x = 1:3), path, row.names = FALSE)
  store <- new_test_store()
  p <- default_import_params("raw"); p$path <- path; p$type <- "csv"
  add_test_task(store, "import", "import_data", params = p)
  expect_true(shiny::isolate(run_task_from_store(store, "import")))
  current <- p; current$csv_escape_backslash <- FALSE; current$csv_escape_double <- TRUE
  current$csv_skip_empty_rows <- TRUE; current$csv_trim_ws <- FALSE
  current$csv_lazy <- FALSE
  current$excel_col_names <- FALSE; current$db_conn_code <- "unused"
  shiny::isolate(store_sync_parameters(store, "import", current))
  expect_identical(shiny::isolate(store$tasks$import$status), "success")
  expect_equal(shiny::isolate(store$tables$raw$x), 1:3)
  current$csv_skip <- 1
  shiny::isolate(store_sync_parameters(store, "import", current))
  expect_identical(shiny::isolate(store$tasks$import$status), "pending")
  expect_null(shiny::isolate(store$tables$raw))
})

test_that("the default Excel sheet and its displayed name have equivalent cached results", {
  path <- tempfile(fileext = ".xlsx"); writexl::write_xlsx(list(Measurements = data.frame(x = 1:3)), path)
  p <- default_import_params("raw"); p$path <- path; p$type <- "xlsx"
  task <- store_task_from_params(task_def("import", "import_data"), p)
  p$excel_sheet <- "Measurements"; p$excel_trim_ws <- TRUE
  expect_true(store_equivalent_parameters(task, store_task_from_params(task, p)))
  p$excel_skip <- 1L
  expect_false(store_equivalent_parameters(task, store_task_from_params(task, p)))
})
