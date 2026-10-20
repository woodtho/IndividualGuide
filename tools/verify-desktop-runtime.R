# Verify the installed R database against current source without rebuilding
# dependencies or relying on the developer's loaded package namespace.
args <- commandArgs(trailingOnly = TRUE)
Sys.setlocale("LC_CTYPE", ".UTF-8")
runtime <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
root <- normalizePath(".", winslash = "/")
.libPaths(file.path(runtime, "R/library"), include.site = FALSE)
ns <- loadNamespace("IndividualGuide")
definitions <- list()
for (file in list.files("R", pattern = "[.]R$", full.names = TRUE)) {
  for (expr in as.list(parse(file, keep.source = FALSE, encoding = "UTF-8"))) {
    if (is.call(expr) && identical(expr[[1L]], as.name("<-")) && is.symbol(expr[[2L]]) &&
        is.call(expr[[3L]]) && identical(expr[[3L]][[1L]], as.name("function")))
      definitions[[as.character(expr[[2L]])]] <- eval(expr[[3L]], envir = baseenv())
  }
}
signature <- function(fn) list(formals = deparse(formals(fn), width.cutoff = 100L), body = deparse(body(fn), width.cutoff = 100L))
differences <- names(definitions)[!vapply(names(definitions), function(name)
  exists(name, ns, inherits = FALSE) && identical(signature(definitions[[name]]), signature(get(name, ns))), logical(1))]
assets <- list.files("inst/app/www", recursive = TRUE, pattern = "[.](js|json|css)$")
version_expression <- Filter(function(expr) is.call(expr) && identical(expr[[1L]], as.name("<-")) &&
  identical(expr[[2L]], as.name("PROJECT_VERSION")), as.list(parse("R/project.R", encoding = "UTF-8")))[[1L]]
constant_matches <- identical(eval(version_expression[[3L]], baseenv()), get("PROJECT_VERSION", ns))
release_version <- unname(read.dcf("DESCRIPTION")[1L, "Version"])
identity_matches <- identical(as.character(utils::packageVersion("IndividualGuide")), release_version) &&
  identical(jsonlite::read_json(file.path(runtime,"runtime.json"))$app_version, release_version) &&
  identical(jsonlite::read_json(file.path(runtime,"R/library/IndividualGuide/build-info.json"))$version, release_version)
asset_differences <- assets[!vapply(assets, function(file) identical(
  unname(tools::md5sum(file.path(root, "inst/app/www", file))),
  unname(tools::md5sum(file.path(runtime, "R/library/IndividualGuide/app/www", file)))), logical(1))]
example_files <- list.files("inst/examples", recursive = TRUE)
example_differences <- example_files[!vapply(example_files, function(file) identical(
  unname(tools::md5sum(file.path(root, "inst/examples", file))),
  unname(tools::md5sum(file.path(runtime, "R/library/IndividualGuide/examples", file)))), logical(1))]
if (length(example_differences)) asset_differences <- c(asset_differences, paste0("examples/", example_differences))
result <- list(ok = !length(differences) && !length(asset_differences) && constant_matches && identity_matches,
  projectFormatMatches = constant_matches, releaseIdentityMatches = identity_matches, functions = length(definitions),
  differences = differences, asset_differences = asset_differences, bundledExampleFiles = length(example_files), runtime = runtime)
jsonlite::write_json(result, args[[2L]], pretty = TRUE, auto_unbox = TRUE)
stopifnot(result$ok)
cat(length(definitions), "R functions and all workspace assets match source.\n")
