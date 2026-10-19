# Run explicitly to update the release lock from the verified private runtime.
# Builds check this file; they never silently update dependency versions.
options(repos = c(CRAN = "https://cloud.r-project.org"), renv.config.auto.snapshot = FALSE)
library <- normalizePath("build/staging/runtime/R/library", winslash = "/", mustWork = TRUE)
if (!requireNamespace("renv", quietly = TRUE)) stop("Install renv in the development library first.")
packages <- read.csv("build/staging/runtime/packages.csv")$Package
base <- rownames(installed.packages(lib.loc = library, priority = "base"))
renv::snapshot(project = getwd(), library = c(library, .libPaths()), packages = setdiff(packages, c(base, "IndividualGuide")),
  lockfile = "renv.lock", prompt = FALSE)
