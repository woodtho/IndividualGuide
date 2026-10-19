# store.R — Shared reactive data environment
# All task modules read from and write to this single reactive object.
#
# Multi-flow model
# ─────────────────
# store$flows       — named list of all flow definitions (id, name, tasks,
#                     task_order, canvas_nodes, canvas_edges)
# store$active_flow — id of the currently visible flow
# store$tasks       — LIVE view: always == flows[[active_flow]]$tasks
# store$task_order  — LIVE view: always == flows[[active_flow]]$task_order
#
# When switching flows call store_activate_flow() which snapshots the current
# live view back into flows[[old_id]], then loads the new flow's data.

# ── Application settings ──────────────────────────────────────────────────────

#' Default user settings (Settings modal). Saved in the project manifest and
#' merged over these defaults on load so old projects pick up new keys.
ig_default_settings <- function() {
  list(
    page_length    = 10L,      # preview table rows per page
    plot_theme     = "clean",  # default theme for new graph tasks
    palette        = "ig",     # default palette for new graph tasks
    stop_on_error  = FALSE,    # Run Flow: stop at the first failing task
    confirm_delete = TRUE,     # ask before deleting tasks / flows
    backup_versions = 20L,
    run_seed = NULL,
    background_tasks = TRUE
  )
}

#' Current preview page length. Reads store$settings reactively, so DT
#' renderers that call this re-render when the setting changes.
#' @param store Session reactive store created by make_store().
ig_page_len <- function(store) {
  s <- store$settings %||% list()
  n <- suppressWarnings(as.integer(s$page_length %||% 10L))
  if (is.na(n) || n < 5L) 10L else n
}

# ── Store constructor ─────────────────────────────────────────────────────────

#' Create the shared application store.
make_store <- function() {
  reactiveValues(
    # Project-level (shared across all flows)
    tables        = list(),          # data frames, keyed by source name
    objects       = list(),          # non-tabular outputs, keyed by output name
    sources       = list(),          # source metadata, keyed by source name
    formats       = list(),
    project_path  = NULL,
    project_name  = "Untitled Project",   # display name; survives Save-As temp paths
    project_assets = NULL,          # owned restored report directory; session only
    run_records   = list(),
    dirty         = FALSE,
    collaboration = ig_default_collaboration(),
    review_mode   = FALSE,

    # Active-flow live window (always reflect the current flow)
    tasks        = list(),          # task defs keyed by task_id
    task_order   = character(0),    # ordered task ids
    active_node  = NULL,            # selected canvas node

    # Flow registry
    flows        = list(),          # named list of flow definition lists
    active_flow  = NULL,            # id of the active flow

    # Run-flow queue (project-level)
    run_queue       = character(0), # task_ids waiting to execute
    run_ids         = character(0), # full id list of the current run (for summary)
    run_waiting     = NULL,         # task awaiting a database-password modal
    run_resumed     = NULL,         # completed modal task awaiting queue bookkeeping
    run_task_done_n = 0L,           # increment to advance the queue
    run_generation  = 0L,          # invalidate delayed queue callbacks
    run_current     = NULL,
    run_started     = NULL,
    run_total       = 0L,
    run_completed   = 0L,
    run_outcome     = "idle",
    background_revision = 0L,
    task_runners    = list(),       # task_id → function(); registered by each module
    code_fns        = list(),       # task_id → function() returning live R code
    params_fns      = list(),       # live configuration readers; session only
    result_fns      = list(),       # live preview refreshers; session only
    db_connections  = list(),       # owned lazy import connections; session only
    db_passwords    = new.env(parent = emptyenv()), # session only; never serialized
    branch_tokens   = character(0), # currently active branch path tokens
    execution_context = list(),    # scoped loop variables; never serialized
    performance_cache = new.env(parent = emptyenv()), # bounded metadata; session only

    # Task-picker favourites (task type IDs starred by the user)
    task_favourites = c("import_data", "query_builder", "script", "export"),

    # User settings (Settings modal) — see ig_default_settings()
    settings = ig_default_settings()
  )
}

# ── Flow helpers ──────────────────────────────────────────────────────────────

#' Create a blank flow definition list.
#' @param name Name of the dataset, output, or connection entry.
make_flow <- function(name = "Flow 1") {
  id <- paste0("flow_", format(Sys.time(), "%Y%m%d%H%M%OS3"))
  list(
    id            = id,
    name          = name,
    tasks         = list(),
    task_order    = character(0),
    canvas_nodes  = NULL,
    canvas_edges  = NULL,
    canvas_layout = "LR",          # "LR" | "UD" | "free"
    canvas_pos    = NULL           # free-form mode: named list id -> list(x, y)
  )
}

# ── Canvas layout / manual positions (per active flow) ────────────────────────

#' Active flow's canvas layout mode ("LR", "UD", or "free"). Reactive.
#' @param store Session reactive store created by make_store().
store_canvas_layout <- function(store) {
  fid <- store$active_flow
  (store$flows[[fid]]$canvas_layout) %||% "LR"
}

#' Set the active flow's canvas layout mode (no-op if unchanged).
#' @param store Session reactive store created by make_store().
#' @param mode Selected canvas layout mode.
store_set_canvas_layout <- function(store, mode) {
  fid   <- isolate(store$active_flow)
  flows <- isolate(store$flows)
  if (is.null(fid) || is.null(flows[[fid]])) return(invisible(NULL))
  if (identical(flows[[fid]]$canvas_layout %||% "LR", mode)) return(invisible(NULL))
  old <- flows[[fid]]$canvas_layout %||% "LR"
  flows[[fid]]$canvas_layout <- mode
  store$flows <- flows
  store$dirty <- TRUE
  store_add_history(store, "flow", fid, "layout",
    sprintf("Canvas layout changed from %s to %s", old, mode))
  invisible(NULL)
}

#' Active flow's saved manual node positions (named list id -> list(x, y)).
#' @param store Session reactive store created by make_store().
store_canvas_positions <- function(store) {
  fid <- isolate(store$active_flow)
  isolate(store$flows)[[fid]]$canvas_pos %||% list()
}

#' Persist manual node positions for the active flow.
#' @param store Session reactive store created by make_store().
#' @param pos Saved node positions keyed by node identifier.
store_set_canvas_positions <- function(store, pos) {
  fid   <- isolate(store$active_flow)
  flows <- isolate(store$flows)
  if (is.null(fid) || is.null(flows[[fid]])) return(invisible(NULL))
  flows[[fid]]$canvas_pos <- pos
  store$flows <- flows
  store$dirty <- TRUE
  invisible(NULL)
}

#' Snapshot the active flow's live tasks/task_order back into store$flows.
#' Always call before switching flows or saving the project.
#'
#' @param canvas_state  Optional list($nodes, $edges) from visNetwork.
#' @param store Session reactive store created by make_store().
store_snapshot_flow <- function(store, canvas_state = NULL) {
  fid   <- isolate(store$active_flow)
  flows <- isolate(store$flows)
  if (is.null(fid) || is.null(flows[[fid]])) return(invisible(NULL))

  flows[[fid]]$tasks      <- isolate(store$tasks)
  flows[[fid]]$task_order <- isolate(store$task_order)
  if (!is.null(canvas_state)) {
    flows[[fid]]$canvas_nodes <- canvas_state$nodes
    flows[[fid]]$canvas_edges <- canvas_state$edges
  }
  store$flows <- flows
  invisible(NULL)
}

#' Activate a different flow.
#' Snapshots the current flow first, then loads the target flow's data into
#' the live store$tasks / store$task_order window.
#'
#' @param canvas_state  Optional canvas state to snapshot for the *current* flow.
#' @param store Session reactive store created by make_store().
#' @param flow_id Identifier of the flow to activate or inspect.
store_activate_flow <- function(store, flow_id, canvas_state = NULL) {
  store_snapshot_flow(store, canvas_state)
  flow <- isolate(store$flows)[[flow_id]]
  if (is.null(flow)) {
    warning("store_activate_flow: flow not found: ", flow_id)
    return(invisible(NULL))
  }
  store$active_flow  <- flow_id
  store$tasks        <- flow$tasks      %||% list()
  store$task_order   <- flow$task_order %||% character(0)
  store$active_node  <- NULL
  store$dirty        <- TRUE
  invisible(NULL)
}

#' Deep-copy a flow, assigning new unique IDs to all its tasks.
#' Returns the new flow_id (character), or NULL on failure.
#' @param store Session reactive store created by make_store().
#' @param src_flow_id Identifier of the flow to copy.
#' @param canvas_state Optional saved canvas nodes and edges.
store_copy_flow <- function(store, src_flow_id, canvas_state = NULL) {
  store_snapshot_flow(store, canvas_state)
  src <- isolate(store$flows)[[src_flow_id]]
  if (is.null(src)) return(NULL)

  # Millisecond timestamp as digits only. Kept as a string — epoch
  # milliseconds overflow as.integer() and would yield NA ids.
  ts      <- gsub("[^0-9]", "", format(Sys.time(), "%Y%m%d%H%M%OS6"))
  old_ids <- names(src$tasks %||% list())

  # Generate new IDs: strip trailing _N from prefix, add copy suffix + timestamp
  new_ids <- paste0(sub("_[0-9]+$", "", old_ids), "_", seq_along(old_ids),
                    "c", ts)
  id_map  <- if (length(old_ids)) setNames(new_ids, old_ids) else character(0)
  output_map <- character(0)
  for (oid in old_ids) {
    task <- src$tasks[[oid]]
    outputs <- unique(c(task_output_names(task), task$params$output_name %||% "",
      unlist(task$params$output_names %||% list(), use.names = FALSE),
      vapply(task$params$output_defs %||% list(), function(x) x$name %||% "", character(1))))
    outputs <- outputs[nzchar(outputs)]
    if (!length(outputs)) next
    primary <- task$output %||% task$params$output_name %||% outputs[[1]]
    if (!nzchar(primary)) primary <- outputs[[1]]
    for (i in seq_along(outputs)) {
      out <- outputs[[i]]
      suffix <- if (identical(out, primary)) "" else if (startsWith(out, paste0(primary, "_"))) {
        substring(out, nchar(primary) + 1L)
      } else paste0("_", i)
      output_map[[out]] <- paste0(id_map[[oid]], "_out", suffix)
    }
  }
  reference_map <- c(id_map, output_map)
  remap <- function(x) store_remap_names(x, reference_map)

  new_tasks <- if (length(old_ids)) {
    tasks_list <- lapply(old_ids, function(oid) {
      t        <- store_remap_task(src$tasks[[oid]], reference_map)
      t$id     <- id_map[[oid]]
      t$status <- "pending"
      for (field in c("run_time", "error_msg", "branch_decision", "loop_iterations",
                      "export_file", "skipped_by")) t[[field]] <- NULL
      t$execution_log <- list()
      t$log_events <- list()
      t$r_code <- ""
      t
    })
    setNames(tasks_list, new_ids)
  } else list()

  new_order <- if (length(src$task_order %||% character(0)))
    remap(src$task_order) else character(0)

  new_flow <- list(
    id           = paste0("flow_", ts, "_copy"),
    name         = paste0(src$name %||% "Flow", " (copy)"),
    tasks        = new_tasks,
    task_order   = new_order,
    canvas_nodes = NULL,   # reset layout — will auto-arrange on load
    canvas_edges = NULL,
    canvas_layout = src$canvas_layout %||% "LR",
    canvas_pos = NULL
  )

  flows <- isolate(store$flows)
  flows[[new_flow$id]] <- new_flow
  store$flows <- flows
  store$dirty <- TRUE
  new_flow$id
}

#' Remap exact graph names while preserving external input names.
#' @keywords internal
#' @param x Input value, column or nested configuration to transform.
#' @param mapping Named replacement vector mapping original names to copied names.
store_remap_names <- function(x, mapping) {
  if (!length(x)) return(x)
  match <- match(x, names(mapping))
  found <- !is.na(match)
  x[found] <- unname(mapping[match[found]])
  x
}

#' Remap object references in user R expressions for copied flows.
#' @keywords internal
#' @param code R source text whose variable references are remapped.
#' @param mapping Named replacement vector mapping original names to copied names.
store_remap_code <- function(code, mapping) {
  if (!nzchar(code %||% "")) return(code)
  expressions <- parse(text = code, keep.source = FALSE)
  walk <- function(x) {
    if (is.symbol(x)) {
      name <- as.character(x)
      if (!nzchar(name)) return(x)
      return(as.name(store_remap_names(name, mapping)))
    }
    if (is.call(x) || is.expression(x) || is.pairlist(x)) {
      # In x$column the RHS is a column name, not a flow-object reference.
      indices <- seq_along(x)
      if (is.call(x) && identical(x[[1]], as.name("$"))) indices <- head(indices, -1L)
      if (is.call(x) && as.character(x[[1]])[[1]] %in% c("get", "assign", "exists", "mget") &&
          length(x) >= 2L && is.character(x[[2]])) x[[2]] <- store_remap_names(x[[2]], mapping)
      for (i in indices) x[[i]] <- walk(x[[i]])
    }
    x
  }
  paste(vapply(as.list(expressions), function(x)
    paste(deparse(walk(x), width.cutoff = 100L), collapse = "\n"), character(1)), collapse = "\n")
}

#' Remap task configuration, including multi-output and control-flow references.
#' @keywords internal
#' @param task Task definition containing its parameters and declared outputs.
#' @param mapping Named replacement vector mapping original names to copied names.
store_remap_task <- function(task, mapping) {
  reference_fields <- c("input_table", "input_tables", "source", "dependencies",
    "output_name", "output_token", "token", "table", "table_a", "table_b",
    "from", "task_id", "output_chi", "predict_table", "pred_table",
    "primary_table", "right_table", "after_tasks")
  walk <- function(x, field = "") {
    if (is.character(x)) {
      if (field %in% c("code", "expr", "custom_expr")) return(store_remap_code(x, mapping))
      if (field %in% c(reference_fields, "name", "output_names")) return(store_remap_names(x, mapping))
      return(x)
    }
    if (is.list(x)) {
      keys <- names(x)
      for (i in seq_along(x)) {
        key <- if (is.null(keys)) field else keys[[i]]
        if (field == "output_names") key <- "output_names"
        x[i] <- list(walk(x[[i]], key))
      }
      if (field == "table_names" && !is.null(keys)) names(x) <- store_remap_names(keys, mapping)
    }
    x
  }
  task$inputs <- store_remap_names(task$inputs %||% character(0), mapping)
  task$control_inputs <- store_remap_names(task$control_inputs %||% character(0), mapping)
  task$output <- store_remap_names(task$output %||% "", mapping)
  task$outputs <- walk(task$outputs %||% list())
  task$params <- walk(task$params %||% list())
  task
}

# ── Table helpers ─────────────────────────────────────────────────────────────

#' Register a data frame into the store.
#' Uses explicit full-list replacement so Shiny's reactive system is guaranteed
#' to invalidate any observer that reads store$tables.
#' @param store Session reactive store created by make_store().
#' @param name Name of the dataset, output, or connection entry.
#' @param source_meta Import source metadata, if this table is an imported source.
#' @param df Data frame or lazy database table being stored.
store_add_table <- function(store, name, df, source_meta = NULL) {
  tbls          <- isolate(store$tables)
  existed       <- name %in% names(tbls)
  tbls[[name]]  <- df
  store$tables  <- tbls          # explicit replace — guaranteed reactive invalidation
  store_invalidate_outputs(store, name)

  if (!is.null(source_meta)) {
    srcs          <- isolate(store$sources)
    srcs[[name]]  <- source_meta
    store$sources <- srcs
  }
  store$dirty <- TRUE
  store_add_history(store, "dataset", name, if (existed) "update" else "create",
    sprintf("Dataset '%s' %s", name, if (existed) "updated" else "added"))
  invisible(name)
}

#' Remove a table from the store.
#' @param store Session reactive store created by make_store().
#' @param name Name of the dataset, output, or connection entry.
store_remove_table <- function(store, name) {
  tbls          <- isolate(store$tables)
  existed       <- name %in% names(tbls)
  tbls[[name]]  <- NULL
  store$tables  <- tbls
  if (existed) store_invalidate_outputs(store, name)

  srcs          <- isolate(store$sources)
  srcs[[name]]  <- NULL
  store$sources <- srcs

  store$dirty <- TRUE
  if (existed) store_add_history(store, "dataset", name, "delete",
    sprintf("Dataset '%s' removed", name))
  invisible(NULL)
}

#' Register a non-tabular object into the store.
#' @param store Session reactive store created by make_store().
#' @param name Name of the dataset, output, or connection entry.
#' @param object Non-tabular value to store.
#' @param meta Metadata describing the stored value.
store_add_object <- function(store, name, object, meta = list()) {
  objs <- isolate(store$objects)
  existed <- name %in% names(objs)
  objs[[name]] <- list(value = object, meta = meta)
  store$objects <- objs
  store_invalidate_outputs(store, name)
  store$dirty <- TRUE
  store_add_history(store, "output", name, if (existed) "update" else "create",
    sprintf("Output '%s' %s", name, if (existed) "updated" else "added"))
  invisible(name)
}

#' Remove a non-tabular object from the store.
#' @param store Session reactive store created by make_store().
#' @param name Name of the dataset, output, or connection entry.
store_remove_object <- function(store, name) {
  objs <- isolate(store$objects)
  existed <- name %in% names(objs)
  objs[[name]] <- NULL
  store$objects <- objs
  if (existed) store_invalidate_outputs(store, name)
  store$dirty <- TRUE
  if (existed) store_add_history(store, "output", name, "delete",
    sprintf("Output '%s' removed", name))
  invisible(NULL)
}

#' Remove any output, whether tabular or special object.
#' @param store Session reactive store created by make_store().
#' @param name Name of the dataset, output, or connection entry.
store_remove_output <- function(store, name) {
  if (!nzchar(name %||% "")) return(invisible(NULL))
  if (name %in% names(isolate(store$tables))) store_remove_table(store, name)
  if (name %in% names(isolate(store$objects))) store_remove_object(store, name)
  invisible(NULL)
}

#' Read all project tasks, using the active flow's live definitions.
#' @keywords internal
#' @param store Session reactive store created by make_store().
#' @param track Whether reading project state should establish reactive dependencies.
store_all_tasks <- function(store, track = FALSE) {
  read <- function(name) if (track) store[[name]] else isolate(store[[name]])
  flows <- read("flows")
  active <- read("active_flow")
  tasks <- list()
  for (fid in names(flows)) {
    current <- if (identical(fid, active)) read("tasks") else flows[[fid]]$tasks
    tasks <- c(tasks, current %||% list())
  }
  if (!length(flows)) tasks <- read("tasks")
  tasks
}

#' Invalidate every cached consumer of changed data, including other flows.
#' @param include Optional task IDs whose own outputs are also invalid.
#' @keywords internal
#' @param store Session reactive store created by make_store().
#' @param changed Names of changed upstream outputs whose consumers require invalidation.
store_invalidate_outputs <- function(store, changed, include = character(0)) {
  tasks <- store_all_tasks(store)
  invalid <- intersect(include, names(tasks))
  dependents <- store_task_dependents(tasks)
  consumers <- names(Filter(function(t)
    length(intersect(t$inputs %||% character(0), changed)) > 0L, tasks))
  pending <- unique(c(consumers, unlist(dependents[invalid], use.names = FALSE)))
  # Visit each consumer once. Preserve the old traversal's project-order waves
  # without rescanning every task's full definition at every pipeline depth.
  seen <- setNames(rep(FALSE, length(tasks)), names(tasks))
  seen[invalid] <- TRUE
  while (length(pending)) {
    added <- names(tasks)[names(tasks) %in% pending & !seen]
    if (!length(added)) break
    seen[added] <- TRUE
    invalid <- c(invalid, added)
    pending <- unique(unlist(dependents[added], use.names = FALSE))
  }
  if (!length(invalid)) return(invisible(character(0)))
  outputs <- unique(unlist(lapply(tasks[invalid], task_output_names), use.names = FALSE))
  tables <- isolate(store$tables)
  objects <- isolate(store$objects)
  store$tables <- tables[setdiff(names(tables), outputs)]
  store$objects <- objects[setdiff(names(objects), outputs)]
  store$branch_tokens <- setdiff(isolate(store$branch_tokens), unique(c(changed, outputs)))
  for (id in invalid) {
    had_results <- length(intersect(task_output_names(tasks[[id]]), c(names(tables), names(objects)))) > 0L
    tasks[[id]]$invalidated <- isTRUE(tasks[[id]]$invalidated) || !is.null(tasks[[id]]$run_time) || had_results
    tasks[[id]]$status <- "pending"
    tasks[[id]]$run_time <- NULL
    tasks[[id]]$error_msg <- NULL
    if (identical(tasks[[id]]$type, "branch")) tasks[[id]]$branch_decision <- NULL
  }
  active_tasks <- isolate(store$tasks)
  for (id in intersect(names(active_tasks), invalid)) active_tasks[[id]] <- tasks[[id]]
  store$tasks <- active_tasks
  flows <- isolate(store$flows)
  for (fid in names(flows)) {
    for (id in intersect(names(flows[[fid]]$tasks), invalid)) flows[[fid]]$tasks[[id]] <- tasks[[id]]
  }
  store$flows <- flows
  # Read the session callback registry once for the invalidation wave. Most
  # tasks have no mounted panel; creating a reactive context for each of them
  # made editing a long pipeline wait on hundreds of empty preview lookups.
  previews <- isolate(store$result_fns)
  for (id in invalid) if (is.function(previews[[id]])) previews[[id]](NULL)
  invisible(invalid)
}

#' Record a failed execution and retire its outputs before consumers can run.
#' @keywords internal
#' @param store Session reactive store created by make_store().
#' @param task_id Task identifier; NULL when no stored task is being edited.
#' @param message Actionable execution failure message shown with task status.
store_task_failed <- function(store, task_id, message) {
  if (is.null(task_id)) return(invisible(FALSE))
  task <- isolate(store$tasks[[task_id]])
  if (is.null(task)) return(invisible(FALSE))
  store_invalidate_outputs(store, task_output_names(task), include = task_id)
  task <- isolate(store$tasks[[task_id]])
  task$error_msg <- message
  task$status <- "error"
  task$run_time <- NULL
  store_set_task(store, task)
  store_update_preview(store, task_id, list(error = message))
  invisible(FALSE)
}

#' Explain why a task cannot consume an unavailable producer's cached result.
#' @keywords internal
#' @param store Session reactive store created by make_store().
#' @param task_id Task identifier; NULL when no stored task is being edited.
store_upstream_problem <- function(store, task_id) {
  tasks <- store_all_tasks(store)
  task <- tasks[[task_id]]
  if (is.null(task) || identical(task$type, "branch")) return(NULL)
  owners <- store_task_output_owner(tasks)
  for (input in task$inputs %||% character(0)) {
    owner <- owners[[input]]
    if (is.null(owner) || identical(owner, task_id)) next
    upstream <- tasks[[owner]]
    if ((upstream$status %||% "") %in% c("error", "skipped")) {
      message <- sprintf("Upstream dependency '%s' (%s) was %s; this task was not run.", owner, input, upstream$status)
      attr(message, "skip") <- TRUE
      return(message)
    }
    if (input %in% task_output_names(upstream, "branch") && identical(upstream$type, "branch") &&
        identical(upstream$status, "success") && !is.null(upstream$branch_decision) &&
        !input %in% (upstream$branch_decision$matched_tokens %||% character(0))) {
      alternatives <- intersect(task$inputs, upstream$branch_decision$matched_tokens %||% character(0))
      if (!length(alternatives)) {
        message <- sprintf("Inactive branch path '%s'.", input)
        attr(message, "skip") <- TRUE
        return(message)
      }
    }
    if (!identical(upstream$status %||% "pending", "success") || isTRUE(upstream$invalidated))
      return(sprintf("Upstream dependency '%s' (%s) has no valid result. Run it successfully first.", owner, input))
  }
  NULL
}

#' Mark a task as skipped without presenting it as an execution failure.
#' @keywords internal
#' @param store Session reactive store created by make_store().
#' @param task_id Task identifier; NULL when no stored task is being edited.
#' @param reason Explanation of the dependency or branch that skipped the task.
store_task_skipped <- function(store, task_id, reason) {
  store_invalidate_outputs(store, character(0), include = task_id)
  task <- isolate(store$tasks[[task_id]])
  if (is.null(task)) return(invisible(FALSE))
  task$status <- "skipped"
  task$error_msg <- NULL
  task$run_time <- NULL
  task$skip_reason <- as.character(reason)
  task$invalidated <- FALSE
  store_set_task(store, task)
  ig_notify(as.character(reason), type = "warning", duration = 5)
  invisible(FALSE)
}

#' List table names currently in the store (computed tables only).
#' @param store Session reactive store created by make_store().
store_table_names <- function(store) names(store$tables)

#' List non-tabular object output names currently in the store.
#' @param store Session reactive store created by make_store().
store_object_names <- function(store) names(store$objects)

#' Return named output specs for a task.
#' @param task Task definition containing its parameters and declared outputs.
task_output_specs <- function(task) {
  outs <- task$outputs %||% list()
  if (!length(outs) && nzchar(task$output %||% "")) {
    outs <- list(list(name = task$output, kind = "table", label = "Output table"))
  }
  Filter(function(x) nzchar(x$name %||% ""), outs)
}

task_output_names <- function(task, kinds = NULL) {
  specs <- task_output_specs(task)
  if (!is.null(kinds)) {
    specs <- Filter(function(x) (x$kind %||% "table") %in% kinds, specs)
  }
  vapply(specs, function(x) x$name %||% "", character(1))
}

store_task_output_owner <- function(tasks, kinds = NULL) {
  owners <- list()
  for (tid in names(tasks %||% list())) {
    for (out in task_output_names(tasks[[tid]], kinds = kinds)) {
      if (nzchar(out)) owners[[out]] <- tid
    }
  }
  owners
}

#' Resolve both data dependencies and explicit task-status dependencies.
#' @keywords internal
#' @param task Task definition containing its parameters and declared outputs.
#' @param tasks Named list of task definitions.
#' @param owners Optional output-name-to-task mapping used for dependency resolution.
store_task_dependency_ids <- function(task, tasks, owners = store_task_output_owner(tasks)) {
  inputs <- task$inputs %||% character(0)
  outputs <- unique(Filter(Negate(is.null), lapply(inputs, function(input) owners[[input]])))
  direct <- if (identical(task$type, "branch")) branch_references(task$params, "task_id") else
    if (identical(task$type, "export_log")) {
      task$params$after_tasks %||% character(0)
    } else character(0)
  unique(c(unlist(outputs, use.names = FALSE), intersect(direct, names(tasks))))
}

store_task_dependents <- function(tasks) {
  out_to_tid <- store_task_output_owner(tasks)
  fwd <- setNames(vector("list", length(tasks)), names(tasks))
  for (tid in names(tasks)) {
    for (producer in store_task_dependency_ids(tasks[[tid]], tasks, out_to_tid)) {
      if (!is.null(producer) && producer %in% names(tasks) &&
          !identical(producer, tid)) {
        fwd[[producer]] <- unique(c(fwd[[producer]], tid))
      }
    }
  }
  fwd
}

store_task_descendants <- function(tasks, task_id) {
  if (is.null(task_id) || !task_id %in% names(tasks %||% list()))
    return(character(0))
  fwd <- store_task_dependents(tasks)
  visited <- character(0)
  queue <- fwd[[task_id]] %||% character(0)
  while (length(queue)) {
    node <- queue[1]; queue <- queue[-1]
    if (node %in% visited) next
    visited <- c(visited, node)
    queue <- c(queue, fwd[[node]] %||% character(0))
  }
  visited
}

store_allowed_outputs <- function(outputs, owners, tasks, task_id = NULL) {
  outputs <- unique(Filter(nzchar, outputs))
  if (is.null(task_id) || !task_id %in% names(tasks %||% list()))
    return(outputs)
  blocked_tasks <- c(task_id, store_task_descendants(tasks, task_id))
  Filter(function(out) {
    owner <- owners[[out]]
    is.null(owner) || !owner %in% blocked_tasks
  }, outputs)
}

store_preserve_choice <- function(current, saved = NULL, choices = character(0),
                                  default = "", initialized = FALSE) {
  if (is.null(current) && initialized) return(if (default %in% choices) default else "")
  if (initialized && identical(current, "") && "" %in% choices) return("")
  current <- current %||% ""
  saved <- saved %||% default
  if (length(current) && nzchar(current) && current %in% choices) return(current)
  if (length(saved) && nzchar(saved) && saved %in% choices) return(saved)
  if (default %in% choices) return(default)
  ""
}

store_preserve_choices <- function(current, saved = character(0),
                                   choices = character(0), initialized = FALSE) {
  if (is.null(current) && initialized) return(character(0))
  if (!initialized && !length(current)) return(intersect(saved %||% character(0), choices))
  if (!is.null(current)) return(intersect(current, choices))
  saved <- saved %||% character(0)
  intersect(saved, choices)
}

#' All table names a task can use as input:
#'   • computed tables already in store$tables
#'   • output names declared by any task in the active flow (may not exist yet)
#'
#' Tracks live definitions so output renames and schema changes are available
#' immediately. The active flow's old snapshot never contributes stale names.
#' @param store Session reactive store created by make_store().
#' @param task_id Task identifier; NULL when no stored task is being edited.
store_available_tables <- function(store, task_id = NULL) {
  computed   <- names(store$tables)          # reactive dep: store$tables
  tasks_snap <- store_choice_tasks(store)
  defined_outs <- unique(Filter(nzchar, unlist(lapply(tasks_snap, task_output_names, kinds = "table"))))
  all_names <- unique(c(computed, setdiff(defined_outs, computed)))
  owners <- store_task_output_owner(tasks_snap, kinds = "table")
  store_allowed_outputs(all_names, owners, tasks_snap, task_id)
}

#' All named outputs a script can use as dependencies: tables plus special
#' objects declared by tasks.
#' @param store Session reactive store created by make_store().
#' @param task_id Task identifier; NULL when no stored task is being edited.
store_available_outputs <- function(store, task_id = NULL) {
  table_outs <- store_available_tables(store, task_id = task_id)
  object_outs <- names(store$objects)
  tasks_snap <- store_choice_tasks(store)
  defined_objs <- unlist(lapply(tasks_snap, task_output_names, kinds = c("model", "plot", "image", "object", "branch")))
  all_names <- unique(Filter(nzchar, c(table_outs, object_outs, defined_objs)))
  owners <- store_task_output_owner(tasks_snap)
  store_allowed_outputs(all_names, owners, tasks_snap, task_id)
}

store_available_control_tokens <- function(store, task_id = NULL) {
  tasks_snap <- store_choice_tasks(store)
  all_tokens <- unique(Filter(nzchar, unlist(lapply(tasks_snap, task_output_names, kinds = "branch"))))
  owners <- store_task_output_owner(tasks_snap, kinds = "branch")
  store_allowed_outputs(all_tokens, owners, tasks_snap, task_id)
}

#' Report whether project-changing actions are blocked by review mode.
#'
#' Review comments and decisions intentionally bypass this guard; task runs,
#' exports, and project-structure changes use it before doing any work.
#' @param store Session reactive store created by make_store().
#' @param action Human-readable description of the attempted operation.
#' @param notify Whether to display a notification when the operation is blocked.
store_review_blocked <- function(store, action = "run tasks", notify = TRUE) {
  blocked <- isTRUE(isolate(store$review_mode))
  if (blocked && isTRUE(notify)) {
    ig_notify(
      sprintf("Review mode is read-only. Disable review mode to %s.", action),
      type = "warning", duration = 5)
  }
  blocked
}

store_run_guarded <- function(store, fn, action = "run tasks", task_id = NULL) {
  state <- isolate(store$background)
  if (!is.null(state$job) && length(isolate(store$run_ids)) && !identical(task_id, state$job$task_id)) {
    ig_notify("The running flow is waiting for its current analysis.", type = "message")
    return(invisible(FALSE))
  }
  if (ig_background_eligible(store, task_id)) return(ig_background_start(store, task_id))
  if (is.null(task_id)) return(store_run_guarded_impl(store, fn, action, task_id))
  ig_task_logged(store, task_id, function() store_run_guarded_impl(store, fn, action, task_id))
}

store_run_guarded_impl <- function(store, fn, action = "run tasks", task_id = NULL) {
  if (store_review_blocked(store, action)) return(invisible(FALSE))
  if (is.null(task_id)) return(fn())
  task <- isolate(store$tasks[[task_id]])
  if (is.null(task)) return(invisible(FALSE))
  problem <- store_upstream_problem(store, task_id)
  if (isTRUE(attr(problem, "skip"))) return(store_task_skipped(store, task_id, problem))
  if (!is.null(problem)) return(store_task_failed(store, task_id, problem))
  previous_time <- task$run_time
  task$status <- "running"
  task$error_msg <- NULL
  store_set_task(store, task)
  caught <- NULL
  result <- tryCatch(fn(), error = function(e) {
    caught <<- if (inherits(e, "shiny.silent.error")) "Required inputs are not set." else conditionMessage(e)
    FALSE
  })
  if (inherits(result, "ig_pending_task")) {
    store_invalidate_outputs(store, character(0), include = task_id)
    waiting <- isolate(store$tasks[[task_id]])
    waiting$status <- "waiting"
    store_set_task(store, waiting)
    return(invisible(result))
  }
  after <- isolate(store$tasks[[task_id]])
  message <- caught %||% after$error_msg
  if (is.null(message) && (identical(result, FALSE) || identical(after$run_time, previous_time)))
    message <- "Task did not complete. Check its required inputs and configuration."
  if (!is.null(message)) {
    ig_notify(message, type = "error", duration = 8)
    if (identical(after$status, "error") && identical(after$error_msg, message)) return(invisible(FALSE))
    return(store_task_failed(store, task_id, message))
  }
  invisible(TRUE)
}

#' Register a run-function for a task.
#' Called by each task module at init so the queue processor can call it.
#' @param store Session reactive store created by make_store().
#' @param task_id Task identifier; NULL when no stored task is being edited.
#' @param fn Callback invoked to read code, configuration, or execute the task.
store_register_runner <- function(store, task_id, fn) {
  if (is.null(task_id)) return(invisible(NULL))
  rnrs              <- isolate(store$task_runners)
  rnrs[[task_id]]   <- function() store_run_guarded(store, fn, task_id = task_id)
  store$task_runners <- rnrs
  invisible(NULL)
}

#' Derive declared dependencies and outputs from persisted task configuration.
#' @keywords internal
#' @param task Task definition containing its parameters and declared outputs.
#' @param params Persisted task configuration list.
store_task_from_params <- function(task, params) {
  type <- task$type
  task$params <- params
  inputs <- switch(type,
    import_data = character(0),
    query_builder = query_input_tables(params),
    append_table = params$input_tables,
    compare_data = c(params$table_a, params$table_b),
    script = params$input_tables,
    report = vapply(params$items %||% list(), function(x) x$name %||% "", character(1)),
    branch = c(params$dependencies, branch_references(params, "table")),
    loop = params$source,
    export = params$source,
    export_log = character(0),
    c(params$input_table, params$pred_table))
  task$inputs <- unique(Filter(nzchar, c(inputs, task$control_inputs %||% character(0))))
  if (type %in% PHASE3_TYPES) {
    task$output <- params$output_name %||% ""
    defs <- phase3_return_defs(type)
    task$outputs <- Filter(Negate(is.null), lapply(defs, function(d) {
      enabled <- params$output_enabled[[d$key]] %||% TRUE
      name <- params$output_names[[d$key]] %||% if (d$key == "table") params$output_name else ""
      if (!isTRUE(enabled) || !nzchar(name %||% "")) return(NULL)
      list(name = name, kind = d$kind, label = d$label)
    }))
  } else if (identical(type, "script")) {
    specs <- params$output_defs %||% list(list(name = params$output_name, kind = "auto"))
    task$outputs <- lapply(specs, function(x) {
      if (identical(x$kind, "auto")) x$kind <- "table"
      x
    })
    table_specs <- Filter(function(x) identical(x$kind, "table"), task$outputs)
    task$output <- if (length(table_specs)) table_specs[[1]]$name else ""
  } else if (type %in% c("branch", "loop", "export", "export_log")) {
    task$output <- ""
    task$outputs <- switch(type, branch = branch_output_specs(params), loop = loop_output_specs(params), list())
  } else {
    task$output <- if (!identical(params$output_enabled, FALSE)) params$output_name %||% "" else ""
    kind <- switch(type, compare_data = "object", report = "report", "table")
    task$outputs <- if (nzchar(task$output)) list(list(name = task$output, kind = kind, label = "Output")) else list()
    if (type == "table_analysis" && isTRUE(params$output_chi_enabled) && nzchar(params$output_chi %||% ""))
      task$outputs <- c(task$outputs, list(list(name = params$output_chi, kind = "table", label = "Chi-square test")))
  }
  task
}

#' Save the current validated shape of a module's configuration without running.
#' @keywords internal
#' @param store Session reactive store created by make_store().
#' @param task_id Task identifier; NULL when no stored task is being edited.
#' @param fn Callback invoked to read code, configuration, or execute the task.
#' @param session Owning Shiny module session.
store_register_params_fn <- function(store, task_id, fn, session = shiny::getDefaultReactiveDomain()) {
  if (is.null(task_id)) return(invisible(NULL))
  ready <- shiny::reactiveVal(FALSE)
  token <- ig_new_id(session$ns("ready"))
  fns <- isolate(store$params_fns)
  fns[[task_id]] <- function() if (isolate(ready())) fn() else NULL
  attr(fns[[task_id]], "ready") <- ready
  store$params_fns <- fns
  ready_observer <- observeEvent(session$input$ig_ready, {
    if (!identical(session$input$ig_ready, token)) return()
    ready(TRUE)
    ready_observer$destroy()
    queue <- isolate(store$run_queue)
    if (length(queue) && identical(queue[[1L]], task_id) && is.null(isolate(store$run_waiting)))
      store$run_task_done_n <- isolate(store$run_task_done_n) + 1L
  })
  session$onFlushed(function() {
    session$sendCustomMessage("ig_module_ready", list(id = session$ns("ig_ready"), token = token,
      panel = paste0("panel_", task_id)))
  }, once = TRUE)
  observe({
    if (!ready() || is.null(isolate(store$tasks[[task_id]])) || store_review_blocked(store, notify = FALSE)) return()
    params <- fn()
    isolate(store_sync_parameters(store, task_id, params))
  }, priority = 100)
  invisible(NULL)
}

#' Synchronize open task settings before saving, switching flows or exporting code.
#' @keywords internal
#' @param store Session reactive store created by make_store().
#' @param task_id Task identifier; NULL when no stored task is being edited.
#' @param params Persisted task configuration list.
store_sync_parameters <- function(store, task_id = NULL, params = NULL) {
  tasks <- isolate(store$tasks)
  fns <- isolate(store$params_fns) %||% list()
  ids <- if (is.null(task_id)) intersect(names(tasks), names(fns)) else intersect(task_id, names(tasks))
  for (id in ids) {
    if (is.null(params) && !is.function(fns[[id]])) next
    current <- if (!is.null(params)) params else fns[[id]]()
    if (is.null(current) || identical(tasks[[id]]$params, current)) next
    updated <- store_task_from_params(tasks[[id]], current)
    if (store_equivalent_parameters(tasks[[id]], updated)) {
      # Browser widgets normalize optional blanks and whole numbers. Retain
      # valid cached results when their effective configuration is unchanged.
      live <- isolate(store$tasks)
      live[[id]]$params <- current
      store$tasks <- live
      next
    }
    store_set_task(store, updated)
  }
  invisible(NULL)
}

# Compare widget representations only where the executor treats them equally.
store_equivalent_parameters <- function(before, after) {
  normalize <- function(task) {
    p <- task$params
    if (task$type %in% PHASE3_TYPES) {
      optional <- c("input_table", "x", "y", "y2", "group", "facet", "size", "cols",
        "response", "predictors", "pred_table")
      for (key in optional) if (!length(p[[key]]) || identical(p[[key]], "")) p[[key]] <- NULL
      for (key in names(p$output_enabled)) if (identical(p$output_enabled[[key]], FALSE))
        p$output_names[[key]] <- NULL
    }
    if (task$type == "import_data") p <- store_effective_import_params(p)
    p <- p[order(names(p))]
    task$params <- p
    task[c("type", "params", "inputs", "output", "control_inputs")]
  }
  isTRUE(all.equal(normalize(before), normalize(after), tolerance = 0, check.attributes = TRUE))
}

# Only the active reader's settings affect imported results. Normalize its
# documented Boolean defaults so opening an options panel cannot retire data.
store_effective_import_params <- function(p) {
  if (identical(p$source_kind, "db")) {
    keys <- c("source_kind", "output_name", "db_conn_mode", "db_table", "db_schema", "db_use_query", "db_sql", "db_collect")
    keys <- c(keys, if (identical(p$db_conn_mode, "code")) "db_conn_code" else
      c("db_driver", "db_dsn", "db_host", "db_port", "db_database", "db_uid"))
    return(p[intersect(keys, names(p))])
  }
  p$type <- import_file_type(p)
  prefix <- switch(p$type, csv = "csv_", xls = , xlsx = "excel_",
    sas7bdat = , dta = , sav = "haven_", rda = "rda_", "unused_")
  keys <- c("source_kind", "output_name", "path", "type", names(p)[startsWith(names(p), prefix)])
  defaults <- switch(p$type,
    csv = list(csv_escape_backslash = FALSE, csv_escape_double = TRUE, csv_trim_ws = FALSE,
      csv_quoted_na = TRUE, csv_skip_empty_rows = TRUE, csv_lazy = FALSE),
    xls = , xlsx = list(excel_trim_ws = TRUE), sav = list(haven_user_na = FALSE), list())
  for (key in names(defaults)) if (is.null(p[[key]])) p[[key]] <- defaults[[key]]
  if (p$type %in% c("xls", "xlsx")) {
    sheets <- tryCatch(readxl::excel_sheets(p$path), error = function(e) character(0))
    if (length(sheets)) {
      sheet <- p$excel_sheet
      if (!length(sheet) || identical(sheet, "")) sheet <- 1L
      if (is.numeric(sheet) && length(sheet) == 1L && is.finite(sheet) && sheet >= 1L && sheet <= length(sheets))
        sheet <- sheets[[as.integer(sheet)]]
      p$excel_sheet <- sheet
    }
  }
  keys <- union(keys, names(defaults))
  if (p$type != "sav") keys <- setdiff(keys, "haven_user_na")
  p[intersect(keys, names(p))]
}

#' Register a live code-generator for a task.
#' The panel header's Code strip prefers this (reflects the current inputs)
#' over the stored last-run code. Safe to call from module init.
#' @param store Session reactive store created by make_store().
#' @param task_id Task identifier; NULL when no stored task is being edited.
#' @param fn Callback invoked to read code, configuration, or execute the task.
store_register_code_fn <- function(store, task_id, fn) {
  if (is.null(task_id)) return(invisible(NULL))
  fns            <- isolate(store$code_fns)
  fns[[task_id]] <- fn
  store$code_fns <- fns
  invisible(NULL)
}

#' Read only the schema needed by input controls, without scanning table values.
#' @param store Session reactive store created by make_store().
#' @param table_name Name of the table to inspect.
#' @keywords internal
store_col_schema_value <- function(store, table_name) {
  df <- store$tables[[table_name]]
  if (is.null(df) || inherits(df, "tbl_sql")) return(store_col_info(store, table_name))
  data.frame(
    column = names(df),
    class = vapply(df, function(x) class(x)[1L], character(1)),
    n_distinct = rep(NA_integer_, ncol(df)),
    n_missing = rep(NA_integer_, ncol(df)),
    stringsAsFactors = FALSE
  )
}

# Keep the reader's closure separate from the cache lookup frame: it must not
# retain an old cache list (and its evicted readers) through that environment.
store_col_schema_reader <- function(store, table_name) {
  force(store); force(table_name)
  shiny::reactive(store_col_schema_value(store, table_name))
}

store_col_schema <- function(store, table_name) {
  if (!is.character(table_name) || length(table_name) != 1L || !nzchar(table_name))
    return(data.frame())
  # A live database can change without a store assignment. Preserve fresh
  # metadata reads when a panel opens instead of memoizing external state.
  if (inherits(store$tables[[table_name]], "tbl_sql")) return(store_col_info(store, table_name))
  cache <- isolate(store$performance_cache)
  if (is.null(cache)) return(store_col_schema_value(store, table_name))
  readers <- cache$schemas %||% list()
  read <- readers[[table_name]]
  if (is.null(read)) {
    read <- store_col_schema_reader(store, table_name)
    if (length(readers) >= 32L) readers <- readers[-1L]
    readers[[table_name]] <- read
    cache$schemas <- readers
  }
  read()
}

#' Get column info for a table (name, class, n_distinct, n_missing).
#' @param store Session reactive store created by make_store().
#' @param table_name Name of the table to inspect.
store_col_info <- function(store, table_name) {
  df <- store$tables[[table_name]]
  if (is.null(df)) return(store$sources[[table_name]]$schema %||% data.frame())

  if (inherits(df, "tbl_sql")) {
    # Fetch 0 rows to get column names and types without pulling data across the wire.
    schema_df <- tryCatch(
      as.data.frame(dplyr::collect(dplyr::slice_head(df, n = 0L))),
      error = function(e) tryCatch(
        as.data.frame(dplyr::collect(utils::head(df, 1L))),
        error = function(e2) NULL
      )
    )
    if (is.null(schema_df)) return(data.frame())
    return(data.frame(
      column     = names(schema_df),
      class      = vapply(schema_df, function(x) class(x)[1L], character(1L)),
      n_distinct = rep(NA_integer_, ncol(schema_df)),
      n_missing  = rep(NA_integer_, ncol(schema_df)),
      stringsAsFactors = FALSE
    ))
  }

  # Original logic for in-memory data frames
  data.frame(
    column     = names(df),
    class      = vapply(df, function(x) class(x)[1], character(1)),
    n_distinct = vapply(df, function(x) length(unique(x)), integer(1)),
    n_missing  = vapply(df, function(x) sum(is.na(x)),    integer(1)),
    stringsAsFactors = FALSE
  )
}

#' Retrieve a table from the store, materialising any lazy tbl_sql to a plain
#' data frame.  Use this everywhere a module server reads a table for immediate
#' computation (describe, graph, stats, data tasks).
#'
#' Pass \code{collect = FALSE} for modules that intentionally work with lazy
#' objects (Query Builder, Script).
#' @param store Session reactive store created by make_store().
#' @param name Name of the dataset, output, or connection entry.
#' @param collect Whether to materialize a lazy database table.
store_get_table <- function(store, name, collect = TRUE) {
  x <- store$tables[[name]]
  if (collect && inherits(x, "tbl_sql")) {
    tryCatch(
      as.data.frame(dplyr::collect(x)),
      error = function(e) {
        warning("store_get_table: could not collect '", name, "': ", e$message)
        NULL
      }
    )
  } else {
    x
  }
}

# ── Task helpers ──────────────────────────────────────────────────────────────

#' Create a skeleton task definition list.
#' @param id Identifier of the module, task, flow, or catalogue entry being addressed.
#' @param type Registered task type identifier.
#' @param inputs Names of upstream data or control outputs.
#' @param output Primary output name.
#' @param params Persisted task configuration list.
task_def <- function(id, type, inputs = character(0),
                     output = NULL, params = list()) {
  list(
    id        = id,
    type      = type,
    label     = NULL,   # optional user-set display name shown on canvas node
    inputs    = inputs,
    output    = output,
    outputs   = if (nzchar(output %||% "")) {
      list(list(name = output, kind = "table", label = "Output table"))
    } else list(),
    params    = params,
    r_code    = "",
    run_time  = NULL,
    error_msg = NULL,
    status    = "pending",
    execution_log = list(),
    logging   = ig_logging_config(type = type),
    log_events = list(),
    note      = NULL
  )
}

#' Order task identifiers using their prerequisite adjacency lists.
#' @param prereqs Named list of prerequisite task identifiers.
#' @param task_order Task identifiers in their stable display order.
#' @keywords internal
store_dependency_order <- function(prereqs, task_order) {
  in_degree <- setNames(integer(length(task_order)), task_order)
  dependents <- setNames(vector("list", length(task_order)), task_order)
  for (id in task_order) {
    dependencies <- intersect(prereqs[[id]], task_order)
    in_degree[[id]] <- length(dependencies)
    for (dependency in dependencies) dependents[[dependency]] <- c(dependents[[dependency]], id)
  }
  ready <- names(in_degree)[in_degree == 0L]
  sorted <- character(length(task_order))
  cursor <- 1L
  count <- 0L
  while (cursor <= length(ready)) {
    id <- ready[[cursor]]; cursor <- cursor + 1L
    count <- count + 1L; sorted[[count]] <- id
    for (consumer in dependents[[id]]) {
      in_degree[[consumer]] <- in_degree[[consumer]] - 1L
      if (in_degree[[consumer]] == 0L) ready <- c(ready, consumer)
    }
  }
  sorted[seq_len(count)]
}

#' Validate output ownership, self references and dependency cycles.
#' @param tasks Named list of task definitions.
#' @param task_order Task identifiers in their stable display order.
#' @keywords internal
store_dependency_problem <- function(tasks, task_order) {
  task_order <- task_order[task_order %in% names(tasks %||% list())]
  if (length(task_order) < 1L) return(NULL)

  out_to_tid <- store_task_output_owner(tasks)
  for (tid in task_order) {
    spec_names <- vapply(task_output_specs(tasks[[tid]]), function(spec) spec$name %||% "", character(1))
    if (anyDuplicated(Filter(nzchar, spec_names))) return(paste("Output names within a task must be unique:", tid))
  }
  outputs <- unlist(lapply(tasks, task_output_names), use.names = FALSE)
  duplicates <- unique(outputs[duplicated(outputs)])
  if (length(duplicates)) return(paste("Output names must have one producer:", paste(duplicates, collapse = ", ")))

  for (tid in task_order) {
    own_outs <- task_output_names(tasks[[tid]])
    self_refs <- intersect(tasks[[tid]]$inputs %||% character(0), own_outs)
    if (identical(tasks[[tid]]$type, "branch") && tid %in% branch_references(tasks[[tid]]$params, "task_id"))
      return(sprintf("Task '%s' cannot depend on its own status or parameters.", tid))
    if (length(self_refs)) {
      return(sprintf(
        "Task '%s' cannot use its own output as an input: %s",
        tid, paste(self_refs, collapse = ", ")
      ))
    }
  }

  prereqs <- setNames(vector("list", length(task_order)), task_order)
  for (tid in task_order) {
    deps <- store_task_dependency_ids(tasks[[tid]], tasks, out_to_tid)
    prereqs[[tid]] <- setdiff(deps, tid)
  }

  sorted <- store_dependency_order(prereqs, task_order)

  if (length(sorted) < length(task_order)) {
    cyclic <- setdiff(task_order, sorted)
    return(sprintf(
      "Circular task reference detected involving: %s",
      paste(cyclic, collapse = ", ")
    ))
  }
  NULL
}

store_notify_dependency_problem <- function(msg) {
  warning(msg, call. = FALSE)
  ig_notify(msg, type = "error", duration = 8)
  invisible(FALSE)
}

store_set_task <- function(store, task) {
  id       <- task$id
  if (identical(task$type, "branch"))
    task$inputs <- unique(c(task$inputs, branch_references(task$params, "table")))
  # Derive the canvas status from the task record so every save path agrees:
  # an error message wins, then a recorded run means success, else pending.
  # (Modules set run_time/error_msg; only the headless executor used to set
  # status, which left panel-run tasks without their green border.)
  task$status <- if (!is.null(task$error_msg)) {
    "error"
  } else if ((task$status %||% "") %in% c("running", "skipped")) {
    task$status
  } else if (!is.null(task$run_time)) {
    "success"
  } else {
    task$status %||% "pending"
  }
  # Legacy/single-output modules usually only update task$output. Keep their
  # output specs synchronized unless the module deliberately registered
  # multiple outputs.
  specs <- task$outputs %||% list()
  specs_are_single_table <- length(specs) <= 1L &&
    (length(specs) == 0L || identical(specs[[1]]$kind %||% "table", "table"))
  if (specs_are_single_table && !task$type %in% c(PHASE3_TYPES, "script", "table_analysis", "loop", "branch", "export")) {
    out <- task$output %||% ""
    task$outputs <- if (nzchar(out)) {
      list(list(name = out, kind = "table", label = "Output table"))
    } else list()
  }
  prev_task <- isolate(store$tasks[[id]])
  if (is.null(prev_task) && id %in% names(store_all_tasks(store)))
    return(store_notify_dependency_problem(paste("Task identifier already belongs to another flow:", id)))
  fresh_run <- !is.null(task$run_time) && !identical(task$run_time, prev_task$run_time)
  if (fresh_run) {
    task$invalidated <- FALSE
    task$restoration_note <- NULL
    task$skip_reason <- NULL
    task$skipped_by <- NULL
    if (!identical(task$status, "error")) task$status <- "success"
  }
  prev_outs <- if (!is.null(prev_task)) task_output_names(prev_task) else character(0)
  new_outs  <- task_output_names(task)
  prev_controls <- prev_task$control_inputs %||% character(0)
  explicit_controls <- task$control_inputs
  control_tokens <- if (length(explicit_controls %||% prev_controls))
    isolate(store_available_control_tokens(store, task_id = id)) else character(0)
  task$control_inputs <- if (is.null(explicit_controls)) {
    intersect(prev_controls, control_tokens)
  } else {
    intersect(unique(explicit_controls), control_tokens)
  }
  task$inputs <- unique(c(task$inputs %||% character(0), task$control_inputs))

  tasks_new <- isolate(store$tasks)
  tasks_new[[id]] <- task
  order_new <- isolate(store$task_order)
  if (!id %in% order_new) order_new <- c(order_new, id)
  project_tasks <- store_all_tasks(store)
  project_tasks[[id]] <- task
  # Status, logs and ordinary parameter edits leave the graph unchanged. Cache
  # only its validated structure, never results or whole task/log records. Read
  # every current definition so direct assignments, Undo and flow changes also
  # invalidate this certificate.
  signature <- lapply(project_tasks, function(current) list(
    type = current$type,
    inputs = current$inputs %||% character(0),
    outputs = task_output_names(current),
    references = if (identical(current$type, "branch")) branch_references(current$params, "task_id") else
      if (identical(current$type, "export_log")) current$params$after_tasks %||% character(0) else character(0)))
  cache <- isolate(store$performance_cache)
  if (is.null(cache) || !identical(cache$validated_graph, signature)) {
    problem <- store_dependency_problem(project_tasks, names(project_tasks))
    if (!is.null(problem)) return(store_notify_dependency_problem(problem))
    if (!is.null(cache)) cache$validated_graph <- signature
  }

  # Remove old outputs when names change so stale tables/objects do not
  # accumulate in the flow.
  for (old in setdiff(prev_outs, new_outs)) store_remove_output(store, old)

  store$tasks <- tasks_new
  store$task_order <- order_new
  configuration <- c("type", "params", "inputs", "output", "outputs", "control_inputs")
  if (!is.null(prev_task) && !fresh_run &&
      !identical(prev_task[configuration], task[configuration])) {
    store_invalidate_outputs(store, prev_outs, include = id)
  }
  store$dirty <- TRUE
  store_add_history(store, "task", id,
    if (is.null(prev_task)) "create" else "update",
    sprintf("Task '%s' %s", id, if (is.null(prev_task)) "created" else "updated"),
    before = prev_task, after = task)
  invisible(id)
}

#' Remove a task from the active flow's live window.
#' @param store Session reactive store created by make_store().
#' @param id Identifier of the module, task, flow, or catalogue entry being addressed.
store_remove_task <- function(store, id) {
  ig_background_cancel(store, id, notify = FALSE, change_status = FALSE)
  store_close_connections(store, id)
  tasks <- isolate(store$tasks)
  prev_task <- tasks[[id]]
  tasks[[id]] <- NULL
  store$tasks     <- tasks
  store$task_order <- setdiff(store$task_order, id)
  # Drop the registered runner too — a stale closure would otherwise keep the
  # deleted module alive and could be invoked by a queued Run Flow.
  rnrs <- isolate(store$task_runners)
  if (!is.null(rnrs[[id]])) {
    rnrs[[id]] <- NULL
    store$task_runners <- rnrs
  }
  fns <- isolate(store$code_fns)
  if (!is.null(fns[[id]])) {
    fns[[id]] <- NULL
    store$code_fns <- fns
  }
  params <- isolate(store$params_fns)
  params[[id]] <- NULL
  store$params_fns <- params
  callbacks <- isolate(store$result_fns)
  callbacks[[id]] <- NULL
  store$result_fns <- callbacks
  store$dirty <- TRUE
  if (!is.null(prev_task)) store_add_history(store, "task", id, "delete",
    sprintf("Task '%s' deleted", id), before = prev_task)
  invisible(NULL)
}

#' Close lazy import connections owned by this session or one task.
#' @keywords internal
#' @param store Session reactive store created by make_store().
#' @param task_id Task identifier; NULL when no stored task is being edited.
store_close_connections <- function(store, task_id = NULL) {
  connections <- isolate(store$db_connections) %||% list()
  ids <- if (is.null(task_id)) names(connections) else intersect(task_id, names(connections))
  for (id in ids) {
    con <- connections[[id]]
    tryCatch({
      if (DBI::dbIsValid(con)) DBI::dbDisconnect(con)
    }, error = function(e) warning("Could not close database connection: ", conditionMessage(e)))
    connections[[id]] <- NULL
  }
  store$db_connections <- connections
  invisible(NULL)
}

#' Transfer ownership of a successful lazy import to the session store.
#' @keywords internal
#' @param store Session reactive store created by make_store().
#' @param task_id Task identifier; NULL when no stored task is being edited.
#' @param connection DBI connection whose lifetime transfers to the session store.
store_register_connection <- function(store, task_id, connection) {
  store_close_connections(store, task_id)
  if (!is.null(connection)) {
    connections <- isolate(store$db_connections) %||% list()
    connections[[task_id]] <- connection
    store$db_connections <- connections
  }
  invisible(NULL)
}

store_apply_branch_decision <- function(store, branch_id) {
  tasks <- isolate(store$tasks)
  branch <- tasks[[branch_id]]
  decision <- branch$branch_decision
  if (is.null(branch) || is.null(decision)) return(invisible(character(0)))

  active_tokens <- decision$matched_tokens %||% character(0)
  inactive_tokens <- decision$skipped_tokens %||% character(0)
  store$branch_tokens <- unique(c(setdiff(isolate(store$branch_tokens), inactive_tokens), active_tokens))
  if (!length(inactive_tokens)) return(invisible(character(0)))

  out_to_tid <- store_task_output_owner(tasks)
  fwd <- setNames(vector("list", length(tasks)), names(tasks))
  for (tid in names(tasks)) {
    for (producer in store_task_dependency_ids(tasks[[tid]], tasks, out_to_tid)) {
      if (!is.null(producer) && producer %in% names(tasks) &&
          !identical(producer, tid)) {
        fwd[[producer]] <- unique(c(fwd[[producer]], tid))
      }
    }
  }

  roots <- names(Filter(function(task) {
    ins <- task$inputs %||% character(0)
    length(intersect(ins, inactive_tokens)) > 0L &&
      length(intersect(ins, active_tokens)) == 0L
  }, tasks))

  skipped <- character(0)
  queue <- roots
  while (length(queue)) {
    tid <- queue[1]; queue <- queue[-1]
    if (tid %in% skipped || identical(tid, branch_id)) next
    ins <- tasks[[tid]]$inputs %||% character(0)
    if (length(intersect(ins, active_tokens)) > 0L) next
    skipped <- c(skipped, tid)
    queue <- c(queue, fwd[[tid]] %||% character(0))
  }

  if (!length(skipped)) return(invisible(character(0)))
  store_invalidate_outputs(store, character(0), include = skipped)
  tasks <- isolate(store$tasks)
  now <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  for (tid in skipped) {
    task <- tasks[[tid]]
    task$status <- "skipped"
    task$error_msg <- NULL
    task$run_time <- NULL
    task$skipped_by <- branch_id
    task$skip_reason <- paste("Inactive branch path from", branch_id)
    task$invalidated <- FALSE
    task$execution_log <- c(task$execution_log %||% list(), list(list(
      time = now,
      event = "skipped",
      branch = branch_id,
      inactive_tokens = inactive_tokens
    )))
    tasks[[tid]] <- task
  }
  store$tasks <- tasks
  store$run_queue <- setdiff(isolate(store$run_queue), skipped)
  for (tid in skipped) ig_task_logged(store, tid, function() invisible(FALSE))
  store$dirty <- TRUE
  invisible(skipped)
}

#' Topologically sort task IDs by their declared input→output dependencies.
#'
#' Builds a dependency graph from task$inputs (table names) → task$output
#' (table name), then applies Kahn's BFS algorithm so that every task runs
#' after the task(s) that produce its input tables.
#'
#' Falls back to the original `task_order` if a cycle is detected.
#'
#' @param tasks      Named list of task definition lists (from store$tasks).
#' @param task_order Character vector of task IDs to sort.
#' @return Character vector of task IDs in safe execution order.
store_topo_order <- function(tasks, task_order) {
  if (length(task_order) < 2L) return(task_order)
  problem <- store_dependency_problem(tasks, task_order)
  if (!is.null(problem)) {
    store_notify_dependency_problem(problem)
    return(task_order)
  }

  # Map every declared output → producing task_id
  out_to_tid <- store_task_output_owner(tasks)

  # Build dependency edges: tid → vector of prerequisite task_ids
  prereqs <- setNames(vector("list", length(task_order)), task_order)
  for (tid in task_order) {
    prereqs[[tid]] <- store_task_dependency_ids(tasks[[tid]], tasks, out_to_tid)
  }

  sorted <- store_dependency_order(prereqs, task_order)

  # If a cycle prevents full sort, return original order
  if (length(sorted) < length(task_order)) task_order else sorted
}

#' Generate a unique task id of the form "<type>_<n>" across ALL flows.
#' @param store Session reactive store created by make_store().
#' @param type Registered task type identifier.
store_next_id <- function(store, type) {
  # Collect existing IDs from active live window + all snapshotted flows
  existing <- names(isolate(store$tasks))
  for (fl in isolate(store$flows))
    existing <- union(existing, names(fl$tasks %||% list()))

  prefix  <- gsub("_", "", type)           # e.g. "querybuilder"
  pattern <- paste0("^", prefix, "_([0-9]+)$")
  nums    <- suppressWarnings(
    as.integer(sub(pattern, "\\1",
      grep(pattern, existing, value = TRUE))))
  n <- if (length(nums) && !all(is.na(nums))) max(nums, na.rm = TRUE) + 1L else 1L
  paste0(prefix, "_", n)
}

# ── Partial topo helpers (for Run from/to here) ───────────────────────────────

#' Topo-ordered subset from start_id (inclusive) to all downstream dependents.
#' @param tasks      Named list of task definitions.
#' @param task_order Character vector of all task IDs in this flow.
#' @param start_id   Task ID from which to start execution.
#' @return Character vector of task IDs in safe execution order.
store_topo_from <- function(tasks, task_order, start_id) {
  if (!start_id %in% task_order) return(character(0))
  sorted <- store_topo_order(tasks, task_order)

  # output → producing task
  out_to_tid <- list()
  for (tid in sorted)
    for (out in task_output_names(tasks[[tid]]))
      if (nzchar(out)) out_to_tid[[out]] <- tid

  # Forward edges: producer → consumers
  fwd <- setNames(vector("list", length(sorted)), sorted)
  for (tid in sorted)
    for (producer in store_task_dependency_ids(tasks[[tid]], tasks, out_to_tid)) {
      if (!is.null(producer) && producer %in% sorted)
        fwd[[producer]] <- unique(c(fwd[[producer]], tid))
    }

  # BFS from start_id
  visited <- character(0)
  queue   <- start_id
  while (length(queue) > 0L) {
    node <- queue[1]; queue <- queue[-1]
    if (node %in% visited) next
    visited <- c(visited, node)
    queue   <- c(queue, fwd[[node]])
  }
  sorted[sorted %in% visited]
}

#' Topo-ordered subset of tasks that end_id depends on (ancestors + end_id).
#' @param tasks      Named list of task definitions.
#' @param task_order Character vector of all task IDs in this flow.
#' @param end_id     Task ID at which to stop execution (inclusive).
#' @return Character vector of task IDs in safe execution order.
store_topo_to <- function(tasks, task_order, end_id) {
  if (!end_id %in% task_order) return(character(0))
  sorted <- store_topo_order(tasks, task_order)

  # output → producing task
  out_to_tid <- list()
  for (tid in sorted)
    for (out in task_output_names(tasks[[tid]]))
      if (nzchar(out)) out_to_tid[[out]] <- tid

  # BFS backwards from end_id (collect ancestors)
  visited <- character(0)
  queue   <- end_id
  while (length(queue) > 0L) {
    node <- queue[1]; queue <- queue[-1]
    if (node %in% visited) next
    visited <- c(visited, node)
    for (producer in store_task_dependency_ids(tasks[[node]], tasks, out_to_tid)) {
      if (!is.null(producer) && !producer %in% visited)
        queue <- c(queue, producer)
    }
  }
  sorted[sorted %in% visited]
}
