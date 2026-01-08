
# Application station essence 


library(shiny)# pour créer l'application
library(shinyjs) # ajout des comportements JavaScript, est un complément à shiny permet des fonctionnalités différentes comme l'ouverture de l'onglet GoogleMaps
library(httr) # permet de communiquer avec les APIs (Nominatim, OSRM)
library(jsonlite) # traduit le format texte JSON en objet R pour qu'il devienne exploitable
library(dplyr) # facilité compréhension et nettoyage des données
library(leaflet) # pour l'affichage de la carte intéractive
library(geosphere)# pour calculer les distances entre deux points GPS (Haversine)


#Interface Utilisatuer ui

ui <- fluidPage(
  useShinyjs(),
  
  tags$head(
    tags$style(HTML("
      .well { background-color: #f5f5f5; }
      #station_info { font-weight: bold; }
    "))
  ),
  
  titlePanel("🚗 Trouver la meilleure station essence"),
  
  sidebarLayout(
    sidebarPanel(
      width = 3,
      textInput("adresse", "Adresse de départ", 
                placeholder = "Ex: 1 Rue de Rivoli, Paris"),
      
      selectInput("carburant", "Type de carburant",
                  choices = c("Gazole", "SP95", "SP98", "E10", "E85", "GPLc")),
      
      sliderInput("rayon", "Rayon de recherche (km)",
                  min = 2, max = 50, value = 15),#la valeur par défaut affichée dans l'application est 15
      
      numericInput("conso", "Consommation (L/100km)",
                   value = 7, min = 1, max = 25, step = 0.5),
      
      actionButton("chercher", "Rechercher", class = "btn-primary"),
      
      hr(),
      
      h4("Station sélectionnée"),
      verbatimTextOutput("station_info"),#On affiche les informations principales de la station choisie
      
      actionButton("gmaps", "Ouvrir dans Google Maps", class = "btn-success")
    ),
    
    mainPanel(
      width = 9,
      tabsetPanel(
        tabPanel("Carte", leafletOutput("carte", height = "700px")),
        tabPanel("Résultats", #On a donc un tableau clair disponible avec les 10 meilleures stations selon le score distance-prix(développé plus tard)
                 tableOutput("resultats"),
                 p("*Coût total = plein 50L + carburant A/R", style="color:gray;"))
      )
    )
  )
)

#Serveur 

server <- function(input, output, session) {
  
  # Variables reactives = ces variables sont indispensables pour la mise à jour de la carte, du tableau et des informations générales
  ma_position <- reactiveVal(NULL) #Position GPS de l'utilisateur
  mes_stations <- reactiveVal(NULL) # Liste des stations trouvées proches de moi
  station_choisie <- reactiveVal(NULL) # Station sélectionnée pour moi
  trajet <- reactiveVal(NULL) # Calcul de mon trajet entre ma position et la station
  
  # Trouver coordonnées depuis adresse = cela permet de transformer l'adresse écrite dans l'app en coordonnées GPS grâce à l'API Nominatim (OpenStreetMap)
  trouver_coords <- function(adresse) {
    url <- "https://nominatim.openstreetmap.org/search"
    reponse <- GET(url, 
                   query = list
                   (q = adresse,
                    format = "json",
                    limit = 1),
                   user_agent("StationApp"))
   
    
      data <- fromJSON(content(reponse, "text"))
      if (length(data) > 0) { # si on trouve une adresse
        return(list(
          lat = as.numeric(data$lat[1]),#la latitude pour l'adresse cherchée
          lon = as.numeric(data$lon[1])
          ))
      }
    
    return(NULL) #si on ne trouve pas d'adresse
  }
  
  # Récupérer stations = Cela permet de recuperer les stations dans un rayon donné autour d'un point GPS
  chercher_stations <- function(lat, lon, rayon) {
    url <- "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records"
    
    filtre <- sprintf(
      "within_distance(geom, GEOM'POINT(%f %f)', %dkm)", #fonction de géo-filtrage proposée par l'API, cela revient TRUE si la station est dans le rayon donné
      lon, lat, rayon
      )
    
    reponse <- GET(
      url, 
      query = list(
        where = filtre, 
        limit = 100 # limite le nombre de resultat à 100 
        )
      )
    
    if (status_code(reponse) == 200) {# juste une verification que ça a marché
      data <- fromJSON(content(reponse, "text"))
      return(data$results)
    }
    return(NULL) #si échec
  }
  
  # Extraire lat/lon (les coordonnées GPS) d'une station
  # On a plusieurs formats de coordonnées données par les APIs: "Lat/lon", "latitude/longitude", "geom"
  # Les 3 methodes permettent de s'assurer que peu importe comme l'API renvoie les coordonnées, on aura les coordonnées à la fin
  get_coords_station <- function(station) {
    lat <- NA 
    lon <- NA
    #Quand on a "lat" et "lon"
    if (all(c("lat","lon") %in% names(station))){
      lat <- as.numeric(station$lat)
      lon <- as.numeric(station$lon)
    }
    
    #Quand on a "latitude" et "longitude"
    if (is.na(lat) && is.na(lon) && all(c("latitude","longitude") %in% names(station))) {
      lat_val <- as.numeric(station$latitude)
      lon_val <- as.numeric(station$longitude)
      lat <- ifelse(lat_val > 1000, lat_val/100000, lat_val) #on divise par 100 000 pour les coordonnées soient compatibles pour la carte et les calculs de distance
      lon <- ifelse(abs(lon_val) > 1000, lon_val/100000, lon_val)
    }
    
    #quand on a geom (data frame avec lat/lon)
    if ((is.na(lat) || is.na(lon)) && "geom" %in% names(station)) {
      geom <- station$geom
      if (is.data.frame(geom)) {
        if ("lat" %in% names(geom)) 
          lat <- as.numeric(geom$lat[1])
        if ("lon" %in% names(geom)) 
          lon <- as.numeric(geom$lon[1])
      }
    }
    
    return(list(lat = lat, lon = lon))
  }
  
  # Extraire prix d'un carburant pour une station donnée
  #on crée le nom de la colonne qui correspond au carburant dans le dataframe
  get_prix <- function(station, carburant) {
    col <- paste0(tolower(carburant), "_prix")#si on a du Gazole, on aura "gazole_prix"
    if (col %in% names(station)){
      return(as.numeric(station[[col]]))#si le prix est disponible 
    }else{
    return(NA) #si prix indisponible
    }
  }  
  
#On calcule l'ancienneté du prix du carburant pour une station = nous permettra de garder les stations avec des prix misent à jour récemment 
#on aura un colonne correspondant à la date de mise à jour du carburant
get_heures_maj <- function(st, carburant) {
  col <- paste0(tolower(carburant), "_maj")# ici pour le gazole, on aura "gazole_maj"
  
  #on verifie que la colonne existe
  if (!col %in% names(st)) return(NA)
  val <- st[[col]]
  if (is.null(val) || is.na(val) || val == "") return(NA)
  
  #on nettoie la chaine de date et on convertit en date/heure (fait de manière plus complexe pour éviter que l'app plante)
  val <- gsub("Z$", "",val)
  val <- gsub("\\+.*$", "", val)
  
  #Utilisation de POSIXct pour avoir date et heure exploitable en R
  date_maj <- as.POSIXct(val, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  if (is.na(date_maj)) return(NA)
  #On retourne le nombre d'heures écoulées depuis la dernière mise à jour
  as.numeric(Sys.time() - date_maj, units = "hours")
}

  
  
  #Une distance à vol d'oiseau pour filtrer initialement les stations  
  calculer_distance_vo <- function(lon1, lat1, lon2, lat2) {
    geosphere::distHaversine(
      cbind(lon1, lat1),
      cbind(lon2, lat2)
    ) / 1000  # km
  }
  
  # Calculer distance routière pour être précis, la fonction sera utilisée uniquement pour les stations pertinentes (Top 15) car requête OSMR est lourde
  #lon1, lat 1 le point départ 
  #lon2, lat2  le point d'arrivée
  #avec_trajet = FALSE: distance seule; = TRUE: distance en km et coordonnées GPS du trajet
  calculer_distance <- function(lon1, lat1, lon2, lat2, avec_trajet = FALSE) {
    url <- sprintf("http://router.project-osrm.org/route/v1/driving/%f,%f;%f,%f?overview=full&geometries=geojson",
                   lon1, lat1, lon2, lat2)
    
    reponse <- GET(url, timeout(5))
    data <- fromJSON(content(reponse, "text"), simplifyVector = FALSE) #lire la réponse
      
    # s'il n'existe pas de route disponible
    if (is.null(data$routes) || length(data$routes) == 0) {
      if (avec_trajet) return(list(distance = NA, route = NULL))
      return(NA)
    }
    # s'il existe une route disponible 
    dist <- data$routes[[1]]$distance / 1000 #la division par 1000 permet de convertir en km
        
        if (avec_trajet) {
          coords <- data$routes[[1]]$geometry$coordinates
          return(list(distance = dist, route = coords))
        }
        return(dist)
    }
  
  # Calculer coût total (déplacement pour aller à la station + faire plein)
  # conso en litres pour 100km 
  # on considère qu'un plein = 50 L (approximation pour comparer les stations)
  calculer_cout <- function(prix, distance, conso) {
    aller_retour <- distance * 2 
    litres <- (aller_retour * conso) / 100 # consommation réelle de carburant en L pour le trajet
    plein <- 50 * prix #ce que coûte un plein de 50L
    cout <- plein + litres * prix # coût du plein + carburant nécessaire pour faire l'aller-retour
    return(cout)
  }
  
  # Recherche principale grace à l'app Shiny = cette partie du code représente tout ce qu'il se passe quand l'utilisateur appuie sur le bouton Rechercher dans l'app
  #Ceci gère la conversion de l'adresse, la récupération des stations, le filtrage, le calcul des distances et du coût total et enfin la mise à jour des variables réactives
  observeEvent(input$chercher, { #input$chercher représente la bouton
    req(input$adresse) #permet d'éviter les bugs, le code s'arrête si l'adresse est vide
    
    withProgress(message = 'Recherche...', value=0, {  #affiche une fenêtre pour montrer que le code "travaille" et que l'app n'est pas bloquée
      incProgress(0.3, detail = "Adresse en coordonnées")
      
      # Trouver position = le but ici transformer l'adresse tapée en coordonnées GPS
      coords <- trouver_coords(input$adresse) # trouver_coords est une fonction cf ligne 76 
      incProgress(0.6, detail = "Analyse des stations")
      #Si l'adresse n'existe pas = message d'erreur 
      if (is.null(coords)) {
        showNotification("Adresse pas trouvée", type = "error")
        return()
      }
      #si l'adresse existe = variable réactive qui stocke les coordonnées 
      ma_position(coords)
      
      
      # Chercher stations autour de moi = grâce à mes coordonnées de départ (adresse) et d'un rayon de recherche donné l'app va chercher des stations
      #coords$lat et coords$lon viennent de la fonction trouver_coords
      #input$rayon vient du sliderInput au début de code
      stations <- chercher_stations(coords$lat, coords$lon, input$rayon) #fct cf ligne 96
      if (is.null(stations)) { #si aucune station n'est trouvé
        return()
      }
      stations <- as.data.frame(stations, stringsAsFactors = FALSE)
     
      # Nettoyer données et prendre les stations valides
      liste <- lapply(1:nrow(stations), function(i){ #on utilise lapply au lieu d'une boucle for
        st <- stations[i,]
        coords_st <- get_coords_station(st) #vérification coordonnées de la station
        prix_st <- get_prix(st, input$carburant) #verification prix pour carburant 
        heures_maj <- get_heures_maj(st, input$carburant)
        
        
        #Pour éviter les bugs on verifie qu'il existe des colonnes adresse et ville grace à %in%
        id_val      <- if("id" %in% names(st) && !is.null(st$id)) as.character(st$id) else paste0("st", i)
        adresse_val <- if("adresse" %in% names(st) && !is.null(st$adresse)) st$adresse else "Adresse non renseignée"
        ville_val   <- if("ville" %in% names(st) && !is.null(st$ville)) st$ville else "Ville inconnue"
        
        
        #On garde uniquement les données complètes, valides (prix>0) et de moins de 7 jours
        cond_coords <- !is.na(coords_st$lat) && !is.na(coords_st$lon)
        cond_prix<- !is.na(prix_st)&& prix_st>0
        cond_fraicheur <- is.na(heures_maj) ||  heures_maj < 168 # les prix affichés datent au maximun d'il y a 1 semaine (168h)
        
        
        if (cond_coords && cond_prix && cond_fraicheur) {
      #on crée une data frame
          data.frame(
            id = id_val,
            adresse =adresse_val,
            ville = ville_val,
            lat = coords_st$lat,
            lon = coords_st$lon,
            prix = prix_st,
            maj_h=ifelse(is.na(heures_maj), NA, round(heures_maj)),#on ajoute une colonne au dataframe
            stringsAsFactors=FALSE # pour éviter que R transforme les adresses et les villes en facteurs, on lui dit de ne pas chercher à analyser les caractères en catégorie statistique
          )
        } else {
          NULL
        }
    }) #fin du lapply
      
 
      
      #On filtre les élements vides
      liste <- Filter(Negate(is.null), liste) 
      if (length(liste) == 0) {
        showNotification("Aucune station avec ce carburant", type = "warning")
        return()
      }
      
      #on combine dans un seul data frame. On a pour chaque station, un ligne avec toutes les informations la concernant
      df <- bind_rows(liste)
      
      
      
      # Calculer distances
      #On calcule les distances à vol d'oiseau c'est à dire la distance entre ma position et toutes les stations
      #On fait un premier filtre des 15 stations les plus proches
      df$distance_vo <- calculer_distance_vo(
        df$lon, df$lat,
        coords$lon, coords$lat
      )
      
      # On garde les 15 stations les plus proches
      top15 <- df %>%
        arrange(distance_vo) %>%
        head(15)
      
     #Calcul de la distance routière
      # Enfin on calcule la distance routière réelle entre ma position et chaque station parmi les 15 plus proches à vol d'oiseau qu'on nomme d
    top15$dist  <- sapply(1:nrow(top15), function(i) {
        d <- calculer_distance(coords$lon, coords$lat, top15$lon[i], top15$lat[i])
        if (is.na(d))10 else d #On remplace ici NA par 10km pour éviter que les stations sans route disponible soient exclues
      })
      
      # Calculer coût total
      top15<- top15 %>%
        mutate(cout = calculer_cout(prix, dist, input$conso)) 
      
      #On va créer un "score" qui va faire un compromis entre distance et prix 
      k<- 0.5 #on fait le choix de favoriser le prix à la distance en pondérant la distance à 0,5 ; si on avait été indifférent k=1
      top15 <- top15 %>% mutate(score = cout + k * dist)
    
      
      #on tri par score et on prend des 10 meilleures stations 
      final <- top15 %>% arrange(score) %>% head(10)
      
      mes_stations(final)
      station_choisie(final[1,]) #variable réactive
      
      # Tracer itinéraire
      meilleure_station<- final[1,] 
      
      #On calcule maintenant la distance entre la station trouvée et on prend les coordonnées GPS
      trajet_meilleure <- calculer_distance(coords$lon, coords$lat, meilleure_station$lon, meilleure_station$lat, avec_trajet = TRUE)
      
      #On stocke le trajet
      trajet(trajet_meilleure$route)
      
      
      incProgress(0.9, detail = "Finalisation")
      showNotification(paste(nrow(final), "stations trouvées"), type = "message")
    })
  })
   
  
  # Carte
  output$carte <- renderLeaflet({
    req(ma_position(), mes_stations())
    
    pos <- ma_position() #coordonnées GPS de l'utilisateur 
    stations <- mes_stations() #dataframe des stations filtrées et triées
    
    # si pas de station on affiche juste la carte centrée sur le position de l'utilisateur
    if (is.null(stations) || nrow(stations) == 0) {
      return(leaflet() %>% addTiles() %>% setView(pos$lon, pos$lat, 12))
    }
    
    # si on a des stations disponibles, on affiche la carte avec position de départ et la station
    carte <- leaflet() %>%
      addTiles() %>%
      addMarkers(pos$lon, pos$lat, popup = "Départ") %>%
      addMarkers(data = stations, ~lon, ~lat, layerId = ~id,
                 popup = ~paste0(ville, "<br>", adresse, "<br>", prix, "€/L<br>Total: ", round(cout, 2), "€")) #br = break line c'est un saut de ligne
    
    # Tracer route pour la station sélectionnée
    route <- trajet() # on récupère les données GPS du trajet grâce à la variable réactive
    if (!is.null(route) && length(route) > 0) { #on vérifie que la route existe
      coords_route <- do.call(rbind, lapply(route, function(c) { #la route est une liste de coordonnées qu'on transforme en data frame
        data.frame(lon = c[[1]], lat = c[[2]])
      }))
      
      #addPolylines= permet d'ajouter le trajet sur la carte
      carte <- carte %>%
        addPolylines(~lon, ~lat, data = coords_route, 
                     color = "blue", weight = 3, opacity = 0.7)
    }
    
    carte
  })
  
  # Clic sur station : on sélectionne un station et on trace le trajet sur la carte
  # On a déjà une station idéale mais si l'utilisateur veut changer il a juste à cliquer sur une autre icone sur la carte
  observeEvent(input$carte_marker_click, {
    click <- input$carte_marker_click # on récupère les informations du clic sur la carte
    stations <- mes_stations() #stations disponibles
    pos <- ma_position() 
    
    if (!is.null(stations) && !is.null(pos)) {
      s <- stations %>% filter(id == click$id)
      if (nrow(s) > 0) {
        station_choisie(s[1,]) #filtre la station par rapport au click
        
        #Calcul le trajet vers la station
        resultat <- calculer_distance(pos$lon, pos$lat, s$lon[1], s$lat[1], avec_trajet = TRUE)
        trajet(resultat$route)
      }
    }
  })
  
  # Tableau
  #renderTable met à jour automatiquement les résultats dès que "mes_stations" change
  #on selectionne aussi ici les colonnes à afficher
  output$resultats <- renderTable({
    req(mes_stations())
    mes_stations() %>%
      select(Ville = ville, Adresse = adresse, "Prix €/L" = prix, 
             "Ancienneté (h)"= maj_h, "Distance (km)" = dist, "Coût total €" = cout, Score = score)
  }, digits = 2)
  
  # Info station : donne les informations détaillées sur la station sélectionnée
  output$station_info <- renderText({
    req(station_choisie())
    s <- station_choisie()
    paste0(s$ville, "\n",
           s$adresse, "\n",
           s$prix, " €/L\n",
           round(s$dist, 1), " km\n",
           round(s$cout, 2), " € total")
  })
  
  # Ouvrir Google Maps
  observeEvent(input$gmaps, {
    req(ma_position(), station_choisie()) #on s'assure que la position de l'utilisateur et la station choisie sont disponibles
    pos <- ma_position()#origine
    dest <- station_choisie()#destination
    
    url <- sprintf("https://www.google.com/maps/dir/?api=1&origin=%f,%f&destination=%f,%f&travelmode=driving",
                   pos$lat, pos$lon, dest$lat, dest$lon) 
    
    runjs(paste0("window.open('", url, "', '_blank');")) #on ouvre l'url dans un nouvel onglet 
  })
}

shinyApp(ui, server)
