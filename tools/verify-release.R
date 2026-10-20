# Fail before publication if identity or required distribution assets differ.
args <- commandArgs(TRUE)
stopifnot(length(args) >= 1L)
output <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
version <- unname(read.dcf("DESCRIPTION")[1L, "Version"])
desktop <- jsonlite::read_json("tools/desktop/package.json")
lock <- jsonlite::read_json("tools/desktop/package-lock.json")
stopifnot(identical(version, desktop$version), identical(version, lock$version),
  identical(version, lock$packages[[which(names(lock$packages) == "")]]$version))
if (length(args) >= 2L && !identical(args[[2L]], paste0("v", version))) stop("Release tag must match package version.")
names <- c(paste0("IndividualGuide_", version, ".tar.gz"), paste0("IndividualGuide_", version, ".zip"),
  paste0("IndividualGuide-", version, "-Setup-Windows-x64.exe"))
book_languages <- c("en-CA","fr-CA")
book_formats <- c("html","pdf","epub","docx")
book_names <- unlist(lapply(book_languages,function(language)paste0("Individual-Guide-Handbook-",language,".",book_formats)),use.names=FALSE)
names <- c(names,book_names)
files <- file.path(output, names)
stopifnot(all(file.exists(files)), all(file.info(files)$size > 0))
for(language in book_languages){
  directory <- file.path("docs/handbook",if(language=="fr-CA")"fr-CA" else "")
  book <- jsonlite::read_json(file.path(directory,"manifest.json"))
  stopifnot(identical(book$language,language),identical(book$packageVersion,version))
  for(format in book_formats){
    staged <- file.path(output,paste0("Individual-Guide-Handbook-",language,".",format))
    source <- file.path(directory,paste0("Individual-Guide-Handbook.",format))
    stopifnot(identical(digest::digest(file=staged,algo="sha256"),digest::digest(file=source,algo="sha256")))
  }
}
entries <- utils::untar(files[[1L]], list = TRUE)
stopifnot(!any(grepl("/(build|artifacts|tools|docs|[.]git)/|PROJECT_AUDIT|COMPLETION_REPORT", entries)))
hashes <- vapply(files, function(file) digest::digest(file = file, algo = "sha256"), character(1))
writeLines(paste(hashes, names, sep = "  "), file.path(output, "SHA256SUMS.txt"))
metadata <- jsonlite::read_json("inst/build-info.json")
stopifnot(identical(metadata$version, version))
if (isTRUE(metadata$dirty)) stop("Release builds must use committed, clean source.")
head <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)
if (!identical(metadata$commit, head[[1L]]) ||
    length(system2("git", c("status", "--porcelain", "--untracked-files=normal"), stdout = TRUE)))
  stop("Commit source changes and rebuild before publishing a release.")
validation <- tempfile("release-package-check-", tmpdir = "build")
dir.create(validation, recursive = TRUE)
source <- file.path(validation, "source"); dir.create(source)
utils::untar(files[[1L]], files = "IndividualGuide/inst/build-info.json", exdir = source)
source_info <- jsonlite::read_json(file.path(source, "IndividualGuide/inst/build-info.json"))
stopifnot(identical(source_info$commit, metadata$commit), identical(source_info$version, version), !source_info$dirty)
library <- file.path(validation, "library"); dir.create(library)
utils::install.packages(files[[2L]], repos = NULL, type = "win.binary", lib = library)
library <- normalizePath(library, winslash = "/")
binary <- callr::r(function(library) {
  .libPaths(c(library, .libPaths()))
  Sys.setenv(IG_USER_DATA = tempfile("ig-release-package-profile-"))
  ns <- loadNamespace("IndividualGuide")
  list(version = as.character(getNamespaceVersion(ns)),
    task_count = length(get("IG_ENABLED_TASK_IDS", ns)),
    examples = length(get("ig_example_catalog", ns)()),
    report_logging = "include_log" %in% names(get("default_report_params", ns)("report")),
    build = jsonlite::read_json(system.file("build-info.json", package = "IndividualGuide")))
}, list(library), system_profile = FALSE, user_profile = FALSE)
stopifnot(identical(binary$version, version), binary$task_count == 58L, binary$examples == 22L,
  binary$report_logging, identical(binary$build$commit, metadata$commit), !binary$build$dirty)
result <- list(version = version, source_commit = metadata$commit, built_at = metadata$built_at,
  dependencies_sha256 = metadata$dependencies_sha256,
  checks = list(source_identity = TRUE, binary_installs = TRUE, binary_namespace = TRUE,
    binary_task_count = binary$task_count, binary_examples = binary$examples, report_logging = TRUE,
    bilingual_handbooks = TRUE,book_languages = book_languages),
  assets = lapply(seq_along(files), function(i) list(file = names[[i]], bytes = unname(file.info(files[[i]])$size), sha256 = hashes[[i]])))
jsonlite::write_json(result, file.path(output, "release-manifest.json"), pretty = TRUE, auto_unbox = TRUE)
cat("Verified release", version, "with", length(files), "assets.\n")
