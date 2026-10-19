test_that("headless lazy imports own connections through replacement deletion and load", {
  skip_if_not_installed("RSQLite")
  db <- tempfile(fileext = ".sqlite")
  seed <- DBI::dbConnect(RSQLite::SQLite(), db)
  DBI::dbWriteTable(seed, "data", data.frame(x = 1:3))
  DBI::dbDisconnect(seed)
  store <- new_test_store()
  p <- default_import_params("raw")
  p$source_kind <- "db"
  p$db_driver <- "sqlite"
  p$db_database <- db
  p$db_table <- "data"
  p$db_conn_mode <- "form"
  p$db_collect <- FALSE
  add_test_task(store, "imp", "import_data", output = "raw", params = p)
  expect_true(shiny::isolate(run_task_from_store(store, "imp")))
  first <- dbplyr::remote_con(shiny::isolate(store$tables$raw))
  expect_true(DBI::dbIsValid(first))
  expect_true(shiny::isolate(run_task_from_store(store, "imp")))
  second <- dbplyr::remote_con(shiny::isolate(store$tables$raw))
  expect_false(DBI::dbIsValid(first))
  expect_true(DBI::dbIsValid(second))
  path <- tempfile(fileext = ".igpx")
  project_save(new_test_store(), path)
  project_load(store, path)
  expect_false(DBI::dbIsValid(second))
  add_test_task(store, "imp", "import_data", output = "raw", params = p)
  expect_true(shiny::isolate(run_task_from_store(store, "imp")))
  third <- dbplyr::remote_con(shiny::isolate(store$tables$raw))
  shiny::isolate(store_remove_task(store, "imp"))
  expect_false(DBI::dbIsValid(third))
})

test_that("custom connection code closes con when later code throws", {
  skip_if_not_installed("RSQLite")
  previous <- getOption("ig.audit.failed.connection")
  on.exit(options(ig.audit.failed.connection = previous), add = TRUE)
  p <- default_import_params("raw")
  p$source_kind <- "db"; p$db_conn_mode <- "code"; p$db_table <- "data"
  p$db_conn_code <- paste('con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")',
    'options(ig.audit.failed.connection = con)', 'stop("after connect")', sep = "\n")
  result <- execute_import(p)
  expect_match(result$error, "after connect")
  expect_s4_class(getOption("ig.audit.failed.connection"), "SQLiteConnection")
  expect_false(DBI::dbIsValid(getOption("ig.audit.failed.connection")))
})

test_that("DuckDB custom imports support real lazy queries and owned cleanup", {
  skip_if_not_installed("duckdb")
  path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(c(path, paste0(path, ".wal"))), add = TRUE)
  seed <- DBI::dbConnect(duckdb::duckdb(), dbdir = path)
  DBI::dbWriteTable(seed, "measurements", data.frame(x = 1:3, label = c("a", "b", "c")))
  DBI::dbDisconnect(seed, shutdown = TRUE)
  store <- new_test_store()
  on.exit(shiny::isolate(store_close_connections(store)), add = TRUE)
  p <- default_import_params("raw"); p$source_kind <- "db"; p$db_conn_mode <- "code"
  p$db_conn_code <- sprintf("con <- DBI::dbConnect(duckdb::duckdb(), dbdir = %s, read_only = TRUE)",
    r_val(path, "character"))
  p$db_table <- "measurements"; p$db_collect <- FALSE
  add_test_task(store, "imp", "import_data", params = p)
  expect_true(shiny::isolate(run_task_from_store(store, "imp")))
  first <- dbplyr::remote_con(shiny::isolate(store$tables$raw))
  expect_true(DBI::dbIsValid(first))
  expect_equal(shiny::isolate(store_get_table(store, "raw"))$x, 1:3)
  query <- default_qb_params("selected"); query$primary_table <- "raw"
  expect_equal(execute_query(query, shiny::isolate(store$tables))$data$x, 1:3)
  expect_true(shiny::isolate(run_task_from_store(store, "imp")))
  expect_false(DBI::dbIsValid(first))
  second <- dbplyr::remote_con(shiny::isolate(store$tables$raw))
  shiny::isolate(store_close_connections(store))
  expect_false(DBI::dbIsValid(second))
})

test_that("lazy projects retain their column schema without reconnecting", {
  skip_if_not_installed("RSQLite")
  db <- tempfile(fileext = ".sqlite")
  con <- DBI::dbConnect(RSQLite::SQLite(), db)
  DBI::dbWriteTable(con, "data", data.frame(x = 1:3, group = letters[1:3])); DBI::dbDisconnect(con)
  store <- new_test_store()
  p <- default_import_params("raw")
  p$source_kind <- "db"; p$db_driver <- "sqlite"; p$db_database <- db
  p$db_conn_mode <- "form"; p$db_table <- "data"; p$db_collect <- FALSE
  add_test_task(store, "imp", "import_data", params = p)
  expect_true(shiny::isolate(run_task_from_store(store, "imp")))
  expect_identical(shiny::isolate(store$sources$raw$schema$column), c("x", "group"))
  path <- tempfile(fileext = ".igpx"); project_save(store, path)
  shiny::isolate(store_close_connections(store))
  loaded <- make_store(); project_load(loaded, path)
  expect_false("raw" %in% names(shiny::isolate(loaded$tables)))
  schema <- shiny::isolate(store_col_info(loaded, "raw"))
  expect_identical(schema$column, c("x", "group"))
  expect_identical(schema$class, c("integer", "character"))
  expect_length(shiny::isolate(loaded$db_connections), 0)
})

test_that("failed lazy DB fetch closes its newly opened connection", {
  skip_if_not_installed("RSQLite")
  opened <- NULL
  testthat::local_mocked_bindings(fetch_db_data = function(con, ...) {
    opened <<- con
    stop("missing table")
  })
  p <- default_import_params("raw")
  p$source_kind <- "db"
  p$db_driver <- "sqlite"
  p$db_conn_mode <- "form"
  p$db_database <- ":memory:"
  p$db_table <- "missing"
  p$db_collect <- FALSE
  expect_match(execute_import(p)$error, "missing|table", ignore.case = TRUE)
  expect_s4_class(opened, "SQLiteConnection")
  expect_false(DBI::dbIsValid(opened))
})

test_that("standalone database code closes eager and failed connections", {
  skip_if_not_installed("RSQLite")
  previous <- getOption("ig.audit.generated.connection")
  on.exit(options(ig.audit.generated.connection = previous), add = TRUE)
  p <- default_import_params("raw ' data"); p$source_kind <- "db"
  p$db_conn_mode <- "code"; p$db_table <- "data"; p$db_collect <- TRUE
  p$db_conn_code <- paste('con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")',
    'options(ig.audit.generated.connection = con)',
    'DBI::dbWriteTable(con, "data", data.frame(x = 1:3))', sep = "\n")
  evaluate <- function(params) {
    env <- new.env(parent = globalenv())
    eval(parse(text = build_import_code(params)), envir = env)
    env
  }
  env <- evaluate(p)
  expect_equal(env[[p$output_name]], data.frame(x = 1:3))
  expect_false(DBI::dbIsValid(getOption("ig.audit.generated.connection")))
  p$output_name <- "con"
  expect_equal(evaluate(p)$con, data.frame(x = 1:3))
  expect_false(DBI::dbIsValid(getOption("ig.audit.generated.connection")))
  p$db_collect <- FALSE
  env <- evaluate(p)
  con <- dbplyr::remote_con(env$con)
  expect_true(DBI::dbIsValid(con))
  expect_equal(dplyr::collect(env$con)$x, 1:3)
  DBI::dbDisconnect(con)
  p$db_table <- "missing"
  expect_error(evaluate(p), "missing|table", ignore.case = TRUE)
  expect_false(DBI::dbIsValid(getOption("ig.audit.generated.connection")))
  p$db_conn_code <- paste(p$db_conn_code, 'stop("after connect")', sep = "\n")
  expect_error(evaluate(p), "after connect")
  expect_false(DBI::dbIsValid(getOption("ig.audit.generated.connection")))
})
