# Benchmark-only instrumentation. This file is sourced by a temporary test app;
# it adds no controls or observers to the distributable application.
performance_app <- function(autosave = FALSE, profiles = NULL, include_result = TRUE) {
  ns <- asNamespace("IndividualGuide")
  wrap <- function(original, key) {
    force(original); force(key)
    function(...) {
      domain <- shiny::getDefaultReactiveDomain()
      counters <- if (!is.null(domain)) domain$userData$performance else NULL
      if (!is.null(counters)) {
        count <- counters[[key]]
        counters[[key]] <- (if (is.null(count)) 0L else count) + 1L
      }
      original(...)
    }
  }
  for (name in c("canvas_build_network", "store_col_info", "store_col_schema",
      "store_available_control_tokens", "build_full_r_script", "project_autosave_recovery")) {
    if (exists(name, ns, inherits = FALSE))
      utils::assignInNamespace(name, wrap(get(name, ns), name), ns = ns)
  }
  server <- get("app_server", ns)
  # Measure interactions independently of periodic file I/O. The unmodified
  # large-table baseline failed to settle because JSON autosave exceeded its
  # own 30-second interval (recorded in browser-before-v2/app.log). Autosave has
  # its own runtime/regression checks, with the real observer enabled.
  expressions <- as.list(body(server))
  autosave_expressions <- vapply(expressions, function(expr) {
    text <- paste(deparse(expr), collapse = "\n")
    grepl("project_autosave_recovery", text, fixed = TRUE) && grepl("invalidateLater", text, fixed = TRUE)
  }, logical(1))
  stopifnot(sum(autosave_expressions) == 1L)
  if (!isTRUE(autosave)) body(server) <- as.call(expressions[!autosave_expressions])
  environment(server) <- new.env(parent = environment(server))
  environment(server)$performance_profiles <- profiles
  environment(server)$performance_include_result <- include_result
  hooks <- quote({
    session$userData$performance <- new.env(parent = emptyenv())
    observeEvent(input$perf_setup, {
      set.seed(310)
      store$tables <- list(raw = as.data.frame(setNames(lapply(1:12,
        function(i) sin(seq_len(200000L) / i)), paste0("c", 1:12))))
      ids <- paste0("first_", 1:100)
      tasks <- setNames(lapply(ids, function(id) {
        p <- default_first_last_params(paste0(id, "_rows")); p$input_table <- "raw"
        store_task_from_params(task_def(id, "first_last_n"), p)
      }), ids)
      p <- default_qb_params("query_rows"); p$primary_table <- "raw"
      tasks$query <- store_task_from_params(task_def("query", "query_builder"), p)
      p <- default_phase3_params("cluster_analysis", "clusters")
      p$input_table <- "heavy_input"; p$predictors <- paste0("v", 1:6)
      p$k <- 6L; p$cluster_method <- "hierarchical"; p$cluster_linkage <- "complete"
      tasks$heavy <- store_task_from_params(task_def("heavy", "cluster_analysis"), p)
      store$tables$heavy_input <- as.data.frame(setNames(lapply(1:6,
        function(i) rnorm(6000L)), paste0("v", 1:6)))
      store$tasks <- tasks; store$task_order <- names(tasks); store$dirty <- FALSE
    })
    observeEvent(input$perf_open, open_task_panel(input$perf_open, focus_tab = TRUE))
    observeEvent(input$perf_values, {
      tables <- isolate(store$tables); tables$raw$c1 <- tables$raw$c1 + 1
      store$tables <- tables
    })
    observeEvent(input$perf_schema, {
      tables <- isolate(store$tables); names(tables$raw)[1L] <- "renamed_column"
      tables$raw[[1L]] <- as.character(tables$raw[[1L]])
      store$tables <- tables
    })
    observeEvent(input$perf_run, run_task_from_store(store, "heavy"))
    observeEvent(input$perf_profile, {
      if (is.null(performance_profiles)) return()
      if (identical(input$perf_profile, "start")) {
        Rprof(file.path(performance_profiles, "server-cpu.out"), interval = 0.01)
      } else if (identical(input$perf_profile, "stop")) {
        Rprof(NULL)
        profile <- summaryRprof(file.path(performance_profiles, "server-cpu.out"))
        write.csv(profile$by.total, file.path(performance_profiles, "server-cpu.csv"))
      }
    })
    observeEvent(input$perf_ping, session$sendCustomMessage("igPerfPong", input$perf_ping))
    observeEvent(input$perf_recovery, {
      restored <- make_store()
      result <- tryCatch({
        project_load(restored, project_recovery_path())
        list(n = isolate(restored$tasks$first_1$params$n),
          dimensions = dim(isolate(restored$tables$raw)),
          data_identical = identical(isolate(restored$tables$raw), isolate(store$tables$raw)), error = NULL)
      }, error = function(error) list(error = conditionMessage(error)))
      project_release_assets(restored)
      session$sendCustomMessage("igPerfRecovery", c(list(nonce = input$perf_recovery), result))
    })
    observeEvent(input$perf_report, {
      nonce <- input$perf_report
      session$onFlushed(function() {
        session$sendCustomMessage("igPerfReport", list(nonce = nonce,
          counters = as.list(session$userData$performance),
          tables = names(isolate(store$tables)), tasks = names(isolate(store$tasks)),
          heavy = isolate(store$tasks$heavy$status),
          heavy_run_time = as.numeric(isolate(store$tasks$heavy$run_time)),
          heavy_rows = nrow(isolate(store$tables$clusters)),
          worker_pid = tryCatch(isolate(store$background)$worker$get_pid(), error = function(error) NULL),
          first_params = isolate(store$tasks$first_1$params),
          console_draft_on_server = !is.null(isolate(input[["r_console-editor"]])),
          result = if (performance_include_result) isolate(store$tables$clusters) else NULL))
      }, once = TRUE)
    })
  })
  body(server) <- as.call(c(as.list(body(server)), list(hooks)))
  shiny::addResourcePath("www", get("app_sys", ns)("app", "www"))
  shiny::shinyApp(ui = get("app_ui", ns)(), server = server)
}
