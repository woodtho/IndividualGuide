# project.R -- Save and load .igpx project files.
#
# .igpx is a zip archive containing a directory of JSON files:
#   manifest.json
#   sources.json
#   formats.json
#   flows.json
#   tables/<index>.json
#   objects/<index>.json
#
# Tables, flows, and arbitrary R objects are stored as JSON documents using
# jsonlite's R-object JSON schema. This keeps the project format zip+JSON while
# preserving model objects, ggplot/girafe objects, factors, dates, and other
# R-specific classes. Rich objects that jsonlite cannot represent (including
# modern ggplot objects with closures) use a native RDS companion and a JSON
# descriptor. Existing JSON-only archives remain readable.
# Payloads at least 1 MiB also use the existing native encoding to avoid
# expanding large datasets and histories into scalar JSON records.

# Portable path markers require a loader that understands bundled inputs and
# relocated exports. Version 0.6 also retains typed global/project option scopes.
# Earlier archives remain readable; older apps reject newer option semantics.
PROJECT_VERSION <- "0.6.0"

# ── JSON archive helpers ──────────────────────────────────────────────────────

project_safe_name <- function(x) {
  utils::URLencode(x %||% "", reserved = TRUE)
}

project_unsafename <- function(x) {
  utils::URLdecode(x %||% "")
}

project_write_json <- function(path, x) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(path)
}

project_read_json <- function(path) {
  jsonlite::read_json(path, simplifyVector = FALSE)
}

project_requires_native <- function(value) {
  if (is.environment(value) || is.function(value) || isS4(value) || typeof(value) == "externalptr") return(TRUE)
  if (is.double(value) && anyNA(unclass(value))) return(TRUE)
  # Classed numeric vectors can encode values in their raw bits (integer64,
  # tagged missing values). Scalar JSON conversion cannot preserve those bits.
  if (is.atomic(value) && is.object(value) &&
      any(!class(value) %in% c("factor", "ordered", "Date", "POSIXct", "POSIXt", "difftime"))) return(TRUE)
  attrs <- attributes(value)
  if (length(attrs) && any(vapply(attrs, project_requires_native, logical(1)))) return(TRUE)
  if (is.list(value) || is.expression(value)) return(any(vapply(value, project_requires_native, logical(1))))
  FALSE
}

project_write_payload <- function(path, name, value, meta = list()) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  payload <- list(
    name = name,
    encoding = "jsonlite-r-object-json",
    meta = meta %||% list(),
    value = value
  )
  # Large payloads spend most of their save time expanding every scalar into
  # JSON and reparsing it on Open. The existing native descriptor is lossless
  # and backward compatible; retain JSON for small, inspectable payloads.
  native <- as.numeric(utils::object.size(value)) >= 1024^2 || project_requires_native(value)
  encoded <- if (native) NULL else
    tryCatch(jsonlite::serializeJSON(payload, pretty = TRUE, digits = NA), error = function(e) NULL)
  if (is.null(encoded)) {
    companion <- paste0(basename(path), ".rds")
    # The surrounding project archive already compresses this file. Avoid a
    # second compression pass and its additional buffers and CPU time.
    saveRDS(value, file.path(dirname(path), companion), compress = FALSE)
    project_write_json(path, list(name = name, encoding = "r-native-rds",
      meta = meta %||% list(), file = companion))
  } else writeLines(encoded, path, useBytes = TRUE)
  invisible(path)
}

project_read_payload <- function(path) {
  text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  descriptor <- jsonlite::fromJSON(text, simplifyVector = FALSE)
  if (identical(descriptor$encoding, "r-native-rds")) {
    file <- descriptor$file
    if (!is.character(file) || length(file) != 1L || !nzchar(file) ||
        grepl("[/\\\\:]|^\\.\\.$", file) || !identical(file, basename(file)))
      stop("Invalid native payload path in ", basename(path))
    companion <- file.path(dirname(path), file)
    if (!file.exists(companion)) stop("Missing native payload for ", basename(path))
    return(list(name = descriptor$name, meta = descriptor$meta %||% list(), value = ig_restore_object_namespaces(readRDS(companion))))
  }
  x <- jsonlite::unserializeJSON(text)
  if (!identical(x$encoding %||% "", "jsonlite-r-object-json"))
    stop("Unsupported payload encoding in ", basename(path))
  # Older jsonlite model payloads reconstructed formula environments with no
  # parent, preventing even base::list() in predict(). Retain their bindings and
  # restore the ordinary R search path; new models use lossless native storage.
  if (inherits(x$value, c("lm", "glm", "aov", "coxph"))) {
    for (field in c("terms", "formula")) {
      formula_env <- attr(x$value[[field]], ".Environment")
      if (is.environment(formula_env)) {
        if (identical(formula_env, emptyenv())) attr(x$value[[field]], ".Environment") <- globalenv()
        else if (identical(parent.env(formula_env), emptyenv())) parent.env(formula_env) <- globalenv()
      }
    }
  }
  list(
    name = x$name %||% project_unsafename(tools::file_path_sans_ext(basename(path))),
    meta = x$meta %||% list(),
    value = ig_restore_object_namespaces(x$value)
  )
}

project_zip_dir <- function(src_dir, zip_path, compression_level = 9L) {
  # Resolve before setwd(), including paths supplied relative to the project.
  destination_dir <- normalizePath(dirname(zip_path), mustWork = TRUE)
  zip_path <- file.path(destination_dir, basename(zip_path))
  replacement <- tempfile(".igpx_new_", tmpdir = destination_dir, fileext = ".zip")
  on.exit(unlink(replacement), add = TRUE)
  files <- list.files(src_dir, recursive = TRUE, all.files = TRUE,
    no.. = TRUE, full.names = FALSE, include.dirs = FALSE)
  old <- setwd(src_dir)
  on.exit(setwd(old), add = TRUE)
  zip::zipr(
    zipfile = replacement,
    files = files,
    compression_level = compression_level,
    include_directories = FALSE,
    mode = "mirror"
  )
  if (!file.exists(replacement) || file.info(replacement)$size == 0L)
    stop("Project archive could not be written.")
  # Windows cannot rename over an existing file. Retain the previous archive
  # until the replacement is complete, and restore it if the final move fails.
  ig_replace_file(replacement, zip_path)
  invisible(zip_path)
}

project_unzip <- function(path) {
  entries <- utils::unzip(path, list = TRUE)
  entry_names <- gsub("\\\\", "/", entries$Name)
  if (!nrow(entries)) stop("Invalid .igpx project: empty or unreadable archive.")
  limit <- getOption("ig.max_project_bytes", 8 * 1024^3)
  if (nrow(entries) > 50000L || any(!is.finite(entries$Length)) || sum(entries$Length) > limit)
    stop("Project archive exceeds the configured extraction limit.")
  if (any(grepl("^/|^[A-Za-z]:|(^|/)\\.\\.(/|$)", entry_names)))
    stop("Unsafe archive entry in .igpx project.")
  if (anyDuplicated(tolower(entry_names)))
    stop("Invalid .igpx project: duplicate archive entries.")
  out <- tempfile("igpx_")
  dir.create(out, recursive = TRUE)
  complete <- FALSE
  on.exit(if (!complete) unlink(out, recursive = TRUE, force = TRUE), add = TRUE)
  utils::unzip(path, exdir = out)
  expected <- file.path(out, entry_names[!grepl("/$", entry_names)])
  if (!all(file.exists(expected))) stop("Invalid .igpx project: extraction failed.")
  complete <- TRUE
  out
}

# ── Save ──────────────────────────────────────────────────────────────────────

#' Serialise the project to an .igpx file.
#'
#' @param store        reactiveValues store (make_store())
#' @param path         Destination .igpx file path
#' @param canvas_state list($nodes, $edges) from visNetwork for the CURRENT flow
#' @param theme        Current UI theme: "dark" (default) or "light"
#' @param update_identity When TRUE (default) record this path as the project's
#'   path/name and clear the dirty flag. Background recovery autosaves pass FALSE
#'   so they don't masquerade as a real "Save".
#' @param portable Bundle file imports and existing exports for relocation.
#' @param compression_level ZIP compression level; recovery uses faster level 1.
project_save <- function(store, path, canvas_state = list(), theme = "dark",
                         update_identity = TRUE, portable = FALSE, compression_level = 9L) {
  store_sync_parameters(store)
  ig_options_sync(store)
  current_theme <- isolate(store$settings)$theme_mode %||% "dark"
  if (!missing(theme) && !is.null(theme) && !identical(theme, current_theme)) {
    overrides <- isolate(store$option_overrides)
    overrides$app$theme_mode <- theme
    store$option_overrides <- overrides
    ig_options_refresh(store)
  }
  theme <- isolate(store$settings)$theme_mode %||% current_theme
  store_snapshot_flow(store, canvas_state)

  root <- tempfile("igpx_build_")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  project_write_json(file.path(root, "manifest.json"), list(
    format = "Individual Guide Project",
    extension = "igpx",
    version = PROJECT_VERSION,
    saved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS%z"),
    project_name = if (isTRUE(update_identity)) tools::file_path_sans_ext(basename(path)) else
      isolate(store$project_name) %||% tools::file_path_sans_ext(basename(path)),
    active_flow = isolate(store$active_flow),
    # User preferences — restored on project load
    theme           = theme %||% "dark",
    task_favourites = as.list(isolate(store$task_favourites) %||% character(0)),
    settings        = isolate(store$settings) %||% ig_default_settings(),
    options_schema  = 1L
  ))

  project_write_payload(file.path(root, "sources.json"), "sources", isolate(store$sources))
  project_write_payload(file.path(root, "options.json"), "options", isolate(store$option_overrides) %||% ig_options_empty())
  project_write_payload(file.path(root, "formats.json"), "formats", isolate(store$formats))
  packed_flows <- project_pack_reports(root, isolate(store$flows))
  original <- isolate(store$project_path)
  packed_flows <- project_pack_inputs(root, packed_flows, path, portable, isolate(store$project_assets),
    source_dir = if (!is.null(original) && nzchar(original)) dirname(original) else getwd())
  project_write_payload(file.path(root, "flows.json"), "flows", packed_flows)
  project_write_payload(file.path(root, "collaboration.json"), "collaboration",
    ig_normalize_collaboration(isolate(store$collaboration)))
  project_write_payload(file.path(root, "runs.json"), "runs", isolate(store$run_records) %||% list())

  tables <- isolate(store$tables)
  for (i in seq_along(tables)) {
    nm <- names(tables)[[i]]
    if (inherits(tables[[nm]], "tbl_sql")) next  # lazy DB tbls are not persisted;
    # they are re-established by re-running the import task after project load.
    project_write_payload(
      file.path(root, "tables", sprintf("%08d.json", i)),
      nm,
      tables[[nm]],
      meta = list(kind = "table")
    )
  }

  objects <- isolate(store$objects)
  for (i in seq_along(objects)) {
    nm <- names(objects)[[i]]
    rec <- objects[[nm]]
    project_write_payload(
      file.path(root, "objects", sprintf("%08d.json", i)),
      nm,
      rec$value,
      meta = rec$meta %||% list()
    )
  }

  # Backups are captured only for explicit saves, after payload preparation.
  # Recovery and portable downloads keep their identity.
  if (isTRUE(update_identity) && file.exists(path)) {
    project_backup_capture(path, isolate(store$settings)$backup_versions %||% 20L)
  }
  project_zip_dir(root, path, compression_level = compression_level)
  if (isTRUE(update_identity)) {
    project_backup_prune(path, isolate(store$settings)$backup_versions %||% 20L)
    store$project_path <- path
    store$project_name <- tools::file_path_sans_ext(basename(path))
    store$dirty <- FALSE
  }
  invisible(path)
}

# ── Recovery autosave ─────────────────────────────────────────────────────────

#' Path to the crash-recovery autosave file (per-user cache dir).
project_recovery_path <- function() {
  dir <- getOption("ig.recovery_dir") %||%
    tryCatch(tools::R_user_dir("IndividualGuide", "cache"),
      error = function(e) file.path(tempdir(), "IndividualGuide"))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  file.path(dir, "recovery.igpx")
}

#' Write a recovery snapshot without touching the project's identity/dirty flag.
#' Best-effort: never errors out into the reactive cycle.
#' @param store Session reactive store created by make_store().
#' @param canvas_state Optional saved canvas nodes and edges.
#' @param theme Saved application appearance mode.
project_autosave_recovery <- function(store, canvas_state = list(), theme = NULL) {
  path <- project_recovery_path()
  saved <- tryCatch(
    project_save(store, path, canvas_state = canvas_state, theme = theme,
                 update_identity = FALSE, compression_level = 1L),
    error = function(e) NULL
  )
  invisible(if (!is.null(saved)) path else NULL)
}

# Active task/window snapshots are derived during Save; changing them alone
# must not schedule another recovery save. Inactive tasks and actual layout
# preferences remain project state and still advance the revision.
project_recovery_flow_state <- function(store) {
  flows <- store$flows
  active <- store$active_flow
  if (!is.null(active) && !is.null(flows[[active]]))
    flows[[active]][c("tasks", "task_order", "canvas_nodes", "canvas_edges")] <- NULL
  flows
}

#' Remove the recovery file (after a successful real save or declined restore).
project_clear_recovery <- function() {
  path <- project_recovery_path()
  if (file.exists(path)) tryCatch(unlink(path), error = function(e) NULL)
  invisible(NULL)
}

# ── Load ──────────────────────────────────────────────────────────────────────

#' Load an .igpx file and rebuild the reactive store.
#'
#' Also supports legacy .igp/.rds project files for migration.
#' @param store Session reactive store created by make_store().
#' @param path Filesystem path of the project or artifact.
#' @param source_path Original project path used to resolve relative files when restoring a backup.
project_load <- function(store, path, source_path = path) {
  # Decode and validate against a temporary store. No live state is replaced
  # until every payload and graph has passed validation (including legacy).
  staged <- make_store()
  committed <- FALSE
  on.exit(if (!committed) project_release_assets(staged), add = TRUE)
  result <- project_load_staged(staged, path, source_path)
  flows <- isolate(staged$flows)
  for (flow in flows) {
    tasks <- flow$tasks %||% list()
    if (!is.list(tasks) || (length(tasks) &&
        (is.null(names(tasks)) || anyDuplicated(names(tasks)))))
      stop("Invalid project: flow tasks must have unique identifiers.")
    order <- flow$task_order %||% character(0)
    if (anyDuplicated(order) || !setequal(order, names(tasks)))
      stop("Invalid project: task order does not match the flow tasks.")
    for (id in names(tasks)) {
      if (!is.list(tasks[[id]]) || !identical(tasks[[id]]$id, id))
        stop("Invalid project: task identifier mismatch: ", id)
    }
    problem <- store_dependency_problem(tasks, order)
    if (!is.null(problem)) stop("Invalid project: ", problem)
  }
  all_tasks <- store_all_tasks(staged)
  problem <- store_dependency_problem(all_tasks, names(all_tasks))
  if (!is.null(problem)) stop("Invalid project: ", problem)
  values <- isolate(shiny::reactiveValuesToList(staged))
  values$run_generation <- isolate(store$run_generation) + 1L
  console <- isolate(store$console)
  if (!is.null(console)) ig_console_reset(console)
  ig_background_cancel(store, notify = FALSE, change_status = FALSE)
  ig_background_retire_worker(store)
  # These handles belong to the live Shiny session, not to the archive. Keep
  # their observers and ownership while clearing the previous R workspaces.
  values$console <- console
  values$background <- isolate(store$background)
  values$background_revision <- isolate(store$background_revision) + 1L
  store_close_connections(store)
  project_release_assets(store)
  for (name in names(values)) store[[name]] <- values[[name]]
  committed <- TRUE
  result$loaded <- TRUE
  result
}

# Internal loader: only writes to the staging store owned by project_load().
project_load_staged <- function(store, path, source_path = path) {
  ext <- tolower(tools::file_ext(path))
  if (identical(ext, "igp") || identical(ext, "rds")) {
    return(project_load_legacy_rds(store, path))
  }

  root <- project_unzip(path)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  manifest_path <- file.path(root, "manifest.json")
  if (!file.exists(manifest_path))
    stop("Invalid .igpx project: manifest.json is missing.")
  manifest <- project_read_json(manifest_path)
  if (!identical(manifest$format, "Individual Guide Project"))
    stop("Invalid .igpx project: unrecognized manifest format.")
  version <- tryCatch(numeric_version(manifest$version %||% ""),
    error = function(e) NULL)
  if (is.null(version) || length(version) != 1L || version > numeric_version(PROJECT_VERSION))
    stop("Unsupported project version: ", manifest$version %||% "missing")

  sources <- if (file.exists(file.path(root, "sources.json")))
    project_read_payload(file.path(root, "sources.json"))$value else list()
  formats <- if (file.exists(file.path(root, "formats.json")))
    project_read_payload(file.path(root, "formats.json"))$value else list()
  flows <- if (file.exists(file.path(root, "flows.json")))
    project_read_payload(file.path(root, "flows.json"))$value else list()
  collaboration <- if (file.exists(file.path(root, "collaboration.json")))
    project_read_payload(file.path(root, "collaboration.json"))$value else list()

  store$sources <- sources %||% list()
  store$formats <- formats %||% list()
  store$collaboration <- ig_normalize_collaboration(collaboration)
  store$review_mode <- FALSE
  store$objects <- list()
  store$tables  <- list()
  store$project_path <- path
  store$project_name <- manifest$project_name %||% tools::file_path_sans_ext(basename(path))
  store$dirty <- FALSE

  # ── Restore user preferences ─────────────────────────────────────────────────
  saved_favs <- tryCatch(
    as.character(unlist(manifest$task_favourites %||% list())),
    error = function(e) character(0)
  )
  if ("task_favourites" %in% names(manifest)) store$task_favourites <- saved_favs

  # Settings: merge over the defaults so projects saved by older versions
  # pick up keys that did not exist when they were written.
  saved_settings <- manifest$settings %||% list()
  defaults <- ig_options_app_values()
  defaults <- ig_options_merge(defaults, saved_settings)
  defaults$page_length <- suppressWarnings(as.integer(defaults$page_length %||% 10L))
  if (length(defaults$page_length) != 1L || is.na(defaults$page_length) ||
      defaults$page_length < 5L) defaults$page_length <- 10L
  if (identical(as.integer(manifest$options_schema %||% 0L), 1L)) {
    option_file <- file.path(root, "options.json")
    if (!file.exists(option_file)) stop("Invalid project: options.json is missing.")
    store$option_overrides <- ig_options_validate_spec(project_read_payload(option_file)$value)
    ig_options_refresh(store)
  } else {
    # Old files explicitly saved the whole settings list. Preserve that behavior
    # as project overrides while new projects inherit current global defaults.
    known <- names(ig_default_settings())
    overrides <- ig_options_empty()
    overrides$app <- defaults[intersect(names(saved_settings), known)]
    if (!is.null(manifest$theme)) overrides$app$theme_mode <- manifest$theme
    store$option_overrides <- overrides
    ig_options_refresh(store)
  }

  table_files <- list.files(file.path(root, "tables"), pattern = "\\.json$",
    full.names = TRUE)
  tbls <- list()
  for (f in table_files) {
    item <- project_read_payload(f)
    if (!is.character(item$name) || length(item$name) != 1L || is.na(item$name) || !nzchar(item$name) ||
        item$name %in% names(tbls)) stop("Invalid project: duplicate or invalid dataset name.")
    tbls[[item$name]] <- item$value
  }
  store$tables <- tbls

  object_files <- list.files(file.path(root, "objects"), pattern = "\\.json$",
    full.names = TRUE)
  objs <- list()
  for (f in object_files) {
    item <- project_read_payload(f)
    if (!is.character(item$name) || length(item$name) != 1L || is.na(item$name) || !nzchar(item$name) ||
        item$name %in% c(names(objs), names(tbls))) stop("Invalid project: duplicate or invalid output name.")
    objs[[item$name]] <- list(value = item$value, meta = item$meta %||% list())
  }
  store$objects <- objs

  if (length(flows) == 0L) {
    fl <- make_flow("Flow 1")
    flows <- setNames(list(fl), fl$id)
  }
  store$flows <- flows
  project_restore_reports(store, root)
  project_restore_inputs(store, root, source_path)
  store$run_records <- if (file.exists(file.path(root, "runs.json")))
    utils::tail(project_read_payload(file.path(root, "runs.json"))$value %||% list(), 200L) else list()
  project_normalize_restored_tasks(store)
  flows <- isolate(store$flows)
  act_fid <- manifest$active_flow %||% names(flows)[1]
  if (!act_fid %in% names(flows)) act_fid <- names(flows)[1]
  store$active_flow <- act_fid
  store$tasks <- flows[[act_fid]]$tasks %||% list()
  store$task_order <- flows[[act_fid]]$task_order %||% character(0)
  store$active_node <- NULL

  active_flow_obj <- isolate(store$flows)[[isolate(store$active_flow)]]
  list(
    ok     = TRUE,
    errors = character(0),
    canvas = list(
      nodes = active_flow_obj$canvas_nodes,
      edges = active_flow_obj$canvas_edges
    ),
    # Saved UI preferences — caller applies these after load
    theme  = isolate(store$settings)$theme_mode %||% manifest$theme %||% "dark"
  )
}

# ── Legacy .igp/.rds loader ───────────────────────────────────────────────────

project_load_legacy_rds <- function(store, path) {
  errors <- character(0)

  proj <- tryCatch(
    ig_restore_object_namespaces(readRDS(path)),
    error = function(e)
      stop("Cannot read legacy project file: ", conditionMessage(e))
  )

  store$sources      <- proj$sources %||% list()
  store$objects      <- proj$objects %||% list()
  store$formats      <- proj$formats %||% list()
  store$collaboration <- ig_default_collaboration()
  store$review_mode   <- FALSE
  store$project_path <- NULL
  store$project_name <- tools::file_path_sans_ext(basename(path))
  store$dirty        <- TRUE

  if (!is.null(proj$tasks) && is.null(proj$flows)) {
    fl               <- make_flow("Flow 1")
    fl$tasks         <- proj$tasks       %||% list()
    fl$task_order    <- proj$task_order  %||% character(0)
    fl$canvas_nodes  <- proj$canvas_nodes
    fl$canvas_edges  <- proj$canvas_edges
    store$flows       <- setNames(list(fl), fl$id)
    store$active_flow <- fl$id
    store$tasks        <- fl$tasks
    store$task_order   <- fl$task_order
  } else {
    flows <- proj$flows %||% list()
    if (length(flows) == 0L) {
      fl    <- make_flow("Flow 1")
      flows <- setNames(list(fl), fl$id)
    }
    store$flows <- flows
    act_fid <- proj$active_flow %||% names(flows)[1]
    if (!act_fid %in% names(flows)) act_fid <- names(flows)[1]
    store$active_flow  <- act_fid
    store$tasks        <- flows[[act_fid]]$tasks      %||% list()
    store$task_order   <- flows[[act_fid]]$task_order %||% character(0)
    store$active_node  <- NULL
  }

  store$tables <- list()
  for (nm in names(store$sources)) {
    meta <- store$sources[[nm]]
    df   <- tryCatch(
      load_source(meta),
      error = function(e) {
        errors <<- c(errors, paste0("'", nm, "': ", conditionMessage(e)))
        NULL
      }
    )
    if (!is.null(df)) store$tables[[nm]] <- df
  }

  active_flow_obj <- isolate(store$flows)[[isolate(store$active_flow)]]
  list(
    ok     = length(errors) == 0L,
    errors = errors,
    canvas = list(
      nodes = active_flow_obj$canvas_nodes,
      edges = active_flow_obj$canvas_edges
    )
  )
}

# ── Source loader ─────────────────────────────────────────────────────────────

load_source <- function(meta) {
  if (!is.null(meta$source_kind) && exists("execute_import", mode = "function")) {
    result <- execute_import(meta)
    if (is.null(result$error)) return(result$data)
    stop(result$error)
  }

  orig <- meta$path %||% ""
  if (nchar(orig) > 0 && file.exists(orig))
    return(read_by_ext(orig, meta))

  snap <- meta$saved_path %||% ""
  if (nchar(snap) > 0 && file.exists(snap))
    return(ig_restore_object_namespaces(readRDS(snap)))

  stop(
    "Cannot reload '", meta$original_name %||% basename(orig), "'.\n",
    "  Original path : ", orig, "\n",
    "Re-import the file or move it back to the original location."
  )
}

read_by_ext <- function(path, meta) {
  ext <- tolower(tools::file_ext(path))
  switch(ext,
    csv      = readr::read_delim(path,
                 delim     = meta$csv_delim %||% ",",
                 col_names = meta$csv_header %||% TRUE,
                 show_col_types = FALSE),
    xlsx     = ,
    xls      = readxl::read_excel(path, sheet = meta$sheet %||% 1L),
    rds      = ig_restore_object_namespaces(readRDS(path)),
    rda      = { e <- new.env(); load(path, envir = e);
                 ig_restore_object_namespaces(get(ls(e)[1], envir = e)) },
    sas7bdat = haven::read_sas(path),
    dta      = haven::read_dta(path),
    sav      = haven::read_spss(path),
    stop("Unknown file type: .", ext)
  )
}
