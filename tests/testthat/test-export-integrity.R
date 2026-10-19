test_that("generated exports honor special source and column names, subsets and overwrite", {
  directory <- tempfile("exports-")
  dir.create(directory)
  data <- data.frame("a column" = 1:3, other = letters[1:3], check.names = FALSE)
  tables <- setNames(list(data), "source's data")
  for (format in c("csv", "rds", "rdata", "xlsx", "json")) {
    p <- default_export_params()
    p$source <- "source's data"
    p$columns <- "a column"
    p$format <- format
    p$dir <- directory
    p$filename <- paste0("result-", format)
    p$overwrite <- TRUE
    result <- execute_export(p, tables)
    expect_null(result$error, info = format)
    env <- list2env(tables, parent = globalenv())
    eval(parse(text = build_export_code(p)), env)
    if (format == "csv") expect_identical(readr::read_csv(result$file, show_col_types = FALSE)$`a column`, c(1, 2, 3))
    if (format == "rds") expect_identical(readRDS(result$file), data["a column"])
    if (format == "rdata") {
      loaded <- new.env()
      load(result$file, loaded)
      expect_identical(get(make.names(p$source), loaded), data["a column"])
    }
    p$overwrite <- FALSE
    expect_error(eval(parse(text = build_export_code(p)), env), "already exists")
  }
})

test_that("append cannot bypass overwrite protection for formats that do not append", {
  directory <- tempfile("exports-")
  dir.create(directory)
  p <- list(source = "data", format = "rds", dir = directory, filename = "keep", overwrite = TRUE)
  expect_null(execute_export(p, list(data = data.frame(x = 1)))$error)
  path <- ig_export_path(directory, "keep", "rds")
  p$overwrite <- FALSE
  p$append <- TRUE
  expect_match(execute_export(p, list(data = data.frame(x = 2)))$error, "[Aa]ppend")
  expect_identical(readRDS(path), data.frame(x = 1))
})

test_that("export rejects stale column selections rather than silently writing all data", {
  directory <- tempfile("exports-")
  dir.create(directory)
  p <- list(source = "data", format = "csv", dir = directory, filename = "selected", columns = "gone")
  expect_match(execute_export(p, list(data = data.frame(private = 1)))$error, "[Cc]olumn")
  expect_false(file.exists(file.path(directory, "selected.csv")))
})

test_that("a failed overwrite preserves the prior exported file", {
  directory <- tempfile("exports-")
  dir.create(directory)
  p <- list(source = "data", format = "csv", dir = directory, filename = "keep", overwrite = TRUE)
  result <- execute_export(p, list(data = data.frame(x = 1)))
  before <- readBin(result$file, "raw", n = file.info(result$file)$size)
  testthat::local_mocked_bindings(ig_write_data = function(df, file, ...) {
    writeLines("partial data", file)
    stop("simulated write failure")
  })
  expect_match(execute_export(p, list(data = data.frame(x = 2)))$error, "simulated write failure")
  expect_identical(readBin(result$file, "raw", n = file.info(result$file)$size), before)
})
test_that("interactive HTML exports contain their dependencies in one file", {
  plot <- ggiraph::girafe(ggobj = ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point())
  directory <- tempfile("portable_export_"); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  p <- default_export_params()
  p$source <- "widget"; p$format <- "html"; p$dir <- directory; p$filename <- "chart"
  result <- execute_export(p, objects = list(widget = plot))
  expect_null(result$error)
  html <- paste(readLines(result$file, warn = FALSE), collapse = "\n")
  expect_match(html, "data:application/javascript;base64,", fixed = TRUE)
  expect_false(grepl('(src|href)="[^"#:]+_files/', html))
  expect_setequal(list.files(directory), "chart.html")
})
