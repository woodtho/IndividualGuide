# Mieux connaître vos données {#describing-data}

Examinez les données avant d’ajuster un modèle. Vérifiez le nombre de lignes, les valeurs manquantes et le type de chaque colonne. Ces tâches aident à repérer les surprises tôt.

Exécutez d’abord la tâche d’entrée. Ces tâches se trouvent dans **Ajouter une tâche > Description**. Les commandes d’analyse et les résultats apparaissent dans le même panneau. La section [commandes des tâches](#task-controls) explique cette disposition commune.

## Caractériser les données {#task-characterize}

Utilisez **Caractériser les données** pour obtenir un aperçu des colonnes d’une table.

1. Sélectionnez la **Table d’entrée**.
2. Définissez le nom de la **Table de sortie** pour conserver le résumé.
3. Cliquez sur **Analyser** ou sur **Exécuter** dans l’en-tête de la tâche.
4. Lisez **Résultats** pour connaître les types de colonnes, les nombres de valeurs et les valeurs manquantes.

Cette tâche décrit toutes les colonnes de son entrée. Elle n’offre pas de sélection de colonnes. Vérifiez que les mesures sont numériques, que les groupes sont des catégories ou du texte et que les colonnes de dates contiennent bien des dates.

C’est une bonne première étape après Importer des données. Si une colonne de nombres est stockée comme texte, cherchez des symboles monétaires ou des mots avant de la convertir. Utilisez Changer le type des colonnes lorsque le sens voulu est clair. L’exemple **Croissance des dents - analyse descriptive** commence par des vérifications qui aident à comprendre les données avant de les résumer.

## Afficher les données {#task-list_data}

Utilisez **Afficher les données** pour parcourir une table dans une vue lisible.

1. Sélectionnez la **Table d’entrée**.
2. Réglez **Lignes par page** pour obtenir une taille d’affichage agréable.
3. Activez la table de sortie et nommez-la pour conserver une copie au besoin.
4. Cliquez sur **Charger** ou sur **Exécuter** dans l’en-tête. Parcourez les pages du résultat.

Lignes par page change la vue, pas le nombre de lignes sources. Ce formulaire n’a pas de sélection de colonnes. Utilisez d’abord Garder ou supprimer des colonnes pour réduire les colonnes affichées.

Une courte liste aide à repérer des catégories mal écrites, des dates inattendues et des valeurs dans les mauvaises unités. Vérifiez le nombre de lignes affiché ou la limite avant de supposer que tout est visible. Gardez la table complète pour les calculs. Voyez **Croissance des dents - analyse descriptive** pour une liste à côté de tâches de résumé. Utilisez Exporter pour livrer un fichier de données plutôt qu’une vue dans le projet.

## Fréquences simples {#task-one_way_freq}

Utilisez **Fréquences simples** pour compter les occurrences de chaque catégorie d’une colonne.

1. Sélectionnez la **Table d’entrée** et la catégorie dans **Variable**.
2. Choisissez **Trier par fréquence** pour afficher les valeurs les plus courantes en premier.
3. Nommez la sortie et cliquez sur **Analyser** ou sur **Exécuter** dans l’en-tête.
4. Vérifiez les effectifs, les pourcentages et leur total dans **Résultats**.

Le formulaire n’a pas de commandes distinctes pour les pourcentages ou les valeurs manquantes. Si une catégorie semble absente, vérifiez les cases vides et l’orthographe dans l’entrée.

![Fréquences simples compte la Variable choisie. Trier par fréquence change l’ordre. Résultats permet de vérifier les effectifs.](assets/ui-frequencies.png){#fig-frequencies}

Un effectif indique le nombre d’observations dans un groupe. Un pourcentage exige aussi un total de référence, comme toutes les lignes ou seulement celles dont la valeur est connue. Vérifiez les lignes incluses avant de publier des pourcentages. **Croissance des dents - analyse descriptive** compte les groupes de suppléments. Vous pouvez aussi compter les espèces d’iris pour vérifier qu’elles ont chacune 50 fleurs.

## Statistiques descriptives {#task-summary_stats}

Utilisez **Statistiques descriptives** pour obtenir la moyenne, la médiane, le minimum, le maximum et la dispersion.

1. Sélectionnez la **Table d’entrée**.
2. Dans **Colonnes numériques**, choisissez les mesures à résumer. Une sélection vide signifie toutes les colonnes numériques.
3. Activez et nommez la **Table de sortie** pour la conserver.
4. Cliquez sur **Analyser** ou sur **Exécuter** dans l’en-tête, puis lisez **Résultats**.

Lisez le nombre de valeurs utilisables et manquantes en plus de la moyenne. Dix valeurs connues et quarante valeurs manquantes ne représentent pas cinquante observations complètes.

Dans **Données**, `n` est le nombre de valeurs connues et `n_miss` le nombre de valeurs manquantes. `sd` signifie écart-type, une mesure de dispersion. Ces vérifications montrent combien d’information soutient une moyenne.

La moyenne est le total divisé par le nombre de valeurs. La médiane est la valeur du milieu après un tri. Quelques valeurs très élevées peuvent éloigner la moyenne de la médiane. Comparer les deux aide à repérer une répartition inégale. **Explorer les iris** donne une vérification simple : la longueur moyenne du sépale est d’environ 5,8433 centimètres. Gardez les unités dans les en-têtes du rapport.

## Tableaux récapitulatifs {#task-summary_tables}

Utilisez **Tableaux récapitulatifs** pour calculer une valeur par groupe, comme les ventes moyennes par région.

1. Sélectionnez la **Table d’entrée** et la **Variable en lignes** qui définit les groupes.
2. Laissez **Variable en colonnes (facultatif)** vide ou choisissez une seconde colonne de regroupement.
3. Choisissez la **Variable des valeurs** numérique et la **Statistique descriptive**.
4. Nommez la sortie et cliquez sur **Analyser** ou sur **Exécuter** dans l’en-tête.

Pour les fleurs, choisissez `Species`, `Petal.Length` et Moyenne. Le résultat contient une moyenne par espèce.

![Tableaux récapitulatifs regroupe une Variable de valeur selon la Variable en ligne. Laissez Variable en colonne vide pour un seul regroupement.](assets/ui-group-summary.png){#fig-group-summary}

Vérifiez le nombre de groupes et leurs étiquettes dans la source. Des groupes avec des mesures manquantes peuvent avoir des nombres différents de valeurs utilisables. Vérifiez l’entrée et faites un résumé des effectifs au besoin. Une table de moyennes ne fournit pas aussi ces nombres. **Explorer les iris** présente trois moyennes d’espèces et **Croissance des dents - analyse descriptive** un autre résumé groupé. Une table groupée peut aussi servir à un rapport ou à un diagramme à barres.

## Analyser un tableau croisé {#task-table_analysis}

Utilisez **Analyser un tableau croisé** pour comparer deux colonnes de catégories dans un tableau croisé. Chaque case compte les lignes qui correspondent à une catégorie de chaque colonne.

1. Sélectionnez la **Table d’entrée**, la **Variable en lignes** et la **Variable en colonnes**.
2. Réglez **Afficher les pourcentages** selon le besoin : aucun, ligne, colonne ou total.
3. Vérifiez les cases et les noms de la table de sortie et de la sortie du khi carré.
4. Cliquez sur **Analyser** ou sur **Exécuter** dans l’en-tête. Lisez les effectifs avant les résultats du test.

Si vous activez le test du khi carré, il cherche des indices d’un lien entre les catégories. Des cases peu remplies ou vides peuvent rendre ce test inadapté. Une **valeur p** aide à évaluer les indices contre l’idée que les catégories sont sans lien. Une petite valeur n’indique pas la taille ni l’utilité du lien. **Croissance des dents - analyse descriptive** croise le supplément et la dose. Cela montre la répartition des observations entre les groupes de l’étude.

## Analyser une distribution {#task-distribution}

Utilisez **Analyser une distribution** pour examiner la répartition des valeurs d’une colonne numérique.

1. Sélectionnez la **Table d’entrée** et la **Variable** numérique.
2. Réglez **Classes**, le nombre de plages de l’histogramme.
3. Choisissez **Densité** ou **Graphique quantile-quantile** pour ces vues et vérifiez les dimensions du graphique.
4. Cliquez sur **Analyser** ou sur **Exécuter** dans l’en-tête. Examinez **Résultats**, **Graphique** et **Données**.

Cherchez une longue queue, plusieurs sommets, des valeurs extrêmes et des valeurs manquantes. Une longue queue signifie que quelques valeurs s’étendent loin de la majorité. La vue Q-Q compare la répartition observée à une référence normale, en forme de cloche.

Servez-vous de ces observations pour choisir la prochaine question. Ne supprimez pas une grande valeur seulement parce qu’elle est inhabituelle. Vérifiez s’il s’agit d’une erreur ou d’une vraie observation. **Croissance des dents - analyse descriptive** place cette tâche à côté d’effectifs et de résumés groupés. Ensemble, ces vues aident à comprendre les mesures et leurs groupes.
