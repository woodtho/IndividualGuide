# Package operations run in a disposable process and a new library generation.
# Failed installs, cancellation and pin conflicts never alter the active library.
ig_package_dependencies_valid <- function(libraries, roots) {
  db <- utils::installed.packages(lib.loc = libraries, noCache = TRUE)
  db <- db[!duplicated(db[, "Package"]), , drop = FALSE]
  dependencies <- tools::package_dependencies(roots, db = db, which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE)
  packages <- intersect(unique(c(roots, unlist(dependencies))), rownames(db))
  for (name in packages) {
    description <- read.dcf(file.path(db[name, "LibPath"], name, "DESCRIPTION"))
    fields <- intersect(c("Depends", "Imports", "LinkingTo"), colnames(description))
    requirements <- trimws(unlist(strsplit(paste(description[1L, fields], collapse = ","), ",")))
    for (requirement in requirements[nzchar(requirements)]) {
      package <- sub("\\s*\\(.*$", "", requirement)
      actual <- if (package == "R") as.character(getRversion()) else if (package %in% rownames(db)) db[package, "Version"] else NA_character_
      if (is.na(actual)) stop(name, " requires missing package ", package, call. = FALSE)
      if (!grepl("\\(", requirement)) next
      constraint <- trimws(sub("^.*\\((.*)\\)$", "\\1", requirement))
      operator <- regmatches(constraint, regexpr("^[<>=]+", constraint))
      version <- trimws(sub("^[<>=]+", "", constraint))
      compared <- utils::compareVersion(actual, version)
      valid <- switch(operator, `>=` = compared >= 0L, `<=` = compared <= 0L,
        `==` = compared == 0L, `>` = compared > 0L, `<` = compared < 0L, FALSE)
      if (!valid) stop(name, " requires ", requirement, "; selected version is ", actual, call. = FALSE)
    }
  }
  invisible(TRUE)
}

ig_package_change <- function(action, package = "", version = "", root = ig_package_root(),
    fallback = getOption("ig.package.fallback", .libPaths()), lock = NULL,
    installer = NULL, probe = NULL, owner = basename(tempfile("operation-"))) {
  if (!action %in% c("install", "pin", "unpin", "remove", "reset", "restore", "rollback")) stop("Unknown package action.")
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  # An atomic directory lock also excludes other browser sessions/processes.
  guard <- file.path(root, "operation.lock")
  if (dir.exists(guard)) {
    record <- if (file.exists(file.path(guard, "owner"))) readLines(file.path(guard, "owner"), warn = FALSE) else character()
    alive <- if (length(record) >= 2L) tryCatch(as.integer(record[[2L]]) %in% ps::ps_pids(), error = function(e) TRUE) else
      as.numeric(difftime(Sys.time(), file.info(guard)$mtime, units = "secs")) < 60
    if (alive && length(record) >= 3L) alive <- tryCatch(
      identical(record[[3L]], as.character(ps::ps_create_time(ps::ps_handle(as.integer(record[[2L]]))))), error = function(e) TRUE)
    if (!alive) {
      abandoned <- tempfile("abandoned-", tmpdir = root)
      if (file.rename(guard, abandoned)) unlink(abandoned, recursive = TRUE)
    }
  }
  if (!dir.create(guard, showWarnings = FALSE)) stop("Another IG package operation is in progress. Wait for it to finish.")
  on.exit(unlink(guard, recursive = TRUE), add = TRUE)
  writeLines(c(owner, as.character(Sys.getpid()), as.character(ps::ps_create_time(ps::ps_handle()))), file.path(guard, "owner"))
  current <- if (action == "reset") tryCatch(ig_package_current(root), error = function(e) NULL) else ig_package_current(root)
  pins <- ig_package_pins(current)
  fallback <- unique(fallback)
  protected <- utils::installed.packages(lib.loc = .Library, noCache = TRUE)
  protected <- c("IndividualGuide", protected[!is.na(protected[, "Priority"]) & protected[, "Priority"] == "base", "Package"])
  if (!action %in% c("reset", "restore", "rollback")) {
    ig_package_validate(package, if (nzchar(version)) version else NULL)
    if (package %in% protected) stop("R base packages and Individual Guide are managed by the app installer.")
  }
  if (action == "rollback") {
    previous <- file.path(root, "previous")
    if (!file.exists(previous)) stop("No previous package profile is available.")
    id <- readLines(previous, warn = FALSE)
    if (length(id) != 1L || !grepl("^profile-[a-zA-Z0-9_-]+$", id)) stop("Invalid previous package profile.")
    manifest <- readRDS(file.path(root, id, "profile.rds"))
    paths <- c(file.path(root, id, "library"), fallback)
    ig_package_check_pins(manifest$packages, paths)
    ig_package_check_pins(manifest$pins, paths)
    ig_package_dependencies_valid(paths, c("IndividualGuide", names(manifest$packages)))
    if (!is.null(probe)) probe(paths, names(manifest$packages))
    ig_package_publish(root, file.path(root, id), manifest)
    return(invisible(id))
  }
  directory <- tempfile("profile-", tmpdir = root)
  library <- file.path(directory, "library")
  dir.create(library, recursive = TRUE)
  published <- FALSE
  on.exit(if (!published) unlink(directory, recursive = TRUE), add = TRUE)
  if (!is.null(current) && !action %in% c("reset", "restore")) {
    contents <- list.files(current$library, all.files = TRUE, no.. = TRUE, full.names = TRUE)
    if (length(contents) && !all(file.copy(contents, library, recursive = TRUE, copy.date = TRUE))) stop("Cannot stage the IG package library.")
  }
  paths <- c(library, fallback)
  versions <- ig_package_versions(paths)
  requests <- character()
  if (action == "install") {
    if (package %in% names(pins) && (!nzchar(version) || version != pins[[package]]))
      stop("Unpin this package before updating it or selecting another version.")
    requests <- if (nzchar(version)) paste0(package, "@", version) else package
    if (nzchar(version)) pins[[package]] <- version
  } else if (action == "pin") {
    if (!package %in% names(versions)) stop("Install the package before pinning its installed version.")
    pins[[package]] <- versions[[package]]
  } else if (action == "unpin") {
    pins <- pins[names(pins) != package]
  } else if (action == "remove") {
    if (!dir.exists(file.path(library, package))) stop("This package is bundled with IG. It cannot be removed; install a different version to override it.")
    unlink(file.path(library, package), recursive = TRUE)
    pins <- pins[names(pins) != package]
  } else if (action == "reset") {
    pins <- character()
  } else if (action == "restore") {
    lock <- ig_package_validate_lock(lock)
    pins <- unlist(lock$pins, use.names = TRUE)
    if (is.null(pins)) pins <- character()
    wanted <- unlist(lock$packages, use.names = TRUE)
    if (any(names(wanted) %in% protected)) stop("The lockfile attempts to replace an app or R base package.")
    missing <- names(wanted)[is.na(versions[names(wanted)]) | versions[names(wanted)] != wanted]
    requests <- if (length(missing)) paste0(missing, "@", wanted[missing]) else character()
  }
  if (length(requests)) {
    if (is.null(installer)) installer <- function(requests, library, fallback, directory) {
      old <- options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 600,
        renv.config.auto.snapshot = FALSE, renv.config.cache.enabled = FALSE)
      on.exit(options(old))
      .libPaths(c(library, fallback), include.site = FALSE)
      renv::settings$external.libraries(fallback, project = directory)
      renv::install(requests, library = library, project = directory, prompt = FALSE,
        dependencies = NA, transactional = TRUE)
    }
    # Supply every manual pin to dependency resolution, then verify the result.
    specs <- unique(c(if (length(pins)) paste0(names(pins), "@", pins), requests))
    installer(specs, library, fallback, directory)
  }
  ig_package_check_pins(pins, paths)
  if (action == "restore") ig_package_check_pins(unlist(lock$packages, use.names = TRUE), paths)
  overlay <- ig_package_versions(library)
  if (length(intersect(names(overlay), protected))) stop("Package installation attempted to replace an app or R base package.")
  ig_package_dependencies_valid(paths, c("IndividualGuide", names(overlay)))
  if (!is.null(probe)) probe(paths, names(overlay))
  manifest <- list(schema = 1L, R = paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][1L], sep = "."),
    created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), pins = pins, packages = overlay)
  ig_package_publish(root, directory, manifest)
  published <- TRUE
  invisible(basename(directory))
}

ig_package_validate_lock <- function(lock) {
  if (!is.list(lock) || !identical(lock$format, "Individual Guide packages") || !identical(as.integer(lock$schema), 1L) ||
      !identical(lock$R, as.character(getRversion()))) stop("Choose an IG package lockfile for this R version.")
  for (field in c("packages", "pins")) {
    values <- lock[[field]]
    if (!is.list(values) || length(values) > 2000L || anyDuplicated(names(values)) ||
        (length(values) && (is.null(names(values)) || any(!nzchar(names(values)))))) stop("Invalid package lockfile.")
    for (name in names(values)) ig_package_validate(name, values[[name]])
  }
  if (!all(names(lock$pins) %in% names(lock$packages)) ||
      any(vapply(names(lock$pins), function(name) !identical(lock$pins[[name]], lock$packages[[name]]), logical(1))))
    stop("Pinned versions do not match the lockfile's package versions.")
  lock
}

ig_package_export <- function(root = ig_package_root(), fallback = getOption("ig.package.fallback", .libPaths())) {
  profile <- ig_package_current(root)
  versions <- ig_package_versions(if (is.null(profile)) fallback else c(profile$library, fallback))
  base <- utils::installed.packages(lib.loc = .Library, priority = "base")[, "Package"]
  versions <- versions[!names(versions) %in% c("IndividualGuide", base)]
  list(format = "Individual Guide packages", schema = 1L, R = as.character(getRversion()),
    packages = as.list(versions), pins = as.list(ig_package_pins(profile)))
}
