# Browser entry point: activate IG's library before importing Shiny or other
# application dependencies. In a fresh R session:
# source(system.file("launch.R", package = "IndividualGuide"))
local({
  fallback <- .libPaths()
  state <- Sys.getenv("IG_USER_DATA", "")
  if (!nzchar(state)) state <- tools::R_user_dir("IndividualGuide", "data")
  root <- file.path(state, "packages", paste0("R-", R.version$major, ".", strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][1L]))
  pointer <- file.path(root, "current")
  if (file.exists(pointer)) {
    # Invalid profiles are left for run_app's recovery path and manager.
    candidate <- tryCatch({
      id <- readLines(pointer, warn = FALSE)
      if (length(id) != 1L || !grepl("^profile-[a-zA-Z0-9_-]+$", id)) stop("Invalid profile")
      library <- file.path(root, id, "library")
      manifest <- readRDS(file.path(root, id, "profile.rds"))
      if (!identical(manifest$R, paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][1L], sep = "."))) stop("Profile R version changed")
      expected <- c(manifest$packages, manifest$pins)
      installed <- utils::installed.packages(lib.loc = c(library, fallback), noCache = TRUE)
      installed <- installed[!duplicated(installed[, "Package"]), , drop = FALSE]
      if (!dir.exists(library) || any(is.na(installed[names(expected), "Version"]) | installed[names(expected), "Version"] != expected)) stop("Profile versions changed")
      list(library = library, expected = expected)
    }, error = function(error) NULL)
    if (!is.null(candidate)) {
      for (name in intersect(names(candidate$expected), loadedNamespaces()))
        if (!identical(as.character(getNamespaceVersion(name)), unname(candidate$expected[[name]])))
          stop("Start a fresh R session, then source this launcher before loading other packages.")
      .libPaths(c(candidate$library, fallback), include.site = FALSE)
    }
  }
  options(ig.package.launch.fallback = fallback)
  bootstrap <- new.env(parent = baseenv())
  sys.source(system.file("options", "bootstrap.R", package = "IndividualGuide"), envir = bootstrap)
  bootstrap$ig_options_bootstrap(state)
  app <- IndividualGuide::run_app()
  print(app)
})
