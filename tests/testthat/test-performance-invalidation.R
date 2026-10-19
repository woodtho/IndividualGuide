test_that("invalidation visits branching and status dependencies in stable waves", {
  store <- new_test_store()
  tasks <- list(
    a = task_def("a", "script", inputs = "raw", output = "a_out"),
    b = task_def("b", "script", inputs = "a_out", output = "b_out"),
    c = task_def("c", "export_log", params = list(after_tasks = "a")),
    d = task_def("d", "script", inputs = "b_out", output = "d_out"),
    unrelated = task_def("unrelated", "script", inputs = "other", output = "u_out")
  )
  for (id in names(tasks)) {
    tasks[[id]]$status <- "success"
    tasks[[id]]$run_time <- as.POSIXct("2026-01-01", tz = "UTC")
  }
  store$tasks <- tasks; store$task_order <- names(tasks)
  store$tables <- list(raw = data.frame(x = 1), a_out = data.frame(x = 1),
    b_out = data.frame(x = 1), d_out = data.frame(x = 1), u_out = data.frame(x = 2))
  expect_identical(shiny::isolate(store_invalidate_outputs(store, "raw")), c("a", "b", "c", "d"))
  expect_identical(shiny::isolate(names(store$tables)), c("raw", "u_out"))
  expect_identical(shiny::isolate(store$tasks$unrelated$status), "success")
  expect_true(shiny::isolate(store$tasks$c$invalidated))
})

test_that("cached validation still rejects direct graph mutations and duplicate outputs", {
  store <- new_test_store()
  shiny::isolate({
    store_set_task(store, task_def("a", "script", output = "a_out"))
    store_set_task(store, task_def("b", "script", inputs = "a_out", output = "b_out"))
    before <- store$performance_cache$validated_graph
    task <- store$tasks$b; task$note <- "Only presentation changed"
    store_set_task(store, task)
    expect_identical(store$performance_cache$validated_graph, before)
    # Simulate a direct mutation from a restored/edited project. Its structure
    # must be checked even when the next store_set_task changes only a label.
    tasks <- store$tasks; tasks$a$inputs <- "b_out"; store$tasks <- tasks
    expect_warning(expect_false(store_set_task(store, task)), "Circular task reference")
    tasks$a$inputs <- character(0); store$tasks <- tasks
    task$output <- "a_out"; task$outputs <- list(list(name = "a_out", kind = "table"))
    expect_warning(expect_false(store_set_task(store, task)), "one producer")
  })
})

test_that("column metadata readers invalidate on schema changes and remain bounded per store", {
  store <- new_test_store(); other <- new_test_store()
  shiny::isolate({
    store$tables <- list(raw = data.frame(x = c(1, 1, NA), f = factor(c("a", "b", "a"))))
    info <- store_col_info(store, "raw")
    schema <- store_col_schema(store, "raw")
    expect_identical(schema[c("column", "class")], info[c("column", "class")])
    expect_true(all(is.na(schema$n_distinct)))
    expect_identical(info$n_distinct, c(2L, 2L))
    store$tables <- list(raw = data.frame(renamed = as.Date("2026-01-01")))
    expect_identical(store_col_schema(store, "raw")$column, "renamed")
    expect_identical(store_col_schema(store, "raw")$class, "Date")
    other$tables <- list(raw = data.frame(private = "other session"))
    expect_identical(store_col_schema(other, "raw")$column, "private")
    expect_identical(store_col_schema(store, "raw")$column, "renamed")
    for (i in 1:80) store_col_schema(store, paste0("absent_", i))
    expect_lte(length(store$performance_cache$schemas), 32L)
    store$tables <- list()
    store$sources <- list(raw = list(schema = data.frame(column = "saved", class = "integer")))
    expect_identical(store_col_schema(store, "raw")$column, "saved")
    store$sources <- list()
    expect_identical(store_col_schema(store, "raw"), data.frame())
    expect_false(identical(store$performance_cache, other$performance_cache))
  })
})

test_that("lazy column selectors preserve fresh reads of external database metadata", {
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "first", data.frame(x = 1:3))
  DBI::dbWriteTable(con, "second", data.frame(y = letters[1:3]))
  store <- new_test_store()
  shiny::isolate({
    store$tables <- list(raw = dplyr::tbl(con, "first"))
    expect_identical(store_col_schema(store, "raw")$column, "x")
    expect_null(store$performance_cache$schemas$raw)
    DBI::dbWriteTable(con, "first", data.frame(x = letters[1:3]), overwrite = TRUE)
    expect_identical(store_col_schema(store, "raw")$class, "character")
    DBI::dbExecute(con, "ALTER TABLE first ADD COLUMN added INTEGER")
    expect_identical(store_col_schema(store, "raw"), store_col_info(store, "raw"))
    store$tables <- list(raw = dplyr::tbl(con, "second"))
    expect_identical(store_col_schema(store, "raw")$column, "y")
  })
})

test_that("canvas card caches bound retained names and are session private", {
  first <- ig_card_cache(); second <- ig_card_cache()
  for (i in 1:4500) ig_card_cache_put(first, paste0("card_", i), "image")
  expect_lte(length(first$values), 4096L)
  expect_lte(length(first$slots), 4096L)
  expect_null(first$values$card_1)
  expect_identical(first$values$card_4500, "image")
  expect_length(second$values, 0L)
  args <- list(name = "Private <name>", type_label = "Script", icon_name = "code",
    bg = "#123456", border = "#654321", status_text = "Not run", status_color = "#abcdef")
  expected <- do.call(ig_card_image, args)
  expect_identical(do.call(ig_card_image, c(args, list(cache = first))), expected)
  expect_identical(do.call(ig_card_image, c(args, list(cache = second))), expected)
  expect_length(second$values, 1L)
  expect_false(any(grepl("Private", ls(.ig_icon_cache, all.names = TRUE))))
  left <- args; left$name <- "a|b"; left$type_label <- "c"
  right <- args; right$name <- "a"; right$type_label <- "b|c"
  expect_false(identical(do.call(ig_card_image, c(left, list(cache = second))),
    do.call(ig_card_image, c(right, list(cache = second)))))
})

test_that("large project payloads round trip exactly without JSON expansion", {
  path <- tempfile(fileext = ".json")
  on.exit(unlink(c(path, paste0(path, ".rds"))))
  original <- data.frame(id = 1:100000, value = sin(1:100000),
    category = rep(c("a", "b"), 50000))
  project_write_payload(path, "large", original)
  expect_identical(project_read_json(path)$encoding, "r-native-rds")
  expect_identical(project_read_payload(path)$value, original)
})

test_that("schema cache cycles do not retain a discarded store", {
  released <- new.env(parent = emptyenv()); released$done <- FALSE
  notify <- function(flag) {
    force(flag)
    function(environment) flag$done <- TRUE
  }
  local({
    store <- new_test_store(list(raw = data.frame(x = 1:10)))
    shiny::isolate(store_col_schema(store, "raw"))
    reg.finalizer(shiny::isolate(store$performance_cache), notify(released))
  })
  gc(); gc()
  expect_true(released$done)
})

test_that("autosave skips unchanged projects and ignores its own flow snapshot", {
  withr::local_options(ig.recovery_dir = tempfile("autosave-test-"))
  writes <- 0L
  original <- project_autosave_recovery
  testthat::local_mocked_bindings(project_autosave_recovery = function(...) {
    writes <<- writes + 1L
    original(...)
  }, .package = "IndividualGuide")
  shiny::testServer(app_server, {
    session$flushReact()
    store$tables <- list(raw = data.frame(x = 1:3)); store$dirty <- TRUE
    session$flushReact()
    expect_equal(writes, 0L)
    session$elapse(31000)
    expect_equal(writes, 1L)
    session$elapse(61000)
    expect_equal(writes, 1L)
    store$tables <- list(raw = data.frame(x = 4:6))
    session$flushReact()
    expect_equal(writes, 1L)
    session$elapse(31000)
    expect_equal(writes, 2L)
    flows <- shiny::isolate(store$flows); id <- shiny::isolate(store$active_flow)
    flows[[id]]$canvas_positions <- list(raw = list(x = 100, y = 200)); store$flows <- flows
    session$flushReact(); session$elapse(31000)
    expect_equal(writes, 3L)
    session$elapse(31000)
    expect_equal(writes, 3L)
    store$dirty <- FALSE
    store$tables <- list(raw = data.frame(x = 7:9))
    session$flushReact(); session$elapse(31000)
    expect_equal(writes, 3L)
  })
})

test_that("failed recovery writes are reported and retried on the next timer", {
  withr::local_options(ig.recovery_dir = tempfile("autosave-retry-"))
  attempts <- 0L
  original <- project_autosave_recovery
  testthat::local_mocked_bindings(project_autosave_recovery = function(...) {
    attempts <<- attempts + 1L
    if (attempts == 1L) return(NULL)
    original(...)
  }, .package = "IndividualGuide")
  shiny::testServer(app_server, {
    session$flushReact(); store$dirty <- TRUE
    session$elapse(31000)
    expect_equal(attempts, 1L)
    session$elapse(31000)
    expect_equal(attempts, 2L)
    session$elapse(31000)
    expect_equal(attempts, 2L)
  })
})
