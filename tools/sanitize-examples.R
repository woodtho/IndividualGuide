# Remove build-machine identity from the distributable tutorial snapshots.
# Only bundled examples are touched; never run this against user projects.
args <- commandArgs(TRUE)
if (.Platform$OS.type == "windows") Sys.setlocale("LC_CTYPE", ".UTF-8")
sanitize_example_text <- function(text) {
  text <- gsub("[A-Za-z]:[/\\\\]+Users[/\\\\]+[^/\\\\\"<>[:space:]]+", "@example-user", text, perl = TRUE)
  user <- Sys.info()[["user"]]
  if (!is.na(user) && nzchar(user)) text <- gsub(paste0('"', user, '"'), '"Example author"', text, fixed = TRUE)
  text
}
sanitize_example_file <- function(path) {
  text <- readLines(path, warn = FALSE, encoding = "UTF-8")
  clean <- sanitize_example_text(text)
  if (!identical(text, clean)) writeLines(clean, path, useBytes = TRUE)
}
sanitize_example_native <- function(value) {
  seen <- new.env(parent = emptyenv())
  walk <- function(value) {
    if (is.character(value)) {
      value <- sanitize_example_text(value)
      user <- Sys.info()[["user"]]
      if (!is.na(user) && nzchar(user)) value[value == user] <- "Example author"
    }
    if (is.environment(value)) {
      if (isNamespace(value) || identical(value, globalenv()) || identical(value, baseenv()) || identical(value, emptyenv())) return(value)
      key <- format(value)
      if (exists(key, seen, inherits = FALSE)) return(value)
      assign(key, TRUE, seen)
      for (name in ls(value, all.names = TRUE)) {
        if (name == "..." || bindingIsActive(name, value) || bindingIsLocked(name, value)) next
        binding <- tryCatch(list(get(name, value, inherits = FALSE)), error = function(e) NULL)
        if (is.null(binding)) next
        child <- binding[[1L]]
        if (rlang::is_missing(child)) next
        # ggplot constructor contexts retain the entire task's local frame,
        # including unrelated HTML widgets and machine font caches. Tutorials
        # use explicit data and column mappings, so these contexts are unneeded.
        if (name %in% c("user_env", "call_env", "plot_env") && is.environment(child)) child <- globalenv()
        assign(name, walk(child), value)
      }
      walk(parent.env(value))
      return(value)
    }
    if (is.function(value)) {
      value <- removeSource(value)
      walk(environment(value))
    }
    if (is.language(value) && !is.name(value)) value <- removeSource(value)
    attrs <- attributes(value)
    if (is.list(value)) {
      value <- unclass(value)
      for (i in seq_along(value)) value[i] <- list(walk(value[[i]]))
    }
    for (name in setdiff(names(attrs), c("class", "S7_class", "names", "dim", "dimnames"))) {
      if (name %in% c("srcref", "wholeSrcref", "srcfile")) attrs[[name]] <- NULL
      else if (name %in% c("plot_env", ".Environment") && is.environment(attrs[[name]]) &&
        !isNamespace(attrs[[name]]) && !identical(attrs[[name]], baseenv())) attrs[[name]] <- globalenv()
      else attrs[[name]] <- walk(attrs[[name]])
    }
    attributes(value) <- attrs
    value
  }
  value <- walk(value)
  # Native byte-code constant pools can retain srcfile references that R-level
  # traversal cannot reach. Replace these through the serializer's reference
  # hook, then save an ordinary RDS that needs no custom reader.
  encoded <- serialize(value, NULL, refhook = function(ref) {
    if (inherits(ref, "srcfile")) "ig-tutorial-source" else NULL
  })
  value <- unserialize(encoded, refhook = function(ref) {
    source <- srcfilecopy("@example-source", character())
    source$wd <- "."
    source
  })
  # Some compiled constants retain cached HTML dependencies outside ordinary
  # R traversal. The ASCII serialization stores escaped strings with explicit
  # decoded byte lengths. Replace home prefixes with equal-byte-length public
  # aliases so those lengths and all reference records remain valid. Always
  # round-trip through R's reader before writing the normal binary RDS.
  text <- rawToChar(serialize(value, NULL, ascii = TRUE))
  positions <- gregexpr("[A-Za-z]:[/\\\\]+Users[/\\\\]+[^/\\\\\"<>[:space:]]+", text, perl = TRUE)
  prefixes <- regmatches(text, positions)[[1L]]
  if (length(prefixes)) {
    replacements <- vapply(prefixes, function(prefix) {
      bytes <- nchar(gsub("\\\\(.)", "\\1", prefix, perl = TRUE), type = "bytes")
      paste0("@public", strrep("_", bytes - 7L))
    }, character(1))
    regmatches(text, positions) <- list(replacements)
    value <- unserialize(charToRaw(text))
  }
  if (grepl("[A-Za-z]:[/\\\\]+Users[/\\\\]+", rawToChar(serialize(value, NULL, ascii = TRUE))))
    stop("A bundled tutorial still contains a Windows user-home path.")
  value
}
sanitize_examples <- function() {
  for (archive in list.files("inst/examples", pattern = "[.]igpx$", recursive = TRUE, full.names = TRUE)) {
    cat("Sanitizing", basename(dirname(archive)), "\n")
    directory <- tempfile("ig-public-example-"); dir.create(directory)
    tryCatch({
      utils::unzip(archive, exdir = directory)
      files <- list.files(directory, recursive = TRUE, full.names = TRUE)
      for (file in files[grepl("[.](json|txt|csv|html|Rmd|R)$", files)]) sanitize_example_file(file)
      for (file in files[grepl("[.]rds$", files)]) {
        value <- sanitize_example_native(readRDS(file))
        saveRDS(value, file, compress = FALSE)
      }
      replacement <- tempfile(fileext = ".igpx")
      zip::zipr(replacement, list.files(directory, all.files = TRUE, no.. = TRUE), root = directory)
      if (!file.copy(replacement, archive, overwrite = TRUE)) stop("Could not replace example: ", archive)
      unlink(replacement)
    }, finally = unlink(directory, recursive = TRUE))
  }
  files <- list.files("inst/examples", recursive = TRUE, full.names = TRUE)
  for (file in files[grepl("[.](json|txt|csv|html|Rmd|R)$", files)]) sanitize_example_file(file)
  cat("Sanitized bundled tutorial build paths and author identity.\n")
}
sanitize_examples()
