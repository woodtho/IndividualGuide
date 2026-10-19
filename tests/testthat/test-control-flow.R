iso <- function(expr) shiny::isolate(expr)

test_that("branch conditions summarize, validate, and evaluate", {
  cond <- list(op = "and", rules = list(
    list(kind = "row_count", table = "sales", op = ">", value = "3"),
    list(kind = "column_value", table = "sales", column = "region",
         op = "==", value = '"North"')
  ))
  expect_null(validate_branch_condition(cond))
  expect_match(branch_condition_summary(cond), "nrow")
  expect_true(branch_eval_condition(cond, list(sales = sample_sales()), list(), list(), list()))
  expect_match(branch_condition_code(cond), "nrow")
})

test_that("branch simple UI values become structured path conditions", {
  path <- branch_simple_to_path(list(
    label = "Large sales",
    token = "gate_large",
    kind = "row_count",
    table = "sales",
    op = ">=",
    value = "10"
  ), 1)
  expect_equal(path$label, "Large sales")
  expect_equal(path$token, "gate_large")
  expect_equal(path$condition$rules[[1]]$kind, "row_count")
  expect_match(branch_condition_summary(path$condition), "nrow\\(sales\\) >= 10")

  fallback <- branch_simple_to_path(list(
    label = "Fallback", token = "gate_else", kind = "else"
  ), 2)
  expect_true(fallback$else_path)
  expect_equal(branch_condition_summary(fallback$condition), "always")
})

test_that("branch paths with empty rules open in the UI mapper", {
  simple <- branch_path_to_simple(list(
    label = "Fallback",
    token = "gate_else",
    else_path = TRUE,
    condition = list(op = "and", rules = list(), groups = list())
  ), 2)
  expect_equal(simple$kind, "else")
  expect_equal(simple$expr, "TRUE")
})

test_that("branch path controls render inside the module namespace", {
  store <- new_test_store(list(sales = sample_sales()))
  p <- default_branch_params("gate")
  branch <- task_def("branch_1", "branch", inputs = "sales", output = "", params = p)
  branch$outputs <- branch_output_specs(p)
  iso(store_set_task(store, branch))

  suppressWarnings(shiny::testServer(branch_server, args = list(store = store, task_id = "branch_1"), {
    session$setInputs(path_count = 2)
    session$flushReact()
    rendered <- output$path_controls
    expect_true(is.list(rendered))
    expect_match(rendered$html, "accordion")
  }))
})

test_that("branch outputs participate in dependency sorting and canvas lineage", {
  store <- new_test_store(list(sales = sample_sales()))
  p <- default_branch_params("gate")
  p$dependencies <- "sales"
  p$paths[[1]]$token <- "gate_true"
  p$paths[[1]]$label <- "Enough rows"
  p$paths[[1]]$condition <- list(op = "and", rules = list(
    list(kind = "row_count", table = "sales", op = ">", value = "3")
  ))
  p$paths[[2]]$token <- "gate_else"
  branch <- task_def("branch_1", "branch", inputs = "sales", output = "", params = p)
  branch$outputs <- branch_output_specs(p)
  iso(store_set_task(store, branch))

  add_test_task(store, "script_1", "script",
    inputs = c("sales", "gate_true"), output = "script_out",
    params = list(input_tables = c("sales", "gate_true"),
                  code = "script_out <- sales",
                  output_defs = list(list(name = "script_out", kind = "table"))))

  expect_equal(iso(store_topo_order(store$tasks, store$task_order))[1], "branch_1")
  nd <- iso(canvas_build_network(store))
  expect_true("gate_true" %in% nd$nodes$id)
  expect_true(any(nd$edges$label == "Enough rows"))
})

test_that("control dependencies are selectable and preserved on downstream tasks", {
  store <- new_test_store(list(sales = sample_sales()))
  p <- default_branch_params("gate")
  branch <- task_def("branch_1", "branch", inputs = "sales", output = "", params = p)
  branch$outputs <- branch_output_specs(p)
  iso(store_set_task(store, branch))

  expect_true("gate_true" %in% iso(store_available_control_tokens(store)))

  downstream <- task_def("script_1", "script",
    inputs = "sales", output = "script_out",
    params = list(input_tables = "sales", code = "script_out <- sales"))
  downstream$control_inputs <- "gate_true"
  iso(store_set_task(store, downstream))
  expect_true("gate_true" %in% iso(store$tasks[["script_1"]]$inputs))

  resaved <- iso(store$tasks[["script_1"]])
  resaved$inputs <- "sales"
  iso(store_set_task(store, resaved))
  expect_equal(iso(store$tasks[["script_1"]]$control_inputs), "gate_true")
  expect_true("gate_true" %in% iso(store$tasks[["script_1"]]$inputs))
})

test_that("headless branch execution marks nonmatching downstream tasks skipped", {
  store <- new_test_store(list(sales = sample_sales()))
  p <- default_branch_params("gate")
  p$dependencies <- "sales"
  p$paths[[1]]$token <- "gate_true"
  p$paths[[1]]$condition <- list(op = "and", rules = list(
    list(kind = "row_count", table = "sales", op = ">", value = "100")
  ))
  p$paths[[2]]$token <- "gate_else"
  branch <- task_def("branch_1", "branch", inputs = "sales", output = "", params = p)
  branch$outputs <- branch_output_specs(p)
  iso(store_set_task(store, branch))

  add_test_task(store, "true_task", "script",
    inputs = c("sales", "gate_true"), output = "true_out",
    params = list(input_tables = c("sales", "gate_true"), code = "true_out <- sales"))
  add_test_task(store, "else_task", "script",
    inputs = c("sales", "gate_else"), output = "else_out",
    params = list(input_tables = c("sales", "gate_else"), code = "else_out <- sales"))

  ok <- iso(run_task_from_store(store, "branch_1"))
  expect_true(ok)
  skipped <- iso(store_apply_branch_decision(store, "branch_1"))
  expect_equal(skipped, "true_task")
  expect_equal(iso(store$tasks[["true_task"]]$status), "skipped")
  expect_equal(iso(store$tasks[["else_task"]]$status), "pending")
})

test_that("loop node previews iterations and exposes a lineage token", {
  p <- default_loop_params("loop")
  p$values <- "a\nb\nc"
  p$output_token <- "loop_each"
  res <- execute_loop(p, list(), list())
  expect_null(res$error)
  expect_equal(res$iterations, c("a", "b", "c"))
  expect_equal(loop_output_specs(p)[[1]]$name, "loop_each")
  expect_silent(parse(text = build_loop_code(p)))
})

test_that("loop node previews dataset groups", {
  p <- default_loop_params("loop")
  p$iteration_type <- "groups"
  p$source <- "sales"
  p$group_col <- "region"
  expect_equal(
    loop_preview_iterations(p, list(sales = sample_sales())),
    sort(unique(sample_sales()$region))
  )
  expect_match(build_loop_code(p), "region")
})
