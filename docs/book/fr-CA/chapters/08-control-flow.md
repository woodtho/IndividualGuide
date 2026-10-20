# Exécuter des étapes sous condition ou en boucle {#control-flow}

Les premiers projets peuvent souvent suivre une simple suite de tâches. Ajoutez un Branchement pour choisir un chemin selon une décision. Ajoutez une Boucle pour répéter des étapes. Essayez l’exemple fourni avant de construire une grande version.

Avant de commencer, enregistrez une copie du projet et exécutez ses entrées. Les deux tâches se trouvent dans **Ajouter une tâche > Contrôle du flux**. Un **jeton de chemin** est un nom qui indique aux tâches suivantes leur parcours. Choisir une table fournit des données; choisir un jeton contrôle si une tâche s’exécute et combien de fois.

## Branchement {#task-branch}

Utilisez **Branchement** pour exécuter des tâches seulement si une condition est respectée. Vous pourriez, par exemple, produire un résumé seulement si une table contient assez de lignes.

1. Ajoutez **Branchement**. Dans **Configuration**, choisissez la table source dans **Entrées / dépendances**.
2. Réglez **Nombre de branches de sortie**, puis développez les paramètres du premier chemin. Saisissez une **Libellé de la branche** et un **Jeton de la branche** unique.
3. Pour vérifier le nombre de lignes, choisissez **Nombre de lignes du jeu de données** dans **Condition**. Choisissez **Jeu de données**, **Opérateur** et **Nombre de lignes**. Dans l’exemple des fleurs, `>=` et `100` signifient au moins 100 lignes.
4. Réglez la **Condition** d’un autre chemin à **Chemin de repli / sinon** pour un parcours lorsqu’aucune condition ordinaire ne correspond. Sélectionnez **Valider**, puis **Évaluer**, et lisez la décision.
5. Ouvrez chaque tâche qui doit suivre cette décision. Dans **Exécuter après une branche ou une boucle**, sélectionnez le jeton voulu.
6. Exécutez le flux actif. Développez **Journalisation** pour vérifier le chemin choisi et les tâches ignorées.

![Les paramètres de Branchement nomment chaque chemin et sa condition. La tâche suivante doit aussi choisir ce chemin dans Exécuter après le chemin de branchement/boucle.](assets/ui-branch.png){#fig-branch}

Choisir seulement une table d’entrée ne rattache pas une tâche à un chemin. Il faut aussi choisir ce chemin. **Fleurs - contrôle de qualité conditionnel** exige au moins 100 fleurs. Changez le seuil dans une copie et relancez pour voir le parcours choisi.

## Boucle {#task-loop}

Utilisez **Boucle** pour répéter des tâches sur plusieurs valeurs, fichiers, tables ou groupes.

Commencez par **Fleurs - répéter par espèce**. Sa boucle de groupes produit un résumé par espèce. Suivez le lien entre le chemin de Boucle et le Script répété. Examinez les trois résumés enregistrés et les entrées d’itération dans le journal.

Pour vous exercer sans écrire du code, enregistrez une copie de **Fleurs - répéter par espèce** et utilisez ses tâches préparées. Une **itération** est un passage dans les étapes répétées.

1. Ouvrez la tâche **Boucle** de l’exemple. Dans **Configuration**, vérifiez que **Type d’itération** est **Groupes**.
2. Choisissez **Jeu de données source / alias d’entrée** et **Colonne de groupe / valeur**.
3. Gardez le nom de **Variable de boucle** utilisé par le Script préparé. Ce nom permet au code d’utiliser le groupe actuel. Ne le changez pas à un seul endroit.
4. Gardez le **Jeton de la branche** et la **Règle de nommage des sorties** de l’exemple pendant votre apprentissage. La partie `{index}` conserve un résultat distinct par itération.
5. Sélectionnez **Aperçu de la boucle**, puis examinez **Aperçu**. Vérifiez que les groupes indiqués sont ceux attendus.
6. Ouvrez la tâche répétée et choisissez le jeton de boucle dans **Exécuter après une branche ou une boucle**, en plus des entrées normales. Exécutez le flux actif et vérifiez les résultats par groupe et les entrées du journal.

Pour créer votre propre boucle, utilisez **Ajouter une tâche > Contrôle du flux > Boucle**. Choisissez un jeton unique et une règle de sortie comme `{task}_{index}_{output}`. Vérifiez les entrées des tâches Rapport et Exporter après avoir changé les noms de sortie.

![Les paramètres de Boucle définissent la source du travail répété. Aperçu de la boucle permet de vérifier les groupes prévus avant d’exécuter le flux.](assets/ui-loop.png){#fig-loop}

Pour les fichiers exportés, donnez un nom différent à chaque itération. Un espace réservé `{index}` pris en charge peut ajouter son numéro. Si chaque itération remplace le même fichier, seul le dernier peut rester.

## Choisir la source d’une boucle

| Source | Ce que vous fournissez |
| --- | --- |
| Liste de paramètres | Une valeur par ligne dans Valeurs d’itération |
| Fichiers | Des chemins de fichiers ou des motifs de recherche |
| Jeux de données | Toutes les tables chargées; Jeu de données source nomme l’alias d’entrée des tâches visuelles répétées |
| Groupes | Une table source et une colonne de regroupement |
| Plages de dates | Une date ou une plage par ligne, comme `2026-01-01` ou `2026-01-01/2026-01-31` |
| Résultats de requête de base de données | Une table de résultats préparée dont les lignes fournissent les éléments |

Vérifiez l’aperçu avant d’exécuter. Un fichier manquant ou un mauvais groupe pourrait répéter le mauvais travail de nombreuses fois. Si l’étape répétée utilise du code, partez de l’exemple fonctionnel et gardez le nom de variable de boucle cohérent avec ce code.

## Commencer petit

Essayez deux ou trois itérations. Vérifiez les noms de sortie, les chemins, le nombre de lignes et les journaux. Une fois ces éléments corrects, élargissez la boucle.

Placez un Rapport final ou Exporter le journal en dehors du chemin répété s’il doit s’exécuter une seule fois à la fin. Rattachez-le au chemin seulement pour en obtenir un par itération. Une boucle arrêtée ou en échec ne supprime pas les fichiers déjà écrits par les itérations précédentes.
