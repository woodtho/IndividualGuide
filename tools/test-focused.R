args <- commandArgs(trailingOnly = TRUE)
if (.Platform$OS.type == "windows") Sys.setlocale("LC_CTYPE", ".UTF-8")
pandoc <- file.path(Sys.getenv("LOCALAPPDATA"), "Pandoc")
if (file.exists(file.path(pandoc, "pandoc.exe"))) Sys.setenv(RSTUDIO_PANDOC = pandoc)
pkgload::load_all(quiet = TRUE)
testthat::test_local(filter = if (length(args)) args[[1]] else NULL,
  reporter = "summary", stop_on_failure = TRUE)
