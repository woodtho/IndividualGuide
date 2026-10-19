ig_build_info <- function() {
  path <- system.file("build-info.json", package = "IndividualGuide")
  info <- if (nzchar(path) && file.exists(path)) jsonlite::read_json(path, simplifyVector = TRUE) else list()
  utils::modifyList(list(version = as.character(utils::packageVersion("IndividualGuide")),
    commit = "source checkout", built_at = "development", R = R.version.string), info)
}

ig_about_ui <- function() {
  info <- ig_build_info()
  modalDialog(title = "About Individual Guide", size = "m", easyClose = TRUE,
    tags$h4(paste("Individual Guide", info$version)),
    tags$dl(tags$dt("Build"), tags$dd(info$built_at), tags$dt("Source commit"), tags$dd(info$commit),
      tags$dt("R runtime"), tags$dd(R.version.string), tags$dt("Project format"), tags$dd(PROJECT_VERSION)),
    p("Local analytical workflows, readable R code and portable projects."),
    p("MIT © Thomas Wood. Bundled R packages, browser components and fonts retain their own licenses."),
    tags$details(tags$summary("Loaded package versions"), tags$pre(paste(capture.output(print(sessionInfo())), collapse = "\n"))),
    footer = modalButton("Close"))
}

project_tools_server <- function(id, store, load_project, open_task, relink_task, theme) {
  parent_session <- shiny::getDefaultReactiveDomain()
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    pending_restore <- reactiveVal(NULL)
    root_path <- reactiveVal(NULL)
    can_edit <- function() {
      if (isTRUE(isolate(store$review_mode)) || length(isolate(store$run_ids)) || !is.null(isolate(store$background$job))) {
        showNotification("Finish the current run and leave read-only review before changing project files.", type = "warning")
        return(FALSE)
      }
      TRUE
    }
    show <- function(tab = "versions") {
      store_sync_parameters(store)
      path <- isolate(store$project_path)
      root_path(path)
      versions <- project_backup_list(path)
      files <- isolate(ig_project_files(store))
      showModal(modalDialog(title = div(class = "ig-project-tools-title", "Project tools"), size = "xl", easyClose = TRUE,
        tabsetPanel(id = ns("tab"), selected = tab,
          tabPanel("Saved versions", value = "versions",
            p("Each explicit save retains the previous project. Restoring opens an unsaved working copy; Save writes it back to your project."),
            if (is.null(path)) p("Save your project first to start retaining versions.") else p(tags$code(path)),
            selectInput(ns("backup"), "Previous saved version", choices = if (nrow(versions)) stats::setNames(versions$id,
              paste(versions$time, "·", format(round(versions$bytes / 1024), big.mark = ","), "KiB")) else character()),
            actionButton(ns("restore"), "Restore selected version", class = "btn-primary", disabled = if (!nrow(versions)) NA else NULL),
            p(class = "small text-muted mt-2", "Configure retained versions in Settings. Crash recovery remains separate.")),
          tabPanel("Files and portability", value = "files",
            DT::DTOutput(ns("files")),
            selectInput(ns("file_task"), "Import task to relink", choices = stats::setNames(files$task, files$task)),
            textInput(ns("replacement"), "Replacement file path"),
            shinyFiles::shinyFilesButton(ns("locate"), "Locate file…", title = "Locate a replacement import file", multiple = FALSE),
            actionButton(ns("relink"), "Use replacement", class = "btn-primary"),
            tags$hr(),
            p("Portable copies include Import Data source files, saved results/reports and existing export files. Script literals and external databases retain their own dependencies. Export destinations relocate to a writable project-output folder."),
            downloadButton(ns("portable"), "Save portable project")),
          tabPanel("Run records", value = "runs",
            p("The latest 200 task runs retain configuration, input/output fingerprints, random state and package/runtime versions; raw data is not included in the downloaded manifest."),
            DT::DTOutput(ns("runs")), uiOutput(ns("comparison")),
            downloadButton(ns("manifest"), "Export run manifest")),
          tabPanel("Task list", value = "tasks",
            p("A keyboard-accessible alternative to the graph. Search by task name, type, status or output, then open a task to edit it."),
            textInput(ns("task_search"), "Find a task"), uiOutput(ns("tasks")))),
        footer = tagList(actionButton(ns("about"), "About this build"), modalButton("Close"))))
    }
    shinyFiles::shinyFileChoose(input, "locate", roots = ig_volumes(), filetypes = IMPORT_TYPES)
    observeEvent(input$locate, {
      files <- shinyFiles::parseFilePaths(ig_volumes(), input$locate)
      if (nrow(files)) updateTextInput(session, "replacement", value = as.character(files$datapath[[1L]]))
    })
    observeEvent(input$about, showModal(ig_about_ui()))
    output$files <- DT::renderDT({ ig_project_files(store) }, rownames = FALSE,
      options = list(pageLength = 5, scrollX = TRUE), selection = "none")
    observeEvent(input$relink, {
      if (!can_edit()) return()
      id <- input$file_task; path <- trimws(input$replacement %||% "")
      if (length(id) != 1L || !id %in% ig_project_files(store)$task || !file.exists(path) || dir.exists(path)) {
        showNotification("Choose an import task and an existing replacement file.", type = "error"); return()
      }
      task <- store_all_tasks(store)[[id]]
      expected <- import_file_type(task$params)
      if (!identical(tolower(tools::file_ext(path)), expected)) {
        showNotification(paste0("Choose a .", expected, " file, or change the reader in the Import task."), type = "error"); return()
      }
      removeModal()
      shiny::withReactiveDomain(parent_session, relink_task(id, normalizePath(path, winslash = "/", mustWork = TRUE)))
    })
    output$portable <- downloadHandler(filename = function() paste0(make.names(isolate(store$project_name)), "-portable.igpx"),
      content = function(file) {
        if (!can_edit()) stop("Finish the run before exporting a portable project.")
        project_save(store, file, theme = theme(), update_identity = FALSE, portable = TRUE)
      }, contentType = "application/zip")
    restore <- function(id, path) {
      versions <- project_backup_list(path)
      if (!id %in% versions$id) { showNotification("That saved version is unavailable.", type = "error"); return() }
      backup <- file.path(project_backup_directory(path), id)
      if (isTRUE(shiny::withReactiveDomain(parent_session, load_project(backup, path)))) {
        store$project_path <- path
        store$project_name <- tools::file_path_sans_ext(basename(path))
        store$dirty <- TRUE
        showNotification("Restored as an unsaved working copy. Save to keep this version.", duration = 7)
      }
    }
    observeEvent(input$restore, {
      if (!can_edit()) return()
      path <- root_path(); id <- input$backup
      if (is.null(path) || length(id) != 1L || !id %in% project_backup_list(path)$id) return()
      if (!isTRUE(store$dirty)) { restore(id, path); return() }
      pending_restore(list(id = id, path = path))
      showModal(modalDialog(title = "Restore an earlier version?",
        p("Your current project has unsaved changes. Save it first and return to Saved versions, or discard those changes to restore."),
        footer = tagList(actionButton(ns("restore_cancel"), "Cancel"), actionButton(ns("restore_save"), "Save current project"),
          actionButton(ns("restore_discard"), "Discard changes and restore", class = "btn-primary"))))
    })
    observeEvent(input$restore_cancel, { pending_restore(NULL); show("versions") })
    observeEvent(input$restore_save, {
      pending_restore(NULL); removeModal(); session$sendCustomMessage("ig_click", "btn_save")
    })
    observeEvent(input$restore_discard, {
      selected <- pending_restore(); pending_restore(NULL)
      if (!is.null(selected) && can_edit()) restore(selected$id, selected$path)
    })
    output$runs <- DT::renderDT({
      records <- rev(store$run_records)
      if (!length(records)) return(data.frame(Time = character(), Task = character(), Status = character(), Seconds = numeric()))
      do.call(rbind, lapply(records, function(record) data.frame(Time = record$started, Task = record$task,
        Status = record$status, Seconds = round(record$elapsed, 3))))
    }, rownames = FALSE, selection = "single", options = list(pageLength = 8, scrollX = TRUE))
    output$comparison <- renderUI({
      records <- rev(store$run_records); selected <- input$runs_rows_selected
      if (!length(selected) || selected[[1]] > length(records)) return(p(class = "small text-muted", "Select a run to inspect its environment and compare it with the previous run of that task."))
      record <- records[[selected[[1]]]]
      earlier <- Filter(function(x) identical(x$task, record$task) && !identical(x$id, record$id) && x$started <= record$started, records)
      fields <- c("config", "inputs", "outputs", "files", "seed", "environment")
      differences <- if (length(earlier)) fields[!vapply(fields, function(field) identical(record[[field]], earlier[[1]][[field]]), logical(1))] else character()
      tagList(p(if (!length(earlier)) "No earlier retained run for this task." else if (!length(differences)) "Fingerprints, settings and environment match the previous run." else paste("Changed since the previous run:", paste(differences, collapse = ", "))),
        tags$details(tags$summary("Run details"), tags$pre(jsonlite::toJSON(record, auto_unbox = TRUE, pretty = TRUE, null = "null"))))
    })
    output$manifest <- downloadHandler(filename = function() "IndividualGuide-run-manifest.json",
      content = function(file) jsonlite::write_json(list(format = "Individual Guide run manifest", version = 1L,
        runs = isolate(store$run_records)), file, auto_unbox = TRUE, pretty = TRUE, null = "null"),
      contentType = "application/json")
    output$tasks <- renderUI({
      tasks <- store$tasks; order <- store$task_order
      query <- tolower(trimws(input$task_search %||% ""))
      matches <- Filter(function(id) !nzchar(query) || grepl(query, tolower(paste(id, tasks[[id]]$label,
        task_type_info(tasks[[id]]$type)$label, tasks[[id]]$status, paste(task_output_names(tasks[[id]]), collapse = " "))), fixed = TRUE), order)
      if (!length(matches)) return(p("No matching tasks."))
      div(class = "ig-accessible-task-list", lapply(matches, function(id) {
        task <- tasks[[id]]
        div(class = "ig-accessible-task-row", div(strong(task$label %||% id),
          div(class = "small text-muted", paste(id, task_type_info(task$type)$label, task$status, sep = " · "))),
          tags$button(type = "button", class = "btn btn-sm btn-outline-primary", `aria-label` = paste("Open task", task$label %||% id),
            onclick = ig_input_event_js(ns("open_task"), id), "Open task"))
      }))
    })
    observeEvent(input$open_task, {
      if (!input$open_task %in% names(store_all_tasks(store))) return()
      selected <- input$open_task
      removeModal(); shiny::withReactiveDomain(parent_session, open_task(selected))
    })
    list(show = show)
  })
}
