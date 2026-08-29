class_name HudSlotCard
extends PanelContainer
## La carte d'un slot de sort.
##
## Elle affiche les chiffres bruts — position dans le pool, étage de validité
## du sceau. C'est volontaire : sans eux, on ne peut pas dire si un reroll a
## changé quelque chose, et le playtest ne mesure plus rien.

signal ecole_demandee(slot_index: int, pas: int)

var slot_index: int = 0

var _texte: RichTextLabel


static func cree(index: int) -> HudSlotCard:
	var carte := HudSlotCard.new()
	carte.slot_index = index
	carte.custom_minimum_size = Vector2(238, 156)

	carte.add_theme_stylebox_override("panel", HudStyle.panneau(Content.palette.encre))

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 4)

	var texte := RichTextLabel.new()
	texte.bbcode_enabled = true
	texte.fit_content = true
	texte.scroll_active = false
	texte.custom_minimum_size = Vector2(0, 96)
	texte.add_theme_font_size_override("normal_font_size", 13)
	texte.add_theme_font_size_override("bold_font_size", 15)
	colonne.add_child(texte)
	carte._texte = texte

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	actions.add_child(carte._fleche("<", -1))
	var titre := Label.new()
	titre.text = "école"
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 12)
	titre.modulate = Color(1, 1, 1, 0.5)
	actions.add_child(titre)
	actions.add_child(carte._fleche(">", 1))

	colonne.add_child(actions)
	carte.add_child(colonne)
	return carte


func _fleche(libelle: String, pas: int) -> Button:
	var bouton := Button.new()
	bouton.text = libelle
	bouton.custom_minimum_size = Vector2(32, 28)
	bouton.tooltip_text = "École précédente" if pas < 0 else "École suivante"
	bouton.pressed.connect(func() -> void: ecole_demandee.emit(slot_index, pas))
	HudStyle.habille_bouton(bouton)
	return bouton


func rafraichit(slot: SpellSlot, etage: int, cooldown: float) -> void:
	var ecole: School = Content.ecole(slot.school_id)
	var nom_ecole: String = ecole.nom if ecole != null else "?"
	var couleur: Color = ecole.couleur if ecole != null else Color.WHITE
	var scelle: bool = slot.is_locked_for(etage + 1)

	var lignes: String = "[b]%d · [color=#%s]%s[/color][/b]%s\n" % [
		slot_index + 1, couleur.to_html(false), nom_ecole.to_upper(),
		"   [SCEAU]" if scelle else "",
	]

	if slot.is_discovered_on(etage):
		var effet: SpellEffect = ecole.effet(slot.effect_index) if ecole != null else null
		lignes += "[b]%s[/b]\n%s · %s\n" % [effet.nom, effet.libelle_famille(),
			effet.libelle_puissance()] if effet != null else "[b]?[/b]\ninconnu\n"
	else:
		lignes += "[color=#8a8a95][b]???[/b]\nlance-le pour découvrir[/color]\n"

	lignes += "[color=#7b7b88]effet %d sur %d du pool[/color]\n" % [
		slot.effect_index + 1, slot.pool_size]
	if cooldown > 0.0:
		lignes += "[color=#ff9b6a]recharge %.1fs[/color]" % cooldown
	elif scelle:
		lignes += "[color=#8fd694]tenu jusqu'à l'étage %d[/color]" % (
			slot.locked_until_floor + 1)
	else:
		lignes += "[color=#8fd694]prêt[/color]"

	_texte.text = lignes
	# Le pied de carte prend la couleur de l'école : c'est le seul endroit vif
	# de l'interface, et il dit d'un coup d'oeil à quoi on a affaire.
	add_theme_stylebox_override("panel", HudStyle.panneau(couleur))
