class_name HubHud
extends Control
## L'interface du hub : le strict nécessaire.
##
## Le hub est un lieu, pas un menu — l'information importante est portée par les
## autels eux-mêmes, dont la flamme dit l'état. L'écran ne rappelle que ce qui
## ne peut pas être dans le monde : le solde d'Éclats et le compte d'écoles.

var _entete: HudPanel
var _invite: Label
var _journal: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_entete = HudPanel.cree(16, 14, 430, 92, false)
	add_child(_entete)

	_journal = _etiquette(Vector2(24, 118), 14, Color(1, 0.85, 0.45))
	add_child(_journal)

	_invite = _etiquette(Vector2.ZERO, 18, Content.palette.lisere_blanc)
	_invite.set_anchors_preset(Control.PRESET_CENTER)
	_invite.offset_left = -420
	_invite.offset_right = 420
	_invite.offset_top = 44
	_invite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_invite)

	var reticule := _etiquette(Vector2.ZERO, 26, Color(1, 1, 1, 0.6))
	reticule.text = "+"
	reticule.set_anchors_preset(Control.PRESET_CENTER)
	reticule.offset_left = -9
	reticule.offset_top = -20
	add_child(reticule)

	var aide := HudPanel.cree(-330, 14, 314, 96, true)
	add_child(aide)
	aide.texte.text = ("[b]Hub[/b]\n"
		+ "ZQSD — se déplacer  ·  E — interagir\n"
		+ "Approche un autel pour prendre son école.\n"
		+ "Retour arrière — menu principal")


func rafraichit(choisies: int) -> void:
	_entete.texte.text = ("[b]Éclats : %d[/b]\n"
		+ "Équipe : %d / %d écoles\n"
		+ "Prochain déblocage : %d Éclats") % [
			Meta.eclats, choisies, PlayerState.SLOT_COUNT, Meta.cout_deblocage()]


func invite(texte: String) -> void:
	_invite.text = texte


func journalise(texte: String) -> void:
	_journal.text = texte


func _etiquette(pos: Vector2, taille: int, couleur: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", taille)
	label.add_theme_color_override("font_color", couleur)
	return label
