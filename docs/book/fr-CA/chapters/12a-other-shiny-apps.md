# Ouvrir d’autres applications Shiny {#other-shiny-apps}

Une application Shiny est une page interactive qui utilise R en arrière-plan. Elle peut afficher un tableau de bord, un graphique ou un formulaire. Vous pouvez ouvrir une application partagée avec vous dans Individual Guide. Il n’est pas nécessaire de copier son code dans un flux.

Votre projet Individual Guide reste ouvert. L’autre application utilise sa propre copie de R. Sa vue remplit presque toute la fenêtre, avec une barre Individual Guide en haut.

## Ce qu’il vous faut

Demandez à l’auteur le dossier complet de l’application et ses consignes de préparation. Un dossier pris en charge contient l’un des formats suivants :

- Un fichier **app.R**, avec les données et les fichiers de soutien qu’il utilise.
- Les deux fichiers **ui.R** et **server.R**, avec les autres fichiers nécessaires.

Gardez le dossier complet. S’il provient d’un fichier ZIP, extrayez-le d’abord. Le choix d’un fichier ne le téléverse pas et n’installe aucun paquet. L’application s’exécute sur cet ordinateur et peut lire ou modifier des fichiers avec vos droits d’accès. Utilisez seulement une application provenant d’une source fiable.

## Essayer les applications de pratique

1. Téléchargez les [applications Shiny de pratique pour cette version](https://github.com/woodtho/IndividualGuide/releases/download/v0.6.0/IndividualGuide-Shiny-Examples-0.6.0.zip).
2. Faites un clic droit sur le ZIP dans Windows, puis choisissez **Extraire tout**. Choisissez un dossier facile à retrouver.
3. Suivez les étapes ci-dessous. Choisissez **iris-explorer/app.R** pour l’application sur les fleurs. Choisissez le dossier **local-sales** pour l’application à deux fichiers, qui lit un CSV et peut télécharger une copie filtrée. Les deux utilisent des paquets inclus dans Individual Guide.

L’application sur les fleurs a sa propre liste **Language / Langue**. Choisissez-y **Français (Canada)** pour afficher ses libellés en français. Cette liste change seulement l’application de pratique.

## Ouvrir et exécuter une application

![Choisissez un fichier app.R ou un dossier contenant ui.R et server.R. Votre projet Individual Guide reste ouvert derrière cette vue.](assets/ui-shiny-app-picker.png){#fig-shiny-app-picker width=16cm}

1. À l’accueil, choisissez **Ouvrir une application Shiny**. Dans votre espace de travail, utilisez l’icône de fenêtre à côté du nom de l’application. Dans le menu de bureau, **Fichier > Ouvrir une application Shiny...** ouvre la même vue.
2. Choisissez **Choisir app.R...** pour une application dans un seul fichier, ou **Choisir le dossier...** pour un dossier. Pour le format à deux fichiers, choisissez le dossier qui contient les deux.
3. Vérifiez le chemin choisi. Gardez les données, les scripts de soutien et le dossier **www** à leur place d’origine.
4. Si la source est fiable, cochez **Je fais confiance à cette application**, puis **Exécuter l’application**.
5. Attendez que l’application apparaisse. Utilisez ses propres commandes pour travailler avec ses données. La barre Individual Guide reste au-dessus.

## Revenir à votre projet

![L’application ouverte remplit presque toute la fenêtre. La barre Individual Guide garde à portée de main le projet, le choix d’application, le journal et la fermeture.](assets/ui-shiny-app-running.png){#fig-shiny-app-running width=16cm}

Choisissez **Individual Guide** à gauche de la barre du haut. Votre projet est toujours là, avec sa saisie et ses résultats. L’autre application continue de fonctionner en arrière-plan.

Utilisez de nouveau l’icône de fenêtre pour revenir à l’autre application. Sa saisie reste telle que vous l’avez laissée. Dans l’application de bureau, **Affichage > Espace de travail Individual Guide** vous ramène aussi à votre projet.

Le changement de vue ne redémarre aucun des deux processus R. Si vous avez terminé avec l’autre application, fermez-la pour libérer ses ressources.

## Fermer une application ou en ouvrir une autre

Pour arrêter une application, choisissez **Fermer l’application** dans sa barre du haut. Enregistrez d’abord votre travail avec ses propres commandes. Lisez la confirmation, puis choisissez encore **Fermer l’application**. **Annuler** la garde ouverte. Sa fermeture laisse Individual Guide et votre projet ouverts.

Pour changer d’application, choisissez **Ouvrir une application...**, puis un autre fichier ou dossier. Le choix d’un fichier ne ferme pas l’application en cours. Vous pouvez choisir **Revenir à l’application en cours** si vous changez d’idée. Quand vous choisissez **Exécuter l’application**, l’ancienne se ferme et la nouvelle démarre. Enregistrez le travail dans l’ancienne avant cette étape.

La fermeture d’Individual Guide arrête aussi l’application ouverte. Sa session temporaire n’est pas enregistrée dans votre projet **.igpx**. Chaque application décide comment enregistrer ses données et ses paramètres.

Le redémarrage du serveur R principal ferme aussi l’application ouverte. Enregistrez le travail dans les deux applications avant de redémarrer.

## Si une application ne démarre pas

Choisissez **Journal de l’application** pour lire ses messages. La même commande fonctionne pendant son exécution. Les journaux gardent la langue d’origine de l’application. Copiez l’erreur exacte pour demander de l’aide à son auteur.

- Si un fichier manque, vérifiez que vous avez extrait et gardé le dossier complet.
- Si un paquet manque, suivez les consignes de l’auteur pour l’installer depuis une source publique. Individual Guide inclut ses propres paquets, mais ne peut pas inclure tous ceux d’une autre application. Individual Guide n’installe pas de paquets supplémentaires pour cette application.
- Si l’application s’arrête ou prend trop de temps à démarrer, la barre du haut reste accessible. Vous pouvez la relancer, en choisir une autre ou revenir à votre projet.

Le choix de langue dans Individual Guide change sa propre barre et ses commandes. L’application ouverte garde la langue et l’apparence prévues par son auteur. Son code R s’exécute séparément, avec les bibliothèques de paquets accessibles à Individual Guide. Les applications qui demandent une autre version de R, un logiciel externe ou une base de données ont toujours besoin de leur propre préparation.

Cette fonction ouvre des applications locales. Dans la version pour navigateur, utilisez un navigateur sur l’ordinateur qui exécute Individual Guide.
