class_name PropDestructible
extends RigidBody3D
## Une caisse, un tonneau, une table : du décor réactif.
##
## Ses points de vie vivent ici et non dans GameState, contrairement à ceux des
## monstres. C'est assumé : un tonneau n'est pas un objet de gameplay répliqué,
## c'est du décor réactif. Le jour où il faudra qu'un coéquipier voie la même
## caisse voler, il rejoindra l'état — pas avant.

const POUSSEE_MINIMALE: float = 2.0

var pv: int = 18
var couleur: Color = Color(0.48, 0.36, 0.24)

var _mesh: MeshInstance3D
var _materiau: ShaderMaterial
var _teinte: float = 0.0


func _ready() -> void:
	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	if _mesh != null:
		_materiau = _mesh.material_override as ShaderMaterial


func _process(delta: float) -> void:
	if _teinte <= 0.0:
		return
	_teinte = maxf(0.0, _teinte - delta * 3.5)
	if _materiau != null:
		_materiau.set_shader_parameter("albedo",
			couleur.lerp(Content.palette.lisere_blanc, _teinte))


## Encaisse des dégâts. Retourne true si l'objet vient d'être détruit.
func encaisse(degats: int, depuis: Vector3 = Vector3.ZERO) -> bool:
	if degats <= 0:
		return false
	pv -= degats
	_teinte = 1.0

	if depuis != Vector3.ZERO:
		var sens: Vector3 = (global_position - depuis).normalized()
		apply_central_impulse((sens + Vector3.UP * 0.2) * POUSSEE_MINIMALE * mass * 0.4)

	if pv > 0:
		return false
	_casse()
	return true


func _casse() -> void:
	_projette_des_debris()
	queue_free()


## Quelques éclats qui retombent : sans eux, l'objet disparaît d'un coup et on
## doute d'avoir fait quelque chose.
func _projette_des_debris() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 100.0) + int(global_position.z * 7.0)

	for i: int in 5:
		var eclat := RigidBody3D.new()
		eclat.mass = 0.6
		eclat.linear_damp = 1.2
		eclat.position = global_position + Vector3(
			rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, 0.5),
			rng.randf_range(-0.3, 0.3))

		var taille := Vector3.ONE * rng.randf_range(0.16, 0.3)
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = taille
		forme.shape = boite
		eclat.add_child(forme)

		var visuel := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = taille
		visuel.mesh = mesh
		visuel.material_override = MaterialLibrary.aplat(couleur.darkened(0.15),
			MaterialLibrary.Role.OBJET)
		eclat.add_child(visuel)

		parent.add_child(eclat)
		eclat.apply_central_impulse(Vector3(
			rng.randf_range(-2.5, 2.5), rng.randf_range(2.0, 4.5),
			rng.randf_range(-2.5, 2.5)))

		# Les éclats ne s'accumulent pas : le sol reste lisible.
		eclat.get_tree().create_timer(2.5).timeout.connect(func() -> void:
			if is_instance_valid(eclat):
				eclat.queue_free()
		)
