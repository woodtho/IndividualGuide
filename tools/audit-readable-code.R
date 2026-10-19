Sys.setlocale("LC_CTYPE", ".UTF-8")
Sys.setenv(LC_ALL = "English_Canada.utf8", LANG = "English_Canada.utf8")
pkgload::load_all(quiet = TRUE)
source("tools/code-readability-fixtures.R")
root <- normalizePath("artifacts/review", winslash = "/")
destination <- file.path(root, "code-after")
dir.create(destination, recursive = TRUE, showWarnings = FALSE)
fixtures <- code_readability_fixtures(root)
RNGkind("L'Ecuyer-CMRG")
options(contrasts = c("contr.sum", "contr.poly"), na.action = "na.exclude")
scripts <- lapply(fixtures$tasks, build_task_code)
scripts$pipeline <- shiny::isolate(build_full_r_script(fixtures$pipeline))
scripts$loop <- shiny::isolate(build_full_r_script(fixtures$loop))
scripts$edge <- shiny::isolate(build_full_r_script(fixtures$edge))
metrics <- do.call(rbind, lapply(names(scripts), function(name) {
  writeLines(scripts[[name]], file.path(destination, paste0(name, ".R")), useBytes = TRUE)
  data.frame(example = name, lines = length(strsplit(scripts[[name]], "\n", fixed = TRUE)[[1L]]), bytes = nchar(scripts[[name]], type = "bytes"))
}))
jsonlite::write_json(metrics, file.path(destination, "metrics.json"), dataframe = "rows", pretty = TRUE)
print(metrics)
bundle_metrics <- do.call(rbind, lapply(c("pipeline", "loop", "edge"), function(name) {
  parts <- code_pipeline_files(scripts[[name]])
  directory <- file.path(destination, paste0(name, " bundle Ω"))
  dir.create(directory, showWarnings = FALSE)
  ig_write_code_bundle(scripts[[name]], file.path(directory, "export.zip"))
  zip::unzip(file.path(directory, "export.zip"), exdir = directory)
  data.frame(example = name, main_lines = length(strsplit(parts$pipeline, "\n", fixed = TRUE)[[1L]]),
    main_bytes = nchar(parts$pipeline, type = "bytes"), support_bytes = nchar(parts$support, type = "bytes"))
}))
jsonlite::write_json(bundle_metrics, file.path(destination, "bundle-metrics.json"), dataframe = "rows", pretty = TRUE)
print(bundle_metrics)
execute <- function(directory, name, mode = "complete") {
  output <- file.path(directory, paste0(name, "-", mode, "-result.rds"))
  source <- if (mode == "complete") readLines(file.path(directory, paste0(name, ".R")), warn = FALSE) else
    readLines(file.path(directory, paste0(name, " bundle Ω"), "pipeline.R"), warn = FALSE)
  result <- switch(name,
    pipeline = "list(summary = summary, sampled = sampled, coefficients = coefficients, fit = coefficients_glance, points = points, plot_class = class(points_plot), status = .task_status)",
    loop = "list(first = multiply_2, second = multiply_3, status = .task_status)",
    edge = "list(raw = .pipeline, summary = `summary Ω`, sampled = `sample Ω`, coefficients = `model Ω`, fit = `model Ω_glance`, status = .task_status)")
  file <- if (mode == "complete") file.path(directory, paste0(name, "-run.R")) else
    file.path(directory, paste0(name, " bundle Ω"), paste0("pipeline-", mode, ".R"))
  writeLines(c(source, "stopifnot(!'IndividualGuide' %in% loadedNamespaces())",
    "stopifnot(all(vapply(.task_status, identical, logical(1), 'success')))",
    paste0("saveRDS(", result, ", ", code_literal(output), ")")), file, useBytes = TRUE)
  if (mode == "source") {
    wrapper <- file.path(directory, paste0(name, "-source.R"))
    writeLines(paste0("source(", code_literal(file), ", local = new.env(parent = globalenv()))"), wrapper, useBytes = TRUE)
    file <- wrapper
  }
  old <- getwd(); on.exit(setwd(old), add = TRUE)
  setwd(tempdir())
  runtime <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript.exe"), c("--vanilla", shQuote(file)), stdout = TRUE, stderr = TRUE))
  writeLines(runtime, file.path(directory, paste0(name, "-", mode, "-run.log")))
  if (!is.null(attr(runtime, "status"))) stop(paste(runtime, collapse = "\n"))
  readRDS(output)
}
baseline <- list()
for (name in c("pipeline", "loop", "edge")) {
  before <- if (name == "edge") simpleError("Additional edge-case fixture; no baseline captured.") else
    tryCatch(execute(file.path(root, "code-before"), name), error = function(e) e)
  after <- execute(destination, name)
  for (mode in c("cli", "source")) stopifnot(isTRUE(all.equal(after, execute(destination, name, mode), tolerance = 1e-12)))
  if (!inherits(before, "error")) {
    stopifnot(isTRUE(all.equal(before, after, tolerance = 1e-12)))
    baseline[[name]] <- list(ok = TRUE, matches = TRUE)
  } else {
    baseline[[name]] <- list(ok = FALSE, error = conditionMessage(before))
    cat("Baseline execution defect captured:", name, "\n")
  }
  store <- fixtures[[name]]
  ids <- if (name == "loop") c("source", "repeat") else shiny::isolate(store$task_order)
  for (id in ids) stopifnot(isTRUE(shiny::isolate(run_task_from_store(store, id))))
  expected <- if (name == "pipeline") shiny::isolate(list(summary = store$tables$summary,
    sampled = store$tables$sampled, coefficients = store$tables$coefficients,
    fit = store$tables$coefficients_glance, points = store$tables$points,
    plot_class = class(store$objects$points_plot$value), status = lapply(store$tasks, `[[`, "status"))) else if (name == "loop")
    shiny::isolate(list(first = store$tables$multiply_2, second = store$tables$multiply_3, status = lapply(store$tasks, `[[`, "status")))
    else shiny::isolate(list(raw = store$tables[[".pipeline"]], summary = store$tables[["summary Ω"]],
      sampled = store$tables[["sample Ω"]], coefficients = store$tables[["model Ω"]],
      fit = store$tables[["model Ω_glance"]], status = lapply(store$tasks, `[[`, "status")))
  stopifnot(isTRUE(all.equal(expected, after, tolerance = 1e-12)))
  cat("Fresh-process/app execution parity:", name, "passed.\n")
}
jsonlite::write_json(list(ok = TRUE, freshProcess = TRUE, appNamespaceLoaded = FALSE,
  bundleCliAndSource = TRUE, differentWorkingDirectory = TRUE, unicodeBundlePath = TRUE,
  examples = c("pipeline", "loop", "edge"), customRngAndContrasts = TRUE,
  nonstandardNamesAndMissingValues = TRUE, baseline = baseline, tolerance = 1e-12), file.path(root, "code-parity.json"), auto_unbox = TRUE, pretty = TRUE)
