test_that("bundled tutorials contain no Windows user-home paths in public text", {
  root <- system.file("examples", package = "IndividualGuide")
  expect_true(nzchar(root))
  archives <- list.files(root, pattern = "[.]igpx$", recursive = TRUE, full.names = TRUE)
  expect_length(archives, 22L)
  home <- "[A-Za-z]:[/\\\\]+Users[/\\\\]+"
  for (archive in archives) {
    directory <- tempfile("ig-public-check-"); dir.create(directory)
    tryCatch({
      utils::unzip(archive, exdir = directory)
      files <- list.files(directory, recursive = TRUE, full.names = TRUE)
      files <- files[grepl("[.](json|txt|csv|html|Rmd|R)$", files)]
      leaking <- files[vapply(files, function(file) any(grepl(home,
        readLines(file, warn = FALSE, encoding = "UTF-8"))), logical(1))]
      expect_equal(length(leaking), 0L, info = basename(dirname(archive)))
      for (file in list.files(directory, pattern = "[.]rds$", recursive = TRUE, full.names = TRUE)) {
        value <- readRDS(file)
        expect_false(grepl(home, rawToChar(serialize(value, NULL, ascii = TRUE))),
          info = paste(basename(dirname(archive)), basename(file)))
        if (inherits(value, "ggplot")) {
          image <- tempfile(fileext = ".png")
          ggplot2::ggsave(image, value, width = 3, height = 2, dpi = 60)
          expect_gt(file.info(image)$size, 1000)
          unlink(image)
        }
      }
    }, finally = unlink(directory, recursive = TRUE))
  }
  files <- list.files(root, recursive = TRUE, full.names = TRUE)
  files <- files[grepl("[.](json|txt|csv|html|Rmd|R)$", files)]
  expect_false(any(vapply(files, function(file) any(grepl(home,
    readLines(file, warn = FALSE, encoding = "UTF-8"))), logical(1))))
})
