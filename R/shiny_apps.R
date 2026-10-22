# A hosted app owns a separate supervised R process. It never shares the
# pipeline session's globals, working directory, reactive graph or stop file.
ig_shiny_app_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path) ||
      !file.exists(path)) stop("Choose an existing app.R file or app folder.", call. = FALSE)
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (!dir.exists(path) && tolower(basename(path)) != "app.r")
    stop("Choose app.R, or the folder containing ui.R and server.R.", call. = FALSE)
  directory <- if (dir.exists(path)) path else dirname(path)
  entries <- list.files(directory)
  entries <- entries[tolower(entries) %in% c("app.r", "ui.r", "server.r")]
  entries <- tolower(entries[!dir.exists(file.path(directory, entries))])
  if (!"app.r" %in% entries && !all(c("ui.r", "server.r") %in% entries))
    stop("This folder needs app.R, or both ui.R and server.R.", call. = FALSE)
  list(path = path, directory = directory, name = basename(directory),
    format = if ("app.r" %in% entries) "app.R" else "ui.R + server.R")
}

ig_shiny_app_log <- function(file, limit = 16000L) {
  if (!file.exists(file)) return("")
  connection <- file(file, "rb")
  on.exit(close(connection))
  size <- file.info(file)$size
  seek(connection, max(0, size - limit), origin = "start")
  text <- rawToChar(readBin(connection, "raw", n = limit))
  iconv(text, from = "UTF-8", to = "UTF-8", sub = "byte")
}

ig_shiny_app_manager <- function(timeout = 120) {
  # A different loopback site gives Chromium a separate iframe renderer as well
  # as a separate R process, keeping the workspace usable if guest JS hangs.
  host <- NULL
  used_hosts <- character()
  process <- NULL
  directory <- tempfile("ig-shiny-app-")
  dir.create(directory)
  stdout <- file.path(directory, "stdout.log")
  stderr <- file.path(directory, "stderr.log")
  state <- list(phase = "idle", name = "", path = "", url = "", message = "Choose a Shiny app to begin.", pid = NULL)
  started <- NULL
  port <- NULL
  alive <- function() !is.null(process) && process$is_alive()
  stop_process <- function() {
    if (alive()) {
      process$kill_tree()
      process$wait(2000)
      if (alive()) stop("The app could not be stopped. Try closing it again.", call. = FALSE)
    }
    process <<- NULL
  }
  logs <- function() paste(Filter(nzchar, c(ig_shiny_app_log(stdout), ig_shiny_app_log(stderr))), collapse = "\n")
  stop_app <- function() {
    stop_process()
    state <<- list(phase = "idle", name = "", path = "", url = "", message = "Choose a Shiny app to begin.", pid = NULL)
    state
  }
  list(
    active = alive,
    start = function(path, trusted = FALSE) {
      if (!isTRUE(trusted)) stop("Only run an app you trust.", call. = FALSE)
      entry <- ig_shiny_app_path(path) # Invalid choices leave the current app running.
      stop_process()
      # Never reuse a stopped app's site: a browser may retain a hung renderer.
      repeat {
        host <<- paste(c(127L, sample.int(254L, 1L), sample.int(256L, 1L) - 1L,
          sample.int(254L, 1L)), collapse = ".")
        if (!host %in% used_hosts) break
      }
      used_hosts <<- c(used_hosts, host)
      unlink(c(stdout, stderr))
      port <<- httpuv::randomPort()
      started <<- Sys.time()
      state <<- list(phase = "starting", name = entry$name, path = entry$directory,
        url = "", message = "Starting the Shiny app...", pid = NULL)
      tryCatch({
        process <<- callr::r_bg(function(directory, port, host) {
          # Inherit package libraries, not the desktop's authentication/recovery
          # environment. Profiles are disabled just as for the main desktop R.
          Sys.unsetenv(grep("^IG_", names(Sys.getenv()), value = TRUE))
          Sys.setenv(no_proxy = paste(Sys.getenv("no_proxy"), host, sep = ","))
          setwd(directory)
          options(shiny.autoreload = FALSE)
          shiny::runApp(directory, host = host, port = port,
            launch.browser = FALSE, display.mode = "normal")
        }, args = list(entry$directory, port, host), libpath = .libPaths(),
          stdout = stdout, stderr = stderr, supervise = TRUE, cleanup_tree = TRUE,
          system_profile = FALSE, user_profile = FALSE)
        state$pid <<- process$get_pid()
      }, error = function(error) {
        state$phase <<- "failed"
        state$message <<- "The Shiny app could not start. Open its log for details."
        writeLines(conditionMessage(error), stderr, useBytes = TRUE)
      })
      state
    },
    poll = function(include_log = FALSE) {
      if (state$phase %in% c("starting", "ready") && !alive()) {
        state$phase <<- if (state$phase == "ready" && !is.null(process) && identical(process$get_exit_status(), 0L)) "stopped" else "failed"
        state$url <<- ""
        state$message <<- "The Shiny app stopped. Open its log, run it again, or choose another app."
      }
      if (state$phase == "starting" && alive()) {
        if (as.numeric(difftime(Sys.time(), started, units = "secs")) > timeout) {
          stop_process()
          state$phase <<- "failed"
          state$message <<- "The Shiny app took too long to start. Open its log for details."
        } else {
          connection <- tryCatch(suppressWarnings(socketConnection(host, port,
            open = "r+", blocking = TRUE, timeout = 0.05)), error = function(error) NULL)
          if (!is.null(connection)) {
            close(connection)
            state$phase <<- "ready"
            state$url <<- paste0("http://", host, ":", port, "/")
            state$message <<- "Shiny app is running."
          }
        }
      }
      result <- state
      if (include_log || state$phase == "failed") result$log <- logs()
      result
    },
    stop = stop_app,
    dispose = function() {
      stop_process()
      unlink(directory, recursive = TRUE)
    }
  )
}

ig_shiny_apps_ui <- function() {
  tags$section(id = "ig-shiny-apps", hidden = NA, `aria-label` = "Shiny app browser",
    tags$header(class = "ig-appbar",
      span(class = "ig-app-brand", icon("share-nodes"), "Individual Guide"),
      tags$button(type = "button", class = "btn btn-sm btn-outline-secondary", id = "ig-app-back", title = "Return to your workspace; keep this app running",
        icon("share-nodes"), "Individual Guide"),
      div(class = "ig-app-heading", strong(id = "ig-app-name", `data-ig-no-translate` = "", "Shiny apps"),
        span(id = "ig-app-status", role = "status", `aria-live` = "polite", "Choose a Shiny app to begin.")),
      tags$button(type = "button", class = "btn btn-sm btn-primary", id = "ig-app-open", "Open app..."),
      tags$button(type = "button", class = "btn btn-sm btn-outline-secondary", id = "ig-app-log", `aria-expanded` = "false", "App log"),
      tags$button(type = "button", class = "btn btn-sm btn-outline-danger", id = "ig-app-close", disabled = NA, "Close app")),
    div(id = "ig-app-stage",
      div(id = "ig-app-empty", class = "ig-app-card",
        h2("Open a Shiny app"),
        p("Choose app.R, or a folder with ui.R and server.R. Keep its data and other files together."),
        div(class = "ig-app-choices",
          shinyFiles::shinyFilesButton("sf_shiny_app", "Choose app.R...", "Choose a Shiny app.R file", multiple = FALSE),
          shinyFiles::shinyDirButton("sf_shiny_folder", "Choose app folder...", "Choose a Shiny app folder")),
        div(id = "ig-app-selection", hidden = NA,
          tags$code(id = "ig-app-path", `data-ig-no-translate` = ""),
          p("Shiny apps run R code with your permissions. Only run apps from a source you trust."),
          p(id = "ig-app-replace-note", hidden = NA, "Running this app closes the current app. Save any work in that app first."),
          tags$label(class = "ig-app-trust", tags$input(id = "ig-app-trust", type = "checkbox"), "I trust this app"),
          tags$button(id = "ig-app-run", type = "button", class = "btn btn-primary", disabled = NA, "Run app")),
        p(id = "ig-app-error", role = "alert"),
        tags$button(id = "ig-app-resume", type = "button", class = "btn btn-link", hidden = NA, "Back to running app")),
      tags$iframe(id = "ig-app-frame", title = "Hosted Shiny app", hidden = NA,
        sandbox = "allow-scripts allow-same-origin allow-forms allow-downloads allow-modals allow-popups"),
      div(id = "ig-app-starting", hidden = NA, class = "ig-app-card", h2("Starting the Shiny app..."),
        p("You can close this app or choose another while it starts.")),
      div(id = "ig-app-log-panel", hidden = NA, h2("App log"),
        p("Messages come from the app and keep their original language."), tags$pre(id = "ig-app-log-text", `data-ig-no-translate` = ""))),
    tags$dialog(id = "ig-app-confirm", h2("Close this app?"),
      p("Save any work in the loaded app first. Closing stops its R process."),
      div(class = "ig-app-choices", tags$button(id = "ig-app-cancel-close", type = "button", class = "btn btn-outline-secondary", "Cancel"),
        tags$button(id = "ig-app-confirm-close", type = "button", class = "btn btn-danger", "Close app"))))
}

ig_shiny_apps_server <- function(input, session) {
  manager <- ig_shiny_app_manager()
  session$onSessionEnded(manager$dispose)
  selected <- NULL
  changed <- shiny::reactiveVal(0L)
  snapshot <- NULL
  roots <- ig_volumes(refresh = TRUE)
  shinyFiles::shinyFileChoose(input, "sf_shiny_app", roots = roots, filetypes = c("R", "r"))
  shinyFiles::shinyDirChoose(input, "sf_shiny_folder", roots = roots)
  notify <- function(value) session$sendCustomMessage("ig_shiny_app", value)
  choose <- function(path) {
    tryCatch({ selected <<- ig_shiny_app_path(path); notify(list(selection = selected)) },
      error = function(error) { selected <<- NULL; notify(list(clearSelection = TRUE, error = conditionMessage(error))) })
  }
  shiny::observeEvent(input$sf_shiny_app, {
    paths <- shinyFiles::parseFilePaths(roots, input$sf_shiny_app)
    if (nrow(paths)) choose(as.character(paths$datapath[[1L]]))
  })
  shiny::observeEvent(input$sf_shiny_folder, {
    path <- shinyFiles::parseDirPath(roots, input$sf_shiny_folder)
    if (length(path) && nzchar(path[[1L]])) choose(path[[1L]])
  })
  shiny::observeEvent(input$app_host_action, {
    request <- input$app_host_action
    if (!is.list(request) || !is.character(request$action) || length(request$action) != 1L ||
        !is.character(request$nonce) || length(request$nonce) != 1L ||
        !grepl("^[0-9]{1,20}$", request$nonce)) return()
    tryCatch({
      if (request$action == "start") {
        hostname <- session$clientData$url_hostname
        if (length(hostname) && nzchar(hostname) && !hostname %in% c("localhost", "127.0.0.1", "::1", "[::1]"))
          stop("Open local Shiny apps from a browser on this computer.", call. = FALSE)
        if (is.null(selected)) stop("Choose an app first.", call. = FALSE)
        value <- manager$start(selected$path, trusted = isTRUE(request$trusted))
      } else if (request$action == "stop") value <- manager$stop() else return()
      notify(list(ack = request$nonce, state = value))
      changed(shiny::isolate(changed()) + 1L)
    }, error = function(error) notify(list(ack = request$nonce, error = conditionMessage(error))))
  })
  shiny::observe({
    changed()
    if (manager$active()) shiny::invalidateLater(750, session)
    value <- manager$poll(include_log = isTRUE(input$app_host_log))
    if (!identical(value, snapshot)) { snapshot <<- value; notify(list(state = value)) }
  })
  invisible(manager)
}
