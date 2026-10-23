options_fixture <- function() {
  file <- tempfile("ig-global-options-", fileext = ".rds")
  previous <- options(ig.options.file = file)
  withr::defer({ options(previous); unlink(file) }, envir = parent.frame())
  file
}

test_that("projects inherit live global defaults and only explicit overrides win", {
  options_fixture()
  defaults <- ig_options_empty(); defaults$app$page_length <- 25L
  ig_options_save_global(defaults)
  store <- make_store()
  expect_identical(isolate(store$settings)$page_length, 25L)
  expect_length(isolate(store$option_overrides)$app, 0L)
  ig_options_set(store, "project", "app", "page_length", 50L)
  ig_options_set(store, "global", "app", "page_length", 100L)
  expect_identical(isolate(store$settings)$page_length, 50L)
  other <- make_store()
  expect_identical(isolate(other$settings)$page_length, 100L)
  ig_options_set(store, "project", "app", "page_length", inherit = TRUE)
  expect_identical(isolate(store$settings)$page_length, 100L)
  ig_options_set(store, "global", "app", "run_seed", 19L)
  ig_options_set(store, "project", "app", "run_seed", NULL)
  expect_null(isolate(store$settings)$run_seed)
  expect_true("run_seed" %in% names(isolate(store$option_overrides)$app))
  expect_identical(ig_options_global()$app$run_seed, 19L)
})

test_that("options survive project save without freezing inherited defaults", {
  options_fixture()
  global <- ig_options_empty(); global$app$page_length <- 25L
  ig_options_save_global(global)
  store <- new_test_store()
  value <- ig_options_empty()
  value$app$editor_font_size <- 17L
  value$app["run_seed"] <- list(NULL)
  value$r$myPackage.value <- c(first = 2L, second = 7L)
  value$r$myPackage.function <- ig_options_parse("local({ amount <- 12L; function(x) x + amount })")
  store$option_overrides <- value; ig_options_refresh(store)
  path <- tempfile(fileext = ".igpx"); on.exit(unlink(path), add = TRUE)
  project_save(store, path)
  global$app$page_length <- 75L; ig_options_save_global(global)
  reopened <- make_store(); project_load(reopened, path)
  expect_identical(isolate(reopened$settings)$page_length, 75L)
  expect_identical(isolate(reopened$settings)$editor_font_size, 17L)
  expect_null(isolate(reopened$settings)$run_seed)
  expect_false("page_length" %in% names(isolate(reopened$option_overrides)$app))
  expect_identical(isolate(reopened$option_overrides)$r$myPackage.value, c(first = 2L, second = 7L))
  expect_identical(isolate(reopened$option_overrides)$r$myPackage.function(3L), 15L)
})

test_that("legacy project settings retain explicit NULL values when migrated and resaved", {
  options_fixture()
  path <- tempfile(fileext = ".igpx")
  on.exit(unlink(path), add = TRUE)
  project_save(make_store(), path)
  directory <- project_unzip(path)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  manifest <- project_read_json(file.path(directory, "manifest.json"))
  manifest$options_schema <- NULL
  manifest$version <- "0.5.0"
  project_write_json(file.path(directory, "manifest.json"), manifest)
  project_zip_dir(directory, path)
  migrated <- make_store()
  expect_true(project_load(migrated, path)$ok)
  expect_true("run_seed" %in% names(isolate(migrated$option_overrides)$app))
  expect_null(isolate(migrated$option_overrides)$app$run_seed)
  project_save(migrated, path)
  expect_true(project_load(make_store(), path)$ok)
})

test_that("the catalogue presents every runtime option and the complete bundled reference", {
  options_fixture()
  withr::local_options(list(myPackage.newOption = list(a = 1L)))
  store <- make_store()
  catalogue <- ig_options_catalog(store)
  expect_true(all(names(options()) %in% catalogue$Name[catalogue$Domain == "r"]))
  docs <- jsonlite::read_json(app_sys("options", "r-options.json"))
  expect_gte(length(docs$options), 100L)
  expect_true(all(vapply(docs$options, `[[`, character(1), "name") %in% catalogue$Name))
  expect_true(all(c("error", "warning.expression", "defaultPackages", "PCRE_limit_recursion", "rl_word_breaks") %in% catalogue$Name))
  expect_true("myPackage.newOption" %in% ig_options_catalog(store, "myPackage.newOption")$Name)
  expect_gte(length(unique(catalogue$Category)), 10L)
})

test_that("arbitrary R option names and structured values can be added and inherited", {
  options_fixture()
  store <- make_store()
  value <- list(enabled = TRUE, limits = c(1L, 4L), label = "project")
  ig_options_set(store, "global", "r", "a.package/custom-option", value)
  expect_identical(ig_options_r_values(store)[["a.package/custom-option"]], value)
  ig_options_set(store, "project", "r", "a.package/custom-option", NULL)
  expect_null(ig_options_r_values(store)[["a.package/custom-option"]])
  expect_true("a.package/custom-option" %in% names(ig_options_r_values(store)))
  ig_options_set(store, "project", "r", "a.package/custom-option", inherit = TRUE)
  expect_identical(ig_options_r_values(store)[["a.package/custom-option"]], value)
  expect_error(ig_options_set(store, "global", "r", "digits", -1L), "digits")
  expect_false("digits" %in% names(ig_options_global()$r))
  expect_error(ig_options_parse("1; 2"), "one R expression")
  expect_error(ig_options_parse("new.env()"), "cannot be saved")
  expect_identical(ig_options_parse("c('a', 'b')"), c("a", "b"))
  expect_identical(ig_options_parse("expression(print('message'))"), expression(print("message")))
})

test_that("foreground tasks use their project options and restore the shared R session", {
  options_fixture()
  before <- getOption("digits")
  global <- ig_options_empty(); global$r$digits <- 6L
  ig_options_save_global(global)
  first <- new_test_store(); second <- new_test_store()
  first$option_overrides <- list(schema = 1L, app = list(), r = list(digits = 4L, myPackage.option = "first"))
  second$option_overrides <- list(schema = 1L, app = list(), r = list(digits = 9L, myPackage.option = "second"))
  for (store in list(first, second)) {
    p <- default_script_params("answer")
    p$code <- "answer <- data.frame(digits=getOption('digits'), value=getOption('myPackage.option'))"
    store_set_task(store, store_task_from_params(task_def("script", "script"), p))
    expect_true(isTRUE(isolate(run_task_from_store(store, "script"))))
  }
  expect_equal(isolate(first$tables$answer$digits), 4L)
  expect_equal(isolate(second$tables$answer$digits), 9L)
  expect_identical(isolate(first$tables$answer$value), "first")
  expect_identical(isolate(second$tables$answer$value), "second")
  expect_identical(getOption("digits"), before)
  expect_null(getOption("myPackage.option"))
  expect_identical(tail(isolate(first$run_records), 1L)[[1L]]$r_options$digits, "4L")
})

test_that("generated scripts retain custom functions, values and project precedence", {
  options_fixture()
  store <- new_test_store()
  store$option_overrides <- list(schema = 1L, app = list(), r = list(
    myPackage.function = ig_options_parse("local({ amount <- 5L; function(x) x + amount })"),
    digits = 5L))
  p <- default_script_params("answer"); p$code <- "answer <- data.frame(value=getOption('myPackage.function')(2L), digits=getOption('digits'))"
  store_set_task(store, store_task_from_params(task_def("script", "script"), p))
  script <- build_full_r_script(store)
  withr::local_options(list(myPackage.function = NULL, digits = getOption("digits")))
  environment <- new.env(parent = globalenv())
  eval(parse(text = script), environment)
  expect_identical(environment$answer$value, 7L)
  expect_equal(environment$answer$digits, 5L)
})

test_that("background workers accept all configured option values including functions", {
  options_fixture()
  withr::local_options(ig.background_workers = 1L)
  store <- new_test_store()
  session <- shiny::MockShinySession$new(); on.exit(session$close(), add = TRUE)
  store_init_background(store, session)
  store$option_overrides <- list(schema = 1L, app = list(), r = list(digits = 4L,
    myPackage.function = ig_options_parse("function(x) x * 3L")))
  p <- default_script_params("answer"); p$code <- "answer <- data.frame(value=getOption('myPackage.function')(7L), digits=getOption('digits'))"
  store_set_task(store, store_task_from_params(task_def("script", "script"), p))
  expect_s3_class(isolate(run_task_from_store(store, "script")), "ig_async_task")
  deadline <- Sys.time() + 90
  while (!is.null(isolate(store$background$job)) && Sys.time() < deadline) later::run_now(.05)
  expect_null(isolate(store$background$job))
  expect_identical(isolate(store$tasks$script$status), "success")
  expect_identical(isolate(store$tables$answer$value), 21L)
  expect_equal(isolate(store$tables$answer$digits), 4L)
})

test_that("a reused R console refreshes managed options and restores inherited values", {
  options_fixture()
  global <- ig_options_empty(); global$r$digits <- 6L; ig_options_save_global(global)
  store <- new_test_store()
  store$option_overrides <- list(schema = 1L, app = list(), r = list(digits = 4L))
  session <- shiny::MockShinySession$new(); on.exit(session$close(), add = TRUE)
  state <- ig_console_state(store, session)
  wait <- function() {
    deadline <- Sys.time() + 90
    while (!is.null(state$pending) && Sys.time() < deadline) later::run_now(.05)
    expect_null(state$pending)
  }
  ig_console_submit(state, store, "cat('DIGITS=',getOption('digits'),'\\n',sep='');options(myConsolePackage.option=c('a','b'))"); wait()
  expect_match(state$text, "DIGITS=4", fixed = TRUE)
  expect_identical(isolate(store$r_options_discovered)$myConsolePackage.option$value, c("a", "b"))
  expect_identical(ig_options_catalog(store, "myConsolePackage.option")$Source, "R console session")
  pid <- state$process$get_pid()
  store$option_overrides <- ig_options_empty()
  ig_console_submit(state, store, "cat('INHERITED=',getOption('digits'),'\\n',sep='')"); wait()
  expect_match(state$text, "INHERITED=6", fixed = TRUE)
  expect_identical(state$process$get_pid(), pid)
})

test_that("global R defaults apply to the application runtime while projects remain scoped", {
  options_fixture()
  before <- getOption("digits")
  global <- ig_options_empty(); global$r$digits <- 4L; ig_options_save_global(global)
  store <- make_store()
  shiny::testServer(ig_options_server, args = list(store = store), {
    session$flushReact()
    expect_identical(getOption("digits"), 4L)
    ig_options_set(store, "global", "r", "digits", 5L)
    session$flushReact()
    expect_identical(getOption("digits"), 5L)
    ig_options_set(store, "project", "r", "digits", 9L)
    session$flushReact()
    expect_identical(getOption("digits"), 5L)
    expect_identical(ig_with_options(store, function() getOption("digits")), 9L)
  })
  expect_identical(getOption("digits"), before)
})

test_that("global resets retain the built-in language instead of reimporting a legacy choice", {
  options_fixture()
  global <- ig_options_empty(); global$app$language <- "fr-CA"; global$r$digits <- 4L
  ig_options_save_global(global)
  store <- make_store()
  captured <- new.env(parent = emptyenv())
  shiny::testServer(ig_options_server, args = list(store = store, changed = function(value) captured$value <- value), {
    session$flushReact()
    expect_identical(captured$value$language_global, "fr-CA")
    session$setInputs(scope = "global", reset_scope = 1L)
    expect_length(ig_options_global()$app, 0L)
    expect_length(ig_options_global()$r, 0L)
    expect_true(ig_options_global()$presentation_initialized)
    expect_identical(captured$value$language_global, "en-CA")
  })
})

test_that("the base-only startup loader applies global R options before package imports", {
  file <- options_fixture()
  global <- ig_options_empty(); global$r$myPackage.beforeLoad <- 71L
  ig_options_save_global(global)
  withr::local_options(list(IndividualGuide.options.bootstrapped = NULL, IndividualGuide.options.ignore_saved = NULL,
    IndividualGuide.options.startup_originals = NULL, myPackage.beforeLoad = NULL))
  withr::local_envvar(IG_IGNORE_GLOBAL_OPTIONS = "0")
  environment <- new.env(parent = baseenv())
  sys.source(app_sys("options", "bootstrap.R"), envir = environment)
  environment$ig_options_bootstrap()
  expect_identical(getOption("myPackage.beforeLoad"), 71L)
  expect_true("myPackage.beforeLoad" %in% names(getOption("IndividualGuide.options.startup_originals")))
  expect_null(getOption("IndividualGuide.options.startup_originals")$myPackage.beforeLoad)
})

test_that("default-options recovery can inspect and repair saved settings without applying them", {
  options_fixture()
  global <- ig_options_empty(); global$r$myPackage.paused <- 91L
  ig_options_save_global(global)
  withr::local_options(list(IndividualGuide.options.bootstrapped = NULL, IndividualGuide.options.ignore_saved = NULL,
    IndividualGuide.options.startup_originals = NULL, myPackage.paused = NULL))
  withr::local_envvar(IG_IGNORE_GLOBAL_OPTIONS = "1")
  environment <- new.env(parent = baseenv())
  sys.source(app_sys("options", "bootstrap.R"), envir = environment)
  environment$ig_options_bootstrap()
  expect_true(getOption("IndividualGuide.options.ignore_saved"))
  expect_null(getOption("myPackage.paused"))
  expect_length(ig_options_r_values(make_store()), 0L)
  expect_true("myPackage.paused" %in% ig_options_catalog(make_store())$Name)
})
