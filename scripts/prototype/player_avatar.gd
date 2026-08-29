class_name PlayerAvatar
extends CharacterBody3D
## Le corps du joueur dans le prototype. JETABLE — remplacé en C3.
##
## Il affiche et il déplace. Il ne détient AUCUN point de vie ni aucune donnée
## de sort : tout ça vit dans GameState (R1). Il ne fait que soumettre des
## intentions à l'EffectResolver (R4).
##
## ── Les valeurs de feel sont toutes ici, en haut. C'est fait pour être trituré.

const VITESSE: float = 7.0
## Plus c'est haut, plus le personnage démarre sec. Bas = patinage.
const ACCELERATION: float = 12.0
const FREINAGE: float = 16.0
const VITESSE_ROTATION: float = 14.0

signal a_lance(slot_index: int, direction: Vector3)

var player_id: int = 0
## Cooldown restant par slot, en secondes.
var _cooldowns: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _vise: Vector3 = Vector3.FORWARD


func _physics_process(delta: float) -> void:
	for i: int in _cooldowns.size():
		_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)

	var entree := Vector2(
		Input.get_action_strength("proto_droite") - Input.get_action_strength("proto_gauche"),
		Input.get_action_strength("proto_bas") - Input.get_action_strength("proto_haut"),
	)
	var voulu := Vector3(entree.x, 0.0, entree.y)
	if voulu.length() > 1.0:
		voulu = voulu.normalized()
	voulu *= VITESSE

	var taux: float = ACCELERATION if voulu.length() > 0.1 else FREINAGE
	velocity.x = move_toward(velocity.x, voulu.x, taux * delta)
	velocity.z = move_toward(velocity.z, voulu.z, taux * delta)
	velocity.y = 0.0
	move_and_slide()

	_oriente(delta)
	_ecoute_les_sorts()


## Le personnage regarde la souris. C'est ce qui rend la visée lisible sans
## avoir à capturer le curseur — bien plus confortable pour un prototype.
func _oriente(delta: float) -> void:
	var cible: Vector3 = _point_sous_la_souris()
	var vers: Vector3 = cible - global_position
	vers.y = 0.0
	if vers.length_squared() < 0.01:
		return
	_vise = vers.normalized()
	var angle: float = atan2(_vise.x, _vise.z)
	rotation.y = lerp_angle(rotation.y, angle, VITESSE_ROTATION * delta)


## Projette la souris sur le plan du sol (y = 0).
func _point_sous_la_souris() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return global_position + _vise
	var souris: Vector2 = get_viewport().get_mouse_position()
	var origine: Vector3 = cam.project_ray_origin(souris)
	var direction: Vector3 = cam.project_ray_normal(souris)
	if absf(direction.y) < 0.0001:
		return global_position + _vise
	var distance: float = -origine.y / direction.y
	return origine + direction * distance


func _ecoute_les_sorts() -> void:
	for i: int in 4:
		if Input.is_action_just_pressed("proto_sort_%d" % (i + 1)) and _cooldowns[i] <= 0.0:
			a_lance.emit(i, _vise)


func demarre_cooldown(slot_index: int, duree: float) -> void:
	if slot_index >= 0 and slot_index < _cooldowns.size():
		_cooldowns[slot_index] = duree


func cooldown_restant(slot_index: int) -> float:
	return _cooldowns[slot_index] if slot_index < _cooldowns.size() else 0.0


func direction_visee() -> Vector3:
	return _vise
