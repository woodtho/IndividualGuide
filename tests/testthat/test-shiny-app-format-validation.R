test_that("directories named like entry files never replace a running app", {
  directory <- tempfile("not-an-app-"); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  dir.create(file.path(directory, "app.R"))
  expect_error(ig_shiny_app_path(directory), "needs app.R")
  writeLines("", file.path(directory, "ui.R"))
  dir.create(file.path(directory, "server.R"))
  expect_error(ig_shiny_app_path(directory), "both ui.R and server.R")
})
