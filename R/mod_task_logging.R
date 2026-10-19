ig_logging_rule_ui <- function(ns, rule) {
  field <- function(suffix) ns(paste0(rule$id, "_", suffix))
  json <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
  insert <- sprintf("const t=document.getElementById(%s),f=document.getElementById(%s);if(t&&f){const a=t.selectionStart??t.value.length,b=t.selectionEnd??a;t.setRangeText(f.value,a,b,'end');t.focus();t.dispatchEvent(new Event('input',{bubbles:true}));t.dispatchEvent(new Event('change',{bubbles:true}));}",
    json(field("template")), json(ns("field")))
  div(id = ns(paste0("row_", rule$id)), class = "ig-log-rule border rounded p-2 mb-2",
    div(class = "row g-2 align-items-end",
      div(class = "col-md-3", selectInput(field("event"), "When", ig_log_triggers(), rule$event)),
      div(class = "col-md-2", selectInput(field("level"), "Level",
        c(ig_log_levels(), "Keep event's level" = "EVENT"), rule$level)),
      div(class = "col-md-5", textInput(field("template"), "Message", rule$template)),
      div(class = "col-md-2 d-flex gap-1 mb-3",
        tags$button(type = "button", class = "btn btn-sm btn-outline-secondary", onclick = insert,
          title = "Insert selected field at the message cursor", `aria-label` = "Insert selected field", icon("plus")),
        tags$button(type = "button", class = "btn btn-sm btn-outline-danger",
          onclick = ig_input_event_js(ns("remove_rule"), rule$id),
          title = "Remove this log rule", `aria-label` = "Remove this log rule", icon("trash")))),
    checkboxInput(field("enabled"), "Enable this rule", rule$enabled))
}

task_logging_ui <- function(id, config = NULL, type = "task") {
  ns <- NS(id)
  config <- ig_logging_config(config, type)
  tags$details(class = "p-2 border-bottom ig-task-logging",
    ontoggle = paste0("if(window.Shiny?.shinyapp?.$socket?.readyState===1){Shiny.setInputValue(",
      jsonlite::toJSON(ns("preview_visible"), auto_unbox = TRUE), ",this.open,{priority:'event'});}"),
    tags$summary("Logging"),
    div(class = "row g-2 mt-1",
      div(class = "col-md-4",
        checkboxInput(ns("enabled"), "Record task logs", config$enabled),
        checkboxInput(ns("console"), "Capture console output", config$console)),
      div(class = "col-md-4", selectInput(ns("min_level"), "Minimum severity to record",
        choices = c("DEBUG", "INFO", "WARN", "ERROR"), selected = config$min_level)),
      div(class = "col-md-4", selectInput(ns("field"), "Field to insert into a message",
        stats::setNames(paste0("{", ig_log_fields(), "}"), names(ig_log_fields()))))),
    p(class = "small text-muted", "Build messages by choosing an event and level, then typing text or inserting fields with +. Multiple rules can match the same event. Changes save automatically. Data values and credentials are not included in fields."),
    div(id = ns("rules"), style = "max-height:26rem;overflow-y:auto;padding-right:.4rem",
      lapply(ig_logging_rules(config, type), function(rule) ig_logging_rule_ui(ns, rule))),
    div(class = "d-flex gap-2 my-2",
      actionButton(ns("add_rule"), "Add log rule", icon = icon("plus"), class = "btn btn-sm btn-outline-primary"),
      actionButton(ns("reset_rules"), "Reset task rules", icon = icon("rotate-left"), class = "btn btn-sm btn-outline-secondary")),
    p(class = "small text-muted", "Reset replaces the rules with this task type's defaults. Minimum severity and console capture still apply. Script code can call log_event('message', 'INFO')."),
    selectInput(ns("preview_event"), "Preview an event", ig_log_triggers(), "success"),
    radioButtons(ns("preview_source"), "Preview values", c("Current task data" = "current", "Example values" = "example"),
      selected = "current", inline = TRUE),
    conditionalPanel("input.preview_source === 'example'", ns = ns,
      div(class = "row g-2",
        div(class = "col-sm-4", numericInput(ns("preview_rows_in"), "Example input rows", 100, min = 0, step = 1)),
        div(class = "col-sm-4", numericInput(ns("preview_rows_out"), "Example output rows", 80, min = 0, step = 1)),
        div(class = "col-sm-4", numericInput(ns("preview_elapsed"), "Example elapsed seconds", 1.234, min = 0, step = 0.1))),
      textInput(ns("preview_message"), "Example condition or Script message", "", placeholder = "Leave blank to use an event example")),
    p(class = "small text-muted", "Preview simulates the selected event without running the task or writing a file. Current values use declared in-memory tables; n/a means unavailable. Example mode uses sample counts and paths where none are configured. Timestamp, elapsed time and condition text are examples."),
    div(class = "row g-3 ig-log-preview-grid",
      div(class = "col-xl-5", tags$h6("Message inputs"), div(class = "ig-log-inputs-scroll", uiOutput(ns("preview_inputs")))),
      div(class = "col-xl-7", tags$h6("Rendered log entries"), uiOutput(ns("preview_entries")),
        verbatimTextOutput(ns("preview")),
        selectInput(ns("preview_format"), "File output preview", c("Text" = "txt", "CSV" = "csv", "JSON" = "json")),
        verbatimTextOutput(ns("preview_file")))),
    tags$h6("Recorded entries"),
    p(class = "small text-muted", "The latest 1,000 entries per task are kept with the project. Export Log writes retained messages at their recorded levels."),
    verbatimTextOutput(ns("events")))
}

task_logging_server <- function(id, store, task_id) {
  ig_module_server(id, function(input, output, session) {
    task <- isolate(store$tasks[[task_id]])
    type <- task$type %||% "task"
    initial <- ig_logging_rules(task$logging, type)
    ids <- reactiveVal(vapply(initial, `[[`, character(1), "id"))
    next_id <- 0L
    collect <- reactive({
      req(!is.null(input$enabled), !is.null(input$console), input$min_level)
      rules <- lapply(ids(), function(id) {
        value <- function(suffix) input[[paste0(id, "_", suffix)]]
        req(!is.null(value("enabled")), value("event"), value("level"), !is.null(value("template")))
        list(id = id, enabled = isTRUE(value("enabled")), event = value("event"),
          level = value("level"), template = value("template"))
      })
      config <- ig_logging_config(isolate(store$tasks[[task_id]])$logging, type)
      config$enabled <- isTRUE(input$enabled); config$console <- isTRUE(input$console)
      config$min_level <- input$min_level; config$rules <- rules
      ig_logging_config(config, type)
    })
    observe({
      config <- collect()
      task <- isolate(store$tasks[[task_id]])
      previous <- ig_logging_config(task$logging, type)
      previous$rules <- ig_logging_rules(previous, type)
      if (is.null(task) || identical(config, previous) ||
          store_review_blocked(store, "change task logging", notify = FALSE)) return()
      task$logging <- config
      store_set_task(store, task)
    }, priority = 100)
    editable <- function() !is.null(isolate(store$tasks[[task_id]])) &&
      !store_review_blocked(store, "change task logging", notify = TRUE)
    fresh_rule <- function(rule) {
      repeat {
        next_id <<- next_id + 1L
        id <- paste0("rule_", next_id)
        if (!id %in% isolate(ids())) break
      }
      rule$id <- id
      rule
    }
    observeEvent(input$add_rule, {
      if (!editable()) return()
      if (length(ids()) >= 64L) {
        showNotification("A task can have up to 64 log rules.", type = "warning"); return()
      }
      rule <- fresh_rule(list(enabled = TRUE, event = "success", level = "INFO",
        template = "{task}: {status}; output {outputs}"))
      insertUI(paste0("#", session$ns("rules")), where = "beforeEnd", ui = ig_logging_rule_ui(session$ns, rule))
      ids(c(ids(), rule$id))
    })
    observeEvent(input$remove_rule, {
      if (!editable() || !input$remove_rule %in% ids()) return()
      removeUI(paste0("#", session$ns(paste0("row_", input$remove_rule))))
      ids(setdiff(ids(), input$remove_rule))
    })
    observeEvent(input$reset_rules, {
      if (!editable()) return()
      rules <- lapply(ig_logging_rules(NULL, type), fresh_rule)
      removeUI(paste0("#", session$ns("rules"), " > .ig-log-rule"), multiple = TRUE)
      insertUI(paste0("#", session$ns("rules")), where = "beforeEnd",
        ui = lapply(rules, function(rule) ig_logging_rule_ui(session$ns, rule)))
      ids(vapply(rules, `[[`, character(1), "id"))
    })
    scenario <- reactive({
      # Native <details> content is not consistently considered hidden by
      # Shiny's output suspension. Do no preview work until the user opens it.
      req(isTRUE(input$preview_visible))
      config <- collect(); event <- req(input$preview_event)
      task <- store$tasks[[task_id]]
      example <- identical(input$preview_source, "example")
      number <- function(value, fallback) if (length(value) == 1L && is.finite(value) && value >= 0) value else fallback
      ig_log_preview_scenario(config, task, store$tables, lapply(store$objects, `[[`, "value"), event,
        example = example, example_rows_in = floor(number(input$preview_rows_in, 100)),
        example_rows_out = floor(number(input$preview_rows_out, 80)),
        example_message = if (example) input$preview_message %||% "" else "",
        elapsed = if (example) number(input$preview_elapsed, 1.234) else 1.234,
        flow_id = store$active_flow %||% "", iteration = store$execution_context$.ig_loop_prefix %||% "")
    })
    output$preview_inputs <- renderUI({
      preview <- scenario(); fields <- ig_log_fields()
      tags$table(class = "table table-sm ig-log-input-table",
        tags$caption(if (preview$example) "Example scenario; configured task and output names are retained." else "Current task data; event/status and timing are simulated."),
        tags$thead(tags$tr(tags$th("Field"), tags$th("Value"))),
        tags$tbody(lapply(seq_along(fields), function(i) {
          value <- preview$values[[fields[[i]]]] %||% ""
          tags$tr(tags$td(tags$div(names(fields)[[i]]), tags$code(paste0("{", fields[[i]], "}"))),
            tags$td(if (nzchar(value)) value else "(empty)"))
        })))
    })
    output$preview_entries <- renderUI(ig_log_entries_ui(scenario()$entries))
    output$preview_file <- renderText(ig_log_preview_text(scenario()$entries, input$preview_format %||% "txt"))
    output$preview <- renderText({
      config <- collect(); preview <- scenario(); entries <- preview$entries
      if (!preview$enabled) return("Logging is turned off for this task.")
      if (identical(input$preview_event, "console") && !preview$console) return("Console capture is turned off.")
      unknown <- setdiff(unlist(lapply(config$rules, function(rule) ig_log_template_fields(rule$template))),
        paste0("{", c(unname(ig_log_fields()), "task_id"), "}"))
      paste(c(if (nrow(entries)) paste0("[", entries$level, "] ", entries$message)
        else "No enabled rule would record this event at the selected minimum severity.",
        if (length(unknown)) paste("Unknown fields stay literal:", paste(unknown, collapse = ", "))), collapse = "\n")
    })
    events <- ig_reactive_distinct(function() store$tasks[[task_id]]$log_events %||% list())
    session$onEnded(function() attr(events, "observer")$destroy())
    output$events <- renderText({
      req(isTRUE(input$preview_visible))
      records <- events()
      if (!length(records)) return("No log entries yet. Run the task to collect logs.")
      paste(vapply(utils::tail(records, 100L), function(x)
        sprintf("%s [%s] %s: %s", x$time, x$level, x$event, x$message), character(1)), collapse = "\n")
    })
  })
}

export_log_ui <- function(id, p = default_export_log_params()) {
  ns <- NS(id)
  bslib::card(class = "ig-task-card",
    bslib::card_header(icon("file-lines"), " Export Log"),
    bslib::card_body(
      textInput(ns("path"), "Destination file path", p$path,
        placeholder = "C:/logs/pipeline.log"),
      selectInput(ns("format"), "Format", choices = c("Text" = "txt", "CSV" = "csv", "JSON" = "json"), selected = p$format),
      checkboxInput(ns("overwrite"), "Overwrite an existing file", p$overwrite),
      selectInput(ns("min_level"), "Minimum severity to export", choices = c("DEBUG", "INFO", "WARN", "ERROR"), selected = p$min_level),
      selectizeInput(ns("after_tasks"), "Run after and include these tasks (blank = all tasks in this flow)",
        choices = stats::setNames(p$after_tasks, p$after_tasks), selected = p$after_tasks, multiple = TRUE),
      p(class = "small text-muted", "Includes retained entries from previous runs. Selected tasks may have failed or been skipped. If Stop on error halts the flow, run Export Log manually. Files contain entries collected before this export starts."),
      tags$details(class = "ig-log-export-preview border rounded p-2 mb-2", open = TRUE,
        tags$summary("Preview exported file"),
        checkboxInput(ns("example_preview"), "Show example entries instead of retained logs", FALSE),
        textOutput(ns("preview_summary")), uiOutput(ns("preview_entries")), verbatimTextOutput(ns("preview_file"))),
      verbatimTextOutput(ns("result")), downloadButton(ns("download"), "Download exported file")),
    bslib::card_footer(actionButton(ns("run"), "Export log", icon = icon("file-export"))))
}

export_log_server <- function(id, store, task_id) {
  ig_module_server(id, function(input, output, session) {
    collect <- reactive({
      list(path = input$path %||% "", format = input$format %||% "txt",
        overwrite = isTRUE(input$overwrite), min_level = input$min_level %||% "DEBUG",
        after_tasks = input$after_tasks %||% character(0))
    })
    observe({
      choices <- setdiff(names(store_ui_read(store, "tasks", store$tasks)), task_id)
      updateSelectizeInput(session, "after_tasks", choices = choices,
        selected = isolate(input$after_tasks) %||% isolate(store$tasks[[task_id]])$params$after_tasks)
    })
    store_register_params_fn(store, task_id, collect, session = session)
    store_register_code_fn(store, task_id, function() build_export_log_code(collect()))
    preview_data <- reactive({
      if (isTRUE(input$example_preview)) {
        data <- ig_log_example_records()
        ranks <- stats::setNames(seq_along(ig_log_levels()), ig_log_levels())
        return(data[ranks[data$level] >= ranks[[input$min_level %||% "DEBUG"]], , drop = FALSE])
      }
      tasks <- store$tasks
      ids <- input$after_tasks %||% character(0)
      if (!length(ids)) ids <- setdiff(names(tasks), task_id)
      ig_log_records(tasks, ids, input$min_level %||% "DEBUG", limit = 25L)
    })
    output$preview_entries <- renderUI(ig_log_entries_ui(utils::head(preview_data(), 3L)))
    output$preview_file <- renderText(ig_log_preview_text(preview_data(), input$format %||% "txt"))
    output$preview_summary <- renderText({
      if (isTRUE(input$example_preview)) return("Example entries only. Preview does not create a file or change recorded logs.")
      if (!nrow(preview_data())) return("No retained entries match this selection. Run tasks or select example entries to see an output preview.")
      "First 25 matching retained entries at most; the exported file includes all matches. Preview text is limited to 20,000 characters."
    })
    observeEvent(input$run, {
      store_sync_parameters(store)
      run_task_from_store(store, task_id)
    })
    result <- reactiveVal(NULL)
    store_register_result_fn(store, task_id, function(value) result(value), session = session)
    output$result <- renderText({
      value <- result()
      if (is.null(value)) return("Run this task to export the collected log.")
      if (!is.null(value$error)) return(paste("Error:", value$error))
      paste("Exported to", value$file)
    })
    output$download <- downloadHandler(
      filename = function() basename(result()$file %||% "pipeline.log"),
      content = function(file) {
        path <- result()$file
        req(!is.null(path), file.exists(path))
        if (!file.copy(path, file, overwrite = TRUE)) stop("Could not copy the exported log.")
      })
  })
}
