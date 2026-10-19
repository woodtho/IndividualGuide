main <- function() {
  Sys.setlocale("LC_CTYPE", ".UTF-8")
  Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe", NOT_CRAN = "true")
  options(chromote.timeout = 180)
  browser <- chromote::Chromote$new(browser = chromote::Chrome$new(args = c(
    chromote::default_chrome_args(), "--no-first-run", "--no-default-browser-check",
    "--disable-sync", "--disable-background-networking")))
  chromote::set_default_chromote_object(browser)
  browser$default_timeout <- 180
  args <- commandArgs(trailingOnly = TRUE)
  baseline <- length(args) > 0L
  workspace <- normalizePath(".", winslash = "/")
  root <- if (baseline) normalizePath(args[[1]], winslash = "/") else workspace
  pkgload::load_all(root, quiet = TRUE)
  artifacts <- file.path(workspace, "artifacts/audit", paste0("input-", if (baseline) "before-" else "after-", format(Sys.time(), "%Y%m%d-%H%M%S")))
  dir.create(artifacts, recursive = TRUE)
  files <- file.path(artifacts, "files"); dir.create(files)
  store <- make_store(); flow <- make_flow("Typing regression")
  store$flows <- setNames(list(flow), flow$id); store$active_flow <- flow$id
  store$tables <- list(raw = mtcars)
  add <- function(id, type, p) shiny::isolate(store_set_task(store, store_task_from_params(task_def(id, type), p)))
  add("route", "branch", default_branch_params("route"))
  p <- default_first_last_params("head_rows"); p$input_table <- "raw"; p$n <- 10L; add("head", "first_last_n", p)
  p <- default_derive_cols_params("derived"); p$input_table <- "raw"
  p$derives <- list(list(name = "double_mpg", expr = "mpg * 2")); add("derive", "derive_cols", p)
  p <- default_recode_values_params("recoded"); p$input_table <- "raw"; p$col <- "cyl"; p$new_col_name <- "cyl"
  p$rules <- list(list(from = "4", to = "four")); add("recode", "recode_values", p)
  p <- default_rename_cols_params("renamed"); p$input_table <- "raw"
  p$renames <- list(list(old = "mpg", new = "mileage")); add("rename", "rename_cols", p)
  p <- default_qb_params("queried"); p$primary_table <- "raw"
  p$select <- list(list(col = "mpg", alias = "mpg", func = "none", expr = ""))
  p$filters <- list(list(id = "fr1", col = "mpg", op = ">", val = "10", val2 = "", join = "AND"))
  add("query", "query_builder", p)
  p <- default_phase3_params("histogram_graph", "histogram"); p$input_table <- "raw"; p$x <- "mpg"
  add("hist", "histogram_graph", p)
  project <- file.path(files, "typing.igpx"); project_save(store, project)
  sandbox <- tempfile("ig-input-"); dir.create(sandbox)
  writeLines(c("Sys.setlocale('LC_CTYPE', '.UTF-8')",
    sprintf("pkgload::load_all(%s, export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)", deparse(root)),
    sprintf("options(ig.file_roots = c(Audit = %s), ig.recovery_dir = file.path(tempdir(), 'input-recovery'))", deparse(files)),
    "IndividualGuide::run_app()"), file.path(sandbox, "app.R"))
  app <- shinytest2::AppDriver$new(app_dir = sandbox, width = 1440, height = 900,
    timeout = 45000, load_timeout = 120000, check_names = FALSE)
  on.exit({
    try(capture.output(print(app$get_logs()), file = file.path(artifacts, "browser-runtime.log")), silent = TRUE)
    try(app$get_screenshot(file = file.path(artifacts, "last-screen.png")), silent = TRUE)
    try(app$stop(), silent = TRUE)
  }, add = TRUE)
  cat("Artifacts:", artifacts, "\n")
  q <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
  click <- function(id) {
    app$wait_for_js(sprintf("document.getElementById(%s)?.classList.contains('shiny-bound-input')", q(id)))
    app$run_js(sprintf("document.getElementById(%s).click()", q(id))); app$wait_for_idle()
  }
  click("splash_fresh"); app$wait_for_js("document.querySelector('.modal-backdrop') === null")
  click("btn_open")
  app$wait_for_js("document.querySelector('#sf_open-modal .sF-file') !== null")
  app$run_js("document.querySelector('#sf_open-modal .sF-file').click()")
  app$wait_for_js("!document.querySelector('#sf_open-modal #sF-selectButton').disabled")
  app$run_js("document.querySelector('#sf_open-modal #sF-selectButton').click()")
  app$wait_for_js("document.querySelector('[onclick*=\"tree_task_click\"]') !== null")
  results <- list()
  test_input <- function(task, id, values, tab = NULL) {
    app$run_js(sprintf("document.querySelector('[onclick*=\"tree_task_click\"][onclick*=%s]').click()", q(task)))
    app$wait_for_js(sprintf("(() => {const p=document.getElementById(%s);return p?.dataset.igReadyToken && Object.entries(Shiny.shinyapp.$inputValues).some(([k,v])=>k.endsWith(%s)&&v===p.dataset.igReadyToken);})()", q(paste0("panel_", task)), q(paste0("_", task, "-ig_ready"))))
    if (!is.null(tab)) {
      app$run_js(sprintf("Array.from(document.querySelectorAll('#panel_%s [data-bs-toggle=\"tab\"]')).find(e=>e.textContent.trim()===%s).click()", task, q(tab)))
    }
    if (identical(task, "hist")) {
      app$run_js("Array.from(document.querySelectorAll('#panel_hist .accordion-button')).find(e=>e.textContent.trim()==='Plot styling').click()")
    }
    app$wait_for_js(sprintf("document.getElementById(%s)?.getClientRects().length > 0", q(id)))
    app$wait_for_idle()
    # Settle initial binding/normalization before measuring repeated edits.
    app$run_js(sprintf("(() => {const e=document.getElementById(%s);e.focus();e.select();})()", q(id)))
    app$get_chromote_session()$Input$insertText(text = values[[1]])
    app$wait_for_idle(duration = 700)
    app$run_js(sprintf("window.igTyping = {element:document.getElementById(%s),values:[],inputs:[]};$(document).off('.igTyping').on('shiny:value.igTyping',e=>igTyping.values.push(e.name)).on('shiny:updateinput.igTyping',e=>igTyping.inputs.push(e.target.id));", q(id)))
    for (value in values[-1]) {
      app$run_js(sprintf("(() => {const e=document.getElementById(%s);e.focus();e.select();})()", q(id)))
      app$get_chromote_session()$Input$insertText(text = value)
      app$wait_for_idle(duration = 700)
    }
    result <- app$get_js(sprintf("({id:%s,sameElement:igTyping.element===document.getElementById(%s),focused:document.activeElement===igTyping.element,value:document.getElementById(%s).value,outputs:igTyping.values,inputs:igTyping.inputs})", q(id), q(id), q(id)))
    results[[id]] <<- result
    cat(id, "same input:", result$sameElement, "focus:", result$focused, "output updates:", length(result$outputs), "\n")
    writeLines(jsonlite::toJSON(results, auto_unbox = TRUE, pretty = TRUE), file.path(artifacts, "typing-results.json"))
    if (!baseline) {
      stopifnot(isTRUE(result$sameElement), isTRUE(result$focused), identical(result$value, tail(values, 1)))
      forbidden <- c("project_tree_ui", "tab_strip_ui", paste0("panel_control_deps_", task), "hdr_comments_btn", "hdr_review_btn")
      stopifnot(!any(unlist(result$outputs) %in% forbidden))
    }
  }
  test_input("head", "fl_head-n", as.character(11:15))
  test_input("derive", "dc_derive-dexpr_dr1", paste0("mpg * ", 3:7))
  test_input("recode", "rv_recode-rto_rc1", paste0("four", 1:5))
  test_input("rename", "rn_rename-rnew_rr1", paste0("mileage", 1:5))
  test_input("query", "qb_query-fval_fr1", as.character(11:15), "Filter Data")
  test_input("hist", "p3_hist-title", paste0("Histogram ", 1:5))
  click("btn_save")
  loaded <- make_store(); project_load(loaded, project)
  tasks <- shiny::isolate(loaded$tasks)
  stopifnot(tasks$head$params$n == 15, tasks$derive$params$derives[[1]]$expr == "mpg * 7",
    tasks$recode$params$rules[[1]]$to == "four5", tasks$rename$params$renames[[1]]$new == "mileage5",
    tasks$query$params$filters[[1]]$val == "15", tasks$hist$params$title == "Histogram 5")
  app$expect_unique_names()
  diagnostics <- capture.output(print(app$get_logs()))
  if (any(grepl("JS error|JS warning", diagnostics))) stop("JavaScript diagnostics recorded")
  cat("All edited values persisted; unique bindings and JavaScript checks passed.\n")
}
main()
