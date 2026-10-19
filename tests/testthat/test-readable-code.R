test_that("pipeline indentation preserves multiline user literals", {
  script <- paste0('text <- "first\n  second\nlast"\n',
    'raw <- r"(alpha\n beta\ngamma)"\n',
    '`a\nb` <- 7\nanswer <- list(text, raw, get("a\\nb"))')
  before <- new.env(); after <- new.env()
  eval(parse(text = script), before)
  eval(parse(text = paste(code_indent_lines(script, 4L), collapse = "\n")), after)
  expect_identical(after$answer, before$answer)
  expect_match(code_indent_lines("x <- 1", 4L), "^    x <- 1$")
})

test_that("namespace aliases preserve strings comments pipes and field names", {
  source <- paste0('# .ig_codegen stays in comments\n',
    'x <- .ig_codegen$calculate(".ig_codegen", r"(C:\\data\\.ig_codegen)")\n',
    'y <- x |> identity()')
  renamed <- code_use_namespace(source, ".pipeline")
  expect_match(renamed, '.pipeline$calculate', fixed = TRUE)
  expect_match(renamed, '# .ig_codegen stays in comments', fixed = TRUE)
  expect_match(renamed, '".ig_codegen"', fixed = TRUE)
  expect_match(renamed, 'r"(C:\\data\\.ig_codegen)"', fixed = TRUE)
  expect_match(renamed, '|> identity()', fixed = TRUE)
  # These expressions must retain their quoted symbols and literal field names.
  guarded <- '.ig_codegen$x; x$.ig_codegen; quote(.ig_codegen)'
  actual <- parse(text = code_use_namespace(guarded, ".pipeline"))
  expect_identical(actual, parse(text = guarded))
  tasks <- list(task_def("script", "script", params = list(code = ".pipeline <- 42")),
    task_def("output", "script", output = ".pipeline_export"))
  expect_identical(code_runtime_name(tasks), ".pipeline_export_export")
})

test_that("specialization retains data validation and only evaluates constants", {
  fn <- function(type_id, data) {
    if (type_id == "a") {
      if (nrow(data) == 0L) stop("Empty data")
      sum(data$x)
    } else stop("Other calculation")
  }
  body(fn) <- code_prune_type_branches(body(fn), list(type_id = "a"))
  expect_equal(fn("a", data.frame(x = 1:3)), 6)
  expect_error(fn("a", data.frame(x = numeric(0))), "Empty data")
  expect_false("type_id" %in% all.names(body(fn)))
  expect_false(code_static_value(quote(stop("must not run")), list())$known)
  arm <- quote(switch(type_id, a = , b = 7, c = 9))
  expect_identical(code_prune_type_branches(arm, list(type_id = "a")), 7)
})

test_that("compact settings preserve required defaults and partial matching guards", {
  fn <- function(settings) list(settings$y %||% "", settings$y_label %||% "Label", settings$enabled)
  settings <- list(y = NULL, y_label = "Label", enabled = TRUE, unused = "extra")
  compact <- code_backend_parameters(settings, "example", list(example = fn))
  expect_true("y" %in% names(compact))
  expect_identical(compact$enabled, TRUE)
  expect_false("unused" %in% names(compact))
  expect_identical(fn(compact), fn(settings))
  simple <- function(settings) settings$threshold %||% 5
  expect_identical(code_backend_parameters(list(threshold = 5), "simple", list(simple = simple)), list())
  dynamic <- function(settings) settings[[paste0("threshold")]]
  expect_identical(code_backend_parameters(settings, "dynamic", list(dynamic = dynamic)), settings)
})

test_that("bundle exports contain a readable pipeline and shared support once", {
  store <- new_test_store()
  p <- default_script_params("raw"); p$code <- "raw <- datasets::mtcars"
  p$output_defs <- list(list(name = "raw", kind = "table"))
  add_test_task(store, "source", "script", params = p)
  p <- default_summary_stats_params("summary"); p$input_table <- "raw"; p$cols <- "mpg"
  add_test_task(store, "summary", "summary_stats", inputs = "raw", params = p)
  previous <- getOption("IndividualGuide.codegen_helpers")
  script <- build_full_r_script(store)
  expect_identical(getOption("IndividualGuide.codegen_helpers"), previous)
  expect_identical(build_full_r_script(store), script)
  parts <- code_pipeline_files(script)
  expect_match(parts$pipeline, "summary <- .pipeline$summarise_numeric_columns", fixed = TRUE)
  expect_false(grepl("ig_capture_task_log <-", parts$pipeline, fixed = TRUE))
  expect_equal(length(gregexpr("ig_capture_task_log <-", script, fixed = TRUE)[[1L]]), 1L)
  expect_lt(nchar(parts$pipeline), nchar(parts$support))
  archive <- tempfile(fileext = ".zip")
  on.exit(unlink(archive), add = TRUE)
  ig_write_code_bundle(script, archive)
  expect_setequal(zip::zip_list(archive)$filename, c("pipeline.R", "pipeline_support.R", "README.txt"))
})

test_that("code views refresh when execution settings change", {
  store <- new_test_store()
  settings <- shiny::isolate(store$settings); settings$stop_on_error <- FALSE
  store$settings <- settings
  shiny::testServer(code_panel_server, args = list(store = store), {
    session$setInputs(view = "complete")
    expect_match(output$code_display, ".ig_stop_on_error <- FALSE", fixed = TRUE)
    settings$stop_on_error <- TRUE; store$settings <- settings
    session$flushReact()
    expect_match(output$code_display, ".ig_stop_on_error <- TRUE", fixed = TRUE)
  })
})

test_that("dynamic sampling helpers do not replace the loop runtime", {
  store <- new_test_store()
  p <- default_script_params("raw_a"); p$code <- "raw_a <- datasets::mtcars; raw_b <- head(raw_a, 10)"
  p$output_defs <- list(list(name = "raw_a", kind = "table"), list(name = "raw_b", kind = "table"))
  add_test_task(store, "source", "script", params = p)
  p <- default_loop_params("repeat"); p$values <- "raw_a\nraw_b"
  loop <- task_def("repeat", "loop", output = "", params = p); loop$outputs <- loop_output_specs(p)
  shiny::isolate(store_set_task(store, loop))
  p <- default_random_sample_params("sampled"); p$input_table <- "{item}"; p$n <- 2L; p$seed <- 17L
  task <- store_task_from_params(task_def("sample", "random_sample"), p)
  task$control_inputs <- loop$params$output_token
  shiny::isolate(store_set_task(store, task))
  expected <- new.env(parent = globalenv())
  code <- shiny::isolate(build_full_r_script(store))
  eval(parse(text = code), expected)
  expect_true(all(vapply(expected$.task_status, identical, logical(1), "success")))
  expect_equal(nrow(expected$sample_raw_a), 2L)
  expect_equal(nrow(expected$sample_raw_b), 2L)
  actual <- callr::r(function(code) {
    result <- new.env(parent = globalenv()); eval(parse(text = code), result)
    stopifnot(!"IndividualGuide" %in% loadedNamespaces())
    list(first = result$sample_raw_a, second = result$sample_raw_b, status = result$.task_status)
  }, list(code), system_profile = FALSE, user_profile = FALSE)
  expect_equal(actual, list(first = expected$sample_raw_a, second = expected$sample_raw_b, status = expected$.task_status))
  expect_true(shiny::isolate(run_task_from_store(store, "source")))
  expect_true(shiny::isolate(run_task_from_store(store, "repeat")))
  expect_equal(actual$first, shiny::isolate(store$tables$sample_raw_a))
  expect_equal(actual$second, shiny::isolate(store$tables$sample_raw_b))
})
