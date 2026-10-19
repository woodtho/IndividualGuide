test_that("task logs capture custom entries, conditions and console before failure", {
  store <- new_test_store()
  task <- task_def("script", "script", params = list(code = paste(
    "cat('before error\\n')", "log_event('checkpoint', 'WARN')",
    "message('progress')", "warning('watch out')", "stop('broken')", sep = "; ")))
  task$logging$min_level <- "DEBUG"
  shiny::isolate(store_set_task(store, task))
  previous <- getOption("IndividualGuide.log_callback")
  expect_warning(expect_message(expect_false(shiny::isolate(run_task_from_store(store, "script"))), "progress"), "watch out")
  logs <- shiny::isolate(ig_log_records(store$tasks))
  expect_true(all(c("start", "custom", "message", "warning", "console", "error") %in% logs$event))
  expect_true(any(grepl("before error", logs$message)))
  expect_true(any(logs$level == "ERROR" & logs$message == "broken"))
  expect_identical(getOption("IndividualGuide.log_callback"), previous)
  expect_equal(length(unique(logs$run_id)), 1L)
  expect_true(all(logs$elapsed_seconds >= 0))
})

test_that("logging controls filter severity and do not invalidate successful results", {
  store <- new_test_store()
  task <- task_def("task", "script", params = list(code = "log_event('info'); log_event('alert', 'ERROR')"))
  task$logging$min_level <- "ERROR"
  shiny::isolate(store_set_task(store, task))
  expect_true(shiny::isolate(run_task_from_store(store, "task")))
  logs <- shiny::isolate(ig_log_records(store$tasks))
  expect_equal(logs$message, "alert")
  task <- shiny::isolate(store$tasks$task)
  task$logging$enabled <- FALSE
  shiny::isolate(store_set_task(store, task))
  expect_equal(shiny::isolate(store$tasks$task$status), "success")
  expect_true(shiny::isolate(run_task_from_store(store, "task")))
  expect_equal(nrow(shiny::isolate(ig_log_records(store$tasks))), 1L)
  task <- shiny::isolate(store$tasks$task)
  task$logging <- ig_logging_config(list(min_level = "DEBUG", console = FALSE,
    start_message = "Begin {task} ({type}) {status}", success_message = "Finished {task}: {status}"))
  task$params$code <- "cat('hidden console'); log_event('retained')"
  shiny::isolate(store_set_task(store, task))
  expect_true(shiny::isolate(run_task_from_store(store, "task")))
  logs <- shiny::isolate(ig_log_records(store$tasks))
  expect_true("Begin task (script) running" %in% logs$message)
  expect_true("Finished task: success" %in% logs$message)
  expect_false(any(logs$event == "console"))
})

test_that("panel runners and skipped dependencies are logged", {
  store <- new_test_store()
  task <- task_def("task", "script")
  shiny::isolate(store_set_task(store, task))
  ok <- shiny::isolate(store_run_guarded(store, function() {
    cat("panel output\n")
    ig_log_event("panel entry")
    task <- shiny::isolate(store$tasks$task)
    task$run_time <- Sys.time(); store_set_task(store, task)
    TRUE
  }, task_id = "task"))
  expect_true(ok)
  expect_equal(shiny::isolate(ig_log_records(store$tasks))$event, c("start", "custom", "success"))
  bad <- task_def("bad", "script", output = "failed", params = list(code = "stop('failure')"))
  shiny::isolate(store_set_task(store, bad))
  shiny::isolate(run_task_from_store(store, "bad"))
  consumer <- task_def("consumer", "script", inputs = "failed")
  shiny::isolate(store_set_task(store, consumer))
  expect_false(shiny::isolate(run_task_from_store(store, "consumer")))
  expect_true("skipped" %in% shiny::isolate(ig_log_records(store$tasks, "consumer"))$event)
})

test_that("log exports run after failed tasks and write all three formats safely", {
  store <- new_test_store()
  task <- task_def("bad", "script", params = list(code = "stop('broken')"))
  shiny::isolate(store_set_task(store, task)); shiny::isolate(run_task_from_store(store, "bad"))
  directory <- tempfile(); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  for (format in c("txt", "csv", "json")) {
    p <- default_export_log_params(); p$after_tasks <- "bad"; p$format <- format
    p$path <- file.path(directory, paste0("pipeline.", format))
    export <- task_def("log", "export_log", output = "", params = p)
    shiny::isolate(store_set_task(store, export))
    expect_equal(shiny::isolate(store_topo_order(store$tasks, c("log", "bad"))), c("bad", "log"))
    expect_true(shiny::isolate(run_task_from_store(store, "log")))
    expect_true(file.exists(p$path))
    expect_match(paste(readLines(p$path, warn = FALSE), collapse = "\n"), "broken")
    expect_false(shiny::isolate(run_task_from_store(store, "log")))
    expect_match(shiny::isolate(store$tasks$log$error_msg), "already exists")
    expect_match(paste(readLines(p$path, warn = FALSE), collapse = "\n"), "broken")
  }
  expect_match(execute_export_log(list(path = ""))$error, "destination")
  expect_match(execute_export_log(list(path = file.path(directory, "empty"), format = "invalid"))$error, "format")
})

test_that("logs and logging settings survive save/load and copied flows reset events", {
  store <- new_test_store()
  task <- task_def("task", "script", params = list(code = "log_event('saved entry')"))
  task$logging$start_message <- "Custom start"
  shiny::isolate(store_set_task(store, task)); shiny::isolate(run_task_from_store(store, "task"))
  p <- default_export_log_params(); p$after_tasks <- "task"
  shiny::isolate(store_set_task(store, task_def("log", "export_log", output = "", params = p)))
  path <- tempfile(fileext = ".igpx"); on.exit(unlink(path))
  shiny::isolate(project_save(store, path))
  restored <- new_test_store(); shiny::isolate(project_load(restored, path))
  expect_equal(shiny::isolate(restored$tasks$task$logging$start_message), "Custom start")
  expect_true("saved entry" %in% shiny::isolate(ig_log_records(restored$tasks))$message)
  copied <- shiny::isolate(store_copy_flow(restored, restored$active_flow))
  expect_true(is.character(copied))
  expect_length(shiny::isolate(ig_log_records(restored$flows[[copied]]$tasks))$message, 0L)
  copied_tasks <- shiny::isolate(restored$flows[[copied]]$tasks)
  export <- Filter(function(task) task$type == "export_log", copied_tasks)[[1]]
  expect_true(export$params$after_tasks %in% names(copied_tasks))
  expect_false(export$params$after_tasks == "task")
})

test_that("generated pipelines collect custom logs and export after failures", {
  store <- new_test_store()
  directory <- tempfile(); dir.create(directory); on.exit(unlink(directory, recursive = TRUE))
  task <- task_def("task", "script", params = list(code = "cat('printed'); log_event('from code'); stop('failed code')"))
  task$logging$min_level <- "DEBUG"
  shiny::isolate(store_set_task(store, task))
  p <- default_export_log_params(); p$after_tasks <- "task"
  p$path <- file.path(directory, "generated.csv"); p$format <- "csv"
  shiny::isolate(store_set_task(store, task_def("log", "export_log", output = "", params = p)))
  code <- shiny::isolate(build_full_r_script(store))
  env <- new.env(parent = globalenv())
  expect_warning(eval(parse(text = code), env), "failed code")
  expect_equal(env$.task_status$log, "success")
  data <- utils::read.csv(p$path)
  expect_true(all(c("printed", "from code", "failed code") %in% data$message))
})

test_that("loop iterations retain logs and a final export waits outside the body", {
  store <- new_test_store()
  p <- default_loop_params("repeat"); p$values <- "a\nb"
  loop <- task_def("repeat", "loop", output = "", params = p); loop$outputs <- loop_output_specs(p)
  shiny::isolate(store_set_task(store, loop))
  script <- task_def("step", "script", params = list(code = "log_event(paste('item', item))"))
  script$control_inputs <- p$output_token
  shiny::isolate(store_set_task(store, script))
  path <- tempfile(fileext = ".json"); on.exit(unlink(path))
  p <- default_export_log_params(); p$path <- path; p$format <- "json"; p$after_tasks <- c("repeat", "step")
  shiny::isolate(store_set_task(store, task_def("log", "export_log", output = "", params = p)))
  expect_true(shiny::isolate(run_task_from_store(store, "repeat")))
  expect_false("log" %in% shiny::isolate(store$tasks[["repeat"]]$loop_body_ids))
  logs <- shiny::isolate(ig_log_records(store$tasks, "step"))
  expect_equal(sum(logs$event == "custom"), 2L)
  expect_equal(length(unique(logs$iteration)), 2L)
  expect_true(shiny::isolate(run_task_from_store(store, "log")))
  expect_true(all(c("item a", "item b") %in% jsonlite::read_json(path, simplifyVector = TRUE)$message))
  p$overwrite <- TRUE
  task <- shiny::isolate(store$tasks$log); task$params <- p; shiny::isolate(store_set_task(store, task))
  env <- new.env(parent = globalenv())
  eval(parse(text = shiny::isolate(build_full_r_script(store))), env)
  expect_equal(sum(jsonlite::read_json(path, simplifyVector = TRUE)$event == "custom"), 2L)
})

test_that("retention is bounded and branch-pruned tasks leave an explanation", {
  store <- new_test_store()
  task <- task_def("many", "script", params = list(code = "for (i in 1:1005) log_event(paste('entry', i))"))
  shiny::isolate(store_set_task(store, task))
  expect_true(shiny::isolate(run_task_from_store(store, "many")))
  logs <- shiny::isolate(ig_log_records(store$tasks))
  expect_equal(nrow(logs), 1000L)
  expect_true("entry 1005" %in% logs$message)
  expect_false("entry 1" %in% logs$message)
  p <- default_branch_params("gate")
  branch <- task_def("branch", "branch", output = "", params = p)
  branch$outputs <- branch_output_specs(p)
  branch$branch_decision <- list(matched_tokens = character(0), skipped_tokens = branch$outputs[[1]]$name)
  shiny::isolate(store_set_task(store, branch))
  consumer <- task_def("pruned", "script", inputs = branch$outputs[[1]]$name)
  shiny::isolate(store_set_task(store, consumer))
  shiny::isolate(store_apply_branch_decision(store, "branch"))
  logs <- shiny::isolate(ig_log_records(store$tasks, "pruned"))
  expect_true(any(logs$event == "skipped" & grepl("Inactive branch path", logs$message)))
})

test_that("exports on loop paths use per-iteration destinations and retain the last download", {
  store <- new_test_store()
  p <- default_loop_params("repeat"); p$values <- "a\nb"
  loop <- task_def("repeat", "loop", output = "", params = p); loop$outputs <- loop_output_specs(p)
  shiny::isolate(store_set_task(store, loop))
  script <- task_def("step", "script", params = list(code = "log_event(paste('item', item))"))
  script$control_inputs <- p$output_token; shiny::isolate(store_set_task(store, script))
  directory <- tempfile(); dir.create(directory); on.exit(unlink(directory, recursive = TRUE))
  p <- default_export_log_params(); p$after_tasks <- "step"; p$format <- "csv"; p$overwrite <- TRUE
  p$path <- file.path(directory, "{item}.csv")
  task <- task_def("log", "export_log", output = "", params = p)
  task$control_inputs <- loop$params$output_token; shiny::isolate(store_set_task(store, task))
  expect_true(shiny::isolate(run_task_from_store(store, "repeat")))
  expect_match(shiny::isolate(store$tasks$log$export_file), "b[.]csv$")
  expect_true("item a" %in% utils::read.csv(file.path(directory, "a.csv"))$message)
  expect_true("item b" %in% utils::read.csv(file.path(directory, "b.csv"))$message)
  env <- new.env(parent = globalenv())
  eval(parse(text = shiny::isolate(build_full_r_script(store))), env)
  expect_equal(env$.task_status$log, "success")
  expect_true("item b" %in% utils::read.csv(file.path(directory, "b.csv"))$message)
})
