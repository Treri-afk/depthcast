class_name EnemyProjectile
extends Area3D
## Le tir d'un monstre. Il passe par le resolver comme tout le reste (R4) :
## un monstre décrit son intention, il n'inflige rien lui-même.

const RAYON: float = 0.3
const PORTEE: float = 22.0
const DUREE: float = 1.7

var degats: int = 8
var direction: Vector3 = Vector3.FORWARD

var _consomme: bool = false


static func cree(fx: FxLibrary, depuis: Vector3, vers: Vector3,
		degats_infliges: int) -> EnemyProjectile:
	var tir := EnemyProjectile.new()
	tir.position = depuis
	tir.direction = vers
	tir.degats = degats_infliges

	var forme := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RAYON
	forme.shape = sphere
	tir.add_child(forme)
	tir.add_child(fx.sphere_lumineuse(RAYON, Color(0.85, 0.4, 0.9)))
	return tir


func _ready() -> void:
	body_entered.connect(_sur_contact)
	var tween := create_tween()
	tween.tween_property(self, "position", position + direction * PORTEE, DUREE)
	tween.tween_callback(queue_free)


func _sur_contact(corps: Node3D) -> void:
	if _consomme:
		return
	_consomme = true
	if corps is PlayerAvatar:
		var intent := EffectIntent.new()
		intent.source_player_id = -1
		intent.source_slot = -1
		intent.kind = EffectIntent.Kind.DAMAGE
		intent.amount = degats
		intent.target_ids = PackedInt64Array([0])
		EffectResolver.submit(intent)
	queue_free()
