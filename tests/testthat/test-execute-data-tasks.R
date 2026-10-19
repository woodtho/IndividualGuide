# Every Phase-2 Data task, exercised through its standalone execute_* function
# (the same code path Run Flow uses when a panel has never been opened).

tabs <- tables_fixture()

# ── append_table ───────────────────────────────────────────────────────────────

test_that("execute_append stacks tables row-wise", {
  res <- execute_append(list(input_tables = c("sales", "sales")), tabs)
  expect_null(res$error)
  expect_equal(nrow(res$data), 2 * nrow(tabs$sales))
})

test_that("execute_append honours the .id source column and labels", {
  res <- execute_append(list(
    input_tables = c("sales", "sales"),
    table_names  = list(sales = "first", sales = "second"),
    id_col       = "src"
  ), tabs)
  expect_null(res$error)
  expect_true("src" %in% names(res$data))
  expect_setequal(unique(res$data$src), c("first", "second"))
})

test_that("execute_append validates inputs", {
  expect_match(execute_append(list(input_tables = "sales"), tabs)$error,
               "at least two")
  expect_match(execute_append(list(input_tables = c("sales", "nope")), tabs)$error,
               "Not found")
})

# ── compare_data ───────────────────────────────────────────────────────────────

test_that("execute_compare returns a waldo comparison object", {
  skip_if_not_installed("waldo")
  modified <- tabs$sales
  modified$amount[1] <- 999
  res <- execute_compare(list(table_a = "sales", table_b = "mod"),
                         c(tabs, list(mod = modified)))
  expect_null(res$error)
  expect_s3_class(res$object, "waldo_compare")
  expect_true(length(res$object) > 0)   # differences found
})

test_that("execute_compare reports no differences for identical tables", {
  skip_if_not_installed("waldo")
  res <- execute_compare(list(table_a = "sales", table_b = "sales"), tabs)
  expect_null(res$error)
  expect_length(res$object, 0)
})

# ── filter_sort ────────────────────────────────────────────────────────────────

test_that("execute_fs filters and sorts", {
  p <- list(
    input_table = "sales",
    filters = list(list(id = "f1", col = "amount", op = ">", val = "15",
                        val2 = "", join = "AND", col_class = "numeric")),
    sorts   = list(list(id = "s1", col = "amount", dir = "DESC")),
    output_name = "fs_out"
  )
  res <- execute_fs(p, tabs)
  expect_null(res$error)
  expect_true(all(res$data$amount > 15, na.rm = TRUE))
  expect_false(is.unsorted(rev(res$data$amount)))
})

test_that("execute_fs supports BETWEEN, IN, IS NULL and LIKE", {
  fs <- function(filters) execute_fs(list(input_table = "sales",
    filters = filters, sorts = list(), output_name = "o"), tabs)

  between <- fs(list(list(id = "f", col = "amount", op = "BETWEEN", val = "15",
                          val2 = "35", join = "AND", col_class = "numeric")))
  expect_equal(sort(between$data$amount), c(20, 30))

  inop <- fs(list(list(id = "f", col = "region", op = "IN",
                       val = "North, East", val2 = "", join = "AND",
                       col_class = "character")))
  expect_setequal(unique(inop$data$region), c("North", "East"))

  isnull <- fs(list(list(id = "f", col = "amount", op = "IS NULL", val = "",
                         val2 = "", join = "AND", col_class = "numeric")))
  expect_equal(nrow(isnull$data), 1L)

  like <- fs(list(list(id = "f", col = "region", op = "LIKE", val = "%orth",
                       val2 = "", join = "AND", col_class = "character")))
  expect_setequal(unique(like$data$region), "North")
})

test_that("execute_fs combines conditions with OR", {
  p <- list(input_table = "sales",
    filters = list(
      list(id = "f1", col = "region", op = "=", val = "North", val2 = "",
           join = "AND", col_class = "character"),
      list(id = "f2", col = "region", op = "=", val = "East", val2 = "",
           join = "OR", col_class = "character")
    ),
    sorts = list(), output_name = "o")
  res <- execute_fs(p, tabs)
  expect_setequal(unique(res$data$region), c("North", "East"))
})

# ── stack_columns / split_columns ─────────────────────────────────────────────

test_that("execute_stack pivots wide to long", {
  res <- execute_stack(list(input_table = "sales", cols = c("amount", "qty"),
                            names_to = "metric", values_to = "val"), tabs)
  expect_null(res$error)
  expect_true(all(c("metric", "val") %in% names(res$data)))
  expect_equal(nrow(res$data), 2 * nrow(tabs$sales))
})

test_that("execute_split pivots long to wide", {
  long <- execute_stack(list(input_table = "sales", cols = c("amount", "qty"),
                             names_to = "metric", values_to = "val"), tabs)$data
  res <- execute_split(list(input_table = "long", names_from = "metric",
                            values_from = "val",
                            id_cols = c("region", "product", "date")),
                       list(long = long))
  expect_null(res$error)
  expect_true(all(c("amount", "qty") %in% names(res$data)))
})

# ── transpose ──────────────────────────────────────────────────────────────────

test_that("execute_transpose swaps rows and columns", {
  small <- data.frame(metric = c("mean", "sd"), a = c(1, 2), b = c(3, 4))
  res <- execute_transpose(list(input_table = "t", id_col = "metric"),
                           list(t = small))
  expect_null(res$error)
  expect_equal(names(res$data), c("mean", "sd"))
  expect_equal(nrow(res$data), 2L)   # a and b rows
})

# ── rank ───────────────────────────────────────────────────────────────────────

test_that("execute_rank adds a rank column (plain and grouped)", {
  res <- execute_rank(list(input_table = "sales", rank_col = "qty",
                           method = "min_rank", new_col_name = "rk"), tabs)
  expect_null(res$error)
  expect_equal(res$data$rk, 1:6)

  grouped <- execute_rank(list(input_table = "sales", rank_col = "qty",
                               method = "row_number", new_col_name = "rk",
                               group_by_cols = "region"), tabs)
  expect_null(grouped$error)
  expect_true(all(grouped$data$rk %in% 1:2))
})

# ── standardize ────────────────────────────────────────────────────────────────

test_that("execute_std z-scores and min-max scales", {
  z <- execute_std(list(input_table = "sales", cols = "qty",
                        method = "zscore"), tabs)
  expect_null(z$error)
  expect_equal(mean(z$data$qty), 0, tolerance = 1e-12)

  mm <- execute_std(list(input_table = "sales", cols = "qty",
                         method = "minmax"), tabs)
  expect_equal(range(mm$data$qty), c(0, 1))
})

# ── random_sample ──────────────────────────────────────────────────────────────

test_that("execute_sample is reproducible with a seed and caps n", {
  a <- execute_sample(list(input_table = "sales", method = "n", n = 3L,
                           seed = 42L), tabs)
  b <- execute_sample(list(input_table = "sales", method = "n", n = 3L,
                           seed = 42L), tabs)
  expect_equal(a$data, b$data)
  expect_equal(nrow(a$data), 3L)

  capped <- execute_sample(list(input_table = "sales", method = "n",
                                n = 999L, seed = 1L), tabs)
  expect_equal(nrow(capped$data), nrow(tabs$sales))

  prop <- execute_sample(list(input_table = "sales", method = "prop",
                              prop = 0.5, seed = 1L), tabs)
  expect_equal(nrow(prop$data), 3L)
})

# ── remove_dups ────────────────────────────────────────────────────────────────

test_that("execute_remove_dups removes exact and keyed duplicates", {
  dup <- rbind(tabs$sales, tabs$sales[1, ])
  res <- execute_remove_dups(list(input_table = "d"), list(d = dup))
  expect_equal(nrow(res$data), nrow(tabs$sales))

  keyed <- execute_remove_dups(list(input_table = "d", cols = "region"),
                               list(d = dup))
  expect_equal(nrow(keyed$data), 3L)         # North/South/East
  expect_equal(ncol(keyed$data), ncol(dup))  # .keep_all = TRUE
})

# ── keep_drop_cols ─────────────────────────────────────────────────────────────

test_that("execute_keep_drop keeps or drops columns", {
  keep <- execute_keep_drop(list(input_table = "sales", action = "keep",
                                 cols = c("region", "amount")), tabs)
  expect_equal(names(keep$data), c("region", "amount"))

  drop <- execute_keep_drop(list(input_table = "sales", action = "drop",
                                 cols = "date"), tabs)
  expect_false("date" %in% names(drop$data))
})

# ── rename_cols ────────────────────────────────────────────────────────────────

test_that("execute_rename_cols renames columns", {
  res <- execute_rename_cols(list(input_table = "sales",
    renames = list(list(old = "amount", new = "revenue"),
                   list(old = "qty",    new = "quantity"))), tabs)
  expect_null(res$error)
  expect_true(all(c("revenue", "quantity") %in% names(res$data)))
  expect_false(any(c("amount", "qty") %in% names(res$data)))
})

# ── first_last_n ───────────────────────────────────────────────────────────────

test_that("execute_first_last takes head or tail", {
  h <- execute_first_last(list(input_table = "sales", which = "head", n = 2L), tabs)
  expect_equal(h$data$qty, 1:2)
  t <- execute_first_last(list(input_table = "sales", which = "tail", n = 2L), tabs)
  expect_equal(t$data$qty, 5:6)
})

# ── replace_missing ────────────────────────────────────────────────────────────

test_that("execute_replace_missing fills NA with fixed / mean / median values", {
  fixed <- execute_replace_missing(list(input_table = "sales", cols = "amount",
                                        method = "fixed", fixed_value = "0"), tabs)
  expect_equal(fixed$data$amount[5], 0)

  mn <- execute_replace_missing(list(input_table = "sales", cols = "amount",
                                     method = "mean"), tabs)
  expect_equal(mn$data$amount[5], mean(tabs$sales$amount, na.rm = TRUE))

  md <- execute_replace_missing(list(input_table = "sales", cols = "amount",
                                     method = "median"), tabs)
  expect_equal(md$data$amount[5], median(tabs$sales$amount, na.rm = TRUE))
})

test_that("execute_replace_missing mode fill picks the most frequent value", {
  # Regression test: the old implementation indexed the data vector with a
  # table() index and could return an arbitrary value instead of the mode.
  df <- data.frame(x = c("b", "a", "a", NA), stringsAsFactors = FALSE)
  res <- execute_replace_missing(list(input_table = "t", cols = "x",
                                      method = "mode"), list(t = df))
  expect_equal(res$data$x[4], "a")

  num <- data.frame(y = c(5, 7, 7, NA))
  res2 <- execute_replace_missing(list(input_table = "t", cols = "y",
                                       method = "mode"), list(t = num))
  expect_identical(res2$data$y[4], 7)
})

test_that("execute_replace_missing can fill factors with unseen levels", {
  df <- data.frame(f = factor(c("x", NA, "y")))
  res <- execute_replace_missing(list(input_table = "t", cols = "f",
                                      method = "fixed", fixed_value = "missing"),
                                 list(t = df))
  expect_equal(as.character(res$data$f[2]), "missing")
})

# ── derive_cols ────────────────────────────────────────────────────────────────

test_that("execute_derive_cols computes new columns with dplyr helpers", {
  res <- execute_derive_cols(list(input_table = "sales",
    derives = list(
      list(name = "total", expr = "amount * qty"),
      list(name = "big",   expr = "if_else(qty > 3, 'yes', 'no')"),
      list(name = "yr",    expr = "year(date)")
    )), tabs)
  expect_null(res$error)
  expect_equal(res$data$total, tabs$sales$amount * tabs$sales$qty)
  expect_equal(res$data$big, c("no", "no", "no", "yes", "yes", "yes"))
  expect_true(all(res$data$yr == 2024))
})

test_that("execute_derive_cols surfaces expression errors", {
  res <- execute_derive_cols(list(input_table = "sales",
    derives = list(list(name = "bad", expr = "nonexistent_col * 2"))), tabs)
  expect_false(is.null(res$error))
})

# ── recode_values ──────────────────────────────────────────────────────────────

test_that("execute_recode_values maps values including NA and else", {
  res <- execute_recode_values(list(input_table = "sales", col = "region",
    new_col_name = "zone",
    rules = list(list(from = "North", to = "N"), list(from = "South", to = "S")),
    else_val = "other"), tabs)
  expect_null(res$error)
  expect_equal(res$data$zone,
               c("N", "S", "N", "S", "other", "other"))

  num <- execute_recode_values(list(input_table = "sales", col = "amount",
    new_col_name = "amt_cat",
    rules = list(list(from = "10", to = "ten"), list(from = "NA", to = "missing")),
    else_val = ""), tabs)
  expect_equal(num$data$amt_cat[1], "ten")
  expect_equal(num$data$amt_cat[5], "missing")
  expect_equal(num$data$amt_cat[2], "20")   # unmatched keeps original as character
})

# ── change_types ───────────────────────────────────────────────────────────────

test_that("execute_change_types converts column types", {
  df <- data.frame(n = c("1", "2"), d = c("2024-01-15", "2024-02-20"),
                   f = c("a", "b"), stringsAsFactors = FALSE)
  res <- execute_change_types(list(input_table = "t",
    type_changes = list(
      list(col = "n", type = "numeric"),
      list(col = "d", type = "Date"),
      list(col = "f", type = "factor")
    )), list(t = df))
  expect_null(res$error)
  expect_type(res$data$n, "double")
  expect_s3_class(res$data$d, "Date")
  expect_s3_class(res$data$f, "factor")
  expect_equal(res$data$d[1], as.Date("2024-01-15"))
})

test_that("execute_change_types detects slash date formats", {
  df <- data.frame(d = c("01/15/2024", "02/20/2024"), stringsAsFactors = FALSE)
  res <- execute_change_types(list(input_table = "t",
    type_changes = list(list(col = "d", type = "Date"))), list(t = df))
  expect_equal(res$data$d[1], as.Date("2024-01-15"))
})

# ── shared validation behaviour ───────────────────────────────────────────────

test_that("data tasks report missing tables and empty selections", {
  expect_match(execute_fs(list(input_table = ""), tabs)$error, "Select an input")
  expect_match(execute_fs(list(input_table = "nope"), tabs)$error, "not found")
  expect_match(execute_stack(list(input_table = "sales", cols = character(0)),
                             tabs)$error, "Select columns")
  expect_match(execute_keep_drop(list(input_table = "sales",
                                      cols = character(0)), tabs)$error,
               "at least one column")
  expect_match(execute_rename_cols(list(input_table = "sales",
                                        renames = list()), tabs)$error,
               "rename pair")
})
