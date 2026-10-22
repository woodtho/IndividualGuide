# Project safety, portable assets and reproducible run records.
ig_user_directory <- function(name) {
  root <- Sys.getenv("IG_USER_DATA", unset = "")
  if (!nzchar(root)) root <- tools::R_user_dir("IndividualGuide", "data")
  path <- file.path(root, name)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}

ig_project_key <- function(path) {
  path <- file.path(normalizePath(dirname(path), winslash = "/", mustWork = FALSE), basename(path))
  if (.Platform$OS.type == "windows") path <- tolower(path)
  digest::digest(path, algo = "sha256", serialize = FALSE)
}

project_backup_directory <- function(path) {
  file.path(getOption("ig.backup_dir") %||% ig_user_directory("project-backups"), ig_project_key(path))
}

project_backup_list <- function(path) {
  if (is.null(path) || !nzchar(path)) return(data.frame(id = character(), time = character(), bytes = numeric()))
  files <- list.files(project_backup_directory(path), pattern = "^[0-9]{8}T[0-9a-fA-F._-]+[.]igpx$", full.names = TRUE)
  if (!length(files)) return(data.frame(id = character(), time = character(), bytes = numeric()))
  info <- file.info(files)
  result <- data.frame(id = basename(files), time = format(info$mtime, "%Y-%m-%d %H:%M:%OS3 %Z"), bytes = info$size)
  result[order(info$mtime, basename(files), decreasing = TRUE), , drop = FALSE]
}

project_backup_capture <- function(path, limit = 20L) {
  limit <- suppressWarnings(as.integer(limit))
  if (length(limit) != 1L || is.na(limit) || limit < 0L || limit > 100L) stop("Backup retention must be between 0 and 100.")
  if (!limit || !file.exists(path)) return(invisible(NULL))
  directory <- project_backup_directory(path)
  if (!dir.create(directory, recursive = TRUE, showWarnings = FALSE) && !dir.exists(directory))
    stop("Could not create the project backup folder.")
  id <- paste0(format(Sys.time(), "%Y%m%dT%H%M%OS6", tz = "UTC"), "_", basename(tempfile(pattern = "")), ".igpx")
  target <- file.path(directory, id)
  if (!file.copy(path, target) || !identical(unname(tools::md5sum(path)), unname(tools::md5sum(target)))) {
    unlink(target)
    stop("Could not verify the previous project backup; the current project was not replaced.")
  }
  invisible(target)
}

project_backup_prune <- function(path, limit = 20L) {
  versions <- project_backup_list(path)
  retired <- utils::tail(versions$id, max(0L, nrow(versions) - limit))
  directory <- normalizePath(project_backup_directory(path), winslash = "/", mustWork = FALSE)
  # Only fixed-format archive basenames inside this project's own backup folder.
  if (length(retired)) unlink(file.path(directory, retired))
  invisible(NULL)
}

ig_absolute_path <- function(path) grepl("^[/\\\\]|^[A-Za-z]:[/\\\\]", path)

project_pack_inputs <- function(root, flows, destination, portable = FALSE, assets = NULL, source_dir = getwd()) {
  base <- normalizePath(dirname(destination), winslash = "/", mustWork = TRUE)
  for (fi in seq_along(flows)) for (ti in seq_along(flows[[fi]]$tasks)) {
    task <- flows[[fi]]$tasks[[ti]]
    p <- task$params
    if (identical(task$type, "import_data") && identical(p$source_kind %||% "file", "file") && nzchar(p$path %||% "")) {
      path <- p$path
      if (!ig_absolute_path(path)) path <- file.path(source_dir, path)
      resolved <- normalizePath(path, winslash = "/", mustWork = FALSE)
      owned <- !is.null(assets) && startsWith(resolved, paste0(normalizePath(assets, winslash = "/", mustWork = FALSE), "/"))
      if (portable || owned) {
        if (!file.exists(path) || dir.exists(path)) stop("Cannot bundle missing import file for task '", task$id, "': ", path)
        relative <- file.path("inputs", sprintf("%08d_%08d", fi, ti), basename(path))
        dir.create(file.path(root, dirname(relative)), recursive = TRUE, showWarnings = FALSE)
        if (!file.copy(path, file.path(root, relative))) stop("Could not bundle input file: ", path)
        task$source_reference <- list(original = task$source_reference$original %||% p$path, bundled = TRUE)
        p$path <- paste0("@project/", gsub("\\\\", "/", relative))
      } else if (startsWith(resolved, paste0(base, "/"))) p$path <- substring(resolved, nchar(base) + 2L)
    }
    if ((portable || nzchar(task$portable_export %||% "")) && task$type %in% c("export", "export_log")) {
      path <- task$export_file %||% if (task$type == "export_log") p$path else
        ig_export_path(p$dir %||% ".", p$filename, p$format)
      relative <- file.path("exports", sprintf("%08d_%08d", fi, ti), basename(path))
      if (file.exists(path) && !dir.exists(path)) {
        dir.create(file.path(root, dirname(relative)), recursive = TRUE, showWarnings = FALSE)
        if (!file.copy(path, file.path(root, relative))) stop("Could not bundle exported file: ", path)
      }
      task$portable_export <- gsub("\\\\", "/", relative)
      task$export_file <- paste0("@project/", task$portable_export)
      if (task$type == "export_log") p$path <- task$export_file else p$dir <- "@project/outputs"
    }
    changed <- !identical(p, task$params)
    task$params <- p
    if (changed) task$r_code <- build_task_code(task)
    flows[[fi]]$tasks[[ti]] <- task
  }
  flows
}

project_restore_inputs <- function(store, root, project_path) {
  flows <- isolate(store$flows)
  assets <- isolate(store$project_assets)
  if (!is.null(assets)) assets <- normalizePath(assets, winslash = "/", mustWork = TRUE)
  for (fid in names(flows)) for (tid in names(flows[[fid]]$tasks)) {
    task <- flows[[fid]]$tasks[[tid]]; p <- task$params
    if (task$type == "import_data" && identical(p$source_kind %||% "file", "file") && nzchar(p$path %||% "")) {
      if (startsWith(p$path, "@project/")) {
        relative <- substring(p$path, 10L)
        if (!startsWith(relative, "inputs/") || grepl("(^|/)\\.\\.(/|$)|^[A-Za-z]:|\\\\", relative)) stop("Invalid bundled input path.")
        source <- file.path(root, relative)
        if (!file.exists(source) || dir.exists(source)) stop("Missing bundled input for task '", tid, "'.")
        if (!startsWith(normalizePath(source, winslash = "/", mustWork = TRUE), paste0(normalizePath(root, winslash = "/", mustWork = TRUE), "/"))) stop("Bundled input is outside the project archive.")
        if (is.null(assets)) { assets <- tempfile("ig_project_assets_"); dir.create(assets); assets <- normalizePath(assets, winslash = "/"); store$project_assets <- assets }
        target <- file.path(assets, relative)
        dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
        if (!file.copy(source, target, overwrite = TRUE)) stop("Could not restore a bundled input.")
        p$path <- normalizePath(target, winslash = "/", mustWork = TRUE)
      } else if (!ig_absolute_path(p$path)) p$path <- file.path(dirname(project_path), p$path)
    }
    if (task$type %in% c("export", "export_log") && nzchar(task$portable_export %||% "")) {
      relative <- task$portable_export
      if (!startsWith(relative, "exports/") || grepl("(^|/)\\.\\.(/|$)|^[A-Za-z]:|\\\\", relative)) stop("Invalid bundled export path.")
      directory <- file.path(ig_user_directory("project-outputs"), ig_project_key(project_path), dirname(relative))
      dir.create(directory, recursive = TRUE, showWarnings = FALSE)
      destination <- file.path(directory, basename(relative))
      source <- file.path(root, relative)
      if (file.exists(source) && !startsWith(normalizePath(source, winslash = "/", mustWork = TRUE), paste0(normalizePath(root, winslash = "/", mustWork = TRUE), "/"))) stop("Bundled export is outside the project archive.")
      # Opening an older snapshot must not overwrite the user's newer exports.
      if (file.exists(source) && !file.exists(destination) && !file.copy(source, destination)) stop("Could not restore exported file.")
      task$export_file <- destination
      if (task$type == "export_log") p$path <- destination else p$dir <- directory
    }
    changed <- !identical(p, task$params)
    task$params <- p
    if (changed) task$r_code <- build_task_code(task)
    flows[[fid]]$tasks[[tid]] <- task
  }
  store$flows <- flows; store$project_assets <- assets
  invisible(NULL)
}

ig_project_files <- function(store) {
  tasks <- store_all_tasks(store)
  rows <- lapply(tasks, function(task) {
    p <- task$params
    if (!identical(task$type, "import_data") || !identical(p$source_kind %||% "file", "file")) return(NULL)
    path <- p$path %||% ""
    data.frame(task = task$id, file = path, exists = nzchar(path) && file.exists(path),
      bundled = isTRUE(task$source_reference$bundled), stringsAsFactors = FALSE)
  })
  if (!length(Filter(Negate(is.null), rows))) return(data.frame(task = character(), file = character(), exists = logical(), bundled = logical()))
  do.call(rbind, rows)
}

ig_environment_info <- function() {
  csv <- file.path(Sys.getenv("IG_RUNTIME_DIR"), "packages.csv")
  packages <- if (nzchar(Sys.getenv("IG_RUNTIME_DIR")) && file.exists(csv)) {
    df <- read.csv(csv, stringsAsFactors = FALSE)
    stats::setNames(as.list(df$Version), df$Package)
  } else list()
  # Read the generation this process actually started with. The package manager
  # may already have selected a different generation for the next R restart.
  library <- Sys.getenv("IG_PACKAGE_LIBRARY", "")
  profile <- if (nzchar(library)) file.path(dirname(library), "profile.rds") else ""
  selected <- if (nzchar(profile) && file.exists(profile)) readRDS(profile) else NULL
  if (!is.null(selected)) for (name in names(selected$packages)) packages[[name]] <- selected$packages[[name]]
  for (name in loadedNamespaces()) packages[[name]] <- as.character(getNamespaceVersion(name))
  list(app = as.character(getNamespaceVersion("IndividualGuide")), R = getRversion() |> as.character(),
    platform = R.version$platform, package_profile = Sys.getenv("IG_PACKAGE_PROFILE", ""),
    package_pins = if (is.null(selected)) list() else as.list(selected$pins), packages = packages[order(names(packages))])
}

ig_environment_changes <- function(previous) {
  if (is.null(previous)) return(character())
  changes <- character()
  if (!identical(previous$R, as.character(getRversion()))) changes <- c(changes, paste("R", previous$R, "→", as.character(getRversion())))
  for (name in names(previous$packages)) {
    current <- tryCatch(as.character(utils::packageVersion(name)), error = function(e) "not installed")
    before <- previous$packages[[name]]
    same <- identical(current, before) || tryCatch(
      isTRUE(package_version(current) == package_version(before)), error = function(e) FALSE)
    if (!same) changes <- c(changes, paste(name, before, "→", current))
  }
  changes
}

ig_fingerprint <- function(value) {
  if (inherits(value, "tbl_sql")) return(list(hash = digest::digest(dbplyr::sql_render(value), algo = "sha256"), complete = FALSE, reason = "Live database contents are not snapshotted"))
  if (typeof(value) %in% c("environment", "externalptr", "weakref") || inherits(value, c("DBIConnection", "connection")))
    return(list(hash = NULL, complete = FALSE, reason = "Process-local object"))
  list(hash = digest::digest(value, algo = "sha256"), complete = TRUE)
}

ig_run_inputs <- function(task, tables, objects = list()) {
  inputs <- unique(c(task$inputs, task$params$input_tables, task$params[["input_table"]], task$params[["pred_table"]]))
  if (task$type == "script" && !length(inputs)) inputs <- names(c(tables, objects))
  values <- c(tables, objects); values <- values[intersect(inputs, names(values))]
  fingerprints <- lapply(values, ig_fingerprint)
  file <- if (task$type == "import_data" && identical(task$params$source_kind %||% "file", "file")) task$params$path else NULL
  if (length(file) && file.exists(file)) fingerprints[[".source_file"]] <- list(hash = digest::digest(file = file, algo = "sha256"), complete = TRUE)
  fingerprints
}

ig_run_begin <- function(store, task_id, task = NULL, tables = NULL, objects = NULL, fingerprint = TRUE) {
  task <- task %||% isolate(store$tasks[[task_id]])
  if (is.null(task)) return(NULL)
  tables <- tables %||% isolate(store$tables)
  objects <- objects %||% lapply(isolate(store$objects), `[[`, "value")
  fingerprints <- if (fingerprint) ig_run_inputs(task, tables, objects) else list()
  seed <- isolate(store$settings)$run_seed
  list(id = basename(tempfile(paste0(task_id, "-"))), task = task_id, flow = isolate(store$active_flow),
    started = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z"), start_time = as.numeric(Sys.time()),
    config = digest::digest(task[c("type", "params", "inputs", "output", "control_inputs")], algo = "sha256"),
    inputs = fingerprints, environment = ig_environment_info(), seed = seed, rng_kind = RNGkind(),
    rng_state = if (exists(".Random.seed", globalenv(), inherits = FALSE)) get(".Random.seed", globalenv()) else NULL)
}

ig_run_finish <- function(store, record, status = NULL) {
  if (is.null(record)) return(invisible(NULL))
  task <- store_all_tasks(store)[[record$task]] %||% list(status = "removed", output = "", outputs = list())
  record$elapsed <- max(0, as.numeric(Sys.time()) - record$start_time)
  record$start_time <- NULL
  record$status <- status %||% task$status %||% "error"
  record$error <- task$error_msg
  names <- task_output_names(task)
  values <- c(isolate(store$tables), lapply(isolate(store$objects), `[[`, "value"))
  record$outputs <- if (record$status == "success") lapply(values[intersect(names, names(values))], ig_fingerprint) else list()
  paths <- unique(as.character(c(task$export_file, unlist(lapply(task$outputs %||% list(), function(output) output$path), use.names = FALSE))))
  paths <- paths[file.exists(paths) & !dir.exists(paths)]
  record$files <- if (record$status == "success") lapply(paths, function(path) list(path = path,
    bytes = unname(file.info(path)$size), sha256 = digest::digest(file = path, algo = "sha256"))) else list()
  records <- isolate(store$run_records) %||% list()
  store$run_records <- utils::tail(c(records, list(record)), 200L)
  store$dirty <- TRUE
  invisible(record)
}

ig_with_project_seed <- function(store, fn) {
  seed <- isolate(store$settings)$run_seed
  if (is.null(seed)) return(fn())
  seed <- suppressWarnings(as.integer(seed))
  if (length(seed) != 1L || is.na(seed) || seed < 0L) stop("Project random seed must be a non-negative integer.")
  present <- exists(".Random.seed", globalenv(), inherits = FALSE)
  old <- if (present) get(".Random.seed", globalenv()) else NULL
  on.exit(if (present) assign(".Random.seed", old, globalenv()) else if (exists(".Random.seed", globalenv(), inherits = FALSE)) rm(".Random.seed", envir = globalenv()), add = TRUE)
  set.seed(seed); fn()
}
