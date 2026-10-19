test_that("cold project restore registers methods for supported saved classes", {
  store <- new_test_store()
  store$tables <- list(typed = tibble::tibble(
    labelled = haven::labelled_spss(c(1, 9, NA_real_), na_values = 9),
    large = bit64::as.integer64(c("9007199254740993", NA_character_, "3")),
    clock = hms::hms(c(3661, NA_real_, 0)), bytes = blob::blob(as.raw(c(1, 2)), NULL, raw())))
  shiny::isolate({
    tables <- store$tables
    tables$tagged <- data.frame(x = c(haven::tagged_na("a"), haven::tagged_na("z"), NA_real_))
    store$tables <- tables
  })
  store$objects <- list(fit = list(value = forecast::ets(datasets::AirPassengers, model = "ANN"), meta = list(kind = "model")))
  path <- tempfile(fileext = ".igpx"); on.exit(unlink(path))
  shiny::isolate(project_save(store, path))
  cold <- function(app_path, path) {
    installed <- file.exists(file.path(app_path, "R/IndividualGuide.rdb"))
    if (installed) loadNamespace("IndividualGuide")
    else pkgload::load_all(app_path, export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
    ns <- asNamespace("IndividualGuide")
    before <- "haven" %in% loadedNamespaces()
    store <- get("make_store", ns)()
    get("project_load", ns)(store, path)
    table <- shiny::isolate(store$tables$typed)
    list(before = before, installed = installed, missing = sum(is.na(table$labelled)),
      large = as.character(table$large), clock = format(table$clock),
      tags = haven::na_tag(shiny::isolate(store$tables$tagged$x)),
      namespaces = c("haven", "bit64", "tibble", "forecast", "hms", "blob") %in% loadedNamespaces(),
      counts = shiny::isolate(get("store_col_info", ns)(store, "typed"))$n_missing)
  }
  environment(cold) <- baseenv()
  result <- callr::r(cold, args = list(app_path = getNamespaceInfo(asNamespace("IndividualGuide"), "path"), path = path),
    libpath = .libPaths(), system_profile = FALSE, user_profile = FALSE)
  # pkgload preloads DESCRIPTION imports in source tests. R CMD check uses the
  # installed package and exercises the genuinely cold namespace path.
  if (result$installed) expect_false(result$before)
  expect_identical(result$missing, 2L)
  expect_identical(result$large, c("9007199254740993", NA_character_, "3"))
  expect_identical(result$clock, format(shiny::isolate(store$tables$typed$clock)))
  expect_identical(result$tags, c("a", "z", NA_character_))
  expect_true(all(result$namespaces))
  expect_identical(result$counts, c(2L, 1L, 1L, 1L))
})

test_that("RDS/RData imports and generated imports retain typed missing-value semantics", {
  table <- data.frame(x = haven::labelled_spss(c(1, 9, NA_real_), na_values = 9))
  for (type in c("rds", "rda")) {
    path <- tempfile(fileext = paste0(".", type)); on.exit(unlink(path), add = TRUE)
    if (type == "rds") saveRDS(table, path) else save(table, file = path)
    p <- default_import_params("result"); p$path <- path; p$type <- type
    actual <- read_file_source(p)
    expect_identical(actual, table)
    env <- new.env(parent = globalenv())
    eval(parse(text = build_import_code(p)), env)
    expect_identical(env$result, table)
    expect_equal(sum(is.na(env$result$x)), 2)
  }
})
