ig_options_server <- function(id, store, changed = function(value) NULL, open_packages = function() NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    ig_options_runtime_session(session)
    selected <- shiny::reactiveVal(NULL)
    revision <- shiny::reactiveVal(0L)
    recovering <- isTRUE(getOption("IndividualGuide.options.ignore_saved"))
    message <- shiny::reactiveVal(if (recovering) "Saved R option overrides are paused for this recovery session. Edit or reset them, then restart R normally." else
      "Choose an option to see its value, scope and documentation.")
    snapshot <- NULL
    categories <- c("All options", "General", "Appearance", "Code editing", "Console", "Execution",
      "Data and results", "Plots and reports", "Files and recovery", "R options", "Package and custom R options")
    scope <- shiny::reactive(input$scope %||% "global")
    show <- function() {
      selected(NULL)
      dialog <- shiny::modalDialog(title = "Options", size = "xl", easyClose = FALSE,
        if (recovering) shiny::tags$div(class = "alert alert-warning", role = "status",
          "Saved R option overrides are paused for this recovery session. Edit or reset them, then restart R normally."),
        shiny::tags$div(class = "ig-options-scope",
          shiny::radioButtons(ns("scope"), "Save changes to", c("Global defaults" = "global", "This project" = "project"), inline = TRUE),
          shiny::tags$p(class = "small text-muted", "Projects inherit global defaults unless an option has an explicit project override.")),
        shiny::tags$div(class = "ig-options-layout",
          shiny::tags$aside(class = "ig-options-sidebar", shiny::radioButtons(ns("category"), "Category", categories),
            shiny::actionButton(ns("packages"), "R package manager", class = "btn-outline-secondary")),
          shiny::tags$section(class = "ig-options-content",
            shiny::textInput(ns("search"), "Find an option", placeholder = "Search names, descriptions and package options"),
            shiny::tags$div(class = "ig-options-tools", shiny::actionButton(ns("add"), "Add R option", class = "btn-outline-primary"),
              shiny::actionButton(ns("refresh"), "Refresh R options", class = "btn-outline-secondary")),
            DT::DTOutput(ns("options")), shiny::uiOutput(ns("editor")),
            shiny::tags$p(role = "status", `aria-live` = "polite", shiny::textOutput(ns("message"), inline = TRUE)),
            shiny::tags$details(shiny::tags$summary("Settings files and defaults"),
              shiny::tags$p("Global defaults are stored on this computer. Project overrides travel with the saved .igpx project."),
              shiny::tags$code(ig_options_file()),
              shiny::actionButton(ns("reset_scope"), "Reset this scope to inherited defaults", class = "btn-outline-secondary"),
              shiny::downloadButton(ns("export"), "Export configured R options")))),
        footer = shiny::modalButton("Close"))
      shiny::showModal(htmltools::tagAppendAttributes(dialog, class = "ig-options-modal"))
    }
    table <- shiny::reactive({
      revision(); store$option_overrides; store$r_options_discovered; .ig_options_state$revision()
      ig_options_catalog(store, trimws(input$search %||% ""), input$category %||% "All options", scope())
    })
    output$options <- DT::renderDT({
      data <- table()
      data$Edit <- vapply(seq_len(nrow(data)), function(row) as.character(shiny::tags$button(type = "button", class = "btn btn-sm btn-outline-secondary",
        `aria-label` = paste("Edit option", data$Name[[row]]),
        onclick = ig_input_event_js(ns("edit"), list(name = data$Name[[row]], domain = data$Domain[[row]])), "Edit")), character(1))
      data
    }, rownames = FALSE, selection = "none", escape = c("Name", "Label", "Category", "Value", "Source", "Domain"),
      options = list(pageLength = 6L, lengthChange = FALSE, searching = FALSE,
        rowCallback = DT::JS("function(row,data){const cells=row.querySelectorAll('td');if(cells[1])cells[1].dataset.igOptionMeta=String(data[5]==='app');if(cells[2])cells[2].dataset.igOptionMeta='true';if(cells[4])cells[4].dataset.igOptionMeta='true';if(cells[5])cells[5].dataset.igOptionMeta='true';}"),
        columnDefs = list(list(visible = FALSE, targets = 5L))))
    output$message <- shiny::renderText(message())
    shiny::observeEvent(input$edit, {
      request <- input$edit
      if (!is.list(request) || !is.character(request$name) || length(request$name) != 1L ||
          !is.character(request$domain) || length(request$domain) != 1L || !request$domain %in% c("app", "r")) return()
      if (request$domain == "app" && !request$name %in% names(ig_default_settings())) return()
      selected(list(name = request$name, domain = request$domain))
    })
    shiny::observeEvent(input$add, { selected(list(name = "", domain = "r")); message("Enter any R or package option name and its value.") })
    shiny::observeEvent(input$refresh, { revision(shiny::isolate(revision()) + 1L); message("The list now includes all currently registered R and package options.") })
    shiny::observeEvent(input$packages, open_packages())
    value <- shiny::reactive({
      revision(); store$option_overrides; store$r_options_discovered; .ig_options_state$revision()
      entry <- selected(); if (is.null(entry)) return(NULL)
      global <- ig_options_global()
      project <- shiny::isolate(store$option_overrides) %||% ig_options_empty()
      defaults <- if (entry$domain == "app") ig_default_settings() else ig_options_r_defaults()
      discovered <- if (entry$domain == "r") shiny::isolate(store$r_options_discovered)[[entry$name]] else NULL
      if (entry$domain == "r" && !entry$name %in% names(defaults) && isTRUE(discovered$has_value)) defaults[entry$name] <- list(discovered$value)
      inherited <- if (entry$name %in% names(global[[entry$domain]])) global[[entry$domain]][[entry$name]] else defaults[[entry$name]]
      result <- if (scope() == "project" && entry$name %in% names(project[[entry$domain]])) project[[entry$domain]][[entry$name]] else inherited
      metadata <- if (entry$domain == "app") Filter(function(item) item$name == entry$name, ig_options_app_catalog())[[1L]] else NULL
      kind <- if (!is.null(metadata)) metadata$type else if (!nzchar(entry$name)) "expression" else if (is.null(result)) "null" else
        if (is.logical(result) && length(result) == 1L) "logical" else if (is.integer(result) && length(result) == 1L) "integer" else
        if (is.numeric(result) && length(result) == 1L && is.finite(result)) "number" else if (is.character(result) && length(result) == 1L) "text" else "expression"
      list(actual = result, inherited = inherited, kind = kind, metadata = metadata,
        discovered = discovered,
        project_value = project[[entry$domain]][[entry$name]],
        overridden = entry$name %in% names(project[[entry$domain]]),
        text = if (kind == "text" || kind == "choice") as.character(result) else ig_options_value_text(result))
    })
    output$editor <- shiny::renderUI({
      entry <- selected(); if (is.null(entry)) return(NULL)
      current <- value()
      reference <- if (entry$domain == "r") tryCatch(jsonlite::read_json(app_sys("options", "r-options.json"))$options, error = function(e) list()) else list()
      doc <- Filter(function(item) identical(item$name, entry$name), reference)
      shiny::tags$section(class = "ig-option-editor",
        shiny::tags$h3(if (!nzchar(entry$name)) "New R option" else current$metadata$label %||% entry$name),
        if (entry$domain == "r") shiny::textInput(ns("name"), "R option name", value = entry$name) else shiny::tags$code(entry$name),
        if (length(doc)) shiny::tags$details(shiny::tags$summary("R option documentation"), shiny::tags$p(doc[[1L]]$description),
          shiny::tags$a(href = "https://stat.ethz.ch/R-manual/R-release/library/base/html/options.html", target = "_blank", rel = "noopener", "R options reference")),
        shiny::tags$p(class = "small text-muted", if (scope() == "global") "Editing the default for projects that inherit this option." else
          if (current$overridden) "This project overrides the global value." else "This project currently inherits the global value."),
        if (scope() == "global" && current$overridden) shiny::tags$details(shiny::tags$summary("This project's override remains active"), shiny::tags$pre(ig_options_value_text(current$project_value))),
        if (scope() == "project") shiny::tags$details(shiny::tags$summary("Global value"), shiny::tags$pre(ig_options_value_text(current$inherited))),
        if (!is.null(current$discovered)) shiny::tags$details(shiny::tags$summary("Current console value"), shiny::tags$pre(current$discovered$text)),
        if (entry$domain == "r") selectInput(ns("kind"), "Value type", c("Text" = "text", "Logical" = "logical", "Integer" = "integer",
          "Number" = "number", "R expression / vector / list / function" = "expression", "Unset (NULL)" = "null"), selected = current$kind),
        shiny::uiOutput(ns("value")),
        shiny::tags$p(class = "small text-muted", if (entry$domain == "r") "R expressions run only when Save option is pressed. Functions and structured values are supported." else current$metadata$description),
        shiny::tags$div(class = "ig-options-tools", shiny::actionButton(ns("save"), "Save option", class = "btn-primary"),
          shiny::actionButton(ns("inherit"), if (scope() == "project") "Use global default" else "Use built-in / R default", class = "btn-outline-secondary")))
    })
    output$value <- shiny::renderUI({
      shiny::req(selected())
      current <- value()
      kind <- if (selected()$domain == "app") current$kind else input$kind %||% current$kind
      if (kind == "null") return(shiny::tags$p(shiny::tags$code("NULL"), " removes the option in this scope."))
      if (kind == "logical") return(shiny::selectInput(ns("input"), "Value", c("TRUE", "FALSE", "NA"), selected = as.character(current$actual)))
      if (kind == "choice") {
        control <- shiny::selectInput(ns("input"), "Value", current$metadata$choices, selected = current$actual)
        control$attribs[["data-ig-choice-labels"]] <- "true"
        return(control)
      }
      if (kind %in% c("integer", "number")) return(shiny::numericInput(ns("input"), "Value",
        value = if (is.numeric(current$actual) && length(current$actual) == 1L) current$actual else 0,
        min = current$metadata$min %||% NA, max = current$metadata$max %||% NA, step = if (kind == "integer") 1 else NA))
      if (kind == "text") shiny::textInput(ns("input"), "Value", value = if (is.character(current$actual) && length(current$actual) == 1L) current$actual else current$text) else
        shiny::textAreaInput(ns("input"), "R value expression", value = ig_options_value_text(current$actual), rows = 5L, width = "100%")
    })
    editable <- function() {
      if (scope() == "project" && isTRUE(shiny::isolate(store$review_mode))) stop("Leave read-only review before changing project options.")
      if (length(shiny::isolate(store$run_ids)) || !is.null(shiny::isolate(store$background$job))) stop("Finish the running flow before changing options.")
    }
    save <- function(inherit = FALSE) tryCatch({
      editable(); entry <- selected(); if (is.null(entry)) stop("Select an option first.")
      name <- if (entry$domain == "r") trimws(input$name %||% entry$name) else entry$name
      current <- value()
      kind <- if (entry$domain == "app") current$kind else input$kind %||% current$kind
      text <- as.character(input$input %||% "")
      if (inherit) parsed <- NULL else if (kind == "choice") parsed <- text else if (identical(kind, current$kind) && identical(text, current$text) && nzchar(entry$name)) parsed <- current$actual else
        parsed <- ig_options_parse(text, kind)
      ig_options_set(store, scope(), entry$domain, name, parsed, inherit)
      selected(list(name = name, domain = entry$domain))
      revision(shiny::isolate(revision()) + 1L)
      message(if (recovering && entry$domain == "r") "Option saved. Restart R normally to apply saved R options after recovery." else
        if (inherit) "The option now inherits its default." else "Option saved. New runs and console commands use the effective value.")
    }, error = function(error) message(conditionMessage(error)))
    shiny::observeEvent(input$save, save())
    shiny::observeEvent(input$inherit, save(TRUE))
    shiny::observeEvent(input$reset_scope, tryCatch({
      editable()
      if (scope() == "global") {
        defaults <- ig_options_empty(); defaults$presentation_initialized <- TRUE
        ig_options_save_global(defaults)
      } else { store$option_overrides <- ig_options_empty(); store$dirty <- TRUE }
      ig_options_refresh(store); revision(shiny::isolate(revision()) + 1L)
      message("All options in this scope now inherit their defaults.")
    }, error = function(error) message(conditionMessage(error))))
    shiny::observe({
      .ig_options_state$revision(); store$option_overrides
      shiny::invalidateLater(2000L, session)
      if (!is.null(snapshot) && !identical(shiny::isolate(store$settings), snapshot$app)) ig_options_sync(store)
      global <- ig_options_global()
      ig_options_apply_global(global)
      effective <- ig_options_refresh(store)
      language_managed <- "language" %in% names(global$app) || isTRUE(global$presentation_initialized)
      presentation <- list(app = effective, language_global = if (language_managed) global$app$language %||% ig_default_settings()$language else NULL,
        language_project = "language" %in% names(shiny::isolate(store$option_overrides)$app))
      if (!identical(presentation, snapshot)) { snapshot <<- presentation; changed(presentation) }
    })
    output$export <- shiny::downloadHandler(filename = function() "IG-configured-R-options.R", content = function(file) {
      writeLines(c("# Effective global and project R option overrides", paste0("options(", ig_options_code(ig_options_r_values(store)), ")")), file)
    })
    list(show = show, language_preference = function(request) {
      if (!is.list(request) || !is.character(request$locale) || length(request$locale) != 1L || !request$locale %in% c("en-CA", "fr-CA")) return(invisible(NULL))
      global <- ig_options_global()
      if (isTRUE(request$initial) && ("language" %in% names(global$app) || isTRUE(global$presentation_initialized))) return(invisible(NULL))
      if (!identical(global$app$language, request$locale)) ig_options_set(store, "global", "app", "language", request$locale)
    })
  })
}
