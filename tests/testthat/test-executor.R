# run_task_from_store: the Run Flow path that executes tasks from saved params
# without their panels ever having been opened. Runs headless (no session).

iso <- shiny::isolate

test_that("run_task_from_store executes a data task and stores its output", {
  store <- new_test_store(tables_fixture())
  add_test_task(store, "fs_1", "filter_sort", inputs = "sales",
    params = list(
      input_table = "sales",
      filters = list(list(id = "f1", col = "amount", op = ">", val = "15",
                          val2 = "", join = "AND", col_class = "numeric")),
      sorts = list(),
      output_name = "fs_1_out"
    ))
  ok <- iso(run_task_from_store(store, "fs_1"))
  expect_true(ok)
  out <- iso(store$tables)$fs_1_out
  expect_false(is.null(out))
  expect_true(all(out$amount > 15, na.rm = TRUE))
  task <- iso(store$tasks)$fs_1
  expect_equal(task$status, "success")
  expect_null(task$error_msg)
  expect_false(is.null(task$run_time))
})

test_that("run_task_from_store records errors on the task", {
  store <- new_test_store(tables_fixture())
  add_test_task(store, "fs_bad", "filter_sort", inputs = "missing_table",
    params = list(input_table = "missing_table", filters = list(),
                  sorts = list(), output_name = "bad_out"))
  ok <- iso(run_task_from_store(store, "fs_bad"))
  expect_false(ok)
  task <- iso(store$tasks)$fs_bad
  expect_equal(task$status, "error")
  expect_match(task$error_msg, "not found")
  expect_false("bad_out" %in% names(iso(store$tables)))
})

test_that("run_task_from_store stores compare_data results as objects", {
  skip_if_not_installed("waldo")
  store <- new_test_store(tables_fixture())
  modified <- sample_sales(); modified$amount[1] <- 999
  store_add_table(store, "sales2", modified)
  add_test_task(store, "cd_1", "compare_data", inputs = c("sales", "sales2"),
    params = list(table_a = "sales", table_b = "sales2",
                  by_cols = character(0), output_name = "cd_1_out"))
  ok <- iso(run_task_from_store(store, "cd_1"))
  expect_true(ok)
  objs <- iso(store$objects)
  expect_true("cd_1_out" %in% names(objs))
  expect_s3_class(objs$cd_1_out$value, "waldo_compare")
  expect_false("cd_1_out" %in% names(iso(store$tables)))
})

test_that("run_task_from_store honours describe-task Save toggles", {
  store <- new_test_store(tables_fixture())
  add_test_task(store, "chr_1", "characterize", inputs = "sales",
    params = list(input_table = "sales", output_name = "chr_1_out",
                  output_enabled = FALSE))
  ok <- iso(run_task_from_store(store, "chr_1"))
  expect_true(ok)
  expect_false("chr_1_out" %in% names(iso(store$tables)))

  add_test_task(store, "chr_2", "characterize", inputs = "sales",
    params = list(input_table = "sales", output_name = "chr_2_out",
                  output_enabled = TRUE))
  iso(run_task_from_store(store, "chr_2"))
  expect_true("chr_2_out" %in% names(iso(store$tables)))
})

test_that("run_task_from_store handles phase3 tasks end to end", {
  store <- new_test_store(tables_fixture())
  p <- default_phase3_params("linear_regression", output_name = "lr_out")
  p$input_table <- "cars"; p$response <- "mpg"; p$predictors <- "wt"
  p$output_enabled$model <- TRUE
  add_test_task(store, "lr_1", "linear_regression", inputs = "cars", params = p)
  ok <- iso(run_task_from_store(store, "lr_1"))
  expect_true(ok)
  expect_true("lr_out" %in% names(iso(store$tables)))
  expect_true("lr_out_model" %in% names(iso(store$objects)))
  expect_match(iso(store$tasks)$lr_1$r_code, "broom::tidy")
})

test_that("run_task_from_store executes script tasks", {
  store <- new_test_store(tables_fixture())
  add_test_task(store, "scr_1", "script", inputs = "sales",
    params = list(code = "filtered <- sales[sales$qty > 2, ]",
                  input_tables = "sales", output_name = "filtered",
                  output_defs = list(list(name = "filtered", kind = "table"))))
  ok <- iso(run_task_from_store(store, "scr_1"))
  expect_true(ok)
  expect_equal(nrow(iso(store$tables)$filtered), 4L)
})

test_that("run_task_from_store executes query_builder tasks", {
  store <- new_test_store(tables_fixture())
  p <- default_qb_params(output_name = "qb_out")
  p$primary_table <- "sales"
  p$select <- list(list(col = "region", alias = "region", func = "none"),
                   list(col = "amount", alias = "total", func = "SUM"))
  add_test_task(store, "qb_1", "query_builder", inputs = "sales", params = p)
  ok <- iso(run_task_from_store(store, "qb_1"))
  expect_true(ok)
  out <- iso(store$tables)$qb_out
  expect_equal(nrow(out), 3L)
})

test_that("a full pipeline runs in topological order", {
  store <- new_test_store(tables_fixture())
  # intentionally registered consumer-first
  add_test_task(store, "sst_1", "summary_stats", inputs = "fs_out",
    params = list(input_table = "fs_out", cols = character(0),
                  output_name = "sst_out"))
  add_test_task(store, "fs_1", "filter_sort", inputs = "sales",
    params = list(input_table = "sales", filters = list(), sorts = list(),
                  output_name = "fs_out"))
  ord <- iso(store_topo_order(store$tasks, store$task_order))
  expect_equal(ord, c("fs_1", "sst_1"))
  for (tid in ord) iso(run_task_from_store(store, tid))
  expect_true(all(c("fs_out", "sst_out") %in% names(iso(store$tables))))
})

test_that("unknown task ids fail gracefully", {
  store <- new_test_store()
  expect_false(iso(run_task_from_store(store, "no_such_task")))
})
