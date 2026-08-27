# DEPTHCAST — Game Design Document

*Version 0.2 — document vivant. Historique des changements : [DECISIONS.md](DECISIONS.md).*

> **Ce qui a changé depuis la v0.1** — quatre décisions du 27 août 2026 modifient le scope :
> le co-op passe en V1, la Résonance devient un pot commun, chaque joueur garde un build
> indépendant, et le chat vocal sort de la V1. Détail et raisons dans [DECISIONS.md](DECISIONS.md).

---

## 1. Vision & Pitch

**Pitch en une phrase :** Un donjon roguelite où la magie ne t'obéit jamais complètement — tes sorts changent de nature à chaque étage, et maîtriser le chaos devient la vraie compétence.

**Pitch étendu :** Le joueur choisit 4 écoles de magie parmi celles débloquées, descend un donjon étage par étage, et doit composer avec le fait que chaque sort peut se transformer en l'un de ses effets possibles à chaque nouvelle descente. La progression méta ne rend jamais le joueur plus prévisible — elle élargit au contraire l'éventail de ce que chaque école peut devenir, forçant une adaptation permanente plutôt qu'une montée en puissance linéaire.

**Comparables (positionnement, pas copie) :**
- *Hades / Dead Cells* — structure roguelite, boucle run/méta, feel de combat
- *Peak* — modèle de sortie : lancer dès que jouable et solide, puis scaler par updates majeures plutôt que tout livrer day one
- *Slay the Spire* (dans l'esprit, pas le genre) — l'incertitude contrôlée comme moteur de decision-making

**Ce qui doit rester vrai à toutes les étapes du projet :** l'instabilité des sorts est la seule vraie promesse du jeu. Toute feature ajoutée doit soit nourrir cette tension (plus d'écoles, plus de façons de la maîtriser/contourner), soit rester périphérique (cosmétique, confort) — jamais la neutraliser.

---

## 2. Modèle de sortie & Roadmap (esprit "Peak")

**Philosophie :** sortir en accès anticipé / V1 dès que la boucle centrale est solide et fun sur un contenu volontairement resserré, puis annoncer et livrer des updates majeures gratuites qui ajoutent du contenu structurant (pas juste des skins).

| Phase | Contenu | Objectif |
|---|---|---|
| **V1 (lancement)** | 1 donjon complet (biome unique), 5 écoles de magie (pools de 2 à 5 effets chacune), **co-op 2-4 joueurs via Steam**, méta-progression de base (Éclats, déblocages d'écoles), économie de Résonance in-run (pot commun, verrouillage de sorts/écoles — section 4), 3-4 étages jouables en boucle avec difficulté croissante | Valider que la boucle "re-roll + adaptation + verrouillage mérité" est fun sur la durée, seul comme à plusieurs, construire une communauté early |
| **Update 1** | 2e biome avec nouvelles règles de salle, 1-2 écoles supplémentaires, premier fragment de narration/lore sur "pourquoi le grimoire est corrompu" | Prouver que le système scale sans se répéter |
| **Update 2** | 3e biome, boss signature, système de synergies entre écoles (combos), **chat vocal de proximité**, progression méta approfondie | Ajouter de la profondeur stratégique et sociale |
| **Update 3+** | Contenu piloté par les retours communauté (mode daily run ? seed partagée ?) | Rétention long terme |

*Note : ce séquençage est une hypothèse de travail, à ajuster selon la taille réelle de l'équipe et le temps disponible — l'idée n'est pas de s'y tenir rigidement mais d'avoir un scope V1 honnête et un horizon clair à montrer à des collaborateurs.*

### Multijoueur — co-op 2-4 joueurs, dans le scope V1

Le co-op est **dans la V1**. C'est un revirement assumé par rapport à la v0.1 du document, qui le classait en update majeure : voir [DECISIONS.md](DECISIONS.md#d1) pour les raisons.

**Décisions arrêtées :**

- **Topologie : P2P host-autoritatif via Steam.** Un joueur héberge et fait autorité sur l'état du jeu. Pas de serveur dédié — surdimensionné pour du co-op PvE, et coûteux en infra.
- **Builds indépendants.** Chaque joueur choisit ses 4 écoles librement et re-roll ses propres sorts. Chacun a son propre aléatoire : le flux RNG d'un joueur dérive de `seed de run + PlayerId`, et le re-roll d'un joueur n'affecte jamais les slots d'un autre. Cela tranche la question ouverte de la v0.1 en faveur de la profondeur stratégique individuelle plutôt que du moment social partagé.
- **Chat vocal de proximité : hors V1.** Repoussé en Update 2. C'est un chantier à part entière (capture, encodage, spatialisation 3D, contrôles de volume et mute) et les joueurs ont Discord en attendant.

**Ce que le co-op impose techniquement :** autorité d'état claire, RNG déterministe et reproductible par joueur, résolution déterministe des effets simultanés. Ces trois points sont précisément ce que garantissent les règles d'architecture de la [section 11](#11-notes-techniques--architecture), qu'il faut donc respecter dès la première ligne de code et non plus « au cas où ».

---

## 3. Boucle de jeu

### Boucle de run (5-15 min selon profondeur atteinte)
1. Sélection de 4 écoles parmi celles débloquées — **indépendamment pour chaque joueur** en co-op
2. Descente étage par étage — plusieurs salles handmade par étage
3. Combat + résolution d'obstacles liés aux effets actifs — les monstres tués génèrent de la **Résonance**, versée dans un **pot commun à l'équipe** (section 4)
4. En fin d'étage : dépense de Résonance pour verrouiller certains sorts/écoles contre le reroll suivant (optionnel). Un joueur ne peut verrouiller que **ses propres** slots, mais puise dans le pot commun
5. À chaque nouvel étage : re-roll des effets dans chaque école non verrouillée, **par joueur**
6. Mort ou fin de run → retour au hub méta avec les **Éclats** récoltés (monnaie méta, cross-run — distincte de la Résonance qui ne survit jamais à la run)

### Boucle méta (entre les runs)
1. Dépense d'**Éclats** pour débloquer de nouvelles écoles (élargit le pool de re-roll, donc plus d'incertitude potentielle)
2. (Post-V1) Progression narrative / cosmétique / biomes débloqués

> **Terminologie — ne jamais confondre, en code comme en UI :**
> **Éclats** = monnaie méta, persiste entre les runs, individuelle, sert à débloquer du contenu.
> **Résonance** = monnaie tactique, ne vit que le temps d'une run, **partagée par l'équipe**, sert à verrouiller des sorts contre le reroll.
> Deux systèmes économiques séparés, avec des objectifs et des durées de vie différents. Aucune conversion possible entre les deux.

---

## 4. Système de sorts

### Règle fondamentale
Chaque **école** a une identité claire (thème mécanique cohérent) et un pool de **2 à 5 effets réels** selon l'école (pas de nombre fixe imposé — chaque école a la taille de pool qui sert le mieux son identité). Le joueur choisit 4 écoles avant le run ; à chaque étage, les 4 slots re-roll indépendamment dans leur propre pool, sauf ceux verrouillés. Un effet reste caché (`???`) tant qu'il n'a pas été lancé au moins une fois **sur l'étage en cours** — y compris un effet verrouillé, qui redevient `???` au nouvel étage tant qu'il n'est pas relancé.

### Les 5 écoles de départ (V1)

| École | Identité | Effets (taille de pool V1 à ajuster en équilibrage) |
|---|---|---|
| **Braise** | Dégâts & auto-soin instable | Boule de Feu / Mur de Flammes / Brûlure Vive *(pool de 3, extensible à 5)* |
| **Givre** | Contrôle & défense | Gel / Bise Glaciale / Rempart *(pool de 3)* |
| **Force** | Positionnement & mobilité | Poussée / Attraction / Ruée *(pool de 3)* |
| **Vie** | Soutien & récupération | Soin / Invocation / Siphon *(pool de 3)* |
| **Ombre** | Évasion & diversion | Pas d'Ombre / Voile / Leurre *(pool de 3)* |

*Règle de conception pour les futures écoles/effets : chaque nouvel effet ajouté à un pool doit avoir une identité mécanique distincte et non redondante avec les autres effets de la même école — sinon le re-roll perd son sens. Un pool à 5 doit se sentir aussi varié qu'un pool à 2, pas juste plus long.*

**À trancher pour le co-op :** le ciblage allié du Soin, la propriété des Invocations, et si le Voile (Ombre) n'affecte que son lanceur.

### Économie de Résonance — verrouiller son chaos par la performance

**Principe :** les monstres tués pendant une run génèrent de la **Résonance**, une monnaie tactique propre à la run (remise à zéro à chaque nouvelle run). En fin d'étage, avant le reroll du suivant, un joueur peut dépenser de la Résonance pour **verrouiller** un de ses sorts ou une de ses écoles contre le reroll de l'étage suivant. Un verrou ne dure qu'un étage : **il faut re-payer à chaque fin d'étage** pour reconduire une protection, rien n'est acquis définitivement sur une run.

**Pourquoi ce système :** ça transforme la frustration passive ("mon sort préféré a disparu") en levier actif ("je dois jouer mieux — tuer plus, finir les puzzles — pour me donner le droit de le garder"). La récompense de skill devient de la stabilité, ce qui est exactement le bon contrepoids à un système dont la promesse est l'instabilité.

**En co-op : un pot commun.** Tous les joueurs alimentent la même réserve et y puisent pour leurs propres verrous. Ce choix crée une tension de négociation réelle — si un joueur verrouille son école entière, il ne reste plus grand-chose aux autres. C'est voulu : ça ajoute une décision collective à un jeu dont les builds sont, eux, individuels.

**Conséquence technique :** la dépense devient une **opération concurrente**. Deux joueurs peuvent acheter au même instant. Le host arbitre et sérialise les achats ; aucune double dépense ne doit être possible, et un achat refusé faute de fonds doit remonter immédiatement au joueur concerné.

**Sources de Résonance :**
- Kills de monstres (base du système)
- Bonus de complétion d'une salle puzzle optionnelle — résoudre un puzzle devient doublement gratifiant : loot + Résonance
- *(Autres sources à explorer en updates : élites, défis optionnels de salle)*

**Table de coûts de base :**

| Verrou | Coût de base | Règle de scaling |
|---|---|---|
| **Un sort précis** (l'effet actif dans un slot) | `X` Résonance | Ajustable à la main par sort — `X` sert de valeur par défaut si non spécifié |
| **Une école entière** | `Y` Résonance, fonction de la taille du pool | Plus le pool est grand, plus verrouiller retire d'incertitude → coûte plus cher. Ex : `Y = base_catégorie × taille_pool` |
| **Verrous multiples le même étage** | Multiplicateur cumulatif | 1er = ×1, 2e = ×1.5, 3e = ×2, 4e = ×3 (indicatif) — empêche de tout figer et de tuer l'identité du jeu |

> **⚠️ Question ouverte —** le multiplicateur cumulatif compte-t-il **par joueur** ou **par équipe** et par étage ?
> Par joueur : chacun gère son propre escalier de coûts, la tension vient uniquement du pot partagé.
> Par équipe : le 2e verrou de l'équipe coûte déjà plus cher même acheté par quelqu'un d'autre — forte compétition interne, risque de frustration.
> Les deux donnent des jeux très différents. À trancher en playtest, pas sur le papier.

**Note de conception importante :** chaque sort et chaque école doit pouvoir recevoir un **coût arbitraire choisi à la main** — mais la table ci-dessus sert de **valeur par défaut systématique**, pour qu'un nouveau sort ajouté sans coût explicite ne casse jamais le système par oubli. En pratique : le champ `coût_verrou` d'une Resource est **nullable**. Vide → calcul par la formule. Renseigné → override manuel. `0` reste une valeur valide et distincte de « non renseigné » : un sort délibérément gratuit à verrouiller doit rester exprimable.

**Toutes les valeurs numériques de cette section vivent dans une Resource de tuning unique**, éditable sans recompilation par un non-programmeur. Aucune valeur économique en dur dans le code.

---

## 4bis. Architecture — contenu piloté par données

**Principe directeur :** ajouter un sort, un monstre ou une salle ne doit jamais nécessiter de retoucher le code central — seulement créer une nouvelle donnée. C'est ce qui rend le projet réellement scalable en équipe et sur la durée.

Pattern : **Resources** (fichiers `.tres`) pour toute donnée de contenu, combinées à des classes de comportement génériques et réutilisables.

- **Sorts** : chaque effet = une `Resource` (dégâts, portée, cooldown, `coût_verrou`) + une implémentation de `Cast()`. Ajouter un sort = créer une Resource dans l'éditeur, zéro modification du code central.
- **Écoles** : une `Resource` référençant une liste de Resources-sorts de taille variable (2 à 5) — ajuster un pool ne touche à aucun code.
- **Monstres** : classe de base commune (mouvement, IA générique, dégâts) + une `Resource` de stats par type (vie, vitesse, dégâts, pattern, rendement de Résonance).
- **Salles** : scène (`.tscn`) avec métadonnées de catégorie (combat/élite/puzzle/repos) et connecteurs standardisés — permet à un non-programmeur de construire des salles dans l'éditeur.

**Bénéfice direct pour l'équipe :** un collaborateur non-dev (artiste, level designer) peut contribuer du contenu directement dans l'éditeur Godot, sans dépendre du programmeur pour chaque ajout. Cette promesse ne tient que si le workflow Git ne lui explose pas au visage — voir [CONTRIBUTING.md](../CONTRIBUTING.md).

---

## 5. Structure du donjon (V1)

### Génération procédurale par assemblage (pas de procgen géométrique)

Le donjon n'est **pas généré au sens géométrique** — c'est un **pool de salles pré-conçues à la main, assemblées algorithmiquement selon une seed**, sur le modèle Binding of Isaac / Enter the Gungeon / Dead Cells. Chaque run tire une seed, loggée, qui détermine l'enchaînement des salles.

En co-op, la seed est partagée par le host et **chaque client assemble le même donjon localement** — aucune géométrie ne transite sur le réseau.

**Pourquoi cette approche :** un roguelite vit sur l'impression de runs différents. Un pool de 12-18 templates combinés par seed multiplie les configurations sans multiplier le travail de contenu dans la même proportion — et chaque future update de biome n'a qu'à ajouter son propre pool au même générateur.

**Mécanique de génération (V1, volontairement simple) :**
- Chaque salle a des **connecteurs standardisés** (nord/sud/est/ouest) pour être assemblable sans gestion de géométrie au cas par cas
- Génération **linéaire avec embranchements optionnels** — pas de graphe complexe ni de BSP au lancement
- Catégories et règles de tirage par étage : combat (majorité), élite (1 garantie par étage), puzzle (0-1), repos (occasionnelle)
- Pool cible V1 : **12-18 templates**

### Salles puzzle : secondaires et skippables, jamais bloquantes

Les salles puzzle sont **optionnelles et positionnées hors du chemin critique**. Une run doit toujours pouvoir se terminer sans en résoudre une seule.

Ça simplifie considérablement le problème posé par la génération procédurale combinée au re-roll : si le joueur n'a roll aucun effet pertinent ce floor-ci, il **peut simplement ignorer** la salle. **Pas de vérification de solvabilité nécessaire côté générateur**, pas de frustration de blocage — juste une salle bonus (loot, Résonance) hors de portée ce run-ci, ce qui est cohérent avec l'esprit du jeu.

Cette décision supprime un problème entier. Ne pas la remettre en cause sans mesurer ce qu'elle économise.

Règle à garder si des puzzles obligatoires sont envisagés plus tard : préférer une **résolution par catégorie d'effet** (n'importe quel effet de mobilité) plutôt qu'un effet nommé précis.

*(Section à détailler avec des croquis de salles une fois la direction artistique posée.)*

---

## 6. Narration & Univers *(à développer)*

Piste de départ : le grimoire du joueur est corrompu depuis un événement non expliqué au lancement — chaque update peut révéler un fragment de cette histoire. Ça donne un moteur narratif naturellement compatible avec un modèle d'updates progressives.

*À enrichir une fois l'univers graphique posé — le ton (sombre ? absurde ? mélancolique ?) doit venir de la direction artistique autant que du gameplay.*

---

## 7. Direction artistique *(NON TRANCHÉE — bloque 13 tâches)*

**Tranché :** rendu **3D stylisé low-poly**, dans l'esprit de *Peak* ou *Yap Yap* — formes simples, palettes assumées, pas de visée photoréaliste. Cohérent avec le moteur et avec la structure en salles fermées, qui permet un éclairage maîtrisé par salle.

**Reste à définir :**
- Univers visuel :
- Palette de couleurs :
- Références (au-delà de *Peak* et *Yap Yap*) :
- Ton (sérieux / cartoon / horreur douce / autre) :

> Tant que cette section est vide, **13 tâches de contenu restent bloquées** : kit de salles, modèles de monstres et de joueur, VFX, éclairage, hub, et une partie du feedback. C'est le goulot le plus large du projet.

---

## 8. Direction sonore *(section ouverte — pour futur collaborateur)*

- Identité musicale :
- SFX signature : **le feedback sonore de la corruption de sort est le moment clé à soigner.** Il sera entendu à chaque étage de chaque run — il doit être identifiable entre tous et supporter la répétition.

---

## 9. Équipe & Production

| Rôle | Statut |
|---|---|
| Programmation / Game Design / Production | Paul-Abraham |
| Direction artistique / Art 2D-3D | À recruter |
| Sound Design / Musique | À recruter |

**Ce que ce GDD doit permettre à un futur collaborateur de comprendre en 5 minutes :** le cœur du jeu (section 4), le modèle de sortie (section 2), et où sa discipline s'insère (sections 7-8).

---

## 9bis. Décisions techniques tranchées

- **Moteur : Godot 4.x, build .NET** (4.7.2 au moment de la rédaction). Justifié pour un rendu 3D stylisé low-poly en environnements fermés : ce profil évite les points faibles connus de Godot en 3D (pas de monde ouvert à streamer, pas de photoréalisme, éclairage maîtrisable salle par salle). Licence MIT — zéro royalties.
  ⚠️ Le build standard de Godot **ne compile pas de C#**. Il faut explicitement la version « .NET ».
- **Langage : C#** — cohérent avec le typage fort déjà pratiqué (TS), transférable vers Unity si besoin, bon support natif dans Godot 4.
- **Réseau : Steam P2P host-autoritatif.** L'intégration Steamworks en C# sous Godot 4 fait l'objet d'un spike dédié (GodotSteam C# / Facepunch.Steamworks / Steamworks.NET) — décision à documenter dans [DECISIONS.md](DECISIONS.md).
- **Conséquence production :** peu d'assets 3D low-poly prêts à l'emploi dans l'écosystème Godot — la majorité des props et matériaux seront produits en interne plutôt qu'achetés. À anticiper dans le planning, et dans le quota Git LFS.

---

## 10. Risques & points de vigilance

- **Lisibilité** — un système où "on ne sait jamais ce que fait son bouton" devient frustrant plutôt qu'excitant si le feedback visuel et sonore n'est pas irréprochable à chaque cast. **Risque n°1.** Aggravé par le co-op : à 4 joueurs qui castent simultanément, chaque effet doit rester distinguable.
- **Équilibrage inter-écoles** — certains effets (Soin, Rempart) sont mécaniquement plus "safe" que d'autres (Mur de Flammes) ; surveiller que le re-roll ne punisse pas trop durement certaines compositions.
- **Le co-op en V1 est un pari.** Il double la surface technique avant même que la boucle solo soit validée. Mitigation : les fondations d'architecture de la section 11 sont traitées comme non négociables dès le premier cycle, et le gros du netcode arrive après une boucle solo complète.
- **Scope creep classique de l'indé** — rester disciplinés sur le contenu V1, résister à la tentation d'ajouter biomes et écoles avant d'avoir validé que la boucle centrale retient les joueurs.

---

## 11. Notes techniques — architecture

Le co-op étant désormais **dans la V1**, ces règles ne sont plus des précautions « au cas où » : ce sont des prérequis. Détail d'implémentation et critères de vérification dans [ARCHITECTURE.md](ARCHITECTURE.md).

1. **État centralisé** — un objet `GameState` clair (joueurs, ennemis, slots de sorts) plutôt que des propriétés éparpillées sur des nodes Godot. Doit être sérialisable en entier.
2. **Joueur en liste** — `players[0]` plutôt qu'un singleton `Player.instance`, même à un seul joueur. Chaque joueur porte un `PlayerId` stable.
3. **RNG seedé explicitement** — flux nommés et séparés par usage. Le flux de reroll d'un joueur dérive de `seed de run + PlayerId`. Seeds loggées dès la V1.
4. **Résolution des effets centralisée** — un seul module "effect resolver". Un `Cast()` produit une intention, il ne mute jamais l'état. Ordre de résolution déterministe et documenté.
5. **Signals Godot (event-driven)** plutôt que des appels directs entre systèmes.

---

*Prochaines étapes : (1) poser la direction artistique — c'est le plus gros déblocage disponible, (2) affiner la structure de donjon avec des croquis de salles, (3) définir les valeurs numériques précises dans un doc d'équilibrage séparé.*
