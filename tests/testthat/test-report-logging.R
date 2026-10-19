test_that("reports can include a filtered log snapshot without a data section", {
  testthat::local_mocked_bindings(ig_report_pandoc_available = function() FALSE)
  events <- lapply(c("DEBUG", "INFO", "WARN", "ERROR"), function(level)
    list(time = "2026-10-19T12:00:00Z", level = level, task_id = "source", event = "custom", message = paste(level, "audit <tag>")))
  tasks <- list(source = list(log_events = events), report = list(log_events = list(events[[1]])))
  p <- default_report_params("audit"); p$include_log <- TRUE; p$log_min_level <- "WARN"
  result <- ig_execute_task("report", p, list(), tasks = tasks, task_id = "report")
  expect_null(result$error)
  values <- readRDS(file.path(dirname(result$report_path), "data.rds"))
  expect_equal(values$.ig_pipeline_log$level, c("WARN", "ERROR"))
  html <- paste(readLines(result$report_path), collapse = "\n")
  expect_match(html, "Pipeline execution log", fixed = TRUE)
  expect_match(html, "WARN audit &lt;tag&gt;", fixed = TRUE)
  expect_false(grepl("DEBUG audit", html, fixed = TRUE))
  p$include_log <- FALSE
  expect_match(ig_execute_task("report", p, list(), tasks = tasks)$error, "Add at least one output")
})

test_that("log sections preserve user outputs with internal-looking names and handle empty logs", {
  testthat::local_mocked_bindings(ig_report_pandoc_available = function() FALSE)
  p <- default_report_params(); p$include_log <- TRUE
  p$items <- list(list(name = ".ig_pipeline_log", heading = "My table"))
  result <- execute_report(p, list(.ig_pipeline_log = data.frame(x = 7)))
  expect_null(result$error)
  values <- readRDS(file.path(dirname(result$report_path), "data.rds"))
  expect_equal(values$.ig_pipeline_log$x, 7)
  expect_equal(nrow(values$.ig_pipeline_log_), 0L)
})

test_that("generated pipelines include fresh logs in reports without loading the app", {
  directory <- tempfile("report-log-codegen-"); dir.create(directory)
  withr::local_dir(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  store <- new_test_store()
  p <- default_script_params("observations")
  p$code <- "observations <- data.frame(x=1:3)\nlog_event('AUDIT_SENTINEL', 'WARN')"
  isolate(store_set_task(store, store_task_from_params(task_def("source", "script"), p)))
  p <- default_report_params("audit_report"); p$include_log <- TRUE; p$log_min_level <- "WARN"
  p$items <- list(list(name = "observations", heading = "Observations"))
  isolate(store_set_task(store, store_task_from_params(task_def("report", "report"), p)))
  code <- isolate(build_full_r_script(store))
  script <- file.path(directory, "pipeline.R"); result <- file.path(directory, "result.rds")
  writeLines(c(code, paste0("saveRDS(list(path=audit_report, namespaces=loadedNamespaces()), ", code_literal(result), ")")), script)
  executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  output <- system2(executable, c("--vanilla", shQuote(script)), stdout = TRUE, stderr = TRUE)
  expect_null(attr(output, "status"), info = paste(output, collapse = "\n"))
  expect_true(file.exists(result))
  if (!file.exists(result)) return(invisible(NULL))
  generated <- readRDS(result)
  expect_false("IndividualGuide" %in% generated$namespaces)
  values <- readRDS(file.path(dirname(generated$path), "data.rds"))
  expect_true("AUDIT_SENTINEL" %in% values$.ig_pipeline_log$message)
  expect_true(all(values$.ig_pipeline_log$level %in% c("WARN", "ERROR")))
})

test_that("Report Appearance restores and updates logging settings", {
  store <- new_test_store(list(data = data.frame(x = 1)))
  p <- default_report_params(); p$include_log <- TRUE; p$log_min_level <- "WARN"
  p$items <- list(list(name = "data", heading = "Data"))
  isolate(store_set_task(store, store_task_from_params(task_def("report", "report"), p)))
  shiny::testServer(report_server, args = list(store = store, task_id = "report"), {
    expect_true(isolate(collect_params())$include_log)
    expect_identical(isolate(collect_params())$log_min_level, "WARN")
    session$setInputs(include_log = FALSE, log_min_level = "ERROR")
    expect_false(isolate(collect_params())$include_log)
    expect_identical(isolate(collect_params())$log_min_level, "ERROR")
  })
})

test_that("Word reports include the same audit table", {
  skip_if_not(ig_report_pandoc_available(), "Pandoc not installed")
  p <- default_report_params(); p$format <- "word"; p$include_log <- TRUE
  log <- ig_log_records(list(source = list(log_events = list(list(level = "WARN", message = "WORD_AUDIT_SENTINEL")))))
  result <- execute_report(p, list(), log_records = log)
  expect_null(result$error)
  directory <- tempfile(); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  utils::unzip(result$report_path, files = "word/document.xml", exdir = directory)
  xml <- paste(readLines(file.path(directory, "word/document.xml"), warn = FALSE), collapse = "")
  expect_match(xml, "WORD_AUDIT_SENTINEL", fixed = TRUE)
  expect_match(xml, "Pipeline execution log", fixed = TRUE)
})

test_that("a real background report worker receives the flow's recorded events", {
  withr::local_options(ig.background_workers = 2L)
  session <- shiny::MockShinySession$new(); on.exit(session$close())
  store <- new_test_store(); store_init_background(store, session)
  on.exit(ig_background_cancel(store), add = TRUE)
  p <- default_script_params("data"); p$code <- "data <- data.frame(x=1:3)\nlog_event('WORKER_AUDIT_SENTINEL', 'WARN')"
  isolate(store_set_task(store, store_task_from_params(task_def("source", "script"), p)))
  # Run the source synchronously, then submit only the report to the child.
  withr::with_options(list(ig.background_workers = 0L), expect_true(isolate(run_task_from_store(store, "source"))))
  p <- default_report_params(); p$include_log <- TRUE; p$log_min_level <- "WARN"
  p$items <- list(list(name = "data"))
  isolate(store_set_task(store, store_task_from_params(task_def("report", "report"), p)))
  expect_s3_class(isolate(ig_background_start(store, "report")), "ig_async_task")
  session$flushReact()
  deadline <- Sys.time() + 120
  while (!is.null(isolate(store$background$job)) && Sys.time() < deadline) later::run_now(.1)
  expect_null(isolate(store$background$job))
  expect_identical(isolate(store$tasks$report$status), "success")
  path <- isolate(store$tasks$report$outputs[[1]]$path)
  values <- readRDS(file.path(dirname(path), "data.rds"))
  expect_true("WORKER_AUDIT_SENTINEL" %in% values$.ig_pipeline_log$message)
})
