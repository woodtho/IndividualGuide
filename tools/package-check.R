Sys.setlocale("LC_CTYPE", ".UTF-8")
Sys.setenv(LC_ALL = "English_Canada.utf8", LANG = "English_Canada.utf8")
pandoc <- file.path(Sys.getenv("LOCALAPPDATA"), "Pandoc")
if (file.exists(file.path(pandoc, "pandoc.exe"))) Sys.setenv(RSTUDIO_PANDOC = pandoc)
roxygen2::roxygenise()
destination <- file.path("artifacts", "audit", paste0("package-check-", format(Sys.time(), "%Y%m%d-%H%M%S")))
dir.create(destination, recursive = TRUE, showWarnings = FALSE)
# Windows R CMD build copies its entire input directory before applying
# .Rbuildignore. Exclude large local build artifacts before that initial copy.
root <- normalizePath(".", winslash = "/")
staged <- file.path(destination, "source", "IndividualGuide")
dir.create(staged, recursive = TRUE)
entries <- list.files(root, all.files = TRUE, no.. = TRUE, full.names = TRUE)
excluded <- tools:::inRbuildignore(basename(entries), root) |
  basename(entries) %in% c("check", "..Rcheck", ".git", ".Rproj.user")
excluded[basename(entries) == ".Rbuildignore"] <- FALSE
if (!all(file.copy(entries[!excluded], staged, recursive = TRUE, copy.date = TRUE)))
  stop("Could not stage package source for checking.")
executable <- file.path(R.home("bin"), "R.exe")
status <- system2(executable, c("CMD", "build", "--no-manual", "--no-build-vignettes", shQuote(staged)))
if (status != 0L) stop("Package build failed.")
package <- list.files(pattern = "^IndividualGuide_.*[.]tar[.]gz$", full.names = TRUE)
package <- package[which.max(file.info(package)$mtime)]
status <- system2(executable, c("CMD", "check", "--no-manual", paste0("--output=", shQuote(destination)), shQuote(package)))
quit(status = status)
