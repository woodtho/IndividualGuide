# Also sourced before loading IndividualGuide in the standalone runtime. Keep
# startup helpers independent of the application namespace and contributed R code.
ig_package_root <- function(state = Sys.getenv("IG_USER_DATA", "")) {
  if (!nzchar(state)) state <- tools::R_user_dir("IndividualGuide", "data")
  file.path(state, "packages", paste0("R-", R.version$major, ".", strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][1L]))
}

ig_package_current <- function(root = ig_package_root()) {
  pointer <- file.path(root, "current")
  if (!file.exists(pointer)) return(NULL)
  id <- readLines(pointer, warn = FALSE)
  if (length(id) != 1L || !grepl("^profile-[a-zA-Z0-9_-]+$", id)) stop("Invalid IG package profile. Open the package manager to reset it.")
  directory <- file.path(root, id)
  manifest <- readRDS(file.path(directory, "profile.rds"))
  if (!identical(manifest$R, paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][1L], sep = ".")) ||
      !dir.exists(file.path(directory, "library"))) stop("The IG package profile is incomplete or belongs to a different R version.")
  list(id = id, directory = directory, library = file.path(directory, "library"), manifest = manifest)
}

ig_package_versions <- function(libraries) {
  installed <- utils::installed.packages(lib.loc = libraries, noCache = TRUE)
  installed <- installed[!duplicated(installed[, "Package"]), , drop = FALSE]
  stats::setNames(installed[, "Version"], installed[, "Package"])
}

ig_package_initialize <- function(state = Sys.getenv("IG_USER_DATA", ""), fallback = .libPaths()) {
  if (isTRUE(getOption("ig.package.library.initialized"))) return(invisible(.libPaths()))
  root <- ig_package_root(state)
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  problem <- NULL
  profile <- tryCatch(ig_package_current(root), error = function(error) { problem <<- conditionMessage(error); NULL })
  if (is.null(profile) && is.null(problem)) {
    directory <- file.path(root, "profile-bundled")
    dir.create(file.path(directory, "library"), recursive = TRUE, showWarnings = FALSE)
    manifest <- list(schema = 1L, R = paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][1L], sep = "."),
      pins = character(), packages = character())
    saveRDS(manifest, file.path(directory, "profile.rds"))
    writeLines("profile-bundled", file.path(root, "current"))
    profile <- ig_package_current(root)
  }
  # Never use the desktop's former unversioned R-library, or the host user's
  # libraries. The desktop supplies its bundled library explicitly.
  recovery <- file.path(root, "recovery", "library")
  dir.create(recovery, recursive = TRUE, showWarnings = FALSE)
  libraries <- if (is.null(profile)) c(recovery, fallback) else c(profile$library, fallback)
  if (!is.null(profile)) {
    tryCatch({
      expected <- profile$manifest$packages
      if (length(expected)) {
        versions <- ig_package_versions(libraries)
        if (any(is.na(versions[names(expected)]) | versions[names(expected)] != expected))
          stop("The IG package library does not match its saved versions. Restore a lockfile or use bundled packages in the package manager.")
      }
      ig_package_check_pins(profile$manifest$pins, libraries)
      for (name in intersect(names(expected), loadedNamespaces())) {
        if (!identical(as.character(getNamespaceVersion(name)), unname(expected[[name]])))
          stop("Restart R before activating the IG package library: ", name)
      }
    }, error = function(error) { problem <<- conditionMessage(error) })
    if (!is.null(problem)) libraries <- c(recovery, fallback)
  }
  .libPaths(libraries, include.site = FALSE)
  Sys.setenv(IG_PACKAGE_LIBRARY = .libPaths()[[1L]],
    IG_PACKAGE_PROFILE = if (is.null(profile) || !is.null(problem)) "bundled" else profile$id)
  options(ig.package.library.initialized = TRUE, ig.package.fallback = fallback,
    ig.package.startup.error = problem,
    ig.package.session.profile = if (is.null(profile) || !is.null(problem)) "bundled" else profile$id)
  invisible(.libPaths())
}

ig_package_validate <- function(package, version = NULL) {
  if (!is.character(package) || length(package) != 1L || is.na(package) ||
      !grepl("^[A-Za-z][A-Za-z0-9.]*$", package) || nchar(package) > 100L)
    stop("Enter one R package name.", call. = FALSE)
  if (!is.null(version) && (!is.character(version) || length(version) != 1L || is.na(version) ||
      !grepl("^[0-9]+([.-][0-9]+)*$", version) || nchar(version) > 60L))
    stop("Enter an exact package version, such as 1.2.3.", call. = FALSE)
  invisible(TRUE)
}

ig_package_pins <- function(profile) {
  if (is.null(profile) || is.null(profile$manifest$pins)) character() else profile$manifest$pins
}

ig_package_check_pins <- function(pins, libraries) {
  if (!length(pins)) return(invisible(TRUE))
  versions <- ig_package_versions(libraries)
  different <- names(pins)[is.na(versions[names(pins)]) | versions[names(pins)] != pins]
  if (length(different)) stop("Package changes conflict with pinned versions: ", paste(different, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

ig_package_publish <- function(root, directory, manifest) {
  metadata <- file.path(directory, "profile.rds")
  if (!file.exists(metadata)) saveRDS(manifest, metadata) else
    if (!identical(readRDS(metadata), manifest)) stop("Cannot change an existing package profile.")
  replacement <- tempfile("current-", tmpdir = root)
  writeLines(basename(directory), replacement)
  destination <- file.path(root, "current")
  backup <- file.path(root, "previous")
  # Retain the previous pointer for rollback. Never modify a running library.
  if (file.exists(destination)) {
    if (file.exists(backup)) unlink(backup)
    if (!file.copy(destination, backup)) stop("Cannot retain the previous IG package profile.")
  }
  if (!file.rename(replacement, destination)) {
    unlink(replacement)
    stop("Cannot activate the new IG package profile. The current profile was retained.")
  }
  invisible(basename(directory))
}

ig_package_inventory <- function(root = ig_package_root(), fallback = getOption("ig.package.fallback", .libPaths())) {
  profile <- ig_package_current(root)
  paths <- if (is.null(profile)) fallback else c(profile$library, fallback)
  installed <- utils::installed.packages(lib.loc = paths, noCache = TRUE)
  installed <- installed[!duplicated(installed[, "Package"]), , drop = FALSE]
  pins <- ig_package_pins(profile)
  names <- installed[, "Package"]
  loaded <- vapply(names, function(name) if (name %in% loadedNamespaces()) as.character(getNamespaceVersion(name)) else "", character(1))
  data.frame(Package = names, Version = unname(installed[, "Version"]), Loaded = unname(loaded),
    Pinned = ifelse(names %in% names(pins), unname(pins[names]), ""),
    Library = if (is.null(profile)) rep("Bundled / existing", length(names)) else
      ifelse(normalizePath(installed[, "LibPath"], winslash = "/") == normalizePath(profile$library, winslash = "/"), "IG library", "Bundled / existing"),
    stringsAsFactors = FALSE, row.names = NULL)
}
