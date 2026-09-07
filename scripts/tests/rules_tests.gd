class_name RulesTests
extends TestSuite
## Règles de jeu — sceaux et découverte


func nom() -> String:
	return "Règles de jeu — sceaux et découverte"


func execute() -> void:
	verifie_le_grimoire()
	_check_verrou_un_seul_etage()
	_check_decouverte_portee_etage()


func _check_verrou_un_seul_etage() -> void:
	print("Verrou — durée d'exactement un étage")

	GameState.start_run(31337, 1)
	GameState.add_resonance(100)
	var joueur: PlayerState = GameState.run.players[0]
	GameState.try_lock_slot(0, 0, 10)
	var fige: int = joueur.slots[0].effect_index

	GameState.advance_floor()
	verifie("le slot résiste au premier reroll", joueur.slots[0].effect_index == fige)

	var protege_encore: bool = joueur.slots[0].is_locked_for(GameState.run.floor_index + 1)
	verifie("le verrou ne couvre pas l'étage d'après", not protege_encore)


	## L'état `???` se réinitialise à chaque étage, verrou ou pas.


func _check_decouverte_portee_etage() -> void:
	print("Découverte — portée étage, pas portée run")

	GameState.start_run(555, 1)
	var joueur: PlayerState = GameState.run.players[0]
	var etage: int = GameState.run.floor_index

	verifie("un sort est inconnu en arrivant", not joueur.slots[0].is_discovered_on(etage))

	_cast(0, 0, 5, [0])
	EffectResolver.resolve_tick()
	verifie("il devient connu une fois lancé", joueur.slots[0].is_discovered_on(etage))

	GameState.add_resonance(50)
	GameState.try_lock_slot(0, 0, 10)
	GameState.advance_floor()
	var nouvel_etage: int = GameState.run.floor_index
	verifie("même verrouillé, il redevient inconnu à l'étage suivant",
		not joueur.slots[0].is_discovered_on(nouvel_etage))


	## Un monstre encaisse, meurt, et verse au pot COMMUN.


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


## LE GRIMOIRE : deux pages au départ, trois au plus.
##
## Ces bornes sont du design, pas de la technique. Les vérifier ici évite qu'un
## refactor les fasse dériver en silence — ce qui vient d'arriver une fois, quand
## le nombre de slots et le nombre d'écoles étaient la même constante.
func verifie_le_grimoire() -> void:
	GameState.start_run(4242, 1)
	var p: PlayerState = GameState.run.get_player(0)

	verifie("on part avec deux pages",
		p.slots.size() == PlayerState.SLOTS_DEPART, "%d" % p.slots.size())
	verifie("et une seule école",
		PlayerState.ECOLES_DEPART == 1)

	var ecole: School = Content.ecoles[0]
	GameState.set_player_schools(0, [{"id": ecole.id,
		"pool_size": ecole.taille_pool()}])
	verifie("les deux pages viennent de la même école",
		p.slots[0].school_id == ecole.id and p.slots[1].school_id == ecole.id)

	# La page achetée : une école de plus, un sort tiré dedans.
	var autre: School = Content.ecoles[1]
	var index: int = GameState.ajoute_une_page(0, autre.id, autre.taille_pool())
	verifie("une page s'ajoute au bout du grimoire", index == 2
		and p.slots.size() == 3 and p.slots[2].school_id == autre.id)
	verifie("son sort est tiré dans le pool de son école",
		p.slots[2].effect_index >= 0
			and p.slots[2].effect_index < autre.taille_pool())

	# Le plafond tient.
	verifie("le grimoire refuse une quatrième page",
		GameState.ajoute_une_page(0, autre.id, autre.taille_pool()) == -1
			and p.slots.size() == PlayerState.SLOTS_MAX)

	# Et la page rerolle comme les deux autres : c'est la décision qui a été
	# prise, et c'est ce qui distingue une page d'un objet.
	var avant: int = p.slots[2].effect_index
	var mute: bool = false
	for essai: int in 12:
		GameState.reroll_slots(0)
		if p.slots[2].effect_index != avant:
			mute = true
			break
	verifie("une page achetée rerolle comme les autres",
		mute or autre.taille_pool() <= 1,
		"pool de %d" % autre.taille_pool())

	GameState.end_run(false)
	GameState.run = null
