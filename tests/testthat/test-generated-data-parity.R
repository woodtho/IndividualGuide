check_data_code <- function(params, builder, execute, tables = tables_fixture()) {
  params$output_name <- "result with spaces"
  code <- builder(params)
  expected <- execute(params, tables)
  expect_null(expected$error)
  env <- list2env(tables, parent = globalenv())
  eval(parse(text = code), envir = env)
  expect_true(exists(params$output_name, env, inherits = FALSE))
  actual <- get(params$output_name, env, inherits = FALSE)
  expect_equal(as.data.frame(actual), as.data.frame(expected$data))
}

test_that("generated keep/drop and keyed duplicate code uses names as strings", {
  check_data_code(list(input_table = "sales", cols = c("region", "amount"), action = "keep"),
    build_keepdrop_code, execute_keep_drop)
  check_data_code(list(input_table = "sales", cols = "region"), build_dedup_code, execute_remove_dups)
})

test_that("generated standardization is parseable and preserves grouped results", {
  check_data_code(list(input_table = "sales", cols = "qty", method = "zscore", group_by_cols = "region"),
    build_std_code, execute_std)
})

test_that("generated missing-value replacement preserves types and factor levels", {
  check_data_code(list(input_table = "sales", cols = "amount", method = "fixed", fixed_value = "0"),
    build_fillna_code, execute_replace_missing)
  check_data_code(list(input_table = "t", cols = "f", method = "fixed", fixed_value = "missing"),
    build_fillna_code, execute_replace_missing, list(t = data.frame(f = factor(c("a", NA)))))
})

test_that("generated date and logical type conversions match execution", {
  tables <- list(t = data.frame(d = c("01/15/2024", "02/20/2024"), l = c("true", "FALSE")))
  check_data_code(list(input_table = "t", type_changes = list(list(col = "d", type = "Date"), list(col = "l", type = "logical"))),
    build_changetype_code, execute_change_types, tables)
})

test_that("generated characterization and summary statistics reproduce all columns", {
  check_data_code(list(input_table = "sales"), build_char_code, execute_characterize)
  check_data_code(list(input_table = "sales", cols = "amount"), build_stats_code, execute_summary_stats)
})

test_that("generated frequencies sort the same object they return", {
  tables <- list(t = data.frame(group = c("a", "b", "b", "b")))
  check_data_code(list(input_table = "t", col = "group", sort_desc = TRUE), build_freq_code, execute_one_way_freq, tables)
})

test_that("generated summary tables reproduce cross-tab shape and counts", {
  check_data_code(list(input_table = "sales", row_var = "region", col_var = "product", value_var = "amount", stat_fn = "sum"),
    build_st_code, execute_summary_table)
  check_data_code(list(input_table = "sales", row_var = "region", col_var = "", value_var = "qty", stat_fn = "n"),
    build_st_code, execute_summary_table)
})

test_that("generated transpose resets row names as the visual operation does", {
  check_data_code(list(input_table = "t", id_col = "metric"), build_transpose_code, execute_transpose,
    list(t = data.frame(metric = c("mean", "sd"), a = 1:2, b = 3:4)))
})

test_that("sampling replacement, seeded RNG and generated rows agree", {
  p <- list(input_table = "sales", method = "n", n = 20, replace = TRUE, seed = 3)
  set.seed(43); before <- .Random.seed
  check_data_code(p, build_sample_code, execute_sample)
  expect_identical(.Random.seed, before)
  expect_equal(nrow(execute_sample(p, tables_fixture())$data), 20L)
  p$seed <- NULL; p$n <- 0
  check_data_code(p, build_sample_code, execute_sample)
  p$n <- -1
  expect_match(execute_sample(p, tables_fixture())$error, "nonnegative")
})

test_that("recode numeric spelling, last rule, missing and else agree", {
  p <- list(input_table = "t", col = "x", new_col_name = "label", else_val = "other",
    rules = list(list(from = "1.0", to = "first"), list(from = "1", to = "last"),
      list(from = "NA", to = "missing")))
  tables <- list(t = data.frame(x = c(1, 2, NA)))
  check_data_code(p, build_recode_code, execute_recode_values, tables)
  expect_equal(execute_recode_values(p, tables)$data$label, c("last", "other", "missing"))
  p$rules <- list(list(from = "oops", to = "bad"))
  expect_match(execute_recode_values(p, tables)$error, "not numeric")
})

test_that("generated rename ignores empty and unchanged pairs", {
  check_data_code(list(input_table = "sales", renames = list(
    list(old = "", new = ""), list(old = "qty", new = "qty"),
    list(old = "amount", new = "total value"))), build_rename_code, execute_rename_cols)
})

test_that("first and last rows use the same defaults and reject invalid sizes", {
  check_data_code(list(input_table = "sales", n = 2), build_firstlast_code, execute_first_last)
  for (n in list(0, -1, 1.5, Inf, NA_real_)) {
    p <- list(input_table = "sales", output_name = "out", n = n)
    expect_match(execute_first_last(p, tables_fixture())$error, "positive whole")
    expect_error(eval(parse(text = build_firstlast_code(p))), "positive whole")
  }
})

test_that("remaining data builders reproduce configured transformations", {
  check_data_code(list(input_tables = c("sales", "sales"), id_col = "source label",
    table_names = list(sales = "first", sales = "second"), fill = TRUE), build_append_code, execute_append)
  check_data_code(list(input_table = "sales", cols = c("amount", "qty"),
    names_to = "field name", values_to = "value col"), build_stack_code, execute_stack)
  long <- data.frame(id = rep(1:2, each = 2), field = rep(c("a b", "c"), 2), value = 1:4)
  check_data_code(list(input_table = "long", id_cols = "id", names_from = "field", values_from = "value"),
    build_split_code, execute_split, list(long = long))
  check_data_code(list(input_table = "sales", rank_col = "qty", method = "dense_rank",
    new_col_name = "rank score", group_by_cols = "region"), build_rank_code, execute_rank)
  check_data_code(list(input_table = "sales", derives = list(list(name = "new amount",
    expr = "if_else(qty > 2, amount, 0)"))), build_derive_code, execute_derive_cols)
  check_data_code(list(input_table = "sales", derives = list(
    list(name = "filled", expr = "replace_na(amount, 0)"),
    list(name = "parsed date", expr = "ymd('2026-01-02')"))), build_derive_code, execute_derive_cols)
  check_data_code(list(input_table = "sales", filters = list(list(col = "amount", op = ">=",
    value = "20", col_class = "numeric", logic = "AND")), sorts = list(list(col = "qty", dir = "DESC"))),
    build_fs_code, execute_fs)
})

test_that("generated keyed comparisons preserve the actual comparison object", {
  a <- sample_sales(); b <- a; b$amount[[1L]] <- 100
  p <- list(table_a = "a", table_b = "b", by_cols = "qty", output_name = "comparison")
  result <- execute_compare(p, list(a = a, b = b)); expect_null(result$error)
  env <- list2env(list(a = a, b = b), parent = globalenv())
  eval(parse(text = build_compare_code(p)), env)
  expect_equal(env$comparison, result$object)
})
