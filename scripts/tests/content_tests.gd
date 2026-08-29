class_name ContentTests
extends TestSuite
## Contenu — Resources et registre


func nom() -> String:
	return "Contenu — Resources et registre"


func execute() -> void:
	_check_contenu()


func _check_contenu() -> void:
	print("Contenu — Resources et registre de comportements")

	verifie("les écoles se chargent depuis resources/", Content.ecoles.size() >= 5,
		"%d trouvée(s)" % Content.ecoles.size())
	verifie("les monstres se chargent depuis resources/", Content.monstres.size() >= 3,
		"%d trouvé(s)" % Content.monstres.size())
	verifie("la table de tuning existe", Content.tuning != null)

	var hors_bornes: Array = []
	for e: School in Content.ecoles:
		if e.taille_pool() < School.POOL_MIN or e.taille_pool() > School.POOL_MAX:
			hors_bornes.append("%s(%d)" % [e.nom, e.taille_pool()])
	verifie("tous les pools tiennent entre 2 et 5 effets", hors_bornes.is_empty(),
		str(hors_bornes))

	var manquants: Array = SpellRegistry.new().comportements_manquants()
	verifie("chaque comportement déclaré a sa classe", manquants.is_empty(), str(manquants))

	# Le coût de scellement doit distinguer « non renseigné » de « zéro » (R7).
	var effet := SpellEffect.new()
	verifie("un coût non renseigné retombe sur la formule",
		effet.cout_de_scellement(18) == 18)
	effet.cout_verrou_personnalise = true
	effet.cout_verrou = 0
	verifie("un coût de zéro reste un coût valide, pas une absence",
		effet.cout_de_scellement(18) == 0)


	# ── Utilitaires ───────────────────────────────────────────────────────────


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
