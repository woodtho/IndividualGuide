Sys.setlocale("LC_CTYPE", ".UTF-8")
Sys.setenv(LC_ALL = "English_Canada.utf8", LANG = "English_Canada.utf8")
pkgload::load_all(quiet = TRUE)
args <- commandArgs(trailingOnly = TRUE)
filter <- if (length(args)) args[[1L]] else "task-logging|background-execution"
testthat::test_local(filter = filter, reporter = "summary", stop_on_failure = TRUE)
