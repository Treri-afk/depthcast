class_name TeleportPreview
extends MeshInstance3D
## Disque qui montre où l'on atterrira avant d'appuyer.
##
## Il ne s'affiche que si un slot PRÊT porte une téléportation DÉCOUVERTE.
## L'afficher sur un slot encore en ??? révélerait le sort avant de l'avoir
## lancé, ce qui viderait l'état de découverte de son sens.

var joueur: PlayerAvatar
var caster: SpellCaster


func _ready() -> void:
	var cylindre := CylinderMesh.new()
	cylindre.top_radius = 0.75
	cylindre.bottom_radius = 0.75
	cylindre.height = 0.12
	mesh = cylindre

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.66, 0.44, 0.95, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.66, 0.44, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = mat
	visible = false


func _process(_delta: float) -> void:
	var portee: float = _portee_disponible()
	visible = portee > 0.0
	if visible:
		global_position = joueur.point_vise(portee) - Vector3(0, 0.9, 0)


func _portee_disponible() -> float:
	if caster == null or joueur == null or not GameState.is_in_run():
		return 0.0
	var etage: int = GameState.run.floor_index
	for i: int in PlayerState.SLOT_COUNT:
		var slot: SpellSlot = GameState.run.players[0].slots[i]
		if not slot.is_discovered_on(etage) or joueur.cooldown_restant(i) > 0.0:
			continue
		var effet: SpellEffect = caster.effet_actif(0, i)
		if effet != null and effet.comportement == SpellEffect.Comportement.TELEPORT:
			return effet.portee
	return 0.0
