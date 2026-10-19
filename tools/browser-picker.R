main <- function() {
  Sys.setlocale("LC_CTYPE", ".UTF-8")
  Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
  Sys.setenv(NOT_CRAN = "true")
  root <- normalizePath(".", winslash = "/")
  artifact <- file.path(root, "artifacts/audit", paste0("picker-", format(Sys.time(), "%Y%m%d-%H%M%S")))
  dir.create(artifact, recursive = TRUE)
  sandbox <- tempfile("ig-picker-"); dir.create(sandbox)
  writeLines(c(sprintf("pkgload::load_all(%s, export_all = FALSE, helpers = FALSE)", deparse(root)),
    "options(ig.recovery_dir = file.path(tempdir(), 'picker-recovery'))", "IndividualGuide::run_app()"),
    file.path(sandbox, "app.R"))
  app <- shinytest2::AppDriver$new(app_dir = sandbox, timeout = 15000, check_names = FALSE)
  on.exit({
    try(capture.output(print(app$get_logs()), file = file.path(artifact, "browser-runtime.log")), silent = TRUE)
    try(app$get_screenshot(file = file.path(artifact, "last-screen.png")), silent = TRUE)
    try(app$stop(), silent = TRUE)
  }, add = TRUE)
  click <- function(id) {
    app$wait_for_js(sprintf("document.getElementById('%s')?.classList.contains('shiny-bound-input')", id))
    app$run_js(sprintf("document.getElementById('%s').click()", id)); app$wait_for_idle()
  }
  click("splash_fresh")
  app$wait_for_js("document.querySelector('.modal-backdrop') === null")
  click("btn_add_task")
  app$wait_for_js("document.querySelector('#shiny-modal.show') !== null")
  app$run_js("document.querySelector('[onclick*=\"picker_fav_toggle\"][onclick*=\"first_last_n\"]').click()")
  app$wait_for_js("document.querySelector('.ig-picker-star--on[onclick*=\"first_last_n\"]') !== null")
  app$wait_for_idle()
  app$wait_for_js("(() => {const m=document.querySelector('#shiny-modal.show');return m && !bootstrap.Modal.getInstance(m)?._isTransitioning && getComputedStyle(m).opacity === '1';})()")
  app$run_js("document.querySelector('#shiny-modal [data-bs-dismiss=\"modal\"]').click()")
  app$wait_for_js("document.querySelector('.modal-backdrop') === null")
  click("btn_help")
  app$wait_for_js("document.getElementById('help_task_search') !== null")
  app$expect_unique_names()
  cat("Favourite toggle, settled native Cancel and Help passed. Artifacts:", artifact, "\n")
}
main()
