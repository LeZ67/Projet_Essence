# Application de echerche de station essence : Optimisation du plein de carburant

## Problématique
Comment rentabiliser son plein d'essence selon la distance et les prix à la pompe ? 

Nous avons voulu à travers notre projet créé une application qui permet automatiquement de calculer le coût **réel** d'un plein de carburant en tenant compte de la consommation du véhicule et du trajet. Il suffit simplement de remplir quelques informations sur notre véhicule et notre position pour connaitre quelles sont les stations essences alentours et où aller pour optimiser notre plein d'essence.

## Traitement des données
Ce projet utilise et transforme trois flux de données : le **Géocodage**, le but est de transformer une adresse textuelle en coordonnées GPS pour que notre application sache où nous sommes positionnés par rapport aux stations alentours ; le **Prix des carburants**, on récupère en temps réel des données gouvernementales (open data) concernant le prix des différents carburants et le **Calcul d'itinéraire** : On récupère des distances routières réelles via le moteur OSRM.

### Étapes de traitement :
**1. Parsing des fichiers JSON :** 

Notre application va récupérer les données brutes en JSON via une API (gouvernementale), puis fait un parsing (analyse et conversion du texte) pour les transformer en DataFrame pour pouvoir calculer le coût total d'un plein. Pour le faire, nous utilisons la fonction ```fromJSON()```, du package ```jsonlite```.

**2. Nettoyage des données (filtrage des prix nuls ou aberrants) :** 

La première étape est de convertir les données pour obtenir un format standard ```WGS84``` pour que la carte ```Leaflet``` les comprennent. Puis il faut filtrer les valeurs manquantes, donc trouver les stations n'ayant pas renseignées leur prix / adresse. Et enfin, il faut séléctionner les données utiles, autrement dit si l'utilisateur cherche un certains type de carburant, le code nettoie la base de données pour ne donner que des informations qui intérèsse l'utilisateur.

**3. Enrichissement des données :** 

Ici, nous enrichissons les données par le calcul du coût total, que nous réalisons avec trois indicateurs, le prix du carburant, la distance aller-retour et la consommation du véhicule. Donc au lieu d'afficher simplment le coût du carburant, l'utilisateur connaitra le ```cout_total```, ce qui permet de présenter les stations par rentabilité réelle. On le calcul simplement grâce à cette formulation :

```{r}
calculer_cout <- function(prix_L, dist_km, conso_100) {
  trajet_AR_km <- dist_km * 2
  litres_conso <- (trajet_AR_km * conso_100) / 100
  cout_plein <- 50 * prix_L 
  return(cout_plein + (litres_conso * prix_L))
}
```

## Lancement de l'outil
Avant de lancer l'application, il est nécéssaire d'effectuer cette manipulation dans votre console R :
```{r}
install.packages(c("shiny", "shinyjs", "httr", "jsonlite", "dplyr", "leaflet"))
1. Assurez-vous d'avoir installé les bibliothèques : `shiny`, `leaflet`, `httr`, `jsonlite`, `dplyr`.
2. Lancez l'application dans R :
   ```R
   shiny::runApp()
```

## Conclusion :
Notre application permet bien de trouver quelle est la station à choisir pour optimiser son plein d'essence (surtout son prix), tout en renseignant le moins d'informations possible. Ce que nous trouvons intéréssant est d'ajouter cette carte, permettant aux utilisateurs de mieux se situer dans l'espace ainsi que de pouvoir visualiser le trajet dans google maps, pour les mener directement à cette station sans perdre de temps.
