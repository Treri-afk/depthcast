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
