package_fixture <- function(library, name, version, imports = NULL) {
  directory <- file.path(library, name)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  fields <- c(Package = name, Version = version, Title = "IG package test fixture", Description = "A fixture.", License = "MIT")
  if (!is.null(imports)) fields <- c(fields, Imports = imports)
  write.dcf(as.list(fields), file.path(directory, "DESCRIPTION"))
  dir.create(file.path(directory, "Meta"), showWarnings = FALSE)
  saveRDS(list(DESCRIPTION = fields, Built = list(R = getRversion(), Platform = R.version$platform,
    Date = "", OStype = .Platform$OS.type)), file.path(directory, "Meta", "package.rds"))
}

package_manager_fixture <- function() {
  root <- tempfile("ig-manager-test-"); dir.create(root)
  withr::defer(unlink(root, recursive = TRUE), envir = parent.frame())
  fallback <- file.path(root, "bundled"); dir.create(fallback)
  package_fixture(fallback, "example", "1.0.0")
  list(root = root, fallback = fallback)
}

test_that("an IG library takes precedence and never includes the desktop's old user library", {
  fixture <- package_manager_fixture()
  old <- .libPaths()
  withr::local_envvar(IG_PACKAGE_LIBRARY = NA, IG_PACKAGE_PROFILE = NA)
  withr::defer(.libPaths(old, include.site = FALSE))
  withr::local_options(list(ig.package.library.initialized = FALSE, ig.package.fallback = NULL,
    ig.package.session.profile = NULL, ig.package.startup.error = NULL))
  ig_package_initialize(fixture$root, fixture$fallback)
  root <- ig_package_root(fixture$root)
  profile <- ig_package_current(root)
  expect_identical(normalizePath(.libPaths()[[1L]]), normalizePath(profile$library))
  expect_false(any(grepl("R-library", .libPaths(), fixed = TRUE)))
  expect_true(normalizePath(fixture$fallback) %in% normalizePath(.libPaths()))
  expect_identical(profile$manifest$packages, character())
})

test_that("pins survive transactions and updates cannot silently replace them", {
  fixture <- package_manager_fixture()
  install <- function(requests, library, fallback, directory) {
    for (request in requests) {
      pair <- strsplit(request, "@", fixed = TRUE)[[1L]]
      package_fixture(library, pair[[1L]], pair[[2L]])
    }
  }
  ig_package_change("install", "example", "2.0.0", fixture$root, fixture$fallback, installer = install)
  first <- ig_package_current(fixture$root)
  expect_identical(first$manifest$pins, c(example = "2.0.0"))
  expect_identical(ig_package_versions(fixture$fallback)[["example"]], "1.0.0")
  expect_error(ig_package_change("install", "example", root = fixture$root, fallback = fixture$fallback, installer = install), "Unpin")
  expect_error(ig_package_change("install", "example", "3.0.0", fixture$root, fixture$fallback, installer = install), "Unpin")
  expect_identical(ig_package_current(fixture$root)$id, first$id)
  ig_package_change("unpin", "example", root = fixture$root, fallback = fixture$fallback)
  ig_package_change("install", "example", "3.0.0", fixture$root, fixture$fallback, installer = install)
  expect_identical(ig_package_current(fixture$root)$manifest$pins, c(example = "3.0.0"))
  expect_identical(ig_package_versions(first$library)[["example"]], "2.0.0")
})

test_that("an unpinned latest install passes only valid package requests", {
  fixture <- package_manager_fixture()
  install <- function(requests, library, fallback, directory) {
    expect_identical(requests, "example")
    package_fixture(library, "example", "2.0.0")
  }
  ig_package_change("install", "example", root = fixture$root, fallback = fixture$fallback, installer = install)
  expect_identical(ig_package_current(fixture$root)$manifest$packages, c(example = "2.0.0"))
  expect_length(ig_package_current(fixture$root)$manifest$pins, 0L)
})

test_that("run records describe the running profile while another profile is pending", {
  fixture <- package_manager_fixture()
  library <- file.path(fixture$root, "running", "library"); dir.create(library, recursive = TRUE)
  saveRDS(list(packages = c(example = "1.0.0"), pins = c(example = "1.0.0")),
    file.path(dirname(library), "profile.rds"))
  withr::local_envvar(IG_PACKAGE_LIBRARY = library, IG_PACKAGE_PROFILE = "running-profile")
  ig_package_change("reset", root = fixture$root, fallback = fixture$fallback)
  info <- ig_environment_info()
  expect_identical(info$packages$example, "1.0.0")
  expect_identical(info$package_pins$example, "1.0.0")
  expect_identical(info$package_profile, "running-profile")
})

test_that("invalid pinned profiles recover to an IG library with a visible startup reason", {
  fixture <- package_manager_fixture()
  withr::local_options(list(ig.package.library.initialized = FALSE, ig.package.fallback = NULL,
    ig.package.session.profile = NULL, ig.package.startup.error = NULL))
  withr::local_envvar(IG_PACKAGE_LIBRARY = NA, IG_PACKAGE_PROFILE = NA)
  old <- .libPaths(); withr::defer(.libPaths(old, include.site = FALSE))
  root <- ig_package_root(fixture$root)
  ig_package_change("pin", "example", root = root, fallback = fixture$fallback)
  package_fixture(fixture$fallback, "example", "2.0.0")
  ig_package_initialize(fixture$root, fixture$fallback)
  expect_match(getOption("ig.package.startup.error"), "pinned versions")
  expect_match(.libPaths()[[1L]], "recovery/library", fixed = TRUE)
  expect_identical(ig_package_versions(.libPaths())[["example"]], "2.0.0")
})

test_that("failed installs, dependency conflicts and probes preserve the current profile", {
  fixture <- package_manager_fixture()
  ig_package_change("pin", "example", root = fixture$root, fallback = fixture$fallback)
  first <- ig_package_current(fixture$root)
  broken <- function(requests, library, fallback, directory) {
    package_fixture(library, "example", "9.0.0")
    stop("download failed")
  }
  expect_error(ig_package_change("install", "another", "1.0.0", fixture$root, fixture$fallback, installer = broken), "download failed")
  conflict <- function(requests, library, fallback, directory) {
    package_fixture(library, "another", "1.0.0", "example (>= 2.0.0)")
  }
  expect_error(ig_package_change("install", "another", "1.0.0", fixture$root, fixture$fallback, installer = conflict), "requires example")
  mutate_pin <- function(requests, library, fallback, directory) {
    package_fixture(library, "example", "9.0.0")
  }
  expect_error(ig_package_change("install", "another", "1.0.0", fixture$root, fixture$fallback, installer = mutate_pin), "pinned versions")
  expect_error(ig_package_change("unpin", "example", root = fixture$root, fallback = fixture$fallback,
    probe = function(...) stop("namespace incompatible")), "namespace incompatible")
  expect_identical(ig_package_current(fixture$root)$id, first$id)
  expect_false(dir.exists(file.path(fixture$root, "operation.lock")))
  expect_length(list.files(fixture$root, "^profile-"), 1L)
})

test_that("lockfiles round-trip exact versions and rollback keeps libraries intact", {
  fixture <- package_manager_fixture()
  ig_package_change("pin", "example", root = fixture$root, fallback = fixture$fallback)
  first <- ig_package_current(fixture$root)
  lock <- ig_package_export(fixture$root, fixture$fallback)
  encoded <- jsonlite::fromJSON(jsonlite::toJSON(lock, auto_unbox = TRUE), simplifyVector = FALSE)
  expect_identical(ig_package_validate_lock(encoded)$pins$example, "1.0.0")
  ig_package_change("reset", root = fixture$root, fallback = fixture$fallback)
  expect_length(ig_package_current(fixture$root)$manifest$pins, 0L)
  ig_package_change("rollback", root = fixture$root, fallback = fixture$fallback)
  expect_identical(ig_package_current(fixture$root)$id, first$id)
  ig_package_change("restore", root = fixture$root, fallback = fixture$fallback, lock = encoded)
  expect_identical(ig_package_current(fixture$root)$manifest$pins, c(example = "1.0.0"))
  encoded$packages$example <- "2.0.0"
  expect_error(ig_package_validate_lock(encoded), "Pinned versions")
})

test_that("package actions reject paths, remotes, malformed versions and protected packages", {
  fixture <- package_manager_fixture()
  for (name in c("../example", "user/repo", "example@latest", "", "a;system('bad')"))
    expect_error(ig_package_change("install", name, root = fixture$root, fallback = fixture$fallback), "package name")
  expect_error(ig_package_validate("example", "latest"), "exact package version")
  expect_error(ig_package_change("install", "IndividualGuide", root = fixture$root, fallback = fixture$fallback), "app installer")
  expect_error(ig_package_change("install", "base", root = fixture$root, fallback = fixture$fallback), "app installer")
  expect_error(ig_package_change("remove", "example", root = fixture$root, fallback = fixture$fallback), "bundled")
  lock <- list(format = "Individual Guide packages", schema = 1L, R = "0.0.0", packages = list(), pins = list())
  expect_error(ig_package_validate_lock(lock), "this R version")
  writeLines("../outside", file.path(fixture$root, "current"))
  expect_error(ig_package_current(fixture$root), "Invalid IG package profile")
  ig_package_change("reset", root = fixture$root, fallback = fixture$fallback)
  expect_length(ig_package_current(fixture$root)$manifest$pins, 0L)
})

test_that("concurrent sessions cannot replace or release another operation's lock", {
  fixture <- package_manager_fixture()
  guard <- file.path(fixture$root, "operation.lock"); dir.create(guard)
  writeLines(c("other-session", Sys.getpid()), file.path(guard, "owner"))
  expect_error(ig_package_change("pin", "example", root = fixture$root, fallback = fixture$fallback), "in progress")
  expect_identical(readLines(file.path(guard, "owner"))[[1L]], "other-session")
})

test_that("a crashed package worker does not permanently lock the manager", {
  fixture <- package_manager_fixture()
  guard <- file.path(fixture$root, "operation.lock"); dir.create(guard)
  writeLines(c("dead-worker", "-1"), file.path(guard, "owner"))
  ig_package_change("pin", "example", root = fixture$root, fallback = fixture$fallback)
  expect_identical(ig_package_current(fixture$root)$manifest$pins, c(example = "1.0.0"))
  expect_false(dir.exists(guard))
})

test_that("package manager denies mutations from a remote browser", {
  withr::local_envvar(IG_USER_DATA = tempfile("ig-manager-ui-"))
  shiny::testServer(ig_package_manager_server, args = list(store = make_store()), {
    session$setInputs(install = 1L)
    session$setInputs(install = 2L)
    expect_match(status(), "only from a browser on this computer")
    expect_null(process)
  })
})
