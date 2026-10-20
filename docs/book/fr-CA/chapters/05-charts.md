# Créer des graphiques faciles à lire {#charts}

Choisissez le graphique selon votre question. Commencez par des paramètres simples. Ajoutez ensuite un titre clair, des étiquettes d’axes et des unités.

Le paramètre **X** contrôle habituellement l’axe horizontal. **Y** contrôle l’axe vertical. Le groupe ou la couleur distingue les catégories. Après l’exécution, vérifiez le graphique et le nombre de lignes utilisées.

Avant de suivre une tâche ci-dessous, exécutez celle qui crée sa table d’entrée. Ajoutez les graphiques avec **Ajouter une tâche > Graphiques**, puis ouvrez **Configuration**. Donnez un nom unique à chaque sortie voulue. La section [commandes des tâches](#task-controls) explique comment garder les résultats pour les étapes suivantes.

## Conserver la sortie voulue

Les tâches de graphiques peuvent offrir les données tracées, un graphique interactif et une image statique. Un graphique interactif peut montrer des détails au survol. Une image statique est un graphique fixe adapté aux rapports Word et aux exportations d’images.

Activez la sortie d’image statique pour exporter un PNG. Utilisez ensuite une tâche **Exporter** pour écrire le fichier. Créer un graphique dans le projet ne place pas automatiquement une image dans votre dossier.

Certaines vues et sorties de données graphiques n’affichent que les 1 000 premières lignes. Vérifiez la limite de la tâche avant de traiter une sortie comme la table source complète. Préparez volontairement un résumé ou un échantillon si les points sont trop nombreux pour être lisibles.

## Diagramme à barres {#task-bar_chart}

Utilisez **Diagramme à barres** pour comparer des effectifs par catégorie ou un résumé numérique choisi.

1. Choisissez **Table d’entrée**, puis la catégorie dans **Catégorie / X**.
2. Laissez **Valeur (facultatif)** vide pour compter les lignes. Pour tracer une valeur numérique existante, sélectionnez cette colonne. Pour une moyenne ou un autre calcul groupé, créez d’abord la table récapitulative. Le formulaire n’offre pas de choix de méthode de résumé.
3. Ajoutez **Groupe / couleur** seulement si cela aide. Définissez **Titre** et **Libellé de l’axe Y** pour expliquer la hauteur des barres.
4. Sélectionnez **Exécuter**, puis ouvrez **Résultats > Graphique**. Comparez les barres aux effectifs sources ou à la table récapitulative.

![Laisser Valeur vide fait compter les observations au Diagramme à barres. Choisissez Species dans Catégorie / X pour comparer les trois groupes de fleurs.](assets/ui-bar-chart.png){#fig-bar-chart}

Gardez les catégories lisibles. Si les étiquettes se chevauchent, réduisez leur nombre ou changez la disposition. **Fleurs - galerie de graphiques par catégorie** compte les trois espèces. Chaque barre devrait représenter 50 fleurs. Comparez avec la table de fréquences en cas de doute sur ce qui est compté.

## Diagramme à barres et à courbe {#task-bar_line_chart}

Utilisez **Diagramme à barres et à courbe** pour montrer des barres et une ligne sur un même axe de catégories ou de temps.

1. Choisissez **Table d’entrée**. Réglez **X / catégorie / date** à la colonne commune de catégories ou de temps.
2. Choisissez **Y / valeur**. Les barres et la ligne utilisent cette mesure, sauf si vous sélectionnez aussi **Y secondaire (facultatif)** pour la seconde série.
3. Si vous utilisez une seconde série, remplissez **Libellé de l’axe Y secondaire**. Ajoutez un **Titre** clair et les étiquettes des axes.
4. Sélectionnez **Exécuter**, puis ouvrez **Résultats > Graphique**. Vérifiez la mesure représentée par chaque axe et chaque série.

Si les deux valeurs ont des unités ou des échelles différentes, expliquez-les. Des hauteurs semblables sur deux axes ne signifient pas des valeurs égales. Évitez de suggérer un lien seulement parce que les formes se ressemblent. **Températures de Nottingham - graphiques temporels** compare les moyennes annuelles aux étendues observées. L’étendue est une différence entre valeurs observées, pas une mesure de l’incertitude de la moyenne.

## Boîte à moustaches {#task-box_plot}

Utilisez **Boîte à moustaches** pour comparer la dispersion d’une mesure numérique entre groupes.

1. Choisissez **Table d’entrée** et la colonne de regroupement dans **X / catégorie / date**.
2. Sélectionnez la mesure dans **Valeur numérique**. Ajoutez **Groupe de remplissage** seulement au besoin.
3. Sélectionnez **Exécuter**, puis ouvrez **Résultats > Graphique**. Vérifiez les étiquettes des groupes et les unités.

La ligne dans la boîte indique la médiane, la valeur du milieu. La boîte couvre la moitié centrale des données. Les points au-delà des moustaches signalent des valeurs à regarder de plus près.

Lisez le graphique avec les effectifs des groupes. Un petit groupe fournit moins d’information qu’un grand, même si les boîtes se ressemblent. Vérifiez les points inhabituels avant de conclure à des erreurs. **Fleurs - galerie de graphiques par catégorie** compare les mesures par espèce. Utilisez Tableaux récapitulatifs pour obtenir aussi les valeurs exactes dans un rapport.

## Diagramme à bulles {#task-bubble_plot}

Utilisez **Diagramme à bulles** pour montrer deux mesures numériques, avec la taille des bulles pour une troisième.

1. Choisissez **Table d’entrée**. Sélectionnez deux colonnes numériques dans **X / catégorie / date** et **Y / valeur**.
2. Choisissez une troisième colonne numérique dans **Taille / poids**. Ajoutez **Groupe / couleur** si c’est utile.
3. Sélectionnez **Exécuter** et ouvrez **Résultats > Graphique**. Vérifiez que la légende des tailles explique les grosses bulles. Indiquez les unités des trois mesures.

Les bulles peuvent en cacher de plus petites. Essayez moins de données ou un Nuage de points si la vue est difficile à lire. Utilisez cette tâche lorsque la taille doit varier visiblement. Un champ Taille partagé avec d’autres graphiques peut ne pas avoir cet effet dans Nuage de points. **Fleurs - galerie de graphiques numériques** permet de comparer les deux graphiques avec les mêmes observations.

## Graphique de contours {#task-contour_plot}

Utilisez **Graphique de contours** pour voir où se concentrent les paires de valeurs numériques.

1. Choisissez **Table d’entrée** et deux colonnes numériques dans **X / catégorie / date** et **Y / valeur**.
2. Définissez **Titre** et les étiquettes d’axes pour nommer les mesures et leurs unités.
3. Sélectionnez **Exécuter**, puis ouvrez **Résultats > Graphique**. Les contours indiquent où se trouvent davantage d’observations. Comparez-les à un Nuage de points des mêmes colonnes.

La forme lissée dépend des données et des paramètres. Elle ne trace pas une frontière mesurée autour d’un groupe réel. Un petit échantillon peut donner une apparence trop certaine. **Fleurs - galerie de graphiques numériques** présente les contours à côté des points individuels. Cela aide à voir ce que le lissage ajoute et laisse de côté.

## Histogramme {#task-histogram_graph}

Utilisez **Histogramme** pour montrer la répartition d’une mesure numérique.

1. Choisissez **Table d’entrée**, puis la mesure dans **Colonne numérique**.
2. Réglez **Classes**, le nombre de plages à compter ensemble. Commencez par la valeur par défaut en cas de doute. Laissez **Superposer la densité (échelle de densité)** désactivé pour un graphique d’effectifs.
3. Sélectionnez **Exécuter**, puis ouvrez **Résultats > Graphique**. Vérifiez l’axe horizontal et les effectifs. Examinez l’entrée ou la tâche Caractériser les données pour les valeurs manquantes.

Essayez quelques nombres de classes raisonnables. Des classes très larges cachent des motifs. Des classes très étroites peuvent faire paraître importante une variation aléatoire. Les barres d’un histogramme représentent des plages numériques. Un Diagramme à barres représente habituellement des catégories distinctes. **Fleurs - galerie de graphiques numériques** comprend un histogramme à comparer aux Statistiques descriptives. Utilisez les deux pour voir la dispersion et les valeurs exactes.

## Graphique à courbes {#task-line_plot}

Utilisez **Graphique à courbes** pour montrer le changement selon une colonne ordonnée, souvent le temps.

1. Choisissez **Table d’entrée**. Sélectionnez la date ou la colonne ordonnée dans **X / catégorie / date** et une mesure dans **Y / valeur**.
2. Ajoutez **Groupe / couleur** pour des lignes distinctes. Laissez **Y secondaire (facultatif)** vide pour une seule mesure.
3. Vérifiez l’ordre de la source et les dates répétées. Pour un total ou une moyenne par période, préparez d’abord une table récapitulative.
4. Sélectionnez **Exécuter**, puis ouvrez **Résultats > Graphique**. Vérifiez la période couverte et les trous.

Une ligne relie des observations. Elle ne prouve pas ce qui s’est passé entre elles et ne constitue pas une prévision. Vérifiez les trous et la période pour rendre les données absentes visibles. **Températures de Nottingham - graphiques temporels** montre 240 observations mensuelles. Lisez la colonne de dates et les unités avant de comparer des années ou de décrire une tendance saisonnière.

## Diagramme circulaire {#task-pie_chart}

Utilisez **Diagramme circulaire** pour présenter simplement la part de chaque catégorie lorsqu’il y a peu de groupes.

1. Choisissez **Table d’entrée**, puis la colonne de catégories dans **Catégorie des secteurs**.
2. Laissez **Diagramme en anneau** désactivé pour un disque plein ou activez-le pour un anneau avec les mêmes effectifs.
3. Sélectionnez **Exécuter**, puis ouvrez **Résultats > Graphique**. Comparez l’effectif et la part de chaque catégorie à une table de fréquences.

Les secteurs comptent les observations par catégorie. Une colonne de montants numériques ne fournit pas le poids des secteurs.

Confirmez les totaux dans une table de fréquences. De nombreux petits secteurs sont difficiles à comparer. Un Diagramme à barres peut être plus lisible pour plusieurs groupes. **Fleurs - galerie de graphiques par catégorie** utilise les trois espèces d’iris. Les secteurs devraient être égaux, car chaque espèce a 50 observations. Changer la couleur modifie la vue, pas les effectifs.

## Nuage de points {#task-scatter_plot}

Utilisez **Nuage de points** pour examiner le lien entre deux colonnes numériques.

1. Choisissez **Table d’entrée**, puis des colonnes numériques dans **X / catégorie / date** et **Y / valeur**.
2. Ajoutez **Groupe / couleur** si c’est utile. Définissez **Titre**, **Libellé de l’axe X** et **Libellé de l’axe Y** avec les unités.
3. Sélectionnez **Exécuter** et ouvrez **Résultats > Graphique**. Vérifiez les axes et les unités. Chaque point visible représente une observation, mais des points peuvent se chevaucher.

Cherchez une tendance, une courbe, des groupes séparés et des points inhabituels. Une tendance visible ne prouve pas qu’une mesure cause l’autre. Utilisez Diagramme à bulles si une troisième mesure doit contrôler la taille des points. **Explorer les iris** compare les longueurs du sépale et du pétale selon l’espèce. Essayez la largeur du pétale pour Y dans une copie, puis relancez le rapport pour y voir le nouveau graphique.

## Matrice de nuages de points {#task-scatter_matrix}

Utilisez **Matrice de nuages de points** pour comparer plusieurs colonnes numériques dans une grille.

1. Choisissez **Table d’entrée**, puis trois ou quatre **Colonnes numériques**.
2. Réglez **Affichage de la matrice** à **Nuages de points par paires**. Choisissez plutôt **Distributions** pour un histogramme distinct de chaque colonne.
3. Sélectionnez **Exécuter** et ouvrez **Résultats > Graphique**. Dans la vue par paires, lisez les étiquettes de ligne et de colonne de chaque panneau pour reconnaître ses mesures.

Commencez par trois ou quatre colonnes. Une grande grille devient difficile à lire. Les limites d’affichage peuvent montrer seulement une partie des grandes tables. Si une paire vous intéresse, ouvrez un Nuage de points distinct pour mieux la voir. **Fleurs - galerie de graphiques numériques** compare les quatre mesures des iris. Utilisez la matrice pour choisir un lien à examiner plutôt que d’expliquer tous les panneaux à la fois.
