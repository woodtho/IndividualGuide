# Comments, review state, history, and global search.

iso <- shiny::isolate

test_that("comments open when any target category is empty", {
  old <- options(ig.recovery_dir = tempfile(), ig.catalogue_dir = tempfile())
  on.exit(options(old), add = TRUE)
  shiny::testServer(app_server, {
    expect_length(comment_target_choices(), 1L)
    store$tables <- list(raw = data.frame(x = 1))
    expect_length(comment_target_choices(), 2L)
    expect_error(show_comments_modal(), NA)
    session$setInputs(comment_target = "project:project", comment_title = "Review", comment_body = "Check source", comment_add = 1)
    session$flushReact()
    expect_length(shiny::isolate(store$collaboration$comments), 1L)
    session$setInputs(history_query = "[", history_user = "(")
    session$flushReact()
    expect_error(output$history_dt, NA)
  })
})

test_that("comment threads attach to nodes and can be searched", {
  store <- new_test_store(list(sales = sample_sales()))
  add_test_task(store, "fs_1", "filter_sort", inputs = "sales",
    params = list(input_table = "sales", output_name = "fs_out"),
    output = "fs_out")

  thread <- store_add_comment_thread(store, "node", "fs_1",
    "Check filter", "Please confirm the amount filter.")
  expect_equal(store_comment_count_for(store, "node", "fs_1"), 1L)

  reply <- store_add_comment_reply(store, thread$id, "Confirmed.")
  expect_equal(reply$text, "Confirmed.")

  hits <- store_search(store, "amount filter")
  expect_true(any(hits$type == "comment" & hits$id == thread$id))

  store_set_comment_status(store, thread$id, "resolved")
  expect_equal(store_comment_count_for(store, "node", "fs_1"), 0L)
  expect_equal(store_comment_count_for(store, "node", "fs_1",
    include_resolved = TRUE), 1L)
})

test_that("review decisions and unresolved issue tracking are stored", {
  store <- new_test_store()

  item <- store_add_review_item(store, "project", "project",
    "Need source note", "Document where the source file came from.")
  expect_equal(iso(store$collaboration)$review$status, "changes_requested")
  expect_equal(length(store_unresolved_review_items(store)), 1L)

  store_set_review_item_status(store, item$id, "resolved")
  expect_equal(length(store_unresolved_review_items(store)), 0L)

  event <- store_set_review_decision(store, "approve", detail = "Ready.")
  expect_equal(event$action, "approve")
  expect_equal(iso(store$collaboration)$review$status, "approved")
  expect_length(iso(store$collaboration)$review$approvals, 1L)
})

test_that("canvas nodes show comment indicators and tooltip counts", {
  store <- new_test_store(list(sales = sample_sales()))
  add_test_task(store, "fs_1", "filter_sort", inputs = "sales",
    params = list(input_table = "sales", output_name = "fs_out"),
    output = "fs_out")
  store_add_comment_thread(store, "node", "fs_1", "Review", "Looks odd.")

  nd <- iso(canvas_build_network(store))
  node <- nd$nodes[nd$nodes$id == "fs_1", ]
  expect_match(node$title, "Comments:")

  svg <- rawToChar(jsonlite::base64_dec(sub("^.*base64,", "", node$image)))
  expect_match(svg, ">1</text>", fixed = TRUE)
})

test_that("collaboration data persists through .igpx round trips", {
  store <- new_test_store(list(sales = sample_sales()))
  add_test_task(store, "fs_1", "filter_sort", inputs = "sales",
    params = list(input_table = "sales", output_name = "fs_out"),
    output = "fs_out")
  thread <- store_add_comment_thread(store, "node", "fs_1",
    "Question", "Why is this filtered?")
  item <- store_add_review_item(store, "node", "fs_1",
    "Needs change", "Tighten the condition.")
  store_set_review_decision(store, "request_changes", detail = "See issue.")

  path <- tempfile(fileext = ".igpx")
  project_save(store, path)

  store2 <- make_store()
  project_load(store2, path)
  collab <- iso(store2$collaboration)
  expect_true(thread$id %in% names(collab$comments))
  expect_true(item$id %in% names(collab$review$items))
  expect_equal(collab$comments[[thread$id]]$target_id, "fs_1")
  expect_equal(collab$review$status, "changes_requested")
})

test_that("comment targets round-trip arbitrary names and include declared outputs", {
  target <- ig_comment_target_value("table", "sales:2026 / Québec")
  parsed <- ig_parse_comment_target(target)
  expect_equal(parsed$scope, "table")
  expect_equal(parsed$id, "sales:2026 / Québec")

  store <- new_test_store()
  task <- task_def("fs_1", "filter_sort", output = "future:table")
  task$outputs <- list(
    list(name = "future:table", kind = "table", label = "Table"),
    list(name = "future:model", kind = "model", label = "Model")
  )
  iso(store_set_task(store, task))

  targets <- iso(store_comment_target_catalog(store))
  expect_true("future:table" %in% targets$tables)
  expect_true("future:model" %in% targets$outputs)
})

test_that("registered task runners are blocked in read-only review mode", {
  store <- new_test_store()
  called <- 0L
  add_test_task(store, "task_1", "script")
  store_register_runner(store, "task_1", function() {
    called <<- called + 1L
    task <- iso(store$tasks$task_1)
    task$run_time <- Sys.time()
    iso(store_set_task(store, task))
    TRUE
  })
  store$review_mode <- TRUE

  result <- suppressWarnings(iso(store$task_runners[["task_1"]])())
  expect_false(isTRUE(result))
  expect_equal(called, 0L)

  store$review_mode <- FALSE
  iso(store$task_runners[["task_1"]])()
  expect_equal(called, 1L)
})
