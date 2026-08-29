class_name LabTests
extends TestSuite
## Souffle, mobilier et terrain d'essai.
##
## Le souffle est du calcul pur : atténuation et direction se vérifient sans
## moteur, et ce sont exactement les deux choses qu'on casserait sans s'en
## apercevoir en retouchant le ressenti d'une explosion.


func nom() -> String:
	return "Souffle, mobilier et terrain d'essai"


func execute() -> void:
	_check_souffle()
	_check_mobilier()
	_check_postes()
	_check_reglages()


func _check_souffle() -> void:
	print("Souffle — atténuation et direction")

	var onde := Souffle.new(Vector3.ZERO, 10.0, 20.0)

	verifie("au centre, la puissance est entière",
		is_equal_approx(onde.attenuation(Vector3.ZERO), 1.0))
	verifie("elle décroît avec la distance",
		onde.attenuation(Vector3(3, 0, 0)) > onde.attenuation(Vector3(7, 0, 0)))
	verifie("elle est nulle au-delà du rayon",
		is_zero_approx(onde.attenuation(Vector3(11, 0, 0))))
	# Un souffle qui s'annule exactement sur son cercle donne une frontière que
	# le joueur apprend par cœur : au bord il reste de quoi être bousculé.
	verifie("elle ne s'annule pas juste avant le bord",
		onde.attenuation(Vector3(9.9, 0, 0)) > 0.1)

	verifie("il pousse vers l'extérieur",
		onde.sens_vers(Vector3(4, 0, 0)).is_equal_approx(Vector3.RIGHT))
	# Sans ce cas particulier, une nova sous ses propres pieds serait décorative.
	verifie("au centre exact, il soulève au lieu de pousser",
		onde.sens_vers(Vector3(0, 0, 0)).is_equal_approx(Vector3.UP))
	verifie("la projection reste horizontale ailleurs",
		is_zero_approx(onde.sens_vers(Vector3(4, 3, 0)).y))

	var aspiration := Souffle.new(Vector3.ZERO, 10.0, 20.0, true)
	verifie("l'aspiration est le même souffle en sens inverse",
		aspiration.sens_vers(Vector3(4, 0, 0)).is_equal_approx(Vector3.LEFT))

	# Épargner le lanceur ne doit épargner QUE lui : le décor part quand même.
	var epargnant := Souffle.new(Vector3.ZERO, 10.0, 20.0)
	epargnant.epargne_le_lanceur = true
	verifie("épargner le lanceur ne change pas l'atténuation",
		is_equal_approx(epargnant.attenuation(Vector3(5, 0, 0)),
			onde.attenuation(Vector3(5, 0, 0))))
	epargnant.sur_joueur(null, Content.tuning)
	verifie("un souffle sans joueur ne plante pas", true)


func _check_mobilier() -> void:
	print("Mobilier — une caisse est une caisse partout")

	var masses: Array[float] = []
	for genre: int in [PropFactory.Genre.CAISSE, PropFactory.Genre.TONNEAU,
			PropFactory.Genre.TABLE]:
		var corps := PropFactory.cree(genre, Vector3.ZERO)
		verifie("%s : ses points de vie suivent sa masse" % PropFactory.nom(genre),
			corps.pv == int(corps.mass * 2.2), "pv=%d masse=%.1f" % [corps.pv, corps.mass])
		verifie("%s : il repose sur le sol, pas dedans" % PropFactory.nom(genre),
			corps.position.y > 0.0)
		verifie("%s : sa couleur vient de la palette" % PropFactory.nom(genre),
			corps.couleur == PropFactory.couleur(genre))
		masses.append(corps.mass)
		corps.free()

	verifie("une table est plus lourde qu'un tonneau, lui-même plus qu'une caisse",
		masses[0] < masses[1] and masses[1] < masses[2], str(masses))


func _check_postes() -> void:
	print("Terrain d'essai — les postes")

	var postes: Array[LabStation] = [DummyStation.new(), BlastStation.new(),
		PropsStation.new(), RerollStation.new(), RangeStation.new()]
	for poste: LabStation in postes:
		verifie("un poste s'annonce : %s" % poste.titre(),
			poste.titre() != "" and poste.titre() != "Poste")
		poste.free()

	# Le cran d'arrêt en tête : la fosse doit pouvoir se taire.
	verifie("la fosse aux explosions a un cran d'arrêt",
		float(BlastStation.CRANS[0]["puissance"]) == 0.0)
	verifie("ses crans montent en puissance",
		float(BlastStation.CRANS[1]["puissance"])
			< float(BlastStation.CRANS[3]["puissance"]))
	verifie("l'étal mélange les masses — sinon un souffle ne compare rien",
		_genres_de_l_etal().size() == 3, str(_genres_de_l_etal()))


func _check_reglages() -> void:
	print("Réglages de projection")

	var t: Tuning = Content.tuning
	verifie("le seuil de projection est non nul — sinon tout souffle décolle",
		t.souffle_seuil_projection > 0.0)
	verifie("la vitesse est plafonnée", t.projection_vitesse_max > 0.0)
	verifie("le contrôle est rendu — une projection n'est pas une paralysie",
		t.projection_controle_perdu > 0.0 and t.projection_controle_perdu < 2.0)
	# Bien plus faible que le freinage normal : un corps projeté glisse.
	verifie("on glisse pendant la projection",
		t.projection_amortissement < t.freinage_joueur)


func _genres_de_l_etal() -> Array:
	var vus: Array = []
	for modele: Dictionary in PropsStation.ETAL:
		if not vus.has(modele["genre"]):
			vus.append(modele["genre"])
	return vus
