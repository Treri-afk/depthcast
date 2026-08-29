extends Node
## Bus d'évènements central — autoload `EventBus`.
##
## Implémente la règle R5 : aucun système n'appelle directement une méthode
## d'un autre système. Tout passe par un signal déclaré ici.
##
## Ce fichier est le catalogue d'évènements exigé par ARCHITECTURE.md. Il ne
## contient QUE des déclarations : pas d'état, pas de logique. Si tu es tenté
## d'ajouter une fonction ici, c'est qu'elle a sa place ailleurs.
##
## Convention de nommage : `<sujet>_<verbe au passé>`. Un signal annonce ce qui
## VIENT DE SE PASSER, jamais ce qu'il faudrait faire.

# ── Cycle de run ──────────────────────────────────────────────────────────
## Émis par GameState quand une run démarre. `run_seed` est loggée et affichable.
signal run_started(run_seed: int)
## Émis à l'entrée de chaque étage, APRÈS le reroll des slots non verrouillés.
signal floor_entered(floor_index: int)
## Émis en fin d'étage, AVANT le reroll suivant — c'est la fenêtre d'achat de verrous.
signal floor_completed(floor_index: int)
## Émis quand la run se termine, par mort ou par victoire.
signal run_ended(floor_reached: int, victory: bool)

# ── Joueurs ───────────────────────────────────────────────────────────────
signal player_registered(player_id: int)
signal player_left(player_id: int)

# ── Sorts ─────────────────────────────────────────────────────────────────
## Un slot a muté au changement d'étage. Le feedback de corruption écoute ça.
signal slot_rerolled(player_id: int, slot_index: int, effect_index: int)
## Un slot verrouillé a résisté au reroll — à distinguer visuellement d'une mutation.
signal slot_kept(player_id: int, slot_index: int)
## L'effet vient d'être lancé pour la première fois de l'étage : il sort de l'état `???`.
signal slot_discovered(player_id: int, slot_index: int)

## Le joueur vient d'encaisser. `origine` est le point d'où vient le coup, ce
## qui permet à l'interface de dire OÙ regarder — en vue subjective, prendre
## des dégâts hors champ sans indication est illisible.
signal player_damaged(player_id: int, degats: int, origine: Vector3)

## Le joueur vient d'être projeté par un souffle. Le son et la caméra écoutent ;
## aucun des deux n'a besoin de savoir QUI a déclenché l'explosion.
signal player_blasted(player_id: int, force: float, origine: Vector3)
## Le joueur vient de retoucher le sol au bout d'une projection. `vitesse` est
## la vitesse de chute : c'est elle qui dit si c'est une réception ou un impact.
signal player_slammed(player_id: int, vitesse: float)

# ── Décor ─────────────────────────────────────────────────────────────────
## Une explosion vient de partir — un tonneau aujourd'hui, un piège demain. Le
## son écoute ; rien d'autre n'a besoin de savoir d'où elle venait.
signal explosion_triggered(origine: Vector3, puissance: float)

# ── Monstres ──────────────────────────────────────────────────────────────
signal monster_spawned(monster_id: int)
signal monster_damaged(monster_id: int, hp_restant: int)
## Le feedback de mort et le drop de Résonance écoutent ça.
signal monster_died(monster_id: int, killer_player_id: int, recompense: int)

# ── Économies ─────────────────────────────────────────────────────────────
## Le pot commun a changé. `total` est la valeur autoritaire du host.
signal resonance_changed(total: int)
## Une dépense a été refusée. Voir GameState.try_spend_resonance().
signal resonance_spend_rejected(player_id: int, reason: String)
## Un verrou a été acheté et payé.
signal slot_locked(player_id: int, slot_index: int, cost: int, until_floor: int)
## Les Éclats d'un joueur ont changé (monnaie méta, individuelle).
signal eclats_changed(player_id: int, total: int)

# ── Résolution d'effets ───────────────────────────────────────────────────
## Une intention a été soumise au resolver. Elle n'a encore RIEN modifié.
signal intent_submitted(intent: EffectIntent)
## Une intention a été résolue et l'état a changé.
signal intent_resolved(intent: EffectIntent)
