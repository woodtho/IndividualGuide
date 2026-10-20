library(shiny)
source("helpers.R", local = TRUE)
sales_data <- read.csv("sales.csv", stringsAsFactors = FALSE)
function(input, output, session) {
  selected <- reactive(sales_data[sales_data$Sales >= input$minimum, , drop = FALSE])
  output$sales <- renderTable(selected())
  output$total <- renderText(sales_summary(selected()))
  output$download <- downloadHandler(filename = "sales.csv", content = function(file)
    write.csv(selected(), file, row.names = FALSE))
}
