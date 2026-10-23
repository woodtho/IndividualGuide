# Ship the installed R version's complete options reference even though the
# desktop strips help databases. Reference text retains R's documentation license.
Sys.setlocale("LC_CTYPE", ".UTF-8")
rd <- utils:::.getHelpFile(utils::help("options", package = "base"))
entries <- list()
text <- function(node) {
  rendered <- capture.output(tools::Rd2txt(structure(node, class = "Rd"), out = "",
    fragment = TRUE, options = list(width = 10000L)))
  trimws(gsub("[[:space:]]+", " ", paste(rendered, collapse = " ")))
}
walk <- function(node) {
  if (identical(attr(node, "Rd_tag"), "\\item")) {
    label <- trimws(gsub("[[:space:]]+", " ", paste(unlist(node[[1L]]), collapse = "")))
    if (grepl(":$", label)) {
      for (name in trimws(strsplit(sub(":$", "", label), ",", fixed = TRUE)[[1L]])) {
        if (grepl("^[A-Za-z][A-Za-z0-9._]*$", name))
          entries[[name]] <<- list(name = name, description = substr(text(node[[2L]]), 1L, 2000L))
      }
    }
    return(invisible(NULL))
  }
  if (is.list(node)) for (child in node) walk(child)
}
walk(rd)
stopifnot(length(entries) > 100L)
path <- "inst/options/r-options.json"
dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(list(R = as.character(getRversion()),
  source = "R Core Team, base::options reference, https://stat.ethz.ch/R-manual/R-release/library/base/html/options.html",
  license = "Reference text: GPL-2 | GPL-3, copyright R Core Team. See R's COPYING file and https://www.r-project.org/Licenses/.",
  license_file = "R-COPYING",
  options = unname(entries[order(names(entries))])), path, auto_unbox = TRUE, pretty = TRUE)
stopifnot(file.copy(file.path(R.home(), "COPYING"), "inst/options/R-COPYING", overwrite = TRUE))
cat(length(entries), "documented R options written to", path, "\n")
