# app.R — Deployment / development launcher for Individual Guide.
#
# The application code lives in this R package (R/ directory). Run it with:
#   - IndividualGuide::run_app()           after installing the package, or
#   - shiny::runApp()                      from this directory (uses pkgload).
if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
  IndividualGuide::run_app()
} else if (requireNamespace("IndividualGuide", quietly = TRUE)) {
  IndividualGuide::run_app()
} else {
  stop(
    "Install the package first (install.packages('pkgload') for dev mode, ",
    "or devtools::install() to install IndividualGuide)."
  )
}
