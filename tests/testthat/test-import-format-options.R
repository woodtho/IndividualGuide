test_that("Stata ignores the SPSS-only missing-value switch", {
  path <- tempfile(fileext = ".dta")
  haven::write_dta(data.frame(x = 1:3), path)
  p <- default_import_params("stata"); p$path <- path; p$haven_user_na <- FALSE
  result <- execute_import(p)
  expect_null(result$error)
  expect_equal(as.numeric(result$data$x), 1:3)
  code <- build_import_code(p)
  expect_false(grepl("user_na", code, fixed = TRUE))
  env <- new.env(parent = globalenv()); eval(parse(text = code), env)
  expect_equal(env$stata, tibble::as_tibble(result$data))
})
