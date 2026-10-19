# test-export.R — Export task: writers, formats, round-trips, errors, codegen,
# and Run-Flow (executor) integration.

iso <- function(expr) shiny::isolate(expr)

export_tmpdir <- function() {
  d <- file.path(tempdir(), paste0("ig_exp_", as.integer(runif(1, 1, 1e9))))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

# ── Format catalogue / helpers ────────────────────────────────────────────────

test_that("value kinds and format menus classify correctly", {
  expect_equal(ig_export_value_kind(data.frame(a = 1)), "data")
  expect_equal(ig_export_value_kind(lm(mpg ~ wt, mtcars)), "object")
  gg <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  expect_equal(ig_export_value_kind(gg), "plot_gg")
  expect_equal(ig_export_value_kind(ggiraph::girafe(ggobj = gg)), "plot_interactive")

  expect_true("parquet" %in% IG_EXPORT_FORMATS$data)
  expect_setequal(IG_EXPORT_FORMATS$object, c("rds", "rdata"))
  expect_equal(ig_format_ext("xlsx"), "xlsx")
  expect_equal(ig_format_ext("rdata"), "RData")
})

test_that("export path strips typed extensions and applies the format ext", {
  expect_equal(basename(ig_export_path("/tmp", "sales.csv", "parquet")), "sales.parquet")
  expect_equal(basename(ig_export_path("/tmp", "", "csv")), "export.csv")
})

# ── Dataset exports + round trips ──────────────────────────────────────────────

test_that("every dataset format writes a non-empty file", {
  dir <- export_tmpdir()
  tabs <- list(sales = sample_sales())
  for (fmt in IG_EXPORT_FORMATS$data) {
    res <- execute_export(list(source = "sales", format = fmt, dir = dir,
                               filename = "sales", overwrite = TRUE), tabs)
    expect_null(res$error, info = fmt)
    expect_true(file.exists(res$file), info = fmt)
    expect_gt(file.info(res$file)$size, 0, label = fmt)
  }
})

test_that("dataset round-trips preserve data (csv, tsv, parquet, feather, rds)", {
  dir <- export_tmpdir()
  df  <- sample_sales()
  tabs <- list(sales = df)
  rt <- function(fmt) execute_export(list(source = "sales", format = fmt, dir = dir,
                                          filename = "s", overwrite = TRUE), tabs)$file

  csv <- readr::read_csv(rt("csv"), show_col_types = FALSE)
  expect_equal(nrow(csv), nrow(df)); expect_equal(names(csv), names(df))
  tsv <- readr::read_tsv(rt("tsv"), show_col_types = FALSE)
  expect_equal(nrow(tsv), nrow(df))
  expect_equal(as.data.frame(arrow::read_parquet(rt("parquet")))$amount, df$amount)
  expect_equal(as.data.frame(arrow::read_feather(rt("feather")))$qty, df$qty)
  expect_equal(readRDS(rt("rds")), df)
})

test_that("column selection limits exported columns", {
  dir <- export_tmpdir()
  res <- execute_export(list(source = "sales", format = "csv", dir = dir,
                             filename = "cols", overwrite = TRUE,
                             columns = c("region", "amount")),
                        list(sales = sample_sales()))
  out <- readr::read_csv(res$file, show_col_types = FALSE)
  expect_equal(names(out), c("region", "amount"))
})

test_that("xlsx and json round-trip", {
  dir <- export_tmpdir()
  tabs <- list(sales = sample_sales())
  xres <- execute_export(list(source = "sales", format = "xlsx", dir = dir,
                              filename = "s", overwrite = TRUE), tabs)
  expect_equal(nrow(readxl::read_excel(xres$file)), nrow(sample_sales()))
  jres <- execute_export(list(source = "sales", format = "json", dir = dir,
                              filename = "s", overwrite = TRUE), tabs)
  expect_equal(length(jsonlite::fromJSON(jres$file)$region), nrow(sample_sales()))
})

test_that("large dataset exports succeed", {
  dir <- export_tmpdir()
  big <- data.frame(id = 1:50000, x = rnorm(50000), g = sample(letters, 50000, TRUE))
  res <- execute_export(list(source = "big", format = "parquet", dir = dir,
                             filename = "big", overwrite = TRUE), list(big = big))
  expect_null(res$error)
  expect_equal(nrow(as.data.frame(arrow::read_parquet(res$file))), 50000)
})

# ── Object exports ─────────────────────────────────────────────────────────────

test_that("object exports round-trip via rds and RData", {
  dir <- export_tmpdir()
  model <- lm(amount ~ qty, sample_sales())
  objs  <- list(fit = model)
  r1 <- execute_export(list(source = "fit", format = "rds", dir = dir,
                            filename = "fit", overwrite = TRUE), list(), objs)
  expect_equal(coef(readRDS(r1$file)), coef(model))
  r2 <- execute_export(list(source = "fit", format = "rdata", dir = dir,
                            filename = "fit", overwrite = TRUE), list(), objs)
  e <- new.env(); load(r2$file, envir = e)
  expect_true("fit" %in% ls(e))
})

# ── Plot / image exports ───────────────────────────────────────────────────────

test_that("static ggplot exports to raster and vector formats", {
  dir <- export_tmpdir()
  gg  <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  objs <- list(p = gg)
  for (fmt in c("png", "jpeg", "tiff", "svg", "pdf")) {
    res <- execute_export(list(source = "p", format = fmt, dir = dir, filename = "p",
                               overwrite = TRUE, width = 5, height = 4, dpi = 120),
                          list(), objs)
    expect_null(res$error, info = fmt)
    expect_gt(file.info(res$file)$size, 0, label = fmt)
  }
})

test_that("interactive girafe exports to html and svg; raster errors helpfully", {
  dir <- export_tmpdir()
  gg  <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  objs <- list(ip = ggiraph::girafe(ggobj = gg))
  for (fmt in c("html", "svg")) {
    res <- execute_export(list(source = "ip", format = fmt, dir = dir,
                               filename = "ip", overwrite = TRUE), list(), objs)
    expect_null(res$error, info = fmt)
    expect_true(file.exists(res$file), info = fmt)
  }
  res <- execute_export(list(source = "ip", format = "png", dir = dir,
                             filename = "ip", overwrite = TRUE), list(), objs)
  expect_match(res$error, "Interactive")
})

# ── Error handling ─────────────────────────────────────────────────────────────

test_that("export validates source, destination, and overwrite", {
  dir <- export_tmpdir()
  tabs <- list(sales = sample_sales())
  expect_match(execute_export(list(format = "csv", dir = dir), tabs)$error, "No source")
  expect_match(execute_export(list(source = "nope", format = "csv", dir = dir), tabs)$error,
               "not available")
  expect_match(execute_export(list(source = "sales", format = "csv", dir = ""), tabs)$error,
               "No destination")
  expect_match(execute_export(list(source = "sales", format = "csv",
               dir = file.path(dir, "nope")), tabs)$error, "does not exist")
  # write once, then overwrite guard
  execute_export(list(source = "sales", format = "csv", dir = dir,
                      filename = "g", overwrite = TRUE), tabs)
  guard <- execute_export(list(source = "sales", format = "csv", dir = dir,
                               filename = "g", overwrite = FALSE), tabs)
  expect_match(guard$error, "already exists")
})

# ── Code generation ────────────────────────────────────────────────────────────

test_that("generated export code is parseable and format-appropriate", {
  base <- list(source = "sales", dir = "out", filename = "sales", value_kind = "data")
  expect_match(build_export_code(c(base, list(format = "csv"))), "readr::write_csv")
  expect_match(build_export_code(c(base, list(format = "parquet"))), "arrow::write_parquet")
  expect_match(build_export_code(c(base, list(format = "xlsx"))), "writexl::write_xlsx")
  expect_match(build_export_code(c(base, list(format = "json"))), "jsonlite::write_json")
  # column subset emits dplyr::select
  expect_match(build_export_code(c(base, list(format = "csv", columns = c("a", "b")))),
               "dplyr::select")
  # object + plot
  expect_match(build_export_code(list(source = "fit", format = "rds",
               value_kind = "object", dir = "o", filename = "fit")), "saveRDS")
  expect_match(build_export_code(list(source = "p", format = "png", value_kind = "plot_gg",
               dir = "o", filename = "p")), "ggplot2::ggsave")
  # every emitted snippet parses
  for (fmt in IG_EXPORT_FORMATS$data) {
    code <- build_export_code(c(base, list(format = fmt)))
    expect_silent(parse(text = code))
  }
})

# ── Run-Flow / executor integration ───────────────────────────────────────────

test_that("export runs through the executor as a sink (no phantom output)", {
  dir   <- export_tmpdir()
  store <- new_test_store(list(sales = sample_sales()))
  add_test_task(store, "exp_1", "export",
    inputs = "sales", output = "",
    params = list(source = "sales", format = "csv", value_kind = "data",
                  dir = dir, filename = "sales", overwrite = TRUE))
  ok <- iso(run_task_from_store(store, "exp_1"))
  expect_true(ok)
  task <- iso(store$tasks[["exp_1"]])
  expect_equal(task$status, "success")
  expect_identical(task$outputs, list())              # sink — no flow output
  expect_true(file.exists(task$export_file))
  expect_match(task$r_code, "write_csv")
  expect_false("sales.csv" %in% names(iso(store$tables)))  # no phantom table
})
