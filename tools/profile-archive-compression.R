# Compression experiment, independent of app code and without touching projects.
Sys.setlocale("LC_CTYPE", ".UTF-8")
out <- "artifacts/performance/responsiveness"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
root <- tempfile("ig-compression-"); dir.create(root)
main <- function() {
  on.exit(unlink(root, recursive = TRUE))
  data <- as.data.frame(setNames(lapply(1:12, function(i) sin(seq_len(200000L) / i)), paste0("c", 1:12)))
  saveRDS(data, file.path(root, "data.rds"), compress = FALSE)
  rows <- list()
  for (trial in 1:3) for (level in c(9L, 1L)) {
    path <- tempfile(tmpdir = root, fileext = ".zip")
    time <- system.time(zip::zipr(path, "data.rds", root = root, compression_level = level))[["elapsed"]]
    restored <- tempfile(tmpdir = root); dir.create(restored)
    zip::unzip(path, exdir = restored)
    stopifnot(identical(data, readRDS(file.path(restored, "data.rds"))))
    rows[[length(rows) + 1L]] <- data.frame(trial = trial, level = level, elapsed_s = time, bytes = file.info(path)$size)
  }
  result <- do.call(rbind, rows)
  write.csv(result, file.path(out, "compression.csv"), row.names = FALSE)
  print(result)
}
main()
