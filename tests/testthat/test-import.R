# Import Data task: validation, file readers, and generated code.

test_that("validate_import_params enforces required fields", {
  base <- default_import_params(output_name = "out")

  p <- base; p$output_name <- ""
  expect_match(validate_import_params(p), "required")

  p <- base; p$output_name <- "not valid!"
  p$path <- tempfile(fileext = ".csv"); writeLines(c("x", "1"), p$path)
  expect_null(validate_import_params(p))

  p <- base; p$path <- ""
  expect_match(validate_import_params(p), "Select a file")

  p <- base; p$path <- "c:/nope/missing.csv"
  expect_match(validate_import_params(p), "does not exist")

  p <- base; p$source_kind <- "db"; p$db_conn_mode <- "code"
  p$db_conn_code <- ""; p$db_use_query <- FALSE; p$db_table <- "x"
  expect_match(validate_import_params(p), "Connection code")

  p$db_conn_code <- "con <- 1"; p$db_table <- ""
  expect_match(validate_import_params(p), "table is required")
})

test_that("execute_import reads csv files with options", {
  csv <- tempfile(fileext = ".csv")
  readr::write_csv(sample_sales(), csv)
  p <- default_import_params("sales_in")
  p$path <- csv; p$type <- "csv"
  res <- execute_import(p)
  expect_null(res$error)
  expect_equal(nrow(res$data), nrow(sample_sales()))
  expect_equal(res$data$region, sample_sales()$region)

  # semicolon delimiter + skip
  csv2 <- tempfile(fileext = ".csv")
  writeLines(c("garbage line", "a;b", "1;2"), csv2)
  p2 <- default_import_params("x")
  p2$path <- csv2; p2$type <- "csv"; p2$csv_delim <- ";"; p2$csv_skip <- 1
  res2 <- execute_import(p2)
  expect_null(res2$error)
  expect_equal(names(res2$data), c("a", "b"))
  expect_equal(res2$data$a, 1)
})

test_that("execute_import reads rds and rda files", {
  rds <- tempfile(fileext = ".rds")
  saveRDS(sample_sales(), rds)
  p <- default_import_params("x"); p$path <- rds; p$type <- "rds"
  expect_equal(nrow(execute_import(p)$data), nrow(sample_sales()))

  rda <- tempfile(fileext = ".rda")
  my_obj <- sample_regions()
  save(my_obj, file = rda)
  p2 <- default_import_params("x"); p2$path <- rda; p2$type <- "rda"
  p2$rda_object <- "my_obj"
  expect_equal(execute_import(p2)$data$manager, sample_regions()$manager)
})

test_that("execute_import reads xlsx files", {
  skip_if_not_installed("writexl")
  xlsx <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(list(Sheet1 = sample_sales()), xlsx)
  p <- default_import_params("x"); p$path <- xlsx; p$type <- "xlsx"
  res <- execute_import(p)
  expect_null(res$error)
  expect_equal(nrow(res$data), nrow(sample_sales()))
})

test_that("execute_import returns an error payload instead of throwing", {
  p <- default_import_params("x")
  p$path <- "c:/definitely/not/here.csv"; p$type <- "csv"
  res <- execute_import(p)
  expect_false(is.null(res$error))
  expect_null(res$data)
})

test_that("build_import_code emits parseable R for each file type", {
  p <- default_import_params("my_out")
  p$path <- "c:/data/file.csv"; p$type <- "csv"
  p$csv_skip <- 2; p$csv_na <- "NA,n/a"
  code <- build_import_code(p)
  expect_no_error(parse(text = code))
  expect_match(code, "readr::read_delim")
  expect_match(code, "skip = 2")
  expect_match(code, 'c\\("NA", "n/a"\\)')

  p$type <- "xlsx"
  expect_match(build_import_code(p), "readxl::read_excel")
  p$type <- "rds"
  expect_match(build_import_code(p), "readRDS")
  p$type <- "sas7bdat"
  expect_match(build_import_code(p), "haven::read_sas")
})

test_that("build_db_import_code never embeds a password", {
  p <- default_import_params("db_out")
  p$source_kind <- "db"; p$db_conn_mode <- "form"; p$db_driver <- "odbc"
  p$db_dsn <- "MyDSN"; p$db_uid <- "user1"; p$db_table <- "tbl"
  p$db_collect <- TRUE
  code <- build_import_code(p)
  expect_match(code, "Sys.getenv", fixed = TRUE)
  expect_no_error(parse(text = code))

  # lazy mode emits dplyr::tbl
  p$db_collect <- FALSE
  expect_match(build_import_code(p), "dplyr::tbl")
})

test_that("import argument helpers behave", {
  expect_equal(split_na("NA, n/a"), c("NA", "n/a"))
  expect_equal(split_na(""), character(0))
  expect_null(set_number(NA))
  expect_equal(set_number(5), 5)
  expect_null(set_bool(NULL))
  expect_true(set_bool(TRUE))
  expect_null(parse_col_select(""))
  expect_equal(parse_col_select("a, b"), c("a", "b"))
  expect_equal(r_chr_vec(c("a", "b")), 'c("a", "b")')
  expect_equal(r_nullable_chr(""), "NULL")
})

test_that("DB round trip works through RSQLite (form mode)", {
  skip_if_not_installed("RSQLite")
  db <- tempfile(fileext = ".sqlite")
  con <- DBI::dbConnect(RSQLite::SQLite(), db)
  DBI::dbWriteTable(con, "sales", sample_sales()[, c("region", "amount", "qty")])
  DBI::dbDisconnect(con)

  p <- default_import_params("db_out")
  p$source_kind <- "db"; p$db_conn_mode <- "form"; p$db_driver <- "sqlite"
  p$db_database <- db; p$db_table <- "sales"; p$db_collect <- TRUE
  res <- execute_import(p)
  expect_null(res$error)
  expect_equal(nrow(res$data), nrow(sample_sales()))

  # lazy mode returns a tbl_sql plus an open connection
  p$db_collect <- FALSE
  lazy <- execute_import(p)
  expect_null(lazy$error)
  expect_true(inherits(lazy$data, "tbl_sql"))
  expect_true(lazy$lazy)
  DBI::dbDisconnect(lazy$con)
})
