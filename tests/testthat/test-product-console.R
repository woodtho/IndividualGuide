test_that("completion uses metadata without evaluating active or delayed bindings", {
  session <- shiny::MockShinySession$new(); on.exit(session$close())
  store <- new_test_store(list(raw = data.frame(value = 1:3, check.names = FALSE)))
  state <- ig_console_state(store, session); store$console <- state
  ig_console_submit(state, store, paste(
    "result <- data.frame(total = sum(raw$value))",
    "delayedAssign('deferred', stop('LAZY FORCED'))",
    "makeActiveBinding('active', function() stop('ACTIVE FORCED'), environment())", sep = "\n"))
  deadline <- Sys.time() + 60
  while (!is.null(state$pending) && Sys.time() < deadline) later::run_now(.05)
  expect_null(state$pending); expect_identical(state$status, "Ready")
  expect_false(grepl("FORCED", state$text, fixed = TRUE) && grepl("Error:", state$text, fixed = TRUE))
  expect_true("result" %in% vapply(ig_console_completions("res", store, state), `[[`, character(1), "label"))
  expect_identical(ig_console_completions("result$to", store, state)[[1]]$insert, "result$total")
  expect_identical(ig_console_completions(".project$tables$raw$va", store, state)[[1]]$insert, ".project$tables$raw$value")
  expect_identical(ig_console_completions("system('BAD')$", store, state), list())
  params <- ig_console_script_params("result <- data.frame(total = sum(raw$value))", store)
  expect_identical(params$params$input_tables, "raw")
  expect_identical(params$params$output_defs, list(list(name = "result", kind = "table")))
  task <- store_task_from_params(task_def("from_console", "script"), params$params)
  store_set_task(store, task)
  expect_true(isolate(run_task_from_store(store, task$id)))
  expect_equal(isolate(store$tables$result$total), 6)
  expect_error(ig_console_script_params("if (", store))
  path <- tempfile(fileext = ".igpx"); project_save(store, path)
  expect_true(project_load(store, path)$ok)
  expect_identical(isolate(store$console), state)
  expect_null(state$process)
})

test_that("desktop sessions refuse unauthenticated clients before creating a store", {
  withr::local_envvar(IG_DESKTOP_TOKEN = "private-test-token")
  session <- shiny::MockShinySession$new()
  expect_false(session$isClosed())
  expect_null(suppressWarnings(app_server(NULL, NULL, session)))
  expect_true(session$isClosed())
})
