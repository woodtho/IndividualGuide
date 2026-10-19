# canvas.R — visNetwork flow canvas Shiny module
#
# The canvas is the persistent left sidebar.  Every dataset and every task is
# a node; directed edges show data flow.  Clicking a node sets store$active_node
# so the main panel can open the correct module.

# ── Colour palette by node type ───────────────────────────────────────────────
NODE_COLOURS <- list(
  source         = list(background = "#2d6a4f", border = "#1b4332", font = "#ffffff"),
  branch         = list(background = "#5b5fc7", border = "#383b91", font = "#ffffff"),
  loop           = list(background = "#0f766e", border = "#115e59", font = "#ffffff"),
  import_data    = list(background = "#2d6a4f", border = "#1b4332", font = "#ffffff"),
  query_builder  = list(background = "#4361ee", border = "#2b4acb", font = "#ffffff"),
  append_table   = list(background = "#7b5ea7", border = "#5a3e87", font = "#ffffff"),
  describe       = list(background = "#c77b3b", border = "#a05c20", font = "#ffffff"),
  graph          = list(background = "#3a8a3a", border = "#256325", font = "#ffffff"),
  stats          = list(background = "#8b1a4a", border = "#6a1238", font = "#ffffff"),
  default        = list(background = "#4a4a6a", border = "#333355", font = "#ffffff")
)

node_colour <- function(type) {
  NODE_COLOURS[[type]] %||% NODE_COLOURS[["default"]]
}

# ── Task icons on canvas nodes ────────────────────────────────────────────────
# Render each task's FontAwesome icon (the SAME glyph the task picker shows) into
# a node image, so the canvas and the menu match. Composed once and cached.
.ig_icon_cache <- new.env(parent = emptyenv())
.ig_glyph_cache <- new.env(parent = emptyenv())

# Pull the inner markup + viewBox out of a FontAwesome <svg> for a given name.
ig_fa_inner <- function(name) {
  cached <- .ig_glyph_cache[[name]]
  if (!is.null(cached)) return(cached)
  s <- tryCatch(as.character(fontawesome::fa(name)), error = function(e) NA_character_)
  if (is.na(s)) return(NULL)
  vb <- regmatches(s, regexpr('viewBox="[^"]*"', s))
  vb <- if (length(vb)) sub('^viewBox="', '', sub('"$', '', vb)) else "0 0 512 512"
  inner <- sub('^.*?<svg[^>]*>', '', s)
  inner <- sub('</svg>\\s*$', '', inner)
  result <- list(viewBox = vb, inner = inner)
  if (length(.ig_glyph_cache) >= 128L) rm(list = ls(.ig_glyph_cache, all.names = TRUE), envir = .ig_glyph_cache)
  .ig_glyph_cache[[name]] <- result
  result
}

# Icon name for a data/object output node by its kind, so data outputs and the
# various special outputs each get a recognisable glyph on the canvas.
ig_kind_icon <- function(kind) {
  switch(kind %||% "table",
    table  = "table",
    model  = "diagram-project",
    plot   = "chart-line",
    image  = "image",
    report = "file-lines",
    object = "cube",
    "cube"
  )
}

# data: URI for a node — rounded square in the node colour, status-coloured
# border, white icon centred. border baked in (image-shape nodes ignore the
# colour.*/borderWidth fields). Shared by task, data and object nodes.
ig_node_icon_image <- function(name, bg, border, border_w = 2) {
  key <- paste(name, bg, border, border_w, sep = "|")
  cached <- .ig_icon_cache[[key]]
  if (!is.null(cached)) return(cached)
  fa <- ig_fa_inner(name %||% "circle") %||% ig_fa_inner("circle")
  glyph <- gsub("<path ", '<path fill="#ffffff" ', fa$inner, fixed = TRUE)
  inset <- border_w / 2
  svg <- sprintf(paste0(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">',
    '<rect x="%g" y="%g" width="%g" height="%g" rx="20" fill="%s" stroke="%s" stroke-width="%g"/>',
    '<svg x="28" y="28" width="44" height="44" viewBox="%s">%s</svg></svg>'),
    inset, inset, 100 - border_w, 100 - border_w, bg, border, border_w,
    fa$viewBox, glyph)
  uri <- paste0("data:image/svg+xml;base64,",
                jsonlite::base64_enc(charToRaw(enc2utf8(svg))))
  if (length(.ig_icon_cache) >= 256L) rm(list = ls(.ig_icon_cache, all.names = TRUE), envir = .ig_icon_cache)
  .ig_icon_cache[[key]] <- uri
  uri
}

ig_xml_escape <- function(x) {
  x <- gsub("&", "&amp;", x %||% "", fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

ig_truncate <- function(x, n) {
  x <- x %||% ""
  if (nchar(x) > n) paste0(substr(x, 1, n - 1L), "\u2026") else x
}

# Border colour / width and a status label + colour for a node, derived from a
# task's run status (and whether it is stale). Shared by task nodes and by the
# output nodes they produce, so an output echoes its producing task's status.
ig_status_display <- function(status, stale, default_border) {
  if (isTRUE(stale) && (status %||% "pending") %in% c("pending", "success"))
    return(list(border = "#f59e0b", width = 3L, text = "\u26a0 Stale", color = "#f59e0b"))
  switch(status %||% "pending",
    success = list(border = "#22c55e", width = 3L, text = "\u2713 Success", color = "#22c55e"),
    error   = list(border = "#ef4444", width = 3L, text = "\u2717 Error",   color = "#ef4444"),
    running = list(border = "#3b82f6", width = 3L, text = "\u21bb Running", color = "#3b82f6"),
    waiting = list(border = "#f59e0b", width = 3L, text = "Waiting for password", color = "#f59e0b"),
    skipped = list(border = "#8b8fa8", width = 3L, text = "Skipped", color = "#8b8fa8"),
    list(border = default_border, width = 2L, text = "Not run", color = "#9aa0bf"))
}

# Node "card": name above, a coloured box holding the icon (and, for tasks, the
# task type), and a status line below — composed as one SVG so all three
# positions are controllable (visNetwork only offers a single label slot). Pass
# type_label = "" for output nodes (icon centred, no type text).
ig_card_cache <- function() {
  cache <- new.env(parent = emptyenv())
  cache$values <- new.env(parent = emptyenv())
  cache$slots <- new.env(parent = emptyenv())
  cache$next_slot <- 1L
  cache
}

ig_card_cache_put <- function(cache, key, image) {
  slot <- as.character(cache$next_slot)
  old <- cache$slots[[slot]]
  if (!is.null(old)) rm(list = old, envir = cache$values)
  cache$values[[key]] <- image
  cache$slots[[slot]] <- key
  cache$next_slot <- if (cache$next_slot == 4096L) 1L else cache$next_slot + 1L
  invisible(image)
}

ig_card_image <- function(name, type_label, icon_name, bg, border,
                          status_text, status_color, border_w = 3,
                          badge_text = "", cache = NULL) {
  key <- jsonlite::toJSON(list(name, type_label, icon_name, bg, border,
    status_text, status_color, border_w, badge_text), auto_unbox = TRUE)
  cached <- if (!is.null(cache)) cache$values[[key]] else NULL
  if (!is.null(cached)) return(cached)
  fa <- ig_fa_inner(icon_name %||% "circle") %||% ig_fa_inner("circle")
  glyph <- gsub("<path ", '<path fill="#ffffff" ', fa$inner, fixed = TRUE)

  has_type <- nzchar(type_label %||% "")
  name_t   <- ig_xml_escape(ig_truncate(name, 20))
  status_t <- ig_xml_escape(status_text)
  inset    <- border_w / 2
  icon_y   <- if (has_type) 46 else 66   # centre the icon when there's no type
  type_svg <- if (has_type) {
    type_fs <- if (nchar(type_label) > 13) 16 else 19
    sprintf(paste0('<text x="100" y="124" text-anchor="middle" font-size="%g" ',
                   'font-weight="700" fill="#ffffff">%s</text>'),
            type_fs, ig_xml_escape(ig_truncate(type_label, 18)))
  } else ""
  badge_svg <- if (nzchar(badge_text %||% "")) {
    sprintf(paste0(
      '<circle cx="172" cy="32" r="17" fill="#facc15" stroke="#111827" stroke-width="3"/>',
      '<text x="172" y="39" text-anchor="middle" font-size="18" ',
      'font-weight="800" fill="#111827">%s</text>'),
      ig_xml_escape(ig_truncate(badge_text, 3)))
  } else ""

  svg <- sprintf(paste0(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 198" width="200" height="198" ',
    'font-family="Segoe UI, Helvetica, Arial, sans-serif">',
    '<text x="100" y="22" text-anchor="middle" font-size="20" font-weight="700" fill="#d2d6ee">%s</text>',
    '<rect x="%g" y="%g" width="%g" height="110" rx="16" fill="%s" stroke="%s" stroke-width="%g"/>',
    '<svg x="78" y="%g" width="44" height="44" viewBox="%s">%s</svg>',
    '%s',
    '%s',
    '<text x="100" y="182" text-anchor="middle" font-size="19" font-weight="700" fill="%s">%s</text>',
    '</svg>'),
    name_t,
    22 + inset, 34 + inset, 156 - border_w, bg, border, border_w,
    icon_y, fa$viewBox, glyph,
    type_svg,
    badge_svg,
    status_color, status_t)
  uri <- paste0("data:image/svg+xml;base64,",
                jsonlite::base64_enc(charToRaw(enc2utf8(svg))))
  if (!is.null(cache)) ig_card_cache_put(cache, key, uri)
  uri
}

canvas_tooltip <- function(...) {
  text <- paste0(...)
  if (!nzchar(text)) return("")
  paste0("<div style=\"color:#000000;\">", text, "</div>")
}

# ── Staleness ─────────────────────────────────────────────────────────────────

#' Compute which tasks are stale (an upstream output changed after this task ran).
#'
#' Single forward sweep through task_order (topologically sorted). A task is
#' stale when it HAS been run AND a direct upstream was re-run more recently, or
#' a direct upstream is itself stale (transitive). Shared by the canvas border
#' colouring and the sidebar Issues panel so the two never disagree.
#'
#' @return list(map = task_id→logical, msgs = task_id→HTML string)
#' @param tasks Named list of task definitions.
#' @param task_order Task identifiers in their stable display order.
flow_stale_map <- function(tasks, task_order) {
  output_to_task <- list()
  for (id in task_order) {
    task <- tasks[[id]]
    if (is.null(task)) next
    for (out in task_output_names(task)) {
      if (!is.null(out) && nzchar(out %||% "")) output_to_task[[out]] <- id
    }
  }

  stale_map  <- list()
  stale_msgs <- list()

  for (id in task_order) {
    task <- tasks[[id]]
    if (is.null(task)) {
      stale_map[[id]]  <- FALSE
      stale_msgs[[id]] <- ""
      next
    }

    is_stale <- isTRUE(task$invalidated)
    s_msg    <- if (is_stale) "Configuration or upstream data changed. Re-run to refresh outputs." else ""

    if (!is.null(task$run_time)) {
      for (inp in (task$inputs %||% character(0))) {
        up_id   <- output_to_task[[inp]]
        if (is.null(up_id)) next
        up_task <- tasks[[up_id]]

        direct_stale     <- !is.null(up_task$run_time) &&
                            up_task$run_time > task$run_time
        transitive_stale <- isTRUE(stale_map[[up_id]])

        if (direct_stale) {
          is_stale <- TRUE
          s_msg    <- paste0(
            "<b>Stale</b> \u2014 upstream <i>", up_id, "</i> was re-run at ",
            format(up_task$run_time, "%H:%M:%S"),
            "<br>Re-run this task to refresh its outputs."
          )
          break
        }
        if (transitive_stale) {
          is_stale <- TRUE
          s_msg    <- paste0(
            "<b>Stale</b> \u2014 upstream <i>", up_id,
            "</i> has stale inputs and has not been re-run.",
            "<br>Re-run from <i>", up_id, "</i> to refresh this task."
          )
          break
        }
      }
    }

    stale_map[[id]]  <- is_stale
    stale_msgs[[id]] <- s_msg
  }

  list(map = stale_map, msgs = stale_msgs)
}

#' Collect actionable problems in the active flow for the sidebar Issues panel.
#'
#' Returns a list of records: list(task_id, kind, label, message) where kind is
#' one of "dependency" (flow-level cycle / self-reference), "error" (task failed
#' on its last run), or "stale" (an upstream changed since this task last ran).
#' "Not run yet" is intentionally excluded — it's a normal state, not a problem.
#' @param store Session reactive store created by make_store().
flow_issues <- function(store) {
  tasks      <- isolate(store$tasks)
  task_order <- isolate(store$task_order)
  if (length(task_order) == 0L) return(list())

  sm     <- flow_stale_map(tasks, task_order)
  issues <- list()

  dep_prob <- tryCatch(store_dependency_problem(tasks, task_order),
                       error = function(e) NULL)
  if (!is.null(dep_prob)) {
    issues[[length(issues) + 1L]] <- list(
      task_id = NULL, kind = "dependency",
      label = "Dependency problem", message = dep_prob)
  }

  for (id in task_order) {
    task <- tasks[[id]]
    if (is.null(task)) next
    status <- task$status %||% "pending"
    label  <- trimws(task$label %||% "")
    label  <- if (nzchar(label)) label else (task_type_info(task$type)$label %||% task$type)

    if (identical(status, "error")) {
      msg <- task$error_msg %||% "Task failed on its last run."
      issues[[length(issues) + 1L]] <- list(
        task_id = id, kind = "error", label = label,
        message = trimws(strsplit(msg, "\n", fixed = TRUE)[[1]][1]))
    } else if (isTRUE(sm$map[[id]])) {
      issues[[length(issues) + 1L]] <- list(
        task_id = id, kind = "stale", label = label,
        message = "Inputs changed upstream \u2014 re-run to refresh.")
    }
  }

  issues
}

# ── Helpers to build visNetwork data frames ────────────────────────────────────

#' Build nodes + edges data frames from the current store state
#'
#' @param store reactiveValues store
#' @return list($nodes df, $edges df) ready for visNetworkProxy or visNetwork()
canvas_build_network <- function(store) {
  tables     <- isolate(store$tables)
  tasks      <- isolate(store$tasks)
  task_order <- isolate(store$task_order)
  performance <- isolate(store$performance_cache)
  if (is.null(performance)) {
    images <- ig_card_cache()
  } else {
    if (is.null(performance$card_images)) performance$card_images <- ig_card_cache()
    images <- performance$card_images
  }
  # Index open threads once per render, rather than filtering and normalizing
  # the full collaboration record separately for every table and task card.
  comment_counts <- new.env(parent = emptyenv())
  threads <- tryCatch(isolate(store_collaboration(store)$comments), error = function(e) list())
  for (thread in threads) {
    if (identical(thread$status %||% "", "resolved")) next
    scope <- thread$scope %||% ""
    target <- thread$target_id %||% ""
    if (!nzchar(scope) || !nzchar(target)) next
    counts <- comment_counts[[scope]] %||% list()
    counts[[target]] <- (counts[[target]] %||% 0L) + 1L
    comment_counts[[scope]] <- counts
  }
  comment_count <- function(scope, target_id) (comment_counts[[scope]] %||% list())[[target_id]] %||% 0L
  comment_badge <- function(n) {
    if (n > 99L) "99+" else if (n > 0L) as.character(n) else ""
  }
  comment_tooltip <- function(n) {
    if (n > 0L) sprintf("<br><br><b>Comments:</b> %d open thread%s",
      n, if (n == 1L) "" else "s") else ""
  }

  # Accumulate one-row data frames in lists and rbind once at the end.
  # Incremental rbind() reallocates and copies the whole growing frame on every
  # iteration (O(n^2)); a single do.call(rbind, ...) is one pass and scales to
  # large flows without the quadratic blow-up.
  empty_nodes <- data.frame(
    id    = character(0),
    label = character(0),
    group = character(0),
    shape = character(0),
    color.background = character(0),
    color.border     = character(0),
    font.color       = character(0),
    borderWidth      = integer(0),
    title            = character(0),
    image            = character(0),
    size             = numeric(0),
    stringsAsFactors = FALSE
  )

  empty_edges <- data.frame(
    from   = character(0),
    to     = character(0),
    arrows = character(0),
    label  = character(0),
    title  = character(0),
    color  = character(0),
    dashes = logical(0),
    stringsAsFactors = FALSE
  )

  node_rows <- list()
  edge_rows <- list()

  # Source / output table nodes (rectangles)
  all_table_names <- union(
    names(tables),
    unlist(lapply(tasks, function(t) task_output_names(t, kinds = "table")))
  )
  all_table_names <- all_table_names[!is.na(all_table_names) & nchar(all_table_names) > 0]
  all_object_names <- unique(unlist(lapply(tasks, function(t)
    task_output_names(t, kinds = c("model", "plot", "image", "object", "branch")))))
  all_object_names <- all_object_names[!is.na(all_object_names) & nchar(all_object_names) > 0]
  # Exclude any name already claimed as a table node (prevents duplicate IDs)
  all_object_names <- setdiff(all_object_names, all_table_names)

  # Staleness + ownership are needed before we draw outputs, so each output can
  # show the run status of the task that produces it. output_owner: name → task,
  # object_kind_map: name → kind (model/plot/…).
  sm        <- flow_stale_map(tasks, task_order)
  stale_map <- sm$map
  output_owner    <- list()
  object_kind_map <- list()
  for (tid in task_order) {
    t <- tasks[[tid]]
    if (is.null(t)) next
    for (spec in task_output_specs(t)) {
      nm <- spec$name %||% ""
      if (!nzchar(nm)) next
      output_owner[[nm]] <- tid
      k <- spec$kind %||% "table"
      if (k %in% c("model", "plot", "image", "object", "report", "branch"))
        object_kind_map[[nm]] <- k
    }
  }

  # Status display for an output node, taken from its producing task (if any).
  output_status <- function(nm, default_border, has_data) {
    owner <- output_owner[[nm]]
    if (!is.null(owner) && !is.null(tasks[[owner]])) {
      ig_status_display(tasks[[owner]]$status %||% "pending",
                        isTRUE(stale_map[[owner]]), default_border)
    } else {
      # No producing task in this flow (e.g. an imported source table).
      list(border = default_border, width = 2L,
           text = if (has_data) "Loaded" else "Pending", color = "#9aa0bf")
    }
  }

  for (tbl in all_table_names) {
    col <- node_colour("source")
    comments_n <- comment_count("table", tbl)
    # Tooltip: dimensions for computed tables, status hints otherwise
    df <- tables[[tbl]]
    tbl_title <- canvas_tooltip(if (is.null(df)) {
      "Declared output \u2014 run the producing task to compute it."
    } else if (inherits(df, "tbl_sql")) {
      "Lazy database table \u2014 queries run inside the database."
    } else {
      sprintf("%s rows &times; %d columns",
              formatC(nrow(df), format = "d", big.mark = ","), ncol(df))
    }, comment_tooltip(comments_n))
    st <- output_status(tbl, col$border, !is.null(df))
    node_rows[[length(node_rows) + 1L]] <- data.frame(
      id               = tbl,
      label            = "",
      group            = "table",
      shape            = "image",
      color.background = col$background,
      color.border     = st$border,
      font.color       = col$font,
      borderWidth      = st$width,
      title            = tbl_title,
      image            = ig_card_image(tbl, "", "table", col$background, st$border,
                           st$text, st$color, st$width, comment_badge(comments_n), cache = images),
      size             = 50,
      stringsAsFactors = FALSE
    )
  }

  for (obj in all_object_names) {
    col  <- node_colour("default")
    kind <- object_kind_map[[obj]] %||% "object"
    st   <- output_status(obj, col$border, TRUE)
    icon <- if (identical(kind, "branch")) "route" else ig_kind_icon(kind)
    comments_n <- comment_count("output", obj)
    node_rows[[length(node_rows) + 1L]] <- data.frame(
      id               = obj,
      label            = "",
      group            = "object",
      shape            = "image",
      color.background = col$background,
      color.border     = st$border,
      font.color       = col$font,
      borderWidth      = st$width,
      title            = canvas_tooltip("Special output (", kind, ")",
                           comment_tooltip(comments_n)),
      image            = ig_card_image(obj, "", icon, col$background,
                           st$border, st$text, st$color, st$width,
                           comment_badge(comments_n), cache = images),
      size             = 50,
      stringsAsFactors = FALSE
    )
  }

  stale_msgs <- sm$msgs

  # ── Task nodes (rounded boxes) ──────────────────────────────────────────────
  for (id in task_order) {
    task <- tasks[[id]]
    if (is.null(task)) next
    col  <- node_colour(task$type)
    info <- task_type_info(task$type)

    stale     <- isTRUE(stale_map[[id]])
    stale_msg <- stale_msgs[[id]] %||% ""

    # Active execution/error states remain visible even when old data is stale.
    st <- ig_status_display(task$status %||% "pending", stale, col$border)
    border_col   <- st$border
    border_w     <- st$width
    status_text  <- st$text
    status_color <- st$color

    # Name above the box: the user's label if set, otherwise the task id.
    user_label <- trimws(task$label %||% "")
    name_disp  <- if (nzchar(user_label)) user_label else id
    type_label <- info$label %||% task$type
    comments_n <- comment_count("node", id)

    # ── Tooltip: stale / not-run message + optional note ────────────────────
    not_run_msg <- if (identical(task$status, "error")) {
      paste0("<b>Error:</b> ", ig_report_html_escape(task$error_msg %||% "Execution failed."))
    } else if (identical(task$status, "skipped")) {
      paste0("<b>Skipped:</b> ", ig_report_html_escape(task$skip_reason %||% "Inactive control path."))
    } else if (identical(task$status, "waiting")) {
      "<b>Waiting for a database password.</b> Complete or cancel the connection prompt."
    } else if (identical(task$status, "running")) {
      "<b>Running.</b>"
    } else if (!is.null(task$restoration_note) && isTRUE(task$invalidated)) {
      ig_report_html_escape(task$restoration_note)
    } else if (!stale && is.null(task$run_time)) {
      "<b>Not run yet</b> \u2014 open the task and run it, or use Run Flow."
    } else ""
    note_text <- if (nzchar(task$note %||% "")) {
      safe <- gsub("&", "&amp;",
               gsub("<", "&lt;",
               gsub(">", "&gt;", task$note)))
      paste0("<br><br><b>Note:</b> ", safe)
    } else ""
    branch_details <- if (identical(task$type, "branch") &&
                          length(task$branch_decision$decisions %||% list())) {
      rows <- vapply(task$branch_decision$decisions, function(d) {
        paste0("<br>", if (isTRUE(d$matched)) "\u2713 " else "\u25cb ",
               ig_report_html_escape(d$label %||% d$token), ": ", ig_report_html_escape(d$summary %||% ""))
      }, character(1))
      paste0("<br><br><b>Branch decision</b>", paste(rows, collapse = ""))
    } else ""
    node_title <- canvas_tooltip(stale_msg, not_run_msg, note_text,
                                 branch_details, comment_tooltip(comments_n))

    # Whole node is a card image: name above, icon + type in the coloured box,
    # status below. The visNetwork label is left blank since the card carries it.
    icon_name <- info$icon %||% "circle"
    node_rows[[length(node_rows) + 1L]] <- data.frame(
      id               = id,
      label            = "",
      group            = task$type,
      shape            = "image",
      color.background = col$background,
      color.border     = border_col,
      font.color       = col$font,
      borderWidth      = border_w,
      title            = node_title,
      image            = ig_card_image(name_disp, type_label, icon_name,
                           col$background, border_col, status_text, status_color,
                           border_w, comment_badge(comments_n), cache = images),
      size             = 52,
      stringsAsFactors = FALSE
    )

    # Edges: input tables → task
    for (inp in task$inputs) {
      if (nchar(inp) > 0) {
        muted <- identical(task$status %||% "", "skipped")
        edge_rows[[length(edge_rows) + 1L]] <- data.frame(
          from = inp, to = id, arrows = "to",
          label = "",
          title = if (muted) "Skipped path" else "",
          color = if (muted) "#5d6178" else "#7a7f8f",
          dashes = muted,
          stringsAsFactors = FALSE
        )
      }
    }
    # Edges: task → all declared outputs
    direct <- if (identical(task$type, "branch")) branch_references(task$params, "task_id") else
      if (identical(task$type, "export_log")) task$params$after_tasks else character(0)
    for (producer in intersect(direct, task_order)) {
      edge_rows[[length(edge_rows) + 1L]] <- data.frame(from = producer, to = id, arrows = "to",
        label = "", title = if (identical(task$type, "export_log")) "Run after task and include its logs" else "Task status / parameter dependency", color = "#7a7f8f", dashes = TRUE,
        stringsAsFactors = FALSE)
    }
    for (spec in task_output_specs(task)) {
      out <- spec$name %||% ""
      if (!is.null(out) && nchar(out) > 0) {
        is_branch <- identical(spec$kind %||% "", "branch")
        active <- out %in% (task$branch_decision$matched_tokens %||% character(0))
        decided <- !is.null(task$branch_decision)
        edge_rows[[length(edge_rows) + 1L]] <- data.frame(
          from = id, to = out, arrows = "to",
          label = if (is_branch) spec$label %||% "" else "",
          title = if (is_branch) {
            paste0(spec$label %||% out,
                   if (decided) {
                     if (active) " \u2014 active path" else " \u2014 skipped path"
                   } else "")
          } else "",
          color = if (is_branch && decided && !active) "#5d6178"
                  else if (is_branch && active) "#22c55e"
                  else "#7a7f8f",
          dashes = is_branch && decided && !active,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  nodes <- if (length(node_rows)) do.call(rbind, node_rows) else empty_nodes
  edges <- if (length(edge_rows)) do.call(rbind, edge_rows) else empty_edges

  # Defensive deduplication — prevents visNetwork "nodes must have unique ids"
  # if the same name somehow appears in multiple node groups.
  if (nrow(nodes) > 0L) nodes <- nodes[!duplicated(nodes$id), ]

  list(nodes = nodes, edges = edges)
}

# ── Module UI ─────────────────────────────────────────────────────────────────

canvas_ui <- function(id) {
  ns <- NS(id)
  div(class = "ig-canvas-wrap",
    # View controls — layouts drift as flows grow; these recover instantly
    div(class = "ig-canvas-controls",
      div(class = "ig-canvas-layout-select",
        title = "Canvas layout",
        selectInput(ns("layout"), label = sr_label("Canvas layout"), width = "140px", selectize = FALSE,
          choices = c("Left \u2192 Right" = "LR", "Top \u2192 Down" = "UD", "Free-form" = "free"),
          selected = "LR")
      ),
      actionButton(ns("fit"), "Fit view", icon = icon("expand"),
        class = "btn btn-xs btn-outline-secondary",
        title = "Zoom to fit the whole flow"),
      actionButton(ns("relayout"), "Re-arrange", icon = icon("wand-magic-sparkles"),
        class = "btn btn-xs btn-outline-secondary",
        title = "Recompute the layout (clears manual positions in Free-form)")
    ),
    visNetwork::visNetworkOutput(ns("net"), height = "calc(100vh - 125px)"),
    # Empty-state guidance when the flow has nothing on it yet
    uiOutput(ns("empty_state"))
  )
}

# ── Module Server ─────────────────────────────────────────────────────────────

canvas_server <- function(id, store, main_panel_trigger) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Right-click context: which task node was right-clicked
    rv_context <- reactiveVal(NULL)

    # Rebuild for graph/status/data/comment changes, not every parameter edit
    # or history entry generated while the user is typing.
    network_data <- reactive({
      # Touch reactive dependencies
      store_ui_read(store, "canvas_tables", store$tables)
      store_ui_read(store, "tasks", store$tasks)
      store$task_order
      store_ui_read(store, "comments", store$collaboration$comments)
      isolate(canvas_build_network(store))
    })

    # "Fit view" — zoom/centre on everything without re-rendering
    observeEvent(input$fit, {
      visNetwork::visNetworkProxy(ns("net")) |>
        visNetwork::visFit(animation = list(duration = 300))
    })

    # "Re-arrange" — recompute the layout from scratch. In Free-form this also
    # discards saved manual positions so physics lays everything out afresh.
    relayout_n <- reactiveVal(0L)
    observeEvent(input$relayout, {
      if (identical(input$layout %||% "LR", "free"))
        store_set_canvas_positions(store, list())
      relayout_n(relayout_n() + 1L)
    })

    # Persist the layout choice on the active flow and re-render.
    observeEvent(input$layout, {
      store_set_canvas_layout(store, input$layout)
      relayout_n(relayout_n() + 1L)
    }, ignoreInit = TRUE)

    # Reflect the active flow's saved layout in the dropdown when flows switch.
    observeEvent(store$active_flow, {
      updateSelectInput(session, "layout", selected = store_canvas_layout(store))
    })

    # Capture dragged / settled node positions (Free-form only).
    observeEvent(input$positions, {
      if (!identical(input$layout %||% "LR", "free")) return()
      store_set_canvas_positions(store, input$positions)
    }, ignoreInit = TRUE)

    output$net <- visNetwork::renderVisNetwork({
      relayout_n()
      mode  <- input$layout %||% "LR"
      nd    <- network_data()
      nodes <- nd$nodes

      free <- identical(mode, "free")
      any_missing <- TRUE
      if (free && nrow(nodes) > 0L) {
        pos  <- isolate(store_canvas_positions(store))
        getc <- function(i, k) {
          p <- pos[[i]]
          if (is.null(p)) NA_real_ else suppressWarnings(as.numeric(p[[k]]))
        }
        nodes$x <- vapply(nodes$id, getc, numeric(1), "x")
        nodes$y <- vapply(nodes$id, getc, numeric(1), "y")
        any_missing <- any(is.na(nodes$x))
      }

      vn <- visNetwork::visNetwork(nodes, nd$edges,
        background = "transparent", width = "100%") |>
        visNetwork::visEdges(
          arrows = "to",
          color  = list(color = "#7a7f8f", highlight = "#f59e0b"),
          smooth = list(type = "cubicBezier", forceDirection = "horizontal")
        ) |>
        visNetwork::visNodes(font = list(size = 12))

      vn <- if (free) {
        vn |>
          visNetwork::visLayout(hierarchical = FALSE, improvedLayout = TRUE) |>
          visNetwork::visPhysics(enabled = any_missing,
            solver = "forceAtlas2Based",
            stabilization = list(enabled = TRUE, iterations = 150))
      } else {
        vn |>
          visNetwork::visLayout(hierarchical = list(
            enabled = TRUE, direction = mode, sortMethod = "directed",
            levelSeparation = 230, nodeSpacing = 150)) |>
          visNetwork::visPhysics(enabled = FALSE)
      }

      pos_js <- paste0(
        "function(){ Shiny.setInputValue('", ns("positions"),
        "', this.getPositions(), {priority:'event'}); }")

      vn |>
        visNetwork::visOptions(
          highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE),
          nodesIdSelection = FALSE
        ) |>
        visNetwork::visInteraction(tooltipDelay = 200, dragNodes = free) |>
        visNetwork::visEvents(
          selectNode = paste0(
            "function(properties) {",
            "  Shiny.setInputValue('", ns("selected_node"), "',",
            "    properties.nodes[0], {priority: 'event'});",
            "}"
          ),
          deselectNode = paste0(
            "function(properties) {",
            "  Shiny.setInputValue('", ns("selected_node"), "', null,",
            "    {priority: 'event'});",
            "}"
          ),
          oncontext = paste0(
            "function(properties) {",
            "  if (properties.nodes && properties.nodes.length > 0) {",
            "    if (properties.event && properties.event.preventDefault)",
            "      properties.event.preventDefault();",
            "    Shiny.setInputValue('", ns("context_node"), "',",
            "      properties.nodes[0], {priority: 'event'});",
            "  }",
            "}"
          ),
          dragEnd = pos_js,
          stabilizationIterationsDone = pos_js
        )
    })

    # Empty-state overlay with the two natural first actions. Buttons drive
    # the app-level inputs directly (raw ids — intentionally un-namespaced).
    output$empty_state <- renderUI({
      nd <- network_data()
      if (nrow(nd$nodes) > 0L) return(NULL)
      div(class = "ig-canvas-empty",
        div(class = "ig-canvas-empty-inner",
          icon("diagram-project", class = "ig-canvas-empty-icon"),
          h3("This flow is empty"),
          p(class = "text-muted",
            "Import a dataset or add a task to start building the pipeline."),
          div(class = "d-flex gap-2 justify-content-center",
            tags$button(class = "btn btn-primary btn-sm", type = "button",
              onclick = "Shiny.setInputValue('tree_add_src_click',Math.random(),{priority:'event'})",
              icon("database"), " Import data"),
            tags$button(class = "btn btn-outline-secondary btn-sm", type = "button",
              onclick = "document.getElementById('btn_add_task').click()",
              icon("plus"), " Add task")
          )
        )
      )
    })

    # Propagate node selection to store
    observeEvent(input$selected_node, {
      store$active_node <- input$selected_node
    })

    # Propagate right-click context node
    observeEvent(input$context_node, {
      rv_context(input$context_node)
    })

    # Return network data + context node for app.R
    list(network_data = network_data, context_node = rv_context)
  })
}
