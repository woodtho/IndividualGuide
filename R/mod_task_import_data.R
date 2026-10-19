# mod_import.R — Import Data task module
#
# Import is a normal task. Each instance owns its source parameters, output
# table name, generated code, preview, and refresh action.

# File-picker roots. Computed lazily (and cached) rather than at package load
# so drive detection reflects the machine the session actually runs on.
ig_volumes <- local({
  cache <- NULL
  function(refresh = FALSE) {
    configured <- getOption("ig.file_roots")
    if (!is.null(configured)) return(configured)
    if (!refresh && !is.null(cache)) return(cache)
    home <- c(Home = path.expand("~"))
    cache <<- if (.Platform$OS.type == "windows") {
      # dir.exists() scan — works on all Windows versions (wmic is deprecated)
      drives <- paste0(LETTERS, ":/")
      drives <- drives[dir.exists(drives)]
      if (!length(drives)) drives <- "C:/"
      c(home, setNames(drives, sub("/$", "", drives)))
    } else {
      c(home, Root = "/")
    }
    cache
  }
})

IMPORT_TYPES <- c("csv", "xlsx", "xls", "rds", "rda",
                  "sas7bdat", "dta", "sav")

default_import_params <- function(output_name = "import_out") {
  list(
    source_kind = "file",
    output_name = output_name,
    path = "",
    type = "",
    csv_delim = ",",
    csv_col_names = TRUE,
    csv_skip = NULL,
    csv_na = "",
    csv_quote = "",
    csv_escape_backslash = NULL,
    csv_escape_double = NULL,
    csv_comment = "",
    csv_trim_ws = NULL,
    csv_locale = "",
    csv_col_types = "",
    csv_col_select = "",
    csv_id = "",
    csv_name_repair = "",
    csv_guess_max = NULL,
    csv_num_threads = NULL,
    csv_quoted_na = TRUE,
    csv_skip_empty_rows = NULL,
    csv_lazy = NULL,
    csv_n_max = NULL,
    excel_sheet = NULL,
    excel_range = "",
    excel_col_names = TRUE,
    excel_col_types = "",
    excel_skip = NULL,
    excel_na = "",
    excel_trim_ws = NULL,
    excel_name_repair = "",
    excel_guess_max = NULL,
    excel_progress = NULL,
    excel_n_max = NULL,
    rda_object = "",
    haven_encoding = "",
    haven_skip = NULL,
    haven_n_max = NULL,
    haven_col_select = "",
    haven_name_repair = "",
    haven_user_na = NULL,
    db_conn_mode = "code",   # "form" | "code"
    db_conn_code = paste0(
      "# DuckDB test database \u2014 4 tables: patients, visits, products, sales\n",
      "con <- DBI::dbConnect(\n",
      "  duckdb::duckdb(),\n",
      "  dbdir = \"c:/tmp/ig_test.duckdb\",\n",
      "  read_only = TRUE\n",
      ")\n",
      "\n",
      "# For other databases, replace above with e.g.:\n",
      "# con <- DBI::dbConnect(\n",
      "#   RPostgres::Postgres(),\n",
      "#   host = \"localhost\", dbname = \"mydb\",\n",
      "#   user = \"me\", password = Sys.getenv(\"DB_PASSWORD\")\n",
      "# )\n"
    ),
    db_driver = "odbc",
    db_dsn = "",
    db_host = "",
    db_port = "",
    db_database = "",
    db_uid = "",
    # db_pwd is intentionally absent — passwords are never stored in the project file.
    # The server holds the password in a session-only reactiveVal and prompts when needed.
    db_schema = "",
    db_table = "",
    db_sql = "",
    db_use_query = FALSE,
    db_collect = FALSE,    # FALSE = lazy tbl_sql (default); TRUE = collect immediately
    db_conn_label = ""     # user-facing name shown on canvas node (not the R variable name)
  )
}

import_ui <- function(id) {
  ns <- NS(id)
  bslib::card(
    class = "ig-task-card",
    full_screen = TRUE,
    bslib::card_header(
      class = "d-flex align-items-center gap-2",
      icon("database"), " Import Data",
      div(class = "ms-auto d-flex align-items-center gap-2",
        span("Output:", class = "text-muted small"),
        textInput(ns("output_name"), sr_label("Output table name"),
          placeholder = "output_table", width = "160px"))
    ),
    bslib::card_body(
      padding = 0, class = "ig-task-tabs",
      bslib::navset_tab(
        id = ns("task_tabs"),
        bslib::nav_panel(
          tagList(icon("sliders"), " Setup"), value = "setup",
          div(class = "ig-setup-pane",
      radioButtons(ns("source_kind"), "Source",
        choices = c("File" = "file", "Database" = "db"),
        selected = "file", inline = TRUE),

      conditionalPanel(
        condition = sprintf("input['%s'] == 'file'", ns("source_kind")),
        div(class = "d-flex align-items-center gap-2 mb-2",
          shinyFiles::shinyFilesButton(
            ns("file_picker"),
            label = "Browse...",
            title = "Select a data file",
            multiple = FALSE,
            icon = icon("folder-open"),
            class = "btn btn-outline-secondary btn-sm",
            style = "white-space:nowrap;"
          ),
          div(class = "text-muted small text-truncate",
            style = "max-width:520px;",
            textOutput(ns("path_display"), inline = TRUE))
        ),
        uiOutput(ns("format_badge_ui")),
        uiOutput(ns("file_options_ui")),
        tags$details(
          style = "margin-top:4px;",
          tags$summary(
            style = "font-size:0.78rem; color:#8888b0; cursor:pointer; user-select:none; list-style:none; display:flex; align-items:center; gap:4px;",
            tags$span(style = "font-size:0.65rem;", "\u25b6"),
            "More file settings"
          ),
          div(style = "padding-top:6px;",
            uiOutput(ns("file_more_settings_ui"))
          )
        )
      ),

      conditionalPanel(
        condition = sprintf("input['%s'] == 'db'", ns("source_kind")),

        # ── Connection catalogue bar ─────────────────────────────────────────────
        div(
          class = "d-flex align-items-center gap-2 mb-3 px-2 py-2 rounded",
          style = "background: rgba(255,255,255,.06); border: 1px solid rgba(255,255,255,.1);",
          icon("bookmark", class = "text-muted"),
          tags$span(class = "text-muted small", style = "white-space:nowrap;",
            "Saved connections:"),
          div(style = "flex:1; min-width:0;",
            selectInput(ns("cat_sel"), sr_label("Saved connection"),
              choices  = c("(no saved connections)" = ""),
              width    = "100%")),
          actionButton(ns("cat_load"), "Load",
            class = "btn btn-xs btn-outline-secondary",
            title = "Populate form from selected saved connection"),
          actionButton(ns("cat_delete"), "",
            icon  = icon("trash"),
            class = "btn btn-xs btn-outline-danger",
            title = "Delete selected connection from catalogue"),
          div(class = "ms-auto",
            actionButton(ns("cat_save_as"), "Save as\u2026",
              icon  = icon("bookmark"),
              class = "btn btn-xs btn-outline-primary",
              title = "Save the current connection settings to the catalogue"))
        ),

        # ── Connection name (canvas label) ──────────────────────────────────────
        # Distinct name for each DB import task — shown on the canvas node so
        # multiple DB connections are immediately identifiable.
        div(class = "mb-2",
          textInput(ns("db_conn_label"), "Connection name",
            placeholder = "e.g. Production PostgreSQL  (label shown on canvas)",
            width = "100%")
        ),

        # ── Connection mode ─────────────────────────────────────────────────────
        radioButtons(ns("db_conn_mode"), "Connection",
          choices  = c("Form" = "form", "Custom code" = "code"),
          selected = "form", inline = TRUE),

        # ── Form mode ───────────────────────────────────────────────────────────
        conditionalPanel(
          condition = sprintf("input['%s'] == 'form'", ns("db_conn_mode")),
          bslib::layout_columns(
            col_widths = c(4, 4, 4),
            selectInput(ns("db_driver"), "Driver",
              choices = c("odbc::odbc()" = "odbc", "RSQLite::SQLite()" = "sqlite"),
              width = "100%"),
            textInput(ns("db_dsn"), "DSN", width = "100%"),
            textInput(ns("db_database"), "Database / file", width = "100%")
          ),
          tags$details(
            style = "margin-top:4px;",
            tags$summary(
              style = "font-size:0.78rem; color:#8888b0; cursor:pointer; user-select:none; list-style:none; display:flex; align-items:center; gap:4px;",
              tags$span(style = "font-size:0.65rem;", "\u25b6"),
              "More connection settings"
            ),
            div(style = "padding-top:6px;",
              bslib::layout_columns(
                col_widths = c(4, 2, 6),
                textInput(ns("db_host"), "Host", width = "100%"),
                textInput(ns("db_port"), "Port", width = "100%"),
                textInput(ns("db_uid"),  "User", width = "100%")
              ),
              p(class = "text-muted small mt-1 mb-0",
                icon("lock"),
                " Password is requested securely when connecting and is never",
                " saved to the project file.")
            )
          )
        ),

        # ── Custom code mode ─────────────────────────────────────────────────────
        # textAreaInput (not Ace) so no binding-race on hidden containers.
        # conditionalPanel hides via CSS — the DOM (and input value) stay live.
        conditionalPanel(
          condition = sprintf("input['%s'] == 'code'", ns("db_conn_mode")),
          tags$label("Connection code", class = "form-label small fw-semibold mb-1"),
          textAreaInput(ns("db_conn_code"), sr_label("Connection code"),
            rows  = 8, width = "100%",
            placeholder = paste(
              "# Assign a valid DBI connection to `con`, e.g.:",
              "# con <- DBI::dbConnect(",
              "#   duckdb::duckdb(), dbdir = 'c:/tmp/ig_test.duckdb', read_only = TRUE",
              "# )",
              "# con <- DBI::dbConnect(",
              "#   RPostgres::Postgres(),",
              "#   host = 'localhost', dbname = 'mydb',",
              "#   user = 'me', password = Sys.getenv('DB_PASSWORD')",
              "# )",
              sep = "\n")
          ),
          p(class = "text-muted small mt-1 mb-0",
            icon("circle-info"),
            " Assign a valid DBI connection to ", tags$code("con"),
            ". Use ", tags$code("Sys.getenv()"), " or ",
            tags$code("keyring::key_get()"),
            " for passwords \u2014 do not paste credentials directly.")
        ),

        # ── Shared: fetch target (both modes) ───────────────────────────────────
        div(class = "mt-2",
          checkboxInput(ns("db_use_query"), "Use SQL query", FALSE),
          conditionalPanel(
            condition = sprintf("input['%s']", ns("db_use_query")),
            textAreaInput(ns("db_sql"), "SQL", rows = 5, width = "100%")
          ),
          conditionalPanel(
            condition = sprintf("!input['%s']", ns("db_use_query")),
            bslib::layout_columns(
              col_widths = c(5, 7),
              textInput(ns("db_schema"), "Schema", width = "100%"),
              textInput(ns("db_table"), "Table",  width = "100%")
            )
          )
        ),

        # ── Lazy / eager option ──────────────────────────────────────────────────
        div(class = "mt-2",
          checkboxInput(ns("db_collect"), "Collect into memory immediately", value = FALSE),
          p(class = "text-muted small mt-0 mb-0",
            icon("circle-info"),
            " Unchecked (default): a lazy reference is stored and queries",
            " run inside the database. Check to fetch everything now and close the connection.")
        )
      ),

      div(class = "d-flex gap-2 mt-2",
        actionButton(ns("btn_preview"), "Preview",
          icon = icon("eye"), class = "btn btn-sm btn-outline-secondary"),
        actionButton(ns("btn_refresh"), "Run import",
          icon = icon("rotate"), class = "btn btn-sm btn-primary"),
        span(class = "ms-auto text-muted small",
          role = "status", `aria-live` = "polite", `aria-atomic` = "true",
          textOutput(ns("run_status"), inline = TRUE))
      )
          )
        ),
        bslib::nav_panel(
          tagList(icon("table"), " Results"), value = "results",
          div(class = "ig-results-pane",
            conditionalPanel(
              condition = sprintf("!output['%s']", ns("preview_visible")),
              .dt_results_placeholder()),
            conditionalPanel(
              condition = sprintf("output['%s']", ns("preview_visible")),
              div(class = "ig-result-panel",
                div(class = "ig-preview-header",
                  span(icon("table"), " Preview (first 1 000 rows)")),
                DT::DTOutput(ns("preview"))))
          )
        )
      )
    )
  )
}

import_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    ns <- session$ns   # needed for renderUI calls that emit namespaced IDs

    init_params <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]])) {
        store$tasks[[task_id]]$params %||% default_import_params()
      } else {
        default_import_params(output_name = paste0(task_id %||% "import", "_out"))
      }
    })

    selected_path <- reactiveVal(init_params$path %||% "")
    preview_df <- reactiveVal(NULL)
    run_status <- reactiveVal("")

    shinyFiles::shinyFileChoose(input, "file_picker",
      roots = ig_volumes(),
      filetypes = IMPORT_TYPES,
      session = session)

    session$onFlushed(function() {
      updateRadioButtons(session, "source_kind",
        selected = init_params$source_kind %||% "file")
      updateTextInput(session, "output_name",
        value = init_params$output_name %||% paste0(task_id, "_out"))
      updateRadioButtons(session, "db_conn_mode",
        selected = init_params$db_conn_mode %||% "code")
      updateTextAreaInput(session, "db_conn_code",
        value = init_params$db_conn_code %||% "")
      updateSelectInput(session, "db_driver", selected = init_params$db_driver %||% "odbc")
      for (nm in c("db_dsn", "db_host", "db_port", "db_database", "db_uid",
                   "db_schema", "db_table")) {
        updateTextInput(session, nm, value = init_params[[nm]] %||% "")
      }
      updateTextAreaInput(session, "db_sql", value = init_params$db_sql %||% "")
      updateTextInput(session, "db_conn_label",
        value = init_params$db_conn_label %||% "")
      updateCheckboxInput(session, "db_use_query", value = isTRUE(init_params$db_use_query))
      updateCheckboxInput(session, "db_collect",   value = isTRUE(init_params$db_collect %||% FALSE))
      # NOTE: db_pwd is intentionally NOT restored — it is session-only and was never saved.
    }, once = TRUE)

    # ── Connection catalogue ──────────────────────────────────────────────────
    # cat_rev bumps whenever the catalogue file changes (add / delete).
    # Any observer that depends on it will re-run and refresh the selectInput.
    cat_rev <- reactiveVal(0L)
    catalogue_change <- function(fn) {
      tryCatch({ fn(); TRUE }, error = function(e) {
        showNotification(conditionMessage(e), type = "error", duration = 8)
        FALSE
      })
    }

    refresh_cat_choices <- function() {
      choices <- cat_choices()
      if (length(choices) == 0L) {
        updateSelectInput(session, "cat_sel",
          choices = c("(no saved connections)" = ""))
      } else {
        updateSelectInput(session, "cat_sel",
          choices = c("\u2014 select \u2014" = "", choices))
      }
    }

    # Initialise the selectInput on first flush (catalogue is on disk, not reactive)
    session$onFlushed(refresh_cat_choices, once = TRUE)

    # Refresh when catalogue changes
    observeEvent(cat_rev(), {
      if (cat_rev() > 0L) refresh_cat_choices()
    }, ignoreInit = TRUE)

    # Load selected connection into the form
    observeEvent(input$cat_load, {
      id <- trimws(input$cat_sel %||% "")
      if (!nzchar(id)) {
        showNotification("Select a saved connection first.", type = "warning", duration = 3)
        return()
      }
      entry <- cat_find(id)
      if (is.null(entry)) {
        showNotification("Connection not found \u2014 it may have been deleted.",
          type = "error", duration = 5)
        return()
      }
      # Populate form
      updateRadioButtons(session, "db_conn_mode",
        selected = entry$conn_mode %||% "form")
      updateSelectInput(session, "db_driver",
        selected = entry$db_driver %||% "odbc")
      for (nm in c("db_dsn", "db_host", "db_port", "db_database", "db_uid", "db_schema")) {
        updateTextInput(session, nm, value = entry[[nm]] %||% "")
      }
      updateTextAreaInput(session, "db_conn_code",
        value = entry$db_conn_code %||% "")
      # Show the extra fields if host/user are populated
      if (nzchar(entry$db_host %||% "") || nzchar(entry$db_uid %||% ""))
        updateCheckboxInput(session, "show_db_settings", value = TRUE)
      # Set the connection name to the catalogue entry name
      updateTextInput(session, "db_conn_label", value = entry$name %||% "")
      showNotification(
        paste0("\u2713 '", entry$name, "' loaded. Re-enter password to connect."),
        type = "message", duration = 5)
    })

    # Delete selected connection
    observeEvent(input$cat_delete, {
      id <- trimws(input$cat_sel %||% "")
      if (!nzchar(id)) {
        showNotification("Select a connection to delete.", type = "warning", duration = 3)
        return()
      }
      entry <- cat_find(id)
      name  <- if (!is.null(entry)) entry$name %||% id else id
      if (!catalogue_change(function() cat_delete(id))) return()
      cat_rev(cat_rev() + 1L)
      showNotification(paste0("'", name, "' removed from catalogue."),
        type = "message", duration = 3)
    })

    # Save as… — prompt for a display name via modal
    observeEvent(input$cat_save_as, {
      showModal(modalDialog(
        title  = tagList(icon("bookmark"), " Save connection to catalogue"),
        size   = "s",
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("cat_save_confirm"), "Save",
            icon  = icon("floppy-disk"),
            class = "btn btn-primary")
        ),
        textInput(ns("cat_save_name"), "Connection name",
          placeholder = "e.g. Production Postgres",
          width = "100%"),
        p(class = "text-muted small mb-0 mt-2",
          icon("lock"), " Password fields are not saved. Connection code is saved as written.")
      ))
    })

    observeEvent(input$cat_save_confirm, {
      name <- trimws(input$cat_save_name %||% "")
      if (!nzchar(name)) {
        showNotification("Enter a name for this connection.", type = "warning", duration = 3)
        return()
      }
      entry <- cat_entry_from_inputs(name, input)
      if (!catalogue_change(function() cat_add(entry))) return()
      cat_rev(cat_rev() + 1L)
      removeModal()
      showNotification(paste0("\u2713 '", name, "' saved to connection catalogue."),
        type = "message", duration = 3)
    })

    # Auto-suggest a connection name when DSN / database / host is filled in
    # and the connection name field is still empty.  Uses isolate() on the
    # label read so this observer only fires when the connection fields change,
    # not every time the user types in the label box itself.
    observe({
      req(identical(input$source_kind, "db"))
      dsn  <- trimws(input$db_dsn      %||% "")
      db   <- trimws(input$db_database %||% "")
      host <- trimws(input$db_host     %||% "")
      current <- isolate(trimws(input$db_conn_label %||% ""))
      if (nzchar(current)) return()   # don't overwrite what the user typed
      suggestion <- if (nzchar(dsn)) dsn else if (nzchar(db)) db else host
      if (nzchar(suggestion))
        updateTextInput(session, "db_conn_label", value = suggestion)
    })

    observeEvent(input$file_picker, {
      info <- shinyFiles::parseFilePaths(ig_volumes(), input$file_picker)
      if (nrow(info) > 0L) {
        p <- normalizePath(as.character(info$datapath[1]), mustWork = FALSE)
        selected_path(p)
        updateTextInput(session, "output_name",
          value = make.names(tools::file_path_sans_ext(basename(p))))
      }
    })

    path_ext <- reactive({
      p <- selected_path()
      ext <- tolower(tools::file_ext(p))
      if (nzchar(ext)) ext else init_params$type %||% ""
    })

    output$path_display <- renderText({
      p <- selected_path()
      if (nzchar(p)) p else "(no file selected)"
    })

    output$format_badge_ui <- renderUI({
      req(identical(input$source_kind, "file"))
      ext <- path_ext()
      if (!nzchar(ext)) return(NULL)
      span(class = "ig-format-badge", toupper(ext))
    })

    output$file_options_ui <- renderUI({
      ext <- path_ext()
      if (ext %in% c("xlsx", "xls")) {
        selectInput(session$ns("excel_sheet"), "Sheet",
          choices = get_excel_sheets(selected_path()),
          selected = init_params$excel_sheet %||% NULL,
          width = "100%")
      } else if (ext == "csv") {
        bslib::layout_columns(
          col_widths = c(6, 6),
          selectInput(session$ns("csv_delim"), "Delimiter",
            choices = c(Comma = ",", Tab = "\t", Semicolon = ";", Pipe = "|"),
            selected = init_params$csv_delim %||% ","),
          checkboxInput(session$ns("csv_col_names"),
            "First row is header", value = isTRUE(init_params$csv_col_names))
        )
      } else if (ext == "rda") {
        textInput(session$ns("rda_object"), "Object name in .RData",
          value = init_params$rda_object %||% "",
          placeholder = "blank loads the first object")
      } else {
        NULL
      }
    })

    output$file_more_settings_ui <- renderUI({
      ext <- path_ext()
      if (ext == "csv") {
        bslib::layout_columns(
          col_widths = c(3, 3, 3, 3),
          numericInput(session$ns("csv_skip"), "skip", finite_or_na(init_params$csv_skip), min = 0),
          textInput(session$ns("csv_na"), "na", init_params$csv_na %||% ""),
          textInput(session$ns("csv_quote"), "quote", init_params$csv_quote %||% ""),
          textInput(session$ns("csv_comment"), "comment", init_params$csv_comment %||% ""),
          checkboxInput(session$ns("csv_escape_backslash"), "escape_backslash", isTRUE(init_params$csv_escape_backslash)),
          checkboxInput(session$ns("csv_escape_double"), "escape_double", !isFALSE(init_params$csv_escape_double)),
          checkboxInput(session$ns("csv_trim_ws"), "trim_ws", isTRUE(init_params$csv_trim_ws)),
          textInput(session$ns("csv_locale"), "locale", init_params$csv_locale %||% ""),
          textInput(session$ns("csv_col_types"), "col_types", init_params$csv_col_types %||% ""),
          textInput(session$ns("csv_col_select"), "col_select", init_params$csv_col_select %||% ""),
          textInput(session$ns("csv_id"), "id", init_params$csv_id %||% ""),
          textInput(session$ns("csv_name_repair"), "name_repair", init_params$csv_name_repair %||% ""),
          numericInput(session$ns("csv_guess_max"), "guess_max", finite_or_na(init_params$csv_guess_max), min = 1),
          numericInput(session$ns("csv_num_threads"), "num_threads", finite_or_na(init_params$csv_num_threads), min = 1),
          checkboxInput(session$ns("csv_quoted_na"), "Treat quoted NA as missing", !isFALSE(init_params$csv_quoted_na)),
          conditionalPanel(sprintf("input['%s'] === false", session$ns("csv_quoted_na")),
            p(class = "text-muted small", "Keeping quoted NA as text uses readr's legacy parser. Lazy and parallel reading do not apply.")),
          checkboxInput(session$ns("csv_skip_empty_rows"), "skip_empty_rows", !isFALSE(init_params$csv_skip_empty_rows)),
          checkboxInput(session$ns("csv_lazy"), "lazy", isTRUE(init_params$csv_lazy)),
          numericInput(session$ns("csv_n_max"), "n_max", finite_or_na(init_params$csv_n_max), min = 1)
        )
      } else if (ext %in% c("xlsx", "xls")) {
        bslib::layout_columns(
          col_widths = c(3, 3, 3, 3),
          textInput(session$ns("excel_range"), "range", init_params$excel_range %||% ""),
          checkboxInput(session$ns("excel_col_names"), "col_names", isTRUE(init_params$excel_col_names)),
          textInput(session$ns("excel_col_types"), "col_types", init_params$excel_col_types %||% ""),
          numericInput(session$ns("excel_skip"), "skip", finite_or_na(init_params$excel_skip), min = 0),
          textInput(session$ns("excel_na"), "na", init_params$excel_na %||% ""),
          checkboxInput(session$ns("excel_trim_ws"), "trim_ws", !isFALSE(init_params$excel_trim_ws)),
          textInput(session$ns("excel_name_repair"), "name_repair", init_params$excel_name_repair %||% ""),
          numericInput(session$ns("excel_guess_max"), "guess_max", finite_or_na(init_params$excel_guess_max), min = 1),
          checkboxInput(session$ns("excel_progress"), "progress", isTRUE(init_params$excel_progress)),
          numericInput(session$ns("excel_n_max"), "n_max", finite_or_na(init_params$excel_n_max), min = 1)
        )
      } else if (ext %in% c("sas7bdat", "dta", "sav")) {
        bslib::layout_columns(
          col_widths = c(3, 3, 3, 3),
          textInput(session$ns("haven_encoding"), "encoding",
            value = init_params$haven_encoding %||% ""),
          numericInput(session$ns("haven_skip"), "skip", finite_or_na(init_params$haven_skip), min = 0),
          numericInput(session$ns("haven_n_max"), "n_max", finite_or_na(init_params$haven_n_max), min = 1),
          textInput(session$ns("haven_col_select"), "col_select", init_params$haven_col_select %||% ""),
          textInput(session$ns("haven_name_repair"), "name_repair", init_params$haven_name_repair %||% ""),
          if (ext == "sav") checkboxInput(session$ns("haven_user_na"), "user_na", isTRUE(init_params$haven_user_na))
        )
      } else {
        div(class = "text-muted small", "No additional settings for this file type.")
      }
    })

    collect_params <- reactive({
      list(
        source_kind = input$source_kind %||% "file",
        output_name = trimws(input$output_name %||% ""),
        path = selected_path(),
        type = path_ext(),
        csv_delim = input$csv_delim %||% ",",
        csv_col_names = isTRUE(input$csv_col_names),
        csv_skip = set_number(input$csv_skip),
        csv_na = input$csv_na %||% "",
        csv_quote = input$csv_quote %||% "",
        csv_escape_backslash = set_bool(input$csv_escape_backslash),
        csv_escape_double = set_bool(input$csv_escape_double),
        csv_comment = input$csv_comment %||% "",
        csv_trim_ws = set_bool(input$csv_trim_ws),
        csv_locale = input$csv_locale %||% "",
        csv_col_types = input$csv_col_types %||% "",
        csv_col_select = input$csv_col_select %||% "",
        csv_id = input$csv_id %||% "",
        csv_name_repair = input$csv_name_repair %||% "",
        csv_guess_max = set_number(input$csv_guess_max),
        csv_num_threads = set_number(input$csv_num_threads),
        csv_quoted_na = set_bool(input$csv_quoted_na),
        csv_skip_empty_rows = set_bool(input$csv_skip_empty_rows),
        csv_lazy = set_bool(input$csv_lazy),
        csv_n_max = set_number(input$csv_n_max),
        excel_sheet = input$excel_sheet %||% NULL,
        excel_range = input$excel_range %||% "",
        excel_col_names = isTRUE(input$excel_col_names),
        excel_col_types = input$excel_col_types %||% "",
        excel_skip = set_number(input$excel_skip),
        excel_na = input$excel_na %||% "",
        excel_trim_ws = set_bool(input$excel_trim_ws),
        excel_name_repair = input$excel_name_repair %||% "",
        excel_guess_max = set_number(input$excel_guess_max),
        excel_progress = set_bool(input$excel_progress),
        excel_n_max = set_number(input$excel_n_max),
        rda_object = input$rda_object %||% "",
        haven_encoding = input$haven_encoding %||% "",
        haven_skip = set_number(input$haven_skip),
        haven_n_max = set_number(input$haven_n_max),
        haven_col_select = input$haven_col_select %||% "",
        haven_name_repair = input$haven_name_repair %||% "",
        haven_user_na = set_bool(input$haven_user_na),
        db_conn_mode = input$db_conn_mode %||% "code",
        db_conn_code = input$db_conn_code %||% "",
        db_driver = input$db_driver %||% "odbc",
        db_dsn = input$db_dsn %||% "",
        db_host = input$db_host %||% "",
        db_port = input$db_port %||% "",
        db_database = input$db_database %||% "",
        db_uid = input$db_uid %||% "",
        # db_pwd is intentionally omitted — password lives only in session_pwd()
        db_schema = input$db_schema %||% "",
        db_table = input$db_table %||% "",
        db_sql = input$db_sql %||% "",
        db_use_query = isTRUE(input$db_use_query),
        db_collect = isTRUE(input$db_collect),
        db_conn_label = trimws(input$db_conn_label %||% "")
      )
    })

    # ── Session-only password store ───────────────────────────────────────────
    # Never persisted to disk.  Held in memory for the lifetime of the session.
    session_pwd    <- reactiveVal(store_db_password(store, task_id))
    pending_action <- reactiveVal(NULL) # "preview" | "refresh" | NULL

    # TRUE when a DB form-mode ODBC connection with a user-name is configured
    # (i.e., a password is almost certainly required).
    db_needs_pwd <- ig_import_needs_password

    is_auth_error <- function(msg) {
      grepl(
        paste(c("auth", "password", "login.{0,10}fail", "access.denied",
                "invalid.{0,10}credential", "SQLSTATE\\[28", "28000", "28P01"),
              collapse = "|"),
        msg, ignore.case = TRUE, perl = TRUE)
    }

    show_pwd_modal <- function(auth_error = NULL) {
      showModal(modalDialog(
        title     = tags$span(icon("key"), " Database password"),
        size      = "s",
        easyClose = FALSE,
        if (!is.null(auth_error))
          div(class = "alert alert-warning small mb-3 py-2",
              icon("triangle-exclamation"), " Authentication failed \u2014 check your password."),
        passwordInput(ns("modal_pwd"), "Password", width = "100%"),
        footer = tagList(
          actionButton(ns("modal_pwd_cancel"), "Cancel", class = "btn btn-secondary"),
          actionButton(ns("modal_pwd_ok"), "Connect", class = "btn btn-primary")
        )
      ))
    }

    # ── Core action: run the import (with password already resolved) ──────────
    do_attempt <- function(register = TRUE) {
      p   <- collect_params()
      pwd <- if (db_needs_pwd(p)) session_pwd() else ""

      err <- validate_import_params(p)
      if (!is.null(err)) {
        if (register) run_status(paste("Error:", err))
        showNotification(err, type = "error", duration = 8)
        if (register && !is.null(task_id)) return(store_task_failed(store, task_id, err))
        return(invisible(FALSE))
      }

      result <- execute_import(p, pwd = pwd)

      # Auth failure: clear cached password and re-prompt
      if (!is.null(result$error) && db_needs_pwd(p) && is_auth_error(result$error)) {
        session_pwd("")
        if (!is.null(task_id)) assign(task_id, "", envir = isolate(store$db_passwords))
        pending_action(if (register) "refresh" else "preview")
        show_pwd_modal(auth_error = result$error)
        return(invisible(ig_pending_task(task_id)))
      }

      if (!is.null(result$error)) {
        if (register) run_status(paste("Error:", result$error))
        showNotification(result$error, type = "error", duration = 8)
        if (register && !is.null(task_id)) return(store_task_failed(store, task_id, result$error))
        return(invisible(FALSE))
      }

      # Preview connections are short-lived; registered lazy imports belong
      # to the project store and remain valid while another flow is active.
      transferred <- FALSE
      on.exit(if (isTRUE(result$lazy) && !transferred && DBI::dbIsValid(result$con))
        DBI::dbDisconnect(result$con), add = TRUE)

      # Preview: for lazy tbls push LIMIT 1000 to the DB; for eager tbls just head()
      preview_slice <- if (isTRUE(result$lazy)) {
        tryCatch(
          as.data.frame(dplyr::collect(dplyr::slice_head(result$data, n = 1000L))),
          error = function(e)
            tryCatch(as.data.frame(dplyr::collect(utils::head(result$data, 1000L))),
                     error = function(e2) NULL)
        )
      } else {
        head(result$data, 1000L)
      }
      preview_df(preview_slice)

      if (register) {
        if (!is.null(task_id)) {
          store_register_connection(store, task_id, result$con)
          transferred <- isTRUE(result$lazy)
        }
        meta <- import_source_meta(p, task_id, result$data)
        store_add_table(store, p$output_name, result$data, source_meta = meta)
        if (!is.null(task_id)) {
          task           <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, "import_data")
          task$inputs    <- character(0)
          task$output    <- p$output_name
          task$params    <- p          # pwd is NOT in p
          task$r_code    <- build_import_code(p)
          task$run_time  <- Sys.time()
          task$error_msg <- NULL
          # Propagate the connection label to the task so the canvas node shows it
          if (identical(p$source_kind, "db") && nzchar(p$db_conn_label %||% ""))
            task$label <- p$db_conn_label
          store_set_task(store, task)
        }
        if (isTRUE(result$lazy)) {
          run_status(sprintf("%s: lazy tbl (%d cols)", p$output_name, ncol(result$data)))
          showNotification("Import registered (lazy connection).", type = "message", duration = 3)
        } else {
          run_status(sprintf("%s: %d rows \u00d7 %d cols",
            p$output_name, nrow(result$data), ncol(result$data)))
          showNotification("Import refreshed.", type = "message", duration = 3)
        }
      }
    }

    # ── Preview button ────────────────────────────────────────────────────────
    observeEvent(input$btn_preview, {
      p <- collect_params()
      if (db_needs_pwd(p) && !nzchar(session_pwd())) {
        pending_action("preview")
        show_pwd_modal()
      } else {
        do_attempt(register = FALSE)
      }
    })

    # ── Refresh / Run import button ───────────────────────────────────────────
    observeEvent(input$btn_refresh, {
      if (store_review_blocked(store, "run imports")) return()
      store_run_guarded(store, do_run, task_id = task_id)
    })

    # ── Password modal — OK ───────────────────────────────────────────────────
    observeEvent(input$modal_pwd_ok, {
      pwd    <- input$modal_pwd %||% ""
      action <- pending_action()
      if (is.null(action)) return()
      removeModal()
      pending_action(NULL)
      if (!nzchar(pwd)) {
        pending_action(action)
        show_pwd_modal()
        return()
      }
      session_pwd(pwd)
      if (!is.null(task_id)) assign(task_id, pwd, envir = isolate(store$db_passwords))
      if (identical(action, "preview")) do_attempt(register = FALSE)
      else if (!store_review_blocked(store, "run imports")) {
        result <- store_run_guarded(store, function() do_attempt(register = TRUE), task_id = task_id)
        if (!inherits(result, "ig_pending_task")) store_resume_run_queue(store, task_id)
      }
    })

    observeEvent(input$modal_pwd_cancel, {
      action <- pending_action()
      pending_action(NULL)
      removeModal()
      if (identical(action, "refresh") && !is.null(task_id)) {
        store_task_skipped(store, task_id, "Database connection cancelled.")
        store_resume_run_queue(store, task_id)
      }
    })

    observeEvent(store$run_generation, {
      if (identical(pending_action(), "refresh") && is.null(isolate(store$run_waiting)))
        pending_action(NULL)
    }, ignoreInit = TRUE, priority = 250)

    do_run <- function() {
      p <- collect_params()
      if (db_needs_pwd(p) && !nzchar(session_pwd())) {
        pending_action("refresh")
        show_pwd_modal()
        return(invisible(ig_pending_task(task_id)))
      }
      do_attempt(register = TRUE)
    }
    store_register_result_fn(store, task_id, function(result) {
      preview_df(ig_preview_data(result$data, 200L)); run_status(ig_preview_status(result))
    }, session = session)
    store_register_params_fn(store, task_id, collect_params, session = session)
    if (!is.null(task_id)) session$onFlushed(function() {
      store_register_runner(store, task_id, do_run)
    }, once = TRUE)
    store_register_code_fn(store, task_id,
      function() build_import_code(collect_params()))

    output$run_status <- renderText(run_status())
    output$preview_visible <- reactive(!is.null(preview_df()))
    outputOptions(output, "preview_visible", suspendWhenHidden = FALSE)
    # Jump to the Results tab whenever a preview/import produces data
    observeEvent(preview_df(), {
      if (!is.null(preview_df()))
        bslib::nav_select("task_tabs", "results", session = session)
    }, ignoreInit = TRUE)
    output$preview <- DT::renderDT({
      req(preview_df())
      DT::datatable(preview_df(),
        options = list(scrollX = TRUE, pageLength = ig_page_len(store), dom = "tip"),
        rownames = FALSE)
    })
  })
}

get_excel_sheets <- function(path) {
  if (!nzchar(path) || !file.exists(path)) return(character(0))
  tryCatch(readxl::excel_sheets(path), error = function(e) character(0))
}

finite_or_na <- function(x) {
  if (is.null(x) || !is.finite(x)) NA_real_ else x
}

validate_import_params <- function(p) {
  if (!nzchar(p$output_name %||% ""))
    return("Output table name is required.")
  if (!p$source_kind %in% c("file", "db")) return("Choose a file or database source.")
  if (identical(p$source_kind, "file")) {
    if (!nzchar(p$path %||% "")) return("Select a file to import.")
    if (!file.exists(p$path)) return(paste("File does not exist:", p$path))
    if (!tolower(tools::file_ext(p$path)) %in% IMPORT_TYPES)
      return("Unsupported file type.")
  } else if (identical(p$source_kind, "db")) {
    conn_mode <- p$db_conn_mode %||% "form"
    if (identical(conn_mode, "code")) {
      if (!nzchar(trimws(p$db_conn_code %||% "")))
        return("Connection code is required.")
    } else {
      if (!p$db_driver %in% c("sqlite", "odbc"))
        return("Choose a supported database driver (SQLite or ODBC).")
      if (identical(p$db_driver, "odbc") && !nzchar(p$db_dsn %||% "") &&
          !nzchar(p$db_host %||% ""))
        return("ODBC imports require either a DSN or host connection settings.")
      if (identical(p$db_driver, "sqlite") && !nzchar(p$db_database %||% ""))
        return("SQLite imports require a database file path.")
    }
    # Shared for both modes: must specify a table or a query
    if (isTRUE(p$db_use_query) && !nzchar(trimws(p$db_sql %||% "")))
      return("SQL is required when using a database query.")
    if (!isTRUE(p$db_use_query) && !nzchar(trimws(p$db_table %||% "")))
      return("Database table is required unless using a SQL query.")
  }
  NULL
}

execute_import <- function(p, pwd = "") {
  tryCatch({
    problem <- validate_import_params(p)
    if (!is.null(problem)) return(list(data = NULL, con = NULL, lazy = FALSE, error = problem))
    if (identical(p$source_kind, "db")) {
      res  <- read_db_source(p, pwd = pwd)
      # Lazy: keep tbl_sql as-is so queries can be pushed to the DB.
      # Eager: coerce to a plain data frame immediately.
      data <- if (isTRUE(res$lazy)) res$data else as.data.frame(res$data)
      list(data = data, con = res$con, lazy = isTRUE(res$lazy), error = NULL)
    } else {
      list(data = as.data.frame(read_file_source(p)),
           con  = NULL, lazy = FALSE, error = NULL)
    }
  }, error = function(e) {
    list(data = NULL, con = NULL, lazy = FALSE, error = conditionMessage(e))
  })
}

import_file_type <- function(p) {
  type <- p$type %||% ""
  tolower(if (nzchar(type)) type else tools::file_ext(p$path %||% ""))
}

read_file_source <- function(p) {
  ext <- import_file_type(p)
  switch(ext,
    csv = {
      args <- list(
        file = p$path,
        delim = p$csv_delim,
        col_names = isTRUE(p$csv_col_names),
        show_col_types = FALSE
      )
      args <- add_arg(args, "skip", p$csv_skip)
      args <- add_arg(args, "na", split_na(p$csv_na), allow_empty = FALSE)
      args <- add_arg(args, "quote", p$csv_quote)
      args <- add_arg(args, "escape_backslash", p$csv_escape_backslash)
      args <- add_arg(args, "escape_double", p$csv_escape_double)
      args <- add_arg(args, "comment", p$csv_comment)
      args <- add_arg(args, "trim_ws", p$csv_trim_ws)
      if (nzchar(p$csv_locale %||% ""))
        args$locale <- readr::locale(date_format = p$csv_locale)
      args <- add_arg(args, "name_repair", p$csv_name_repair)
      args <- add_arg(args, "guess_max", p$csv_guess_max)
      args <- add_arg(args, "num_threads", p$csv_num_threads)
      if (identical(p$csv_quoted_na, FALSE)) args$quoted_na <- FALSE
      args <- add_arg(args, "n_max", p$csv_n_max)
      args <- add_arg(args, "skip_empty_rows", p$csv_skip_empty_rows)
      args <- add_arg(args, "lazy", p$csv_lazy)
      if (nzchar(p$csv_col_types %||% "")) args$col_types <- p$csv_col_types
      if (nzchar(p$csv_col_select %||% "")) args$col_select <- parse_col_select(p$csv_col_select)
      if (nzchar(p$csv_id %||% "")) args$id <- p$csv_id
      if (identical(p$csv_quoted_na, FALSE)) ig_read_legacy_csv(args) else do.call(readr::read_delim, args)
    },
    xlsx = ,
    xls = {
      args <- list(path = p$path, col_names = isTRUE(p$excel_col_names))
      args <- add_arg(args, "sheet", p$excel_sheet)
      args <- add_arg(args, "range", p$excel_range)
      args <- add_arg(args, "col_types", split_or_null(p$excel_col_types), allow_empty = FALSE)
      args <- add_arg(args, "skip", p$excel_skip)
      args <- add_arg(args, "na", split_na(p$excel_na), allow_empty = FALSE)
      args <- add_arg(args, "trim_ws", p$excel_trim_ws)
      args <- add_arg(args, "n_max", p$excel_n_max)
      args <- add_arg(args, "guess_max", p$excel_guess_max)
      args <- add_arg(args, "progress", p$excel_progress)
      args <- add_arg(args, ".name_repair", p$excel_name_repair)
      do.call(readxl::read_excel, args)
    },
    rds = ig_restore_object_namespaces(readRDS(p$path)),
    rda = {
      e <- new.env(parent = emptyenv())
      load(p$path, envir = e)
      obj <- if (nzchar(p$rda_object %||% "")) p$rda_object else ls(e)[1]
      ig_restore_object_namespaces(get(obj, envir = e))
    },
    sas7bdat = do.call(haven::read_sas, haven_args(p, user_na = FALSE)),
    dta = do.call(haven::read_dta, haven_args(p, user_na = FALSE)),
    sav = do.call(haven::read_sav, haven_args(p, user_na = TRUE)),
    stop("Unsupported file type: .", ext)
  )
}

read_db_source <- function(p, pwd = "") {
  if (!requireNamespace("DBI", quietly = TRUE))
    stop("Package DBI is required for database imports.")

  lazy <- !isTRUE(p$db_collect)   # lazy = TRUE by default

  # ── Custom connection code mode ─────────────────────────────────────────────
  if (identical(p$db_conn_mode %||% "form", "code")) {
    env <- new.env(parent = globalenv())
    transferred <- FALSE
    on.exit({
      candidate <- get0("con", envir = env, inherits = FALSE)
      if (!transferred && inherits(candidate, "DBIConnection") && DBI::dbIsValid(candidate))
        try(DBI::dbDisconnect(candidate), silent = TRUE)
    }, add = TRUE)
    tryCatch(
      eval(parse(text = p$db_conn_code %||% ""), envir = env),
      error = function(e) stop("Connection code error: ", conditionMessage(e))
    )
    if (!exists("con", envir = env, inherits = FALSE) ||
        !inherits(get("con", envir = env, inherits = FALSE), "DBIConnection"))
      stop("Connection code must assign a valid DBI connection to 'con'.")
    con <- get("con", envir = env, inherits = FALSE)
    # Eager: disconnect when this function exits. Lazy: caller owns the connection.
    data <- fetch_db_data(con, p, lazy = lazy)
    transferred <- lazy
    return(list(data = data, con = if (lazy) con else NULL, lazy = lazy))
  }

  # ── Form mode ───────────────────────────────────────────────────────────────
  con <- NULL

  if (identical(p$db_driver, "sqlite")) {
    if (!requireNamespace("RSQLite", quietly = TRUE))
      stop("Package RSQLite is required for SQLite imports.")
    con <- DBI::dbConnect(RSQLite::SQLite(), dbname = p$db_database)
  } else {
    if (!requireNamespace("odbc", quietly = TRUE))
      stop("Package odbc is required for ODBC imports.")
    args <- list(drv = odbc::odbc())
    if (nzchar(p$db_dsn      %||% "")) args$dsn      <- p$db_dsn
    if (nzchar(p$db_host     %||% "")) args$server   <- p$db_host
    if (nzchar(p$db_port     %||% "")) args$port     <- p$db_port
    if (nzchar(p$db_database %||% "")) args$database <- p$db_database
    if (nzchar(p$db_uid      %||% "")) args$uid      <- p$db_uid
    if (nzchar(pwd))                   args$pwd      <- pwd
    con <- do.call(DBI::dbConnect, args)
  }

  transferred <- FALSE
  on.exit(if (!transferred && !is.null(con) && DBI::dbIsValid(con)) try(DBI::dbDisconnect(con), silent = TRUE), add = TRUE)
  data <- fetch_db_data(con, p, lazy = lazy)
  transferred <- lazy
  list(data = data, con = if (lazy) con else NULL, lazy = lazy)
}

# Shared fetch logic — used by both connection modes
fetch_db_data <- function(con, p, lazy = FALSE) {
  if (isTRUE(lazy)) {
    # Return a lazy tbl_sql reference — connection stays open, queries run in the DB.
    # dbplyr::in_schema() composes correctly into the FROM clause across all backends.
    if (isTRUE(p$db_use_query)) {
      dplyr::tbl(con, dbplyr::sql(p$db_sql))
    } else if (nzchar(p$db_schema %||% "")) {
      dplyr::tbl(con, dbplyr::in_schema(p$db_schema, p$db_table))
    } else {
      dplyr::tbl(con, p$db_table)
    }
  } else {
    # Eagerly collect — used when db_collect = TRUE
    if (isTRUE(p$db_use_query)) {
      DBI::dbGetQuery(con, p$db_sql)
    } else {
      table_id <- if (nzchar(p$db_schema %||% ""))
        DBI::Id(schema = p$db_schema, table = p$db_table) else p$db_table
      DBI::dbReadTable(con, table_id)
    }
  }
}

build_import_code <- function(p) {
  out <- r_ident(p$output_name)
  if (identical(p$source_kind, "db")) {
    return(build_db_import_code(p, out))
  }
  ext <- import_file_type(p)
  if (ext == "csv" && identical(p$csv_quoted_na, FALSE)) {
    args <- csv_code_args(p)
    expression <- build_call_code("list", args)
    return(paste(c(paste0(out, " <- local({"), code_helper_definitions("ig_read_legacy_csv"),
      paste0("  .ig_codegen$ig_read_legacy_csv(", expression, ")"), "})"), collapse = "\n"))
  }
  call <- switch(ext,
    csv = build_call_code("readr::read_delim", csv_code_args(p)),
    xlsx = ,
    xls = build_call_code("readxl::read_excel", excel_code_args(p)),
    rds = paste0("readRDS(", r_val(p$path, "character"), ")"),
    rda = paste0("{\n  e <- new.env(parent = emptyenv())\n  load(",
      r_val(p$path, "character"), ", envir = e)\n  obj <- ",
      if (nzchar(p$rda_object %||% "")) r_val(p$rda_object, "character") else "ls(e)[1]",
      "\n  get(obj, envir = e)\n}"),
    sas7bdat = build_call_code("haven::read_sas", haven_code_args(p, user_na = FALSE)),
    dta = build_call_code("haven::read_dta", haven_code_args(p, user_na = FALSE)),
    sav = build_call_code("haven::read_sav", haven_code_args(p, user_na = TRUE)),
    paste0("# Unsupported import type: ", ext)
  )
  if (ext %in% c("rds", "rda")) return(paste(c(paste0(out, " <- local({"),
    code_helper_definitions("ig_restore_object_namespaces"),
    paste0(".ig_codegen$ig_restore_object_namespaces(", call, ")"), "})"), collapse = "\n"))
  paste0(out, " <- ", call)
}

build_db_import_code <- function(p, out) {
  lazy <- !isTRUE(p$db_collect)
  destination <- p$output_name
  out <- ".ig_import_data"

  # ── Fetch / assign line ──────────────────────────────────────────────────────
  fetch_line <- if (lazy) {
    # Lazy: return a tbl_sql reference; connection stays open
    if (isTRUE(p$db_use_query)) {
      paste0(out, " <- dplyr::tbl(con, dbplyr::sql(", r_val(p$db_sql, "character"), "))")
    } else if (nzchar(p$db_schema %||% "")) {
      paste0(out, " <- dplyr::tbl(con, dbplyr::in_schema(",
        r_val(p$db_schema, "character"), ", ", r_val(p$db_table, "character"), "))")
    } else {
      paste0(out, " <- dplyr::tbl(con, ", r_val(p$db_table, "character"), ")")
    }
  } else {
    # Eager: collect into memory and close connection
    if (isTRUE(p$db_use_query)) {
      paste0(out, " <- DBI::dbGetQuery(con, ", r_val(p$db_sql, "character"), ")")
    } else if (nzchar(p$db_schema %||% "")) {
      paste0(out, " <- DBI::dbReadTable(con, DBI::Id(schema = ",
        r_val(p$db_schema, "character"), ", table = ", r_val(p$db_table, "character"), "))")
    } else {
      paste0(out, " <- DBI::dbReadTable(con, ", r_val(p$db_table, "character"), ")")
    }
  }

  lib_lines <- if (lazy) c("library(DBI)", "library(dbplyr)") else "library(DBI)"
  wrap <- function(connection_code) {
    body <- c(".ig_destination <- parent.frame()", "con <- NULL", ".ig_complete <- FALSE",
      "on.exit({",
      paste0("  if ((! .ig_complete || ", if (lazy) "FALSE" else "TRUE", ") && inherits(con, 'DBIConnection')) {"),
      "    try(if (DBI::dbIsValid(con)) DBI::dbDisconnect(con), silent = TRUE)",
      "  }", "}, add = TRUE)", connection_code,
      "if (!inherits(con, 'DBIConnection')) stop('Connection code must create a DBI connection named con.')",
      fetch_line,
      paste0("assign(", r_val(destination, "character"), ", .ig_import_data, envir = .ig_destination)"),
      if (lazy && !identical(destination, "con")) "assign('con', con, envir = .ig_destination)",
      ".ig_complete <- TRUE", "invisible(.ig_import_data)")
    paste(c(lib_lines, "(function() {", paste0("  ", body), "})()",
      if (lazy) paste0("# Close when finished: DBI::dbDisconnect(dbplyr::remote_con(",
        r_ident(destination), "))")), collapse = "\n")
  }

  # ── Custom code mode: emit the user's connection code verbatim ──────────────
  if (identical(p$db_conn_mode %||% "form", "code")) {
    conn_code <- trimws(p$db_conn_code %||% "")
    return(wrap(conn_code))
  }

  # ── Form mode ───────────────────────────────────────────────────────────────
  con_lines <- if (identical(p$db_driver, "sqlite")) {
    c("con <- DBI::dbConnect(RSQLite::SQLite(),",
      paste0("  dbname = ", r_val(p$db_database, "character"), ")"))
  } else {
    args <- c("odbc::odbc()")
    if (nzchar(p$db_dsn      %||% "")) args <- c(args, paste0("dsn = ",      r_val(p$db_dsn,      "character")))
    if (nzchar(p$db_host     %||% "")) args <- c(args, paste0("server = ",   r_val(p$db_host,     "character")))
    if (nzchar(p$db_port     %||% "")) args <- c(args, paste0("port = ",     r_val(p$db_port,     "character")))
    if (nzchar(p$db_database %||% "")) args <- c(args, paste0("database = ", r_val(p$db_database, "character")))
    if (nzchar(p$db_uid      %||% "")) args <- c(args, paste0("uid = ",      r_val(p$db_uid,      "character")))
    # Password: use environment variable — never embed credentials in generated code
    if (nzchar(p$db_uid      %||% "")) args <- c(args, "pwd = Sys.getenv(\"IG_DB_PASSWORD\")")
    c("con <- DBI::dbConnect(",
      paste0("  ", paste(args, collapse = ",\n  ")),
      ")")
  }
  wrap(con_lines)
}

import_source_meta <- function(p, task_id = NULL, data = NULL) {
  c(p, list(task_id = task_id, original_name = basename(p$path %||% ""), schema = import_schema(data)))
}

import_schema <- function(data) {
  if (inherits(data, "tbl_sql")) data <- tryCatch(as.data.frame(dplyr::collect(utils::head(data, 0L))), error = function(e) NULL)
  if (!is.data.frame(data)) return(data.frame())
  data.frame(column = names(data), class = vapply(data, function(column) class(column)[[1L]], character(1)),
    n_distinct = rep(NA_integer_, ncol(data)), n_missing = rep(NA_integer_, ncol(data)), stringsAsFactors = FALSE)
}

split_na <- function(x) {
  x <- x %||% ""
  if (!nzchar(x)) return(character(0))
  trimws(unlist(strsplit(x, ","), use.names = FALSE))
}

set_number <- function(x) {
  if (is.null(x) || length(x) == 0L || is.na(x)) NULL else x
}

set_bool <- function(x) {
  if (is.null(x) || length(x) == 0L) NULL else isTRUE(x)
}

is_set <- function(x, allow_empty = FALSE) {
  if (is.null(x) || length(x) == 0L) return(FALSE)
  if (is.numeric(x) && length(x) == 1L && is.na(x)) return(FALSE)
  if (is.character(x) && length(x) == 1L && !allow_empty && !nzchar(x)) return(FALSE)
  if (is.logical(x) && length(x) == 1L && is.na(x)) return(FALSE)
  TRUE
}

add_arg <- function(args, name, value, allow_empty = FALSE) {
  if (is_set(value, allow_empty = allow_empty)) args[[name]] <- value
  args
}

haven_args <- function(p, user_na = FALSE) {
  args <- list(file = p$path)
  args <- add_arg(args, "encoding", p$haven_encoding)
  args <- add_arg(args, "col_select", parse_col_select(p$haven_col_select), allow_empty = FALSE)
  args <- add_arg(args, "skip", p$haven_skip)
  args <- add_arg(args, "n_max", p$haven_n_max)
  args <- add_arg(args, ".name_repair", p$haven_name_repair)
  if (isTRUE(user_na)) args <- add_arg(args, "user_na", p$haven_user_na)
  args
}

csv_code_args <- function(p) {
  args <- list(
    file = r_val(p$path, "character"),
    delim = r_val(p$csv_delim, "character"),
    col_names = r_bool(p$csv_col_names),
    show_col_types = "FALSE"
  )
  args <- code_arg(args, "skip", p$csv_skip)
  args <- code_arg(args, "na", split_na(p$csv_na), r_chr_vec, allow_empty = FALSE)
  args <- code_arg(args, "quote", p$csv_quote, function(x) r_val(x, "character"))
  args <- code_arg(args, "escape_backslash", p$csv_escape_backslash, r_bool)
  args <- code_arg(args, "escape_double", p$csv_escape_double, r_bool)
  args <- code_arg(args, "comment", p$csv_comment, function(x) r_val(x, "character"))
  args <- code_arg(args, "col_types", p$csv_col_types, r_nullable_chr)
  args <- code_arg(args, "col_select", parse_col_select(p$csv_col_select), r_chr_vec, allow_empty = FALSE)
  args <- code_arg(args, "id", p$csv_id, r_nullable_chr)
  args <- code_arg(args, "trim_ws", p$csv_trim_ws, r_bool)
  if (nzchar(p$csv_locale %||% "")) args$locale <- r_locale_code(p$csv_locale)
  args <- code_arg(args, "name_repair", p$csv_name_repair, function(x) r_val(x, "character"))
  args <- code_arg(args, "guess_max", p$csv_guess_max)
  args <- code_arg(args, "num_threads", p$csv_num_threads)
  if (identical(p$csv_quoted_na, FALSE)) args$quoted_na <- "FALSE"
  args <- code_arg(args, "n_max", p$csv_n_max, r_number_or_inf)
  args <- code_arg(args, "skip_empty_rows", p$csv_skip_empty_rows, r_bool)
  args <- code_arg(args, "lazy", p$csv_lazy, r_bool)
  args
}

excel_code_args <- function(p) {
  args <- list(path = r_val(p$path, "character"), col_names = r_bool(p$excel_col_names))
  args <- code_arg(args, "sheet", p$excel_sheet, r_nullable_chr)
  args <- code_arg(args, "range", p$excel_range, r_nullable_chr)
  args <- code_arg(args, "col_types", split_or_null(p$excel_col_types), r_chr_vec, allow_empty = FALSE)
  args <- code_arg(args, "skip", p$excel_skip)
  args <- code_arg(args, "na", split_na(p$excel_na), r_chr_vec, allow_empty = FALSE)
  args <- code_arg(args, "trim_ws", p$excel_trim_ws, r_bool)
  args <- code_arg(args, "n_max", p$excel_n_max, r_number_or_inf)
  args <- code_arg(args, "guess_max", p$excel_guess_max)
  args <- code_arg(args, "progress", p$excel_progress, r_bool)
  args <- code_arg(args, ".name_repair", p$excel_name_repair, function(x) r_val(x, "character"))
  args
}

haven_code_args <- function(p, user_na = FALSE) {
  args <- list(file = r_val(p$path, "character"))
  args <- code_arg(args, "encoding", p$haven_encoding, r_nullable_chr)
  args <- code_arg(args, "col_select", parse_col_select(p$haven_col_select), r_chr_vec, allow_empty = FALSE)
  args <- code_arg(args, "skip", p$haven_skip)
  args <- code_arg(args, "n_max", p$haven_n_max, r_number_or_inf)
  args <- code_arg(args, ".name_repair", p$haven_name_repair, function(x) r_val(x, "character"))
  if (isTRUE(user_na)) args <- code_arg(args, "user_na", p$haven_user_na, r_bool)
  args
}

code_arg <- function(args, name, value, formatter = as.character, allow_empty = FALSE) {
  if (is_set(value, allow_empty = allow_empty)) args[[name]] <- formatter(value)
  args
}

build_call_code <- function(fn, args) {
  parts <- paste0("  ", names(args), " = ", unlist(args, use.names = FALSE))
  paste0(fn, "(\n", paste(parts, collapse = ",\n"), "\n)")
}

split_or_null <- function(x) {
  x <- x %||% ""
  if (!nzchar(x)) return(NULL)
  trimws(unlist(strsplit(x, ","), use.names = FALSE))
}

parse_col_select <- function(x) {
  x <- x %||% ""
  if (!nzchar(x)) return(NULL)
  vals <- trimws(unlist(strsplit(x, ","), use.names = FALSE))
  vals[nzchar(vals)]
}

nonempty_null <- function(x) {
  if (is.null(x) || !nzchar(x)) NULL else x
}

r_bool <- function(x) if (isTRUE(x)) "TRUE" else "FALSE"
r_number_or_inf <- function(x) if (is.null(x) || !is.finite(x)) "Inf" else as.character(x)
r_nullable_chr <- function(x) if (is.null(x) || !nzchar(x)) "NULL" else r_val(x, "character")
r_chr_vec <- function(x) {
  if (length(x) == 0L) return("character(0)")
  paste0("c(", paste(vapply(x, r_val, character(1), "character"), collapse = ", "), ")")
}
r_chr_vec_or_null <- function(x) {
  if (length(x) == 0L) return("NULL")
  r_chr_vec(x)
}
r_locale_code <- function(x) {
  if (is.null(x) || !nzchar(x)) return("readr::default_locale()")
  paste0("readr::locale(date_format = ", r_val(x, "character"), ")")
}
