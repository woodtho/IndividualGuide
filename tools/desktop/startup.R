# Standalone runtime entry point. Called by the desktop shell with --vanilla;
# normal startup uses bundled dependencies and requires no network connection.
Sys.setlocale("LC_CTYPE", ".UTF-8")
startup_started <- proc.time()[["elapsed"]]
startup_log <- function(stage, detail = "") {
  cat(sprintf("[R startup] %s +%.3fs %s %s\n", format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z"),
    proc.time()[["elapsed"]] - startup_started, stage, detail))
}
startup_log("runtime", paste(R.version.string, R.version$platform))
runtime <- normalizePath(Sys.getenv("IG_RUNTIME_DIR"), winslash = "/", mustWork = TRUE)
state <- Sys.getenv("IG_USER_DATA")
if (!nzchar(state)) stop("The desktop shell did not supply a writable data directory.")
dir.create(state, recursive = TRUE, showWarnings = FALSE)
bundle_library <- file.path(runtime, "R/library")
.libPaths(bundle_library, include.site = FALSE)
bootstrap <- new.env(parent = baseenv())
sys.source(file.path(runtime, "package-library.R"), envir = bootstrap)
bootstrap$ig_package_initialize(state, fallback = bundle_library)
startup_log("library.paths", paste(.libPaths(), collapse = "; "))
options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 600)
manifest <- read.csv(file.path(runtime, "packages.csv"), stringsAsFactors = FALSE)
missing <- manifest$Package[!vapply(manifest$Package, function(name)
  file.exists(file.path(bundle_library, name, "DESCRIPTION")), logical(1))]
startup_log("dependency.manifest", sprintf("packages=%d missing=%d", nrow(manifest), length(missing)))
if (length(missing)) {
  stop("Bundled dependencies are missing: ", paste(missing, collapse = ", "), ". Reinstall Individual Guide to repair them.")
}
# Optional database/report/model packages initialize when their tasks use them.
# Loading the whole manifest here triples startup memory and delays even an
# empty workspace. The full dependency preflight remains part of EXE testing.
startup_packages <- if (identical(Sys.getenv("IG_SMOKE_TEST"), "1")) manifest$Package else "IndividualGuide"
startup_log("namespaces.begin", paste(startup_packages, collapse = ", "))
failures <- vapply(startup_packages, function(name) {
  tryCatch({ loadNamespace(name); "" }, error = function(e) paste0(name, ": ", conditionMessage(e)))
}, character(1))
if (any(nzchar(failures))) stop("A bundled dependency could not load:\n", paste(failures[nzchar(failures)], collapse = "\n"))
startup_log("namespaces.ready", paste("IndividualGuide", utils::packageVersion("IndividualGuide"), "Shiny", utils::packageVersion("shiny")))
Sys.setenv(RSTUDIO_PANDOC = file.path(runtime, "pandoc"))
options(ig.desktop = TRUE, ig.recovery_dir = file.path(state, "recovery"), ig.catalogue_dir = file.path(state, "connections"))
working_directory <- Sys.getenv("IG_WORK_DIR")
setwd(if (dir.exists(working_directory)) working_directory else state)
startup_log("workspace.paths", paste("working_directory=", getwd(), "recovery=", getOption("ig.recovery_dir")))

if (identical(Sys.getenv("IG_SMOKE_TEST"), "1")) {
  result <- list(r_home = R.home(), library_paths = .libPaths(), packages = nrow(manifest), checks = list())
  check <- function(name, fn) {
    fn()
    result$checks[[name]] <<- TRUE
  }
  temp <- tempfile("ig-standalone-check-"); dir.create(temp)
  check("backgroundAnalysis", function() {
    ns <- asNamespace("IndividualGuide")
    p <- get("default_phase3_params", ns)("cluster_analysis", "clusters")
    p$input_table <- "raw"; p$predictors <- c("x", "y"); p$k <- 2L
    p$cluster_method <- "hierarchical"
    tables <- list(raw = data.frame(x = 1:30, y = sin(1:30)))
    expected <- get("execute_phase3_task", ns)("cluster_analysis", p, tables)
    session <- shiny::MockShinySession$new()
    on.exit(session$close(), add = TRUE)
    store <- get("make_store", ns)()
    flow <- get("make_flow", ns)("Worker verification")
    store$flows <- stats::setNames(list(flow), flow$id); store$active_flow <- flow$id
    store$tables <- tables
    get("store_init_background", ns)(store, session)
    task <- get("store_task_from_params", ns)(get("task_def", ns)("worker-smoke", "cluster_analysis"), p)
    shiny::isolate(get("store_set_task", ns)(store, task))
    shiny::isolate(get("ig_background_start", ns)(store, task$id))
    deadline <- Sys.time() + 120
    while (!is.null(shiny::isolate(store$background$job)) && Sys.time() < deadline) later::run_now(.05)
    if (!is.null(shiny::isolate(store$background$job))) stop("Bundled analysis worker timed out.")
    actual <- shiny::isolate(store$tasks[[task$id]])
    stopifnot(identical(shiny::isolate(store$tables$clusters), expected$data), is.null(actual$error_msg),
      all(c("start", "success") %in% vapply(actual$log_events, `[[`, character(1), "event")))
  })
  check("arrow", function() {
    path <- file.path(temp, "data.parquet"); arrow::write_parquet(data.frame(x = 1:3), path)
    stopifnot(identical(arrow::read_parquet(path)$x, 1:3))
  })
  check("projectSeed", function() {
    ns <- asNamespace("IndividualGuide")
    store <- get("make_store", ns)()
    p <- get("default_script_params", ns)("seed_rows")
    p$code <- "seed_rows <- data.frame(value=runif(3))"
    task <- get("store_task_from_params", ns)(get("task_def", ns)("seed-smoke", "script"), p)
    shiny::isolate({ store$settings$run_seed <- 91L; get("store_set_task", ns)(store, task) })
    stopifnot(isTRUE(shiny::isolate(get("run_task_from_store", ns)(store, task$id))))
    script <- get("build_full_r_script", ns)(store)
    target <- new.env(parent = globalenv()); eval(parse(text = script), target)
    stopifnot(identical(target$seed_rows, shiny::isolate(store$tables$seed_rows)))
  })
  check("sqlite", function() {
    con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:"); on.exit(DBI::dbDisconnect(con))
    stopifnot(DBI::dbGetQuery(con, "select 7 as value")$value == 7)
  })
  check("duckdb", function() {
    con <- DBI::dbConnect(duckdb::duckdb()); on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
    stopifnot(DBI::dbGetQuery(con, "select 9 as value")$value == 9)
  })
  check("forecast", function() stopifnot(length(forecast::forecast(forecast::ets(datasets::AirPassengers, model = "ANN"), h = 2)$mean) == 2))
  check("plot", function() ggplot2::ggsave(file.path(temp, "plot.svg"), ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point(), width = 4, height = 3))
  check("pandoc", function() {
    stopifnot(rmarkdown::pandoc_available())
    source <- file.path(temp, "report.Rmd")
    writeLines(c("---", "title: Standalone report", "output: word_document", "---", "A bundled Pandoc test."), source)
    stopifnot(file.exists(rmarkdown::render(source, quiet = TRUE)))
  })
  jsonlite::write_json(result, Sys.getenv("IG_RUNTIME_RESULT"), auto_unbox = TRUE, pretty = TRUE)
  unlink(temp, recursive = TRUE)
}

stop_file <- Sys.getenv("IG_STOP_FILE")
watch_stop <- function() {
  if (nzchar(stop_file) && file.exists(stop_file)) shiny::stopApp()
  else later::later(watch_stop, 0.5)
}
later::later(watch_stop, 0.5)
startup_log("application.begin")
application <- IndividualGuide::run_app()
startup_log("application.ready", paste("port=", Sys.getenv("IG_PORT")))
shiny::runApp(application, host = "127.0.0.1", port = as.integer(Sys.getenv("IG_PORT")),
  launch.browser = FALSE, display.mode = "normal")
startup_log("application.stopped")
