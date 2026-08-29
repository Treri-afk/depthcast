extends Control
## Le salon : qui est là, et qui appuie sur le bouton.
##
## Il n'affiche rien qu'il détienne. La liste des joueurs vit dans la session,
## et cet écran se contente de la redessiner à chaque changement — c'est la même
## règle que pour l'état de jeu (R1), et pour la même raison : deux copies d'une
## vérité finissent toujours par diverger.
##
## Seul le host peut lancer. La graine part avec l'ordre de départ : sans elle,
## chacun générerait son propre donjon et personne ne jouerait dans le même.

var _liste: Label
var _descendre: Button
var _statut: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ScreenUtils.fond(self)
	var col := ScreenUtils.colonne(self, 14)

	col.add_child(ScreenUtils.titre("SALON"))
	var quoi: String = Net.transport.nom() if Net.transport != null else "hors ligne"
	var ou: String = Net.transport.adresse_affichable() if Net.transport != null else ""
	col.add_child(ScreenUtils.sous_titre(
		"%s   ·   les autres joueurs saisissent %s" % [quoi, ou]))
	col.add_child(_espace(20))

	_liste = ScreenUtils.sous_titre("", Color(1, 1, 1, 0.9))
	_liste.add_theme_font_size_override("font_size", 18)
	col.add_child(_liste)
	col.add_child(_espace(20))

	_descendre = ScreenUtils.bouton("Descendre")
	_descendre.pressed.connect(func() -> void: Net.lance_la_partie())
	col.add_child(_descendre)

	var quitter := ScreenUtils.bouton("Quitter le salon")
	quitter.pressed.connect(func() -> void:
		Net.quitte()
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_MENU))
	col.add_child(quitter)

	_statut = ScreenUtils.sous_titre("", Color(1, 0.6, 0.5, 0.9))
	col.add_child(_statut)

	Net.roster_change.connect(_rafraichit)
	Net.partie_lancee.connect(_descend)
	Net.connexion_perdue.connect(func() -> void:
		_statut.text = "Le host a quitté la partie.")
	Net.echec.connect(func(message: String) -> void: _statut.text = message)
	_rafraichit()


func _rafraichit() -> void:
	var lignes: PackedStringArray = []
	for id: int in Net.joueurs():
		var marque: String = "  (host)" if id == 0 else ""
		var moi: String = "  ← toi" if GameState.est_local(id) else ""
		lignes.append("%d.  %s%s%s" % [id + 1, Net.nom_du_joueur(id), marque, moi])
	_liste.text = "\n".join(lignes)

	# Seul le host lance. Un client qui aurait le bouton croirait qu'il ne
	# marche pas, ce qui est pire que de ne pas l'avoir.
	_descendre.disabled = not Net.est_host()
	if not Net.est_host():
		_descendre.text = "En attente du host…"


func _descend(_graine: int) -> void:
	get_tree().change_scene_to_file(ScreenUtils.CHEMIN_JEU)


func _espace(hauteur: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, hauteur)
	return c
