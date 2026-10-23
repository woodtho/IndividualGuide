# Settings have three layers: built-in defaults, user-wide defaults, and only
# the explicit overrides saved with a project. NULL is a value, not inheritance.
.ig_options_state <- new.env(parent = emptyenv())
.ig_options_state$revision <- shiny::reactiveVal(0L)
.ig_options_state$originals <- getOption("IndividualGuide.options.startup_originals", list())
.ig_options_state$applied <- names(.ig_options_state$originals)
.ig_options_state$signature <- NULL
.ig_options_state$sessions <- 0L
options(IndividualGuide.options.startup_originals = NULL)

ig_options_initialize <- function() {
  bootstrap <- new.env(parent = baseenv())
  sys.source(app_sys("options", "bootstrap.R"), envir = bootstrap)
  bootstrap$ig_options_bootstrap()
  original <- getOption("IndividualGuide.options.startup_originals", list())
  .ig_options_state$originals <- ig_options_merge(.ig_options_state$originals, original)
  .ig_options_state$applied <- union(.ig_options_state$applied, names(original))
  options(IndividualGuide.options.startup_originals = NULL)
  invisible(NULL)
}

ig_options_merge <- function(base, overrides) {
  if (length(overrides)) base[names(overrides)] <- overrides
  base
}

ig_options_empty <- function() list(schema = 1L, app = list(), r = list())

ig_options_file <- function() getOption("ig.options.file") %||% file.path(ig_user_directory("settings"), "options.rds")

ig_options_global <- function() {
  file <- ig_options_file()
  if (!file.exists(file)) return(ig_options_empty())
  value <- tryCatch(readRDS(file), error = function(error) stop("Cannot read global options: ", conditionMessage(error)))
  ig_options_validate_spec(value)
}

ig_options_validate_spec <- function(spec) {
  if (!is.list(spec) || !is.list(spec$app) || !is.list(spec$r)) stop("Invalid options configuration.")
  for (domain in c("app", "r")) {
    values <- spec[[domain]]
    if (length(values) && (is.null(names(values)) || anyNA(names(values)) || any(!nzchar(names(values))) || anyDuplicated(names(values))))
      stop("Option names must be unique and nonempty.")
    if (length(values) > 10000L) stop("Too many configured options.")
  }
  spec$schema <- 1L
  spec
}

ig_options_save_global <- function(spec) {
  spec <- ig_options_validate_spec(spec)
  if ("language" %in% names(spec$app)) spec$presentation_initialized <- TRUE
  path <- ig_options_file()
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile("options-", tmpdir = dirname(path))
  on.exit(unlink(temporary), add = TRUE)
  saveRDS(spec, temporary)
  ig_replace_file(temporary, path)
  .ig_options_state$revision(shiny::isolate(.ig_options_state$revision()) + 1L)
  invisible(spec)
}

ig_options_app_values <- function(store = NULL, global = ig_options_global()) {
  overrides <- if (is.null(store)) list() else shiny::isolate(store$option_overrides)$app %||% list()
  ig_options_merge(ig_options_merge(ig_default_settings(), global$app), overrides)
}

ig_options_r_values <- function(store = NULL, global = ig_options_global()) {
  if (isTRUE(getOption("IndividualGuide.options.ignore_saved"))) return(list())
  if (!is.null(store) && !is.null(shiny::isolate(store$runtime_r_options))) return(shiny::isolate(store$runtime_r_options))
  overrides <- if (is.null(store)) list() else shiny::isolate(store$option_overrides)$r %||% list()
  ig_options_merge(global$r, overrides)
}

ig_options_r_defaults <- function() ig_options_merge(options(), .ig_options_state$originals)

ig_options_apply_global <- function(global = ig_options_global()) {
  if (isTRUE(getOption("IndividualGuide.options.ignore_saved"))) return(invisible(NULL))
  signature <- digest::digest(global$r, algo = "sha256")
  if (identical(signature, .ig_options_state$signature)) return(invisible(NULL))
  fresh <- setdiff(names(global$r), names(.ig_options_state$originals))
  for (name in fresh) .ig_options_state$originals[name] <- list(getOption(name))
  removed <- setdiff(.ig_options_state$applied, names(global$r))
  if (length(removed)) options(.ig_options_state$originals[removed])
  if (length(global$r)) options(global$r)
  .ig_options_state$applied <- names(global$r)
  .ig_options_state$signature <- signature
  invisible(NULL)
}

ig_options_runtime_session <- function(session) {
  .ig_options_state$sessions <- .ig_options_state$sessions + 1L
  session$onSessionEnded(function() {
    .ig_options_state$sessions <- max(0L, .ig_options_state$sessions - 1L)
    if (.ig_options_state$sessions == 0L) {
      if (length(.ig_options_state$originals)) options(.ig_options_state$originals)
      .ig_options_state$originals <- list()
      .ig_options_state$applied <- character()
      .ig_options_state$signature <- NULL
    }
  })
}

ig_options_refresh <- function(store) {
  value <- ig_options_app_values(store)
  if (!identical(shiny::isolate(store$settings), value)) store$settings <- value
  invisible(value)
}

ig_options_sync <- function(store) {
  # Preserve the public store$settings API used by existing integrations.
  current <- shiny::isolate(store$settings)
  expected <- ig_options_app_values(store)
  spec <- shiny::isolate(store$option_overrides) %||% ig_options_empty()
  for (name in intersect(names(current), names(ig_default_settings())))
    if (!identical(current[[name]], expected[[name]])) spec$app[name] <- current[name]
  store$option_overrides <- spec
  invisible(spec)
}

ig_options_value_text <- function(value, lines = -1L) paste(suppressWarnings(deparse(value, width.cutoff = 90L, control = "all", nlines = lines)), collapse = "\n")

ig_options_code <- function(values) {
  if (project_requires_native(values)) paste0("unserialize(as.raw(", code_literal(as.integer(serialize(values, NULL))), "))") else code_literal(values)
}

ig_options_parse <- function(text, type = "expression") {
  if (!is.character(text) || length(text) != 1L || is.na(text) || nchar(text) > 100000L) stop("Enter one option value.")
  if (type == "text") return(text)
  if (type == "null") return(NULL)
  if (type == "logical") {
    if (!text %in% c("TRUE", "FALSE", "NA")) stop("Choose TRUE, FALSE or NA.")
    return(if (text == "TRUE") TRUE else if (text == "FALSE") FALSE else NA)
  }
  if (type %in% c("integer", "number")) {
    value <- suppressWarnings(as.numeric(text))
    if (length(value) != 1L || is.na(value) || !is.finite(value)) stop("Enter a finite number.")
    if (type == "integer") {
      if (value != trunc(value) || abs(value) > .Machine$integer.max) stop("Enter a valid whole number.")
      return(as.integer(value))
    }
    return(value)
  }
  expression <- parse(text = text, keep.source = FALSE)
  if (length(expression) != 1L) stop("Enter one R expression. Use list(...) or c(...) for several values.")
  # An explicitly submitted R expression can construct arbitrary package values,
  # expressions and functions. Avoid capturing the main workspace in closures.
  value <- eval(expression[[1L]], envir = new.env(parent = baseenv()))
  if (!ig_transferable(value)) stop("Live connections, environments and external pointers cannot be saved as options. Use a function that creates the value when needed.")
  value
}

ig_options_validate_r <- function(name, value) {
  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name) || nchar(name) > 250L || grepl("[[:cntrl:]]", name))
    stop("Enter a nonempty R option name without control characters.")
  # Let R validate its own options; there is deliberately no name whitelist.
  # Validation happens outside the server so error hooks and execution limits
  # cannot break the preferences dialog while the user is editing them.
  result <- callr::r(function(name, value) {
    previous <- options()
    on.exit(options(previous), add = TRUE)
    suppressWarnings(options(stats::setNames(list(value), name)))
    getOption(name)
  }, args = list(name, value), system_profile = FALSE, user_profile = FALSE, timeout = 30)
  result
}

ig_options_set <- function(store, scope, domain, name, value = NULL, inherit = FALSE) {
  if (!scope %in% c("global", "project") || !domain %in% c("app", "r")) stop("Choose an option scope and type.")
  if (domain == "app") ig_options_validate_app(name, value, inherit) else if (!inherit) value <- ig_options_validate_r(name, value)
  spec <- if (scope == "global") ig_options_global() else shiny::isolate(store$option_overrides) %||% ig_options_empty()
  if (inherit) spec[[domain]][name] <- NULL else spec[[domain]][name] <- list(value)
  if (scope == "global") ig_options_save_global(spec) else {
    store$option_overrides <- spec
    store$dirty <- TRUE
  }
  ig_options_refresh(store)
  invisible(spec)
}

ig_with_options <- function(store, fn) {
  configured <- ig_options_r_values(store)
  if (!length(configured)) return(fn())
  previous <- stats::setNames(lapply(names(configured), getOption), names(configured))
  on.exit(options(previous), add = TRUE)
  options(configured)
  fn()
}

ig_options_app_catalog <- function() {
  entry <- function(name, category, label, type, description = "", choices = NULL, min = NULL, max = NULL)
    list(name = name, category = category, label = label, type = type, description = description, choices = choices, min = min, max = max)
  list(
    entry("confirm_delete", "General", "Confirm before deleting tasks and flows", "logical"),
    entry("stop_on_error", "Execution", "Stop the flow after the first error", "logical"),
    entry("background_tasks", "Execution", "Run supported tasks in background workers", "logical"),
    entry("run_seed", "Execution", "Default random seed", "expression", "NULL uses normal random generation; an integer fixes the seed."),
    entry("theme_mode", "Appearance", "Appearance", "choice", choices = c("Dark" = "dark", "Light" = "light")),
    entry("language", "Appearance", "Interface language", "choice", choices = c("English" = "en-CA", "Français (Canada)" = "fr-CA")),
    entry("reduce_motion", "Appearance", "Reduce interface animations", "logical"),
    entry("editor_font_size", "Code editing", "Editor font size", "integer", min = 9, max = 32),
    entry("editor_tab_size", "Code editing", "Indentation width", "integer", min = 1, max = 8),
    entry("editor_soft_tabs", "Code editing", "Insert spaces instead of tabs", "logical"),
    entry("editor_wrap", "Code editing", "Wrap long lines", "logical"),
    entry("editor_line_numbers", "Code editing", "Show line numbers", "logical"),
    entry("editor_show_invisibles", "Code editing", "Show whitespace characters", "logical"),
    entry("editor_highlight_line", "Code editing", "Highlight the active line", "logical"),
    entry("console_font_size", "Console", "Console font size", "integer", min = 9, max = 32),
    entry("console_max_chars", "Console", "Retained console characters", "integer", min = 10000, max = 10000000),
    entry("console_auto_scroll", "Console", "Follow new console output", "logical"),
    entry("page_length", "Data and results", "Preview rows per page", "integer", min = 5, max = 1000),
    entry("plot_theme", "Plots and reports", "Default plot theme", "choice", choices = c("Clean" = "clean", "Publication" = "publication", "Minimal" = "minimal", "Classic" = "classic", "Light" = "light", "Dark" = "dark")),
    entry("palette", "Plots and reports", "Default plot palette", "choice", choices = c("Individual Guide" = "ig", "Okabe-Ito" = "okabe_ito", "Tableau" = "tableau", "Viridis" = "viridis", "Grey" = "grey")),
    entry("console_plot_width", "Plots and reports", "Console plot width (pixels)", "integer", min = 320, max = 4096),
    entry("console_plot_height", "Plots and reports", "Console plot height (pixels)", "integer", min = 240, max = 4096),
    entry("backup_versions", "Files and recovery", "Previous saved versions to keep", "integer", min = 0, max = 100),
    entry("autosave_seconds", "Files and recovery", "Recovery autosave interval (seconds)", "integer", min = 5, max = 3600)
  )
}

ig_options_validate_app <- function(name, value, inherit = FALSE) {
  catalog <- ig_options_app_catalog()
  match <- which(vapply(catalog, function(entry) identical(entry$name, name), logical(1)))
  if (length(match) != 1L) stop("Unknown application option.")
  if (inherit) return(invisible(TRUE))
  entry <- catalog[[match]]
  valid <- switch(entry$type,
    logical = is.logical(value) && length(value) == 1L && !is.na(value),
    choice = is.character(value) && length(value) == 1L && value %in% unname(entry$choices),
    integer = is.numeric(value) && length(value) == 1L && is.finite(value) && value == trunc(value) && value >= entry$min && value <= entry$max,
    expression = is.null(value) || (is.numeric(value) && length(value) == 1L && is.finite(value) && value == trunc(value) && value >= 0 && value <= .Machine$integer.max), FALSE)
  if (!isTRUE(valid)) stop("Enter a valid value for ", entry$label, ".")
  invisible(TRUE)
}

ig_options_catalog <- function(store, query = "", category = "All options", scope = "effective") {
  global <- ig_options_global()
  project <- shiny::isolate(store$option_overrides) %||% ig_options_empty()
  app <- ig_options_app_catalog()
  reference <- tryCatch(jsonlite::read_json(app_sys("options", "r-options.json"))$options, error = function(error) list())
  known <- stats::setNames(reference, vapply(reference, `[[`, character(1), "name"))
  discovered <- shiny::isolate(store$r_options_discovered) %||% list()
  r_names <- sort(unique(c(names(options()), names(known), names(global$r), names(project$r), names(discovered))))
  rows <- c(lapply(app, function(entry) c(entry, list(domain = "app"))), lapply(r_names, function(name) {
    doc <- known[[name]]
    list(name = name, domain = "r", label = name, category = if (is.null(doc)) "Package and custom R options" else "R options",
      type = "expression", description = doc$description %||% "An R or package option. Any valid R option name and serializable value can be configured.")
  }))
  rows <- Filter(function(entry) (category == "All options" || entry$category == category ||
    (category == "R options" && entry$domain == "r")) && (!nzchar(query) || grepl(tolower(query),
      tolower(paste(entry$name, entry$label, entry$description, entry$category)), fixed = TRUE)), rows)
  if (!length(rows)) return(data.frame(Name = character(), Label = character(), Category = character(), Value = character(), Source = character(), Domain = character()))
  defaults <- ig_default_settings()
  do.call(rbind, lapply(rows, function(entry) {
    domain <- entry$domain; name <- entry$name
    project_value <- scope != "global" && name %in% names(project[[domain]])
    source <- if (project_value) "Project override" else if (name %in% names(global[[domain]])) "Global default" else "Built-in / R session"
    value <- if (project_value) project[[domain]][[name]] else if (name %in% names(global[[domain]])) global[[domain]][[name]] else
      if (domain == "app") defaults[[name]] else ig_options_r_defaults()[[name]]
    text <- ig_options_value_text(value, 4L)
    if (domain == "r" && !name %in% names(options()) && !name %in% names(global$r) && !project_value && name %in% names(discovered)) {
      text <- discovered[[name]]$text
      source <- "R console session"
    }
    data.frame(Name = name, Label = entry$label, Category = entry$category, Value = substr(text, 1L, 160L), Source = source, Domain = domain, stringsAsFactors = FALSE)
  }))
}
