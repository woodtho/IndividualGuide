# Query Builder: pure code generation and execution
# (mod_task_query_builder.R; shared SQL/filter helpers in task_helpers_query.R).

tabs <- tables_fixture()

# ── identifier / value quoting ─────────────────────────────────────────────────

test_that("r_ident quotes only when needed", {
  expect_equal(r_ident("amount"), "amount")
  expect_equal(r_ident("my col"), "`my col`")
  expect_equal(r_ident("TRUE"), "`TRUE`")
  expect_equal(r_ident("if"), "`if`")
  expect_equal(r_ident("2col"), "`2col`")
})

test_that("r_val quotes by column class", {
  expect_equal(r_val("5", "numeric"), "5")
  expect_equal(r_val("abc", "character"), '"abc"')
  expect_equal(r_val("abc", "numeric"), '"abc"')        # non-numeric falls back
  expect_equal(r_val("true", "logical"), "TRUE")
  expect_equal(r_val("0", "logical"), "FALSE")
  expect_equal(r_val("2024-01-01", "Date"), 'as.Date("2024-01-01")')
  expect_equal(r_val(NULL, "character"), '""')
  expect_equal(r_val('say "hi"', "character"), '"say \\"hi\\""')
})

test_that("like_to_regex translates SQL wildcards", {
  expect_equal(like_to_regex("%abc%"), "^.*abc.*$")
  expect_equal(like_to_regex("a_c"), "^a.c$")
  expect_equal(like_to_regex("1.5%"), "^1\\.5.*$")
})

test_that("clean_libraries splits and trims", {
  expect_equal(clean_libraries("stringr, lubridate"), c("stringr", "lubridate"))
  expect_equal(clean_libraries(NULL), character(0))
  expect_equal(clean_libraries(c(" a ", "", "b")), c("a", "b"))
})

# ── execute_query ──────────────────────────────────────────────────────────────

qb_p <- function(...) {
  set_params(default_qb_params(output_name = "q_out"), ...)
}

test_that("plain select with alias works", {
  p <- qb_p(primary_table = "sales",
            select = list(list(col = "region", alias = "zone", func = "none"),
                          list(col = "amount", alias = "amount", func = "none")))
  res <- execute_query(p, tabs)
  expect_null(res$error)
  expect_equal(names(res$data), c("zone", "amount"))
  expect_equal(nrow(res$data), nrow(tabs$sales))
})

test_that("filters and sorts execute", {
  p <- qb_p(primary_table = "sales",
            filters = list(new_filter_row("f1", "amount", ">", "15",
                                          col_class = "numeric")),
            sorts = list(list(id = "s1", col = "amount", dir = "DESC")))
  res <- execute_query(p, tabs)
  expect_null(res$error)
  expect_true(all(res$data$amount > 15))
  expect_false(is.unsorted(rev(res$data$amount)))
})

test_that("aggregation groups by non-aggregated columns", {
  p <- qb_p(primary_table = "sales",
            select = list(
              list(col = "region", alias = "region", func = "none"),
              list(col = "amount", alias = "total",  func = "SUM"),
              list(col = "qty",    alias = "n_rows", func = "COUNT")
            ))
  res <- execute_query(p, tabs)
  expect_null(res$error)
  expect_equal(nrow(res$data), 3L)                  # one row per region
  expect_setequal(names(res$data), c("region", "total", "n_rows"))
  expect_equal(res$data$total[res$data$region == "North"], 40)
  expect_equal(res$data$n_rows[res$data$region == "East"], 2L)
})

test_that("HAVING filters after aggregation", {
  p <- qb_p(primary_table = "sales",
            select = list(
              list(col = "region", alias = "region", func = "none"),
              list(col = "amount", alias = "total",  func = "SUM")
            ),
            having = list(new_filter_row("h1", "total", ">", "50",
                                         col_class = "numeric")))
  res <- execute_query(p, tabs)
  expect_null(res$error)
  expect_true(all(res$data$total > 50))
})

test_that("joins pull in lookup columns", {
  p <- qb_p(primary_table = "sales",
            joins = list(list(right_table = "regions", type = "left",
                              keys_left = "region", keys_right = "region")))
  res <- execute_query(p, tabs)
  expect_null(res$error)
  expect_true("manager" %in% names(res$data))
  expect_equal(nrow(res$data), nrow(tabs$sales))

  inner <- qb_p(primary_table = "regions",
                joins = list(list(right_table = "sales", type = "inner",
                                  keys_left = "region", keys_right = "region")))
  res2 <- execute_query(inner, tabs)
  expect_null(res2$error)
  expect_false("West" %in% res2$data$region)   # no sales in West
})

test_that("computed columns are available to select and filter", {
  p <- qb_p(primary_table = "sales",
            computed = list(list(name = "total", expr = "amount * qty")),
            filters  = list(new_filter_row("f1", "total", ">", "100",
                                           col_class = "numeric")))
  res <- execute_query(p, tabs)
  expect_null(res$error)
  expect_true(all(res$data$total > 100))
})

test_that("distinct removes duplicate rows", {
  p <- qb_p(primary_table = "sales", distinct = TRUE,
            select = list(list(col = "region", alias = "region", func = "none")))
  res <- execute_query(p, tabs)
  expect_equal(nrow(res$data), 3L)
})

test_that("custom aggregate expressions run", {
  p <- qb_p(primary_table = "sales",
            select = list(
              list(col = "region", alias = "region", func = "none"),
              list(col = "amount", alias = "avg_per_unit", func = "CUSTOM",
                   expr = "sum(amount, na.rm = TRUE) / sum(qty)")
            ))
  res <- execute_query(p, tabs)
  expect_null(res$error)
  expect_true("avg_per_unit" %in% names(res$data))
})

test_that("execute_query validates inputs and surfaces errors", {
  expect_match(execute_query(qb_p(primary_table = ""), tabs)$error,
               "primary")
  bad <- qb_p(primary_table = "sales",
              computed = list(list(name = "x", expr = "no_such_col + 1")),
              select = list(list(col = "x", alias = "x", func = "none")))
  expect_false(is.null(execute_query(bad, tabs)$error))
})

test_that("MEDIAN / STDDEV / VAR aggregates work (stats fns injected)", {
  p <- qb_p(primary_table = "sales",
            select = list(
              list(col = "region", alias = "region", func = "none"),
              list(col = "amount", alias = "med", func = "MEDIAN"),
              list(col = "amount", alias = "stdev", func = "STDDEV"),
              list(col = "amount", alias = "vr",  func = "VAR")
            ))
  res <- execute_query(p, tabs)
  expect_null(res$error)
  expect_true(all(c("med", "stdev", "vr") %in% names(res$data)))
})

test_that("query_input_tables lists primary and joined tables", {
  p <- qb_p(primary_table = "sales",
            joins = list(list(right_table = "regions", type = "left",
                              keys_left = "region", keys_right = "region")))
  expect_setequal(query_input_tables(p), c("sales", "regions"))
})

test_that("build_query_code output is valid parseable R", {
  p <- qb_p(primary_table = "sales",
            select = list(list(col = "region", alias = "region", func = "none"),
                          list(col = "amount", alias = "total", func = "SUM")),
            sorts = list(list(id = "s", col = "total", dir = "DESC")))
  code <- build_query_code(p)
  expect_no_error(parse(text = code))
  expect_match(code, "group_by\\(region\\)")
  expect_match(code, "summarise")
})
