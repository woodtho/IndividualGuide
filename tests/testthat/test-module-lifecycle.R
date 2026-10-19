test_that("unrun module edits persist and old observers stop when a module ends", {
  store <- new_test_store(list(raw = data.frame(x = 1:3)))
  add_test_task(store, "firstlast_1", "first_last_n", inputs = "raw",
    params = default_first_last_params("head_rows"))
  shiny::testServer(first_last_n_server,
    args = list(store = store, task_id = "firstlast_1"), {
      session$setInputs(input_table = "raw", output_name = "head_rows", n = 2, which = "head", ig_ready = module_ready_value(store, "firstlast_1"))
      session$flushReact()
      expect_equal(shiny::isolate(store$tasks$firstlast_1$params$n), 2)
      expect_equal(shiny::isolate(store$tasks$firstlast_1$inputs), "raw")
      expect_null(shiny::isolate(store$tasks$firstlast_1$run_time))
      path <- tempfile(fileext = ".igpx")
      project_save(store, path)
      loaded <- make_store()
      project_load(loaded, path)
      expect_equal(shiny::isolate(loaded$tasks$firstlast_1$params$n), 2)
      expect_true(shiny::isolate(run_task_from_store(loaded, "firstlast_1")))
      expect_equal(nrow(shiny::isolate(loaded$tables$head_rows)), 2)
      ig_end_task_modules(session)
      session$setInputs(n = 1)
      session$flushReact()
      expect_equal(shiny::isolate(store$tasks$firstlast_1$params$n), 2)
    })
})

test_that("script dependencies can be explicitly cleared after binding", {
  store <- new_test_store(list(raw = data.frame(x = 1:3)))
  p <- default_script_params("out"); p$input_tables <- "raw"; p$code <- "out <- raw"
  add_test_task(store, "script", "script", inputs = "raw", params = p)
  shiny::testServer(script_server, args = list(store = store, task_id = "script"), {
    session$setInputs(input_tables = "raw", code = p$code, output_name = "out", output_defs = "out: table",
      ig_ready = module_ready_value(store, "script"))
    session$flushReact()
    expect_equal(shiny::isolate(store$tasks$script$inputs), "raw")
    session$setInputs(input_tables = NULL)
    session$flushReact()
    expect_identical(shiny::isolate(store$tasks$script$inputs), character(0))
  })
})

test_that("sibling modules retain distinct input and output namespaces", {
  store <- new_test_store(list(raw = data.frame(x = 1:5)))
  for (id in c("head_a", "head_b")) add_test_task(store, id, "first_last_n", inputs = "raw",
    params = default_first_last_params(paste0(id, "_out")))
  shiny::testServer(function(input, output, session) {
    first_last_n_server("first", store, "head_a")
    first_last_n_server("second", store, "head_b")
  }, {
    root <- session$rootScope()
    root$setInputs(`first-input_table` = "raw", `first-output_name` = "head_a_out",
      `first-n` = 1, `first-which` = "head", `first-ig_ready` = module_ready_value(store, "head_a"),
      `second-input_table` = "raw", `second-output_name` = "head_b_out",
      `second-n` = 3, `second-which` = "tail", `second-ig_ready` = module_ready_value(store, "head_b"))
    root$flushReact()
    expect_equal(shiny::isolate(store$tasks$head_a$params$n), 1)
    expect_equal(shiny::isolate(store$tasks$head_b$params$n), 3)
    expect_identical(environment(shiny::isolate(store$params_fns$head_a))$session$ns("n"), "first-n")
    expect_true(shiny::isolate(store$task_runners$head_a()))
    expect_true(shiny::isolate(store$task_runners$head_b()))
    expect_equal(shiny::isolate(store$tables$head_a_out), data.frame(x = 1L))
    expect_equal(shiny::isolate(store$tables$head_b_out), data.frame(x = 3:5, row.names = 3:5))
  })
})

test_that("opening a restored successful task hydrates its saved preview", {
  store <- new_test_store(list(raw = data.frame(x = 1:5)))
  p <- default_first_last_params("rows"); p$input_table <- "raw"; p$n <- 2L
  add_test_task(store, "head", "first_last_n", inputs = "raw", params = p)
  expect_true(shiny::isolate(run_task_from_store(store, "head")))
  path <- tempfile(fileext = ".igpx"); project_save(store, path)
  loaded <- make_store(); project_load(loaded, path)
  shiny::testServer(first_last_n_server, args = list(store = loaded, task_id = "head"), {
    expect_equal(preview_df(), data.frame(x = 1:2))
    expect_match(run_status_msg(), "Complete")
  })
})

test_that("panel validation failures retain the executor's actionable message", {
  store <- new_test_store(list(raw = data.frame(x = 1:3)))
  add_test_task(store, "head", "first_last_n", params = default_first_last_params("rows"))
  shiny::testServer(first_last_n_server, args = list(store = store, task_id = "head"), {
    session$setInputs(input_table = "missing", output_name = "rows", n = 2, which = "head", ig_ready = module_ready_value(store, "head"))
    session$flushReact()
    session$setInputs(btn_run = 1)
    session$flushReact()
    expect_match(shiny::isolate(store$tasks$head$error_msg), "Table not found: missing", fixed = TRUE)
    expect_match(run_status_msg(), "Table not found: missing", fixed = TRUE)
    expect_identical(shiny::isolate(store$tasks$head$status), "error")
  })
})

test_that("cleared NULL selections are not restored from saved parameters after binding", {
  expect_identical(store_preserve_choices(NULL, "x", c("x", "y"), initialized = TRUE), character(0))
  expect_identical(store_preserve_choices(NULL, "x", c("x", "y")), "x")
  store <- new_test_store(list(raw = data.frame(x = 1:3, y = 4:6)))
  p <- default_summary_stats_params("summary"); p$input_table <- "raw"; p$cols <- "x"
  add_test_task(store, "summary", "summary_stats", inputs = "raw", params = p)
  shiny::testServer(summary_stats_server, args = list(store = store, task_id = "summary"), {
    expect_false(store_inputs_ready(store, "summary"))
    session$setInputs(input_table = "raw", cols = "x", output_name = "summary", output_enabled = TRUE,
      ig_ready = module_ready_value(store, "summary"))
    session$flushReact()
    expect_true(store_inputs_ready(store, "summary"))
    session$setInputs(cols = NULL)
    session$flushReact()
    store_add_table(store, "raw", data.frame(x = 1:4, y = 5:8, z = 9:12))
    session$flushReact()
    expect_identical(shiny::isolate(store$tasks$summary$params$cols), character(0))
  })
})

test_that("blank initial widget values restore saved selections before binding", {
  expect_identical(store_preserve_choice("", "y", c("", "x", "y")), "y")
  expect_identical(store_preserve_choice("", "y", c("", "x", "y"), initialized = TRUE), "")
  expect_identical(store_preserve_choices(character(0), "x", c("x", "y")), "x")
  expect_identical(store_preserve_choices(character(0), "x", c("x", "y"), initialized = TRUE), character(0))
})

test_that("open data previews clear on edits and refresh after headless runs", {
  store <- new_test_store(list(raw = data.frame(x = 1:5)))
  add_test_task(store, "head1", "first_last_n", inputs = "raw", params = default_first_last_params("rows"))
  shiny::testServer(first_last_n_server, args = list(store = store, task_id = "head1"), {
    session$setInputs(input_table = "raw", output_name = "rows", n = 2, which = "head", ig_ready = module_ready_value(store, "head1"))
    session$flushReact()
    expect_true(run_task_from_store(store, "head1"))
    expect_equal(preview_df(), data.frame(x = 1:2))
    session$setInputs(n = 3)
    session$flushReact()
    expect_null(preview_df())
    expect_equal(run_status_msg(), "")
    expect_true(run_task_from_store(store, "head1"))
    expect_equal(preview_df(), data.frame(x = 1:3))
    store_add_table(store, "raw", data.frame(x = 6:9))
    expect_null(preview_df())
    expect_true(run_task_from_store(store, "head1"))
    expect_equal(preview_df(), data.frame(x = 6:8))
    expect_false(store_run_guarded(store, function() stop("broken run"), task_id = "head1"))
    expect_null(preview_df())
    expect_match(run_status_msg(), "broken run")
    ig_end_task_modules(session)
    expect_null(shiny::isolate(store$result_fns$head1))
  })
})

test_that("model panels receive headless output and retire stale plots", {
  store <- new_test_store(list(raw = mtcars))
  p <- default_phase3_params("linear_regression", "fit")
  p$input_table <- "raw"; p$response <- "mpg"; p$predictors <- "wt"
  add_test_task(store, "model1", "linear_regression", inputs = "raw", params = p)
  shiny::testServer(phase3_task_server,
    args = list(type_id = "linear_regression", store = store, task_id = "model1"), {
      expect_true(run_task_from_store(store, "model1"))
      expect_true(is.data.frame(result_df()))
      expect_s3_class(result_objects()$model, "lm")
      store_add_table(store, "raw", mtcars[1:10, ])
      expect_null(result_df())
      expect_null(result_plot())
      expect_length(result_objects(), 0)
    })
})
