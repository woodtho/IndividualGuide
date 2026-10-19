main <- function() {
  Sys.setlocale("LC_CTYPE", ".UTF-8")
  Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe", NOT_CRAN = "true")
  browser <- chromote::Chromote$new(browser = chromote::Chrome$new(args = c(chromote::default_chrome_args(), "--no-first-run", "--disable-sync")))
  chromote::set_default_chromote_object(browser); browser$default_timeout <- 180
  root <- normalizePath(".", winslash = "/")
  artifacts <- file.path(root, "artifacts/review", paste0("product-accessibility-", format(Sys.time(), "%Y%m%d-%H%M%S")))
  dir.create(artifacts, recursive = TRUE)
  sandbox <- tempfile("ig-product-browser-"); dir.create(sandbox)
  writeLines(c("Sys.setlocale('LC_CTYPE', '.UTF-8')",
    sprintf(".libPaths(c(%s, .libPaths()))", deparse(file.path(root, "build/staging/runtime/R/library"))),
    "options(ig.recovery_dir=file.path(tempdir(),'recovery'),ig.catalogue_dir=file.path(tempdir(),'catalogue'),ig.examples_dir=file.path(tempdir(),'examples'))",
    "IndividualGuide::run_app()"), file.path(sandbox, "app.R"))
  app <- shinytest2::AppDriver$new(app_dir = sandbox, width = 1440, height = 900, load_timeout = 180000, timeout = 120000, check_names = FALSE)
  on.exit({
    try(app$get_screenshot(file = file.path(artifacts, "last-screen.png")), silent = TRUE)
    try(capture.output(print(app$get_logs()), file = file.path(artifacts, "logs.txt")), silent = TRUE)
    app$stop()
  })
  app$wait_for_js("Boolean(document.getElementById('splash_fresh')?.classList.contains('shiny-bound-input'))")
  app$run_js(paste(readLines("tools/desktop/node_modules/axe-core/axe.min.js", warn = FALSE), collapse = "\n"))
  audits <- list()
  audit <- function(name, selector = "body") {
    value <- app$get_js(sprintf("(async()=>{const r=await axe.run(%s,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa']}});return {violations:r.violations.map(v=>({id:v.id,impact:v.impact,description:v.description,nodes:v.nodes.map(n=>({target:n.target,summary:n.failureSummary}))})),passes:r.passes.length,incomplete:r.incomplete.map(v=>v.id)}})()", jsonlite::toJSON(selector, auto_unbox = TRUE)))
    audits[[name]] <<- value
    jsonlite::write_json(audits, file.path(artifacts, "axe.json"), auto_unbox = TRUE, pretty = TRUE)
  }
  close_modal <- function() {
    app$wait_for_js("(()=>{const m=document.querySelector('.modal.show');return m && !bootstrap.Modal.getInstance(m)?._isTransitioning})()")
    app$run_js("document.querySelector('.modal.show .modal-footer [data-bs-dismiss=modal],.modal.show .modal-footer [data-dismiss=modal]').click()")
    app$wait_for_js("!document.querySelector('.modal.show')")
  }
  audit("welcome", ".modal.show")
  app$run_js("document.getElementById('splash_fresh').click()")
  app$wait_for_js("!document.querySelector('.modal.show')")
  audit("workspace")
  app$run_js("Shiny.setInputValue('help_example','iris',{priority:'event'})")
  app$wait_for_js("document.getElementById('project_tree_ui').textContent.includes('example_source')")
  app$run_js("document.getElementById('btn_project_tools').click()")
  app$wait_for_js("Boolean(document.getElementById('project_tools-task_search'))")
  app$run_js("document.querySelector('[data-value=tasks]').click()")
  app$wait_for_js("Boolean(document.querySelector('.ig-accessible-task-row button')?.getClientRects().length)")
  audit("task-list", ".modal.show")
  app$run_js("const e=document.getElementById('project_tools-task_search');e.focus();e.value='example_source';e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}))")
  app$wait_for_js("document.querySelectorAll('.ig-accessible-task-row').length===1")
  app$run_js("document.querySelector('.ig-accessible-task-row button').focus()")
  app$get_chromote_session()$Input$dispatchKeyEvent(type = "keyDown", key = "Enter", code = "Enter", windowsVirtualKeyCode = 13, text = "\r")
  app$get_chromote_session()$Input$dispatchKeyEvent(type = "keyUp", key = "Enter", code = "Enter", windowsVirtualKeyCode = 13)
  app$wait_for_js("Boolean(document.getElementById('panel_example_source')?.dataset.igReadyToken)")
  app$run_js("document.getElementById('btn_validate_flow').click()")
  app$wait_for_js("document.querySelector('.modal.show')?.textContent.includes('Flow validation')")
  audit("preflight", ".modal.show"); close_modal()
  app$run_js("Shiny.setInputValue('shortcut_open_tab','console',{priority:'event'})")
  app$wait_for_js("document.getElementById('panel_console').classList.contains('ig-panel-active')")
  audit("console", "#panel_console")
  app$run_js("document.getElementById('btn_settings').click()")
  app$wait_for_js("Boolean(document.getElementById('settings_backup_versions'))")
  audit("settings", ".modal.show"); close_modal()
  app$run_js("document.getElementById('btn_project_tools').click()")
  app$wait_for_js("Boolean(document.getElementById('project_tools-task_search'))")
  app$run_js("document.querySelector('[data-value=tasks]').click()")
  for (scale in c(1.25,1.5,2)) {
    app$set_window_size(width = as.integer(1440 / scale), height = as.integer(900 / scale))
    app$wait_for_js("document.querySelector('.modal.show .modal-footer').getBoundingClientRect().bottom<=innerHeight && document.documentElement.scrollWidth<=innerWidth")
    app$get_screenshot(file = file.path(artifacts, paste0("tasks-scale-", scale, ".png")))
  }
  close_modal()
  result <- list(ok = !any(vapply(audits, function(a) length(a$violations) > 0L, logical(1))),
    keyboardTaskOpen = TRUE, scaling = c(125,150,200), audits = audits, artifacts = artifacts,
    scope = "Automated WCAG checks and keyboard/layout acceptance; manual screen-reader certification remains external.")
  jsonlite::write_json(result, file.path(root, "artifacts/review/product-accessibility-result.json"), auto_unbox = TRUE, pretty = TRUE)
  stopifnot(result$ok)
}
main()
