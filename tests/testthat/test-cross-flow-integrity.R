test_that("selectors track live output renames without retaining the active snapshot", {
  store <- new_test_store()
  task <- add_test_task(store, "a", "first_last_n", params = default_first_last_params("old_name"))
  shiny::isolate(store_snapshot_flow(store))
  available <- shiny::reactive(store_available_tables(store))
  expect_true("old_name" %in% shiny::isolate(available()))
  task$params$output_name <- "new_name"; task$output <- "new_name"
  shiny::isolate(store_set_task(store, task))
  expect_true("new_name" %in% shiny::isolate(available()))
  expect_false("old_name" %in% shiny::isolate(available()))
  expect_false("new_name" %in% shiny::isolate(store_available_tables(store, "a")))
})

test_that("output ownership and cycles are validated across flows", {
  store <- new_test_store()
  first <- shiny::isolate(store$active_flow)
  add_test_task(store, "a", "first_last_n", inputs = "from_b", params = default_first_last_params("from_a"))
  second <- make_flow("Second"); second$id <- "second"
  flows <- shiny::isolate(store$flows); flows[[second$id]] <- second; store$flows <- flows
  shiny::isolate(store_activate_flow(store, second$id))
  duplicate <- task_def("b", "first_last_n", output = "from_a", params = default_first_last_params("from_a"))
  expect_warning(expect_false(shiny::isolate(store_set_task(store, duplicate))), "one producer")
  expect_null(shiny::isolate(store$tasks$b))
  cycle <- task_def("b", "first_last_n", inputs = "from_a", output = "from_b", params = default_first_last_params("from_b"))
  expect_warning(expect_false(shiny::isolate(store_set_task(store, cycle))), "Circular")
  expect_null(shiny::isolate(store$tasks$b))
  expect_true("from_a" %in% shiny::isolate(store_available_tables(store)))
  expect_identical(shiny::isolate(store$flows)[[first]]$tasks$a$output, "from_a")
})

test_that("task-status dependencies invalidate and draw edges for sink tasks", {
  store <- new_test_store(list(raw = data.frame(x = 1:3)))
  directory <- tempfile("sink_"); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  p <- default_export_params(); p$source <- "raw"; p$dir <- directory; p$filename <- "data"; p$overwrite <- TRUE
  task <- task_def("sink", "export", inputs = "raw", output = "", params = p)
  shiny::isolate(store_set_task(store, task))
  gate <- default_branch_params("gate")
  gate$paths[[1]]$condition$rules <- list(list(kind = "task_status", task_id = "sink", status = "success"))
  task <- task_def("gate", "branch", output = "", params = gate); task$outputs <- branch_output_specs(gate)
  shiny::isolate(store_set_task(store, task))
  expect_true(shiny::isolate(run_task_from_store(store, "sink")))
  expect_true(shiny::isolate(run_task_from_store(store, "gate")))
  network <- shiny::isolate(canvas_build_network(store))
  expect_true(any(network$edges$from == "sink" & network$edges$to == "gate"))
  store_add_table(store, "raw", data.frame(x = 4:6))
  expect_true(shiny::isolate(store$tasks$gate$invalidated))
  expect_identical(shiny::isolate(store$tasks$gate$status), "pending")
  expect_null(shiny::isolate(store$tasks$gate$branch_decision))
})

test_that("two enabled outputs of one analytical task cannot share a name", {
  p <- default_phase3_params("linear_regression", "same")
  p$output_enabled$glance <- TRUE; p$output_names$glance <- "same"
  store <- new_test_store()
  task <- store_task_from_params(task_def("fit", "linear_regression"), p)
  expect_warning(expect_false(shiny::isolate(store_set_task(store, task))), "within a task")
})
