# mod_query_builder.R — Query Builder Shiny module
#
# Mirrors the SAS Enterprise Guide Query Builder UX:
#   Tab 1 — Select Data   (column picker + alias + aggregate)
#   Tab 2 — Filter Data   (dynamic WHERE condition builder)
#   Tab 3 — Sort Data     (ORDER BY list)
#   Tab 4 — Join Tables   (launched as a modal)
#   Tab 5 — Computed Cols (launched as a modal)
#
# Depends on: qb_build.R, store.R

# ── Operator sets by column class ─────────────────────────────────────────────
OPS_NUMERIC <- c("=", "!=", "<", ">", "<=", ">=", "BETWEEN",
                 "IN", "IS NULL", "IS NOT NULL")
OPS_CHAR    <- c("=", "!=", "IN", "LIKE", "IS NULL", "IS NOT NULL")
OPS_DATE    <- c("=", "!=", "<", ">", "<=", ">=", "BETWEEN",
                 "IS NULL", "IS NOT NULL")
OPS_LOGICAL <- c("=", "!=", "IS NULL", "IS NOT NULL")
OPS_DEFAULT <- c("=", "!=", "<", ">", "<=", ">=", "IS NULL", "IS NOT NULL")


AGG_CHOICES <- c(
  "(none)"             = "none",
  "COUNT"              = "COUNT",
  "COUNT DISTINCT"     = "COUNT_DISTINCT",
  "SUM"                = "SUM",
  "AVG"                = "AVG",
  "MIN"                = "MIN",
  "MAX"                = "MAX",
  "MEDIAN"             = "MEDIAN",
  "STD DEV"            = "STDDEV",
  "VARIANCE"           = "VAR",
  "Custom expression\u2026" = "CUSTOM"
)

# ══════════════════════════════════════════════════════════════════════════════
# UI
# ══════════════════════════════════════════════════════════════════════════════

query_builder_ui <- function(id) {
  ns <- NS(id)

  bslib::card(
    class = "ig-task-card",
    full_screen = TRUE,
    bslib::card_header(
      class = "d-flex align-items-center gap-3",
      icon("filter"), span(" Query Builder"),
      # Output name + distinct toggle live in the header bar
      div(class = "ms-auto d-flex align-items-center gap-3",
        checkboxInput(ns("distinct"), "SELECT DISTINCT", value = FALSE),
        div(class = "d-flex align-items-center gap-1",
          span("Output:", class = "text-muted small"),
          textInput(ns("output_name"), sr_label("Output table name"),
            width = "160px", placeholder = "e.g. query_1_out"))
      )
    ),

    bslib::card_body(
      padding = 0,
      bslib::navset_tab(
        id = ns("qb_tabs"),

        # ── Tab 1: Select Data ──────────────────────────────────────────────
        bslib::nav_panel("Select Data",
          bslib::layout_columns(
            col_widths = c(4, 8),
            style = "height: calc(100vh - 240px); overflow: hidden;",

            # LEFT — available columns
            bslib::card(
              bslib::card_header(
                class = "d-flex align-items-center gap-2 py-1",
                "Available columns",
                div(class = "ms-auto",
                  selectInput(ns("src_table"), sr_label("Primary input table"),
                    choices  = character(0),
                    width    = "160px"))
              ),
              bslib::card_body(
                padding = "4px",
                style   = "overflow-y:auto; height:100%;",
                uiOutput(ns("avail_cols_ui"))
              )
            ),

            # RIGHT — selected columns (alias + aggregate)
            bslib::card(
              bslib::card_header(
                class = "d-flex align-items-center gap-2 py-1",
                "Selected columns",
                div(class = "ms-auto d-flex gap-1",
                  actionButton(ns("sel_all"),  "All",   class = "btn btn-xs btn-outline-secondary"),
                  actionButton(ns("sel_none"), "Clear", class = "btn btn-xs btn-outline-secondary"))
              ),
              bslib::card_body(
                padding = "4px",
                style   = "overflow-y:auto; height:100%;",
                uiOutput(ns("group_by_banner_ui")),
                uiOutput(ns("alias_warn_ui")),
                uiOutput(ns("sel_cols_ui"))
              )
            )
          )
        ),

        # ── Tab 2: Filter Data ──────────────────────────────────────────────
        bslib::nav_panel("Filter Data",
          bslib::card_body(
            padding = "6px",
            actionButton(ns("add_filter"), "Add condition",
              icon  = icon("plus"),
              class = "btn btn-sm btn-outline-secondary mb-2"),
            uiOutput(ns("filter_rows_ui"))
          )
        ),

        # ── Tab 3: Sort Data ────────────────────────────────────────────────
        bslib::nav_panel("Sort Data",
          bslib::card_body(
            padding = "6px",
            actionButton(ns("add_sort"), "Add sort",
              icon  = icon("plus"),
              class = "btn btn-sm btn-outline-secondary mb-2"),
            uiOutput(ns("sort_rows_ui"))
          )
        ),

        # ── Tab 4: Having (post-GROUP BY filter) ────────────────────────────
        bslib::nav_panel("Having",
          bslib::card_body(
            padding = "6px",
            uiOutput(ns("having_header_ui")),
            uiOutput(ns("having_rows_ui"))
          )
        ),

        # ── Tab 5: Join Tables (opens modal) ────────────────────────────────
        bslib::nav_panel("Join Tables",
          bslib::card_body(
            padding = "6px",
            p(class = "text-muted small mb-2",
              "Each join adds a second table to the query."),
            actionButton(ns("open_join_modal"), "Add join",
              icon  = icon("code-merge"),
              class = "btn btn-sm btn-outline-secondary mb-2"),
            uiOutput(ns("joins_summary_ui"))
          )
        ),

        # ── Tab 6: Computed Columns (opens modal) ───────────────────────────
        bslib::nav_panel("Computed Columns",
          bslib::card_body(
            padding = "6px",
            p(class = "text-muted small mb-2",
              "New columns defined by a formula. Available in SELECT and WHERE."),
            textInput(ns("compute_libraries"), "Libraries for computed columns",
              placeholder = "e.g. stringr, lubridate, forcats", width = "100%"),
            uiOutput(ns("compute_function_palette")),
            actionButton(ns("open_compute_modal"), "Add column",
              icon  = icon("calculator"),
              class = "btn btn-sm btn-outline-secondary mb-2"),
            uiOutput(ns("computed_summary_ui"))
          )
        ),

        # ── Tab 7: Results (filled by Preview / Run & save) ─────────────────
        bslib::nav_panel(tagList(icon("table"), " Results"), value = "results",
          div(class = "ig-results-pane",
            conditionalPanel(
              condition = sprintf("!output['%s']", ns("preview_visible")),
              .dt_results_placeholder()),
            conditionalPanel(
              condition = sprintf("output['%s']", ns("preview_visible")),
              div(class = "ig-result-panel",
                DT::DTOutput(ns("preview_dt"))))
          )
        )
      ) # end navset_tab
    ), # end card_body

    # ── Footer: Preview / Run ────────────────────────────────────────────────
    bslib::card_footer(
      class = "d-flex align-items-center gap-2",
      actionButton(ns("btn_preview"), "Preview (1 000 rows)",
        icon  = icon("eye"),
        class = "btn btn-sm btn-outline-secondary"),
      actionButton(ns("btn_run"), "Run & save",
        icon  = icon("play"),
        class = "btn btn-sm btn-primary"),
      span(class = "ms-auto text-muted small",
        role = "status", `aria-live` = "polite", `aria-atomic` = "true",
        textOutput(ns("run_status"), inline = TRUE)),
      # Live code preview toggle
      actionButton(ns("toggle_code"), "Show code",
        icon  = icon("code"),
        class = "btn btn-xs btn-outline-secondary")
    ),

    # Inline code display (hidden until toggle)
    conditionalPanel(
      condition = paste0("input['", ns("toggle_code"), "'] % 2 == 1"),
      bslib::card_body(
        verbatimTextOutput(ns("live_r_code"))
      )
    )
  ) # end card
}

# ══════════════════════════════════════════════════════════════════════════════
# SERVER
# ══════════════════════════════════════════════════════════════════════════════

#' Configure and execute a Query Builder task.
#' @param id       Module namespace id
#' @param store    reactiveValues store (from make_store())
#' @param task_id  Character id of the task being edited (NULL = new task)
query_builder_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    ns <- session$ns

    # ── Initialise from existing task params (if editing) ──────────────────
    init_params <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]])) {
        store$tasks[[task_id]]$params %||% default_qb_params()
      } else {
        default_qb_params(output_name = paste0(task_id %||% "query", "_out"))
      }
    })

    # ── Reactive state ─────────────────────────────────────────────────────
    # Selected columns (rv_sel): ordered list of items — allows same column multiple times.
    # Each item: list(id, col, alias, func, expr); id is unique, col can repeat.
    init_sel   <- init_params$select %||% list()
    init_items <- lapply(seq_along(init_sel), function(i) {
      x <- init_sel[[i]]
      list(id    = paste0("si", i),
           col   = x$col   %||% "",
           alias = x$alias %||% x$col %||% "",
           func  = x$func  %||% "none",
           expr  = x$expr  %||% "")
    })
    rv_sel  <- reactiveVal(init_items)
    sel_ctr <- reactiveVal(length(init_items))

    # Filter rows
    .f_list <- init_params$filters %||% list()
    .f_ids  <- if (length(.f_list)) vapply(.f_list, `[[`, character(1), "id") else character(0)
    filter_ids  <- reactiveVal(.f_ids)
    filter_ctr  <- reactiveVal(length(.f_list))
    filter_init <- reactiveVal(if (length(.f_list)) setNames(.f_list, .f_ids) else list())

    # Sort rows
    .s_list <- init_params$sorts %||% list()
    .s_ids  <- if (length(.s_list)) vapply(.s_list, `[[`, character(1), "id") else character(0)
    sort_ids  <- reactiveVal(.s_ids)
    sort_ctr  <- reactiveVal(length(.s_list))
    sort_init <- reactiveVal(if (length(.s_list)) setNames(.s_list, .s_ids) else list())

    # Having rows
    .h_list <- init_params$having %||% list()
    .h_ids  <- if (length(.h_list)) vapply(.h_list, `[[`, character(1), "id") else character(0)
    having_ids  <- reactiveVal(.h_ids)
    having_ctr  <- reactiveVal(length(.h_list))
    having_init <- reactiveVal(if (length(.h_list)) setNames(.h_list, .h_ids) else list())

    # Joins and computed cols
    rv_joins    <- reactiveVal(init_params$joins    %||% list())
    rv_computed <- reactiveVal(init_params$computed %||% list())

    # ── Source table selector ───────────────────────────────────────────────
    observe({
      tbls <- store_available_tables(store, task_id = task_id)
      cur  <- isolate(input$src_table)
      selected <- if (!is.null(cur) && cur %in% tbls) cur
                  else init_params$primary_table %||% tbls[1]
      updateSelectInput(session, "src_table", choices = tbls, selected = selected)
    })

    # Initialise output name and distinct flag (direct update — valid at module startup)
    updateTextInput(session, "output_name",
      value = init_params$output_name %||% paste0(task_id %||% "query", "_out"))
    updateCheckboxInput(session, "distinct", value = isTRUE(init_params$distinct))
    updateTextInput(session, "compute_libraries",
      value = paste(init_params$libraries %||% character(0), collapse = ", "))

    # ── Column info for current source table ────────────────────────────────
    col_info <- reactive({
      req(input$src_table, input$src_table %in% store_available_tables(store, task_id))
      store_col_schema(store, input$src_table)
    })

    selectable_col_info <- reactive({
      ci <- col_info()
      comps <- rv_computed()
      comp_names <- vapply(comps, function(x) x$name %||% "", character(1))
      comp_names <- unique(comp_names[nzchar(comp_names)])
      comp_names <- setdiff(comp_names, ci$column)
      if (length(comp_names) == 0L) return(ci)
      comp_info <- data.frame(
        column = comp_names,
        class = rep("computed", length(comp_names)),
        n_distinct = NA_integer_,
        n_missing = NA_integer_,
        stringsAsFactors = FALSE
      )
      rbind(ci, comp_info)
    })

    col_class_map <- reactive({
      ci <- selectable_col_info()
      setNames(as.list(ci$class), ci$column)
    })

    # ── Tab 1: Available columns UI ─────────────────────────────────────────
    output$avail_cols_ui <- renderUI({
      ci  <- selectable_col_info()
      sel <- rv_sel()
      if (nrow(ci) == 0L) return(p(class="text-muted small p-2", "No table selected."))

      # Count how many times each column already appears in the selection list
      sel_counts <- table(vapply(sel, `[[`, character(1), "col"))

      rows <- lapply(seq_len(nrow(ci)), function(i) {
        cname  <- ci$column[i]
        cclass <- ci$class[i]
        cnt_raw <- sel_counts[cname]
        cnt     <- if (!is.na(cnt_raw)) as.integer(cnt_raw) else 0L
        div(
          class = paste("ig-col-row d-flex align-items-center gap-2",
                        if (cnt > 0L) "ig-col-row-selected" else ""),
          actionButton(ns(paste0("add_col_", cname)), "",
            icon  = icon("plus"),
            class = "btn btn-xs btn-outline-secondary",
            title = paste0("Add ", cname, " to selection"),
            onclick = ig_input_event_js(ns("add_avail_col"), cname)),
          tags$code(style = "font-size:0.8rem;", cname),
          if (cnt > 0L)
            span(class = "ms-auto badge bg-secondary rounded-pill", as.character(cnt))
          else
            span(class = "ms-auto text-muted", style = "font-size:0.72rem;",
                 badge_class(cclass))
        )
      })
      tagList(rows)
    })

    # Add a column entry when the user clicks its "+" button in the left panel.
    # The same column can be added multiple times — each gets a unique id.
    observeEvent(input$add_avail_col, {
      col <- input$add_avail_col
      if (!nzchar(col %||% "")) return()
      n <- sel_ctr() + 1L
      sel_ctr(n)
      rv_sel(c(rv_sel(), list(list(
        id    = paste0("si", n),
        col   = col,
        alias = col,
        func  = "none",
        expr  = ""
      ))))
    })

    observeEvent(input$sel_all, {
      ci       <- selectable_col_info()
      cur      <- rv_sel()
      cur_cols <- vapply(cur, `[[`, character(1), "col")
      ctr      <- sel_ctr()
      new_items <- lapply(
        ci$column[!ci$column %in% cur_cols],
        function(cname) {
          ctr <<- ctr + 1L
          list(id = paste0("si", ctr), col = cname,
               alias = cname, func = "none", expr = "")
        }
      )
      sel_ctr(ctr)
      rv_sel(c(cur, new_items))
    })

    observeEvent(input$sel_none, { rv_sel(list()) })

    # ── Tab 1: GROUP BY banner ───────────────────────────────────────────────
    # Separate output so it reacts to func-dropdown changes without triggering
    # a full re-render of the selected-columns list (which would steal focus).
    output$group_by_banner_ui <- renderUI({
      if (!has_aggregates()) return(NULL)
      div(class = "alert alert-info py-1 px-2 mb-1 d-flex align-items-center gap-2",
        style = "font-size:0.79rem;",
        icon("layer-group"),
        span(tags$b("GROUP BY mode: "),
          "columns without a function are group keys; ",
          "columns with COUNT / SUM / etc. are summarised.")
      )
    })

    # ── Tab 1: Alias uniqueness warning ─────────────────────────────────────
    # Also a separate output — depends on alias inputs; does NOT feed into
    # sel_cols_ui so it won't cause focus loss.
    output$alias_warn_ui <- renderUI({
      sel <- rv_sel()
      if (length(sel) < 2L) return(NULL)
      aliases <- vapply(sel, function(item) {
        trimws(input[[paste0("alias_", item$id)]] %||% item$alias %||% item$col)
      }, character(1))
      dups <- unique(aliases[duplicated(aliases) & nzchar(aliases)])
      if (length(dups) == 0L) return(NULL)
      div(class = "alert alert-warning py-1 px-2 mb-1 d-flex align-items-center gap-2",
        style = "font-size:0.79rem;",
        icon("triangle-exclamation"),
        span(tags$b("Duplicate aliases: "),
          paste(dups, collapse = ", "),
          " \u2014 each output column needs a unique name.")
      )
    })

    # ── Tab 1: Selected columns UI (alias + aggregate per row) ──────────────
    # Depends ONLY on rv_sel() — alias/func/expr inputs are read with isolate()
    # so typing in an alias does not trigger a re-render or steal focus.
    output$sel_cols_ui <- renderUI({
      sel <- rv_sel()
      if (length(sel) == 0L)
        return(p(class="text-muted small p-3", "No columns selected yet."))

      n_sel  <- length(sel)
      header <- div(
        class = "ig-grid-header",
        div(style = "width:28px;"),          # spacer for ↑↓ buttons
        div(style = "flex:2;", "Column"),
        div(style = "flex:2;", "Alias"),
        div(style = "flex:2;", "Aggregate function"),
        div(style = "width:30px;")
      )

      rows <- lapply(seq_along(sel), function(i) {
        item  <- sel[[i]]
        is_first <- i == 1L
        is_last  <- i == n_sel
        # isolate() reads current input values without creating a reactive
        # dependency — prevents re-renders (and focus loss) while the user types.
        cur_alias <- isolate(input[[paste0("alias_", item$id)]]) %||% item$alias %||% item$col
        cur_func  <- isolate(input[[paste0("func_",  item$id)]]) %||% item$func  %||% "none"
        cur_expr  <- isolate(input[[paste0("expr_",  item$id)]]) %||% item$expr  %||% ""
        tagList(
          div(
            class = "ig-grid-row",
            # ── Up / Down reorder buttons ──────────────────────────────────
            div(
              style = "width:28px; display:flex; flex-direction:column; gap:1px; flex-shrink:0;",
              tags$button(
                class        = paste("btn btn-xs btn-outline-secondary",
                                     if (is_first) "disabled" else ""),
                title        = "Move up",
                `aria-label` = paste("Move", item$col, "up"),
                disabled     = if (is_first) NA else NULL,
                onclick      = if (!is_first) ig_input_event_js(ns("move_sel_up"), item$id) else NULL,
                icon("chevron-up")
              ),
              tags$button(
                class        = paste("btn btn-xs btn-outline-secondary",
                                     if (is_last) "disabled" else ""),
                title        = "Move down",
                `aria-label` = paste("Move", item$col, "down"),
                disabled     = if (is_last) NA else NULL,
                onclick      = if (!is_last) ig_input_event_js(ns("move_sel_dn"), item$id) else NULL,
                icon("chevron-down")
              )
            ),
            div(style = "flex:2; font-size:0.82rem;",
              tags$code(item$col)),
            div(style = "flex:2;",
              textInput(ns(paste0("alias_", item$id)),
                sr_label(paste("Alias for column", item$col)),
                value = cur_alias, width = "100%")),
            div(style = "flex:2;",
              selectInput(ns(paste0("func_", item$id)),
                sr_label(paste("Aggregate function for", item$col)),
                choices  = AGG_CHOICES,
                selected = cur_func,
                width    = "100%")),
            div(style = "width:30px;",
              actionButton(ns(paste0("rm_sel_", item$id)), "",
                icon         = icon("xmark"),
                class        = "btn btn-xs btn-outline-danger",
                title        = paste("Remove", item$col),
                `aria-label` = paste("Remove column", item$col),
                onclick      = ig_input_event_js(ns("remove_sel_col"), item$id)))
          ),
          # Custom expression textarea — conditionalPanel is pure JS, no R
          # reactivity, so selecting CUSTOM shows it immediately without a
          # re-render and without disturbing focus elsewhere.
          conditionalPanel(
            condition = sprintf("input['%s'] === 'CUSTOM'",
                                ns(paste0("func_", item$id))),
            div(class = "px-2 pb-2",
              textAreaInput(ns(paste0("expr_", item$id)),
                sr_label(paste("Custom expression for", item$col)),
                value       = cur_expr,
                placeholder = paste0("R expression using this column, e.g. ",
                                     "sum(", item$col, ", na.rm=TRUE) / n()"),
                rows = 2, width = "100%"))
          )
        )
      })
      tagList(header, rows)
    })

    observeEvent(input$remove_sel_col, {
      id  <- input$remove_sel_col
      cur <- rv_sel()
      rv_sel(cur[!vapply(cur, function(x) identical(x$id, id), logical(1))])
    })

    # Snapshot the current textInput / selectInput values for all items back
    # into the rv_sel() items.  Called before every reorder so that item$alias,
    # item$func, and item$expr are always the authoritative copy of the user's
    # intent — not just the initial values from the last add/load.
    snap_sel_inputs <- function(items) {
      lapply(items, function(item) {
        a <- input[[paste0("alias_", item$id)]]
        f <- input[[paste0("func_",  item$id)]]
        e <- input[[paste0("expr_",  item$id)]]
        if (!is.null(a)) item$alias <- trimws(a)
        if (!is.null(f)) item$func  <- f
        if (!is.null(e)) item$expr  <- trimws(e)
        item
      })
    }

    observeEvent(input$move_sel_up, {
      id  <- input$move_sel_up
      cur <- snap_sel_inputs(rv_sel())
      i   <- which(vapply(cur, function(x) identical(x$id, id), logical(1)))
      if (length(i) == 1L && i > 1L) {
        cur[c(i - 1L, i)] <- cur[c(i, i - 1L)]
        rv_sel(cur)
      }
    })

    observeEvent(input$move_sel_dn, {
      id  <- input$move_sel_dn
      cur <- snap_sel_inputs(rv_sel())
      i   <- which(vapply(cur, function(x) identical(x$id, id), logical(1)))
      if (length(i) == 1L && i < length(cur)) {
        cur[c(i, i + 1L)] <- cur[c(i + 1L, i)]
        rv_sel(cur)
      }
    })

    # Auto-sync the select list into task$params whenever rv_sel() changes.
    # This ensures Run Flow always uses the latest column ordering even when
    # the task has never been explicitly "Run & Save"d after a reorder.
    observe({
      sel <- rv_sel()
      if (is.null(task_id)) return()
      task <- isolate(store$tasks[[task_id]])
      if (is.null(task) || is.null(task$params)) return()
      task$params$select <- lapply(sel, function(item) {
        list(
          col   = item$col,
          alias = trimws(item$alias %||% item$col),
          func  = item$func  %||% "none",
          expr  = trimws(item$expr %||% "")
        )
      })
      store_set_task(store, task)
    })

    # ── Tab 2: Filter rows UI ───────────────────────────────────────────────
    observeEvent(input$add_filter, {
      n   <- filter_ctr() + 1L; filter_ctr(n)
      fid <- paste0("fr", n)
      fi  <- filter_init(); fi[[fid]] <- new_filter_row(fid); filter_init(fi)
      filter_ids(c(filter_ids(), fid))
    })

    observeEvent(input$remove_filter_row, {
      rid <- input$remove_filter_row
      filter_ids(setdiff(filter_ids(), rid))
    })

    output$filter_rows_ui <- renderUI({
      ids <- filter_ids()
      if (length(ids) == 0L)
        return(p(class = "text-muted small", "No conditions yet. Click 'Add condition'."))

      ci      <- col_info()
      col_choices <- if (nrow(ci) > 0) setNames(ci$column, ci$column) else character(0)
      # Also expose computed col names
      comp_names <- vapply(rv_computed(), `[[`, character(1), "name")
      col_choices <- c(col_choices, setNames(comp_names, comp_names))

      rows <- lapply(seq_along(ids), function(i) {
        fid  <- ids[i]
        fi   <- filter_init()[[fid]] %||% new_filter_row(fid)
        cur_col   <- input[[paste0("fcol_",  fid)]] %||% fi$col
        cur_class <- col_class_map()[[cur_col]] %||% "character"
        cur_op    <- input[[paste0("fop_",   fid)]] %||% fi$op
        cur_join  <- isolate(input[[paste0("fjoin_", fid)]]) %||% fi$join %||% "AND"

        # Preserve current values so inputs don't reset when col/op changes
        norm_val <- function(v, fallback = "") {
          if (is.null(v) || (length(v) == 1L && is.na(v))) fallback else as.character(v)
        }
        cur_val  <- norm_val(isolate(input[[paste0("fval_",  fid)]]), fi$val  %||% "")
        cur_val2 <- norm_val(isolate(input[[paste0("fval2_", fid)]]), fi$val2 %||% "")

        div(class = "d-flex align-items-start gap-2 mb-2",
          # AND/OR connector (hidden for first row)
          if (i > 1) {
            div(style = "width:70px; padding-top:4px;",
              selectInput(ns(paste0("fjoin_", fid)),
                sr_label("Combine with previous condition"),
                choices  = c("AND", "OR"),
                selected = cur_join,
                width    = "70px"))
          } else div(style = "width:70px;"),

          # Column
          div(style = "flex:2;",
            selectInput(ns(paste0("fcol_", fid)),
              sr_label("Filter column"),
              choices  = col_choices,
              selected = cur_col,
              width    = "100%")),

          # Operator — choices update when class changes; selected tracks current
          div(style = "flex:2;",
            selectInput(ns(paste0("fop_", fid)),
              sr_label("Filter operator"),
              choices  = ops_for_class(cur_class),
              selected = cur_op,
              width    = "100%")),

          # Value(s) — adapts to op and col class; values preserved on re-render
          div(style = "flex:3;", filter_value_ui(ns, fid, cur_val, cur_val2, cur_op, cur_class)),

          # Remove
          div(style = "padding-top:4px;",
            actionButton(ns(paste0("rmfr_", fid)), "",
              icon         = icon("xmark"),
              class        = "btn btn-xs btn-outline-danger",
              title        = "Remove filter condition",
              `aria-label` = paste("Remove filter condition", fid),
              onclick      = ig_input_event_js(ns("remove_filter_row"), fid)))
        )
      })
      tagList(rows)
    })

    # ── Tab 3: Sort rows UI ─────────────────────────────────────────────────
    observeEvent(input$add_sort, {
      n   <- sort_ctr() + 1L; sort_ctr(n)
      sid <- paste0("sr", n)
      si  <- sort_init(); si[[sid]] <- list(id = sid, col = "", dir = "ASC"); sort_init(si)
      sort_ids(c(sort_ids(), sid))
    })

    observeEvent(input$remove_sort_row, {
      rid <- input$remove_sort_row
      sort_ids(setdiff(sort_ids(), rid))
    })

    output$sort_rows_ui <- renderUI({
      ids <- sort_ids()
      if (length(ids) == 0L)
        return(p(class = "text-muted small", "No sort criteria. Click 'Add sort'."))

      ci <- col_info()
      col_choices <- if (nrow(ci) > 0) setNames(ci$column, ci$column) else character(0)
      comp_names  <- vapply(rv_computed(), `[[`, character(1), "name")
      col_choices <- c(col_choices, setNames(comp_names, comp_names))

      rows <- lapply(ids, function(sid) {
        si <- sort_init()[[sid]] %||% list(id = sid, col = "", dir = "ASC")
        div(class = "d-flex align-items-center gap-2 mb-2",
          div(style = "flex:3;",
            selectInput(ns(paste0("scol_", sid)),
              sr_label("Sort column"),
              choices  = col_choices,
              selected = si$col,
              width    = "100%")),
          div(style = "flex:2;",
            selectInput(ns(paste0("sdir_", sid)),
              sr_label("Sort direction"),
              choices  = c("ASC" = "ASC", "DESC" = "DESC"),
              selected = si$dir %||% "ASC",
              width    = "100%")),
          actionButton(ns(paste0("rmsr_", sid)), "",
            icon         = icon("xmark"),
            class        = "btn btn-xs btn-outline-danger",
            title        = "Remove sort rule",
            `aria-label` = paste("Remove sort rule", sid),
            onclick      = ig_input_event_js(ns("remove_sort_row"), sid))
        )
      })
      tagList(rows)
    })

    # ── Tab 4: Having rows ─────────────────────────────────────────────────
    # Aggregated column aliases available for HAVING.
    # Uses live input$func_* values (with stored fallback) so changes to the
    # aggregate function dropdown are reflected immediately without requiring
    # rv_sel to be explicitly synced.
    having_col_choices <- reactive({
      sel <- rv_sel()
      aliases <- vapply(sel, function(item) {
        fn    <- input[[paste0("func_",  item$id)]] %||% item$func  %||% "none"
        alias <- input[[paste0("alias_", item$id)]] %||% item$alias %||% item$col
        if (!identical(fn, "none")) trimws(alias) else ""
      }, character(1))
      aliases <- unique(aliases[nzchar(aliases)])
      if (length(aliases) == 0L) return(character(0))
      setNames(aliases, aliases)
    })

    has_aggregates <- reactive({
      sel <- rv_sel()
      any(vapply(sel, function(item) {
        fn <- input[[paste0("func_", item$id)]] %||% item$func %||% "none"
        !identical(fn, "none")
      }, logical(1)))
    })

    output$having_header_ui <- renderUI({
      if (!has_aggregates()) {
        tags$p(class = "text-muted small",
          icon("circle-info"),
          " HAVING conditions are only available when aggregate functions",
          " (COUNT, SUM, AVG, etc.) are selected in the Select Data tab.")
      } else {
        actionButton(ns("add_having"), "Add having condition",
          icon  = icon("plus"),
          class = "btn btn-sm btn-outline-secondary mb-3")
      }
    })

    observeEvent(input$add_having, {
      n   <- having_ctr() + 1L; having_ctr(n)
      hid <- paste0("hv", n)
      hi  <- having_init(); hi[[hid]] <- new_filter_row(hid); having_init(hi)
      having_ids(c(having_ids(), hid))
    })

    observeEvent(input$remove_having_row, {
      rid <- input$remove_having_row
      having_ids(setdiff(having_ids(), rid))
    })

    output$having_rows_ui <- renderUI({
      ids         <- having_ids()
      col_choices <- having_col_choices()

      if (!has_aggregates()) return(NULL)
      if (length(ids) == 0L)
        return(tags$p(class = "text-muted small",
          "No having conditions. Click 'Add having condition'."))
      if (length(col_choices) == 0L)
        return(tags$p(class = "text-muted small text-warning",
          "No aggregate columns available yet. ",
          "Assign aggregate functions in Select Data."))

      norm_hval <- function(v, fallback = "") {
        if (is.null(v) || (length(v) == 1L && is.na(v))) fallback else as.character(v)
      }

      rows <- lapply(seq_along(ids), function(i) {
        hid  <- ids[i]
        hi   <- having_init()[[hid]] %||% new_filter_row(hid)
        cur_col  <- input[[paste0("hcol_", hid)]] %||% hi$col
        if (!nzchar(cur_col) || !cur_col %in% col_choices)
          cur_col <- col_choices[[1L]]
        cur_op   <- input[[paste0("hop_",  hid)]] %||% hi$op %||% ">"
        if (!cur_op %in% OPS_NUMERIC) cur_op <- ">"
        cur_join <- isolate(input[[paste0("hjoin_",hid)]]) %||% hi$join %||% "AND"
        cur_val  <- norm_hval(isolate(input[[paste0("fval_",  hid)]]), hi$val  %||% "")
        cur_val2 <- norm_hval(isolate(input[[paste0("fval2_", hid)]]), hi$val2 %||% "")

        div(class = "d-flex align-items-start gap-2 mb-2",
          if (i > 1) {
            div(style = "width:70px; padding-top:4px;",
              selectInput(ns(paste0("hjoin_", hid)),
                sr_label("Combine with previous having condition"),
                choices  = c("AND", "OR"),
                selected = cur_join,
                width    = "70px"))
          } else div(style = "width:70px;"),
          div(style = "flex:2;",
            selectInput(ns(paste0("hcol_", hid)),
              sr_label("Having column"),
              choices  = col_choices,
              selected = cur_col,
              width    = "100%")),
          div(style = "flex:2;",
            selectInput(ns(paste0("hop_", hid)),
              sr_label("Having operator"),
              choices  = OPS_NUMERIC,
              selected = cur_op,
              width    = "100%")),
          div(style = "flex:3;",
            filter_value_ui(ns, hid, cur_val, cur_val2, cur_op, "numeric")),
          div(style = "padding-top:4px;",
            actionButton(ns(paste0("rmhv_", hid)), "",
              icon         = icon("xmark"),
              class        = "btn btn-xs btn-outline-danger",
              title        = "Remove having condition",
              `aria-label` = paste("Remove having condition", hid),
              onclick      = ig_input_event_js(ns("remove_having_row"), hid)))
        )
      })
      tagList(rows)
    })

    # ── Tab 5: Join modal ───────────────────────────────────────────────────
    observeEvent(input$open_join_modal, {
      all_tables <- store_available_tables(store, task_id = task_id)
      showModal(modalDialog(
        title  = "Add join",
        size   = "l",
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("modal_join_ok"), "Add join", class = "btn btn-primary")
        ),
        bslib::layout_columns(
          col_widths = c(6, 6),
          selectInput(ns("jn_right"),  "Right table",
            choices = setdiff(all_tables, input$src_table)),
          selectInput(ns("jn_type"),   "Join type",
            choices = c("Left" = "left", "Inner" = "inner",
                        "Right" = "right", "Full" = "full", "Cross" = "cross"))
        ),
        hr(),
        p(class="text-muted small", "Key pairs (left column = right column):"),
        uiOutput(ns("join_key_ui")),
        actionButton(ns("add_join_key"), "Add key pair",
          icon = icon("plus"), class = "btn btn-xs btn-outline-secondary mt-2")
      ))
      # Initialise key builder state
      rv_join_keys(list(list(left = "", right = "")))
    })

    rv_join_keys <- reactiveVal(list())

    observeEvent(input$add_join_key, {
      keys <- snapshot_join_keys(input, rv_join_keys())
      rv_join_keys(c(keys, list(list(left = "", right = ""))))
    })

    output$join_key_ui <- renderUI({
      keys    <- rv_join_keys()
      li_tbl  <- col_info()$column
      req_tbl <- input$jn_right
      ri_cols <- if (!is.null(req_tbl) && req_tbl %in% store_table_names(store))
                   store_col_schema(store, req_tbl)$column else character(0)

      rows <- lapply(seq_along(keys), function(i) {
        bslib::layout_columns(
          col_widths = c(5, 1, 5, 1),
          selectInput(ns(paste0("jk_left_", i)),
            sr_label(paste("Left join key", i)),
            choices = li_tbl, selected = keys[[i]]$left),
          div(class="d-flex align-items-center justify-content-center pt-2",
              icon("equals")),
          selectInput(ns(paste0("jk_right_", i)),
            sr_label(paste("Right join key", i)),
            choices = ri_cols, selected = keys[[i]]$right),
          div(class="d-flex align-items-center pt-2",
            if (i > 1) actionButton(ns(paste0("rm_jk_", i)), "",
              icon         = icon("xmark"),
              class        = "btn btn-xs btn-outline-danger",
              title        = "Remove key pair",
              `aria-label` = paste("Remove join key pair", i),
              onclick      = ig_input_event_js(ns("rm_join_key"), i)))
        )
      })
      tagList(rows)
    })

    observeEvent(input$rm_join_key, {
      i    <- input$rm_join_key
      keys <- rv_join_keys(); keys[[i]] <- NULL; rv_join_keys(keys)
    })

    observeEvent(input$modal_join_ok, {
      rv_join_keys(snapshot_join_keys(input, rv_join_keys()))
      n_keys  <- length(rv_join_keys())
      kl <- vapply(seq_len(n_keys), function(i)
        input[[paste0("jk_left_",  i)]] %||% "", character(1))
      kr <- vapply(seq_len(n_keys), function(i)
        input[[paste0("jk_right_", i)]] %||% "", character(1))

      keep <- nzchar(kl) & nzchar(kr)
      kl <- kl[keep]
      kr <- kr[keep]

      if (!identical(input$jn_type, "cross") && length(kl) == 0L) {
        showNotification("Select at least one join key pair.", type = "warning")
        return()
      }
      if (!nzchar(input$jn_right %||% "")) {
        showNotification("Select a right table.", type = "warning")
        return()
      }

      new_join <- list(
        right_table = input$jn_right,
        type        = input$jn_type,
        keys_left   = kl,
        keys_right  = kr
      )
      rv_joins(c(rv_joins(), list(new_join)))
      removeModal()
    })

    output$joins_summary_ui <- renderUI({
      joins <- rv_joins()
      if (length(joins) == 0L)
        return(p(class = "text-muted small", "No joins defined."))

      rows <- lapply(seq_along(joins), function(i) {
        j <- joins[[i]]
        div(class = "ig-summary-row",
          icon("code-merge"),
          strong(toupper(j$type), " JOIN "),
          code(j$right_table),
          span(class="text-muted small",
            if (length(j$keys_left))
              paste("ON", paste(j$keys_left, "=", j$keys_right, collapse=", "))
            else "(cross)"),
          div(class="ms-auto",
            actionButton(ns(paste0("rm_join_", i)), "",
              icon         = icon("xmark"),
              class        = "btn btn-xs btn-outline-danger",
              title        = paste("Remove join with", j$right_table),
              `aria-label` = paste("Remove join with", j$right_table),
              onclick      = ig_input_event_js(ns("rm_join"), i)))
        )
      })
      tagList(rows)
    })

    observeEvent(input$rm_join, {
      i <- input$rm_join; j <- rv_joins(); j[[i]] <- NULL; rv_joins(j)
    })

    # ── Tab 5: Computed columns modal ────────────────────────────────────────
    observeEvent(input$open_compute_modal, {
      showModal(modalDialog(
        title  = "Add computed column",
        size   = "l",
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("modal_compute_ok"), "Add column", class = "btn btn-primary")
        ),
        textInput(ns("comp_name"), "New column name", placeholder = "e.g. profit_margin"),
        radioButtons(ns("comp_mode"), "Creation mode",
          choices = c("Basic builder" = "basic", "Custom R expression" = "custom"),
          selected = "basic", inline = TRUE),
        conditionalPanel(
          condition = sprintf("input['%s'] == 'basic'", ns("comp_mode")),
          uiOutput(ns("compute_basic_ui"))
        ),
        conditionalPanel(
          condition = sprintf("input['%s'] == 'custom'", ns("comp_mode")),
          textAreaInput(ns("comp_expr"), "Formula (R expression)",
            placeholder = "e.g. (`revenue` - `cost`) / `revenue` * 100",
            rows = 4, width = "100%")
        ),
        div(class = "ig-function-palette",
          tags$strong("Available libraries: "),
          textOutput(ns("compute_modal_libraries"), inline = TRUE)
        )
      ))
    })

    output$compute_modal_libraries <- renderText({
      libs <- compute_libraries()
      if (length(libs) == 0L) "base, dplyr" else paste(c("base", "dplyr", libs), collapse = ", ")
    })

    output$compute_basic_ui <- renderUI({
      ci <- col_info()
      col_choices <- if (nrow(ci) > 0L) setNames(ci$column, ci$column) else character(0)
      tagList(
        bslib::layout_columns(
          col_widths = c(4, 4, 4),
          selectInput(ns("comp_basic_op"), "Operation",
            choices = c(
              "Use operand A" = "copy",
              "A + B" = "add",
              "A - B" = "subtract",
              "A * B" = "multiply",
              "A / B" = "divide",
              "Concatenate A and B" = "concat",
              "Uppercase A" = "upper",
              "Lowercase A" = "lower",
              "Trim A" = "trim",
              "Is A missing" = "is_na"
            ),
            width = "100%"),
          div(),
          div()
        ),
        bslib::layout_columns(
          col_widths = c(6, 6),
          operand_ui(ns, "a", "Operand A", col_choices),
          operand_ui(ns, "b", "Operand B", col_choices)
        )
      )
    })

    observeEvent(input$modal_compute_ok, {
      name <- trimws(input$comp_name %||% "")
      expr <- if (identical(input$comp_mode, "custom")) {
        trimws(input$comp_expr %||% "")
      } else {
        build_basic_compute_expr(
          input$comp_basic_op,
          input$comp_basic_a_kind,
          input$comp_basic_a_col,
          input$comp_basic_a_value,
          input$comp_basic_b_kind,
          input$comp_basic_b_col,
          input$comp_basic_b_value
        )
      }
      if (nchar(name) == 0L || nchar(expr) == 0L) {
        showNotification("Name and expression are required.", type = "warning")
        return()
      }
      if (!make.names(name) == name) {
        showNotification("Column name must be a valid R identifier.", type = "warning")
        return()
      }
      rv_computed(c(rv_computed(), list(list(
        name = name,
        expr = expr,
        mode = input$comp_mode %||% "custom"
      ))))
      removeModal()
    })

    observeEvent(input$rm_computed, {
      i <- input$rm_computed; c <- rv_computed(); c[[i]] <- NULL; rv_computed(c)
    })

    output$computed_summary_ui <- renderUI({
      comps <- rv_computed()
      if (length(comps) == 0L)
        return(p(class = "text-muted small", "No computed columns defined."))

      rows <- lapply(seq_along(comps), function(i) {
        x <- comps[[i]]
        div(class = "ig-summary-row",
          icon("calculator"),
          code(x$name),
          span(class = "text-muted small", "="),
          code(x$expr),
          div(class="ms-auto",
            actionButton(ns(paste0("rm_comp_", i)), "",
              icon         = icon("xmark"),
              class        = "btn btn-xs btn-outline-danger",
              title        = paste("Remove computed column", x$name),
              `aria-label` = paste("Remove computed column", x$name),
              onclick      = ig_input_event_js(ns("rm_computed"), i)))
        )
      })
      tagList(rows)
    })

    compute_libraries <- reactive({
      x <- input$compute_libraries %||% ""
      libs <- trimws(unlist(strsplit(x, ","), use.names = FALSE))
      unique(libs[nzchar(libs)])
    })

    output$compute_function_palette <- renderUI({
      libs <- compute_libraries()
      built_in <- c(
        "Arithmetic: + - * /",
        "Base: ifelse(), paste(), substr(), toupper(), tolower(), trimws()",
        "Math: round(), abs(), log(), sqrt(), mean(), sum(), min(), max()",
        "Dates: as.Date(), format(), difftime()",
        "dplyr: case_when(), coalesce(), between(), if_else()"
      )
      if (length(libs) == 0L) {
        return(div(class = "ig-function-palette",
          tags$ul(lapply(built_in, tags$li))
        ))
      }

      lib_items <- lapply(libs, function(pkg) {
        fns <- tryCatch({
          ns_pkg <- getNamespace(pkg)
          head(sort(getNamespaceExports(ns_pkg)), 24)
        }, error = function(e) character(0))
        if (length(fns) == 0L) {
          tags$li(tags$strong(pkg), ": not installed or cannot be loaded")
        } else {
          tags$li(tags$strong(pkg), ": ", paste0(fns, "()", collapse = ", "))
        }
      })

      div(class = "ig-function-palette",
        tags$ul(c(lapply(built_in, tags$li), lib_items))
      )
    })

    # ── Collect params from current UI state ─────────────────────────────────
    collect_params <- reactive({
      sel     <- rv_sel()
      flt_ids <- filter_ids()
      srt_ids <- sort_ids()
      hav_ids <- having_ids()

      # Build select list preserving insertion order; include expr for CUSTOM func
      select_list <- lapply(sel, function(item) {
        list(
          col   = item$col,
          alias = trimws(input[[paste0("alias_", item$id)]] %||% item$alias %||% item$col),
          func  = input[[paste0("func_",  item$id)]] %||% item$func %||% "none",
          expr  = trimws(input[[paste0("expr_",   item$id)]] %||% item$expr  %||% "")
        )
      })

      # Build filter list
      filter_list <- lapply(flt_ids, function(fid) {
        col  <- input[[paste0("fcol_", fid)]] %||% ""
        op   <- input[[paste0("fop_",  fid)]] %||% "="
        join <- input[[paste0("fjoin_",fid)]] %||% "AND"
        cls  <- col_class_map()[[col]] %||% "character"
        # Normalise: numericInput returns NA when empty; dateInput returns a Date obj
        norm_val <- function(v) {
          if (is.null(v) || (length(v) == 1L && is.na(v))) return("")
          as.character(v)
        }
        val  <- norm_val(input[[paste0("fval_",  fid)]])
        val2 <- norm_val(input[[paste0("fval2_", fid)]])
        new_filter_row(fid, col, op, val, val2, join, cls)
      })

      # Build having list (post-aggregation filter; col_class always "numeric")
      having_list <- lapply(hav_ids, function(hid) {
        col  <- input[[paste0("hcol_", hid)]] %||% ""
        op   <- input[[paste0("hop_",  hid)]] %||% ">"
        join <- input[[paste0("hjoin_",hid)]] %||% "AND"
        norm_val <- function(v) {
          if (is.null(v) || (length(v) == 1L && is.na(v))) return("")
          as.character(v)
        }
        val  <- norm_val(input[[paste0("fval_",  hid)]])
        val2 <- norm_val(input[[paste0("fval2_", hid)]])
        new_filter_row(hid, col, op, val, val2, join, "numeric")
      })

      # Build sort list
      sort_list <- lapply(srt_ids, function(sid) {
        list(
          id  = sid,
          col = input[[paste0("scol_", sid)]] %||% "",
          dir = input[[paste0("sdir_", sid)]] %||% "ASC"
        )
      })

      list(
        primary_table = input$src_table %||% "",
        libraries     = compute_libraries(),
        joins         = rv_joins(),
        computed      = rv_computed(),
        filters       = filter_list,
        having        = having_list,
        select        = select_list,
        sorts         = sort_list,
        distinct      = isTRUE(input$distinct),
        output_name   = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })

    # ── Live code display ─────────────────────────────────────────────────────
    output$live_r_code <- renderText({
      p <- collect_params()
      tryCatch(build_query_code(p), error = function(e) paste("# Error:", conditionMessage(e)))
    })

    # ── Preview ───────────────────────────────────────────────────────────────
    preview_data <- reactiveVal(NULL)
    preview_visible <- reactiveVal(FALSE)

    output$preview_visible <- reactive({ isTRUE(preview_visible()) })
    outputOptions(output, "preview_visible", suspendWhenHidden = FALSE)

    # Helper — returns a dup-alias error string, or NULL if aliases are unique.
    check_alias_uniqueness <- function(p) {
      aliases <- vapply(p$select %||% list(), function(x)
        trimws(x$alias %||% x$col %||% ""), character(1))
      aliases <- aliases[nzchar(aliases)]
      dups <- unique(aliases[duplicated(aliases)])
      if (length(dups) == 0L) return(NULL)
      paste0("Duplicate column aliases: ",
             paste(dups, collapse = ", "),
             ". Each output column must have a unique name.")
    }

    observeEvent(input$btn_preview, {
      p      <- collect_params()
      if (!is.null(err <- check_alias_uniqueness(p))) {
        showNotification(err, type = "error", duration = 8)
        return()
      }
      tables <- isolate(store$tables)
      result <- execute_query(p, tables)
      if (!is.null(result$error)) {
        showNotification(paste("Query error:", result$error), type = "error", duration = 8)
        preview_data(NULL)
        preview_visible(FALSE)
      } else {
        preview_data(head(result$data, 1000L))
        preview_visible(TRUE)
        bslib::nav_select("qb_tabs", "results", session = session)
      }
    })

    output$preview_dt <- DT::renderDT({
      req(preview_data())
      DT::datatable(
        preview_data(),
        options = list(scrollX = TRUE, pageLength = ig_page_len(store), dom = "tip"),
        rownames = FALSE
      )
    })

    # ── Run & Save ────────────────────────────────────────────────────────────
    run_status_msg <- reactiveVal("")
    output$run_status <- renderText({ run_status_msg() })

    do_run <- function() {
      p <- collect_params()
      if (!is.null(err <- check_alias_uniqueness(p))) {
        run_status_msg(paste0("\u2717 ", err))
        showNotification(err, type = "error", duration = 8)
        return()
      }
      tables <- isolate(store$tables)
      result <- execute_query(p, tables)

      if (!is.null(result$error)) {
        run_status_msg(paste0("Error: ", result$error))
        showNotification(paste("Run error:", result$error), type = "error", duration = 8)
        if (!is.null(task_id)) {
          task <- isolate(store$tasks[[task_id]])
          if (!is.null(task)) {
            task$error_msg <- result$error
            # store_set_task (not direct assignment) so the canvas status flips
            # to error and reactive observers are invalidated
            store_set_task(store, task)
          }
        }
        return()
      }

      out_name <- p$output_name
      store_add_table(store, out_name, result$data)
      r_code <- build_query_code(p)
      if (!is.null(task_id)) {
        task <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, "query_builder")
        task$inputs    <- query_input_tables(p)
        task$output    <- out_name
        task$params    <- p
        task$r_code    <- r_code
        task$run_time  <- Sys.time()
        task$error_msg <- NULL
        store_set_task(store, task)
      }
      n_rows <- nrow(result$data); n_cols <- ncol(result$data)
      run_status_msg(sprintf("\u2713 %s: %d rows \u00d7 %d cols", out_name, n_rows, n_cols))
      preview_data(head(result$data, 1000L))
      preview_visible(TRUE)
      bslib::nav_select("qb_tabs", "results", session = session)
      showNotification(
        sprintf("'%s' created \u2014 %d rows \u00d7 %d cols.", out_name, n_rows, n_cols),
        type = "message", duration = 3)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_result_fn(store, task_id, function(result) {
      preview_data(ig_preview_data(result$data)); preview_visible(!is.null(result$data)); run_status_msg(ig_preview_status(result))
    }, session = session)
    store_register_params_fn(store, task_id, collect_params, session = session)
    if (!is.null(task_id)) session$onFlushed(function() {
      store_register_runner(store, task_id, do_run)
    }, once = TRUE)
    store_register_code_fn(store, task_id,
      function() build_query_code(collect_params()))
  })
}

# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════


#' Return a small colour-coded badge string for a column class
#' @param cls Column class used to select the matching badge style.
badge_class <- function(cls) {
  cls <- cls %||% "unknown"
  cls_key <- gsub("[^a-zA-Z0-9_-]", "-", tolower(cls))
  span(
    class = paste("ig-type-badge", paste0("ig-type-", cls_key)),
    cls
  )
}

operand_ui <- function(ns, suffix, label, col_choices) {
  tagList(
    div(class = "ig-operand-box",
      div(class = "ig-operand-title", label),
      radioButtons(ns(paste0("comp_basic_", suffix, "_kind")), NULL,
        choices = c("Column" = "column", "Fixed value" = "value"),
        selected = "column", inline = TRUE),
      conditionalPanel(
        condition = sprintf("input['%s'] == 'column'",
          ns(paste0("comp_basic_", suffix, "_kind"))),
        selectInput(ns(paste0("comp_basic_", suffix, "_col")), sr_label("Operand column"),
          choices = col_choices, width = "100%")
      ),
      conditionalPanel(
        condition = sprintf("input['%s'] == 'value'",
          ns(paste0("comp_basic_", suffix, "_kind"))),
        textInput(ns(paste0("comp_basic_", suffix, "_value")), sr_label("Operand value"),
          placeholder = "number, text, TRUE/FALSE, or date", width = "100%")
      )
    )
  )
}

build_basic_compute_expr <- function(op,
                                     a_kind, a_col, a_value,
                                     b_kind, b_col, b_value) {
  op <- op %||% "copy"
  a <- basic_operand_expr(a_kind, a_col, a_value)
  b <- basic_operand_expr(b_kind, b_col, b_value)
  if (!nzchar(a)) return("")

  switch(op,
    copy = a,
    add = if (nzchar(b)) paste0("(", a, ") + (", b, ")") else "",
    subtract = if (nzchar(b)) paste0("(", a, ") - (", b, ")") else "",
    multiply = if (nzchar(b)) paste0("(", a, ") * (", b, ")") else "",
    divide = if (nzchar(b)) paste0("(", a, ") / (", b, ")") else "",
    concat = if (nzchar(b)) paste0("paste0(", a, ", ", b, ")") else "",
    upper = paste0("toupper(", a, ")"),
    lower = paste0("tolower(", a, ")"),
    trim = paste0("trimws(", a, ")"),
    is_na = paste0("is.na(", a, ")"),
    a
  )
}

basic_operand_expr <- function(kind, col, value) {
  kind <- kind %||% "column"
  if (identical(kind, "column")) {
    col <- col %||% ""
    if (!nzchar(col)) return("")
    return(r_ident(col))
  }
  basic_value_expr(value)
}

basic_value_expr <- function(value) {
  value <- trimws(value %||% "")
  if (!nzchar(value)) return("")
  if (grepl("^-?\\d+(\\.\\d+)?$", value)) return(value)
  if (value %in% c("TRUE", "FALSE", "NA", "NULL", "Inf", "NaN")) return(value)
  r_val(value, "character")
}

snapshot_join_keys <- function(input, keys) {
  if (length(keys) == 0L) return(list())
  lapply(seq_along(keys), function(i) {
    list(
      left = input[[paste0("jk_left_", i)]] %||% keys[[i]]$left %||% "",
      right = input[[paste0("jk_right_", i)]] %||% keys[[i]]$right %||% ""
    )
  })
}

#' Translate a QB params list into a dplyr pipeline string
#'
#' @param p  QB params list (see schema above)
#' @return   Single character string — the R code snippet for this task
build_query_code <- function(p) {
  primary <- p$primary_table %||% ""
  chain   <- if (nzchar(primary)) primary else "input_data"

  # ── Joins ──────────────────────────────────────────────────────────────────
  for (j in p$joins %||% list()) {
    fn <- switch(j$type %||% "left",
      inner = "inner_join", left  = "left_join",
      right = "right_join", full  = "full_join", cross = "cross_join",
      "left_join")
    if (length(j$keys_left) == 0L || fn == "cross_join") {
      by_arg <- ""
    } else {
      pairs <- paste0('"', j$keys_left, '" = "', j$keys_right, '"')
      by_arg <- paste0(', by = c(', paste(pairs, collapse = ", "), ')')
    }
    chain <- paste0(chain, ' |>\n  ', fn, '(', j$right_table, by_arg, ')')
  }

  # ── Computed columns (mutate) ──────────────────────────────────────────────
  computed <- p$computed %||% list()
  computed <- computed[vapply(computed, function(x)
    nchar(trimws(x$name %||% "")) > 0 && nchar(trimws(x$expr %||% "")) > 0,
    logical(1))]
  if (length(computed) > 0L) {
    mutate_args <- paste(
      vapply(computed, function(x) paste0(r_ident(x$name), " = ", x$expr), character(1)),
      collapse = ",\n    "
    )
    chain <- paste0(chain, ' |>\n  mutate(\n    ', mutate_args, '\n  )')
  }

  # ── Filter ─────────────────────────────────────────────────────────────────
  filters <- p$filters %||% list()
  filters <- filters[vapply(filters, function(f)
    nchar(trimws(f$col %||% "")) > 0, logical(1))]
  if (length(filters) > 0L) {
    chain <- paste0(chain, ' |>\n  filter(\n    ',
                    build_filter_r(filters), '\n  )')
  }

  # ── Select / Summarise ─────────────────────────────────────────────────────
  sel <- p$select %||% list()
  sel <- sel[vapply(sel, function(x) nchar(trimws(x$col %||% "")) > 0, logical(1))]
  has_agg <- any(vapply(sel, function(x) (x$func %||% "none") != "none", logical(1)))

  if (length(sel) > 0L) {
    if (has_agg) {
      # Non-aggregated columns are group keys. They must NOT be repeated inside
      # summarise() — referencing a bare group column there returns one row per
      # source row ("reframe" semantics), silently duplicating the result.
      is_agg  <- vapply(sel, function(x) (x$func %||% "none") != "none", logical(1))
      non_agg <- sel[!is_agg]
      agg_sel <- sel[is_agg]
      if (length(non_agg) > 0L) {
        keys <- vapply(non_agg, function(x) {
          col   <- r_ident(x$col)
          alias <- r_ident(x$alias %||% x$col)
          # group_by(new_name = col) renames the key in the output
          if (alias != col) paste0(alias, " = ", col) else col
        }, character(1))
        chain <- paste0(chain, ' |>\n  group_by(',
                        paste(keys, collapse = ", "), ')')
      }

      sum_args <- paste(
        vapply(agg_sel, function(x) {
          col   <- r_ident(x$col)
          alias <- r_ident(x$alias %||% x$col)
          func  <- x$func  %||% "none"
          expr  <- switch(func,
            COUNT          = "n()",
            COUNT_DISTINCT = paste0("n_distinct(", col, ")"),
            SUM            = paste0("sum(", col, ", na.rm = TRUE)"),
            AVG            = paste0("mean(", col, ", na.rm = TRUE)"),
            MIN            = paste0("min(", col, ", na.rm = TRUE)"),
            MAX            = paste0("max(", col, ", na.rm = TRUE)"),
            MEDIAN         = paste0("median(", col, ", na.rm = TRUE)"),
            STDDEV         = paste0("sd(", col, ", na.rm = TRUE)"),
            VAR            = paste0("var(", col, ", na.rm = TRUE)"),
            CUSTOM         = {
              ce <- trimws(x$expr %||% "")
              if (nzchar(ce)) ce else col
            },
            col)
          paste0(alias, " = ", expr)
        }, character(1)),
        collapse = ",\n    ")
      chain <- paste0(chain, ' |>\n  summarise(\n    ', sum_args,
                      ',\n    .groups = "drop"\n  )')

      # ── HAVING (post-aggregation filter) ──────────────────────────────────
      havings <- p$having %||% list()
      havings <- havings[vapply(havings, function(f)
        nchar(trimws(f$col %||% "")) > 0, logical(1))]
      if (length(havings) > 0L) {
        chain <- paste0(chain, ' |>\n  filter(\n    ',
                        build_filter_r(havings), '\n  )')
      }

    } else {
      sel_args <- paste(
        vapply(sel, function(x) {
          col   <- r_ident(x$col)
          alias <- r_ident(x$alias %||% x$col)
          if (alias != col) paste0(alias, " = ", col) else col
        }, character(1)),
        collapse = ",\n    ")
      fn <- if (isTRUE(p$distinct)) "distinct" else "select"
      chain <- paste0(chain, ' |>\n  ', fn, '(\n    ', sel_args, '\n  )')
    }
  } else if (isTRUE(p$distinct)) {
    chain <- paste0(chain, ' |>\n  distinct()')
  }

  # ── Sort ───────────────────────────────────────────────────────────────────
  sorts <- p$sorts %||% list()
  sorts <- sorts[vapply(sorts, function(x) nchar(trimws(x$col %||% "")) > 0, logical(1))]
  if (length(sorts) > 0L) {
    arr_args <- paste(
      vapply(sorts, function(x) {
        col <- r_ident(x$col)
        if ((x$dir %||% "ASC") == "DESC") paste0("desc(", col, ")") else col
      }, character(1)),
      collapse = ", ")
    chain <- paste0(chain, ' |>\n  arrange(', arr_args, ')')
  }

  # ── Assignment ─────────────────────────────────────────────────────────────
  out <- r_ident(p$output_name %||% "query_out")
  lib_lines <- library_code_lines(p$libraries %||% character(0))
  paste(c(lib_lines, paste0(out, " <- ", chain)), collapse = "\n")
}

#' Execute a QB params list against a named list of data frames
#'
#' @param p       QB params list
#' @param tables  Named list of data frames (from store$tables)
#' @return        List with $data (df or NULL) and $error (chr or NULL)
#' @param context Named iteration or execution values available to expressions.
execute_query <- function(p, tables, context = list()) {
  if (!nzchar(p$primary_table %||% ""))
    return(list(data = NULL, error = "Select a primary (input) table before running."))
  code <- tryCatch(build_query_code(p), error = function(e) NULL)
  if (is.null(code)) return(list(data = NULL, error = "Failed to build query code."))

  env <- list2env(tables, parent = baseenv())
  for (name in names(context)) env[[name]] <- context[[name]]
  env$dplyr <- asNamespace("dplyr")
  # Expose dplyr verbs directly for generated code
  for (fn in c("filter","select","mutate","arrange","summarise","group_by",
               "distinct","inner_join","left_join","right_join","full_join",
               "cross_join","n","n_distinct","desc","between","case_when",
               "coalesce","if_else")) {
    if (!fn %in% names(tables))
      assign(fn, getExportedValue("dplyr", fn), envir = env)
  }
  # Expose stats functions used by aggregate options (MEDIAN, STDDEV, VAR)
  for (fn in c("median", "sd", "var")) {
    if (!fn %in% names(tables))
      assign(fn, getExportedValue("stats", fn), envir = env)
  }
  for (pkg in clean_libraries(p$libraries %||% character(0))) {
    ns_pkg <- tryCatch(loadNamespace(pkg), error = function(e) NULL)
    if (is.null(ns_pkg)) {
      return(list(data = NULL, error = paste0("Package not available: ", pkg)))
    }
    for (fn in getNamespaceExports(ns_pkg)) {
      if (!fn %in% names(tables))
        assign(fn, getExportedValue(pkg, fn), envir = env)
    }
  }

  result <- tryCatch({
    eval(parse(text = code), envir = env)
    raw <- get(p$output_name %||% "query_out", envir = env)
    # Collect lazy tbls (tbl_sql for DB tables, tbl_df/tibble for in-memory).
    # dplyr::collect() is a no-op on plain data frames; as.data.frame() removes
    # any tibble class.  This ensures the QB always stores a base data frame.
    collected <- if (inherits(raw, "tbl")) {
      as.data.frame(dplyr::collect(raw))
    } else {
      raw
    }
    list(data = collected, error = NULL)
  }, error = function(e) {
    list(data = NULL, error = conditionMessage(e))
  })
  result
}

#' Return a fresh, empty QB params list
#' @param output_name Name assigned to the resulting output.
default_qb_params <- function(output_name = "query_out") {
  list(
    primary_table = NULL,
    joins         = list(),
    libraries     = character(0),
    computed      = list(),
    filters       = list(),
    having        = list(),
    select        = list(),
    sorts         = list(),
    distinct      = FALSE,
    output_name   = output_name
  )
}

query_input_tables <- function(p) {
  primary <- p$primary_table %||% ""
  joined <- vapply(p$joins %||% list(), function(j) j$right_table %||% "", character(1))
  unique(Filter(nzchar, c(primary, joined)))
}
