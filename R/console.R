# A console belongs to one Shiny session and uses a separate, persistent R
# process. Nothing from its workspace is committed to the pipeline store.
ig_console_worker <- function(code, snapshot, directory, output, working_directory, r_options = list(), app_options = list()) {
  # Keep unmanaged options explicitly set by console commands, but update every
  # managed global/project option at the start of the next command.
  previous <- getOption("ig.console.managed_options", list())
  removed <- setdiff(names(previous), names(r_options))
  if (length(removed)) options(previous[removed])
  original <- options()[intersect(names(r_options), names(options()))]
  absent <- setdiff(names(r_options), names(original))
  if (length(absent)) original[absent] <- rep(list(NULL), length(absent))
  for (name in intersect(names(previous), names(original))) original[name] <- previous[name]
  if (length(r_options)) options(r_options)
  options(ig.console.managed_options = original)
  if (!is.null(working_directory)) setwd(working_directory)
  if (!is.null(snapshot)) {
    old <- getOption("ig.console.project_names", character())
    rm(list = intersect(old, ls(globalenv(), all.names = TRUE)), envir = globalenv())
    assign(".project", snapshot, envir = globalenv())
    values <- c(snapshot$tables, snapshot$objects)
    values <- values[!duplicated(names(values)) & names(values) != ".project"]
    # Serialized S3 objects retain class names without necessarily attaching
    # their methods. Load only namespaces needed by the copied data.
    owners <- c(tbl_df = "tibble", grouped_df = "dplyr", haven_labelled = "haven",
      integer64 = "bit64", hms = "hms", blob = "blob", vctrs_vctr = "vctrs",
      ggplot = "ggplot2", "ggplot2::ggplot" = "ggplot2", coxph = "survival",
      survfit = "survival", Surv = "survival", forecast = "forecast", ets = "forecast")
    restore <- function(x) {
      for (package in unique(unname(owners[intersect(class(x), names(owners))]))) loadNamespace(package)
      if (is.list(x)) for (item in x) restore(item)
    }
    restore(values)
    list2env(values, envir = globalenv())
    options(ig.console.project_names = names(values))
  }
  connection <- file(output, open = "at", encoding = "UTF-8")
  depth <- sink.number()
  message_connection <- getConnection(sink.number(type = "message"))
  sink(connection)
  sink(connection, type = "message")
  on.exit({
    while (sink.number() > depth) sink()
    sink(message_connection, type = "message")
    close(connection)
  }, add = TRUE)
  device <- NULL
  initial_plot <- NULL
  on.exit({
    if (!is.null(device) && device %in% grDevices::dev.list()) {
      # Windows' PNG device writes a blank file even when nothing was drawn.
      # Compare recorded display lists, without inspecting their internals.
      unused <- identical(grDevices::recordPlot(), initial_plot)
      try(grDevices::dev.off(device), silent = TRUE)
      if (unused) unlink(list.files(directory, pattern = "[.]png$", full.names = TRUE))
    }
  }, add = TRUE)
  status <- "Ready"
  tryCatch(withCallingHandlers({
    expressions <- parse(text = code, keep.source = FALSE)
    if (length(expressions)) {
      grDevices::png(file.path(directory, "plot-%03d.png"), width = if (is.null(app_options$console_plot_width)) 1000 else app_options$console_plot_width,
        height = if (is.null(app_options$console_plot_height)) 700 else app_options$console_plot_height)
      device <- grDevices::dev.cur()
      grDevices::dev.control(displaylist = "enable")
      initial_plot <- grDevices::recordPlot()
    }
    for (expression in expressions) {
      value <- withVisible(eval(expression, envir = globalenv()))
      assign(".Last.value", value$value, envir = globalenv())
      if (value$visible) print(value$value)
      flush(connection)
    }
  }, warning = function(warning) {
    cat("Warning: ", conditionMessage(warning), "\n", sep = "")
    flush(connection); invokeRestart("muffleWarning")
  }, message = function(message) {
    cat(conditionMessage(message), sep = "")
    flush(connection); invokeRestart("muffleMessage")
  }), error = function(error) {
    cat("Error: ", conditionMessage(error), "\n", sep = "")
    status <<- "Error"
  })
  words <- ls(globalenv(), all.names = FALSE)
  fields <- list(); kinds <- list()
  lazy <- if (length(words)) rlang::env_binding_are_lazy(globalenv(), words) else logical()
  for (name in words) {
    if (bindingIsActive(name, globalenv()) || isTRUE(lazy[[name]])) next
    value <- get(name, globalenv(), inherits = FALSE)
    kinds[[name]] <- if (is.data.frame(value)) "table" else "object"
    if (is.data.frame(value)) fields[[name]] <- attr(value, "names", exact = TRUE)
  }
  if (exists(".project", globalenv(), inherits = FALSE) && !bindingIsActive(".project", globalenv()) &&
      !rlang::env_binding_are_lazy(globalenv(), ".project")) {
    project <- get(".project", globalenv())
    if (is.list(project) && is.list(project$tables)) {
      fields[[".project$tables"]] <- names(project$tables)
      fields[[".project$objects"]] <- names(project$objects)
      for (name in names(project$tables)) if (is.data.frame(project$tables[[name]]))
        fields[[paste0(".project$tables$", paste(deparse(as.name(name), backtick = TRUE), collapse = ""))]] <- attr(project$tables[[name]], "names", exact = TRUE)
    }
  }
  portable_option <- function(value) {
    if (is.function(value) || typeof(value) %in% c("environment", "externalptr", "weakref")) return(FALSE)
    if (is.list(value)) return(all(vapply(value, portable_option, logical(1))))
    is.atomic(value) || is.null(value)
  }
  registered <- lapply(options(), function(value) {
    small <- as.numeric(utils::object.size(value)) <= 1000000
    text <- if (small) paste(suppressWarnings(deparse(value, width.cutoff = 90L, nlines = 4L)), collapse = "\n") else paste("<large", typeof(value), "option>")
    safe <- small && portable_option(value)
    list(text = substr(text, 1L, 1000L), has_value = safe, value = if (safe) value else NULL)
  })
  list(status = status, symbols = list(words = utils::head(words, 2000L), fields = fields, kinds = kinds), registered_options = registered)
}

ig_console_snapshot <- function(store) {
  tables <- isolate(store$tables)
  objects <- lapply(isolate(store$objects), `[[`, "value")
  # Live database handles/external pointers cannot be transferred to another
  # process. Leave lazy tables in the app; users can collect them in a task.
  portable <- function(x) {
    if (inherits(x, c("tbl_sql", "DBIConnection", "connection")) ||
        typeof(x) %in% c("externalptr", "weakref", "environment")) return(FALSE)
    if (is.list(x)) return(all(vapply(x, portable, logical(1))))
    TRUE
  }
  skipped <- c(names(tables)[!vapply(tables, portable, logical(1))],
    names(objects)[!vapply(objects, portable, logical(1))])
  list(tables = tables[setdiff(names(tables), skipped)],
    objects = objects[setdiff(names(objects), skipped)], skipped = skipped)
}

ig_console_state <- function(store, session, changed = function() NULL) {
  state <- new.env(parent = emptyenv())
  state$process <- NULL; state$pending <- NULL; state$closed <- FALSE
  state$text <- "R console\nProject data loads on first run. Refresh data replaces imported variables.\n"
  state$status <- "Ready"; state$plots <- character(); state$generation <- 0L
  state$symbols <- list(words = character(), fields = list(), kinds = list())
  state$history_generation <- 0L
  state$directory <- tempfile("ig-console-"); dir.create(state$directory)
  state$prefix <- paste0("ig-console-", basename(state$directory))
  shiny::addResourcePath(state$prefix, state$directory)
  state$changed <- changed
  state$max_chars <- isolate(store$settings)$console_max_chars %||% 300000L
  session$onSessionEnded(function() {
    if (state$closed) return()
    state$closed <- TRUE
    ig_console_reset(state, notify = FALSE)
    shiny::removeResourcePath(state$prefix)
    unlink(state$directory, recursive = TRUE)
  })
  state
}

ig_console_append <- function(state, text) {
  state$text <- paste0(state$text, text)
  limit <- state$max_chars %||% 300000L
  if (nchar(state$text, type = "chars") > limit)
    state$text <- paste0("[Earlier console output trimmed]\n", substr(state$text,
      nchar(state$text) - as.integer(limit * .85), nchar(state$text)))
}

ig_console_reset <- function(state, notify = TRUE) {
  if (!is.null(state$process)) try(state$process$kill(), silent = TRUE)
  state$process <- NULL; state$pending <- NULL; state$generation <- state$generation + 1L
  state$history_generation <- state$history_generation + 1L
  state$status <- "Ready"; state$plots <- character()
  state$symbols <- list(words = character(), fields = list(), kinds = list())
  unlink(list.files(state$directory, full.names = TRUE), recursive = TRUE)
  state$text <- "R console reset. Project data will load on the next run.\n"
  if (notify) state$changed()
  invisible(NULL)
}

ig_console_output <- function(state) {
  job <- state$pending
  if (is.null(job) || !file.exists(job$output)) return()
  size <- file.info(job$output)$size
  if (size <= job$offset) return()
  con <- file(job$output, "rb"); on.exit(close(con))
  # Bound each update even when a command prints millions of lines.
  start <- max(job$offset, size - 200000L)
  seek(con, start)
  bytes <- readBin(con, "raw", n = size - start)
  if (start > job$offset) ig_console_append(state, "\n[Excess command output trimmed]\n")
  text <- iconv(rawToChar(bytes), from = "UTF-8", to = "UTF-8", sub = "byte")
  ig_console_append(state, text)
  state$pending$offset <- size
}

ig_console_submit <- function(state, store, code = "", refresh = FALSE) {
  if (state$closed || !is.null(state$pending)) return(invisible(FALSE))
  if (!is.character(code) || length(code) != 1L || is.na(code) || nchar(code) > 100000L)
    return(invisible(FALSE))
  if (!nzchar(trimws(code)) && !refresh) return(invisible(FALSE))
  alive <- !is.null(state$process) && state$process$is_alive()
  if (!alive && !is.null(state$process)) {
    state$process <- NULL
    ig_console_append(state, "\nR console session ended; starting a fresh workspace.\n")
  }
  snapshot <- if (!alive || refresh) ig_console_snapshot(store) else NULL
  if (!is.null(snapshot) && length(snapshot$skipped)) ig_console_append(state,
    paste0("Not copied (live handles): ", paste(snapshot$skipped, collapse = ", "), "\n"))
  working_directory <- if (!alive) getwd() else NULL
  state$max_chars <- isolate(store$settings)$console_max_chars %||% 300000L
  directory <- tempfile("command-", tmpdir = state$directory); dir.create(directory)
  state$pending <- list(code = code, snapshot = snapshot, directory = directory,
    output = file.path(directory, "output.txt"), offset = 0, sent = FALSE, working_directory = working_directory,
    r_options = ig_options_r_values(store), app_options = isolate(store$settings), started = Sys.time())
  if (nzchar(trimws(code))) ig_console_append(state, paste0("> ", gsub("\n", "\n+ ", code, fixed = TRUE), "\n"))
  else ig_console_append(state, "[Refresh project data]\n")
  state$status <- if (alive) "Running" else "Starting R"
  generation <- state$generation
  poll <- function() {
    if (state$closed || state$generation != generation || is.null(state$pending)) return()
    before <- list(text = state$text, status = state$status, plots = state$plots, busy = !is.null(state$pending))
    tryCatch({
      process <- state$process
      if (!process$is_alive()) stop("The console R process ended. Run another command to start a fresh workspace.")
      if (!state$pending$sent && as.numeric(difftime(Sys.time(), state$pending$started, units = "secs")) > 60)
        stop("The console R process took too long to start. Try running the command again.")
      result <- NULL
      # Reading the protocol advances callr from starting/busy to idle. Merely
      # inspecting get_state() never consumes the startup or result message.
      for (i in seq_len(20L)) {
        if (!identical(unname(process$poll_process(0)), "ready")) break
        message <- process$read()
        if (is.null(message)) break
        if (identical(message$code, 200L) || message$code >= 500L) result <- message
      }
      phase <- process$get_state()
      if (!state$pending$sent && identical(phase, "idle")) {
        worker <- ig_console_worker; environment(worker) <- baseenv()
        job <- state$pending
        process$call(worker, args = list(code = job$code, snapshot = job$snapshot,
          directory = job$directory, output = job$output, working_directory = job$working_directory,
          r_options = job$r_options, app_options = job$app_options))
        state$pending$sent <- TRUE; state$status <- "Running"
      }
      ig_console_output(state)
      if (!is.null(result) && isTRUE(state$pending$sent)) {
        ig_console_output(state)
        if (!is.null(result$error)) stop(result$error)
        state$status <- result$result$status %||% "Ready"
        state$symbols <- result$result$symbols %||% list(words = character(), fields = list(), kinds = list())
        store$r_options_discovered <- result$result$registered_options %||% list()
        plots <- list.files(state$pending$directory, pattern = "[.]png$", full.names = TRUE)
        state$plots <- c(state$plots, plots)
        retired <- head(state$plots, max(0L, length(state$plots) - 12L))
        unlink(retired); state$plots <- utils::tail(state$plots, 12L)
        unlink(state$pending$output)
        if (!length(plots)) unlink(state$pending$directory, recursive = TRUE)
        state$pending <- NULL
      }
    }, error = function(error) {
      ig_console_append(state, paste0("Error: ", conditionMessage(error), "\n"))
      state$status <- "Error"; state$pending <- NULL
      if (!is.null(state$process)) try(state$process$kill(), silent = TRUE)
      state$process <- NULL
    })
    after <- list(text = state$text, status = state$status, plots = state$plots, busy = !is.null(state$pending))
    if (!state$closed && !identical(before, after)) state$changed()
    if (!is.null(state$pending)) later::later(poll, 0.15)
  }
  tryCatch({
    if (!alive) state$process <- callr::r_session$new(options = callr::r_session_options(
      libpath = .libPaths(), system_profile = FALSE, user_profile = FALSE, supervise = TRUE), wait = FALSE)
    later::later(poll, 0.05)
  }, error = function(error) {
    ig_console_append(state, paste0("Error starting R: ", conditionMessage(error), "\n"))
    state$status <- "Error"; state$pending <- NULL
  })
  state$changed()
  invisible(TRUE)
}

console_ui <- function(id) {
  ns <- NS(id)
  div(class = "ig-console", `data-console-id` = id,
    div(class = "ig-console-toolbar",
      div(class = "ig-console-identity", span(class = "ig-console-mark", `aria-hidden` = "true", "R"),
        span("Console"), span(class = "ig-console-session", "Local session")),
      div(class = "ig-console-actions",
      actionButton(ns("refresh"), "Refresh data", class = "btn-sm", title = "Replace imported variables with current project data; keep other console variables."),
      actionButton(ns("clear"), "Clear output", class = "btn-sm", title = "Clear output and plots; keep variables (Ctrl+L)."),
      tags$button(type = "button", class = "btn btn-sm ig-console-history-toggle", "History"),
      tags$button(type = "button", class = "btn btn-sm ig-console-create-script", title = "Create a Script task from selected code, the draft, or the last command.", "Create Script"),
      actionButton(ns("reset"), "Reset R", class = "btn-sm", title = "Stop the console and clear its workspace, plots and history."),
      downloadButton(ns("download"), "Save transcript", class = "btn-sm", icon = icon("download")))),
    div(class = "ig-console-surface",
      div(class = "ig-console-history-panel", hidden = NA,
        tags$label(`for` = ns("history_search"), "Search command history"),
        tags$input(id = ns("history_search"), type = "search", class = "ig-console-history-search form-control form-control-sm", autocomplete = "off",
          `data-shiny-no-bind-input` = NA),
        tags$button(type = "button", class = "btn btn-sm ig-console-history-close", "Close history"),
        div(class = "ig-console-history-results", role = "list", `aria-label` = "Matching commands")),
      div(class = "ig-console-results", tabindex = "0", `aria-label` = "Console output",
      tags$pre(id = ns("transcript"), class = "ig-console-transcript"),
      uiOutput(ns("plots"))),
      tags$button(type = "button", class = "ig-console-latest", hidden = NA,
        `aria-label` = "Scroll to latest console output", icon("arrow-down"), " Latest output"),
      div(class = "ig-console-composer",
        span(class = "ig-console-prompt", `aria-hidden` = "true", "❯"),
        tags$label(`for` = ns("editor"), class = "visually-hidden", "R command"),
        div(class = "ig-console-input-wrap",
        tags$pre(class = "ig-console-highlight", `aria-hidden` = "true"),
        tags$textarea(id = ns("editor"), class = "ig-console-editor", rows = 1L,
          # Drafts/history search are browser state. Explicit command requests
          # and completion already have their own Shiny message channels.
          `data-shiny-no-bind-input` = NA,
          spellcheck = "false", autocomplete = "off", autocapitalize = "off", autocorrect = "off",
          maxlength = 100000L, `aria-describedby` = ns("keys"), `aria-controls` = ns("completions"), `aria-autocomplete` = "list",
          placeholder = "Enter R code…")),
        div(id = ns("completions"), class = "ig-console-completions", role = "listbox", `aria-label` = "R completions", hidden = NA),
        actionButton(ns("run"), "Run", icon = icon("play"), class = "btn-sm", title = "Run command (Enter or Ctrl+Enter)."),
        tags$button(type = "button", class = "btn btn-sm ig-console-run-selection", title = "Run selection (Ctrl+Shift+Enter).", "Selection"),
        actionButton(ns("stop"), "Stop", icon = icon("stop"), class = "btn-sm", disabled = NA,
          title = "Interrupt command and clear its R workspace (Ctrl+C with no selected text)."))),
    div(class = "ig-console-footer",
      span(id = ns("status"), role = "status", `aria-live` = "polite", "Ready"),
      span(id = ns("keys"), class = "ig-console-keys", "Enter run · Shift+Enter newline · ↑↓ history · Ctrl+L clear")),
    tags$details(class = "ig-console-info", tags$summary("About this session"),
      p("Project tables and objects are copies. Browse .project$tables and .project$objects. ",
        "Console variables are temporary; use a Script task to save work in your pipeline. ",
        "Refresh data replaces imported variables and keeps your own variables. Stop clears the R workspace; Reset R also clears output and history. ",
        "Ctrl+Enter runs multiline code; Ctrl+Shift+Enter runs a selection. Ctrl+Space offers names, functions and data columns without evaluating the text being typed. ",
        "Alt+Up/Down recalls whole commands from anywhere in the editor. History searches retained commands; Create Script copies code and inferred outputs into a reproducible task.")))
}

console_server <- function(id, store) {
  moduleServer(id, function(input, output, session) {
    revision <- reactiveVal(0L)
    state <- ig_console_state(store, session, function() revision(isolate(revision()) + 1L))
    store$console <- state
    observe({
      revision()
      session$sendCustomMessage("ig_console", list(id = session$ns(""), text = state$text,
        status = state$status, busy = !is.null(state$pending), generation = state$history_generation))
    })
    observeEvent(input$request, {
      if (!ig_console_submit(state, store, input$request$code %||% "")) state$changed()
    })
    observeEvent(input$complete, {
      request <- input$complete
      if (!is.list(request) || !is.character(request$prefix) || length(request$prefix) != 1L) return()
      session$sendCustomMessage("ig_console_completions", list(id = session$ns(""), nonce = request$nonce,
        prefix = request$prefix, items = ig_console_completions(request$prefix, store, state)))
    })
    observeEvent(input$refresh, ig_console_submit(state, store, refresh = TRUE))
    observeEvent(input$stop, {
      if (is.null(state$pending)) return()
      ig_console_output(state)
      # Terminating the isolated process reliably interrupts native R code on
      # Windows too. Its workspace is intentionally retired with the command.
      if (!is.null(state$process)) try(state$process$kill(), silent = TRUE)
      state$process <- NULL; state$pending <- NULL; state$generation <- state$generation + 1L
      state$symbols <- list(words = character(), fields = list(), kinds = list())
      ig_console_append(state, "\nStopped. Console workspace cleared; project data reloads on the next run.\n")
      state$status <- "Stopped"; state$changed()
    })
    observeEvent(input$reset, ig_console_reset(state))
    observeEvent(input$clear, {
      state$text <- ""; unlink(state$plots); state$plots <- character(); state$changed()
    })
    output$plots <- renderUI({
      revision()
      tagList(lapply(state$plots, function(path) tags$img(class = "ig-console-plot",
        src = paste0(state$prefix, "/", basename(dirname(path)), "/", basename(path)), alt = "R console plot")))
    })
    output$download <- downloadHandler(filename = function() paste0("R-console-", Sys.Date(), ".txt"),
      content = function(file) writeLines(state$text, file, useBytes = TRUE), contentType = "text/plain; charset=utf-8")
    list(reset = function() ig_console_reset(state), state = state)
  })
}
