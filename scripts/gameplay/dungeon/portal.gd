class_name Portal
extends Node3D
## Le portail de descente. Il ne décide de rien : c'est le FloorDirector qui
## dit s'il est franchissable.


static func cree(pos: Vector3) -> Portal:
	var portail := Portal.new()
	portail.position = Vector3(pos.x, 0.1, pos.z)

	var anneau := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.5
	mesh.outer_radius = 2.0
	anneau.mesh = mesh
	anneau.rotation_degrees = Vector3(90, 0, 0)
	anneau.position = Vector3(0, 2.0, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.75, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.7, 1.0)
	mat.emission_energy_multiplier = 1.6
	anneau.material_override = mat
	portail.add_child(anneau)
	return portail


func _process(delta: float) -> void:
	rotate_y(delta * 0.6)
