# app_server.R — Top-level server for Individual Guide.
#
# Multiple process flows
# ──────────────────────
# Each project holds N flows.  Switching flows snapshots the active flow's tasks
# back into store$flows, then loads the target flow's tasks into the live
# store$tasks / store$task_order window.  All dynamic task panels are removed
# from the DOM on flow switch and re-inserted lazily when reopened.

app_server <- function(input, output, session) {
  token <- Sys.getenv("IG_DESKTOP_TOKEN", "")
  if (nzchar(token) && !identical(session$request$HTTP_X_IG_DESKTOP_TOKEN, token)) {
    session$close()
    return(invisible(NULL))
  }

  # ── Shared store ─────────────────────────────────────────────────────────────
  store <- make_store()
  store_init_ui_reactivity(store)
  store_init_background(store, session)
  startup_ready <- reactiveVal(FALSE)
  recovery_pending <- reactiveVal(file.exists(project_recovery_path()))
  workspace_welcome <- reactiveVal(TRUE)
  ig_shiny_apps_server(input, session)
  observeEvent(input$app_host_open, {
    if (isTRUE(isolate(recovery_pending()))) return()
    if (isTRUE(isolate(workspace_welcome()))) {
      workspace_welcome(FALSE)
      removeModal()
    }
  })
  session$onSessionEnded(function() {
    store_close_connections(store)
    project_release_assets(store)
  })

  # Initialise with one default flow
  local({
    fl           <- make_flow("Flow 1")
    store$flows      <- setNames(list(fl), fl$id)
    store$active_flow <- fl$id
  })

  # ── Tab state ─────────────────────────────────────────────────────────────────
  PERMANENT_TABS <- c("flow", "code", "console")

  tabs_rv <- reactiveValues(
    open   = PERMANENT_TABS,
    active = "flow"
  )
  theme_mode <- reactiveVal("dark")

  # Bulk-select set for the sidebar tree (task ids checked for bulk actions).
  # Server-side so it survives renderUI cycles; cleared on flow switch.
  selected_tasks <- reactiveVal(character(0))

  inserted_panels    <- character(0)   # task panels inserted into DOM
  initialised_modules <- character(0)  # module servers already started
  panel_observers    <- character(0)   # panels whose header observers exist
  panel_observer_handles <- list()
  preview_table_name <- reactiveVal(NULL)
  preview_object_name <- reactiveVal(NULL)
  preview_trigger    <- reactiveVal(0L)  # incremented each time preview opens

  structural_edit_blocked <- function(action) {
    if (review_edit_blocked(action)) return(TRUE)
    if (!length(isolate(store$run_ids))) return(FALSE)
    showNotification("Wait for the running flow to finish, or cancel its database connection prompt.", type = "warning")
    TRUE
  }

  dispose_task_panel <- function(tid) {
    ig_end_task_modules(session, tid)
    for (observer in panel_observer_handles[[tid]]) observer$destroy()
    panel_observer_handles[[tid]] <<- NULL
    panel_observers <<- setdiff(panel_observers, tid)
    if (tid %in% inserted_panels) removeUI(selector = paste0("#panel_", tid), immediate = TRUE)
    inserted_panels <<- setdiff(inserted_panels, tid)
    initialised_modules <<- initialised_modules[!endsWith(initialised_modules, paste0("_", tid))]
    tabs_rv$open <- setdiff(isolate(tabs_rv$open), tid)
  }

  # ── Flow switch helper ────────────────────────────────────────────────────────
  # Clears all dynamic task tabs/panels then activates the target flow.
  switch_flow <- function(flow_id) {
    if (!identical(flow_id, isolate(store$active_flow)) && length(isolate(store$run_ids))) {
      showNotification("Wait for the running flow to finish, or cancel its database connection prompt.", type = "warning")
      return(invisible(FALSE))
    }
    store_sync_parameters(store)
    # Bulk selection is scoped to one flow — drop it when leaving.
    selected_tasks(character(0))
    # Retain open panels and their inputs for a return to this flow. Only the
    # current flow's tabs are visible; modules ignore settings for absent tasks.

    # Drop task tabs from tab strip; keep permanent ones
    keep        <- intersect(isolate(tabs_rv$open), PERMANENT_TABS)
    tabs_rv$open <- keep
    if (!isolate(tabs_rv$active) %in% keep) {
      tabs_rv$active <- "flow"
      session$sendCustomMessage("ig_switch_tab", "flow")
    }

    # Activate the new flow in the store
    store_activate_flow(store, flow_id)

    # Show the flow visualizer after changing active flows.
    open_task_panel("flow", focus_tab = TRUE)
  }

  # ── Project tree renderUI ─────────────────────────────────────────────────────
  output$project_tree_ui <- renderUI({
    # Reactive dependencies (touching each one ensures re-render on any change)
    sources    <- store$sources
    table_names <- store_ui_read(store, "table_names", names(store$tables))
    object_names <- store_ui_read(store, "object_names", names(store$objects))
    flows      <- store_ui_read(store, "flows", store$flows)
    active_fid <- store$active_flow
    task_order <- store$task_order    # live window for the active flow
    tasks      <- store_ui_read(store, "tasks", store$tasks)
    proj_name  <- store$project_name   # set by project_save / project_load / save-as
    active_tab <- tabs_rv$active       # highlight the open task in the tree
    sel_tasks  <- selected_tasks()     # bulk-select checkbox state

    # ── Data Sources ────────────────────────────────────────────────────────
    src_icon <- function(type) switch(type %||% "",
      csv      = "file-csv",
      xlsx = , xls = "file-excel",
      rds  = , rda = "cube",
      "file"
    )

    src_items <- lapply(names(sources), function(nm) {
      div(class = "ig-tree-item ig-key-activate",
        role = "button", tabindex = "0",
        onclick = ig_input_event_js("tree_src_click", nm),
        tags$span(class = "ig-tree-icon",
          icon(src_icon(sources[[nm]]$type))),
        tags$span(class = "ig-tree-label", title = nm, nm),
        tags$button(
          class   = "ig-tree-action-btn ig-tree-action-danger",
          title   = paste("Remove", nm),
          `aria-label` = paste("Remove", nm),
          onclick = ig_input_event_js("tree_rm_src", nm, stop_propagation = TRUE),
          icon("xmark")
        )
      )
    })

    # ── Cross-flow dependency map ───────────────────────────────────────────
    # output_name → flow_id that produces it
    output_owner <- local({
      om <- list()
      for (fid in names(flows)) {
        fl_t <- if (identical(fid, active_fid)) tasks else flows[[fid]]$tasks %||% list()
        for (tid in names(fl_t)) {
          for (out in task_output_names(fl_t[[tid]])) {
            if (nzchar(out)) om[[out]] <- fid
          }
        }
      }
      om
    })
    # flow_id → character vector of flow_ids it depends on
    flow_dep_map <- setNames(lapply(names(flows), function(fid) {
      fl_t <- if (identical(fid, active_fid)) tasks else flows[[fid]]$tasks %||% list()
      deps <- character(0)
      for (tid in names(fl_t))
        for (inp in fl_t[[tid]]$inputs %||% character(0)) {
          owner <- output_owner[[inp]]
          if (!is.null(owner) && !identical(owner, fid))
            deps <- union(deps, owner)
        }
      deps
    }), names(flows))

    # ── Process Flows ───────────────────────────────────────────────────────
    flow_items <- lapply(names(flows), function(fid) {
      fl        <- flows[[fid]]
      is_active <- identical(fid, active_fid)

      # Use live window for active flow; snapshot for others
      fl_order <- if (is_active) task_order         else fl$task_order %||% character(0)
      fl_tasks <- if (is_active) tasks              else fl$tasks      %||% list()

      table_row <- function(tbl, role = "dataset") {
        is_imported <- tbl %in% names(sources)
        has_data    <- tbl %in% table_names
        div(class = paste("ig-tree-item ig-tree-dataset-item ig-key-activate",
                          if (!is_imported) "ig-tree-derived-item"),
          role = "button", tabindex = "0",
          onclick = ig_input_event_js("tree_dataset_click", tbl),
          tags$span(class = "ig-tree-icon",
            icon(if (is_imported) src_icon(sources[[tbl]]$type) else "table")),
          tags$span(class = "ig-tree-label", title = tbl, tbl),
          tags$span(class = "ig-tree-node-role",
            if (is_imported) "imported" else role),
          # Export icon — only shown when the table has data
          if (has_data)
            tags$button(
              class   = "ig-tree-action-btn",
              title   = paste("Export", tbl),
              `aria-label` = paste("Export", tbl),
              onclick = ig_input_event_js("tree_export_click", tbl, stop_propagation = TRUE),
              icon("download")
            )
        )
      }

      object_row <- function(obj, role = "object") {
        has_obj <- obj %in% object_names
        div(class = "ig-tree-item ig-tree-dataset-item ig-tree-derived-item ig-key-activate",
          role = "button", tabindex = "0",
          onclick = ig_input_event_js("tree_object_click", obj),
          tags$span(class = "ig-tree-icon", icon("cube")),
          tags$span(class = "ig-tree-label", title = obj, obj),
          tags$span(class = "ig-tree-node-role", if (has_obj) role else "pending")
        )
      }

      flow_outputs <- unique(Filter(nzchar,
        unlist(lapply(fl_tasks, function(t) task_output_names(t, kinds = "table")))))
      flow_datasets <- unique(c(table_names, flow_outputs))
      flow_objects <- unique(Filter(nzchar,
        unlist(lapply(fl_tasks, function(t)
          task_output_names(t, kinds = c("model", "plot", "image", "object"))))))

      task_blocks <- Filter(Negate(is.null), lapply(fl_order, function(tid) {
        t <- fl_tasks[[tid]]
        if (is.null(t)) return(NULL)
        info <- task_type_info(t$type)

        # An input may be a table or a special-output object (model/plot/etc.) —
        # render with the matching row style so its icon/kind reads correctly.
        input_rows <- Filter(Negate(is.null), lapply(t$inputs %||% character(0), function(inp) {
          if (!nzchar(inp)) return(NULL)
          if (inp %in% flow_objects) object_row(inp, "input") else table_row(inp, "input")
        }))

        output_rows <- lapply(task_output_specs(t), function(out) {
          kind <- out$kind %||% "table"
          if (identical(kind, "table")) table_row(out$name, "derived") else object_row(out$name, kind)
        })

        has_edges <- length(input_rows) > 0L || length(output_rows) > 0L

        div(class = paste("ig-tree-task-block",
                          if (identical(tid, active_tab)) "ig-tree-task-block-open"),
          `data-collapse-key` = paste0("tblock_", tid),
          div(class = paste("ig-tree-item ig-tree-task-item ig-key-activate",
                            if (identical(tid, active_tab)) "ig-tree-task-open"),
            role = "button", tabindex = "0",
            `aria-current` = if (identical(tid, active_tab)) "true" else NULL,
            onclick = ig_input_event_js("tree_task_click", tid),
            tags$input(
              type = "checkbox", class = "ig-tree-task-check",
              checked = if (tid %in% sel_tasks) "checked" else NULL,
              title = "Select for bulk actions",
              `aria-label` = paste("Select task", tid, "for bulk actions"),
              onclick = ig_input_event_js("tree_task_toggle_select", tid, stop_propagation = TRUE)
            ),
            if (has_edges)
              tags$button(
                class   = "ig-tree-caret-btn",
                type    = "button",
                title   = "Expand / collapse inputs and outputs",
                `aria-label` = "Toggle task inputs and outputs",
                `aria-expanded` = "true",
                onclick = sprintf(
                  "event.stopPropagation();igToggleCollapse('tblock_%s')", tid),
                tags$span(class = "ig-tree-caret", icon("chevron-down"))
              ),
            tags$span(class = "ig-tree-icon", icon(info$icon %||% "circle")),
            local({
              disp <- trimws(t$label %||% "")
              disp <- if (nzchar(disp)) disp else (info$label %||% t$type)
              tags$span(class = "ig-tree-label", title = disp, disp)
            }),
            tags$span(class = "ig-tree-task-id", title = tid, tid),
            tags$button(
              class = "ig-tree-action-btn",
              title = paste("Rename", tid),
              `aria-label` = paste("Rename", tid),
              onclick = ig_input_event_js("tree_rename_task", tid, stop_propagation = TRUE),
              icon("pen")
            ),
            tags$button(
              class = "ig-tree-action-btn ig-tree-action-danger",
              title = paste("Delete", tid),
              `aria-label` = paste("Delete", tid),
              onclick = ig_input_event_js("tree_delete_task", tid, stop_propagation = TRUE),
              icon("trash")
            )
          ),
          if (length(input_rows) > 0L)
            div(class = "ig-tree-io-group ig-tree-io-inputs",
              div(class = "ig-tree-io-caption", icon("arrow-right-to-bracket"), "Uses"),
              div(class = "ig-tree-edge-list", input_rows)
            ),
          if (length(output_rows) > 0L)
            div(class = "ig-tree-io-group ig-tree-io-outputs",
              div(class = "ig-tree-io-caption", icon("arrow-right-from-bracket"), "Creates"),
              div(class = "ig-tree-edge-list", output_rows)
            )
        )
      }))

      dataset_rows <- lapply(flow_datasets, table_row)
      object_rows <- lapply(flow_objects, object_row)

      div(class = paste("ig-tree-flow", if (is_active) "ig-tree-flow-active"),
        `data-collapse-key` = fid,
        # Flow header row
        div(class = "ig-tree-flow-header",
          onclick = ig_input_event_js("tree_flow_click", fid),
          tags$button(
            class   = "ig-tree-caret-btn",
            type    = "button",
            title   = "Expand / collapse",
            `aria-label` = paste("Toggle flow", fl$name %||% fid),
            `aria-expanded` = "true",
            onclick = sprintf(
              "event.stopPropagation();igToggleCollapse('%s')", fid),
            tags$span(class = "ig-tree-caret", icon("chevron-down"))
          ),
          tags$span(class = "ig-tree-icon", icon("sitemap")),
          tags$button(type = "button", class = "ig-tree-label ig-tree-select-flow", title = fl$name %||% fid,
            `aria-label` = paste("Select flow", fl$name %||% fid),
            onclick = ig_input_event_js("tree_flow_click", fid, stop_propagation = TRUE), fl$name %||% fid),
          if (is_active) tags$span(class = "ig-tree-badge", "active"),
          div(class = "ig-tree-flow-btns",
            tags$button(class = "ig-tree-action-btn ig-tree-run-btn",
              title = "Run all tasks in this flow",
              `aria-label` = paste("Run flow", fl$name %||% fid),
              onclick = ig_input_event_js("tree_run_flow", fid, stop_propagation = TRUE),
              icon("play")),
            tags$button(class = "ig-tree-action-btn", title = "Copy flow",
              `aria-label` = paste("Copy flow", fl$name %||% fid),
              onclick = ig_input_event_js("tree_copy_flow", fid, stop_propagation = TRUE),
              icon("copy")),
            tags$button(class = "ig-tree-action-btn", title = "Rename",
              `aria-label` = paste("Rename flow", fl$name %||% fid),
              onclick = ig_input_event_js("tree_rename_flow", fid, stop_propagation = TRUE),
              icon("pen")),
            if (length(names(flows)) > 1L)
              tags$button(
                class   = "ig-tree-action-btn ig-tree-action-danger",
                title   = "Delete flow",
                `aria-label` = paste("Delete flow", fl$name %||% fid),
                onclick = ig_input_event_js("tree_delete_flow", fid, stop_propagation = TRUE),
                icon("trash"))
          )
        ),
        # Cross-flow dependency indicator
        if (length(flow_dep_map[[fid]]) > 0L) {
          dep_names <- vapply(flow_dep_map[[fid]], function(df_id)
            flows[[df_id]]$name %||% df_id, character(1))
          div(class = "ig-tree-flow-dep-bar",
            icon("arrow-right-long"),
            " depends on ", tags$strong(paste(dep_names, collapse = ", "))
          )
        },
        # Issues panel — actionable problems (errors, stale, dependency) for the
        # active flow only. Clicking a task-scoped issue opens that task.
        local({
          issues <- if (is_active) flow_issues(store) else list()
          if (length(issues) == 0L) return(NULL)
          n_err  <- sum(vapply(issues, function(i) i$kind == "error", logical(1)))
          issue_rows <- lapply(issues, function(iss) {
            sev_icon <- switch(iss$kind,
              error = "circle-xmark", stale = "triangle-exclamation",
              dependency = "link-slash", "circle-info")
            clickable <- !is.null(iss$task_id)
            div(
              class = paste("ig-tree-item ig-tree-issue-row",
                            paste0("ig-tree-issue-", iss$kind),
                            if (clickable) "ig-key-activate"),
              role = if (clickable) "button" else NULL,
              tabindex = if (clickable) "0" else NULL,
              title = iss$message,
              onclick = if (clickable) ig_input_event_js("tree_task_click", iss$task_id) else NULL,
              tags$span(class = "ig-tree-icon", icon(sev_icon)),
              tags$span(class = "ig-tree-label", title = iss$label, iss$label),
              tags$span(class = "ig-tree-issue-msg", title = iss$message, iss$message)
            )
          })
          div(class = "ig-tree-node-group ig-tree-issues-group",
            `data-collapse-key` = paste0(fid, "_issues"),
            div(class = "ig-tree-node-group-title ig-key-activate",
              `data-collapsible` = "1",
              role = "button", tabindex = "0", `aria-expanded` = "true",
              onclick = sprintf("igToggleCollapse('%s')", paste0(fid, "_issues")),
              tags$span(class = "ig-tree-caret", icon("chevron-down")),
              icon("triangle-exclamation"), " Issues",
              tags$span(class = "ig-tree-issue-count",
                title = sprintf("%d issue%s%s", length(issues),
                  if (length(issues) == 1L) "" else "s",
                  if (n_err > 0L) sprintf(", %d error%s", n_err,
                    if (n_err == 1L) "" else "s") else ""),
                as.character(length(issues)))
            ),
            div(class = "ig-tree-task-list", issue_rows)
          )
        }),
        # Nodes nested under this flow, mirroring the canvas contents.
        if (length(dataset_rows) > 0L)
          div(class = "ig-tree-node-group",
            `data-collapse-key` = paste0(fid, "_ds"),
            div(class = "ig-tree-node-group-title ig-key-activate",
              `data-collapsible` = "1",
              role = "button", tabindex = "0", `aria-expanded` = "true",
              onclick = sprintf("igToggleCollapse('%s')", paste0(fid, "_ds")),
              tags$span(class = "ig-tree-caret", icon("chevron-down")),
              icon("database"), " Datasets"
            ),
            div(class = "ig-tree-task-list", dataset_rows)
          ),
        if (length(object_rows) > 0L)
          div(class = "ig-tree-node-group",
            `data-collapse-key` = paste0(fid, "_obj"),
            div(class = "ig-tree-node-group-title ig-key-activate",
              `data-collapsible` = "1",
              role = "button", tabindex = "0", `aria-expanded` = "true",
              onclick = sprintf("igToggleCollapse('%s')", paste0(fid, "_obj")),
              tags$span(class = "ig-tree-caret", icon("chevron-down")),
              icon("cube"), " Special Outputs"
            ),
            div(class = "ig-tree-task-list", object_rows)
          ),
        if (length(task_blocks) > 0L)
          div(class = "ig-tree-node-group",
            `data-collapse-key` = paste0(fid, "_steps"),
            div(class = "ig-tree-node-group-title ig-key-activate",
              `data-collapsible` = "1",
              role = "button", tabindex = "0", `aria-expanded` = "true",
              onclick = sprintf("igToggleCollapse('%s')", paste0(fid, "_steps")),
              tags$span(class = "ig-tree-caret", icon("chevron-down")),
              icon("diagram-project"), " Steps"
            ),
            # Bulk-action bar — appears for the active flow once tasks are checked
            local({
              sel_here <- intersect(sel_tasks, names(fl_tasks))
              if (!is_active || length(sel_here) == 0L) return(NULL)
              div(class = "ig-tree-bulk-bar",
                tags$span(class = "ig-tree-bulk-count",
                  sprintf("%d selected", length(sel_here))),
                tags$button(class = "btn btn-xs btn-outline-secondary ig-tree-bulk-btn",
                  type = "button",
                  onclick = "Shiny.setInputValue('tree_bulk_clear_sel',Math.random(),{priority:'event'})",
                  "Clear"),
                tags$button(class = "btn btn-xs btn-danger ig-tree-bulk-btn",
                  type = "button",
                  onclick = "Shiny.setInputValue('tree_bulk_delete',Math.random(),{priority:'event'})",
                  icon("trash"), " Delete")
              )
            }),
            div(class = "ig-tree-task-list", task_blocks)
          )
        else if (is_active)
          div(class = "ig-tree-empty-tasks",
            icon("circle-info"), " Use Add Task to build this flow")
      )
    })

    tagList(
      # Project name header
      div(class = "ig-tree-project-name",
        div(class = "ig-tree-project-title",
          icon("folder-open"), strong(proj_name)),
        div(class = "ig-tree-project-subtitle",
          sprintf("%d data source%s \u00b7 %d flow%s",
            length(sources), if (length(sources) != 1) "s" else "",
            length(flows), if (length(flows) != 1) "s" else ""))
      ),

      # Data Sources section
      div(class = "ig-tree-section",
        div(class = "ig-tree-section-header",
          tags$span("Data Sources"),
          tags$button(class = "ig-tree-add-btn", title = "Import data source",
            `aria-label` = "Import data source",
            onclick = "Shiny.setInputValue('tree_add_src_click',Math.random(),{priority:'event'})",
            icon("plus"))
        ),
        if (length(src_items) > 0L)
          div(class = "ig-tree-items", src_items)
        else
          div(class = "ig-tree-empty", icon("circle-info"), " No data sources")
      ),

      # Process Flows section
      div(class = "ig-tree-section",
        div(class = "ig-tree-section-header",
          tags$span("Process Flows"),
          tags$button(class = "ig-tree-add-btn", title = "Add new flow",
            `aria-label` = "Add new flow",
            onclick = "Shiny.setInputValue('tree_add_flow_click',Math.random(),{priority:'event'})",
            icon("plus"))
        ),
        div(class = "ig-tree-flows", flow_items)
      )
    )
  })

  # ── Project tree click handlers ───────────────────────────────────────────────

  # Data source clicks
  observeEvent(input$tree_src_click, {
    nm <- input$tree_src_click
    meta <- isolate(store$sources[[nm]])
    if (!is.null(meta$task_id)) {
      open_task_by_id(meta$task_id)
    } else {
      show_dataset_preview(nm)   # show_dataset_preview sets preview_table_name internally
    }
  })
  observeEvent(input$tree_add_src_click, { create_task("import_data") })
  observeEvent(input$tree_rm_src, {
    if (structural_edit_blocked("remove data sources")) return()
    nm <- input$tree_rm_src
    capture_undo(sprintf("Removed data source '%s'.", nm))
    store_remove_table(store, nm)
    offer_undo(sprintf("Removed data source '%s'.", nm))
  })

  observeEvent(input$tree_dataset_click, {
    node <- input$tree_dataset_click
    if (node %in% names(isolate(store$sources))) {
      meta <- isolate(store$sources[[node]])
      if (!is.null(meta$task_id)) open_task_by_id(meta$task_id)
      else show_dataset_preview(node)
    } else if (node %in% store_table_names(store)) {
      show_dataset_preview(node)
    }
  })

  observeEvent(input$tree_object_click, {
    show_object_preview(input$tree_object_click)
  })

  # Export icon click in the tree — open the preview (which has download controls)
  observeEvent(input$tree_export_click, {
    show_dataset_preview(input$tree_export_click)
  })

  # Task clicks — may need to switch flow first
  observeEvent(input$tree_task_click, {
    open_task_by_id(input$tree_task_click)
  })

  # Flow clicks — switch to flow and show canvas
  observeEvent(input$tree_flow_click, {
    fid <- input$tree_flow_click
    if (!identical(fid, isolate(store$active_flow)))
      switch_flow(fid)
    else
      open_task_panel("flow", focus_tab = TRUE)
  })

  # ── Run Flow ──────────────────────────────────────────────────────────────────
  # Shared queue starter for Run Flow / Run from here / Run to here / shortcut.
  start_run_queue <- function(run_ids, label = "") {
    if (review_edit_blocked("run tasks")) return(invisible(NULL))
    if (!is.null(isolate(store$background$job))) {
      showNotification("Wait for the current analysis before starting a flow.", type = "message")
      return(invisible(NULL))
    }
    if (length(isolate(store$run_ids))) {
      showNotification("A flow is already running.", type = "warning")
      return(invisible(NULL))
    }
    problem <- store_dependency_problem(isolate(store$tasks), isolate(store$task_order))
    if (!is.null(problem)) {
      showNotification(problem, type = "error", duration = 8)
      return(invisible(NULL))
    }
    if (length(run_ids) == 0L) {
      showNotification("No tasks to run.", type = "message", duration = 3)
      return(invisible(NULL))
    }
    store_sync_parameters(store)
    validation <- ig_preflight(store, run_ids)
    if (any(validation$severity == "error")) {
      showModal(ig_preflight_ui(validation, "Fix these problems before running"))
      return(invisible(NULL))
    }
    showNotification(sprintf("Running %d task(s)%s\u2026", length(run_ids), label),
                     id = "run_flow_notice", type = "message", duration = NA)
    store$run_ids         <- run_ids
    store$run_queue       <- run_ids
    store$run_generation  <- isolate(store$run_generation) + 1L
    store$run_current     <- NULL
    store$run_started     <- Sys.time()
    store$run_total       <- length(run_ids)
    store$run_completed   <- 0L
    store$run_outcome     <- "running"
    store$run_task_done_n <- isolate(store$run_task_done_n) + 1L
    invisible(NULL)
  }

  # "Run Flow" button in the sidebar: activate the flow, then execute each task
  # in dependency order (topo-sort on task$inputs → task$output edges).
  run_whole_flow <- function(fid) {
    if (length(isolate(store$run_ids))) {
      showNotification("A flow is already running.", type = "warning")
      return(invisible(NULL))
    }
    if (!identical(fid, isolate(store$active_flow)))
      switch_flow(fid)
    store_sync_parameters(store)
    ord <- isolate(store$task_order)
    if (length(ord) == 0L) {
      showNotification("No tasks to run in this flow.", type = "message", duration = 3)
      return(invisible(NULL))
    }
    # Sort by declared dependencies so producers always run before consumers
    tasks_snap <- isolate(store$tasks)
    start_run_queue(store_topo_order(tasks_snap, ord))
  }

  observeEvent(input$tree_run_flow, { run_whole_flow(input$tree_run_flow) })

  # Ctrl+Alt+R — run the active flow from anywhere
  observeEvent(input$shortcut_run_flow, {
    run_whole_flow(isolate(store$active_flow))
  })

  observe({ session$sendCustomMessage("ig_run_state", store_run_state(store)) })
  observeEvent(input$stop_run, {
    waiting <- isolate(store$run_waiting)
    password <- !is.null(waiting) && is.null(isolate(store$background$job))
    if (isTRUE(store_stop_run(store))) {
      if (password) removeModal()
      removeNotification("run_flow_notice")
      showNotification("Run stopped. Remaining tasks were not run.", type = "message")
    }
  }, priority = 300)

  advance_run <- function() {
    generation <- isolate(store$run_generation)
    # Yield to the browser and pending Stop input between synchronous tasks.
    session$onFlushed(function() later::later(function() {
      if (isTRUE(session$isClosed())) return()
      isolate({
        if (identical(store$run_generation, generation) && length(store$run_ids))
          store$run_task_done_n <- store$run_task_done_n + 1L
      })
    }, delay = 0.08), once = TRUE)
  }

  # Queue processor — advances one task per reactive cycle.
  # Priority: registered runner (live module) → run_task_from_store (stored params).
  observeEvent(store$run_task_done_n, {
    queue <- isolate(store$run_queue)
    if (!is.null(isolate(store$run_waiting))) return()
    resumed <- isolate(store$run_resumed)
    if (length(queue) == 0L && is.null(resumed)) {
      removeNotification("run_flow_notice")
      # Summarise the finished run: which of the queued tasks now carry errors
      ran <- isolate(store$run_ids)
      if (length(ran)) {
        store$run_ids <- character(0)
        store$run_current <- NULL
        tasks_now <- isolate(store$tasks)
        failed <- Filter(function(tid) !is.null(tasks_now[[tid]]$error_msg), ran)
        succeeded <- Filter(function(tid) identical(tasks_now[[tid]]$status, "success"), ran)
        skipped <- setdiff(ran, c(failed, succeeded))
        store$run_outcome <- if (length(failed)) "failed" else "finished"
        if (length(failed)) {
          showNotification(
            sprintf("Flow finished: %d succeeded, %d failed, %d skipped \u2014 %s",
                    length(succeeded), length(failed), length(skipped),
                    paste(failed, collapse = ", ")),
            type = "warning", duration = 10)
        } else {
          showNotification(
            sprintf("Flow finished: %d succeeded, %d skipped.", length(succeeded), length(skipped)),
            type = "message", duration = 5)
        }
      }
      return()
    }
    tid <- resumed %||% queue[[1L]]
    if (is.null(resumed) && !identical(isolate(store$run_current), tid)) {
      store$run_current <- tid
      advance_run()
      return()
    }
    task_to_run <- isolate(store$tasks[[tid]])
    runner          <- isolate(store$task_runners)[[tid]]
    if (is.null(resumed) && identical(task_to_run$type, "import_data") &&
        ig_import_needs_password(task_to_run$params)) {
      reader <- isolate(store$params_fns[[tid]])
      if (is.null(reader) || is.null(reader())) {
        open_task_panel(tid, focus_tab = TRUE)
        return() # The module-ready acknowledgement advances this queue.
      }
    }
    if (is.null(resumed)) store$run_queue <- queue[-1L] else store$run_resumed <- NULL
    if (identical(task_to_run$type, "loop")) runner <- NULL

    run_result <- NULL
    if (!is.null(resumed)) {
      # The password modal already executed this task; process its final status.
    } else if (!is.null(runner)) {
      # Panel has been opened — use the live registered runner
      run_result <- tryCatch(
        runner(),
        shiny.silent.error = function(e) {
          store_task_failed(store, tid, "Required inputs are not set.")
          showNotification(sprintf("'%s': required inputs not set.", tid),
                           type = "warning", duration = 5)
        },
        error = function(e) {
          store_task_failed(store, tid, conditionMessage(e))
          showNotification(sprintf("'%s' failed: %s", tid, conditionMessage(e)),
                           type = "error", duration = 10)
        }
      )
    } else {
      # Panel not opened yet — execute from stored params (no panel required)
      run_result <- run_task_from_store(store, tid)
    }
    if (inherits(run_result, "ig_pending_task") || inherits(run_result, "ig_async_task")) {
      store$run_waiting <- tid
      return()
    }

    just_ran_task <- isolate(store$tasks[[tid]])
    if (identical(just_ran_task$type, "loop"))
      store$run_queue <- setdiff(isolate(store$run_queue), just_ran_task$loop_body_ids %||% character(0))
    if (is.null(runner) &&
        identical(just_ran_task$type %||% "", "branch") &&
        identical(just_ran_task$status %||% "", "success")) {
      skipped_by_branch <- store_apply_branch_decision(store, tid)
      if (length(skipped_by_branch)) {
        showNotification(
          sprintf("Branch '%s' skipped: %s",
                  tid, paste(skipped_by_branch, collapse = ", ")),
          type = "message", duration = 5)
      }
    }

    # Optional fail-fast: abandon the rest of the queue when this task errored
    if (isTRUE((isolate(store$settings) %||% list())$stop_on_error)) {
      just_ran <- isolate(store$tasks[[tid]])
      if (!is.null(just_ran$error_msg) &&
          length(isolate(store$run_queue)) > 0L) {
        skipped <- isolate(store$run_queue)
        store$run_queue <- character(0)
        for (id in skipped) store_task_skipped(store, id, paste("Stopped after failure of", tid))
        showNotification(
          sprintf("'%s' failed \u2014 stopped the run. Skipped: %s",
                  tid, paste(skipped, collapse = ", ")),
          type = "warning", duration = 10)
      }
    }

    store$run_completed <- isolate(store$run_total) - length(isolate(store$run_queue))
    store$run_current <- NULL
    advance_run()
  }, ignoreInit = TRUE)

  review_edit_blocked <- function(action = "edit the project") {
    store_review_blocked(store, action)
  }

  # Add new (empty) flow
  observeEvent(input$tree_add_flow_click, {
    if (review_edit_blocked("add flows")) return()
    n   <- length(isolate(store$flows)) + 1L
    fl  <- make_flow(paste("Flow", n))
    flows <- isolate(store$flows)
    flows[[fl$id]] <- fl
    store$flows <- flows
    switch_flow(fl$id)
    store$dirty <- TRUE
  })

  # Copy flow
  observeEvent(input$tree_copy_flow, {
    if (review_edit_blocked("copy flows")) return()
    new_id <- store_copy_flow(store, input$tree_copy_flow)
    if (!is.null(new_id)) switch_flow(new_id)
  })

  # Rename task — modal dialog (sets task$label, shown as the canvas card name)
  rv_rename_tid <- reactiveVal(NULL)
  observeEvent(input$tree_rename_task, {
    if (review_edit_blocked("rename tasks")) return()
    tid  <- input$tree_rename_task
    task <- isolate(store$tasks[[tid]])
    if (is.null(task)) return()
    rv_rename_tid(tid)
    info <- task_type_info(task$type)
    showModal(modalDialog(
      title  = div(icon("pen"), " Rename task"),
      size   = "s",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("rename_task_confirm", "Rename", class = "btn btn-primary")),
      textInput("rename_task_name", "Display name",
        value = trimws(task$label %||% ""), width = "100%",
        placeholder = info$label %||% task$type),
      p(class = "text-muted small mb-0",
        "Shown on the canvas card and the tree. Leave blank to use the task type (",
        tags$code(tid), ").")
    ))
  })
  observeEvent(input$rename_task_confirm, {
    if (review_edit_blocked("rename tasks")) {
      removeModal()
      return()
    }
    tid  <- rv_rename_tid()
    req(!is.null(tid))
    task <- isolate(store$tasks[[tid]])
    if (!is.null(task)) {
      task$label <- trimws(input$rename_task_name %||% "")
      store_set_task(store, task)
    }
    removeModal()
  })

  # Rename flow — modal dialog
  rv_rename_fid <- reactiveVal(NULL)
  observeEvent(input$tree_rename_flow, {
    if (review_edit_blocked("rename flows")) return()
    fid <- input$tree_rename_flow
    rv_rename_fid(fid)
    fl  <- isolate(store$flows)[[fid]]
    showModal(modalDialog(
      title  = div(icon("pen"), " Rename flow"),
      size   = "s",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("rename_flow_confirm", "Rename", class = "btn btn-primary")),
      textInput("rename_flow_name", "Name",
        value = fl$name %||% "", width = "100%")
    ))
  })
  observeEvent(input$rename_flow_confirm, {
    if (review_edit_blocked("rename flows")) {
      removeModal()
      return()
    }
    fid  <- rv_rename_fid()
    name <- trimws(input$rename_flow_name)
    req(!is.null(fid), nchar(name) > 0)
    flows <- isolate(store$flows)
    if (!is.null(flows[[fid]])) {
      flows[[fid]]$name <- name
      store$flows <- flows
      store$dirty <- TRUE
    }
    removeModal()
  })

  # ── Undo stack (multi-step) ────────────────────────────────────────────────
  # Deletes are easy to trigger by accident and otherwise unrecoverable. Before
  # any destructive op we push a project-state snapshot onto undo_stack and pop a
  # toast; the user can step back through several actions via the toast, the
  # header Undo button, or Ctrl+Alt+Z. Restoring is a straight assignment back,
  # which the canvas/tree observers pick up automatically.
  UNDO_MAX   <- 25L                  # cap depth so snapshots can't grow unbounded
  undo_stack <- reactiveVal(list())  # list of list(label, state); newest last

  capture_undo <- function(label) {
    store_sync_parameters(store)
    store_snapshot_flow(store)
    entry <- list(
      label = label,
      state = list(
        flows       = isolate(store$flows),
        active_flow = isolate(store$active_flow),
        tasks       = isolate(store$tasks),
        task_order  = isolate(store$task_order),
        sources     = isolate(store$sources),
        tables      = isolate(store$tables),
        objects     = isolate(store$objects),
        branch_tokens = isolate(store$branch_tokens),
        open_tabs   = isolate(tabs_rv$open),
        active_tab  = isolate(tabs_rv$active)
      )
    )
    stk <- c(isolate(undo_stack()), list(entry))
    if (length(stk) > UNDO_MAX) stk <- stk[(length(stk) - UNDO_MAX + 1L):length(stk)]
    undo_stack(stk)
  }

  offer_undo <- function(label) {
    showNotification(
      ui = tagList(
        tags$span(label),
        actionButton("undo_action", "Undo",
          icon = icon("rotate-left"),
          class = "btn btn-sm btn-light ms-2")
      ),
      duration = 9, type = "warning", id = "ig-undo-toast"
    )
  }

  # Pop the most recent snapshot and restore it.
  do_undo <- function() {
    if (structural_edit_blocked("undo changes")) return(invisible(FALSE))
    stk <- isolate(undo_stack())
    if (length(stk) == 0L) return(invisible(NULL))
    u  <- stk[[length(stk)]]
    st <- u$state
    for (tid in inserted_panels) dispose_task_panel(tid)
    store$task_runners <- list()
    store$params_fns <- list()
    store$code_fns <- list()
    store$result_fns <- list()
    store$flows       <- st$flows
    store$active_flow <- st$active_flow
    store$tasks       <- st$tasks
    store$task_order  <- st$task_order
    store$sources     <- st$sources
    store$tables      <- st$tables
    store$objects     <- st$objects
    store$branch_tokens <- st$branch_tokens %||% character(0)
    store_restore_valid_tables(store)
    tabs_rv$open <- PERMANENT_TABS
    tabs_rv$active <- "flow"
    for (tid in intersect(st$open_tabs, names(st$tasks))) open_task_panel(tid)
    activate_tab(if (st$active_tab %in% isolate(tabs_rv$open)) st$active_tab else "flow")
    selected_tasks(character(0))
    store$dirty       <- TRUE
    undo_stack(stk[-length(stk)])
    removeNotification("ig-undo-toast")
    remaining <- length(stk) - 1L
    showNotification(
      sprintf("Undone: %s%s", u$label,
              if (remaining > 0L) sprintf(" (%d more)", remaining) else ""),
      duration = 3, type = "message")
    invisible(NULL)
  }

  observeEvent(input$undo_action, { do_undo() })
  observeEvent(input$btn_undo,    { do_undo() })
  observeEvent(input$shortcut_undo, { do_undo() })

  # Header Undo button — enabled only when the stack has entries; the badge
  # shows depth and the tooltip names the next action that would be undone.
  output$undo_btn_ui <- renderUI({
    stk <- undo_stack()
    n   <- length(stk)
    nxt <- if (n > 0L) stk[[n]]$label else ""
    tags$button(
      id = "btn_undo", type = "button",
      class = paste("btn btn-sm ig-header-btn action-button",
                    if (n == 0L) "disabled"),
      disabled = if (n == 0L) "disabled" else NULL,
      title = if (n > 0L) paste0("Undo: ", nxt, " (", n, " in history)")
              else "Nothing to undo",
      `aria-label` = "Undo last action",
      icon("rotate-left"),
      if (n > 0L) tags$span(class = "ig-undo-badge", as.character(n))
    )
  })

  # Delete flow — confirmation dialog (skippable via Settings)
  rv_delete_fid <- reactiveVal(NULL)

  perform_delete_flow <- function(fid) {
    if (structural_edit_blocked("delete flows")) return(invisible(FALSE))
    flows <- isolate(store$flows)
    if (is.null(fid) || is.null(flows[[fid]]) || length(flows) <= 1L) return(invisible(NULL))
    is_active <- identical(fid, isolate(store$active_flow))
    fl_name <- flows[[fid]]$name %||% fid
    capture_undo(sprintf("Deleted flow '%s'.", fl_name))
    background <- isolate(store$background$job)
    if (!is.null(background) && identical(background$flow_id, fid))
      ig_background_cancel(store, notify = FALSE, change_status = FALSE)
    tasks <- if (is_active) isolate(store$tasks) else flows[[fid]]$tasks
    store_detach_task_outputs(store, names(tasks))
    for (tid in names(tasks)) {
      dispose_task_panel(tid)
      store_close_connections(store, tid)
      for (key in c("task_runners", "params_fns", "code_fns", "result_fns")) {
        entries <- isolate(store[[key]]); entries[[tid]] <- NULL; store[[key]] <- entries
      }
    }
    flows <- isolate(store$flows)
    flows[[fid]] <- NULL
    store$flows  <- flows
    store$dirty  <- TRUE
    if (is_active) switch_flow(names(flows)[1])
    offer_undo(sprintf("Deleted flow '%s'.", fl_name))
    invisible(NULL)
  }

  observeEvent(input$tree_delete_flow, {
    if (review_edit_blocked("delete flows")) return()
    fid   <- input$tree_delete_flow
    flows <- isolate(store$flows)
    if (length(flows) <= 1L) {
      showNotification("Cannot delete the only flow.", type = "warning")
      return()
    }
    if (isFALSE((isolate(store$settings) %||% list())$confirm_delete)) {
      perform_delete_flow(fid)
      return()
    }
    rv_delete_fid(fid)
    fl <- flows[[fid]]
    showModal(modalDialog(
      title  = div(icon("trash"), " Delete flow"),
      size   = "s",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("delete_flow_confirm", "Delete", class = "btn btn-danger")),
      p(sprintf("Delete flow '%s'? All tasks in this flow will be permanently removed.",
                fl$name %||% fid))
    ))
  })
  observeEvent(input$delete_flow_confirm, {
    if (review_edit_blocked("delete flows")) {
      removeModal()
      return()
    }
    perform_delete_flow(rv_delete_fid())
    removeModal()
  })

  # Delete task — confirmation dialog (skippable via Settings)
  rv_delete_task_id <- reactiveVal(NULL)

  perform_delete_task <- function(tid) {
    if (structural_edit_blocked("delete tasks")) return(invisible(FALSE))
    task <- isolate(store$tasks[[tid]])
    if (is.null(task)) return(invisible(NULL))
    info <- task_type_info(task$type)
    lbl  <- trimws(task$label %||% "")
    lbl  <- if (nzchar(lbl)) lbl else (info$label %||% task$type)
    capture_undo(sprintf("Deleted task '%s'.", lbl))
    store_detach_task_outputs(store, tid)
    store_remove_task(store, tid)
    dispose_task_panel(tid)
    if (identical(tabs_rv$active, tid) || !tabs_rv$active %in% tabs_rv$open)
      activate_tab("flow")
    offer_undo(sprintf("Deleted task '%s'.", lbl))
    invisible(NULL)
  }

  show_delete_task_modal <- function(tid) {
    if (review_edit_blocked("delete tasks")) return()
    task <- isolate(store$tasks[[tid]])
    if (is.null(task)) return()
    # Settings → "Ask for confirmation before deleting" can disable the dialog
    if (isFALSE((isolate(store$settings) %||% list())$confirm_delete)) {
      perform_delete_task(tid)
      return()
    }
    rv_delete_task_id(tid)
    info <- task_type_info(task$type)
    showModal(modalDialog(
      title = div(icon("trash"), " Delete task"),
      size = "s",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("delete_task_confirm", "Delete", class = "btn btn-danger")
      ),
      p(sprintf("Delete '%s'?", info$label %||% task$type)),
      if (!is.null(task$output) && nzchar(task$output))
        p(class = "text-muted small",
          "The task output table '", task$output,
          "' will also be removed if no other task uses it.")
    ))
  }

  # Fired from the project tree sidebar
  observeEvent(input$tree_delete_task,  { show_delete_task_modal(input$tree_delete_task)  })
  # Fired from the trash button inside the task panel itself
  observeEvent(input$panel_delete_task, { show_delete_task_modal(input$panel_delete_task) })

  observeEvent(input$delete_task_confirm, {
    if (review_edit_blocked("delete tasks")) {
      removeModal()
      return()
    }
    tid <- rv_delete_task_id()
    req(!is.null(tid))
    perform_delete_task(tid)
    removeModal()
  })

  # ── Bulk task selection / delete ──────────────────────────────────────────────
  observeEvent(input$tree_task_toggle_select, {
    tid <- input$tree_task_toggle_select
    cur <- isolate(selected_tasks())
    selected_tasks(if (tid %in% cur) setdiff(cur, tid) else c(cur, tid))
  })

  observeEvent(input$tree_bulk_clear_sel, { selected_tasks(character(0)) })

  perform_bulk_delete <- function(ids) {
    if (structural_edit_blocked("delete tasks")) return()
    ids <- intersect(ids, names(isolate(store$tasks)))
    if (length(ids) == 0L) return(invisible(NULL))
    capture_undo(sprintf("Deleted %d task%s.", length(ids),
                         if (length(ids) == 1L) "" else "s"))
    store_detach_task_outputs(store, ids)
    for (tid in ids) {
      task <- isolate(store$tasks[[tid]])
      if (is.null(task)) next
      store_remove_task(store, tid)
      dispose_task_panel(tid)
    }
    if (!tabs_rv$active %in% tabs_rv$open) activate_tab("flow")
    selected_tasks(character(0))
    offer_undo(sprintf("Deleted %d task%s.", length(ids),
                       if (length(ids) == 1L) "" else "s"))
    invisible(NULL)
  }

  observeEvent(input$tree_bulk_delete, {
    if (review_edit_blocked("delete tasks")) return()
    ids <- intersect(isolate(selected_tasks()), names(isolate(store$tasks)))
    if (length(ids) == 0L) return()
    if (isFALSE((isolate(store$settings) %||% list())$confirm_delete)) {
      perform_bulk_delete(ids)
      return()
    }
    showModal(modalDialog(
      title  = div(icon("trash"), " Delete selected tasks"),
      size   = "s",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("bulk_delete_confirm", "Delete", class = "btn btn-danger")),
      p(sprintf("Delete %d selected task%s? Their output tables will also be removed if no other task uses them.",
                length(ids), if (length(ids) == 1L) "" else "s"))
    ))
  })

  observeEvent(input$bulk_delete_confirm, {
    if (review_edit_blocked("delete tasks")) {
      removeModal()
      return()
    }
    perform_bulk_delete(isolate(selected_tasks()))
    removeModal()
  })

  # ── Tab strip rendering ───────────────────────────────────────────────────────
  TAB_META <- list(
    flow   = list(label = "Flow",  icon = "share-nodes"),
    code   = list(label = "Code",  icon = "code"),
    console = list(label = "R Console", icon = "terminal")
  )

  tab_meta <- function(tab_id) {
    if (tab_id %in% names(TAB_META)) return(TAB_META[[tab_id]])
    task <- isolate(store$tasks[[tab_id]])
    info <- if (!is.null(task)) task_type_info(task$type) else NULL
    list(
      label = if (!is.null(info)) info$label else tab_id,
      icon  = if (!is.null(info)) info$icon  else "circle"
    )
  }

  output$tab_strip_ui <- renderUI({
    open   <- tabs_rv$open
    active <- tabs_rv$active
    tasks  <- store_ui_read(store, "tasks", store$tasks)
    n_tasks <- length(store$task_order)

    pills <- lapply(open, function(tid) {
      meta      <- tab_meta(tid)
      is_active <- identical(tid, active)
      closeable <- !tid %in% PERMANENT_TABS

      # Status dot for task tabs; task-count badge for the Flow tab
      status_extra <- if (closeable) {
        t <- tasks[[tid]]
        if (!is.null(t$error_msg)) {
          span(class = "ig-tab-dot ig-tab-dot-error",
            title = "Last run failed", `aria-label` = "failed")
        } else if (!is.null(t$run_time)) {
          span(class = "ig-tab-dot ig-tab-dot-success",
            title = "Ran successfully", `aria-label` = "ran successfully")
        } else NULL
      } else if (identical(tid, "flow") && n_tasks > 0L) {
        span(class = "ig-tab-count", title = sprintf("%d task(s) in this flow", n_tasks),
          n_tasks)
      } else NULL

      div(
        # id lets each tabpanel reference its controlling tab via aria-labelledby
        id              = paste0("tabpill_", tid),
        class           = paste("ig-tab-pill", if (is_active) "active"),
        role            = "tab",
        `aria-controls` = paste0("panel_", tid),
        # aria-selected communicates active state to screen readers
        `aria-selected` = if (is_active) "true" else "false",
        # Roving tabindex: only the active tab is in the Tab key sequence;
        # arrow keys move within the tablist without adding Tab stops.
        tabindex        = if (is_active) "0" else "-1",
        onclick = ig_input_event_js("tab_clicked", tid),
        title = if (closeable) {
          "Arrow keys move tabs. Delete or Ctrl+Alt+W closes this task tab."
        } else {
          "Arrow keys move tabs."
        },
        icon(meta$icon), span(meta$label),
        status_extra,
        if (closeable) tags$button(
          # Real button: keyboard-focusable, meaningful label, correct type.
          # tabindex=-1 keeps it out of the roving tabindex sequence; users
          # reach it via Delete while the tab pill has focus.
          class        = "ig-tab-close",
          type         = "button",
          tabindex     = "-1",
          `aria-label` = paste("Close", meta$label, "tab"),
          onclick      = ig_input_event_js("tab_closed", tid, stop_propagation = TRUE),
          # aria-hidden hides the × glyph from AT; the aria-label on the
          # button provides the accessible name.
          tags$span(`aria-hidden` = "true", "\u00d7")
        )
      )
    })

    div(
      class        = "ig-tab-strip-inner",
      role         = "tablist",
      `aria-label` = "Task panels",
      tagList(pills)
    )
  })

  # ── Tab navigation ────────────────────────────────────────────────────────────
  activate_tab <- function(tab_id, focus_tab = FALSE) {
    tabs_rv$active <- tab_id
    if (isTRUE(focus_tab)) {
      session$sendCustomMessage("ig_focus_tab", tab_id)
    }
    session$sendCustomMessage("ig_switch_tab", tab_id)
  }

  observeEvent(input$tab_clicked, { activate_tab(input$tab_clicked) })

  observeEvent(input$shortcut_open_tab, {
    open_task_panel(input$shortcut_open_tab, focus_tab = TRUE)
  })

  observeEvent(input$tab_closed, {
    tid <- input$tab_closed
    if (tid %in% PERMANENT_TABS) return()
    remaining <- setdiff(tabs_rv$open, tid)
    tabs_rv$open <- remaining
    # Do NOT removeUI — the panel div stays in the DOM so all Shiny input values
    # (code textarea, output_name, input_tables) are preserved for when the user
    # reopens the tab.  ig_switch_tab will hide it immediately via CSS.
    if (identical(tabs_rv$active, tid)) {
      new_active <- if (length(remaining)) remaining[length(remaining)] else "flow"
      activate_tab(new_active, focus_tab = TRUE)
    }
  })

  # ── Open a task panel (idempotent) ───────────────────────────────────────────
  open_task_by_id <- function(tid) {
    tasks <- isolate(store$tasks)
    if (!tid %in% names(tasks)) {
      flows <- isolate(store$flows)
      for (fid in names(flows)) {
        if (tid %in% names(flows[[fid]]$tasks %||% list())) {
          switch_flow(fid)
          break
        }
      }
    }
    open_task_panel(tid, focus_tab = TRUE)
  }

  open_task_panel <- function(tab_id, focus_tab = FALSE) {
    if (!tab_id %in% tabs_rv$open)
      tabs_rv$open <- c(tabs_rv$open, tab_id)

    if (tab_id %in% PERMANENT_TABS) {
      activate_tab(tab_id, focus_tab = focus_tab)
      return()
    }

    if (!tab_id %in% inserted_panels) {
      task <- isolate(store$tasks[[tab_id]])
      req(!is.null(task))
      panel_ui <- task_panel_ui(tab_id, task$type)
      info     <- task_type_info(task$type)

      insertUI(
        selector  = "#all-panels",
        where     = "beforeEnd",
        immediate = TRUE,
        ui = div(
          id                = paste0("panel_", tab_id),
          class             = "ig-task-panel",
          role              = "tabpanel",
          # aria-labelledby links this panel to its controlling tab pill so
          # screen readers announce the tab name when the panel is focused.
          `aria-labelledby` = paste0("tabpill_", tab_id),
          # Start hidden; ig_switch_tab will set aria-hidden="false" when
          # this tab is activated.  Redundant with display:none but explicit
          # for assistive technology that checks aria-hidden directly.
          `aria-hidden`     = "true",
          `data-tab-id`     = tab_id,
          # ── Task header bar: identity, live status, code toggle, delete ──
          div(
            class = "ig-panel-toolbar",
            span(class = "ig-panel-task-info",
              icon(info$icon %||% "circle"),
              strong(info$label %||% task$type),
              tags$code(class = "ig-panel-task-id", tab_id)
            ),
            uiOutput(paste0("panel_status_", tab_id), inline = TRUE),
            div(class = "ms-auto d-flex align-items-center gap-2",
              actionButton(paste0("panel_run_btn_", tab_id), "Run",
                icon  = icon("play"),
                class = "btn btn-xs btn-primary",
                title = "Run this task with its current settings"),
              actionButton(paste0("panel_code_btn_", tab_id), "Code",
                icon  = icon("code"),
                class = "btn btn-xs btn-outline-secondary",
                title = "Show / hide this task's generated R code"),
              tags$button(
                class        = "btn btn-xs btn-outline-danger ig-panel-delete-btn",
                type         = "button",
                `aria-label` = "Delete this task",
                title        = "Delete this task",
                onclick      = ig_input_event_js("panel_delete_task", tab_id),
                icon("trash")
              )
            )
          ),
          # Generated-code strip — collapsed until the Code button is toggled
          conditionalPanel(
            condition = paste0("input['panel_code_btn_", tab_id, "'] % 2 == 1"),
            div(class = "ig-panel-code-view ig-code-panel",
              verbatimTextOutput(paste0("panel_code_view_", tab_id)))
          ),
          uiOutput(paste0("panel_control_deps_", tab_id)),
          task_logging_ui(paste0("log_", tab_id), task$logging, task$type),
          panel_ui
        )
      )
      inserted_panels <<- c(inserted_panels, tab_id)
      init_task_module(tab_id, task$type)
      task_logging_server(paste0("log_", tab_id), store, tab_id)

      # Live header outputs for this panel. Re-registering on reopen simply
      # replaces the previous binding, so flow switches are safe.
      local({
        tid <- tab_id
        output[[paste0("panel_status_", tid)]] <- renderUI({
          t <- store_ui_read(store, "tasks", store$tasks)[[tid]]
          if (is.null(t)) return(NULL)
          if (!is.null(t$error_msg)) {
            span(class = "ig-status-chip ig-status-error",
              title = t$error_msg,
              icon("xmark"), "failed")
          } else if (identical(t$status %||% "", "skipped")) {
            span(class = "ig-status-chip ig-status-pending",
              title = t$skip_reason %||% paste("Skipped by branch", t$skipped_by %||% ""),
              icon("forward"), "skipped")
          } else if (identical(t$status %||% "", "waiting")) {
            span(class = "ig-status-chip ig-status-pending", icon("key"), "waiting for password")
          } else if (identical(t$status %||% "", "running")) {
            span(class = "ig-status-chip ig-status-pending", icon("spinner"), "running")
          } else if (!is.null(t$run_time)) {
            span(class = "ig-status-chip ig-status-success",
              title = format(t$run_time, "%Y-%m-%d %H:%M:%S"),
              icon("check"), paste("ran", format(t$run_time, "%H:%M:%S")))
          } else {
            span(class = "ig-status-chip ig-status-pending",
              icon("clock"), "not run yet")
          }
        })
        output[[paste0("panel_code_view_", tid)]] <- renderText({
          # Prefer a live code generator (reflects the panel's current
          # inputs); fall back to the last-run code stored on the task.
          fn <- store$code_fns[[tid]]
          live <- if (!is.null(fn)) {
            tryCatch(trimws(fn() %||% ""), error = function(e) "")
          } else ""
          if (nzchar(live)) return(live)
          t <- store$tasks[[tid]]
          code <- trimws(t$r_code %||% "")
          if (nzchar(code)) code else
            "# Run the task to generate its R code."
        })
        control_state <- ig_reactive_distinct(function() {
          t <- store_ui_read(store, "tasks", store$tasks)[[tid]]
          list(task = t[c("type", "control_inputs")],
            choices = store_available_control_tokens(store, task_id = tid))
        })
        output[[paste0("panel_control_deps_", tid)]] <- renderUI({
          state <- control_state()
          t <- state$task
          if (is.null(t) || t$type %in% c("branch", "loop")) return(NULL)
          choices <- state$choices
          selected <- intersect(t$control_inputs %||% character(0), choices)
          if (!length(choices)) return(NULL)
          div(class = "ig-panel-control-deps",
            selectizeInput(
              paste0("panel_control_select_", tid),
              label = tagList(icon("route"), " Run after branch/loop path"),
              choices = choices,
              selected = selected,
              multiple = TRUE,
              options = list(plugins = list("remove_button"),
                             placeholder = "Choose path tokens for conditional execution")
            ),
            div(class = "small text-muted",
              "Use this to put the task on a branch or loop path. Keep normal dataset inputs in the task settings below.")
          )
        })
        # Header Run button — observers must register exactly once per task
        # (re-opening a panel after a flow switch re-runs this block).
        if (!tid %in% panel_observers) {
          panel_observers <<- c(panel_observers, tid)
          controls_observer <- observeEvent(input[[paste0("panel_control_select_", tid)]], {
            task <- isolate(store$tasks[[tid]])
            if (is.null(task) || review_edit_blocked("change control-flow dependencies")) return()
            task$control_inputs <- input[[paste0("panel_control_select_", tid)]] %||% character(0)
            task$inputs <- setdiff(task$inputs %||% character(0),
              store_available_control_tokens(store, task_id = tid))
            task$inputs <- unique(c(task$inputs, task$control_inputs))
            store_set_task(store, task)
          }, ignoreInit = TRUE)
          run_observer <- observeEvent(input[[paste0("panel_run_btn_", tid)]], {
            if (review_edit_blocked("run tasks")) return()
            runner <- isolate(store$task_runners)[[tid]]
            if (identical(isolate(store$tasks[[tid]])$type, "loop")) runner <- NULL
            if (!is.null(runner)) {
              tryCatch(
                runner(),
                shiny.silent.error = function(e) {
                  showNotification(
                    sprintf("'%s': required inputs not set.", tid),
                    type = "warning", duration = 5)
                },
                error = function(e) {
                  showNotification(
                    sprintf("'%s' failed: %s", tid, conditionMessage(e)),
                    type = "error", duration = 10)
                }
              )
            } else {
              run_task_from_store(store, tid)
            }
          }, ignoreInit = TRUE)
          panel_observer_handles[[tid]] <<- list(controls_observer, run_observer, attr(control_state, "observer"))
        }
      })
    }

    activate_tab(tab_id, focus_tab = isTRUE(focus_tab))
  }

  task_panel_ui <- function(tab_id, type) {
    if (type %in% PHASE3_TYPES)
      return(phase3_task_ui(paste0("p3_", tab_id), type))
    switch(type,
      import_data         = import_ui(paste0("import_", tab_id)),
      query_builder       = query_builder_ui(paste0("qb_",   tab_id)),
      # ── Phase 2 Data ────────────────────────────────────────────────────────
      append_table        = append_table_ui(paste0("at_",   tab_id)),
      compare_data        = compare_data_ui(paste0("cd_",   tab_id)),
      filter_sort         = filter_sort_ui(paste0("fs_",    tab_id)),
      stack_columns       = stack_columns_ui(paste0("sc_",  tab_id)),
      split_columns       = split_columns_ui(paste0("sp_",  tab_id)),
      transpose           = transpose_ui(paste0("tr_",      tab_id)),
      rank                = rank_ui(paste0("rk_",           tab_id)),
      standardize         = standardize_ui(paste0("std_",   tab_id)),
      random_sample       = random_sample_ui(paste0("rs_",   tab_id)),
      remove_dups         = remove_dups_ui(paste0("rd_",    tab_id)),
      keep_drop_cols      = keep_drop_cols_ui(paste0("kd_",  tab_id)),
      rename_cols         = rename_cols_ui(paste0("rn_",    tab_id)),
      first_last_n        = first_last_n_ui(paste0("fl_",   tab_id)),
      replace_missing     = replace_missing_ui(paste0("rp_", tab_id)),
      derive_cols         = derive_cols_ui(paste0("dc_",    tab_id)),
      recode_values       = recode_values_ui(paste0("rv_",  tab_id)),
      change_types        = change_types_ui(paste0("ct_",   tab_id)),
      # ── Phase 2 Describe ────────────────────────────────────────────────────
      characterize        = characterize_data_ui(paste0("chr_",  tab_id)),
      distribution        = distribution_analysis_ui(paste0("dist_", tab_id)),
      list_data           = list_data_ui(paste0("ld_",      tab_id)),
      one_way_freq        = one_way_freq_ui(paste0("owf_",  tab_id)),
      summary_stats       = summary_stats_ui(paste0("sst_", tab_id)),
      summary_tables      = summary_tables_ui(paste0("stbl_", tab_id)),
      table_analysis      = table_analysis_ui(paste0("ta_", tab_id)),
      # ── General ─────────────────────────────────────────────────────────────
      script              = script_ui(paste0("scr_", tab_id)),
      report              = report_ui(paste0("rpt_", tab_id)),
      export              = export_ui(paste0("exp_", tab_id)),
      export_log          = export_log_ui(paste0("elog_", tab_id), isolate(store$tasks[[tab_id]])$params),
      branch              = branch_ui(paste0("br_", tab_id)),
      loop                = loop_ui(paste0("loop_", tab_id)),
      # ── Fallback ────────────────────────────────────────────────────────────
      bslib::card(
        bslib::card_header(icon("clock"),
          sprintf(" %s \u2014 Coming Soon", type)),
        bslib::card_body(
          p(class = "text-muted",
            "This task is planned for a future phase.")
        )
      )
    )
  }

  init_task_module <- function(tab_id, type) {
    mod_id <- paste0(type, "_", tab_id)
    if (mod_id %in% initialised_modules) return()
    initialised_modules <<- c(initialised_modules, mod_id)
    if (type %in% PHASE3_TYPES) {
      phase3_task_server(paste0("p3_", tab_id), store, task_id = tab_id, type_id = type)
      return(invisible(NULL))
    }
    switch(type,
      import_data   = import_server(paste0("import_", tab_id), store, task_id = tab_id),
      query_builder = query_builder_server(paste0("qb_", tab_id), store, task_id = tab_id),
      # ── Phase 2 Data ────────────────────────────────────────────────────────
      append_table  = append_table_server(paste0("at_",  tab_id), store, task_id = tab_id),
      compare_data  = compare_data_server(paste0("cd_",  tab_id), store, task_id = tab_id),
      filter_sort   = filter_sort_server(paste0("fs_",   tab_id), store, task_id = tab_id),
      stack_columns = stack_columns_server(paste0("sc_", tab_id), store, task_id = tab_id),
      split_columns = split_columns_server(paste0("sp_", tab_id), store, task_id = tab_id),
      transpose     = transpose_server(paste0("tr_",     tab_id), store, task_id = tab_id),
      rank          = rank_server(paste0("rk_",          tab_id), store, task_id = tab_id),
      standardize   = standardize_server(paste0("std_",  tab_id), store, task_id = tab_id),
      random_sample   = random_sample_server(paste0("rs_",    tab_id), store, task_id = tab_id),
      remove_dups     = remove_dups_server(paste0("rd_",     tab_id), store, task_id = tab_id),
      keep_drop_cols  = keep_drop_cols_server(paste0("kd_",  tab_id), store, task_id = tab_id),
      rename_cols     = rename_cols_server(paste0("rn_",     tab_id), store, task_id = tab_id),
      first_last_n    = first_last_n_server(paste0("fl_",    tab_id), store, task_id = tab_id),
      replace_missing = replace_missing_server(paste0("rp_", tab_id), store, task_id = tab_id),
      derive_cols     = derive_cols_server(paste0("dc_",     tab_id), store, task_id = tab_id),
      recode_values   = recode_values_server(paste0("rv_",   tab_id), store, task_id = tab_id),
      change_types    = change_types_server(paste0("ct_",    tab_id), store, task_id = tab_id),
      # ── Phase 2 Describe ────────────────────────────────────────────────────
      characterize   = characterize_data_server(paste0("chr_",  tab_id), store, task_id = tab_id),
      distribution   = distribution_analysis_server(paste0("dist_", tab_id), store, task_id = tab_id),
      list_data      = list_data_server(paste0("ld_",      tab_id), store, task_id = tab_id),
      one_way_freq   = one_way_freq_server(paste0("owf_",  tab_id), store, task_id = tab_id),
      summary_stats  = summary_stats_server(paste0("sst_", tab_id), store, task_id = tab_id),
      summary_tables = summary_tables_server(paste0("stbl_", tab_id), store, task_id = tab_id),
      table_analysis = table_analysis_server(paste0("ta_", tab_id), store, task_id = tab_id),
      # General
      script         = script_server(paste0("scr_", tab_id), store, task_id = tab_id),
      report         = report_server(paste0("rpt_", tab_id), store, task_id = tab_id),
      export         = export_server(paste0("exp_", tab_id), store, task_id = tab_id),
      export_log     = export_log_server(paste0("elog_", tab_id), store, task_id = tab_id),
      branch         = branch_server(paste0("br_", tab_id), store, task_id = tab_id),
      loop           = loop_server(paste0("loop_", tab_id), store, task_id = tab_id)
    )
  }

  # ── Task creation ─────────────────────────────────────────────────────────────
  create_task <- function(type_id) {
    if (review_edit_blocked("add tasks")) return(invisible(NULL))
    task_id  <- store_next_id(store, type_id)
    out_name <- paste0(task_id, "_out")
    if (type_id %in% PHASE3_TYPES) {
      init_p <- default_phase3_params(type_id, output_name = out_name)
      # New graph tasks start from the user's preferred styling defaults
      s <- isolate(store$settings) %||% list()
      init_p$plot_theme <- s$plot_theme %||% init_p$plot_theme
      init_p$palette    <- s$palette    %||% init_p$palette
      task <- task_def(task_id, type_id,
                       inputs = character(0),
                       output = out_name,
                       params = init_p)
      store_set_task(store, task)
      open_task_panel(task_id, focus_tab = TRUE)
      return(invisible(task_id))
    }
    init_p   <- switch(type_id,
      # Phase 1
      import_data    = default_import_params(output_name = out_name),
      query_builder  = default_qb_params(output_name = out_name),
      # Phase 2 — Data
      append_table   = default_append_table_params(output_name = out_name),
      compare_data   = default_compare_data_params(output_name = out_name),
      filter_sort    = default_filter_sort_params(output_name = out_name),
      stack_columns  = default_stack_columns_params(output_name = out_name),
      split_columns  = default_split_columns_params(output_name = out_name),
      transpose      = default_transpose_params(output_name = out_name),
      rank           = default_rank_params(output_name = out_name),
      standardize    = default_standardize_params(output_name = out_name),
      random_sample   = default_random_sample_params(output_name = out_name),
      remove_dups     = default_remove_dups_params(output_name = out_name),
      keep_drop_cols  = default_keep_drop_params(output_name = out_name),
      rename_cols     = default_rename_cols_params(output_name = out_name),
      first_last_n    = default_first_last_params(output_name = out_name),
      replace_missing = default_replace_missing_params(output_name = out_name),
      derive_cols     = default_derive_cols_params(output_name = out_name),
      recode_values   = default_recode_values_params(output_name = out_name),
      change_types    = default_change_types_params(output_name = out_name),
      # Phase 2 — Describe
      characterize   = default_characterize_params(output_name = out_name),
      distribution   = default_distribution_params(output_name = out_name),
      list_data      = default_list_data_params(output_name = out_name),
      one_way_freq   = default_one_way_freq_params(output_name = out_name),
      summary_stats  = default_summary_stats_params(output_name = out_name),
      summary_tables = default_summary_tables_params(output_name = out_name),
      table_analysis = default_table_analysis_params(output_name = out_name),
      # General
      script         = default_script_params(output_name = out_name),
      report         = default_report_params(output_name = out_name),
      export         = default_export_params(output_name = out_name),
      export_log     = default_export_log_params(),
      branch         = default_branch_params(output_name = out_name),
      loop           = default_loop_params(output_name = out_name),
      # Fallback for future tasks
      list(output_name = out_name)
    )
    # Export is a SINK; control-flow nodes expose path tokens instead of tables.
    if (identical(type_id, "export_log")) init_p$after_tasks <- isolate(store$task_order)
    task_output <- if (type_id %in% c("export", "export_log", "branch", "loop")) "" else out_name
    task <- task_def(task_id, type_id,
                     inputs = character(0),
                     output = task_output,
                     params = init_p)
    if (identical(type_id, "export")) task$outputs <- list()
    if (identical(type_id, "branch")) task$outputs <- branch_output_specs(init_p)
    if (identical(type_id, "loop")) task$outputs <- loop_output_specs(init_p)
    store_set_task(store, task)
    open_task_panel(task_id, focus_tab = TRUE)
  }

  # ── Canvas → main panel bridge ───────────────────────────────────────────────
  panel_trigger <- function(target) {
    switch(target,
      import    = create_task("import_data"),
      new_query = create_task("query_builder"),
      flow      = open_task_panel("flow", focus_tab = TRUE),
      code      = open_task_panel("code", focus_tab = TRUE)
    )
  }

  # ── Module servers ────────────────────────────────────────────────────────────
  canvas_rv <- canvas_server("canvas", store, panel_trigger)
  code_panel_server("code", store)
  r_console <- console_server("r_console", store)

  # ── Canvas context menu (right-click on task node) ────────────────────────────
  ctx_node <- reactiveVal(NULL)

  observeEvent(canvas_rv$context_node(), {
    node_id <- canvas_rv$context_node()
    if (is.null(node_id) || !nzchar(node_id %||% "")) return()
    task <- isolate(store$tasks[[node_id]])
    if (is.null(task)) return()  # table/object node — no context menu
    ctx_node(node_id)

    run_label <- if (!is.null(task$run_time))
      sprintf("Last run: %s", format(task$run_time, "%Y-%m-%d %H:%M:%S"))
    else "Not yet run."

    showModal(modalDialog(
      title = paste("Task:", node_id),
      footer = tagList(
        actionButton("ctx_save_note",  "Save note",
          class = "btn btn-outline-secondary"),
        actionButton("ctx_run_to",     "Run to here",
          class = "btn btn-outline-primary"),
        actionButton("ctx_run_from",   "Run from here",
          class = "btn btn-primary"),
        modalButton("Close")
      ),
      size = "s",
      textAreaInput("ctx_note", "Note (shown as node tooltip)",
        value       = task$note %||% "",
        rows        = 3,
        width       = "100%",
        placeholder = "Optional \u2014 visible as tooltip on the canvas node."),
      tags$small(class = "text-muted d-block mt-2", run_label)
    ))
  })

  # Helper: save note text for the current context node
  save_ctx_note <- function() {
    if (review_edit_blocked("edit node notes")) return(FALSE)
    nid  <- isolate(ctx_node())
    if (is.null(nid)) return(FALSE)
    task <- isolate(store$tasks[[nid]])
    if (is.null(task)) return(FALSE)
    task$note <- trimws(input$ctx_note %||% "")
    store_set_task(store, task)
    TRUE
  }

  observeEvent(input$ctx_save_note, {
    save_ctx_note()
    removeModal()
  })

  # Run from here: execute start_id and all downstream tasks in topo order
  observeEvent(input$ctx_run_from, {
    if (!save_ctx_note()) return()
    nid <- isolate(ctx_node())
    removeModal()
    if (is.null(nid)) return()
    ord        <- isolate(store$task_order)
    tasks_snap <- isolate(store$tasks)
    run_ids    <- store_topo_from(tasks_snap, ord, nid)
    start_run_queue(run_ids, sprintf(" from '%s'", nid))
  })

  # Run to here: execute all ancestors of end_id (inclusive) in topo order
  observeEvent(input$ctx_run_to, {
    if (!save_ctx_note()) return()
    nid <- isolate(ctx_node())
    removeModal()
    if (is.null(nid)) return()
    ord        <- isolate(store$task_order)
    tasks_snap <- isolate(store$tasks)
    run_ids    <- store_topo_to(tasks_snap, ord, nid)
    start_run_queue(run_ids, sprintf(" up to '%s'", nid))
  })

  # ── Splash screen (shown once on session start) ───────────────────────────────
  show_splash <- function() {
    workspace_welcome(TRUE)
    showModal(modalDialog(
      title     = NULL,
      footer    = NULL,
      easyClose = FALSE,
      size      = "m",
      div(class = "ig-splash",
        div(class = "ig-browser-only d-flex justify-content-center mb-3", ig_language_picker("ig-welcome-language")),
        div(class = "ig-splash-logo",
          icon("share-nodes", class = "ig-splash-icon"),
          h2(class = "ig-splash-title", "Individual Guide"),
          p(class  = "ig-splash-tagline text-muted",
            "Build analytical pipelines without writing code")
        ),
        div(class = "ig-splash-divider"),
        div(class = "ig-splash-actions",
          actionButton("splash_import", "Import data",
            icon  = icon("database"),
            class = "btn btn-primary ig-splash-btn",
            width = "100%"),
          actionButton("splash_open", "Open project",
            icon  = icon("folder-open"),
            class = "btn btn-outline-secondary ig-splash-btn",
            width = "100%"),
          tags$button(id = "splash_shiny_apps", type = "button", class = "btn btn-outline-secondary ig-splash-btn ig-browser-only",
            icon("window-maximize"), "Open Shiny app")
        ),
        div(class = "ig-splash-fresh",
          actionButton("splash_fresh", "Start with a blank canvas",
            class = "btn btn-link text-muted ig-splash-fresh-btn")
        )
      )
    ))
  }

  # ── Crash recovery ────────────────────────────────────────────────────────────
  # If a recovery autosave from a previous (crashed / closed) session exists,
  # offer to restore it before falling back to the normal splash.
  show_recovery_modal <- function(rec_path) {
    info  <- file.info(rec_path)
    stamp <- tryCatch(format(info$mtime, "%Y-%m-%d %H:%M"), error = function(e) "")
    showModal(modalDialog(
      title     = div(icon("clock-rotate-left"), " Recover unsaved work?"),
      footer    = tagList(
        actionButton("recover_discard", "Discard", class = "btn btn-outline-secondary"),
        actionButton("recover_restore", "Restore", class = "btn btn-primary")),
      easyClose = FALSE,
      p("Individual Guide found work that was not saved to a project file",
        if (nzchar(stamp)) sprintf(" (last autosaved %s)", stamp) else "", "."),
      p(class = "text-muted small",
        "Restore it to continue where you left off, or discard to start clean.")
    ))
  }

  start_session_ui <- function() {
    rec_path <- project_recovery_path()
    if (file.exists(rec_path)) show_recovery_modal(rec_path) else show_splash()
    startup_ready(TRUE)
  }

  session$onFlushed(function() { start_session_ui() }, once = TRUE)

  observeEvent(input$recover_restore, {
    if(!isTRUE(isolate(recovery_pending())))return()
    recovery_pending(FALSE)
    workspace_welcome(FALSE)
    removeModal()
    res <- tryCatch(project_load(store, project_recovery_path()),
                    error = function(e) list(ok = FALSE, errors = conditionMessage(e)))
    if (isTRUE(res$ok) || length(res$errors %||% character(0)) == 0L) {
      store$project_path <- NULL  # recovery snapshots must never become real save targets
      store$dirty <- TRUE   # restored-but-not-saved-to-a-file
      activate_tab("flow")
      showNotification("Recovered your previous session.", type = "message", duration = 4)
    } else {
      showNotification(paste("Recovery problem:",
        paste(res$errors, collapse = "; ")), type = "warning", duration = 6)
      activate_tab("flow")
    }
  })

  observeEvent(input$recover_discard, {
    if(!isTRUE(isolate(recovery_pending())))return()
    recovery_pending(FALSE)
    removeModal()
    project_clear_recovery()
    show_splash()
  })

  # ── Recovery autosave ──────────────────────────────────────────────────────────
  # Keep a generation number, not old copies of tables/models. Track inactive
  # flow definitions and genuine layout changes, excluding the active flow's
  # derived Save snapshot so autosaving does not invalidate itself.
  recovery_revision <- 0
  recovery_saved_revision <- -1
  recovery_flows <- ig_reactive_distinct(function() project_recovery_flow_state(store))
  observe({
    store$tables; store$objects; store$sources; store$formats
    store$tasks; store$task_order; store$active_flow; store$project_name
    store$settings; store$task_favourites; store$collaboration
    recovery_flows(); theme_mode()
    recovery_revision <<- recovery_revision + 1
  }, priority = -90)
  observe({
    if (isTRUE(isolate(store$dirty)) && recovery_revision != recovery_saved_revision) {
      # Parameter readers invoked while saving must not turn this timer into
      # another input observer. Retry a failed write at the next interval.
      # The graph is derived from tasks. Manual positions already live in the
      # flow's canvas_pos; retain legacy snapshots without rebuilding cards or
      # serializing a fresh set of SVGs during an editing pause.
      saved <- isolate(project_autosave_recovery(store, canvas_state = NULL, theme = theme_mode()))
      if (!is.null(saved)) recovery_saved_revision <<- recovery_revision
    }
    # Schedule after I/O: a slow save must not immediately start another save.
    invalidateLater(30000)
  }, priority = -100)

  observeEvent(input$splash_import, {
    workspace_welcome(FALSE)
    removeModal()
    create_task("import_data")
  })

  observeEvent(input$splash_open, {
    # ig_click closes the splash modal and opens the picker only once the splash
    # has finished hiding (Bootstrap won't stack modals) — don't removeModal here.
    session$sendCustomMessage("ig_click", "sf_open")
  })

  observeEvent(input$splash_fresh, {
    workspace_welcome(FALSE)
    removeModal()
    activate_tab("flow")
  })

  # ── Title-bar buttons ─────────────────────────────────────────────────────────
  observeEvent(input$btn_add_task,  { show_task_picker() })
  comment_observers <- character(0)
  review_item_observers <- character(0)

  comment_target_choices <- function() {
    targets <- store_comment_target_catalog(store)
    group <- function(scope, values, label) {
      if (!length(values)) return(character(0))
      setNames(vapply(values, function(x) ig_comment_target_value(scope, x), character(1)), paste(label, values))
    }
    c(
      "Project" = ig_comment_target_value("project", "project"),
      group("node", targets$nodes, "Node:"),
      group("table", targets$tables, "Table:"),
      group("output", targets$outputs, "Output:")
    )
  }

  active_comment_target <- function() {
    node <- isolate(store$active_node)
    targets <- store_comment_target_catalog(store)
    if (!is.null(node) && node %in% targets$nodes)
      return(ig_comment_target_value("node", node))
    if (!is.null(node) && node %in% targets$tables)
      return(ig_comment_target_value("table", node))
    if (!is.null(node) && node %in% targets$outputs)
      return(ig_comment_target_value("output", node))
    ig_comment_target_value("project", "project")
  }

  split_target <- function(x) {
    ig_parse_comment_target(x)
  }

  scope_icon <- function(scope) switch(scope %||% "project",
    node = "diagram-project", table = "table", output = "cube", "folder-open")

  show_comments_modal <- function() {
    showModal(modalDialog(
      title = div(icon("comments"), " Comments"),
      size = "l",
      easyClose = TRUE,
      footer = modalButton("Close"),
      div(class = "ig-collab-modal",
        # Compose form
        div(class = "ig-collab-new",
          div(class = "row g-2",
            div(class = "col-md-7",
              selectInput("comment_target", "Attach to",
                choices = comment_target_choices(), selected = active_comment_target(),
                width = "100%")),
            div(class = "col-md-5",
              textInput("comment_title", "Title (optional)", value = "",
                placeholder = "Short title", width = "100%"))
          ),
          textAreaInput("comment_body", sr_label("Comment"), value = "", rows = 2, width = "100%",
            placeholder = "Add a comment, question, or review note\u2026"),
          div(class = "d-flex gap-2",
            actionButton("comment_add", "Comment", icon = icon("paper-plane"),
              class = "btn btn-sm btn-primary"),
            actionButton("review_issue_add", "Raise issue", icon = icon("triangle-exclamation"),
              class = "btn btn-sm btn-outline-warning")
          )
        ),
        # Static filter — lives outside the re-rendered list so it never loses focus
        div(class = "ig-collab-search mt-3",
          tags$span(class = "ig-collab-search-icon", icon("magnifying-glass")),
          tags$input(id = "comment_filter", type = "text",
            class = "ig-collab-search-field", placeholder = "Filter comments\u2026",
            autocomplete = "off", spellcheck = "false",
            oninput = "Shiny.setInputValue('comment_filter', this.value, {priority:'event'})")
        ),
        uiOutput("comments_threads_ui")
      )
    ))
  }

  output$comments_threads_ui <- renderUI({
    threads <- unname((store$collaboration$comments %||% list()))
    q <- tolower(input$comment_filter %||% "")
    if (!length(threads)) {
      return(div(class = "ig-collab-empty",
        icon("comments"), " No comments yet \u2014 start the conversation above."))
    }
    # Newest activity first
    ord <- order(vapply(threads, function(t)
      t$updated_at %||% t$created_at %||% "", character(1)), decreasing = TRUE)
    cards <- lapply(threads[ord], function(thread) {
      body <- paste(vapply(thread$comments %||% list(), function(c) c$text %||% "",
        character(1)), collapse = " ")
      hay <- tolower(paste(thread$title, thread$scope, thread$target_id, body))
      if (nzchar(q) && !grepl(q, hay, fixed = TRUE)) return(NULL)
      resolved  <- identical(thread$status %||% "", "resolved")
      n_msgs    <- length(thread$comments %||% list())
      div(class = paste("ig-comment-thread", if (resolved) "is-resolved"),
        div(class = "ig-comment-head",
          span(class = "ig-collab-target", title = paste(thread$scope, thread$target_id),
            icon(scope_icon(thread$scope)), " ", thread$target_id %||% "project"),
          strong(class = "ig-comment-title", thread$title %||% "(untitled)"),
          if (resolved)
            span(class = "ig-collab-pill ig-pill-resolved", icon("check"), " Resolved")
          else span(class = "ig-collab-pill ig-pill-open", "Open"),
          span(class = "ms-auto ig-collab-meta",
            sprintf("%d message%s", n_msgs, if (n_msgs == 1L) "" else "s"))
        ),
        div(class = "ig-comment-list",
          lapply(thread$comments %||% list(), function(comment) {
            au <- comment$author %||% "Reviewer"
            div(class = "ig-comment-msg",
              span(class = "ig-avatar",
                style = sprintf("background:%s;", ig_avatar_color(au)),
                ig_initials(au)),
              div(class = "ig-comment-bubble",
                div(class = "ig-comment-byline",
                  strong(au),
                  span(class = "ig-collab-meta", title = ig_time_full(comment$created_at),
                    ig_time_ago(comment$created_at))),
                div(class = "ig-comment-text", comment$text %||% "")))
          })
        ),
        div(class = "ig-comment-actions",
          div(class = "flex-grow-1",
            textInput(paste0("reply_", thread$id), sr_label("Reply"),
              placeholder = "Reply\u2026", width = "100%")),
          actionButton(paste0("reply_btn_", thread$id), "Reply", icon = icon("reply"),
            class = "btn btn-xs btn-outline-secondary"),
          actionButton(paste0("resolve_btn_", thread$id),
            if (resolved) "Reopen" else "Resolve",
            icon = icon(if (resolved) "rotate-left" else "check"),
            class = "btn btn-xs btn-outline-secondary")
        )
      )
    })
    cards <- Filter(Negate(is.null), cards)
    if (length(cards)) tagList(cards)
    else div(class = "ig-collab-empty", "No comments match your filter.")
  })

  observeEvent(input$comment_add, {
    target <- split_target(input$comment_target)
    title <- trimws(input$comment_title %||% "")
    body <- trimws(input$comment_body %||% "")
    if (!nzchar(body)) {
      showNotification("Enter a comment before adding a thread.", type = "warning")
      return()
    }
    if (!nzchar(title)) title <- paste("Comment on", target$id)
    store_add_comment_thread(store, target$scope, target$id, title, body)
    updateTextInput(session, "comment_title", value = "")
    updateTextAreaInput(session, "comment_body", value = "")
  })

  observeEvent(input$review_issue_add, {
    target <- split_target(input$comment_target)
    title <- trimws(input$comment_title %||% "")
    body <- trimws(input$comment_body %||% "")
    if (!nzchar(title)) title <- paste("Review issue for", target$id)
    store_add_review_item(store, target$scope, target$id, title, body)
    if (nzchar(body)) store_add_comment_thread(store, target$scope, target$id, title, body)
    showNotification("Review issue created.", type = "message")
  })

  observe({
    threads <- unname((store$collaboration$comments %||% list()))
    lapply(threads, function(thread) {
      local({
        tid <- thread$id
        if (tid %in% comment_observers) return(NULL)
        comment_observers <<- c(comment_observers, tid)
        observeEvent(input[[paste0("reply_btn_", tid)]], {
          txt <- trimws(input[[paste0("reply_", tid)]] %||% "")
          if (nzchar(txt)) {
            store_add_comment_reply(store, tid, txt)
            updateTextInput(session, paste0("reply_", tid), value = "")
          }
        }, ignoreInit = TRUE)
        observeEvent(input[[paste0("resolve_btn_", tid)]], {
          current <- store_collaboration(store)$comments[[tid]]$status %||% "open"
          store_set_comment_status(store, tid,
            if (identical(current, "resolved")) "open" else "resolved")
        }, ignoreInit = TRUE)
      })
    })
  })

  show_review_modal <- function() {
    showModal(modalDialog(
      title = div(icon("clipboard-check"), " Review Dashboard"),
      size = "xl",
      easyClose = TRUE,
      footer = modalButton("Close"),
      uiOutput("review_dashboard_ui")
    ))
  }

  output$review_dashboard_ui <- renderUI({
    review <- ig_normalize_collaboration(store$collaboration)$review
    items  <- unname(review$items %||% list())
    unresolved <- Filter(function(x) !identical(x$status %||% "open", "resolved"), items)
    resolved_n <- length(items) - length(unresolved)
    st <- review$status %||% "draft"
    st_class <- switch(st, approved = "ig-pill-approved", rejected = "ig-pill-rejected",
      changes_requested = "ig-pill-changes", "ig-pill-draft")
    st_label <- switch(st, changes_requested = "Changes requested",
      approved = "Approved", rejected = "Rejected", "Draft")

    div(class = "ig-review-dashboard",
      # Status banner
      div(class = "ig-review-banner",
        span(class = paste("ig-collab-pill", st_class), st_label),
        span(class = "ig-collab-meta",
          sprintf("%d open \u00b7 %d resolved", length(unresolved), resolved_n)),
        div(class = "form-check form-switch ms-auto mb-0",
          tags$input(class = "form-check-input", type = "checkbox", role = "switch",
            id = "review_mode_toggle",
            onchange = "Shiny.setInputValue('review_mode_toggle', this.checked)",
            checked = if (isTRUE(store$review_mode)) "checked"),
          tags$label(class = "form-check-label small", `for` = "review_mode_toggle",
            "Read-only review mode"))
      ),
      # Decision actions
      div(class = "d-flex gap-2 my-3",
        actionButton("review_approve", "Approve", icon = icon("check"),
          class = paste("btn btn-sm", if (identical(st, "approved")) "btn-success" else "btn-outline-success")),
        actionButton("review_changes", "Request changes", icon = icon("pen"),
          class = paste("btn btn-sm", if (identical(st, "changes_requested")) "btn-warning" else "btn-outline-warning")),
        actionButton("review_reject", "Reject", icon = icon("xmark"),
          class = paste("btn btn-sm", if (identical(st, "rejected")) "btn-danger" else "btn-outline-danger"))
      ),
      tags$h6(class = "ig-collab-section", "Outstanding issues"),
      if (length(unresolved)) {
        div(class = "ig-issue-list", lapply(unresolved, function(item) {
          sev <- item$severity %||% "change"
          div(class = "ig-issue-card",
            span(class = paste0("ig-sev-dot ig-sev-", sev)),
            div(class = "flex-grow-1",
              div(class = "ig-issue-title", strong(item$title %||% item$id)),
              if (nzchar(item$detail %||% "")) div(class = "ig-issue-detail", item$detail),
              div(class = "ig-collab-meta",
                icon(scope_icon(item$scope)), " ", item$target_id %||% "project",
                " \u00b7 ", span(title = ig_time_full(item$created_at), ig_time_ago(item$created_at)))),
            actionButton(paste0("resolve_issue_", item$id), "Resolve", icon = icon("check"),
              class = "btn btn-xs btn-outline-secondary align-self-center"))
        }))
      } else div(class = "ig-collab-empty", icon("circle-check"), " No outstanding issues."),
      tags$h6(class = "ig-collab-section mt-3", "Review activity"),
      if (length(review$history %||% list())) {
        div(class = "ig-review-timeline", lapply(rev(review$history %||% list()), function(event) {
          act <- event$action %||% ""
          ic <- switch(act, approve = "check", reject = "xmark",
            request_changes = "pen", issue_created = "triangle-exclamation", "circle")
          div(class = "ig-timeline-row",
            span(class = paste0("ig-timeline-icon ig-tl-", gsub("_", "-", act)), icon(ic)),
            div(span(class = "ig-tl-action", gsub("_", " ", act)),
              " \u2014 ", event$author %||% "",
              if (nzchar(event$detail %||% "")) span(class = "text-muted", paste0(": ", event$detail)),
              div(class = "ig-collab-meta", title = ig_time_full(event$created_at),
                ig_time_ago(event$created_at))))
        }))
      } else div(class = "ig-collab-empty", "No review activity yet.")
    )
  })

  observeEvent(input$review_mode_toggle, {
    store$review_mode <- isTRUE(input$review_mode_toggle)
    store_add_history(store, "review", "project", "mode",
      if (store$review_mode) "Read-only review mode enabled" else "Read-only review mode disabled")
  }, ignoreInit = TRUE)
  observeEvent(input$review_approve, { store_set_review_decision(store, "approve") })
  observeEvent(input$review_reject, { store_set_review_decision(store, "reject") })
  observeEvent(input$review_changes, { store_set_review_decision(store, "request_changes") })
  observe({
    items <- unname((store$collaboration$review$items %||% list()))
    lapply(items, function(item) {
      local({
        iid <- item$id
        if (iid %in% review_item_observers) return(NULL)
        review_item_observers <<- c(review_item_observers, iid)
        observeEvent(input[[paste0("resolve_issue_", iid)]], {
          store_set_review_item_status(store, iid, "resolved")
        }, ignoreInit = TRUE)
      })
    })
  })

  show_history_modal <- function() {
    showModal(modalDialog(
      title = div(icon("clock-rotate-left"), " Change History"),
      size = "xl", easyClose = TRUE, footer = modalButton("Close"),
      fluidRow(
        column(4, selectInput("history_type", "Object type",
          choices = c("All" = "", "Task" = "task", "Dataset" = "dataset",
                      "Flow" = "flow", "Output" = "output", "Review" = "review",
                      "Comment" = "comment", "Settings" = "settings"))),
        column(4, textInput("history_user", "User filter", value = "")),
        column(4, textInput("history_query", "Text filter", value = ""))
      ),
      DT::DTOutput("history_dt")
    ))
  }

  output$history_dt <- DT::renderDT({
    events <- rev(store$collaboration$history %||% list())
    rows <- if (length(events)) do.call(rbind, lapply(events, function(e) {
      data.frame(
        when = ig_time_full(e$created_at %||% ""),
        user = e$user %||% "",
        type = e$object_type %||% "",
        id = e$object_id %||% "",
        action = e$action %||% "",
        summary = e$summary %||% "",
        stringsAsFactors = FALSE
      )
    })) else data.frame(when = character(), user = character(), type = character(),
      id = character(), action = character(), summary = character())
    if (nzchar(input$history_type %||% "")) rows <- rows[rows$type == input$history_type, , drop = FALSE]
    if (nzchar(input$history_user %||% "")) rows <- rows[grepl(tolower(input$history_user), tolower(rows$user), fixed = TRUE), , drop = FALSE]
    if (nzchar(input$history_query %||% "")) {
      q <- input$history_query
      rows <- rows[grepl(tolower(q), tolower(paste(rows$id, rows$action, rows$summary)), fixed = TRUE), , drop = FALSE]
    }
    DT::datatable(rows, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  show_search_modal <- function() {
    showModal(modalDialog(
      title = div(icon("magnifying-glass"), " Global Search"),
      size = "l", easyClose = TRUE, footer = modalButton("Close"),
      div(class = "ig-collab-search mb-2",
        tags$span(class = "ig-collab-search-icon", icon("magnifying-glass")),
        tags$input(id = "global_search_query", type = "text",
          class = "ig-collab-search-field",
          placeholder = "Tasks, datasets, variables, outputs, code, comments\u2026",
          autocomplete = "off", spellcheck = "false",
          oninput = "Shiny.setInputValue('global_search_query', this.value, {priority:'event'})")),
      div(class = "ig-collab-meta mb-2", textOutput("global_search_count", inline = TRUE)),
      DT::DTOutput("global_search_dt")
    ))
  }

  output$global_search_count <- renderText({
    q <- trimws(input$global_search_query %||% "")
    if (!nzchar(q)) return("Type to search across the project.")
    n <- nrow(store_search(store, q))
    sprintf("%d result%s for \u201c%s\u201d", n, if (n == 1L) "" else "s", q)
  })

  output$global_search_dt <- DT::renderDT({
    rows <- store_search(store, input$global_search_query %||% "")
    DT::datatable(rows[, c("type", "id", "label"), drop = FALSE],
      selection = "single", rownames = FALSE, colnames = c("Type", "ID", "Name"),
      options = list(pageLength = 10, dom = "tp"))
  })

  observeEvent(input$global_search_dt_rows_selected, {
    rows <- store_search(store, input$global_search_query %||% "")
    i <- input$global_search_dt_rows_selected
    if (!length(i) || i > nrow(rows)) return()
    hit <- rows[i, , drop = FALSE]
    removeModal()
    if (identical(hit$type[[1]], "task")) open_task_by_id(hit$id[[1]])
    else if (identical(hit$type[[1]], "dataset")) show_dataset_preview(hit$id[[1]])
    else if (identical(hit$type[[1]], "output")) show_object_preview(hit$id[[1]])
    else show_comments_modal()
  })

  # Header buttons with live count badges (open comment threads / review issues).
  output$hdr_comments_btn <- renderUI({
    n <- length(Filter(function(t) !identical(t$status %||% "", "resolved"),
      unname(store_ui_read(store, "comments", store$collaboration$comments %||% list()))))
    tags$button(id = "btn_comments", type = "button",
      class = "btn btn-sm ig-header-btn action-button position-relative",
      title = "Comments", `aria-label` = "Comments",
      icon("comments"),
      if (n > 0L) span(class = "ig-header-badge", as.character(n)))
  })
  output$hdr_review_btn <- renderUI({
    review <- store_ui_read(store, "review", ig_normalize_collaboration(store$collaboration)$review)
    n <- length(Filter(function(x) !identical(x$status %||% "open", "resolved"),
      unname(review$items %||% list())))
    st <- review$status %||% "draft"
    dot <- switch(st, approved = "#22c55e", rejected = "#ef4444",
                  changes_requested = "#f59e0b", NULL)
    tags$button(id = "btn_review", type = "button",
      class = "btn btn-sm ig-header-btn action-button position-relative",
      title = paste0("Review dashboard (", gsub("_", " ", st), ")"),
      `aria-label` = "Review dashboard",
      icon("clipboard-check"),
      if (!is.null(dot)) span(class = "ig-header-dot", style = sprintf("background:%s;", dot)),
      if (n > 0L) span(class = "ig-header-badge ig-badge-warn", as.character(n)))
  })

  observeEvent(input$btn_search,   { show_search_modal() })
  observeEvent(input$btn_comments, { show_comments_modal() })
  observeEvent(input$btn_review,   { show_review_modal() })
  observeEvent(input$btn_history,  { show_history_modal() })
  observeEvent(input$btn_help,      { showModal(help_modal_ui()) })
  observeEvent(input$btn_shortcuts, { show_shortcuts_modal() })
  observeEvent(input$shortcut_help, { show_shortcuts_modal() })
  observeEvent(input$btn_settings,  { show_settings_modal() })

  observe({
    session$sendCustomMessage("ig_theme_mode", theme_mode())
  })

  # ── Unsaved-changes indicator ─────────────────────────────────────────────────
  # Mirrors store$dirty to the browser: an amber dot on the Save button plus a
  # beforeunload warning so closing the tab can't silently lose work.
  observe({
    session$sendCustomMessage("ig_dirty", isTRUE(store$dirty))
  })

  show_settings_modal <- function() {
    s <- isolate(store$settings) %||% ig_default_settings()
    showModal(modalDialog(
      title = div(icon("gear"), " Settings"),
      size = "m",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("settings_apply", "Apply", class = "btn btn-primary")
      ),
      selectInput("settings_language", "Language",
        choices = c("English" = "en-CA", "Français (Canada)" = "fr-CA"),
        selected = ig_language(), width = "100%"),
      p(class = "small text-muted", "Language is saved on this computer, not in the project.",
        " Language changes take effect immediately."),
      radioButtons("settings_theme_mode", "Appearance",
        choices = c("Dark" = "dark", "Light" = "light"),
        selected = theme_mode(), inline = TRUE,
        width = "100%"),
      selectInput("settings_page_length", "Preview rows per page",
        choices = c(10, 15, 25, 50, 100),
        selected = s$page_length %||% 10L, width = "100%"),
      bslib::layout_columns(
        col_widths = c(6, 6),
        selectInput("settings_plot_theme", "Default plot theme (new graphs)",
          choices = c("Clean" = "clean", "Publication" = "publication",
                      "Minimal" = "minimal", "Classic" = "classic",
                      "Light" = "light", "Dark" = "dark"),
          selected = s$plot_theme %||% "clean", width = "100%"),
        selectInput("settings_palette", "Default palette (new graphs)",
          choices = c("Individual Guide" = "ig", "Okabe-Ito" = "okabe_ito",
                      "Tableau" = "tableau", "Viridis" = "viridis",
                      "Grey" = "grey"),
          selected = s$palette %||% "ig", width = "100%")
      ),
      checkboxInput("settings_stop_on_error",
        "Stop Run Flow at the first failing task",
        value = isTRUE(s$stop_on_error), width = "100%"),
      checkboxInput("settings_confirm_delete",
        "Ask for confirmation before deleting tasks and flows",
        value = !isFALSE(s$confirm_delete), width = "100%"),
      numericInput("settings_backup_versions", "Previous saved versions to keep (0–100)", value = s$backup_versions %||% 20L, min = 0L, max = 100L, step = 1L),
      checkboxInput("settings_fixed_seed", "Use a fixed project random seed", value = !is.null(s$run_seed)),
      numericInput("settings_run_seed", "Project random seed", value = s$run_seed %||% 123L, min = 0L, max = .Machine$integer.max, step = 1L),
      checkboxInput("settings_background_tasks", "Run supported tasks in the background", value = !isFALSE(s$background_tasks)),
      p(class = "text-muted small mb-0",
        icon("circle-info"),
        " Other settings are saved with the project and restored on load.")
    ))
  }

  show_shortcuts_modal <- function() {
    shortcut_row <- function(keys, action) {
      tags$tr(
        tags$td(class = "ig-shortcut-keys",
          tagList(lapply(keys, function(key) tags$kbd(key)))),
        tags$td(action)
      )
    }
    showModal(modalDialog(
      title = div(icon("keyboard"), " Keyboard shortcuts"),
      size = "m",
      easyClose = TRUE,
      footer = modalButton("Close"),
      tags$div(class = "ig-shortcuts-modal",
        tags$p(class = "text-muted small",
          "Shortcuts are ignored while typing in text fields, selectors, code editors, or editable content."),
        tags$table(class = "table table-sm ig-shortcuts-table",
          tags$thead(tags$tr(tags$th("Keys"), tags$th("Action"))),
          tags$tbody(
            shortcut_row(c("Tab"), "Move through focusable controls."),
            shortcut_row(c("Enter", "Space"), "Activate a focused tree item, button, or tab."),
            shortcut_row(c("Arrow Left", "Arrow Right"), "Move between tabs when a tab has focus."),
            shortcut_row(c("Home", "End"), "Jump to the first or last tab when a tab has focus."),
            shortcut_row(c("Delete"), "Close the focused task tab."),
            shortcut_row(c("Ctrl", "Alt", "Left / Right"), "Move to the previous or next tab from anywhere."),
            shortcut_row(c("Ctrl", "Alt", "W"), "Close the active task tab."),
            shortcut_row(c("Ctrl", "Alt", "F"), "Open the Process Flow tab."),
            shortcut_row(c("Ctrl", "Alt", "K"), "Open the Code tab."),
            shortcut_row(c("Ctrl", "Alt", "C"), "Open the R Console tab."),
            shortcut_row(c("Ctrl", "Enter"), "Run code in the R Console editor."),
            shortcut_row(c("Alt", "Up / Down"), "Recall R Console commands, keeping the current draft."),
            shortcut_row(c("Ctrl", "Alt", "N"), "Open Add Task."),
            shortcut_row(c("Ctrl", "Alt", "R"), "Run the active flow."),
            shortcut_row(c("Ctrl", "Alt", "S"), "Save the project."),
            shortcut_row(c("Ctrl", "Alt", "Z"), "Undo the last delete."),
            shortcut_row(c("Ctrl", "Alt", "/"), "Open this shortcut reference.")
          )
        )
      )
    ))
  }

  observeEvent(input$settings_apply, {
    if (review_edit_blocked("change settings")) return()
    count <- input$settings_backup_versions %||% 20L
    seed <- input$settings_run_seed %||% 123L
    if (length(count) != 1L || !is.finite(count) || count < 0 || count > 100 || count != floor(count) ||
        (isTRUE(input$settings_fixed_seed) && (length(seed) != 1L || !is.finite(seed) || seed < 0 || seed > .Machine$integer.max || seed != floor(seed)))) {
      showNotification("Enter a whole backup count from 0 to 100 and a valid nonnegative integer seed.", type = "error"); return()
    }
    old_settings <- isolate(store$settings)
    theme_mode(input$settings_theme_mode %||% "dark")
    store$settings <- list(
      page_length    = as.integer(input$settings_page_length %||% 10L),
      plot_theme     = input$settings_plot_theme %||% "clean",
      palette        = input$settings_palette %||% "ig",
      stop_on_error  = isTRUE(input$settings_stop_on_error),
      confirm_delete = isTRUE(input$settings_confirm_delete),
      backup_versions = as.integer(count),
      run_seed = if (isTRUE(input$settings_fixed_seed)) as.integer(seed) else NULL,
      background_tasks = !identical(input$settings_background_tasks, FALSE)
    )
    store$dirty <- TRUE
    store_add_history(store, "settings", "project", "update",
      "Project settings changed", before = old_settings, after = isolate(store$settings))
    removeModal()
  })

  # Canvas node click → open the task's panel
  handle_node_open <- function(node) {
    req(!is.null(node))
    if (node %in% names(isolate(store$tasks))) {
      open_task_panel(node, focus_tab = TRUE)
    } else if (node %in% store_table_names(store)) {
      if (node %in% names(isolate(store$sources))) {
        meta <- isolate(store$sources[[node]])
        if (!is.null(meta$task_id)) open_task_by_id(meta$task_id)
        else show_dataset_preview(node)
      } else {
        show_dataset_preview(node)
      }
    } else if (node %in% store_object_names(store)) {
      show_object_preview(node)
    }
  }

  observeEvent(store$active_node, {
    handle_node_open(store$active_node)
  })

  show_dataset_preview <- function(table_name) {
    df <- isolate(store$tables[[table_name]])
    if (is.null(df)) {
      showNotification(
        sprintf("'%s' has no data yet \u2014 run the task first.", table_name),
        type = "warning", duration = 5)
      return(invisible(NULL))
    }
    # Always update both name and trigger so renderDT re-fires even when the
    # same table is opened twice consecutively.
    preview_table_name(table_name)
    preview_trigger(isolate(preview_trigger()) + 1L)
    nr <- nrow(df); nc <- ncol(df)
    showModal(modalDialog(
      title     = div(icon("table"), " ", table_name),
      size      = "xl",
      easyClose = TRUE,
      footer    = div(
        class = "d-flex align-items-center gap-2 w-100",
        # Export controls on the left
        icon("download", class = "text-muted"),
        span(class = "text-muted small", `aria-hidden` = "true", "Export as:"),
        selectInput("export_format", sr_label("Export format"),
                    choices = c(
                      "CSV (.csv)"           = "csv",
                      "Tab-delimited (.txt)" = "tsv",
                      "Excel (.xlsx)"        = "xlsx",
                      "RDS (.rds)"           = "rds"
                    ),
                    width = "170px"),
        downloadButton("dataset_export_dl", "Download",
                       class = "btn btn-sm btn-outline-secondary"),
        # Push Close to the right
        div(class = "ms-auto", modalButton("Close"))
      ),
      div(class = "ig-dataset-preview-meta",
        formatC(nr, format = "d", big.mark = ","), " rows  \u00d7  ", nc, " columns"),
      DT::DTOutput("dataset_preview_dt")
    ))
  }

  output$dataset_preview_dt <- DT::renderDT({
    preview_trigger()                      # re-render whenever preview opens
    nm <- preview_table_name()
    req(!is.null(nm))
    df <- isolate(store$tables[[nm]])
    req(!is.null(df))
    DT::datatable(
      head(df, 1000L),
      options  = list(scrollX = TRUE, pageLength = ig_page_len(store), dom = "tip"),
      rownames = FALSE
    )
  })

  show_object_preview <- function(object_name) {
    obj_rec <- isolate(store$objects[[object_name]])
    if (is.null(obj_rec)) {
      showNotification(
        sprintf("'%s' has no object yet \u2014 run the task first.", object_name),
        type = "warning", duration = 5)
      return(invisible(NULL))
    }
    obj <- obj_rec$value
    preview_object_name(object_name)
    showModal(modalDialog(
      title = div(icon("cube"), " ", object_name),
      size = "xl",
      easyClose = TRUE,
      footer = div(
        class = "d-flex align-items-center gap-2 w-100",
        icon("download", class = "text-muted"),
        if (inherits(obj, "ggplot"))
          downloadButton("object_export_png_dl", "Download PNG",
            class = "btn btn-sm btn-outline-secondary"),
        if (inherits(obj, "girafe"))
          downloadButton("object_export_html_dl", "Download HTML",
            class = "btn btn-sm btn-outline-secondary"),
        downloadButton("object_export_dl", "Download RDS",
          class = "btn btn-sm btn-outline-secondary"),
        div(class = "ms-auto", modalButton("Close"))
      ),
      if (inherits(obj, "girafe")) {
        ggiraph::girafeOutput("object_preview_plot", height = "10cm")
      } else if (inherits(obj, "ggplot")) {
        plotOutput("object_preview_ggplot", height = "10cm")
      } else if (inherits(obj, "waldo_compare")) {
        uiOutput("object_preview_waldo")
      } else {
        verbatimTextOutput("object_preview_str")
      }
    ))
    output$object_preview_plot <- ggiraph::renderGirafe({
      req(inherits(obj, "girafe"))
      obj
    })
    output$object_preview_ggplot <- renderPlot({
      req(inherits(obj, "ggplot"))
      print(obj)
    })
    output$object_preview_waldo <- renderUI({
      req(inherits(obj, "waldo_compare"))
      waldo_compare_html(obj)
    })
    output$object_preview_str <- renderPrint({
      utils::str(obj, max.level = 2)
    })
  }

  output$object_export_dl <- downloadHandler(
    filename = function() {
      paste0(preview_object_name() %||% "object", ".rds")
    },
    content = function(file) {
      nm <- preview_object_name()
      obj_rec <- isolate(store$objects[[nm]])
      if (is.null(obj_rec)) return(invisible(NULL))
      saveRDS(obj_rec$value, file)
    }
  )

  output$object_export_png_dl <- downloadHandler(
    filename = function() paste0(preview_object_name() %||% "plot", ".png"),
    content = function(file) {
      nm <- preview_object_name()
      obj_rec <- isolate(store$objects[[nm]])
      if (is.null(obj_rec) || !inherits(obj_rec$value, "ggplot")) return(invisible(NULL))
      ggplot2::ggsave(file, obj_rec$value, width = 16, height = 10, units = "cm", dpi = 150)
    }
  )

  output$object_export_html_dl <- downloadHandler(
    filename = function() paste0(preview_object_name() %||% "plot", ".html"),
    content = function(file) {
      nm <- preview_object_name()
      obj_rec <- isolate(store$objects[[nm]])
      if (is.null(obj_rec) || !inherits(obj_rec$value, "girafe")) return(invisible(NULL))
      writeLines(ig_report_widget_html(obj_rec$value), file, useBytes = TRUE)
    }
  )

  # ── Dataset export ────────────────────────────────────────────────────────────
  output$dataset_export_dl <- downloadHandler(
    filename = function() {
      nm  <- preview_table_name() %||% "export"
      fmt <- input$export_format  %||% "csv"
      ext <- switch(fmt, csv = ".csv", tsv = ".txt", xlsx = ".xlsx", rds = ".rds", ".csv")
      paste0(nm, ext)
    },
    content = function(file) {
      nm  <- preview_table_name()
      df  <- isolate(store$tables[[nm]])
      if (is.null(df)) return(invisible(NULL))
      fmt <- input$export_format %||% "csv"
      switch(fmt,
        csv  = readr::write_csv(df, file),
        tsv  = readr::write_tsv(df, file),
        xlsx = writexl::write_xlsx(df, file),
        rds  = saveRDS(df, file)
      )
    }
  )

  # ── Task picker modal ─────────────────────────────────────────────────────────
  # Helper: build one task row with star button + click-to-add
  .picker_task_row <- function(t, favs) {
    avail   <- isTRUE(t$available)
    is_fav  <- t$id %in% favs
    star_cls <- paste("ig-picker-star", if (is_fav) "ig-picker-star--on" else "ig-picker-star--off")
    div(
      class        = paste("ig-task-item", if (avail) "ig-key-activate",
                           if (!avail) "ig-task-unavailable"),
      `data-label` = tolower(t$label),
      role         = if (avail) "button" else "listitem",
      tabindex     = if (avail) "0" else NULL,
      `aria-disabled` = if (!avail) "true" else NULL,
      onclick      = if (avail)
        ig_input_event_js("picker_select", t$id)
      else NULL,
      div(class = "ig-task-item-inner",
        # Star toggle (stop propagation so clicking star doesn't also add the task)
        tags$button(
          class   = star_cls,
          type    = "button",
          title   = if (is_fav) "Remove from favourites" else "Add to favourites",
          `aria-label` = paste(
            if (is_fav) "Remove" else "Add", t$label,
            if (is_fav) "from favourites" else "to favourites"),
          `aria-pressed` = if (is_fav) "true" else "false",
          onclick = ig_input_event_js("picker_fav_toggle", t$id, stop_propagation = TRUE),
          icon(if (is_fav) "star" else "star", class = "ig-star-icon")
        ),
        icon(t$icon, class = "ig-task-icon"),
        div(
          div(class = "ig-task-label", t$label,
            if (!avail) span(class = "ig-phase-badge", paste0("Phase ", t$phase))),
          div(class = "ig-task-desc",  t$desc)
        )
      )
    )
  }

  # Helper: build a collapsible category group
  .picker_cat_group <- function(cat_label, task_list, favs, expanded = FALSE) {
    group_id <- paste0("picker_cat_", gsub("[^a-z0-9]", "_", tolower(cat_label)))
    rows <- lapply(task_list, .picker_task_row, favs = favs)
    div(
      class = "ig-picker-group",
      # Search restores this state when the query is cleared
      `data-default-expanded` = if (expanded) "true" else "false",
      div(
        class   = "ig-task-category ig-picker-group-header ig-key-activate",
        # Keyboard-operable disclosure: Enter/Space activate via the shared
        # ig-key-activate handler; aria-expanded is kept in sync by JS.
        role            = "button",
        tabindex        = "0",
        `aria-expanded` = if (expanded) "true" else "false",
        `aria-controls` = group_id,
        onclick = sprintf("igPickerToggle('%s')", group_id),
        # caret starts at -90deg (right arrow) for collapsed groups, 0deg for expanded
        span(class = paste("ig-tree-caret", if (!expanded) "ig-picker-open"),
          icon("chevron-down")),
        cat_label,
        span(class = "ig-picker-count",
          `aria-label` = sprintf("%d tasks", length(task_list)),
          length(task_list))
      ),
      div(
        id    = group_id,
        class = paste("ig-picker-group-body", if (!expanded) "ig-picker-collapsed"),
        do.call(tagList, rows)
      )
    )
  }

  show_task_picker <- function() {
    favs <- isolate(store$task_favourites) %||% character(0)

    # Favourites section (always expanded, shown at top)
    fav_tasks   <- Filter(function(t) t$id %in% favs, TASK_REGISTRY)
    fav_section <- if (length(fav_tasks) > 0L) {
      .picker_cat_group("\u2605  Favourites", fav_tasks, favs, expanded = TRUE)
    } else NULL

    # Other categories (collapsed by default)
    cats       <- task_categories()
    cat_groups <- lapply(cats, function(cat) {
      .picker_cat_group(cat, tasks_for_category(cat), favs, expanded = FALSE)
    })

    showModal(modalDialog(
      title     = div(class = "d-flex align-items-center gap-3",
        icon("list-check"), "Add Task"),
      size      = "m",
      footer    = modalButton("Cancel"),
      easyClose = TRUE,
      div(
        textInput("task_search", sr_label("Search tasks"),
          placeholder = "Search tasks\u2026", width = "100%"),
        div(class = "ig-task-list",
          fav_section,
          do.call(tagList, cat_groups))
      )
    ))
  }

  observeEvent(input$picker_select, {
    type_id <- input$picker_select
    removeModal()
    create_task(type_id)
  })
  observeEvent(input$console_create_script, {
    if (structural_edit_blocked("create a Script task")) return()
    request <- input$console_create_script
    if (!is.list(request)) return()
    result <- tryCatch(ig_console_script_params(request$code, store), error = function(error) {
      showNotification(conditionMessage(error), type = "error"); NULL
    })
    if (is.null(result)) return()
    id <- store_next_id(store, "script")
    task <- store_task_from_params(task_def(id, "script"), result$params)
    task$label <- "Console script"
    store_set_task(store, task)
    open_task_panel(id, focus_tab = TRUE)
    if (length(result$missing)) showNotification(paste0("Script created. Include setup for console-only variables: ",
      paste(result$missing, collapse = ", "), "."), type = "warning", duration = 10)
    else showNotification("Script created with project inputs and inferred outputs. Review it before running.")
  })

  # Toggle a task type's favourite status and re-open the picker
  observeEvent(input$picker_fav_toggle, {
    tid  <- input$picker_fav_toggle
    favs <- isolate(store$task_favourites) %||% character(0)
    if (tid %in% favs) {
      store$task_favourites <- setdiff(favs, tid)
    } else {
      store$task_favourites <- c(favs, tid)
    }
    # Re-open the picker so the star state refreshes
    show_task_picker()
  }, ignoreInit = TRUE)

  # ── Project open / save (shinyFiles) ──────────────────────────────────────────
  # shinyFiles gives an in-app file browser that returns REAL server-side paths,
  # so Save can overwrite the project in place. Unlike the OS choose.files dialog
  # it is non-blocking and works whether the app is run locally or served. The
  # actual picker buttons (sf_open / sf_save_as) live hidden in the sidebar and
  # are triggered from the header / splash via the ig_click custom message.
  file_roots <- ig_volumes(refresh = TRUE)
  shinyFiles::shinyFileChoose(input, "sf_open", roots = file_roots,
    filetypes = c("igpx", "igp", "rds"))
  shinyFiles::shinyFileSave(input, "sf_save_as", roots = file_roots,
    filetypes = c("igpx"))

  # Load from a real on-disk path: project_load records it as store$project_path,
  # so a later Save overwrites this exact file.
  load_from_local_path <- function(path, source_path = path) {
    if (length(isolate(store$run_ids)) || !is.null(isolate(store$background$job))) {
      showNotification("Wait for the running flow to finish before opening another project.", type = "warning")
      return(invisible(FALSE))
    }
    if (length(path) != 1L || is.na(path) || !nzchar(path) || !file.exists(path))
      return(invisible(FALSE))
    result <- tryCatch(project_load(store, path, source_path),
      error = function(e) list(ok = FALSE, loaded = FALSE, errors = conditionMessage(e)))
    if (!isTRUE(result$loaded)) {
      showNotification(paste("Could not open project:", paste(result$errors, collapse = " | ")),
        type = "error", duration = 8)
      return(invisible(FALSE))
    }
    project_clear_recovery()
    workspace_welcome(FALSE)
    pending_example(NULL)
    ig_end_task_modules(session)
    for (observers in panel_observer_handles) for (observer in observers) observer$destroy()
    panel_observer_handles <<- list()
    panel_observers <<- character(0)
    selected_tasks(character(0))
    undo_stack(list())
    for (pid in inserted_panels)
      removeUI(selector = paste0("#panel_", pid), immediate = TRUE)
    inserted_panels     <<- character(0)
    initialised_modules <<- character(0)
    tabs_rv$open   <- PERMANENT_TABS
    tabs_rv$active <- "flow"
    session$sendCustomMessage("ig_switch_tab", "flow")

    saved_theme <- result$theme %||% "dark"
    if (saved_theme %in% c("dark", "light")) theme_mode(saved_theme)

    if (!isTRUE(result$ok) && length(result$errors %||% character(0)) > 0L) {
      showModal(modalDialog(
        title  = "Load warnings",
        tagList(lapply(result$errors,
          function(e) p(icon("triangle-exclamation"), e))),
        footer = modalButton("Close")))
    } else {
      showNotification(paste0("Opened ", basename(path)), type = "message", duration = 3)
    }
    records <- isolate(store$run_records)
    if (length(records)) {
      changes <- ig_environment_changes(utils::tail(records, 1)[[1]]$environment)
      if (length(changes)) showNotification(paste0("This project's last run used a different environment: ",
        paste(utils::head(changes, 5), collapse = "; "), ". Inspect Project tools → Run records before reproducing results."), type = "warning", duration = 15)
    }
    invisible(TRUE)
  }

  product <- project_tools_server("project_tools", store,
    load_project = function(path, source_path = path) load_from_local_path(path, source_path),
    open_task = function(id) open_task_by_id(id), theme = function() isolate(theme_mode()),
    relink_task = function(id, path) {
      if (structural_edit_blocked("relink a file")) return(FALSE)
      store_sync_parameters(store)
      if (!id %in% names(isolate(store$tasks))) {
        flows <- isolate(store$flows)
        owners <- names(Filter(function(flow) id %in% names(flow$tasks), flows))
        if (length(owners)) switch_flow(owners[[1L]])
      }
      task <- isolate(store$tasks[[id]])
      if (is.null(task) || !identical(task$type, "import_data")) return(FALSE)
      dispose_task_panel(id)
      task$params$path <- path; task$source_reference <- list(original = path, bundled = FALSE)
      task$r_code <- build_task_code(task)
      store_set_task(store, task)
      open_task_panel(id, focus_tab = TRUE)
      showNotification("Import source updated. Run the task to refresh its data.")
      TRUE
    })
  observeEvent(input$btn_project_tools, product$show())
  observeEvent(input$btn_validate_flow, {
    store_sync_parameters(store)
    showModal(ig_preflight_ui(ig_preflight(store), allow_run = TRUE))
  })
  observeEvent(input$preflight_open_task, {
    if (!input$preflight_open_task %in% names(store_all_tasks(store))) return()
    removeModal(); open_task_by_id(input$preflight_open_task)
  })
  observeEvent(input$preflight_run, { removeModal(); run_whole_flow(isolate(store$active_flow)) })
  observeEvent(input$product_action, {
    action <- input$product_action
    if (action == "about") showModal(ig_about_ui())
    else if (action == "validate") {
      store_sync_parameters(store); showModal(ig_preflight_ui(ig_preflight(store), allow_run = TRUE))
    } else if (action %in% c("versions", "files", "runs", "tasks")) product$show(action)
  })

  reset_project <- function(welcome = FALSE) {
    if (isTRUE(isolate(recovery_pending()))) return(FALSE)
    if (length(isolate(store$run_ids)) || !is.null(isolate(store$background$job))) return(FALSE)
    r_console$reset()
    pending_example(NULL)
    ig_end_task_modules(session)
    for (observers in panel_observer_handles) for (observer in observers) observer$destroy()
    panel_observer_handles <<- list(); panel_observers <<- character(0)
    for (pid in inserted_panels) removeUI(selector = paste0("#panel_", pid), immediate = TRUE)
    inserted_panels <<- character(0); initialised_modules <<- character(0)
    selected_tasks(character(0)); undo_stack(list())
    preview_table_name(NULL); preview_object_name(NULL)
    store_close_connections(store); project_release_assets(store)
    settings <- isolate(store$settings); favourites <- isolate(store$task_favourites)
    ig_background_retire_worker(store)
    background <- isolate(store$background)
    generation <- isolate(store$run_generation) + 1L
    values <- isolate(shiny::reactiveValuesToList(make_store()))
    values$background <- background; values$console <- r_console$state
    for (name in names(values)) store[[name]] <- values[[name]]
    store$run_generation <- generation
    store$settings <- settings; store$task_favourites <- favourites
    fl <- make_flow("Flow 1")
    store$flows <- setNames(list(fl), fl$id); store$active_flow <- fl$id
    tabs_rv$open <- PERMANENT_TABS; tabs_rv$active <- "flow"
    project_clear_recovery()
    workspace_welcome(welcome)
    removeModal()
    session$sendCustomMessage("ig_switch_tab", "flow")
    if (welcome) show_splash()
    TRUE
  }

  # Open: header + splash both pop the shinyFiles open browser.
  open_example_project <- function(id) {
    if (isTRUE(isolate(recovery_pending())) || length(isolate(store$run_ids)) ||
        !is.null(isolate(store$background$job))) return(FALSE)
    tryCatch({
      prepared <- ig_prepare_example(id)
      if (!isTRUE(load_from_local_path(prepared$path))) return(FALSE)
      store$project_path <- NULL
      store$project_name <- prepared$title
      store$dirty <- TRUE
      removeModal()
      showNotification(paste0("Opened ", prepared$title, ". Outputs: ", prepared$directory,
        ". Use Save As to keep your project."), duration = 12)
      TRUE
    }, error = function(error) {
      showNotification(paste("Could not open example:", conditionMessage(error)), type = "error", duration = 8)
      FALSE
    })
  }
  pending_example <- reactiveVal(NULL)
  observeEvent(input$help_example, {
    id <- input$help_example
    if (inherits(try(ig_example_info(id), silent = TRUE), "try-error")) return()
    if (isTRUE(recovery_pending()) || length(store$run_ids) || !is.null(store$background$job)) {
      showNotification("Finish the current run or recovery before opening an example.", type = "warning")
      return()
    }
    store_sync_parameters(store)
    if (!isTRUE(store$dirty)) { open_example_project(id); return() }
    pending_example(id)
    showModal(modalDialog(title = "Open example project?",
      p("Your current project has unsaved changes. Save it first, or discard those changes to open the example."),
      p(class = "small text-muted", "After saving, return to Help → Example projects to open the example."),
      footer = tagList(actionButton("example_cancel", "Cancel"),
        actionButton("example_save", "Save current project…"),
        actionButton("example_discard", "Discard and open example", class = "btn-primary"))))
  })
  observeEvent(input$example_cancel, { pending_example(NULL); showModal(help_modal_ui()) })
  observeEvent(input$example_save, {
    pending_example(NULL); removeModal(); session$sendCustomMessage("ig_click", "btn_save")
  })
  observeEvent(input$example_discard, {
    id <- isolate(pending_example()); pending_example(NULL)
    if (!is.null(id)) open_example_project(id)
  })

  observeEvent(input$btn_open, {
    session$sendCustomMessage("ig_click", "sf_open")
  }, ignoreNULL = FALSE, ignoreInit = TRUE)

  pending_project_open <- reactiveVal(NULL)
  observeEvent(input$sf_open, {
    fi <- tryCatch(shinyFiles::parseFilePaths(file_roots, input$sf_open),
                   error = function(e) NULL)
    if (is.null(fi) || nrow(fi) == 0L) return()
    path <- as.character(fi$datapath)[1]
    pending_project_open(list(path = path, hash = digest::digest(file = path, algo = "sha256")))
    showModal(modalDialog(title = "Trust this project?",
      p("Projects can contain R code and serialized R objects. Open files only from sources you trust; opening or running a project can execute code and access files with your permissions."),
      if (isTRUE(store$dirty)) p("Your current project has unsaved changes. Save it first or discard those changes when opening."),
      footer = tagList(actionButton("project_open_cancel", "Cancel"),
        if (isTRUE(store$dirty)) actionButton("project_open_save", "Save current project"),
        actionButton("project_open_trust", if (isTRUE(store$dirty)) "Trust, discard changes and open" else "Trust and open", class = "btn-primary"))))
  })
  observeEvent(input$project_open_cancel, { pending_project_open(NULL); removeModal() })
  observeEvent(input$project_open_save, {
    pending_project_open(NULL); removeModal(); session$sendCustomMessage("ig_click", "btn_save")
  })
  observeEvent(input$project_open_trust, {
    selected <- pending_project_open(); pending_project_open(NULL)
    if (is.null(selected) || !file.exists(selected$path) ||
        !identical(digest::digest(file = selected$path, algo = "sha256"), selected$hash)) {
      showNotification("The selected file changed. Choose it again before opening.", type = "warning"); return()
    }
    removeModal(); load_from_local_path(selected$path)
  })

  # Write the project to a path, in place, and report success.
  save_project_to <- function(path) {
    nd <- canvas_rv$network_data()
    ok <- tryCatch({
      project_save(store, path, canvas_state = nd, theme = theme_mode())
      TRUE
    }, error = function(e) {
      showNotification(paste("Save failed:", conditionMessage(e)),
                       type = "error", duration = 6)
      FALSE
    })
    if (ok) {
      project_clear_recovery()
      showNotification(paste0("Saved to ", path), type = "message", duration = 3)
    }
    ok
  }

  # Save overwrites the project's real on-disk file in place. A project that has
  # never been saved (no path) pops the Save-As browser to choose a location.
  observeEvent(input$btn_save, {
    path <- isolate(store$project_path)
    if (is.null(path) || !nzchar(path)) {
      session$sendCustomMessage("ig_click", "sf_save_as")
    } else {
      save_project_to(path)
    }
  }, ignoreNULL = FALSE, ignoreInit = TRUE)

  observeEvent(input$sf_save_as, {
    sp <- tryCatch(shinyFiles::parseSavePath(file_roots, input$sf_save_as),
                   error = function(e) NULL)
    if (is.null(sp) || nrow(sp) == 0L) return()
    path <- as.character(sp$datapath)[1]
    if (!grepl("\\.igpx$", path, ignore.case = TRUE)) path <- paste0(path, ".igpx")
    save_project_to(path)   # project_save records the path/name for future Saves
  })

  # Only the local desktop runtime enables this path-based protocol. Hosted
  # sessions keep shinyFiles and never accept a client-supplied desktop path.
  if (isTRUE(getOption("ig.desktop", FALSE))) {
    for (id in c("undo_btn_ui", "hdr_comments_btn", "hdr_review_btn"))
      outputOptions(output, id, suspendWhenHidden = FALSE)
    desktop_project_state <- function() {
      list(
        name = store$project_name %||% "Untitled", path = store$project_path %||% "",
        running = { store$background_revision; length(store$run_ids) > 0L || !is.null(store$background$job) },
        canRun = length(store$task_order) > 0L && !isTRUE(store$review_mode),
        startupReady = startup_ready(), recoveryPending = recovery_pending(), welcome = workspace_welcome())
    }
    observe({ session$sendCustomMessage("ig_desktop_project", desktop_project_state()) })
    observeEvent(input$desktop_file_command, {
      command <- input$desktop_file_command
      if (!is.list(command) || !is.character(command$id) || length(command$id) != 1L || is.na(command$id) ||
          !is.character(command$action) || length(command$action) != 1L ||
          is.na(command$action) ||
          !command$action %in% c("prepare", "open", "save", "new", "close", "example")) return()
      result <- list(id = command$id, action = command$action, ok = FALSE)
      tryCatch({
      if (identical(command$action, "prepare")) {
        store_sync_parameters(store)
        result$ok <- TRUE
        result$dirty <- isTRUE(store$dirty)
        result$name <- store$project_name %||% "Untitled"
        result$path <- store$project_path %||% ""
        result$running <- length(store$run_ids) > 0L || !is.null(store$background$job)
        result$recoveryPending <- isTRUE(recovery_pending())
      } else if (isTRUE(recovery_pending())) {
        result$ok <- FALSE
      } else if (identical(command$action, "example")) {
        result$ok <- isTRUE(open_example_project(command$path))
      } else if (command$action %in% c("new", "close")) {
        result$ok <- reset_project(identical(command$action, "close"))
      } else if (is.character(command$path) && length(command$path) == 1L &&
                 !is.na(command$path) && nzchar(command$path)) {
        if (identical(command$action, "open")) {
          result$ok <- isTRUE(load_from_local_path(command$path))
        } else {
          # Native Save As already normalizes its chosen extension. Save must
          # preserve the current path. Legacy imports have no path and use Save As.
          result$ok <- isTRUE(save_project_to(command$path))
        }
      }
      }, error = function(error) {
        result$ok <<- FALSE
        showNotification("The project command failed. See the startup log for details.", type = "error")
        warning("Desktop project command failed: ", conditionMessage(error), call. = FALSE)
      })
      result$path <- store$project_path %||% ""
      result$dirty <- isTRUE(store$dirty)
      result$project <- desktop_project_state()
      session$sendCustomMessage("ig_desktop_result", result)
    }, ignoreInit = TRUE)
  }
}
