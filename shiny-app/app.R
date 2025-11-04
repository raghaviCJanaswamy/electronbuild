library(shiny)

ui <- fluidPage(
  titlePanel("Hello from Shiny + Electron"),
  sidebarLayout(
    sidebarPanel(
      sliderInput("obs", "Number of observations:", min = 1, max = 1000, value = 500)
    ),
    mainPanel(
      plotOutput("distPlot"),
      tags$p("This is a placeholder Shiny app. Replace shiny-app/app.R with your own!")
    )
  )
)

server <- function(input, output, session) {
  output$distPlot <- renderPlot({
    hist(rnorm(input$obs))
  })
}

shinyApp(ui, server)
