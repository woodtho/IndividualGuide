# Rendered reports must outlive the temporary R session that created them.
project_pack_reports <- function(root, flows) {
  for (fi in seq_along(flows)) for (ti in seq_along(flows[[fi]]$tasks)) {
    fid <- names(flows)[[fi]]
    id <- names(flows[[fi]]$tasks)[[ti]]
    task <- flows[[fid]]$tasks[[id]]
    for (i in seq_along(task$outputs)) {
      spec <- task$outputs[[i]]
      path <- spec$path %||% ""
      if (!identical(spec$kind, "report") || !nzchar(path) || !file.exists(path)) next
      relative <- file.path("reports", sprintf("%08d", fi), sprintf("%08d", ti), sprintf("%08d", i))
      destination <- file.path(root, relative)
      dir.create(destination, recursive = TRUE, showWarnings = FALSE)
      directory <- dirname(path)
      companions <- c(path, file.path(directory, c("report.Rmd", "data.rds")),
        list.files(directory, pattern = "^(report_files|figure_[0-9]+|widget_[0-9]+)", full.names = TRUE))
      companions <- unique(companions[file.exists(companions)])
      if (!all(file.copy(companions, destination, recursive = TRUE, overwrite = TRUE)))
        stop("Could not package report artifacts for task '", id, "'.")
      spec$artifact_path <- gsub("\\\\", "/", file.path(relative, basename(path)))
      spec$path <- NULL
      task$outputs[[i]] <- spec
    }
    flows[[fid]]$tasks[[id]] <- task
  }
  flows
}

project_restore_reports <- function(store, root) {
  flows <- isolate(store$flows)
  assets <- NULL
  complete <- FALSE
  on.exit(if (!complete && !is.null(assets)) unlink(assets, recursive = TRUE), add = TRUE)
  for (fid in names(flows)) for (id in names(flows[[fid]]$tasks)) {
    task <- flows[[fid]]$tasks[[id]]
    for (i in seq_along(task$outputs)) {
      spec <- task$outputs[[i]]
      relative <- spec$artifact_path %||% ""
      if (!identical(spec$kind, "report") || !nzchar(relative)) next
      relative <- gsub("\\\\", "/", relative)
      if (!startsWith(relative, "reports/") || grepl("(^|/)\\.\\.(/|$)|^[A-Za-z]:", relative))
        stop("Invalid report artifact path in project.")
      source <- file.path(root, relative)
      if (!file.exists(source) || dir.exists(source)) stop("Missing report artifact for task '", id, "'.")
      resolved <- normalizePath(source, winslash = "/", mustWork = TRUE)
      if (!startsWith(resolved, paste0(normalizePath(root, winslash = "/"), "/")))
        stop("Report artifact is outside the project archive.")
      if (is.null(assets)) {
        assets <- tempfile("ig_project_assets_")
        dir.create(assets)
      }
      destination <- file.path(assets, dirname(relative))
      dir.create(destination, recursive = TRUE, showWarnings = FALSE)
      files <- list.files(dirname(source), full.names = TRUE, all.files = TRUE, no.. = TRUE)
      if (!all(file.copy(files, destination, recursive = TRUE, overwrite = TRUE)))
        stop("Could not restore report artifacts.")
      spec$path <- file.path(destination, basename(source))
      task$outputs[[i]] <- spec
    }
    flows[[fid]]$tasks[[id]] <- task
  }
  store$flows <- flows
  store$project_assets <- assets
  complete <- TRUE
  invisible(NULL)
}

project_release_assets <- function(store) {
  path <- isolate(store$project_assets)
  if (!is.null(path) && dir.exists(path)) {
    resolved <- normalizePath(path, winslash = "/", mustWork = TRUE)
    temp_root <- paste0(normalizePath(tempdir(), winslash = "/", mustWork = TRUE), "/")
    if (startsWith(resolved, temp_root) && startsWith(basename(resolved), "ig_project_assets_"))
      unlink(resolved, recursive = TRUE)
  }
  store$project_assets <- NULL
  invisible(NULL)
}

# Preserve saved downstream snapshots for inspection, while requiring a new run
# before they can be consumed after an unavailable connection/report is loaded.
project_normalize_restored_tasks <- function(store) {
  flows <- isolate(store$flows)
  tables <- names(isolate(store$tables))
  tasks <- unlist(lapply(flows, function(flow) flow$tasks), recursive = FALSE)
  # unlist prefixes names with flow IDs; task IDs themselves are authoritative.
  names(tasks) <- vapply(tasks, `[[`, character(1), "id")
  if (anyDuplicated(names(tasks))) stop("Invalid project: task identifiers must be unique across flows.")
  pending <- character(0)
  for (id in names(tasks)) {
    task <- tasks[[id]]
    lazy_missing <- identical(task$type, "import_data") && identical(task$params$source_kind, "db") &&
      !isTRUE(task$params$db_collect) && !all(task_output_names(task) %in% tables)
    report_missing <- any(vapply(task$outputs %||% list(), function(spec)
      identical(spec$kind, "report") && !file.exists(spec$path %||% ""), logical(1)))
    if (lazy_missing || report_missing || (task$status %||% "") %in% c("running", "waiting")) {
      pending <- union(pending, id)
      tasks[[id]]$restoration_note <- if (lazy_missing) "Reconnect and rerun the database import." else
        if (report_missing) "Regenerate this report; its previous file is unavailable." else "Run interrupted; rerun this task."
    }
  }
  owners <- store_task_output_owner(tasks)
  while (length(pending)) {
    added <- names(Filter(function(task) length(intersect(store_task_dependency_ids(task, tasks, owners), pending)) > 0L, tasks))
    next_pending <- union(pending, added)
    if (setequal(next_pending, pending)) break
    pending <- next_pending
  }
  for (id in pending) {
    tasks[[id]]$status <- "pending"
    tasks[[id]]$invalidated <- TRUE
    tasks[[id]]$run_time <- NULL
    tasks[[id]]$error_msg <- NULL
    tasks[[id]]$restoration_note <- tasks[[id]]$restoration_note %||% "Rerun after restoring the upstream input."
  }
  for (fid in names(flows)) for (id in names(flows[[fid]]$tasks)) flows[[fid]]$tasks[[id]] <- tasks[[id]]
  store$flows <- flows
  invisible(NULL)
}
