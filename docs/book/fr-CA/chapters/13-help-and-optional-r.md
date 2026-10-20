# Garder le travail fluide {#performance}

Essayez une petite version du flux avant d’utiliser beaucoup de données. Vérifiez les paramètres, puis exécutez la version complète une fois son rôle bien compris.

## Si la saisie semble lente

Attendez la fin de l’exécution active ou utilisez Arrêter si elle n’est plus nécessaire. Fermez les panneaux inutilisés et utilisez la Liste des tâches pour parcourir un grand projet. Un graphique réduit ou un échantillon facilite l’exploration, mais gardez les données complètes pour les calculs qui en ont besoin.

Si l’application reste lente, enregistrez, fermez-la et rouvrez-la depuis son raccourci. Notez la tâche et l’action qui provoquent le délai si vous demandez de l’aide. **Saisir le nom de sortie est lent dans un projet de 40 tâches** est plus facile à étudier que **L’application est lente**.

# Résoudre les problèmes {#troubleshooting}

Commencez par le symptôme ci-dessous. Gardez le texte exact de l’erreur pour demander de l’aide. Il indique souvent un fichier, une colonne ou un paquet manquant.

## L’application semble ne pas s’ouvrir

Utilisez le raccourci installé dans le menu Démarrer ou sur le bureau. Attendez les étapes de démarrage, surtout au premier lancement. Si vous avez ouvert Setup, terminez l’installation, puis utilisez le raccourci de l’application.

Si le démarrage échoue, ouvrez son journal et gardez le message d’erreur. Vérifiez que l’installation vient de la [page publique des versions](https://github.com/woodtho/IndividualGuide/releases/latest) et convient à votre ordinateur Windows 64 bits.

## L’application se déconnecte ou le serveur R s’arrête

1. Si l’espace de travail répond encore, enregistrez le projet et attendez la fin de l’enregistrement.
2. Dans l’application de bureau, choisissez **Session > Redémarrer le serveur R...**. Si un écran de reconnexion apparaît, son bouton **Redémarrer le serveur R** offre le même moyen de récupération.
3. Lisez la confirmation et redémarrez. Cela arrête le travail actif et peut perdre les changements non enregistrés.
4. Attendez la reconnexion. Rouvrez le projet enregistré ou sélectionnez **Rétablir** si **Récupérer le travail non enregistré?** propose la copie voulue. Enregistrez une copie récupérée avant de continuer.
5. Vérifiez les chemins d’entrée et les résultats avant de relancer le flux.

![Le menu Session de l’application de bureau offre le redémarrage du serveur et les diagnostics de démarrage. Utilisez plutôt les journaux des tâches pour étudier un résultat d’analyse.](assets/ui-session-menu.png){#fig-session-menu width=11cm}

Si vous utilisez R dans un navigateur, retournez à la fenêtre R qui a lancé l’application. Arrêtez cette session au besoin et relancez la commande d’ouverture. Voyez [Facultatif : installer avec R](#install-with-r). La version navigateur n’a pas de menu Session de bureau indépendant.

## Un bouton ou un menu est désactivé

Terminez toute fenêtre ouverte et vérifiez si un flux est en cours. Ouvrez ou créez un projet si vous êtes encore à l’accueil. Si l’application est déconnectée, reconnectez ou redémarrez d’abord le serveur R.

## Un fichier ne s’importe pas

Vérifiez que le fichier existe et que vous pouvez ouvrir son dossier. Pour le texte, vérifiez le séparateur et les en-têtes. Pour Excel, vérifiez la feuille et la plage choisies. Confirmez que le type de fichier correspond au choix d’importation.

Si l’erreur nomme un paquet absent et que vous utilisez R, suivez les [instructions d’installation publiques](#install-with-r). Avec Setup, gardez l’erreur complète et la version de l’application pour signaler le problème.

## Une table ou une colonne manque dans une liste

Exécutez la tâche qui crée la table. Vérifiez son nom de sortie et Résultats. Regardez ensuite si une tâche de nettoyage a renommé ou retiré la colonne. Une liste numérique peut cacher une colonne stockée comme texte. Examinez son type avant de la convertir.

## Un résultat est ancien, vide ou différent de l’aperçu

Vérifiez l’entrée et les filtres choisis. Utilisez Exécuter, plutôt qu’Aperçu seulement, pour conserver le résultat. Relancez les tâches suivantes après un changement d’entrée. Vérifiez les décisions de branchement pour le travail ignoré et les journaux pour les échecs précédents.

Certaines vues montrent seulement le début d’une grande table. Lisez le nombre de lignes et la limite avant de conclure à des données absentes.

## Un modèle échoue ou semble étrange

Lisez son premier avertissement ou sa première erreur. Vérifiez les types de la réponse et des prédicteurs, les valeurs manquantes, les effectifs des groupes et les lignes utilisables. Un exemple semblable aide à vérifier la configuration. Des conseils de méthode peuvent être nécessaires même si tous les paramètres sont valides.

## Un graphique manque dans un rapport

Exécutez la tâche graphique et activez sa sortie d’image statique. Sélectionnez cette image dans Rapport, puis relancez Rapport. Ouvrez le fichier téléchargé pour vérifier.

Si Word indique que Pandoc manque, suivez la configuration des rapports dans la section R facultative. Setup pour Windows comprend déjà Pandoc. HTML est un bon premier format à essayer.

## Un fichier exporté manque ou ne se met pas à jour

Ouvrez sa tâche Exporter ou Exporter le journal. Vérifiez la destination complète, les droits du dossier, le nom et le format. Relancez la tâche. Si le fichier existe déjà, choisissez entre autoriser le remplacement et donner un autre nom. Fermez-le dans tout autre programme qui pourrait le verrouiller.

## Un journal semble vide

Vérifiez que la journalisation et ses règles sont activées. Les messages INFO n’apparaissent pas avec un minimum de WARN. Relancez une tâche choisie et vérifiez son propre journal avant l’exportation ou l’annexe du rapport.

La section de journal du rapport contient les événements déjà consignés, pas sa propre fin survenue plus tard. Placez Exporter le journal après Rapport pour obtenir cette entrée.

## Demander de l’aide

Utilisez le [suivi public des problèmes](https://github.com/woodtho/IndividualGuide/issues) pour les problèmes de l’application. Un compte GitHub est nécessaire pour créer un signalement. Indiquez la version, le moyen d’ouverture, la dernière action, l’erreur exacte et le résultat attendu.

Pour les problèmes de démarrage ou de connexion, utilisez **Session > Enregistrer le journal de diagnostic...** dans l’application de bureau. Pour une analyse, exportez le journal de la tâche concernée. Vérifiez les pièces jointes avant de publier : retirez les données privées et les mots de passe. Un petit exemple de données publiques explique souvent le mieux le problème.

# Facultatif : installer avec R {#install-with-r}

Passez ce chapitre si vous utilisez Setup pour Windows. Ces étapes servent à lancer l’application depuis R. Il n’est pas nécessaire d’apprendre d’abord la programmation R.

**R** est le logiciel de calcul. Un **paquet** R est un ajout au logiciel. IndividualGuide est le nom du paquet de l’application. Vous l’installez une fois, puis utilisez une courte commande les jours suivants.

## Étape 1 : installer R depuis son site public

1. Allez au [site de téléchargement de R, CRAN](https://cran.r-project.org/). Choisissez votre système d’exploitation.
2. Sous Windows, choisissez **Download R for Windows**, puis **base**, puis l’installateur R actuel. Téléchargez-le et suivez ses instructions.
3. Ouvrez **R** depuis le menu Démarrer. Vérifiez la présence d’une console avec l’invite `>` avant de continuer.

Collez les commandes d’installation ci-dessous dans cette console R. Ne saisissez pas le `>` lui-même. Utilisez l’application R distincte pour l’installation, et non une tâche Script ou la Console R dans Individual Guide.

Sur macOS, utilisez le téléchargement macOS de CRAN et ouvrez R. Sous Linux, suivez les instructions CRAN pour votre version de Linux. Certains paquets demandent d’autres logiciels système.

## Étape 2 : installer l’application depuis GitHub

L’installation exige Internet. Collez ces commandes dans la console R et appuyez sur Entrée. L’installation peut prendre plusieurs minutes et afficher beaucoup de lignes de progression. Gardez R ouvert et attendez une nouvelle invite `>` avant de continuer.

```r
options(repos = c(CRAN = "https://cloud.r-project.org"))
install.packages("remotes")
remotes::install_github(
  "woodtho/IndividualGuide",
  ref = "v0.6.0",
  dependencies = NA,
  upgrade = "never"
)
```

Cela obtient l’application depuis son étiquette de version GitHub publique et ses ajouts nécessaires depuis CRAN, le service public de paquets. Vous n’avez pas à télécharger le dépôt source ni à trouver un dossier de compilation local. Un compte GitHub n’est habituellement pas nécessaire pour ce téléchargement public.

Si R propose de créer une bibliothèque personnelle de paquets, choisissez Oui. Il s’agit du dossier de vos ajouts installés. Si Windows demande de compiler les paquets depuis les sources alors qu’une version prête à utiliser existe, choisissez Non pour cette dernière. Si l’installation se termine par une erreur, lisez-la avant d’essayer d’ouvrir l’application.

## Étape 3 : ajouter les fonctions nécessaires

L’installation de base comprend les paquets obligatoires. Ces paquets publics supplémentaires servent aux rapports et à certaines analyses. Installez-les une fois pour ces fonctions ou pour explorer tous les exemples :

```r
install.packages(
  c("rmarkdown", "knitr", "survival", "forecast"),
  repos = "https://cloud.r-project.org"
)
```

Pour les rapports Word, installez aussi Pandoc avec son [installateur officiel](https://pandoc.org/installing.html). Fermez et rouvrez R après l’installation. Vérifiez que R le trouve avec :

```r
rmarkdown::pandoc_available()
```

`TRUE` signifie qu’il a été trouvé. Les rapports HTML ont une solution de repli plus simple. Vous pouvez commencer par HTML en réglant la prise en charge de Word.

Ajoutez la prise en charge des bases seulement au besoin. Pour un fichier SQLite, exécutez :

```r
install.packages("RSQLite", repos = "https://cloud.r-project.org")
```

Pour une connexion ODBC, exécutez :

```r
install.packages("odbc", repos = "https://cloud.r-project.org")
```

ODBC peut aussi demander un pilote du fournisseur de la base. Demandez à votre personne-ressource lequel utiliser. Pour du code de connexion personnalisé fiable, demandez à son auteur les paquets supplémentaires nécessaires. Exécutez ces commandes dans l’application R distincte, avec Individual Guide fermé.

## Étape 4 : ouvrir l’application

Dans la console R, exécutez :

```r
IndividualGuide::run_app()
```

L’application s’ouvre dans un navigateur. Gardez la fenêtre R ouverte pendant l’utilisation. Cette session R fait fonctionner l’application. Il est donc normal que sa console soit occupée.

Utilisez les boutons d’ouverture et d’enregistrement de l’application. Les menus Fichier et Session de bureau appartiennent à la version Setup pour Windows et ne sont pas présents ici.

À la fin, enregistrez d’abord le projet. Fermez l’onglet du navigateur, puis arrêtez l’application dans R avec la commande d’arrêt ou Échap, selon votre fenêtre R. Quittez R quand vous n’en avez plus besoin.

## Ouvrir l’application la prochaine fois

Ouvrez R et exécutez seulement `IndividualGuide::run_app()`. Vous n’avez pas à réinstaller les paquets chaque jour. Si le navigateur ne s’ouvre pas seul, utilisez l’adresse locale affichée dans la console R.

Pour mettre à jour plus tard, enregistrez et fermez l’application, ouvrez une nouvelle session R et suivez les instructions de la version voulue. L’étiquette `v0.6.0` choisit volontairement la version de ce guide.

## Si l’installation d’un paquet échoue

Si une tâche facultative nomme un paquet absent, fermez l’application et retournez à R. Utilisez une commande d’installation d’un seul paquet ci-dessus en remplaçant le premier nom entre guillemets par celui de l’erreur. Gardez l’adresse CRAN indiquée.

Vérifiez Internet et copiez la première erreur utile. Un message de bibliothèque système ou de compilateur manquant exige une configuration propre au paquet et au système. Répéter la commande ne le réglera pas. Sous Windows, Setup public est la voie plus simple si vous n’avez pas besoin d’une installation gérée par R.

Ces commandes suivent la [référence officielle d’installation de remotes](https://remotes.r-lib.org/reference/install_github.html). Consultez toujours les notes publiques du projet pour les instructions propres aux versions.
