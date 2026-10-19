Sys.setlocale("LC_CTYPE", ".UTF-8")
pkgload::load_all(quiet = TRUE)
measurements <- list()
profile <- "--profile" %in% commandArgs(trailingOnly = TRUE)
for (n in if (profile) 100L else c(20L, 100L, 500L)) {
  store <- make_store(); flow <- make_flow("Performance audit")
  store$flows <- setNames(list(flow), flow$id); store$active_flow <- flow$id
  store$tables <- list(raw = data.frame(x = seq_len(1000)))
  ids <- paste0("node_", seq_len(n))
  tasks <- setNames(lapply(seq_len(n), function(i) {
    p <- default_first_last_params(paste0("data_", i))
    p$input_table <- if (i == 1L) "raw" else paste0("data_", i - 1L)
    store_task_from_params(task_def(ids[[i]], "first_last_n"), p)
  }), ids)
  store$tasks <- tasks; store$task_order <- ids
  topology <- system.time(order <- store_topo_order(tasks, ids))[["elapsed"]]
  stopifnot(identical(order, ids))
  if (profile) Rprof("artifacts/audit/canvas-profile.out", interval = 0.005)
  canvas <- system.time(network <- shiny::isolate(canvas_build_network(store)))[["elapsed"]]
  if (profile) {
    Rprof(NULL)
    print(head(summaryRprof("artifacts/audit/canvas-profile.out")$by.total, 20L))
  }
  code <- system.time(script <- shiny::isolate(build_full_r_script(store)))[["elapsed"]]
  stopifnot(length(parse(text = script)) > 0)
  path <- tempfile(fileext = ".igpx")
  save <- system.time(project_save(store, path))[["elapsed"]]
  load <- system.time({ restored <- make_store(); project_load(restored, path) })[["elapsed"]]
  stopifnot(length(shiny::isolate(restored$tasks)) == n)
  measurements[[length(measurements) + 1L]] <- data.frame(tasks = n, topology_s = topology,
    canvas_s = canvas, code_s = code, save_s = save, load_s = load,
    task_bytes = as.numeric(object.size(tasks)), code_bytes = nchar(script))
  unlink(path)
}
result <- do.call(rbind, measurements)
print(result)
dir.create(file.path("artifacts", "audit"), recursive = TRUE, showWarnings = FALSE)
write.csv(result, file.path("artifacts", "audit", if (profile) "performance-profile.csv" else "performance.csv"), row.names = FALSE)
