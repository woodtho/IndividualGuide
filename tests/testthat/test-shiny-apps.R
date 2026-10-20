test_that("app selection validates formats without running any app code", {
  directory <- tempfile("app path with spaces-"); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  marker <- file.path(directory, "must-not-run.txt")
  writeLines(sprintf('writeLines("executed", %s)', deparse(marker)), file.path(directory, "app.R"))
  expect_identical(ig_shiny_app_path(directory)$format, "app.R")
  expect_identical(ig_shiny_app_path(file.path(directory, "app.R"))$directory,
    normalizePath(directory, winslash = "/"))
  expect_false(file.exists(marker))
  writeLines("", file.path(directory, "ui.R"))
  expect_error(ig_shiny_app_path(file.path(directory, "ui.R")), "Choose app.R")
  unlink(file.path(directory, "app.R"))
  expect_error(ig_shiny_app_path(directory), "both ui.R and server.R")
  writeLines("", file.path(directory, "server.R"))
  expect_identical(ig_shiny_app_path(directory)$format, "ui.R + server.R")
  for (invalid in list(NULL, NA_character_, character(), c("a", "b"), "missing-directory"))
    expect_error(ig_shiny_app_path(invalid), "existing")
})

wait_for_host <- function(manager, phase = "ready", timeout = 45) {
  deadline <- Sys.time() + timeout
  repeat {
    state <- manager$poll(TRUE)
    if (state$phase == phase) return(state)
    if (state$phase == "failed" && phase != "failed") stop(state$log)
    if (Sys.time() > deadline) stop("App host did not reach ", phase, ": ", state$log)
    Sys.sleep(.05)
  }
}

test_that("real apps run separately and switch only after a valid trusted choice", {
  manager <- ig_shiny_app_manager(); on.exit(manager$dispose())
  first <- app_sys("shiny-apps", "iris-explorer", "app.R")
  second <- app_sys("shiny-apps", "local-sales")
  expect_error(manager$start(first), "trust")
  expect_identical(manager$start(first, TRUE)$phase, "starting")
  state <- wait_for_host(manager)
  first_pid <- state$pid
  expect_false(identical(first_pid, Sys.getpid()))
  expect_true(any(grepl("Iris explorer", readLines(state$url, warn = FALSE), fixed = TRUE)))
  expect_error(manager$start(file.path(second, "ui.R"), TRUE), "Choose app.R")
  expect_identical(manager$poll()$pid, first_pid)
  expect_true(manager$active())
  manager$start(second, TRUE)
  state <- wait_for_host(manager)
  expect_false(first_pid %in% ps::ps_pids())
  expect_true(any(grepl("Local sales", readLines(state$url, warn = FALSE), fixed = TRUE)))
  last_pid <- state$pid
  expect_identical(manager$stop()$phase, "idle")
  expect_false(manager$active())
  expect_false(last_pid %in% ps::ps_pids())
  expect_true(file.exists(file.path(second, "sales.csv")))
})

test_that("startup errors and timeouts leave the launcher recoverable", {
  directory <- tempfile("broken-app-"); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  writeLines('stop("Practice startup failure")', file.path(directory, "app.R"))
  manager <- ig_shiny_app_manager(); on.exit(manager$dispose())
  manager$start(directory, TRUE)
  state <- wait_for_host(manager, "failed")
  expect_match(state$log, "Practice startup failure", fixed = TRUE)
  expect_identical(state$url, "")
  manager$dispose()
  manager <- ig_shiny_app_manager(timeout = .5)
  writeLines('Sys.sleep(60)', file.path(directory, "app.R"))
  manager$start(directory, TRUE)
  state <- wait_for_host(manager, "failed")
  expect_match(state$message, "too long", fixed = TRUE)
  expect_false(manager$active())
  expect_identical(manager$stop()$phase, "idle")
})
