test_that("deletion preserves cross-flow consumers and undo rebuilds disposable panels", {
  withr::local_options(ig.background_workers = 0L)
  old <- options(ig.recovery_dir = tempfile(), ig.catalogue_dir = tempfile())
  on.exit(options(old), add = TRUE)
  shiny::testServer(app_server, {
    root <- session$rootScope()
    store$tables <- list(raw = data.frame(x = 1:5))
    p <- default_first_last_params("rows"); p$input_table <- "raw"; p$n <- 2L
    add_test_task(store, "head", "first_last_n", inputs = "raw", params = p)
    expect_true(shiny::isolate(run_task_from_store(store, "head")))
    first <- shiny::isolate(store$active_flow)
    second <- make_flow("Other")
    second$tasks <- list(consumer = task_def("consumer", "first_last_n", inputs = "rows",
      output = "other", params = set_params(default_first_last_params("other"), input_table = "rows")))
    second$task_order <- "consumer"
    flows <- shiny::isolate(store$flows); flows[[second$id]] <- second; store$flows <- flows
    open_task_panel("head"); root$flushReact()
    previous_token <- module_ready_value(store, "head")
    root$setInputs(`fl_head-input_table` = "raw", `fl_head-output_name` = "rows",
      `fl_head-which` = "head", `fl_head-n` = 2L, `fl_head-ig_ready` = previous_token)
    perform_delete_task("head")
    expect_null(shiny::isolate(store$tasks$head))
    expect_equal(shiny::isolate(store$tables$rows), data.frame(x = 1:2))
    expect_null(shiny::isolate(store$task_runners$head))
    expect_null(environment(open_task_panel)$panel_observer_handles$head)
    expect_false("head" %in% environment(open_task_panel)$panel_observers)
    do_undo(); root$flushReact()
    expect_true("head" %in% names(shiny::isolate(store$tasks)))
    expect_false(identical(previous_token, module_ready_value(store, "head")))
    # Run, control selection and the distinct control-UI observer share the
    # panel's lifetime and must all be replaced on Undo.
    expect_equal(length(environment(open_task_panel)$panel_observer_handles$head), 3L)
    root$setInputs(`fl_head-input_table` = "raw", `fl_head-output_name` = "rows",
      `fl_head-which` = "head", `fl_head-n` = 2L, `fl_head-ig_ready` = module_ready_value(store, "head"))
    root$flushReact()
    expect_identical(shiny::isolate(store$tasks$head$status), "success")
    # Deleting a whole active flow must also release its modules and snapshots.
    perform_delete_flow(first)
    expect_false(first %in% names(shiny::isolate(store$flows)))
    expect_identical(shiny::isolate(store$active_flow), second$id)
    expect_null(shiny::isolate(store$task_runners$head))
    expect_equal(shiny::isolate(store$tables$rows), data.frame(x = 1:2))
    do_undo(); root$flushReact()
    expect_identical(shiny::isolate(store$active_flow), first)
    expect_true("head" %in% names(shiny::isolate(store$tasks)))
    store$run_ids <- "head"
    perform_delete_task("head")
    expect_true("head" %in% names(shiny::isolate(store$tasks)))
    store$run_ids <- character(0)
    store$review_mode <- TRUE
    depth <- length(shiny::isolate(undo_stack()))
    do_undo()
    expect_equal(length(shiny::isolate(undo_stack())), depth)
  })
})

test_that("retiring lazy producers materializes shared outputs and undo rejects dead pointers", {
  skip_if_not_installed("RSQLite")
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  DBI::dbWriteTable(con, "data", data.frame(x = 1:3))
  store <- new_test_store()
  p <- default_import_params("raw"); p$source_kind <- "db"; p$db_collect <- FALSE
  add_test_task(store, "imp", "import_data", params = p)
  add_test_task(store, "head", "first_last_n", inputs = "raw",
    params = set_params(default_first_last_params("rows"), input_table = "raw"))
  store$tables <- list(raw = dplyr::tbl(con, "data"))
  store$sources <- list(raw = list(task_id = "imp"))
  store_register_connection(store, "imp", con)
  original <- shiny::isolate(store$tables)
  shiny::isolate(store_detach_task_outputs(store, "imp"))
  shiny::isolate(store_remove_task(store, "imp"))
  expect_false(DBI::dbIsValid(con))
  expect_s3_class(shiny::isolate(store$tables$raw), "data.frame")
  expect_equal(shiny::isolate(store$tables$raw$x), 1:3)
  expect_null(shiny::isolate(store$sources$raw$task_id))
  add_test_task(store, "imp", "import_data", params = p)
  store$tables <- original
  shiny::isolate(store_restore_valid_tables(store))
  expect_null(shiny::isolate(store$tables$raw))
  expect_identical(shiny::isolate(store$tasks$imp$status), "pending")
  expect_match(shiny::isolate(store$tasks$imp$restoration_note), "Reconnect")
})
