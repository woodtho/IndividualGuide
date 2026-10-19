# Phase-2 Describe tasks via their standalone execute_* functions.

tabs <- tables_fixture()

test_that("execute_characterize profiles every column", {
  res <- execute_characterize(list(input_table = "sales"), tabs)
  expect_null(res$error)
  expect_equal(res$data$column, names(tabs$sales))
  expect_equal(res$data$n_missing[res$data$column == "amount"], 1L)
  expect_equal(res$data$type[res$data$column == "date"], "Date")
  expect_true(all(res$data$n_rows == nrow(tabs$sales)))
})

test_that("execute_list_data returns the table unchanged", {
  res <- execute_list_data(list(input_table = "sales"), tabs)
  expect_null(res$error)
  expect_identical(res$data, tabs$sales)
})

test_that("execute_one_way_freq counts, percents, and sorts", {
  res <- execute_one_way_freq(list(input_table = "sales", col = "region",
                                   sort_desc = FALSE), tabs)
  expect_null(res$error)
  expect_equal(sum(res$data$n), nrow(tabs$sales))
  expect_equal(sum(res$data$percent), 100, tolerance = 0.1)
  expect_equal(res$data$cum_percent[nrow(res$data)], 100, tolerance = 0.1)

  sorted <- execute_one_way_freq(list(input_table = "sales", col = "region",
                                      sort_desc = TRUE), tabs)
  expect_false(is.unsorted(rev(sorted$data$n)))
  # cumulative percent must be recomputed after sorting
  expect_equal(sorted$data$cum_percent, cumsum(sorted$data$percent),
               tolerance = 0.1)
})

test_that("execute_one_way_freq includes NA as a level", {
  res <- execute_one_way_freq(list(input_table = "sales", col = "amount",
                                   sort_desc = FALSE), tabs)
  expect_equal(sum(res$data$n), nrow(tabs$sales))   # NA row counted
})

test_that("execute_summary_stats summarises numeric columns", {
  res <- execute_summary_stats(list(input_table = "sales"), tabs)
  expect_null(res$error)
  expect_setequal(res$data$column, c("amount", "qty"))
  amount <- res$data[res$data$column == "amount", ]
  expect_equal(amount$n, 5)
  expect_equal(amount$n_miss, 1)
  expect_equal(amount$mean, mean(tabs$sales$amount, na.rm = TRUE), tolerance = 1e-3)

  none <- execute_summary_stats(list(input_table = "sales", cols = "region"), tabs)
  expect_true("message" %in% names(none$data))
})

test_that("execute_table_analysis builds a contingency table", {
  res <- execute_table_analysis(list(input_table = "sales",
                                     row_col = "region", col_col = "product"), tabs)
  expect_null(res$error)
  expect_equal(sum(as.matrix(res$data)), nrow(tabs$sales))
  expect_setequal(rownames(res$data), c("North", "South", "East"))
})

test_that("execute_summary_table supports all three shapes", {
  # row only → counts
  counts <- execute_summary_table(list(input_table = "sales",
                                       row_var = "region"), tabs)
  expect_null(counts$error)
  expect_equal(sum(counts$data$n), nrow(tabs$sales))

  # row + value → one summary column
  means <- execute_summary_table(list(input_table = "sales", row_var = "region",
                                      value_var = "qty", stat_fn = "mean"), tabs)
  expect_true("mean_qty" %in% names(means$data))

  # row + col + value → cross tab
  cross <- execute_summary_table(list(input_table = "sales", row_var = "region",
                                      col_var = "product", value_var = "amount",
                                      stat_fn = "sum"), tabs)
  expect_null(cross$error)
  expect_true(all(c("A", "B", "C") %in% names(cross$data)))
})

test_that("execute_distribution returns summary stats for numeric columns", {
  res <- execute_distribution(list(input_table = "sales", col = "amount"), tabs)
  expect_null(res$error)
  expect_equal(res$data$n, 5)
  expect_equal(res$data$n_miss, 1)

  bad <- execute_distribution(list(input_table = "sales", col = "region"), tabs)
  expect_match(bad$error, "numeric")
})
