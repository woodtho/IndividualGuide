# mod_script.R — Script task: run arbitrary R code as part of a flow
#
# The code runs in an environment that has all current flow tables and special
# outputs available as named R variables. Declare dependencies to drive Run Flow
# ordering. Declare one or more output variables to save tables or objects.

default_script_params <- function(output_name = "script_out") {
  list(
    input_tables = character(0),   # declared dependencies (drives run order)
    code         = paste0(
      "# Write your R code here.\n",
      "# Declared inputs are available as variables.\n",
      "# Assign values to declared output variables to save them.\n"
    ),
    output_name  = output_name,
    output_defs  = list(list(name = output_name, kind = "auto")),
    language     = "R"
  )
}

script_ui <- function(id) {
  ns <- NS(id)
  bslib::card(
    class = "ig-task-card",
    full_screen = TRUE,
    bslib::card_header(
      class = "d-flex align-items-center gap-2",
      icon("code"), " Script",
      div(class = "ms-auto d-flex align-items-center gap-2",
        span("Primary table:", class = "text-muted small"),
        textInput(ns("output_name"), sr_label("Primary output table name"),
          width = "160px", placeholder = "script_out"))
    ),
    bslib::card_body(
      padding = 0, class = "ig-task-tabs",
      bslib::navset_tab(
        id = ns("task_tabs"),
        bslib::nav_panel(
          tagList(icon("sliders"), " Setup"), value = "setup",
          div(class = "ig-setup-pane",
      # Input declaration panel — sets dependency edges for Run Flow ordering
      div(class = "ig-script-inputs-row",
        selectInput(ns("input_tables"),
          "Input tables / special outputs (declares run-order dependencies)",
          choices  = character(0),
          multiple = TRUE,
          width    = "100%"),
        p(class = "text-muted small mt-1 mb-2",
          icon("circle-info"),
          " All flow tables are available in code; declaring them here ensures ",
          "they run before this script.")
      ),
      # ── Ace code editor ────────────────────────────────────────────────────────
      tags$label("R code", class = "form-label small fw-semibold mb-1"),
      div(class = "ig-ace-wrap",
        shinyAce::aceEditor(
          outputId         = ns("code"),
          value            = "",
          mode             = "r",
          theme            = "tomorrow_night",
          fontSize         = 13,
          tabSize          = 2L,
          useSoftTabs      = TRUE,
          showPrintMargin  = FALSE,
          highlightActiveLine = TRUE,
          autoComplete     = "live",
          autoCompleters   = c("static", "text", "snippet"),
          autoCompleteList = list(),
          height           = "340px",
          placeholder      = "# Write your R code here.\n# Declared inputs are available as named variables."
        )
      ),
      # ── Output declarations ─────────────────────────────────────────────────────
      div(class = "mt-3",
        textAreaInput(ns("output_defs"), "Outputs",
          value = "",
          rows  = 4,
          placeholder = "clean_data: table\nfit: model\nchart: plot\nnotes: object",
          width = "100%"),
        p(class = "text-muted small mt-1 mb-0",
          "One output per line \u2014 name or name: kind. Kinds: auto, table, object, model, plot, image.")
      ),
      div(class = "mt-2",
        tags$strong(class = "small", "Saved outputs"),
        uiOutput(ns("outputs_ui"))
      )
          )
        ),
        bslib::nav_panel(
          tagList(icon("terminal"), " Results"), value = "results",
          div(class = "ig-results-pane",
            conditionalPanel(
              condition = sprintf("!output['%s']", ns("result_visible")),
              .dt_results_placeholder()),
            conditionalPanel(
              condition = sprintf("output['%s']", ns("result_visible")),
              div(class = "ig-result-panel",
                verbatimTextOutput(ns("console_out")),
                DT::DTOutput(ns("result_dt"))))
          )
        )
      )
    ),
    bslib::card_footer(
      class = "d-flex align-items-center gap-2",
      actionButton(ns("btn_run"), "Run", icon = icon("play"),
        class = "btn btn-sm btn-primary"),
      span(class = "ms-auto text-muted small",
        role = "status", `aria-live` = "polite", `aria-atomic` = "true",
        textOutput(ns("run_status"), inline = TRUE))
    )
  )
}

script_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_script_params()
      else default_script_params(paste0(task_id %||% "script", "_out"))
    })

    run_status_msg <- reactiveVal("")
    console_text   <- reactiveVal("")
    result_df      <- reactiveVal(NULL)
    saved_outputs  <- reactiveVal(list())
    sel_ready      <- reactiveVal(FALSE)        # TRUE after onFlushed sets initial selection
    prev_computed  <- reactiveVal(character(0)) # last-seen names(store$tables)

    # ── Persistent server-side mirror of the declared input selection ────────────
    # input$input_tables can be NULL before the browser has responded to the
    # initial updateSelectInput sent from onFlushed, or temporarily ambiguous
    # while Observer 1 is pushing a choices update.  declared_inputs is
    # initialised from saved params and only advances when the browser sends an
    # value after module binding, so the flow runner sees a stable list and a
    # user-cleared selection is not replaced by saved dependencies.
    declared_inputs <- reactiveVal(init_p$input_tables %||% character(0))
    observe({
      if (!store_inputs_ready(store, task_id)) return()
      declared_inputs(input$input_tables %||% character(0))
    })

    # ── Dynamic autocompletion: inject available store names into Ace ────────────
    # Fires whenever tables or objects change so the user can autocomplete any
    # variable that exists in the flow at the time they're writing code.
    observe({
      all_names <- store_available_outputs(store, task_id = task_id)   # reactive dep
      completions <- lapply(all_names, function(nm) {
        list(name = nm, value = nm, meta = "flow variable")
      })
      shinyAce::updateAceEditor(session, "code", autoCompleteList = completions)
    })

    # Available tables for input declaration: everything EXCEPT this task's own
    # output (selecting your own output as input creates a circular dependency).
    own_output_avail <- reactive({
      all_tbls <- store_available_outputs(store, task_id = task_id)
      own_outs <- script_declared_output_names(
        parse_script_output_defs(input$output_defs %||% "", input$output_name %||% ""))
      setdiff(all_tbls, own_outs)
    })

    session$onFlushed(function() {
      updateTextInput(session, "output_name", value = init_p$output_name)
      shinyAce::updateAceEditor(session, "code", value = init_p$code %||% "")
      updateTextAreaInput(session, "output_defs",
        value = format_script_output_defs(init_p$output_defs %||%
          list(list(name = init_p$output_name %||% "", kind = "auto"))))

      own_outs <- script_declared_output_names(init_p$output_defs %||%
        list(list(name = init_p$output_name %||% "", kind = "auto")))
      tbls     <- setdiff(isolate(store_available_outputs(store, task_id = task_id)), own_outs)
      computed <- names(isolate(store$tables))

      # Existing task with saved deps → restore them.
      # Brand-new task (no declared deps yet) → auto-select all currently computed tables.
      sel <- if (length(init_p$input_tables %||% character(0)))
        intersect(init_p$input_tables, tbls)
      else
        intersect(setdiff(computed, own_outs), tbls)

      prev_computed(computed)
      updateSelectInput(session, "input_tables", choices = tbls, selected = sel)
      sel_ready(TRUE)
    }, once = TRUE)

    # ── Observer 1: refresh choices ──────────────────────────────────────────────
    # Fires when available tables change or the output name changes.
    # Preserve the selection explicitly: rebuilding selectize options without
    # a selection can clear restored dependencies before binding completes.
    observe({
      tbls <- own_output_avail()
      selected <- store_preserve_choices(isolate(input$input_tables),
        isolate(declared_inputs()), tbls, initialized = store_inputs_ready(store, task_id))
      updateSelectInput(session, "input_tables", choices = tbls, selected = selected)
    })

    # ── Observer 2: auto-add newly computed tables ───────────────────────────────
    # Fires only when store$tables changes.  sel_ready is read with isolate so
    # setting it in onFlushed does NOT re-trigger this observer (avoiding a race
    # where input$input_tables is still NULL before the browser has responded).
    observe({
      computed <- names(store$tables)        # reactive dep — fires on table changes
      if (!isolate(sel_ready())) return()

      tbls     <- isolate(own_output_avail())
      prev     <- isolate(prev_computed())
      cur      <- isolate(input$input_tables) %||% character(0)
      new_ones <- setdiff(intersect(computed, tbls), prev)

      prev_computed(computed)               # advance the baseline

      if (length(new_ones)) {
        updateSelectInput(session, "input_tables",
          choices  = tbls,
          selected = unique(c(cur, new_ones)))
      }
    })

    # Collect current params (including input declaration)
    collect_p <- reactive({
      list(
        input_tables = declared_inputs(),   # stable reactiveVal — never NULL
        code         = input$code %||% "",
        output_name  = trimws(input$output_name %||% paste0(task_id %||% "script", "_out")),
        output_defs  = parse_script_output_defs(
          input$output_defs %||% "",
          trimws(input$output_name %||% paste0(task_id %||% "script", "_out"))),
        language     = "R"
      )
    })

    do_run <- function() {
      p      <- collect_p()
      tables <- isolate(store$tables)
      objects <- lapply(isolate(store$objects), `[[`, "value")

      # Pass declared outputs. If none are declared, expose every table and
      # every special output.
      scoped_tables <- if (length(p$input_tables)) {
        c(
          tables[intersect(p$input_tables, names(tables))],
          objects[intersect(p$input_tables, names(objects))]
        )
      } else {
        c(tables, objects)
      }

      result <- execute_script(p, scoped_tables)

      warn_txt <- if (length(result$warnings %||% character(0))) {
        paste(c("Warnings:", result$warnings), collapse = "\n")
      } else ""
      console_text(paste(c(result$output %||% "", warn_txt), collapse = "\n"))
      # Show the Results tab (console + table) whether the run succeeded or failed
      .desc_goto_results(session)

      if (!is.null(result$error)) {
        run_status_msg(paste("Error:", result$error))
        showNotification(result$error, type = "error", duration = 8)
        if (!is.null(task_id)) {
          task           <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, "script")
          task$error_msg <- result$error
          store_set_task(store, task)
        }
        return()
      }

      store_script_outputs(store, p, result)
      specs <- script_result_specs(p, result)
      saved_outputs(specs)

      if (length(result$warnings %||% character(0))) {
        showNotification(paste(result$warnings, collapse = "\n"), type = "warning", duration = 8)
      }

      if (!is.null(result$data)) {
        result_df(head(result$data, 1000L))
        run_status_msg(sprintf("\u2713 %d output(s) saved", length(specs)))
        showNotification(sprintf("%d script output(s) saved.", length(specs)),
          type = "message", duration = 3)
      } else {
        result_df(NULL)
        run_status_msg(sprintf("\u2713 Script completed%s",
          if (length(specs)) sprintf(" \u2014 %d output(s) saved", length(specs)) else ""))
        showNotification(if (length(specs)) sprintf("%d script output(s) saved.", length(specs)) else "Script completed.",
          type = "message", duration = 2)
      }

      if (!is.null(task_id)) {
        task           <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, "script")
        task$inputs    <- p$input_tables   # drives canvas edges + topo-sort
        task$output    <- if (!is.null(result$data)) result$primary_output %||% "" else ""
        task$outputs   <- specs
        task$params    <- p
        task$r_code    <- p$code
        task$run_time  <- Sys.time()
        task$error_msg <- NULL
        store_set_task(store, task)
      }
    }

    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })

    store_register_result_fn(store, task_id, function(result) {
      result_df(ig_preview_data(result$data))
      console_text(paste(c(result$output, result$warnings), collapse = "\n"))
      saved_outputs(if (is.null(result) || !is.null(result$error)) list() else result$specs %||% script_result_specs(collect_p(), result))
      run_status_msg(ig_preview_status(result))
    }, session = session)
    store_register_params_fn(store, task_id, collect_p, session = session)
    if (!is.null(task_id)) session$onFlushed(function() {
      store_register_runner(store, task_id, do_run)
    }, once = TRUE)
    store_register_code_fn(store, task_id, function() input$code %||% "")

    output$run_status  <- renderText(run_status_msg())
    register_preview_visible(output, run_status_msg)
    output$console_out <- renderText({
      ct <- console_text()
      if (nzchar(ct)) ct else NULL
    })
    output$result_dt <- DT::renderDT({
      req(result_df())
      DT::datatable(result_df(),
        options  = list(scrollX = TRUE, pageLength = 20, dom = "tip"),
        rownames = FALSE)
    })
    output$outputs_ui <- renderUI({
      defs <- parse_script_output_defs(input$output_defs %||% "", input$output_name %||% "")
      if (!length(defs)) return(p(class = "text-muted small", "No outputs declared."))
      tagList(lapply(defs, function(x) {
        span(class = "ig-type-badge me-1", paste0(x$name, ":", x$kind %||% "auto"))
      }))
    })
  })
}

parse_script_output_defs <- function(text, fallback_name = "") {
  lines <- trimws(unlist(strsplit(text %||% "", "\n", fixed = TRUE)))
  lines <- lines[nzchar(lines)]
  if (!length(lines) && nzchar(fallback_name %||% "")) {
    return(list(list(name = fallback_name, kind = "auto")))
  }
  allowed <- c("auto", "table", "object", "model", "plot", "image")
  defs <- lapply(lines, function(line) {
    parts <- trimws(strsplit(line, ":", fixed = TRUE)[[1L]])
    nm <- parts[1L] %||% ""
    kind <- if (length(parts) >= 2L && nzchar(parts[2L])) tolower(parts[2L]) else "auto"
    if (!kind %in% allowed) kind <- "auto"
    list(name = make.names(nm), kind = kind)
  })
  defs <- Filter(function(x) nzchar(x$name %||% ""), defs)
  defs[!duplicated(vapply(defs, `[[`, character(1), "name"))]
}

format_script_output_defs <- function(defs) {
  defs <- defs %||% list()
  paste(vapply(defs, function(x) {
    paste0(x$name %||% "", ": ", x$kind %||% "auto")
  }, character(1)), collapse = "\n")
}

script_declared_output_names <- function(defs) {
  vapply(defs %||% list(), function(x) x$name %||% "", character(1))
}


execute_script <- function(p, tables, context = list()) {
  code <- p$code %||% ""
  if (!nzchar(trimws(code)))
    return(list(data = NULL, output = "", error = "No code to run."))
  out_name <- p$output_name %||% ""

# Use only declared input tables (scoped) or all supplied outputs if none declared.
  input_tbls <- p$input_tables %||% character(0)
  scoped <- if (length(input_tbls)) tables[intersect(input_tbls, names(tables))] else tables

  # Build execution environment with scoped outputs as variables
  env <- new.env(parent = globalenv())
  for (nm in names(scoped)) env[[nm]] <- scoped[[nm]]
  for (nm in names(context)) env[[nm]] <- context[[nm]]
  env$log_event <- ig_log_event
  # Capture printed output
  output_txt <- character(0)
  warnings <- character(0)
  console_connection <- textConnection("output_txt", "w", local = TRUE)
  captured <- tryCatch({
    capture.output(
      eval(parse(text = code), envir = env),
      type = "output", file = console_connection
    )
    list(error = NULL)
  }, error = function(e) list(error = conditionMessage(e)),
    finally = close(console_connection))
  captured$output <- paste(output_txt, collapse = "\n")
  on.exit(ig_log_result(list(output = captured$output, warnings = warnings)), add = TRUE)
  if (!is.null(captured$error))
    return(list(data = NULL, output = captured$output, error = captured$error))

  defs <- p$output_defs %||% list(list(name = out_name, kind = "auto"))
  defs <- Filter(function(x) nzchar(x$name %||% ""), defs)
  outputs <- list()
  warnings <- character(0)
  for (def in defs) {
    nm <- def$name %||% ""
    if (!exists(nm, envir = env, inherits = FALSE)) {
      warnings <- c(warnings, sprintf("Declared output '%s' was not created by the script.", nm))
      next
    }
    value <- get(nm, envir = env, inherits = FALSE)
    kind <- script_resolve_output_kind(value, def$kind %||% "auto")
    if (identical(kind, "table") && !is.data.frame(value)) {
      warnings <- c(warnings, sprintf("Output '%s' is declared as table but is not a data frame.", nm))
      next
    }
    outputs[[nm]] <- list(name = nm, kind = kind, value = value)
  }

  primary <- NULL
  primary_name <- ""
  for (nm in names(outputs)) {
    if (identical(outputs[[nm]]$kind, "table")) {
      primary <- outputs[[nm]]$value
      primary_name <- nm
      break
    }
  }
  list(data = primary, outputs = outputs, primary_output = primary_name,
    output = captured$output, warnings = warnings, error = NULL)
}

script_resolve_output_kind <- function(value, kind = "auto") {
  kind <- tolower(kind %||% "auto")
  if (!identical(kind, "auto")) return(kind)
  if (is.data.frame(value)) return("table")
  if (inherits(value, "girafe")) return("plot")
  if (inherits(value, "ggplot")) return("image")
  if (inherits(value, c("lm", "glm", "aov", "kmeans", "prcomp", "nls"))) return("model")
  "object"
}

script_result_specs <- function(p, result) {
  outputs <- result$outputs %||% list()
  if (!length(outputs)) return(list())
  lapply(outputs, function(x) {
    list(name = x$name, kind = x$kind %||% "object",
      label = paste("Script output:", x$name))
  })
}

store_script_outputs <- function(store, p, result) {
  outputs <- result$outputs %||% list()
  for (nm in names(outputs)) {
    item <- outputs[[nm]]
    if (identical(item$kind, "table")) {
      store_add_table(store, item$name, item$value)
    } else {
      store_add_object(store, item$name, item$value,
        meta = list(kind = item$kind, task_type = "script"))
    }
  }
  invisible(NULL)
}
