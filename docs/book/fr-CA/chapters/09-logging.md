# Garder un journal utile {#logging}

Un journal aide à répondre à trois questions : Qu’est-ce qui a été exécuté? Qu’est-ce qui a changé? Qu’est-ce qui a mal fonctionné? L’application consigne les événements des tâches. Vous pouvez ajouter des messages pour expliquer vos vérifications.

## Choisir la quantité d’information à consigner

Ouvrez une tâche configurée et développez **Journalisation**, près du haut de son panneau. Gardez **Consigner les événements de la tâche** activé, puis choisissez **Niveau minimal à consigner**. La gravité indique l’importance d’un message. L’application appelle ces choix des niveaux.

| Niveau | Usage |
| --- | --- |
| DEBUG | Détails supplémentaires pour chercher un problème |
| INFO | Progression et résultats habituels |
| WARN | Élément à vérifier, même si la tâche continue |
| ERROR | Échec ou problème grave |

INFO est un bon point de départ. Un minimum de WARN garde les avertissements et les erreurs, mais exclut les messages INFO ordinaires. Ce choix détermine les nouveaux messages conservés. Demander plus de détails plus tard ne retrouve pas les messages jamais consignés.

## Personnaliser le message d’une tâche

1. Développez **Journalisation**. Trouvez la règle dont **Quand** correspond à l’événement voulu, comme la fin de la tâche.
2. Cochez **Activer cette règle** et choisissez son **Niveau**. Celui-ci doit aussi respecter **Niveau minimal à consigner**.
3. Modifiez **Message**. Utilisez **Champ à insérer dans un message** et le bouton d’insertion de la règle pour ajouter le nom de la tâche ou le nombre de lignes de sortie.
4. Réglez **Afficher l’aperçu d’un événement** au même événement. Utilisez **Valeurs d’exemple** pour essayer des effectifs, puis lisez **Aperçu des événements du journal**. Cet aperçu n’exécute pas la tâche.
5. Exécutez la tâche et examinez ses entrées dans Journalisation. Vérifiez l’heure pour lire la nouvelle entrée.

![La Journalisation permet de choisir les événements, les niveaux et les champs des messages. Testez le texte dans l’aperçu avant d’exécuter la tâche.](assets/ui-logging.png){#fig-logging}

Pour une tâche de nettoyage, vous pourriez utiliser :

```text
{task_name}: {rows_in} rows in; {rows_out} rows out.
```

Les mots entre accolades sont des espaces réservés. L’application les remplit avec les valeurs de l’exécution. Utilisez le sélecteur pour ne pas avoir à retenir leur orthographe. Le nombre de lignes de sortie peut être inconnu au début. Utilisez-le donc dans un message de fin. Le texte d’exercice ci-dessus reste identique dans les deux éditions; vous pouvez traduire les mots autour des accolades dans vos propres messages.

![Lisez l’entrée rendue avant d’exécuter la tâche. L’aperçu du fichier permet d’examiner Texte, CSV ou JSON sans écrire de fichier.](assets/ui-logging-preview.png){#fig-logging-preview}

Gardez le champ du message d’origine dans les règles d’avertissement et d’erreur. Votre texte ne masquera ainsi pas la cause d’un échec. Si un espace réservé reste visible, vérifiez son champ et son événement dans l’aperçu.

## Ajouter un message dans un Script

Cette partie est facultative. Un Script peut ajouter un message simple avec la fonction fournie `log_event()` :

```r
log_event("Checked the source data before making the report", "INFO")
```

Expliquez les décisions dans les messages, comme le choix d’un filtre ou d’un remplacement de valeurs manquantes. Évitez d’imprimer des données privées par ligne seulement pour montrer qu’une étape s’est exécutée. L’exemple **Voitures - rapport avec trace d’exécution** comprend un avertissement personnalisé à examiner.

Un avertissement seul n’arrête pas un Script. Pour choisir un autre chemin selon une condition de qualité, utilisez Branchement. Pour faire échouer le code si une condition est mauvaise, demandez à son auteur d’ajouter cette vérification précise.

## Exporter le journal {#task-export_log}

Utilisez **Exporter le journal** pour écrire les journaux choisis dans un fichier au sein du flux.

1. Ajoutez Exporter le journal depuis Sortie.
2. Choisissez les tâches dans **Exécuter après et inclure ces tâches**. Incluez Rapport pour consigner sa fin. Une sélection vide signifie toutes les autres tâches du flux actif.
3. Choisissez **Texte**, **CSV** ou **JSON** dans **Format**, puis **Niveau minimal à exporter**. Laissez **Afficher des exemples plutôt que les événements consignés** désactivé pour vérifier votre propre exécution.
4. Saisissez un **Chemin complet du fichier de destination** complet dans un dossier où vous pouvez écrire. Ajoutez la bonne extension, comme `/pipeline-log.csv` après l’adresse du dossier pour CSV.
5. Cochez **Remplacer un fichier existant** seulement pour remplacer ce fichier aux prochaines exécutions. Sélectionnez **Exporter le journal** ou **Exécuter** dans l’en-tête. Ouvrez le fichier hors de l’application et vérifiez ses dates et ses messages.

![Exporter le journal demande un chemin de fichier complet, un format et les tâches à attendre. Son filtre de gravité s’applique aux messages déjà conservés par ces tâches.](assets/ui-export-log.png){#fig-export-log}

TXT se lit facilement en texte simple. CSV s’ouvre dans un tableur avec des champs distincts. JSON est utile si un autre programme lit les entrées. Exporter le journal écrit un fichier plutôt que de créer une table de données.

Si le flux s’est arrêté sur une erreur précédente, exécutez ensuite Exporter le journal seul lorsque c’est possible. Cela aide à recueillir les erreurs. Son fichier ne peut pas contenir sa propre fin, qui survient plus tard.

## Mettre le journal dans un rapport

Les titres intégrés aux rapports enregistrés gardent leur langue d’origine. Ce guide cite **Pipeline execution log** tel quel pour vous aider à le trouver dans le fichier téléchargé. Il s’agit du journal d’exécution du pipeline. Vous pouvez écrire vos propres titres de rapport, notes et messages en français ou en anglais.

1. Ouvrez une tâche Rapport après avoir exécuté les tâches dont les journaux sont nécessaires.
2. Dans **Apparence**, cochez **Inclure le journal du flux dans le rapport**. Réglez **Niveau minimal du journal** à INFO pour la progression normale ou à WARN pour les avertissements et les erreurs seulement.
3. Sélectionnez **Générer le rapport**, puis **Télécharger le fichier HTML** ou **Télécharger le DOCX**. Ouvrez le fichier et cherchez **Pipeline execution log**.

![Apparence du Rapport contrôle l’annexe du journal et son niveau minimal. Générez de nouveau le rapport après avoir changé ce réglage.](assets/ui-report-log.png){#fig-report-log}

Le rapport prend une copie des journaux disponibles des autres tâches avant sa création. Il ne peut pas inclure sa propre fin à ce moment. Ajoutez Exporter le journal après Rapport pour garder cet événement dans un autre fichier. Vous pouvez aussi créer un rapport contenant seulement le journal : activez l’option sans sélectionner d’éléments ordinaires.

## Lire les dates en plus des messages

Chaque tâche conserve jusqu’à 1 000 entrées récentes, sur plusieurs exécutions. Le projet enregistré garde les entrées disponibles. Relancer le flux n’efface pas les anciens messages.

Utilisez les heures et les identifiants d’exécution pour comparer les passages. D’anciens avertissements peuvent rester après une correction. Une exécution longue ou très bavarde peut chasser les anciennes entrées du journal conservé. Exportez donc les journaux importants à temps.

## Utiliser les journaux de démarrage pour les problèmes de démarrage

Le menu **Session** de l’application de bureau offre **Ouvrir le journal de démarrage**, **Ouvrir le dossier des journaux** et **Enregistrer le journal de diagnostic** pour les problèmes de connexion et de démarrage. Les journaux des tâches servent à l’analyse elle-même. Avant de partager un journal, retirez les données privées, les mots de passe et les chemins à ne pas publier.
