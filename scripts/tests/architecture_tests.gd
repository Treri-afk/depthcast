class_name ArchitectureTests
extends TestSuite
## Architecture — R1, R3 et R4


var _rerolls: Array = []


func _init() -> void:
	EventBus.slot_rerolled.connect(func(j: int, s: int, e: int) -> void:
		_rerolls.append([j, s, e]))


func nom() -> String:
	return "Architecture — R1, R3 et R4"


func execute() -> void:
	_check_r3_determinisme()
	_check_r1_serialisation()
	_check_r4_ordre_deterministe()


func _check_r3_determinisme() -> void:
	print("R3 — RNG seedé et reproductible")

	var first: Array = _run_scenario(4242)
	var second: Array = _run_scenario(4242)
	var different: Array = _run_scenario(9999)

	verifie("la même seed rejoue les mêmes rerolls", first == second,
		"\n     %s\n     %s" % [first, second])
	verifie("une seed différente donne autre chose", first != different)


	## R1 — l'état complet survit à un aller-retour de sérialisation.


func _check_r1_serialisation() -> void:
	print("R1 — état centralisé et sérialisable")

	GameState.start_run(777, 2)
	GameState.add_resonance(120)
	GameState.try_lock_slot(0, 1, 30)
	GameState.advance_floor()

	var avant: Dictionary = GameState.serialize()
	GameState.deserialize(avant)
	var apres: Dictionary = GameState.serialize()

	verifie("sérialiser puis recharger redonne le même état", avant == apres)
	verifie("le pot commun a bien été débité", int(avant["resonance_pool"]) == 90,
		"attendu 90, obtenu %s" % avant["resonance_pool"])


	## R4 — l'ordre de soumission n'influence pas le résultat.


func _check_r4_ordre_deterministe() -> void:
	print("R4 — résolution déterministe des effets")

	var direct: int = _resolve_two_casts(false)
	var inverse: int = _resolve_two_casts(true)

	verifie("deux ordres d'arrivée donnent le même état final", direct == inverse,
		"direct=%d inversé=%d" % [direct, inverse])


	## Un verrou protège l'étage suivant, et seulement lui.


func _frappe_monstre(player_id: int, monster_id: int, degats: float) -> void:
	var intent := EffectIntent.new()
	intent.source_player_id = player_id
	intent.source_slot = 0
	intent.kind = EffectIntent.Kind.DAMAGE
	intent.amount = degats
	intent.target_monsters = PackedInt64Array([monster_id])
	EffectResolver.submit(intent)


func _run_scenario(seed_value: int) -> Array:
	_rerolls.clear()
	GameState.start_run(seed_value, 2)
	for i: int in 3:
		GameState.complete_floor()
		GameState.advance_floor()
	return _rerolls.duplicate(true)


func _cast(player_id: int, slot: int, amount: float, targets: Array) -> EffectIntent:
	var intent := EffectIntent.new()
	intent.source_player_id = player_id
	intent.source_slot = slot
	intent.kind = EffectIntent.Kind.DAMAGE
	intent.amount = amount
	intent.target_ids = PackedInt64Array(targets)
	EffectResolver.submit(intent)
	return intent


## Deux joueurs frappent la même cible au même tick. On soumet dans un ordre,
## puis dans l'autre. Le résultat doit être identique.
func _resolve_two_casts(inverser: bool) -> int:
	GameState.start_run(1000, 2)
	var cible: PlayerState = GameState.run.players[1]
	cible.hp = 100
	if inverser:
		_cast(1, 0, 30, [1])
		_cast(0, 0, 7, [1])
	else:
		_cast(0, 0, 7, [1])
		_cast(1, 0, 30, [1])
	EffectResolver.resolve_tick()
	return cible.hp
