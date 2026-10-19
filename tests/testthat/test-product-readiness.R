test_that("explicit saves retain verified versions without altering RNG", {
  withr::local_options(ig.backup_dir = tempfile())
  store <- new_test_store(list(data = data.frame(x = 1)))
  folder <- tempfile(); dir.create(folder); path <- file.path(folder, "Project.igpx")
  project_save(store, path)
  unpacked <- project_unzip(path); on.exit(unlink(unpacked, recursive = TRUE), add = TRUE)
  expect_identical(project_read_json(file.path(unpacked, "manifest.json"))$version, PROJECT_VERSION)
  before <- unname(tools::md5sum(path))
  set.seed(51); rng <- .Random.seed
  store$tables <- list(data = data.frame(x = 2)); project_save(store, path)
  expect_identical(.Random.seed, rng)
  versions <- project_backup_list(path)
  expect_equal(nrow(versions), 1)
  backup <- file.path(project_backup_directory(path), versions$id[[1]])
  expect_identical(unname(tools::md5sum(backup)), before)
  restored <- make_store(); expect_true(project_load(restored, backup)$ok)
  expect_equal(isolate(restored$tables$data$x), 1)
  isolate(store$settings$backup_versions <- 2L)
  for (i in 3:6) { store$tables <- list(data = data.frame(x = i)); project_save(store, path) }
  expect_equal(nrow(project_backup_list(path)), 2)
  project_save(store, path, update_identity = FALSE)
  expect_equal(nrow(project_backup_list(path)), 2)
})

test_that("portable import files survive moving and resaving the project", {
  withr::local_options(ig.backup_dir = tempfile())
  folder <- tempfile(); dir.create(folder)
  file <- file.path(folder, "measurements.csv"); write.csv(data.frame(x = 1:3), file, row.names = FALSE)
  store <- new_test_store()
  p <- default_import_params("data"); p$path <- file; p$type <- "csv"
  store_set_task(store, store_task_from_params(task_def("import", "import_data"), p))
  path <- file.path(folder, "portable.igpx")
  project_save(store, path, portable = TRUE)
  unlink(file)
  moved <- tempfile(fileext = ".igpx"); file.copy(path, moved)
  restored <- make_store(); on.exit(project_release_assets(restored), add = TRUE)
  expect_true(project_load(restored, moved)$ok)
  isolate({
    restored_file <- restored$tasks$import$params$path
    expect_true(file.exists(restored_file)); expect_true(startsWith(restored_file, restored$project_assets))
    expect_true(run_task_from_store(restored, "import"))
    expect_equal(restored$tables$data$x, 1:3)
  })
  saved <- tempfile(fileext = ".igpx"); project_save(restored, saved)
  another <- make_store(); on.exit(project_release_assets(another), add = TRUE)
  expect_true(project_load(another, saved)$ok)
  expect_true(file.exists(isolate(another$tasks$import$params$path)))
  expect_true(isolate(ig_project_files(another)$bundled[[1]]))
})

test_that("preflight sees all static errors and accepts future producer columns", {
  store <- new_test_store(list(data = data.frame(x = 1:3)))
  p <- default_import_params("raw"); p$path <- file.path(tempdir(), "absent-product-file.csv")
  store_set_task(store, store_task_from_params(task_def("import", "import_data"), p))
  p <- default_summary_stats_params("summary"); p$input_table <- "data"; p$cols <- "absent"
  store_set_task(store, store_task_from_params(task_def("summary", "summary_stats"), p))
  result <- isolate(ig_preflight(store))
  expect_true(any(result$task == "import" & result$severity == "error" & result$field == "path"))
  expect_true(any(result$task == "summary" & result$severity == "error" & result$field == "cols"))
  p$input_table <- "raw"; p$cols <- "new_column"
  store_set_task(store, store_task_from_params(task_def("summary", "summary_stats"), p))
  result <- isolate(ig_preflight(store))
  expect_false(any(result$task == "summary" & result$severity == "error"))
  expect_true(any(result$task == "summary" & result$field == "schema"))
  isolate({ store$tasks$import$status <- "success"; store$tables$raw <- data.frame(old_column = 1) })
  expect_false(any(isolate(ig_preflight(store))$severity == "error" & isolate(ig_preflight(store))$task == "summary"))
  script <- default_script_params("generated"); script$code <- "generated <- data.frame(x = 1)"
  script$input_table <- character()
  store_set_task(store, store_task_from_params(task_def("script", "script"), script))
  expect_no_error(isolate(ig_preflight(store)))
})

test_that("run records preserve input identity, environment and optional random seeds", {
  store <- new_test_store(list(data = data.frame(x = 1:6)))
  p <- default_script_params("result"); p$code <- "result <- data.frame(x = runif(3))"; p$input_tables <- "data"
  store_set_task(store, store_task_from_params(task_def("script", "script"), p))
  isolate(store$settings$run_seed <- 123L)
  set.seed(47); before <- .Random.seed
  expect_true(isolate(run_task_from_store(store, "script")))
  first <- isolate(store$tables$result)
  expect_identical(.Random.seed, before)
  expect_true(isolate(run_task_from_store(store, "script")))
  expect_identical(isolate(store$tables$result), first)
  records <- isolate(store$run_records)
  expect_length(records, 2); expect_identical(records[[1]]$inputs$data$hash, records[[2]]$inputs$data$hash)
  expect_equal(records[[1]]$seed, 123); expect_equal(records[[1]]$status, "success")
  expect_true(nzchar(records[[1]]$environment$R)); expect_true(nzchar(records[[1]]$outputs$result$hash))
  path <- tempfile(fileext = ".igpx"); project_save(store, path)
  restored <- make_store(); expect_true(project_load(restored, path)$ok)
  expect_equal(isolate(restored$run_records), records)
})

test_that("project tools handle empty versions and invoke task callbacks in the parent session", {
  shiny::testServer(function(input, output, session) {
    store <- new_test_store()
    add_test_task(store, "target", "script", params = default_script_params("result"))
    invoked <- new.env(parent = emptyenv())
    tools <- project_tools_server("tools", store, function(path) FALSE,
      function(id) { invoked$id <- id; invoked$namespace <- shiny::getDefaultReactiveDomain()$ns("") },
      function(id, path) TRUE, function() "dark")
  }, {
    expect_no_error(isolate(tools$show()))
    session$setInputs(`tools-open_task` = "target")
    session$flushReact()
    expect_identical(invoked$id, "target")
    expect_identical(invoked$namespace, session$ns(""))
  })
})

test_that("restoring a saved version resolves relative imports beside the original project", {
  withr::local_options(ig.backup_dir = tempfile())
  folder <- tempfile(); dir.create(folder)
  file <- file.path(folder, "input.csv"); write.csv(data.frame(x = 1:2), file, row.names = FALSE)
  path <- file.path(folder, "relative.igpx")
  store <- new_test_store(); p <- default_import_params("raw"); p$path <- file
  add_test_task(store, "import", "import_data", params = p)
  project_save(store, path); project_save(store, path)
  backup <- file.path(project_backup_directory(path), project_backup_list(path)$id[[1]])
  restored <- make_store()
  expect_true(project_load(restored, backup, source_path = path)$ok)
  expect_identical(normalizePath(isolate(restored$tasks$import$params$path)), normalizePath(file))
  expect_true(isolate(run_task_from_store(restored, "import")))
})

test_that("portable exports relocate and reopening preserves newer output files", {
  withr::local_envvar(IG_USER_DATA = tempfile())
  folder <- tempfile(); dir.create(folder)
  store <- new_test_store(list(raw = data.frame(x = 1:3)))
  p <- default_export_params(); p$source <- "raw"; p$dir <- folder; p$filename <- "result"; p$overwrite <- TRUE
  add_test_task(store, "export", "export", inputs = "raw", params = p)
  expect_true(isolate(run_task_from_store(store, "export")))
  source <- isolate(store$tasks$export$export_file)
  record <- tail(isolate(store$run_records),1)[[1]]
  expect_identical(record$files[[1]]$sha256, digest::digest(file = source, algo = "sha256"))
  path <- file.path(folder, "portable.igpx"); project_save(store, path, portable = TRUE)
  unlink(source)
  restored <- make_store(); expect_true(project_load(restored, path)$ok)
  destination <- isolate(restored$tasks$export$export_file)
  expect_true(file.exists(destination)); expect_false(identical(destination, source))
  writeLines("newer output", destination)
  again <- make_store(); expect_true(project_load(again, path)$ok)
  expect_identical(readLines(destination), "newer output")
  expect_true(isolate(run_task_from_store(restored, "export")))
  expect_match(readLines(destination)[1], "x")
})

test_that("single-file and bundled code honor project seeds for every task", {
  store <- new_test_store()
  for (id in c("first", "second")) {
    p <- default_script_params(id)
    p$code <- paste0(id, " <- data.frame(value=runif(4))")
    add_test_task(store, id, "script", params = p)
  }
  isolate(store$settings$run_seed <- 91L)
  expect_true(isolate(run_task_from_store(store, "first")))
  expect_true(isolate(run_task_from_store(store, "second")))
  expected <- isolate(store$tables)
  script <- build_full_r_script(store)
  parts <- code_pipeline_files(script)
  # The existing export header deliberately selects RNGkind. Task execution
  # must preserve the caller state established by that header.
  set.seed(51); prepared <- new.env(parent = globalenv())
  eval(parse(text = parts$support), prepared); previous <- .Random.seed
  set.seed(51)
  target <- new.env(parent = globalenv())
  eval(parse(text = script), target)
  expect_equal(target$first, expected$first); expect_equal(target$second, expected$second)
  expect_identical(.Random.seed, previous)
  split <- new.env(parent = globalenv()); eval(parse(text = parts$support), split)
  eval(parse(text = paste(strsplit(parts$pipeline, "# Pipeline ----", fixed = TRUE)[[1]][-1], collapse = "# Pipeline ----")), split)
  expect_equal(split$first, expected$first); expect_equal(split$second, expected$second)
})
