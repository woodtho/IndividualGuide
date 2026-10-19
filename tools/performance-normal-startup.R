# Verify the normal deferred bootstrap, separately from the eager EXE preflight.
main <- function() {
  root <- normalizePath(".", winslash = "/")
  runtime <- file.path(root, "build/staging/runtime")
  out <- file.path(root, "artifacts/performance/normal-startup")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  state <- tempfile("ig-normal-state-"); dir.create(state)
  stop_file <- file.path(state, "stop")
  port <- httpuv::randomPort()
  environment <- Sys.getenv()
  environment <- environment[!grepl("^(R_HOME|R_LIBS.*|R_PROFILE.*|R_ENVIRON.*|RSTUDIO.*|ELECTRON_RUN_AS_NODE|PATH)$", names(environment), ignore.case = TRUE)]
  rhome <- file.path(runtime, "R"); executable <- file.path(rhome, "bin/x64/Rscript.exe")
  environment <- c(environment, R_HOME = rhome, R_LIBS_USER = file.path(state, "R-library"), R_LIBS_SITE = "",
    R_ENVIRON_USER = "NUL", R_PROFILE_USER = "NUL", RSTUDIO_PANDOC = file.path(runtime, "pandoc"),
    PATH = paste(c(dirname(executable), file.path(runtime, "pandoc"),
      file.path(Sys.getenv("SystemRoot"), "System32/WindowsPowerShell/v1.0"),
      file.path(Sys.getenv("SystemRoot"), "System32"), Sys.getenv("SystemRoot")), collapse = ";"),
    LC_ALL = "English_Canada.utf8", LANG = "English_Canada.utf8", IG_RUNTIME_DIR = runtime,
    IG_USER_DATA = state, IG_WORK_DIR = state, IG_STOP_FILE = stop_file,
    IG_PORT = as.character(port), IG_SMOKE_TEST = "0", http_proxy = "http://127.0.0.1:9", https_proxy = "http://127.0.0.1:9")
  environment <- environment[!duplicated(names(environment), fromLast = TRUE)]
  process <- processx::process$new(executable, c("--vanilla", file.path(runtime, "startup.R")),
    env = environment, stdout = file.path(out, "stdout.log"), stderr = file.path(out, "stderr.log"),
    windows_hide_window = TRUE, cleanup_tree = TRUE)
  browser <- NULL
  on.exit({
    if (!is.null(browser)) try(browser$close(), silent = TRUE)
    writeLines("stop", stop_file)
    process$wait(5000)
    if (process$is_alive()) process$kill_tree()
    unlink(state, recursive = TRUE)
  }, add = TRUE)
  deadline <- Sys.time() + 120
  app_url <- paste0("http://127.0.0.1:", port, "/")
  repeat {
    if (!process$is_alive()) stop("Normal bootstrap stopped: ", paste(readLines(file.path(out, "stderr.log")), collapse = "\n"))
    ready <- tryCatch({ con <- base::url(app_url, open = "r"); close(con); TRUE }, error = function(error) FALSE, warning = function(warning) FALSE)
    if (ready) break
    if (Sys.time() > deadline) stop("Normal bootstrap timed out.")
    Sys.sleep(0.2)
  }
  Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
  browser <- chromote::Chromote$new(browser = chromote::Chrome$new(args = c(
    chromote::default_chrome_args(), "--no-first-run", "--no-default-browser-check", "--disable-sync")))
  browser$default_timeout <- 180
  page <- chromote::ChromoteSession$new(parent = browser)
  js <- function(code) page$Runtime$evaluate(expression = code, returnByValue = TRUE)$result$value
  page$Page$navigate(url = app_url)
  wait <- function(expression) {
    deadline <- Sys.time() + 120
    while (!isTRUE(js(expression))) {
      if (Sys.time() > deadline) stop("Normal startup browser did not become ready.")
      Sys.sleep(0.1)
    }
  }
  wait("!!window.Shiny?.shinyapp?.$socket && Shiny.shinyapp.$socket.readyState===1 && !!document.getElementById('splash_fresh')")
  js("Shiny.setInputValue('splash_fresh',1,{priority:'event'})")
  wait("!document.querySelector('.modal-backdrop') && document.querySelector('.ig-workspace')?.getClientRects().length>0 && !document.documentElement.classList.contains('shiny-busy')")
  errors <- js("[...document.querySelectorAll('.shiny-output-error:not(.shiny-output-error-validation)')].filter(e=>e.getClientRects().length).map(e=>e.textContent)")
  stopifnot(length(errors) == 0L, process$is_alive())
  writeLines("stop", stop_file); process$wait(5000)
  stopifnot(!process$is_alive())
  jsonlite::write_json(list(ok = TRUE, eager_preflight = FALSE, workspace_ready = TRUE,
    visible_errors = errors, backend_stopped = TRUE), file.path(out, "result.json"), pretty = TRUE, auto_unbox = TRUE)
  cat("Normal private-R bootstrap, connected workspace and graceful shutdown passed.\n")
}
main()
