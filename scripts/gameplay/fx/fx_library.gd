class_name FxLibrary
extends RefCounted
## Les petits visuels partagés par les sorts : anneaux, cônes, marqueurs.
##
## Regroupés ici parce qu'ils étaient dupliqués dans chaque comportement. Ils
## seront remplacés par de vrais VFX quand la direction artistique sera posée ;
## d'ici là ils servent surtout à rendre chaque sort lisible.

var monde: Node3D


func _init(p_monde: Node3D) -> void:
	monde = p_monde


func sphere_lumineuse(rayon: float, couleur: Color) -> MeshInstance3D:
	var visuel := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = rayon
	mesh.height = rayon * 2.0
	visuel.mesh = mesh
	visuel.material_override = MaterialLibrary.lumineux(couleur)
	return visuel


## Onde circulaire qui s'évase depuis un point.
func anneau(centre: Vector3, rayon: float, couleur: Color) -> void:
	var visuel := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = rayon * 0.85
	mesh.outer_radius = rayon
	visuel.mesh = mesh
	var mat := _materiau_emissif(couleur, true)
	visuel.material_override = mat
	visuel.position = centre - Vector3(0, 0.8, 0)
	visuel.scale = Vector3(0.3, 1, 0.3)
	monde.add_child(visuel)

	var tween := monde.create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuel, "scale", Vector3.ONE, 0.3)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(visuel.queue_free)


func cone(origine: Vector3, direction: Vector3, portee: float, couleur: Color) -> void:
	var visuel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = portee * 0.55
	mesh.bottom_radius = 0.2
	mesh.height = portee
	visuel.mesh = mesh
	var mat := _materiau_emissif(couleur, true)
	mat.albedo_color.a = 0.5
	visuel.material_override = mat
	visuel.position = origine + direction * (portee * 0.5)
	visuel.rotation = Vector3(deg_to_rad(90), atan2(direction.x, direction.z), 0)
	monde.add_child(visuel)

	var tween := monde.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tween.tween_callback(visuel.queue_free)


## Marque un point qui vient d'être quitté ou atteint (téléportation).
func marqueur(pos: Vector3, couleur: Color) -> void:
	var visuel := sphere_lumineuse(0.6, couleur)
	var mat := _materiau_emissif(couleur, true)
	visuel.material_override = mat
	visuel.position = pos
	monde.add_child(visuel)

	var tween := monde.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(visuel.queue_free)


func _materiau_emissif(couleur: Color, transparent: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = couleur
	mat.emission_enabled = true
	mat.emission = couleur
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
