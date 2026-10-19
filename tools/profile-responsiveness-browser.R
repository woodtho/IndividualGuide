# Real browser measurements. Uses source from argv[1], so the identical driver
# can measure a frozen baseline and the checkout. No installed app is modified.
main <- function() {
  args <- commandArgs(TRUE)
  source <- normalizePath(if (length(args)) args[[1L]] else ".", winslash = "/")
  label <- if (length(args) > 1L) args[[2L]] else "after"
  enforce <- "--check" %in% args
  autosave_only <- "--autosave-only" %in% args
  root <- normalizePath(".", winslash = "/")
  out <- file.path(root, "artifacts/performance/responsiveness", paste0("browser-", label))
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  Sys.setlocale("LC_CTYPE", ".UTF-8")
  Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    NOT_CRAN = "true", LC_ALL = "English_Canada.utf8", LANG = "English_Canada.utf8")
  browser <- chromote::Chromote$new(browser = chromote::Chrome$new(args = c(
    chromote::default_chrome_args(), "--no-first-run", "--disable-sync", "--disable-background-networking",
    "--disable-background-timer-throttling", "--disable-renderer-backgrounding", "--disable-backgrounding-occluded-windows")))
  chromote::set_default_chromote_object(browser)
  browser$default_timeout <- 180
  sandbox <- tempfile("ig-responsiveness-"); dir.create(sandbox)
  writeLines(c("Sys.setlocale('LC_CTYPE', '.UTF-8')",
    sprintf("pkgload::load_all(%s, export_all=FALSE, helpers=FALSE, attach_testthat=FALSE)", deparse(source)),
    "options(ig.recovery_dir=file.path(tempdir(),'recovery'),ig.catalogue_dir=file.path(tempdir(),'catalogue'))",
    sprintf("source(%s)", deparse(file.path(root, "tools/performance-fixture.R"))),
    sprintf("performance_app(autosave=TRUE, profiles=%s, include_result=FALSE)", deparse(out))), file.path(sandbox, "app.R"))
  app <- NULL
  on.exit({
    if (!is.null(app)) {
      try(app$get_screenshot(file = file.path(out, "screen.png")), silent = TRUE)
      try(capture.output(print(app$get_logs()), file = file.path(out, "app.log")), silent = TRUE)
      try(app$stop(), silent = TRUE)
    }
    try(browser$close(), silent = TRUE)
  }, add = TRUE)
  started <- proc.time()[["elapsed"]]
  app <- shinytest2::AppDriver$new(app_dir = sandbox, width = 1440, height = 900,
    timeout = 120000, load_timeout = 180000, check_names = FALSE)
  results <- list(source = source, startup_connected_s = proc.time()[["elapsed"]] - started,
    autosave_enabled = TRUE)
  page <- app$get_chromote_session()
  page$Page$bringToFront()
  js <- function(code) app$get_js(code)
  q <- function(value) as.character(jsonlite::toJSON(value, auto_unbox = TRUE))
  send <- function(name, value) app$run_js(sprintf("Shiny.setInputValue(%s,%s,{priority:'event'})", q(name), q(value)))
  save <- function() jsonlite::write_json(results, file.path(out, "results.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")
  app$run_js(paste0("window.igPerf={reports:{},started:{},latencies:{},pongs:[],outputs:[],longTasks:[]};",
    "Shiny.addCustomMessageHandler('igPerfReport',m=>{igPerf.reports[m.nonce]=m;if(igPerf.started[m.nonce])igPerf.latencies[m.nonce]=performance.now()-igPerf.started[m.nonce];});",
    "Shiny.addCustomMessageHandler('igPerfPong',n=>{igPerf.pongs.push(performance.now()-igPerf.started[n]);});",
    "Shiny.addCustomMessageHandler('igPerfRecovery',m=>{igPerf.recovery=m;});",
    "$(document).on('shiny:value.igPerf',e=>igPerf.outputs.push(e.name));",
    "new PerformanceObserver(l=>igPerf.longTasks.push(...l.getEntries().map(e=>({start:e.startTime,duration:e.duration})))).observe({type:'longtask',buffered:true});"))
  app$run_js("document.getElementById('splash_fresh').click()")
  app$wait_for_idle()
  send("perf_setup", 1L); app$wait_for_idle()
  send("perf_open", "first_1")
  app$wait_for_js("!!document.getElementById('panel_first_1')?.dataset.igReadyToken")
  app$wait_for_idle()
  nonce <- 0L
  report <- function() {
    nonce <<- nonce + 1L; key <- paste0("report_", nonce)
    send("perf_report", key)
    app$wait_for_js(sprintf("!!igPerf.reports[%s]", q(key)))
    js(sprintf("igPerf.reports[%s]", q(key)))
  }
  difference <- function(after, before, name) (after$counters[[name]] %||% 0L) - (before$counters[[name]] %||% 0L)
  # Record first-edit costs separately from steady typing; widget hydration and
  # first result invalidation must finish before comparing repeated edits.
  initial <- proc.time()[["elapsed"]]
  app$run_js("const e=document.getElementById('fl_first_1-n');e.value='30';e.dispatchEvent(new Event('change',{bubbles:true}))")
  deadline <- Sys.time() + 30
  repeat {
    if (isTRUE(report()$first_params$n == 30L)) break
    if (Sys.time() > deadline) stop("The initial edit did not settle")
  }
  app$wait_for_idle()
  results$initial_edit_settled_ms <- 1000 * (proc.time()[["elapsed"]] - initial)
  if (autosave_only) {
    # Force a real unsaved edit at the start of a window longer than the timer.
    # A cumulative write count alone could otherwise describe an idle window
    # whose recovery file was already up to date before the pings began.
    before <- report()
    send("perf_profile", "start"); app$wait_for_idle()
    app$run_js("igPerf.pongs=[];igPerf.pingN=0;igPerf.waitStarted=performance.now();igPerf.pingTimer=setInterval(()=>{const n='save'+(++igPerf.pingN);igPerf.started[n]=performance.now();Shiny.setInputValue('perf_ping',n,{priority:'event'});},100);const e=document.getElementById('fl_first_1-n');e.value='31';e.dispatchEvent(new Event('change',{bubbles:true}));")
    app$wait_for_js("performance.now()-igPerf.waitStarted>34000", timeout = 45000)
    app$run_js("clearInterval(igPerf.pingTimer)")
    after <- report()
    send("perf_profile", "stop"); app$wait_for_idle()
    send("perf_recovery", "verify")
    app$wait_for_js("igPerf.recovery?.nonce==='verify'")
    results$autosave <- list(writes_during_window = difference(after, before, "project_autosave_recovery"),
      ping_ms = unlist(js("igPerf.pongs")), graph_builds = difference(after, before, "canvas_build_network"),
      restored = js("igPerf.recovery"))
    restored <- results$autosave$restored
    results$ok <- results$autosave$writes_during_window > 0L && is.null(restored$error) &&
      isTRUE(restored$n == 31) && isTRUE(restored$data_identical) &&
      identical(as.integer(unlist(restored$dimensions)), c(200000L, 12L))
    if (enforce) {
      results$gates <- list(no_recovery_graph_build = results$autosave$graph_builds == 0L)
      results$ok <- results$ok && all(unlist(results$gates))
    }
    results$scope <- "Dirty recovery window with real timer, concurrent pings and archive reopen verification"
    save(); stopifnot(results$ok)
    cat("Dirty recovery profiling complete:", file.path(out, "results.json"), "\n")
    return(invisible(NULL))
  }
  before <- report()
  send("perf_profile", "start"); app$wait_for_idle()
  page$Profiler$enable(); page$Profiler$start()
  app$run_js("igPerf.outputs=[];igPerf.editor=document.getElementById('fl_first_1-n');igPerf.editor.focus();")
  for (i in 1:12) {
    key <- paste0("edit_", i)
    app$run_js(sprintf(paste0("(()=>{const e=document.getElementById('fl_first_1-n');",
      "igPerf.started[%s]=performance.now();e.value=%s;e.dispatchEvent(new Event('change',{bubbles:true}));",
      "Shiny.setInputValue('perf_report',%s,{priority:'event'});})()"), q(key), q(as.character(i + 10L)), q(key)))
    app$wait_for_js(sprintf("igPerf.reports[%s]?.first_params.n===%d", q(key), i + 10L))
  }
  app$wait_for_idle()
  after <- report()
  jsonlite::write_json(page$Profiler$stop()$profile, file.path(out, "renderer.cpuprofile"), auto_unbox = TRUE)
  send("perf_profile", "stop"); app$wait_for_idle()
  results$editing <- list(roundtrip_ms = unlist(js("Object.values(igPerf.latencies)")),
    canvas_builds = difference(after, before, "canvas_build_network"),
    code_builds = difference(after, before, "build_full_r_script"),
    outputs = js("igPerf.outputs"),
    editor_preserved = js("igPerf.editor===document.getElementById('fl_first_1-n') && document.activeElement===igPerf.editor"))
  save(); cat("Numeric edits profiled.\n")
  app$run_js("document.querySelector('#panel_first_1 .ig-task-logging').open=true")
  app$wait_for_js("document.getElementById('log_first_1-preview_inputs').textContent.includes('Current task data')")
  results$logging_preview_opens <- TRUE
  app$run_js("document.querySelector('#panel_first_1 .ig-task-logging').open=false")
  app$wait_for_idle()
  send("shortcut_open_tab", "flow"); app$wait_for_idle()
  before <- report(); send("perf_values", 1L); app$wait_for_idle(); after <- report()
  results$value_change <- list(canvas_builds = difference(after, before, "canvas_build_network"))
  before <- report()
  send("perf_open", "query"); app$wait_for_idle()
  send("perf_schema", 1L); app$wait_for_idle()
  app$wait_for_js("document.querySelector('#panel_query')?.innerText.includes('renamed_column')")
  results$schema_refreshed <- TRUE
  save(); cat("Value and schema replacements checked.\n")
  # Test long editor drafts using the actual app handlers and CDP CPU profiler.
  send("shortcut_open_tab", "console")
  app$wait_for_js("document.getElementById('panel_console').classList.contains('ig-panel-active')")
  page$Profiler$start()
  app$run_js("igPerf.frames=[];igPerf.frameStart=performance.now();igPerf.frameLoop=true;(function frame(t){if(!igPerf.frameLoop)return;igPerf.frames.push(t-igPerf.frameStart);igPerf.frameStart=t;requestAnimationFrame(frame);})(performance.now());")
  results$console <- js(paste0("(async()=>{const e=document.getElementById('r_console-editor');e.value='x <- 123 + 456 # draft\\n'.repeat(900);",
    "const latencies=[],handlers=[];let token=null,stable=true;for(let i=0;i<20;i++){const t=performance.now();e.value+='1';e.setSelectionRange(e.value.length,e.value.length);",
    "e.dispatchEvent(new Event('input',{bubbles:true}));handlers.push(performance.now()-t);const pre=e.parentElement.querySelector('.ig-console-highlight');if(i===0)token=pre.firstChild;else stable=stable&&token===pre.firstChild;await new Promise(requestAnimationFrame);latencies.push(performance.now()-t);} ",
    "return {frame_ms:latencies,handler_ms:handlers,visibility:document.visibilityState,token_nodes_preserved:stable,highlight_matches_draft:e.parentElement.querySelector('.ig-console-highlight').textContent===e.value+'\\n',draft_preserved:e.value.endsWith('1'.repeat(20)),highlighted:!!e.parentElement.querySelector('.ig-console-highlight').textContent};})()"))
  jsonlite::write_json(page$Profiler$stop()$profile, file.path(out, "console.cpuprofile"), auto_unbox = TRUE)
  app$run_js("igPerf.frameLoop=false")
  results$console$draft_sent_to_server <- isTRUE(report()$console_draft_on_server)
  save(); cat("Large console draft profiled.\n")
  # Leave the real recovery timer enabled. Repeated websocket pings measure
  # server stalls during autosave without AppDriver's fixed idle-wait padding.
  app$run_js("igPerf.pongs=[];igPerf.pingN=0;igPerf.pingTimer=setInterval(()=>{const n='p'+(++igPerf.pingN);igPerf.started[n]=performance.now();Shiny.setInputValue('perf_ping',n,{priority:'event'});},250);igPerf.waitStarted=performance.now();")
  app$wait_for_js("performance.now()-igPerf.waitStarted>34000", timeout = 45000)
  app$run_js("clearInterval(igPerf.pingTimer)")
  after <- report()
  results$autosave <- list(writes = after$counters$project_autosave_recovery %||% 0L,
    ping_ms = unlist(js("igPerf.pongs")))
  save()
  cat("Real recovery autosave measured.\n")
  # Actual heavy work with pings serviced by the same R server process.
  results$worker <- list()
  for (i in 1:2) {
    previous <- report()$heavy_run_time
    app$run_js("igPerf.pongs=[];igPerf.workStarted=performance.now();igPerf.pingTimer=setInterval(()=>{const n='w'+(++igPerf.pingN);igPerf.started[n]=performance.now();Shiny.setInputValue('perf_ping',n,{priority:'event'});},100);")
    send("perf_run", i)
    deadline <- Sys.time() + 120
    repeat {
      completed <- report(); state <- completed$heavy
      if (identical(state, "error")) stop("Heavy task failed")
      if (identical(state, "success") && !identical(completed$heavy_run_time, previous)) break
      if (Sys.time() > deadline) stop("Heavy task did not finish within 120 seconds")
      Sys.sleep(0.05)
    }
    app$run_js("clearInterval(igPerf.pingTimer)")
    results$worker[[if (i == 1L) "cold" else "warm"]] <- list(elapsed_ms = js("performance.now()-igPerf.workStarted"),
      ping_ms = unlist(js("igPerf.pongs")), pid = completed$worker_pid, result_rows = completed$heavy_rows)
    save()
  }
  results$visible_errors <- js("[...document.querySelectorAll('.shiny-output-error:not(.shiny-output-error-validation)')].filter(e=>e.getClientRects().length).map(e=>e.textContent)")
  results$long_tasks <- js("igPerf.longTasks")
  results$ok <- length(results$visible_errors) == 0L && isTRUE(results$editing$editor_preserved) &&
    isTRUE(results$schema_refreshed) && isTRUE(results$console$draft_preserved) && results$autosave$writes > 0L
  if (enforce) {
    results$gates <- list(no_value_graph_reload = results$value_change$canvas_builds == 0L,
      no_edit_graph_reload = results$editing$canvas_builds == 0L,
      no_hidden_code_build = results$editing$code_builds == 0L,
      no_collapsed_logging_preview = !any(grepl("^log_first_1-preview", unlist(results$editing$outputs))),
      stable_large_draft_highlighting = isTRUE(results$console$token_nodes_preserved) && isTRUE(results$console$highlight_matches_draft),
      console_drafts_stay_in_browser = !isTRUE(results$console$draft_sent_to_server),
      reusable_worker = identical(results$worker$cold$pid, results$worker$warm$pid) &&
        length(results$worker$cold$pid) == 1L && results$worker$warm$result_rows == 6L,
      no_tree_replacement = !"project_tree_ui" %in% results$editing$outputs)
    # Timing targets are reported separately: noisy host load must not turn
    # functional CI into a flaky stopwatch test or hide unmet latency targets.
    results$advisory_budgets <- list(edit_p95_under_300ms = unname(quantile(results$editing$roundtrip_ms, .95)) < 300,
      worker_ping_p95_under_300ms = all(vapply(results$worker, function(x) length(x$ping_ms) && quantile(x$ping_ms, .95) < 300, logical(1))),
      warm_console_handler_p95_under_50ms = unname(quantile(unlist(results$console$handler_ms)[-1L], .95)) < 50)
    results$ok <- results$ok && all(unlist(results$gates))
  }
  save()
  stopifnot(results$ok)
  cat("Browser profiling complete:", file.path(out, "results.json"), "\n")
}
`%||%` <- function(x, y) if (is.null(x)) y else x
main()
