# Publish derived UI state only when its value changes. The lazy refresh also
# keeps callers in the same server event up to date before the observer runs.
ig_reactive_distinct <- function(read) {
  value <- shiny::reactiveVal(NULL)
  refresh <- shiny::reactive({
    next_value <- read()
    shiny::isolate(value(next_value))
    invisible(NULL)
  })
  observer <- shiny::observe(refresh(), priority = 200)
  read_value <- function() {
    shiny::isolate(refresh())
    value()
  }
  attr(read_value, "observer") <- observer
  read_value
}

# Settings and generated code do not affect workspace chrome. Preserve only
# branch task references needed by dependency helpers, not editable conditions.
ig_task_ui_snapshot <- function(tasks, choices = FALSE) {
  lapply(tasks, function(task) {
    task$control_inputs <- task$control_inputs %||% character(0)
    task$invalidated <- isTRUE(task$invalidated)
    snapshot <- if (choices) {
      task[intersect(names(task), c("id", "type", "inputs", "output", "outputs", "control_inputs"))]
    } else {
      task[setdiff(names(task), c("params", "r_code", "logging", "log_events"))]
    }
    if (identical(task$type, "branch")) {
      rules <- lapply(branch_references(task$params, "task_id"), function(id) list(task_id = id))
      snapshot$params <- list(paths = list(list(condition = list(rules = rules))))
    }
    if (identical(task$type, "export_log")) snapshot$params <- list(after_tasks = task$params$after_tasks)
    snapshot <- Filter(Negate(is.null), snapshot)
    snapshot[order(names(snapshot))]
  })
}

# Session-only readers are intentionally absent from make_store() and archives.
store_init_ui_reactivity <- function(store) {
  store$ui_readers <- list(
    table_names = ig_reactive_distinct(function() names(store$tables)),
    object_names = ig_reactive_distinct(function() names(store$objects)),
    # Graph cards display presence, dimensions and lazy-table status. Values
    # and column schemas belong to previews/editors and must not redraw cards.
    canvas_tables = ig_reactive_distinct(function() lapply(store$tables, function(table) {
      if (is.null(table)) return(NULL)
      if (inherits(table, "tbl_sql")) return(list(lazy = TRUE))
      list(dimensions = dim(table))
    })),
    tasks = ig_reactive_distinct(function() ig_task_ui_snapshot(store$tasks)),
    flows = ig_reactive_distinct(function() {
      active <- store$active_flow
      lapply(store$flows, function(flow) {
        snapshot <- flow[intersect(names(flow), c("id", "name", "task_order"))]
        # The active flow's tree uses live tasks/order. Save also writes a
        # duplicate snapshot; publishing it would redraw the tree at autosave.
        if (identical(flow$id, active)) {
          snapshot$task_order <- character(0)
          snapshot$tasks <- list()
        } else snapshot$tasks <- ig_task_ui_snapshot(flow$tasks %||% list())
        snapshot
      })
    }),
    choices = ig_reactive_distinct(function() ig_task_ui_snapshot(store_all_tasks(store, track = TRUE), choices = TRUE)),
    comments = ig_reactive_distinct(function() store$collaboration$comments %||% list()),
    review = ig_reactive_distinct(function() ig_normalize_collaboration(store$collaboration)$review)
  )
  invisible(NULL)
}

store_ui_read <- function(store, key, fallback) {
  read <- shiny::isolate(store$ui_readers[[key]])
  if (is.function(read)) read() else fallback
}

store_choice_tasks <- function(store) {
  store_ui_read(store, "choices", store_all_tasks(store, track = TRUE))
}
