extends Node
## Résolution centralisée des effets — autoload `EffectResolver`.
##
## Règle R4, la plus exigeante du projet. C'est l'arbitre : lui seul modifie
## l'état. Un sort produit une EffectIntent et la soumet ici ; il n'écrit jamais
## dans GameState lui-même.
##
## Pourquoi c'est non négociable : si chaque effet mutait l'état dans son coin,
## l'ordre d'application dépendrait de l'ordre d'arrivée des paquets réseau, et
## deux clients divergeraient. Ici les intentions sont accumulées sur un tick,
## triées par une clé stable, puis appliquées. Deux clients qui reçoivent les
## mêmes intentions dans des ordres différents aboutissent au même état.
##
## Ajouter un nouvel effet ne doit demander AUCUNE modification de ce fichier :
## seul le `match` sur `EffectIntent.Kind` connaît les familles d'effets, et
## elles sont volontairement peu nombreuses et génériques.

var _tick: int = 0
var _pending: Array[EffectIntent] = []
var _sequence: int = 0


## Soumet une intention. Ne modifie RIEN — elle attend la résolution du tick.
func submit(intent: EffectIntent) -> void:
	intent.tick = _tick
	intent.sequence = _sequence
	_sequence += 1
	_pending.append(intent)
	EventBus.intent_submitted.emit(intent)


## Résout toutes les intentions du tick courant, dans un ordre déterministe.
## Retourne le nombre d'intentions appliquées.
func resolve_tick() -> int:
	if _pending.is_empty():
		_advance_tick()
		return 0

	# LE point critique : le tri, pas l'ordre d'arrivée.
	_pending.sort_custom(EffectIntent.sort_intents)

	var applied: int = 0
	for intent: EffectIntent in _pending:
		_apply(intent)
		EventBus.intent_resolved.emit(intent)
		applied += 1

	_pending.clear()
	_advance_tick()
	return applied


func current_tick() -> int:
	return _tick


func pending_count() -> int:
	return _pending.size()


func _advance_tick() -> void:
	_tick += 1
	_sequence = 0


## Application effective. C'est le SEUL endroit du projet qui a le droit
## d'écrire dans l'état de gameplay.
func _apply(intent: EffectIntent) -> void:
	# Un sort lancé sort de l'état `???` — et c'est bien à portée étage,
	# puisqu'on mémorise l'étage courant et non un booléen.
	if intent.source_slot >= 0 and GameState.is_in_run():
		var caster: PlayerState = GameState.run.get_player(intent.source_player_id)
		if caster != null and intent.source_slot < caster.slots.size():
			var slot: SpellSlot = caster.slots[intent.source_slot]
			if not slot.is_discovered_on(GameState.run.floor_index):
				slot.mark_discovered(GameState.run.floor_index)
				EventBus.slot_discovered.emit(intent.source_player_id, intent.source_slot)

	match intent.kind:
		EffectIntent.Kind.DAMAGE:
			_apply_damage(intent)
		EffectIntent.Kind.HEAL:
			_apply_heal(intent)
		EffectIntent.Kind.MOVE, EffectIntent.Kind.SPAWN, EffectIntent.Kind.APPLY_STATUS:
			# À implémenter avec le combat (cycle C3) et les écoles (C4).
			pass


func _apply_damage(intent: EffectIntent) -> void:
	if not GameState.is_in_run():
		return

	# Cibles joueurs. Note de design ouverte : les sorts ratés peuvent-ils
	# toucher un coéquipier ? Rien ne l'interdit dans cette structure — c'est un
	# choix de gameplay, pas une contrainte technique.
	for target_id: int in intent.target_ids:
		var target: PlayerState = GameState.run.get_player(target_id)
		if target != null:
			target.hp = maxi(0, target.hp - int(intent.amount))

	# Cibles monstres. La récompense de Résonance part au pot COMMUN (D3),
	# quel que soit le joueur qui a porté le coup fatal.
	for monster_id: int in intent.target_monsters:
		var monster: MonsterState = GameState.run.get_monster(monster_id)
		if monster == null:
			continue
		var tue: bool = monster.take_damage(int(intent.amount))
		EventBus.monster_damaged.emit(monster_id, monster.hp)
		if tue:
			GameState.add_resonance(monster.resonance_reward)
			EventBus.monster_died.emit(
				monster_id, intent.source_player_id, monster.resonance_reward
			)


func _apply_heal(intent: EffectIntent) -> void:
	if not GameState.is_in_run():
		return
	for target_id: int in intent.target_ids:
		var target: PlayerState = GameState.run.get_player(target_id)
		if target != null:
			target.hp = mini(target.max_hp, target.hp + int(intent.amount))
