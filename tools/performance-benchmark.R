# Run the same workloads against a frozen source tree and the updated checkout.
# Timing trials are separate from allocation/CPU profiling, so profiler I/O is
# not counted as a measured interaction time.
args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(args)) args[[1]] else ".", winslash = "/")
label <- if (length(args) > 1L) args[[2]] else "after"
selected <- if (length(args) > 2L) args[[3]] else NULL
Sys.setlocale("LC_CTYPE", ".UTF-8")
destination <- file.path(normalizePath(".", winslash = "/"), "artifacts/performance", label)
dir.create(destination, recursive = TRUE, showWarnings = FALSE)
pkgload::load_all(root, quiet = TRUE)
iso <- shiny::isolate
chain <- function(n = 200L, rows = 1000L) {
  store <- make_store(); flow <- make_flow("Benchmark")
  store$flows <- setNames(list(flow), flow$id); store$active_flow <- flow$id
  store$tables <- list(raw = data.frame(x = seq_len(rows)))
  ids <- paste0("task_", seq_len(n))
  tasks <- setNames(lapply(seq_len(n), function(i) {
    p <- default_first_last_params(paste0("data_", i))
    p$input_table <- if (i == 1L) "raw" else paste0("data_", i - 1L)
    p$n <- 10L
    task <- store_task_from_params(task_def(ids[[i]], "first_last_n"), p)
    task$control_inputs <- character(0); task$run_time <- as.POSIXct("2026-01-01", tz = "UTC")
    task$status <- "success"; task
  }), ids)
  store$tasks <- tasks; store$task_order <- ids
  store
}
timings <- list(); allocations <- list(); fingerprints <- list()
measure <- function(name, setup, action, check = function(value, context) TRUE, profile = FALSE) {
  if (!is.null(selected) && !grepl(selected, name)) return(invisible(NULL))
  for (i in 1:3) {
    context <- setup(); gc()
    elapsed <- system.time(value <- iso(action(context)))
    stopifnot(isTRUE(iso(check(value, context))))
    timings[[length(timings) + 1L]] <<- data.frame(case = name, trial = i,
      elapsed_s = unname(elapsed[["elapsed"]]), cpu_s = sum(elapsed[c("user.self", "sys.self")]))
  }
  context <- setup(); gc()
  memory_file <- file.path(destination, paste0(name, "-allocations.out"))
  Rprofmem(memory_file)
  value <- iso(action(context))
  Rprofmem(NULL)
  stopifnot(isTRUE(iso(check(value, context))))
  lines <- readLines(memory_file, warn = FALSE)
  bytes <- suppressWarnings(as.numeric(sub(" .*", "", lines)))
  allocations[[length(allocations) + 1L]] <<- data.frame(case = name,
    allocated_bytes = sum(bytes, na.rm = TRUE), allocation_count = sum(!is.na(bytes)))
  if (profile) {
    context <- setup()
    Rprof(file.path(destination, paste0(name, "-cpu.out")), interval = 0.01)
    iso(action(context)); Rprof(NULL)
    report <- summaryRprof(file.path(destination, paste0(name, "-cpu.out")))
    write.csv(head(report$by.total, 35L), file.path(destination, paste0(name, "-cpu.csv")))
    write.csv(head(report$by.self, 35L), file.path(destination, paste0(name, "-cpu-self.csv")))
  }
  cat(name, "median:", median(vapply(Filter(function(x) x$case == name, timings), function(x) x$elapsed_s, numeric(1))), "s\n")
  write.csv(do.call(rbind, timings), file.path(destination, "timings.csv"), row.names = FALSE)
  write.csv(do.call(rbind, allocations), file.path(destination, "allocations.csv"), row.names = FALSE)
  invisible(value)
}
measure("invalidate_200", chain, function(store) store_invalidate_outputs(store, "raw"),
  function(value, store) setequal(value, names(store$tasks)), profile = TRUE)
measure("edit_first_200", chain, function(store) {
  task <- store$tasks$task_1; task$params$n <- 8L; store_set_task(store, task)
}, function(value, store) identical(store$tasks$task_1$params$n, 8L), profile = TRUE)
measure("pipeline_40", function() chain(40L), function(store) {
  for (id in store$task_order) stopifnot(isTRUE(run_task_from_store(store, id)))
  store$tables$data_40
}, function(value, store) identical(value, data.frame(x = 1:10)), profile = TRUE)
measure("column_selectors_20", function() {
  store <- chain(1L)
  n <- 200000L
  store$tables <- list(raw = as.data.frame(setNames(lapply(1:12, function(i)
    if (i %% 3L == 0L) rep(c("a", "b", NA_character_), length.out = n) else sin(seq_len(n) / i)), paste0("c", 1:12))))
  store
}, function(store) {
  read <- if (exists("store_col_schema")) store_col_schema else store_col_info
  for (i in 1:20) result <- read(store, "raw")
  result[c("column", "class")]
}, function(value, store) identical(value$column, names(store$tables$raw)), profile = TRUE)
measure("canvas_100_comments_200", function() {
  store <- chain(100L)
  collab <- ig_default_collaboration()
  collab$comments <- setNames(lapply(1:200, function(i) list(scope = "node", target_id = paste0("task_", (i %% 100) + 1L), status = "open")), paste0("thread_", 1:200))
  store$collaboration <- collab; store
}, function(store) canvas_build_network(store), function(value, store) nrow(value$nodes) == 201L, profile = TRUE)
measure("project_save_load_100k", function() {
  store <- chain(20L)
  store$tables <- list(raw = data.frame(id = 1:100000, value = sin(1:100000), category = rep(c("a", "b"), 50000)))
  store
}, function(store) {
  path <- tempfile(fileext = ".igpx"); on.exit(unlink(path))
  project_save(store, path); restored <- make_store(); project_load(restored, path)
  # The existing JSON format rounds some doubles by up to 5.6e-16. Check
  # semantic equality at a tighter tolerance than R's default, retaining exact
  # classes, attributes and integer/string values.
  stopifnot(isTRUE(all.equal(store$tables$raw, restored$tables$raw, tolerance = 1e-14)))
  file.info(path)$size
}, profile = TRUE)
measure("environment_100", function() {
  runtime <- tempfile("ig-profile-manifest-"); dir.create(runtime)
  shipped <- file.path("build/staging/runtime", "packages.csv")
  manifest <- if (file.exists(shipped)) read.csv(shipped, stringsAsFactors = FALSE) else
    data.frame(Package = loadedNamespaces(), Version = vapply(loadedNamespaces(), function(name)
      as.character(getNamespaceVersion(name)), character(1)))
  write.csv(manifest, file.path(runtime, "packages.csv"), row.names = FALSE)
  list(directory = runtime, packages = manifest$Package)
}, function(context) {
  previous <- Sys.getenv("IG_RUNTIME_DIR", unset = NA_character_)
  on.exit({
    if (is.na(previous)) Sys.unsetenv("IG_RUNTIME_DIR") else Sys.setenv(IG_RUNTIME_DIR = previous)
    unlink(context$directory, recursive = TRUE)
  })
  Sys.setenv(IG_RUNTIME_DIR = context$directory)
  for (i in 1:100) value <- ig_environment_info()
  value
}, function(value, context) identical(value$app, as.character(getNamespaceVersion("IndividualGuide"))) &&
  all(context$packages %in% names(value$packages)), profile = TRUE)
measure("run_records_20", function() chain(1L, 100000L), function(store) {
  for (i in 1:20) {
    record <- ig_run_begin(store, "task_1")
    ig_run_finish(store, record, status = "success")
  }
  store$run_records
}, function(value, context) length(value) == 20L &&
  all(vapply(value, function(x) isTRUE(x$inputs$raw$complete), logical(1))), profile = TRUE)
measure("autosave_100k", function() {
  store <- chain(20L, 100000L); store$dirty <- TRUE; store
}, function(store) {
  directory <- tempfile("ig-profile-recovery-")
  previous <- options(ig.recovery_dir = directory)
  on.exit({ options(previous); unlink(directory, recursive = TRUE) })
  path <- project_autosave_recovery(store)
  restored <- make_store(); project_load(restored, path)
  stopifnot(identical(store$tables$raw, shiny::isolate(restored$tables$raw)))
  path
}, profile = TRUE)
measure("filtered_console_5000", function() paste(rep("diagnostic", 12), collapse = " "), function(line) {
  events <- NULL
  value <- ig_capture_task_log(function() {
    for (i in 1:5000) cat(line, "\n")
    42L
  }, list(min_level = "INFO"), list(task_id = "logging", type = "script"),
  emit = function(x) events <<- x, outcome = function(x) list(status = "success"))
  list(value = value, events = vapply(events, `[[`, character(1), "event"))
}, function(value, context) identical(value$value, 42L) && identical(value$events, c("start", "success")))
saveRDS(list(session = sessionInfo(), source = root, timings = do.call(rbind, timings),
  allocations = do.call(rbind, allocations)), file.path(destination, "results.rds"))
