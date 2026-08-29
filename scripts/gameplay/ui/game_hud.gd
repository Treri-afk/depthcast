class_name GameHud
extends Control
## Interface de jeu. Elle assemble ses morceaux et LIT l'état — elle ne le
## modifie jamais : les boutons émettent des signaux que la racine traite.
##
## Sa mission est de rendre lisible ce que fait le moteur. Les panneaux et les
## cartes vivent dans ui/parts/.

signal ecole_changee(slot_index: int, pas: int)

var joueur: PlayerAvatar = null
var caster: SpellCaster = null

var _statut: HudPanel
var _aide: HudPanel
var _journal: Label
var _invite: Label
var _cartes: Array[HudSlotCard] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_statut = HudPanel.cree(16, 14, 452, 116, false)
	add_child(_statut)

	_aide = HudPanel.cree(-346, 14, 330, 168, true)
	add_child(_aide)
	_aide.texte.text = ("[b]Commandes[/b]\n"
		+ "ZQSD / WASD — se déplacer\n"
		+ "Espace — sauter  ·  Souris — viser\n"
		+ "Clic ou 1-4 — lancer un sort\n"
		+ "[color=#ffd24a]E — interagir (marchand, portail)[/color]\n"
		+ "[color=#ffd24a]F — ramasser / poser  ·  G — lancer[/color]\n"
		+ "[color=#ffd24a]Maj + 1-4 — changer l'école du slot[/color]\n"
		+ "Échap — libérer le curseur\n"
		+ "Clic droit — reprendre la visée")

	_journal = _etiquette(Vector2(24, 140), 14, Color(1, 0.85, 0.45))
	add_child(_journal)

	_invite = _etiquette(Vector2.ZERO, 17, Color(1, 0.93, 0.6))
	_invite.set_anchors_preset(Control.PRESET_CENTER)
	_invite.offset_left = -320
	_invite.offset_right = 320
	_invite.offset_top = 40
	_invite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_invite)

	_construit_les_cartes()
	_construit_le_reticule()


## L'ancrage passe par des offsets explicites et non par un preset seul : un
## preset appliqué à un conteneur le laisse avec une taille nulle, ce qui avait
## rendu la barre entièrement invisible.
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

	for i: int in PlayerState.SLOT_COUNT:
		var carte := HudSlotCard.cree(i)
		carte.ecole_demandee.connect(func(index: int, pas: int) -> void:
			ecole_changee.emit(index, pas))
		barre.add_child(carte)
		_cartes.append(carte)


func _construit_le_reticule() -> void:
	var reticule := _etiquette(Vector2.ZERO, 26, Color(1, 1, 1, 0.65))
	reticule.text = "+"
	reticule.set_anchors_preset(Control.PRESET_CENTER)
	reticule.offset_left = -9
	reticule.offset_top = -20
	add_child(reticule)


func _etiquette(pos: Vector2, taille: int, couleur: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", taille)
	label.add_theme_color_override("font_color", couleur)
	return label


## Ligne de raccourcis de développement, vide en build de release.
func aide_debug(texte: String) -> void:
	if texte.is_empty():
		return
	_aide.texte.text += "\n\n" + texte


func journalise(texte: String) -> void:
	_journal.text = texte


func invite(texte: String) -> void:
	_invite.text = texte


func _process(_delta: float) -> void:
	if not GameState.is_in_run():
		return
	var p: PlayerState = GameState.local_player()
	if p == null:
		return
	var etage: int = GameState.run.floor_index

	var curseur: String = "capturé" if (joueur != null and joueur.souris_capturee()) \
		else "[color=#ffd24a]LIBRE — clic droit pour viser[/color]"

	_statut.texte.text = ("[b]Étage %d[/b]   ·   %d monstre(s) restant(s)\n"
		+ "PV [b]%d[/b] / %d\n"
		+ "Résonance (pot commun) : [b]%d[/b]\n"
		+ "seed %d   ·   curseur %s%s") % [
			etage + 1, GameState.run.alive_monsters().size(), p.hp, p.max_hp,
			GameState.run.resonance_pool, GameState.run.run_seed, curseur,
			_ligne_de_session()]

	for carte: HudSlotCard in _cartes:
		carte.rafraichit(p.slots[carte.slot_index], etage,
			joueur.cooldown_restant(carte.slot_index) if joueur != null else 0.0)


## L'état réseau, affiché en jeu et pas seulement au salon.
##
## Sans lui, deux fenêtres qui jouent chacune leur partie sont indiscernables de
## deux fenêtres qui jouent ensemble tant qu'on ne s'est pas cherché du regard.
## Une ligne lève le doute, et elle disparaît en solo.
func _ligne_de_session() -> String:
	if not Net.en_ligne():
		return ""
	return "\n[color=#7fd0ff]co-op · %d joueur(s) · tu es %s (joueur %d)[/color]" % [
		Net.nombre_de_joueurs(),
		"l'hôte" if multiplayer.is_server() else "invité",
		GameState.local_player_id + 1]
