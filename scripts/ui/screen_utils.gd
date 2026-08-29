class_name ScreenUtils
extends RefCounted
## Fabrique les éléments communs aux écrans hors-jeu, pour que menu, hub et
## écran de fin partagent une même présentation sans se copier.

const CHEMIN_MENU := "res://scenes/menu.tscn"
const CHEMIN_HUB := "res://scenes/hub.tscn"
const CHEMIN_JEU := "res://scenes/jeu.tscn"


static func fond(parent: Control) -> void:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(0.06, 0.06, 0.09)
	parent.add_child(rect)


static func titre(texte: String, taille: int = 46) -> Label:
	var label := Label.new()
	label.text = texte
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", taille)
	return label


static func sous_titre(texte: String, couleur := Color(1, 1, 1, 0.65)) -> Label:
	var label := Label.new()
	label.text = texte
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", couleur)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func bouton(texte: String, actif: bool = true) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(340, 46)
	b.disabled = not actif
	return b


static func colonne(parent: Control, separation: int = 14) -> VBoxContainer:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(centre)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", separation)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(col)
	return col
