product_wait_job <- function(store, timeout = 90) {
  deadline <- Sys.time() + timeout
  while (!is.null(isolate(store$background$job))) {
    if (Sys.time() >= deadline) stop("The real task worker did not finish.")
    later::run_now(.05)
  }
}

test_that("a real background task completes through the Shiny flow queue", {
  withr::local_options(ig.background_workers = 2L, ig.recovery_dir = tempfile(), ig.catalogue_dir = tempfile())
  shiny::testServer(app_server, {
    p <- default_script_params("queued"); p$code <- "queued <- data.frame(value=42)"
    store_set_task(store, store_task_from_params(task_def("queued_script", "script"), p))
    session$rootScope()$flushReact()
    start_run_queue("queued_script")
    deadline <- Sys.time() + 60
    repeat {
      session$rootScope()$flushReact(); later::run_now(.05)
      if (!length(isolate(store$run_ids))) break
      if (Sys.time() > deadline) stop(paste("Queue did not finish:", paste(capture.output(str(isolate(list(state=store_run_state(store),tasks=store$tasks,job=store$background$job)))),collapse="\n")))
    }
    expect_identical(isolate(store$run_outcome), "finished")
    expect_equal(isolate(store$tables$queued$value), 42)
  })
})

test_that("real script workers are reusable, cancellable and isolated", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close(), add = TRUE)
  store <- new_test_store(list(data = data.frame(x = 1:4)))
  store_init_background(store, session)
  p <- default_script_params("result"); p$input_tables <- "data"
  p$code <- "result <- data.frame(total=sum(data$x))"
  isolate(store_set_task(store, store_task_from_params(task_def("script", "script"), p)))
  expect_s3_class(isolate(run_task_from_store(store, "script")), "ig_async_task")
  product_wait_job(store)
  expect_identical(isolate(store$tasks$script$status), "success")
  expect_equal(isolate(store$tables$result$total), 10)
  worker <- isolate(store$background)$worker; pid <- worker$get_pid()
  expect_true(worker$is_alive())
  expect_s3_class(isolate(run_task_from_store(store, "script")), "ig_async_task")
  product_wait_job(store)
  expect_identical(isolate(store$background)$worker$get_pid(), pid)
  expect_equal(length(isolate(store$run_records)), 2)
  expect_true(nzchar(isolate(store$run_records)[[1]]$inputs$data$hash))
  p$code <- "Sys.sleep(60); result <- data.frame(total=999)"
  isolate(store_set_task(store, store_task_from_params(task_def("script", "script"), p)))
  expect_s3_class(isolate(run_task_from_store(store, "script")), "ig_async_task")
  later::run_now(.1)
  expect_true(isolate(store_stop_run(store)))
  worker$wait(5000); expect_false(worker$is_alive())
  expect_null(isolate(store$background$job))
  expect_identical(isolate(utils::tail(store$run_records, 1))[[1]]$status, "stopped")
  expect_false(identical(isolate(store$tables$result$total), 999))
  path <- tempfile(fileext = ".igpx"); project_save(store, path)
  state <- isolate(store$background)
  expect_true(project_load(store, path)$ok)
  expect_identical(isolate(store$background), state)
  expect_true(isolate(ig_background_eligible(store, "script")))
  loaded <- isolate(store$tasks$script); loaded$params$code <- "result <- data.frame(total=25)"
  isolate(store_set_task(store, loaded))
  expect_s3_class(isolate(run_task_from_store(store, "script")), "ig_async_task")
  product_wait_job(store)
  expect_equal(isolate(store$tables$result$total), 25)
})

test_that("file imports and reports use real background dispatch and retain artifacts", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close(), add = TRUE)
  store <- new_test_store(); store_init_background(store, session)
  file <- tempfile(fileext = ".csv"); write.csv(data.frame(x = 1:3), file, row.names = FALSE)
  p <- default_import_params("data"); p$path <- file; p$type <- "csv"
  isolate(store_set_task(store, store_task_from_params(task_def("import", "import_data"), p)))
  expect_s3_class(isolate(run_task_from_store(store, "import")), "ig_async_task")
  product_wait_job(store)
  expect_equal(isolate(store$tables$data$x), 1:3)
  expect_true(nzchar(isolate(store$run_records)[[1]]$inputs$.source_file$hash))
  p <- default_report_params("report"); p$items <- list(list(name = "data", heading = "Actual background data"))
  p$format <- "html"
  isolate(store_set_task(store, store_task_from_params(task_def("report", "report"), p)))
  expect_s3_class(isolate(run_task_from_store(store, "report")), "ig_async_task")
  product_wait_job(store)
  expect_identical(isolate(store$tasks$report$status), "success")
  expect_true(file.exists(isolate(store$tasks$report$outputs[[1]])$path))
})

test_that("loop coordination and iteration bodies execute in one cancellable worker", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close(), add = TRUE)
  store <- new_test_store(list(raw = data.frame(x = 1:3))); store_init_background(store, session)
  p <- default_loop_params("repeat"); p$values <- "2\n3"
  loop <- task_def("repeat", "loop", output = "", params = p); loop$outputs <- loop_output_specs(p)
  isolate(store_set_task(store, loop))
  body <- task_def("calculate", "script", inputs = "raw", output = "scaled",
    params = list(input_tables = "raw", output_name = "scaled",
      code = "scaled <- transform(raw, x=x*as.numeric(item))", output_defs = list(list(name = "scaled", kind = "table"))))
  body$control_inputs <- p$output_token
  isolate(store_set_task(store, body))
  expect_s3_class(isolate(run_task_from_store(store, "repeat")), "ig_async_task")
  product_wait_job(store)
  expect_identical(isolate(store$tasks[["repeat"]]$status), "success")
  expect_equal(isolate(store$tables$calculate_2$x), c(2, 4, 6))
  expect_equal(isolate(store$tables$calculate_3$x), c(3, 6, 9))
  expect_equal(isolate(store$tables$raw$x), 1:3)
  expect_true(length(isolate(store$run_records)) >= 3)
})
