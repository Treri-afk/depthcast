extends Control
## Menu principal.
##
## Le bouton multijoueur est visible mais désactivé, et dit pourquoi. Masquer
## une fonctionnalité prévue donne l'impression qu'elle n'existe pas ; la
## montrer inerte donne une carte du chemin restant.


var _adresse: LineEdit
var _statut: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Revenir au menu ferme la partie en cours : une session laissée ouverte
	# derrière soi bloquerait le port au prochain hébergement.
	Net.quitte()
	Net.echec.connect(func(message: String) -> void: _statut.text = message)
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

	col.add_child(_espace(8))
	var heberger := ScreenUtils.bouton("Héberger une partie")
	heberger.pressed.connect(func() -> void: _ouvre(Net.heberge()))
	col.add_child(heberger)

	# L'adresse est pré-remplie sur la machine locale : le cas le plus fréquent
	# pendant le développement est deux fenêtres côte à côte, et il ne doit rien
	# demander de plus qu'un clic.
	_adresse = ScreenUtils.champ("127.0.0.1", "adresse du host")
	col.add_child(_adresse)

	var rejoindre := ScreenUtils.bouton("Rejoindre")
	rejoindre.pressed.connect(func() -> void: _ouvre(Net.rejoint(_adresse.text)))
	col.add_child(rejoindre)

	_statut = ScreenUtils.sous_titre("", Color(1, 0.6, 0.5, 0.9))
	col.add_child(_statut)
	col.add_child(_espace(14))

	var quitter := ScreenUtils.bouton("Quitter")
	quitter.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quitter)


## Le salon ne s'ouvre que si la connexion a démarré. Sinon on reste ici, avec
## la raison affichée sous les boutons.
func _ouvre(ouverte: bool) -> void:
	if ouverte:
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_SALON)


func _espace(hauteur: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, hauteur)
	return c
