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
  source_mode <- "--source" %in% commandArgs(TRUE)
  artifacts <- file.path(root, "artifacts/review", paste0("console-terminal-", format(Sys.time(), "%Y%m%d-%H%M%S")))
  dir.create(artifacts, recursive = TRUE, showWarnings = FALSE)
  sandbox <- tempfile("ig-console-browser-"); dir.create(sandbox)
  writeLines(c("Sys.setlocale('LC_CTYPE', '.UTF-8')",
    if (source_mode) sprintf("pkgload::load_all(%s,export_all=FALSE,helpers=FALSE,attach_testthat=FALSE)", deparse(root)) else
      sprintf(".libPaths(c(%s, .libPaths()))", deparse(file.path(root, "build/staging/runtime/R/library"))),
    "options(ig.recovery_dir = file.path(tempdir(), 'recovery'), ig.catalogue_dir = file.path(tempdir(), 'catalogue'))",
    "IndividualGuide::run_app()"), file.path(sandbox, "app.R"))
  app <- shinytest2::AppDriver$new(app_dir = sandbox, name = "console", width = 1440, height = 900,
    load_timeout = 180000, timeout = 120000, check_names = FALSE)
  on.exit({
    try(jsonlite::write_json(app$get_js("({active:document.activeElement?.id,panels:[...document.querySelectorAll('.ig-task-panel')].filter(e=>e.classList.contains('ig-panel-active')).map(e=>e.id)})"), file.path(artifacts, "focus.json"), auto_unbox = TRUE, pretty = TRUE), silent = TRUE)
    try(app$get_screenshot(file = file.path(artifacts, "last-screen.png")), silent = TRUE)
    try(capture.output(print(app$get_logs()), file = file.path(artifacts, "logs.txt")), silent = TRUE)
    app$stop()
  })
  checks <- list()
  app$wait_for_js("Boolean(document.getElementById('splash_fresh')?.classList.contains('shiny-bound-input'))")
  app$run_js("document.getElementById('splash_fresh').click()")
  app$wait_for_js("!document.querySelector('.modal.show')")
  stopifnot(app$get_js("!window.igDesktop && document.getElementById('btn_save').getClientRects().length>0 && document.getElementById('btn_open').getClientRects().length>0"))
  checks$ordinaryBrowserControls <- TRUE
  app$run_js("document.body.dispatchEvent(new KeyboardEvent('keydown',{key:'c',ctrlKey:true,altKey:true,bubbles:true}))")
  app$wait_for_js("document.getElementById('panel_console').classList.contains('ig-panel-active')")
  checks$consoleKeyboardAccess <- TRUE
  app$wait_for_js("document.activeElement===document.getElementById('r_console-editor')")
  checks$focusOnOpen <- TRUE
  app$run_js("document.getElementById('tabpill_code').click()")
  app$wait_for_js("document.getElementById('panel_code').classList.contains('ig-panel-active')")
  app$run_js("const tab=document.getElementById('tabpill_code');tab.focus();tab.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowDown',bubbles:true,cancelable:true}))")
  app$wait_for_js("document.getElementById('panel_console').classList.contains('ig-panel-active') && document.activeElement===document.getElementById('tabpill_console')")
  checks$tabNavigationKeepsFocus <- TRUE
  app$run_js("document.getElementById('r_console-editor').focus()")
  run <- function(code) {
    app$wait_for_js("document.querySelector('.ig-console').dataset.busy==='false' && !document.getElementById('r_console-run').disabled")
    app$run_js(sprintf("document.getElementById('r_console-editor').value=%s; document.getElementById('r_console-editor').dispatchEvent(new Event('input',{bubbles:true})); document.getElementById('r_console-editor').dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true}))", jsonlite::toJSON(code, auto_unbox = TRUE)))
    app$wait_for_js(sprintf("document.getElementById('r_console-transcript').textContent.includes(%s)", jsonlite::toJSON(paste0("> ", strsplit(code,"\n")[[1]][[1]]), auto_unbox = TRUE)))
    app$wait_for_js("document.querySelector('.ig-console').dataset.busy==='false' && !document.getElementById('r_console-run').disabled")
  }
  run("browser_value <- 42; browser_value\nplot(1:4)")
  app$wait_for_js("document.querySelector('.ig-console-plot')?.naturalWidth===1000")
  stopifnot(grepl("\\[1\\] 42", app$get_js("document.getElementById('r_console-transcript').textContent")))
  checks$commandAndPlot <- TRUE
  run("browser_value + 1")
  stopifnot(grepl("\\[1\\] 43", app$get_js("document.getElementById('r_console-transcript').textContent")))
  checks$persistentVariables <- TRUE
  stopifnot(app$get_js("document.querySelector('#r_console-transcript .ig-console-command').textContent.startsWith('> ')"))
  checks$enterRuns <- TRUE
  app$run_js("document.getElementById('r_console-editor').dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowUp',altKey:true,bubbles:true}))")
  stopifnot(identical(app$get_js("document.getElementById('r_console-editor').value"), "browser_value + 1"))
  checks$history <- TRUE
  app$run_js("const e=document.getElementById('r_console-editor');e.value='unsent draft';e.setSelectionRange(e.value.length,e.value.length);e.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowDown',altKey:true,bubbles:true}));e.value='unsent draft';e.setSelectionRange(e.value.length,e.value.length);e.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowUp',bubbles:true}))")
  stopifnot(identical(app$get_js("document.getElementById('r_console-editor').value"), "browser_value + 1"))
  app$run_js("document.getElementById('r_console-editor').dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowDown',bubbles:true}))")
  stopifnot(identical(app$get_js("document.getElementById('r_console-editor').value"), "unsent draft"))
  checks$arrowHistoryRestoresDraft <- TRUE
  # Real browser input verifies Shift+Enter inserts a newline without submitting.
  app$run_js("const e=document.getElementById('r_console-editor');e.value='first';e.focus();e.setSelectionRange(5,5)")
  app$get_chromote_session()$Input$dispatchKeyEvent(type = "keyDown", key = "Enter", code = "Enter", windowsVirtualKeyCode = 13, modifiers = 8, text = "\r", unmodifiedText = "\r")
  app$get_chromote_session()$Input$dispatchKeyEvent(type = "keyUp", key = "Enter", code = "Enter", windowsVirtualKeyCode = 13, modifiers = 8)
  stopifnot(identical(app$get_js("document.getElementById('r_console-editor').value"), "first\n"))
  checks$shiftEnterNewline <- TRUE
  app$run_js("const e=document.getElementById('r_console-editor');e.value='one\\ntwo\\nthree';e.dispatchEvent(new Event('input',{bubbles:true}));e.setSelectionRange(5,5);const k=new KeyboardEvent('keydown',{key:'ArrowUp',bubbles:true,cancelable:true});e.dispatchEvent(k);window.multilineArrowUnchanged=!k.defaultPrevented && e.value==='one\\ntwo\\nthree'")
  stopifnot(app$get_js("window.multilineArrowUnchanged && document.getElementById('r_console-editor').clientHeight>55"))
  checks$multilineEditing <- TRUE
  run("cat('<img src=x onerror=alert(1)>\\n'); warning('terminal warning'); stop('terminal error')")
  stopifnot(app$get_js("!document.querySelector('#r_console-transcript img') && Boolean(document.querySelector('#r_console-transcript .ig-console-warning')) && Boolean(document.querySelector('#r_console-transcript .ig-console-error'))"))
  checks$safeColoredOutput <- TRUE
  run("cat('Error'); Sys.sleep(0.4); cat(': streamed line\\n')")
  stopifnot(app$get_js("Array.from(document.querySelectorAll('#r_console-transcript .ig-console-error')).some(e=>e.textContent.includes('Error: streamed line'))"))
  checks$partialLineColor <- TRUE
  # Stay in scrollback while a long command produces more output.
  app$run_js("window.consoleEditorNode=document.getElementById('r_console-editor');consoleEditorNode.value='cat(paste0(1:400, collapse=\"\\\\n\")); Sys.sleep(2); cat(\"\\\\nLATEST_MARKER\")';consoleEditorNode.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',ctrlKey:true,bubbles:true}))")
  app$wait_for_js("document.querySelector('.ig-console').dataset.busy==='true' && document.querySelector('.ig-console-results').scrollHeight>1500")
  app$run_js("const s=document.querySelector('.ig-console-results');s.scrollTop=0;s.dispatchEvent(new Event('scroll'));consoleEditorNode.value='next command draft'")
  app$wait_for_js("document.querySelector('.ig-console').dataset.busy==='false'")
  stopifnot(app$get_js("document.querySelector('.ig-console-results').scrollTop===0 && !document.querySelector('.ig-console-latest').hidden && document.getElementById('r_console-editor')===consoleEditorNode && consoleEditorNode.value==='next command draft'"))
  app$run_js("document.querySelector('.ig-console-latest').click()")
  stopifnot(app$get_js("document.querySelector('.ig-console-latest').hidden"))
  checks$scrollbackAndStableDraft <- TRUE
  app$run_js("consoleEditorNode.value='Sys.sleep(60)';consoleEditorNode.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true}))")
  app$wait_for_js("document.querySelector('.ig-console').dataset.busy==='true'")
  app$run_js("consoleEditorNode.value='selected';consoleEditorNode.setSelectionRange(0,8);const k=new KeyboardEvent('keydown',{key:'c',ctrlKey:true,bubbles:true,cancelable:true});consoleEditorNode.dispatchEvent(k);window.copyNotInterrupted=!k.defaultPrevented")
  stopifnot(app$get_js("window.copyNotInterrupted && document.querySelector('.ig-console').dataset.busy==='true'"))
  app$run_js("consoleEditorNode.setSelectionRange(8,8);consoleEditorNode.dispatchEvent(new KeyboardEvent('keydown',{key:'c',ctrlKey:true,bubbles:true}))")
  app$wait_for_js("document.querySelector('.ig-console').dataset.busy==='false'")
  stopifnot(grepl("Stopped.", app$get_js("document.getElementById('r_console-transcript').textContent"), fixed = TRUE))
  checks$ctrlCInterruptKeepsCopy <- TRUE
  run("browser_value <- 42; cat('Terminal ready\\n')")
  for (width in c(1440, 1024)) {
    app$set_window_size(width = width, height = 900)
    app$wait_for_js("document.documentElement.scrollWidth<=innerWidth && document.querySelector('.ig-console-editor').getBoundingClientRect().bottom<=innerHeight")
    app$get_screenshot(file = file.path(artifacts, paste0("console-", width, ".png")))
  }
  checks$responsiveLayout <- TRUE
  app$run_js("document.documentElement.setAttribute('data-ig-theme','light')")
  app$get_screenshot(file = file.path(artifacts, "console-light.png"))
  stopifnot(app$get_js("getComputedStyle(document.querySelector('.ig-console-surface')).backgroundColor==='rgb(250, 251, 252)'"))
  app$run_js("document.documentElement.setAttribute('data-ig-theme','dark')")
  checks$lightTheme <- TRUE
  app$run_js("document.getElementById('r_console-editor').dispatchEvent(new KeyboardEvent('keydown',{key:'l',ctrlKey:true,bubbles:true}))")
  app$wait_for_js("!document.getElementById('r_console-transcript').textContent && !document.querySelector('.ig-console-plot')")
  run("browser_value")
  stopifnot(grepl("\\[1\\] 42", app$get_js("document.getElementById('r_console-transcript').textContent")))
  checks$clearRetainsWorkspace <- TRUE
  jsonlite::write_json(list(ok = TRUE, checks = checks), file.path(artifacts, "result.json"), auto_unbox = TRUE, pretty = TRUE)
  jsonlite::write_json(list(ok = TRUE, checks = checks, artifacts = artifacts), file.path(root, "artifacts/review/terminal-browser-result.json"), auto_unbox = TRUE, pretty = TRUE)
}
main()
