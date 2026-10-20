# Render/inspect the offline handbook with a real Chromium browser, then inspect
# the resulting PDF through Poppler. Only owned book output/profile paths used.
if (.Platform$OS.type == "windows") Sys.setlocale("LC_CTYPE", ".UTF-8")
root <- normalizePath(".", winslash = "/")
output <- Sys.getenv("BOOK_OUTPUT_DIR", file.path(root, "build/book"))
output <- normalizePath(output, winslash = "/", mustWork = TRUE)
metadata <- jsonlite::read_json(file.path(output,"book-metadata.json"))
french <- identical(metadata$lang,"fr-CA")
edge <- "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
if (!nzchar(Sys.getenv("CHROMOTE_CHROME")) && file.exists(edge)) Sys.setenv(CHROMOTE_CHROME = edge)
options(chromote.timeout = 180)
browser <- chromote::Chromote$new(browser = chromote::Chrome$new(args = c(
  chromote::default_chrome_args(), "--no-first-run", "--no-default-browser-check",
  "--disable-sync", "--disable-background-networking")))
chromote::set_default_chromote_object(browser)
browser$default_timeout <- 180
page <- chromote::ChromoteSession$new(width = 1440, height = 1000)
main <- function() {
  on.exit({ try(page$close(), silent = TRUE); try(browser$close(), silent = TRUE) }, add = TRUE)
  evaluate <- function(js) {
    value <- page$Runtime$evaluate(js, returnByValue = TRUE, awaitPromise = TRUE)
    if (!is.null(value$exceptionDetails)) stop(jsonlite::toJSON(value$exceptionDetails, auto_unbox = TRUE))
    value$result$value
  }
  shot <- function(file) {
    value <- page$Page$captureScreenshot(format = "png", captureBeyondViewport = FALSE)
    writeBin(jsonlite::base64_dec(value$data), file)
  }
  if ("--assets-only" %in% commandArgs(TRUE)) {
    page$Emulation$setDeviceMetricsOverride(width = 2000L, height = 580L, deviceScaleFactor = 1, mobile = FALSE)
    svg <- paste0("file:///", utils::URLencode(file.path(root, "docs/book/assets/workflow.svg"), reserved = FALSE))
    page$go_to(svg)
    shot(file.path(root, "docs/book/assets/workflow.png"))
    cat("Rasterized the editable workflow diagram for all book formats.\n")
    return(invisible(NULL))
  }
  url <- paste0("file:///", utils::URLencode(file.path(output, "Individual-Guide-Handbook.html"), reserved = FALSE))
  page$go_to(url)
  evaluate("document.fonts.ready.then(()=>true)")
  stopifnot(evaluate("Array.from(document.images).every(image=>image.complete&&image.naturalWidth>0)"))
  checks <- list()
  checks$htmlSha256 <- digest::digest(file = file.path(output,"Individual-Guide-Handbook.html"), algo = "sha256")
  checks$images <- evaluate("Array.from(document.images).map(image=>({alt:image.alt,width:image.naturalWidth,height:image.naturalHeight}))")
  checks$figures <- evaluate("Array.from(document.querySelectorAll('figure')).map(figure=>({caption:figure.querySelector('figcaption')?.textContent.trim(),alt:figure.querySelector('img')?.alt,width:figure.querySelector('img')?.getBoundingClientRect().width}))")
  stopifnot(length(checks$figures) >= 25L,
    all(vapply(checks$figures, function(figure) nzchar(figure$alt) &&
      grepl('^Figure [0-9]+[.]', figure$caption) && figure$width > 150, logical(1))))
  checks$anchors <- evaluate("(() => {const ids=Array.from(document.querySelectorAll('[id]')).map(e=>e.id);return {duplicate:ids.filter((id,i)=>ids.indexOf(id)!==i),missing:Array.from(document.querySelectorAll('a[href^=\"#\"]')).map(a=>a.getAttribute('href').slice(1)).filter(id=>id&&!document.getElementById(decodeURIComponent(id)))};})()")
  stopifnot(length(checks$anchors$duplicate) == 0L, length(checks$anchors$missing) == 0L)
  checks$language <- evaluate("document.documentElement.lang")
  stopifnot(identical(checks$language,metadata$lang))
  checks$sourceEdition <- evaluate(paste0("document.body.innerText.includes(",jsonlite::toJSON(paste0(metadata$version,"-Setup-Windows-x64.exe"),auto_unbox=TRUE),")&&document.body.innerText.includes(",jsonlite::toJSON(if(french)"58 types de tâches" else "58 task",auto_unbox=TRUE),")"))
  search_text <- if(french)"Analyse de regroupement" else "Cluster Analysis"
  checks$filter <- evaluate(paste0("(() => {const term=",jsonlite::toJSON(search_text,auto_unbox=TRUE),";const s=document.getElementById('toc-search');s.value=term;s.dispatchEvent(new Event('input'));const rows=Array.from(document.querySelectorAll('#TOC li')).filter(li=>!li.hidden);const ok=rows.some(li=>li.textContent.includes(term))&&rows.length<20;s.value='';s.dispatchEvent(new Event('input'));return ok;})()"))
  stopifnot(isTRUE(checks$sourceEdition), isTRUE(checks$filter))
  shot(file.path(output, "book-desktop.png"))
  checks$layouts <- list()
  for (width in c(1440L, 1024L, 390L)) {
    page$Emulation$setDeviceMetricsOverride(width = width, height = 1000L, deviceScaleFactor = 1, mobile = FALSE)
    evaluate("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve(true))))")
    layout <- evaluate("({width:innerWidth,scrollWidth:document.documentElement.scrollWidth,mainWidth:document.querySelector('main').getBoundingClientRect().width})")
    stopifnot(layout$scrollWidth <= width + 1, layout$mainWidth > 0)
    checks$layouts[[as.character(width)]] <- layout
    if (width != 1440L) shot(file.path(output, paste0("book-", width, ".png")))
  }
  page$Emulation$setDeviceMetricsOverride(width = 1440L, height = 1000L, deviceScaleFactor = 1, mobile = FALSE)
  evaluate("document.documentElement.style.scrollBehavior='auto';document.getElementById('task-cluster_analysis').scrollIntoView();new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve(true))))")
  checks$taskReferenceVisible <- evaluate("(() => {const r=document.getElementById('task-cluster_analysis').getBoundingClientRect();return r.top>=0&&r.top<innerHeight;})()")
  stopifnot(isTRUE(checks$taskReferenceVisible))
  shot(file.path(output, "book-task-reference.png"))
  evaluate("document.querySelectorAll('h1,h2,h3,h4').forEach(heading=>heading.setAttribute('aria-label',heading.textContent.trim()));true")
  page$Emulation$setEmulatedMedia(media = "print")
  checks$taskFinderCellPadding <- evaluate("parseFloat(getComputedStyle(document.getElementById('task-finder').nextElementSibling.nextElementSibling.querySelector('td')).paddingTop)")
  stopifnot(checks$taskFinderCellPadding > 4, checks$taskFinderCellPadding < 6)
  pdf <- page$Page$printToPDF(printBackground = TRUE, preferCSSPageSize = TRUE,
    displayHeaderFooter = TRUE,
    headerTemplate = paste0('<div style="font-family:Arial;font-size:8px;width:100%;text-align:center;color:#65748b">',metadata$title,' · ',if(french)'Version ' else 'Release ',metadata$version,'</div>'),
    footerTemplate = '<div style="font-family:Arial;font-size:8px;width:100%;text-align:center;color:#65748b"><span class="pageNumber"></span> / <span class="totalPages"></span></div>',
    generateTaggedPDF = TRUE, generateDocumentOutline = TRUE)
  pdf_path <- file.path(output, "Individual-Guide-Handbook.pdf")
  writeBin(jsonlite::base64_dec(pdf$data), pdf_path)
  if (!requireNamespace("pdftools", quietly = TRUE)) stop("Install pdftools in the documentation-development R library to verify PDF text/layout.")
  info <- pdftools::pdf_info(pdf_path)
  texts <- pdftools::pdf_text(pdf_path)
  writeLines(texts, file.path(output, "pdf-text.txt"), useBytes = TRUE)
  checks$pdf <- list(pages = info$pages, bytes = file.info(pdf_path)$size,
    textCharacters = sum(nchar(texts)), nonemptyPages = sum(nchar(trimws(texts)) > 80),
    fonts = pdftools::pdf_fonts(pdf_path))
  checks$pdf$sha256 <- digest::digest(file = pdf_path, algo = "sha256")
  checks$pdf$outline <- pdftools::pdf_toc(pdf_path)
  stopifnot(length(checks$pdf$outline) > 0L)
  stopifnot(info$pages >= 20L, all(nchar(trimws(texts)) > 80L))
  figure_pages <- which(grepl("Figure[[:space:]]+[[:digit:]]+[.]", texts))
  selected <- sort(unique(as.integer(c(1, 3, figure_pages, round(info$pages / 3), round(info$pages * 2/3), info$pages))))
  images <- pdftools::pdf_convert(pdf_path, format = "png", pages = selected, dpi = 80,
    filenames = file.path(output, paste0("pdf-page-", selected, ".png")), verbose = FALSE)
  checks$pdf$samplePages <- selected
  checks$ok <- TRUE
  jsonlite::write_json(checks, file.path(output, "render-verification.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")
  cat("Rendered and inspected", info$pages, "PDF pages.\n")
}
main()
