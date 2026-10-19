test_that("registered runners record exceptions and failed returns instead of retaining success", {
  store <- new_test_store()
  task <- add_test_task(store, "a", "script", output = "cached")
  task$run_time <- Sys.time()
  shiny::isolate(store_set_task(store, task))
  store_add_table(store, "cached", data.frame(x = 99))
  store_register_runner(store, "a", function() stop("broken runner"))
  expect_false(shiny::isolate(store$task_runners$a()))
  expect_equal(shiny::isolate(store$tasks$a$status), "error")
  expect_match(shiny::isolate(store$tasks$a$error_msg), "broken runner")
  expect_false("cached" %in% names(shiny::isolate(store$tables)))
  store_register_runner(store, "a", function() FALSE)
  expect_false(shiny::isolate(store$task_runners$a()))
  expect_equal(shiny::isolate(store$tasks$a$status), "error")
})

test_that("failed headless producers retire stale outputs and block consumers", {
  store <- new_test_store()
  add_test_task(store, "a", "script", output = "cached",
    params = list(code = "stop('bad input')", output_name = "cached"))
  add_test_task(store, "b", "first_last_n", inputs = "cached", output = "result",
    params = list(input_table = "cached", output_name = "result", n = 1))
  store_add_table(store, "cached", data.frame(x = 99))
  store_add_table(store, "result", data.frame(x = 99))
  expect_false(shiny::isolate(run_task_from_store(store, "a")))
  expect_false("cached" %in% names(shiny::isolate(store$tables)))
  expect_false("result" %in% names(shiny::isolate(store$tables)))
  expect_false(shiny::isolate(run_task_from_store(store, "b")))
  expect_equal(shiny::isolate(store$tasks$b$status), "skipped")
  expect_null(shiny::isolate(store$tasks$b$error_msg))
  expect_match(shiny::isolate(store$tasks$b$skip_reason), "[Uu]pstream|[Dd]ependency")
})

test_that("changing data invalidates consumers across flows", {
  store <- new_test_store(list(raw = data.frame(x = 1)))
  first <- shiny::isolate(store$active_flow)
  a <- add_test_task(store, "a", "first_last_n", inputs = "raw", output = "a_out",
    params = list(input_table = "raw", output_name = "a_out"))
  expect_true(shiny::isolate(run_task_from_store(store, "a")))
  second <- make_flow("Second")
  flows <- shiny::isolate(store$flows)
  flows[[second$id]] <- second
  store$flows <- flows
  store_activate_flow(store, second$id)
  add_test_task(store, "b", "first_last_n", inputs = "a_out", output = "b_out",
    params = list(input_table = "a_out", output_name = "b_out"))
  expect_true(shiny::isolate(run_task_from_store(store, "b")))
  store_add_table(store, "raw", data.frame(x = 2))
  expect_false(any(c("a_out", "b_out") %in% names(shiny::isolate(store$tables))))
  expect_true(shiny::isolate(store$tasks$b$invalidated))
  expect_true(shiny::isolate(store$flows)[[first]]$tasks$a$invalidated)
})

test_that("configuration changes invalidate old results and running status wins over old time", {
  store <- new_test_store(list(raw = data.frame(x = 1:3)))
  add_test_task(store, "a", "first_last_n", inputs = "raw", output = "result",
    params = list(input_table = "raw", output_name = "result", n = 2))
  expect_true(shiny::isolate(run_task_from_store(store, "a")))
  task <- shiny::isolate(store$tasks$a)
  task$status <- "running"
  shiny::isolate(store_set_task(store, task))
  expect_equal(shiny::isolate(store$tasks$a$status), "running")
  task$params$n <- 1
  task$status <- "success"
  shiny::isolate(store_set_task(store, task))
  expect_true(shiny::isolate(store$tasks$a$invalidated))
  expect_false("result" %in% names(shiny::isolate(store$tables)))
})

test_that("single-output consumers cannot silently share ambiguous producers", {
  store <- new_test_store()
  add_test_task(store, "a", "script", output = "same")
  expect_warning(ok <- shiny::isolate(store_set_task(store,
    task_def("b", "script", output = "same"))), "[Oo]utput.*same|[Ss]ame.*output")
  expect_false(ok)
  expect_false("b" %in% names(shiny::isolate(store$tasks)))
})
test_that("editing an unrun task stays pending while actual failures outrank stale visuals", {
  store <- new_test_store(list(raw = data.frame(x = 1:3)))
  p <- default_first_last_params("rows"); p$input_table <- "raw"
  add_test_task(store, "head", "first_last_n", inputs = "raw", params = p)
  p$n <- 2L
  shiny::isolate(store_sync_parameters(store, "head", p))
  expect_false(isTRUE(shiny::isolate(store$tasks$head$invalidated)))
  expect_identical(shiny::isolate(store$tasks$head$status), "pending")
  expect_identical(ig_status_display("error", TRUE, "grey")$text, "✗ Error")
  expect_identical(ig_status_display("running", TRUE, "grey")$text, "↻ Running")
  expect_identical(ig_status_display("pending", TRUE, "grey")$text, "⚠ Stale")
})
