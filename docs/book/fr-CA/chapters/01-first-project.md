# Votre premier projet {#first-project}

Commencez par un exemple qui fonctionne déjà. Vous ouvrirez des données sur des fleurs, trouverez un graphique, vérifierez un rapport et enregistrerez votre propre copie. Cette première partie ne demande aucun code R.

## Ouvrir l’exemple sur les fleurs

1. Si l’écran d’accueil est encore ouvert, choisissez **Commencer avec un canevas vide**.
2. Dans l’application de bureau, choisissez **Aide > Aide de l’application**. Dans un navigateur, sélectionnez le bouton **Aide** en haut de l’application.
3. Ouvrez **Projets d’exemple** et recherchez **Explorer les iris**.
4. Choisissez **Ouvrir l’exemple**. Si un message signale du travail non enregistré, choisissez **Annuler**, puis enregistrez votre travail avant de réessayer. Dans l’application de bureau, **Abandonner** remplace le travail actuel. Dans un navigateur, ce choix s’appelle **Abandonner et ouvrir l’exemple**.
5. Choisissez **Fichier > Enregistrer le projet sous...**. Enregistrez le projet sous le nom `flower-practice.igpx` dans votre dossier de projets. Dans un navigateur, sélectionnez **Enregistrer le projet**, puis choisissez le nom et le dossier dans la fenêtre qui s’ouvre pour cet exemple encore non enregistré.

L’iris est une fleur. L’exemple contient les mesures de **150 fleurs**, réparties en **trois espèces**, avec **50 fleurs par espèce**. Chaque ligne représente une fleur. Les quatre colonnes de mesures utilisent les centimètres. `Species` indique l’espèce de la fleur.

Ouvrir un exemple crée une copie de travail distincte. Vous pouvez la modifier sans changer l’exemple fourni avec l’application. Enregistrez votre copie pour conserver vos changements.

Un exemple peut afficher un avis de version, car ses résultats enregistrés proviennent d’une autre installation. Vous pouvez d’abord consulter ces résultats. Avant de relancer le travail, vérifiez les dossiers d’exportation. Consultez ensuite les nouveaux journaux pour voir comment le travail s’exécute sur votre ordinateur. Les [outils de révision](#review) expliquent les traces d’exécution si vous devez comparer des versions.

## Faire le tour avant d’exécuter quoi que ce soit

La partie gauche présente les tâches et les données du projet. L’onglet **Flux** montre les étapes reliées. Sélectionnez la tâche source et lisez ses notes. Ouvrez sa table de fleurs et regardez les noms des colonnes.

Les étiquettes de l’exemple décrivent le rôle de chaque étape. Sélectionnez **Summarize measurements**, **Compare mean petal length by species** et **Explore relationships** pour ouvrir les tâches Statistiques descriptives, Tableaux récapitulatifs et Nuage de points. Le type de tâche apparaît dans chaque panneau. Ouvrez **Résultats** pour consulter le résultat enregistré avant de relancer une tâche. Les noms donnés aux étapes dans un projet restent dans leur langue d’origine.

![Le repère 1 indique l’arbre du projet; le 2, le flux relié; le 3, les onglets Flux, Code et Console R. Sélectionnez une tâche pour ouvrir ses paramètres.](assets/ui-workspace.png){#fig-workspace}

Dans le résumé par espèce, les longueurs moyennes des pétales devraient être d’environ :

| Espèce | Longueur moyenne du pétale, en centimètres |
| --- | ---: |
| setosa | 1,462 |
| versicolor | 4,260 |
| virginica | 5,552 |

Vous n’avez pas à retenir ces valeurs. Elles permettent de vérifier que vous consultez la bonne table avec les bons paramètres.

![L’exemple sur les fleurs compare la longueur du sépale à celle du pétale. La couleur indique l’espèce.](assets/iris-chart.png){#fig-iris-chart}

## Faire un petit changement

1. Ouvrez la tâche **Nuage de points**.
2. Dans **Configuration**, remplacez `Petal.Length` par `Petal.Width` dans **Y / valeur**.
3. Faites défiler **Configuration** vers le bas. Remplacez le **Titre** par **Largeur du pétale selon la longueur du sépale**. Réglez **Libellé de l’axe Y** à **Largeur du pétale (cm)**.
4. Cliquez sur **Exécuter** dans l’en-tête de la tâche. Ouvrez Résultats et vérifiez le nouveau graphique.
5. Ouvrez la tâche **Rapport** et sélectionnez **Générer le rapport** pour y mettre le graphique à jour.
6. Choisissez **Fichier > Enregistrer le projet** ou appuyez sur Ctrl+S.

Vérifiez que l’axe vertical porte l’étiquette **Largeur du pétale (cm)**. Les largeurs des pétales dans les données sources vont de 0,1 à 2,5 centimètres.

![Partez de ces paramètres de Nuage de points et remplacez Y / valeur par Petal.Width. Enregistrer : Image ggplot statique conserve une image pour le rapport.](assets/ui-chart-settings.png){#fig-chart-settings}

Modifier un paramètre ne met pas à jour un rapport déjà enregistré. Exécutez la tâche modifiée, puis les tâches suivantes qui utilisent son résultat. Pour tout relancer, utilisez le bouton de lecture du flux. Vérifiez d’abord les dossiers des tâches Exporter et leurs paramètres de remplacement des fichiers.

## Trouver le rapport et le journal

1. Ouvrez la tâche **Rapport**. Dans **Apparence**, sélectionnez **Inclure le journal du flux dans le rapport**.
2. Sélectionnez **Générer le rapport**, puis **Télécharger le fichier HTML**. Enregistrez le fichier dans votre dossier de projets et ouvrez-le dans un navigateur.
3. Vérifiez les titres, les tables, le graphique et la section **Pipeline execution log**. Le rapport téléchargé est un fichier distinct du projet.

Ouvrez **Exporter le journal** pour voir comment l’exemple écrit son journal dans un fichier. Avant d’exécuter cette tâche, choisissez une destination facile à retrouver. Un journal peut contenir des exécutions précédentes en plus de la dernière. Les dates et les heures aident à les distinguer.

## Construire un petit flux vous-même

Cet exercice facultatif crée les mêmes types de résultats dans un nouveau projet. Il comprend un court extrait de code R à copier exactement. Vous n’avez pas besoin de comprendre ce code pour terminer l’exercice. Vous pouvez aussi continuer avec les exemples prêts à utiliser.

Partez d’un projet vide. Dans l’application Windows, choisissez **Fichier > Nouveau projet** et enregistrez-le sous `first-iris.igpx`. Dans un navigateur, enregistrez votre travail, actualisez la page et choisissez **Commencer avec un canevas vide**. Utilisez ensuite **Enregistrer le projet** pour créer `first-iris.igpx`.

Utilisez **Ajouter une tâche** pour trouver chaque tâche ci-dessous. Les étiquettes permettent de reconnaître les étapes. Les noms des sorties indiquent aux étapes suivantes quel résultat utiliser. Saisissez donc ces noms avec soin.

### Étape 1 : charger les données d’exercice

1. Sélectionnez **Ajouter une tâche**, ouvrez **Général** et choisissez **Script**.
2. Dans l’en-tête de la tâche, réglez **Table principale** à `flowers`.
3. Dans **Configuration**, laissez **Tables d’entrée / sorties spéciales** vide. Cette étape fournit ses propres données.
4. Dans **Sorties**, saisissez `flowers: table` sur une ligne. Cela indique à l’application de conserver une table nommée `flowers`.
5. Collez le code suivant dans **Code R**, et non dans la Console R :

```r
flowers <- datasets::iris
log_event(sprintf("Loaded %d flowers", nrow(flowers)), "INFO")
```

![Dans Sorties, flowers: table déclare la table à conserver. Son nom correspond à flowers dans le code copié.](assets/ui-script-outputs.png){#fig-script-outputs}

Cliquez sur **Exécuter**. Sélectionnez `flowers` sous **JEUX DE DONNÉES** dans l’arbre du projet et vérifiez qu’il y a 150 lignes et cinq colonnes. Si la table est absente, assurez-vous que Sorties contient `flowers: table`. Le nom doit correspondre à celui du code copié.

### Étape 2 : résumer les mesures

1. Sélectionnez **Ajouter une tâche > Description > Statistiques descriptives**.
2. Dans **Configuration**, sélectionnez `flowers` dans **Table d’entrée**.
3. Dans **Colonnes numériques**, choisissez `Sepal.Length`, `Sepal.Width`, `Petal.Length` et `Petal.Width`.
4. Laissez **Enregistrer** coché et saisissez `measurement_summary` dans **Table de sortie**.
5. Sélectionnez **Analyser**, puis ouvrez **Résultats**.

![Statistiques descriptives demande une table d’entrée et des colonnes numériques. La case Enregistrer conserve la Table de sortie pour les tâches suivantes.](assets/ui-summary-settings.png){#fig-summary-settings}

Dans **Résultats**, sélectionnez **Données** pour lire la table enregistrée. Vérifiez la moyenne de `Sepal.Length`. Elle devrait être d’environ **5,8433**. Une moyenne est le total divisé par le nombre de valeurs. L’application peut afficher moins de décimales.

### Étape 3 : comparer les trois espèces

1. Sélectionnez **Ajouter une tâche > Description > Tableaux récapitulatifs**.
2. Dans **Configuration**, choisissez les paramètres suivants :

| Paramètre | Choix |
| --- | --- |
| Table d’entrée | `flowers` |
| Variable en ligne | `Species` |
| Variable de valeur | `Petal.Length` |
| Statistique récapitulative | Moyenne |
| Table de sortie | `species_summary` |

3. Laissez **Enregistrer** coché et sélectionnez **Analyser**.
4. Ouvrez **Résultats > Données** et comparez les trois moyennes avec la table présentée plus haut dans ce chapitre.

### Étape 4 : tracer le graphique

1. Sélectionnez **Ajouter une tâche > Graphiques > Nuage de points** et choisissez `flowers` dans **Table d’entrée**.
2. Réglez **X / catégorie / date** à `Sepal.Length`, **Y / valeur** à `Petal.Length` et **Groupe / couleur** à `Species`.
3. Réglez **Titre** à **Mesures des iris par espèce**.
4. Près du haut du panneau, cochez **Enregistrer : Image ggplot statique**. Réglez **Nom de la sortie : Image ggplot statique** à `iris_scatter_image`.
5. Sélectionnez **Exécuter** et ouvrez **Résultats**. Vérifiez que le graphique ressemble à la [figure](#fig-iris-chart).

Une image statique est un graphique fixe à placer dans un rapport ou à exporter en PNG. Le mot ggplot désigne l’outil de création du graphique. Vous n’avez pas à l’apprendre.

### Étape 5 : enregistrer une table et un graphique dans des fichiers

1. Sélectionnez **Ajouter une tâche > Sortie > Exporter**. Choisissez `species_summary` dans **Sortie à exporter** et CSV dans **Format**.
2. Sélectionnez **Choisir un dossier…** et choisissez votre dossier de projets. Dans **Nom du fichier (sans extension)**, saisissez `species-summary`.
3. Sélectionnez **Exporter** et vérifiez que `species-summary.csv` se trouve dans ce dossier.
4. Ajoutez une autre tâche Exporter. Sélectionnez `iris_scatter_image`, choisissez PNG et utilisez le même dossier.
5. Saisissez `iris-scatter` sans extension. Réglez **DPI** à 150, sélectionnez **Exporter** et ouvrez `iris-scatter.png`.

DPI indique le nombre de points par pouce. Vérifiez le texte dans l’image produite avant de la partager.

Un fichier existant peut bloquer l’exportation. Choisissez un autre nom ou activez **Remplacer le fichier s’il existe déjà** si vous voulez le remplacer. Un fichier exporté est distinct de votre projet enregistré.

### Étape 6 : créer un rapport

1. Sélectionnez **Ajouter une tâche > Sortie > Rapport**. Dans **Contenu**, ajoutez `measurement_summary`, `species_summary` et `iris_scatter_image`. Donnez un titre de section clair à chaque élément.
2. Dans **Apparence**, choisissez HTML dans **Format de sortie** et réglez **Titre du rapport** à **Premier rapport sur les iris**.
3. Sélectionnez **Inclure le journal du flux dans le rapport** et laissez **Niveau minimal du journal** à INFO.
4. Sélectionnez **Générer le rapport**, puis **Télécharger le fichier HTML**. Ouvrez le fichier téléchargé et vérifiez qu’il contient les deux tables, le graphique et **Pipeline execution log**.

### Étape 7 : enregistrer le journal

Un chemin complet comprend l’adresse du dossier et le nom du fichier. Utilisez votre propre dossier de projets. Le dossier d’exercice montré dans les images sert seulement d’exemple.

1. Sélectionnez **Ajouter une tâche > Sortie > Exporter le journal**.
2. Dans **Exécuter après et inclure ces tâches**, sélectionnez les tâches précédentes, dont Rapport, pour que l’exportation les attende.
3. Choisissez CSV. Dans **Chemin complet du fichier de destination**, saisissez le chemin complet de `iris-log.csv` dans votre dossier de projets. Par exemple, prenez l’adresse du dossier dans l’Explorateur de fichiers Windows, puis ajoutez `/iris-log.csv`.
4. Exécutez le flux actif. Ouvrez le CSV et cherchez **Loaded 150 flowers** et l’entrée indiquant la fin de la tâche Rapport.

La section du journal dans le rapport est créée avant la fin du rapport. La tâche finale Exporter le journal peut consigner cette fin survenue plus tard.

### Étape 8 : fermer et rouvrir votre travail

1. Choisissez **Fichier > Enregistrer le projet** pour enregistrer `first-iris.igpx`.
2. Choisissez **Fichier > Fermer le projet**, puis **Fichier > Ouvrir un projet...** et sélectionnez ce fichier. Dans un navigateur, utilisez **Ouvrir un projet** en haut de l’application après avoir enregistré.
3. Vérifiez que la table, le graphique et le rapport sont toujours là. Vous avez créé un flux réutilisable avec des données, des résultats, un rapport et un journal.

# Se repérer dans l’application {#workspace}

La liste du projet, le diagramme du flux et les panneaux des tâches présentent le même travail de différentes façons. Choisissez la vue qui vous aide à trouver la prochaine étape.

## Ouvrir une tâche ou un résultat

Sélectionnez une tâche dans la liste du projet ou dans le flux pour ouvrir son panneau. Ses paramètres définissent ce qu’elle fait. Les résultats montrent ce qui s’est passé lors de sa dernière exécution. Développez **Journalisation** pour lire les entrées et définir des messages. **Code**, lorsqu’il est offert, montre les instructions R. Sa lecture est facultative.

Fermer l’onglet d’une tâche masque son panneau sans supprimer la tâche. Utilisez l’action de suppression seulement si vous voulez retirer l’étape elle-même.

Si le diagramme est trop chargé, choisissez **Affichage > Liste des tâches** dans l’application de bureau. Dans un navigateur, sélectionnez **Outils du projet**, puis **Liste des tâches**. Recherchez l’étape voulue et ouvrez-la depuis la liste. Utilisez **Ajuster l’affichage** pour revoir tout le flux.

## Configurer et conserver le résultat d’une tâche {#task-controls}

La plupart des pages sur les tâches supposent que vous avez ouvert un projet et exécuté l’étape qui fournit la table d’entrée. Pour ajouter une tâche, sélectionnez **Ajouter une tâche**, choisissez sa catégorie, puis son nom. Le [répertoire des tâches](#task-finder) donne les catégories.

1. Ouvrez **Configuration** si la tâche possède cet onglet. Choisissez la table d’entrée avant les colonnes. La liste des colonnes peut rester vide tant que la tâche source n’a pas été exécutée.
2. Saisissez un nom de sortie unique. Gardez cochée toute case **Enregistrer** à côté d’un résultat à conserver. Un résultat seulement affiché peut ne pas être accessible aux tâches suivantes.
3. Sélectionnez **Exécuter** dans l’en-tête de la tâche. Certains formulaires ont aussi un bouton plus précis, comme **Analyser**, **Charger**, **Exporter** ou **Générer le rapport**. Ce guide donne ce nom lorsque cela aide.
4. Ouvrez **Résultats**, **Données** ou **Aperçu**, selon les indications. Vérifiez les valeurs et les messages avant de continuer.
5. Enregistrez le projet pour conserver le travail sur disque. La case **Enregistrer** d’une tâche et **Enregistrer le projet** ont des rôles différents.

![Dans Résultats, l’onglet Données présente une ligne par mesure numérique. Vérifiez la moyenne et le nombre de valeurs manquantes avant d’utiliser la table dans un rapport.](assets/ui-summary-result.png){#fig-summary-result}

Un formulaire peut défiler. Si un réglage de sortie est introuvable, regardez près du haut du panneau. Si le bouton d’action est introuvable, regardez près du bas. Les couleurs des images peuvent différer de votre thème. Les étiquettes et les étapes restent les mêmes.

Les images utilisent un dossier d’exercice distinct. Choisissez le dossier créé lors de l’installation si votre adresse de fichier diffère de celle de l’image.

## Comprendre les flèches

Une tâche suivante a besoin du bon nom d’entrée. Par exemple, un résumé qui utilise `flowers` doit attendre la tâche qui crée `flowers`. L’application dessine le lien à partir de ces choix.

Déplacer une tâche dans le diagramme change sa position, mais pas son ordre d’exécution. Pour changer cet ordre, modifiez ses entrées ou ses paramètres de branche et de boucle.

## Choisir des noms utiles

Donnez aux tâches des étiquettes claires, comme **Retirer les lignes de clients répétées**. Utilisez des noms de sortie courts et uniques, comme `customers_clean`. Après avoir changé un nom de sortie, vérifiez les entrées des tâches suivantes et relancez le flux.

# Enregistrer, rouvrir et partager des projets {#projects}

## Enregistrer votre projet

Utilisez **Fichier > Enregistrer le projet** ou Ctrl+S dans l’application de bureau. Au premier enregistrement, choisissez un nom et un dossier. Utilisez **Fichier > Enregistrer le projet sous...** pour garder une copie distincte avant un grand changement.

![Le menu Fichier regroupe l’enregistrement, les versions enregistrées, la portabilité et les paramètres. Utilisez Enregistrer le projet sous pour créer une copie distincte.](assets/ui-file-menu.png){#fig-file-menu width=10cm}

Dans un navigateur, utilisez les commandes d’enregistrement de l’application. Suivez la fenêtre de sélection ou de téléchargement et vérifiez où le fichier est enregistré.

Un projet enregistré conserve les tâches, les paramètres, les résultats disponibles, les notes et les journaux conservés. Il ne copie pas automatiquement tous les fichiers externes utilisés par les tâches. Gardez les fichiers d’entrée importants dans un dossier stable.

## Déplacer le travail vers un autre ordinateur

1. Enregistrez le projet, puis choisissez **Fichier > Fichiers du projet et transfert...** dans l’application de bureau. Dans un navigateur, ouvrez **Outils du projet**, puis l’option des fichiers du projet.
2. Vérifiez la liste des fichiers externes. Réglez les fichiers manquants avant de créer une copie portable.
3. Sélectionnez **Enregistrer un projet portable** pour joindre les entrées prises en charge au projet.
4. Ouvrez la copie sur l’autre ordinateur et vérifiez ses entrées avant de l’exécuter.

Les connexions aux bases de données exigent toujours l’accès à ces bases. Un Script peut utiliser un fichier que l’exportation portable ne trouve pas seule. Dans ce cas, joignez ce fichier séparément et mettez son chemin à jour. Un chemin est l’adresse d’un fichier ou d’un dossier sur votre ordinateur.

Les rapports et fichiers déjà exportés sont des copies distinctes. Enregistrer à nouveau le projet ne met pas ces copies à jour. Exécutez la tâche Rapport ou Exporter voulue quand les résultats changent.

## Récupérer du travail interrompu

L’application garde des informations de récupération pour le travail non enregistré. Après un arrêt ou un redémarrage, elle peut proposer une copie de récupération. Lisez le message, récupérez le travail voulu, puis enregistrez-le sous un nom clair.

La récupération aide après un problème. Continuez à enregistrer pendant le travail normal. Pour retrouver une ancienne copie enregistrée, choisissez **Fichier > Versions enregistrées du projet...** dans l’application de bureau, ou **Versions enregistrées** dans les Outils du projet du navigateur. Vérifiez la date avant de restaurer une version.

1. Enregistrez le projet actuel avant d’ouvrir ses versions enregistrées.
2. Ouvrez **Versions enregistrées du projet...** pour le projet à restaurer. Sélectionnez une **Version enregistrée précédente** selon sa date et son heure.
3. Sélectionnez **Rétablir la version sélectionnée**. Cela ouvre l’ancien travail comme copie non enregistrée.
4. Vérifiez ses résultats, puis utilisez **Enregistrer le projet sous...** pour le garder sous un autre nom. **Enregistrer le projet** réécrit le travail restauré dans le fichier du projet actuel.

## Partager un projet avec soin

Un projet peut contenir des données, des chemins, des journaux et du code R. Partagez seulement ce que vous souhaitez partager. Ouvrez les projets de personnes ou de sources fiables, car les tâches peuvent exécuter du code et écrire des fichiers.

Avant d’envoyer un projet, enregistrez-le, vérifiez son rapport et essayez d’ouvrir la copie enregistrée. Si la personne a seulement besoin des résultats, envoyez un rapport ou un CSV plutôt que le projet complet.
