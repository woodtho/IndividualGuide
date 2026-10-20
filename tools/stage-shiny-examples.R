# Public practice apps for the beginner handbook; no R code is executed here.
main <- function() {
  args <- commandArgs(TRUE)
  stopifnot(length(args) == 1L)
  output <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
  version <- unname(read.dcf("DESCRIPTION")[1L,"Version"])
  staging <- tempfile("shiny-examples-", tmpdir = output)
  dir.create(staging)
  staging <- normalizePath(staging, winslash = "/", mustWork = TRUE)
  stopifnot(startsWith(staging,paste0(output,"/")))
  on.exit(unlink(staging,recursive=TRUE))
  for (name in c("iris-explorer","local-sales"))
    stopifnot(file.copy(file.path("inst/shiny-apps",name),staging,recursive=TRUE))
  writeLines(c("Individual Guide - Shiny practice apps", "",
    "Extract the ZIP first. In Individual Guide, choose Open Shiny app.",
    "For the Iris example, choose iris-explorer/app.R.",
    "For the two-file example, choose the local-sales folder. Keep all its files together.",
    "These apps only need shiny, which Individual Guide includes.",
    "Use Individual Guide in the top bar to return to your project without stopping the app.",
    "Close app stops it. Save work before closing or replacing an app.", "",
    "Applications de pratique Shiny pour Individual Guide", "",
    "Extrayez d'abord le ZIP. Dans Individual Guide, choisissez Ouvrir une application Shiny.",
    "Pour les iris, choisissez iris-explorer/app.R.",
    "Pour le format à deux fichiers, choisissez le dossier local-sales. Gardez tous ses fichiers ensemble.",
    "Ces applications utilisent seulement shiny, qui est inclus dans Individual Guide.",
    "La barre du haut permet de revenir au projet sans arrêter l'application.",
    "Enregistrez le travail avant de fermer ou de remplacer une application.", "",
    "MIT License - Thomas Wood", "https://github.com/woodtho/IndividualGuide"),
    file.path(staging,"README.txt"),useBytes=TRUE)
  archive <- file.path(output,paste0("IndividualGuide-Shiny-Examples-",version,".zip"))
  stopifnot(file.copy("LICENSE.md",file.path(staging,"LICENSE.txt")))
  zip::zipr(archive,c("iris-explorer","local-sales","README.txt","LICENSE.txt"),root=staging)
  cat("Staged",basename(archive),"with two complete working Shiny apps.\n")
}
main()
