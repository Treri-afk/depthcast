class_name RerollStation
extends LabStation
## Pupitre des mutations : rejoue le reroll à la demande.
##
## Le moment le plus important du jeu, et le plus difficile à calibrer, parce
## qu'il ne survient qu'une fois par étage. Ici il survient quand on veut, avec
## la vraie séquence et le vrai flux aléatoire du joueur — pas une imitation.

var _mutations: Array[bool] = []


func titre() -> String:
	return "Pupitre des mutations"


func installe() -> void:
	pancarte("PUPITRE DES MUTATIONS\n[E] provoquer un reroll", 3.4, 34)
	dalle(4.0, Content.palette.socle)

	var colonne := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.4, 1.0)
	colonne.mesh = mesh
	colonne.position = Vector3(0, 0.7, 0)
	colonne.material_override = MaterialLibrary.aplat(Content.palette.socle,
		MaterialLibrary.Role.INTERACTIF)
	add_child(colonne)

	# On écoute en permanence : les signaux partent PENDANT le reroll, donc
	# s'abonner au moment de l'interaction serait déjà trop tard.
	EventBus.slot_rerolled.connect(func(_j: int, slot: int, _e: int) -> void:
		_note(slot, true))
	EventBus.slot_kept.connect(func(_j: int, slot: int) -> void:
		_note(slot, false))


func invite() -> String:
	return "[E] provoquer un reroll des slots non scellés"


func interagit() -> String:
	if not GameState.is_in_run():
		return ""
	_mutations.clear()
	GameState.reroll_slots(0)
	terrain.montre_le_reroll(_mutations, GameState.run.floor_index)
	return "Reroll provoqué. Les slots scellés ont tenu."


func _note(slot: int, mute: bool) -> void:
	while _mutations.size() <= slot:
		_mutations.append(false)
	_mutations[slot] = mute
