# RDS/JSON retain S3 class names but need not load the package that implements
# their methods. Restore the app's supported types on demand after decoding.
ig_restore_object_namespaces <- function(value) {
  owners <- c(haven_labelled = "haven", haven_labelled_spss = "haven",
    integer64 = "bit64", tbl_df = "tibble", spec_tbl_df = "readr",
    grouped_df = "dplyr", rowwise_df = "dplyr", hms = "hms", blob = "blob",
    vctrs_vctr = "vctrs", vctrs_list_of = "vctrs",
    coxph = "survival", coxph.null = "survival", survfit = "survival", Surv = "survival",
    Arima = "forecast", forecast_ARIMA = "forecast", forecast = "forecast", ets = "forecast", msts = "forecast",
    ggplot = "ggplot2", "ggplot2::ggplot" = "ggplot2", girafe = "ggiraph",
    htmlwidget = "htmlwidgets", gt_tbl = "gt")
  walk <- function(x) {
    packages <- unique(unname(owners[intersect(class(x), names(owners))]))
    for (package in packages) if (!isNamespaceLoaded(package)) loadNamespace(package)
    # Atomic columns need only their class metadata; never scan their rows.
    # Environments are not traversed, so cyclic model environments stay safe.
    if (is.list(x)) for (item in x) walk(item)
    invisible(NULL)
  }
  walk(value)
  value
}
