main <- function() {
  Sys.setlocale("LC_CTYPE", ".UTF-8")
  Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    NOT_CRAN = "true", LC_ALL = "English_Canada.utf8", LANG = "English_Canada.utf8")
  options(chromote.timeout = 180)
  browser <- chromote::Chromote$new(browser = chromote::Chrome$new(
    args = c(chromote::default_chrome_args(), "--no-first-run",
      "--no-default-browser-check", "--disable-sync", "--disable-background-networking")))
  chromote::set_default_chromote_object(browser)
  browser$default_timeout <- 180
  args <- commandArgs(trailingOnly = TRUE)
  root <- normalizePath(if (length(args)) args[[1]] else ".", winslash = "/")
  label <- if (length(args) > 1L) args[[2]] else "after"
  workspace <- normalizePath(".", winslash = "/")
  out <- file.path(workspace, "artifacts/performance", paste0("browser-", label))
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  sandbox <- tempfile("ig-perf-browser-"); dir.create(sandbox)
  writeLines(c("Sys.setlocale('LC_CTYPE', '.UTF-8')",
    sprintf("pkgload::load_all(%s, export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)", deparse(root)),
    "options(ig.recovery_dir = file.path(tempdir(), 'performance-recovery'), ig.catalogue_dir = file.path(tempdir(), 'performance-connections'))",
    sprintf("source(%s)", deparse(file.path(workspace, "tools/performance-fixture.R"))),
    "performance_app()"), file.path(sandbox, "app.R"))
  started <- proc.time()[["elapsed"]]
  app <- NULL
  on.exit({
    if (!is.null(app)) {
      try(app$get_screenshot(file = file.path(out, "last-screen.png")), silent = TRUE)
      try(capture.output(print(app$get_logs()), file = file.path(out, "app.log")), silent = TRUE)
      try(app$stop(), silent = TRUE)
    }
    try(browser$close(), silent = TRUE)
  }, add = TRUE)
  app <- shinytest2::AppDriver$new(app_dir = sandbox, width = 1440, height = 900,
    timeout = 120000, load_timeout = 180000, check_names = FALSE)
  results <- list(startup_connected_s = proc.time()[["elapsed"]] - started)
  cat("Connected workspace:", results$startup_connected_s, "s\n")
  q <- function(value) as.character(jsonlite::toJSON(value, auto_unbox = TRUE))
  js <- function(source) app$get_js(source)
  evaluate <- function(browser, source) browser$Runtime$evaluate(expression = source, returnByValue = TRUE)$result$value
  wait <- function(read, predicate, timeout = 120) {
    deadline <- Sys.time() + timeout
    repeat {
      value <- read()
      if (isTRUE(predicate(value))) return(value)
      if (Sys.time() >= deadline) stop("Performance browser wait timed out.")
      later::run_now(0.05)
      Sys.sleep(0.05)
    }
  }
  install <- paste0("window.igPerf={reports:{},pongs:{},outputs:[],started:{}};",
    "Shiny.addCustomMessageHandler('igPerfReport',m=>{igPerf.reports[m.nonce]=m;});",
    "Shiny.addCustomMessageHandler('igPerfPong',n=>{igPerf.pongs[n]=performance.now()-igPerf.started[n];});",
    "$(document).on('shiny:value.igPerf',e=>igPerf.outputs.push(e.name));")
  app$run_js(install)
  app$run_js("document.getElementById('splash_fresh').click()")
  app$wait_for_idle()
  nonce <- 0L
  send <- function(input, value) app$run_js(sprintf("Shiny.setInputValue(%s,%s,{priority:'event'})", q(input), q(value)))
  report <- function() {
    nonce <<- nonce + 1L; key <- paste0("r", nonce)
    send("perf_report", key)
    wait(function() js(sprintf("igPerf.reports[%s]||null", q(key))), function(x) !is.null(x))
  }
  save <- function() jsonlite::write_json(results, file.path(out, "results.json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
  send("perf_setup", 1L); app$wait_for_idle()
  send("perf_open", "first_1")
  app$wait_for_js("document.getElementById('fl_first_1-n')?.classList.contains('shiny-bound-input')")
  app$wait_for_idle()
  baseline <- report()
  results$initial_counters <- baseline$counters
  cat("Fixture ready; measuring edits.\n")
  results$edit_ms <- numeric(3)
  for (i in 1:3) {
    before <- proc.time()[["elapsed"]]
    app$run_js(sprintf("(()=>{const e=document.getElementById('fl_first_1-n');e.value=%s;e.dispatchEvent(new Event('change',{bubbles:true}));})()", q(as.character(i + 10L))))
    app$wait_for_idle()
    results$edit_ms[[i]] <- 1000 * (proc.time()[["elapsed"]] - before)
    save()
  }
  before <- report()
  send("perf_values", 1L); app$wait_for_idle(); after <- report()
  results$value_change_canvas_builds <- (after$counters$canvas_build_network %||% 0) - (before$counters$canvas_build_network %||% 0)
  cat("Table value change:", results$value_change_canvas_builds, "canvas build(s).\n"); save()
  send("perf_open", "query"); app$wait_for_idle()
  before <- proc.time()[["elapsed"]]
  send("perf_schema", 1L); app$wait_for_idle()
  results$schema_change_ms <- 1000 * (proc.time()[["elapsed"]] - before)
  app$wait_for_js("document.querySelector('#panel_query')?.innerText.includes('renamed_column')")
  results$schema_updated <- TRUE
  cat("Schema replacement reflected in the query UI.\n")
  save()

  # A second real websocket session in the same R process, with independent
  # app state. The heavy operation is an actual hierarchical-clustering task.
  second <- chromote::ChromoteSession$new()
  on.exit(try(second$close(), silent = TRUE), add = TRUE, after = FALSE)
  second$Page$navigate(url = js("location.href"))
  wait(function() evaluate(second, "!!window.Shiny?.shinyapp?.$socket && Shiny.shinyapp.$socket.readyState===1"), isTRUE)
  evaluate(second, install)
  evaluate(second, "Shiny.setInputValue('splash_fresh',1,{priority:'event'})")
  ping <- function(key) {
    evaluate(second, sprintf("igPerf.started[%s]=performance.now();Shiny.setInputValue('perf_ping',%s,{priority:'event'})", q(key), q(key)))
    wait(function() evaluate(second, sprintf("igPerf.pongs[%s]??null", q(key))), function(x) is.numeric(x) && length(x) == 1L)
  }
  results$second_session_warmup_ms <- ping("warmup")
  results$idle_ping_ms <- vapply(1:3, function(i) ping(paste0("idle_", i)), numeric(1))
  second_key <- "private_state"
  evaluate(second, sprintf("Shiny.setInputValue('perf_report',%s,{priority:'event'})", q(second_key)))
  private <- wait(function() evaluate(second, sprintf("igPerf.reports[%s]||null", q(second_key))), function(x) !is.null(x))
  stopifnot(length(private$tables) == 0L, length(private$tasks) == 0L)
  results$sessions_isolated <- TRUE
  cat("Independent second session connected; measuring shared-process contention.\n")
  before <- proc.time()[["elapsed"]]
  send("perf_run", 1L)
  later::run_now(0.15)
  results$busy_ping_ms <- ping("busy")
  save()
  wait(function() {
    state <- report()$heavy
    if (identical(state, "error")) stop("Heavy analysis failed; inspect the application log.")
    state
  }, function(x) identical(x, "success"))
  results$heavy_elapsed_s <- proc.time()[["elapsed"]] - before
  completed <- report()
  stopifnot(is.data.frame(completed$result) || is.list(completed$result))
  results$heavy_result <- completed$result
  results$final_counters <- completed$counters
  results$page <- js("({domMs:performance.getEntriesByType('navigation')[0]?.domContentLoadedEventEnd,loadMs:performance.getEntriesByType('navigation')[0]?.loadEventEnd,errors:Array.from(document.querySelectorAll('.shiny-output-error:not(.shiny-output-error-validation)')).filter(e=>e.getClientRects().length).map(e=>e.textContent)})")
  stopifnot(length(results$page$errors) == 0L)
  save()
  print(results[c("startup_connected_s", "edit_ms", "value_change_canvas_builds", "schema_change_ms", "idle_ping_ms", "busy_ping_ms", "heavy_elapsed_s")])
}
`%||%` <- function(x, y) if (is.null(x)) y else x
main()
