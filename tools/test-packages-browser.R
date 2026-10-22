# Run explicitly: this acceptance check downloads praise@1.0.0 from CRAN into
# a disposable IG profile, exercises the actual manager, and restarts the app.
main <- function() {
  Sys.setlocale("LC_CTYPE", ".UTF-8")
  options(chromote.timeout = 120)
  root <- normalizePath(getwd(), winslash = "/")
  args <- commandArgs(TRUE)
  evidence <- if (length(args)) args[[1L]] else tempfile("ig-package-browser-")
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
      app <- IndividualGuide::run_app()
      jsonlite::write_json(list(paths = .libPaths(), session = getOption("ig.package.session.profile"),
        worker = callr::r(function() find.package("praise"), libpath = .libPaths())),
        file.path(state, "environment.json"), auto_unbox = TRUE, pretty = TRUE)
      shiny::runApp(app, host = "127.0.0.1", port = port, launch.browser = FALSE)
    }, args = list(root, port, state), stdout = file.path(evidence, "server.stdout.log"),
      stderr = file.path(evidence, "server.stderr.log"))
    paste0("http://127.0.0.1:", port)
  }
  on.exit(if (!is.null(server) && server$is_alive()) server$kill_tree(), add = TRUE)
  url <- start()
  Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
  browser <- chromote::Chromote$new()
  browser$default_timeout <- 120
  page <- chromote::ChromoteSession$new(width = 1280, height = 900, parent = browser)
  on.exit({try(page$close(), silent = TRUE); try(browser$close(), silent = TRUE)}, add = TRUE)
  js <- function(code) {
    value <- page$Runtime$evaluate(code, returnByValue = TRUE, awaitPromise = TRUE)
    if (!is.null(value$exceptionDetails)) stop(jsonlite::toJSON(value$exceptionDetails, auto_unbox = TRUE))
    value$result$value
  }
  shot <- function(name) writeBin(jsonlite::base64_dec(page$Page$captureScreenshot(format = "png")$data), file.path(evidence, name))
  wait <- function(test, label, timeout = 150) {
    deadline <- Sys.time() + timeout
    repeat {
      if (isTRUE(tryCatch(test(), error = function(error) FALSE))) return(invisible(TRUE))
      if (!server$is_alive()) stop(paste(readLines(file.path(evidence, "server.stderr.log"), warn = FALSE), collapse = "\n"))
      if (Sys.time() > deadline) {
        try(shot("failure.png"), silent = TRUE)
        try(writeLines(js("document.body.innerText"), file.path(evidence, "failure.txt")), silent = TRUE)
        stop("Package manager browser check timed out: ", label)
      }
      Sys.sleep(.1)
    }
  }
  navigate <- function(url) {
    wait(function() { connection <- url(url); on.exit(close(connection)); length(suppressWarnings(readLines(connection, warn = FALSE))) > 0 }, "HTTP")
    page$go_to(url)
    wait(function() js("Boolean(window.Shiny?.shinyapp?.$socket?.readyState===1&&document.getElementById('splash_fresh'))"), "welcome")
    js("document.getElementById('splash_fresh').click()")
    wait(function() js("!document.querySelector('.modal.show')"), "blank project")
  }
  navigate(url)
  cat("Browser: blank project ready.\n"); flush.console()
  js("document.getElementById('btn_settings').click()")
  wait(function() js("Boolean(document.getElementById('settings_packages')?.classList.contains('shiny-bound-input'))"), "settings entry")
  cat("Browser: Settings entry ready.\n"); flush.console()
  js("document.getElementById('settings_packages').click()")
  wait(function() js("Boolean(document.getElementById('packages-install')?.classList.contains('shiny-bound-input')&&document.querySelector('#packages-packages table'))"), "package manager")
  cat("Browser: manager ready.\n"); flush.console()
  js("window.igI18n.setLanguage('en-CA');$('#packages-package').val('praise').trigger('change');$('#packages-version').val('1.0.0').trigger('change')")
  Sys.sleep(.3)
  js("document.getElementById('packages-install').click()")
  wait(function() js("document.getElementById('packages-status').textContent.includes('were saved')"), "real exact-version installation")
  cat("Browser: installation saved.\n"); flush.console()
  js("$('#packages-packages input[type=search]').val('praise').trigger('input')")
  wait(function() js("document.querySelector('#packages-packages tbody').textContent.includes('praise')&&document.querySelector('#packages-packages tbody').textContent.includes('1.0.0')"), "installed package row")
  shot("manager-installed.png")
  stopifnot(isTRUE(js("document.getElementById('packages-status').textContent.includes('Restart R')")))
  js("window.igI18n.setLanguage('fr-CA')")
  wait(function() js("document.querySelector('.modal-title').textContent.includes('Gestionnaire de paquets R')"), "French manager")
  stopifnot(identical(js("document.getElementById('packages-package').value"), "praise"))
  shot("manager-french.png")
  page$Emulation$setDeviceMetricsOverride(width = 900, height = 720, deviceScaleFactor = 1, mobile = FALSE)
  wait(function() js("document.querySelector('.modal-dialog').getBoundingClientRect().width>800"), "laptop dialog width")
  shot("manager-laptop.png")
  stopifnot(isTRUE(js("document.documentElement.scrollWidth<=window.innerWidth")))
  stopifnot(isTRUE(js("document.querySelector('.modal-body').scrollWidth<=document.querySelector('.modal-body').clientWidth+1")))
  server$kill_tree(); server$wait(3000)
  url <- start(); navigate(url)
  environment <- jsonlite::read_json(file.path(state, "environment.json"), simplifyVector = TRUE)
  stopifnot(startsWith(normalizePath(environment$paths[[1L]], winslash = "/"), paste0(evidence, "/user-data/packages/")),
    startsWith(normalizePath(environment$worker, winslash = "/"), paste0(evidence, "/user-data/packages/")))
  jsonlite::write_json(list(ok = TRUE, checks = c("settings entry", "real CRAN install and pin", "restart notice", "French UI preserves package names", "laptop layout", "persistent IG library after restart", "child process library inheritance")),
    file.path(evidence, "result.json"), auto_unbox = TRUE, pretty = TRUE)
  cat("Package manager browser checks passed. Evidence:", evidence, "\n")
}
main()
