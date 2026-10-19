if (.Platform$OS.type == "windows") Sys.setlocale("LC_CTYPE", ".UTF-8")
pkgload::load_all(quiet = TRUE)
codetools::checkUsagePackage("IndividualGuide")
