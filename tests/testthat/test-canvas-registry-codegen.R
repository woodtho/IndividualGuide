# Canvas network builder, task registry integrity, code panel assembly,
# result formatting, and misc helpers.

iso <- shiny::isolate

# ── canvas ─────────────────────────────────────────────────────────────────────

test_that("canvas_build_network builds nodes and edges from the store", {
  store <- new_test_store(list(sales = sample_sales()))
  add_test_task(store, "fs_1", "filter_sort", inputs = "sales",
    params = list(input_table = "sales", output_name = "fs_out"),
    output = "fs_out")
  nd <- iso(canvas_build_network(store))
  expect_setequal(nd$nodes$id, c("sales", "fs_out", "fs_1"))
  expect_equal(nrow(nd$edges), 2L)
  expect_true(any(nd$edges$from == "sales" & nd$edges$to == "fs_1"))
  expect_true(any(nd$edges$from == "fs_1" & nd$edges$to == "fs_out"))
})

test_that("canvas marks downstream tasks stale after an upstream re-run", {
  store <- new_test_store(list(sales = sample_sales()))
  t_up <- task_def("up", "filter_sort", inputs = "sales", output = "up_out")
  t_up$run_time <- Sys.time()
  t_dn <- task_def("dn", "rank", inputs = "up_out", output = "dn_out")
  t_dn$run_time <- Sys.time() - 60   # ran BEFORE the upstream re-run
  iso(store_set_task(store, t_up))
  iso(store_set_task(store, t_dn))
  nd <- iso(canvas_build_network(store))
  dn_node <- nd$nodes[nd$nodes$id == "dn", ]
  # Staleness shows as the amber status border + the card image + the tooltip.
  expect_equal(dn_node$color.border, "#f59e0b")
  expect_match(dn_node$title, "Stale")
  stale_svg <- rawToChar(jsonlite::base64_dec(
    sub("^.*base64,", "", dn_node$image)))
  expect_match(stale_svg, "Stale")
})

test_that("canvas tooltips show dataset dimensions and not-run status", {
  store <- new_test_store(list(sales = sample_sales()))
  add_test_task(store, "fs_1", "filter_sort", inputs = "sales",
    params = list(input_table = "sales", output_name = "fs_out"),
    output = "fs_out")
  nd <- iso(canvas_build_network(store))
  sales_node <- nd$nodes[nd$nodes$id == "sales", ]
  expect_match(sales_node$title, "6 rows")
  # declared-but-uncomputed output gets a hint instead of dimensions
  out_node <- nd$nodes[nd$nodes$id == "fs_out", ]
  expect_match(out_node$title, "run the producing task")
  # never-run task gets a not-run tooltip
  task_node <- nd$nodes[nd$nodes$id == "fs_1", ]
  expect_match(task_node$title, "Not run yet")
})

test_that("canvas deduplicates node ids defensively", {
  store <- new_test_store(list(x_out = data.frame(a = 1)))
  add_test_task(store, "t1", "filter_sort", output = "x_out",
    params = list(output_name = "x_out"))
  nd <- iso(canvas_build_network(store))
  expect_false(any(duplicated(nd$nodes$id)))
})

# ── task registry ──────────────────────────────────────────────────────────────

test_that("task registry entries are complete and unique", {
  ids <- vapply(TASK_REGISTRY, `[[`, character(1), "id")
  expect_false(any(duplicated(ids)))
  for (t in TASK_REGISTRY) {
    expect_true(all(c("id", "label", "category", "icon", "desc", "phase",
                      "available") %in% names(t)), info = t$id)
    expect_true(nzchar(t$label), info = t$id)
  }
  # every enabled id must exist in the registry
  expect_true(all(IG_ENABLED_TASK_IDS %in% ids))
  # all declared tasks are implemented and enabled in the picker
  expect_setequal(IG_ENABLED_TASK_IDS, ids)
  expect_true(all(vapply(TASK_REGISTRY, `[[`, logical(1), "available")))
})

test_that("every registry task has an extended help entry", {
  ids     <- vapply(TASK_REGISTRY, `[[`, character(1), "id")
  details <- ig_task_help_details()
  missing_help <- setdiff(ids, names(details))
  expect_length(missing_help, 0)
  orphaned <- setdiff(names(details), ids)   # help for tasks that don't exist
  expect_length(orphaned, 0)
  # every entry is a non-trivial description
  expect_true(all(vapply(details, function(x)
    is.character(x) && nchar(x) > 60, logical(1))))
})

test_that("the help modal builds with all five sections", {
  m <- help_modal_ui()
  expect_s3_class(m, "shiny.tag")
  html <- as.character(m)
  for (tab in c("Overview", "Workspace", "Tasks", "Running",
                "Projects &amp; settings")) {
    expect_match(html, tab, fixed = TRUE)
  }
  # every task label appears in the rendered reference
  for (t in TASK_REGISTRY) expect_match(html, t$label, fixed = TRUE)
})

test_that("task_type_info and category helpers look up entries", {
  info <- task_type_info("filter_sort")
  expect_equal(info$label, "Filter and Sort")
  expect_null(task_type_info("nope"))
  expect_true("Data" %in% task_categories())
  data_tasks <- tasks_for_category("Data")
  expect_true(all(vapply(data_tasks, function(t) t$category == "Data",
                         logical(1))))
})

test_that("every enabled non-phase3 task type has a standalone executor", {
  # Mirrors the dispatch table in run_task_from_store.
  executors <- c(
    import_data = "execute_import", query_builder = "execute_query", export_log = "execute_export_log",
    append_table = "execute_append", compare_data = "execute_compare",
    filter_sort = "execute_fs", stack_columns = "execute_stack",
    split_columns = "execute_split", transpose = "execute_transpose",
    rank = "execute_rank", standardize = "execute_std",
    random_sample = "execute_sample", remove_dups = "execute_remove_dups",
    keep_drop_cols = "execute_keep_drop", rename_cols = "execute_rename_cols",
    first_last_n = "execute_first_last",
    replace_missing = "execute_replace_missing",
    derive_cols = "execute_derive_cols", recode_values = "execute_recode_values",
    change_types = "execute_change_types", characterize = "execute_characterize",
    list_data = "execute_list_data", one_way_freq = "execute_one_way_freq",
    summary_stats = "execute_summary_stats",
    table_analysis = "execute_table_analysis",
    summary_tables = "execute_summary_table",
    distribution = "execute_distribution",
    script = "execute_script", report = "execute_report",
    export = "execute_export", branch = "execute_branch",
    loop = "execute_loop"
  )
  for (tid in setdiff(IG_ENABLED_TASK_IDS, PHASE3_TYPES)) {
    expect_true(tid %in% names(executors), info = tid)
    expect_true(exists(executors[[tid]], mode = "function"), info = tid)
  }
})

test_that("every default param builder includes an output_name", {
  builders <- list(
    default_qb_params, default_import_params, default_append_table_params,
    default_compare_data_params, default_filter_sort_params,
    default_stack_columns_params, default_split_columns_params,
    default_transpose_params, default_rank_params, default_standardize_params,
    default_random_sample_params, default_remove_dups_params,
    default_keep_drop_params, default_rename_cols_params,
    default_first_last_params, default_replace_missing_params,
    default_derive_cols_params, default_recode_values_params,
    default_change_types_params, default_characterize_params,
    default_distribution_params, default_one_way_freq_params,
    default_summary_stats_params, default_summary_tables_params,
    default_table_analysis_params, default_script_params,
    default_report_params
  )
  for (b in builders) {
    p <- b(output_name = "custom_out")
    expect_equal(p$output_name, "custom_out")
  }
  # phase3 builder has a different signature
  p3 <- default_phase3_params("bar_chart", output_name = "custom_out")
  expect_equal(p3$output_name, "custom_out")
})

# ── code generation panel ──────────────────────────────────────────────────────

test_that("build_full_r_script assembles snippets with deduplicated libraries", {
  store <- new_test_store()
  t1 <- task_def("a", "filter_sort", output = "a_out")
  t1$r_code <- "library(dplyr)\na_out <- filter(raw, x > 1)"
  t2 <- task_def("b", "rank", inputs = "a_out", output = "b_out")
  t2$r_code <- "library(dplyr)\nlibrary(stringr)\nb_out <- mutate(a_out, r = min_rank(x))"
  iso(store_set_task(store, t1)); iso(store_set_task(store, t2))

  script <- iso(build_full_r_script(store))
  expect_equal(sum(gregexpr("library\\(dplyr\\)", script)[[1]] > 0), 1L)
  expect_match(script, "library\\(stringr\\)")
  expect_match(script, "# Filter and Sort (a) ----", fixed = TRUE)
  # task a's code comes before task b's
  expect_lt(regexpr("a_out <- filter", script),
            regexpr("b_out <- mutate", script))
})

test_that("build_full_r_script orders tasks by dependencies, not insertion", {
  store <- new_test_store()
  # consumer registered FIRST — the script must still emit the producer first
  t_consumer <- task_def("consumer", "rank", inputs = "raw_out", output = "rank_out")
  t_consumer$r_code <- "rank_out <- transform(raw_out, r = rank(x))"
  t_producer <- task_def("producer", "filter_sort", output = "raw_out")
  t_producer$r_code <- "raw_out <- data.frame(x = 1:3)"
  iso(store_set_task(store, t_consumer))
  iso(store_set_task(store, t_producer))
  script <- iso(build_full_r_script(store))
  expect_lt(regexpr("raw_out <- data.frame", script, fixed = TRUE),
            regexpr("rank_out <- transform", script, fixed = TRUE))
})

# ── result formatting ──────────────────────────────────────────────────────────

test_that("format_phase3_result returns gt tables for model results", {
  fit <- lm(mpg ~ wt, data = datasets::mtcars)
  tidy_df <- broom::tidy(fit, conf.int = TRUE)
  glance_df <- broom::glance(fit)
  gt_tbl <- format_phase3_result("linear_regression", tidy_df,
                                 list(glance = glance_df))
  expect_s3_class(gt_tbl, "gt_tbl")

  tt <- broom::tidy(t.test(datasets::mtcars$mpg))
  expect_s3_class(format_phase3_result("t_test", tt), "gt_tbl")
  expect_null(format_phase3_result("bar_chart", data.frame(x = 1)))
  expect_null(format_phase3_result("linear_regression", NULL))
})

test_that("significance helpers format p-values", {
  expect_equal(.sig_stars(c(0.0001, 0.005, 0.03, 0.07, 0.5, NA)),
               c("***", "**", "*", ".", "", ""))
  expect_equal(.fmt_p(0.0001), "< .001")
  expect_equal(.fmt_p(NA), "—")
})

# ── misc helpers ───────────────────────────────────────────────────────────────

test_that("%||% and ig_notify behave outside a session", {
  expect_equal(NULL %||% "b", "b")
  expect_equal("a" %||% "b", "a")
  expect_no_error(ig_notify("message with no session"))
})

test_that("waldo_compare_html renders diff lines", {
  skip_if_not_installed("waldo")
  cmp <- waldo::compare(data.frame(x = 1), data.frame(x = 2))
  html <- waldo_compare_html(cmp)
  expect_s3_class(html, "shiny.tag")
})

test_that("connection catalogue CRUD works against a sandboxed directory", {
  tmp_dir <- tempfile("cat_"); dir.create(tmp_dir)
  withr_opts <- options(ig.catalogue_dir = tmp_dir)
  on.exit(options(withr_opts), add = TRUE)

  expect_equal(cat_read(), list())
  entry <- list(id = "conn_test_1", name = "Test DB", conn_mode = "form",
                db_driver = "sqlite", db_database = "x.db")
  cat_add(entry)
  expect_equal(cat_find("conn_test_1")$name, "Test DB")
  expect_equal(unname(cat_choices()["Test DB"]), "conn_test_1")

  entry$name <- "Renamed"
  cat_add(entry)                      # upsert by id
  expect_length(cat_read(), 1L)
  expect_equal(cat_find("conn_test_1")$name, "Renamed")

  cat_delete("conn_test_1")
  expect_null(cat_find("conn_test_1"))
})

test_that("script output declaration helpers round-trip", {
  defs <- list(list(name = "a", kind = "table"), list(name = "b", kind = "auto"))
  txt <- format_script_output_defs(defs)
  expect_equal(parse_script_output_defs(txt, ""), defs)
  expect_equal(script_declared_output_names(defs), c("a", "b"))
})
