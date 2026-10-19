args <- commandArgs(TRUE)
root <- normalizePath(".", winslash = "/")
runtime <- if (length(args)) normalizePath(args[[1L]], winslash = "/", mustWork = TRUE) else NULL
version <- unname(read.dcf("DESCRIPTION")[1L, "Version"])
desktop <- jsonlite::read_json("tools/desktop/package.json")
stopifnot(identical(version, desktop$version))
commit <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)
dirty <- length(system2("git", c("status", "--porcelain", "--untracked-files=normal"), stdout = TRUE)) > 0L
packages <- if (!is.null(runtime)) read.csv(file.path(runtime, "packages.csv")) else NULL
info <- list(version = version, commit = commit[[1L]], dirty = dirty,
  built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), R = R.version.string,
  dependencies_sha256 = if (file.exists("renv.lock")) digest::digest(file = "renv.lock", algo = "sha256") else NULL)
jsonlite::write_json(info, "inst/build-info.json", pretty = TRUE, auto_unbox = TRUE, null = "null")
if (!is.null(runtime)) {
  manifest_path <- file.path(runtime, "runtime.json")
  manifest <- jsonlite::read_json(manifest_path)
  manifest$app_version <- version; manifest$built_at <- info$built_at; manifest$source_commit <- info$commit
  manifest$source_modified <- dirty; manifest$dependencies_sha256 <- info$dependencies_sha256
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  if (!is.null(packages)) {
    packages$Version[packages$Package == "IndividualGuide"] <- version
    write.csv(packages, file.path(runtime, "packages.csv"), row.names = FALSE)
  }
}
cat("Build metadata:", version, substr(info$commit, 1L, 12L), if (dirty) "modified" else "clean", "\n")
