.libPaths(c("build/staging/runtime/R/library", .libPaths()))
Sys.setlocale("LC_CTYPE", ".UTF-8")
testthat::test_dir("tests/testthat", filter = if ("--all" %in% commandArgs(TRUE)) NULL else "console",
  package = "IndividualGuide", load_package = "installed", reporter = "summary")
