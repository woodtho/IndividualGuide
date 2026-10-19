# qb_build.R — Pure code-generation and execution functions for the Query Builder.
# Nothing in this file touches Shiny reactivity; everything is testable standalone.
#
# params list schema (all fields optional unless noted):
#   primary_table  chr(1)  [required] name of the main input table
#   joins          list of join-def lists
#   computed       list of computed-col defs
#   filters        list of filter-row defs
#   select         list of select-col defs
#   sorts          list of sort-def lists
#   distinct       logical (FALSE)
#   output_name    chr(1) [required] name written back to store

# ══════════════════════════════════════════════════════════════════════════════
# R CODE BUILDER
# ══════════════════════════════════════════════════════════════════════════════


# ══════════════════════════════════════════════════════════════════════════════
# FILTER EXPRESSION HELPERS
# ══════════════════════════════════════════════════════════════════════════════

#' Build a dplyr filter() expression from a list of filter row specs
#' @param filters Ordered filter rules, including their comparison and conjunction settings.
build_filter_r <- function(filters) {
  if (!length(filters)) return("TRUE")
  parts <- vapply(filters, function(f) {
    col <- r_ident(f$col %||% "")
    op  <- f$op  %||% "="
    cls <- f$col_class %||% "character"

    switch(op,
      "="          = paste0(col, " == ", r_val(f$val, cls)),
      "!="         = paste0(col, " != ", r_val(f$val, cls)),
      "<"          = paste0(col, " < ",  r_val(f$val, cls)),
      ">"          = paste0(col, " > ",  r_val(f$val, cls)),
      "<="         = paste0(col, " <= ", r_val(f$val, cls)),
      ">="         = paste0(col, " >= ", r_val(f$val, cls)),
      "BETWEEN"    = paste0("dplyr::between(", col, ", ",
                             r_val(f$val, cls), ", ", r_val(f$val2 %||% f$val, cls), ")"),
      "IN"         = {
        vals <- strsplit(f$val %||% "", ",")[[1]]
        vals <- trimws(vals)
        paste0(col, " %in% c(", paste(vapply(vals, r_val, character(1), cls), collapse = ", "), ")")
      },
      "IS NULL"    = paste0("is.na(", col, ")"),
      "IS NOT NULL"= paste0("!is.na(", col, ")"),
      "LIKE"       = paste0('grepl(', r_val(like_to_regex(f$val %||% ""), "character"), ', ', col, ')'),
      paste0(col, " ", op, " ", r_val(f$val, cls))  # fallback
    )
  }, character(1))

  result <- parts[1]
  for (i in seq_along(filters)[-1]) {
    conn <- filters[[i]]$join %||% "AND"
    r_conn <- if (identical(conn, "OR")) "|" else "&"
    result <- paste0(result, "\n    ", r_conn, " ", parts[i])
  }
  result
}

# ── Value quoting helpers ──────────────────────────────────────────────────────

r_val <- function(v, col_class) {
  # Defensive: handle NULL, NA, or R objects (Date, numeric) passed from Shiny inputs
  if (is.null(v) || (length(v) == 1L && is.na(v))) {
    v <- ""
  } else {
    v <- as.character(v)
  }
  if (col_class %in% c("numeric", "integer", "double", "complex",
                       "integer64", "bit64", "float", "float64",
                       "bigint", "smallint", "tinyint", "hugeint", "decimal", "NUMBER")) {
    # Empty or non-numeric string: fall back to quoting
    if (nchar(trimws(v)) == 0L || is.na(suppressWarnings(as.numeric(v))))
      encodeString(v, quote = '"')
    else
      v
  } else if (col_class %in% c("logical", "boolean")) {
    # Emit R logical literal: TRUE or FALSE
    vl <- tolower(trimws(v))
    if (vl %in% c("true",  "1", "yes")) "TRUE"
    else if (vl %in% c("false", "0", "no")) "FALSE"
    else encodeString(v, quote = '"')
  } else if (col_class %in% c("Date", "POSIXct", "POSIXlt", "difftime",
                               "datetime", "timestamp", "TIMESTAMP")) {
    # Emit as.Date() call so dplyr/dbplyr translates correctly across backends
    paste0('as.Date(', encodeString(v, quote = '"'), ')')
  } else {
    encodeString(v, quote = '"')
  }
}

r_ident <- function(x) {
  x <- x %||% ""
  reserved <- c(
    "if", "else", "repeat", "while", "function", "for", "in", "next",
    "break", "TRUE", "FALSE", "NULL", "Inf", "NaN", "NA", "NA_integer_",
    "NA_real_", "NA_complex_", "NA_character_"
  )
  if (identical(make.names(x), x) && !x %in% reserved)
    return(x)
  if (!nzchar(x)) return("``")
  paste(deparse(as.name(x), backtick = TRUE), collapse = "\n")
}

clean_libraries <- function(libraries) {
  libraries <- libraries %||% character(0)
  if (length(libraries) == 1L)
    libraries <- unlist(strsplit(libraries, ","), use.names = FALSE)
  libraries <- trimws(libraries)
  unique(libraries[nzchar(libraries)])
}

library_code_lines <- function(libraries) {
  libraries <- clean_libraries(libraries)
  if (length(libraries) == 0L) return(character(0))
  c(
    vapply(libraries, function(pkg) {
      paste0("library(", r_ident(pkg), ")")
    }, character(1)),
    ""
  )
}

like_to_regex <- function(pattern) {
  chars <- strsplit(pattern, "", fixed = TRUE)[[1L]]
  pieces <- character(0)
  escaped <- FALSE
  for (char in chars) {
    if (!escaped && char == "\\") { escaped <- TRUE; next }
    piece <- if (!escaped && char == "%") ".*" else if (!escaped && char == "_") "." else {
      if (char %in% c(".", "^", "$", "|", "(", ")", "[", "]", "{", "}", "*", "+", "?", "\\")) paste0("\\", char) else char
    }
    pieces <- c(pieces, piece)
    escaped <- FALSE
  }
  if (escaped) pieces <- c(pieces, "\\\\")
  paste0("^", paste0(pieces, collapse = ""), "$")
}

# ══════════════════════════════════════════════════════════════════════════════
# EXECUTOR
# ══════════════════════════════════════════════════════════════════════════════


# ══════════════════════════════════════════════════════════════════════════════
# DEFAULT PARAMS
# ══════════════════════════════════════════════════════════════════════════════



# ── Filter row constructor ─────────────────────────────────────────────────────
new_filter_row <- function(id, col = "", op = "=", val = "", val2 = "",
                           join = "AND", col_class = "character") {
  list(id = id, col = col, op = op, val = val, val2 = val2,
       join = join, col_class = col_class)
}

ops_for_class <- function(cls) {
  cls <- cls %||% "character"
  switch(cls,
    # Numeric — R base + common DB types (DuckDB, PostgreSQL, SQL Server, etc.)
    numeric  = , integer  = , double  = , complex  = ,
    integer64 = , bit64   = , float   = , float64  = ,
    bigint   = , smallint = , tinyint = , hugeint  = , decimal = , NUMBER = OPS_NUMERIC,
    # Character / categorical
    character = , factor  = , ordered = , varchar  = , text = , string = , CHAR = OPS_CHAR,
    # Date / time
    Date     = , POSIXct = , POSIXlt = , difftime = ,
    datetime = , timestamp = , TIMESTAMP = OPS_DATE,
    # Logical / boolean
    logical  = , boolean = OPS_LOGICAL,
    # Fallback for unknown types
    OPS_DEFAULT
  )
}

#' Render the value input(s) for a single filter row.
#'
#' @param val   Current first value as character (already normalised; "" if unset)
#' @param val2  Current second value as character (for BETWEEN; "" if unset)
#' @param cur_op     Operator string, e.g. "=", "BETWEEN", "IS NULL"
#' @param cur_class  Column class from col_class_map(), e.g. "numeric", "Date"
#' @param ns Shiny module namespace function.
#' @param fid Identifier of the filter row.
filter_value_ui <- function(ns, fid, val, val2, cur_op, cur_class) {
  needs_two <- cur_op == "BETWEEN"
  no_val    <- cur_op %in% c("IS NULL", "IS NOT NULL")

  if (no_val) return(div())

  val  <- val  %||% ""
  val2 <- val2 %||% ""

  # Broad class buckets that cover both R types and DB/dbplyr-reported types
  is_numeric_cls <- cur_class %in% c(
    "numeric", "integer", "double", "complex",
    "integer64", "bit64", "float", "float64",
    "bigint", "smallint", "tinyint", "hugeint", "decimal", "NUMBER")
  is_date_cls <- cur_class %in% c(
    "Date", "POSIXct", "POSIXlt", "difftime",
    "datetime", "timestamp", "TIMESTAMP")

  make_input <- function(input_id, v, what = "Filter value") {
    if (is_numeric_cls) {
      numericInput(ns(input_id), sr_label(what),
        value = suppressWarnings(as.numeric(v)),
        width = "100%")
    } else if (is_date_cls) {
      dateInput(ns(input_id), sr_label(what),
        value = tryCatch(as.Date(v), error = function(e) Sys.Date()),
        width = "100%")
    } else {
      textInput(ns(input_id), sr_label(what),
        value = v,
        placeholder = switch(cur_op,
          "IN"   = "val1, val2, val3",
          "LIKE" = "%pattern%",
          ""),
        width = "100%")
    }
  }

  val_ui <- make_input(paste0("fval_",  fid), val)
  if (!needs_two) return(val_ui)

  val2_ui <- make_input(paste0("fval2_", fid), val2, "Filter value (upper bound)")
  div(class = "d-flex gap-1 align-items-center",
    div(style = "flex:1;", val_ui),
    span("and"),
    div(style = "flex:1;", val2_ui))
}
