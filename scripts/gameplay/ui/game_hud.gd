class_name GameHud
extends Control
## HUD du prototype. JETABLE — la vraie UI arrive en C8.
##
## Sa mission ici n'est pas d'être beau : c'est de rendre LISIBLE tout ce que
## fait le moteur, pour qu'un playtest puisse dire ce qui se passe. D'où les
## chiffres bruts affichés partout — index d'effet, taille de pool, étage de
## validité du verrou.
##
## Il ne fait que LIRE GameState. Il ne modifie rien : les boutons émettent des
## signaux que la racine du prototype traite.

signal etage_suivant_demande()
## Demande de changer l'école d'un slot. `pas` vaut -1 ou +1.
signal ecole_changee(slot_index: int, pas: int)

var joueur: PlayerAvatar = null
var caster: SpellCaster = null

var _info: RichTextLabel
var _journal: Label
var _aide: RichTextLabel
var _cartes: Array[RichTextLabel] = []
var _invite: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_info = _panneau_texte(16, 14, 452, 116, false)
	_aide = _panneau_texte(-346, 14, 330, 168, true)
	_aide.text = ("[b]Commandes[/b]\n"
		+ "ZQSD / WASD — se déplacer\n"
		+ "Espace — sauter  ·  Souris — viser\n"
		+ "Clic ou 1-4 — lancer un sort\n"
		+ "[color=#ffd24a]E — interagir (marchand, portail)[/color]\n"
		+ "[color=#ffd24a]Maj + 1-4 — changer l'école du slot[/color]\n"
		+ "Échap — libérer le curseur\n"
		+ "Clic droit — reprendre la visée")

	_journal = Label.new()
	_journal.position = Vector2(24, 140)
	_journal.add_theme_font_size_override("font_size", 14)
	_journal.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	add_child(_journal)

	_construit_les_cartes()
	_construit_le_reticule()

	# Invite d'interaction, juste sous le réticule : c'est là que l'oeil est.
	_invite = Label.new()
	_invite.set_anchors_preset(Control.PRESET_CENTER)
	_invite.offset_left = -320
	_invite.offset_right = 320
	_invite.offset_top = 40
	_invite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_invite.add_theme_font_size_override("font_size", 17)
	_invite.add_theme_color_override("font_color", Color(1, 0.93, 0.6))
	add_child(_invite)


func _panneau_texte(x: float, y: float, largeur: float, hauteur: float,
		a_droite: bool) -> RichTextLabel:
	var fond := PanelContainer.new()
	if a_droite:
		fond.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		fond.offset_left = x
		fond.offset_right = x + largeur
	else:
		fond.offset_left = x
		fond.offset_right = x + largeur
	fond.offset_top = y
	fond.offset_bottom = y + hauteur

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.74)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	fond.add_theme_stylebox_override("panel", style)
	add_child(fond)

	var texte := RichTextLabel.new()
	texte.bbcode_enabled = true
	texte.fit_content = true
	texte.scroll_active = false
	texte.add_theme_font_size_override("normal_font_size", 14)
	texte.add_theme_font_size_override("bold_font_size", 14)
	fond.add_child(texte)
	return texte


## Une carte par slot, ancrée en bas.
##
## L'ancrage passe par des offsets explicites et non par un preset seul : un
## preset appliqué à un conteneur le laisse avec une taille nulle, et c'est
## exactement pour ça que la barre était invisible.
func _construit_les_cartes() -> void:
	var barre := HBoxContainer.new()
	barre.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	barre.offset_left = 20
	barre.offset_right = -20
	barre.offset_top = -186
	barre.offset_bottom = -20
	barre.alignment = BoxContainer.ALIGNMENT_CENTER
	barre.add_theme_constant_override("separation", 12)
	add_child(barre)

	for i: int in 4:
		var carte := PanelContainer.new()
		carte.custom_minimum_size = Vector2(238, 156)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.06, 0.09, 0.84)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(10)
		style.border_width_bottom = 3
		style.border_color = Color(0.4, 0.4, 0.45)
		carte.add_theme_stylebox_override("panel", style)

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

		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 4)

		var gauche := Button.new()
		gauche.text = "<"
		gauche.tooltip_text = "École précédente"
		gauche.custom_minimum_size = Vector2(32, 28)
		gauche.pressed.connect(func() -> void: ecole_changee.emit(i, -1))
		actions.add_child(gauche)

		var titre := Label.new()
		titre.text = "école"
		titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titre.add_theme_font_size_override("font_size", 12)
		titre.modulate = Color(1, 1, 1, 0.5)
		actions.add_child(titre)

		var droite := Button.new()
		droite.text = ">"
		droite.tooltip_text = "École suivante"
		droite.custom_minimum_size = Vector2(32, 28)
		droite.pressed.connect(func() -> void: ecole_changee.emit(i, 1))
		actions.add_child(droite)

		colonne.add_child(actions)
		carte.add_child(colonne)
		barre.add_child(carte)

		_cartes.append(texte)


func _construit_le_reticule() -> void:
	var reticule := Label.new()
	reticule.text = "+"
	reticule.add_theme_font_size_override("font_size", 26)
	reticule.set_anchors_preset(Control.PRESET_CENTER)
	reticule.offset_left = -9
	reticule.offset_top = -20
	reticule.modulate = Color(1, 1, 1, 0.65)
	add_child(reticule)


func journalise(texte: String) -> void:
	_journal.text = texte


func invite(texte: String) -> void:
	_invite.text = texte


func _process(_delta: float) -> void:
	if not GameState.is_in_run():
		return
	var p: PlayerState = GameState.run.players[0]
	var etage: int = GameState.run.floor_index
	var vivants: int = GameState.run.alive_monsters().size()

	var curseur: String = "capturé" if (joueur != null and joueur.souris_capturee()) \
		else "[color=#ffd24a]LIBRE — clic droit pour viser[/color]"

	_info.text = ("[b]Étage %d[/b]   ·   %d monstre(s) restant(s)\n"
		+ "PV [b]%d[/b] / %d\n"
		+ "Résonance (pot commun) : [b]%d[/b]\n"
		+ "seed %d   ·   curseur %s") % [
			etage + 1, vivants, p.hp, p.max_hp,
			GameState.run.resonance_pool, GameState.run.run_seed, curseur,
		]

	for i: int in _cartes.size():
		_maj_carte(i, p.slots[i], etage)


func _maj_carte(i: int, slot: SpellSlot, etage: int) -> void:
	var ecole: School = Content.ecole(slot.school_id)
	var nom_ecole: String = ecole.nom if ecole != null else "?"
	var couleur: Color = ecole.couleur if ecole != null else Color.WHITE
	var teinte: String = "#" + couleur.to_html(false)

	var verrouille: bool = slot.is_locked_for(etage + 1)
	var connu: bool = slot.is_discovered_on(etage)
	var cd: float = joueur.cooldown_restant(i) if joueur != null else 0.0

	var lignes: String = "[b]%d · [color=%s]%s[/color][/b]%s\n" % [
		i + 1, teinte, nom_ecole.to_upper(), "   [VERROU]" if verrouille else "",
	]

	if connu:
		var eff: SpellEffect = ecole.effet(slot.effect_index) if ecole != null else null
		if eff != null:
			lignes += "[b]%s[/b]\n%s · %s\n" % [
				eff.nom, eff.libelle_famille(), eff.libelle_puissance()]
		else:
			lignes += "[b]?[/b]\neffet introuvable\n"
	else:
		lignes += "[color=#8a8a95][b]???[/b]\nlance-le pour découvrir[/color]\n"

	# Les chiffres bruts : c'est ce qui rend le reroll compréhensible.
	lignes += "[color=#7b7b88]effet %d sur %d du pool[/color]\n" % [
		slot.effect_index + 1, slot.pool_size,
	]
	if cd > 0.0:
		lignes += "[color=#ff9b6a]recharge %.1fs[/color]" % cd
	elif verrouille:
		lignes += "[color=#8fd694]tenu jusqu'à l'étage %d[/color]" % (slot.locked_until_floor + 1)
	else:
		lignes += "[color=#8fd694]prêt[/color]"

	_cartes[i].text = lignes
