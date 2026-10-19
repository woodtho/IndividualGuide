# Project persistence: .igpx save / load round trip.

iso <- shiny::isolate

test_that("project_save / project_load round-trips a full project", {
  store <- new_test_store(list(sales = sample_sales()))
  add_test_task(store, "fs_1", "filter_sort", inputs = "sales",
    params = list(input_table = "sales", filters = list(), sorts = list(),
                  output_name = "fs_out"))
  store_add_object(store, "fit", lm(qty ~ amount, sample_sales()),
                   meta = list(kind = "model"))
  store$task_favourites <- c("script", "rank")
  flow_id <- iso(store$active_flow)

  path <- tempfile(fileext = ".igpx")
  project_save(store, path, theme = "light")
  expect_true(file.exists(path))
  expect_false(iso(store$dirty))

  store2 <- make_store()
  result <- project_load(store2, path)
  expect_true(result$ok)
  expect_equal(result$theme, "light")

  expect_equal(iso(store2$active_flow), flow_id)
  expect_equal(names(iso(store2$tasks)), "fs_1")
  expect_equal(iso(store2$tasks)$fs_1$params$output_name, "fs_out")
  expect_equal(iso(store2$task_favourites), c("script", "rank"))

  sales2 <- iso(store2$tables)$sales
  expect_equal(as.data.frame(sales2), sample_sales())
  expect_s3_class(sales2$date, "Date")          # Date class survives JSON

  fit2 <- iso(store2$objects)$fit
  expect_s3_class(fit2$value, "lm")
  expect_equal(fit2$meta$kind, "model")
})

test_that("settings persist through a project round trip with key merging", {
  store <- new_test_store()
  store$settings <- list(page_length = 50L, plot_theme = "dark",
                         palette = "viridis", stop_on_error = TRUE,
                         confirm_delete = FALSE)
  path <- tempfile(fileext = ".igpx")
  project_save(store, path)

  store2 <- make_store()
  project_load(store2, path)
  s <- iso(store2$settings)
  expect_equal(s$page_length, 50L)
  expect_equal(s$plot_theme, "dark")
  expect_equal(s$palette, "viridis")
  expect_true(s$stop_on_error)
  expect_false(s$confirm_delete)

  # older projects without a settings block fall back to defaults
  store3 <- new_test_store()
  store3$settings <- list(page_length = 25L)   # partial — merge fills the rest
  path2 <- tempfile(fileext = ".igpx")
  project_save(store3, path2)
  store4 <- make_store()
  project_load(store4, path2)
  s4 <- iso(store4$settings)
  expect_equal(s4$page_length, 25L)
  expect_equal(s4$plot_theme, "clean")          # merged default
  expect_true(s4$confirm_delete)                # merged default
})

test_that("branch nodes persist through .igpx project round trips", {
  store <- new_test_store(list(sales = sample_sales()))
  p <- default_branch_params("gate")
  p$dependencies <- "sales"
  p$paths[[1]]$label <- "Enough rows"
  p$paths[[1]]$token <- "gate_true"
  p$paths[[1]]$condition <- list(op = "and", rules = list(
    list(kind = "row_count", table = "sales", op = ">", value = "3")
  ))
  p$paths[[2]]$label <- "Fallback"
  p$paths[[2]]$token <- "gate_else"

  branch <- task_def("branch_1", "branch", inputs = "sales", output = "", params = p)
  branch$outputs <- branch_output_specs(p)
  branch$branch_decision <- execute_branch(
    p, list(sales = sample_sales()), list(), list(), "branch_1"
  )
  iso(store_set_task(store, branch))

  path <- tempfile(fileext = ".igpx")
  project_save(store, path)
  store2 <- make_store()
  project_load(store2, path)

  restored <- iso(store2$tasks[["branch_1"]])
  expect_equal(restored$type, "branch")
  expect_equal(restored$output, "")
  expect_equal(vapply(restored$outputs, `[[`, character(1), "name"),
               c("gate_true", "gate_else"))
  expect_equal(restored$params$paths[[1]]$label, "Enough rows")
  expect_equal(restored$branch_decision$matched, "gate_true")
})

test_that("project_save skips lazy DB tables", {
  skip_if_not_installed("RSQLite")
  store <- new_test_store(list(sales = sample_sales()))
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "lazy_tbl", data.frame(x = 1:3))
  store_add_table(store, "lazy_tbl", dplyr::tbl(con, "lazy_tbl"))

  path <- tempfile(fileext = ".igpx")
  project_save(store, path)
  store2 <- make_store()
  project_load(store2, path)
  expect_true("sales" %in% names(iso(store2$tables)))
  expect_false("lazy_tbl" %in% names(iso(store2$tables)))
})

test_that("project_load rejects archives without a manifest", {
  bogus_dir <- tempfile(); dir.create(bogus_dir)
  writeLines("not a project", file.path(bogus_dir, "readme.txt"))
  bogus <- tempfile(fileext = ".igpx")
  old <- setwd(bogus_dir); on.exit(setwd(old))
  zip::zipr(bogus, "readme.txt")
  setwd(old)
  store <- make_store()
  expect_error(project_load(store, bogus), "manifest")
})

test_that("multi-flow projects restore the active flow", {
  store <- new_test_store()
  add_test_task(store, "fs_1", "filter_sort",
                params = list(output_name = "a_out", input_table = "",
                              filters = list(), sorts = list()))
  fl2 <- make_flow("Second")
  flows <- iso(store$flows); flows[[fl2$id]] <- fl2; store$flows <- flows
  store_activate_flow(store, fl2$id)
  add_test_task(store, "rk_1", "rank",
                params = list(output_name = "b_out", input_table = ""))

  path <- tempfile(fileext = ".igpx")
  project_save(store, path)

  store2 <- make_store()
  project_load(store2, path)
  expect_length(iso(store2$flows), 2L)
  expect_equal(iso(store2$active_flow), fl2$id)
  expect_equal(names(iso(store2$tasks)), "rk_1")
})

test_that("project name encoding handles awkward table names", {
  store <- new_test_store()
  store_add_table(store, "my table (v2)", data.frame(x = 1))
  path <- tempfile(fileext = ".igpx")
  project_save(store, path)
  store2 <- make_store()
  project_load(store2, path)
  expect_true("my table (v2)" %in% names(iso(store2$tables)))
})
