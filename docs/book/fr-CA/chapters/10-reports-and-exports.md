# Partager des rapports et des fichiers {#reports-and-exports}

Choisissez selon les besoins du lecteur. Envoyez un rapport à lire, un CSV pour travailler sur les données ou un projet pour modifier le flux. Vous pouvez en envoyer plusieurs si chacun a un rôle clair.

## Rapport {#task-report}

Utilisez **Rapport** pour réunir des tables, des graphiques et des notes dans un document HTML ou Word.

Exécutez d’abord les tâches qui fournissent les résultats. Pour un graphique dans Word, gardez sa sortie d’image statique activée et relancez le graphique au besoin.

1. Ajoutez Rapport depuis Sortie.
2. Dans **Contenu**, utilisez le bouton plus à côté d’un résultat dans **Sorties disponibles**. Vérifiez qu’il apparaît dans **Contenu du rapport**. Ajoutez les éléments dans l’ordre de lecture voulu.
3. Pour chacun, remplissez **Titre de section** et **Note**. Expliquez la source, les unités et les choix importants. Laissez **Style de rendu** à Auto sauf si une vue précise est nécessaire.
4. Dans **Apparence**, choisissez HTML ou Word dans **Format de sortie** et saisissez **Titre du rapport**.
5. Activez **Inclure le journal du flux dans le rapport** pour ajouter une section de journal d’exécution.
6. Sélectionnez **Générer le rapport**. À la fin, sélectionnez **Télécharger le fichier HTML** ou **Télécharger le DOCX**. Enregistrez le document et ouvrez-le hors de l’application.

![Ajoutez les sorties de gauche pour construire le Contenu du rapport à droite. Chaque élément peut avoir son titre, sa note et son style de rendu.](assets/ui-report-content.png){#fig-report-content}

Vérifiez le document lui-même avant de le partager. Un résultat absent peut produire un avertissement et une section incomplète. Exécutez sa source, puis recréez le rapport. **Explorer les iris** réunit des tables et un graphique. **Voitures - rapport avec trace d’exécution** met l’accent sur les journaux.

## Choisir HTML ou Word

HTML s’ouvre dans un navigateur. C’est un bon premier choix qui peut inclure des tables interactives si elles sont prises en charge. Téléchargez le fichier et vérifiez-le hors de l’application en cours.

Word produit un fichier .docx modifiable dans un traitement de texte compatible. Utilisez des graphiques et des tables statiques. Une page Word ne conserve pas les commandes de survol du navigateur. Si le graphique manque, activez sa sortie d’image statique, exécutez-le et sélectionnez cette sortie dans le rapport.

Le programme d’installation Windows comprend les outils habituels de rapports. Une installation avec R demande des paquets de rapports supplémentaires et Pandoc pour Word. Voyez [Facultatif : installer avec R](#install-with-r) si vous utilisez cette méthode.

## Choisir un style de contenu

Commencez par **Auto**. Ce choix adapte la vue au résultat réel. Utilisez un style de table pour une table et un style de figure pour un graphique statique. Le style d’impression affiche le texte d’un objet si c’est ce qu’il vous faut.

Donnez assez de contexte pour comprendre le résultat. Par exemple, **Longueur moyenne des pétales par espèce, 150 fleurs, mesures en centimètres** est plus utile que **Sortie 2**. Si les données ou le graphique changent, relancez Rapport. Un document déjà enregistré ne se met pas à jour seul.

## Exporter {#task-export}

Utilisez **Exporter** pour écrire une table, un graphique ou un objet pris en charge dans un fichier externe.

Avant de commencer, exécutez la tâche qui crée le résultat à exporter.

1. Sélectionnez **Ajouter une tâche > Sortie > Exporter**. Dans **Configuration**, choisissez **Sortie à exporter**, puis un **Format** compatible.
2. Sélectionnez **Choisir un dossier…** et une destination facile à retrouver.
3. Dans **Nom du fichier (sans extension)**, saisissez un nom comme `species-summary`. Vérifiez l’adresse complète affichée : l’application ajoute l’extension du format.
4. Pour une image, vérifiez les dimensions et **DPI**. Cochez **Remplacer le fichier s’il existe déjà** seulement si vous voulez remplacer ce fichier.
5. Sélectionnez **Exporter**. Ouvrez le fichier produit dans le dossier choisi et vérifiez son contenu.

![Exporter sépare le dossier de destination du nom du fichier. Vérifiez l’adresse complète avant d’écrire ou de remplacer un fichier.](assets/ui-export.png){#fig-export}

Commencez par CSV pour les données et PNG pour un graphique fixe. La source doit avoir le bon type : exporter les données d’un graphique en CSV diffère de l’exportation de son image statique en PNG.

Vérifiez le remplacement avant de relancer. L’ajout est offert pour CSV et TSV lorsque c’est pris en charge. Il ajoute des lignes à un fichier existant, mais ne sert pas généralement à ajouter une feuille Excel. Exporter écrit un fichier sans créer de table pour les tâches suivantes. Le résultat d’origine reste leur source.

## Choisir un format d’exportation

| Besoin | Choix utile | À vérifier |
| --- | --- | --- |
| Données pour de nombreuses applications | CSV ou TSV | Dates, identifiants texte et valeurs manquantes après ouverture |
| Une feuille de calcul | XLSX | Types de colonnes et limites du tableur destinataire |
| Un graphique fixe | PNG | Étiquettes lisibles, dimensions et résolution |
| Un graphique redimensionnable | PDF ou SVG, si offert | Ouverture dans l’application destinataire |
| Des données typées pour des outils compatibles | Parquet ou Feather | Prise en charge par l’outil destinataire |
| Des données structurées pour un programme | JSON | Format attendu par le programme |
| Un résultat R pour un autre utilisateur de R | RDS ou RData | Versions de R et paquets du destinataire |

Vous n’avez pas à apprendre tous les formats. Choisissez celui que le lecteur ou l’outil suivant peut utiliser. Si les zéros initiaux disparaissent dans un tableur, importez-y la colonne d’identifiants comme texte. Si un CSV s’ouvre dans une seule colonne, utilisez l’importation texte/CSV du tableur et choisissez la virgule comme séparateur.

## Vérifier une livraison terminée

Enregistrez le projet. Ouvrez les rapports et les données exportés hors de l’application. Vérifiez les titres, les unités, les nombres de lignes, les graphiques et les dates du journal. Assurez-vous d’envoyer les derniers fichiers du dossier réellement choisi.

Pour prouver que le rapport s’est terminé, joignez un journal final créé par Exporter le journal après Rapport. Ses événements sont plus récents que la copie incluse dans le rapport.
