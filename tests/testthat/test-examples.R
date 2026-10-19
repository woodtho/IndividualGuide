test_that("shipped examples are complete projects with real data, logs and files", {
  withr::local_envvar(IG_USER_DATA = tempfile("example-profile-"))
  withr::local_options(ig.examples_dir = tempfile("example-copies-"))
  for (info in Filter(function(x) x$id %in% c("iris", "air-quality", "fuel-economy"), ig_example_catalog())) {
    prepared <- ig_prepare_example(info$id)
    expect_true(file.exists(prepared$path))
    store <- make_store(); on.exit(project_release_assets(store), add = TRUE)
    result <- project_load(store, prepared$path)
    expect_true(result$ok)
    isolate({
      expect_true(all(vapply(store$tasks, function(task) identical(task$status, "success"), logical(1))))
      source <- switch(info$id, iris = "flowers", `air-quality` = "air_raw", "cars")
      expected <- switch(info$id, iris = datasets::iris, `air-quality` = datasets::airquality,
        { df <- datasets::mtcars; df$car <- rownames(df); rownames(df) <- NULL; df })
      expect_identical(store$tables[[source]], expected)
      expect_equal(nrow(store$tables[[source]]), info$rows)
      expect_gt(nrow(ig_log_records(store$tasks)), 20L)
      expect_true(any(ig_log_records(store$tasks)$event == "custom"))
      expect_true(file.exists(store$tasks$example_report$outputs[[1]]$path))
      expect_s3_class(store$objects$chart_data_image$value, "ggplot")
      expect_false("chart_data_plot" %in% names(store$objects))
      expect_false(store$tasks$example_chart$params$output_enabled$plot)
      restored_chart <- file.path(prepared$directory, "restored-chart.png")
      ggplot2::ggsave(restored_chart, store$objects$chart_data_image$value, width = 4, height = 3, dpi = 72)
      expect_gt(file.info(restored_chart)$size, 0)
      for (id in c("example_csv", "example_png", "example_log")) {
        expect_true(file.exists(store$tasks[[id]]$export_file))
        expect_true(startsWith(store$tasks[[id]]$export_file, prepared$directory))
        expect_gt(file.info(store$tasks[[id]]$export_file)$size, 0)
      }
      if (info$id == "air-quality") {
        expect_gt(sum(is.na(store$tables$air_raw)), 0)
        expect_equal(sum(is.na(store$tables$air_clean)), 0)
        expect_true(any(ig_log_records(store$tasks)$level == "WARN"))
      }
      if (info$id == "fuel-economy") {
        expect_s3_class(store$objects$mpg_model_model$value, "lm")
        expect_equal(nrow(store$tables$mpg_model_augment), 32)
      }
      order <- store_topo_order(store$tasks, store$task_order)
      expect_identical(utils::tail(order, 1), "example_log")
      for (id in order) expect_true(isTRUE(run_task_from_store(store, id)), info = paste(info$id, id))
      records <- ig_log_records(store$tasks, store$tasks$example_log$params$after_tasks)
      exported <- store$tasks$example_log$export_file
      if (info$id == "iris") expect_match(paste(readLines(exported), collapse = "\n"), "Loaded 150 iris observations")
      if (info$id == "air-quality") expect_equal(nrow(jsonlite::fromJSON(exported)), nrow(records))
      if (info$id == "fuel-economy") expect_equal(nrow(utils::read.csv(exported)), nrow(records))
      saved <- file.path(prepared$directory, "Saved copy.igpx")
      project_save(store, saved)
      another <- make_store(); on.exit(project_release_assets(another), add = TRUE)
      expect_true(project_load(another, saved)$ok)
      expect_equal(another$tables[[source]], expected)
      expect_true(file.exists(another$tasks$example_report$outputs[[1]]$path))
    })
    independent <- ig_prepare_example(info$id)
    expect_false(identical(independent$directory, prepared$directory))
    expect_true(file.exists(prepared$path))
  }
  expect_error(ig_prepare_example("../iris"), "Unknown")
  expect_error(ig_prepare_example(NA_character_), "Choose")
})

test_that("the example catalogue covers every enabled task with honest metadata", {
  catalog <- ig_example_catalog()
  expect_gte(length(catalog), 20L)
  expect_false(anyDuplicated(vapply(catalog, `[[`, character(1), "id")) > 0L)
  expect_setequal(unique(unlist(lapply(catalog, `[[`, "task_types"))), IG_ENABLED_TASK_IDS)
  for (info in catalog) {
    expect_true(all(nzchar(c(info$title, info$description, info$learn, info$source))))
    expect_true(all(info$task_types %in% IG_ENABLED_TASK_IDS))
  }
})

test_that("expanded projects rerun offline and retain reports, inputs and audit exports", {
  withr::local_envvar(IG_USER_DATA = tempfile("expanded-profile-"))
  withr::local_options(ig.examples_dir = tempfile("expanded-examples-"), ig.background_workers = 0L)
  catalog <- Filter(function(x) !x$id %in% c("iris", "air-quality", "fuel-economy"), ig_example_catalog())
  for (info in catalog) {
    prepared <- ig_prepare_example(info$id)
    store <- make_store(); on.exit(project_release_assets(store), add = TRUE)
    expect_true(project_load(store, prepared$path)$ok, info = info$id)
    isolate({
      expect_true(setequal(unique(vapply(store$tasks, `[[`, character(1), "type")), info$task_types), info = info$id)
      expect_true(all(vapply(store$tasks, function(task) identical(task$status, "success"), logical(1))), info = info$id)
      expect_true(any(ig_log_records(store$tasks)$event == "custom"), info = info$id)
      report <- store$tasks$example_report$outputs[[1]]$path
      expect_true(file.exists(report), info = info$id)
      expect_match(paste(readLines(report, warn = FALSE), collapse = "\n"), "Pipeline execution log", fixed = TRUE)
      # Replay the real flow, letting the loop execute its own body once per group.
      body <- character()
      for (id in store_topo_order(store$tasks, store$task_order)) {
        if (id %in% body) next
        expect_true(isTRUE(run_task_from_store(store, id)), info = paste(info$id, id, store$tasks[[id]]$error_msg))
        if (identical(store$tasks[[id]]$type, "loop")) body <- c(body, store$tasks[[id]]$loop_body_ids)
      }
      for (task in Filter(function(task) task$type %in% c("export", "export_log"), store$tasks)) {
        expect_true(startsWith(task$export_file, prepared$directory), info = info$id)
        expect_true(file.info(task$export_file)$size > 0, info = info$id)
      }
      if (info$id == "data-cleaning") {
        expect_equal(nrow(store$tables$cars), 33L)
        expect_equal(nrow(store$tables$analysis_cars), 32L)
        expect_s3_class(store$tables$analysis_cars$transmission, "factor")
      }
      if (info$id == "query-joins") {
        expect_true(file.exists(store$tasks$example_import$params$path))
        expect_equal(nrow(store$tables$states), 50L)
        expect_true(all(store$tables$high_income$Income >= 4500))
        expect_true(all(diff(store$tables$high_income$Income) <= 0))
        expect_false(anyNA(store$tables$state_regions$region))
      }
      if (info$id == "looping") {
        expect_equal(store$tasks$example_loop$loop_completed_iterations, 3L)
        iteration_logs <- ig_log_records(store$tasks, "example_iteration")
        expect_length(unique(iteration_logs$iteration), 3L)
        expect_true(all(paste0("species_summary_", 1:3) %in% names(store$tables)))
        expect_equal(vapply(store$tables[paste0("species_summary_", 1:3)], function(x) x$n, integer(1)), rep(50L, 3), ignore_attr = TRUE)
      }
      if (info$id == "report-audit") {
        logs <- utils::read.csv(store$tasks$example_log$export_file)
        expect_true(any(logs$task_id == "example_report" & logs$event == "success"))
        expect_true(any(logs$level == "WARN"))
        expect_true(all(c("txt", "csv", "json") %in% tools::file_ext(list.files(prepared$directory))))
      }
      saved <- file.path(prepared$directory, "rerun-copy.igpx")
      project_save(store, saved)
      restored <- make_store(); on.exit(project_release_assets(restored), add = TRUE)
      expect_true(project_load(restored, saved)$ok, info = info$id)
      expect_true(file.exists(restored$tasks$example_report$outputs[[1]]$path), info = info$id)
      if (info$id == "query-joins") expect_true(file.exists(restored$tasks$example_import$params$path))
    })
  }
})

test_that("Help protects unsaved work and opens a writable example", {
  withr::local_envvar(IG_USER_DATA = tempfile("help-example-profile-"))
  withr::local_options(ig.examples_dir = tempfile(), ig.recovery_dir = tempfile(), ig.catalogue_dir = tempfile())
  shiny::testServer(app_server, {
    root <- session$rootScope(); recovery_pending(FALSE)
    store$tables <- list(own_data = data.frame(x = 7)); store$dirty <- TRUE
    session$setInputs(help_example = "iris"); root$flushReact()
    expect_identical(pending_example(), "iris")
    expect_true("own_data" %in% names(store$tables))
    session$setInputs(example_cancel = 1); root$flushReact()
    expect_null(pending_example()); expect_true("own_data" %in% names(store$tables))
    session$setInputs(help_example = "iris"); root$flushReact()
    session$setInputs(example_discard = 1); root$flushReact()
    expect_true("flowers" %in% names(store$tables)); expect_false("own_data" %in% names(store$tables))
    expect_null(store$project_path); expect_true(store$dirty)
    expect_identical(store$project_name, "Iris exploration")
    path <- store$tasks$example_csv$export_file
    store$run_ids <- "busy"
    expect_false(open_example_project("air-quality"))
    expect_identical(store$tasks$example_csv$export_file, path)
    store$run_ids <- character()
    expect_false(open_example_project("../iris"))
    expect_true("flowers" %in% names(store$tables))
  })
})
