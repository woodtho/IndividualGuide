#' Generate one task's R code directly from its authoritative configuration.
#' @param task A task definition from the store.
#' @return A scalar character string; errors identify invalid configurations.
#' @keywords internal
build_task_code <- function(task) {
  p <- task$params %||% list()
  type <- task$type %||% ""
  # Older saved tasks may carry only code. Preserve those snippets verbatim.
  if (!length(p) && nzchar(task$r_code %||% "")) return(task$r_code)
  if (type %in% PHASE3_TYPES) return(code_use_namespace(build_phase3_code(type, p)))
  name <- task_code_builder_name(type)
  if (identical(type, "script")) return(p$code %||% "")
  if (identical(type, "list_data")) {
    return(paste0(r_ident(p$output_name %||% ".ig_preview"), " <- ", r_ident(p$input_table)))
  }
  if (is.null(name)) stop("No code builder for task type: ", type)
  if (identical(p$output_enabled, FALSE)) p$output_name <- ".ig_preview"
  code_use_namespace(get(name, envir = environment(build_task_code))(p))
}

#' Look up a task's pure code builder for reusable generated loop helpers.
#' @keywords internal
#' @param type Registered task type identifier.
task_code_builder_name <- function(type) {
  if (type %in% PHASE3_TYPES) return("build_phase3_code")
  mapping <- c(
    import_data = "build_import_code",
    query_builder = "build_query_code",
    append_table = "build_append_code",
    compare_data = "build_compare_code",
    filter_sort = "build_fs_code",
    stack_columns = "build_stack_code",
    split_columns = "build_split_code",
    transpose = "build_transpose_code",
    rank = "build_rank_code",
    standardize = "build_std_code",
    random_sample = "build_sample_code",
    remove_dups = "build_dedup_code",
    keep_drop_cols = "build_keepdrop_code",
    rename_cols = "build_rename_code",
    first_last_n = "build_firstlast_code",
    replace_missing = "build_fillna_code",
    derive_cols = "build_derive_code",
    recode_values = "build_recode_code",
    change_types = "build_changetype_code",
    characterize = "build_char_code",
    one_way_freq = "build_freq_code",
    summary_stats = "build_stats_code",
    table_analysis = "build_table_analysis_code",
    summary_tables = "build_st_code",
    distribution = "build_dist_code",
    report = "build_report_code",
    export = "build_export_code",
    export_log = "build_export_log_code",
    branch = "build_branch_code",
    loop = "build_loop_code")
  if (!type %in% names(mapping)) return(NULL)
  unname(mapping[[type]])
}
