test_that("fallback HTML embeds figures and interactive tables without sidecars", {
  testthat::local_mocked_bindings(ig_report_pandoc_available = function() FALSE)
  p <- list(title = '<Quarter "A">', format = "html", items = list(
    list(name = "plot", heading = "Chart"),
    list(name = "table", heading = "Table", render = "datatable")))
  plot <- ggplot2::ggplot(data.frame(x = 1:3, y = 3:1), ggplot2::aes(x, y)) + ggplot2::geom_point()
  result <- execute_report(p, list(table = data.frame(x = 1:3)), list(plot = plot))
  expect_null(result$error)
  html <- paste(readLines(result$report_path, warn = FALSE), collapse = "\n")
  expect_match(html, "data:image/png;base64,", fixed = TRUE)
  expect_match(html, "srcdoc=", fixed = TRUE)
  expect_match(html, "data:application/javascript;base64,", fixed = TRUE)
  expect_false(grepl('(?:src|href)="(?:figure_|widget_|widget_files/)', html, perl = TRUE))
  expect_match(html, "&lt;Quarter &quot;A&quot;&gt;", fixed = TRUE)
  expect_true(all(file.exists(file.path(dirname(result$report_path), c("report.Rmd", "data.rds")))))
  expect_match(result$warnings, "built-in", fixed = TRUE)
})

test_that("report fallback handles NULL objects and rejects unsupported formats", {
  testthat::local_mocked_bindings(ig_report_pandoc_available = function() FALSE)
  p <- list(format = "html", items = list(list(name = "nothing")))
  res <- execute_report(p, list(), list(nothing = NULL))
  expect_null(res$error)
  expect_match(paste(readLines(res$report_path), collapse = ""), "NULL")
  p$format <- "word"
  expect_match(execute_report(p, list(), list(nothing = NULL))$error, "Word reports require Pandoc")
  p$format <- "pdf"
  expect_match(execute_report(p, list(), list(nothing = NULL))$error, "HTML or Word")
})

test_that("quoted metadata and internal-looking output names render in HTML and Word", {
  skip_if_not(ig_report_pandoc_available(), "Pandoc not installed")
  title <- "A \\ path: \"quoted\"\nsecond line"
  p <- list(title = title, author = "A \\ B", format = "html",
    items = list(list(name = ".ig_report_values", heading = "A \\ B \"C\"")))
  data <- list(.ig_report_values = data.frame(`odd \\ \" name` = 1:3, check.names = FALSE))
  for (format in c("html", "word")) {
    p$format <- format
    result <- execute_report(p, data)
    expect_null(result$error, info = format)
    expect_true(file.exists(result$report_path), info = format)
    if (format == "word") expect_true("word/document.xml" %in% utils::unzip(result$report_path, list = TRUE)$Name)
  }
})

test_that("generated report code runs in a clean R process without the application", {
  skip_if_not(ig_report_pandoc_available(), "Pandoc not installed")
  directory <- tempfile("report_codegen_")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  result_file <- file.path(directory, "result.rds")
  script <- file.path(directory, "report.R")
  p <- list(title = "Standalone", format = "html", output_name = "finished report",
    items = list(list(name = "source \\ ` name", heading = 'Quoted "heading"')))
  source_name <- p$items[[1]]$name
  writeLines(c('if (.Platform$OS.type == "windows") Sys.setlocale("LC_CTYPE", ".UTF-8")',
    paste0('setwd(', code_literal(directory), ')'),
    paste0('assign(', code_literal(source_name), ', data.frame(x = 1:3))'),
    build_report_code(p),
    paste0('saveRDS(list(path = `finished report`, namespaces = loadedNamespaces()), ', code_literal(result_file), ')')),
    script, useBytes = TRUE)
  executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  output <- system2(executable, c("--vanilla", shQuote(script)), stdout = TRUE, stderr = TRUE)
  expect_null(attr(output, "status"), info = paste(output, collapse = "\n"))
  expect_true(file.exists(result_file))
  if (!file.exists(result_file)) return(invisible(NULL))
  result <- readRDS(result_file)
  expect_false("IndividualGuide" %in% result$namespaces)
  expect_true(file.exists(result$path))
  expect_true(file.exists(file.path(dirname(result$path), "report.Rmd")))
})
