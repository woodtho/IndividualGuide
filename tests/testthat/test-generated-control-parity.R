test_that("exported parameter loops repeat real bodies and retain the same outputs", {
  store <- new_test_store(list(raw = data.frame(x = 1:3)))
  p <- default_loop_params("repeat")
  p$values <- "2\n3"
  loop <- task_def("repeat", "loop", output = "", params = p)
  loop$outputs <- loop_output_specs(p)
  shiny::isolate(store_set_task(store, loop))
  task <- task_def("calculate", "script", inputs = "raw", output = "scaled",
    params = list(input_tables = "raw", output_name = "scaled",
      code = "scaled <- transform(raw, x = x * as.numeric(item))",
      output_defs = list(list(name = "scaled", kind = "table"))))
  task$control_inputs <- p$output_token
  shiny::isolate(store_set_task(store, task))
  script <- build_full_r_script(store)
  expect_match(script, "for \\(")
  env <- list2env(list(raw = data.frame(x = 1:3)), parent = globalenv())
  eval(parse(text = script), env)
  expect_equal(env$calculate_2$x, c(2, 4, 6))
  expect_equal(env$calculate_3$x, c(3, 6, 9))
  expect_true(shiny::isolate(run_task_from_store(store, "repeat")))
  expect_identical(env$calculate_2, shiny::isolate(store$tables$calculate_2))
  expect_identical(env$calculate_3, shiny::isolate(store$tables$calculate_3))
})

test_that("file dataset date and database-row loops retain typed values in exported scripts", {
  file <- tempfile(fileext = ".csv"); write.csv(data.frame(x = 1:2), file, row.names = FALSE)
  for (type in c("files", "datasets", "date_ranges", "database_query")) {
    store <- new_test_store(list(raw = data.frame(x = 1:2)))
    p <- default_loop_params("loop"); p$iteration_type <- type
    p$naming_rule <- "{task}_{index}"; p$source <- if (type == "database_query") "raw" else ""
    p$values <- if (type == "files") file else "2026-01-01\n2026-02-01/2026-02-03"
    loop <- task_def("loop", "loop", output = "", params = p); loop$outputs <- loop_output_specs(p)
    shiny::isolate(store_set_task(store, loop))
    body <- task_def("body", "script", output = "out", params = list(code = "out <- list(value = item)",
      output_name = "out", output_defs = list(list(name = "out", kind = "object"))))
    body$control_inputs <- p$output_token; shiny::isolate(store_set_task(store, body))
    env <- list2env(list(raw = data.frame(x = 1:2)), parent = globalenv())
    eval(parse(text = build_full_r_script(store)), env)
    expect_true(shiny::isolate(run_task_from_store(store, "loop")), info = type)
    count <- shiny::isolate(store$tasks$loop$loop_completed_iterations)
    for (i in seq_len(count)) expect_equal(get(paste0("body_", i), env),
      shiny::isolate(store$objects)[[paste0("body_", i)]]$value, info = type)
  }
})

test_that("exported branch paths gate downstream operations and preserve fallback", {
  store <- new_test_store(list(raw = data.frame(x = 1:3)))
  p <- default_branch_params("gate")
  p$paths[[1]]$condition$rules[[1]]$expr <- "FALSE"
  gate <- task_def("gate", "branch", output = "", params = p)
  gate$outputs <- branch_output_specs(p)
  shiny::isolate(store_set_task(store, gate))
  for (path in c("true", "else")) {
    task <- task_def(path, "script", inputs = "raw", output = paste0(path, "_out"),
      params = list(input_tables = "raw", code = paste0(path, "_out <- raw"), output_name = paste0(path, "_out")))
    task$control_inputs <- paste0("gate_", path)
    shiny::isolate(store_set_task(store, task))
  }
  env <- list2env(list(raw = data.frame(x = 1:3)), parent = globalenv())
  eval(parse(text = build_full_r_script(store)), env)
  expect_false(exists("true_out", env, inherits = FALSE))
  expect_equal(env$else_out$x, 1:3)
  expect_identical(env$.task_status[["true"]], "skipped")
  expect_identical(env$.task_status[["else"]], "success")
})

test_that("iteration placeholders use the same parameter builder in exported code", {
  store <- new_test_store(list(raw = data.frame(x = 1:3)))
  p <- default_loop_params("gate")
  p$values <- "x\ny"
  loop <- task_def("loop", "loop", output = "", params = p)
  loop$outputs <- loop_output_specs(p)
  shiny::isolate(store_set_task(store, loop))
  p2 <- default_derive_cols_params("derived")
  p2$input_table <- "raw"
  p2$derives <- list(list(name = "{item}", expr = "x * 2"))
  task <- task_def("derive", "derive_cols", inputs = "raw", output = "derived", params = p2)
  task$control_inputs <- p$output_token
  shiny::isolate(store_set_task(store, task))
  env <- list2env(list(raw = data.frame(x = 1:3)), parent = globalenv())
  eval(parse(text = build_full_r_script(store)), env)
  expect_true(shiny::isolate(run_task_from_store(store, "loop")))
  expect_identical(as.data.frame(env$derive_y), shiny::isolate(store$tables$derive_y))
})

test_that("exported group loops keep the source intact and match each group's data", {
  store <- new_test_store(list(sales = sample_sales()))
  p <- default_loop_params("groups")
  p$iteration_type <- "groups"
  p$source <- "sales"
  p$group_col <- "region"
  loop <- task_def("groups", "loop", inputs = "sales", output = "", params = p)
  loop$outputs <- loop_output_specs(p)
  shiny::isolate(store_set_task(store, loop))
  task <- task_def("copy", "script", inputs = "sales", output = "result",
    params = list(input_tables = "sales", code = "result <- sales", output_name = "result"))
  task$control_inputs <- p$output_token
  shiny::isolate(store_set_task(store, task))
  env <- list2env(list(sales = sample_sales()), parent = globalenv())
  eval(parse(text = build_full_r_script(store)), env)
  expect_true(shiny::isolate(run_task_from_store(store, "groups")))
  for (name in c("copy_East", "copy_North", "copy_South"))
    expect_identical(get(name, env), shiny::isolate(store$tables)[[name]])
  expect_identical(env$sales, sample_sales())
})

test_that("exported nested loops retain all outer/inner combinations", {
  store <- new_test_store()
  for (id in c("outer", "inner")) {
    p <- default_loop_params(id)
    p$variable <- paste0(id, "_value")
    p$values <- if (id == "outer") "a\nb" else "1\n2"
    task <- task_def(id, "loop", output = "", params = p)
    task$outputs <- loop_output_specs(p)
    if (id == "inner") task$control_inputs <- "outer_each"
    shiny::isolate(store_set_task(store, task))
  }
  task <- task_def("body", "script", output = "result",
    params = list(code = "result <- data.frame(outer = outer_value, inner = inner_value)", output_name = "result"))
  task$control_inputs <- "inner_each"
  shiny::isolate(store_set_task(store, task))
  env <- new.env(parent = globalenv())
  eval(parse(text = build_full_r_script(store)), env)
  expect_true(shiny::isolate(run_task_from_store(store, "outer")))
  for (name in c("outer_a_body_1", "outer_a_body_2", "outer_b_body_1", "outer_b_body_2")) {
    expect_true(exists(name, env, inherits = FALSE), info = paste(ls(env, all.names = TRUE), collapse = ", "))
    expect_identical(get(name, env), shiny::isolate(store$tables)[[name]])
  }
})

test_that("analytical loop placeholders include their standalone helper dependencies", {
  store <- new_test_store(list(raw = mtcars))
  p <- default_loop_params("loop"); p$values <- "first\nsecond"
  loop <- task_def("loop", "loop", output = "", params = p)
  loop$outputs <- loop_output_specs(p)
  shiny::isolate(store_set_task(store, loop))
  g <- default_phase3_params("scatter_plot", "chart")
  g$input_table <- "raw"; g$x <- "wt"; g$y <- "mpg"; g$title <- "Iteration {item}"
  g$output_enabled$image <- TRUE
  task <- store_task_from_params(task_def("graph", "scatter_plot"), g)
  task$control_inputs <- p$output_token
  shiny::isolate(store_set_task(store, task))
  env <- list2env(list(raw = mtcars), parent = globalenv())
  eval(parse(text = build_full_r_script(store)), env)
  expect_true(shiny::isolate(run_task_from_store(store, "loop")))
  for (item in c("first", "second")) {
    name <- paste0("graph_", item, "_chart_image")
    expect_identical(get(name, env)$labels$title, paste("Iteration", item))
    expect_equal(get(name, env)$labels$title, shiny::isolate(store$objects)[[name]]$value$labels$title)
  }
})
