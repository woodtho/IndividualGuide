main <- function() {
  Sys.setlocale("LC_CTYPE", ".UTF-8")
  Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    NOT_CRAN = "true", LC_ALL = "English_Canada.utf8", LANG = "English_Canada.utf8")
  browser <- chromote::default_chromote_object(); browser$default_timeout <- 180
  root <- normalizePath(".", winslash = "/"); pkgload::load_all(root, quiet = TRUE)
  artifacts <- file.path(root, "artifacts", "audit", paste0("restoration-", format(Sys.time(), "%Y%m%d-%H%M%S")))
  dir.create(artifacts, recursive = TRUE)
  files <- file.path(artifacts, "files"); dir.create(files)
  store <- make_store(); flow <- make_flow("Restoration")
  store$flows <- setNames(list(flow), flow$id); store$active_flow <- flow$id
  store$tables <- list(raw = data.frame(x = 1:12, y = c(2,5,3,8,6,9,4,10,7,13,11,14)))
  settings <- shiny::isolate(store$settings); settings$confirm_delete <- FALSE; store$settings <- settings
  add <- function(id, type, p) shiny::isolate(store_set_task(store, store_task_from_params(task_def(id, type), p)))
  p <- default_first_last_params("top_rows"); p$input_table <- "raw"; p$n <- 4L; add("head", "first_last_n", p)
  p <- default_phase3_params("linear_regression", "fit"); p$input_table <- "raw"; p$response <- "y"; p$predictors <- "x"
  add("model", "linear_regression", p)
  p <- default_script_params("script_rows"); p$input_tables <- "top_rows"; p$code <- "script_rows <- transform(top_rows, doubled = x * 2)"
  add("script", "script", p)
  for (id in c("head", "model", "script")) stopifnot(shiny::isolate(run_task_from_store(store, id)))
  project <- file.path(files, "restoration.igpx"); project_save(store, project)
  sandbox <- tempfile("ig-restoration_"); dir.create(sandbox)
  trace_file <- file.path(artifacts, "parameter-changes.log")
  writeLines(c("Sys.setlocale('LC_CTYPE', '.UTF-8')",
    sprintf("pkgload::load_all(%s, export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)", deparse(root)),
    sprintf("options(ig.file_roots = c(Audit = %s), ig.catalogue_dir = file.path(tempdir(), 'catalogue'), ig.recovery_dir = file.path(tempdir(), 'recovery'), ig.audit.trace = %s)", deparse(files), deparse(trace_file)),
    "trace('store_set_task', where = asNamespace('IndividualGuide'), print = FALSE, tracer = quote({",
    "  previous <- shiny::isolate(store$tasks[[task$id]])",
    "  if (!is.null(previous) && !identical(previous$params, task$params)) cat(task$id, paste(waldo::compare(previous$params, task$params), collapse='\\n'), '\\n', file=getOption('ig.audit.trace'), append=TRUE)",
    "}))", "IndividualGuide::run_app()"), file.path(sandbox, "app.R"))
  app <- shinytest2::AppDriver$new(app_dir = sandbox, width = 1440, height = 900,
    load_timeout = 180000, timeout = 120000, check_names = FALSE)
  on.exit({
  try({
    app$run_js("document.getElementById('btn_save')?.click()")
    app$wait_for_idle()
    capture.output(print(app$get_logs()), file = file.path(artifacts, "browser-runtime.log"))
    capture.output(dput(app$get_js("Object.fromEntries(Object.entries(Shiny.shinyapp.$inputValues).filter(([k])=>k.startsWith('p3_model-')||k.startsWith('scr_script-')))")), file = file.path(artifacts, "inputs.R"))
    app$get_screenshot(file = file.path(artifacts, "last-screen.png")); app$stop()
    }, silent = TRUE)
  try(app$stop(), silent = TRUE)
}, add = TRUE)
  cat("Artifacts:", artifacts, "\n")
  q <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
  click <- function(id) {
    app$wait_for_js(sprintf("document.getElementById(%s)?.classList.contains('shiny-bound-input') && !document.getElementById(%s).disabled", q(id), q(id)))
    app$run_js(sprintf("document.getElementById(%s).click()", q(id))); app$wait_for_idle()
  }
  ready <- function(id) {
    app$wait_for_js(sprintf("(() => {const p=document.getElementById(%s);return p?.dataset.igReadyToken && Object.entries(Shiny.shinyapp.$inputValues).some(([k,v])=>k.endsWith(%s)&&v===p.dataset.igReadyToken);})()", q(paste0("panel_", id)), q(paste0("_", id, "-ig_ready"))))
    app$wait_for_idle()
  }
  app$wait_for_js("document.querySelector('#splash_fresh.shiny-bound-input') !== null")
  click("splash_fresh")
  app$wait_for_js("document.querySelector('.modal-backdrop') === null")
  click("btn_open")
  app$wait_for_js("document.querySelector('#sf_open-modal .sF-file') !== null")
  app$run_js("document.querySelector('#sf_open-modal .sF-file').click()")
  app$wait_for_js("!document.querySelector('#sf_open-modal #sF-selectButton').disabled")
  app$run_js("document.querySelector('#sf_open-modal #sF-selectButton').click()")
  app$wait_for_js("Boolean(document.getElementById('project_open_trust')?.classList.contains('shiny-bound-input'))")
  click("project_open_trust")
  app$wait_for_js("document.querySelector('[onclick*=\"tree_task_click\"]') !== null")
  for (id in c("head", "model", "script")) {
    app$run_js(sprintf("document.querySelector('[onclick*=\"tree_task_click\"][onclick*=%s]').click()", q(id)))
    ready(id)
    app$wait_for_js(sprintf("document.querySelector(%s) !== null", q(paste0("#panel_status_", id, " .ig-status-success"))))
    cat("Restored", id, "without invalidating its cache.\n")
  }
  app$run_js("ace.edit('scr_script-code').setValue('script_rows <- transform(top_rows, tripled = x * 3)', -1)")
  click("panel_run_btn_script")
  app$wait_for_idle(duration = 1000)
  stopifnot(isTRUE(app$get_js("document.querySelector('#panel_status_model .ig-status-success') !== null")))
  cat("An unrelated live output update preserved model settings and cache.\n")
  app$run_js("document.querySelector('#panel_script [onclick*=\"panel_delete_task\"]').click()")
  app$wait_for_js("document.getElementById('panel_script') === null")
  click("btn_undo")
  for (id in c("head", "model", "script")) ready(id)
  click("btn_save")
  loaded <- make_store(); project_load(loaded, project)
  tasks <- shiny::isolate(loaded$tasks)
  stopifnot(identical(tasks$model$status, "success"), identical(tasks$model$params$predictors, "x"),
    identical(tasks$script$status, "success"), identical(tasks$script$params$input_tables, "top_rows"))
  app$expect_unique_names()
  cat("Undo preserved model and script configuration and caches.\n")
  log <- capture.output(print(app$get_logs()))
  if (any(grepl("JS error|JS warning", log))) stop("Browser diagnostics were recorded.")
}
main()
