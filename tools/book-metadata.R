# Refresh the handbook's authoritative catalogue/defaults and example snapshots.
# No user profile, project, database connection or task execution is touched.
args <- commandArgs(TRUE)
if (.Platform$OS.type == "windows") Sys.setlocale("LC_CTYPE", ".UTF-8")
root <- normalizePath(".", winslash = "/")
pkgload::load_all(root, export_all = FALSE, helpers = FALSE, attach_testthat = FALSE, quiet = TRUE)
ns <- asNamespace("IndividualGuide")
get_ig <- function(name) get(name, ns)
constructors <- c(import_data = "default_import_params", query_builder = "default_qb_params", keep_drop_cols = "default_keep_drop_params",
  first_last_n = "default_first_last_params")
defaults <- function(type) {
  if (type %in% get_ig("PHASE3_TYPES")) return(get_ig("default_phase3_params")(type, "result"))
  name <- constructors[[type]]
  if (is.null(name)) name <- paste0("default_", type, "_params")
  get_ig(name)("result")
}
# Named-vector [[ fails for absent names; preserve a predictable lookup.
constructors <- as.list(constructors)
registry <- lapply(get_ig("TASK_REGISTRY"), function(task) {
  task$defaults <- defaults(task$id)
  task$defaults_r <- paste(capture.output(dput(task$defaults)), collapse = "\n")
  task$help <- get_ig("ig_task_help_details")()[[task$id]]
  if (task$id %in% get_ig("PHASE3_TYPES")) task$output_definitions <- get_ig("phase3_return_defs")(task$id)
  task
})
catalog <- get_ig("ig_example_catalog")()
examples <- lapply(catalog, function(info) {
  cat("Reading example", info$id, "\n")
  archive <- file.path(root, "inst/examples", info$id, "project.igpx")
  directory <- tempfile("ig-book-example-"); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  utils::unzip(archive, exdir = directory)
  flows <- get_ig("project_read_payload")(file.path(directory, "flows.json"))$value
  flow <- flows[[1L]]
  info$tasks <- lapply(flow$task_order, function(id) {
    task <- flow$tasks[[id]]
    p <- task$params
    base <- defaults(task$type)
    changed <- names(p)[!vapply(names(p), function(name) identical(p[[name]], base[[name]]), logical(1))]
    changed <- setdiff(changed, c("output_names", "output_enabled", "type_id"))
    list(id = id, type = task$type, label = task$label, note = task$note,
      status = task$status, inputs = task$inputs, outputs = task$outputs,
      control_inputs = task$control_inputs, params = p,
      changed_params = p[changed], log_events = length(task$log_events))
  })
  files <- list.files(file.path(directory, "tables"), pattern = "[.]json$", full.names = TRUE)
  info$tables <- lapply(files, function(path) {
    payload <- get_ig("project_read_payload")(path)
    data <- payload$value
    list(name = payload$name, rows = nrow(data), columns = names(data),
      classes = vapply(data, function(column) paste(class(column), collapse = "/"), character(1)),
      preview = utils::head(data, 3L))
  })
  info$exports <- list.files(file.path(root, "inst/examples", info$id, "outputs"))
  info$archive_md5 <- unname(tools::md5sum(archive))
  info
})
paths <- c(list.files("R", full.names = TRUE, pattern = "[.]R$"), "DESCRIPTION",
  "tools/desktop/menus.cjs", "tools/desktop/BUILD-README.md", "tools/example-recipes.R")
metadata <- list(title = "Individual Guide: A Friendly Guide", edition = "Beginner edition for release 0.4.0, 2026-10-19",
  package_version = as.character(getNamespaceVersion("IndividualGuide")), project_format = get_ig("PROJECT_VERSION"),
  R = R.version.string, task_count = length(registry), registry = registry, examples = examples,
  settings = get_ig("ig_default_settings")(), export_formats = get_ig("IG_EXPORT_FORMATS"),
  logging_fields = get_ig("ig_log_fields")(), logging_levels = get_ig("ig_log_levels")(),
  source_md5 = as.list(tools::md5sum(paths)))
dir.create("docs/book/data", recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(metadata, "docs/book/data/app-reference.json", auto_unbox = TRUE, pretty = TRUE,
  null = "null", na = "null", dataframe = "rows", digits = NA)
cat("Recorded", length(registry), "task types and", length(examples), "projects.\n")
