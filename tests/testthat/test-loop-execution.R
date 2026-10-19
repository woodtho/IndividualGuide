test_that("parameter loops execute chained body tasks once per value and keep named results", {
  store <- new_test_store(list(raw = data.frame(x = 1:3)))
  p <- default_loop_params("repeat")
  p$values <- "2\n3"
  loop <- task_def("repeat", "loop", output = "", params = p)
  loop$outputs <- loop_output_specs(p)
  shiny::isolate(store_set_task(store, loop))
  script <- task_def("calculate", "script", inputs = "raw", output = "scaled",
    params = list(input_tables = "raw", output_name = "scaled",
      code = "scaled <- transform(raw, x = x * as.numeric(item))",
      output_defs = list(list(name = "scaled", kind = "table"))))
  script$control_inputs <- p$output_token
  shiny::isolate(store_set_task(store, script))
  add_test_task(store, "take", "first_last_n", inputs = "scaled", output = "small",
    params = list(input_table = "scaled", n = 1, output_name = "small"))
  expect_true(shiny::isolate(run_task_from_store(store, "repeat")))
  tables <- shiny::isolate(store$tables)
  expect_equal(tables$calculate_2$x, c(2, 4, 6))
  expect_equal(tables$calculate_3$x, c(3, 6, 9))
  expect_equal(tables$take_2$x, 2)
  expect_equal(tables$take_3$x, 3)
  expect_equal(tables$raw$x, 1:3)
  expect_equal(shiny::isolate(store$tasks$calculate$params$code), script$params$code)
  expect_equal(shiny::isolate(store$tasks[["repeat"]]$loop_completed_iterations), 2)
})

test_that("group loops bind actual group values and restore the full source", {
  p <- default_loop_params("groups")
  p$iteration_type <- "groups"
  p$source <- "sales"
  p$group_col <- "region"
  result <- execute_loop(p, list(sales = sample_sales()))
  expect_null(result$error)
  expect_length(result$records, 3)
  expect_equal(result$records[[1]]$value, "East")
  expect_equal(nrow(result$records[[1]]$data), 2)
})

test_that("loop iteration sources validate dates files variables and database rows", {
  p <- default_loop_params()
  p$variable <- "not a variable"
  expect_match(execute_loop(p)$error, "variable", ignore.case = TRUE)
  p$variable <- "item"
  p$iteration_type <- "files"
  p$values <- file.path(tempdir(), "missing-file-*.csv")
  expect_match(execute_loop(p)$error, "files|match", ignore.case = TRUE)
  p$iteration_type <- "date_ranges"
  p$values <- "2026-02-30/2026-01-01"
  expect_match(execute_loop(p)$error, "date|range", ignore.case = TRUE)
  p$values <- "2026-01-01/2026-01-03"
  result <- execute_loop(p)
  expect_equal(result$records[[1]]$value$end, as.Date("2026-01-03"))
  p$iteration_type <- "database_query"
  p$source <- "query_rows"
  p$group_col <- "id"
  result <- execute_loop(p, list(query_rows = data.frame(id = c(2, 4))))
  expect_null(result$error)
  expect_equal(vapply(result$records, function(x) x$value, numeric(1)), c(2, 4))
})

test_that("loop reruns do not multiply dataset iterations or overwrite distinct outputs", {
  store <- new_test_store(list(a = data.frame(x = 1), b = data.frame(x = 2)))
  p <- default_loop_params("each")
  p$iteration_type <- "datasets"
  p$source <- "a"
  loop <- task_def("each", "loop", output = "", params = p)
  loop$outputs <- loop_output_specs(p)
  shiny::isolate(store_set_task(store, loop))
  task <- task_def("copy", "script", inputs = "a", output = "copy_data",
    params = list(input_tables = "a", output_name = "copy_data", code = "copy_data <- a; count <- nrow(a)",
      output_defs = list(list(name = "copy_data", kind = "table"), list(name = "count", kind = "object"))))
  task$outputs <- list(list(name = "copy_data", kind = "table"), list(name = "count", kind = "object"))
  task$control_inputs <- p$output_token
  shiny::isolate(store_set_task(store, task))
  for (attempt in 1:2) {
    expect_true(shiny::isolate(run_task_from_store(store, "each")))
    expect_equal(shiny::isolate(store$tasks$each$loop_completed_iterations), 2)
    expect_equal(shiny::isolate(store$tables$copy_a$x), 1)
    expect_equal(shiny::isolate(store$tables$copy_b$x), 2)
    expect_true("copy_b_count" %in% names(shiny::isolate(store$objects)))
  }
  path <- tempfile(fileext = ".igpx")
  project_save(store, path)
  loaded <- make_store()
  project_load(loaded, path)
  expect_identical(shiny::isolate(loaded$tables$copy_b), shiny::isolate(store$tables$copy_b))
})

test_that("nested loops preserve distinct results for every outer and inner value", {
  store <- new_test_store()
  outer_p <- default_loop_params("outer")
  outer_p$variable <- "outer_value"
  outer_p$values <- "a\nb"
  outer <- task_def("outer", "loop", output = "", params = outer_p)
  outer$outputs <- loop_output_specs(outer_p)
  shiny::isolate(store_set_task(store, outer))
  inner_p <- default_loop_params("inner")
  inner_p$values <- "1\n2"
  inner <- task_def("inner", "loop", inputs = outer_p$output_token, output = "", params = inner_p)
  inner$outputs <- loop_output_specs(inner_p)
  inner$control_inputs <- outer_p$output_token
  shiny::isolate(store_set_task(store, inner))
  task <- task_def("body", "script", inputs = inner_p$output_token, output = "result",
    params = list(code = "result <- data.frame(outer = outer_value, inner = item)", output_name = "result",
      output_defs = list(list(name = "result", kind = "table"))))
  task$control_inputs <- inner_p$output_token
  shiny::isolate(store_set_task(store, task))
  ok <- shiny::isolate(run_task_from_store(store, "outer"))
  expect_true(ok, info = shiny::isolate(store$tasks$outer$error_msg))
  tables <- shiny::isolate(store$tables)
  expect_equal(tables$outer_a_body_1$outer, "a")
  expect_equal(tables$outer_a_body_2$inner, "2")
  expect_equal(tables$outer_b_body_1$outer, "b")
  expect_equal(tables$outer_b_body_2$inner, "2")
})
