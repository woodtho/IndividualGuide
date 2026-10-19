# Scheduling/cancellation unit tests use controllable process handles. The
# two-session browser workload separately runs real R subprocesses end to end.
background_fixture <- function(offset = 0) {
  store <- new_test_store(list(raw = data.frame(x = 1:12 + offset, y = sin(1:12))))
  p <- default_phase3_params("cluster_analysis", "result")
  p$input_table <- "raw"; p$predictors <- c("x", "y"); p$k <- 2L
  shiny::isolate(store_set_task(store, store_task_from_params(task_def("analysis", "cluster_analysis"), p)))
  store
}

background_fake_process <- function(value) {
  process <- new.env(parent = emptyenv())
  process$alive <- TRUE; process$killed <- FALSE; process$value <- value
  process$is_alive <- function() process$alive
  process$get_result <- function() process$value
  process$kill <- function() { process$killed <- TRUE; process$alive <- FALSE; TRUE }
  process
}

background_pump <- function(predicate) {
  deadline <- Sys.time() + 10
  while (!isTRUE(predicate())) {
    if (Sys.time() >= deadline) stop("Background test did not reach its expected state.")
    later::run_now(0.1)
  }
}

test_that("eligibility checks the current input widget before dispatching", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close())
  store <- background_fixture(); store_init_background(store, session)
  tasks <- shiny::isolate(store$tasks)
  tasks$analysis$log_events <- list(list(event = "success", elapsed_seconds = 10))
  store$tasks <- tasks
  expect_true(shiny::isolate(ig_background_eligible(store, "analysis")))
  tables <- shiny::isolate(store$tables); tables$sql <- structure(list(), class = c("tbl_sql", "tbl")); store$tables <- tables
  p <- tasks$analysis$params; p$input_table <- "sql"
  store$params_fns <- list(analysis = function() p)
  expect_false(shiny::isolate(ig_background_eligible(store, "analysis")))
  store$params_fns <- list(analysis = function() NULL)
  expect_false(shiny::isolate(ig_background_eligible(store, "analysis")))
})

test_that("scheduling measurements survive disabled user-facing logging", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close())
  store <- background_fixture(); store_init_background(store, session)
  task <- shiny::isolate(store$tasks$analysis); task$logging$enabled <- FALSE
  shiny::isolate(store_set_task(store, task))
  shiny::isolate(store$settings$background_tasks <- FALSE)
  expect_true(shiny::isolate(run_task_from_store(store, "analysis")))
  cache <- shiny::isolate(store$performance_cache)
  expect_true(is.finite(cache$task_durations$analysis$elapsed))
  expect_length(shiny::isolate(store$tasks$analysis$log_events), 0L)
  cache$task_durations$analysis$elapsed <- 2
  shiny::isolate(store$settings$background_tasks <- TRUE)
  expect_true(shiny::isolate(ig_background_eligible(store, "analysis")))
  cache$task_durations$analysis$elapsed <- 10
  expect_true(shiny::isolate(ig_background_eligible(store, "analysis")))
})

test_that("completed background results use the normal executor and resume the queue", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close())
  store <- background_fixture(); store_init_background(store, session)
  p <- shiny::isolate(store$tasks$analysis$params)
  result <- execute_phase3_task("cluster_analysis", p, shiny::isolate(store$tables))
  process <- background_fake_process(list(result = result, events = list()))
  testthat::local_mocked_bindings(ig_background_process = function(job) process, .package = "IndividualGuide")
  handle <- shiny::isolate(ig_background_start(store, "analysis"))
  expect_s3_class(handle, "ig_async_task")
  expect_identical(shiny::isolate(store$tasks$analysis$status), "running")
  store$run_waiting <- "analysis"; store$run_ids <- "analysis"
  session$flushReact(); background_pump(function() length(.ig_background$active) == 1L)
  process$alive <- FALSE
  background_pump(function() is.null(shiny::isolate(store$background$job)))
  expect_identical(shiny::isolate(store$tables$result), result$data)
  expect_identical(shiny::isolate(store$tasks$analysis$status), "success")
  expect_null(shiny::isolate(store$run_waiting))
  expect_identical(shiny::isolate(store$run_resumed), "analysis")
  expect_equal(shiny::isolate(store$run_task_done_n), 1L)
})

test_that("input edits cancel work and a late callback cannot overwrite new state", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close())
  store <- background_fixture(); store_init_background(store, session)
  process <- background_fake_process(list(result = list(data = data.frame(old = 1)), events = list()))
  testthat::local_mocked_bindings(ig_background_process = function(job) process, .package = "IndividualGuide")
  shiny::isolate(ig_background_start(store, "analysis"))
  job <- shiny::isolate(store$background$job)
  session$flushReact(); background_pump(function() length(.ig_background$active) == 1L)
  store$tables <- list(raw = data.frame(x = 101:112, y = sin(1:12)))
  session$flushReact()
  expect_true(process$killed)
  expect_null(shiny::isolate(store$background$job))
  expect_identical(shiny::isolate(store$tasks$analysis$status), "pending")
  shiny::isolate(ig_background_finish(job, process$value))
  expect_null(shiny::isolate(store$tables$result))
  expect_identical(shiny::isolate(store$tables$raw$x), 101:112)
})

test_that("session end kills its worker and releases global scheduling slots", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new()
  store <- background_fixture(); store_init_background(store, session)
  process <- background_fake_process(list(result = list(data = data.frame(x = 1)), events = list()))
  testthat::local_mocked_bindings(ig_background_process = function(job) process, .package = "IndividualGuide")
  shiny::isolate(ig_background_start(store, "analysis"))
  session$flushReact(); background_pump(function() length(.ig_background$active) == 1L)
  session$close()
  expect_true(process$killed)
  expect_length(.ig_background$active, 0L)
  expect_length(.ig_background$queue, 0L)
  expect_null(shiny::isolate(store$background$job))
})

test_that("worker startup errors become task errors and logged diagnostics", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close())
  store <- background_fixture(); store_init_background(store, session)
  testthat::local_mocked_bindings(ig_background_process = function(job) stop("Cannot start analysis worker"),
    .package = "IndividualGuide")
  shiny::isolate(ig_background_start(store, "analysis"))
  session$flushReact(); background_pump(function() is.null(shiny::isolate(store$background$job)))
  expect_identical(shiny::isolate(store$tasks$analysis$status), "error")
  expect_match(shiny::isolate(store$tasks$analysis$error_msg), "Cannot start analysis worker")
  events <- shiny::isolate(store$tasks$analysis$log_events)
  expect_true(any(vapply(events, function(event) identical(event$level, "ERROR"), logical(1))))
  expect_length(.ig_background$active, 0L)
})

test_that("worker slots are bounded and each session receives its own data", {
  withr::local_options(ig.background_workers = 2L)
  sessions <- lapply(1:3, function(i) shiny::MockShinySession$new())
  on.exit(lapply(sessions, function(session) session$close()))
  stores <- lapply(1:3, function(i) background_fixture(i * 100))
  processes <- list()
  testthat::local_mocked_bindings(ig_background_process = function(job) {
    process <- background_fake_process(list(result = execute_phase3_task(job$type, job$params, job$tables), events = list()))
    processes[[job$id]] <<- process
    process
  }, .package = "IndividualGuide")
  handles <- lapply(1:3, function(i) {
    store_init_background(stores[[i]], sessions[[i]])
    shiny::isolate(ig_background_start(stores[[i]], "analysis"))
  })
  for (session in sessions) session$flushReact()
  background_pump(function() length(.ig_background$active) == 2L)
  expect_length(.ig_background$queue, 1L)
  expect_length(processes, 2L)
  processes[[handles[[1]]$id]]$alive <- FALSE
  background_pump(function() !is.null(processes[[handles[[3]]$id]]))
  expect_length(.ig_background$active, 2L)
  expect_null(shiny::isolate(stores[[2]]$tables$result))
  expect_null(shiny::isolate(stores[[3]]$tables$result))
  expect_true(all(shiny::isolate(stores[[1]]$tables$result$x) > 100))
  expect_true(all(shiny::isolate(stores[[1]]$tables$result$x) < 200))
})

test_that("inactive-flow completion restores the visible flow and updates its owner", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close())
  store <- background_fixture(); store_init_background(store, session)
  p <- shiny::isolate(store$tasks$analysis$params)
  process <- background_fake_process(list(result = execute_phase3_task("cluster_analysis", p,
    shiny::isolate(store$tables)), events = list()))
  testthat::local_mocked_bindings(ig_background_process = function(job) process, .package = "IndividualGuide")
  owner <- shiny::isolate(store$active_flow)
  shiny::isolate(ig_background_start(store, "analysis"))
  session$flushReact(); background_pump(function() length(.ig_background$active) == 1L)
  flow <- make_flow("Other"); flow$id <- "other_flow"
  flows <- shiny::isolate(store$flows); flows[[flow$id]] <- flow; store$flows <- flows
  shiny::isolate(store_activate_flow(store, flow$id))
  session$flushReact(); process$alive <- FALSE
  background_pump(function() is.null(shiny::isolate(store$background$job)))
  expect_identical(shiny::isolate(store$active_flow), "other_flow")
  expect_length(shiny::isolate(store$tasks), 0L)
  expect_identical(shiny::isolate(store$flows[[owner]]$tasks$analysis$status), "success")
  expect_identical(shiny::isolate(store$tables$result), process$value$result$data)
})

test_that("malformed worker responses are errors instead of empty successful runs", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close())
  store <- background_fixture(); store_init_background(store, session)
  process <- background_fake_process(NULL)
  testthat::local_mocked_bindings(ig_background_process = function(job) process, .package = "IndividualGuide")
  shiny::isolate(ig_background_start(store, "analysis"))
  session$flushReact(); background_pump(function() length(.ig_background$active) == 1L)
  process$alive <- FALSE
  background_pump(function() is.null(shiny::isolate(store$background$job)))
  expect_identical(shiny::isolate(store$tasks$analysis$status), "error")
  expect_match(shiny::isolate(store$tasks$analysis$error_msg), "invalid result")
  expect_null(shiny::isolate(store$tables$result))
})

test_that("review changes and deletion cancel registered work, while previews keep results private", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close())
  store <- background_fixture(); store_init_background(store, session)
  processes <- list()
  testthat::local_mocked_bindings(ig_background_process = function(job) {
    process <- background_fake_process(list(result = list(data = data.frame(x = 1)), events = list()))
    processes[[length(processes) + 1L]] <<- process
    process
  }, .package = "IndividualGuide")
  shiny::isolate(ig_background_start(store, "analysis"))
  session$flushReact(); background_pump(function() length(processes) == 1L)
  store$review_mode <- TRUE; session$flushReact()
  expect_true(processes[[1]]$killed)
  expect_null(shiny::isolate(store$background$job))
  preview <- NULL
  shiny::isolate(ig_background_start(store, "analysis", register = FALSE, complete = function(value) preview <<- value))
  session$flushReact(); background_pump(function() length(processes) == 2L)
  processes[[2]]$alive <- FALSE
  background_pump(function() !is.null(preview))
  expect_identical(preview$data, data.frame(x = 1))
  expect_null(shiny::isolate(store$tables$result))
  expect_identical(shiny::isolate(store$tasks$analysis$status), "pending")
  store$review_mode <- FALSE
  shiny::isolate(ig_background_start(store, "analysis"))
  session$flushReact(); background_pump(function() length(processes) == 3L)
  shiny::isolate(store_remove_task(store, "analysis"))
  expect_true(processes[[3]]$killed)
  expect_null(shiny::isolate(store$background$job))
  expect_null(shiny::isolate(store$tasks$analysis))
})

test_that("real child R computes equivalent results and releases its resources", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close())
  store <- background_fixture(); store_init_background(store, session)
  p <- shiny::isolate(store$tasks$analysis$params)
  p$cluster_method <- "hierarchical"
  shiny::isolate(store_set_task(store, store_task_from_params(task_def("analysis", "cluster_analysis"), p)))
  # Old project records can lack the normalized empty control dependency list.
  tasks <- shiny::isolate(store$tasks); tasks$analysis$control_inputs <- NULL
  tasks$analysis$logging$min_level <- "DEBUG"
  tasks$analysis$logging$rules <- list(
    list(id = "worker_begin", event = "start", level = "DEBUG", enabled = TRUE, template = "Worker {task}: {rows_in} input rows"),
    list(id = "worker_done", event = "success", level = "WARN", enabled = TRUE, template = "Worker {task}: {rows_out}/{rows_in} rows"))
  store$tasks <- tasks
  expected <- execute_phase3_task("cluster_analysis", p, shiny::isolate(store$tables))
  shiny::isolate(ig_background_start(store, "analysis"))
  job <- shiny::isolate(store$background$job)
  session$flushReact()
  deadline <- Sys.time() + 90
  while (!is.null(shiny::isolate(store$background$job)) && Sys.time() < deadline) later::run_now(0.1)
  expect_null(shiny::isolate(store$background$job))
  expect_identical(shiny::isolate(store$tasks$analysis$status), "success")
  expect_identical(shiny::isolate(store$tables$result), expected$data)
  expect_false(job$process$is_alive())
  expect_identical(job$process$get_result()$result, expected)
  logs <- shiny::isolate(ig_log_records(store$tasks, "analysis"))
  expect_identical(logs$level, c("DEBUG", "WARN"))
  expect_identical(logs$message, c("Worker analysis: 12 input rows", paste0("Worker analysis: ", nrow(expected$data), "/12 rows")))
  expect_false(any(file.exists(c(job$stdout, job$stderr))))
  expect_length(.ig_background$active, 0L)
  expect_length(.ig_background$queue, 0L)
})

test_that("the application queue waits for background work and applies stop-on-error", {
  withr::local_options(ig.background_workers = 2L)
  for (fail in c(FALSE, TRUE)) {
    process <- NULL
    testthat::local_mocked_bindings(ig_background_process = function(job) {
      value <- if (fail) list(error = "analysis failure") else execute_phase3_task(job$type, job$params, job$tables)
      process <<- background_fake_process(list(result = value, events = list()))
      process
    }, .package = "IndividualGuide")
    shiny::testServer(app_server, {
      session$flushReact()
      store$tables <- list(raw = data.frame(x = 1:12, y = sin(1:12)))
      p <- default_phase3_params("cluster_analysis", "result")
      p$input_table <- "raw"; p$predictors <- c("x", "y"); p$k <- 2L
      task <- store_task_from_params(task_def("analysis", "cluster_analysis"), p)
      task$log_events <- list(list(event = "success", elapsed_seconds = 10))
      store_set_task(store, task)
      store_set_task(store, task_def("following", "script", params = list(code = "1 + 1")))
      settings <- store$settings; settings$stop_on_error <- TRUE; store$settings <- settings
      start_run_queue(c("analysis", "following")); session$flushReact()
      wait_for_test_run(session, function() !is.null(process))
      expect_identical(store$run_waiting, "analysis")
      expect_identical(store$tasks$following$status, "pending")
      store$settings$background_tasks <- FALSE # This fixture controls one mock worker; the following Script is tested synchronously.
      process$alive <- FALSE
      wait_for_test_run(session, function() !length(store$run_ids))
      expect_null(store$run_waiting)
      expect_identical(store$tasks$following$status, if (fail) "skipped" else "success")
      expect_length(store$run_ids, 0L)
    })
  }
})

test_that("project replacement cancels workers only after the new project validates", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close())
  store <- background_fixture(); state <- store_init_background(store, session)
  valid <- tempfile(fileext = ".igpx"); invalid <- tempfile(fileext = ".rds")
  on.exit(unlink(c(valid, invalid)), add = TRUE)
  shiny::isolate(project_save(store, valid)); writeLines("invalid project", invalid)
  process <- background_fake_process(list(result = list(error = "unused"), events = list()))
  testthat::local_mocked_bindings(ig_background_process = function(job) process, .package = "IndividualGuide")
  shiny::isolate(ig_background_start(store, "analysis"))
  session$flushReact(); background_pump(function() length(.ig_background$active) == 1L)
  job <- shiny::isolate(store$background$job)
  expect_error(shiny::isolate(project_load(store, invalid)), "Cannot read legacy project")
  expect_false(process$killed)
  expect_identical(shiny::isolate(store$background$job), job)
  shiny::isolate(project_load(store, valid))
  expect_true(process$killed)
  expect_identical(shiny::isolate(store$background), state)
  expect_null(shiny::isolate(store$background$job))
  expect_length(.ig_background$active, 0L)
})

test_that("real workers preserve model options and the selected random-number generator", {
  withr::local_options(ig.background_workers = 2L)
  withr::local_options(contrasts = c("contr.sum", "contr.poly"), na.action = "na.exclude")
  expect_identical(ig_background_options()$na.action, "na.exclude")
  old_kind <- RNGkind()
  old_seed <- if (exists(".Random.seed", globalenv(), inherits = FALSE)) get(".Random.seed", globalenv()) else NULL
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (is.null(old_seed)) rm(list = intersect(".Random.seed", ls(globalenv(), all.names = TRUE)), envir = globalenv())
    else assign(".Random.seed", old_seed, globalenv())
  }, add = TRUE)
  RNGkind("L'Ecuyer-CMRG")
  tables <- list(raw = data.frame(x = 1:60, y = sin(1:60), group = factor(rep(letters[1:3], 20))))
  for (type in c("linear_regression", "cluster_analysis")) {
    p <- default_phase3_params(type, "result"); p$input_table <- "raw"
    p$response <- "y"; p$predictors <- if (type == "linear_regression") c("x", "group") else c("x", "y")
    p$k <- 3L
    expected <- execute_phase3_task(type, p, tables)
    expect_null(expected$error)
    session <- shiny::MockShinySession$new()
    store <- new_test_store(tables); store_init_background(store, session)
    shiny::isolate(store_set_task(store, store_task_from_params(task_def("analysis", type), p)))
    actual <- NULL
    shiny::isolate(ig_background_start(store, "analysis", register = FALSE, complete = function(result) actual <<- result))
    deadline <- Sys.time() + 90
    while (!is.null(shiny::isolate(store$background$job)) && Sys.time() < deadline) later::run_now(.05)
    expect_null(shiny::isolate(store$background$job))
    expect_null(actual$error)
    expect_identical(actual$data, expected$data)
    session$close()
  }
  session <- shiny::MockShinySession$new(); on.exit(session$close(), add = TRUE)
  store <- background_fixture(); store_init_background(store, session)
  cache <- shiny::isolate(store$performance_cache)
  cache$task_durations <- list(analysis = list(type = "cluster_analysis", elapsed = 10))
  expect_true(shiny::isolate(ig_background_eligible(store, "analysis")))
  withr::local_options(na.action = stats::na.omit)
  expect_false(shiny::isolate(ig_background_eligible(store, "analysis")))
})
