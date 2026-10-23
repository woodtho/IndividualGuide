# Bienvenue dans Individual Guide {#reading-this-book}

Vous pouvez utiliser Individual Guide sans connaître R. L’application vous aide à importer des données, à les nettoyer, à créer des graphiques et à partager les résultats. Vous choisissez les paramètres dans des formulaires. L’application fait les calculs pour vous.

Un projet ressemble à une recette. Vos données sont les ingrédients. Chaque **tâche** est une étape, comme trier des lignes ou tracer un graphique. Un **flux**, aussi appelé pipeline, relie ces étapes. Vous pouvez enregistrer la recette et la réutiliser.

Ce guide porte sur **Individual Guide 0.7.0**, qui offre **58 types de tâches** et **22 projets d’exemple**. Commencez par l’installation et le premier projet. Ensuite, consultez les tâches dont vous avez besoin. Vous n’avez pas à lire le guide du début à la fin.

## Trouver votre point de départ

| Ce que vous voulez faire | Où aller |
| --- | --- |
| Installer l’application Windows | [Installation et premier démarrage](#installation) |
| Essayer l’application avec des données prêtes à utiliser | [Votre premier projet](#first-project) |
| Importer votre feuille de calcul ou votre fichier CSV | [Importer vos données](#importing) |
| Trouver une tâche et un exemple correspondant | [Répertoire des tâches](#task-finder) |
| Créer un rapport avec un journal | [Rapports et fichiers](#reports-and-exports) |
| Régler un problème | [Dépannage](#troubleshooting) |
| Lancer plutôt l’application avec R | [Facultatif : installer avec R](#install-with-r) |

## Six mots que vous verrez souvent

| Mot | Sens dans l’application |
| --- | --- |
| Projet | Votre travail enregistré : données, tâches, résultats et notes |
| Table | Des données en lignes et en colonnes, comme dans une feuille de calcul |
| Tâche | Une étape qui accomplit un travail |
| Flux | Un groupe de tâches reliées |
| Sortie | Le résultat d’une tâche, comme une table ou un graphique |
| Journal | Un relevé de ce qui s’est passé pendant l’exécution des tâches |

Par exemple, un projet sur des fleurs peut partir de mesures, calculer une moyenne, tracer un graphique et créer un rapport. Les flèches montrent quelles étapes ont besoin des résultats des étapes précédentes.

![Un flux mène les données vers des tâches, puis vers des résultats, des rapports et un journal enregistré.](assets/workflow.png){#fig-flow}

## Comment suivre ce guide

Les mots en gras, comme **Exécuter**, nomment des boutons ou des choix. **Fichier > Enregistrer le projet sous...** veut dire d’ouvrir le menu Fichier, puis de choisir Enregistrer le projet sous. Les points indiquent qu’une autre fenêtre va s’ouvrir. Le texte comme `flowers` est un nom à saisir exactement.

L’application Windows a des menus en haut de la fenêtre. Si vous ouvrez l’application avec R dans un navigateur Web, utilisez ses boutons pour ouvrir et enregistrer les projets. Certaines fonctions de bureau, comme redémarrer le serveur R dans un menu, sont réservées à l’application Windows.

Certaines commandes du navigateur sont des icônes. Pointez une icône pour voir son nom, comme **Enregistrer le projet** ou **Aide**.

Le guide HTML fonctionne hors ligne une fois téléchargé. Utilisez **Trouver un chapitre ou une tâche** dans sa table des matières, ou Ctrl+F pour chercher dans la page. Le PDF est pratique pour l’impression. EPUB convient aux liseuses, et Word vous permet d’ajouter vos notes.

Consultez le même guide en [English](https://woodtho.github.io/IndividualGuide/) ou en [Français (Canada)](https://woodtho.github.io/IndividualGuide/fr-CA/). Les deux éditions ont les mêmes chapitres, exemples et étapes, avec des captures d’écran dans leur langue. Choisissez la même langue pour l’application et le guide afin que les boutons correspondent aux images.

# Installation et premier démarrage {#installation}

Pour la plupart des utilisateurs de Windows, le programme d’installation Setup est le choix le plus simple. Il comprend R et les logiciels nécessaires à l’application. **Vous n’avez pas à installer R ou RStudio séparément.**

## Télécharger la version publique pour Windows

Il vous faut un ordinateur avec Windows 10 ou Windows 11 en 64 bits. Prévoyez environ 1,5 Go pour le programme, plus de l’espace pour vos projets. Une connexion Internet est nécessaire pour télécharger Setup. Une fois installés, l’application et ses exemples fonctionnent hors ligne. Les tâches qui utilisent une base de données en ligne ont toujours besoin de cette connexion.

1. Ouvrez la [page des versions publiques](https://github.com/woodtho/IndividualGuide/releases/latest).
2. Sous **Assets**, téléchargez **IndividualGuide-0.7.0-Setup-Windows-x64.exe** pour cette édition. Si une version plus récente est affichée, lisez ses notes avant de la choisir. Le programme qui correspond à ce guide se trouve sur la [page de la version 0.7.0](https://github.com/woodtho/IndividualGuide/releases/tag/v0.7.0).
3. Fermez toute copie ouverte d’Individual Guide. Les fichiers nommés **Source code** ne sont pas nécessaires pour utiliser l’application de bureau.
4. Double-cliquez sur le fichier Setup téléchargé. Choisissez **English** ou **Français (Canada)** lorsque la langue est demandée, puis suivez les instructions. L’installation habituelle utilise votre propre compte Windows.
5. Ouvrez **Individual Guide** dans le menu Démarrer ou avec le raccourci du Bureau.

Le programme d’installation n’est pas signé. Windows peut afficher un avertissement d’éditeur inconnu. Vérifiez que le fichier vient de **woodtho/IndividualGuide** avant de décider de continuer. Si votre ordinateur de travail ou d’école le bloque, demandez de l’aide à votre équipe de soutien.

## Ouvrir l’application chaque jour

Utilisez le menu Démarrer ou le raccourci du Bureau. Setup installe ou met à jour le programme. Vous n’avez pas à le lancer chaque fois.

Le premier démarrage peut prendre plus de temps que les suivants. Patientez pendant que l’écran de démarrage affiche la progression. L’écran d’accueil propose ensuite trois choix. Pour le premier exercice, choisissez **Commencer avec un canevas vide**. L’espace de travail s’ouvre et le menu Aide devient accessible.

![À l’accueil, choisissez Commencer avec un canevas vide pour accéder à l’espace de travail et à son menu Aide.](assets/ui-welcome.png){#fig-welcome width=12cm}

Si le démarrage s’arrête avec une erreur, choisissez **Ouvrir le journal de démarrage**. Consultez le [dépannage](#troubleshooting) pour la suite. Ouvrir plusieurs copies aide rarement.

## Choisir ou changer la langue {#language}

L’application offre l’anglais et le français canadien. Le programme d’installation Windows transmet votre choix à l’application. Vous pouvez le changer plus tard sans redémarrer R ni rouvrir le projet.

1. Choisissez **English** ou **Français (Canada)** dans la liste des langues à l’accueil ou près du nom de l’application.
2. Dans l’application de bureau, vous pouvez aussi utiliser le menu **Langue**. Dans **Paramètres**, recherchez **Langue de l’interface**, puis sélectionnez **Édition** et **Enregistrer l’option** pour une valeur globale ou un remplacement du projet.
3. Vérifiez que les boutons et les menus sont dans la langue choisie. L’application la conserve sur cet ordinateur.

La langue est distincte du projet. Ouvrir un autre projet ne la change pas. Vos données, noms de colonnes, chemins de fichiers, formules et noms saisis restent tels quels. Les commandes R et les identifiants techniques gardent l’orthographe que R exige.

## Mettre à jour l’application

1. Enregistrez votre projet et fermez l’application.
2. Consultez la [page des versions publiques](https://github.com/woodtho/IndividualGuide/releases/latest).
3. Téléchargez le nouveau programme Setup et lancez-le.
4. Ouvrez l’application avec son raccourci. Consultez **Aide > À propos d’Individual Guide...** pour voir la version installée.

L’application ne se met pas à jour toute seule. Une mise à jour conserve les projets et les paramètres, mais gardez votre propre copie de vos projets importants. La désinstallation dans Windows retire le programme et conserve les données utilisateur stockées séparément.

## Avant votre premier projet

Créez un dossier facile à retrouver, comme **Documents > Projets Individual Guide**. Utilisez-le pour les projets enregistrés et les fichiers exportés. Donnez un nom clair à chaque projet, comme `flower-practice.igpx`.

L’extension **.igpx** désigne un projet Individual Guide. Ouvrez-le avec **Fichier > Ouvrir un projet...**, ou double-cliquez sur le fichier dans Windows après l’installation.

Vous pouvez maintenant essayer [votre premier projet](#first-project). Les étapes facultatives d’installation de R sont à la fin du guide. L’application Windows n’en a pas besoin.
