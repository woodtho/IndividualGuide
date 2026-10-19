main <- function() {
  Sys.setlocale("LC_CTYPE", ".UTF-8")
  Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
  pkgload::load_all(quiet = TRUE)
  artifacts <- file.path(normalizePath(".", winslash = "/"), "artifacts", "audit",
    paste0("portable-", format(Sys.time(), "%Y%m%d-%H%M%S")))
  dir.create(artifacts, recursive = TRUE)
  original <- tempfile("ig_portable_"); dir.create(original)
  on.exit(unlink(original, recursive = TRUE), add = TRUE)
  df <- data.frame(x = 1:5, y = c(2, 4, 3, 8, 6))
  plot <- ggplot2::ggplot(df, ggplot2::aes(x, y)) + ggplot2::geom_point()
  widget <- ggiraph::girafe(ggobj = plot)
  p <- list(title = 'Portable "report"', items = list(list(name = "table", render = "datatable"),
    list(name = "figure"), list(name = "widget")))
  ig_report_write_html(p, list(table = df, figure = plot, widget = widget), file.path(original, "report.html"))
  ig_write_plot(widget, file.path(original, "chart.html"), "html")
  stopifnot(all(file.copy(file.path(original, c("report.html", "chart.html")), artifacts)))
  unlink(original, recursive = TRUE)
  browser <- chromote::ChromoteSession$new()
  on.exit(browser$close(), add = TRUE)
  browser$Emulation$setDeviceMetricsOverride(width = 1440, height = 900, deviceScaleFactor = 1, mobile = FALSE)
  errors <- character(0)
  browser$Runtime$enable()
  browser$Runtime$exceptionThrown(callback_ = function(params) {
    errors <<- c(errors, params$exceptionDetails$text)
  }, wait_ = FALSE)
  evaluate <- function(expression) browser$Runtime$evaluate(expression = expression, returnByValue = TRUE)$result$value
  for (file in c("report.html", "chart.html")) {
    path <- normalizePath(file.path(artifacts, file), winslash = "/")
    browser$Page$navigate(url = paste0("file:///", path))
    predicate <- if (file == "report.html") paste0("(() => { const f = Array.from(document.querySelectorAll('iframe'));",
      " const img = document.querySelector('img.figure'); return f.length === 2 && img && img.complete && img.naturalWidth > 0 &&",
      " f.some(x => x.contentDocument && x.contentDocument.querySelector('.dataTables_wrapper,.dt-container')) &&",
      " f.some(x => x.contentDocument && x.contentDocument.querySelector('svg')); })()") else
      "document.querySelector('svg') !== null"
    deadline <- Sys.time() + 30
    repeat {
      if (isTRUE(evaluate(predicate))) break
      if (Sys.time() > deadline) stop("Moved artifact did not render: ", file)
      later::run_now(0.1)
    }
    stopifnot(!length(errors))
    screenshot <- browser$Page$captureScreenshot(format = "png")$data
    writeBin(jsonlite::base64_dec(screenshot), file.path(artifacts, paste0(file, ".png")))
    cat("Moved", file, "rendered with dependencies and no JavaScript exceptions.\n")
  }
  cat("Artifacts:", artifacts, "\n")
}
main()
