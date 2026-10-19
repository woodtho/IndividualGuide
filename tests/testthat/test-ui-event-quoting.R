test_that("UI event handlers send arbitrary names unchanged as JavaScript values", {
  node <- Sys.which("node")
  skip_if(!nzchar(node), "Node is not installed; covered by browser E2E instead")
  directory <- tempfile("ui_events_"); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  script <- file.path(directory, "events.js")
  result <- file.path(directory, "events.json")
  names <- c("ordinary", "a'b\"c\\d", "line\nbreak", "x'); throw new Error('broken'); //")
  handlers <- vapply(names, function(value) ig_input_event_js("panel'input", value, TRUE), character(1))
  writeLines(c("const events = []; let stopped = 0;",
    "const event = {stopPropagation: () => stopped++};",
    "const Shiny = {setInputValue: (id, value, options) => events.push({id, value, options})};",
    paste0(handlers, ";"),
    paste0("require('fs').writeFileSync(", as.character(jsonlite::toJSON(result, auto_unbox = TRUE)),
      ", JSON.stringify({events, stopped}));")), script, useBytes = TRUE)
  output <- system2(node, shQuote(script), stdout = TRUE, stderr = TRUE)
  expect_null(attr(output, "status"), info = paste(output, collapse = "\n"))
  actual <- jsonlite::read_json(result, simplifyVector = TRUE)
  expect_identical(actual$events$value, names)
  expect_true(all(actual$events$id == "panel'input"))
  expect_true(all(actual$events$options$priority == "event"))
  expect_equal(actual$stopped, length(names))
})
