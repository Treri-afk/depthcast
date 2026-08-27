# Architecture — règles non négociables

Ce document traduit la [section 11 du GDD](GDD.md#11-notes-techniques--architecture) en contraintes vérifiables. Le co-op étant dans le scope V1 ([D1](DECISIONS.md#d1--le-co-op-2-4-joueurs-passe-dans-le-scope-v1)), ces règles ne sont pas des précautions : les enfreindre coûte une réécriture, pas un refactor.

**Comment lire ce document :** chaque règle a un *pourquoi*, une *formulation opérationnelle*, et un *test* — une question dont la réponse se vérifie en lisant le code, pas en discutant.

---

## R1 — Tout l'état vit dans `GameState`

**Pourquoi.** Un état éparpillé sur des nodes Godot ne peut être ni sérialisé, ni répliqué, ni rejoué depuis une seed. Les trois sont des besoins V1.

**Opérationnel.**
- Un objet racine détient joueurs, ennemis, slots de sorts, étage courant, seeds, économies.
- Aucune donnée de gameplay n'est stockée en propriété libre sur un node.
- Les nodes *affichent* l'état ; ils ne le détiennent pas.
- L'écriture passe par des méthodes explicites, pas des champs publics mutables.

**Test.** Puis-je sérialiser l'intégralité de la partie en cours, tuer le processus, le relancer et reprendre exactement où j'en étais ? Si non, il reste de l'état ailleurs.

---

## R2 — Les joueurs sont une collection, jamais un singleton

**Pourquoi.** `Player.Instance` est une hypothèse « il n'y en a qu'un » gravée dans chaque appel. La retirer plus tard, c'est toucher tous les fichiers qui l'utilisent.

**Opérationnel.**
- `Players[0]` fonctionne dès le solo. Aucun `Player.Instance` nulle part.
- Chaque joueur porte un `PlayerId` stable, utilisé par le RNG, les verrous et la réplication.
- Les systèmes qui agissent sur « le joueur » prennent un `PlayerId` en paramètre.

**Test.** Instancier 4 joueurs locaux casse-t-il un système ? Si oui, ce système suppose l'unicité.

---

## R3 — Tout aléatoire passe par un flux seedé et nommé

**Pourquoi.** Le co-op exige que tous les clients arrivent au même donjon. Le rejeu par seed exige que la même run redonne les mêmes tirages. Un `Random` anonyme quelque part suffit à casser les deux.

**Opérationnel.**
- Flux séparés par usage : génération de donjon, re-roll (**un flux par joueur**), loot, comportements.
- Le flux de re-roll d'un joueur dérive de `seed de run + PlayerId` — déterministe, reproductible, jamais influencé par les autres joueurs ([D4](DECISIONS.md#d4--builds-indépendants-par-joueur)).
- La seed de run est affichée, copiable, et loggée à chaque étage.
- Aucun appel direct à un générateur aléatoire global.

**Test.** Deux clients qui reçoivent la même seed produisent-ils le même donjon ? Rejouer une seed avec la même équipe redonne-t-il les mêmes re-rolls ?

---

## R4 — Un seul Effect Resolver

**Pourquoi.** C'est la règle la plus exigeante, et celle qui conditionne le reste. Si chaque effet mute l'état dans son coin, l'ordre de résolution dépend de l'ordre d'arrivée réseau — donc diverge entre clients.

**Opérationnel.**
- `Cast()` **produit une intention**. Il ne mute jamais l'état.
- Aucun effet n'écrit dans `GameState` en dehors du resolver.
- L'ordre de résolution est déterministe et documenté. Les effets simultanés de plusieurs joueurs sont résolus dans un ordre **stable**, pas dans l'ordre d'arrivée des paquets.
- Ajouter un effet ne demande aucune modification du resolver.

**Test.** Deux joueurs castent au même tick, dans un ordre réseau inversé selon le client. Les deux clients aboutissent-ils au même état ?

---

## R5 — Communication par signals

**Pourquoi.** Des appels directs entre systèmes créent un graphe de dépendances qui rend impossible d'insérer une couche réseau entre eux.

**Opérationnel.**
- Catalogue d'événements documenté : nom, payload, émetteur, abonnés attendus.
- Aucun système n'appelle directement une méthode d'un autre système.
- Convention de nommage établie et appliquée.

**Test.** Puis-je insérer un intercepteur qui logge ou retarde un événement, sans modifier ni l'émetteur ni le récepteur ?

---

## R6 — Le contenu est de la donnée, pas du code

Formalise la [section 4bis du GDD](GDD.md#4bis-architecture--contenu-piloté-par-données).

**Pourquoi.** C'est ce qui permet à un artiste ou un level designer de contribuer sans passer par le programmeur. La promesse ne vaut que si elle est vraie à 100 % : une seule exception et le goulot revient.

**Opérationnel.**

| Contenu | Donnée | Code |
|---|---|---|
| Effet de sort | `Resource` : dégâts, portée, cooldown, `coût_verrou` | Comportement générique paramétré |
| École | `Resource` : identité + liste de 2 à 5 effets | — |
| Monstre | `Resource` : vie, vitesse, dégâts, pattern, rendement | Classe de base commune |
| Salle | `.tscn` + métadonnées de catégorie + connecteurs | Générateur agnostique |

- Aucune boucle ne suppose une taille de pool fixe. 2 et 5 doivent fonctionner sans cas particulier.
- Le générateur de donjon ne connaît pas les biomes : ajouter un biome = ajouter un pool de salles.

**Test.** Ajouter un sort, un monstre ou une salle demande-t-il d'ouvrir un fichier `.cs` ? Si oui, la règle est enfreinte.

---

## R7 — Les valeurs numériques sont éditables sans recompiler

**Pourquoi.** L'équilibrage est un travail itératif à haute fréquence. S'il faut une compilation C# par ajustement, il n'aura pas lieu.

**Opérationnel.**
- Une Resource de tuning unique contient : `X` (coût de verrou par sort), `Y` (base catégorie par école), multiplicateurs cumulatifs, rendements de Résonance, courbe de difficulté, règles de tirage de salles.
- Modifiable dans l'inspecteur par un non-programmeur.
- Aucune valeur d'équilibrage en dur ailleurs.

**Le cas `coût_verrou` mérite une attention particulière.** Le champ est **nullable** :

| Valeur | Sens |
|---|---|
| *(vide)* | Calculer via la formule par défaut |
| `0` | Coût réel de zéro — verrou gratuit, choix délibéré |
| `12` | Override manuel |

Ne **jamais** utiliser `0` comme sentinelle d'absence. Un sort ajouté sans coût défini doit tomber sur la formule, jamais casser le système par oubli — c'est la note de conception explicite du [GDD §4](GDD.md#4-système-de-sorts).

---

## R8 — Le client n'a pas autorité

Découle de [D2](DECISIONS.md#d2--topologie-réseau--p2p-host-autoritatif-via-steam).

**Opérationnel.**
- Les clients envoient des intentions ; le host décide et diffuse les résultats.
- Un client ne peut pas s'attribuer de la Résonance, valider un verrou, ni déclarer un kill.
- La dépense sur le pot commun est sérialisée par le host : **aucune double dépense**, et un refus faute de fonds remonte immédiatement au joueur concerné ([D3](DECISIONS.md#d3--résonance-en-pot-commun-partagé)).
- Aucune géométrie de salle ne transite : seulement la seed et l'index d'étage.

**Test.** Un client modifié peut-il se donner de la Résonance ? La réponse doit être non par construction, pas par confiance.

---

## Pièges spécifiques à ce projet

**L'état `???` est à portée étage.** Un effet reste masqué tant qu'il n'a pas été lancé sur l'étage **en cours**. Il se réinitialise à chaque changement d'étage — y compris pour un slot verrouillé, qui redevient `???` tant qu'il n'est pas relancé. Ce n'est ni un flag de run, ni un flag de profil. En co-op, chaque joueur a son propre état de découverte.

**Un verrou dure exactement un étage.** Il faut re-payer à chaque fin d'étage. Rien n'est acquis définitivement sur une run.

**L'ordre en fin d'étage est : achat des verrous, PUIS re-roll des slots non verrouillés.** L'inverse rendrait les verrous inutiles.

**Éclats et Résonance ne partagent aucun code.** Deux types distincts, deux stockages distincts, aucune conversion. La Résonance n'est **jamais** persistée.
