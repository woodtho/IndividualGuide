test_that("branch parameter comparisons respect every selected operator", {
  tasks <- list(up = list(status = "success", params = list(n = 10)))
  for (op in c(">", ">=", "!=", "==", "<", "<=")) {
    condition <- list(rules = list(list(kind = "parameter_value", task_id = "up", parameter = "n", op = op, value = "5")))
    expected <- do.call(op, list(10, 5))
    expect_identical(branch_eval_condition(condition, list(), list(), tasks, list()), expected)
  }
})

test_that("branches reject duplicate tokens and ambiguous conditions", {
  p <- default_branch_params()
  p$paths[[2]]$token <- p$paths[[1]]$token
  expect_match(execute_branch(p)$error, "unique")
  p <- default_branch_params()
  p$paths[[1]]$condition$rules[[1]]$expr <- "c(TRUE, FALSE)"
  expect_error(execute_branch(p), "one TRUE or FALSE")
})

test_that("branch status references enforce order even for tasks with no output", {
  p <- default_branch_params("gate")
  p$paths[[1]]$condition$rules <- list(list(kind = "task_status", task_id = "sink", status = "success"))
  gate <- task_def("gate", "branch", output = "", params = p)
  gate$outputs <- branch_output_specs(p)
  sink <- task_def("sink", "export", output = "")
  tasks <- list(gate = gate, sink = sink)
  expect_equal(store_topo_order(tasks, c("gate", "sink")), c("sink", "gate"))
  expect_equal(store_topo_to(tasks, c("gate", "sink"), "gate"), c("sink", "gate"))
})

test_that("generated branch decisions match runtime fallback and task state", {
  p <- default_branch_params("gate")
  p$paths[[1]]$condition$rules <- list(list(kind = "task_status", task_id = "a", status = "success"))
  tasks <- list(a = list(status = "error", params = list()))
  expected <- execute_branch(p, tasks = tasks)
  env <- new.env(parent = baseenv())
  env$.task_status <- list(a = "error")
  env$.task_params <- list(a = list())
  eval(parse(text = build_branch_code(p)), env)
  expect_equal(names(Filter(isTRUE, env$branch_decision)), expected$matched_tokens)
  expect_identical(env$.task_status$a, "error")
})
