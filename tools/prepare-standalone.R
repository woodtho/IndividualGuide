args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) %in% c(2L, 3L))
Sys.setlocale("LC_CTYPE", ".UTF-8")
root <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
pandoc <- normalizePath(args[[2]], winslash = "/", mustWork = TRUE)
stage <- if (length(args) == 3L) args[[3L]] else file.path(root, "build/staging/runtime")
stage <- normalizePath(stage, winslash = "/", mustWork = FALSE)
dir.create(file.path(root, "build"), showWarnings = FALSE)
build <- normalizePath(file.path(root, "build"), winslash = "/", mustWork = TRUE)
if (!startsWith(stage, paste0(build, "/"))) stop("Runtime staging must stay under build/.")
if (length(list.files(stage, all.files = TRUE, no.. = TRUE)))
  stop("Runtime staging is not empty. Supply a fresh directory under build/; existing builds are preserved.")
dir.create(stage, recursive = TRUE, showWarnings = FALSE)
options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 900)
description <- read.dcf(file.path(root, "DESCRIPTION"))
imports <- trimws(strsplit(gsub("\\s*\\([^)]*\\)", "", description[1, "Imports"]), ",")[[1]])
sources <- paste(vapply(list.files(file.path(root, "R"), "[.]R$", full.names = TRUE),
  function(path) paste(readLines(path, warn = FALSE), collapse = "\n"), character(1)), collapse = "\n")
namespaced <- unique(sub("::+$", "", regmatches(sources, gregexpr("[A-Za-z][A-Za-z0-9.]*::+", sources))[[1]]))
development <- c("pkgload", "testthat", "chromote", "shinytest2", "devtools", "roxygen2", "rcmdcheck")
requested <- setdiff(unique(c(imports, namespaced, "rmarkdown", "knitr", "odbc", "RSQLite",
  "duckdb", "survival", "forecast", "bit64", "hms", "blob", "keyring", "RPostgres")), c(development, "R"))
installed <- installed.packages()
missing <- setdiff(requested, rownames(installed))
if (length(missing)) {
  cat("Installing missing runtime dependencies:", paste(missing, collapse = ", "), "\n")
  install.packages(missing, type = "binary", Ncpus = 2L)
  installed <- installed.packages()
}
missing <- setdiff(requested, rownames(installed))
if (length(missing)) stop("Missing runtime dependencies: ", paste(missing, collapse = ", "))
dependencies <- tools::package_dependencies(requested, db = installed,
  which = c("Depends", "Imports"), recursive = TRUE)
base_packages <- setdiff(installed[!is.na(installed[, "Priority"]) & installed[, "Priority"] == "base", "Package"],
  c("tcltk", "translations"))
packages <- sort(setdiff(unique(c(requested, unlist(dependencies), base_packages)), "R"))
missing <- setdiff(packages, rownames(installed))
if (length(missing)) stop("The dependency closure is incomplete: ", paste(missing, collapse = ", "))

copy_tree <- function(from, to) {
  dir.create(to, recursive = TRUE, showWarnings = FALSE)
  entries <- list.files(from, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  if (length(entries) && !all(file.copy(entries, to, recursive = TRUE, copy.date = TRUE)))
    stop("Could not copy runtime component: ", from)
}
rhome <- file.path(stage, "R")
for (directory in c("bin", "etc", "modules", "share")) copy_tree(file.path(R.home(), directory), file.path(rhome, directory))
dir.create(file.path(rhome, "doc"), recursive = TRUE)
for (name in c("COPYING", "COPYRIGHTS", "AUTHORS", "CRAN_mirrors.csv"))
  file.copy(file.path(R.home(), "doc", name), file.path(rhome, "doc", name))
file.copy(file.path(R.home(), "COPYING"), rhome)
# The desktop shell replaces R's console and GUI launchers. Keep Rscript,
# Rterm, R.dll and their runtime libraries, but omit compilers, headers and IDEs.
unlink(file.path(rhome, "bin/x64", c("Rgui.exe", "RSetReg.exe", "Rcmd.exe", "Rfe.exe")))
library <- file.path(rhome, "library"); dir.create(library)
for (name in packages) {
  cat("Bundling", name, installed[name, "Version"], "\n")
  copy_tree(file.path(installed[name, "LibPath"], name), file.path(library, name))
}
cat("Installing the app into its private runtime library...\n")
# The fresh private build library has no live consumers. Avoid the final
# directory rename, which cloud sync can deny during a staged installation.
status <- system2(file.path(R.home("bin"), "R.exe"), c("CMD", "INSTALL", "--no-multiarch",
  "--no-staged-install", "--no-docs", "--no-help", "--no-demo", "--no-test-load",
  paste0("--library=", shQuote(library)), shQuote(root)))
if (status != 0L) stop("Installing IndividualGuide into the runtime failed.")
for (name in c(packages, "IndividualGuide")) {
  # Keep R/data databases, native libraries, licenses, fonts, templates, and web
  # assets. These top-level folders contain development material only.
  unlink(file.path(library, name, c("help", "html", "doc", "tests", "demo", "include")), recursive = TRUE)
}
dir.create(file.path(stage, "pandoc"))
stopifnot(file.copy(pandoc, file.path(stage, "pandoc/pandoc.exe")))
stopifnot(file.copy(file.path(root, "tools/desktop/startup.R"), file.path(stage, "startup.R")))
stopifnot(file.copy(file.path(root, "R/package_library.R"), file.path(stage, "package-library.R")))
stopifnot(file.copy(file.path(root, "inst/options/bootstrap.R"), file.path(stage, "options-bootstrap.R")))
dir.create(file.path(stage, "licenses"))
file.copy(file.path(root, "LICENSE.md"), file.path(stage, "licenses/IndividualGuide-MIT.txt"))
file.copy(file.path(R.home(), "doc/COPYING"), file.path(stage, "licenses/R-COPYING.txt"))
file.copy(file.path(R.home(), "doc/COPYRIGHTS"), file.path(stage, "licenses/R-COPYRIGHTS.txt"))
manifest <- as.data.frame(installed[packages, c("Package", "Version", "License")], stringsAsFactors = FALSE)
manifest <- rbind(manifest, data.frame(Package = "IndividualGuide", Version = description[1, "Version"], License = description[1, "License"]))
write.csv(manifest, file.path(stage, "packages.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(manifest, file.path(root, "build/packages.csv"), row.names = FALSE, fileEncoding = "UTF-8")
writeLines(c("Bundled third-party components",
  paste0("R ", getRversion(), " - https://www.r-project.org/ - see R-COPYING.txt and R-COPYRIGHTS.txt"),
  "Pandoc - https://pandoc.org/ - GPL-2.0-or-later; source: https://github.com/jgm/pandoc",
  "Electron/Chromium - see LICENSE.electron.txt and LICENSES.chromium.html alongside the unpacked executable.",
  "R package versions/licenses are listed in packages.csv. Original DESCRIPTION/LICENSE files remain in each package directory.",
  "Package sources: https://cran.r-project.org/src/contrib/ and https://cran.r-project.org/src/contrib/Archive/"),
  file.path(stage, "licenses/THIRD-PARTY-NOTICES.txt"))
jsonlite::write_json(list(app_version = unname(description[1, "Version"]), r_version = as.character(getRversion()),
  platform = R.version$platform, packages = nrow(manifest),
  source = "This runtime contains installed R packages, not a development checkout.",
  built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")), file.path(stage, "runtime.json"), auto_unbox = TRUE, pretty = TRUE)
cat("Prepared", nrow(manifest), "packages at", stage, "\n")
