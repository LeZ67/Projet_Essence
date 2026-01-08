# Application de recherche de station essence : Optimisation du plein de carburant

## Problématique
Nous nous sommes posé une question : **est-ce possible de trouver la station essence idéale?**, celle qui serait la plus intéressante en termes de distance et de prix. 

Nous avons donc décidé de créer une application Shiny où il suffit d'entrer une adresse donnée pour trouver la station essence qui est un compromis entre la moins loin et la moins chère. On s'est basé sur le prix du carburant, la distance réelle, la consommation du véhicule et l'ancienneté du prix (la dernière mise à jour du prix). 
Cette application s'adresse à toute personne souhaitant trouver la station idéale en termes de distance et de prix. 

## Principales fonctionnalités du code 
- Conversion d'une adresse texte en coordonnées GPS
- Récupération des stations services dans un rayon donné autour d'un point GPS
- Calcul d'une distance routière réelle entre une position et une station
- Calcul du coût total et d'un score distance-prix
- Affichage sur une carte de manière interactive grâce à Leaflet
- Création d'un tableau comparatif des meilleures stations 
- Ouverture de Google Maps avec l'itinéraire pour aller à la station

## Données  et packages utilisés
Ce projet utilise trois sources de données :
- **Nominatim (OpenStreetMap)** permet le **Géocodage**, c'est à dire transformer une adresse textuelle en coordonnées GPS pour que notre application sache où nous sommes positionnés.
- **API Prix des carburants – data.economie.gouv.fr** permet de récuperer en temps réel des données gouvernementales (open data) concernant le prix des différents carburants 
- **OSRM (Open Source Routing Machine)** permet le **Calcul d'itinéraire** et des **distances routières réelles**

Liste des packages utilisés : 
- ```shiny```: pour créer l'application
- ```shinyjs```: ajout des comportements JavaScript, est un complément à shiny permet des fonctionnalités différentes comme l'ouverture de l'onglet GoogleMaps
- ```httr```: permet de communiquer avec les APIs
- ```jsonlite```: traduit le format texte JSON en objet R pour qu'il devienne exploitable
- ```dplyr```: facilite compréhension et nettoyage des données
- ```leaflet```: pour l'affichage de la carte intéractive
- ```geosphere```: pour calculer les distances entre deux points GPS
- 
## Lancement de l'outil
Avant de lancer l'application, il est nécessaire d'effectuer cette manipulation dans votre console R :

```markdown
```r
install.packages(c("shiny", "shinyjs", "httr", "jsonlite", "dplyr", "leaflet"))
1. Assurez-vous d'avoir installé les bibliothèques : `shiny`, `leaflet`, `httr`, `jsonlite`, `dplyr`.
2. Lancez l'application dans R :
   ```R
   shiny::runApp()
```
## Comment utiliser notre application 
1. Indiquer votre adresse de départ
2. Indiquer le type de carburant souhaité
3. Indiquer le rayon de recherche d'une station en km
4. Indiquer la consommation de votre véhicule au L/100km
5. Appuyer sur "Rechercher"
6. Vous pouvez Appuyer sur "Carte" ou "Résultats" pour avoir le détail des stations sélectionnées
7. Appuyer sur "Ouvrir Google Maps" pour avoir l'itinéraire vers la meilleure station
  
## A savoir pour mieux comprendre le code 
### Définitions des fonctions créées
- ```trouver_coords``` = convertir mon adresse en coordonnées GPS
- ```chercher_station``` = récupérer les stations dans un rayon autour d'un point GPS
- ```get_coords_station``` = extraire les données GPS d'une station
- ```get_prix``` = extraire le prix du carburant sélectionné pour une station donnée
- ```get_heures_maj``` = calculer de l'ancienneté (h) de la dernière mise à jour du prix du carburant
- ```calculer_distance_vo``` = calculer la distance à vol d'oiseau entre 2 points GPS (ma position et les stations) pour un filtrage rapide
- ```calculer_distance``` = calculer la distance routière réelle sur les stations pertinente
- ```calculer_cout``` = calculer coût total (déplacement A/R et plein)
### Hypothèses de modélisation
Nous faisons les hypothèses suivantes: 
- Le plein d'une voiture est fixée à **50L**
- Nous prenons les distances **aller-retour** entre l'adresse de départ et la station
- On suppose que la consommation du vehicule est **constante** tout au long du trajet
- Seuil de fraîcheur des prix est fixé à **7 jours**, c'est à dire que nous ne prenons pas de prix qui ont été mis à jour il y a plus d'une semaine
- Pondération de **k=0.5**
- Le choix de la station repose sur le **score distance-prix**
```markdown
```r
top15<- top15 %>%
        mutate(cout = calculer_cout(prix, dist, input$conso))
      k<- 0.5 
      top15 <- top15 %>% mutate(score = cout + k * dist)      
      #on tri par score et on prend des 10 meilleures stations 
      final <- top15 %>% arrange(score) %>% head(10)
```

## Conclusion :
Notre application permet bien de trouver quelle est la station à choisir pour optimiser son plein d'essence (son prix et sa distance parcourue), tout en renseignant le moins d'informations possible. Ce que nous trouvons intéressant est d'ajouter une carte, permettant aux utilisateurs de mieux se situer dans l'espace ainsi que de pouvoir visualiser le trajet dans google maps, pour les mener directement à cette station.
