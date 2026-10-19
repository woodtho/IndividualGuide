# Select only compile-time task-type branches. Data-dependent validation stays
# in the exported R, and user-written Script code never passes through this.
code_static_value <- function(node, bindings) {
  if (is.null(node) || is.atomic(node)) return(list(known = TRUE, value = node))
  if (is.symbol(node)) {
    name <- as.character(node)
    if (name %in% names(bindings)) return(list(known = TRUE, value = bindings[[name]]))
    return(list(known = FALSE))
  }
  allowed <- c("c", "list", "character", "integer", "numeric", "logical", "is.null", "isTRUE", "identical", "%in%", "==", "!=", "!", "&&", "||", "nzchar", "length", "&", "|")
  if (!is.call(node) || !is.symbol(node[[1L]]) || !as.character(node[[1L]]) %in% allowed) return(list(known = FALSE))
  args <- lapply(as.list(node)[-1L], code_static_value, bindings = bindings)
  if (!all(vapply(args, function(x) isTRUE(x$known), logical(1)))) return(list(known = FALSE))
  values <- lapply(args, `[[`, "value")
  tryCatch(list(known = TRUE, value = do.call(get(as.character(node[[1L]]), baseenv()), values)),
    error = function(e) list(known = FALSE))
}

code_replace_symbols <- function(node, replacements) {
  if (is.symbol(node)) return(replacements[[as.character(node)]] %||% node)
  if (!is.call(node)) return(node)
  head <- if (is.symbol(node[[1L]])) as.character(node[[1L]]) else ""
  if (head %in% c("quote", "substitute", "expression", "bquote", "alist")) return(node)
  if (head == "function") {
    nested <- replacements[setdiff(names(replacements), names(node[[2L]]))]
    node[[3L]] <- code_replace_symbols(node[[3L]], nested)
    return(node)
  }
  for (i in seq_along(node)) {
    if (head %in% c("$", "@", "::", ":::") && i >= 3L) next
    value <- tryCatch(list(value = node[[i]]), error = function(e) NULL)
    if (!is.null(value)) node[i] <- list(code_replace_symbols(value$value, replacements))
  }
  node
}

code_prune_type_branches <- function(node, bindings = list()) {
  if (!is.call(node)) return(node)
  head <- if (is.symbol(node[[1L]])) as.character(node[[1L]]) else ""
  if (head %in% c("quote", "substitute", "expression", "bquote", "alist", "function")) return(node)
  if (head == "{") {
    if (length(node) == 1L) return(node)
    for (i in seq.int(2L, length(node))) {
      node[i] <- list(code_prune_type_branches(node[[i]], bindings))
      statement <- node[[i]]
      if (is.call(statement) && identical(statement[[1L]], as.name("<-")) && is.symbol(statement[[2L]])) {
        value <- code_static_value(statement[[3L]], bindings)
        name <- as.character(statement[[2L]])
        if (isTRUE(value$known)) bindings[name] <- list(value$value) else bindings[name] <- NULL
      } else if (is.call(statement) && is.symbol(statement[[1L]]) && as.character(statement[[1L]]) %in% c("if", "for", "while", "repeat")) {
        # Never propagate an initial value across a conditional or loop update.
        assigned <- all.names(statement, functions = FALSE)
        bindings <- bindings[setdiff(names(bindings), assigned)]
      }
    }
    return(node)
  }
  if (head == "if") {
    condition <- node[[2L]]
    simplify <- function(value) {
      if (is.call(value) && is.symbol(value[[1L]]) && as.character(value[[1L]]) %in% c("&&", "||")) {
        left <- code_static_value(value[[2L]], bindings)
        if (isTRUE(left$known) && is.logical(left$value) && length(left$value) == 1L && !is.na(left$value)) {
          if (identical(value[[1L]], as.name("&&"))) return(if (left$value) simplify(value[[3L]]) else FALSE)
          return(if (left$value) TRUE else simplify(value[[3L]]))
        }
      }
      value
    }
    condition <- simplify(condition)
    value <- code_static_value(condition, bindings)
    if (isTRUE(value$known) && is.logical(value$value) && length(value$value) == 1L && !is.na(value$value)) {
      if (value$value) return(code_prune_type_branches(node[[3L]], bindings))
      return(if (length(node) >= 4L) code_prune_type_branches(node[[4L]], bindings) else NULL)
    }
    node[2L] <- list(condition)
    node[3L] <- list(code_prune_type_branches(node[[3L]], bindings))
    if (length(node) >= 4L) node[4L] <- list(code_prune_type_branches(node[[4L]], bindings))
    return(node)
  }
  if (head == "switch") {
    value <- code_static_value(node[[2L]], bindings)
    if (isTRUE(value$known) && is.character(value$value) && length(value$value) == 1L) {
      index <- match(value$value, names(node))
      if (!is.na(index)) for (i in seq.int(index, length(node))) {
        if (identical(node[[i]], quote(expr = ))) next
        arm <- tryCatch(list(value = node[[i]]), error = function(e) NULL)
        if (!is.null(arm)) return(code_prune_type_branches(arm$value, bindings))
      }
    }
  }
  for (i in seq_along(node)[-1L]) {
    value <- tryCatch(list(value = node[[i]]), error = function(e) NULL)
    if (!is.null(value)) node[i] <- list(code_prune_type_branches(value$value, bindings))
  }
  node
}

code_task_backend <- function(helper, type, title = type) {
  namespace <- environment(code_task_backend)
  fn <- get(helper, namespace, inherits = FALSE)
  replacements <- list()
  if ("type_id" %in% names(formals(fn))) replacements$type_id <- type
  if ("default_title" %in% names(formals(fn))) replacements$default_title <- title
  body(fn) <- code_prune_type_branches(code_replace_symbols(body(fn), replacements))
  unused <- intersect(names(replacements), setdiff(names(formals(fn)), all.names(body(fn), functions = FALSE)))
  formals(fn) <- formals(fn)[setdiff(names(formals(fn)), unused)]
  renames <- c(p = "settings", df = "data")
  body(fn) <- code_replace_symbols(body(fn), lapply(renames, as.name))
  names(formals(fn)) <- ifelse(names(formals(fn)) %in% names(renames), renames[names(formals(fn))], names(formals(fn)))
  name <- paste0("calculate_", type)
  registry <- getOption("IndividualGuide.codegen_helpers")
  if (is.environment(registry)) {
    base <- name; index <- 1L
    while (!is.null(registry$overrides[[name]]) &&
      !identical(body(registry$overrides[[name]]), body(fn))) {
      index <- index + 1L; name <- paste0(base, "_", index)
    }
  }
  list(name = name, fn = fn)
}

code_backend_parameters <- function(p, helper, overrides = list()) {
  namespace <- environment(code_backend_parameters)
  available <- union(ls(namespace, all.names = TRUE), names(overrides))
  visited <- character(0); fields <- character(0); required <- character(0)
  defaults <- list(); dynamic <- FALSE
  setting_field <- function(node) {
    if (!is.call(node) || !is.symbol(node[[1L]]) || !as.character(node[[1L]]) %in% c("$", "[[") ||
        !is.symbol(node[[2L]]) || !as.character(node[[2L]]) %in% c("p", "settings")) return(NULL)
    if (identical(node[[1L]], as.name("$")) || (is.character(node[[3L]]) && length(node[[3L]]) == 1L)) as.character(node[[3L]]) else NULL
  }
  scan <- function(node) {
    if (!is.call(node)) return(invisible(NULL))
    head <- if (is.symbol(node[[1L]])) as.character(node[[1L]]) else ""
    if (head == "%||%" && !is.null(setting_field(node[[2L]]))) {
      key <- setting_field(node[[2L]]); fields <<- union(fields, key)
      fallback <- code_static_value(node[[3L]], list())
      if (isTRUE(fallback$known)) defaults[[key]] <<- c(defaults[[key]], list(fallback$value)) else required <<- union(required, key)
      scan(node[[3L]])
      return(invisible(NULL))
    }
    if (!head %in% c("$", "[[") && !head %in% available &&
        any(vapply(as.list(node)[-1L], function(x) tryCatch(is.symbol(x) && as.character(x) %in% c("p", "settings"),
          error = function(e) FALSE), logical(1)))) dynamic <<- TRUE
    if (head == "[" && is.symbol(node[[2L]]) && as.character(node[[2L]]) %in% c("p", "settings")) dynamic <<- TRUE
    if (head %in% c("$", "[[") && is.symbol(node[[2L]]) && as.character(node[[2L]]) %in% c("p", "settings")) {
      key <- node[[3L]]
      if (head == "$" || (is.character(key) && length(key) == 1L)) {
        fields <<- union(fields, as.character(key)); required <<- union(required, as.character(key))
      } else dynamic <<- TRUE
    }
    for (part in as.list(node)[-1L]) tryCatch(scan(part), error = function(e) NULL)
    invisible(NULL)
  }
  visit <- function(name) {
    if (name %in% visited || !name %in% available) return(invisible(NULL))
    visited <<- c(visited, name)
    fn <- overrides[[name]] %||% get(name, namespace, inherits = FALSE)
    if (!is.function(fn)) return(invisible(NULL))
    scan(body(fn))
    for (dependency in intersect(all.names(body(fn), functions = TRUE), available)) visit(dependency)
    invisible(NULL)
  }
  visit(helper)
  if (dynamic) return(p)
  fields <- intersect(names(p), fields)
  keep <- vapply(fields, function(key) {
    # Retain prefix keys so R's $ partial matching cannot change after pruning.
    if (any(startsWith(setdiff(fields, key), key))) return(TRUE)
    if (is.null(p[[key]])) return(FALSE)
    key %in% required || !length(defaults[[key]]) ||
      !all(vapply(defaults[[key]], function(fallback) identical(p[[key]], fallback), logical(1)))
  }, logical(1))
  if (!any(keep)) return(list())
  p[fields[keep]]
}
