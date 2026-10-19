#' Render an R value as source without depending on the application at runtime.
#' @keywords internal
#' @param value Value supplied to the helper.
code_literal <- function(value) paste(capture.output(dput(value)), collapse = "\n")

# Builders invoked inside loops sometimes choose calculations by name. Declare
# those dependencies explicitly so their generated environment remains complete.
CODE_HELPER_DEPENDENCIES <- list(
  build_phase3_shared_code = c("execute_phase3_graph", ".p3_correlations", ".p3_pca",
    ".p3_cluster", ".p3_regression", ".p3_anova", ".p3_t_test_result", "execute_cdf_plot",
    "execute_probability_plot", "execute_control_chart", "execute_arima_forecast",
    "execute_life_tables", "execute_cox", "execute_nonlinear_regression"),
  build_report_code = "execute_report",
  build_import_code = c("ig_read_legacy_csv", "ig_restore_object_namespaces"),
  build_export_code = "ig_write_plot",
  build_export_log_code = c("ig_write_log", "ig_log_records")
)

#' Collect the pure helper functions needed by generated iteration code.
#' @keywords internal
#' @param names Names of pure helper functions to embed in standalone code.
code_helper_definitions <- function(names, emit = FALSE, overrides = list()) {
  registry <- getOption("IndividualGuide.codegen_helpers")
  if (is.environment(registry)) {
    registry$roots <- union(registry$roots, names)
    registry$overrides <- utils::modifyList(registry$overrides %||% list(), overrides)
    if (!emit) return(character(0))
    names <- registry$roots
    overrides <- registry$overrides
  }
  namespace <- environment(code_helper_definitions)
  available <- union(ls(namespace, all.names = TRUE), names(overrides))
  visited <- character(0)
  definitions <- character(0)
  visit <- function(name) {
    if (name %in% visited || !name %in% available) return(invisible(NULL))
    visited <<- c(visited, name)
    object <- overrides[[name]] %||% get(name, namespace, inherits = FALSE)
    if (is.function(object)) {
      dependencies <- intersect(c(all.names(body(object), functions = TRUE, unique = TRUE),
        CODE_HELPER_DEPENDENCIES[[name]]), available)
      for (dependency in setdiff(dependencies, name)) visit(dependency)
      source <- paste(deparse(object, width.cutoff = 100L), collapse = "\n")
    } else if (is.atomic(object) || is.list(object)) {
      source <- code_literal(object)
    } else stop("Cannot export code helper: ", name)
    definitions <<- c(definitions, paste0(r_ident(name), " <- ", source))
    invisible(NULL)
  }
  for (name in names) visit(name)
  c(".ig_codegen <- local({",
    "  .scope <- environment()",
    "  if (exists('.ig_codegen', inherits = TRUE) && is.environment(get('.ig_codegen', inherits = TRUE))) parent.env(.scope) <- get('.ig_codegen', inherits = TRUE)",
    "  rm(.scope)",
    paste0("  ", unlist(strsplit(definitions, "\n", fixed = TRUE))),
    "  environment()", "})")
}

#' Return visible data objects for generated dataset/group iteration sources.
#' @keywords internal
#' @param root Project archive staging directory.
#' @param envir Environment whose visible data objects are inspected.
code_visible_tables <- function(envir, root) {
  names <- character(0)
  current <- envir
  repeat {
    names <- union(names, ls(current, all.names = TRUE))
    if (identical(current, root) || identical(current, emptyenv())) break
    current <- parent.env(current)
  }
  values <- mget(names, envir = envir, inherits = TRUE)
  Filter(function(x) is.data.frame(x) || inherits(x, "tbl_sql"), values)
}

#' Assemble dependency guards, branch gates and real repeated loop bodies.
#' @keywords internal
#' @param tasks Named list of task definitions.
#' @param order Task identifiers in dependency execution order.
#' @param snippets Generated R source snippets keyed by task identifier.
#' @param stop_on_error Whether to stop after the first failed task or iteration.
#' @param project_seed Optional fixed seed applied separately to each task.
build_control_flow_code <- function(tasks, order, snippets, stop_on_error = FALSE, project_seed = NULL) {
  literal <- code_literal
  indent <- code_indent_lines
  owners <- store_task_output_owner(tasks)
  outputs <- lapply(tasks, function(task) {
    if (task$type == "loop") return(vapply(loop_output_specs(task$params), `[[`, character(1), "name"))
    task_output_names(task)
  })
  runtime_name <- code_runtime_name(tasks)
  helpers <- c("ig_code_run_task", "ig_code_completed", "ig_log_event")
  has_loops <- any(vapply(tasks, function(task) identical(task$type, "loop"), logical(1)))
  if (has_loops) helpers <- c(helpers, "loop_iteration_records", "loop_result_name", "loop_substitute_params", "code_visible_tables")
  has_placeholder <- function(value, field = "") {
    if (field %in% c("code", "expr", "custom_expr", "naming_rule")) return(FALSE)
    if (is.character(value)) return(any(grepl("{item}", value, fixed = TRUE) | grepl("{index}", value, fixed = TRUE)))
    if (!is.list(value)) return(FALSE)
    any(vapply(seq_along(value), function(i) has_placeholder(value[[i]], if (is.null(names(value))) field else names(value)[[i]]), logical(1)))
  }
  guard <- function(task) {
    ids <- if (task$type %in% c("branch", "export_log")) character(0) else store_task_dependency_ids(task, tasks, owners)
    parts <- if (length(ids)) sprintf("%s$completed(%s)", runtime_name, literal(ids)) else "TRUE"
    control <- Filter(function(input) {
      owner <- owners[[input]]
      !is.null(owner) && input %in% task_output_names(tasks[[owner]], "branch")
    }, task$inputs %||% character(0))
    groups <- split(control, vapply(control, function(x) owners[[x]], character(1)))
    for (tokens in groups) parts <- c(parts, sprintf("any(vapply(%s, function(token) isTRUE(.ig_control[[token]]), logical(1)))", literal(tokens)))
    paste(parts, collapse = " && ")
  }
  regular_code <- function(id, in_loop) {
    task <- tasks[[id]]
    if (in_loop && !task$type %in% c("script", "list_data") && has_placeholder(task$params)) {
      builder <- task_code_builder_name(task$type)
      helpers <<- union(helpers, builder)
      call <- if (task$type %in% PHASE3_TYPES) {
        sprintf(".ig_codegen$%s(%s, .ig_params)", builder, literal(task$type))
      } else sprintf(".ig_codegen$%s(.ig_params)", builder)
      return(c(sprintf(".ig_params <- .ig_codegen$loop_substitute_params(%s, .ig_record, .ig_index)", literal(task$params)),
        sprintf(".task_params[[%s]] <- .ig_params", literal(id)),
        "local({", "  support <- .ig_codegen", "  target <- parent.env(environment())",
        sprintf("  tryCatch(eval(parse(text = %s), envir = target),", call),
        "    finally = assign('.ig_codegen', support, envir = target))", "})"))
    }
    snippets[[id]]$body %||% paste0("stop(", literal(paste("Configure task", id, "before exporting code.")), ")")
  }
  wrap <- function(id, code, in_loop = FALSE) {
    task <- tasks[[id]]
    condition <- guard(task)
    args <- c(if (!identical(condition, "TRUE")) paste0("when = ", condition), if (in_loop) "in_loop = TRUE")
    c(paste0("# ", gsub("[\r\n]+", " ", task$label %||% task_type_info(task$type)$label %||% task$type), " (", id, ") ----"),
      sprintf("%s$run_task(%s, {", runtime_name, literal(id)), indent(code),
      paste0("}", if (length(args)) paste0(", ", paste(args, collapse = ", ")), ")"), "")
  }
  emit <- function(ids, in_loop = FALSE) {
    lines <- character(0)
    consumed <- character(0)
    for (id in ids) {
      if (id %in% consumed) next
      task <- tasks[[id]]
      if (task$type != "loop") {
        lines <- c(lines, wrap(id, regular_code(id, in_loop), in_loop))
        next
      }
      body <- intersect(ids, store_task_descendants(tasks, id))
      body <- Filter(function(task_id) !identical(tasks[[task_id]]$type, "export_log") ||
        length(tasks[[task_id]]$control_inputs %||% character(0)) > 0L, body)
      consumed <- union(consumed, body)
      body_code <- emit(body, in_loop = TRUE)
      p <- task$params
      excluded <- unique(unlist(outputs[c(id, body)], use.names = FALSE))
      retained <- character(0)
      planned <- character(0)
      for (body_id in body) {
        body_outputs <- outputs[[body_id]]
        for (j in seq_along(body_outputs)) {
          out <- body_outputs[[j]]
          planned <- c(planned,
            sprintf(".ig_codegen$loop_result_name(.ig_loop_params, %s, %s, .ig_records[[i]], i, %s, .ig_prefix)",
              literal(body_id), literal(out), if (j > 1L) "TRUE" else "FALSE"))
          retained <- c(retained,
            sprintf("if (exists(%s, envir = environment(), inherits = FALSE)) {", literal(out)),
            sprintf("  .ig_name <- .ig_codegen$loop_result_name(.ig_loop_params, %s, %s, .ig_record, .ig_index, %s, .ig_prefix)", literal(body_id), literal(out), if (j > 1L) "TRUE" else "FALSE"),
            sprintf("  assign(.ig_name, get(%s, envir = environment()), envir = .ig_root_env)", literal(out)),
            "  for (.ig_ancestor in .ig_loop_ancestor_keys) .ig_loop_output_names[[.ig_ancestor]] <- unique(c(.ig_loop_output_names[[.ig_ancestor]], .ig_name))", "}")
        }
      }
      loop_code <- c("local({", "  .ig_parent <- parent.env(environment())",
        "  .task_status <- .task_status", "  .ig_control <- .ig_control",
        sprintf("  .ig_loop_params <- %s", literal(p)),
        "  .ig_prefix <- if (exists('.ig_loop_prefix', inherits = TRUE)) .ig_loop_prefix else ''",
        sprintf("  .ig_loop_key <- paste0(.ig_prefix, %s)", literal(id)),
        "  .ig_loop_ancestor_keys <- c(if (exists('.ig_loop_ancestor_keys', inherits = TRUE)) .ig_loop_ancestor_keys else character(0), .ig_loop_key)",
        "  .ig_tables <- .ig_codegen$code_visible_tables(environment(), .ig_root_env)",
        "  .ig_previous <- .ig_loop_output_names[[.ig_loop_key]]",
        "  .ig_ancestor_outputs <- unlist(.ig_loop_output_names[.ig_loop_ancestor_keys], use.names = FALSE)",
        sprintf("  .ig_tables <- .ig_tables[setdiff(names(.ig_tables), c(%s, .ig_ancestor_outputs))]", literal(excluded)),
        "  .ig_records <- .ig_codegen$loop_iteration_records(.ig_loop_params, .ig_tables)",
        "  if (!length(.ig_records)) stop('Loop has no iterations to run.')",
        sprintf("  .ig_plan <- unlist(lapply(seq_along(.ig_records), function(i) c(%s)), use.names = FALSE)", paste(planned, collapse = ", ")),
        "  if (anyDuplicated(.ig_plan)) stop('Loop output names collide. Include {index} or {output} in the output naming rule.')",
        "  if (length(intersect(.ig_plan, names(.ig_tables)))) stop('Loop output names conflict with existing project data.')",
        "  rm(list = intersect(.ig_previous, ls(.ig_root_env, all.names = TRUE)), envir = .ig_root_env)",
        "  .ig_loop_output_names[[.ig_loop_key]] <- character(0)",
        sprintf("  .ig_failed <- setNames(rep(FALSE, %dL), %s)", length(body), literal(body)),
        "  for (.ig_index in seq_along(.ig_records)) {",
        "    .ig_record <- .ig_records[[.ig_index]]",
        "    assign(.ig_loop_params$variable, .ig_record$value, envir = environment())",
        "    if (!is.null(.ig_record$data)) {",
        "      .loop_data <- .ig_record$data",
        "      if (nzchar(.ig_loop_params$source)) assign(.ig_loop_params$source, .loop_data, envir = environment())",
        "    }",
        sprintf("    .ig_loop_prefix <- paste0(.ig_prefix, %s, '_', gsub('[^[:alnum:]_.-]', '_', .ig_record$label), '_')", literal(id)),
        sprintf("    .task_status[%s] <- 'pending'", literal(body)),
        sprintf("    .task_status[[%s]] <- 'success'", literal(id)),
        sprintf("    .ig_control[[%s]] <- TRUE", literal(p$output_token)),
        indent(body_code, 4L), indent(retained, 4L),
        sprintf("    .ig_failed <- .ig_failed | vapply(.task_status[%s], identical, logical(1), 'error')", literal(body)),
        "  }",
        sprintf("  .task_status[names(.ig_failed)[.ig_failed]] <- 'error'"),
        "  .ig_status <- get('.task_status', envir = .ig_parent, inherits = TRUE)",
        sprintf("  .ig_status[%s] <- .task_status[%s]", literal(body), literal(body)),
        "  assign('.task_status', .ig_status, envir = .ig_parent)",
        "  assign('.ig_loop_output_names', .ig_loop_output_names, envir = .ig_parent)",
        sprintf("  for (.ig_output in %s) if (exists(.ig_output, envir = environment(), inherits = FALSE)) assign(.ig_output, get(.ig_output), envir = .ig_parent)", literal(unique(unlist(outputs[body], use.names = FALSE)))),
        "  if (any(.ig_failed)) stop('One or more loop iterations failed. See task warnings.')", "})")
      lines <- c(lines, wrap(id, loop_code, in_loop))
    }
    lines
  }
  body <- emit(order)
  prelude <- c(".ig_root_env <- environment()",
    sprintf(".ig_stop_on_error <- %s", if (isTRUE(stop_on_error)) "TRUE" else "FALSE"),
    sprintf(".task_status <- setNames(as.list(rep('pending', %dL)), %s)", length(tasks), literal(names(tasks))),
    sprintf(".task_params <- %s", literal(lapply(tasks, function(task) task$params %||% list()))),
    ".ig_control <- list()",
    ".ig_task_logs <- new.env(parent = emptyenv())",
    ".ig_task_logs$tasks <- list()")
  if (has_loops) prelude <- c(prelude,
    "if (!exists('.ig_loop_output_names', inherits = FALSE)) .ig_loop_output_names <- list()")
  prelude <- c(prelude, "", "# Shared support functions ----", code_helper_definitions(helpers, emit = TRUE),
    paste0(runtime_name, " <- .ig_codegen"), paste0(runtime_name, "$run_task <- ", runtime_name, "$ig_code_run_task"),
    paste0(runtime_name, "$project_seed <- ", literal(project_seed)),
    paste0(runtime_name, "$completed <- ", runtime_name, "$ig_code_completed"),
    if (has_loops) paste0(runtime_name, "$substitute_params <- ", runtime_name, "$loop_substitute_params"),
    "", "# Task metadata and custom logging ----", paste0(runtime_name, "$steps <- ", literal(code_step_definitions(tasks))),
    paste0("log_event <- ", runtime_name, "$ig_log_event"))
  c(prelude, "", "# Pipeline ----", body)
}
