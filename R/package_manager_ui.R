ig_package_job <- function(request, app_path, source, r_options = list()) {
  if (length(r_options)) options(r_options)
  if (source) pkgload::load_all(app_path, quiet = TRUE, export_all = FALSE) else loadNamespace("IndividualGuide")
  ns <- asNamespace("IndividualGuide")
  probe <- function(paths, packages) {
    callr::r(function(paths, packages, app_path, source) {
      .libPaths(paths, include.site = FALSE)
      if (source) pkgload::load_all(app_path, quiet = TRUE, export_all = FALSE) else loadNamespace("IndividualGuide")
      for (package in packages) loadNamespace(package)
      TRUE
    }, args = list(paths, packages, app_path, source), libpath = paths,
      system_profile = FALSE, user_profile = FALSE, timeout = 120)
  }
  request$probe <- probe
  do.call(get("ig_package_change", ns), request)
}

ig_package_manager_server <- function(id, store) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    revision <- shiny::reactiveVal(0L)
    status <- shiny::reactiveVal(getOption("ig.package.startup.error") %||%
      "Package changes take effect after restarting R. Save your project before restarting.")
    log <- shiny::reactiveVal("")
    process <- NULL
    previous_profile <- NULL
    closed <- FALSE
    owner <- basename(tempfile("operation-"))
    log_file <- tempfile("ig-packages-", fileext = ".log")
    root <- ig_package_root()
    fallback <- getOption("ig.package.fallback", .libPaths())
    if (!is.null(getOption("ig.package.startup.error"))) shiny::showNotification(
      paste("IG is using its bundled packages.", getOption("ig.package.startup.error")), type = "warning", duration = NULL)
    writable <- function() {
      host <- session$clientData$url_hostname
      # Installing packages executes code. A hosted public browser session must
      # not expose the host's application-wide package environment to visitors.
      !is.null(host) && length(host) == 1L && host %in% c("localhost", "127.0.0.1", "::1", "[::1]")
    }
    busy <- function() !is.null(process) && process$is_alive()
    inventory <- shiny::reactive({ revision(); tryCatch(ig_package_inventory(root, fallback),
      error = function(error) ig_package_inventory(tempfile(), fallback)) })
    show <- function() {
      dialog <- shiny::modalDialog(title = "R package manager", size = "xl", easyClose = FALSE,
        shiny::tags$p("Packages and pins are shared by this IG installation. Your other R libraries are unchanged."),
        shiny::tags$details(shiny::tags$summary("IG library location"), shiny::tags$code(root)),
        shiny::uiOutput(ns("status")),
        DT::DTOutput(ns("packages")),
        bslib::layout_columns(col_widths = c(6, 6),
          shiny::textInput(ns("package"), "Package name"),
          shiny::textInput(ns("version"), "Exact version (leave blank for latest)")),
        shiny::tags$div(class = "d-flex flex-wrap gap-2 mb-3",
          shiny::actionButton(ns("install"), "Install / update", class = "btn-primary"),
          shiny::actionButton(ns("pin"), "Pin installed version", class = "btn-outline-secondary"),
          shiny::actionButton(ns("unpin"), "Unpin", class = "btn-outline-secondary"),
          shiny::actionButton(ns("remove"), "Remove IG override", class = "btn-outline-secondary")),
        shiny::tags$p(class = "small text-muted", "An exact version is pinned automatically. Unpin before updating. Older versions may require Rtools to compile."),
        shiny::tags$details(shiny::tags$summary("Lockfile and recovery"),
          shiny::downloadButton(ns("export"), "Export package lockfile"),
          shiny::fileInput(ns("lockfile"), "IG package lockfile", accept = ".json"),
          shiny::actionButton(ns("restore"), "Restore lockfile", class = "btn-outline-secondary"),
          shiny::actionButton(ns("rollback"), "Undo last package change", class = "btn-outline-secondary"),
          shiny::actionButton(ns("reset"), "Use bundled packages", class = "btn-outline-secondary")),
        shiny::tags$details(shiny::tags$summary("Installation log"), shiny::verbatimTextOutput(ns("log"))),
        footer = shiny::tagList(shiny::actionButton(ns("cancel"), "Cancel operation", class = "btn-outline-secondary"), shiny::modalButton("Close")))
      shiny::showModal(htmltools::tagAppendAttributes(dialog, class = "ig-package-manager"))
    }
    output$packages <- DT::renderDT(inventory(), rownames = FALSE, selection = "single",
      options = list(pageLength = 8L))
    output$status <- shiny::renderUI({
      revision()
      profile <- tryCatch(ig_package_current(root), error = function(e) NULL)
      pending <- !is.null(profile) && !identical(profile$id, getOption("ig.package.session.profile", "bundled"))
      shiny::tags$div(role = "status", `aria-live` = "polite", class = "mb-3",
        shiny::tags$p(status()),
        if (pending) shiny::tags$strong("Restart R to apply the selected package versions."),
        if (!writable()) shiny::tags$p("Package changes are available only from a browser on this computer."))
    })
    output$log <- shiny::renderText(log())
    shiny::observeEvent(input$packages_rows_selected, {
      row <- input$packages_rows_selected
      table <- inventory()
      if (length(row) == 1L && row > 0L && row <= nrow(table)) {
        shiny::updateTextInput(session, "package", value = table$Package[[row]])
        shiny::updateTextInput(session, "version", value = "")
      }
    })
    poll <- function() {
      if (closed || is.null(process)) return()
      if (file.exists(log_file)) log(ig_shiny_app_log(log_file, 32000L))
      if (process$is_alive()) { later::later(poll, .3); return() }
      tryCatch({
        process$get_result()
        status("Package changes were saved. Restart R to apply them to the workspace, console and Shiny apps.")
      }, error = function(error) status(paste("Package change failed. The previous library is unchanged.", conditionMessage(error))))
      process <<- NULL
      release_lock()
      revision(shiny::isolate(revision()) + 1L)
    }
    start <- function(action) {
      if (!writable()) { status("Package changes are available only from a browser on this computer."); return() }
      if (!is.null(process)) { status("A package operation is already running."); return() }
      if (length(shiny::isolate(store$run_ids)) || !is.null(shiny::isolate(store$background$job)) || isTRUE(shiny::isolate(store$review_mode))) {
        status("Finish the current run and leave read-only review before changing packages."); return()
      }
      tryCatch({
        lock <- NULL
        if (action == "restore") {
          upload <- input$lockfile
          if (is.null(upload) || upload$size > 1024 * 1024) stop("Choose an IG package lockfile smaller than 1 MiB.")
          lock <- ig_package_validate_lock(jsonlite::read_json(upload$datapath, simplifyVector = FALSE))
        }
        request <- list(action = action, package = trimws(input$package %||% ""), version = trimws(input$version %||% ""),
          root = root, fallback = fallback, lock = lock, owner = owner)
        if (!action %in% c("restore", "reset", "rollback")) ig_package_validate(request$package, if (nzchar(request$version)) request$version else NULL)
        app_path <- getNamespaceInfo(asNamespace("IndividualGuide"), "path")
        previous_profile <<- tryCatch(ig_package_current(root)$id, error = function(e) NULL)
        source <- !file.exists(file.path(app_path, "R", "IndividualGuide.rdb"))
        worker <- ig_package_job; environment(worker) <- baseenv()
        unlink(log_file)
        process <<- callr::r_bg(worker, args = list(request, app_path, source, ig_options_r_values(store)), libpath = .libPaths(),
          stdout = log_file, stderr = "2>&1", system_profile = FALSE, user_profile = FALSE, supervise = TRUE)
        status("Preparing package changes. You can keep using the current workspace.")
        log("")
        later::later(poll, .1)
      }, error = function(error) status(conditionMessage(error)))
    }
    for (action in c("install", "pin", "unpin", "remove", "restore", "rollback", "reset")) local({
      selected <- action
      shiny::observeEvent(input[[selected]], start(selected), ignoreInit = TRUE)
    })
    output$export <- shiny::downloadHandler(filename = function() "IndividualGuide-packages.json",
      content = function(file) jsonlite::write_json(ig_package_export(root, fallback), file, auto_unbox = TRUE, pretty = TRUE),
      contentType = "application/json")
    release_lock <- function() {
      guard <- file.path(root, "operation.lock")
      if (!file.exists(file.path(guard, "owner"))) return(invisible(NULL))
      record <- tryCatch(readLines(file.path(guard, "owner"), warn = FALSE), error = function(e) character())
      if (length(record) >= 2L && identical(record[[1L]], owner)) unlink(guard, recursive = TRUE)
    }
    shiny::observeEvent(input$cancel, {
      if (is.null(process)) return()
      if (busy()) { process$kill_tree(); process$wait(2000) }
      release_lock()
      process <<- NULL
      current <- tryCatch(ig_package_current(root)$id, error = function(e) NULL)
      status(if (identical(current, previous_profile)) "Package operation cancelled. The selected library is unchanged." else
        "Package changes were saved. Restart R to apply them to the workspace, console and Shiny apps.")
      revision(shiny::isolate(revision()) + 1L)
    })
    session$onSessionEnded(function() {
      closed <<- TRUE
      if (busy()) { process$kill_tree(); process$wait(2000) }
      # A killed worker cannot run on.exit; only release the lock we owned.
      release_lock()
      process <<- NULL
      unlink(log_file)
    })
    list(show = show)
  })
}
