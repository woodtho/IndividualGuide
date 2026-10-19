test_that("Stop clears pending queue work before cancelling a worker", {
  store <- make_store()
  store$run_ids <- c("first", "second"); store$run_queue <- "second"
  store$run_waiting <- "first"; store$run_resumed <- "first"; store$run_current <- "first"
  expect_true(isolate(store_stop_run(store)))
  isolate({
    expect_length(store$run_ids, 0L); expect_length(store$run_queue, 0L)
    expect_null(store$run_waiting); expect_null(store$run_resumed); expect_null(store$run_current)
    expect_equal(store$run_generation, 1L); expect_identical(store$run_outcome, "stopped")
    expect_false(store_stop_run(store))
  })
})

test_that("run status describes current task and preserves stop progress", {
  store <- make_store()
  store$run_ids <- c("one", "two"); store$run_total <- 2L; store$run_completed <- 1L
  store$run_current <- "two"; store$run_started <- as.POSIXct("2026-10-16", tz = "UTC")
  isolate({
    state <- store_run_state(store)
    expect_true(state$running); expect_identical(state$task, "two")
    expect_equal(state$total, 2L); expect_equal(state$completed, 1L)
    expect_false(state$interruptible); expect_gt(state$started, 0)
    store_stop_run(store)
    state <- store_run_state(store)
    expect_false(state$running); expect_equal(state$completed, 1L); expect_identical(state$outcome, "stopped")
  })
})
test_that("Stop kills a real worker and late results cannot change the project", {
  session <- shiny::MockShinySession$new(); on.exit(session$close())
  store <- new_test_store(list(raw = data.frame(x = 1:12, y = sin(1:12))))
  p <- default_phase3_params("cluster_analysis", "result")
  p$input_table <- "raw"; p$predictors <- c("x", "y"); p$k <- 2L
  isolate(store_set_task(store, store_task_from_params(task_def("analysis", "cluster_analysis"), p)))
  store_init_background(store, session)
  isolate(ig_background_start(store, "analysis"))
  session$flushReact()
  deadline <- Sys.time() + 30
  while (is.null(isolate(store$background$job$process)) && Sys.time() < deadline) later::run_now(0.05)
  job <- isolate(store$background$job)
  expect_false(is.null(job$process))
  process <- job$process
  expect_true(process$is_alive())
  isolate(store_stop_run(store)); process$wait(5000)
  expect_false(process$is_alive())
  isolate(ig_background_finish(job, list(result = list(data = data.frame(late = 1)), events = list())))
  expect_null(isolate(store$tables$result))
  expect_false(isolate(store_run_state(store)$running))
  expect_identical(isolate(store$run_outcome), "stopped")
})
test_that("New Project releases old data, credentials and modules without reloading R", {
  withr::local_options(ig.recovery_dir = tempfile(), ig.catalogue_dir = tempfile())
  shiny::testServer(app_server, {
    add_test_task(store, "old", "script", params = default_script_params("old_rows"))
    store$tables <- list(old_rows = data.frame(x = 1))
    store$objects <- list(old_model = list(value = lm(mpg ~ wt, mtcars)))
    assign("old", "secret", envir = store$db_passwords)
    open_task_panel("old"); session$rootScope()$flushReact()
    previous <- module_ready_value(store, "old")
    store$dirty <- TRUE
    expect_true(reset_project())
    session$rootScope()$flushReact()
    expect_length(store$tasks, 0L); expect_length(store$tables, 0L); expect_length(store$objects, 0L)
    expect_length(ls(store$db_passwords), 0L)
    expect_length(store$task_runners, 0L); expect_length(store$params_fns, 0L)
    expect_false(store$dirty); expect_null(store$project_path); expect_length(store$flows, 1L)
    add_test_task(store, "old", "script", params = default_script_params("new_rows"))
    open_task_panel("old"); session$rootScope()$flushReact()
    expect_false(identical(previous, module_ready_value(store, "old")))
  })
})
test_that("Stop retires a password prompt and ignores its late submission", {
  withr::local_options(ig.recovery_dir = tempfile(), ig.catalogue_dir = tempfile())
  attempts <- 0L
  testthat::local_mocked_bindings(execute_import = function(...) {
    attempts <<- attempts + 1L; list(error = "Late credential submission executed")
  })
  shiny::testServer(app_server, {
    root <- session$rootScope()
    p <- default_import_params("raw"); p$source_kind <- "db"; p$db_conn_mode <- "form"
    p$db_driver <- "odbc"; p$db_dsn <- "example"; p$db_uid <- "tester"; p$db_table <- "data"
    add_test_task(store, "imp", "import_data", output = "raw", params = p)
    root$flushReact(); start_run_queue("imp")
    wait_for_test_run(root, function() is.function(store$params_fns$imp))
    root$setInputs(`import_imp-source_kind` = "db", `import_imp-db_conn_mode` = "form",
      `import_imp-db_driver` = "odbc", `import_imp-db_dsn` = "example", `import_imp-db_uid` = "tester",
      `import_imp-db_table` = "data", `import_imp-output_name` = "raw", `import_imp-ig_ready` = module_ready_value(store, "imp"))
    wait_for_test_run(root, function() identical(store$run_waiting, "imp"))
    root$setInputs(stop_run = 1)
    expect_null(store$run_waiting); expect_length(store$run_ids, 0L)
    root$setInputs(`import_imp-modal_pwd` = "secret", `import_imp-modal_pwd_ok` = 1)
    root$flushReact()
    expect_equal(attempts, 0L); expect_null(store$tables$raw)
  })
})
