# Nettoyer et réorganiser les données {#preparing-data}

Gardez une table d’entrée intacte et donnez un nouveau nom à chaque résultat nettoyé. Vous verrez plus facilement ce qui a changé. Après chaque tâche, comparez le nombre de lignes, les noms des colonnes et quelques valeurs.

Avant de commencer, exécutez les tâches qui fournissent les tables d’entrée. Choisissez **Ajouter une tâche**, puis **Données**, pour trouver les tâches de ce chapitre. Le [guide des commandes des tâches](#task-controls) explique où exécuter une tâche et nommer sa sortie.

## Ajouter des tables {#task-append_table}

Utilisez **Ajouter des tables** pour placer les lignes d’une table sous celles d’une autre. Vous pourriez, par exemple, réunir les ventes de janvier et de février.

1. Dans **Tables à combiner**, sélectionnez au moins deux tables.
2. Vérifiez que les colonnes correspondantes ont les mêmes unités et des types compatibles. Utilisez **Remplir les colonnes manquantes avec NA** seulement pour laisser des valeurs manquantes lorsqu’une entrée n’a pas une colonne.
3. Laissez **Colonne d’identifiant de source (.id)** vide ou saisissez un nom pour reconnaître la table d’origine de chaque ligne.
4. Saisissez un nom de table de sortie et cliquez sur **Exécuter**.

Le résultat contient les lignes réunies. Vérifiez son nombre de lignes et les valeurs manquantes créées par l’option de remplissage.

L’ajout réunit des lignes. Il ne fait pas correspondre les renseignements de clients entre tables. Utilisez le Créateur de requêtes pour cela. Ouvrez **Iris - réorganiser et comparer** pour voir deux sous-ensembles d’espèces réunis en 100 lignes.

## Comparer des données {#task-compare_data}

Utilisez **Comparer des données** pour repérer les différences entre deux tables. C’est utile après un nettoyage, l’importation d’une nouvelle copie ou une réorganisation aller-retour.

1. Sélectionnez **Table A (référence)** et **Table B (comparaison)**.
2. Pour trier les tables avant la comparaison, sélectionnez leurs **Colonnes clés** communes. Laissez ce champ vide pour comparer leur ordre actuel.
3. Saisissez un nom de sortie et cliquez sur **Exécuter**.
4. Ouvrez **Résultats** et lisez les différences signalées.

Choisir des clés trie les tables pour les comparer. Cela ne joint pas leurs lignes. Les types et les attributs des colonnes peuvent différer même si les valeurs affichées se ressemblent.

Si les tables n’ont pas le même nombre de lignes, cherchez d’abord pourquoi. Un filtre a peut-être retiré des lignes volontairement. L’exemple **Iris - réorganiser et comparer** compare une table avant et après une réorganisation. Ses notes expliquent les différences attendues.

## Empiler des colonnes {#task-stack_columns}

Utilisez **Empiler des colonnes** pour transformer plusieurs colonnes de mesures en lignes. On dit souvent que les données deviennent longues.

1. Sélectionnez la **Table d’entrée**.
2. Dans **Colonnes à empiler**, sélectionnez les mesures. Laissez les identifiants, comme `flower_id`, non sélectionnés pour qu’ils restent à côté des valeurs empilées.
3. Saisissez les noms de la **Nouvelle colonne des noms** et de la **Nouvelle colonne des valeurs**.
4. Nommez la sortie, cliquez sur **Exécuter** et vérifiez la table longue dans **Résultats**.

Dans **Iris - réorganiser et comparer**, les quatre mesures de chacune des 150 fleurs deviennent 600 lignes. Un identifiant de fleur montre quelles lignes vont ensemble. Gardez cet identifiant pour remettre les mesures en colonnes plus tard. Les lignes supplémentaires sont normales ici. Elles ne représentent pas de nouvelles fleurs.

![Empiler des colonnes conserve les identifiants non sélectionnés et place les mesures choisies dans deux nouvelles colonnes : leurs noms et leurs valeurs.](assets/ui-reshape.png){#fig-reshape}

## Déployer des colonnes {#task-split_columns}

Utilisez **Déployer des colonnes** pour remettre des valeurs de format long dans des colonnes distinctes. On dit souvent que les données deviennent larges. Cette tâche réorganise une table. Vérifiez ses paramètres plutôt que de supposer qu’elle coupe des mots aux virgules.

1. Sélectionnez la **Table d’entrée** et ses **Colonnes d’identifiants (garder en lignes)**.
2. Dans **Noms provenant de**, choisissez la colonne dont les valeurs deviendront les en-têtes.
3. Dans **Valeurs tirées de**, choisissez la colonne de mesures.
4. Nommez la sortie et cliquez sur **Exécuter**. Vérifiez les nouveaux en-têtes et le nombre de lignes dans **Résultats**.

Chaque paire identifiant et nouvelle colonne devrait décrire une seule valeur. Si plusieurs lignes occupent la même place, examinez-les avant de continuer. Il faudra peut-être d’abord les résumer. L’exemple **Iris - réorganiser et comparer** montre un aller-retour complet entre formats long et large avec un identifiant de fleur.

## Transposer {#task-transpose}

Utilisez **Transposer** pour transformer les lignes en colonnes et les colonnes en lignes. Cette tâche est surtout utile pour présenter une petite table autrement.

1. Préparez d’abord une petite entrée. Utilisez **Garder ou supprimer des colonnes** et **Premières ou dernières N lignes** pour créer un sous-ensemble au besoin.
2. Dans Transposer, sélectionnez la **Table d’entrée**.
3. Vous pouvez sélectionner une **Colonne d’identifiant de ligne** pour fournir les nouveaux en-têtes.
4. Nommez la sortie et cliquez sur **Exécuter**. Examinez la nouvelle table et ses en-têtes.

Transposer utilise toute la table choisie. La tâche n’offre pas de sélection distincte des colonnes de mesures. Préparez cette sélection dans une tâche précédente.

Commencez avec quelques lignes. Transposer une grande table peut créer un résultat très large, difficile à voir ou à exporter. Mélanger du texte et des nombres peut aussi changer le stockage des valeurs. L’exemple **Iris - réorganiser et comparer** transpose volontairement un petit sous-ensemble numérique.

## Classer {#task-rank}

Utilisez **Classer** pour ajouter des positions comme première, deuxième et troisième selon les valeurs d’une colonne.

1. Sélectionnez la **Table d’entrée** et la **Colonne à classer**.
2. Pour des positions simples, choisissez **Rang minimal** ou **Rang dense** dans **Méthode**. Il y a égalité lorsque des lignes ont la même valeur. D’autres méthodes donnent des fractions ou départagent selon l’ordre des lignes.
3. Définissez le **Nouveau nom de colonne**. Utilisez **Grouper par** seulement pour recommencer les rangs dans chaque groupe.
4. Nommez la sortie et cliquez sur **Exécuter**.

Le formulaire classe les valeurs en ordre croissant. Il n’a pas de commande distincte pour l’ordre décroissant. Le rang minimal laisse des trous après une égalité; le rang dense n’en laisse pas.

Vérifiez les valeurs les plus hautes et les plus basses, ainsi qu’au moins une égalité. Un rang est une position, pas la mesure d’origine. Gardez la colonne d’origine si elle est nécessaire plus tard. L’exemple **Voitures - classer, mettre à l’échelle et échantillonner** classe la consommation de carburant.

## Standardiser les données {#task-standardize}

Utilisez **Standardiser les données** pour placer des colonnes numériques sur une échelle commune avant une analyse. Par exemple, les plages du poids et de la longueur peuvent être très différentes.

1. Sélectionnez la **Table d’entrée** et les **Colonnes numériques à standardiser**.
2. Choisissez **Score Z** ou **Min-Max** dans **Méthode**.
3. Laissez **Grouper par** vide pour traiter toute la table ou choisissez des groupes à mettre à l’échelle séparément.
4. Nommez la sortie et cliquez sur **Exécuter**.

Le score Z soustrait la moyenne et divise par l’écart-type, une mesure de dispersion. Min-Max ramène la plage observée entre zéro et un. Les deux méthodes changent les unités des colonnes sélectionnées.

Vérifiez la sortie et gardez la table d’origine comme référence. Une colonne constante n’a aucune dispersion et exige une attention particulière pour certaines méthodes. Ouvrez **Voitures - classer, mettre à l’échelle et échantillonner** pour un exemple. La mise à l’échelle dépend de l’analyse suivante. Ce n’est pas une correction à appliquer à toutes les données.

## Échantillon aléatoire {#task-random_sample}

Utilisez **Échantillon aléatoire** pour choisir une partie d’une table sans prendre simplement les premières lignes. Cela aide à essayer un flux sur moins de données.

1. Sélectionnez la **Table d’entrée**.
2. Dans **Échantillonner selon**, choisissez un nombre de lignes ou une proportion, puis saisissez la quantité. Une proportion de 0.1 représente 10 %.
3. Saisissez une **Graine aléatoire** pour répéter le choix avec les mêmes données dans le même ordre.
4. Choisissez si vous voulez **Échantillonner avec remise**, nommez la sortie et cliquez sur **Exécuter**.

Avec remise signifie qu’une même ligne source peut être choisie plusieurs fois. Sans remise, choisissez une quantité qui respecte le nombre de lignes disponibles.

Vérifiez la taille de l’échantillon. Ne traitez pas un petit échantillon d’exercice comme s’il représentait toute la table. L’exemple **Voitures - classer, mettre à l’échelle et échantillonner** choisit dix lignes avec la graine 2026. Essayez une autre graine dans une copie enregistrée et comparez les lignes retenues.

## Supprimer les doublons {#task-remove_dups}

Utilisez **Supprimer les doublons** pour retirer les lignes répétées selon les colonnes choisies.

1. Sélectionnez la **Table d’entrée**.
2. Dans **Portée**, choisissez **Toutes les colonnes (lignes identiques)** ou **Colonnes clés seulement (garder la première ligne par clé)**.
3. Si vous avez choisi les clés, sélectionnez les **Colonnes clés** qui définissent un doublon.
4. Nommez la sortie et cliquez sur **Exécuter**.

L’option des clés garde la première ligne correspondante dans l’ordre actuel. Triez d’abord si ce choix compte. Deux lignes ayant le même numéro de client peuvent décrire des événements différents.

![Supprimer les doublons compare les lignes complètes ou les clés choisies. Choisissez la portée avant de vérifier le nombre de lignes retirées.](assets/ui-cleaning.png){#fig-cleaning}

Comparez le nombre de lignes avant et après. Examinez quelques répétitions en cas de doute. Des lignes peuvent se ressembler tout en décrivant des événements distincts. Ne les retirez pas seulement pour réduire la table. **Voitures - préparer une table d’analyse** ajoute volontairement un doublon : ses 33 lignes deviennent 32 après cette tâche.

## Garder ou supprimer des colonnes {#task-keep_drop_cols}

Utilisez **Garder ou supprimer des colonnes** pour choisir les colonnes qui restent dans une table.

1. Sélectionnez la **Table d’entrée**.
2. Dans **Action**, choisissez Garder ou Retirer.
3. Sélectionnez les **Colonnes**. Garder conserve seulement la sélection; Retirer l’enlève.
4. Donnez un nouveau nom à la sortie et cliquez sur **Exécuter**.

Ouvrez le résultat et vérifiez les noms des colonnes. Gardez un identifiant s’il est nécessaire aux jointures ou aux vérifications. Retirer une colonne de cette sortie ne la retire pas de la table source intacte. Si une tâche suivante signale une colonne absente, vérifiez si cette étape l’a retirée. L’exemple **Voitures - préparer une table d’analyse** montre une table d’analyse réduite.

## Renommer des colonnes {#task-rename_cols}

Utilisez **Renommer des colonnes** pour rendre les en-têtes plus faciles à comprendre.

1. Sélectionnez la **Table d’entrée**.
2. Dans **Paires de renommage**, cliquez sur **Ajouter**.
3. Sélectionnez la colonne et saisissez son nouveau nom. Ajoutez une paire pour chaque autre changement.
4. Nommez la sortie, cliquez sur **Exécuter** et vérifiez les en-têtes dans **Résultats**.

Utilisez des noms uniques. Des noms courts avec des lettres, des chiffres et des traits de soulignement sont faciles à utiliser dans les formules suivantes.

Renommer change l’étiquette, pas les valeurs ni leurs unités. Une colonne de poids ne devient pas des kilogrammes parce qu’on l’appelle `weight_kg`. Ajoutez un calcul pour une vraie conversion. Vérifiez les tâches suivantes après le renommage, car leurs choix de colonnes peuvent aussi devoir changer. **Voitures - préparer une table d’analyse** fournit un exemple à suivre.

## Premières ou dernières N lignes {#task-first_last_n}

Utilisez **Premières ou dernières N lignes** pour garder un nombre donné de lignes à une extrémité de la table.

1. Sélectionnez la **Table d’entrée**.
2. Dans **Lignes à garder**, choisissez Premières ou Dernières.
3. Saisissez le nombre de lignes dans **N**.
4. Nommez la sortie, cliquez sur **Exécuter** et vérifiez le nombre de lignes.

L’ordre actuel de la table détermine les premières et les dernières lignes. Triez d’abord pour obtenir, par exemple, les dix ventes les plus élevées.

Cette tâche sert à une vérification rapide ou à une présentation courte. Elle ne crée pas un échantillon aléatoire. Si les premières lignes viennent toutes de la même date ou du même groupe, elles peuvent mal représenter l’ensemble. Voyez **Voitures - préparer une table d’analyse** pour une petite sélection.

## Remplacer les valeurs manquantes {#task-replace_missing}

Utilisez **Remplacer les valeurs manquantes** lorsque vous avez une raison de remplir des entrées inconnues.

1. Sélectionnez la **Table d’entrée**.
2. Sélectionnez les **Colonnes à remplir**. Une sélection vide signifie toutes les colonnes. Choisissez donc les colonnes précisément pendant votre apprentissage.
3. Dans **Remplir avec**, choisissez la méthode. Saisissez une **Valeur de remplacement** si vous choisissez une valeur fixe.
4. Nommez la sortie et cliquez sur **Exécuter**. Vérifiez les valeurs modifiées et le nombre de valeurs manquantes restantes.

Gardez les données brutes et notez votre méthode. Remplir une case ne retrouve pas la valeur d’origine inconnue. Cela peut changer les résumés et les modèles. **Qualité de l’air - nettoyer et comparer** utilise la moyenne pour enseigner les commandes. C’est un choix d’exercice, pas une recommandation générale. Vous pouvez examiner le bilan des valeurs manquantes avant tout changement.

## Recoder des valeurs {#task-recode_values}

Utilisez **Recoder des valeurs** pour remplacer certaines valeurs par d’autres valeurs ou étiquettes. Par exemple, vous pourriez remplacer 0 et 1 par **Automatique** et **Manuelle** dans une colonne d’affichage.

1. Sélectionnez la **Table d’entrée** et la **Colonne à recoder**.
2. Saisissez un **Nom de la colonne de sortie** pour créer une colonne d’étiquettes distincte.
3. Ajoutez les correspondances entre anciennes et nouvelles valeurs. Vérifiez le réglage Sinon pour les valeurs non indiquées.
4. Nommez la table de sortie et cliquez sur **Exécuter**. Comptez les catégories pour vérifier les changements.

Gardez les codes d’origine si un modèle suivant en a besoin. Un modèle peut attendre des nombres même si un graphique se lit mieux avec des mots. **Voitures - préparer une table d’analyse** montre les étiquettes de transmission et leur lien avec les codes d’origine.

## Changer le type des colonnes {#task-change_types}

Utilisez **Changer le type des colonnes** lorsque les valeurs sont stockées dans un type incorrect. Les types courants sont texte, nombre, date et facteur. Un facteur contient un ensemble de catégories.

1. Sélectionnez la **Table d’entrée**.
2. Dans **Conversions de type**, cliquez sur **Ajouter**.
3. Sélectionnez une **Colonne à convertir** et son **Type cible**. Répétez pour les autres colonnes.
4. Nommez la sortie et cliquez sur **Exécuter**. Vérifiez les types, les valeurs et les nouvelles valeurs manquantes éventuelles.

Le formulaire n’a pas de champ pour un format de date personnalisé. Une date standard comme `2026-10-19` est l’entrée la plus simple. Pour un autre format, préparez les dates avant la conversion ou utilisez un Script fiable.

Gardez les identifiants comme texte si les zéros initiaux comptent. Utilisez des nombres pour les mesures et des catégories pour les groupes. **Voitures - préparer une table d’analyse** change le type d’une catégorie. Si une colonne manque dans un graphique ou une liste de modèle, vérifiez d’abord son type actuel.
