test_that("headless imports receive session credentials without persisting them", {
  received <- NULL
  testthat::local_mocked_bindings(execute_import = function(p, pwd = "") {
    received <<- pwd
    list(data = data.frame(x = 1:3), lazy = FALSE, con = NULL, error = NULL)
  })
  store <- new_test_store()
  p <- default_import_params("raw"); p$source_kind <- "db"
  add_test_task(store, "imp", "import_data", output = "raw", params = p)
  shiny::isolate(assign("imp", "testing-secret", envir = store$db_passwords))
  expect_true(shiny::isolate(run_task_from_store(store, "imp")))
  expect_identical(received, "testing-secret")
  path <- tempfile(fileext = ".igpx")
  project_save(store, path)
  root <- project_unzip(path)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  text <- paste(unlist(lapply(list.files(root, recursive = TRUE, full.names = TRUE), readLines, warn = FALSE)), collapse = "\n")
  expect_false(grepl("testing-secret", text, fixed = TRUE))
  loaded <- make_store(); project_load(loaded, path)
  expect_identical(store_db_password(loaded, "imp"), "")
})

test_that("flow queue pauses for credentials, retries authentication and resumes once", {
  # This fixture exercises the credential/modal state machine. Real workers
  # and queue resumption are covered separately without a 15-second UI timeout.
  withr::local_options(ig.background_workers = 0L)
  old_options <- options(ig.recovery_dir = tempfile("auth-recovery-"), ig.catalogue_dir = tempfile("auth-catalogue-"))
  on.exit(options(old_options), add = TRUE)
  attempts <- character(0)
  testthat::local_mocked_bindings(execute_import = function(p, pwd = "") {
    attempts <<- c(attempts, pwd)
    if (!identical(pwd, "testing-secret")) return(list(error = "authentication failed"))
    list(data = data.frame(x = 1:4), lazy = FALSE, con = NULL, error = NULL)
  })
  shiny::testServer(app_server, {
    root_session <- session$rootScope()
    p <- default_import_params("raw")
    p$source_kind <- "db"; p$db_conn_mode <- "form"; p$db_driver <- "odbc"
    p$db_dsn <- "example"; p$db_uid <- "tester"; p$db_table <- "data"
    add_test_task(store, "imp", "import_data", output = "raw", params = p)
    h <- default_first_last_params("rows"); h$input_table <- "raw"; h$n <- 2
    add_test_task(store, "head", "first_last_n", inputs = "raw", output = "rows", params = h)
    root_session$flushReact()
    start_run_queue(c("imp", "head"))
    wait_for_test_run(root_session, function() is.function(store$params_fns$imp))
    expect_equal(shiny::isolate(store$run_queue), c("imp", "head"))
    root_session$setInputs(`import_imp-source_kind` = "db", `import_imp-db_conn_mode` = "form",
      `import_imp-db_driver` = "odbc", `import_imp-db_dsn` = "example", `import_imp-db_uid` = "tester",
      `import_imp-db_table` = "data", `import_imp-output_name` = "raw", `import_imp-ig_ready` = module_ready_value(store, "imp"))
    root_session$flushReact()
    wait_for_test_run(root_session, function() identical(store$run_waiting, "imp"))
    expect_true("imp" %in% names(shiny::isolate(store$params_fns)))
    expect_false(is.null(shiny::isolate(store$params_fns$imp())))
    expect_identical(shiny::isolate(store$run_waiting), "imp")
    expect_identical(shiny::isolate(store$tasks$imp$status), "waiting")
    expect_null(shiny::isolate(store$tasks$imp$error_msg))
    expect_length(attempts, 0)
    expect_false("rows" %in% names(shiny::isolate(store$tables)))
    root_session$setInputs(`import_imp-modal_pwd` = "wrong", `import_imp-modal_pwd_ok` = 1)
    root_session$flushReact()
    expect_identical(shiny::isolate(store$run_waiting), "imp")
    expect_identical(shiny::isolate(store$tasks$imp$status), "waiting")
    root_session$setInputs(`import_imp-modal_pwd` = "testing-secret", `import_imp-modal_pwd_ok` = 2)
    wait_for_test_run(root_session, function() !length(store$run_ids))
    expect_null(shiny::isolate(store$run_waiting))
    expect_length(shiny::isolate(store$run_ids), 0)
    expect_identical(attempts, c("wrong", "testing-secret"))
    expect_identical(shiny::isolate(store$tasks$imp$status), "success")
    expect_identical(shiny::isolate(store$tasks$head$status), "success")
    expect_equal(shiny::isolate(store$tables$rows), data.frame(x = 1:2))
  })
})

test_that("cancelled credential requests skip their dependent queue", {
  withr::local_options(ig.background_workers = 0L)
  old_options <- options(ig.recovery_dir = tempfile("auth-recovery-"), ig.catalogue_dir = tempfile("auth-catalogue-"))
  on.exit(options(old_options), add = TRUE)
  shiny::testServer(app_server, {
    root_session <- session$rootScope()
    p <- default_import_params("raw")
    p$source_kind <- "db"; p$db_conn_mode <- "form"; p$db_driver <- "odbc"
    p$db_dsn <- "example"; p$db_uid <- "tester"; p$db_table <- "data"
    add_test_task(store, "imp", "import_data", output = "raw", params = p)
    h <- default_first_last_params("rows"); h$input_table <- "raw"
    add_test_task(store, "head", "first_last_n", inputs = "raw", output = "rows", params = h)
    root_session$flushReact()
    start_run_queue(c("imp", "head")); root_session$flushReact()
    wait_for_test_run(root_session, function() is.function(store$params_fns$imp))
    root_session$setInputs(`import_imp-source_kind` = "db", `import_imp-db_conn_mode` = "form",
      `import_imp-db_uid` = "tester", `import_imp-db_dsn` = "example", `import_imp-db_table` = "data",
      `import_imp-output_name` = "raw", `import_imp-ig_ready` = module_ready_value(store, "imp"))
    wait_for_test_run(root_session, function() identical(store$run_waiting, "imp"))
    root_session$setInputs(`import_imp-modal_pwd_cancel` = 1)
    wait_for_test_run(root_session, function() !length(store$run_ids))
    expect_null(shiny::isolate(store$run_waiting))
    expect_length(shiny::isolate(store$run_ids), 0)
    expect_identical(shiny::isolate(store$tasks$imp$status), "skipped")
    expect_identical(shiny::isolate(store$tasks$head$status), "skipped")
    expect_null(shiny::isolate(store$tasks$head$error_msg))
    root_session$setInputs(`import_imp-btn_refresh` = 1)
    root_session$flushReact()
    expect_identical(shiny::isolate(store$tasks$imp$status), "waiting")
    root_session$setInputs(`import_imp-modal_pwd_cancel` = 2)
    root_session$flushReact()
    expect_identical(shiny::isolate(store$tasks$imp$status), "skipped")
  })
})
