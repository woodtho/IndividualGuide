test_that("case-distinct R names survive projects on case-insensitive filesystems", {
  store <- new_test_store()
  for (name in c("A", "a")) store_add_table(store, name, data.frame(value = if (name == "A") 1L else 2L))
  shiny::isolate({
    store_add_object(store, "Model", list(value = 10L))
    store_add_object(store, "model", list(value = 20L))
  })
  path <- tempfile(fileext = ".igpx")
  project_save(store, path)
  loaded <- make_store(); project_load(loaded, path)
  expect_setequal(names(shiny::isolate(loaded$tables)), c("A", "a"))
  expect_equal(shiny::isolate(loaded$tables$A$value), 1L)
  expect_equal(shiny::isolate(loaded$tables$a$value), 2L)
  expect_setequal(names(shiny::isolate(loaded$objects)), c("Model", "model"))
  expect_equal(shiny::isolate(loaded$objects$Model$value$value), 10L)
  expect_equal(shiny::isolate(loaded$objects$model$value$value), 20L)
})

test_that("reserved and long names use independent archive entries", {
  names <- c("CON", "NUL", "a/b:c?*", paste(rep("long", 100), collapse = ""))
  store <- new_test_store(setNames(lapply(seq_along(names), function(i) data.frame(value = i)), names))
  path <- tempfile(fileext = ".igpx"); project_save(store, path)
  loaded <- make_store(); project_load(loaded, path)
  expect_setequal(names(shiny::isolate(loaded$tables)), names)
  for (i in seq_along(names)) expect_equal(shiny::isolate(loaded$tables[[names[[i]]]]$value), i)
})

test_that("duplicate payload metadata is rejected without replacing the open project", {
  store <- new_test_store(list(keep = data.frame(x = 7)))
  path <- tempfile(fileext = ".igpx"); project_save(new_test_store(list(a = data.frame(x = 1))), path)
  root <- project_unzip(path); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  file <- list.files(file.path(root, "tables"), full.names = TRUE)[[1L]]
  file.copy(file, file.path(root, "tables", "duplicate.json"))
  project_zip_dir(root, path)
  expect_error(project_load(store, path), "duplicate or invalid dataset")
  expect_equal(shiny::isolate(store$tables$keep$x), 7)
})
