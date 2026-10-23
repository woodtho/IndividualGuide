# run_app.R — Package entry point for launching the Shiny application.

#' Path to a file shipped in inst/ of the package
#'
#' Resolves through `system.file()` when the package is installed (or loaded
#' with pkgload), and falls back to the source `inst/` directory so the app
#' can also be run from a plain source checkout.
#' @keywords internal
#' @param ... Additional arguments forwarded to the wrapped operation.
app_sys <- function(...) {
  path <- system.file(..., package = "IndividualGuide")
  if (nzchar(path)) return(path)
  file.path("inst", ...)
}

#' Launch Individual Guide
#'
#' Starts the Individual Guide Shiny application — a low-code analytical
#' pipeline builder. Tasks are added to a process flow, configured in panels,
#' and each task generates readable R (and where applicable SQL) code.
#'
#' @param ... Additional arguments passed on to [shiny::shinyApp()]
#'   (e.g. `options = list(port = 1234)`).
#'
#' @return A [shiny::shinyApp()] object (invisibly runs the app when printed).
#' @export
#'
#' @examples
#' if (interactive()) {
#'   run_app()
#' }
run_app <- function(...) {
  ig_package_initialize(fallback = getOption("ig.package.launch.fallback", .libPaths()))
  ig_options_initialize()
  # Serve packaged static assets (styles.css, ig_tree.js) under /www
  shiny::addResourcePath("www", app_sys("app", "www"))
  shiny::shinyApp(ui = app_ui(), server = app_server, ...)
}
