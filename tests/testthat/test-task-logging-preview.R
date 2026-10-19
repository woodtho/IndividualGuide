test_that("preview file formatting matches every exported format including empty and Unicode logs", {
  data <- ig_log_example_records()
  data$message[[2L]] <- "A quoted \"value\", a new\nline and Ω"
  for (empty in c(FALSE, TRUE)) for (format in c("txt", "csv", "json")) {
    rows <- if (empty) data[FALSE, ] else data
    path <- tempfile(); on.exit(unlink(path), add = TRUE)
    ig_write_log(rows, list(path = path, format = format))
    expect_identical(readLines(path, encoding = "UTF-8", warn = FALSE), ig_log_file_lines(rows, format))
    expect_identical(paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n"), ig_log_preview_text(rows, format))
    if (format == "csv") expect_equal(nrow(utils::read.csv(path)), nrow(rows))
    if (format == "json") expect_length(jsonlite::read_json(path), nrow(rows))
  }
})

test_that("message input values and rendered previews use the actual rule engine", {
  task <- task_def("pick", "first_last_n", inputs = "raw", output = "picked")
  task$logging$rules <- list(list(id = "done", enabled = TRUE, event = "success", level = "WARN",
    template = "{task}: {rows_in} -> {rows_out} in {elapsed}s"))
  tables <- list(raw = data.frame(x = 1:9), picked = data.frame(x = 1:3))
  actual <- ig_log_preview_scenario(task$logging, task, tables, elapsed = 2.5)
  expect_identical(actual$values$rows_in, "9")
  expect_identical(actual$entries$message, "pick: 9 -> 3 in 2.5s")
  expect_identical(actual$entries$level, "WARN")
  expect_false(grepl('"_row"', ig_log_preview_text(actual$entries, "json"), fixed = TRUE))
  example <- ig_log_preview_scenario(task$logging, task, tables, example = TRUE,
    example_rows_in = 100, example_rows_out = 20, elapsed = 1.5)
  expect_identical(example$entries$message, "pick: 100 -> 20 in 1.5s")
  expect_identical(example$values$inputs, "raw")
  expect_true(example$example)
  task$logging$min_level <- "ERROR"
  expect_equal(nrow(ig_log_preview_scenario(task$logging, task, tables)$entries), 0L)
  task$logging$enabled <- FALSE
  expect_false(ig_log_preview_scenario(task$logging, task, tables)$enabled)
})

test_that("previews are bounded and retain the same first chronological records", {
  data <- ig_log_example_records()
  records <- lapply(seq_len(nrow(data)), function(i) as.list(data[i, ]))
  tasks <- list(a = list(log_events = records), b = list(log_events = rev(records)))
  all <- ig_log_records(tasks)
  expect_identical(ig_log_records(tasks, limit = 2L), all[1:2, , drop = FALSE])
  expect_lte(nchar(ig_log_preview_text(data, max_chars = 30L)), 60L)
  expect_match(ig_log_preview_text(data, max_chars = 30L), "preview truncated", fixed = TRUE)
})

test_that("preview-only changes do not save example values or dirty a project", {
  store <- new_test_store(list(answer = data.frame(x = 1:2)))
  task <- task_def("one", "script", output = "answer", params = list(code = "1"))
  task$logging$rules <- list(list(id = "only", enabled = TRUE, event = "success", level = "INFO", template = "Rows {rows_out}"))
  shiny::isolate(store_set_task(store, task)); store$dirty <- FALSE
  shiny::testServer(task_logging_server, args = list(store = store, task_id = "one"), {
    session$setInputs(enabled = TRUE, console = TRUE, min_level = "INFO", preview_event = "success", preview_visible = TRUE,
      only_event = "success", only_level = "INFO", only_template = "Rows {rows_out}", only_enabled = TRUE)
    before <- shiny::isolate(store$tasks$one)
    session$setInputs(preview_source = "example", preview_rows_in = 90, preview_rows_out = 12, preview_format = "json")
    expect_match(output$preview, "Rows 12", fixed = TRUE)
    expect_identical(jsonlite::fromJSON(output$preview_file)$message, "Rows 12")
    expect_match(output$preview_inputs$html, "Example scenario", fixed = TRUE)
    expect_identical(shiny::isolate(store$tasks$one), before)
    expect_false(shiny::isolate(store$dirty))
    expect_length(shiny::isolate(store$tasks$one$log_events), 0L)
  })
})
