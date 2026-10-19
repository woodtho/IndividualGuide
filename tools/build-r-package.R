# Build distribution archives from package inputs only, avoiding local runtimes.
args <- commandArgs(TRUE)
if (.Platform$OS.type == "windows") Sys.setlocale("LC_CTYPE", ".UTF-8")
root <- normalizePath(".", winslash = "/")
output <- if (length(args)) args[[1L]] else "build/release"
dir.create(output, recursive = TRUE, showWarnings = FALSE)
output <- normalizePath(output, winslash = "/", mustWork = TRUE)
version <- unname(read.dcf("DESCRIPTION")[1L, "Version"])
staging <- tempfile("package-source-", tmpdir = file.path(root, "build"))
dir.create(staging, recursive = TRUE)
source <- file.path(staging, "IndividualGuide"); dir.create(source)
entries <- list.files(root, all.files = TRUE, no.. = TRUE, full.names = TRUE)
package_inputs <- c("DESCRIPTION", "NAMESPACE", "LICENSE", "LICENSE.md", "NEWS.md", ".Rbuildignore",
  "R", "inst", "man", "tests", "data", "src", "vignettes", "configure", "configure.win", "cleanup", "cleanup.win")
entries <- entries[basename(entries) %in% package_inputs]
excluded <- tools:::inRbuildignore(basename(entries), root) |
  basename(entries) %in% c("check", "..Rcheck", ".git", ".Rproj.user")
excluded[basename(entries) == ".Rbuildignore"] <- FALSE
if (!all(file.copy(entries[!excluded], source, recursive = TRUE))) stop("Could not stage R package source.")
old <- setwd(output)
executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "R.exe" else "R")
status <- system2(executable, c("CMD", "build", "--no-manual", "--no-build-vignettes", shQuote(source)))
if (status != 0L) stop("Source package build failed.")
archive <- file.path(output, paste0("IndividualGuide_", version, ".tar.gz"))
stopifnot(file.exists(archive))
if (.Platform$OS.type == "windows") {
  library <- file.path(staging, "library"); dir.create(library)
  status <- system2(executable, c("CMD", "INSTALL", "--no-multiarch", "--no-staged-install", "--without-keep.source",
    paste0("--library=", shQuote(library)), shQuote(archive)))
  if (status != 0L) stop("Windows R package build failed.")
  tools:::.installMD5sums(file.path(library, "IndividualGuide"))
  zip::zipr(file.path(output, paste0("IndividualGuide_", version, ".zip")), "IndividualGuide", root = library)
  stopifnot(file.exists(file.path(output, paste0("IndividualGuide_", version, ".zip"))))
}
setwd(old)
cat("R package archives built in", output, "\n")
