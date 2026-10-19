# utils.R — Small shared helpers used across the package.

#' Null-coalescing operator
#'
#' Returns `b` when `a` is NULL, otherwise `a`.
#' @name op-null-default
#' @keywords internal
#' @param a Value to return when non-NULL.
#' @param b Default returned when the first value is NULL.
`%||%` <- function(a, b) if (!is.null(a)) a else b

# Shiny's Font Awesome tags carry a label but omit the role required for an
# accessible labelled graphic. Preserve their names and add that role at source.
icon <- function(name, class = NULL, lib = "font-awesome", ...) {
  tag <- shiny::icon(name, class = class, lib = lib, ...)
  tag$attribs$role <- "img"
  tag
}

# Quote data as JavaScript values, including names supplied by imported files.
ig_input_event_js <- function(id, value, stop_propagation = FALSE) {
  encode <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null"))
  paste0(if (stop_propagation) "event.stopPropagation();" else "",
    "Shiny.setInputValue(", encode(id), ",", encode(value), ",{priority:'event'})")
}

#' Replace a file only after its complete replacement has been written.
#' @param replacement Completed temporary file in the destination directory.
#' @param destination Final file path.
#' @return The destination invisibly; the previous file survives a failed move.
#' @keywords internal
ig_replace_file <- function(replacement, destination) {
  directory <- normalizePath(dirname(destination), mustWork = TRUE)
  destination <- file.path(directory, basename(destination))
  backup <- tempfile(".ig_previous_", tmpdir = directory)
  previous <- file.exists(destination)
  if (previous && !file.rename(destination, backup)) stop("Cannot replace file: ", destination)
  if (!file.rename(replacement, destination)) {
    if (previous && !file.rename(backup, destination)) stop("Previous file retained at: ", backup)
    stop("Cannot replace file: ", destination)
  }
  if (previous) unlink(backup)
  invisible(destination)
}

#' Screen-reader-only input label
#'
#' Inputs that omit their visible label (`label = NULL`) have no accessible
#' name — `aria-label` on the Shiny wrapper div does not reach the actual
#' control. Passing this as the `label` argument emits a real `<label>`
#' element (correctly associated via `for=`) that Bootstrap 5 hides visually
#' but exposes to assistive technology.
#' @keywords internal
#' @param text Accessible label text.
sr_label <- function(text) {
  tags$span(class = "visually-hidden", text)
}

#' Session-safe notification
#'
#' Drop-in for [shiny::showNotification()] that silently no-ops when no Shiny
#' session is active (e.g. when execute functions run in unit tests or
#' headless scripts).
#' @keywords internal
#' @param type Registered task type identifier.
#' @param id Identifier of the module, task, flow, or catalogue entry being addressed.
#' @param ui Notification content.
#' @param duration Notification duration in seconds.
ig_notify <- function(ui, type = "message", duration = 5, id = NULL) {
  domain <- shiny::getDefaultReactiveDomain()
  if (is.null(domain)) return(invisible(NULL))
  shiny::showNotification(ui, type = type, duration = duration, id = id,
    session = domain)
  invisible(NULL)
}
