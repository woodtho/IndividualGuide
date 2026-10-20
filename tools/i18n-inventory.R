# Collect app-owned labels/help text for the Canadian French coverage gate.
root <- normalizePath(getwd(), winslash = "/")
records <- list()
add <- function(value, file) {
  if (!is.character(value)) return(invisible(NULL))
  for (text in value) {
    text <- trimws(gsub("[[:space:]]+", " ", text))
    if (nzchar(text) && grepl("[A-Za-z]", text) && !grepl("^#[0-9a-fA-F]+$", text))
      records[[text]] <<- unique(c(records[[text]], file))
  }
}
literal <- function(value, file) {
  if(missing(value))return(invisible(NULL))
  if (is.character(value)) add(value, file)
  else if (is.call(value) && as.character(value[[1L]])[1L] %in% c("sprintf", "paste", "paste0", "if", "switch"))
    for (argument in as.list(value)[-1L]) literal(argument,file)
}
walk <- function(value, file) {
  if (missing(value)) return(invisible(NULL))
  if(is.pairlist(value)){
    arguments<-as.list(value)
    for(i in seq_along(arguments))if(names(arguments)[i] %in% c("label","title","description","placeholder"))literal(arguments[[i]],file)
    return(invisible(NULL))
  }
  if (!is.call(value) && !is.expression(value)) return(invisible(NULL))
  if (is.expression(value)) {for (child in value) walk(child, file); return(invisible(NULL))}
  call_name <- paste(deparse(value[[1L]]), collapse = "")
  name <- sub("^.*(::|\\$)", "", call_name)
  args <- as.list(value)[-1L]; nms <- names(args); if (is.null(nms)) nms <- rep("", length(args))
  if(identical(file,"R/preflight.R")&&name=="add"&&length(args)>=4L)literal(args[[4L]],file)
  if(name %in% c("<-","=")&&length(args)==2L&&is.symbol(args[[1L]])&&
      grepl("_label$",as.character(args[[1L]]))&&is.call(args[[2L]])&&identical(args[[2L]][[1L]],as.name("switch")))
    for(branch in as.list(args[[2L]])[-c(1L,2L)])literal(branch,file)
  for (i in seq_along(args)) {
    if (nms[i] %in% c("label", "title", "description", "placeholder", "aria-label", "category")) literal(args[[i]], file)
    if (nms[i] == "choices" && is.call(args[[i]]) && as.character(args[[i]][[1L]])[1L] %in% c("c", "list")) {
      choices <- as.list(args[[i]])[-1L]; labels <- names(choices)
      for (j in seq_along(choices)) {
        if (!is.null(labels) && nzchar(labels[j])) add(labels[j], file)
        else if (is.character(choices[[j]])) add(choices[[j]], file)
      }
    }
  }
  if (name %in% c("div", "span", "p", "strong", "em", "small", "h1", "h2", "h3", "h4", "h5", "h6", "li", "a", "button", "summary", "label", "th", "td", "card_header", "card_footer", "tagList", "modalDialog"))
    for (i in seq_along(args)) if (!nzchar(nms[i])) literal(args[[i]], file)
  second <- c("actionButton", "downloadButton", "selectInput", "radioButtons", "checkboxInput", "checkboxGroupInput", "textInput", "textAreaInput", "numericInput", "sliderInput", "dateInput", "dateRangeInput", "fileInput", "passwordInput", "shinyFilesButton", "shinyDirButton", "shinySaveButton", "tooltip", "need")
  first <- c("modalButton", "nav_panel", "nav_menu", "tabPanel", "showNotification", "stop", "warning")
  if (name %in% second && length(args) >= 2L && !"label" %in% nms) literal(args[[2L]], file)
  if(name %in% c("selectInput","radioButtons","checkboxGroupInput")&&length(args)>=3L&&!"choices" %in% nms){
    choice <- args[[3L]]
    if(is.call(choice)&&as.character(choice[[1L]])[1L] %in% c("c","list")){
      values <- as.list(choice)[-1L]; labels <- names(values)
      for(j in seq_along(values)){
        if(!is.null(labels)&&nzchar(labels[j]))add(labels[j],file)
        else if(is.character(values[[j]]))add(values[[j]],file)
      }
    }
  }
  if (name %in% first && length(args) >= 1L) literal(args[[1L]], file)
  if (name != "HTML") for (child in args) walk(child, file)
}
for (file in list.files("R", pattern = "[.]R$", full.names = TRUE)) walk(parse(file, encoding = "UTF-8"), file)
pkgload::load_all(".", quiet = TRUE, export_all = FALSE)
namespace <- asNamespace("IndividualGuide")
for(status in c("success","error","running","waiting","skipped","pending"))
  add(get("ig_status_display",namespace)(status,FALSE,"#333333")$text,"rendered canvas status")
add(get("ig_status_display",namespace)("success",TRUE,"#333333")$text,"rendered stale canvas status")
add(c("Loaded","Pending"),"canvas status for a table without a producing task")
for(type in get("PHASE3_TYPES",namespace))for(definition in get("phase3_return_defs",namespace)(type))
  add(paste0(definition$kind,": ",definition$label),"rendered task output descriptions")
add(get("ig_preview_status",namespace)(list()),"rendered preview status")
add(get("ig_preview_status",namespace)(list(data=data.frame(value=1))),"rendered preview dimensions")
add(get("ig_preview_status",namespace)(list(error="Example error")),"rendered preview error prefix")
for(name in c("ig_log_triggers","ig_log_fields"))add(names(get(name,namespace)()),paste0("static helper: ",name))
for(name in c("REPORT_FORMATS","REPORT_RENDER_CHOICES"))add(names(get(name,namespace)),paste0("static choices: ",name))
help <- htmltools::renderTags(get("help_modal_ui", namespace)())$html
document <- xml2::read_html(help)
leaves <- xml2::xml_find_all(document, "//text()[not(ancestor::script) and not(ancestor::style) and not(ancestor::code) and not(ancestor::pre)]")
for (text in xml2::xml_text(leaves)) add(text, "rendered help")
dir.create("artifacts/i18n", recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(list(strings = sort(names(records)), sources = records), "artifacts/i18n/source-inventory.json", pretty = TRUE, auto_unbox = TRUE)
cat("Inventoried", length(records), "application strings.\n")
