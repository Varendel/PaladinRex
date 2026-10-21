# Paladin Rex

Addon pour paladin sur **World of Warcraft 3.3.5a** (Wrath of the Lich King), entièrement en français.
Un seul addon pour le PvE, le JcJ, la menace et les urgences.

## Installation

1. Télécharge l'archive `PaladinRex-1.4.zip` (onglet *Releases*) ou le code du dépôt.
2. Copie le dossier `PaladinRex` dans `World of Warcraft\Interface\AddOns\`.
3. Relance complètement le jeu, puis coche « Paladin Rex » dans la liste des addons.

L'addon ne se charge que sur un personnage paladin.

## Mode PvE

- Une ligne par classe du groupe ou du raid, avec les icônes Puissance, Sagesse, Rois et Sanctuaire pour choisir la bénédiction de chaque classe.
- Clic gauche sur une ligne : bénédiction (supérieure si tu as des Symboles des rois), clic droit : bénédiction simple.
- Nombre de joueurs bénis, temps restant, joueurs hors de portée.
- Un gros bouton (et une touche) qui pose l'aura, la Fureur vertueuse en mode tank, puis la prochaine bénédiction manquante. Appuie jusqu'à ce que tout soit à jour, hors combat.
- Rangée d'auras, sceau actif, alerte « Aucun sceau ! » en combat, compteur de Symboles des rois.
- Bouton de réduction du panneau.

## Mode JcJ

S'active seul en champ de bataille et en arène (ou avec `/pala pvp`).

- Barre de sorts avec recharges : Marteau de la justice, Repentir, Marteau de courroux, Horion sacré, Mains de liberté, de protection et de sacrifice, Épuration, Bouclier divin, Imposition des mains, Courroux vengeur, Maîtrise des auras, Faveur divine. Clic gauche sur la cible, clic droit sur soi.
- Longanimité affichée sur les sorts bloqués.
- Alertes au centre : Bouclier divin sous 30 % de vie, Main de liberté quand tu es ralenti, Épuration, Marteau de courroux pour achever, Marteau de la justice quand la cible incante.
- Rendements décroissants des étourdissements sur la cible (estimation).
- Grosses capacités ennemies signalées (Bloc de glace, Cape d'ombre, Héroïsme…).

## Menace

- Tableau de la menace du groupe sur ta cible.
- En tank (Fureur vertueuse active ou `/pala tank`) : « AGGRO PERDUE » avec le nom de la victime et la provocation disponible.
- Sinon : alerte à 85 % de menace et quand tu prends l'aggro.
- Touches : Main de rétribution sur la cible, Défense vertueuse sur l'allié frappé par ta cible.

## Bulles

Trois boutons ronds et transparents à côté du personnage : Bouclier divin, Protection divine, Main de protection.
Sous 15 % de vie, ils prennent leur couleur et la bulle à lancer clignote. Alt + glisser pour les déplacer.

## Commandes

| Commande | Effet |
|---|---|
| `/pala` | afficher ou masquer |
| `/pala pvp`, `/pala pve`, `/pala auto` | changer de mode |
| `/pala tank` | mode tank (Fureur vertueuse, alertes d'aggro) |
| `/pala grandes` | bénédictions supérieures : auto, toujours, jamais |
| `/pala menace` | tableau de menace |
| `/pala bulles`, `/pala seuil 20` | bulles et seuil de vie |
| `/pala alertes` | alertes JcJ |
| `/pala verrou`, `/pala reset` | bloquer ou replacer les fenêtres |
| `/pala minicarte` | icône de la minicarte |

Les touches se règlent dans Options, Raccourcis, AddOns, Paladin Rex.

## Limites connues

- Écrit pour le client 3.3.5a en français ; les noms de sorts viennent du jeu, donc les autres langues devraient fonctionner, mais l'interface reste en français.
- Les rendements décroissants des étourdissements sont une estimation.

## Licence

MIT, voir `LICENSE`.
