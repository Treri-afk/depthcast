class_name MonsterAvatar
extends CharacterBody3D
## Le corps d'un monstre dans le prototype. JETABLE — remplacé en C3.
##
## Il ne connaît que son `monster_id`. Ses points de vie vivent dans
## MonsterState, à l'intérieur de GameState (R1). Il ne s'inflige ni ne
## s'applique jamais de dégâts lui-même : il écoute et il réagit.
##
## Sa position, en revanche, vit ici. C'est une simplification assumée du
## prototype : les positions n'entreront dans GameState qu'en C3, avec la
## réplication. D'ici là, pousser ou attirer un monstre est un effet de scène.

const VITESSE: float = 2.6
const DEGATS_CONTACT: int = 6
const DELAI_ENTRE_COUPS: float = 1.0
const PORTEE_CONTACT: float = 1.8
## Vitesse à laquelle une poussée s'essouffle.
const AMORTISSEMENT: float = 6.0

var monster_id: int = -1
## Ce que le monstre poursuit. Un leurre peut prendre la place du joueur.
var cible: Node3D = null
## Tant que c'est vrai, le monstre a perdu la trace du joueur (Voile).
var aveugle: bool = false

var _recharge: float = 0.0
var _impulsion: Vector3 = Vector3.ZERO
var _facteur_vitesse: float = 1.0
var _ralenti_restant: float = 0.0
var _mesh: MeshInstance3D = null
var _materiau: StandardMaterial3D = null
var _teinte_restante: float = 0.0


func _ready() -> void:
	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	if _mesh != null:
		_materiau = _mesh.get_surface_override_material(0) as StandardMaterial3D


func _physics_process(delta: float) -> void:
	_recharge = maxf(0.0, _recharge - delta)
	_maj_ralentissement(delta)
	_maj_teinte(delta)

	# La poussée s'applique quel que soit l'état : être repoussé pendant qu'on
	# est gelé doit rester lisible.
	_impulsion = _impulsion.move_toward(Vector3.ZERO, AMORTISSEMENT * delta)

	var deplacement := Vector3.ZERO
	if cible != null and not aveugle:
		var vers: Vector3 = cible.global_position - global_position
		vers.y = 0.0
		if vers.length() > PORTEE_CONTACT:
			deplacement = vers.normalized() * VITESSE * _facteur_vitesse
		elif _recharge <= 0.0 and not (cible is Node3D and cible.is_in_group("leurre")):
			_frappe()
			_recharge = DELAI_ENTRE_COUPS

	velocity.x = deplacement.x + _impulsion.x
	velocity.z = deplacement.z + _impulsion.z
	velocity.y = 0.0
	move_and_slide()


func _maj_ralentissement(delta: float) -> void:
	if _ralenti_restant <= 0.0:
		_facteur_vitesse = 1.0
		return
	_ralenti_restant -= delta
	if _ralenti_restant <= 0.0:
		_facteur_vitesse = 1.0
		if _materiau != null:
			_materiau.emission_enabled = false


func _maj_teinte(delta: float) -> void:
	if _teinte_restante <= 0.0:
		return
	_teinte_restante = maxf(0.0, _teinte_restante - delta * 4.0)
	if _materiau != null:
		_materiau.albedo_color = Color(0.75, 0.3, 0.35).lerp(
			Color(1.0, 1.0, 1.0), _teinte_restante
		)


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


## Poussée ou aspiration. Le vecteur donne la direction et la force.
func repousse(vecteur: Vector3) -> void:
	_impulsion += Vector3(vecteur.x, 0.0, vecteur.z)


func ralentis(facteur: float, duree: float) -> void:
	_facteur_vitesse = minf(_facteur_vitesse, facteur)
	_ralenti_restant = maxf(_ralenti_restant, duree)
	if _materiau != null:
		_materiau.emission_enabled = true
		_materiau.emission = Color(0.35, 0.7, 1.0)
		_materiau.emission_energy_multiplier = 0.5


func encaisse_visuellement() -> void:
	_teinte_restante = 1.0
	scale = Vector3(1.25, 0.8, 1.25)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.18)
