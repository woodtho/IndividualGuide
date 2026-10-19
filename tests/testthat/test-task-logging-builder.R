log_rule <- function(id, event, level, template, enabled = TRUE) {
  list(id = id, event = event, level = level, template = template, enabled = enabled)
}

test_that("all task types have useful lifecycle and condition defaults", {
  for (entry in TASK_REGISTRY) {
    task <- task_def("example", entry$id)
    rules <- ig_logging_rules(task$logging, entry$id)
    expect_true(all(c("start", "success", "warning", "error", "skipped", "message", "console", "custom") %in%
      vapply(rules, `[[`, character(1), "event")), info = entry$id)
    expect_true(all(ig_log_levels() %in% vapply(rules, `[[`, character(1), "level")), info = entry$id)
    expect_true(all(nzchar(vapply(rules, `[[`, character(1), "template"))), info = entry$id)
    expect_identical(task$logging$min_level, "INFO")
  }
  expect_match(ig_logging_defaults("import_data")$success_message, "imported.*rows")
  expect_match(ig_logging_defaults("filter_sort")$success_message, "input rows.*rows")
  expect_match(ig_logging_defaults("export")$success_message, "destination", fixed = TRUE)
  expect_false(identical(ig_logging_defaults("pca")$success_message, ig_logging_defaults("regression")$success_message))
})

test_that("custom rules route levels, repeat events, interpolate details and retain literals", {
  store <- new_test_store(list(raw = data.frame(x = 1:8)))
  p <- default_first_last_params("picked"); p$input_table <- "raw"; p$n <- 3L
  task <- store_task_from_params(task_def("choose", "first_last_n"), p)
  task$label <- "Choose rows"
  task$logging$rules <- list(
    log_rule("begin", "start", "DEBUG", "{task_name} reads {inputs}: {rows_in} x {columns_in}"),
    log_rule("done", "success", "WARN", "{task}/{type}/{status}: {rows_out} x {columns_out} -> {outputs}"),
    log_rule("again", "success", "ERROR", "Duration {elapsed}; {not_a_field}; {task_name}"),
    log_rule("off", "success", "INFO", "never", FALSE))
  shiny::isolate(store_set_task(store, task))
  expect_true(shiny::isolate(run_task_from_store(store, "choose")))
  data <- shiny::isolate(ig_log_records(store$tasks))
  expect_identical(data$level, c("WARN", "ERROR"))
  expect_identical(data$message[[1L]], "choose/first_last_n/success: 3 x 1 -> picked")
  expect_match(data$message[[2L]], "Duration [0-9.]+; \\{not_a_field\\}; Choose rows")
  expect_identical(ig_log_template("{task_name} {task}", list(task_name = "literal {task}", task_id = "id"), "success"), "literal {task} id")
  expect_identical(ig_log_template("{message}", list(message = "{system('bad')}"), "error"), "{system('bad')}")
})

test_that("promoted console and custom entries obey rules and thresholds", {
  events <- NULL
  config <- list(min_level = "WARN", rules = list(
    log_rule("console", "console", "WARN", "Output: {message} / {status}"),
    log_rule("script", "custom", "ERROR", "Checkpoint: {message}")))
  ig_capture_task_log(function() { cat("printed\n"); ig_log_event("checkpoint", "DEBUG"); TRUE }, config,
    list(task_id = "test", type = "script"), function(x) events <<- x,
    function(value) list(status = "success"))
  expect_identical(vapply(events, `[[`, character(1), "level"), c("ERROR", "WARN"))
  expect_match(events[[2L]]$message, "Output: printed / success", fixed = TRUE)
  config$console <- FALSE
  ig_capture_task_log(function() { cat("hidden\n"); TRUE }, config,
    list(task_id = "test", type = "script"), function(x) events <<- x,
    function(value) list(status = "success"))
  expect_length(events, 0L)
})

test_that("logging uses metadata without collecting lazy tables or exposing credentials", {
  lazy <- structure(list(), class = c("tbl_sql", "tbl"))
  task <- task_def("query", "query_builder", inputs = "database", output = "answer")
  context <- ig_log_context(task, list(database = lazy, answer = data.frame(x = 1:2)))
  expect_identical(context$rows_in, "n/a")
  expect_identical(context$rows_out, "2")
  task <- task_def("import", "import_data", params = list(source_kind = "db", path = "",
    db_table = "customers", db_pwd = "secret password", db_sql = "secret query"))
  context <- ig_log_context(task)
  expect_identical(context$source, "customers")
  expect_false(any(grepl("secret", unlist(context))))
  expect_false(any(grepl("secret", unlist(ig_log_task_spec(task)))))
  task <- task_def("export", "export", params = list(dir = tempdir(), filename = "sample", format = "csv"))
  expect_identical(ig_log_context(task)$destination, file.path(tempdir(), "sample.csv"))
  branch <- task_def("gate", "branch", params = default_branch_params("gate"))
  expect_identical(ig_log_context(branch)$destination, "(not configured)")
  legacy <- task_def("legacy", "script", output = "answer")
  legacy$output <- NULL
  expect_identical(ig_log_context(legacy)$outputs, "answer")
})

test_that("old settings migrate and new rules survive archives, copies and exports", {
  store <- new_test_store()
  task <- task_def("script", "script", params = list(code = "log_event('saved Ω')"))
  task$logging <- list(enabled = TRUE, min_level = "INFO", console = TRUE,
    start_message = "Old start {task}", success_message = "Old finish {status}")
  shiny::isolate(store_set_task(store, task)); shiny::isolate(run_task_from_store(store, "script"))
  expect_true("Old start script" %in% shiny::isolate(ig_log_records(store$tasks))$message)
  task <- shiny::isolate(store$tasks$script)
  task$logging$rules <- list(log_rule("custom", "custom", "WARN", "Custom Ω: {message}"))
  shiny::isolate(store_set_task(store, task)); shiny::isolate(run_task_from_store(store, "script"))
  path <- tempfile(fileext = ".igpx"); on.exit(unlink(path))
  shiny::isolate(project_save(store, path))
  restored <- new_test_store(); shiny::isolate(project_load(restored, path))
  expect_identical(shiny::isolate(restored$tasks$script$logging$rules), task$logging$rules)
  copied <- shiny::isolate(store_copy_flow(restored, restored$active_flow))
  copied_task <- shiny::isolate(restored$flows[[copied]]$tasks)[[1L]]
  expect_identical(copied_task$logging$rules, task$logging$rules)
  expect_length(copied_task$log_events, 0L)
  for (format in c("txt", "csv", "json")) {
    file <- tempfile(fileext = paste0(".", format)); on.exit(unlink(file), add = TRUE)
    value <- shiny::isolate(execute_export_log(list(path = file, format = format, min_level = "WARN"), restored$tasks))
    expect_null(value$error)
    text <- paste(readLines(file, encoding = "UTF-8", warn = FALSE), collapse = "\n")
    expect_match(text, "Custom Ω: saved Ω", fixed = TRUE)
  }
})

test_that("generated pipelines use the same custom messages and dimensions", {
  store <- new_test_store(list(raw = data.frame(x = 1:8)))
  script <- task_def("source", "script", output = "raw", params = list(code = "raw <- data.frame(x = 1:8)",
    output_defs = list(list(name = "raw", kind = "table"))))
  shiny::isolate(store_set_task(store, script))
  p <- default_first_last_params("picked"); p$input_table <- "raw"; p$n <- 3L
  task <- store_task_from_params(task_def("pick", "first_last_n"), p)
  task$logging$rules <- list(log_rule("count", "success", "WARN", "Picked {rows_out} / {rows_in}; {outputs}"))
  shiny::isolate(store_set_task(store, task))
  code <- shiny::isolate(build_full_r_script(store))
  env <- new.env(parent = globalenv()); eval(parse(text = code), env)
  records <- ig_log_records(env$.ig_task_logs$tasks, "pick")
  expect_identical(records$message, "Picked 3 / 8; picked")
  expect_identical(records$level, "WARN")
})

test_that("the builder persists edits without changing results and blocks review edits", {
  store <- new_test_store(list(answer = data.frame(x = 1:2)))
  task <- task_def("one", "script", output = "answer", params = list(code = "1"))
  task$status <- "success"
  task$logging$rules <- list(log_rule("only", "success", "INFO", "Old {task}"))
  shiny::isolate(store_set_task(store, task))
  store$dirty <- FALSE
  shiny::testServer(task_logging_server, args = list(store = store, task_id = "one"), {
    session$setInputs(enabled = TRUE, console = TRUE, min_level = "INFO", preview_event = "success", preview_visible = TRUE,
      only_event = "success", only_level = "INFO", only_template = "Old {task}", only_enabled = TRUE)
    expect_false(shiny::isolate(store$dirty))
    session$setInputs(only_template = "New {outputs}: {rows_out}", only_level = "WARN")
    expect_identical(shiny::isolate(store$tasks$one$logging$rules[[1L]]$template), "New {outputs}: {rows_out}")
    expect_identical(shiny::isolate(store$tasks$one$status), "success")
    expect_identical(shiny::isolate(store$tables$answer), data.frame(x = 1:2))
    expect_match(output$preview, "[WARN] New answer: 2", fixed = TRUE)
    before <- shiny::isolate(store$tasks$one$logging)
    store$review_mode <- TRUE
    session$setInputs(only_template = "Forbidden edit")
    expect_identical(shiny::isolate(store$tasks$one$logging), before)
    session$setInputs(remove_rule = "only")
    expect_identical(shiny::isolate(ids()), "only")
    store$review_mode <- FALSE
    session$setInputs(only_template = "Allowed again")
    expect_identical(shiny::isolate(store$tasks$one$logging$rules[[1L]]$template), "Allowed again")
  })
})
