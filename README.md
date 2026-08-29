# DepthCast

> Un donjon roguelite coopératif où la magie ne t'obéit jamais complètement — tes sorts changent de nature à chaque étage, et maîtriser le chaos devient la vraie compétence.

**Godot 4.x · GDScript typé · 3D stylisé low-poly · co-op 2-4 joueurs via Steam**

---

## Par où commencer

| Tu es… | Lis ça |
|---|---|
| **Nouveau sur le projet** | [GDD](docs/GDD.md) — 10 minutes, tu comprends le jeu |
| **Développeur** | [ARCHITECTURE.md](docs/ARCHITECTURE.md) — les règles non négociables, à lire **avant** le premier commit |
| **Artiste / Level designer** | [CONTRIBUTING.md](CONTRIBUTING.md) — comment contribuer sans ligne de commande |
| **Tu veux savoir pourquoi X** | [DECISIONS.md](docs/DECISIONS.md) — le journal des décisions |

Le suivi des tâches est dans Plane, projet `DEPTH`.

### Jouer à plusieurs

Le menu propose **Héberger une partie** et **Rejoindre**. Le transport par
défaut est le réseau local (ENet) : deux instances du jeu sur la même machine se
parlent en `127.0.0.1`, sans compte, sans client tiers, sans connexion Internet.

**Steam n'est pas nécessaire pour développer ni pour essayer le co-op.** Il
viendra remplacer le tuyau pour la distribution — traverser les box des joueurs,
inviter des amis — et rien d'autre. C'est tout l'objet de
[R9](docs/ARCHITECTURE.md) : le jeu ne connaît jamais son transport.

Lancer deux instances sur la même machine :

```
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

deux fois, dans deux terminaux. Depuis l'éditeur, `Débogage → Exécuter plusieurs
instances → 2`.

Pour vérifier la session sans ouvrir de fenêtre, la sonde réseau :

```
Godot --headless --path . res://tools/sonde.tscn -- host   # terminal 1
Godot --headless --path . res://tools/sonde.tscn           # terminal 2
```

Les deux doivent afficher le même salon et la même graine.

### Le terrain d'essai

Le menu principal propose **Terrain d'essai** : une salle sans enjeu où l'on ne
meurt pas, avec des mannequins dont on peut couper l'IA et qui affichent leurs
points de vie, une fosse qui explose en boucle à puissance réglable, un étal de
mobilier qui se réarme, un portique gradué tous les quatre mètres et un pupitre
qui rejoue le reroll à la demande.

C'est l'outil de calibrage du projet. Une sensation — la portée d'un sort, la
violence d'une projection, le rythme du reroll — ne se règle pas en lisant un
nombre : il faut la subir vingt fois d'affilée en changeant un réglage entre
deux essais. Le donjon rend chacune de ces boucles trop longue, donc on ne les
fait pas, donc rien ne se règle.

Le terrain monte le **même** `PlayField` que le jeu : même joueur, même HUD,
mêmes sorts, mêmes matériaux, mêmes monstres. Un banc d'essai qui reconstruit
une version simplifiée de ce qu'il mesure finit par ne mesurer que lui-même.

---

## Installation

### 1. Godot — build standard

Version 4.x, build standard. Le build **.NET n'est pas nécessaire** : le projet est en GDScript ([D7](docs/DECISIONS.md#d7--gdscript-plutôt-que-c)).

Téléchargement : [godotengine.org/download](https://godotengine.org/download)

### 2. Git LFS

Indispensable **avant** de cloner : sans lui, tu récupères des fichiers texte de quelques octets à la place des modèles et des textures.

```bash
brew install git-lfs   # macOS
git lfs install
```

### 3. Cloner

```bash
git clone <url-du-dépôt>
cd DepthCast
git lfs pull
```

Ouvre ensuite `project.godot` depuis Godot. Le premier lancement régénère le cache `.godot/` — c'est normal, il est ignoré par Git.

---

## Structure

```
DepthCast/
├── docs/
│   ├── GDD.md            Game Design Document
│   ├── ARCHITECTURE.md   Règles techniques non négociables
│   └── DECISIONS.md      Journal des décisions et questions ouvertes
├── scenes/               Scènes Godot (.tscn)
├── scripts/              Code GDScript (typé statiquement)
├── resources/            Données de contenu (.tres) — sorts, écoles, monstres, tuning
├── art/                  Assets 3D, textures (Git LFS)
└── audio/                Sons et musique (Git LFS)
```

Le découpage `resources/` sépare **la donnée du comportement** : ajouter un sort, un monstre ou une salle ne doit jamais demander d'ouvrir un fichier `.gd`. Voir [R6](docs/ARCHITECTURE.md#r6--le-contenu-est-de-la-donnée-pas-du-code).

---

## Les cinq règles à connaître avant de coder

Détaillées et testables dans [ARCHITECTURE.md](docs/ARCHITECTURE.md). En résumé :

1. **Tout l'état vit dans `GameState`** — sérialisable en entier
2. **Les joueurs sont une collection**, jamais un singleton — `players[0]` dès le solo
3. **Tout aléatoire passe par un flux seedé et nommé** — un flux de re-roll par joueur
4. **Un seul Effect Resolver** — `cast()` produit une intention, ne mute rien
5. **Communication par signals**, pas d'appels directs entre systèmes

Le code est en **GDScript typé statiquement**. Les annotations (`var degats: int`, `func cast(cible: Node3D) -> void`) ne sont pas optionnelles : sans elles, on perd la détection d'erreurs à l'édition.

Le co-op est dans le scope V1. Ces règles ne sont pas des précautions : les enfreindre coûte une réécriture.

---

## État du projet

**Pré-production.** Le backlog V1 est posé (83 tâches, 9 cycles). Le développement démarre par les fondations techniques et le pipeline de collaboration.

**Non tranché :** la direction artistique et la direction sonore. 13 tâches en dépendent — c'est le plus gros déblocage disponible.
