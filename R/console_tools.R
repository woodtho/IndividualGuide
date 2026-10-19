# Completion uses names and captured column metadata; it never evaluates the
# expression being typed and never competes with a running console command.
ig_console_completions <- function(prefix, store, state) {
  if (!is.character(prefix) || length(prefix) != 1L || is.na(prefix) || nchar(prefix) > 256L)
    return(list())
  tables <- isolate(store$tables); objects <- isolate(store$objects)
  catalog <- state$symbols %||% list(words = character(), fields = list(), kinds = list())
  quote_name <- function(name) paste(deparse(as.name(name), backtick = TRUE), collapse = "")
  insert_prefix <- ""; kind <- "name"
  if (grepl("::", prefix, fixed = TRUE)) {
    parts <- strsplit(prefix, "::", fixed = TRUE)[[1]]
    package <- parts[[1]]; stem <- if (endsWith(prefix, "::")) "" else parts[[length(parts)]]
    if (!package %in% loadedNamespaces() || length(parts) > 2L) return(list())
    words <- getNamespaceExports(package); insert_prefix <- paste0(package, "::"); kind <- "function"
  } else if (grepl("$", prefix, fixed = TRUE)) {
    split <- regexpr("\\$[^$]*$", prefix)
    source <- substring(prefix, 1L, split - 1L); stem <- substring(prefix, split + 1L)
    plain <- gsub("^`|`$", "", source)
    fields <- lapply(tables[vapply(tables, is.data.frame, logical(1))], function(value) attr(value, "names", exact = TRUE))
    for (name in names(tables)) fields[[paste0(".project$tables$", quote_name(name))]] <- if (is.data.frame(tables[[name]])) attr(tables[[name]], "names", exact = TRUE) else character()
    fields[[".project$tables"]] <- names(tables); fields[[".project$objects"]] <- names(objects)
    # Project data may have been edited in the console; captured worker fields
    # take precedence for ordinary variables, while .project stays explicit.
    for (name in names(catalog$fields)) fields[[name]] <- catalog$fields[[name]]
    words <- fields[[plain]] %||% fields[[source]] %||% character()
    insert_prefix <- paste0(source, "$"); kind <- "column"
  } else {
    stem <- prefix
    packages <- intersect(c("base", "stats", "utils", "graphics", "grDevices", "dplyr", "tidyr"), loadedNamespaces())
    words <- unique(c(catalog$words, names(tables), names(objects), ".project",
      unlist(lapply(packages, getNamespaceExports), use.names = FALSE)))
  }
  words <- sort(unique(words[startsWith(words, stem)]))
  lapply(utils::head(words, 80L), function(word) list(label = word,
    insert = paste0(insert_prefix, quote_name(word)), kind = kind))
}

ig_console_script_params <- function(code, store) {
  if (!is.character(code) || length(code) != 1L || is.na(code) || !nzchar(trimws(code)) || nchar(code) > 100000L)
    stop("Choose a console command or selection to create a Script task.")
  expressions <- parse(text = code)
  assigned <- unique(unlist(lapply(as.list(expressions), function(expression) {
    if (is.call(expression) && is.symbol(expression[[1L]]) && as.character(expression[[1L]]) %in% c("<-", "=") && is.symbol(expression[[2L]]))
      as.character(expression[[2L]]) else NULL
  }), use.names = FALSE))
  symbols <- isolate(store$console)$symbols %||% list(kinds = list(), words = character())
  available <- c(names(isolate(store$tables)), names(isolate(store$objects)))
  references <- unique(all.vars(expressions))
  inputs <- setdiff(intersect(references, available), assigned)
  definitions <- lapply(assigned, function(name) list(name = name,
    kind = if (identical(symbols$kinds[[name]], "table")) "table" else "object"))
  tables <- Filter(function(def) def$kind == "table", definitions)
  p <- default_script_params(if (length(tables)) tables[[1L]]$name else "")
  p$code <- code; p$input_tables <- inputs; p$output_defs <- definitions
  list(params = p, missing = setdiff(intersect(references, c(symbols$words, ".project")), c(inputs, assigned)))
}
