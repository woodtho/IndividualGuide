# Fresh-process runtime profiling. Invoke using the private Rscript, not the
# developer library; compare eager dependency loading with the app's normal
# namespace loading. Native extraction is measured separately by the EXE test.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
runtime <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
mode <- args[[2]]
output <- normalizePath(args[[3]], winslash = "/", mustWork = FALSE)
Sys.setlocale("LC_CTYPE", ".UTF-8")
.libPaths(file.path(runtime, "R/library"), include.site = FALSE)
Sys.setenv(RSTUDIO_PANDOC = file.path(runtime, "pandoc"))
started <- proc.time()
manifest <- read.csv(file.path(runtime, "packages.csv"), stringsAsFactors = FALSE)
stopifnot(all(file.exists(file.path(runtime, "R/library", manifest$Package, "DESCRIPTION"))))
for (package in if (mode == "eager") manifest$Package else "IndividualGuide") loadNamespace(package)
loaded <- proc.time()
ui <- getFromNamespace("app_ui", "IndividualGuide")()
html <- htmltools::renderTags(ui)
ready <- proc.time()
stopifnot(nchar(html$html) > 10000L)
namespaces <- loadedNamespaces()
memory <- suppressWarnings(as.numeric(system2(file.path(Sys.getenv("SystemRoot"), "System32/WindowsPowerShell/v1.0/powershell.exe"),
  c("-NoProfile", "-Command", shQuote(sprintf("(Get-Process -Id %d).WorkingSet64", Sys.getpid()))), stdout = TRUE)))
result <- data.frame(mode = mode, namespace_s = (loaded - started)[["elapsed"]],
  ui_s = (ready - loaded)[["elapsed"]], total_s = (ready - started)[["elapsed"]],
  cpu_s = sum((ready - started)[c("user.self", "sys.self")]),
  namespaces = length(namespaces), resident_bytes = memory[[1L]])
write.csv(result, output, row.names = FALSE)
print(result)
