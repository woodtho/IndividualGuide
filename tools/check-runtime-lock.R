args <- commandArgs(TRUE)
library <- if (length(args)) args[[1L]] else .libPaths()
lock <- jsonlite::read_json("renv.lock")
if (!identical(as.character(getRversion()), lock$R$Version)) stop("Use R ", lock$R$Version, " for release builds.")
reference <- jsonlite::read_json("inst/options/r-options.json")
if (!identical(reference$R, lock$R$Version) || length(reference$options) < 100L)
  stop("Regenerate the R options reference with tools/build-r-options-catalog.R using the locked R version.")
installed <- installed.packages(lib.loc = library)
expected <- vapply(lock$Packages, `[[`, character(1), "Version")
if (length(args) && file.exists(file.path(dirname(dirname(args[[1L]])), "packages.csv"))) {
  shipped <- read.csv(file.path(dirname(dirname(args[[1L]])), "packages.csv"))$Package
  expected <- expected[intersect(names(expected), shipped)]
}
missing <- setdiff(names(expected), rownames(installed))
different <- intersect(names(expected), rownames(installed))
different <- different[installed[different, "Version"] != expected[different]]
if (length(c(missing, different))) stop("Runtime does not match renv.lock: ", paste(c(missing, different), collapse = ", "), ". Restore the locked release library before building.")
cat(length(expected), "locked R dependencies match.\n")
