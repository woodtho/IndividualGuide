# Exercise every bundled runtime check before spending time compressing an EXE.
args <- commandArgs(TRUE)
stopifnot(length(args) == 2L)
runtime <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
state <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
.libPaths(file.path(runtime, "R/library"), include.site = FALSE)
stop <- file.path(state, "stop-after-checks")
writeLines("stop", stop)
Sys.setenv(IG_RUNTIME_DIR = runtime, IG_USER_DATA = state, IG_WORK_DIR = state,
  IG_SMOKE_TEST = "1", IG_RUNTIME_RESULT = file.path(state, "runtime.json"),
  IG_STOP_FILE = stop, IG_PORT = as.character(httpuv::randomPort()), IG_DESKTOP_TOKEN = "")
source(file.path(runtime, "startup.R"), encoding = "UTF-8")
result <- jsonlite::read_json(file.path(state, "runtime.json"))
stopifnot(identical(normalizePath(result$r_home), normalizePath(file.path(runtime, "R"))))
stopifnot(all(c("backgroundAnalysis", "projectSeed", "arrow", "sqlite", "duckdb", "forecast", "plot", "pandoc") %in% names(result$checks)), all(unlist(result$checks)))
