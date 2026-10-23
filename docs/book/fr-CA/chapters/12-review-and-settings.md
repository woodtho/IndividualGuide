# Expliquer et réviser le travail {#review}

Un projet utile explique à une autre personne ce que vous avez fait et pourquoi. Quelques notes claires peuvent faire gagner beaucoup plus de temps qu’une longue suite de noms de tâches sans explication.

## Ajouter des notes aux points de décision

Utilisez les notes de tâches ou les commentaires du projet pour expliquer les choix. Notez pourquoi vous avez retiré des lignes, rempli des valeurs manquantes, choisi un modèle ou fixé un seuil. Écrivez pour une personne qui découvre le projet.

1. Faites un clic droit sur une tâche dans le flux. Saisissez une **Note (affichée dans l’infobulle du nœud)**, puis sélectionnez **Enregistrer la note**. Pointez ensuite la tâche pour la lire.
2. Pour une discussion plus longue, choisissez **Affichage > Commentaires...** dans l’application de bureau ou le bouton **Commentaires** dans le navigateur.
3. Choisissez **Joindre à**, saisissez un titre facultatif et votre commentaire. Sélectionnez **Commentaire** pour le conserver ou **Signaler un problème** s’il demande une révision.
4. Enregistrez le projet pour y conserver les notes.

Par exemple : **Nous avons gardé les commandes de janvier à mars et exclu les commandes annulées.** Cela explique davantage que **Filtre mis à jour**.

## Vérifier avant de partager

1. Choisissez **Affichage > Tableau de révision...** dans l’application de bureau ou la commande de révision dans le navigateur. Vérifiez les problèmes ouverts avant de déclarer le travail prêt à réviser.
2. Choisissez **Affichage > Historique des modifications...** pour examiner les modifications enregistrées. Utilisez les filtres pour trouver la tâche ou la période voulue.
3. Choisissez **Tâche > Historique des exécutions...** pour consulter les anciennes exécutions. Dans un navigateur, utilisez **Outils du projet > Historique des exécutions**.
4. Comparez les traces de la tâche à vérifier. Une trace aide à repérer les changements de paramètres, d’entrées et de versions logicielles. Elle ne remplace pas la lecture du résultat.

![Le tableau de bord de révision réunit l’état de révision et les problèmes. Les notes et les commentaires aident à comprendre les choix derrière les résultats.](assets/ui-review.png){#fig-review}

Vérifiez aussi les résultats actuels. D’anciens messages de réussite ne prouvent pas qu’une tâche modifiée a été relancée. Mettez à jour les résultats périmés et le rapport, puis enregistrez.

## Trouver rapidement un élément

1. Dans l’application de bureau, appuyez sur Ctrl+Maj+F pour ouvrir **Recherche globale**. Dans un navigateur, sélectionnez le bouton **Recherche globale** en haut de l’application.
2. Saisissez une partie d’un nom de tâche, de colonne ou de commentaire. Sélectionnez un résultat pour l’ouvrir.
3. Pour voir seulement les tâches, choisissez **Affichage > Liste des tâches** dans l’application de bureau ou **Outils du projet > Liste des tâches** dans un navigateur. Saisissez une partie du nom dans **Trouver une tâche**, puis ouvrez la ligne correspondante.

![La Liste des tâches offre une autre vue du diagramme, avec recherche. Trouvez une tâche par son nom, son type, son état ou sa sortie.](assets/ui-task-list.png){#fig-task-list}

Annuler peut restaurer les modifications de projet prises en charge, mais ne remonte pas toutes les actions. En particulier, cela ne retrouve pas l’ancien contenu d’un fichier externe remplacé par Exporter. Enregistrez une copie distincte avant un grand changement.

## Une courte liste de révision

- Pouvez-vous nommer la source des données et la date de la copie utilisée?
- Les nombres de lignes et les valeurs manquantes sont-ils logiques après le nettoyage?
- Les graphiques montrent-ils les bonnes colonnes, étiquettes et unités?
- Avez-vous vérifié les avertissements des modèles et le nombre de lignes utilisées?
- Le dernier rapport correspond-il aux derniers résultats?
- Les journaux et les fichiers exportés sont-ils dans le dossier prévu?
- Avez-vous enregistré le projet et vérifié la copie à partager?

# Adapter l’application à vos besoins {#settings}

1. Ouvrez un projet, puis choisissez **Fichier > Paramètres...** dans l’application de bureau. Dans un navigateur, sélectionnez **Paramètres** en haut de l’application.
2. Choisissez **Valeurs globales par défaut** ou **Ce projet**, puis recherchez une option ou sélectionnez une catégorie. Commencez par **Apparence** ou **Lignes d’aperçu par page** si l’espace de travail est difficile à lire.
3. Sélectionnez **Édition** à côté de l’option, changez sa valeur, puis sélectionnez **Enregistrer l’option**. Vérifiez l’espace de travail. Enregistrez le projet pour garder ses remplacements.

![Les Options regroupent l’apparence, l’édition du code, la console, l’exécution et la récupération. Choisissez une portée, recherchez une option, puis sélectionnez Édition.](assets/ui-settings.png){#fig-settings}

## Valeurs globales et remplacements du projet

Les valeurs globales s’appliquent aux projets qui en héritent. **Ce projet** enregistre seulement les valeurs remplacées. Sélectionnez **Utiliser la valeur globale** pour retirer un remplacement du projet. Une valeur R `NULL` explicite supprime une option; elle ne signifie pas l’héritage. Les anciens projets conservent leurs préférences enregistrées à l’ouverture.

Les catégories d’options R présentent la référence R incluse et les options enregistrées par l’application ou la console. Utilisez **Ajouter une option R** si une option de paquet ne figure pas dans la liste. Entrez son nom, choisissez le type de valeur, puis sélectionnez **Enregistrer l’option**. L’éditeur d’expressions accepte les vecteurs, les listes et les fonctions; les expressions sont exécutées à l’enregistrement. Consultez la documentation de l’option pour choisir une valeur valide. Certaines options R demandent un redémarrage. Si une option R enregistrée bloque le démarrage, choisissez **Session > Redémarrer avec les options R par défaut...**, corrigez l’option, puis redémarrez normalement.

## Versions des paquets

Choisissez **Session > Paquets R...**, ou **Gestionnaire de paquets R** dans les Options. IG utilise sa propre bibliothèque. Entrez le nom du paquet et une version exacte, ou laissez la version vide pour la dernière version disponible. **Fixer la version installée** conserve la version choisie. Exportez un fichier de verrouillage pour conserver le profil de paquets; restaurez-le pour demander ces versions de nouveau. Enregistrez le projet et redémarrez R après les changements de paquets. Le gestionnaire permet de restaurer un profil précédent ou de revenir aux paquets inclus.

## Affichage et navigation

Utilisez **Apparence** pour choisir Sombre ou Clair. **Thème de graphique par défaut** et **Palette de graphique par défaut** touchent les nouveaux graphiques. Ils ne changent pas tous les graphiques existants. Les catégories d’édition du code et de console règlent les polices, le retour à la ligne et d’autres choix d’affichage. Les commandes de zoom du menu Affichage agrandissent le texte. Pour un grand flux, combinez **Ajuster l’affichage** et **Liste des tâches**.

Le clavier aide si le diagramme est difficile à utiliser. Tab déplace le focus entre les commandes. Le [guide des raccourcis](#working-reference) présente les touches courantes de l’application de bureau.

## Enregistrement et confirmations

**Versions enregistrées précédentes à conserver** définit le nombre d’enregistrements antérieurs gardés pour un projet. La valeur par défaut est 20; zéro les désactive. La récupération après un arrêt est distincte. Gardez vos propres copies de sauvegarde des projets importants.

Activez **Arrêter le flux après la première erreur** pendant votre apprentissage pour remarquer les erreurs. **Exécuter les tâches compatibles en arrière-plan** aide à garder l’interface disponible pendant certains travaux. Ce réglage n’exécute pas toutes les tâches en même temps. **Intervalle d’enregistrement automatique de récupération (secondes)** vaut 30 par défaut.

Gardez les confirmations utiles pendant votre apprentissage. Lisez tout avertissement de travail non enregistré avant d’ouvrir un autre projet ou exemple. Enregistrer prend peu de temps et évite de refaire les changements.

## Confiance et renseignements privés

Ouvrir un projet rend ses tâches et son code accessibles à l’exécution. Acceptez des projets de sources fiables. Vérifiez les chemins d’entrée, les destinations d’exportation et les Scripts avant d’exécuter le flux d’une autre personne.

Un projet peut contenir des renseignements privés, tout comme un rapport ou un journal. Vérifiez les fichiers réels avant de les placer dans un dossier public ou de les joindre à un signalement.
