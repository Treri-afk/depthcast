class_name RunEndScreen
extends Control
## Écran de fin de run. Il annonce le résultat, verse les Éclats, et affiche la
## seed — sans elle, une run intéressante n'est pas rejouable.

var victoire: bool = false
var etage_atteint: int = 0
var seed_run: int = 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var voile := ColorRect.new()
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	voile.color = Color(0.04, 0.04, 0.07, 0.92)
	add_child(voile)

	var gagne: int = Meta.recompense(etage_atteint, victoire)
	Meta.gagne_eclats(gagne)

	var col := ScreenUtils.colonne(self, 12)
	col.add_child(ScreenUtils.titre(
		"Le Seuil est franchi" if victoire else "La descente s'arrête", 38))
	col.add_child(ScreenUtils.sous_titre(
		"Étage atteint : %d   ·   Éclats gagnés : %d" % [etage_atteint + 1, gagne]))

	var seed_label := ScreenUtils.sous_titre("seed %d" % seed_run,
		Color(1, 1, 1, 0.45))
	col.add_child(seed_label)

	var copier := ScreenUtils.bouton("Copier la seed")
	copier.custom_minimum_size = Vector2(340, 36)
	copier.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(str(seed_run))
		copier.text = "Seed copiée")
	col.add_child(copier)

	var hub := ScreenUtils.bouton("Retour au hub")
	hub.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_HUB))
	col.add_child(hub)
