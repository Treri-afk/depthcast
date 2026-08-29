extends Control
## Le hub : on y dépense ses Éclats et on y compose son équipe d'écoles.
##
## C'est ici que se joue la promesse méta du GDD : débloquer une école élargit
## le pool de choix, donc l'incertitude. On ne devient jamais plus fort, on
## devient moins prévisible.

var _selection: Array[StringName] = []
var _liste: VBoxContainer
var _entete: Label
var _descendre: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ScreenUtils.fond(self)

	var col := ScreenUtils.colonne(self, 10)
	col.add_child(ScreenUtils.titre("Hub", 34))
	_entete = ScreenUtils.sous_titre("")
	col.add_child(_entete)

	_liste = VBoxContainer.new()
	_liste.add_theme_constant_override("separation", 6)
	col.add_child(_liste)

	_descendre = ScreenUtils.bouton("Descendre")
	_descendre.pressed.connect(_descend)
	col.add_child(_descendre)

	var retour := ScreenUtils.bouton("Retour au menu")
	retour.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_MENU))
	col.add_child(retour)

	_preselectionne()
	_rafraichit()


## On arrive avec une équipe valide déjà composée : le hub propose, il ne
## bloque pas. Un joueur pressé doit pouvoir descendre en un clic.
func _preselectionne() -> void:
	_selection.clear()
	for ecole: School in Meta.ecoles_disponibles():
		if _selection.size() < PlayerState.SLOT_COUNT:
			_selection.append(ecole.id)


func _rafraichit() -> void:
	_entete.text = "Éclats : %d   ·   %d / %d écoles choisies" % [
		Meta.eclats, _selection.size(), PlayerState.SLOT_COUNT]

	for enfant: Node in _liste.get_children():
		enfant.queue_free()

	for ecole: School in Content.ecoles:
		_liste.add_child(_ligne(ecole))

	_descendre.disabled = _selection.size() != PlayerState.SLOT_COUNT


func _ligne(ecole: School) -> Control:
	var ligne := HBoxContainer.new()
	ligne.custom_minimum_size = Vector2(560, 0)
	ligne.add_theme_constant_override("separation", 10)

	var nom := Label.new()
	nom.text = "%s — %s  (%d effets)" % [ecole.nom, ecole.identite, ecole.taille_pool()]
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.add_theme_color_override("font_color", ecole.couleur)
	ligne.add_child(nom)

	if not Meta.est_debloquee(ecole.id):
		var cout: int = Meta.cout_deblocage()
		var achat := ScreenUtils.bouton("Débloquer — %d Éclats" % cout,
			Meta.eclats >= cout)
		achat.custom_minimum_size = Vector2(220, 34)
		achat.pressed.connect(func() -> void:
			if Meta.tente_deblocage(ecole.id):
				_rafraichit())
		ligne.add_child(achat)
		return ligne

	var choisie: bool = _selection.has(ecole.id)
	var bascule := ScreenUtils.bouton("Retirer" if choisie else "Choisir",
		choisie or _selection.size() < PlayerState.SLOT_COUNT)
	bascule.custom_minimum_size = Vector2(220, 34)
	bascule.pressed.connect(func() -> void:
		if _selection.has(ecole.id):
			_selection.erase(ecole.id)
		elif _selection.size() < PlayerState.SLOT_COUNT:
			_selection.append(ecole.id)
		_rafraichit())
	ligne.add_child(bascule)
	return ligne


func _descend() -> void:
	# La sélection traverse le changement de scène par l'état, pas par un
	# paramètre : c'est GameState qui fait foi (R1).
	GameState.ecoles_choisies = _selection.duplicate()
	get_tree().change_scene_to_file(ScreenUtils.CHEMIN_JEU)
