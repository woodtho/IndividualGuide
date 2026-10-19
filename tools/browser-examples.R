main <- function() {
  Sys.setlocale("LC_CTYPE", ".UTF-8")
  Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    NOT_CRAN = "true", LC_ALL = "English_Canada.utf8", LANG = "English_Canada.utf8")
  options(chromote.timeout = 180)
  browser <- chromote::Chromote$new(browser = chromote::Chrome$new(args = c(
    chromote::default_chrome_args(), "--no-first-run", "--no-default-browser-check",
    "--disable-sync", "--disable-background-networking")))
  chromote::set_default_chromote_object(browser)
  browser$default_timeout <- 180
  root <- normalizePath(".", winslash = "/")
  artifacts <- file.path(root, "artifacts/review", paste0("examples-browser-", format(Sys.time(), "%Y%m%d-%H%M%S")))
  dir.create(artifacts, recursive = TRUE, showWarnings = FALSE)
  sandbox <- tempfile("ig-examples-browser-"); dir.create(sandbox)
  writeLines(c("Sys.setlocale('LC_CTYPE', '.UTF-8')",
    sprintf(".libPaths(c(%s, .libPaths()))", deparse(file.path(root, "build/staging/runtime/R/library"))),
    "Sys.setenv(IG_USER_DATA = file.path(tempdir(), 'example-test-profile'))",
    "options(ig.examples_dir = file.path(tempdir(), 'examples'), ig.recovery_dir = file.path(tempdir(), 'recovery'), ig.catalogue_dir = file.path(tempdir(), 'catalogue'))",
    sprintf("pkgload::load_all(%s, quiet=TRUE, export_all=FALSE, helpers=FALSE, attach_testthat=FALSE)", deparse(root)),
    "IndividualGuide::run_app()"), file.path(sandbox, "app.R"))
  app <- shinytest2::AppDriver$new(app_dir = sandbox, name = "examples", width = 1440, height = 900,
    load_timeout = 180000, timeout = 120000, check_names = FALSE)
  on.exit({
    try(app$get_screenshot(file = file.path(artifacts, "last-screen.png")), silent = TRUE)
    try(capture.output(print(app$get_logs()), file = file.path(artifacts, "logs.txt")), silent = TRUE)
    cat("Stopping isolated example app\n")
    app$stop()
    cat("Closing example-test browser\n")
    browser$close()
    cat("Example browser cleanup complete\n")
  })
  checks <- list()
  click <- function(id) {
    quoted <- jsonlite::toJSON(id, auto_unbox = TRUE)
    app$wait_for_js(sprintf("(() => { const e=document.getElementById(%s); return e && e.getClientRects().length>0 && (e.dataset.igExample || e.classList.contains('shiny-bound-input')); })()", quoted))
    app$run_js(sprintf("document.getElementById(%s).click()", quoted))
    app$wait_for_idle()
  }
  help <- function() {
    click("btn_help"); app$wait_for_js("Boolean(document.getElementById('help_example_iris'))")
    app$run_js("document.querySelector('[data-value=\"examples\"]').click()")
    app$wait_for_js("document.getElementById('help_example_iris').getClientRects().length>0")
  }
  app$wait_for_js("Boolean(document.getElementById('splash_fresh')?.classList.contains('shiny-bound-input'))")
  click("splash_fresh"); app$wait_for_js("!document.querySelector('.modal.show')")
  stopifnot(app$get_js("!window.igDesktop && document.getElementById('btn_save').getClientRects().length>0"))
  expected_count <- length(list.dirs(file.path(root, "inst/examples"), full.names = FALSE, recursive = FALSE))
  help(); stopifnot(identical(app$get_js("document.querySelectorAll('[data-ig-example]').length"), as.integer(expected_count)))
  checks$helpCatalog <- TRUE
  app$wait_for_js(sprintf("document.getElementById('ig-example-count').textContent === '%d of %d examples'", expected_count, expected_count))
  stopifnot(isTRUE(app$get_js("(() => {
    const type=document.getElementById('ig-example-type');
    for (const option of Array.from(type.options).slice(1)) {
      type.value=option.value; type.dispatchEvent(new Event('change'));
      const visible=Array.from(document.querySelectorAll('.ig-example-card')).filter(card=>!card.hidden);
      if (!visible.length || visible.some(card=>!card.dataset.tasks.split('|').includes(option.value))) return false;
    }
    type.value=''; type.dispatchEvent(new Event('change')); return true;
  })()")))
  checks$everyTaskFilterHasExamples <- TRUE
  stopifnot(isTRUE(app$get_js("['ig-example-search','ig-example-type','ig-example-category'].every(id=>!Object.prototype.hasOwnProperty.call(Shiny.shinyapp.$inputValues,id))")))
  checks$filtersStayLocal <- TRUE
  app$run_js("(() => {const s=document.getElementById('ig-example-search');s.value='execution audit';s.dispatchEvent(new Event('input'));})()")
  stopifnot(isTRUE(app$get_js("JSON.stringify(Array.from(document.querySelectorAll('.ig-example-card')).filter(c=>!c.hidden).map(c=>c.querySelector('[data-ig-example]').dataset.igExample)) === JSON.stringify(['report-audit'])")))
  app$run_js("(() => {const c=document.getElementById('ig-example-category');c.value='Survival Analysis';c.dispatchEvent(new Event('change'));})()")
  stopifnot(isTRUE(app$get_js("!document.getElementById('ig-example-empty').hidden")))
  app$run_js("document.getElementById('ig-example-search').value='';document.getElementById('ig-example-search').dispatchEvent(new Event('input'))")
  stopifnot(identical(app$get_js("Array.from(document.querySelectorAll('.ig-example-card')).filter(c=>!c.hidden).length"), 1L))
  checks$combinedFiltersAndEmptyState <- TRUE
  app$get_screenshot(file = file.path(artifacts, "filtered-survival.png"))
  app$run_js("document.getElementById('ig-example-category').value='';document.getElementById('ig-example-category').dispatchEvent(new Event('change'))")
  jsonlite::write_json(app$get_js("(() => { const rect=s=>{const e=document.querySelector(s),r=e.getBoundingClientRect(),c=getComputedStyle(e);return {top:r.top,bottom:r.bottom,height:r.height,maxHeight:c.maxHeight,overflow:c.overflowY,marginTop:c.marginTop}};return {innerWidth,innerHeight,scrollWidth:document.documentElement.scrollWidth,dialog:rect('.modal.show .modal-dialog'),content:rect('.modal.show .modal-content'),body:rect('.modal.show .modal-body'),footer:rect('.modal.show .modal-footer'),help:rect('.ig-help-body')};})()"),file.path(artifacts,"layout.json"),auto_unbox=TRUE,pretty=TRUE)
  if ("--layout-only" %in% commandArgs(TRUE)) return(invisible(NULL))
  for (width in c(1440, 1024)) {
    app$set_window_size(width = width, height = 900)
    app$wait_for_js("document.documentElement.scrollWidth<=innerWidth && document.querySelector('.modal.show .modal-footer').getBoundingClientRect().bottom<=innerHeight")
    app$get_screenshot(file = file.path(artifacts, paste0("examples-", width, ".png")))
  }
  checks$layouts <- TRUE
  click("help_example_iris"); app$wait_for_js("!document.querySelector('.modal.show')")
  app$wait_for_js("document.querySelector('.ig-project-name')?.textContent?.includes('Iris') || document.querySelector('.ig-project-header')?.textContent?.includes('Iris') || document.body.textContent.includes('Iris exploration')")
  app$run_js("Shiny.setInputValue('tree_task_click','example_source',{priority:'event'})")
  app$wait_for_js("Boolean(document.getElementById('panel_example_source')?.dataset.igReadyToken)")
  stopifnot(grepl("datasets::iris", app$get_js("ace.edit('scr_example_source-code').getValue()"), fixed = TRUE))
  checks$realProjectLoaded <- TRUE
  help(); click("help_example_air-quality")
  app$wait_for_js("Boolean(document.getElementById('example_cancel')?.classList.contains('shiny-bound-input'))")
  click("example_cancel"); app$wait_for_js("Boolean(document.getElementById('help_example_iris'))")
  stopifnot(grepl("datasets::iris", app$get_js("ace.edit('scr_example_source-code').getValue()"), fixed = TRUE))
  checks$cancelProtectsWork <- TRUE
  app$run_js("document.querySelector('[data-value=\"examples\"]').click()")
  click("help_example_air-quality")
  app$wait_for_js("Boolean(document.getElementById('example_discard')?.classList.contains('shiny-bound-input'))")
  click("example_discard"); app$wait_for_js("!document.querySelector('.modal.show')")
  app$wait_for_js("document.body.textContent.includes('Air quality - clean and compare')")
  app$run_js("Shiny.setInputValue('tree_task_click','example_source',{priority:'event'})")
  app$wait_for_js("Boolean(document.getElementById('panel_example_source')?.dataset.igReadyToken)")
  app$wait_for_js("ace.edit('scr_example_source-code').getValue().includes('datasets::airquality')")
  stopifnot(grepl("datasets::airquality", app$get_js("ace.edit('scr_example_source-code').getValue()"), fixed = TRUE))
  checks$discardLoadsNewProject <- TRUE
  app$run_js("Shiny.setInputValue('shortcut_run_flow', Date.now(),{priority:'event'})")
  app$wait_for_js("window.igRunState?.outcome==='finished'")
  stopifnot(identical(app$get_js("window.igRunState.completed"),10L))
  checks$rerunWithLogging <- TRUE
  app$get_screenshot(file = file.path(artifacts,"loaded-example.png"))
  help(); click("help_example_report-audit")
  app$wait_for_js("Boolean(document.getElementById('example_discard')?.classList.contains('shiny-bound-input'))")
  click("example_discard"); app$wait_for_js("!document.querySelector('.modal.show')")
  app$run_js("Shiny.setInputValue('tree_task_click','example_report',{priority:'event'})")
  app$wait_for_js("Boolean(document.getElementById('panel_example_report')?.dataset.igReadyToken)")
  app$run_js("document.querySelector('#panel_example_report [data-value=\"Appearance\"]').click()")
  app$wait_for_js("document.getElementById('rpt_example_report-include_log').getClientRects().length>0")
  stopifnot(isTRUE(app$get_js("document.getElementById('rpt_example_report-include_log').checked && document.getElementById('rpt_example_report-log_min_level').value==='INFO'")))
  checks$newAuditProjectAndReportSettings <- TRUE
  app$get_screenshot(file = file.path(artifacts, "report-logging.png"))
  result <- list(ok = TRUE, checks = checks, artifacts = artifacts)
  jsonlite::write_json(result, file.path(artifacts,"result.json"), auto_unbox = TRUE, pretty = TRUE)
  jsonlite::write_json(result, file.path(root,"artifacts/review/examples-browser-result.json"), auto_unbox = TRUE, pretty = TRUE)
}
main()
