# connection_catalogue.R — Persistent catalogue of named DB connection configs.
#
# Saves named connection presets to a user-level JSON file that persists across
# projects and sessions. Dedicated password controls are never captured.
# Custom connection code is retained verbatim; use environment credentials.
#
# All functions are pure (no Shiny dependency) and are safe to call from both
# server and global scope.

# ── File location ──────────────────────────────────────────────────────────────

#' Path to the catalogue JSON file.
#' Stored in ~/.rIG/ so it survives project switches and reinstalls.
#' Override with options(ig.catalogue_dir = ...) — used by tests to sandbox.
cat_path <- function() {
  dir <- getOption("ig.catalogue_dir",
                   default = file.path(path.expand("~"), ".rIG"))
  if (!dir.exists(dir))
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  file.path(dir, "connections.json")
}

# ── Low-level I/O ──────────────────────────────────────────────────────────────

#' Read all catalogue entries.  Returns a list (may be empty list()).
cat_read <- function() {
  p <- cat_path()
  if (!file.exists(p)) return(list())
  tryCatch(
    jsonlite::fromJSON(p, simplifyVector = FALSE),
    error = function(e) list()
  )
}

#' Write the full catalogue list to disk.
#' @param entries List of named connection presets to persist.
cat_write <- function(entries) {
  path <- cat_path()
  if (file.exists(path)) tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) stop("Cannot replace the unreadable connection catalogue: ", path))
  replacement <- tempfile(".ig_catalogue_", tmpdir = dirname(path), fileext = ".json")
  on.exit(unlink(replacement), add = TRUE)
  jsonlite::write_json(entries, replacement, auto_unbox = TRUE, pretty = TRUE)
  jsonlite::fromJSON(replacement, simplifyVector = FALSE)
  ig_replace_file(replacement, path)
  invisible(entries)
}

# ── CRUD helpers ───────────────────────────────────────────────────────────────

#' Add a new entry, or replace an existing one matched by id.
#' @param entry Named connection preset without session password values.
cat_add <- function(entry) {
  entries <- cat_read()
  ids     <- vapply(entries, `[[`, character(1), "id")
  if (entry$id %in% ids) {
    entries[[which(ids == entry$id)]] <- entry
  } else {
    entries <- c(entries, list(entry))
  }
  cat_write(entries)
  invisible(entry)
}

#' Delete an entry by id.  Silently no-ops if id not found.
#' @param id Identifier of the module, task, flow, or catalogue entry being addressed.
cat_delete <- function(id) {
  entries <- cat_read()
  entries <- entries[!vapply(entries,
    function(e) identical(e$id, id), logical(1))]
  cat_write(entries)
  invisible(NULL)
}

#' Find a single entry by id.  Returns NULL if not found.
#' @param id Identifier of the module, task, flow, or catalogue entry being addressed.
cat_find <- function(id) {
  entries <- cat_read()
  idx <- which(vapply(entries,
    function(e) identical(e$id, id), logical(1)))
  if (length(idx) == 0L) return(NULL)
  entries[[idx[1L]]]
}

# ── UI helpers ─────────────────────────────────────────────────────────────────

#' Named character vector suitable for selectInput choices.
#' Format: c("Display name" = "id", ...)
#' Returns character(0) when the catalogue is empty.
cat_choices <- function() {
  entries <- cat_read()
  if (length(entries) == 0L) return(character(0))
  nms <- vapply(entries, function(e) e$name %||% e$id, character(1))
  ids <- vapply(entries, `[[`, character(1), "id")
  setNames(ids, nms)
}

# ── Entry constructor ──────────────────────────────────────────────────────────

#' Build a catalogue entry from the current Shiny input object.
#' db_pwd is intentionally absent — passwords are never stored.
#'
#' @param name  Display name chosen by the user.
#' @param input Shiny input object (passed from moduleServer).
#' @return Named list suitable for cat_add().
cat_entry_from_inputs <- function(name, input) {
  list(
    id           = paste0("conn_", format(Sys.time(), "%Y%m%d%H%M%S%OS3")),
    name         = trimws(name),
    conn_mode    = input$db_conn_mode  %||% "form",
    db_driver    = input$db_driver     %||% "odbc",
    db_dsn       = input$db_dsn        %||% "",
    db_host      = input$db_host       %||% "",
    db_port      = input$db_port       %||% "",
    db_database  = input$db_database   %||% "",
    db_uid       = input$db_uid        %||% "",
    db_schema    = input$db_schema     %||% "",
    db_conn_code = input$db_conn_code  %||% ""
    # db_pwd intentionally absent — never stored, never serialised.
  )
}
