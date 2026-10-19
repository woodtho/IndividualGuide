main <- function() {
Sys.setlocale("LC_CTYPE", ".UTF-8")
Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
Sys.setenv(NOT_CRAN = "true")
Sys.setenv(LC_ALL = "English_Canada.utf8", LANG = "English_Canada.utf8")
options(chromote.timeout = 180)
browser <- chromote::default_chromote_object()
browser$default_timeout <- 180
root <- normalizePath(".", winslash = "/")
artifacts <- file.path(root, "artifacts", "audit", paste0("browser-", format(Sys.time(), "%Y%m%d-%H%M%S")))
dir.create(artifacts, recursive = TRUE, showWarnings = FALSE)
sandbox <- tempfile("ig-browser-")
dir.create(sandbox)
writeLines(c(
  "Sys.setlocale('LC_CTYPE', '.UTF-8')",
  sprintf("pkgload::load_all(%s, export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)", deparse(root)),
  "options(ig.catalogue_dir = file.path(tempdir(), 'ig-test-catalogue'), ig.recovery_dir = file.path(tempdir(), 'ig-test-recovery'))",
  "IndividualGuide::run_app()"
), file.path(sandbox, "app.R"))
app <- shinytest2::AppDriver$new(app_dir = sandbox, name = "audit-smoke",
  width = 1440, height = 900, load_timeout = 180000, timeout = 120000,
  options = list(shiny.port = NULL), check_names = FALSE)
on.exit({
  try({
  capture.output(print(app$get_logs()), file = file.path(artifacts, "browser-runtime.log"))
  app$stop()
  }, silent = TRUE)
  try(app$stop(), silent = TRUE)
}, add = TRUE)
cat("App loaded\n")
cat("Screenshots:", artifacts, "\n")
app$get_screenshot(file = file.path(artifacts, "initial-splash.png"))
app$wait_for_js("document.querySelector('#splash_fresh.shiny-bound-input') !== null")
app$click("splash_fresh")
app$wait_for_js("document.querySelector('.modal-backdrop') === null")
app$get_screenshot(file = file.path(artifacts, "initial-workspace.png"))
app$click("btn_add_task")
app$wait_for_js("(() => { const m = document.querySelector('#shiny-modal.show'); return m && getComputedStyle(m).opacity === '1'; })()")
app$get_screenshot(file = file.path(artifacts, "initial-task-picker.png"))
pkgload::load_all(root, quiet = TRUE)
catalogue <- TASK_REGISTRY
if ("--quick" %in% commandArgs(trailingOnly = TRUE)) catalogue <- Filter(function(task)
  task$id %in% c("import_data", "query_builder", "bar_chart", "linear_regression", "rank", "change_types", "script", "branch", "loop", "export", "report"), catalogue)
for (task in catalogue) {
  app$run_js(sprintf("Shiny.setInputValue('picker_select', %s, {priority:'event'});",
    jsonlite::toJSON(task$id, auto_unbox = TRUE)))
  app$wait_for_idle()
  panel <- paste0("panel_", gsub("_", "", task$id), "_1")
  app$wait_for_js(sprintf("document.getElementById(%s) !== null", jsonlite::toJSON(panel, auto_unbox = TRUE)))
  ready_suffix <- paste0("_", sub("^panel_", "", panel), "-ig_ready")
  app$wait_for_js(sprintf("Object.entries(Shiny.shinyapp.$inputValues).some(([k,v]) => k.endsWith(%s) && typeof v === 'string' && v === document.getElementById(%s)?.dataset.igReadyToken)",
    jsonlite::toJSON(ready_suffix, auto_unbox = TRUE), jsonlite::toJSON(panel, auto_unbox = TRUE)))
  app$wait_for_idle()
  app$expect_unique_names()
  errors <- app$get_js("Array.from(document.querySelectorAll('.shiny-output-error:not(.shiny-output-error-validation)')).filter(e => e.getClientRects().length).map(e => e.innerText)")
  cat("Opened", task$id, ":", paste(unlist(errors), collapse = " | "), "\n")
  if (length(unlist(errors))) stop("Rendered errors in task: ", task$id)
}
app$wait_for_js("Array.from(document.querySelectorAll('.recalculating')).every(e => !e.getClientRects().length)")
app$wait_for_idle()
app$get_screenshot(file = file.path(artifacts, "all-task-panels-smoke.png"))
cat(app$get_js("document.body.innerText"), sep = "\n")
log_text <- capture.output(print(app$get_logs()))
cat(log_text, sep = "\n")
if (any(grepl("JS error|JS warning", log_text))) stop("Browser runtime errors or warnings were recorded; inspect browser-runtime.log.")
}
main()
