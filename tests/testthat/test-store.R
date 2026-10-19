# Store: tables, tasks, flows, dependency ordering.

iso <- shiny::isolate

test_that("store_add_table / store_remove_table manage tables and sources", {
  store <- new_test_store()
  store_add_table(store, "t1", sample_sales(), source_meta = list(type = "csv"))
  expect_equal(iso(store_table_names(store)), "t1")
  expect_equal(iso(store$sources)$t1$type, "csv")
  expect_true(iso(store$dirty))

  store_remove_table(store, "t1")
  expect_length(iso(store_table_names(store)), 0)
  expect_null(iso(store$sources)$t1)
})

test_that("canvas layout + manual positions persist on the active flow", {
  store <- new_test_store()
  # default
  expect_equal(iso(store_canvas_layout(store)), "LR")
  # set + read back
  store_set_canvas_layout(store, "free")
  expect_equal(iso(store_canvas_layout(store)), "free")
  fid <- iso(store$active_flow)
  expect_equal(iso(store$flows)[[fid]]$canvas_layout, "free")
  # unchanged write is a no-op (dirty cleared first to prove it stays clean)
  store$dirty <- FALSE
  store_set_canvas_layout(store, "free")
  expect_false(iso(store$dirty))
  # positions round-trip
  pos <- list(t1 = list(x = 10, y = 20), t2 = list(x = -5, y = 7))
  store_set_canvas_positions(store, pos)
  expect_equal(iso(store_canvas_positions(store)), pos)
  expect_true(iso(store$dirty))
})

test_that("store_add_object / store_remove_output handle special outputs", {
  store <- new_test_store()
  store_add_object(store, "m1", lm(qty ~ amount, sample_sales()),
                   meta = list(kind = "model"))
  expect_equal(iso(store_object_names(store)), "m1")
  store_remove_output(store, "m1")
  expect_length(iso(store_object_names(store)), 0)
})

test_that("task_def + store_set_task register tasks and outputs", {
  store <- new_test_store()
  t1 <- task_def("fs_1", "filter_sort", inputs = "raw", output = "fs_1_out")
  iso(store_set_task(store, t1))
  expect_equal(iso(store$task_order), "fs_1")
  expect_equal(task_output_names(iso(store$tasks)$fs_1), "fs_1_out")
})

test_that("renaming a task output retires the stale table", {
  store <- new_test_store()
  t1 <- task_def("fs_1", "filter_sort", output = "old_out")
  iso(store_set_task(store, t1))
  store_add_table(store, "old_out", sample_sales())
  t1$output <- "new_out"
  iso(store_set_task(store, t1))
  expect_false("old_out" %in% iso(store_table_names(store)))
})

test_that("settings defaults exist and ig_page_len validates", {
  store <- new_test_store()
  s <- iso(store$settings)
  expect_equal(s$page_length, 10L)
  expect_equal(s$plot_theme, "clean")
  expect_false(s$stop_on_error)
  expect_true(s$confirm_delete)

  expect_equal(iso(ig_page_len(store)), 10L)
  store$settings <- list(page_length = 50)
  expect_equal(iso(ig_page_len(store)), 50L)
  store$settings <- list(page_length = "bogus")
  expect_equal(iso(ig_page_len(store)), 10L)   # invalid → safe default
  store$settings <- list(page_length = 2)
  expect_equal(iso(ig_page_len(store)), 10L)   # below floor → safe default
})

test_that("store_set_task derives canvas status from run_time / error_msg", {
  store <- new_test_store()
  t1 <- task_def("fs_1", "filter_sort", output = "o1")
  iso(store_set_task(store, t1))
  expect_equal(iso(store$tasks)$fs_1$status, "pending")

  # a recorded run (any save path — panel or headless) means success
  t1$run_time <- Sys.time()
  iso(store_set_task(store, t1))
  expect_equal(iso(store$tasks)$fs_1$status, "success")

  # an error message wins over a stale run_time
  t1$error_msg <- "boom"
  iso(store_set_task(store, t1))
  expect_equal(iso(store$tasks)$fs_1$status, "error")

  # clearing the error on the next successful run restores success
  t1$error_msg <- NULL
  iso(store_set_task(store, t1))
  expect_equal(iso(store$tasks)$fs_1$status, "success")
})

test_that("store_remove_task also drops the registered runner and code fn", {
  store <- new_test_store()
  iso(store_set_task(store, task_def("fs_1", "filter_sort", output = "o1")))
  store_register_runner(store, "fs_1", function() TRUE)
  store_register_code_fn(store, "fs_1", function() "x <- 1")
  expect_true("fs_1" %in% names(iso(store$task_runners)))
  expect_equal(iso(store$code_fns)$fs_1(), "x <- 1")
  iso(store_remove_task(store, "fs_1"))
  expect_false("fs_1" %in% names(iso(store$task_runners)))
  expect_false("fs_1" %in% names(iso(store$code_fns)))
  # NULL task_id is a safe no-op (modules opened without a task id)
  expect_no_error(store_register_code_fn(store, NULL, function() ""))
})

test_that("store_set_task rejects self-referencing tasks", {
  store <- new_test_store()
  bad <- task_def("fs_1", "filter_sort", inputs = "fs_1_out", output = "fs_1_out")
  expect_warning(ok <- iso(store_set_task(store, bad)), "own output")
  expect_false(ok)
  expect_length(iso(store$task_order), 0)
})

test_that("store_dependency_problem detects circular references", {
  t_a <- task_def("a", "filter_sort", inputs = "b_out", output = "a_out")
  t_b <- task_def("b", "filter_sort", inputs = "a_out", output = "b_out")
  msg <- store_dependency_problem(list(a = t_a, b = t_b), c("a", "b"))
  expect_match(msg, "Circular")
})

test_that("store_topo_order sorts producers before consumers", {
  t_imp <- task_def("imp", "import_data", output = "raw")
  t_fs  <- task_def("fs", "filter_sort", inputs = "raw", output = "fs_out")
  t_sum <- task_def("sum", "summary_stats", inputs = "fs_out", output = "sum_out")
  tasks <- list(sum = t_sum, fs = t_fs, imp = t_imp)
  ord <- suppressWarnings(store_topo_order(tasks, c("sum", "fs", "imp")))
  expect_equal(ord, c("imp", "fs", "sum"))
})

test_that("store_topo_from / store_topo_to walk the dependency graph", {
  t_imp <- task_def("imp", "import_data", output = "raw")
  t_fs  <- task_def("fs", "filter_sort", inputs = "raw", output = "fs_out")
  t_sum <- task_def("sum", "summary_stats", inputs = "fs_out", output = "sum_out")
  t_iso <- task_def("island", "characterize", inputs = "raw", output = "iso_out")
  tasks <- list(imp = t_imp, fs = t_fs, sum = t_sum, island = t_iso)
  order <- c("imp", "fs", "sum", "island")

  expect_equal(store_topo_from(tasks, order, "fs"), c("fs", "sum"))
  expect_setequal(store_topo_from(tasks, order, "imp"), order)
  expect_equal(store_topo_to(tasks, order, "sum"), c("imp", "fs", "sum"))
  expect_equal(store_topo_to(tasks, order, "island"), c("imp", "island"))
})

test_that("store_next_id increments per type across flows", {
  store <- new_test_store()
  expect_equal(iso(store_next_id(store, "filter_sort")), "filtersort_1")
  iso(store_set_task(store, task_def("filtersort_1", "filter_sort",
                                     output = "o1")))
  expect_equal(iso(store_next_id(store, "filter_sort")), "filtersort_2")
  expect_equal(iso(store_next_id(store, "rank")), "rank_1")
})

test_that("store_copy_flow deep-copies tasks with remapped ids", {
  store <- new_test_store()
  iso(store_set_task(store, task_def("fs_1", "filter_sort", output = "fs_1_out",
    params = list(output_name = "fs_1_out"))))
  src_id <- iso(store$active_flow)
  new_id <- iso(store_copy_flow(store, src_id))
  expect_false(is.null(new_id))
  new_flow <- iso(store$flows)[[new_id]]
  expect_equal(length(new_flow$tasks), 1L)
  new_task <- new_flow$tasks[[1]]
  expect_false(identical(new_task$id, "fs_1"))
  expect_match(new_flow$name, "copy")
  # the copy's params point at its own output name, not the original's
  expect_equal(new_task$params$output_name, paste0(new_task$id, "_out"))
})

test_that("store_activate_flow snapshots and restores the live window", {
  store <- new_test_store()
  iso(store_set_task(store, task_def("fs_1", "filter_sort", output = "o1")))
  fl2 <- make_flow("Flow 2")
  flows <- iso(store$flows); flows[[fl2$id]] <- fl2; store$flows <- flows
  first_id <- setdiff(names(flows), fl2$id)

  store_activate_flow(store, fl2$id)
  expect_equal(iso(store$active_flow), fl2$id)
  expect_length(iso(store$tasks), 0)
  # original flow kept its snapshot
  expect_equal(names(iso(store$flows)[[first_id]]$tasks), "fs_1")

  store_activate_flow(store, first_id)
  expect_equal(names(iso(store$tasks)), "fs_1")
})

test_that("store_available_tables excludes own/descendant outputs", {
  store <- new_test_store()
  store_add_table(store, "raw", sample_sales())
  iso(store_set_task(store, task_def("fs_1", "filter_sort",
                                     inputs = "raw", output = "fs_out")))
  iso(store_set_task(store, task_def("rk_1", "rank",
                                     inputs = "fs_out", output = "rk_out")))
  avail_fs <- iso(store_available_tables(store, task_id = "fs_1"))
  # fs_1 must not see its own output, nor its descendant's output
  expect_false("fs_out" %in% avail_fs)
  expect_false("rk_out" %in% avail_fs)
  expect_true("raw" %in% avail_fs)
  # rk_1 can see fs_out (its upstream) but not its own output
  avail_rk <- iso(store_available_tables(store, task_id = "rk_1"))
  expect_true("fs_out" %in% avail_rk)
  expect_false("rk_out" %in% avail_rk)
})

test_that("store_preserve_choice prefers current, then saved, then default", {
  expect_equal(store_preserve_choice("a", "b", c("a", "b")), "a")
  expect_equal(store_preserve_choice("", "b", c("a", "b")), "b")
  expect_equal(store_preserve_choice("zz", "yy", c("a", "b"), default = "a"), "a")
  expect_equal(store_preserve_choice("zz", "yy", c("a", "b")), "")
  expect_equal(store_preserve_choices(c("a", "zz"), c("b"), c("a", "b")), "a")
  expect_equal(store_preserve_choices(NULL, c("b"), c("a", "b")), "b")
  expect_equal(store_preserve_choices(character(0), c("b"), c("a", "b"), initialized = TRUE), character(0))
  expect_equal(store_preserve_choice("", "b", c("", "a", "b"), initialized = TRUE), "")
})

test_that("store_col_info profiles data frame columns", {
  store <- new_test_store(list(sales = sample_sales()))
  info <- iso(store_col_info(store, "sales"))
  expect_equal(info$column, names(sample_sales()))
  expect_equal(info$n_missing[info$column == "amount"], 1L)
})

test_that("store_get_table returns plain data frames", {
  store <- new_test_store(list(sales = sample_sales()))
  expect_identical(iso(store_get_table(store, "sales")), sample_sales())
  expect_null(iso(store_get_table(store, "missing")))
})
