# Script task and Report task execution.

tabs <- tables_fixture()

# ── Script ─────────────────────────────────────────────────────────────────────

test_that("execute_script runs code with input tables in scope", {
  p <- list(code = "out <- subset(sales, qty > 3)",
            input_tables = "sales", output_name = "out",
            output_defs = list(list(name = "out", kind = "table")))
  res <- execute_script(p, tabs)
  expect_null(res$error)
  expect_equal(nrow(res$data), 3L)
  expect_equal(res$primary_output, "out")
})

test_that("execute_script captures printed console output", {
  p <- list(code = "print('hello'); x <- 1", input_tables = character(0),
            output_name = "x", output_defs = list(list(name = "x", kind = "auto")))
  res <- execute_script(p, tabs)
  expect_match(res$output, "hello")
})

test_that("execute_script classifies multiple output kinds", {
  p <- list(
    code = paste(
      "tbl <- data.frame(a = 1:3)",
      "fit <- lm(mpg ~ wt, data = cars)",
      "note <- 'remember this'",
      sep = "\n"),
    input_tables = "cars",
    output_name = "tbl",
    output_defs = list(
      list(name = "tbl",  kind = "auto"),
      list(name = "fit",  kind = "auto"),
      list(name = "note", kind = "auto")
    ))
  res <- execute_script(p, tabs)
  expect_null(res$error)
  expect_equal(res$outputs$tbl$kind, "table")
  expect_equal(res$outputs$fit$kind, "model")
  expect_equal(res$outputs$note$kind, "object")
  expect_identical(res$data, res$outputs$tbl$value)
})

test_that("execute_script warns about undeclared / mistyped outputs", {
  p <- list(code = "x <- 1", input_tables = character(0), output_name = "missing_var",
            output_defs = list(list(name = "missing_var", kind = "auto")))
  res <- execute_script(p, tabs)
  expect_match(res$warnings, "was not created")

  p2 <- list(code = "x <- 1", input_tables = character(0), output_name = "x",
             output_defs = list(list(name = "x", kind = "table")))
  res2 <- execute_script(p2, tabs)
  expect_match(res2$warnings, "not a data frame")
})

test_that("execute_script surfaces runtime errors", {
  p <- list(code = "stop('boom')", input_tables = character(0),
            output_name = "x", output_defs = list(list(name = "x", kind = "auto")))
  res <- execute_script(p, tabs)
  expect_match(res$error, "boom")
})

test_that("script only sees declared inputs when declared", {
  # 'regions' is undeclared, so it must not be a local variable in the script
  # environment (inherits = FALSE avoids false hits on attached datasets).
  p <- list(code = paste(
              "has_sales <- exists('sales', inherits = FALSE)",
              "has_regions <- exists('regions', inherits = FALSE)", sep = "\n"),
            input_tables = "sales", output_name = "has_regions",
            output_defs = list(list(name = "has_regions", kind = "object"),
                               list(name = "has_sales", kind = "object")))
  res <- execute_script(p, tabs)
  expect_true(res$outputs$has_sales$value)
  expect_false(res$outputs$has_regions$value)
})

test_that("script_resolve_output_kind detects classes", {
  expect_equal(script_resolve_output_kind(data.frame(x = 1)), "table")
  expect_equal(script_resolve_output_kind(lm(qty ~ amount, sample_sales())), "model")
  expect_equal(script_resolve_output_kind(ggplot2::ggplot()), "image")
  expect_equal(script_resolve_output_kind("text"), "object")
  expect_equal(script_resolve_output_kind(1:3, kind = "table"), "table")  # explicit wins
})

test_that("parse_script_output_defs parses names and kinds", {
  defs <- parse_script_output_defs("clean: table\nfit: model\nplain", "fb")
  expect_equal(length(defs), 3L)
  expect_equal(defs[[1]], list(name = "clean", kind = "table"))
  expect_equal(defs[[2]], list(name = "fit", kind = "model"))
  expect_equal(defs[[3]]$kind, "auto")

  # falls back to the primary output name when empty
  fb <- parse_script_output_defs("", "primary")
  expect_equal(fb[[1]]$name, "primary")

  # invalid kinds become auto; duplicates dropped
  dup <- parse_script_output_defs("a: bogus\na: table", "fb")
  expect_equal(length(dup), 1L)
  expect_equal(dup[[1]]$kind, "auto")
})

test_that("store_script_outputs writes tables and objects", {
  store <- new_test_store()
  p <- list(code = "", output_name = "t")
  result <- list(outputs = list(
    t   = list(name = "t",   kind = "table",  value = data.frame(x = 1)),
    obj = list(name = "obj", kind = "object", value = "hello")
  ))
  shiny::isolate(store_script_outputs(store, p, result))
  expect_true("t" %in% names(shiny::isolate(store$tables)))
  expect_true("obj" %in% names(shiny::isolate(store$objects)))
})

# ── Report ─────────────────────────────────────────────────────────────────────

test_that("build_report_rmd produces a renderable Rmd source", {
  p <- list(title = "My Report", subtitle = "Q1", author = "Tester",
            format = "html",
            items = list(list(name = "sales", kind = "table", heading = "Sales")))
  rmd <- build_report_rmd(p, list(sales = tabs$sales), "C:/tmp/data.rds")
  expect_match(rmd, "title: \"My Report\"")
  expect_match(rmd, "subtitle: \"Q1\"")
  expect_match(rmd, "## Sales")
  expect_match(rmd, 'knitr::kable(.ig_report_values[["sales"]]', fixed = TRUE)
  expect_match(rmd, "C:/tmp/data.rds", fixed = TRUE)
})

test_that("build_report_rmd prints non-table outputs", {
  p <- list(title = "My Report", format = "html",
            items = list(list(name = "fit", kind = "model", heading = "Fit")))
  rmd <- build_report_rmd(p, list(fit = lm(qty ~ amount, tabs$sales)), "C:/tmp/data.rds")
  expect_match(rmd, "## Fit")
  expect_match(rmd, '.ig_obj <- .ig_report_values[["fit"]]', fixed = TRUE)
  expect_match(rmd, "capture.output(print(.ig_obj))", fixed = TRUE)
})

test_that("build_report_rmd renders by actual class, not declared kind", {
  # ggplot becomes a figure chunk — never captured print text
  gg <- ggplot2::ggplot(tabs$sales, ggplot2::aes(qty, amount)) +
    ggplot2::geom_point()
  p <- list(title = "T", format = "html",
            items = list(list(name = "chart", kind = "object", heading = "Chart")))
  rmd <- build_report_rmd(p, list(chart = gg), "C:/tmp/data.rds")
  expect_match(rmd, "fig.width")
  expect_false(grepl("capture.output", rmd, fixed = TRUE))

  # a data frame with a stale non-table kind still renders as kable
  p2 <- list(title = "T", format = "html",
             items = list(list(name = "tbl", kind = "object", heading = "Tbl")))
  rmd2 <- build_report_rmd(p2, list(tbl = tabs$sales), "C:/tmp/data.rds")
  expect_match(rmd2, 'knitr::kable(.ig_report_values[["tbl"]]', fixed = TRUE)

  # interactive widgets embed in HTML but degrade to a note in Word
  # (suppressWarnings: the sales fixture has one NA amount geom_point drops)
  wid <- suppressWarnings(ggiraph::girafe(ggobj = gg))
  p3 <- list(title = "T", format = "html",
             items = list(list(name = "wid", kind = "plot", heading = "Widget")))
  rmd3 <- build_report_rmd(p3, list(wid = wid), "C:/tmp/data.rds")
  expect_match(rmd3, '```{r}\n.ig_report_values[["wid"]]\n```', fixed = TRUE)
  p3$format <- "word"
  rmd4 <- build_report_rmd(p3, list(wid = wid), "C:/tmp/data.rds")
  expect_match(rmd4, "interactive widget")
  expect_false(grepl('```{r}\n.ig_report_values[["wid"]]\n```', rmd4, fixed = TRUE))
})

test_that("report items support render overrides and notes", {
  # DT override for a data frame (HTML) → DT::datatable chunk
  p <- list(title = "T", format = "html",
            items = list(list(name = "sales", kind = "table", heading = "Sales",
                              render = "datatable",
                              note = "First quarter only")))
  rmd <- build_report_rmd(p, list(sales = tabs$sales), "C:/tmp/data.rds")
  expect_match(rmd, 'DT::datatable(.ig_report_values[["sales"]]', fixed = TRUE)
  expect_false(grepl("knitr::kable", rmd))
  expect_match(rmd, "*First quarter only*", fixed = TRUE)

  # the same override degrades to a note in Word
  p$format <- "word"
  rmd2 <- build_report_rmd(p, list(sales = tabs$sales), "C:/tmp/data.rds")
  expect_match(rmd2, "interactive table")
  expect_false(grepl("DT::datatable", rmd2))

  # print override forces text rendering even for a data frame
  p3 <- list(title = "T", format = "html",
             items = list(list(name = "sales", kind = "table",
                               heading = "Raw", render = "print")))
  rmd3 <- build_report_rmd(p3, list(sales = tabs$sales), "C:/tmp/data.rds")
  expect_match(rmd3, "capture.output", fixed = TRUE)
  expect_false(grepl("knitr::kable", rmd3))

  # nonsensical overrides fall back safely (kable on a model → print)
  p4 <- list(title = "T", format = "html",
             items = list(list(name = "fit", kind = "model",
                               heading = "Fit", render = "kable")))
  rmd4 <- build_report_rmd(p4, list(fit = lm(qty ~ amount, tabs$sales)),
                           "C:/tmp/data.rds")
  expect_match(rmd4, "capture.output", fixed = TRUE)
})

test_that("execute_report validates empty item lists", {
  res <- execute_report(list(items = list()), tabs)
  expect_match(res$error, "at least one")
})

test_that("execute_report renders HTML without Pandoc", {
  p <- list(title = "T", format = "html",
            items = list(list(name = "sales", kind = "table", heading = "Sales")))
  res <- execute_report(p, tabs)
  expect_null(res$error)
  expect_true(file.exists(res$report_path))
  expect_match(res$report_path, "\\.html$")
})

test_that("execute_report explains Pandoc requirement for Word", {
  skip_if(requireNamespace("rmarkdown", quietly = TRUE) &&
            rmarkdown::pandoc_available(), "pandoc is available")
  p <- list(title = "T", format = "word",
            items = list(list(name = "sales", kind = "table", heading = "Sales")))
  res <- execute_report(p, tabs)
  expect_match(res$error, "Word reports require Pandoc")
})

test_that("execute_report accepts non-table outputs even with stale table kind", {
  skip_if_not_installed("rmarkdown")
  skip_if(!rmarkdown::pandoc_available(), "pandoc not available")
  p <- list(title = "T", format = "html",
            items = list(list(name = "fit", kind = "table", heading = "Fit")))
  res <- execute_report(p, tabs, objects = list(fit = lm(qty ~ amount, tabs$sales)))
  expect_null(res$error)
  expect_true(file.exists(res$report_path))
})

test_that("execute_report renders an HTML file", {
  skip_if_not_installed("rmarkdown")
  skip_if(!rmarkdown::pandoc_available(), "pandoc not available")
  p <- list(title = "T", format = "html",
            items = list(list(name = "sales", kind = "table", heading = "Sales")))
  res <- execute_report(p, tabs)
  expect_null(res$error)
  expect_true(file.exists(res$report_path))
  expect_match(res$report_path, "\\.html$")
})

test_that("build_report_code summarises the report definition", {
  code <- build_report_code(list(title = "T", format = "html",
    items = list(list(name = "sales", kind = "table"))))
  expect_match(code, "sales")
  expect_match(code, "HTML")
})
