library(shiny)
fluidPage(
  titlePanel("Local sales / Ventes locales"),
  p("A two-file app with a local CSV and helper file. / Une application avec un fichier CSV local."),
  numericInput("minimum", "Minimum sales / Ventes minimales", value = 0, min = 0),
  tableOutput("sales"), textOutput("total"),
  downloadButton("download", "Download CSV / Télécharger le CSV")
)
