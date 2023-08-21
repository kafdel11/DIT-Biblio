# Installation des packages requis 
if (!require(shiny)) {
  install.packages("shiny")
}

if (!require(RSQLite)) {
  install.packages("RSQLite")
}

if (!require(plotly)) {
  install.packages("plotly")
}

if (!require(shinydashboard)) {
  install.packages("shinydashboard")
}

# Chargement des bibliothèques
library(shiny)
library(RSQLite)
library(plotly)
library(shinydashboard)
library(reticulate)


# Fonction pour vérifier si une table existe dans la base de données
table_exists <- function(con, table_name) {
  table_info <- dbListTables(con)
  table_name %in% table_info
}

# Vérification et connexion à la base de données SQLite
if (file.exists("library.db")) {
  con <- dbConnect(RSQLite::SQLite(), "library.db")
  
  # Vérification si la table "Livre" existe dans la base de données
  if (!table_exists(con, "Livre")) {
    stop("La table 'Livre' n'existe pas dans la base de données.")
  }
  
  # Vérification si la table "emprunt" existe dans la base de données
  if (!table_exists(con, "emprunt")) {
    stop("La table 'emprunt' n'existe pas dans la base de données.")
  }
  
  # Vérification si la table "users" existe dans la base de données
  if (!table_exists(con, "users")) {
    stop("La table 'users' n'existe pas dans la base de données.")
  }
} else {
  stop("Le fichier de la base de données 'library.db' n'a pas été trouvé.")
}

# Définition du style CSS pour le tableau des résumés
tableCSS <- "
  th, td {
    padding: 12px; /* Increase padding for cells */
    font-size: 16px; /* Increase font size */
    text-align: left;
    border-bottom: 1px solid #ddd;
  }
  th {
    background-color: #f2f2f2;
  }
  tr:hover {
    background-color: #f5f5f5;
  }
"

# UI
ui <- dashboardPage(
  dashboardHeader(title = "Analyse de la bibliothèque"),
  dashboardSidebar(
    # Filtre pour les tables
    selectInput("tableType", "Table",
                choices = c("General", "Livre", "emprunt"),
                selected = "General"),
    
    # Filtre pour emprunts par jour, par mois, par semaine ou par utilisateur
    conditionalPanel(
      condition = "input.tableType == 'emprunt'",
      selectInput("borrowType", "Emprunts par",
                  choices = c("Jour", "Mois", "Semaine", "Utilisateur"),
                  selected = "Jour")
    )
  ),
  dashboardBody(
    tabsetPanel(
      # Onglet pour les résumés
      tabPanel("Résumés",
               tags$style(tableCSS),
               conditionalPanel(
                 condition = "input.tableType == 'General'",
                 tableOutput("summaryTable")
               ),
               conditionalPanel(
                 condition = "input.tableType == 'Livre'",
                 tableOutput("summaryLivre")
               ),
               conditionalPanel(
                 condition = "input.tableType == 'emprunt'",
                 tableOutput("summaryEmprunt")
               )
  
      ),
      
      # Onglet pour les graphiques
      tabPanel("Graphiques",
               conditionalPanel(
                 condition = "input.tableType == 'General'",
                 plotlyOutput("generalBorrowEvolutionLine")  # Correction ici
               ),
               conditionalPanel(
                 condition = "input.tableType == 'emprunt' && input.borrowType == 'Jour'",
                 plotOutput("borrowsByDayPie"),
                 plotOutput("borrowsByDayBar"),
                 plotlyOutput("borrowEvolutionLine")  # Ajout ici
               ),
               conditionalPanel(
                 condition = "input.tableType == 'emprunt' && input.borrowType == 'Mois'",
                 plotOutput("borrowsByMonthPie"),
                 plotOutput("borrowsByMonthBar")
               ),
               conditionalPanel(
                 condition = "input.tableType == 'emprunt' && input.borrowType == 'Semaine'",
                 plotOutput("borrowsByWeekPie"),
                 plotOutput("borrowsByWeekBar")
               ),
               conditionalPanel(
                 condition = "input.tableType == 'emprunt' && input.borrowType == 'Utilisateur'",
                 plotOutput("borrowPerUserPie"),
                 plotOutput("borrowPerUserBar")
               )
      )
    )
  )
)

# Server
server <- function(input, output) {
  # Résumés
  output$summaryTable <- renderTable({
    total_books <- dbGetQuery(con, "SELECT COUNT(*) FROM Livre")$`COUNT(*)`
    total_borrows <- dbGetQuery(con, "SELECT COUNT(*) FROM emprunt")$`COUNT(*)`
    total_users <- dbGetQuery(con, "SELECT COUNT(*) FROM users")$`COUNT(*)`
    available_books <- dbGetQuery(con, "SELECT COUNT(*) FROM Livre WHERE Disponibilité = 'Disponible'")$`COUNT(*)`
    unavailable_books <- dbGetQuery(con, "SELECT COUNT(*) FROM Livre WHERE Disponibilité = 'Indisponible'")$`COUNT(*)`
    
    data.frame(
      "Statistiques" = c("Total de livres dans la bibliothèque",
                         "Total d'emprunts dans la bibliothèque",
                         "Total d'utilisateurs dans la bibliothèque",
                         "Livres disponibles",
                         "Livres indisponibles"),
      "Valeur" = c(total_books, total_borrows, total_users, available_books, unavailable_books)
    )
  }, row.names = FALSE)
  
  output$summaryLivre <- renderTable({
    # Récupérer les données de la table "Livre"
    dbGetQuery(con, "SELECT * FROM Livre")
  })
  
  output$summaryEmprunt <- renderTable({
    # Récupérer les données de la table "emprunt"
    dbGetQuery(con, "SELECT * FROM emprunt")
  })
  
  output$summaryUsers <- renderTable({
    # Récupérer les données de la table "users"
    dbGetQuery(con, "SELECT * FROM users")
  })
  
  # Graphiques
  #output$booksByAvailability <- renderPlot({
   # books_by_availability <- dbGetQuery(con, "SELECT Disponibilité, COUNT(*) as Count FROM Livre GROUP BY Disponibilité")
    #pie(books_by_availability$Count, 
     #   labels = books_by_availability$Disponibilité,
      #  main = "Répartition des livres par disponibilité",col = c("#1f77b4", "#ff7f0e"))})
  
  output$borrowPerUserPie <- renderPlot({
    borrow_by_user <- dbGetQuery(con, "SELECT u.user_name, COUNT(e.id_borrow) as Count 
                                     FROM users u
                                     LEFT JOIN emprunt e ON u.id_user = e.Id_user
                                     GROUP BY u.user_name")
    pie(borrow_by_user$Count, labels = borrow_by_user$user_name,
        main = "Répartition des emprunts par utilisateur",
        col = rainbow(length(borrow_by_user$user_name)))
  })
  
  output$borrowPerUserBar <- renderPlot({
    borrow_by_user <- dbGetQuery(con, "SELECT u.user_name, COUNT(e.id_borrow) as Count 
                                     FROM users u
                                     LEFT JOIN emprunt e ON u.id_user = e.Id_user
                                     GROUP BY u.user_name")
    barplot(borrow_by_user$Count, names.arg = borrow_by_user$user_name,
            xlab = "Utilisateurs", ylab = "Nombre d'emprunts",
            main = "Nombre d'emprunts par utilisateur",
            col = rainbow(length(borrow_by_user$user_name)))
  })
  
  output$borrowsByDayPie <- renderPlot({
    borrow_by_day <- dbGetQuery(con, "SELECT strftime('%Y-%m-%d', borrow_date) as Date, COUNT(*) as Count FROM emprunt GROUP BY Date")
    pie(borrow_by_day$Count, labels = borrow_by_day$Date,
        main = "Répartition des emprunts par jour",
        col = rainbow(length(borrow_by_day$Date)))
  })
  
  output$borrowsByDayBar <- renderPlot({
    borrow_by_day <- dbGetQuery(con, "SELECT strftime('%Y-%m-%d', borrow_date) as Date, COUNT(*) as Count FROM emprunt GROUP BY Date")
    barplot(borrow_by_day$Count, names.arg = borrow_by_day$Date,
            xlab = "Jour", ylab = "Nombre d'emprunts",
            main = "Nombre d'emprunts par jour",
            col = rainbow(length(borrow_by_day$Date)))
  })
  
  output$borrowsByMonthPie <- renderPlot({
    borrow_by_month <- dbGetQuery(con, "SELECT strftime('%Y-%m', borrow_date) as Date, COUNT(*) as Count FROM emprunt GROUP BY Date")
    pie(borrow_by_month$Count, labels = borrow_by_month$Date,
        main = "Répartition des emprunts par mois",
        col = rainbow(length(borrow_by_month$Date)))
  })
  
  output$borrowsByMonthBar <- renderPlot({
    borrow_by_month <- dbGetQuery(con, "SELECT strftime('%Y-%m', borrow_date) as Date, COUNT(*) as Count FROM emprunt GROUP BY Date")
    barplot(borrow_by_month$Count, names.arg = borrow_by_month$Date,
            xlab = "Mois", ylab = "Nombre d'emprunts",
            main = "Nombre d'emprunts par mois",
            col = rainbow(length(borrow_by_month$Date)))
  })
  
  output$borrowsByWeekPie <- renderPlot({
    borrow_by_week <- dbGetQuery(con, "SELECT strftime('%Y-%W', borrow_date) as Date, COUNT(*) as Count FROM emprunt GROUP BY Date")
    pie(borrow_by_week$Count, labels = borrow_by_week$Date,
        main = "Répartition des emprunts par semaine",
        col = rainbow(length(borrow_by_week$Date)))
  })
  
  output$borrowsByWeekBar <- renderPlot({
    borrow_by_week <- dbGetQuery(con, "SELECT strftime('%Y-%W', borrow_date) as Date, COUNT(*) as Count FROM emprunt GROUP BY Date")
    barplot(borrow_by_week$Count, names.arg = borrow_by_week$Date,
            xlab = "Semaine", ylab = "Nombre d'emprunts",
            main = "Nombre d'emprunts par semaine",
            col = rainbow(length(borrow_by_week$Date)))
  })
  
  output$borrowEvolutionLine <- renderPlotly({
    if (input$tableType == "emprunt" && input$borrowType == "Jour") {  # Correction ici
      borrow_by_day <- dbGetQuery(con, "SELECT strftime('%Y-%m-%d', borrow_date) as Date, COUNT(*) as Count FROM emprunt GROUP BY Date")
      
      # Convertir la colonne Date en format de date R
      borrow_by_day$Date <- as.Date(borrow_by_day$Date)
      
      # Créer le graphique de type courbe évolutives (line plot) avec plotly
      plot_ly(data = borrow_by_day, x = ~Date, y = ~Count, type = "scatter", mode = "lines+markers",
              marker = list(color = "blue"), line = list(color = "blue")) %>%
        layout(title = "Évolution des emprunts par jour",
               xaxis = list(title = "Date"),
               yaxis = list(title = "Nombre d'emprunts"))
    } else {
      # Retourne un plotly vierge si les conditions ne sont pas remplies
      plot_ly() %>%
        layout(title = "Évolution des emprunts par jour",
               xaxis = list(title = "Date"),
               yaxis = list(title = "Nombre d'emprunts"))
    }
  })
  
  # Code pour ajouter la courbe évolutives des emprunts par jour à la table générale
  output$generalBorrowEvolutionLine <- renderPlotly({
    if (input$tableType == "General") {
      borrow_by_day <- dbGetQuery(con, "SELECT strftime('%Y-%m-%d', borrow_date) as Date, COUNT(*) as Count FROM emprunt GROUP BY Date")
      
      # Convertir la colonne Date en format de date R
      borrow_by_day$Date <- as.Date(borrow_by_day$Date)
      
      # Créer le graphique de type courbe évolutives (line plot) avec plotly
      plot_ly(data = borrow_by_day, x = ~Date, y = ~Count, type = "scatter", mode = "lines+markers",
              marker = list(color = "blue"), line = list(color = "blue")) %>%
        layout(title = "Évolution des emprunts par jour",
               xaxis = list(title = "Date"),
               yaxis = list(title = "Nombre d'emprunts"))
    } else {
      # Retourne un plotly vierge si les conditions ne sont pas remplies
      plot_ly() %>%
        layout(title = "Évolution des emprunts par jour",
               xaxis = list(title = "Date"),
               yaxis = list(title = "Nombre d'emprunts"))
    }
  })
}

# Exécution de l'application Shiny
shinyApp(ui, server)
