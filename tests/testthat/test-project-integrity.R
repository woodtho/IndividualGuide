test_that("corrupt payloads and incompatible manifests leave the open project intact", {
  original <- new_test_store(list(keep = data.frame(x = 7)))
  original$project_name <- "Keep this project"
  original$dirty <- TRUE
  before <- shiny::isolate(shiny::reactiveValuesToList(original))
  incoming <- new_test_store(list(incoming = data.frame(x = 9)))
  path <- tempfile(fileext = ".igpx")
  project_save(incoming, path)
  root <- project_unzip(path)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines("not valid JSON", list.files(file.path(root, "tables"), pattern = "\\.json$", full.names = TRUE)[[1L]])
  project_zip_dir(root, path)
  expect_error(project_load(original, path))
  expect_identical(shiny::isolate(shiny::reactiveValuesToList(original)), before)

  project_save(incoming, path)
  root2 <- project_unzip(path)
  on.exit(unlink(root2, recursive = TRUE), add = TRUE)
  manifest_path <- file.path(root2, "manifest.json")
  manifest <- project_read_json(manifest_path)
  manifest$version <- "999.0.0"
  project_write_json(manifest_path, manifest)
  project_zip_dir(root2, path)
  expect_error(project_load(original, path), "version")
  expect_identical(shiny::isolate(shiny::reactiveValuesToList(original)), before)
})

test_that("loading restores empty favourites and clears session execution closures", {
  store <- new_test_store()
  store$task_favourites <- character(0)
  path <- tempfile(fileext = ".igpx")
  project_save(store, path)
  loaded <- new_test_store()
  loaded$run_queue <- "obsolete"
  loaded$run_ids <- "obsolete"
  loaded$task_runners <- list(obsolete = function() stop("old runner"))
  loaded$code_fns <- list(obsolete = function() "old code")
  loaded$branch_tokens <- "old_path"
  project_load(loaded, path)
  expect_length(shiny::isolate(loaded$task_favourites), 0)
  expect_length(shiny::isolate(loaded$run_queue), 0)
  expect_length(shiny::isolate(loaded$run_ids), 0)
  expect_length(shiny::isolate(loaded$task_runners), 0)
  expect_length(shiny::isolate(loaded$code_fns), 0)
  expect_length(shiny::isolate(loaded$branch_tokens), 0)
})

test_that("failed archive creation preserves the previous destination", {
  store <- new_test_store(list(sales = sample_sales()))
  path <- tempfile(fileext = ".igpx")
  project_save(store, path)
  original <- readBin(path, "raw", n = file.info(path)$size)
  testthat::local_mocked_bindings(
    zipr = function(...) stop("simulated disk failure"), .package = "zip")
  expect_error(project_save(store, path), "simulated disk failure")
  expect_identical(readBin(path, "raw", n = file.info(path)$size), original)
})

test_that("relative save paths resolve before archive creation changes directories", {
  path <- paste0("audit-relative-", Sys.getpid(), ".igpx")
  on.exit(unlink(path), add = TRUE)
  project_save(new_test_store(list(x = data.frame(x = 1))), path)
  expect_true(file.exists(path))
  restored <- make_store()
  expect_true(project_load(restored, path)$ok)
  expect_equal(shiny::isolate(restored$tables$x), data.frame(x = 1))
})

test_that("unsafe archive paths are rejected before extraction", {
  testthat::local_mocked_bindings(
    unzip = function(zipfile, list = FALSE, ...) {
      if (list) return(data.frame(Name = "../outside.json", Length = 1))
      stop("extraction must never happen")
    }, .package = "utils")
  expect_error(project_unzip("untrusted.igpx"), "Unsafe archive")
})

test_that("legacy delimited sources honor delimiter and header", {
  path <- tempfile(fileext = ".csv")
  writeLines(c("a;b", "1;2"), path)
  value <- read_by_ext(path, list(csv_delim = ";", csv_header = TRUE))
  expect_equal(names(value), c("a", "b"))
  expect_equal(value$a, 1)
})
