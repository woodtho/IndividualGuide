test_that("CSV quoted-missing options work with selections, source IDs and generated code", {
  path <- tempfile(fileext = ".csv")
  writeLines(c("label,value,other", '"NA",1,a', 'NA,2,b', '"a""b",3,c', '"",4,d'), path)
  for (quoted in c(TRUE, FALSE)) {
    p <- default_import_params("result ' name")
    p$path <- path; p$type <- "csv"; p$csv_quoted_na <- quoted
    p$csv_col_types <- "cic"; p$csv_col_select <- "label,value"; p$csv_id <- "source file"
    p$csv_escape_backslash <- FALSE; p$csv_escape_double <- TRUE; p$csv_trim_ws <- FALSE
    p$csv_skip_empty_rows <- TRUE; p$csv_lazy <- FALSE
    result <- execute_import(p)
    expect_null(result$error)
    expect_identical(names(result$data), c("source file", "label", "value"))
    expect_identical(result$data$label, if (quoted) c(NA, NA, 'a"b', NA) else c("NA", NA, 'a"b', ""))
    expect_equal(result$data[["source file"]], rep(path, 4))
    env <- new.env(parent = globalenv())
    expect_no_error(eval(parse(text = build_import_code(p)), env))
    expect_equal(as.data.frame(get(p$output_name, env)), result$data)
  }
})

test_that("legacy quoted-NA mode honors explicit header name repair", {
  path <- tempfile(fileext = ".csv")
  writeLines(c('odd name,odd name', '"NA",1', 'x,2'), path)
  p <- default_import_params("out"); p$path <- path; p$type <- "csv"
  p$csv_quoted_na <- FALSE; p$csv_col_types <- "ci"; p$csv_name_repair <- "minimal"
  result <- execute_import(p)
  expect_null(result$error)
  expect_identical(names(result$data), c("odd name", "odd name"))
  expect_identical(result$data[[1]], c("NA", "x"))
  env <- new.env(parent = globalenv())
  eval(parse(text = build_import_code(p)), env)
  expect_equal(as.data.frame(env$out), result$data)
})
