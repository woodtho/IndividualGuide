# Base-R-only entry point, used before loading application/package namespaces.
ig_options_bootstrap <- function(state = Sys.getenv("IG_USER_DATA", "")) {
  if (isTRUE(getOption("IndividualGuide.options.bootstrapped"))) return(invisible(NULL))
  ignored <- identical(Sys.getenv("IG_IGNORE_GLOBAL_OPTIONS", "0"), "1")
  options(IndividualGuide.options.ignore_saved = ignored, IndividualGuide.options.bootstrapped = TRUE)
  if (ignored) return(invisible(NULL))
  if (!nzchar(state)) state <- tools::R_user_dir("IndividualGuide", "data")
  file <- getOption("ig.options.file")
  if (is.null(file)) file <- file.path(state, "settings", "options.rds")
  if (!file.exists(file)) return(invisible(NULL))
  configuration <- readRDS(file)
  if (!is.list(configuration$r)) stop("Invalid saved global R options. Restart with default R options to repair them.")
  previous <- stats::setNames(lapply(names(configuration$r), getOption), names(configuration$r))
  tryCatch({
    if (length(configuration$r)) options(configuration$r)
  }, error = function(error) {
    if (length(previous)) options(previous)
    stop("Saved global R options could not be applied. Restart with default R options: ", conditionMessage(error))
  })
  options(IndividualGuide.options.startup_originals = previous)
  invisible(NULL)
}
