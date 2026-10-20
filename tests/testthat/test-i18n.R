test_that("language is a presentation preference with a safe English fallback", {
  expect_identical(ig_language("fr-CA"), "fr-CA")
  expect_identical(ig_language("fr_CA"), "fr-CA")
  expect_identical(ig_language("en-CA"), "en-CA")
  expect_identical(ig_language("unknown"), "en-CA")
  expect_identical(ig_language(character()), "en-CA")
  expect_identical(ig_language(NA_character_), "en-CA")
  expect_identical(ig_language(c("fr-CA", "en-CA")), "en-CA")
})

test_that("literal UI choices are marked without changing their values", {
  view <- selectInput("method", "Method", c("Mean"="mean", "Median"="median"))
  html <- as.character(view)
  expect_match(html, 'data-ig-choice-labels="true"', fixed=TRUE)
  expect_match(html, 'value="mean"', fixed=TRUE)
  expect_match(html, 'value="median"', fixed=TRUE)
  columns <- c("Source", "Mean", "Échantillon")
  view <- selectInput("columns", "Columns", columns)
  html <- as.character(view)
  expect_match(html, 'data-ig-choice-labels="false"', fixed=TRUE)
  expect_match(html, 'value="Source"', fixed=TRUE)
  expect_match(html, 'value="Mean"', fixed=TRUE)
  expect_identical(columns, c("Source", "Mean", "Échantillon"))
  events <- as.character(selectInput("event", "When", ig_log_triggers()))
  expect_match(events,'data-ig-choice-labels="true"',fixed=TRUE)
  fields <- as.character(selectInput("field","Field",stats::setNames(paste0("{",ig_log_fields(),"}"),names(ig_log_fields()))))
  expect_match(fields,'data-ig-choice-labels="true"',fixed=TRUE)
  styles <- as.character(selectInput("render","Render style",REPORT_RENDER_CHOICES))
  expect_match(styles,'data-ig-choice-labels="true"',fixed=TRUE)
  dynamic <- as.character(selectInput("inputs","Inputs",stats::setNames(columns,columns)))
  expect_match(dynamic,'data-ig-choice-labels="false"',fixed=TRUE)
})

test_that("language changes are independent between browser sessions", {
  server <- function(input, output, session) {
    output$language <- shiny::renderText(ig_language())
  }
  shiny::testServer(server, {
    session$setInputs(ig_language="fr-CA")
    expect_identical(output$language, "fr-CA")
  })
  shiny::testServer(server, {
    session$setInputs(ig_language="en-CA")
    expect_identical(output$language, "en-CA")
  })
})

test_that("task searches accept Canadian French without renaming project data",{
  store <- make_store()
  isolate({
    store$tasks <- list(analysis_task=list(id="analysis_task",type="summary_stats",label="Custom summary",r_code="",note=""))
    store$tables <- list(Mean=data.frame(Source="Mean"))
  })
  before <- isolate(store$tasks)
  expect_identical(store_search(store,"statistiques")$id,"analysis_task")
  expect_true("analysis_task" %in% store_search(store,"Summary Statistics")$id)
  expect_true("Mean" %in% store_search(store,"Mean")$id)
  expect_identical(isolate(store$tasks),before)
  expect_identical(isolate(store$tables$Mean$Source),"Mean")
})
