class_name RerollSequence
extends Control
## Le moment du reroll.
##
## C'est LA promesse du jeu, et elle se jouait jusqu'ici en une ligne de texte
## pendant qu'on courait. Le GDD identifie ce défaut comme son risque numéro
## un : « un système où l'on ne sait jamais ce que fait son bouton devient
## frustrant plutôt qu'excitant si le feedback n'est pas irréprochable ».
##
## Trois partis pris.
##
## On S'ARRÊTE. Un évènement qu'on peut ignorer en courant n'est pas un
## évènement. Le contrôle est rendu à la fin, pas avant.
##
## Les cartes se retournent UNE PAR UNE. Quatre changements simultanés ne se
## lisent pas ; en cascade, chacun a son instant.
##
## Ce qui a RÉSISTÉ est montré aussi. Voir son sceau tenir est la récompense de
## la Résonance dépensée — l'escamoter reviendrait à ne payer que pour une
## absence de mauvaise nouvelle.

signal terminee()

const DELAI_ENTRE_CARTES: float = 0.26
const TEMPS_DE_LECTURE: float = 0.55

var mutations: Array[bool] = []
var etage: int = 0

var _titre: Label
var _cartes: Array[HudSlotCard] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var voile := ColorRect.new()
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	voile.color = Color(Content.palette.fond.r, Content.palette.fond.g,
		Content.palette.fond.b, 0.72)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(voile)

	_titre = ScreenUtils.titre("Étage %d" % (etage + 1), 40)
	_titre.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_titre.offset_left = -400
	_titre.offset_right = 400
	_titre.offset_top = 120
	add_child(_titre)

	var sous := ScreenUtils.sous_titre("Le grimoire se réécrit.")
	sous.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sous.offset_left = -400
	sous.offset_right = 400
	sous.offset_top = 178
	add_child(sous)

	_construit_les_cartes()
	_joue()


func _construit_les_cartes() -> void:
	var barre := HBoxContainer.new()
	barre.set_anchors_preset(Control.PRESET_CENTER)
	barre.offset_left = -520
	barre.offset_right = 520
	barre.offset_top = -80
	barre.offset_bottom = 80
	barre.alignment = BoxContainer.ALIGNMENT_CENTER
	barre.add_theme_constant_override("separation", 16)
	add_child(barre)

	var joueur: PlayerState = GameState.local_player()
	for i: int in joueur.slots.size():
		var carte := HudSlotCard.cree(i)
		carte.rafraichit(joueur.slots[i], GameState.run.floor_index, 0.0)
		# Elles arrivent en retrait : chacune se révèle à son tour.
		carte.modulate = Color(1, 1, 1, 0.25)
		carte.scale = Vector2(0.92, 0.92)
		carte.pivot_offset = Vector2(119, 78)
		barre.add_child(carte)
		_cartes.append(carte)


func _joue() -> void:
	for i: int in _cartes.size():
		var carte: HudSlotCard = _cartes[i]
		var mute: bool = i < mutations.size() and mutations[i]
		var minuteur := get_tree().create_timer(float(i) * DELAI_ENTRE_CARTES)
		minuteur.timeout.connect(func() -> void: _revele(carte, mute))

	var total: float = float(_cartes.size()) * DELAI_ENTRE_CARTES + TEMPS_DE_LECTURE
	get_tree().create_timer(total).timeout.connect(func() -> void:
		terminee.emit()
		queue_free())


func _revele(carte: HudSlotCard, mute: bool) -> void:
	Audio.joue(&"mutation" if mute else &"sceau_tient")

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(carte, "modulate", Color.WHITE, 0.18)
	# Une carte qui a muté sursaute ; une carte scellée se pose. Le mouvement
	# dit lequel des deux s'est produit avant même qu'on lise le texte.
	var cible: Vector2 = Vector2(1.12, 1.12) if mute else Vector2(1.0, 1.0)
	tween.tween_property(carte, "scale", cible, 0.14)
	tween.chain().tween_property(carte, "scale", Vector2.ONE, 0.2)

	if not mute:
		var sceau := ScreenUtils.sous_titre("SCEAU TENU", Content.palette.lisere_blanc)
		sceau.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		sceau.offset_top = -26
		carte.add_child(sceau)
