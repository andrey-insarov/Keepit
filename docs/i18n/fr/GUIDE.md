<!-- source: GUIDE.md 39bab8b4f2a3de5ce61f2427db3f17e669b6f280 -->
# Guide de Keepit

Keepit est un gestionnaire d’historique du presse-papiers et de modèles pour macOS. Il s’installe dans
la barre des menus, mémorise tout ce que vous copiez et recolle n’importe quel élément avec un
raccourci clavier. Tous les raccourcis ci-dessous sont ceux par défaut, et chacun se modifie dans
*Réglages → Raccourcis*. Ce guide décrit Keepit 3. Le guide de Keepit 2.x est conservé tel quel sur
[keep.it.com/v2/guide](https://keep.it.com/v2/guide) (en anglais).

![Le menu d’historique](site/img/guide/menu.png)

**Sommaire**

- [Partie 1 : Premiers pas](#part-1--getting-started) : [Installation](#install) · [Premier lancement](#first-launch)
- [Partie 2 : Au quotidien](#part-2--everyday-use) : [Le menu d’historique](#the-history-menu) · [Recherche et aperçu](#search-and-preview) · [Coller sans le menu](#paste-without-the-menu) · [La file de collage](#the-paste-queue) · [Le menu étendu](#the-extended-menu)
- [Partie 3 : Modèles](#part-3--templates) : [Créer et organiser](#creating-and-organising) · [Variables](#placeholders) · [Des modèles qui posent des questions](#templates-that-ask-questions)
- [Partie 4 : La Visionneuse](#part-4--the-viewer)
- [Partie 5 : Réglages](#part-5--settings)
- [Partie 6 : Sécurité](#part-6-security) : [Mot de passe et chiffrement](#password-and-encryption) · [Touch ID](#touch-id) · [Phrase de récupération](#recovery-phrase) · [Sauvegarde](#backup)
- [Partie 7 : Fonctions avancées](#part-7--advanced) : [Automatisation](#automation-the-keepit-url-scheme) · [Mises à jour](#updates) · [Désinstallation](#uninstalling)
- [Référence](#reference) : [Dépannage](#troubleshooting) · [Aide-mémoire des raccourcis](#keyboard-cheat-sheet) · [Aide-mémoire des variables](#placeholder-cheat-sheet)

---

## Partie 1 : Premiers pas

### Installation

**Homebrew** est la méthode recommandée, car `brew upgrade` maintient l’app à jour :

```bash
brew tap andrey-insarov/keepit https://github.com/andrey-insarov/Keepit
brew install --cask andrey-insarov/keepit/keepit
```

**DMG :** téléchargez `Keepit-<version>.dmg` depuis la page de la
[dernière version](https://github.com/andrey-insarov/Keepit/releases/latest), ouvrez-le et faites glisser Keepit
dans *Applications*.

![Le DMG : faites glisser Keepit dans Applications](site/img/guide/dmg.png)

À la première ouverture, macOS confirme que l’app provient d’Internet et qu’elle a été vérifiée par
Apple. Cliquez sur *Ouvrir*.

![Confirmation Gatekeeper de macOS](site/img/guide/gatekeeper.png)

Keepit est signé et notarié, se met à jour tout seul et fonctionne en natif sur les Mac à puce Apple
et Intel sous macOS 13 Ventura ou ultérieur.

### Premier lancement

Keepit est une app de barre des menus : elle n’a ni icône dans le Dock ni fenêtre tant que vous n’en
ouvrez pas. Après le premier lancement, l’icône 📎 apparaît dans la barre des menus et Keepit pose
trois questions.

**1. Restaurer depuis une sauvegarde ?** S’il s’agit d’un nouveau Mac et que vous avez une sauvegarde
Keepit (automatique, dans iCloud Drive ou un autre dossier, ou un fichier `.keepit` exporté),
*Restaurer depuis une sauvegarde…* ramène votre historique et vos modèles avant toute autre chose. Le
fichier se déverrouille avec le mot de passe du Mac dont il provient, ou avec sa phrase de
récupération. *Repartir de zéro* passe cette étape. La même restauration reste disponible plus tard
dans *Réglages → Sauvegarde → Restaurer…*, et un double-clic sur un fichier `.keepit` dans le Finder
l’ouvre également. Les détails se trouvent dans la section [Sauvegarde](#backup).

![La première question sur un nouveau Mac : restaurer depuis une sauvegarde ou repartir de zéro](site/img/guide/restore-first-run.png)

**2. Un mot de passe (facultatif).** Keepit peut stocker l’historique et les modèles sous forme
chiffrée et les déverrouiller avec Touch ID. Vous pouvez décider maintenant ou plus tard dans
*Réglages → Sécurité*. La [Partie 6](#part-6-security) explique le fonctionnement. Avec *Pas
maintenant*, tout reste non chiffré sur le disque. Si vous venez de restaurer une sauvegarde avec son
mot de passe, Keepit propose de conserver ce mot de passe pour ce Mac.

![La proposition de mot de passe au premier lancement](site/img/guide/password-offer.png)

![« Pas maintenant » choisi : ce que cela signifie est dit clairement, ainsi que l’endroit où le modifier](site/img/guide/no-password-notice.png)

**3. L’autorisation d’accessibilité.** Pour coller à votre place, Keepit envoie ⌘V à l’app dans
laquelle vous travailliez. macOS ne le permet qu’aux apps listées dans *Réglages Système →
Confidentialité et sécurité → Accessibilité*. Cliquez sur *Ouvrir Réglages Système* et activez Keepit.
Sans cette autorisation, Keepit continue d’enregistrer et de copier, mais c’est vous qui appuyez sur
⌘V.

![Keepit demande l’autorisation d’accessibilité](site/img/guide/accessibility-prompt.png)

![Keepit activé dans Confidentialité et sécurité → Accessibilité](site/img/guide/accessibility-settings.png)

Par défaut, Keepit se lance à l’ouverture de session. Cela se désactive dans *Réglages → Général*.

---

## Partie 2 : Au quotidien

### Le menu d’historique

Appuyez sur **⌥M** dans n’importe quelle app ou cliquez sur l’icône 📎. Le menu s’ouvre au niveau du
curseur de texte quand Keepit parvient à le localiser, sinon au niveau du pointeur de la souris.

Chaque ligne correspond à un élément copié, le plus récent en premier. Celui-ci est en **gras** : c’est
ce qui se trouve actuellement dans le presse-papiers. L’icône indique l’app depuis laquelle vous avez
copié. Un titre qui se termine par `…` signale que l’élément compte plus de lignes que le menu n’en
affiche. Les images apparaissent sous forme de vignette, les listes de fichiers avec les noms des
fichiers.

![Le panneau d’aperçu à côté du menu affiche l’élément sélectionné en entier, avec son app d’origine, l’heure et la taille](site/img/guide/menu-preview.png)

![Une image dans l’historique : vignette dans le menu, image complète dans l’aperçu](site/img/guide/menu-image.png)

Pour coller un élément, cliquez dessus, ou atteignez-le avec ↑ ↓ et appuyez sur Retour, ou encore
appuyez sur son numéro avec **⌃⌥** : `⌃⌥3` colle l’élément 3. La même touche fonctionne partout, sans
ouvrir le menu.

Sous l’historique se trouvent le sous-menu *Modèles*, la Visionneuse (⌥E), les Réglages (⌥S), *Effacer
l’historique* (⌥C), *Suspendre l’enregistrement 10 minutes* (⌥P, pour taper quelque chose que vous ne
voulez pas voir enregistré), *Verrouiller Keepit* (⌥L) lorsqu’un mot de passe est défini, et les mises
à jour. **⌥T** ouvre le menu des modèles seul. Toutes ces touches fonctionnent aussi sans le menu.

### Recherche et aperçu

**Recherche.** Commencez à taper quand le menu est ouvert : le champ du haut filtre la liste par titre
et par texte intégral, si bien qu’une ligne au milieu d’un long élément est trouvée aussi. Retour colle
le premier résultat, Échap vide le champ et un second Échap ferme le menu.

**Aperçu.** Survolez un élément (ou atteignez-le au clavier) et un panneau à côté du menu affiche
l’image entière ou les premières lignes d’un long texte, avec l’app d’origine, la date et la taille.
Les textes courts d’une seule ligne n’ont pas d’aperçu, puisque la ligne du menu les montre déjà en
entier.

![La saisie filtre le menu ; le panneau d’aperçu affiche l’élément sélectionné](site/img/guide/search-preview.png)

### Coller sans le menu

Les raccourcis globaux agissent depuis n’importe quelle app sur l’historique tel qu’il est à cet
instant. L’élément 1 est le presse-papiers :

| Touches | Effet |
|------|--------------|
| `⌃⌥1` … `⌃⌥9`, `⌃⌥0` | Coller l’un des éléments 1 à 10 de l’historique |
| `⌥⇧V` | Coller l’élément *précédent* (élément 2) ; appuyez de nouveau pour revenir |
| `⌃⌥V` | Coller le presse-papiers en texte brut, sans mise en forme |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | Coller le presse-papiers en MAJUSCULES / en minuscules / avec Une Majuscule À Chaque Mot / avec une majuscule en début de phrase |
| `⌃⌥W` | Coller le presse-papiers sans les espaces de début et de fin |
| `⌃⌥J` | Coller le presse-papiers sur une seule ligne |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` | Coller le presse-papiers barré / souligné / souligné d’un trait ondulé, sous forme de texte brut qui garde son apparence partout, y compris dans les messageries (voir ci-dessous) |
| `⌃⌥X` | Coller le presse-papiers sans ces décorations |
| `⌃⌥A` | Ajouter le presse-papiers aux Modèles |
| `⌃⌥⌫` | Supprimer l’élément le plus récent de l’historique |

Ces trois décorations ne sont pas de la mise en forme : Keepit ajoute après chaque caractère un *signe
combinatoire* Unicode (b̶a̶r̶r̶é̶, s̲o̲u̲l̲i̲g̲n̲é̲, o̰n̰d̰ṵl̰ḛ́), si bien que le texte a le même aspect dans une
messagerie, un formulaire web ou un terminal, là où une vraie mise en forme serait perdue. Le revers :
ce texte pèse trois fois plus lourd, une recherche sur le mot simple ne le trouve pas, les lecteurs
d’écran butent dessus et certaines polices tracent le trait de façon irrégulière. *Retirer les
décorations* (`⌃⌥X`) enlève ces signes, y compris dans un texte décoré ailleurs. Dans les deux sens,
les signes sont retirés d’après leur point de code, quelle que soit leur origine : une transcription
phonétique qui utilise les mêmes signes comme lettres (U+0330 est aussi le signe API de la voix
craquée) les perd, et les trois décorations commencent elles aussi par les retirer. Quand VoiceOver
est activé, `⌃⌥` est sa propre touche de modification : attribuez-en une autre à *Actions sur le
dernier élément* dans Réglages → Raccourcis.

Les transformations s’appliquent au texte. Pour une image ou une liste de fichiers, la touche émet un
bip. Tout cela se modifie ou se désactive dans *Réglages → Raccourcis*.

### La file de collage

Il arrive qu’on veuille copier cinq choses à un endroit et les coller dans l’ordre ailleurs : des
cellules dans un formulaire, des lignes d’une page dans un document. La file de collage le fait sans
le menu :

1. Appuyez sur **⌥N** (ou choisissez *Démarrer la file de collage* dans le menu). L’icône de la barre
   des menus affiche un point rouge et un compteur : `📎 ● 0`.
2. Copiez comme d’habitude avec ⌘C, autant de fois que vous voulez. Le compteur augmente à chaque
   copie : 1, 2, 3… Tout est également enregistré dans l’historique.

   ![La barre des menus quand la file est active : point rouge et compteur](site/img/guide/queue-menubar.png)

3. Passez à l’endroit où le texte doit aller et appuyez sur **⌥V** pour chaque élément. Ce que vous
   avez copié en premier est collé en premier, et le compteur diminue. ⌘V colle toujours le
   presse-papiers comme d’habitude, vous pouvez donc combiner les deux.
4. La file se désactive d’elle-même une fois le dernier élément collé, ou après deux minutes sans
   copie ni collage (la durée est réglable). Un nouvel appui sur ⌥N l’arrête plus tôt.

**⌥⇧N** colle d’un coup tout ce qui reste dans la file. Les éléments sont séparés par un retour à la
ligne, une tabulation, une espace ou rien du tout : cela se choisit dans la sous-fenêtre *File de
collage* des Réglages, où se règle aussi le délai d’inactivité. Tant que la file est active, le menu
d’historique marque ses éléments : `▶` sera collé ensuite, `○` attend encore, `✓` est déjà collé.

![Le menu d’historique avec la file active : ○ en attente, ▶ suivant, ✓ collé ; la ligne du menu indique combien il en reste](site/img/guide/queue-menu.png)

![Réglages → File de collage](site/img/guide/prefs-queue.png)

### Le menu étendu

Maintenez **⇧** quand le menu d’historique est ouvert et chaque élément reçoit un sous-menu `▸` qui
regroupe toutes ses actions : Coller, Coller en texte brut, Copier seulement (dans le presse-papiers,
sans coller), les transformations *Coller en*, Ajouter aux Modèles, Afficher dans la Visionneuse,
Supprimer. Pointez un élément ou appuyez sur → pour l’ouvrir. Une fois le sous-menu ouvert, vous
pouvez relâcher ⇧.

![Maintenez ⇧ : chaque élément reçoit un sous-menu ; pour l’élément le plus récent, il affiche les raccourcis globaux](site/img/guide/extended-menu.png)

Pour l’élément le plus récent, le sous-menu indique les raccourcis globaux du tableau ci-dessus. Ce
sont les mêmes actions avec les mêmes touches, c’est donc un bon endroit pour les apprendre. Les autres
éléments affichent les actions sans touches : un raccourci fonctionne partout, ou il n’est pas affiché.

![Pour les autres éléments : les mêmes actions, sans raccourcis](site/img/guide/extended-menu-item2.png)

![Pour une image, les actions sur le texte sont grisées : seuls Coller, Copier seulement, Ajouter aux Modèles, Afficher dans la Visionneuse et Supprimer s’appliquent](site/img/guide/extended-menu-image.png)

---

## Partie 3 : Modèles

Les modèles sont des éléments que vous gardez pour de bon : signatures, adresses, réponses types,
extraits de code, un logo que vous collez souvent. Ils sont rangés dans une arborescence de dossiers et
apparaissent dans le sous-menu *Modèles* du menu d’historique ainsi que sous **⌥T**. Une installation
neuve contient un dossier *Exemples* (une formule de salutation, la date du jour, une citation du
presse-papiers et une signature) pour que vous voyiez ce que les modèles savent faire avant d’écrire
les vôtres. Supprimez-les ou modifiez-les à votre guise (*Réinitialiser…* dans les Réglages les fait
revenir).

![Le dossier Exemples : le survol d’un élément affiche son texte](site/img/guide/template-examples.png)

![Le menu des modèles : les dossiers s’ouvrent en sous-menus, les lettres précédées de & deviennent des touches d’accès rapide](site/img/guide/template-menu-letters.png)

### Créer et organiser

**Ajouter un modèle**

- Depuis le menu d’historique : `⌃⌥A` pour l’élément le plus récent, *Ajouter le presse-papiers aux
  modèles* en bas du menu, ou ⇧ → sous-menu de l’élément → *Ajouter aux Modèles* pour n’importe quel
  élément.
- Dans la Visionneuse : sélectionnez un élément de l’historique et cliquez sur *Ajouter aux modèles*,
  ou faites-le glisser sur l’arborescence des modèles. *Nouvel élément* crée un modèle de texte vide ;
  *Nouvel élément depuis un fichier…* (menu contextuel) en crée un à partir d’un fichier texte ou
  image.

**Organiser**

- *Nouveau dossier* crée un dossier. Faites glisser les éléments d’un dossier à l’autre, ou utilisez
  *Monter* / *Descendre* dans le menu contextuel.
- Un modèle nommé `-` devient une ligne de séparation dans le menu.
- Un `&` devant une lettre du nom (par exemple `&Signature`) fait de cette lettre la touche d’accès
  rapide de l’élément dans le menu des modèles : appuyez sur `S` quand le menu est ouvert.
- *Définir le raccourci…* dans le menu contextuel attribue à un modèle son propre raccourci global.
- Un modèle sans nom affiche sa première ligne. *Renommer* et *Effacer le nom* se trouvent dans le
  menu contextuel, ou modifiez le champ *Nom* au-dessus du texte.

### Variables

Les modèles de texte peuvent contenir des variables `{…}` qui sont remplies au moment du collage. Tout
le reste est collé tel quel. Dans la Visionneuse, **Insérer ▾** liste toutes les variables et place
celle que vous choisissez à l’emplacement du curseur : il n’y a rien à retenir.

![L’exemple « Date du jour » : `{date:EEEE, d MMMM yyyy}` devient la date courante au collage](site/img/guide/template-examples-date.png)

![Insérer ▾ dans la Visionneuse liste toutes les variables](site/img/guide/insert-menu.png)

Les plus utiles :

| Variable | Résultat |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Date du jour / heure actuelle, au format du système |
| `{date:yyyy-MM-dd}` | N’importe quel format (`yyyy MM dd EEEE HH mm …`) |
| `{date:long}` `{time:short}` `{datetime:medium}` | Un style nommé : `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{date+1y-2d}` | Décalage : `d` jours, `w` semaines, `m` mois, `y` années, `h` heures ; sur `date`, `time`, `datetime`, plusieurs à la suite si besoin |
| `{clipboard}` `{clipboard:2}` | Le presse-papiers, ou l’élément N de l’historique |
| `{clipboard\|upper}` `{clipboard\|trim\|oneline}` | Filtres `upper` `lower` `title` `trim` `oneline` `url`, combinables |
| `{cursor}` | L’endroit où se retrouve le curseur de texte après le collage |
| `{user}` `{username}` `{host}` | Nom complet, nom du compte, nom de l’ordinateur |
| `{uuid}` `{random:1-100}` | Un nouvel UUID ; un nombre aléatoire |
| `{{` `}}` | Accolades littérales : le modèle `{{"x":1}}` colle `{"x":1}` |

Les noms des variables s’écrivent en minuscules : `{date}` est une variable, `{Date}` et `{DATE}` sont
du texte collé tel quel. Les noms de styles et de filtres (`{date:LONG}`, `{clipboard|UPPER}`)
s’écrivent indifféremment en majuscules ou en minuscules.

La liste complète se trouve dans l’[aide-mémoire des variables](#placeholder-cheat-sheet).

### Des modèles qui posent des questions

`{input:Name}` et `{choice:Label=A|B|C}` transforment un modèle en petit formulaire : au moment du
collage, Keepit demande d’abord les valeurs, puis colle le texte final. Un même nom n’est demandé
qu’une fois, quel que soit le nombre de ses occurrences. `{input:Name=Default}` préremplit le champ.

![Le collage d’un modèle avec {input:Name} demande d’abord la valeur](site/img/guide/input-dialog.png)

Par exemple, un modèle de réponse :

```
Bonjour {input:Nom},

Merci pour votre message du {date-1d}. Je reviens vers vous d’ici {date+3d:EEEE}.
{cursor}
{user}
```

Au collage, il demande *Nom*, remplit les dates, signe avec votre nom complet et laisse le curseur sur
la ligne vide.

---

## Partie 4 : La Visionneuse

*Visionneuse…* dans le menu, ou un clic droit sur l’icône 📎, ouvre une fenêtre avec trois
arborescences : **Presse-papiers** (son contenu actuel, en lecture seule), **Historique** (*Texte et
fichiers* et *Images*) et **Modèles**.

![La Visionneuse avec un modèle sélectionné](site/img/guide/viewer.png)

- Sélectionnez un élément pour le voir à droite. Le texte se modifie sur place, et les changements
  s’appliquent quand vous quittez l’éditeur. Une image est affichée à la taille de la sous-fenêtre,
  avec ses dimensions en pixels et la taille du fichier au-dessus. Dans les listes de fichiers, un
  double-clic ouvre le fichier. *Afficher en hexadécimal* dans le menu contextuel montre les octets
  bruts.
- La barre d’outils : *Envoyer au presse-papiers*, *Coller* (dans l’app d’où vous venez), *Ajouter aux
  modèles*, *Nouvel élément*, *Nouveau dossier*, *Supprimer*, *Insérer ▾* (variables) et **?**, qui
  ouvre ce guide.
- **Rechercher** (`⌘F`) : le champ de gauche filtre l’historique et les modèles par nom et par contenu
  et surligne le résultat.
- Faites glisser des éléments de l’historique vers l’arborescence des modèles pour les conserver, et
  des modèles vers l’Historique pour les recopier. L’ordre se modifie par glisser-déposer ou avec
  *Monter* / *Descendre*. ⌫ supprime l’élément sélectionné.
- La barre d’état indique la date, l’app d’origine, le format et la taille.

![La recherche dans la Visionneuse surligne les résultats](site/img/guide/viewer-search.png)

---

## Partie 5 : Réglages

`⌘,` dans le menu, *Réglages…*, ou ⌥S depuis n’importe quelle app. La fenêtre fonctionne comme les
fenêtres de réglages du Mac : choisissez une sous-fenêtre dans la barre d’outils, et chaque changement
s’applique immédiatement. Il n’y a pas de bouton Enregistrer. Fermez la fenêtre avec ⌘W ou Échap.
Chaque option accompagnée d’un **?** dispose d’une bulle qui l’explique.

![Réglages → Général](site/img/guide/prefs-general.png)

| Sous-fenêtre | Ce qu’on y trouve |
|-----|---------------|
| **Général** | Lancer à l’ouverture de session · enregistrer l’historique en quittant, le restaurer au démarrage · coller après le choix (désactivé = copier seulement) · délai de collage (augmentez-le pour les apps lentes à passer au premier plan) · ouvrir le menu au curseur de texte · Mises à jour : *Rechercher les mises à jour automatiquement* (version en téléchargement direct ; désactivé = aucune requête réseau) — [Mises à jour](#updates) |
| **Raccourcis** | Tous les raccourcis globaux au même endroit, voir ci-dessous |
| **File de collage** | Les trois touches de la file, le délai d’inactivité après lequel elle se désactive et ce qu’il faut placer entre les éléments pour *Coller tout le reste* — [La file de collage](#the-paste-queue) |
| **Historique** | Nombre d’éléments texte/fichiers et d’images à conserver (1000 / 30) · oublier les éléments plus anciens que … · *Supprimer les doublons* (recopier la même chose la remonte en tête) · *Ignorer les données masquées du presse-papiers* · la liste des apps ignorées (identifiants de bundle ; les gestionnaires de mots de passe sont toujours ignorés) |
| **Menu** | Champ de recherche · numérotation · panneau d’aperçu · infobulles · icônes des apps d’origine · vignettes d’images · éléments dans le menu (nombre d’entrées récentes affichées, 60 par défaut ; les autres restent accessibles par la recherche) · longueur des titres · hauteur des vignettes |
| **Sécurité** | Mot de passe, Touch ID, verrouillage, phrase de récupération — [Partie 6](#part-6-security) |
| **Sauvegarde** | Sauvegarde automatique (ligne d’état à côté du titre) : *Sauvegarder automatiquement dans un dossier*, le nom du Mac dans les fichiers, le dossier, le nombre de copies à conserver · Sauvegarde manuelle : *Sauvegarder maintenant*, *Enregistrer une archive…* · Restauration : *Restaurer…* — [Sauvegarde](#backup) |
| **Avancé** | Intervalle d’interrogation du presse-papiers · Automatisation : *Autoriser les commandes URL keepit://* (désactivé par défaut — [Automatisation](#automation-the-keepit-url-scheme)) · Données : *Ouvrir le dossier* · Réinitialiser et désinstaller : *Réinitialiser…* (retour à l’état d’une installation neuve, les modèles d’exemple reviennent) · *Désinstaller…* (réinitialisation, puis suppression de l’app, du lancement à l’ouverture de session, de l’entrée du trousseau et des autorisations) |

![Réglages → Historique : limites et liste des apps ignorées](site/img/guide/prefs-history.png)

![Réglages → Raccourcis](site/img/guide/prefs-hotkeys.png)

Dans la sous-fenêtre **Raccourcis**, cliquez dans un champ et appuyez sur une combinaison. ⌫ désactive
une touche. Une combinaison déjà utilisée par une autre commande est refusée, et la raison s’affiche
sous les champs. *Rétablir les valeurs par défaut* restaure le jeu ⌥+lettre (⌥M historique, ⌥T
modèles, ⌥E Visionneuse, ⌥S Réglages, ⌥C Effacer l’historique, ⌥P pause, ⌥L verrouiller, ⌥Q quitter),
ainsi que ⌥⇧V et ⌃⌥. *Coller l’élément par numéro* et *Actions sur le dernier élément* n’acceptent que
des touches de modification, le chiffre ou la lettre étant ajouté par Keepit. Si macOS ou une autre
app utilise déjà une combinaison, Keepit le signale au démarrage. *Visionneuse* ⌥E, *Réglages* ⌥S,
*Effacer l’historique* ⌥C, *Suspendre l’enregistrement* ⌥P, *Verrouiller Keepit* ⌥L et *Quitter
Keepit* ⌥Q fonctionnent depuis n’importe quelle app et sont rappelés à côté de leurs commandes dans le
menu. Les touches sont définies par leur position physique sur le clavier, selon la disposition
américaine : sur un clavier AZERTY, ⌥M correspond donc à la touche située à droite du N. Sur un Mac,
⌥+lettre saisit normalement un caractère spécial (© ou € par exemple) ; si vous avez besoin de
l’un d’eux, déplacez la commande sur une autre touche.

---

## Partie 6 : Sécurité

### Mot de passe et chiffrement

*Réglages → Sécurité → Demander le mot de passe au lancement* chiffre l’historique et les modèles avec
AES-256-GCM. La clé est dérivée de votre mot de passe (PBKDF2, 200 000 itérations) et n’existe qu’en
mémoire. Elle est effacée quand Keepit se verrouille : avec *Verrouiller Keepit* (`⌥L`), à la
fermeture et, si vous le souhaitez, après que le Mac est resté verrouillé ou en veille un certain
temps. *Verrouillage auto de Keepit* vaut **Jamais** sur une nouvelle installation (une mise à jour
depuis la 3.0.3 conserve l’ancien choix, *Immédiatement* si le verrouillage avec l’écran était
activé). Un gestionnaire de presse-papiers qui réclame son mot de passe après chaque pause café finit
par ne plus être utilisé, et `⌥L` est là pour les moments qui comptent. *Immédiatement* verrouille en
même temps que l’écran. *Après 5 minutes*, *Après 15 minutes* ou *Après 1 heure* ne tiennent pas compte d’une
courte absence : Keepit reste déverrouillé et continue d’enregistrer, et ne se verrouille que si le
Mac est resté absent pendant toute la durée. Il en va de même quand Keepit démarre alors que le Mac
est déjà verrouillé ou que la session d’un autre utilisateur est au premier plan (un redémarrage après
une mise à jour, par exemple) : l’absence est comptée à partir du démarrage, dans la mesure où macOS
signale cet état à Keepit (c’est normalement le cas ; sinon, le décompte commence au prochain
verrouillage ou à la prochaine mise en veille). Avec Touch ID, Keepit demande une empreinte dès que le
Mac est déverrouillé et se trouve ainsi prêt avant le premier `⌥M`.

![Définition du mot de passe avec le clavier à l’écran. Il s’agit d’une photo de l’écran et non d’une capture : sur le Mac de l’auteur, une capture de cette scène ne montre que la zone de dialogue](site/img/guide/set-password-keyboard.jpg)

Les zones de dialogue de mot de passe indiquent la disposition de clavier active et signalent le
verrouillage des majuscules, de sorte qu’un mot de passe refusé reste rarement un mystère. Le bouton
clavier à côté du champ ouvre un **clavier à l’écran** qui permet de saisir le mot de passe à la
souris : les clics ne transitent jamais par le système sous forme de frappes, les touches sont
mélangées à chaque ouverture et le clavier demande à macOS de l’exclure des captures et des
enregistrements d’écran (il est exclu sur certaines configurations, sans garantie). Il est utile sur
un Mac auquel vous ne faites pas entièrement confiance, ou dont l’écran est partagé. Au lancement et
après un verrouillage, Keepit demande le mot de passe (ou Touch ID). *Récupérer l’accès…* accepte à la
place la phrase de 24 mots, voir [Phrase de récupération](#recovery-phrase).

![Déverrouillage au lancement : mot de passe, Quitter ou phrase de récupération ; OK reste désactivé tant que rien n’est saisi. Photographié pour la même raison](site/img/guide/unlock-keyboard.jpg)

![Réglages → Sécurité](site/img/guide/prefs-security.png)

### Touch ID

Avec *Déverrouiller avec Touch ID*, la clé est également stockée dans la Secure Enclave, protégée par
votre empreinte : Keepit demande un toucher au lieu du mot de passe. Le mot de passe continue de
fonctionner en solution de secours (le bouton de mot de passe dans la demande). Écran rabattu et avec
un Magic Keyboard externe doté de Touch ID, Keepit demande l’empreinte sur le clavier. *Autoriser le
changement de mot de passe avec Touch ID* permet à une empreinte de remplacer l’ancien mot de passe
lorsque vous le changez.

![Déverrouillage avec Touch ID ; le mot de passe reste la solution de secours](site/img/guide/touch-id.png)

### Phrase de récupération

Quand vous définissez un mot de passe, Keepit affiche une seule fois une phrase de 24 mots.
Imprimez-la ou conservez-la dans un gestionnaire de mots de passe. Si vous oubliez le mot de passe,
*Récupérer l’accès…* dans la fenêtre de déverrouillage ouvre les données et vous permet d’en définir
un nouveau. *Phrase de récupération → Créer une nouvelle…* génère une nouvelle phrase et invalide
l’ancienne. *Afficher…*, juste à côté, montre de nouveau la phrase actuelle après Touch ID ou le mot
de passe.

Sans le mot de passe, Touch ID sur le même Mac ou la phrase, les données sont irrécupérables : il n’y
a pas de serveur et rien à réinitialiser.

![La phrase de récupération de 24 mots (les mots sont masqués ici)](site/img/guide/recovery-phrase.png)

### Sauvegarde

Keepit peut conserver une copie chiffrée de votre historique et de vos modèles dans le dossier de
votre choix (iCloud Drive, Dropbox, Google Drive, un disque externe, un NAS) et en écrire une nouvelle
dès que quelque chose a changé. Il n’existe pas de serveur Keepit : le dossier est le vôtre. Le
fournisseur qui l’héberge voit le fichier chiffré, sa taille et un petit en-tête non chiffré (la date
d’écriture et la version de Keepit, la méthode de dérivation de la clé, des identifiants aléatoires,
et le nom de votre Mac uniquement si vous l’activez). La [page sur la sécurité](/security#backups)
(en anglais) le détaille champ par champ.

![Réglages → Sauvegarde : sauvegarde automatique, sauvegarde manuelle, restauration](site/img/guide/prefs-backup.png)

**Activation.** *Réglages → Sauvegarde → Sauvegarder automatiquement dans un dossier*, puis
*Choisir…* un dossier (le sélecteur s’ouvre dans iCloud Drive). La sauvegarde automatique nécessite la
protection par mot de passe de *Réglages → Sécurité* : chaque copie est scellée avec une clé dérivée
de celle de votre coffre. Elle s’ouvre donc avec votre mot de passe Keepit ou votre phrase de
récupération, sur ce Mac ou sur un autre, sans rien avoir à configurer. Sans mot de passe, la case est
désactivée et l’indique.

**Ce qui se passe ensuite : le calendrier.** Environ cinq minutes après la dernière modification (et
au plus tard une fois par jour tant que Keepit tourne), Keepit écrit dans le dossier un fichier nommé
`Keepit-<date and time>-<installation>-<id>.keepit`, le relit pour le vérifier, et seulement ensuite
supprime les plus anciennes de ses propres copies au-delà de *Conserver* (10 par défaut, de 1 à 100).
Chaque copie est complète en elle-même, ce n’est pas un incrément : un seul fichier vous suffit
toujours. Les copies créées par un autre Mac et les fichiers que vous déposez vous-même ne sont jamais
touchés : deux Mac qui partagent un dossier écrivent deux séries indépendantes. La ligne d’état à côté
du titre *Sauvegarde automatique* indique l’heure et la taille de la dernière copie, ou la raison de
l’échec de la dernière tentative. Rien ne se passe tant que Keepit est verrouillé. *Sauvegarder
maintenant* (sous *Sauvegarde manuelle*) n’attend pas la période de calme.

**Inclure le nom de ce Mac dans les fichiers de sauvegarde** (désactivé par défaut) inscrit le nom de
l’ordinateur dans l’en-tête non chiffré de chaque fichier, pour distinguer facilement deux séries d’un
même dossier dans le Finder. Le fournisseur de stockage peut voir ce nom, c’est pourquoi l’option est
facultative.

**Restauration.** *Restaurer…* ouvre une sauvegarde (de ce Mac, d’un autre Mac ou un fichier exporté)
une fois que vous l’avez déverrouillée : avec le mot de passe du Mac sur lequel elle a été créée, ou
avec la phrase de récupération que ce Mac a affichée quand son mot de passe a été défini (*Récupérer
l’accès…* dans la zone de dialogue du mot de passe). Un aperçu indique quand et où le fichier a été
créé et combien d’éléments il contient. Deux possibilités s’offrent ensuite :

![L’aperçu de la restauration : quand et avec quelle version de Keepit le fichier a été écrit, ce qu’il contient, Fusionner ou Remplacer](site/img/guide/restore-preview.png)

- *Fusionner* ajoute ce qui n’est pas déjà présent : les éléments d’historique d’après leur contenu,
  et les modèles de la sauvegarde dans un nouveau dossier nommé *Import <date>*, sans leurs
  raccourcis. Vous voyez ainsi exactement ce qui vient de la sauvegarde et pouvez le déplacer ou le
  supprimer. Rien de ce qui est à vous n’est écrasé.
- *Remplacer* abandonne l’historique et les modèles actuels et prend ceux de la sauvegarde. Avant
  cela, Keepit écrit une copie de ce que vous avez actuellement (`Keepit-before-restore-…`) dans le
  dossier de sauvegarde ou dans un dossier que vous choisissez. Si cette copie ne peut pas être
  écrite, le remplacement ne démarre pas. Si Keepit n’a pas encore de mot de passe, il vous en demande
  un pour cette copie, comme pour *Enregistrer une archive…*.

*Restaurer aussi les préférences* reprend les raccourcis, les limites et les options de la sauvegarde.
Les réglages qui expriment la confiance accordée à un Mac précis (Touch ID, l’automatisation par URL
et ses apps de confiance, le dossier de sauvegarde lui-même) restent toujours tels qu’ils sont ici. Si
l’historique de la sauvegarde dépasse ce qu’autorisent les limites de ce Mac, Keepit indique avant
confirmation ce qui pourra tenir.

Vous avez restauré une sauvegarde avec sa phrase de récupération sur un Mac qui n’a pas encore de mot
de passe ? Keepit vous demande d’abord d’en définir un, afin que les données restaurées ne se
retrouvent jamais non chiffrées sur le disque, et vous laisse conserver cette phrase pour ce Mac ou en
obtenir une nouvelle. Restauré avec le mot de passe ? Keepit propose de le garder comme mot de passe
de ce Mac. Dans les deux cas, la sauvegarde automatique est un réglage propre à chaque Mac :
activez-la ici et choisissez le dossier (le même convient très bien), et ce Mac commence sa propre
série de fichiers à côté de celle de l’ancien.

**Le passage à un nouveau Mac** est la raison d’être de tout cela : installez Keepit, choisissez
*Restaurer depuis une sauvegarde…* au premier lancement, sélectionnez le fichier le plus récent de
votre dossier, saisissez le mot de passe de l’ancien Mac et cliquez sur *Remplacer*. Activez ensuite la
sauvegarde automatique sur le nouveau Mac. Les copies déjà créées s’ouvrent avec le mot de passe et la
phrase en vigueur au moment de leur écriture : après un changement de mot de passe, les anciennes
nécessitent toujours l’ancien mot de passe.

**Sauvegarde manuelle.** Deux boutons, deux choses différentes. *Sauvegarder maintenant* crée
immédiatement une copie semblable aux copies automatiques : même type de fichier, même dossier et même
série, à ouvrir avec votre mot de passe Keepit ou votre phrase. *Enregistrer une archive…* écrit une
seule *archive* `.keepit` à l’endroit de votre choix, verrouillée par un mot de passe que vous
choisissez pour elle. Elle ne nécessite pas la protection par mot de passe de Keepit, et Keepit ne
suit plus le fichier par la suite. C’est pratique pour transmettre des données ou garder une copie en
dehors du dossier de sauvegarde. Le nom proposé dit ce que c’est :
`Keepit-archive-<date>-manual.keepit`, à côté des copies automatiques
`Keepit-<date and time>-<installation>-<id>.keepit`.

![Enregistrer une archive… : le nom du fichier contient archive et manual](site/img/guide/save-to-archive.png)

![Le mot de passe propre à l’archive, avec un indicateur de robustesse : il n’est stocké nulle part](site/img/guide/archive-password.png)

*Restaurer…* ouvre les deux types de fichiers. L’archive remplace *Exporter…* / *Importer…* de la
2.x. Le fichier transfère les données entre la version en téléchargement direct et la version App
Store, ainsi qu’entre Keepit 2.x et 3.x. Un fichier écrit par la 3.0 nécessite la 3.0 ou une version
ultérieure pour être ouvert ; la 3.0 lit tout ce que la 2.x a écrit.

**En cas de problème.** Une copie qui échoue est signalée dans la ligne d’état, puis retentée à
intervalles croissants. Les copies précédentes sont conservées. Si Keepit a été quitté ou si le Mac
s’est arrêté au milieu d’une restauration, le lancement suivant remet discrètement tout en l’état
d’avant la restauration. Dans le cas rare où c’est impossible (un fichier impossible à écrire, un
disque plein), Keepit nomme le fichier et quitte sans rien modifier : corrigez le problème et relancez.
Les détails, y compris la structure interne du format de fichier, se trouvent sur la
[page sur la sécurité](/security#backups) (en anglais).

---

## Partie 7 : Fonctions avancées

### Automatisation : le schéma d’URL keepit://

Raccourcis (*Ouvrir l’URL*), Raycast, Alfred, Keyboard Maestro ou `open` dans un shell peuvent piloter
Keepit, **une fois que vous l’avez activé** dans *Réglages → Avancé → Automatisation → Autoriser les
commandes URL keepit://*. C’est désactivé par défaut, car n’importe quelle app ou page web peut ouvrir
une URL, et `add` / `paste` modifient le presse-papiers et saisissent du texte dans l’app au premier
plan. Quand c’est désactivé, Keepit ignore ces URL en émettant un bip. Quand c’est activé, Keepit
regarde qui a ouvert l’URL : la première commande de chaque app qui modifie quelque chose (`paste`,
`copy`, `template`, `add`, `add-template`, `pause`, `resume`) est présentée dans une zone de dialogue.
*Autoriser* l’exécute une fois, *Toujours autoriser* ajoute l’app à la liste de confiance (qui se vide
avec *Oublier les apps de confiance* dans la même sous-fenêtre). Pour un navigateur web, ou un
expéditeur que macOS ne sait pas nommer, la question est posée à chaque fois. Les commandes qui se
contentent d’ouvrir les fenêtres de Keepit ne demandent jamais rien.

| URL | Effet |
|-----|--------|
| `keepit://paste/2`<br>`keepit://paste/latest`<br>`keepit://paste/previous` | Coller l’élément N de l’historique (ou le dernier / le précédent) dans l’app au premier plan |
| `keepit://copy/3` | Placer l’élément N dans le presse-papiers sans le coller |
| `keepit://template/Signature`<br>`keepit://template/Work/Reply?copy=1` | Coller (ou copier) un modèle d’après son nom ou son chemin de dossier |
| `keepit://add?text=…` | Ajouter du texte à l’historique et au presse-papiers |
| `keepit://add-template?text=…&name=…` | Créer un modèle |
| `keepit://history`<br>`keepit://templates`<br>`keepit://viewer`<br>`keepit://settings` | Ouvrir le menu d’historique, le menu des modèles, la Visionneuse, les Réglages |
| `keepit://pause`<br>`keepit://resume` | Suspendre l’enregistrement 10 minutes / le reprendre |

Encodez le texte en pourcentage (`%20` pour une espace). Les URL sont ignorées tant que Keepit est
verrouillé.

### Mises à jour

Keepit consulte GitHub Releases une fois par jour et propose les mises à jour dans une zone de
dialogue. *Rechercher des mises à jour…* le fait immédiatement. Les mises à jour sont signées (EdDSA)
et notariées. Avec Homebrew, `brew upgrade --cask keepit` fait la même chose. Les sommes de contrôle de
chaque téléchargement se trouvent dans `SHA256SUMS` sur la page de la version.

Cette recherche est la seule requête réseau de Keepit, et elle est facultative : *Réglages → Général →
Mises à jour → Rechercher les mises à jour automatiquement*. Une fois désactivée, Keepit ne contacte
plus rien, même à votre demande, et *Rechercher des mises à jour…* disparaît des menus. La mise à jour
se fait alors en téléchargeant l’app sur [keep.it.com](https://keep.it.com) ou avec Homebrew. La
version App Store n’a ni système de mise à jour ni cette option : c’est l’App Store qui la met à jour.

### Désinstallation

*Réglages → Avancé → Réinitialiser et désinstaller → Désinstaller…* supprime l’app, le dossier de
données, les entrées du trousseau (y compris la clé Touch ID), l’élément d’ouverture de session et
l’entrée d’accessibilité. Keepit demande votre mot de passe ou Touch ID, la saisie du mot `DELETE` et
une confirmation. Exportez d’abord une sauvegarde si vous pensez avoir encore besoin des données. Avec
Homebrew, lancez ensuite `brew uninstall --cask --force keepit` pour que Homebrew oublie le cask.

![Réglages → Avancé](site/img/guide/prefs-advanced.png)

---

## Référence

### Dépannage

**Rien n’est collé après le choix d’un élément.** L’autorisation d’accessibilité manque : *Réglages
Système → Confidentialité et sécurité → Accessibilité → Keepit*. Si Keepit figure dans la liste mais
ne colle toujours pas, désactivez-le puis réactivez-le : macOS oublie l’autorisation quand l’app est
réinstallée.

**Un raccourci ne fait rien.** Une autre app ou macOS l’utilise déjà. Keepit le signale au lancement.
Choisissez une autre combinaison dans la sous-fenêtre *Raccourcis*. ⌃⌥ avec des chiffres et des lettres
est libre sur un Mac dans sa configuration d’origine.

**Le menu s’ouvre au mauvais endroit.** L’app dans laquelle vous êtes n’expose pas son curseur de
texte, le menu se rabat donc sur le pointeur de la souris. *Ouvrir le menu au curseur de texte si
possible*, dans la sous-fenêtre Général, désactive cette recherche si vous préférez toujours le
pointeur.

**Quelque chose que j’ai copié manque.** Ce que l’app d’origine marque comme masqué n’est pas
enregistré, pas plus qu’une copie faite pendant qu’un gestionnaire de mots de passe (liste intégrée) ou
une app de votre liste d’exclusion était au premier plan, y compris l’app que vous venez tout juste de
quitter. Voir *Réglages → Historique* et la
[page sur la sécurité](/security#what-is-not-recorded) (en anglais).

**Touch ID n’est pas proposé.** Aucun capteur Touch ID n’est accessible pour le moment (écran rabattu,
pas de clavier avec Touch ID). Keepit conserve le réglage et demandera l’empreinte dès qu’un capteur
sera disponible.

**L’état de la sauvegarde indique que le dossier n’est pas disponible.** Le dossier a été déplacé,
renommé, éjecté ou (iCloud Drive) supprimé du stockage local. Montez-le ou rétablissez-le, et la copie
suivante aboutira. Vous pouvez aussi *Choisir…* un nouveau dossier : il commence une nouvelle série,
et les anciens fichiers restent où ils sont.

**Un fichier de sauvegarde ne s’ouvre pas.** *Mot de passe incorrect* signifie que la balise
d’authentification du fichier ne correspond pas : vérifiez que vous utilisez bien le mot de passe du
Mac qui a *écrit* le fichier (après un changement de mot de passe, les anciennes copies s’ouvrent
toujours avec l’ancien), ou sa phrase de récupération. *Cette sauvegarde nécessite Keepit 3.0 ou plus
récent* signifie que le fichier a été écrit par une version plus récente que celle qui tente de
l’ouvrir.

**Homebrew refuse d’installer par-dessus une app existante.** Quittez Keepit et placez d’abord
`/Applications/Keepit.app` dans la corbeille, ou ajoutez `--force`.

Toujours bloqué ? [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues) · admin@keep.it.com

### Aide-mémoire des raccourcis

| Touches | Action |
|------|--------|
| `⌥M` | Menu d’historique ; tapez pour rechercher |
| `⌥T` | Menu des modèles |
| `⌃⌥1` … `⌃⌥0` | Coller l’un des éléments 1 à 10 (dans le menu et partout) |
| `⇧` dans le menu | Menu étendu : toutes les actions pour chaque élément |
| `⌥⇧V` | Coller l’élément précédent / permuter |
| `⌃⌥V` | Coller le presse-papiers en texte brut |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | MAJUSCULES / minuscules / Majuscule À Chaque Mot / majuscule en début de phrase |
| `⌃⌥W` `⌃⌥J` | Sans espaces aux extrémités / sur une seule ligne |
| `⌃⌥K` `⌃⌥D` `⌃⌥Y` `⌃⌥X` | Barré / souligné / souligné ondulé / retirer les décorations |
| `⌃⌥A` | Ajouter le presse-papiers aux Modèles |
| `⌃⌥⌫` | Supprimer l’élément le plus récent |
| `⌥N` · `⌥V` · `⌥⇧N` | File de collage : démarrer / arrêter · coller le suivant · coller tout le reste |
| `⌥E` `⌥S` `⌥C` `⌥P` `⌥L` `⌥Q` | Visionneuse · Réglages · Effacer l’historique · Suspendre l’enregistrement · Verrouiller · Quitter |
| `⌘F` dans la Visionneuse | Rechercher |
| `⌘,` | Réglages |

### Aide-mémoire des variables

| Variable | Résultat |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Date / heure / les deux, au format du système |
| `{date:yyyy-MM-dd}` `{time:HH:mm}` | Format personnalisé (modèles de date Unicode) |
| `{date:long}` `{time:short}` `{datetime:full}` | Style nommé : `short` `medium` `long` `full` |
| `{date+7d}` `{date-1m:MMMM}` `{time+1h}` `{datetime-1d:long}` `{date+1y-2d}` | Décalage (`d` `w` `m` `y` `h` ; jusqu’à quatre décalages à la suite) |
| `{weekday}` `{month}` `{year}` | Nom du jour, nom du mois, année |
| `{iso}` `{unix}` | Horodatage ISO 8601, heure Unix |
| `{clipboard}` `{clipboard:2}` | Le presse-papiers (élément 1) ou l’élément N |
| `{clipboard\|upper}` `\|lower` `\|title` `\|trim` `\|oneline` `\|url` | Filtres, combinables |
| `{input:Name}` `{input:Name=Default}` | Demander une valeur avant de coller |
| `{choice:Label=A\|B\|C}` | Proposer de choisir une option |
| `{cursor}` | Position du curseur après le collage |
| `{user}` `{username}` `{host}` | Nom complet, nom du compte, nom de l’ordinateur |
| `{uuid}` `{random:1-100}` | Nouvel UUID, nombre aléatoire dans un intervalle |
| `{{` `}}` | Accolades littérales |
