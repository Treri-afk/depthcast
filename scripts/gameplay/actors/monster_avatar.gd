class_name MonsterAvatar
extends CharacterBody3D
## Le corps d'un monstre : il se déplace, il encaisse visuellement, il bouscule.
##
## Il ne décide de rien — c'est MonsterBrain qui choisit. Il ne calcule aucun
## dégât non plus : il soumet une intention au resolver (R4). Ses points de vie
## vivent dans MonsterState, à l'intérieur de GameState (R1).

const AMORTISSEMENT: float = 6.0
const GRAVITE: float = 26.0
## Force avec laquelle un monstre bouscule les caisses et les tables.
const POUSSEE_OBJETS: float = 3.0

signal veut_tirer(depuis: Vector3, direction: Vector3, degats: int)

var monster_id: int = -1
## Ce que le monstre poursuit. Un leurre peut prendre la place du joueur.
var cible: Node3D = null
## Tant que c'est vrai, le monstre a perdu la trace du joueur (Voile).
var aveugle: bool = false
var stats: MonsterStats = null

var _cerveau: MonsterBrain
var _impulsion: Vector3 = Vector3.ZERO
var _facteur_vitesse: float = 1.0
var _ralenti_restant: float = 0.0
var _teinte_restante: float = 0.0
var _telegraphe: float = 0.0
var _materiau: StandardMaterial3D = null


func _ready() -> void:
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)

	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null:
		_materiau = mesh.get_surface_override_material(0) as StandardMaterial3D

	_cerveau = _cree_cerveau()
	_cerveau.veut_frapper.connect(_frappe)
	_cerveau.veut_tirer.connect(_tire)
	_cerveau.engage_l_attaque.connect(_signale_attaque)


## Point d'extension : un boss redéfinit cette méthode pour installer le sien.
func _cree_cerveau() -> MonsterBrain:
	return MonsterBrain.new(stats, 1.0 if (monster_id % 2 == 0) else -1.0)


func _physics_process(delta: float) -> void:
	_telegraphe = maxf(0.0, _telegraphe - delta)
	_maj_ralentissement(delta)
	_maj_teinte(delta)
	_impulsion = _impulsion.move_toward(Vector3.ZERO, AMORTISSEMENT * delta)

	var deplacement := Vector3.ZERO
	if cible != null and not aveugle:
		deplacement = _cerveau.decide(delta, global_position, cible, _facteur_vitesse)

	velocity.x = deplacement.x + _impulsion.x
	velocity.z = deplacement.z + _impulsion.z
	_maj_vertical(delta)
	move_and_slide()
	_bouscule_les_objets()


func _maj_vertical(delta: float) -> void:
	if not stats.vole:
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITE * delta
		return
	# Le volant se maintient à son altitude, avec un léger flottement pour
	# qu'il ne ressemble pas à une cible fixe.
	var voulue: float = stats.hauteur_vol \
		+ sin(float(Time.get_ticks_msec()) * 0.002 + float(monster_id)) * 0.35
	velocity.y = (voulue - global_position.y) * 3.0


## Un monstre qui traverse une caisse sans la bouger casse l'illusion.
func _bouscule_les_objets() -> void:
	for i: int in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var corps := collision.get_collider() as RigidBody3D
		if corps != null:
			corps.apply_central_impulse(-collision.get_normal() * POUSSEE_OBJETS)


# ── Attaques : toujours via le resolver ───────────────────────────────────

func _frappe() -> void:
	var intent := EffectIntent.new()
	intent.source_player_id = -1
	intent.source_slot = -1
	intent.kind = EffectIntent.Kind.DAMAGE
	intent.amount = stats.degats
	intent.target_ids = PackedInt64Array([0])
	EffectResolver.submit(intent)


func _tire(direction: Vector3) -> void:
	veut_tirer.emit(global_position, direction, stats.degats)


## Un éclat juste avant de frapper : sans télégraphe, une attaque n'est pas
## esquivable, elle est seulement subie.
func _signale_attaque() -> void:
	_telegraphe = 0.35
	if _materiau != null:
		_materiau.emission_enabled = true
		_materiau.emission = Color(1.0, 0.85, 0.4)
		_materiau.emission_energy_multiplier = 1.4


# ── Effets subis ──────────────────────────────────────────────────────────

func repousse(vecteur: Vector3) -> void:
	_impulsion += Vector3(vecteur.x, 0.0, vecteur.z)
	if _cerveau != null:
		_cerveau.interrompt_l_assaut()


func ralentis(facteur: float, duree: float) -> void:
	_facteur_vitesse = minf(_facteur_vitesse, facteur)
	_ralenti_restant = maxf(_ralenti_restant, duree)
	if _materiau != null:
		_materiau.emission_enabled = true
		_materiau.emission = Color(0.35, 0.7, 1.0)
		_materiau.emission_energy_multiplier = 0.5


func encaisse_visuellement() -> void:
	_teinte_restante = 1.0
	scale = Vector3(1.2, 0.85, 1.2)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.18)


func _maj_ralentissement(delta: float) -> void:
	if _ralenti_restant <= 0.0:
		_facteur_vitesse = 1.0
		return
	_ralenti_restant -= delta
	if _ralenti_restant <= 0.0:
		_facteur_vitesse = 1.0
		if _materiau != null and _telegraphe <= 0.0:
			_materiau.emission_enabled = false


func _maj_teinte(delta: float) -> void:
	if _materiau != null and _telegraphe <= 0.0 and _ralenti_restant <= 0.0 \
			and _teinte_restante <= 0.0 and _materiau.emission_enabled:
		_materiau.emission_enabled = false
	if _teinte_restante <= 0.0:
		return
	_teinte_restante = maxf(0.0, _teinte_restante - delta * 4.0)
	if _materiau != null:
		_materiau.albedo_color = stats.couleur.lerp(Color.WHITE, _teinte_restante)
