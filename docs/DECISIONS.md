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
- Le choix de l'intégration Steamworks fait l'objet d'un spike dédié — GodotSteam en module compilé ou en GDExtension. **Décision à documenter ici une fois tranchée.** Voir aussi [D8](#d8--développement-steam-sur-lapp-id-public-480-transport-interchangeable) pour la façon dont on développe sans payer et sans second compte.

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

## D7 — GDScript plutôt que C#
**27 août 2026** · remplace le choix de langage du GDD v0.1 §9bis

**Décision.** Le projet est écrit en **GDScript, en typage statique**. Le build .NET de Godot n'est pas utilisé.

**Contexte.** La v0.1 retenait C# pour deux raisons : la cohérence avec le typage fort déjà pratiqué en TypeScript, et la transférabilité vers Unity en cas de changement de moteur.

**Pourquoi le changement.**
- **Réduire les inconnues simultanées.** Apprendre Godot *et* C#-dans-Godot en même temps rend chaque problème ambigu : moteur, langage, ou binding entre les deux ? Sur un projet solo de cette durée, c'est un coût permanent.
- **L'écosystème est GDScript-first.** La quasi-totalité des tutoriels, addons et réponses de forum sont en GDScript. Chaque problème rencontré aura sa réponse dans le bon langage.
- **Itération plus rapide.** Pas d'étape de compilation entre une modification et son test.
- **Le typage statique de GDScript couvre le besoin d'origine.** `var degats: int`, `func cast(cible: Node3D) -> void` : l'éditeur détecte les erreurs avant l'exécution. La raison qui motivait C# est satisfaite autrement.

**Écarté.** Rester en C# — la transférabilité vers Unity reste théorique et ne justifie pas de payer le coût d'apprentissage tout au long du projet.

**Compromis accepté.** GDScript est plus lent à l'exécution que C#. Sur ce profil de jeu — salles fermées, poignée de monstres simultanés — ce n'est pas contraignant. Si une boucle chaude pose un jour problème, elle se réécrit en GDExtension sans toucher au reste.

**Conséquences.**
- **Le typage statique n'est pas optionnel.** Sans annotations, GDScript redevient permissif — exactement ce qu'on cherchait à éviter en choisissant C#. C'est une règle de revue, pas une préférence.
- Le build standard de Godot suffit. Rien à installer côté .NET.
- Conventions de nommage : `snake_case` pour les variables et fonctions, `PascalCase` pour les classes. Les documents ont été mis à jour en conséquence (`player_id`, `cast()`, `players[0]`).
- Le spike Steamworks change de périmètre : GodotSteam devient le candidat naturel, au lieu de comparer trois bibliothèques C#.

---

## D8 — Développement Steam sur l'App ID public 480, transport interchangeable
**28 août 2026** · précise D2

**Décision.** Le développement et les tests se font avec l'**App ID 480**
(*Spacewar*), l'application publique de test fournie par Valve. La couche réseau
est écrite derrière une interface de transport, avec **ENet en local** et
**Steam Networking Sockets en production**.

**Contexte.** Publier sur Steam demande les 100 $ de Steam Direct (récupérables
au-delà de 1 000 $ de revenus). Rien n'oblige à les payer pour développer : l'App
ID 480 donne accès aux lobbies, aux invitations et au P2P.

**Le vrai problème, lui, n'est pas financier.** Steam refuse deux clients
connectés au même compte sur une même machine. Un développeur seul ne peut donc
pas tester une session à deux joueurs si la logique est soudée à Steam. Il
faudrait un second compte et une seconde machine — à chaque test.

**Conséquences.**
- Toute la logique réseau se développe et se débogue en ENet, avec autant
  d'instances locales que voulu, sans client Steam.
- Steam devient une couche de transport branchée par-dessus, plus une dépendance
  transverse. Formalisé en [R9](ARCHITECTURE.md#r9--le-transport-réseau-est-interchangeable).
- Les 100 $ ne se paient qu'au moment de publier.
- Limite connue de l'App ID 480 : il est partagé par tout le monde, donc la liste
  des lobbies est polluée. On filtre par métadonnée de lobby propre au jeu.
- Le client Steam doit tourner et être connecté pour tout test du transport Steam.

---

## D9 — Intégration Steam : GodotSteam en GDExtension
**29 août 2026** · résout le spike ouvert par [D2](#d2--topologie-réseau--p2p-host-autoritatif-via-steam)

**Décision.** GodotSteam en version **GDExtension**, et non en module compilé.

**Ce qui a été vérifié.**
- La GDExtension couvre **Godot 4.4 à 4.8**, donc notre 4.6.3. Version courante :
  GodotSteam 4.22, Steamworks SDK 1.65.
- Plateformes : Windows, Linux et **macOS** — la machine de développement est un Mac.
- Installation par l'AssetLib de l'éditeur ou en déposant l'archive dans le projet.
  Aucun build custom du moteur.

**Écarté : le module compilé.** Il impose un binaire Godot custom à *tout* le monde.
Un artiste devrait installer une version spéciale du moteur avant même d'ouvrir le
projet — ce qui contredit frontalement la promesse du GDD qu'un non-développeur
contribue sans friction. Les deux versions sont mutuellement incompatibles : le choix
se fait une fois.

**Pièges relevés, à ne pas découvrir en production.**
- **Exporter avec les templates Godot standards**, surtout pas ceux de GodotSteam.
  L'inverse provoque, selon la documentation du projet, « beaucoup de problèmes ».
- **L'overlay Steam ne fonctionne pas depuis l'éditeur**, uniquement dans un export.
  Toute validation d'invitation ou de lobby demande donc un build — ce qui renforce
  [R9](ARCHITECTURE.md#r9--le-transport-réseau-est-interchangeable) : le
  développement quotidien se fait en ENet, pas en tapant sur Steam.

**Non vérifié à ce stade.** L'initialisation réelle de l'API n'a pas été exécutée :
cela demande d'installer un binaire tiers dans le dépôt et un client Steam connecté.
À faire au moment de brancher le transport Steam (C7), pas avant — rien ne l'exige
tant que la logique réseau se développe en ENet.

**Rappel de [D8](#d8--développement-steam-sur-lapp-id-public-480-transport-interchangeable) :**
développement sur l'App ID public 480, les 100 $ de Steam Direct ne sont dus qu'à la
publication.

---

# Questions ouvertes

## D10 — Une explosion projette le joueur, et le ragdoll dure jusqu'à l'atterrissage
*Décidé le 29 août 2026*

Un souffle (`Souffle`) déplace trois choses avec la même courbe d'atténuation :
le mobilier, les monstres, et **le joueur**.

Ce n'est pas un ragdoll au sens strict — il n'y a pas de squelette à faire
s'affaler, et en vue subjective on ne le verrait pas. C'est la seule moitié qui
se transpose : **on ne conduit plus, on subit**, on ne peut plus lancer de sort,
et la vue se relâche.

### Deux phases, et c'est là qu'est le ressenti

**Le vol dure exactement tant qu'on n'a pas retouché le sol.** Aucun minuteur.
Un minuteur fixe donne la même secousse qu'on ait été déplacé de deux mètres ou
envoyé par-dessus une estrade ; en attendant l'atterrissage, la durée découle de
la trajectoire — donc de la violence de l'explosion — sans être calculée nulle
part.

**Le relevé, lui, est proportionnel à la vitesse reçue.** C'est la moitié qui
fait « plusieurs secondes » : après un gros souffle on ne se remet pas debout
comme après une bourrade. Mesuré au terrain d'essai, un souffle moyen à trois
mètres du centre donne 1,05 s de vol puis 1,2 s à terre — 2,3 s sans contrôle.
Un souffle violent approche les quatre secondes.

### La verticale est bornée, l'horizontale ne l'est pas

Premier essai : vingt mètres de haut, pour des murs qui en font cinq et demi. On
sortait du décor. `projection_hauteur_max` borne donc la seule composante
verticale — **on part loin, pas haut**. C'est aussi bien plus lisible : on voit
où l'on va atterrir.

### Le lanceur n'est pas toujours épargné

Chaque sort décide (`epargne_le_lanceur`) :

- **Répulsion et Attraction l'épargnent.** Le lanceur est le point d'ancrage :
  il pousse le monde, le monde ne le pousse pas. Une Attraction qui s'attirerait
  elle-même s'annulerait.
- **Nova ne l'épargne pas.** Le lanceur est au centre exact, donc le souffle le
  **soulève** — le cas « direction indéfinie » est traité comme une élévation, à
  dessein. Un sort défensif devient un outil de déplacement dès qu'un joueur y
  pense, sans qu'une règle ait eu à l'autoriser. Il le paie : on ne lance rien
  pendant qu'on vole.

### Tout est réglable

Groupe *Souffle et projection* du `Tuning` : part de puissance reçue, élévation,
seuil de déclenchement, plafond de vitesse, hauteur maximale, durée du relevé,
amortissement en vol, amplitude de la culbute, et un booléen pour rendre les
sorts pendant la projection. **Aucune de ces valeurs n'est écrite en dur.**

Le seuil mérite une mention : sans lui, un souffle lointain décolle le joueur
d'un demi-mètre, et ça ne se lit pas comme une explosion — ça se lit comme un
bug de collision.

---

## D11 — Entre joueurs : la poussée oui, les dégâts non
*Décidé le 29 août 2026*

Un souffle de sort projette **tous** les joueurs à portée, pas seulement son
lanceur. Une Répulsion catapulte le coéquipier qui passait par là.

Le dosage est toute la décision, et il est tranché dans un sens : **des dégâts
entre alliés font des disputes, une poussée seule fait de la comédie.** Personne
ne meurt de la main d'un ami, tout le monde le déteste trente secondes. Les
dégâts de sort continuent donc de ne viser que les monstres.

Une seule chose blesse sans regarder qui : la **braise laissée par un tonneau**.
Elle ne demande pas qui a allumé le feu, et c'est ce qui empêche de faire sauter
un baril à ses pieds sans y penser.

`epargne_le_lanceur` n'épargne que le lanceur, jamais ses alliés — c'est le sens
même du drapeau. Sur une Répulsion, celui qui lance est le point d'ancrage ; pas
toute l'équipe, qui n'a rien demandé.

**Non vérifiable pour l'instant** : le `PlayField` ne construit qu'une
`PlayerAvatar`. La logique passe par une liste (`SpellContext.joueurs`) plutôt
que par un avatar unique, donc brancher des coéquipiers ne demandera de toucher
à aucun sort. Mais le calibrage attend le cycle du netcode, ou un mannequin
coéquipier au terrain d'essai.

---

## D12 — Un seul verbe pour les mains : porter, poser, lancer
*Décidé le 29 août 2026*

Ramasser une caisse, un tonneau explosif ou une balise de leurre est **le même
geste**. Aucune mécanique d'inventaire séparée n'a été inventée pour les objets :
un objet du jeu est un corps du monde, et on le prend dans ses mains.

C'est ce qui rend le verbe évident et ce qui fait que le prochain objet — mine,
lanterne, fiole de poix — ne coûtera qu'une Resource et une classe.

**Porter coûte.** Vitesse réduite, sorts bloqués. Sans coût, porter serait
gratuit et il n'y aurait aucune décision entre traverser vite et traverser armé.
Porter un tonneau amorcé jusqu'à un groupe devient alors un vrai pari.

Une projection par souffle fait lâcher ce qu'on tient. Un corps qui part en
vrille ne garde pas un tonneau dans les bras.

Deux détails trouvés en mesurant plutôt qu'en calculant :

- Écrire `linear_velocity` juste après avoir dégelé un corps en fait perdre une
  partie. Une impulsion, elle, est appliquée au pas de simulation suivant, donc
  après le dégel. Depuis, la distance mesurée colle exactement à la balistique.
- À plat, la gravité du jeu — volontairement forte — plaque l'objet au sol en
  trois dixièmes de seconde. D'où `portage_arc` : un lancer sans arc ne sert à
  rien. Viser vers le haut reste le vrai levier, et c'est celui qui récompense
  le joueur.

---

## D13 — Le son du monde est situé ; celui qui parle de soi ne l'est pas
*Décidé le 29 août 2026*

Jusqu'ici tout passait par des `AudioStreamPlayer` 2D : une explosion à vingt
mètres claquait aussi fort qu'à ses pieds, et une mèche allumée derrière soi
était un bruit plutôt qu'une information. Dans un jeu en vue subjective où l'on
encaisse hors champ, c'est la moitié de l'information disponible qui manquait.

Chaque `SoundDef` déclare maintenant s'il appartient au monde, avec sa portée et
sa distance de référence. Une détonation porte à quatre-vingt-dix mètres, un
impact à trente-cinq : **la distance dit la gravité de ce qui se passe.**

Ce qui parle de SOI reste non situé — un achat, un refus, une mutation, sa
propre douleur. Les spatialiser les ferait varier selon l'orientation du joueur
au moment où il clique, ce qui est exactement le contraire d'un retour
d'interface. La direction d'un coup encaissé est déjà dite par l'interface.

**Le `où` passe par un signal, pas par le catalogue.** `sound_emitted(id,
origine)` ajoute la position sans obliger la moitié des évènements du bus à
transporter un `Vector3` dont un seul écouteur a besoin. Le jeu annonce, il
n'appelle toujours pas le son : couper l'audio ne demande de toucher aucun
système. Au passage, `SpellCaster` appelait `Audio.joue()` en direct, ce qui
contredisait cette règle depuis le début.

---

## D14 — Le ressenti est de la donnée, pas du code
*Décidé le 29 août 2026*

Quatre ajouts qui ne changent aucune règle et décident pourtant si le jeu est
bon.

**L'arrêt sur image.** Cinquante millisecondes de gel sur une mise à mort. Il
passe par l'échelle de temps globale, donc il touche la physique : d'où deux
garde-fous non négociables — très court, et jamais empilé. Deux morts
simultanées ne doivent pas figer le jeu deux fois plus longtemps. Son minuteur
ignore l'échelle de temps, sinon il serait ralenti par ce qu'il est censé
interrompre et durerait vingt fois trop.

**Les deux pardons du saut.** Le coyote laisse sauter un instant après avoir
quitté le sol ; le tampon retient un saut demandé un instant avant de toucher.
Personne ne sait nommer ces deux défauts, tout le monde les sent : sans eux,
sauter du bord d'une estrade échoue une fois sur trois et le joueur croit que sa
commande a été perdue.

**Le recul au lancer.** Une valeur PAR SORT, dans la Resource (R6). Une boule de
feu et un soin ne se lancent pas pareil, et ça se règle dans l'inspecteur sans
écrire une ligne. Le recul va vers le haut et se compense — c'est ce qui le
distingue d'une secousse, qui n'a pas de direction et se subit.

**Les chiffres de dégâts.** La seule chose du jeu qui dise si l'on progresse.
Sans eux, deux sorts dont l'un fait le double de dégâts de l'autre se
ressemblent : la créature blanchit dans les deux cas. Ils durent moins d'une
seconde — un chiffre qui traîne devient un tableau de bord, et on cesse de
regarder le combat.

---

## D15 — Le réseau local d'abord, Steam en dernier
*Décidé le 29 août 2026*

Le transport par défaut est **ENet**, en local et en LAN. Steam reste prévu pour
la distribution (D8, D9), mais il arrive en dernier et ne change rien au jeu.

Ce n'est pas une préférence technique, c'est une question de boucle de travail.
Steam impose Windows et un client lancé, alors que le co-op se conçoit et se
calibre **en jouant** : il faut pouvoir ouvrir deux fenêtres côte à côte,
essayer, refermer, recommencer. Un projet qui ne peut essayer son multijoueur
qu'en conditions de production ne l'essaie jamais — et découvre ses problèmes de
ressenti trois mois trop tard.

`NetTransport` est l'abstraction de R9. Le jeu demande à héberger ou à
rejoindre, il reçoit un pair, il s'en sert. Il ne sait pas lequel il utilise.

### Ce que l'étape 2 réplique, et ce qu'elle ne réplique pas

**Répliqué** : la session (qui joue, sous quel identifiant, qui fait autorité),
la graine de la run, et la position et le regard de chaque avatar.

**Pas encore répliqué** : les monstres, les dégâts, la Résonance, le mobilier.
Les deux machines partent du même donjon parce qu'elles partagent la graine,
puis **simulent chacune de leur côté et divergent**. C'est attendu, et c'est
l'objet de l'étape suivante : passer les intentions par le host, qui seul
résout, et diffuser le résultat.

Dire lesquels des deux on a fait est ce qui évite de croire le multijoueur
terminé parce que deux personnages se voient courir.

### Le corps distant ne calcule pas sa physique

Sa trajectoire est calculée chez son propriétaire. La recalculer localement
produirait deux vérités qui divergent — précisément ce que l'architecture
host-autoritaire existe pour empêcher. Chacun n'annonce que sa propre position :
personne ne peut déplacer le personnage d'un autre, et ce n'est pas une
politesse, c'est ce qui empêche un client bricolé de téléporter l'équipe.

### Hors ligne, la session répond en solo

`est_host()` vaut vrai, `nombre_de_joueurs()` vaut 1. Le code de gameplay ne
demande donc jamais « y a-t-il un réseau ? » avant de décider s'il a le droit
d'agir. **C'est la condition pour que le solo ne devienne pas un cas particulier
du multijoueur** — ce serait le meilleur moyen de le casser sans s'en apercevoir.
Un test le garde.

---

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
