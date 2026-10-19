.libPaths(c("build/staging/runtime/R/library", .libPaths()))
Sys.setlocale("LC_CTYPE", ".UTF-8")
args <- commandArgs(TRUE)
testthat::test_local(".", filter = if ("--all" %in% args) NULL else
  if (length(args)) args[[1L]] else "product-readiness", reporter = "summary")
