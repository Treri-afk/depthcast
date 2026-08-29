class_name PrototypeHud
extends Control
## HUD du prototype. JETABLE — la vraie UI arrive en C8.
##
## Il ne fait que LIRE GameState et afficher. Il ne modifie rien : les boutons
## de verrouillage émettent un signal que la racine du prototype traite.
##
## Le point important à ressentir ici : un slot non découvert affiche `???`.
## Tu ne sais pas ce que fait ton bouton tant que tu ne l'as pas pressé sur cet
## étage — même s'il était verrouillé depuis l'étage d'avant.

signal verrou_demande(slot_index: int)
signal etage_suivant_demande()
## Demande de changer l'école d'un slot. `pas` vaut -1 ou +1.
signal ecole_changee(slot_index: int, pas: int)

var joueur: PlayerAvatar = null

var _etiquette_haut: Label
var _slots: Array[Panel] = []
var _labels_slot: Array[Label] = []
var _boutons_verrou: Array[Button] = []
var _journal: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_etiquette_haut = Label.new()
	_etiquette_haut.position = Vector2(18, 14)
	_etiquette_haut.add_theme_font_size_override("font_size", 17)
	add_child(_etiquette_haut)

	_journal = Label.new()
	_journal.position = Vector2(18, 44)
	_journal.add_theme_font_size_override("font_size", 14)
	_journal.modulate = Color(1, 1, 1, 0.75)
	add_child(_journal)

	var barre := HBoxContainer.new()
	barre.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	barre.position = Vector2(-330, -128)
	barre.add_theme_constant_override("separation", 10)
	add_child(barre)

	for i: int in 4:
		var colonne := VBoxContainer.new()
		colonne.custom_minimum_size = Vector2(155, 0)

		# Flèches de changement d'école : comparer deux écoles sans relancer.
		var choix := HBoxContainer.new()
		var gauche := Button.new()
		gauche.text = "<"
		gauche.custom_minimum_size = Vector2(30, 0)
		gauche.pressed.connect(func() -> void: ecole_changee.emit(i, -1))
		var droite := Button.new()
		droite.text = ">"
		droite.custom_minimum_size = Vector2(30, 0)
		droite.pressed.connect(func() -> void: ecole_changee.emit(i, 1))
		var espace := Control.new()
		espace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choix.add_child(gauche)
		choix.add_child(espace)
		choix.add_child(droite)
		colonne.add_child(choix)

		var panneau := Panel.new()
		panneau.custom_minimum_size = Vector2(155, 62)
		var label := Label.new()
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		panneau.add_child(label)
		colonne.add_child(panneau)

		var bouton := Button.new()
		bouton.text = "Verrouiller"
		bouton.pressed.connect(func() -> void: verrou_demande.emit(i))
		colonne.add_child(bouton)

		barre.add_child(colonne)
		_slots.append(panneau)
		_labels_slot.append(label)
		_boutons_verrou.append(bouton)

	# Réticule : indispensable en vue subjective pour savoir où l'on vise.
	var reticule := Label.new()
	reticule.text = "+"
	reticule.add_theme_font_size_override("font_size", 24)
	reticule.set_anchors_preset(Control.PRESET_CENTER)
	reticule.position = Vector2(-8, -18)
	reticule.modulate = Color(1, 1, 1, 0.7)
	add_child(reticule)

	var suivant := Button.new()
	suivant.text = "Étage suivant  (F)"
	suivant.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	suivant.position = Vector2(-190, -52)
	suivant.custom_minimum_size = Vector2(170, 36)
	suivant.pressed.connect(func() -> void: etage_suivant_demande.emit())
	add_child(suivant)


func journalise(texte: String) -> void:
	_journal.text = texte


func _process(_delta: float) -> void:
	if not GameState.is_in_run():
		return
	var p: PlayerState = GameState.run.players[0]
	var etage: int = GameState.run.floor_index

	_etiquette_haut.text = "Étage %d   ·   PV %d/%d   ·   Résonance %d   ·   seed %d" % [
		etage + 1, p.hp, p.max_hp, GameState.run.resonance_pool, GameState.run.run_seed,
	]

	for i: int in _labels_slot.size():
		var slot: SpellSlot = p.slots[i]
		var ecole: Dictionary = PrototypeCatalogue.school_by_id(slot.school_id)
		var nom_ecole: String = String(ecole.get("nom", "?"))
		var couleur: Color = ecole.get("couleur", Color.WHITE)

		var titre: String = "???"
		if slot.is_discovered_on(etage):
			var eff: Dictionary = PrototypeCatalogue.effect(slot.school_id, slot.effect_index)
			titre = String(eff.get("nom", "?"))

		var verrou: String = "  🔒" if slot.is_locked_for(etage + 1) else ""
		var cd: float = joueur.cooldown_restant(i) if joueur != null else 0.0
		var attente: String = "  (%.1fs)" % cd if cd > 0.0 else ""

		_labels_slot[i].text = "%d · %s%s\n%s%s" % [i + 1, nom_ecole, verrou, titre, attente]
		_labels_slot[i].modulate = couleur if slot.is_discovered_on(etage) else Color(0.65, 0.65, 0.65)
		_boutons_verrou[i].disabled = slot.is_locked_for(etage + 1)
