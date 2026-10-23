# helper-fixtures.R — shared data and store fixtures for the test suite.
options(ig.backup_dir = file.path(tempdir(), "IndividualGuide-test-backups"))
options(ig.options.file = file.path(tempdir(), "IndividualGuide-test-global-options.rds"))
# Headless/module unit fixtures run deterministically without dispatching R
# processes. Worker tests explicitly enable the real scheduler; browser and
# packaged acceptance use the normal application defaults.
options(ig.background_workers = 0L)

# A small sales table exercising character, numeric, integer, Date, and NA.
sample_sales <- function() {
  data.frame(
    region  = c("North", "South", "North", "South", "East", "East"),
    product = c("A", "A", "B", "B", "C", "C"),
    amount  = c(10, 20, 30, 40, NA, 60),
    qty     = c(1L, 2L, 3L, 4L, 5L, 6L),
    date    = as.Date("2024-01-01") + 0:5,
    stringsAsFactors = FALSE
  )
}

# Lookup table for join tests.
sample_regions <- function() {
  data.frame(
    region  = c("North", "South", "East", "West"),
    manager = c("Ann", "Bob", "Cal", "Dee"),
    stringsAsFactors = FALSE
  )
}

# Numeric table (mtcars with the rownames promoted to a column).
sample_cars <- function() {
  df <- datasets::mtcars
  df$car <- rownames(df)
  rownames(df) <- NULL
  df
}

tables_fixture <- function() {
  list(
    sales   = sample_sales(),
    regions = sample_regions(),
    cars    = sample_cars()
  )
}

# A store pre-initialised with one flow, mirroring app_server startup.
new_test_store <- function(tables = list()) {
  store <- make_store()
  fl <- make_flow("Flow 1")
  store$flows       <- stats::setNames(list(fl), fl$id)
  store$active_flow <- fl$id
  for (nm in names(tables)) store_add_table(store, nm, tables[[nm]])
  store
}

# Minimal task helper: build + register a task with params in one call.
# task$output always mirrors params$output_name (like the real modules do).
add_test_task <- function(store, id, type, inputs = character(0),
                          output = NULL, params = list()) {
  output <- output %||% params$output_name %||% paste0(id, "_out")
  params$output_name <- params$output_name %||% output
  task <- task_def(id, type, inputs = inputs, output = output, params = params)
  shiny::isolate(store_set_task(store, task))
  task
}

# Override fields of a default-params list. (modifyList() is unsafe here: it
# recursively merges nested lists and silently drops unnamed entries.)
set_params <- function(p, ...) {
  args <- list(...)
  for (nm in names(args)) p[[nm]] <- args[[nm]]
  p
}

module_ready_value <- function(store, id) {
  reader <- shiny::isolate(store$params_fns[[id]])
  environment(reader)$token %||% TRUE
}
wait_for_test_run <- function(session, predicate, timeout = 15) {
  deadline <- Sys.time() + timeout
  repeat {
    session$flushReact()
    later::run_now(0.1)
    session$flushReact()
    if (isTRUE(shiny::isolate(predicate()))) return(invisible(TRUE))
    if (Sys.time() > deadline) stop("Run did not reach its expected state.")
  }
}
