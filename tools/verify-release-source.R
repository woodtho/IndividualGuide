Sys.setlocale("LC_CTYPE", ".UTF-8")
Sys.setenv(LC_ALL = "English_Canada.utf8", LANG = "English_Canada.utf8")
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
staged <- file.path(args[[1L]], "source", "IndividualGuide")
roots <- c("R", "tests", "man", "inst", "DESCRIPTION", "NAMESPACE", "LICENSE", ".Rbuildignore")
files <- unlist(lapply(roots, function(root) {
  if (dir.exists(root)) list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE) else root
}), use.names = FALSE)
hash <- function(path) digest::digest(file = path, algo = "sha256")
differences <- files[!vapply(files, function(file) file.exists(file.path(staged, file)) &&
  identical(hash(file), hash(file.path(staged, file))), logical(1))]
jsonlite::write_json(list(ok = !length(differences), files = length(files), differences = differences,
  checkedSource = staged), "artifacts/review/checked-source.json", auto_unbox = TRUE, pretty = TRUE)
stopifnot(!length(differences))

pkgload::load_all(quiet = TRUE, export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
namespace <- asNamespace("IndividualGuide")
functions <- unique(unlist(lapply(list.files("R", pattern = "[.]R$", full.names = TRUE), function(file) {
  unlist(lapply(as.list(parse(file, keep.source = FALSE)), function(x) {
    if (is.call(x) && identical(x[[1L]], as.name("<-")) && is.symbol(x[[2L]]) &&
        is.call(x[[3L]]) && identical(x[[3L]][[1L]], as.name("function"))) as.character(x[[2L]]) else character(0)
  }))
})))
definitions <- function(namespace, functions) stats::setNames(lapply(functions, function(name) {
  fn <- get(name, namespace, inherits = FALSE)
  list(formals = paste(deparse(formals(fn), width.cutoff = 100L), collapse = "\n"),
    body = paste(deparse(body(fn), width.cutoff = 100L), collapse = "\n"))
}), functions)
expected <- definitions(namespace, functions)
library <- normalizePath("build/staging/runtime/R/library", winslash = "/")
actual <- callr::r(function(library, functions, definitions) {
  .libPaths(c(library, .libPaths()), include.site = FALSE)
  definitions(loadNamespace("IndividualGuide"), functions)
}, list(library, functions, definitions), system_profile = FALSE, user_profile = FALSE)
differences <- functions[!vapply(functions, function(name) identical(expected[[name]], actual[[name]]), logical(1))]
jsonlite::write_json(list(ok = !length(differences), functions = length(functions), differences = differences,
  runtimeLibrary = library), "artifacts/review/runtime-source.json", auto_unbox = TRUE, pretty = TRUE)
stopifnot(!length(differences))
manifest_file <- "build/staging/runtime/runtime.json"
manifest <- jsonlite::read_json(manifest_file)
manifest$built_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
jsonlite::write_json(manifest, manifest_file, auto_unbox = TRUE, pretty = TRUE)
dir.create("artifacts/review/release", showWarnings = FALSE)
version <- unname(read.dcf("DESCRIPTION")[1L, "Version"])
filename <- paste0("IndividualGuide_", version, ".tar.gz")
archive <- file.path("artifacts/review/release", filename)
stopifnot(file.copy(file.path("build/release", filename), archive, overwrite = TRUE))
writeLines(paste(hash(archive), basename(archive)), paste0(archive, ".sha256"))
cat(length(files), "checked files and", length(functions), "packaged functions match current source.\n")
