# Vérifier les tendances et travailler avec le temps {#diagnostics-and-time}

Ces tâches répondent à des questions plus précises. Lisez d’abord l’exemple correspondant et gardez clairs le sens et l’ordre des données.

Exécutez d’abord la tâche d’entrée. Trouvez la catégorie de chaque analyse dans le [répertoire des tâches](#task-finder), ajoutez-la, puis choisissez **Table d’entrée** dans **Configuration**. Gardez les sorties activées pour les résultats nécessaires plus tard.

## Fonctions de répartition {#task-cdf_plots}

Utilisez **Fonctions de répartition** pour voir la part d’observations inférieures ou égales à une valeur. CDF est le sigle anglais de fonction de répartition cumulative.

1. Choisissez **Table d’entrée** et la mesure dans **Variable numérique**.
2. Ajoutez **Groupe / couleur (facultatif)** seulement pour des courbes par groupe.
3. Sélectionnez **Exécuter**, puis ouvrez **Résultats** et examinez le graphique. Choisissez une valeur sur l’axe horizontal et lisez sa part sur l’axe vertical. Une part de 0,75 signifie qu’environ 75 % des observations sont inférieures ou égales à cette valeur.

Cette vue aide à comparer des seuils sans choisir de classes d’histogramme. Vérifiez les unités et les valeurs manquantes. Elle décrit les données fournies et ne garantit pas les mesures futures. **Débit du Nil - distribution et stabilité** présente ce graphique avec un graphique de probabilité et une carte de contrôle. Vous pouvez comparer plusieurs vues des mêmes 100 observations annuelles.

## Graphiques de probabilité {#task-probability_plots}

Utilisez **Graphiques de probabilité** pour comparer une colonne numérique à une distribution normale, une forme courante de cloche.

1. Choisissez **Table d’entrée**, puis la mesure dans **Variable numérique**.
2. Gardez la sortie graphique activée. Cette tâche utilise une référence normale. Il n’y a pas de choix de distribution de référence.
3. Sélectionnez **Exécuter**, puis ouvrez **Résultats** et examinez le graphique. Des points près de la ligne suggèrent une répartition semblable. Des courbes et des points éloignés suggèrent des différences, surtout aux extrêmes.

Ce graphique est une vérification, pas un certificat de réussite pour toutes les analyses suivantes. Lisez-le avec un histogramme et le contexte de l’étude. Ne retirez pas des observations seulement pour aligner les points. **Débit du Nil - distribution et stabilité** fournit un graphique de probabilité normale prêt à examiner. Apprenez le lien entre la ligne et les points avant d’interpréter vos propres données.

## Cartes de contrôle {#task-control_charts}

Utilisez **Cartes de contrôle** pour examiner des mesures dans leur ordre d’observation et signaler des motifs inhabituels.

1. Triez l’entrée selon l’ordre des observations avant d’ajouter la tâche. Choisissez **Table d’entrée** et **Mesure**.
2. Laissez **Sous-groupe** vide pour une carte individuelle. Choisissez un sous-groupe seulement si les lignes forment des sous-groupes pertinents pour une carte Xbar des moyennes.
3. Cochez **Règles de séquence Western Electric** si ces vérifications supplémentaires conviennent. Elles repèrent certaines suites de points, pas seulement des points extrêmes isolés.
4. Sélectionnez **Exécuter**, puis ouvrez **Résultats**. Examinez le graphique et la table des points avec leurs limites et leurs indicateurs.

![Cartes de contrôle utilise l’ordre des lignes de l’entrée. Sous-groupe vide choisit une carte individuelle; les règles de séquence ajoutent des vérifications de motifs.](assets/ui-control-chart.png){#fig-control-chart}

L’application estime les limites à partir des données. Ces limites diffèrent d’une cible externe ou d’une tolérance fixée par un client. Un point dans les limites ne prouve pas qu’il respecte une exigence du produit. **Débit du Nil - distribution et stabilité** utilise une carte individuelle pour l’exercice. Les observations d’un fleuve servent à l’apprentissage, pas à représenter une usine contrôlée. Lisez les notes avant de reprendre les paramètres pour un autre usage.

## ARIMA et prévisions de base {#task-arima_forecast}

Utilisez **ARIMA et prévisions de base** pour estimer des valeurs futures à partir d’une série numérique ordonnée.

1. Préparez une valeur numérique par intervalle régulier, comme un mois. Triez la table dans l’ordre du temps. Il faut au moins huit valeurs et aucune valeur manquante dans la série.
2. Choisissez **Table d’entrée**, puis **Valeur de la série (lignes en ordre chronologique)**.
3. Réglez **Horizon de prévision (nombre de périodes)**. Saisissez 12 pour douze intervalles futurs.
4. Sélectionnez **Exécuter**, puis ouvrez **Résultats**. Examinez le modèle ajusté, les prévisions et les intervalles.

![Le formulaire de prévision utilise une colonne de valeurs ordonnées et un horizon en pas. Il ne déduit pas l’intervalle du calendrier à partir d’une colonne de dates.](assets/ui-forecast.png){#fig-forecast}

**Passagers aériens - prévoir une série mensuelle** part de 144 valeurs mensuelles et prévoit 12 pas de plus. La tâche ne transforme pas automatiquement toute table datée en modèle saisonnier optimisé. Vérifiez les paramètres et le modèle. Les intervalles montrent l’incertitude du modèle sans promettre que les événements futurs y resteront. Gardez les périodes claires dans le rapport.

# Le temps avant un événement {#survival-analysis}

Les tâches de survie utilisent une colonne de temps et un indicateur d’événement. Il peut s’agir d’une panne, d’une réparation ou d’une autre issue. Une observation censurée signifie que l’événement n’a pas été observé avant la fin de son suivi.

Pour un indicateur numérique, vérifiez que **1 signifie que l’événement a eu lieu** et que **0 signifie qu’il n’a pas été observé pendant le suivi**. Convertissez d’abord les autres codes numériques. Pour du texte ou des catégories, utilisez **Niveau de l’événement** pour indiquer la valeur qui représente l’événement. L’exemple prépare des codes 0/1 et explique ce changement dans sa tâche de préparation.

## Tables de survie {#task-life_tables}

Utilisez **Tables de survie** pour estimer comment la chance de rester sans événement évolue avec le temps.

1. Choisissez la **Table d’entrée** préparée. Sélectionnez **Délai avant l’événement** et **Indicateur d’événement (1 = événement, 0 = censuré)**.
2. Pour un indicateur texte ou de catégorie, définissez précisément **Niveau de l’événement**. Pour un indicateur numérique 0/1, gardez ce codage.
3. Ajoutez une colonne **Strates** pour des courbes distinctes. Seule la première colonne sélectionnée est utilisée.
4. Sélectionnez **Exécuter**, puis ouvrez **Résultats**. Vérifiez le nombre de lignes utilisables et d’événements. Confirmez l’unité de temps et l’absence de valeurs négatives inexpliquées.

![Tables de survie distingue le temps de suivi, le codage de l’événement et les strates facultatives. Vérifiez la colonne d’événement préparée avant de lire les courbes.](assets/ui-survival.png){#fig-survival width=14.5cm}

**Cancer du poumon - analyse de survie** garde les 228 lignes d’origine et prépare une entrée distincte pour l’analyse. Son code d’événement d’origine 2 devient 1. Ouvrez la tâche de préparation avant de lire la courbe. Cet exemple enseigne les commandes et la vérification des codes. Il ne guide pas les décisions de soins. Demandez des conseils d’analyse appropriés avant d’utiliser ces méthodes pour des décisions importantes.

## Risques proportionnels {#task-proportional_hazards}

Utilisez **Risques proportionnels** pour modéliser le lien entre des prédicteurs et le taux d’apparition d’un événement au fil du temps. On parle souvent de modèle de Cox.

1. Choisissez la **Table d’entrée** préparée, **Délai avant l’événement** et **Indicateur d’événement (1 = événement, 0 = censuré)**.
2. Sélectionnez les prédicteurs dans **Covariables**. Définissez **Niveau de l’événement** si la colonne est du texte ou une catégorie.
3. Vérifiez les valeurs manquantes et le codage, puis sélectionnez **Exécuter**.
4. Ouvrez **Résultats**. Lisez ensemble les coefficients, les intervalles, les avertissements et le nombre d’observations incluses.

**Cancer du poumon - analyse de survie** comprend un modèle d’illustration. Un rapport de risques compare des taux d’événements ajustés. Ce n’est pas la probabilité absolue d’événement d’une personne. Utilisez l’exemple pour apprendre les commandes. Demandez des conseils sur la méthode avant de vous fier aux hypothèses du modèle.
