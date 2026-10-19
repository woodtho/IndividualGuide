# collaboration.R -- Comments, reviews, history, and search helpers.

ig_now <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%OS%z")
}

# ── Display helpers (humanized time, author avatars) ──────────────────────────

ig_parse_time <- function(iso) {
  if (is.null(iso) || !nzchar(iso)) return(NA)
  suppressWarnings(tryCatch(
    as.POSIXct(iso, format = "%Y-%m-%dT%H:%M:%OS%z", tz = ""),
    error = function(e) NA))
}

# Friendly relative time: "just now", "5 min ago", "3 h ago", "2 d ago", "Jun 14".
ig_time_ago <- function(iso) {
  t <- ig_parse_time(iso)
  if (is.na(t)) return(iso %||% "")
  secs <- as.numeric(difftime(Sys.time(), t, units = "secs"))
  if (secs < 0) secs <- 0
  if (secs < 45)   return("just now")
  if (secs < 90)   return("1 min ago")
  mins <- round(secs / 60)
  if (mins < 60)   return(paste0(mins, " min ago"))
  hrs <- round(mins / 60)
  if (hrs < 24)    return(paste0(hrs, " h ago"))
  days <- round(hrs / 24)
  if (days < 7)    return(paste0(days, " d ago"))
  format(t, "%b %e")
}

# Full timestamp for tooltips.
ig_time_full <- function(iso) {
  t <- ig_parse_time(iso)
  if (is.na(t)) return(iso %||% "")
  format(t, "%Y-%m-%d %H:%M")
}

# Up to two initials from an author name ("Ann Lee" -> "AL", "reviewer" -> "RE").
ig_initials <- function(name) {
  name <- trimws(name %||% "")
  if (!nzchar(name)) return("?")
  parts <- strsplit(name, "[\\s._-]+")[[1]]
  parts <- parts[nzchar(parts)]
  if (length(parts) >= 2L) {
    toupper(paste0(substr(parts[1], 1, 1), substr(parts[2], 1, 1)))
  } else {
    toupper(substr(name, 1, 2))
  }
}

# Deterministic avatar background colour from the author name (HSL hue).
ig_avatar_color <- function(name) {
  name <- name %||% ""
  h <- sum(utils::head(utf8ToInt(paste0(name, "x")), 24)) %% 360
  sprintf("hsl(%d, 55%%, 42%%)", h)
}

ig_current_author <- function(store = NULL) {
  author <- Sys.getenv("IG_AUTHOR", unset = "")
  if (!nzchar(author)) author <- Sys.getenv("USERNAME", unset = "")
  if (!nzchar(author)) author <- Sys.getenv("USER", unset = "")
  if (!nzchar(author)) author <- "Reviewer"
  author
}

ig_new_id <- function(prefix) {
  paste0(prefix, "_", gsub("[^0-9]", "", format(Sys.time(), "%Y%m%d%H%M%OS6")))
}

ig_comment_target_value <- function(scope, target_id) {
  paste0(scope %||% "project", ":",
         utils::URLencode(target_id %||% "project", reserved = TRUE))
}

ig_parse_comment_target <- function(value) {
  value <- value %||% ig_comment_target_value("project", "project")
  pos <- regexpr(":", value, fixed = TRUE)[1L]
  if (is.na(pos) || pos < 1L) {
    return(list(scope = "project", id = utils::URLdecode(value)))
  }
  list(
    scope = substr(value, 1L, pos - 1L) %||% "project",
    id = utils::URLdecode(substr(value, pos + 1L, nchar(value))) %||% "project"
  )
}

store_comment_target_catalog <- function(store) {
  tasks <- isolate(store$tasks)
  specs <- unlist(lapply(tasks, task_output_specs), recursive = FALSE)
  declared_tables <- vapply(Filter(function(x)
    identical(x$kind %||% "table", "table") && nzchar(x$name %||% ""), specs),
    function(x) x$name, character(1))
  declared_outputs <- vapply(Filter(function(x)
    !identical(x$kind %||% "table", "table") && nzchar(x$name %||% ""), specs),
    function(x) x$name, character(1))
  list(
    nodes = names(tasks),
    tables = unique(c(names(isolate(store$tables)), declared_tables)),
    outputs = unique(c(names(isolate(store$objects)), declared_outputs))
  )
}

ig_comment_thread <- function(scope = "project", target_id = "project",
                              title = "", status = "open", author = NULL,
                              text = "") {
  id <- ig_new_id("thread")
  list(
    id = id,
    scope = scope,
    target_id = target_id,
    title = title %||% "",
    status = status %||% "open",
    created_by = author %||% ig_current_author(),
    created_at = ig_now(),
    updated_at = ig_now(),
    comments = if (nzchar(text %||% "")) {
      list(ig_comment(author = author, text = text))
    } else list()
  )
}

ig_comment <- function(author = NULL, text = "") {
  list(
    id = ig_new_id("comment"),
    author = author %||% ig_current_author(),
    created_at = ig_now(),
    text = text %||% ""
  )
}

ig_review_item <- function(scope = "project", target_id = "project",
                           title = "", detail = "", severity = "change",
                           status = "open", author = NULL) {
  list(
    id = ig_new_id("review"),
    scope = scope,
    target_id = target_id,
    title = title %||% "",
    detail = detail %||% "",
    severity = severity %||% "change",
    status = status %||% "open",
    author = author %||% ig_current_author(),
    created_at = ig_now(),
    updated_at = ig_now()
  )
}

ig_review_event <- function(action, author = NULL, detail = "") {
  list(
    id = ig_new_id("review_event"),
    action = action,
    author = author %||% ig_current_author(),
    detail = detail %||% "",
    created_at = ig_now()
  )
}

ig_history_event <- function(object_type, object_id, action,
                             summary = "", user = NULL, before = NULL,
                             after = NULL) {
  list(
    id = ig_new_id("history"),
    object_type = object_type %||% "project",
    object_id = object_id %||% "",
    action = action %||% "change",
    summary = summary %||% "",
    user = user %||% ig_current_author(),
    created_at = ig_now(),
    before = before,
    after = after
  )
}

ig_default_review <- function() {
  list(
    status = "draft",
    approvals = list(),
    items = list(),
    history = list()
  )
}

ig_default_collaboration <- function() {
  list(
    comments = list(),
    review = ig_default_review(),
    history = list()
  )
}

ig_normalize_collaboration <- function(x) {
  x <- x %||% list()
  defaults <- ig_default_collaboration()
  x$comments <- x$comments %||% defaults$comments
  x$history <- x$history %||% defaults$history
  x$review <- x$review %||% defaults$review
  x$review$status <- x$review$status %||% "draft"
  x$review$approvals <- x$review$approvals %||% list()
  x$review$items <- x$review$items %||% list()
  x$review$history <- x$review$history %||% list()
  x
}

store_collaboration <- function(store) {
  ig_normalize_collaboration(isolate(store$collaboration))
}

store_set_collaboration <- function(store, collab) {
  collab <- ig_normalize_collaboration(collab)
  store$collaboration <- collab
  store$dirty <- TRUE
  invisible(collab)
}

store_add_history <- function(store, object_type, object_id, action,
                              summary = "", before = NULL, after = NULL,
                              user = NULL) {
  collab <- store_collaboration(store)
  event <- ig_history_event(object_type, object_id, action, summary, user, before, after)
  collab$history <- c(collab$history %||% list(), list(event))
  store_set_collaboration(store, collab)
  invisible(event)
}

store_add_comment_thread <- function(store, scope, target_id, title, text,
                                     author = NULL) {
  collab <- store_collaboration(store)
  thread <- ig_comment_thread(scope, target_id, title, "open", author, text)
  collab$comments[[thread$id]] <- thread
  store_set_collaboration(store, collab)
  store_add_history(store, "comment", thread$id, "create",
    sprintf("Comment thread added to %s '%s'", scope, target_id))
  invisible(thread)
}

store_add_comment_reply <- function(store, thread_id, text, author = NULL) {
  collab <- store_collaboration(store)
  thread <- collab$comments[[thread_id]]
  if (is.null(thread)) return(NULL)
  comment <- ig_comment(author, text)
  thread$comments <- c(thread$comments %||% list(), list(comment))
  thread$updated_at <- ig_now()
  collab$comments[[thread_id]] <- thread
  store_set_collaboration(store, collab)
  invisible(comment)
}

store_set_comment_status <- function(store, thread_id, status) {
  collab <- store_collaboration(store)
  thread <- collab$comments[[thread_id]]
  if (is.null(thread)) return(NULL)
  thread$status <- status %||% "open"
  thread$updated_at <- ig_now()
  collab$comments[[thread_id]] <- thread
  store_set_collaboration(store, collab)
  invisible(thread)
}

store_comments_for <- function(store, scope = NULL, target_id = NULL,
                               include_resolved = TRUE) {
  threads <- unname(store_collaboration(store)$comments %||% list())
  Filter(function(thread) {
    ok <- TRUE
    if (!is.null(scope)) ok <- ok && identical(thread$scope %||% "", scope)
    if (!is.null(target_id)) ok <- ok && identical(thread$target_id %||% "", target_id)
    if (!isTRUE(include_resolved)) ok <- ok && !identical(thread$status %||% "", "resolved")
    ok
  }, threads)
}

store_comment_count_for <- function(store, scope, target_id,
                                    include_resolved = FALSE) {
  length(store_comments_for(store, scope, target_id, include_resolved))
}

store_add_review_item <- function(store, scope, target_id, title, detail = "",
                                  severity = "change", author = NULL) {
  collab <- store_collaboration(store)
  item <- ig_review_item(scope, target_id, title, detail, severity, "open", author)
  collab$review$items[[item$id]] <- item
  collab$review$status <- "changes_requested"
  collab$review$history <- c(collab$review$history %||% list(),
    list(ig_review_event("issue_created", author, title)))
  store_set_collaboration(store, collab)
  invisible(item)
}

store_set_review_item_status <- function(store, item_id, status) {
  collab <- store_collaboration(store)
  item <- collab$review$items[[item_id]]
  if (is.null(item)) return(NULL)
  item$status <- status %||% "open"
  item$updated_at <- ig_now()
  collab$review$items[[item_id]] <- item
  store_set_collaboration(store, collab)
  invisible(item)
}

store_set_review_decision <- function(store, action,
                                      author = NULL, detail = "") {
  collab <- store_collaboration(store)
  action <- action %||% "request_changes"
  collab$review$status <- switch(action,
    approve = "approved",
    reject = "rejected",
    request_changes = "changes_requested",
    action
  )
  event <- ig_review_event(action, author, detail)
  collab$review$history <- c(collab$review$history %||% list(), list(event))
  if (identical(action, "approve")) {
    collab$review$approvals <- c(collab$review$approvals, list(event))
  }
  store_set_collaboration(store, collab)
  invisible(event)
}

store_unresolved_review_items <- function(store) {
  items <- unname(store_collaboration(store)$review$items %||% list())
  Filter(function(item) !identical(item$status %||% "open", "resolved"), items)
}

store_search_index <- function(store) {
  tasks <- isolate(store$tasks)
  tables <- isolate(store$tables)
  objects <- isolate(store$objects)
  collab <- store_collaboration(store)
  rows <- list()
  add <- function(type, id, label, text) {
    rows[[length(rows) + 1L]] <<- data.frame(
      type = type, id = id, label = label %||% id, text = text %||% "",
      stringsAsFactors = FALSE
    )
  }
  for (tid in names(tasks)) {
    task <- tasks[[tid]]
    add("task", tid, task$label %||% tid,
      paste(task$type, task$r_code %||% "", task$note %||% "", collapse = " "))
  }
  for (nm in names(tables)) {
    add("dataset", nm, nm, paste(nm, paste(names(tables[[nm]]), collapse = " ")))
    for (col in names(tables[[nm]])) add("variable", paste(nm, col, sep = "$"), col, nm)
  }
  for (nm in names(objects)) {
    add("output", nm, nm, paste(nm, objects[[nm]]$meta$kind %||% "object"))
  }
  for (thread in unname(collab$comments %||% list())) {
    body <- paste(vapply(thread$comments %||% list(), function(c) c$text %||% "",
      character(1)), collapse = " ")
    add("comment", thread$id, thread$title %||% thread$id,
      paste(thread$scope, thread$target_id, body))
  }
  for (item in unname(collab$review$items %||% list())) {
    add("review", item$id, item$title %||% item$id,
      paste(item$scope, item$target_id, item$detail))
  }
  if (!length(rows)) {
    return(data.frame(type = character(0), id = character(0),
      label = character(0), text = character(0)))
  }
  do.call(rbind, rows)
}

store_search <- function(store, query) {
  q <- trimws(query %||% "")
  idx <- store_search_index(store)
  if (!nzchar(q) || !nrow(idx)) return(idx[0, , drop = FALSE])
  hay <- tolower(paste(idx$type, idx$id, idx$label, idx$text))
  idx[grepl(tolower(q), hay, fixed = TRUE), , drop = FALSE]
}
