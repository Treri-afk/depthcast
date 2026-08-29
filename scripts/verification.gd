extends Node3D
## Scène de démarrage — pour l'instant, un banc de vérification de l'architecture.
##
## Elle ne contient pas de jeu : elle exécute les TESTS formulés dans
## ARCHITECTURE.md et affiche le résultat. Tant que le gameplay n'existe pas,
## c'est ce qui garantit que les règles ne sont pas déjà enfreintes.
##
## Se lance aussi sans fenêtre :
##   godot --headless --path . --quit-after 2

var _failures: int = 0
var _rerolls: Array = []


func _ready() -> void:
	print("─── DepthCast — vérification de l'architecture ───")
	EventBus.slot_rerolled.connect(_on_slot_rerolled)

	_check_r3_determinisme()
	_check_r1_serialisation()
	_check_r4_ordre_deterministe()
	_check_verrou_un_seul_etage()
	_check_decouverte_portee_etage()
	_check_monstres()
	_check_contenu()

	print("─────────────────────────────────────────────────")
	if _failures == 0:
		print("✓ toutes les vérifications passent")
	else:
		printerr("✗ %d vérification(s) en échec" % _failures)

	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if _failures > 0 else 0)


func _on_slot_rerolled(player_id: int, slot_index: int, effect_index: int) -> void:
	_rerolls.append([player_id, slot_index, effect_index])


func _ok(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ %s" % label)
	else:
		_failures += 1
		printerr("  ✗ %s %s" % [label, detail])


## R3 — même seed et même équipe redonnent exactement les mêmes rerolls.
func _check_r3_determinisme() -> void:
	print("R3 — RNG seedé et reproductible")

	var first: Array = _run_scenario(4242)
	var second: Array = _run_scenario(4242)
	var different: Array = _run_scenario(9999)

	_ok("la même seed rejoue les mêmes rerolls", first == second,
		"\n     %s\n     %s" % [first, second])
	_ok("une seed différente donne autre chose", first != different)


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

	_ok("sérialiser puis recharger redonne le même état", avant == apres)
	_ok("le pot commun a bien été débité", int(avant["resonance_pool"]) == 90,
		"attendu 90, obtenu %s" % avant["resonance_pool"])


## R4 — l'ordre de soumission n'influence pas le résultat.
func _check_r4_ordre_deterministe() -> void:
	print("R4 — résolution déterministe des effets")

	var direct: int = _resolve_two_casts(false)
	var inverse: int = _resolve_two_casts(true)

	_ok("deux ordres d'arrivée donnent le même état final", direct == inverse,
		"direct=%d inversé=%d" % [direct, inverse])


## Un verrou protège l'étage suivant, et seulement lui.
func _check_verrou_un_seul_etage() -> void:
	print("Verrou — durée d'exactement un étage")

	GameState.start_run(31337, 1)
	GameState.add_resonance(100)
	var joueur: PlayerState = GameState.run.players[0]
	GameState.try_lock_slot(0, 0, 10)
	var fige: int = joueur.slots[0].effect_index

	GameState.advance_floor()
	_ok("le slot résiste au premier reroll", joueur.slots[0].effect_index == fige)

	var protege_encore: bool = joueur.slots[0].is_locked_for(GameState.run.floor_index + 1)
	_ok("le verrou ne couvre pas l'étage d'après", not protege_encore)


## L'état `???` se réinitialise à chaque étage, verrou ou pas.
func _check_decouverte_portee_etage() -> void:
	print("Découverte — portée étage, pas portée run")

	GameState.start_run(555, 1)
	var joueur: PlayerState = GameState.run.players[0]
	var etage: int = GameState.run.floor_index

	_ok("un sort est inconnu en arrivant", not joueur.slots[0].is_discovered_on(etage))

	_cast(0, 0, 5, [0])
	EffectResolver.resolve_tick()
	_ok("il devient connu une fois lancé", joueur.slots[0].is_discovered_on(etage))

	GameState.add_resonance(50)
	GameState.try_lock_slot(0, 0, 10)
	GameState.advance_floor()
	var nouvel_etage: int = GameState.run.floor_index
	_ok("même verrouillé, il redevient inconnu à l'étage suivant",
		not joueur.slots[0].is_discovered_on(nouvel_etage))


## Un monstre encaisse, meurt, et verse au pot COMMUN.
func _check_monstres() -> void:
	print("Monstres — dégâts, mort et Résonance")

	GameState.start_run(2024, 2)
	var id: int = GameState.spawn_monster(30, 25)
	var monstre: MonsterState = GameState.run.get_monster(id)

	_ok("le monstre est enregistré dans l'état de la run", monstre != null and monstre.hp == 30)

	_frappe_monstre(0, id, 10)
	EffectResolver.resolve_tick()
	_ok("il encaisse sans mourir", monstre.hp == 20 and monstre.is_alive(),
		"pv=%d" % monstre.hp)
	_ok("aucune Résonance tant qu'il vit", GameState.run.resonance_pool == 0)

	# Le joueur 1 porte le coup fatal, mais la récompense va au pot commun.
	_frappe_monstre(1, id, 50)
	EffectResolver.resolve_tick()
	_ok("il meurt sans passer en PV négatifs", monstre.hp == 0 and not monstre.is_alive())
	_ok("la récompense va au pot commun, pas au tueur",
		GameState.run.resonance_pool == 25, "pot=%d" % GameState.run.resonance_pool)

	# Frapper un cadavre ne doit pas re-créditer.
	_frappe_monstre(0, id, 10)
	EffectResolver.resolve_tick()
	_ok("un monstre déjà mort ne rapporte pas deux fois",
		GameState.run.resonance_pool == 25, "pot=%d" % GameState.run.resonance_pool)

	var avant: Dictionary = GameState.serialize()
	GameState.deserialize(avant)
	_ok("les monstres survivent à la sérialisation", GameState.serialize() == avant)

	GameState.advance_floor()
	_ok("les monstres sont vidés au changement d'étage",
		GameState.run.monsters.is_empty())


## Le contenu est de la donnée : on vérifie qu'il se charge et qu'aucun
## comportement déclaré n'a été oublié dans le registre.
##
## Cette dernière vérification transforme un oubli en échec de test, au lieu
## d'un sort qui ne fait simplement rien une fois en jeu.
func _check_contenu() -> void:
	print("Contenu — Resources et registre de comportements")

	_ok("les écoles se chargent depuis resources/", Content.ecoles.size() >= 5,
		"%d trouvée(s)" % Content.ecoles.size())
	_ok("les monstres se chargent depuis resources/", Content.monstres.size() >= 3,
		"%d trouvé(s)" % Content.monstres.size())
	_ok("la table de tuning existe", Content.tuning != null)

	var hors_bornes: Array = []
	for e: School in Content.ecoles:
		if e.taille_pool() < School.POOL_MIN or e.taille_pool() > School.POOL_MAX:
			hors_bornes.append("%s(%d)" % [e.nom, e.taille_pool()])
	_ok("tous les pools tiennent entre 2 et 5 effets", hors_bornes.is_empty(),
		str(hors_bornes))

	var manquants: Array = SpellRegistry.new().comportements_manquants()
	_ok("chaque comportement déclaré a sa classe", manquants.is_empty(), str(manquants))

	# Le coût de scellement doit distinguer « non renseigné » de « zéro » (R7).
	var effet := SpellEffect.new()
	_ok("un coût non renseigné retombe sur la formule",
		effet.cout_de_scellement(18) == 18)
	effet.cout_verrou_personnalise = true
	effet.cout_verrou = 0
	_ok("un coût de zéro reste un coût valide, pas une absence",
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
