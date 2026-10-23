# Actual UI acceptance: scope inheritance, custom R values, console discovery,
# editor preferences and persistence across an application restart.
main <- function() {
  Sys.setlocale("LC_CTYPE", ".UTF-8")
  options(chromote.timeout = 120)
  root <- normalizePath(getwd(), winslash = "/")
  args <- commandArgs(TRUE)
  evidence <- if (length(args)) args[[1L]] else tempfile("ig-options-browser-")
  dir.create(evidence, recursive = TRUE, showWarnings = FALSE)
  evidence <- normalizePath(evidence, winslash = "/")
  state <- file.path(evidence, "user-data")
  server <- NULL
  start <- function() {
    port <- httpuv::randomPort()
    server <<- callr::r_bg(function(root, port, state) {
      Sys.setlocale("LC_CTYPE", ".UTF-8")
      Sys.setenv(IG_USER_DATA = state)
      options(ig.recovery_dir = file.path(state, "recovery"), ig.catalogue_dir = file.path(state, "connections"))
      setwd(root); pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
      shiny::runApp(IndividualGuide::run_app(), host = "127.0.0.1", port = port, launch.browser = FALSE)
    }, args = list(root, port, state), stdout = file.path(evidence, "server.stdout.log"), stderr = file.path(evidence, "server.stderr.log"))
    paste0("http://127.0.0.1:", port)
  }
  on.exit(if (!is.null(server) && server$is_alive()) server$kill_tree(), add = TRUE)
  url <- start()
  Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
  browser <- chromote::Chromote$new(browser = chromote::Chrome$new(args = c(chromote::default_chrome_args(), "--no-first-run", "--no-default-browser-check")))
  page <- chromote::ChromoteSession$new(width = 1440, height = 1000, parent = browser)
  on.exit({try(page$close(), silent = TRUE); try(browser$close(), silent = TRUE)}, add = TRUE)
  js <- function(code) {
    result <- page$Runtime$evaluate(code, returnByValue = TRUE, awaitPromise = TRUE)
    if (!is.null(result$exceptionDetails)) stop(jsonlite::toJSON(result$exceptionDetails, auto_unbox = TRUE))
    result$result$value
  }
  encode <- function(value) as.character(jsonlite::toJSON(value, auto_unbox = TRUE))
  shot <- function(name) writeBin(jsonlite::base64_dec(page$Page$captureScreenshot(format = "png")$data), file.path(evidence, name))
  wait <- function(test, label, timeout = 120) {
    deadline <- Sys.time() + timeout
    repeat {
      if (isTRUE(tryCatch(test(), error = function(error) FALSE))) return(invisible(TRUE))
      if (!server$is_alive()) stop(paste(readLines(file.path(evidence, "server.stderr.log"), warn = FALSE), collapse = "\n"))
      if (Sys.time() > deadline) {
        try(shot("failure.png"), silent = TRUE)
        try(writeLines(js("document.body.innerText"), file.path(evidence, "failure.txt")), silent = TRUE)
        stop("Options browser check timed out: ", label)
      }
      Sys.sleep(.1)
    }
  }
  navigate <- function(url) {
    wait(function() { con <- url(url); on.exit(base::close(con)); length(suppressWarnings(readLines(con, warn = FALSE))) > 0 }, "HTTP")
    page$Page$navigate(url)
    wait(function() {
      if (isTRUE(js("Boolean(document.getElementById('recover_discard')?.classList.contains('shiny-bound-input'))")))
        js("document.getElementById('recover_discard').click()")
      js("Boolean(window.igPreferences&&window.igI18n&&document.getElementById('splash_fresh')?.classList.contains('shiny-bound-input'))")
    }, "welcome")
    js("window.igI18n.setLanguage('en-CA');document.getElementById('splash_fresh').click()")
    wait(function() js("!document.querySelector('.modal.show')"), "blank project")
  }
  open <- function() {
    js("document.getElementById('btn_settings').click()")
    wait(function() js("Boolean(document.getElementById('preferences-add')?.classList.contains('shiny-bound-input')&&window.jQuery?.fn?.dataTable?.isDataTable(document.querySelector('#preferences-options table'))&&$('#preferences-options table').DataTable().page.info().recordsTotal>108)"), "options dialog")
  }
  scope <- function(value) {
    js(sprintf("document.querySelector('#preferences-scope input[value=%s]').click()", encode(value)))
    wait(function() js(sprintf("!document.querySelector('.ig-option-editor')||document.querySelector('.ig-option-editor').textContent.includes(%s)", encode(if (value == "global") "Editing the default" else "This project"))), "scope editor")
    Sys.sleep(.2)
  }
  choose <- function(name) {
    js(sprintf("$('#preferences-search').val(%s).trigger('change')", encode(name)))
    wait(function() js(sprintf("document.querySelector('#preferences-options tbody tr td')?.textContent===%s", encode(name))), paste("option row", name))
    js("document.querySelector('#preferences-options tbody tr button').click()")
    wait(function() js(sprintf("Boolean(document.getElementById('preferences-save')?.classList.contains('shiny-bound-input'))&&(document.getElementById('preferences-name')?.value===%s||document.querySelector('.ig-option-editor > code')?.textContent===%s)&&(document.getElementById('preferences-input')?.classList.contains('shiny-bound-input')||document.getElementById('preferences-kind')?.value==='null')", encode(name), encode(name))), "editor")
  }
  value <- function(text) {
    wait(function() js("Boolean(document.getElementById('preferences-input')?.classList.contains('shiny-bound-input'))"), "bound value input")
    js(sprintf("(()=>{const e=document.getElementById('preferences-input');if(e.selectize)e.selectize.setValue(%s);else $(e).val(%s).trigger('change');})()", encode(text), encode(text)))
    Sys.sleep(.15)
  }
  save <- function() js("document.getElementById('preferences-save').click()")
  read_global <- function() readRDS(file.path(state, "settings", "options.rds"))
  close <- function() {
    js("document.querySelector('.modal-footer [data-bs-dismiss=modal],.modal-footer [data-dismiss=modal]').click()")
    wait(function() js("!document.querySelector('.modal.show')"), "close dialog")
  }
  console <- function(code, expected) {
    js("Shiny.setInputValue('shortcut_open_tab','console',{priority:'event'})")
    wait(function() js("document.getElementById('panel_console').classList.contains('ig-panel-active')"), "console tab")
    js(sprintf("document.getElementById('r_console-editor').value=%s;document.getElementById('r_console-editor').dispatchEvent(new Event('input',{bubbles:true}));document.getElementById('r_console-run').click()", encode(code)))
    wait(function() js(sprintf("document.getElementById('r_console-transcript').textContent.includes(%s)", encode(expected))), paste("console", expected))
  }
  navigate(url); open()
  cat("Options dialog is ready.\n"); flush.console()
  stopifnot(js("$('#preferences-options table').DataTable().page.info().recordsTotal") > 108)
  scope("global"); choose("page_length"); value("75"); save()
  wait(function() identical(read_global()$app$page_length, 75L), "global preview default")
  scope("project"); value("25"); save()
  wait(function() js("window.igPreferences.page_length===25"), "project preview override")
  scope("global"); value("100"); save()
  wait(function() identical(read_global()$app$page_length, 100L), "changed global default")
  stopifnot(isTRUE(js("window.igPreferences.page_length===25")))
  scope("project"); js("document.getElementById('preferences-inherit').click()")
  wait(function() js("window.igPreferences.page_length===100"), "inherit global again")
  cat("Scope inheritance passed.\n"); flush.console()
  scope("global"); js("document.getElementById('preferences-add').click()")
  wait(function() js("Boolean(document.getElementById('preferences-name'))"), "new option editor")
  js("$('#preferences-name').val('myPkg.threshold').trigger('change');document.getElementById('preferences-kind').selectize.setValue('integer')")
  wait(function() js("document.getElementById('preferences-input')?.type==='number'&&document.getElementById('preferences-input').classList.contains('shiny-bound-input')"), "integer editor")
  value("23"); save()
  wait(function() identical(read_global()$r$myPkg.threshold, 23L), "manual R option")
  close()
  console("cat('GLOBAL_VALUE=',getOption('myPkg.threshold'),'\\n',sep='');options(myConsolePackage.setting=c('a','b'))", "GLOBAL_VALUE=23")
  open(); choose("myConsolePackage.setting")
  wait(function() js("document.querySelector('#preferences-options tbody').textContent.includes('R console session')"), "console package discovery")
  scope("project"); choose("myPkg.threshold")
  js("document.getElementById('preferences-kind').selectize.setValue('null')"); save()
  wait(function() js("document.querySelector('#preferences-options tbody').textContent.includes('Project override')&&document.querySelector('#preferences-options tbody').textContent.includes('NULL')"), "explicit project NULL")
  choose("editor_font_size"); value("19"); save()
  wait(function() js("window.igPreferences.editor_font_size===19"), "editor font preference")
  choose("editor_wrap"); value("TRUE"); save()
  wait(function() js("window.igPreferences.editor_wrap===true"), "editor wrap preference")
  choose("language"); value("fr-CA"); save()
  wait(function() js("document.documentElement.lang==='fr-CA'&&window.igPreferences.language==='fr-CA'"), "project language override")
  stopifnot(identical(read_global()$app$language, "en-CA"))
  js("window.igI18n.setLanguage('en-CA')")
  wait(function() js("document.documentElement.lang==='fr-CA'"), "project language survives a global language choice")
  shot("options-project.png"); close()
  console("cat('PROJECT_VALUE=',getOption('myPkg.threshold','unset'),'\\n',sep='')", "PROJECT_VALUE=unset")
  js("document.getElementById('btn_add_task').click()")
  wait(function() js("Boolean(document.querySelector('[onclick*=picker_select][onclick*=script]'))"), "script picker")
  js("document.querySelector('[onclick*=picker_select][onclick*=script]').click()")
  wait(function() js("Boolean(window.ace&&document.getElementById('scr_script_1-code'))"), "script editor")
  wait(function() js("parseInt(ace.edit('scr_script_1-code').getFontSize())===19&&ace.edit('scr_script_1-code').session.getUseWrapMode()"), "live Ace preferences")
  open()
  wait(function() js("document.documentElement.lang==='fr-CA'"), "French options")
  shot("options-french.png")
  page$Emulation$setDeviceMetricsOverride(width = 900, height = 720, deviceScaleFactor = 1, mobile = FALSE)
  Sys.sleep(.4); shot("options-laptop.png")
  stopifnot(isTRUE(js("document.documentElement.scrollWidth<=window.innerWidth&&document.querySelector('.modal-body').scrollWidth<=document.querySelector('.modal-body').clientWidth+1")))
  server$kill_tree(); server$wait(3000)
  url <- start(); navigate(url)
  wait(function() js("window.igPreferences.page_length===100&&window.igPreferences.editor_font_size===13"), "global defaults after restart")
  console("cat('RESTART_VALUE=',getOption('myPkg.threshold'),'\\n',sep='')", "RESTART_VALUE=23")
  open(); scope("global")
  js("document.querySelector('.ig-options-content > details').open=true;document.getElementById('preferences-reset_scope').click()")
  wait(function() js("window.igPreferences.page_length===10&&document.documentElement.lang==='en-CA'") && length(read_global()$app) == 0L && length(read_global()$r) == 0L, "reset global defaults")
  close()
  console("cat('RESET_VALUE=',getOption('myPkg.threshold','unset'),'\\n',sep='')", "RESET_VALUE=unset")
  jsonlite::write_json(list(ok = TRUE, checks = c("all-options catalogue", "global/project precedence", "inherit/reset", "custom option", "explicit NULL", "console option discovery", "live editor settings", "responsive bilingual UI", "global persistence and clean new-project defaults")), file.path(evidence, "result.json"), auto_unbox = TRUE, pretty = TRUE)
  cat("Options browser checks passed:", evidence, "\n")
}
main()
