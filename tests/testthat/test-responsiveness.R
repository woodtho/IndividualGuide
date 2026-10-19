test_that("table value edits leave workspace chrome alone and dimensions stay fresh", {
  shiny::testServer(function(input, output, session) {
    store <- new_test_store(list(raw = data.frame(x = 1:4)))
    store_init_ui_reactivity(store)
    counts <- new.env(); counts$names <- counts$graph <- 0L
    shiny::observe({ store_ui_read(store, "table_names", names(store$tables)); counts$names <- counts$names + 1L })
    shiny::observe({ store_ui_read(store, "canvas_tables", store$tables); counts$graph <- counts$graph + 1L })
  }, {
    session$flushReact()
    store$tables <- list(raw = data.frame(x = 5:8))
    session$flushReact()
    expect_equal(counts$names, 1L)
    expect_equal(counts$graph, 1L)
    # Changing a column name/type must still reach column readers, without
    # rebuilding graph cards whose visible content has not changed.
    store$tables <- list(raw = data.frame(renamed = letters[1:4]))
    expect_identical(shiny::isolate(store_col_schema(store, "raw")$column), "renamed")
    session$flushReact()
    expect_equal(counts$graph, 1L)
    store$tables <- list(raw = data.frame(renamed = letters[1:5]))
    expect_identical(shiny::isolate(store_ui_read(store, "canvas_tables", store$tables))$raw$dimensions, c(5L, 1L))
    session$flushReact()
    expect_equal(counts$names, 1L)
    expect_equal(counts$graph, 2L)
    store$tables <- list(other = data.frame(x = 1:5))
    session$flushReact()
    expect_equal(counts$names, 2L)
    expect_equal(counts$graph, 3L)
    store$tables <- list()
    session$flushReact()
    expect_equal(counts$names, 3L)
    expect_equal(counts$graph, 4L)
  })
})

test_that("canvas metadata never collects a lazy database table", {
  skip_if_not_installed("RSQLite")
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "raw", data.frame(x = 1:4))
  shiny::testServer(function(input, output, session) {
    store <- new_test_store()
    store_init_ui_reactivity(store)
  }, {
    store$tables <- list(raw = dplyr::tbl(con, "raw"))
    expect_identical(shiny::isolate(store_ui_read(store, "canvas_tables", store$tables)), list(raw = list(lazy = TRUE)))
    before <- shiny::isolate(canvas_build_network(store))
    expect_true(any(grepl("Lazy database table", before$nodes$title)))
    store$tables <- list(raw = data.frame(x = 1:4))
    expect_identical(shiny::isolate(store_ui_read(store, "canvas_tables", store$tables)), list(raw = list(dimensions = c(4L, 1L))))
    expect_true(any(grepl("4 rows", shiny::isolate(canvas_build_network(store))$nodes$title)))
  })
})

test_that("invalidation clears mounted previews in dependency order without touching unrelated ones", {
  store <- new_test_store(list(raw = data.frame(x = 1)))
  shiny::isolate({
    add_test_task(store, "a", "first_last_n", inputs = "raw", output = "a_out")
    add_test_task(store, "b", "first_last_n", inputs = "a_out", output = "b_out")
    add_test_task(store, "unrelated", "first_last_n", inputs = "elsewhere", output = "u_out")
    store$tables <- c(store$tables, list(a_out = data.frame(x = 1), b_out = data.frame(x = 1)))
    calls <- list()
    callback <- function(id) { force(id); function(result) calls[[length(calls) + 1L]] <<- list(id = id, value = result) }
    store$result_fns <- list(a = callback("a"), b = callback("b"), unrelated = callback("unrelated"))
    expect_identical(store_invalidate_outputs(store, "raw"), c("a", "b"))
    expect_identical(vapply(calls, `[[`, character(1), "id"), c("a", "b"))
    expect_true(all(vapply(calls, function(x) is.null(x$value), logical(1))))
    expect_identical(names(store$tables), "raw")
    expect_identical(store$tasks$a$status, "pending")
    expect_identical(store$tasks$b$status, "pending")
  })
})

test_that("new chrome metadata stays session private and out of project archives", {
  first <- new_test_store(list(private = data.frame(x = 1:3)))
  second <- new_test_store(list(other = data.frame(x = 1:2)))
  shiny::testServer(function(input, output, session) {
    store_init_ui_reactivity(first); store_init_ui_reactivity(second)
  }, {
    expect_identical(shiny::isolate(store_ui_read(first, "table_names", NULL)), "private")
    expect_identical(shiny::isolate(store_ui_read(second, "table_names", NULL)), "other")
    first$objects <- list(model = list(value = 1))
    expect_identical(shiny::isolate(store_ui_read(first, "object_names", NULL)), "model")
    path <- tempfile(fileext = ".igpx"); on.exit(unlink(path))
    project_save(first, path)
    restored <- new_test_store(); project_load(restored, path)
    expect_null(shiny::isolate(restored$ui_readers))
    expect_identical(shiny::isolate(restored$tables$private), data.frame(x = 1:3))
  })
})

test_that("collapsed logging previews do no scenario work and reopen with current data", {
  store <- new_test_store(list(raw = data.frame(x = 1:4)))
  task <- task_def("one", "first_last_n", inputs = "raw", output = "rows")
  task$logging$rules <- list(list(id = "done", enabled = TRUE, event = "success", level = "INFO", template = "Input {rows_in}"))
  shiny::isolate(store_set_task(store, task))
  calls <- 0L; original <- ig_log_preview_scenario
  testthat::local_mocked_bindings(ig_log_preview_scenario = function(...) {
    calls <<- calls + 1L; original(...)
  }, .package = "IndividualGuide")
  shiny::testServer(task_logging_server, args = list(store = store, task_id = "one"), {
    session$setInputs(enabled = TRUE, console = TRUE, min_level = "INFO", preview_event = "success",
      done_event = "success", done_level = "INFO", done_template = "Input {rows_in}", done_enabled = TRUE)
    expect_equal(calls, 0L)
    session$setInputs(preview_visible = TRUE)
    expect_match(output$preview, "Input 4", fixed = TRUE)
    expect_gt(calls, 0L)
    session$setInputs(preview_visible = FALSE)
    before <- calls
    store$tables <- list(raw = data.frame(x = 1:9))
    session$flushReact()
    expect_equal(calls, before)
    session$setInputs(preview_visible = TRUE)
    expect_match(output$preview, "Input 9", fixed = TRUE)
    expect_gt(calls, before)
  })
})

test_that("fast recovery archives preserve data, models and project identity exactly", {
  withr::local_options(ig.recovery_dir = tempfile("fast-recovery-"))
  store <- new_test_store(list(raw = data.frame(x = seq_len(100000), y = sin(seq_len(100000)))))
  shiny::isolate({
    store_add_object(store, "fit", lm(stats::as.formula("y ~ x", env = baseenv()), store$tables$raw))
    store$project_name <- "Unsaved edits"; store$project_path <- "original.igpx"; store$dirty <- TRUE
    path <- project_autosave_recovery(store)
    expect_true(file.exists(path))
    expect_identical(store$project_path, "original.igpx")
    expect_identical(store$project_name, "Unsaved edits")
    expect_true(store$dirty)
    restored <- new_test_store(); project_load(restored, path)
    expect_identical(restored$tables$raw, store$tables$raw)
    expect_equal(stats::predict(restored$objects$fit$value), stats::predict(store$objects$fit$value))
  })
})

test_that("saving the active flow snapshot does not replace tree metadata", {
  shiny::testServer(function(input, output, session) {
    store <- new_test_store(list(raw = data.frame(x = 1:3)))
    add_test_task(store, "one", "first_last_n", inputs = "raw", output = "rows")
    other <- make_flow("Other")
    flows <- shiny::isolate(store$flows); flows[[other$id]] <- other; store$flows <- flows
    store_init_ui_reactivity(store)
    counts <- new.env(); counts$updates <- 0L
    shiny::observe({ store_ui_read(store, "flows", store$flows); counts$updates <- counts$updates + 1L })
  }, {
    session$flushReact(); before <- counts$updates
    shiny::isolate(store_snapshot_flow(store)); session$flushReact()
    expect_equal(counts$updates, before)
    flows <- shiny::isolate(store$flows)
    flows[[other$id]]$tasks <- list(other_task = task_def("other_task", "script", output = "other_rows"))
    store$flows <- flows; session$flushReact()
    expect_equal(counts$updates, before + 1L)
    flows <- shiny::isolate(store$flows); flows[[other$id]]$name <- "Renamed"
    store$flows <- flows; session$flushReact()
    expect_equal(counts$updates, before + 2L)
  })
})

test_that("recovery without a graph rebuild retains layout and current task definitions", {
  withr::local_options(ig.recovery_dir = tempfile("recovery-layout-"))
  store <- new_test_store(list(raw = data.frame(x = 1:3)))
  shiny::isolate({
    add_test_task(store, "one", "first_last_n", inputs = "raw", output = "old_rows",
      params = list(input_table = "raw", n = 2L))
    positions <- list(one = list(x = 125, y = -35), raw = list(x = -100, y = 20))
    store_set_canvas_positions(store, positions)
    store_set_canvas_layout(store, "free")
    legacy <- list(nodes = data.frame(id = "legacy_node"), edges = data.frame())
    store_snapshot_flow(store, legacy)
    task <- store$tasks$one
    p <- task$params; p$output_name <- "new_rows"
    store_set_task(store, store_task_from_params(task, p))
    path <- project_autosave_recovery(store, canvas_state = NULL)
    restored <- new_test_store(); project_load(restored, path)
    expect_identical(store_canvas_positions(restored), positions)
    expect_identical(store_canvas_layout(restored), "free")
    expect_identical(restored$flows[[restored$active_flow]]$canvas_nodes, legacy$nodes)
    graph <- canvas_build_network(restored)
    expect_contains(graph$nodes$id, "new_rows")
    expect_false(any(c("old_rows", "legacy_node") %in% graph$nodes$id))
  })
})
