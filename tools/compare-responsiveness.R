args <- commandArgs(TRUE)
stopifnot(length(args) == 1L)
label <- args[[1L]]
base <- file.path("artifacts/performance", paste0(label, "-before"))
after <- file.path("artifacts/performance", paste0(label, "-after"))
out <- file.path("artifacts/performance/responsiveness", label)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
metadata <- jsonlite::read_json(file.path(out, "metadata.json"), simplifyVector = TRUE)
expected <- c("invalidate_200", "edit_first_200", "pipeline_40", "column_selectors_20",
  "canvas_100_comments_200", "project_save_load_100k", "environment_100", "run_records_20",
  "autosave_100k", "filtered_console_5000")
summarize <- function(directory) {
  timings <- read.csv(file.path(directory, "timings.csv"))
  counts <- table(timings$case)
  stopifnot(setequal(names(counts), expected), all(counts == 3L),
    all(is.finite(timings$elapsed_s)), all(timings$elapsed_s >= 0))
  stopifnot(all(file.exists(file.path(directory, paste0(expected, "-allocations.out")))),
    all(file.exists(file.path(directory, paste0(setdiff(expected, "filtered_console_5000"), "-cpu.out")))))
  times <- stats::aggregate(cbind(elapsed_s, cpu_s) ~ case, timings, median)
  merge(times, read.csv(file.path(directory, "allocations.csv")), by = "case")
}
comparison <- merge(summarize(base), summarize(after), by = "case", suffixes = c("_before", "_after"))
comparison$elapsed_change_percent <- 100 * (comparison$elapsed_s_after / comparison$elapsed_s_before - 1)
comparison$allocation_change_percent <- 100 * (comparison$allocated_bytes_after / comparison$allocated_bytes_before - 1)
write.csv(comparison, file.path(out, "comparison.csv"), row.names = FALSE)
result <- list(backend = comparison, browser = NULL,
  interpretation = "Three-trial medians on this machine; timings are observations, not portable performance guarantees. Profiling and allocations are collected separately from timed trials.")
lines <- c("# Responsiveness comparison", "", result$interpretation, "",
  "| Workload | Before (s) | After (s) | Time change | Allocations change |",
  "|---|---:|---:|---:|---:|")
for (i in seq_len(nrow(comparison))) {
  x <- comparison[i, ]
  lines <- c(lines, sprintf("| %s | %.3f | %.3f | %+.1f%% | %+.1f%% |", x$case,
    x$elapsed_s_before, x$elapsed_s_after, x$elapsed_change_percent, x$allocation_change_percent))
}
paths <- file.path("artifacts/performance/responsiveness", paste0("browser-", label, c("-before", "-after")), "results.json")
if (isTRUE(metadata$browserExecuted)) {
  stopifnot(all(file.exists(paths)))
  browser <- lapply(paths, jsonlite::read_json, simplifyVector = TRUE)
  stopifnot(all(vapply(browser, function(x) isTRUE(x$ok), logical(1))),
    length(browser[[2L]]$gates) > 0L, all(unlist(browser[[2L]]$gates)))
  metrics <- function(x) c(edit_median_ms = median(x$editing$roundtrip_ms), edit_p95_ms = unname(quantile(x$editing$roundtrip_ms, .95)),
    value_change_canvas_builds = x$value_change$canvas_builds,
    edit_canvas_builds = x$editing$canvas_builds,
    collapsed_log_output_messages = sum(grepl("^log_first_1-preview", x$editing$outputs)),
    console_handler_median_ms = median(x$console$handler_ms),
    console_handler_warm_p95_ms = unname(quantile(x$console$handler_ms[-1L], .95)),
    console_frame_median_ms = median(x$console$frame_ms),
    idle_window_ping_p95_ms = unname(quantile(x$autosave$ping_ms, .95)),
    worker_cold_ms = x$worker$cold$elapsed_ms, worker_warm_ms = x$worker$warm$elapsed_ms,
    worker_cold_ping_p95_ms = unname(quantile(x$worker$cold$ping_ms, .95)),
    worker_warm_ping_p95_ms = unname(quantile(x$worker$warm$ping_ms, .95)))
  values <- data.frame(metric = names(metrics(browser[[1L]])), before = metrics(browser[[1L]]), after = metrics(browser[[2L]]), row.names = NULL)
  result$browser <- values; result$browser_gates <- browser[[2L]]$gates
  result$advisory_budgets <- browser[[2L]]$advisory_budgets
  lines <- c(lines, "", "| Browser metric | Before | After |", "|---|---:|---:|")
  lines <- c(lines, vapply(seq_len(nrow(values)), function(i) sprintf("| %s | %.2f | %.2f |", values$metric[[i]], values$before[[i]], values$after[[i]]), character(1)))
  lines <- c(lines, "", "Functional browser gates:", "",
    vapply(names(result$browser_gates), function(name) paste0("- ", name, ": ", if (isTRUE(result$browser_gates[[name]])) "passed" else "FAILED"), character(1)),
    "", "Advisory latency targets (reported even when unmet):", "",
    vapply(names(result$advisory_budgets), function(name) paste0("- ", name, ": ", if (isTRUE(result$advisory_budgets[[name]])) "met" else "not met"), character(1)))
}
if (isTRUE(metadata$autosaveExecuted)) {
  autosave_paths <- file.path("artifacts/performance/responsiveness", paste0("browser-", label, "-autosave-", c("before", "after")), "results.json")
  stopifnot(all(file.exists(autosave_paths)))
  autosave <- lapply(autosave_paths, jsonlite::read_json, simplifyVector = TRUE)
  stopifnot(all(vapply(autosave, function(x) isTRUE(x$ok) && x$autosave$writes_during_window > 0L, logical(1))),
    isTRUE(autosave[[2L]]$gates$no_recovery_graph_build))
  result$autosave <- data.frame(mode = c("before", "after"), writes = vapply(autosave, function(x) x$autosave$writes_during_window, numeric(1)),
    graph_builds = vapply(autosave, function(x) x$autosave$graph_builds, numeric(1)),
    ping_median_ms = vapply(autosave, function(x) median(x$autosave$ping_ms), numeric(1)),
    ping_p95_ms = vapply(autosave, function(x) unname(quantile(x$autosave$ping_ms, .95)), numeric(1)),
    ping_max_ms = vapply(autosave, function(x) max(x$autosave$ping_ms), numeric(1)))
  lines <- c(lines, "", "Dirty recovery window: an edit at window start must be saved by the real timer; the archive is reopened to verify the new value and full table dimensions.", "",
    "| Mode | Actual writes | Graph builds | Ping median / p95 / max (ms) |", "|---|---:|---:|---:|")
  lines <- c(lines, vapply(seq_len(nrow(result$autosave)), function(i) {
    x <- result$autosave[i, ]
    sprintf("| %s | %.0f | %.0f | %.1f / %.1f / %.1f |", x$mode, x$writes, x$graph_builds, x$ping_median_ms, x$ping_p95_ms, x$ping_max_ms)
  }, character(1)))
}
if (isTRUE(metadata$startupExecuted)) {
  startup_paths <- unlist(lapply(c("normal", "eager"), function(mode)
    file.path(out, paste0("startup-", mode, "-", 1:3, ".csv"))))
  stopifnot(all(file.exists(startup_paths)))
  startup <- do.call(rbind, lapply(startup_paths, read.csv))
  stopifnot(nrow(startup) == 6L, all(is.finite(startup$total_s)), all(startup$total_s > 0))
  result$startup <- stats::aggregate(cbind(namespace_s, ui_s, total_s, cpu_s, namespaces, resident_bytes) ~ mode, startup, median)
  result$startup_scope <- "Existing shipped private runtime; namespace/UI construction only, without installer extraction or R-server/browser connection."
  lines <- c(lines, "", "Startup experiment: three fresh private-R processes per mode.",
    result$startup_scope, "", "| Mode | Median namespace/UI total (s) | Namespaces | Resident MiB |", "|---|---:|---:|---:|")
  lines <- c(lines, vapply(seq_len(nrow(result$startup)), function(i) {
    x <- result$startup[i, ]
    sprintf("| %s | %.3f | %.0f | %.1f |", x$mode, x$total_s, x$namespaces, x$resident_bytes / 1024^2)
  }, character(1)))
}
result$ok <- TRUE
jsonlite::write_json(result, file.path(out, "comparison.json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
writeLines(lines, file.path(out, "comparison.md"))
cat(paste(lines, collapse = "\n"), "\n")
