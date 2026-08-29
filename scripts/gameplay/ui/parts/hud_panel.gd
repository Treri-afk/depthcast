class_name HudPanel
extends PanelContainer
## Panneau de texte du HUD : un fond sombre lisible et un RichTextLabel.
##
## Extrait parce que le HUD en pose plusieurs et que la recette du fond
## n'a pas à être copiée à chaque fois.

var texte: RichTextLabel


static func cree(x: float, y: float, largeur: float, hauteur: float,
		ancre_a_droite: bool) -> HudPanel:
	var panneau := HudPanel.new()
	if ancre_a_droite:
		panneau.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panneau.offset_left = x
	panneau.offset_right = x + largeur
	panneau.offset_top = y
	panneau.offset_bottom = y + hauteur

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.74)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panneau.add_theme_stylebox_override("panel", style)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", 14)
	label.add_theme_font_size_override("bold_font_size", 14)
	panneau.add_child(label)
	panneau.texte = label
	return panneau
