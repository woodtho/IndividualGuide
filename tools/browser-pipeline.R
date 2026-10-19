main <- function() {
  Sys.setlocale("LC_CTYPE", ".UTF-8")
  Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    NOT_CRAN = "true", LC_ALL = "English_Canada.utf8", LANG = "English_Canada.utf8")
  browser <- chromote::default_chromote_object(); browser$default_timeout <- 180
  root <- normalizePath(".", winslash = "/")
  pkgload::load_all(root, quiet = TRUE)
  artifacts <- file.path(root, "artifacts", "audit", paste0("pipeline-", format(Sys.time(), "%Y%m%d-%H%M%S")))
  dir.create(artifacts, recursive = TRUE)
  files <- file.path(artifacts, "files"); dir.create(files)
  exports <- file.path(files, "exports"); dir.create(exports)
  csv <- file.path(files, "input.csv"); write.csv(data.frame(x = 1:5), csv, row.names = FALSE)
  store <- make_store(); flow <- make_flow("Branched reporting pipeline")
  store$flows <- setNames(list(flow), flow$id); store$active_flow <- flow$id
  add <- function(id, type, params, control = character(0)) {
    task <- store_task_from_params(task_def(id, type), params)
    task$control_inputs <- control
    shiny::isolate(store_set_task(store, task))
  }
  p <- default_import_params("raw"); p$path <- csv; p$type <- "csv"; add("import", "import_data", p)
  p <- default_qb_params("filtered"); p$primary_table <- "raw"; add("query", "query_builder", p)
  p <- default_branch_params("gate"); p$dependencies <- "filtered"
  p$paths[[1]]$condition$rules[[1]]$expr <- "nrow(filtered) == 5"
  add("gate", "branch", p)
  p <- default_loop_params("repeat"); p$values <- "2\n3"; add("repeat", "loop", p, "gate_true")
  p <- default_script_params("result"); p$input_tables <- "filtered"
  p$code <- "result <- transform(filtered, scaled = x * as.numeric(item))"
  add("calculate", "script", p, "repeat_each")
  add("report", "report", list(output_name = "document", title = "Iteration {item}", format = "html",
    items = list(list(name = "result", kind = "table", heading = "Scaled results"))), "repeat_each")
  p <- default_export_params(); p$source <- "result"; p$dir <- exports; p$filename <- "{item}_rows"; p$overwrite <- TRUE
  add("export", "export", p, "repeat_each")
  p <- default_script_params("unselected"); p$code <- "stop('Inactive branch executed')"
  add("inactive", "script", p, "gate_else")
  project <- file.path(files, "pipeline.igpx"); project_save(store, project)
  sandbox <- tempfile("ig-browser-pipeline_"); dir.create(sandbox)
  writeLines(c("Sys.setlocale('LC_CTYPE', '.UTF-8')",
    sprintf("pkgload::load_all(%s, export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)", deparse(root)),
    sprintf("options(ig.file_roots = c(Audit = %s), ig.catalogue_dir = file.path(tempdir(), 'catalogue'), ig.recovery_dir = file.path(tempdir(), 'recovery'))", deparse(files)),
    "IndividualGuide::run_app()"), file.path(sandbox, "app.R"))
  app <- shinytest2::AppDriver$new(app_dir = sandbox, width = 1440, height = 900,
    load_timeout = 180000, timeout = 180000, check_names = FALSE)
  on.exit({
  try({
    capture.output(print(app$get_logs()), file = file.path(artifacts, "browser-runtime.log"))
    app$get_screenshot(file = file.path(artifacts, "last-screen.png")); app$stop()
    }, silent = TRUE)
  try(app$stop(), silent = TRUE)
}, add = TRUE)
  cat("Artifacts:", artifacts, "\n")
  app$wait_for_js("document.querySelector('#splash_fresh.shiny-bound-input') !== null")
  app$click("splash_fresh"); app$wait_for_js("document.querySelector('.modal-backdrop') === null")
  app$click("btn_open")
  app$wait_for_js("document.querySelector('#sf_open-modal .sF-file') !== null")
  app$run_js("Array.from(document.querySelectorAll('#sf_open-modal .sF-file')).find(e => e.querySelector('.sF-file-name').innerText === 'pipeline.igpx').click()")
  app$run_js("document.querySelector('#sf_open-modal #sF-selectButton').click()")
  app$wait_for_js("document.querySelector('[onclick*=\"tree_run_flow\"]') !== null")
  app$wait_for_idle()
  app$run_js("document.querySelector('[onclick*=\"tree_run_flow\"]').click()")
  app$wait_for_js("document.body.innerText.includes('Flow finished:')")
  app$wait_for_idle()
  cat(app$get_js("document.querySelector('.shiny-notification')?.innerText || ''"), "\n")
  app$click("btn_save"); app$wait_for_idle()
  loaded <- make_store(); project_load(loaded, project)
  tasks <- shiny::isolate(loaded$tasks)
  stopifnot(identical(tasks$inactive$status, "skipped"), identical(tasks[["repeat"]]$status, "success"),
    tasks[["repeat"]]$loop_completed_iterations == 2L,
    identical(shiny::isolate(loaded$tables$calculate_2$scaled), c(2, 4, 6, 8, 10)),
    identical(shiny::isolate(loaded$tables$calculate_3$scaled), c(3, 6, 9, 12, 15)),
    file.exists(file.path(exports, "2_rows.csv")), file.exists(file.path(exports, "3_rows.csv")))
  reports <- Filter(function(spec) identical(spec$kind, "report"), tasks[["repeat"]]$outputs)
  stopifnot(length(reports) == 2L, all(vapply(reports, function(x) file.exists(x$path), logical(1))))
  app$run_js("document.querySelector('[onclick*=\"tree_task_click\"][onclick*=\"report\"]').click()")
  app$wait_for_js("document.getElementById('panel_report') !== null")
  app$wait_for_idle(); app$expect_unique_names()
  app$get_screenshot(file = file.path(artifacts, "loop-report-restored.png"))
  log <- capture.output(print(app$get_logs()))
  if (any(grepl("JS error|JS warning", log))) stop("Browser runtime diagnostics were recorded.")
  cat("Real import/query/branch/loop/script/report/export execution and archived artifacts passed.\n")
}
main()
