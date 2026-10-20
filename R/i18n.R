# Language is a presentation preference. Never change R's parsing/numeric locale,
# column names, task identifiers, or project data to translate the interface.
ig_language_picker <- function(id = "ig-language-choice") {
  tags$label(class = "ig-language-control", `data-ig-no-translate` = "true",
    tags$span(class = "visually-hidden", "Language / Langue"),
    tags$select(id = id, class = "form-select form-select-sm ig-language-picker",
      `aria-label` = "Language / Langue",
      tags$option(value = "en-CA", "English"),
      tags$option(value = "fr-CA", "Français (Canada)")))
}

ig_language <- function(value = NULL) {
  if (is.null(value)) {
    session <- shiny::getDefaultReactiveDomain()
    value <- if (!is.null(session)) shiny::isolate(session$input$ig_language) else NULL
    value <- value %||% Sys.getenv("IG_LANGUAGE", "en-CA")
  }
  if (length(value) == 1L && is.character(value) && !is.na(value) && grepl("^fr($|[-_])", value, ignore.case = TRUE)) "fr-CA" else "en-CA"
}

# Search fixed task metadata in either supported language. User names, code,
# columns and project contents remain untouched. Load the bundled catalog once.
IG_I18N_SEARCH_CACHE <- new.env(parent = emptyenv())
ig_task_search_text <- function(type) {
  info <- task_type_info(type)
  labels <- c(info$label %||% type, info$category %||% "")
  if(is.null(IG_I18N_SEARCH_CACHE$strings)){
    path <- system.file("app/www/i18n/fr-CA.json",package="IndividualGuide")
    IG_I18N_SEARCH_CACHE$strings <- if(nzchar(path)&&file.exists(path))
      jsonlite::read_json(path)$strings else list()
  }
  translated <- vapply(labels,function(label)IG_I18N_SEARCH_CACHE$strings[[label]] %||% label,character(1))
  paste(c(labels,translated),collapse=" ")
}

# Selectize and radio choices can be data (column names, table names, etc.). Mark
# only literal application choices as translatable, rather than translating a
# user's value merely because it happens to match a word in the dictionary.
ig_literal_choices <- function(expression) {
  if (is.atomic(expression) || is.null(expression)) return(TRUE)
  if(is.symbol(expression))return(as.character(expression) %in% c("REPORT_FORMATS","REPORT_RENDER_CHOICES"))
  if (!is.call(expression)) return(FALSE)
  name <- paste(deparse(expression[[1L]]), collapse = "")
  if (name %in% c("c", "list", "stats::setNames", "setNames", "paste0", "names"))
    return(length(expression) > 1L && all(vapply(as.list(expression)[-1L], ig_literal_choices, logical(1))))
  name %in% c("ig_log_levels", "ig_log_fields", "ig_log_triggers", "ig_theme_choices", "ig_palette_choices")
}

selectInput <- function(inputId, label, choices, ...) {
  control <- shiny::selectInput(inputId, label, choices, ...)
  htmltools::tagAppendAttributes(control,
    `data-ig-choice-labels` = if (ig_literal_choices(substitute(choices))) "true" else "false")
}

radioButtons <- function(inputId, label, choices, ...) {
  control <- shiny::radioButtons(inputId, label, choices, ...)
  htmltools::tagAppendAttributes(control,
    `data-ig-choice-labels` = if (ig_literal_choices(substitute(choices))) "true" else "false")
}

checkboxGroupInput <- function(inputId, label, choices, ...) {
  control <- shiny::checkboxGroupInput(inputId, label, choices, ...)
  htmltools::tagAppendAttributes(control,
    `data-ig-choice-labels` = if (ig_literal_choices(substitute(choices))) "true" else "false")
}
