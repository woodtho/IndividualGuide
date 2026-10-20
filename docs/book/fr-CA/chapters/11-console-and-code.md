# Facultatif : essayer la Console R {#console}

Vous pouvez utiliser l’application sans la console. Elle sert aux questions rapides et aux petits essais lorsque vous souhaitez plus de contrôle.

R est le langage de calcul utilisé par l’application. Une **commande** est une instruction donnée à R. La console montre la commande et son résultat. Commencez par ce calcul :

```r
2 + 3
```

Le résultat est 5. Vous n’avez rien à installer pour essayer dans l’application de bureau.

## Ouvrir la console et exécuter une commande

1. Choisissez l’onglet **Console R**. Dans l’application de bureau, vous pouvez aussi utiliser **Affichage > Console R**.
2. Sélectionnez la zone de commande, saisissez `2 + 3` et appuyez sur Entrée. Vérifiez que la transcription montre 5.
3. Utilisez Maj+Entrée pour ajouter une ligne sans exécuter. Utilisez Ctrl+Entrée pour exécuter un bloc de lignes.

![La Console R comprend une zone de commande et une transcription. Les commandes de données du projet fournissent des copies de travail pour les essais, sans ajouter d’étape au flux.](assets/ui-console.png){#fig-console}

Les commandes, les résultats de R et les messages de console gardent leur texte d’origine. Les boutons suivent la langue choisie.

La console charge des copies des données disponibles du projet à la première commande. Sélectionnez **Actualiser les données** après avoir modifié les données du flux. Cela remplace les copies importées tout en gardant les autres valeurs de console. Modifier une valeur dans la console ne change pas automatiquement la table ou le flux du projet.

## Lire une commande avant de l’exécuter

Les commandes peuvent calculer, modifier des valeurs, lire ou écrire des fichiers. Utilisez du code compris ou fiable. Pour un exercice simple avec les fleurs fournies par R, essayez :

```r
mean(datasets::iris$Sepal.Length)
```

Le résultat est d’environ 5,8433. Ici, `mean` demande une moyenne. Le reste désigne la colonne de longueur du sépale dans les données de fleurs fournies. Vous n’avez pas à retenir cette ponctuation pour utiliser les formulaires.

## Retrouver et réutiliser une commande

Utilisez les commandes d’historique pour retrouver les anciennes commandes. Les flèches Haut et Bas parcourent l’historique lorsque le curseur est à la limite de la commande. Alt+Haut et Alt+Bas aident aussi. Ctrl+R recherche dans l’historique.

Tab ou Ctrl+Espace propose des complétions lorsqu’elles sont disponibles. Une complétion aide à saisir un nom. Elle ne vérifie pas que la commande répond à votre question. Lisez les erreurs et modifiez la commande avant de réessayer.

## Effacer, arrêter et réinitialiser

| Action | Quand l’utiliser | Résultat attendu |
| --- | --- | --- |
| Effacer la sortie ou Ctrl+L | Pour nettoyer l’affichage | Efface la transcription et les graphiques; garde les valeurs de travail |
| Arrêter | Si une commande prend trop de temps | Arrête le travail et efface les valeurs de console; garde la transcription et l’historique |
| Réinitialiser R | Pour repartir dans une console vide | Efface les valeurs de travail, la transcription, l’historique, le brouillon et les graphiques |
| Redémarrer le serveur R | Si le service de calcul de l’application s’est arrêté | Redémarre la session de l’application; enregistrez d’abord si possible |

Après Arrêter, la commande suivante charge des copies fraîches des données du projet. Les valeurs créées seulement dans la console ont disparu. Ces actions ne transforment pas un essai en tâche enregistrée.

## Garder le code utile dans une tâche

1. Sélectionnez le code utile dans la console ou laissez-le comme brouillon actuel ou dernière commande.
2. Sélectionnez **Créer un script**. Ouvrez la nouvelle tâche Script et vérifiez le code copié.
3. Vérifiez **Tables d’entrée / sorties spéciales** et **Sorties**. Même un nom déduit doit correspondre au résultat créé par le code.
4. Exécutez le Script et vérifiez les résultats enregistrés. Le [guide de la tâche Script](#task-script) explique le format des lignes de sortie.

# Facultatif : exporter le flux en code R {#generated-code}

L’onglet **Code** exporte le flux actif en script R complet ou en ensemble de code. C’est utile pour relancer une analyse sans ouvrir Individual Guide.

Un script est un fichier texte de commandes R. Un ensemble contient le script, ses fichiers de soutien et des instructions. Pour transmettre le travail, choisissez une exportation du flux complet. Le code d’une seule tâche peut dépendre d’étapes précédentes.

L’exportation de code est facultative pour l’usage quotidien. Un projet enregistré est habituellement le moyen le plus simple de reprendre le travail.

## Partager du code exécutable

1. Exécutez le flux et vérifiez ses résultats. Sélectionnez le flux à partager.
2. Ouvrez **Code** ou **Affichage > Code R généré** dans l’application de bureau. Choisissez **Script complet** dans **Affichage du code** pour lire toutes les instructions ensemble.
3. Sélectionnez **Télécharger le fichier .R** pour un script complet ou **Télécharger le lot de code** pour un ZIP contenant le pipeline, ses fonctions de soutien et un README.
4. Enregistrez le téléchargement. Joignez séparément les fichiers d’entrée nécessaires et indiquez les sorties attendues. L’ensemble de code ne recueille ni les fichiers de données externes ni les identifiants de base de données.

![L’onglet Code sépare le pipeline des fonctions de soutien. Télécharger .R les réunit dans un fichier; Télécharger l’ensemble les garde ensemble dans un ZIP.](assets/ui-code.png){#fig-code}

Le destinataire a besoin de R, des paquets demandés et de l’accès aux entrées. Le pipeline complet généré n’exige pas le paquet Individual Guide lui-même. Il faut encore configurer l’accès aux bases et les chemins des fichiers sur l’autre ordinateur.

Ouvrez le README de l’ensemble et suivez ses instructions dans un dossier de travail distinct. Vérifiez les destinations avant d’exécuter. Un script enregistré peut remplacer des fichiers, tout comme Exporter dans l’application.
