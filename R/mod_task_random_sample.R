# mod_task_random_sample.R — Random Sample
#
# Self-contained task module: default params, UI, server, execute, and any
# task-specific code generation. Shared helpers live in task_helpers_*.R.


default_random_sample_params <- function(output_name = "sample_out") {
  list(input_table = NULL, method = "n", n = 100L, prop = 0.1,
       replace = FALSE, seed = NA_integer_, output_name = output_name)
}

random_sample_ui <- function(id) {
  ns <- NS(id)
  .dt_task_shell(ns, "shuffle", "Random Sample", "sample_out",
    selectInput(ns("input_table"), "Input table",
      choices = character(0), width = "100%"),
    radioButtons(ns("method"), "Sample by",
      choices  = c("Number of rows" = "n", "Proportion" = "prop"),
      selected = "n", inline = TRUE),
    bslib::layout_columns(
      col_widths = c(4, 4, 4),
      conditionalPanel(
        condition = sprintf("input['%s'] == 'n'", ns("method")),
        numericInput(ns("n"), "Rows", value = 100L, min = 1L, step = 1L, width = "100%")
      ),
      conditionalPanel(
        condition = sprintf("input['%s'] == 'prop'", ns("method")),
        numericInput(ns("prop"), "Proportion", value = 0.1,
          min = 0.001, max = 1, step = 0.01, width = "100%")
      ),
      numericInput(ns("seed"), "Seed (NA = random)", value = NA_real_,
        step = 1L, width = "100%"),
      checkboxInput(ns("replace"), "Sample with replacement", value = FALSE)
    )
  )
}

random_sample_server <- function(id, store, task_id = NULL) {
  ig_module_server(id, function(input, output, session) {
    init_p <- isolate({
      if (!is.null(task_id) && !is.null(store$tasks[[task_id]]))
        store$tasks[[task_id]]$params %||% default_random_sample_params()
      else default_random_sample_params(paste0(task_id %||% "randomsample", "_out"))
    })
    run_status_msg <- reactiveVal("")
    preview_df     <- reactiveVal(NULL)

    session$onFlushed(function() {
      updateTextInput(session,    "output_name", value = init_p$output_name)
      updateRadioButtons(session, "method",      selected = init_p$method %||% "n")
      updateNumericInput(session, "n",            value = init_p$n %||% 100L)
      updateNumericInput(session, "prop",         value = init_p$prop %||% 0.1)
      updateNumericInput(session, "seed",         value = init_p$seed %||% NA_real_)
      updateCheckboxInput(session, "replace",     value = isTRUE(init_p$replace))
    }, once = TRUE)

    observe({
      tbls <- c("",store_available_tables(store, task_id = task_id))
      cur  <- isolate(input$input_table) %||% init_p$input_table %||% ""
      updateSelectInput(session, "input_table", choices = tbls,
        selected = if (cur %in% store_available_tables(store, task_id = task_id)) cur else "")
    })

    collect_p <- reactive({
      list(
        input_table = input$input_table %||% "",
        method      = input$method %||% "n",
        n           = input$n %||% 100L,
        prop        = as.numeric(input$prop %||% 0.1),
        replace     = isTRUE(input$replace),
        seed        = if (is.na(input$seed %||% NA_real_)) NA_integer_
                      else input$seed,
        output_name = trimws(input$output_name %||% paste0(task_id, "_out"))
      )
    })

    execute_sample_from_tables <- execute_sample
    execute_sample <- function(p) {
      execute_sample_from_tables(p, isolate(store$tables))
    }

    observeEvent(input$btn_preview, {
      result <- execute_sample(collect_p())
      if (!is.null(result$error)) showNotification(result$error, type = "error", duration = 8)
      else preview_df(head(result$data, 1000L))
    })

    do_run <- function() {
      p <- collect_p()
      result <- execute_sample(p)
      .dt_save(store, task_id, "random_sample", p, p$input_table,
               result, build_sample_code(p), run_status_msg, preview_df)
    }
    observeEvent(input$btn_run, { store_run_guarded(store, do_run, task_id = task_id) })
    store_register_code_fn(store, task_id,
      function() build_sample_code(collect_p()))

    output$run_status <- renderText(run_status_msg())
    .dt_render_preview(output, preview_df, session, store)
    store_register_result_fn(store, task_id, function(result) {
      preview_df(ig_preview_data(result$data)); run_status_msg(ig_preview_status(result))
    }, session = session)
    store_register_params_fn(store, task_id, collect_p, session = session)
    if (!is.null(task_id)) session$onFlushed(function() {
      store_register_runner(store, task_id, do_run)
    }, once = TRUE)
  })
}

execute_sample <- function(p, tables) {
  tbl <- p$input_table %||% ""
  if (!nzchar(tbl)) return(list(data = NULL, error = "Select an input table."))
  df <- tables[[tbl]]
  if (is.null(df)) return(list(data = NULL, error = paste("Table not found:", tbl)))
  tryCatch(list(data = ig_sample_data(df, p), error = NULL),
    error = function(e) list(data = NULL, error = conditionMessage(e)))
}

ig_sample_data <- function(df, p) {
  if (inherits(df, "tbl_sql")) df <- dplyr::collect(df)
  method <- p$method %||% "n"
  if (!method %in% c("n", "prop")) stop("Unknown sampling method.")
  value <- if (method == "n") p$n %||% 100L else p$prop %||% 0.1
  if (length(value) != 1L || !is.finite(value) || value < 0 ||
      (method == "n" && value != floor(value)))
    stop("Sample size must be a nonnegative whole number; proportion must be nonnegative.")
  seed <- p$seed %||% NA_integer_
  if (length(seed) != 1L || (!is.na(seed) && (!is.finite(seed) || seed < 0 ||
      seed > .Machine$integer.max || seed != floor(seed))))
    stop("Random seed must be a nonnegative whole number or blank.")
  if (!is.na(seed)) {
    had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
    if (had_seed) old_seed <- get(".Random.seed", envir = globalenv())
    on.exit(if (had_seed) assign(".Random.seed", old_seed, envir = globalenv())
      else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE))
        rm(".Random.seed", envir = globalenv()), add = TRUE)
    set.seed(as.integer(seed))
  }
  result <- if (method == "n") dplyr::slice_sample(df, n = value, replace = isTRUE(p$replace))
    else dplyr::slice_sample(df, prop = value, replace = isTRUE(p$replace))
  as.data.frame(result)
}

#' Generate reproducible R code from stored task parameters.
#' @keywords internal
#' @param p Configured task parameter list.
build_sample_code <- function(p) {
  method <- p$method %||% "n"
  if (!method %in% c("n", "prop")) return('stop("Unknown sampling method.")')
  size <- if (method == "n") paste0("n = ", code_literal(p$n %||% 100L)) else paste0("prop = ", code_literal(p$prop %||% 0.1))
  helper <- "sample_rows"
  paste(c(code_helper_definitions(helper, overrides = stats::setNames(list(ig_code_sample_rows), helper)),
    paste0(r_ident(p$output_name), " <- .ig_codegen$", helper, "(", r_ident(p$input_table), ", ", size,
      if (isTRUE(p$replace)) ", replace = TRUE" else "", ", seed = ", code_literal(p$seed %||% NA_integer_), ")")), collapse = "\n")
}
