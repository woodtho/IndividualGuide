# Verify the handbook's literal R examples and its first complete tutorial.
if (.Platform$OS.type == "windows") Sys.setlocale("LC_CTYPE", ".UTF-8")
root <- normalizePath(".", winslash = "/")
output <- Sys.getenv("BOOK_OUTPUT_DIR", file.path(root, "build/book"))
pkgload::load_all(root, export_all = FALSE, helpers = FALSE, attach_testthat = FALSE, quiet = TRUE)
ns <- asNamespace("IndividualGuide")
env <- new.env(parent = ns)
env$root <- root; env$output <- output
evalq({
  checks <- list()
  check <- function(name, value) {
    if (!isTRUE(value)) stop("Book check failed: ", name)
    checks[[name]] <<- TRUE
  }
  book <- paste(readLines(file.path(output, "Individual-Guide-Handbook.md"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  blocks <- regmatches(book, gregexpr("```r\n[\\s\\S]*?\n```", book, perl = TRUE))[[1L]]
  for (block in blocks) parse(text = sub("\n```$", "", sub("^```r\n", "", block)))
  check("all_printed_R_blocks_parse", length(blocks) >= 80L)
  check("iris_count", nrow(datasets::iris) == 150L)
  check("iris_species_counts", all(table(datasets::iris$Species) == 50L))
  check("sepal_mean", abs(mean(datasets::iris$Sepal.Length) - 5.8433333333) < 1e-8)
  means <- aggregate(Petal.Length ~ Species, datasets::iris, mean)$Petal.Length
  check("petal_means", isTRUE(all.equal(means, c(1.462, 4.260, 5.552), tolerance = 1e-10)))
  check("other_real_source_counts", identical(c(nrow(datasets::airquality), nrow(datasets::mtcars), nrow(datasets::ToothGrowth),
    nrow(datasets::PlantGrowth), nrow(datasets::warpbreaks), nrow(datasets::Puromycin), nrow(survival::lung)), c(153L,32L,60L,30L,54L,23L,228L)))
  check("series_counts", identical(c(length(datasets::nottem),length(datasets::AirPassengers),length(datasets::Nile)),c(240L,144L,100L)))
  inspect_xml_archive <- function(file, pattern) {
    directory <- tempfile("ig-book-xml-"); dir.create(directory)
    on.exit(unlink(directory, recursive = TRUE), add = TRUE)
    utils::unzip(file, exdir = directory)
    files <- list.files(directory, pattern = pattern, recursive = TRUE, full.names = TRUE)
    for (path in files) xml2::read_xml(path)
    length(files)
  }
  check("EPUB_XML_and_chapters_well_formed", inspect_xml_archive(file.path(output,"Individual-Guide-Handbook.epub"),"[.](xml|opf|ncx|xhtml)$") >= 20L)
  check("Word_XML_well_formed", inspect_xml_archive(file.path(output,"Individual-Guide-Handbook.docx"),"[.]xml$") >= 5L)
  work <- tempfile("ig-book-tutorial-"); dir.create(work)
  old <- setwd(work)
  Sys.setenv(IG_USER_DATA = file.path(work, "profile"))
  options(ig.background_workers = 0L, ig.recovery_dir = file.path(work,"recovery"), ig.catalogue_dir = file.path(work,"connections"))
  store <- make_store()
  flow <- make_flow("First Iris")
  store$flows <- setNames(list(flow),flow$id); store$active_flow <- flow$id
  add <- function(id, type, p) store_set_task(store, store_task_from_params(task_def(id,type),p))
  p <- default_script_params("flowers")
  tutorial <- paste(readLines(file.path(root,"docs/book/chapters/01-first-project.md"),encoding="UTF-8"),collapse="\n")
  source <- regmatches(tutorial,regexpr("```r\n[\\s\\S]*?\n```",tutorial,perl=TRUE))
  p$code <- sub("\n```$","",sub("^```r\n","",source)); add("source","script",p)
  p <- default_summary_stats_params("measurement_summary");p$input_table<-"flowers";p$cols<-names(datasets::iris)[1:4];add("summary","summary_stats",p)
  p <- default_summary_tables_params("species_summary");p$input_table<-"flowers";p$row_var<-"Species";p$value_var<-"Petal.Length";p$stat_fn<-"mean";add("groups","summary_tables",p)
  p <- default_phase3_params("scatter_plot","iris_scatter");p$input_table<-"flowers";p$x<-"Sepal.Length";p$y<-"Petal.Length";p$group<-"Species";p$title<-"Iris measurements by species"
  p$output_enabled$image<-TRUE;p$output_names$image<-"iris_scatter_image";add("chart","scatter_plot",p)
  p<-default_export_params();p$source<-"species_summary";p$dir<-work;p$filename<-"species-summary.csv";p$overwrite<-TRUE;add("csv","export",p)
  p<-default_export_params();p$source<-"iris_scatter_image";p$format<-"png";p$value_kind<-"image";p$dir<-work;p$filename<-"iris-scatter.png";p$dpi<-150;p$overwrite<-TRUE;add("png","export",p)
  p<-default_report_params("iris_report");p$title<-"First Iris report";p$include_log<-TRUE
  p$items<-lapply(c("measurement_summary","species_summary","iris_scatter_image"),function(name)list(name=name,heading=name));add("report","report",p)
  p<-default_export_log_params();p$path<-file.path(work,"iris-log.csv");p$format<-"csv";p$overwrite<-TRUE;p$after_tasks<-isolate(store$task_order);add("audit","export_log",p)
  for(id in isolate(store_topo_order(store$tasks,store$task_order)))check(paste0("tutorial_task_",id),isTRUE(isolate(run_task_from_store(store,id))))
  check("tutorial_raw_data",identical(isolate(store$tables$flowers),datasets::iris))
  check("tutorial_three_summary_rows",nrow(isolate(store$tables$species_summary))==3L)
  check("tutorial_csv",nrow(read.csv(file.path(work,"species-summary.csv")))==3L)
  check("tutorial_png",file.info(file.path(work,"iris-scatter.png"))$size>1000)
  logs<-read.csv(file.path(work,"iris-log.csv"));check("tutorial_custom_log",any(grepl("Loaded 150 flowers",logs$message,fixed=TRUE)))
  check("tutorial_report_completion_log",any(logs$task_id=="report"&logs$event=="success"))
  report<-isolate(store$tasks$report$outputs[[1]]$path);check("tutorial_report_appendix",grepl("Pipeline execution log",paste(readLines(report,warn=FALSE),collapse=""),fixed=TRUE))
  saved<-file.path(work,"first-iris.igpx");project_save(store,saved)
  other<-make_store();check("tutorial_reopen",isTRUE(project_load(other,saved)$ok))
  check("tutorial_reopened_data",identical(isolate(other$tables$flowers),datasets::iris))
  check("tutorial_reopened_report",file.exists(isolate(other$tasks$report$outputs[[1]]$path)))
  script<-isolate(build_full_r_script(store));writeLines(c(script,
    "stopifnot(!'IndividualGuide' %in% loadedNamespaces(), nrow(flowers)==150L)",
    "stopifnot(nrow(species_summary)==3L)"),file.path(work,"pipeline.R"))
  executable<-file.path(R.home("bin"),if(.Platform$OS.type=="windows")"Rscript.exe"else"Rscript")
  result<-system2(executable,c("--vanilla",shQuote(file.path(work,"pipeline.R"))),stdout=TRUE,stderr=TRUE)
  check("tutorial_generated_script_without_app",is.null(attr(result,"status")))
  setwd(old);project_release_assets(store);project_release_assets(other)
  jsonlite::write_json(list(ok=TRUE,RBlocks=length(blocks),checks=checks,work=work,
    markdownSha256=digest::digest(file=file.path(output,"Individual-Guide-Handbook.md"),algo="sha256")),file.path(output,"calculation-verification.json"),pretty=TRUE,auto_unbox=TRUE)
  cat("Verified",length(blocks),"printed R blocks and",length(checks),"worked tutorial checks.\n")
}, envir=env)
