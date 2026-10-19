test_that("identifiers and values round trip quotes, backslashes, backticks and newlines", {
  for (name in c("with space", "with`tick", "a\\b", "a\nb", "TRUE", 'x"y')) {
    env <- new.env(parent = baseenv())
    assign(name, 42L, env)
    expect_equal(eval(parse(text = r_ident(name)), env), 42L, info = name)
    for (class in c("character", "numeric", if (name != "TRUE") "logical"))
      expect_identical(eval(parse(text = r_val(name, class))), name)
  }
})

test_that("LIKE uses SQL wildcards and treats regex punctuation literally", {
  values <- c('a[1]+(x)?"\\z', 'pre a[1]+(x)?"\\z suffix', "a1x", "100%", "1000", "x_y", "xay")
  df <- data.frame(text = values)
  p <- default_filter_sort_params(output_name = "out")
  p$input_table <- "data"
  for (case in list(list('a[1]+(x)?"\\\\z', 1L), list('%[1]+(x)?"%', c(1L, 2L)),
                   list("100\\%", 4L), list("x\\_y", 6L), list("x_y", c(6L, 7L)))) {
    p$filters <- list(new_filter_row("f", "text", "LIKE", case[[1]]))
    result <- execute_fs(p, list(data = df))
    expect_null(result$error)
    expect_equal(result$data$text, values[case[[2]]])
  }
})

test_that("mixed AND/OR filters retain SQL AND precedence in both paths", {
  df <- data.frame(a = c(1, 0, 0), b = c(0, 1, 1), c = c(0, 1, 0))
  filters <- list(new_filter_row("a", "a", "=", "1", col_class = "numeric"),
    new_filter_row("b", "b", "=", "1", col_class = "numeric", join = "OR"),
    new_filter_row("c", "c", "=", "1", col_class = "numeric", join = "AND"))
  p <- default_qb_params("out"); p$primary_table <- "data"; p$filters <- filters
  expect_equal(execute_query(p, list(data = df))$data, df[1:2, ])
  q <- default_filter_sort_params("out"); q$input_table <- "data"; q$filters <- filters
  expect_equal(execute_fs(q, list(data = df))$data, df[1:2, ])
})
