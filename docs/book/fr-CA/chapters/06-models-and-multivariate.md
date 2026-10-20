# Comparer des groupes et ajuster des modèles {#models}

Un modèle décrit une tendance dans les données. Vous n’avez pas besoin d’écrire du R pour utiliser ces formulaires, mais la méthode doit convenir à votre question. Commencez par un exemple dont la question ressemble à la vôtre.

La **réponse** est le résultat à expliquer ou à prédire. Les **Variables explicatives** sont les colonnes utilisées pour l’expliquer. Un **coefficient** décrit une partie de la relation ajustée. Une **valeur ajustée** est l’estimation du modèle pour une ligne utilisée dans l’ajustement.

Exécutez d’abord l’entrée. Vérifiez les valeurs manquantes et les types de colonnes avant de choisir un modèle. Après l’ajustement, lisez les avertissements et le nombre de lignes utilisées. Vérifiez les données avec des résumés et des graphiques, en plus des résultats du modèle.

Le [répertoire des tâches](#task-finder) indique la catégorie de chaque tâche dans Ajouter une tâche. Dans **Configuration**, choisissez **Table d’entrée** avant les colonnes. Près du haut du panneau, gardez les commandes **Enregistrer** cochées pour les tables voulues. Voyez [Commandes des tâches](#task-controls) si vous ajoutez votre première analyse.

## ANOVA à un facteur {#task-one_way_anova}

Utilisez **ANOVA à un facteur** pour comparer les moyennes d’une réponse numérique entre groupes.

1. Choisissez **Table d’entrée**, puis la mesure dans **Variable réponse (numérique)**.
2. Sélectionnez une **Variable de groupe**. Vérifiez les noms et les effectifs des groupes dans l’entrée.
3. Sélectionnez **Exécuter** et ouvrez **Résultats**. Lisez la table ANOVA et les comparaisons par paires enregistrées, si elles sont activées.

La valeur p de la table ANOVA aide à évaluer les indices que les moyennes ne sont pas toutes égales. Ce test global n’indique pas quelles paires diffèrent. Les comparaisons de Tukey portent sur les paires. Lisez la taille des différences en plus des valeurs p.

La méthode suppose un plan d’étude et des données appropriés. Des mesures répétées sur une même personne, par exemple, exigent plus d’attention que des observations indépendantes. **Croissance des plantes - comparer des groupes expérimentaux** utilise 30 poids de plantes dans trois groupes. Ouvrez cet exemple pour voir ensemble la réponse, le groupe choisi, le résumé et le rapport avant votre propre comparaison.

## Test t {#task-t_test}

Utilisez **Test t** pour comparer deux groupes, des mesures appariées ou une moyenne à zéro.

1. Choisissez **Table d’entrée** et **Variable réponse (numérique)**.
2. Pour deux groupes indépendants, choisissez **Groupe (facultatif — deux catégories)** et désactivez **Mesures appariées**. L’entrée doit contenir exactement les deux groupes à comparer.
3. Pour des paires, activez **Mesures appariées** et choisissez **Deuxième mesure (même ligne)**. Chaque ligne doit contenir une paire correspondante. Laissez le groupe vide.
4. Pour comparer la moyenne d’un échantillon à zéro, laissez le groupe vide et les mesures appariées désactivées. Aucune commande ne permet de choisir une autre valeur de comparaison.
5. Sélectionnez **Exécuter**, puis ouvrez **Résultats**. Lisez la différence de moyennes et son intervalle avec la valeur p.

Vérifiez soigneusement le réglage d’appariement. Pour des données appariées, choisissez la seconde colonne de mesures. Chaque ligne doit contenir une paire, comme les valeurs avant et après d’une même personne. Deux groupes indépendants ne sont pas appariés. Exécutez la tâche et lisez la différence de moyennes, son intervalle et la valeur p ensemble. **Croissance des plantes - comparer des groupes expérimentaux** comprend un exemple de deux groupes dans un sous-ensemble préparé.

## Modèles linéaires {#task-linear_models}

Utilisez **Modèles linéaires** pour expliquer une réponse numérique à l’aide d’un ou de plusieurs prédicteurs, y compris des groupes.

1. Choisissez **Table d’entrée** et la **Variable réponse** numérique.
2. Sélectionnez les **Variables explicatives**. Une colonne dont les valeurs nomment des groupes devrait avoir un type de catégorie. Vérifiez-la d’abord avec Caractériser les données ou Changer le type des colonnes.
3. Sélectionnez **Exécuter**, puis ouvrez **Résultats**. Vérifiez les coefficients, l’ajustement et le nombre d’observations utilisées.

Lisez ensemble les tables de coefficients et d’ajustement. Un coefficient de groupe est habituellement une comparaison à un groupe de référence. Il n’est pas toujours la moyenne brute de ce groupe. L’exemple **Croissance des plantes** place un modèle à côté des comparaisons de groupes. Gardez la description du modèle dans le rapport pour préciser les prédicteurs inclus. Un ajustement terminé ne montre pas à lui seul que le modèle est utile.

## Régression linéaire {#task-linear_regression}

Utilisez **Régression linéaire** pour modéliser une réponse numérique à partir de prédicteurs choisis.

1. Choisissez **Table d’entrée**, puis **Variable réponse** et **Variables explicatives**.
2. Gardez les sorties des coefficients et de l’ajustement du modèle. Sélectionnez **Enregistrer : Valeurs ajustées (augment)** pour obtenir aussi les valeurs ajustées et les résidus par ligne. Un résidu est la valeur observée moins la valeur ajustée.
3. Sélectionnez **Exécuter**, puis ouvrez **Résultats**. Vérifiez les coefficients, l’ajustement, les avertissements et les tables enregistrées.

![Régression linéaire utilise une réponse et des prédicteurs sélectionnés. Les sorties facultatives comprennent les valeurs ajustées et un objet de modèle.](assets/ui-regression.png){#fig-regression}

L’exemple **Modèle de consommation de carburant** utilise 32 voitures et prédit la consommation à partir du poids et de la puissance. Le poids y est exprimé en milliers de livres. Vérifiez ces unités avant d’expliquer un coefficient. Un ajustement à ces observations ne prouve pas que modifier une caractéristique causera le changement prévu. Essayez de retirer un prédicteur dans une copie enregistrée. Comparez le modèle et ses avertissements.

## Régression logistique {#task-logistic_regression}

Utilisez **Régression logistique** pour une réponse ayant deux issues possibles, comme 0 et 1.

1. Choisissez **Table d’entrée**. Dans **Variable réponse (0/1)**, sélectionnez une colonne codée 0 et 1. Confirmez le sens de 1.
2. Choisissez les **Variables explicatives** et gardez les tables de sortie voulues. Activez les valeurs ajustées pour obtenir des résultats par ligne.
3. Sélectionnez **Exécuter**, puis ouvrez **Résultats**. Examinez les coefficients et l’ajustement. Lisez les avertissements avant d’interpréter.

Les probabilités ajustées vont de zéro à un. Les coefficients utilisent une autre échelle. Ce ne sont donc pas des changements directs en points de pourcentage.

**Voitures - modèle à réponse binaire** utilise 1 pour la transmission manuelle et 0 pour l’automatique. Cela aide à vérifier ce que décrit une probabilité. Lisez les avertissements de convergence ou de séparation. Ils peuvent indiquer que le modèle n’estime pas la relation de façon fiable. Un état vert ne justifie pas d’utiliser des estimations extrêmes sans les vérifier.

## Modèles linéaires généralisés {#task-glm}

Utilisez **Modèles linéaires généralisés** si la réponse demande une famille de modèles autre que la régression numérique ordinaire.

1. Choisissez **Table d’entrée**, **Variable réponse** et **Variables explicatives**.
2. Choisissez **Famille du modèle linéaire généralisé** selon un exemple semblable ou un plan d’analyse. Par exemple, **poisson** sert aux effectifs dans l’exemple des ruptures de fils.
3. Sélectionnez **Exécuter**, puis ouvrez **Résultats**. Examinez les avertissements, les coefficients et l’ajustement.

La famille décrit le type de résultat. Le formulaire utilise son lien standard, qui relie les prédicteurs au résultat attendu. Vous ne choisissez pas de lien distinct ici.

**Ruptures de fils - modèle de comptage** utilise un modèle de Poisson pour 54 nombres de ruptures sur des métiers à tisser. Les effectifs sont des nombres entiers d’événements, pas des pourcentages ni des taux. Si le temps d’exposition varie entre les lignes, cet exemple simple peut ne pas convenir. Exécutez la tâche et lisez les avertissements et l’ajustement. Un ajustement réussi ne prouve pas que la famille choisie convient.

## Régression non linéaire {#task-nonlinear_regression}

Utilisez **Régression non linéaire** pour ajuster une des formes de courbe proposées à des mesures numériques.

1. Choisissez **Table d’entrée** et la **Variable réponse (y)** numérique.
2. Choisissez une colonne numérique dans **Variable explicative (x — première sélection utilisée)**, puis une **Courbe prédéfinie**. Commencez par celle d’un exemple semblable.
3. Vérifiez les zéros et les valeurs négatives. Certaines courbes exigent des valeurs positives. La tâche prépare ses propres valeurs de départ.
4. Sélectionnez **Exécuter**, puis ouvrez **Résultats**. Comparez la courbe ajustée aux points observés.

**Puromycine - ajuster une courbe non linéaire** utilise les concentrations et les vitesses de réaction positives d’un sous-ensemble préparé. La courbe de puissance sert d’exemple. Un autre choix de courbe change le modèle. Ce n’est pas un simple bouton de réparation d’un échec. En cas d’échec, vérifiez d’abord les entrées et la forme choisie. Soyez prudent avec les prédictions hors de la plage observée.

## Corrélations {#task-correlations}

Utilisez **Corrélations** pour mesurer comment des paires de colonnes numériques varient ensemble.

1. Choisissez **Table d’entrée** et les **Variables numériques** voulues. Une sélection vide signifie toutes les colonnes numériques, y compris les identifiants numériques. Une sélection précise est souvent plus sûre.
2. Sélectionnez **Exécuter** et ouvrez **Résultats**. La tâche calcule les corrélations de Pearson avec les paires disponibles en présence de valeurs manquantes.
3. Comparez la table aux Nuages de points des paires intéressantes. Une valeur près de 1 ou de -1 montre une forte relation en ligne droite. Une valeur près de zéro n’exclut pas une courbe.

Une corrélation ne montre pas qu’une valeur cause l’autre. Les groupes et les points inhabituels peuvent aussi changer le résultat. **Fleurs - structure multivariée** compare les quatre mesures des iris. Examinez les groupes d’espèces et le résultat global. Vérifiez le nombre d’observations utilisables lorsque les valeurs manquantes font varier les lignes utilisées selon les paires.

## Composantes principales {#task-pca}

Utilisez **Composantes principales** pour réunir plusieurs colonnes numériques en un nombre réduit de directions de résumé. On appelle souvent cette tâche ACP ou PCA.

1. Choisissez **Table d’entrée**. Dans **Variables numériques**, sélectionnez seulement les mesures à réunir. Excluez les identifiants et les codes de groupes.
2. Gardez les sorties voulues près du haut du panneau. Activez **Enregistrer : Scores des composantes (augment)** pour obtenir une valeur de composante par ligne.
3. Sélectionnez **Exécuter**, puis ouvrez **Résultats**. Vérifiez la variance expliquée et les contributions. La tâche met automatiquement les mesures à l’échelle.

La variance expliquée indique la part de dispersion représentée par chaque composante. Les contributions montrent le rôle des colonnes d’origine.

**Fleurs - structure multivariée** utilise les quatre mesures des fleurs et exclut les étiquettes d’espèces de ces entrées. La mise à l’échelle se fait dans l’ACP. Une composante est une direction calculée, pas une nouvelle mesure avec une unité d’origine simple. Explorez les tendances avec ses scores, puis revenez aux colonnes d’origine pour les expliquer.

## Analyse de regroupement {#task-cluster_analysis}

Utilisez **Analyse de regroupement** pour réunir les lignes ayant des mesures numériques semblables.

1. Choisissez **Table d’entrée** et les **Variables numériques** voulues. Standardisez-les d’abord si une échelle commune est nécessaire. Cette tâche ne le fait pas automatiquement.
2. Choisissez **Méthode** et réglez **Groupes** au nombre demandé.
3. Pour **k-means**, réglez **Graine aléatoire** afin de répéter le départ aléatoire avec les mêmes données. Pour **Hiérarchique**, choisissez **Méthode de liaison** selon le plan d’analyse ou l’exemple.
4. Sélectionnez **Exécuter** et ouvrez **Résultats**. Examinez la taille des groupes et les affectations enregistrées.

Exécutez la tâche et examinez les tailles et les affectations. Des groupes très petits ou dominés par une colonne de grande échelle demandent votre attention. **Fleurs - structure multivariée** crée trois groupes. Demander trois groupes ne prouve pas qu’il existe trois groupes naturels. Ils ne correspondent pas forcément aux espèces connues. Comparez les mesures et les graphiques avant de nommer les groupes.
