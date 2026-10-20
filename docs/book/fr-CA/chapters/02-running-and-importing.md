# Exécuter les tâches et vérifier les résultats {#running}

Pendant votre apprentissage, commencez par une tâche. Une fois que chaque étape fonctionne, exécutez tout le flux.

## Aperçu, Exécuter et Enregistrer ont des rôles différents

| Action | Son rôle |
| --- | --- |
| Aperçu | Permet d’examiner un résultat d’essai lorsque la tâche le permet |
| Exécuter ou Exécuter et enregistrer | Exécute la tâche et conserve son résultat dans le projet |
| Exécuter le flux | Exécute les tâches reliées du flux actif |
| Enregistrer le projet | Écrit le projet dans son fichier .igpx |

Après un aperçu, utilisez Exécuter pour conserver le résultat. Après l’exécution, enregistrez le projet pour le garder sur disque. Un Script peut écrire des fichiers externes même pendant un aperçu. Prévisualisez seulement du code fiable.

## Vérifier l’état de la tâche

Un état réussi signifie que la tâche s’est terminée. Ouvrez son résultat pour vérifier qu’il répond à votre question. Une erreur demande votre attention. Développez **Journalisation** et lisez les erreurs consignées.

Un résultat périmé signifie qu’une entrée ou un paramètre a changé depuis sa création. Exécutez la tâche touchée, puis les tâches suivantes qui l’utilisent. Un ancien rapport peut encore s’ouvrir en attendant d’être recréé.

Une tâche ignorée peut appartenir à une branche qui n’a pas été choisie. Une tâche en attente peut avoir besoin qu’une tâche précédente se termine. Vérifiez les entrées et les paramètres de branche avant de conclure à un échec.

## Exécuter la bonne partie du projet

Utilisez le bouton de lecture du flux pour exécuter le flux actif. Si le projet en a plusieurs, vérifiez lequel est sélectionné. Faites un clic droit sur une tâche pour choisir **Exécuter jusqu’ici** ou **Exécuter à partir d’ici**, lorsque ces actions sont offertes. Elles suivent les liens entre tâches, et non la position des formes à l’écran.

1. Dans l’application de bureau, choisissez **Tâche > Valider le flux actif...** avant une longue exécution. Dans un navigateur, sélectionnez **Valider le flux actif** en haut de l’application.
2. Lisez les problèmes indiqués. Fermez la fenêtre et corrigez les entrées manquantes ou les paramètres invalides.
3. Validez à nouveau. Quand tout est prêt, choisissez **Tâche > Exécuter le flux actif** ou utilisez le bouton de lecture du flux.

La validation vérifie la configuration. Elle ne prouve pas que les données ou les conclusions sont correctes.

![La validation présente des problèmes ou des renseignements sur les vérifications à venir. Lisez chaque message et corrigez les éléments bloquants avant de continuer.](assets/ui-validation.png){#fig-validation}

## Arrêter une exécution

Utilisez **Arrêter** ou **Tâche > Arrêter l’exécution** dans l’application de bureau. Certains travaux doivent terminer l’étape en cours avant de s’arrêter. Attendez que l’état change avant de lancer une autre exécution.

L’arrêt n’annule pas les fichiers déjà écrits. Vérifiez les dossiers d’exportation avant de relancer. Pour éviter de remplacer des fichiers, choisissez de nouveaux noms ou désactivez le remplacement.

# Importer vos données {#importing}

Pour un premier import, utilisez un petit CSV ou une feuille Excel avec une seule ligne d’en-tête. Donnez un nom à chaque colonne. Gardez les titres, les notes et les totaux en dehors de la zone de données.

## Importer des données {#task-import_data}

Utilisez **Importer des données** pour ajouter un fichier ou une table de base de données au projet.

1. Sélectionnez **Ajouter une tâche > Données > Importer des données**. Dans **Configuration**, choisissez **Fichier** dans **Source**.
2. Sélectionnez **Parcourir...** et choisissez le fichier. L’application détecte son type à partir du fichier sélectionné.
3. Pour un CSV ou un autre fichier texte, vérifiez **Séparateur** et **La première ligne contient les en-têtes**. Un séparateur distingue les colonnes, souvent par une virgule ou une tabulation. Ouvrez **Autres paramètres du fichier** seulement pour changer une option comme l’encodage du texte.
4. Pour Excel, choisissez la feuille et les paramètres de lignes ou de plage affichés après la sélection du fichier.
5. Sélectionnez **Aperçu**. Chaque champ devrait occuper sa propre colonne, avec les bons noms et les bonnes valeurs.
6. Saisissez un **Nom de la table de sortie** clair, comme `sales_raw`, puis sélectionnez **Exécuter l’importation**.

![Importer des données détecte le CSV choisi et propose les réglages du séparateur et des en-têtes. Vérifiez l’aperçu avant d’exécuter l’importation.](assets/ui-import.png){#fig-import}

Ouvrez la nouvelle table et vérifiez son nombre de lignes. Vérifiez les dates, les valeurs manquantes et les identifiants, comme les codes postaux. Si un identifiant commence par zéro, gardez-le comme texte pour conserver ce zéro.

Choisir un autre fichier propose un nouveau nom de sortie tiré de ce fichier. Vérifiez encore **Nom de la table de sortie** avant de relancer un import existant. Les tâches suivantes ont toujours besoin du nom choisi dans leurs paramètres.

Si toutes les valeurs se retrouvent dans une seule colonne, vérifiez le séparateur. Si les noms deviennent la première ligne de données, vérifiez le réglage des en-têtes. Si les lettres semblent incorrectes, essayez l’encodage du fichier. L’exemple **États américains - importer, joindre et filtrer** utilise un vrai CSV fourni avec l’application. Vous pouvez l’examiner sans trouver votre propre fichier.

### Garder les zéros au début d’un identifiant

Utilisez cette méthode si un CSV contient des identifiants comme `001` dont vous devez conserver le texte exact.

1. Sélectionnez le CSV, puis ouvrez **Autres paramètres du fichier**.
2. Dans **col_types**, saisissez un `c` minuscule par colonne, sans espaces ni guillemets. Utilisez `cc` pour deux colonnes ou `cccc` pour quatre. Chaque `c` indique de lire la colonne comme du texte.
3. Regardez l’aperçu et vérifiez que `001` conserve ses zéros. Confirmez le nom de sortie, puis sélectionnez **Exécuter l’importation**.
4. Utilisez ensuite **Changer le type des colonnes** pour convertir les mesures en nombres. Gardez la colonne d’identifiants comme texte.

Utilisez cette option seulement au besoin. Si toutes les colonnes sont lues comme du texte, il faudra convertir les mesures avant de les utiliser dans des graphiques ou des modèles numériques.

## Travailler avec une base de données

Demandez à la personne responsable de la base les détails de connexion et une petite table pour vous exercer. Un **pilote** permet à l’application de se connecter à ce type de base. Un **DSN** est une connexion nommée configurée sur votre ordinateur.

1. Dans **Importer des données > Configuration**, choisissez **Base de données** dans **Source**.
2. Si une **Connexion enregistrée** convient, sélectionnez-la et choisissez **Charger**. Sinon, choisissez **Formulaire** sous **Connexion** et saisissez un **Nom de la connexion** clair.
3. Choisissez le **Pilote** selon les conseils de votre personne-ressource. Pour un fichier SQLite, choisissez **RSQLite::SQLite()** et saisissez son chemin complet dans **Base de données / fichier**. Pour ODBC, choisissez **odbc::odbc()** et utilisez le **DSN** ou les détails fournis.
4. Ouvrez **Autres paramètres de connexion** si vous avez besoin de **Hôte**, **Port** ou **Utilisateur**. Saisissez un mot de passe seulement lorsque l’application le demande pendant la connexion.
5. Saisissez **Table** et **Schéma**, au besoin. Activez **Utiliser une requête SQL** seulement si vous avez une requête appropriée à coller dans **SQL**.
6. Pour une petite copie d’exercice fixe, cochez **Charger immédiatement en mémoire**. Cela charge le résultat et ferme la connexion. Décochez seulement pour conserver une référence active à la base.
7. Définissez **Nom de la table de sortie**, sélectionnez **Aperçu** et vérifiez les colonnes. Sélectionnez **Exécuter l’importation**, puis vérifiez la table enregistrée et son nombre de lignes.

Commencez par une petite table ou requête. Un résultat lié à une base active a toujours besoin de sa connexion lorsque les tâches suivantes l’utilisent. Notez la date d’une copie fixe si cela compte pour le rapport. Un échec de connexion peut venir d’une mauvaise adresse, d’un pilote absent ou d’une restriction du compte. Donnez le message d’erreur exact à votre personne-ressource.

L’application Windows comprend ses paquets habituels. Une installation avec R peut exiger un paquet de base de données et un pilote système distinct. La section [installation facultative avec R](#install-with-r) explique où obtenir les paquets. Ne mettez pas de mots de passe dans un rapport, un message de journal ou un Script partagé.

# Sélectionner, joindre et calculer des données {#queries}

Ces tâches aident à choisir les lignes et les colonnes voulues. Exécutez d’abord la tâche d’entrée pour que les listes de colonnes affichent ses résultats.

## Créateur de requêtes {#task-query_builder}

Utilisez le **Créateur de requêtes** pour choisir des colonnes, joindre des tables, filtrer des lignes ou produire des totaux par groupe dans une seule tâche.

1. Sélectionnez **Ajouter une tâche > Données > Créateur de requêtes**. Dans **Sélectionner les données**, choisissez la **Table d’entrée principale**.
2. Utilisez les boutons plus sous **Colonnes disponibles** pour ajouter des colonnes à **Colonnes sélectionnées**. Utilisez **Tout** pour tout ajouter.
3. Pour ajouter une table, ouvrez **Joindre des tables > Ajouter une jointure**. Choisissez la **Table de droite**, le **Type de jointure** et les colonnes clés correspondantes, puis sélectionnez **Ajouter une jointure** dans la fenêtre.
4. Utilisez **Filtrer les données > Ajouter une condition** pour garder les lignes correspondantes. Utilisez **Trier les données > Ajouter un tri** pour choisir leur ordre.
5. Saisissez un **Nom de la table de sortie**. Sélectionnez **Aperçu (1 000 lignes)** et examinez **Résultats**, puis sélectionnez **Exécuter et enregistrer** pour conserver le résultat complet.

Une jointure associe des lignes grâce à une clé commune, comme un numéro de client. Une jointure gauche garde les lignes de la première table et ajoute les correspondances de la seconde.

![Le Créateur de requêtes sépare la sélection de colonnes, les filtres, le tri et les jointures en onglets. Ajoutez les colonnes voulues à Colonnes sélectionnées avant l’aperçu.](assets/ui-query.png){#fig-query}

Examinez l’aperçu et son nombre de lignes. Si le résultat convient, exécutez la tâche pour le conserver. Si une clé revient plusieurs fois dans les deux tables, la jointure peut produire plus de lignes que prévu. Vérifiez les clés avant de calculer des totaux.

Pour des résultats groupés, réglez le calcul d’une colonne sélectionnée à **SUM** ou **AVG**. AVG signifie moyenne. Les autres colonnes sélectionnées sans calcul définissent les groupes. **Filtrer les données** choisit les lignes d’entrée; **Filtrer les groupes (HAVING)** filtre les résultats calculés par groupe. Commencez par l’exemple **États américains** pour examiner une jointure enregistrée.

## Filtrer et trier {#task-filter_sort}

Utilisez **Filtrer et trier** pour garder les lignes correspondantes et les mettre en ordre.

1. Sélectionnez **Ajouter une tâche > Données > Filtrer et trier**, puis choisissez **Table d’entrée** dans l’en-tête de la tâche.
2. Dans **Filtrer les données**, sélectionnez **Ajouter une condition**. Choisissez la colonne, l’opérateur et la valeur. Par exemple, un montant supérieur à 100 garde les lignes au-dessus de ce montant.
3. Si vous ajoutez des conditions, vérifiez leur choix **ET** ou **OU**. ET exige que les deux règles soient respectées; OU exige au moins une règle.
4. Dans **Trier les données**, sélectionnez **Ajouter un tri**. Choisissez la colonne et le sens du tri. Croissant va du plus petit au plus grand, ou de A à Z. Décroissant inverse cet ordre.
5. Saisissez un **Nom de la table de sortie**, sélectionnez **Exécuter et enregistrer**, puis ouvrez **Résultats**. Vérifiez quelques lignes au début et à la fin.

Les valeurs manquantes demandent une règle distincte. Une valeur manquante est inconnue. Ce n’est ni zéro ni un mot vide. Utilisez **IS NULL** pour choisir les valeurs manquantes ou **IS NOT NULL** pour garder les valeurs connues.

**Note sur la version 0.4.0 :** ouvrir l’étape Filtrer et trier enregistrée dans **États américains - importer, joindre et filtrer** peut déconnecter l’espace de travail. Examinez plutôt sa sortie enregistrée ou ajoutez une nouvelle tâche Filtrer et trier en suivant les étapes ci-dessus. Enregistrez d’abord. Au besoin, suivez les [étapes de redémarrage](#troubleshooting).

## Calculer des colonnes {#task-derive_cols}

Utilisez **Calculer des colonnes** pour ajouter une colonne calculée, comme un total ou une valeur dans une nouvelle unité.

1. Sélectionnez **Ajouter une tâche > Données > Calculer des colonnes** et choisissez **Table d’entrée**.
2. Sélectionnez **Ajouter**. Saisissez le **Nouveau nom de colonne** et l’**Expression R pour la nouvelle colonne**. Par exemple, avec `price` et `quantity`, saisissez `total` et `price * quantity`.
3. Saisissez un **Nom de la table de sortie** et sélectionnez **Exécuter et enregistrer**.
4. Ouvrez **Résultats** et comparez la nouvelle colonne à quelques valeurs calculées vous-même.

Commencez par une colonne. Exécutez la tâche et vérifiez quelques valeurs à la main. Ajoutez ensuite d’autres calculs au besoin. Gardez les unités claires : changer le nom ne convertit pas les centimètres en mètres.

Les formules utilisent des expressions R. Les noms et la ponctuation comptent. En cas de doute, copiez une formule qui fonctionne dans un exemple semblable. L’exemple **Voitures - préparer une table d’analyse** montre un champ calculé. Vous pouvez passer cette tâche jusqu’à ce qu’un calcul nécessaire ne soit pas offert par une tâche plus simple.

# Facultatif : étapes de code enregistrées {#scripts}

## Script {#task-script}

Utilisez **Script** pour exécuter du code R fiable dans un flux. Vous pouvez réaliser de nombreux projets avec les autres formulaires.

1. Sélectionnez **Ajouter une tâche > Général > Script**. Dans **Configuration**, choisissez les **Tables d’entrée / sorties spéciales** nécessaires au code. Ces choix indiquent au flux quels résultats précédents attendre.
2. Collez le code fiable dans **Code R**. L’[exercice du premier projet](#first-project) fournit un exemple complet de deux lignes.
3. Dans **Sorties**, placez chaque résultat sur une ligne sous la forme `name: kind`. Pour une table appelée flowers, saisissez `flowers: table`. Pour un modèle appelé fit, saisissez `fit: model`.
4. Sélectionnez **Exécuter**, puis vérifiez les résultats enregistrés et les entrées sous **Journalisation**.

Exécutez la tâche et vérifiez Résultats et Journal. Si un résultat manque, comparez d’abord son nom déclaré avec le code. Les majuscules comptent : `Flowers` et `flowers` sont différents.

L’exercice du premier projet fournit un Script de deux lignes à copier. Les exemples contiennent aussi des Scripts prêts à utiliser, avec des notes. Lisez ces notes avant de modifier leur code. Utilisez la [Console R](#console) pour un essai rapide, puis gardez le code à répéter dans une tâche Script. Une commande de console seule ne devient pas une étape enregistrée du flux.
