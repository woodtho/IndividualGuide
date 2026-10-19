options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 600)
description <- read.dcf("DESCRIPTION")
deps <- strsplit(gsub("\\s*\\([^)]*\\)", "", description[1, "Imports"]), ",")[[1]]
deps <- unique(c(trimws(deps), "testthat", "chromote", "shinytest2", "rmarkdown", "knitr", "RSQLite", "odbc", "duckdb", "survival", "forecast", "roxygen2", "rcmdcheck"))
missing <- deps[!vapply(deps, requireNamespace, logical(1), quietly = TRUE)]
cat("Installing:", paste(missing, collapse = ", "), "\n")
if (length(missing)) install.packages(missing, type = "binary", Ncpus = 4)
missing <- deps[!vapply(deps, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Still missing: ", paste(missing, collapse = ", "))
