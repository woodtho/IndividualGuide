test_that("flow copies remap chained references and reset execution evidence", {
  store <- new_test_store(list(external = data.frame(x = 1:3)))
  p <- default_script_params("source output")
  p$input_tables <- "external"
  p$output_defs <- list(list(name = "source output", kind = "table"),
    list(name = "model output", kind = "object"))
  p$code <- "`source output` <- external; `model output` <- list(x = 1)"
  task <- task_def("source_1", "script", inputs = "external", output = "source output", params = p)
  task$outputs <- lapply(p$output_defs, function(x) c(x, list(label = x$name)))
  task$run_time <- Sys.time()
  task$status <- "success"
  shiny::isolate(store_set_task(store, task))
  add_test_task(store, "consumer_1", "first_last_n", inputs = "source output",
    params = list(input_table = "source output", output_name = "last output", n = 2))
  original <- shiny::isolate(store$tasks)
  copy_id <- store_copy_flow(store, shiny::isolate(store$active_flow))
  copied <- shiny::isolate(store$flows)[[copy_id]]
  producer <- copied$tasks[[1]]
  consumer <- copied$tasks[[2]]
  expect_false(any(task_output_names(producer) %in% task_output_names(original[[1]])))
  expect_equal(consumer$inputs, producer$output)
  expect_equal(consumer$params$input_table, producer$output)
  expect_equal(producer$params$output_defs[[1]]$name, producer$output)
  expect_match(producer$params$code, producer$output, fixed = TRUE)
  expect_null(producer$run_time)
  expect_equal(producer$status, "pending")
  expect_identical(shiny::isolate(store$tasks), original)
  store_activate_flow(store, copy_id)
  expect_true(run_task_from_store(store, producer$id))
  expect_true(run_task_from_store(store, consumer$id))
  expect_equal(nrow(shiny::isolate(store$tables)[[consumer$output]]), 2)
  expect_false("source output" %in% names(shiny::isolate(store$tables)))
})

test_that("copied branch tokens and task-status references belong to the copy", {
  store <- new_test_store()
  add_test_task(store, "producer", "script", params = list(output_name = "data"))
  p <- default_branch_params("gate")
  p$paths[[1]]$condition$rules <- list(list(kind = "task_status", task_id = "producer", status = "success"))
  branch <- task_def("gate", "branch", inputs = "data", output = "", params = p)
  branch$outputs <- branch_output_specs(p)
  shiny::isolate(store_set_task(store, branch))
  child <- task_def("child", "first_last_n", inputs = "data", output = "result")
  child$control_inputs <- "gate_true"
  shiny::isolate(store_set_task(store, child))
  copy_id <- store_copy_flow(store, shiny::isolate(store$active_flow))
  copied <- shiny::isolate(store$flows)[[copy_id]]
  new_branch <- copied$tasks[[2]]
  expect_equal(new_branch$params$paths[[1]]$condition$rules[[1]]$task_id, copied$tasks[[1]]$id)
  expect_equal(copied$tasks[[3]]$control_inputs, new_branch$params$paths[[1]]$token)
  expect_true(new_branch$params$paths[[1]]$token %in% copied$tasks[[3]]$inputs)
  expect_null(store_dependency_problem(copied$tasks, copied$task_order))
})
