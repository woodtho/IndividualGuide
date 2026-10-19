# readr edition 2 always recognises quoted NA markers. The existing opt-out
# requires edition 1; restore the selection/id/name-repair options it lacks.
ig_read_legacy_csv <- function(args) {
  select <- args$col_select
  id <- args$id
  repair <- args$name_repair
  legacy <- args[setdiff(names(args), c("col_select", "id", "name_repair", "num_threads", "lazy"))]
  value <- withCallingHandlers(readr::with_edition(1, do.call(readr::read_delim, legacy)),
    warning = function(warning) {
      # The requested name repair below replaces edition 1's intermediate
      # deduplication. Keep every parsing warning, but avoid reporting a rename
      # that is immediately undone for explicit minimal/check_unique repair.
      if (!is.null(repair) && startsWith(conditionMessage(warning), "Duplicated column names deduplicated:"))
        invokeRestart("muffleWarning")
    })
  if (!is.null(repair)) {
    if (isTRUE(legacy$col_names)) {
      header_args <- legacy
      header_args$col_names <- FALSE
      header_args$col_types <- readr::cols(.default = readr::col_character())
      header_args$na <- character(0)
      header_args$n_max <- 1L
      header <- readr::with_edition(1, do.call(readr::read_delim, header_args))
      if (nrow(header) && ncol(header) == ncol(value)) names(value) <- as.character(unlist(header[1, ], use.names = FALSE))
    }
    names(value) <- vctrs::vec_as_names(names(value), repair = repair)
  }
  if (!is.null(select)) value <- dplyr::select(value, dplyr::all_of(select))
  if (!is.null(id)) {
    value <- as.data.frame(value)
    value[[id]] <- rep(args$file, nrow(value))
    value <- value[c(id, setdiff(names(value), id))]
  }
  value
}
