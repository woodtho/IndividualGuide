# A complete practice app. It only needs the public shiny package.
library(shiny)
ui <- fluidPage(
  titlePanel(textOutput("app_title"), windowTitle = "Iris explorer"),
  selectInput("language", "Language / Langue", c("English" = "en", "Français (Canada)" = "fr"), selectize = FALSE),
  uiOutput("controls"), plotOutput("chart"), textOutput("count")
)
server <- function(input, output, session) {
  french <- reactive(identical(input$language, "fr"))
  output$app_title <- renderText(if (french()) "Explorer les iris" else "Iris explorer")
  output$controls <- renderUI(tagList(
    selectInput("species", if (french()) "Espèce" else "Species",
      setNames(c("all", levels(iris$Species)), c(if (french()) "Toutes" else "All", levels(iris$Species))), selectize = FALSE),
    sliderInput("bins", if (french()) "Nombre de barres" else "Number of bars", min = 3, max = 25, value = 10)
  ))
  flowers <- reactive({
    req(input$species)
    if (input$species == "all") iris else iris[iris$Species == input$species, , drop = FALSE]
  })
  output$chart <- renderPlot({
    req(input$bins)
    hist(flowers()$Sepal.Length, breaks = input$bins, col = "#4966d9", border = "white",
      main = if (french()) "Longueur des sépales" else "Sepal length",
      xlab = if (french()) "Longueur (cm)" else "Length (cm)", ylab = if (french()) "Fleurs" else "Flowers")
  })
  output$count <- renderText(paste(nrow(flowers()), if (french()) "fleurs" else "flowers"))
}
shinyApp(ui, server)
