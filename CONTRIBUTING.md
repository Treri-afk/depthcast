# Contribuer à DepthCast

Ce document existe pour une raison précise : le [GDD](docs/GDD.md) promet qu'un artiste ou un level designer puisse ajouter du contenu **directement dans l'éditeur Godot**, sans dépendre du programmeur. Cette promesse ne tient que si Git ne leur explose pas au visage.

---

## Pour les non-développeurs

Tu n'as pas besoin de la ligne de commande. Installe un client graphique :

- **[GitHub Desktop](https://desktop.github.com/)** — le plus simple, gratuit
- **[Fork](https://git-fork.com/)** — plus complet, gère bien LFS

### Avant tout, une seule fois

Installe **Git LFS** ([git-lfs.com](https://git-lfs.com)). Sans lui, tu télécharges des fichiers texte de quelques octets à la place des modèles 3D et des textures.

### Le cycle normal

1. **Récupère** les dernières modifications (*Fetch* puis *Pull*) — toujours avant de commencer
2. **Pose un verrou** sur les fichiers binaires que tu vas modifier (voir plus bas)
3. **Travaille** dans Godot ou Blender
4. **Publie** — écris un message qui dit *quoi* et *pourquoi* ("ajoute la salle de repos avec 3 sorties" plutôt que "update")
5. **Libère le verrou**

---

## Le verrouillage de fichiers

**Le problème.** Un `.png`, un `.glb`, un `.wav` ne peuvent pas fusionner. Si deux personnes modifient le même fichier en parallèle, il n'y a pas de résolution possible : quelqu'un perd son travail.

**La solution.** Poser un verrou avant de toucher un binaire. Les autres voient le fichier comme verrouillé et ne peuvent pas le modifier tant que tu ne l'as pas libéré.

```bash
git lfs lock art/monstres/gobelin.glb     # avant de travailler
git lfs locks                             # qui a verrouillé quoi
git lfs unlock art/monstres/gobelin.glb   # une fois publié
```

GitHub Desktop et Fork proposent ces actions dans leur interface — pas besoin de taper les commandes.

**Règle simple :** tout ce qui n'est pas du texte se verrouille avant modification.

Les binaires sont marqués `lockable` dans `.gitattributes` : ils arrivent en **lecture seule** dans ta copie de travail. Si ton logiciel refuse d'enregistrer par-dessus, ce n'est pas un bug — c'est le rappel qu'il faut poser un verrou d'abord.

---

## Les scènes Godot : une scène, un propriétaire à la fois

Les `.tscn` et `.tres` sont du texte, donc versionnés en clair et diffables. **Mais ils fusionnent très mal** — leur structure est positionnelle, et un merge automatique produit régulièrement une scène corrompue plutôt qu'un conflit propre.

**Convention :** avant de modifier une scène existante, préviens. Si deux personnes doivent travailler dessus, découpez-la en sous-scènes.

**Ce qui rend ça vivable :** chaque salle du donjon est une scène indépendante ([GDD §5](docs/GDD.md#5-structure-du-donjon-v1)). Deux level designers peuvent donc travailler en parallèle sans jamais se croiser — à condition que le découpage le garantisse vraiment. Si tu te retrouves à devoir éditer la même scène que quelqu'un d'autre, c'est le signe que le découpage est à revoir.

---

## Pour les développeurs

### Branches

Trunk-based avec branches courtes. **Pas de push direct sur `main`** — on passe par une branche et une Pull Request.

⚠️ C'est une **discipline d'équipe, pas une contrainte technique** : la protection de branche sur dépôt privé demande GitHub Pro. Rien ne t'empêchera mécaniquement de pousser sur `main`. Voir [D6](docs/DECISIONS.md#d6--hébergement-du-dépôt--github-privé).

```bash
git switch -c feat/effect-resolver
# ... commits ...
git push -u origin feat/effect-resolver
# puis Pull Request
```

Une branche vit quelques jours, pas quelques semaines. Plus elle vit, plus elle diverge.

### Messages de commit

```
<type>: <ce qui change, à l'impératif>

<pourquoi, si ce n'est pas évident>
```

Types : `feat`, `fix`, `refactor`, `docs`, `chore`, `content` (ajout de Resources ou de salles).

Le code est en **GDScript typé statiquement** — les annotations de type ne sont pas optionnelles, voir [D7](docs/DECISIONS.md#d7--gdscript-plutôt-que-c).

Le *pourquoi* compte plus que le *quoi* — le diff dit déjà le quoi.

### Avant d'ouvrir une PR

Relis [ARCHITECTURE.md](docs/ARCHITECTURE.md). Les huit règles y sont formulées comme des **tests**, pas comme des principes. Si ton code ne passe pas l'un d'eux, c'est un problème structurel, pas une préférence de style.

Les trois erreurs qui coûtent le plus cher, dans l'ordre :

1. Un effet qui mute l'état sans passer par le resolver — casse le déterminisme co-op
2. Un `Random` appelé directement — casse le rejeu par seed et la synchronisation
3. Une valeur d'équilibrage en dur — rend le tuning impossible sans rouvrir un script

### Ajouter du contenu

Créer un sort, un monstre ou une salle **ne doit demander aucune modification de `.gd`**. Si tu dois ouvrir un script pour ajouter du contenu, le pattern data-driven est cassé quelque part — signale-le plutôt que de contourner.

---

## Git LFS — ce qui est suivi

Modèles (`.glb`, `.fbx`, `.blend`), textures (`.png`, `.jpg`, `.psd`, `.exr`), audio (`.wav`, `.ogg`, `.mp3`), polices. La liste complète est dans [`.gitattributes`](.gitattributes).

**Avant d'ajouter un nouveau type de binaire, ajoute-le au `.gitattributes` d'abord.** Un binaire commité hors LFS reste dans l'historique pour toujours — le retirer demande de réécrire tous les commits.

⚠️ Le plan GitHub gratuit donne **1 Go de stockage LFS et 1 Go de bande passante par mois**. Garde un œil dessus quand la production d'assets démarre : voir [D6](docs/DECISIONS.md#d6--hébergement-du-dépôt--github-privé) pour les options quand la limite approche.
