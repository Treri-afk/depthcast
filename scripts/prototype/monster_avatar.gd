class_name MonsterAvatar
extends CharacterBody3D
## Le corps d'un monstre dans le prototype. JETABLE — remplacé en C3.
##
## Il ne connaît que son `monster_id`. Ses points de vie vivent dans
## MonsterState, à l'intérieur de GameState (R1). Il ne s'inflige ni ne
## s'applique jamais de dégâts lui-même : il écoute les signaux et réagit.

const VITESSE: float = 2.6
const DEGATS_CONTACT: int = 6
const DELAI_ENTRE_COUPS: float = 1.0
const PORTEE_CONTACT: float = 1.8

var monster_id: int = -1
var cible: Node3D = null

var _recharge: float = 0.0
var _mesh: MeshInstance3D = null
var _materiau: StandardMaterial3D = null
var _teinte_restante: float = 0.0


func _ready() -> void:
	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	if _mesh != null:
		_materiau = _mesh.get_surface_override_material(0) as StandardMaterial3D


func _physics_process(delta: float) -> void:
	_recharge = maxf(0.0, _recharge - delta)

	if _teinte_restante > 0.0:
		_teinte_restante = maxf(0.0, _teinte_restante - delta * 4.0)
		if _materiau != null:
			_materiau.albedo_color = Color(0.75, 0.3, 0.35).lerp(
				Color(1.0, 1.0, 1.0), _teinte_restante
			)

	if cible == null:
		return

	var vers: Vector3 = cible.global_position - global_position
	vers.y = 0.0
	var distance: float = vers.length()

	if distance > PORTEE_CONTACT:
		velocity.x = vers.normalized().x * VITESSE
		velocity.z = vers.normalized().z * VITESSE
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _recharge <= 0.0:
			_frappe()
			_recharge = DELAI_ENTRE_COUPS

	velocity.y = 0.0
	move_and_slide()


## Même un monstre passe par le resolver : c'est lui, et lui seul, qui touche
## aux points de vie (R4). L'avatar se contente de décrire son intention.
func _frappe() -> void:
	var intent := EffectIntent.new()
	intent.source_player_id = -1
	intent.source_slot = -1
	intent.kind = EffectIntent.Kind.DAMAGE
	intent.amount = DEGATS_CONTACT
	intent.target_ids = PackedInt64Array([0])
	EffectResolver.submit(intent)


func encaisse_visuellement() -> void:
	_teinte_restante = 1.0
	scale = Vector3(1.25, 0.8, 1.25)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.18)
