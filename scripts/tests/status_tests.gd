class_name StatusTests
extends TestSuite
## Les états temporaires — la tuyauterie sur laquelle reposeront les rôles.
##
## Ces vérifications ne portent sur aucun contenu : ni protection, ni
## provocation nommée. Elles portent sur les RÈGLES que tout contenu futur
## supposera, et qu'il coûterait très cher de découvrir fausses une fois douze
## sorts écrits par-dessus.


func nom() -> String:
	return "États — protection, provocation, cumul"


func execute() -> void:
	_check_cumul()
	_check_duree()
	_check_degats()
	_check_provocation()
	_check_serialisation()


func _check_cumul() -> void:
	print("Le cumul est multiplicatif, jamais additif")

	var sac := StatusHolder.new()
	sac.pose(_protection(&"a", 0.6))
	sac.pose(_protection(&"b", 0.6))
	# 0,36 et non 0,2 : l'addition permet d'atteindre zéro dégât reçu en
	# empilant assez de sorts, la multiplication s'en approche sans y arriver.
	verifie("deux protections se multiplient",
		is_equal_approx(sac.degats_recus(), 0.36), "%.2f" % sac.degats_recus())
	verifie("et n'atteignent jamais l'invulnérabilité", sac.degats_recus() > 0.0)

	# Reposer le même état rafraîchit, il n'empile pas : sinon relancer un sort
	# de protection en boucle rendrait invincible.
	sac.pose(_protection(&"a", 0.6))
	verifie("le même état remplace au lieu de s'ajouter",
		is_equal_approx(sac.degats_recus(), 0.36), "%.2f" % sac.degats_recus())
	verifie("et il n'y en a toujours que deux", sac.etats.size() == 2)


func _check_duree() -> void:
	print("Un état s'éteint")

	var sac := StatusHolder.new()
	var bref := Status.cree(&"court", 0.5)
	bref.degats_recus = 0.5
	sac.pose(bref)
	sac.avance(0.3)
	verifie("il tient tant que sa durée court", sac.porte(&"court"))
	sac.avance(0.3)
	verifie("puis il disparaît", not sac.porte(&"court"))
	verifie("et le porteur redevient neutre",
		is_equal_approx(sac.degats_recus(), 1.0))


func _check_degats() -> void:
	print("Protection et vulnérabilité au passage du resolver")

	GameState.start_run(77, 2)
	var cible: PlayerState = GameState.run.get_player(0)
	var depart: int = cible.hp

	_frappe(0, 100.0)
	verifie("sans état, on encaisse le montant plein",
		cible.hp == depart - 100 or cible.hp == 0, "pv %d" % cible.hp)

	cible.hp = depart
	cible.statuts.pose(_protection(&"protection", 0.5))
	_frappe(0, 40.0)
	verifie("protégé, on encaisse la moitié", cible.hp == depart - 20,
		"pv %d au lieu de %d" % [cible.hp, depart - 20])

	# Les dégâts INFLIGÉS par le lanceur comptent aussi : c'est le même levier,
	# vu de l'autre côté.
	var frappeur: PlayerState = GameState.run.get_player(1)
	var fort := Status.cree(&"rage", 5.0, 1)
	fort.degats_infliges = 2.0
	frappeur.statuts.pose(fort)
	cible.hp = depart
	_frappe_par(1, 0, 40.0)
	verifie("un lanceur enragé frappe plus fort, protection comprise",
		cible.hp == depart - 40, "pv %d" % cible.hp)


func _check_provocation() -> void:
	print("La provocation prend l'attention")

	var sac := StatusHolder.new()
	verifie("sans provocation, personne n'est désigné", sac.provocateur() == -1)

	sac.pose(_provocation(&"cri", 2))
	verifie("provoqué, le monstre sait par qui", sac.provocateur() == 2)

	# Le dernier l'emporte : une provocation fraîche doit reprendre l'attention,
	# sinon deux tanks se disputeraient un monstre au profit du premier arrivé.
	sac.pose(_provocation(&"autre_cri", 3))
	verifie("et une provocation plus fraîche reprend l'attention",
		sac.provocateur() == 3)


func _check_serialisation() -> void:
	print("Les états traversent le réseau comme le reste")

	GameState.start_run(88, 1)
	var p: PlayerState = GameState.run.get_player(0)
	p.statuts.pose(_protection(&"protection", 0.4))

	var photo: Dictionary = GameState.serialize()
	GameState.deserialize(photo)
	var apres: PlayerState = GameState.run.get_player(0)
	verifie("un état survit à la sérialisation", apres.statuts.porte(&"protection"))
	verifie("avec son facteur intact",
		is_equal_approx(apres.statuts.degats_recus(), 0.4),
		"%.2f" % apres.statuts.degats_recus())
	# C'est ce qui les réplique gratuitement : aucune ligne de réseau n'a été
	# écrite pour les états, la photo du host suffit.
	verifie("et la photo reste identique à elle-même",
		GameState.serialize() == photo)


func _protection(id: StringName, facteur: float) -> Status:
	var etat := Status.cree(id, 5.0)
	etat.degats_recus = facteur
	return etat


func _provocation(id: StringName, par: int) -> Status:
	var etat := Status.cree(id, 5.0, par)
	etat.provoque = true
	return etat


func _frappe(cible: int, montant: float) -> void:
	_frappe_par(-1, cible, montant)


func _frappe_par(source: int, cible: int, montant: float) -> void:
	var intent := EffectIntent.new()
	intent.kind = EffectIntent.Kind.DAMAGE
	intent.amount = montant
	intent.source_player_id = source
	intent.target_ids = PackedInt64Array([cible])
	EffectResolver.submit(intent)
	EffectResolver.resolve_tick()
