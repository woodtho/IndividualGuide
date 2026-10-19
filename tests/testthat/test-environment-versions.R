test_that("example environment checks compare package versions semantically", {
  testthat::local_mocked_bindings(packageVersion = function(name) {
    if (name == "missing") stop("not installed")
    package_version("2.1.4")
  }, .package = "utils")
  previous <- list(R = as.character(getRversion()), packages = list(example = "2.1-4"))
  expect_length(ig_environment_changes(previous), 0L)
  previous$packages$example <- "2.1.3"
  expect_match(ig_environment_changes(previous), "2.1.3.*2.1.4")
  previous$packages <- list(missing = "1.0.0")
  expect_match(ig_environment_changes(previous), "not installed", fixed = TRUE)
  previous$packages <- list(example = "unrecognized")
  expect_match(ig_environment_changes(previous), "unrecognized", fixed = TRUE)
})
