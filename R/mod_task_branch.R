# mod_task_branch.R -- Branch control node.

default_branch_params <- function(output_name = "branch_out") {
  list(
    dependencies = character(0),
    paths = list(
      list(
        id = "true",
        label = "True",
        token = paste0(output_name, "_true"),
        condition = list(
          op = "and",
          rules = list(list(kind = "custom", expr = "TRUE")),
          groups = list()
        )
      ),
      list(
        id = "else",
        label = "Else",
        token = paste0(output_name, "_else"),
        else_path = TRUE,
        condition = list(op = "and", rules = list(), groups = list())
      )
    )
  )
}

branch_output_specs <- function(p) {
  paths <- p$paths %||% list()
  specs <- lapply(paths, function(path) {
    token <- trimws(path$token %||% "")
    if (!nzchar(token)) return(NULL)
    list(
      name = token,
      kind = "branch",
      label = path$label %||% token,
      branch_path = path$id %||% token
    )
  })
  Filter(Negate(is.null), specs)
}

branch_condition_summary <- function(cond) {
  cond <- cond %||% list(op = "and", rules = list(), groups = list())
  op <- toupper(cond$op %||% "and")
  parts <- c(
    vapply(cond$rules %||% list(), branch_rule_summary, character(1)),
    vapply(cond$groups %||% list(), function(g) {
      paste0("(", branch_condition_summary(g), ")")
    }, character(1))
  )
  parts <- parts[nzchar(parts)]
  if (!length(parts)) return("always")
  paste(parts, collapse = paste0(" ", op, " "))
}

branch_rule_summary <- function(rule) {
  kind <- rule$kind %||% "custom"
  switch(kind,
    row_count = sprintf(
      "nrow(%s) %s %s",
      rule$table %||% "<dataset>", rule$op %||% ">", rule$value %||% "0"
    ),
    column_value = sprintf(
      "any(%s$%s %s %s)",
      rule$table %||% "<dataset>", rule$column %||% "<column>",
      rule$op %||% "==", rule$value %||% "<value>"
    ),
    validation_result = sprintf(
      "validation %s is %s",
      rule$task_id %||% "<task>", rule$state %||% "success"
    ),
    task_status = sprintf(
      "task %s status is %s",
      rule$task_id %||% "<task>", rule$status %||% "success"
    ),
    parameter_value = sprintf(
      "%s.%s %s %s",
      rule$task_id %||% "<task>", rule$parameter %||% "<param>",
      rule$op %||% "==", rule$value %||% "<value>"
    ),
    custom = rule$expr %||% "",
    ""
  )
}

branch_rule_code <- function(rule) {
  kind <- rule$kind %||% "custom"
  switch(kind,
    row_count = sprintf(
      "nrow(%s) %s %s",
      r_ident(rule$table %||% ""), rule$op %||% ">", rule$value %||% "0"
    ),
    column_value = sprintf(
      "any(%s[[%s]] %s %s, na.rm = TRUE)",
      r_ident(rule$table %||% ""), deparse(rule$column %||% ""),
      rule$op %||% "==", rule$value %||% "NA"
    ),
    validation_result = sprintf(
      "identical(.task_status[[%s]], %s)",
      deparse(rule$task_id %||% ""), deparse(rule$state %||% "success")
    ),
    task_status = sprintf(
      "identical(.task_status[[%s]], %s)",
      deparse(rule$task_id %||% ""), deparse(rule$status %||% "success")
    ),
    parameter_value = sprintf(
      "(.task_params[[%s]][[%s]] %s %s)",
      deparse(rule$task_id %||% ""), deparse(rule$parameter %||% ""),
      rule$op %||% "==",
      rule$value %||% "NULL"
    ),
    custom = rule$expr %||% "FALSE",
    "FALSE"
  )
}

branch_condition_code <- function(cond) {
  cond <- cond %||% list(op = "and", rules = list(), groups = list())
  sep <- if (identical(tolower(cond$op %||% "and"), "or")) " || " else " && "
  parts <- c(
    vapply(cond$rules %||% list(), branch_rule_code, character(1)),
    vapply(cond$groups %||% list(), function(g) {
      paste0("(", branch_condition_code(g), ")")
    }, character(1))
  )
  parts <- parts[nzchar(parts)]
  if (!length(parts)) return("TRUE")
  paste0("(", paste(parts, collapse = sep), ")")
}

validate_branch_condition <- function(cond) {
  code <- branch_condition_code(cond)
  tryCatch({
    parse(text = code)
    NULL
  }, error = function(e) conditionMessage(e))
}

branch_eval_condition <- function(cond, tables, objects, tasks, params) {
  code <- branch_condition_code(cond)
  env <- new.env(parent = baseenv())
  for (nm in names(tables)) env[[nm]] <- tables[[nm]]
  for (nm in names(objects)) env[[nm]] <- objects[[nm]]
  env$.task_status <- lapply(tasks, function(t) t$status %||% "pending")
  env$.task_params <- lapply(tasks, function(t) t$params %||% list())
  for (fn in c("nrow", "ncol", "any", "all", "sum", "mean", "isTRUE",
               "identical", "length", "is.na")) {
    env[[fn]] <- get(fn, envir = baseenv())
  }
  tryCatch({
    value <- eval(parse(text = code), envir = env)
    if (!is.logical(value) || length(value) != 1L || is.na(value))
      stop("Condition must return one TRUE or FALSE value.")
    value
  },
    error = function(e) stop("Condition failed: ", conditionMessage(e)))
}

execute_branch <- function(p, tables = list(), objects = list(), tasks = list(),
                           task_id = NULL) {
  paths <- p$paths %||% list()
  if (!length(paths)) return(list(error = "Branch has no paths."))
  tokens <- vapply(paths, function(x) trimws(x$token %||% ""), character(1))
  if (any(!nzchar(tokens)) || anyDuplicated(tokens))
    return(list(error = "Every branch path needs a non-empty, unique token."))
  if (sum(vapply(paths, function(x) isTRUE(x$else_path), logical(1))) > 1L)
    return(list(error = "A branch can have only one Else path."))

  errors <- Filter(Negate(is.null), lapply(paths, function(path) {
    if (isTRUE(path$else_path)) return(NULL)
    err <- validate_branch_condition(path$condition)
    if (!is.null(err)) paste(path$label %||% path$id %||% path$token, err, sep = ": ")
  }))
  if (length(errors)) return(list(error = paste(errors, collapse = " | ")))

  matched <- character(0)
  decisions <- lapply(paths, function(path) {
    token <- path$token %||% ""
    ok <- FALSE
    if (!isTRUE(path$else_path)) {
      ok <- branch_eval_condition(path$condition, tables, objects, tasks, p)
      if (ok && nzchar(token)) matched <<- c(matched, token)
    }
    list(
      id = path$id %||% token,
      label = path$label %||% token,
      token = token,
      matched = ok,
      summary = if (isTRUE(path$else_path)) "else" else branch_condition_summary(path$condition)
    )
  })

  if (!length(matched)) {
    for (i in seq_along(paths)) {
      if (isTRUE(paths[[i]]$else_path) && nzchar(paths[[i]]$token %||% "")) {
        matched <- paths[[i]]$token
        decisions[[i]]$matched <- TRUE
      }
    }
  }

  list(
    data = NULL,
    outputs = branch_output_specs(p),
    matched_tokens = matched,
    skipped_tokens = setdiff(vapply(paths, `[[`, character(1), "token"), matched),
    decisions = decisions,
    error = NULL
  )
}

build_branch_code <- function(p) {
  lines <- c(
    "# Branch paths",
    "if (!exists('.task_status', inherits = FALSE)) .task_status <- list()",
    "if (!exists('.task_params', inherits = FALSE)) .task_params <- list()",
    "if (!exists('.ig_control', inherits = FALSE)) .ig_control <- list()",
    "branch_decision <- list()"
  )
  paths <- p$paths %||% list()
  ordinary <- Filter(function(x) !isTRUE(x$else_path), paths)
  fallback <- Filter(function(x) isTRUE(x$else_path), paths)
  for (path in c(ordinary, fallback)) {
    token <- path$token %||% ""
    expr <- if (isTRUE(path$else_path)) "!any(unlist(branch_decision))" else branch_condition_code(path$condition)
    lines <- c(lines,
      sprintf(".ig_condition <- %s", expr),
      "if (!is.logical(.ig_condition) || length(.ig_condition) != 1L || is.na(.ig_condition)) stop('Condition must return one TRUE or FALSE value.')",
      sprintf("branch_decision[[%s]] <- .ig_condition", deparse(token)),
      sprintf(".ig_control[[%s]] <- .ig_condition", deparse(token)))
  }
  paste(lines, collapse = "\n")
}

#' Read table and task references from nested branch conditions.
#' @keywords internal
#' @param p Configured task parameter list.
#' @param field Configuration field being inspected or substituted.
branch_references <- function(p, field = c("table", "task_id")) {
  field <- match.arg(field)
  walk <- function(condition) {
    rules <- condition$rules %||% list()
    direct <- vapply(rules, function(x) x[[field]] %||% "", character(1))
    nested <- unlist(lapply(condition$groups %||% list(), walk), use.names = FALSE)
    unique(Filter(nzchar, c(direct, nested)))
  }
  unique(unlist(lapply(p$paths %||% list(), function(path) walk(path$condition %||% list())), use.names = FALSE))
}

branch_ui <- function(id) {
  ns <- NS(id)
  bslib::card(
    class = "ig-task-card",
    full_screen = TRUE,
    bslib::card_header(class = "d-flex align-items-center gap-2",
      icon("code-branch"), " Branch"),
    bslib::card_body(
      padding = 0, class = "ig-task-tabs",
      bslib::navset_tab(
        id = ns("task_tabs"),
        bslib::nav_panel(tagList(icon("sliders"), " Setup"), value = "setup",
          div(class = "ig-setup-pane",
            div(class = "alert alert-info small mb-3",
              tags$strong("How branches work"),
              tags$ol(class = "mb-0 mt-2",
                tags$li("Choose the datasets or task outputs this branch reads."),
                tags$li("Create one path per possible route. Each path emits a token."),
                tags$li("Add the matching path token to downstream tasks as an input dependency."),
                tags$li("Run the branch or the full flow. Non-matching downstream paths are marked skipped.")
              )
            ),
            selectInput(ns("dependencies"), "Inputs / dependencies",
              choices = character(0), selected = character(0), multiple = TRUE,
              width = "100%"),
            fluidRow(
              column(5, numericInput(ns("path_count"), "Number of outgoing paths",
                min = 1, max = 6, value = 2, step = 1)),
              column(7, div(class = "small text-muted mt-4",
                "A path token is the control dependency downstream tasks use, for example gate_true."))
            ),
            uiOutput(ns("path_controls")),
            actionButton(ns("validate"), "Validate", icon = icon("check"),
              class = "btn btn-sm btn-outline-secondary")
          )
        ),
        bslib::nav_panel(tagList(icon("file-code"), " Code"), value = "code",
          div(class = "ig-results-pane p-3",
            div(class = "alert alert-light border small",
              tags$strong("Downstream wiring"),
              tags$p(class = "mb-0",
                "Each branch path becomes a lineage node. Add the matching token to a downstream task's inputs so Run Flow can skip non-matching paths.")),
            uiOutput(ns("summary")),
            verbatimTextOutput(ns("code_preview"), placeholder = TRUE)
          )
        )
      )
    ),
    bslib::card_footer(
      class = "d-flex align-items-center gap-2",
      actionButton(ns("btn_run"), "Evaluate", icon = icon("play"),
        class = "btn btn-sm btn-primary"),
      span(class = "ms-auto text-muted small", role = "status",
        `aria-live` = "polite", textOutput(ns("run_status"), inline = TRUE))
    )
  )
}

branch_kind_choices <- function() {
  c(
    "Dataset row count" = "row_count",
    "Dataset column value" = "column_value",
    "Validation task result" = "validation_result",
    "Task success/failure" = "task_status",
    "Parameter value" = "parameter_value",
    "Custom R expression" = "custom",
    "Fallback / else path" = "else"
  )
}

branch_comparison_choices <- function() {
  c("==" = "==", "!=" = "!=", ">" = ">", ">=" = ">=", "<=" = "<=", "<" = "<")
}

branch_path_to_simple <- function(path, i = 1L) {
  cond <- path$condition %||% list()
  rules <- cond$rules %||% list()
  rule <- if (length(rules)) rules[[1]] else list(kind = "custom", expr = "TRUE")
  kind <- if (isTRUE(path$else_path)) "else" else rule$kind %||% "custom"
  list(
    label = path$label %||% paste("Path", i),
    token = path$token %||% paste0("branch_path_", i),
    kind = kind,
    table = rule$table %||% "",
    column = rule$column %||% "",
    op = rule$op %||% "==",
    value = rule$value %||% "",
    task_id = rule$task_id %||% "",
    state = rule$state %||% rule$status %||% "success",
    parameter = rule$parameter %||% "",
    expr = rule$expr %||% "TRUE"
  )
}

branch_simple_to_path <- function(x, i = 1L) {
  kind <- x$kind %||% "custom"
  is_else <- identical(kind, "else")
  rule <- switch(kind,
    row_count = list(kind = "row_count", table = x$table %||% "",
      op = x$op %||% ">", value = x$value %||% "0"),
    column_value = list(kind = "column_value", table = x$table %||% "",
      column = x$column %||% "", op = x$op %||% "==",
      value = x$value %||% "NA"),
    validation_result = list(kind = "validation_result", task_id = x$task_id %||% "",
      state = x$state %||% "success"),
    task_status = list(kind = "task_status", task_id = x$task_id %||% "",
      status = x$state %||% "success"),
    parameter_value = list(kind = "parameter_value", task_id = x$task_id %||% "",
      parameter = x$parameter %||% "", op = x$op %||% "==",
      value = x$value %||% "NULL"),
    custom = list(kind = "custom", expr = x$expr %||% "FALSE"),
    list(kind = "custom", expr = "FALSE")
  )
  list(
    id = paste0("path", i),
    label = trimws(x$label %||% paste("Path", i)),
    token = trimws(x$token %||% paste0("branch_path_", i)),
    else_path = is_else,
    condition = if (is_else) {
      list(op = "and", rules = list(), groups = list())
    } else {
      list(op = "and", rules = list(rule), groups = list())
    }
  )
}

parse_branch_paths_text <- function(text, output_name = "branch_out") {
  lines <- strsplit(text %||% "", "\n", fixed = TRUE)[[1]]
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]
  if (!length(lines)) return(default_branch_params(output_name)$paths)
  lapply(seq_along(lines), function(i) {
    parts <- trimws(strsplit(lines[[i]], "|", fixed = TRUE)[[1]])
    label <- if (length(parts) >= 1L && nzchar(parts[[1]])) parts[[1]] else paste("Path", i)
    token <- if (length(parts) >= 2L && nzchar(parts[[2]])) parts[[2]] else paste0(output_name, "_", i)
    expr <- if (length(parts) >= 3L && nzchar(parts[[3]])) parts[[3]] else "TRUE"
    list(
      id = paste0("path", i),
      label = label,
      token = token,
      else_path = identical(toupper(expr), "ELSE"),
      condition = if (identical(toupper(expr), "ELSE")) {
        list(op = "and", rules = list(), groups = list())
      } else {
        list(op = "and", rules = list(list(kind = "custom", expr = expr)), groups = list())
      }
    )
  })
}

format_branch_paths_text <- function(paths) {
  paste(vapply(paths %||% list(), function(path) {
    expr <- if (isTRUE(path$else_path)) "ELSE" else branch_condition_summary(path$condition)
    paste(path$label %||% "", path$token %||% "", expr, sep = " | ")
  }, character(1)), collapse = "\n")
}

branch_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    ns <- session$ns
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_branch_params()
      else default_branch_params(paste0(task_id %||% "branch", "_out"))
    })
    init_simple <- lapply(seq_along(init_p$paths %||% list()), function(i) {
      branch_path_to_simple(init_p$paths[[i]], i)
    })
    run_status_msg <- reactiveVal("")

    observe({
      choices <- store_available_outputs(store, task_id = task_id)
      updateSelectInput(session, "dependencies", choices = choices,
        selected = intersect(init_p$dependencies %||% character(0), choices))
    })
    session$onFlushed(function() {
      updateNumericInput(session, "path_count",
        value = max(1L, length(init_p$paths %||% list())))
    }, once = TRUE)

    output$path_controls <- renderUI({
      n <- max(1L, min(6L, as.integer(input$path_count %||% length(init_simple) %||% 2L)))
      table_choices <- c("", store_available_tables(store, task_id))
      task_choices <- c("", names(isolate(store$tasks) %||% list()))
      controls <- lapply(seq_len(n), function(i) {
        saved <- init_simple[[i]] %||% branch_path_to_simple(list(), i)
        table_id <- paste0("table_col_", i)
        selected_table <- input[[table_id]] %||% saved$table %||% ""
        col_choices <- c("", store_col_schema(store, selected_table)$column)
        kind_id <- ns(paste0("kind_", i))
        bslib::accordion_panel(
          title = paste("Path", i),
          value = paste0("path_", i),
          fluidRow(
            column(5, textInput(ns(paste0("label_", i)), "Path label",
              value = saved$label)),
            column(5, textInput(ns(paste0("token_", i)), "Path token",
              value = saved$token)),
            column(2, selectInput(ns(paste0("kind_", i)), "Condition",
              choices = branch_kind_choices(), selected = saved$kind))
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'row_count'", kind_id),
            fluidRow(
              column(5, selectInput(ns(paste0("table_row_", i)), "Dataset",
                choices = table_choices, selected = saved$table)),
              column(3, selectInput(ns(paste0("op_row_", i)), "Operator",
                choices = branch_comparison_choices(), selected = saved$op)),
              column(4, textInput(ns(paste0("value_row_", i)), "Row count",
                value = saved$value %||% "0"))
            )
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'column_value'", kind_id),
            fluidRow(
              column(4, selectInput(ns(paste0("table_col_", i)), "Dataset",
                choices = table_choices, selected = saved$table)),
              column(4, selectInput(ns(paste0("column_", i)), "Column",
                choices = col_choices, selected = saved$column)),
              column(2, selectInput(ns(paste0("op_col_", i)), "Operator",
                choices = branch_comparison_choices(), selected = saved$op)),
              column(2, textInput(ns(paste0("value_col_", i)), "R value",
                value = saved$value %||% "\"value\""))
            )
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'validation_result' || input['%s'] == 'task_status'", kind_id, kind_id),
            fluidRow(
              column(7, selectInput(ns(paste0("task_status_", i)), "Task",
                choices = task_choices, selected = saved$task_id)),
              column(5, selectInput(ns(paste0("state_", i)), "State",
                choices = c("success", "error", "skipped", "pending"),
                selected = saved$state))
            )
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'parameter_value'", kind_id),
            fluidRow(
              column(4, selectInput(ns(paste0("task_param_", i)), "Task",
                choices = task_choices, selected = saved$task_id)),
              column(3, textInput(ns(paste0("parameter_", i)), "Parameter",
                value = saved$parameter)),
              column(2, selectInput(ns(paste0("op_param_", i)), "Operator",
                choices = branch_comparison_choices(), selected = saved$op)),
              column(3, textInput(ns(paste0("value_param_", i)), "R value",
                value = saved$value %||% "NULL"))
            )
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'custom'", kind_id),
            textAreaInput(ns(paste0("expr_", i)), "R expression",
              value = saved$expr %||% "TRUE", rows = 2, width = "100%")
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'else'", kind_id),
            div(class = "alert alert-light border small mb-0",
              "This path runs only when no earlier non-else path matches.")
          )
        )
      })
      do.call(bslib::accordion, c(controls, list(open = paste0("path_", seq_len(n)))))
    })

    collect_p <- reactive({
      n <- max(1L, min(6L, as.integer(input$path_count %||% length(init_simple) %||% 2L)))
      paths <- lapply(seq_len(n), function(i) {
        kind <- input[[paste0("kind_", i)]] %||% "custom"
        table_value <- if (identical(kind, "row_count")) {
          input[[paste0("table_row_", i)]] %||% ""
        } else {
          input[[paste0("table_col_", i)]] %||% ""
        }
        op_value <- switch(kind,
          row_count = input[[paste0("op_row_", i)]] %||% ">",
          column_value = input[[paste0("op_col_", i)]] %||% "==",
          parameter_value = input[[paste0("op_param_", i)]] %||% "==",
          "=="
        )
        compare_value <- switch(kind,
          row_count = input[[paste0("value_row_", i)]] %||% "0",
          column_value = input[[paste0("value_col_", i)]] %||% "NA",
          parameter_value = input[[paste0("value_param_", i)]] %||% "NULL",
          ""
        )
        task_value <- if (identical(kind, "parameter_value")) {
          input[[paste0("task_param_", i)]] %||% ""
        } else {
          input[[paste0("task_status_", i)]] %||% ""
        }
        branch_simple_to_path(list(
          label = input[[paste0("label_", i)]] %||% paste("Path", i),
          token = input[[paste0("token_", i)]] %||% paste0(task_id %||% "branch", "_", i),
          kind = kind,
          table = table_value,
          column = input[[paste0("column_", i)]] %||% "",
          op = op_value,
          value = compare_value,
          task_id = task_value,
          state = input[[paste0("state_", i)]] %||% "success",
          parameter = input[[paste0("parameter_", i)]] %||% "",
          expr = input[[paste0("expr_", i)]] %||% "TRUE"
        ), i)
      })
      list(
        dependencies = input$dependencies %||% character(0),
        paths = paths
      )
    })

    output$code_preview <- renderText(build_branch_code(collect_p()))
    output$summary <- renderUI({
      paths <- collect_p()$paths
      tags$ul(lapply(paths, function(path) {
        tags$li(tags$strong(path$label %||% path$token), ": ",
          if (isTRUE(path$else_path)) "else" else branch_condition_summary(path$condition))
      }))
    })
    output$run_status <- renderText(run_status_msg())

    do_run <- function() {
      p <- collect_p()
      result <- execute_branch(
        p,
        tables = isolate(store$tables),
        objects = lapply(isolate(store$objects), `[[`, "value"),
        tasks = isolate(store$tasks),
        task_id = task_id
      )
      if (!is.null(result$error)) {
        run_status_msg(paste("Error:", result$error))
        if (!is.null(task_id)) {
          task <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, "branch")
          task$error_msg <- result$error
          task$params <- p
          store_set_task(store, task)
        }
        return(invisible(FALSE))
      }
      if (!is.null(task_id)) {
        task <- isolate(store$tasks[[task_id]]) %||% task_def(task_id, "branch")
        task$inputs <- p$dependencies
        task$output <- ""
        task$outputs <- branch_output_specs(p)
        task$params <- p
        task$r_code <- build_branch_code(p)
        task$branch_decision <- result
        task$run_time <- Sys.time()
        task$error_msg <- NULL
        task$execution_log <- c(task$execution_log %||% list(), list(list(
          time = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
          event = "branch",
          matched = result$matched_tokens,
          skipped = result$skipped_tokens
        )))
        store_set_task(store, task)
        store_apply_branch_decision(store, task_id)
      }
      run_status_msg(paste("Matched:", paste(result$matched_tokens, collapse = ", ")))
      invisible(TRUE)
    }

    observeEvent(input$validate, {
      errs <- Filter(Negate(is.null), lapply(collect_p()$paths, function(path) {
        if (isTRUE(path$else_path)) NULL else validate_branch_condition(path$condition)
      }))
      if (length(errs)) {
        run_status_msg(paste("Invalid:", paste(errs, collapse = " | ")))
      } else {
        run_status_msg("All branch expressions parse.")
      }
    })
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_result_fn(store, task_id, function(result) {
      run_status_msg(if (is.null(result) || !is.null(result$error)) ig_preview_status(result) else paste("Matched:", paste(result$matched_tokens, collapse = ", ")))
    }, session = session)
    store_register_params_fn(store, task_id, collect_p, session = session)
    if (!is.null(task_id)) {
      store_register_runner(store, task_id, do_run)
      store_register_code_fn(store, task_id, function() build_branch_code(collect_p()))
    }
  })
}
