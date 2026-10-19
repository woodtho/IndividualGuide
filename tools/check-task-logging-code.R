# Generate and execute log-export pipelines in a fresh R process that has never
# loaded IndividualGuide, so an attached development namespace cannot mask a
# missing generated helper.
Sys.setlocale("LC_CTYPE", ".UTF-8")
pkgload::load_all(quiet = TRUE)
root <- file.path("artifacts/audit", paste0("logging-standalone-", format(Sys.time(), "%Y%m%d-%H%M%S")))
dir.create(root, recursive = TRUE)
root <- normalizePath(root, winslash = "/")
store <- make_store(); flow <- make_flow("Standalone log export")
store$flows <- setNames(list(flow), flow$id); store$active_flow <- flow$id
p <- default_loop_params("repeat"); p$values <- "a\nb"
task <- task_def("repeat", "loop", output = "", params = p); task$outputs <- loop_output_specs(p)
shiny::isolate(store_set_task(store, task))
task <- task_def("step", "script", params = list(code = "cat('console'); log_event(paste('item', item))"))
task$logging$rules <- list(list(id = "checkpoint", event = "custom", level = "WARN", enabled = TRUE, template = "{message}"))
task$control_inputs <- p$output_token; shiny::isolate(store_set_task(store, task))
p <- default_export_log_params(); p$after_tasks <- "step"; p$format <- "csv"; p$overwrite <- TRUE
p$path <- file.path(root, "{item}.csv")
task <- task_def("log", "export_log", output = "", params = p)
task$control_inputs <- shiny::isolate(store$tasks[["repeat"]])$params$output_token
shiny::isolate(store_set_task(store, task))
script <- file.path(root, "pipeline.R")
writeLines(c(shiny::isolate(build_full_r_script(store)),
  "stopifnot(!'package:IndividualGuide' %in% search(), .task_status$log == 'success')",
  ".export_messages <- vapply(.ig_task_logs$tasks$log$log_events, `[[`, character(1), 'message')",
  "stopifnot(any(grepl('a.csv', .export_messages, fixed = TRUE)), any(grepl('b.csv', .export_messages, fixed = TRUE)), !any(grepl('{item}', .export_messages, fixed = TRUE)))"), script)
Rscript <- file.path(R.home("bin"), "Rscript.exe")
result <- system2(Rscript, c("--vanilla", shQuote(script)), stdout = TRUE, stderr = TRUE)
writeLines(result, file.path(root, "runtime.log"))
if (!is.null(attr(result, "status"))) stop(paste(result, collapse = "\n"))
stopifnot("item a" %in% utils::read.csv(file.path(root, "a.csv"))$message,
  "item b" %in% utils::read.csv(file.path(root, "b.csv"))$message,
  all(utils::read.csv(file.path(root, "b.csv"))$level == "WARN"))
cat("Standalone R process: per-iteration log export passed. Artifacts:", root, "\n")
