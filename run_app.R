#!/usr/bin/env Rscript
port <- as.integer(Sys.getenv("PORT", "4242"))
app_dir <- file.path(getwd(), "shiny-app")

if (!requireNamespace("shiny", quietly = TRUE)) {
  install.packages("shiny", repos = "https://cloud.r-project.org")
}

# Prevent auto-opening a browser; bind only to localhost
shiny::runApp(appDir = app_dir, host = "127.0.0.1", port = port, launch.browser = FALSE)
