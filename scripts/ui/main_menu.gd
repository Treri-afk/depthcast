extends Control
## Menu principal.
##
## Le bouton multijoueur est visible mais désactivé, et dit pourquoi. Masquer
## une fonctionnalité prévue donne l'impression qu'elle n'existe pas ; la
## montrer inerte donne une carte du chemin restant.


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ScreenUtils.fond(self)
	var col := ScreenUtils.colonne(self, 16)

	col.add_child(ScreenUtils.titre("DEPTHCAST"))
	col.add_child(ScreenUtils.sous_titre(
		"La magie ne t'obéit jamais complètement."))
	col.add_child(_espace(28))

	var solo := ScreenUtils.bouton("Jouer en solo")
	solo.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_HUB))
	col.add_child(solo)

	# Le terrain d'essai est au menu et non derrière une touche de debug : c'est
	# là qu'on passe le plus de temps quand on règle le jeu, et une chose qu'on
	# ouvre vingt fois par jour ne doit pas demander de traverser le hub.
	var labo := ScreenUtils.bouton("Terrain d'essai")
	labo.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_LABO))
	col.add_child(labo)
	col.add_child(ScreenUtils.sous_titre(
		"Mannequins, explosions en boucle, mobilier qui se réarme, portique de\n"
		+ "mesure et pupitre de reroll. Aucun enjeu : on n'y meurt pas.",
		Color(0.55, 0.85, 1.0, 0.75)))
	col.add_child(_espace(12))

	col.add_child(ScreenUtils.bouton("Jouer en coopération", false))
	col.add_child(ScreenUtils.sous_titre(
		"Le réseau n'est pas encore implémenté. L'architecture est prête — état\n"
		+ "centralisé, joueurs indexés, RNG par joueur, résolution déterministe —\n"
		+ "mais aucun transport n'est branché. Prévu au cycle C7.",
		Color(1, 0.82, 0.45, 0.8)))
	col.add_child(_espace(20))

	var quitter := ScreenUtils.bouton("Quitter")
	quitter.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quitter)


func _espace(hauteur: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, hauteur)
	return c
