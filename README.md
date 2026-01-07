# Application de recherche de station essence : Optimisation du plein de carburant

## Problématique
Nous nous sommes posé une question : **est-ce possible de trouver la station essence idéale?**, celle qui serait la plus intéressante en termes de distance et de prix. 

Nous avons donc décidé de créer une application Shiny où il suffit d'entrer une adresse donnée pour trouver la station essence qui est un compromis entre la moins loin et la moins chère. On s'est basé sur le prix du carburant, la distance réelle, la consommation du véhicule et l'ancienneté du prix (la dernière mise à jour du prix). 

## Principales fonctionnalités du code 
- Conversion d'une adresse texte en coordonnées GPS
- Récupération des stations services dans un rayon donné autour d'un point GPS
- Calcul d'une distance routière réelle entre une position et une station
- Calcul du coût total et d'un score distance-prix
- Affichage sur une carte de manière interactive grâce à Leaflet
- Création d'un tableau comparatif des meilleures stations 
- Ouverture de Google Maps avec l'itinéraire pour aller à la station
  
## Traitement des données
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

### Étapes de traitement :
**1. Parsing des fichiers JSON :** 

Notre application va récupérer les données brutes en JSON via une API (gouvernementale), puis fait un parsing (analyse et conversion du texte) pour les transformer en DataFrame pour pouvoir calculer le coût total d'un plein. Pour le faire, nous utilisons la fonction ```fromJSON()```, du package ```jsonlite```.

**2. Nettoyage des données (filtrage des prix nuls ou aberrants) :** 

La première étape est de convertir les données pour obtenir un format standard ```WGS84``` pour que la carte ```Leaflet``` les comprennent. Puis il faut filtrer les valeurs manquantes, donc trouver les stations n'ayant pas renseignées leur prix / adresse. Et enfin, il faut sélectionner les données utiles, autrement dit si l'utilisateur cherche un certains type de carburant, le code nettoie la base de données pour ne donner que des informations qui intéresse l'utilisateur.

**3. Enrichissement des données :** 

Ici, nous enrichissons les données par le calcul du coût total, que nous réalisons avec trois indicateurs, le prix du carburant, la distance aller-retour et la consommation du véhicule. Donc au lieu d'afficher simplement le coût du carburant, l'utilisateur connaitra le ```cout_total```.

```markdown
```r
calculer_cout <- function(prix_L, dist_km, conso_100) {
  trajet_AR_km <- dist_km * 2
  litres_conso <- (trajet_AR_km * conso_100) / 100
  cout_plein <- 50 * prix_L 
  return(cout_plein + (litres_conso * prix_L))
}
```
On crée par la suite un score distance-prix permettant de trouver la meilleure station en faisant un compromis entre la distance et le prix. On pondère la distance à k=0.5. C'est à dire qu'on favorise le prix à la distance ( si k=1 on aurait été indifférent entre le prix et la distance)

```markdown
```r
top15<- top15 %>%
        mutate(cout = calculer_cout(prix, dist, input$conso))

      k<- 0.5 
      top15 <- top15 %>% mutate(score = cout + k * dist)      
      #on tri par score et on prend des 10 meilleures stations 
      final <- top15 %>% arrange(score) %>% head(10)
```
### Hypothèse de modélisation 
Nous faisons les hypothèses suivantes: 
- Le plein d'une voiture est fixée à **50L**
- Nous prenons les distances **aller-retour** entre l'adresse de départ et la station
- On suppose que la consommation du vehicule est **constante** tout au long du trajet
- Seuil de fraîcheur des prix est fixé à **7 jours**, c'est à dire que nous ne prenons pas de prix qui ont été mis à jour il y a plus d'une semaine
- Pondération de **k=0.5**
- Le choix de la station repose sur le **score distance-prix**

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

## Conclusion :
Notre application permet bien de trouver quelle est la station à choisir pour optimiser son plein d'essence (surtout son prix), tout en renseignant le moins d'informations possible. Ce que nous trouvons intéressant est d'ajouter cette carte, permettant aux utilisateurs de mieux se situer dans l'espace ainsi que de pouvoir visualiser le trajet dans google maps, pour les mener directement à cette station sans perdre de temps.
