test_that("UI projections skip unchanged values and refresh within the same event", {
  shiny::testServer(function(input, output, session) {
    source <- shiny::reactiveVal(list(name = "table", setting = 1L))
    visible <- ig_reactive_distinct(function() source()$name)
    counts <- new.env(); counts$renders <- 0L
    shiny::observe({ visible(); counts$renders <- counts$renders + 1L })
  }, {
    session$flushReact()
    expect_equal(counts$renders, 1L)
    source(list(name = "table", setting = 2L))
    session$flushReact()
    expect_equal(counts$renders, 1L)
    source(list(name = "renamed", setting = 3L))
    expect_identical(shiny::isolate(visible()), "renamed")
    session$flushReact()
    expect_equal(counts$renders, 2L)
  })
})

test_that("editing task settings does not refresh workspace or input choices", {
  shiny::testServer(function(input, output, session) {
    store <- new_test_store(list(raw = data.frame(x = 1:10)))
    p <- default_first_last_params("rows"); p$input_table <- "raw"
    add_test_task(store, "head", "first_last_n", inputs = "raw", params = p, output = "rows")
    store_init_ui_reactivity(store)
    counts <- new.env()
    counts$workspace_updates <- counts$choice_updates <- counts$flow_updates <- counts$comment_updates <- 0L
    shiny::observe({ store_ui_read(store, "tasks", store$tasks); counts$workspace_updates <- counts$workspace_updates + 1L })
    shiny::observe({ store_available_tables(store); counts$choice_updates <- counts$choice_updates + 1L })
    shiny::observe({ store_ui_read(store, "flows", store$flows); counts$flow_updates <- counts$flow_updates + 1L })
    shiny::observe({ store_ui_read(store, "comments", store$collaboration$comments); counts$comment_updates <- counts$comment_updates + 1L })
  }, {
    session$flushReact()
    for (n in 1:4) {
      p <- shiny::isolate(store$tasks$head$params); p$n <- n
      shiny::isolate(store_sync_parameters(store, "head", p))
      session$flushReact()
    }
    expect_equal(shiny::isolate(store$tasks$head$params$n), 4L)
    expect_equal(counts$workspace_updates, 1L)
    expect_equal(counts$choice_updates, 1L)
    expect_equal(counts$flow_updates, 1L)
    expect_equal(counts$comment_updates, 1L)
    p$output_name <- "renamed"
    shiny::isolate(store_sync_parameters(store, "head", p))
    # A consumer in the same event must see fresh declarations, before flushing.
    expect_contains(shiny::isolate(store_available_tables(store)), "renamed")
    expect_false("rows" %in% shiny::isolate(store_available_tables(store)))
    session$flushReact()
    expect_equal(counts$workspace_updates, 2L)
    expect_equal(counts$choice_updates, 2L)
    task <- shiny::isolate(store$tasks$head)
    task$run_time <- Sys.time(); shiny::isolate(store_set_task(store, task))
    session$flushReact()
    expect_equal(counts$workspace_updates, 3L)
    expect_equal(counts$choice_updates, 2L)
  })
})

test_that("cached choices retain branch dependencies and survive project replacement", {
  shiny::testServer(function(input, output, session) {
    store <- new_test_store(list(raw = data.frame(x = 1:3)))
    store_init_ui_reactivity(store)
  }, {
    p <- default_branch_params("route")
    p$paths[[1]]$condition$rules <- list(list(kind = "task_status", task_id = "producer", status = "success"))
    add_test_task(store, "producer", "first_last_n", inputs = "raw", output = "rows")
    shiny::isolate(store_set_task(store, store_task_from_params(task_def("route", "branch"), p)))
    expect_false("route_true" %in% shiny::isolate(store_available_control_tokens(store, "producer")))
    expect_contains(shiny::isolate(store_available_control_tokens(store)), "route_true")
    path <- tempfile(fileext = ".igpx")
    replacement <- new_test_store(list(other = data.frame(y = 1)))
    project_save(replacement, path); project_load(store, path)
    expect_identical(shiny::isolate(store_available_tables(store)), "other")
    expect_length(shiny::isolate(store_available_control_tokens(store)), 0L)
  })
})

test_that("task parameter readers do not rerun for unrelated task edits", {
  shiny::testServer(function(input, output, session) {
    store <- new_test_store(list(raw = data.frame(x = 1:3)))
    for (id in c("a", "b")) add_test_task(store, id, "first_last_n", inputs = "raw",
      output = paste0(id, "_out"), params = list(input_table = "raw", output_name = paste0(id, "_out"), n = 1L))
    counts <- new.env(); counts$reads <- 0L
    store_register_params_fn(store, "a", function() {
      counts$reads <- counts$reads + 1L
      list(input_table = "raw", output_name = "a_out", n = input$n %||% 1L)
    }, session)
  }, {
    session$setInputs(n = 1L, ig_ready = module_ready_value(store, "a"))
    session$flushReact()
    before <- counts$reads
    p <- shiny::isolate(store$tasks$b$params); p$n <- 2L
    shiny::isolate(store_sync_parameters(store, "b", p)); session$flushReact()
    expect_equal(counts$reads, before)
    session$setInputs(n = 3L); session$flushReact()
    expect_equal(shiny::isolate(store$tasks$a$params$n), 3L)
    expect_gt(counts$reads, before)
  })
})

test_that("branch value edits leave UI stable but changed task references update choices", {
  shiny::testServer(function(input, output, session) {
    store <- new_test_store(list(raw = data.frame(x = 1:3)))
    for (id in c("a", "b")) add_test_task(store, id, "first_last_n", inputs = "raw", output = paste0(id, "_rows"))
    p <- default_branch_params("route")
    p$paths[[1]]$condition$rules <- list(list(kind = "task_status", task_id = "a", status = "success"))
    shiny::isolate(store_set_task(store, store_task_from_params(task_def("route", "branch"), p)))
    store_init_ui_reactivity(store)
    counts <- new.env(); counts$choices <- 0L
    shiny::observe({ store_available_control_tokens(store, "a"); counts$choices <- counts$choices + 1L })
  }, {
    session$flushReact()
    p <- shiny::isolate(store$tasks$route$params)
    p$paths[[1]]$condition$rules[[1]]$status <- "pending"
    shiny::isolate(store_sync_parameters(store, "route", p)); session$flushReact()
    expect_equal(counts$choices, 1L)
    expect_false("route_true" %in% shiny::isolate(store_available_control_tokens(store, "a")))
    p$paths[[1]]$condition$rules[[1]]$task_id <- "b"
    shiny::isolate(store_sync_parameters(store, "route", p))
    expect_contains(shiny::isolate(store_available_control_tokens(store, "a")), "route_true")
    expect_false("route_true" %in% shiny::isolate(store_available_control_tokens(store, "b")))
    session$flushReact()
    expect_equal(counts$choices, 2L)
  })
})
