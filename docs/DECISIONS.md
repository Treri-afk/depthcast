# Journal des décisions

Une entrée par décision structurante. Le [GDD](GDD.md) dit **ce qu'est le jeu** ; ce journal dit **pourquoi il a changé**.

Format : une décision, son contexte, ce qui a été écarté, et ses conséquences concrètes. Ne jamais réécrire une entrée passée — si une décision est renversée, on en ajoute une nouvelle qui la remplace explicitement.

---

## D1 — Le co-op 2-4 joueurs passe dans le scope V1
**27 août 2026** · remplace la position « en suspens » du GDD v0.1 §2

**Décision.** Le multijoueur coopératif 2 à 4 joueurs via Steam fait partie de la V1, et non plus d'une update majeure.

**Contexte.** Le GDD v0.1 classait le co-op comme candidat pour l'Update 2 ou 3, en attendant que la boucle solo soit validée. Le co-op est un argument de vente fort pour un roguelite, et le reporter signifiait construire une V1 puis rouvrir toute l'architecture ensuite.

**Écarté.** Garder le co-op en update — plus sûr en termes de scope, mais force à revenir sur l'état, le RNG et la résolution d'effets une fois le solo figé.

**Conséquences.**
- Les 5 règles d'architecture du §11 ne sont plus des précautions optionnelles : ce sont des prérequis à respecter dès le premier commit.
- Un module de backlog entier (9 tâches) est dédié au netcode.
- Le risque de scope augmente. Mitigation : le gros du netcode est planifié **après** une boucle solo complète et jouable, pour que ce soit un chantier ciblé et non une réécriture.

---

## D2 — Topologie réseau : P2P host-autoritatif via Steam
**27 août 2026**

**Décision.** Un joueur héberge la session et fait autorité sur l'état du jeu. Transport via les Steam Networking Sockets.

**Écarté.** Serveur dédié — autorité neutre et vraie protection anti-triche, mais coût d'infrastructure et de déploiement injustifié pour du co-op PvE entre amis.

**Conséquences.**
- Les clients envoient des **intentions**, jamais des résultats. Un client ne peut pas s'auto-attribuer de la Résonance ni un verrou.
- La perte du host termine la session. La migration d'host est hors scope V1.
- Le choix de la bibliothèque d'intégration Steamworks en C# (GodotSteam C# / Facepunch.Steamworks / Steamworks.NET) fait l'objet d'un spike dédié — **décision à documenter ici une fois tranchée**.

---

## D3 — Résonance en pot commun partagé
**27 août 2026** · précise le GDD v0.1 §4, muet sur le cas co-op

**Décision.** En co-op, la Résonance générée par les kills de tous les joueurs alimente une **réserve unique**. Chaque joueur y puise pour verrouiller ses propres sorts.

**Écarté.**
- *Portefeuilles individuels* — plus simple à synchroniser, zéro négociation, mais le co-op se réduit à quatre parties solo côte à côte.
- *Portefeuilles + don manuel* — plus riche, mais une feature réseau de plus en V1.

**Conséquences.**
- Une **tension de négociation réelle** apparaît : si un joueur verrouille son école entière, il ne reste plus grand-chose aux autres. C'est l'intérêt du choix.
- La dépense devient une **opération concurrente**. Le host sérialise les achats ; aucune double dépense possible ; un refus faute de fonds doit remonter immédiatement.
- L'UI de fin d'étage doit montrer le solde commun **en direct** et qui achète quoi. Le pot est commun, l'information doit l'être aussi.
- Ouvre une question non tranchée — voir Q1 plus bas.

---

## D4 — Builds indépendants par joueur
**27 août 2026** · tranche la question ouverte du GDD v0.1 §2

**Décision.** Chaque joueur choisit ses 4 écoles librement, sans contrainte d'unicité, et re-roll ses propres sorts. Chacun a son propre flux d'aléatoire.

**Écarté.** Table de re-roll partagée — tout le monde découvre les mêmes corruptions au même moment, plus simple à synchroniser et renforce le moment social « on panique ensemble ». Mais supprime la profondeur stratégique individuelle.

**Conséquences.**
- Le flux RNG d'un joueur dérive de `seed de run + PlayerId` : déterministe, rejouable, jamais influencé par les actions des autres.
- Le re-roll d'un joueur n'affecte jamais les slots d'un autre.
- Rejouer une run avec la même seed **et la même composition d'équipe** doit redonner exactement les mêmes re-rolls.
- Combiné à D3, ça donne la structure du jeu en co-op : **builds individuels, économie collective**.

---

## D5 — Chat vocal de proximité hors V1
**27 août 2026**

**Décision.** Pas de voix intégrée en V1. Repoussé en Update 2.

**Contexte.** Le GDD v0.1 évoquait un chat de proximité type Steam comme partie intégrante du co-op.

**Conséquences.** Réduit nettement la surface réseau de la V1 (pas de capture, d'encodage, de spatialisation 3D, ni de contrôles de mute et volume). Les joueurs utilisent Discord en attendant.

---

## D6 — Hébergement du dépôt : GitHub privé
**27 août 2026**

**Décision.** Dépôt privé sur GitHub, avec Git LFS pour les binaires.

**Écarté.**
- *GitLab auto-hébergé existant* — c'est une instance professionnelle. Un projet personnel sur l'infra d'un employeur pose une zone grise sur la propriété du code.
- *Gitea/Forgejo sur le VPS personnel* — LFS illimité et gratuit, ressources suffisantes (46 Go libres, 4 Go de RAM disponible). Mais **le VPS n'a aucune sauvegarde configurée**, et il fait déjà tourner de la production. Y héberger la seule copie de 18 mois de travail est un mauvais échange contre 5 $/mois.

**Conséquences.**
- Limite LFS du plan gratuit : **1 Go de stockage et 1 Go de bande passante par mois**. Suffisant pour du code et des docs, insuffisant dès qu'un artiste produit en volume.
- Point de bascule prévu : data pack GitHub à 5 $/mois pour 50 Go, ou migration vers Forgejo auto-hébergé **une fois des sauvegardes testées en place** — pas seulement configurées.
- Migrer LFS reste faisable tant que l'historique est jeune. À réévaluer avant que le volume d'assets décolle.

---

# Questions ouvertes

## Q1 — Le multiplicateur cumulatif de verrous : par joueur ou par équipe ?
*Ouverte depuis le 27 août 2026 — conséquence directe de D3*

Les verrous successifs d'un même étage coûtent de plus en plus cher (indicatif : ×1, ×1.5, ×2, ×3) pour empêcher de tout figer et de tuer l'identité du jeu. Avec un pot commun, ce compteur peut se lire de deux façons :

- **Par joueur** — chacun gère son propre escalier de coûts. La tension vient uniquement du partage du pot.
- **Par équipe et par étage** — le 2e verrou de l'équipe coûte déjà plus cher, même acheté par quelqu'un d'autre. Compétition interne beaucoup plus forte, mais risque réel de frustration ("il a verrouillé avant moi et maintenant je paie le double").

Les deux donnent des jeux très différents. **À trancher en playtest, pas sur le papier.**

## Q2 — Ciblage co-op de certains effets
*Ouverte depuis le 27 août 2026*

- Le **Soin** (Vie) peut-il cibler un allié, et comment ?
- À qui appartiennent les **Invocations** (Vie) ?
- Le **Voile** (Ombre) n'affecte-t-il que son lanceur ?

## Q3 — La difficulté s'ajuste-t-elle au nombre de joueurs ?
*Ouverte depuis le 27 août 2026*

Un donjon calibré pour un joueur devient trivial à quatre. Scaling des HP, du nombre d'ennemis, des deux ? Et le rendement de Résonance suit-il ?

## Q4 — Direction artistique et direction sonore
*Ouvertes depuis la v0.1 du GDD*

Non tranchées. **13 tâches du backlog en dépendent** — c'est le plus gros déblocage disponible sur le projet.
