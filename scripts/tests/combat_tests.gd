class_name CombatTests
extends TestSuite
## Combat — monstres, dégâts et Résonance


func nom() -> String:
	return "Combat — monstres, dégâts et Résonance"


func execute() -> void:
	_check_monstres()


func _check_monstres() -> void:
	print("Monstres — dégâts, mort et Résonance")

	GameState.start_run(2024, 2)
	var id: int = GameState.spawn_monster(30, 25)
	var monstre: MonsterState = GameState.run.get_monster(id)

	verifie("le monstre est enregistré dans l'état de la run", monstre != null and monstre.hp == 30)

	_frappe_monstre(0, id, 10)
	EffectResolver.resolve_tick()
	verifie("il encaisse sans mourir", monstre.hp == 20 and monstre.is_alive(),
		"pv=%d" % monstre.hp)
	verifie("aucune Résonance tant qu'il vit", GameState.run.resonance_pool == 0)

	# Le joueur 1 porte le coup fatal, mais la récompense va au pot commun.
	_frappe_monstre(1, id, 50)
	EffectResolver.resolve_tick()
	verifie("il meurt sans passer en PV négatifs", monstre.hp == 0 and not monstre.is_alive())
	verifie("la récompense va au pot commun, pas au tueur",
		GameState.run.resonance_pool == 25, "pot=%d" % GameState.run.resonance_pool)

	# Frapper un cadavre ne doit pas re-créditer.
	_frappe_monstre(0, id, 10)
	EffectResolver.resolve_tick()
	verifie("un monstre déjà mort ne rapporte pas deux fois",
		GameState.run.resonance_pool == 25, "pot=%d" % GameState.run.resonance_pool)

	var avant: Dictionary = GameState.serialize()
	GameState.deserialize(avant)
	verifie("les monstres survivent à la sérialisation", GameState.serialize() == avant)

	GameState.advance_floor()
	verifie("les monstres sont vidés au changement d'étage",
		GameState.run.monsters.is_empty())


	## Le contenu est de la donnée : on vérifie qu'il se charge et qu'aucun
	## comportement déclaré n'a été oublié dans le registre.
	##
	## Cette dernière vérification transforme un oubli en échec de test, au lieu
	## d'un sort qui ne fait simplement rien une fois en jeu.


func _frappe_monstre(player_id: int, monster_id: int, degats: float) -> void:
	var intent := EffectIntent.new()
	intent.source_player_id = player_id
	intent.source_slot = 0
	intent.kind = EffectIntent.Kind.DAMAGE
	intent.amount = degats
	intent.target_monsters = PackedInt64Array([monster_id])
	EffectResolver.submit(intent)


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
