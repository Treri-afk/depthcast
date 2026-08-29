class_name ZoneEffet
extends Area3D
## Une zone qui agit dans la durée : mur de flammes, sol embrasé, totem de soin,
## nappe de gel. JETABLE — remplacée par de vraies Resources en C2.
##
## Elle ne calcule aucun dégât elle-même. À chaque battement, elle regarde qui
## est à l'intérieur et soumet une intention à l'EffectResolver (R4). C'est ce
## qui garantit que deux zones qui se chevauchent restent déterministes : leurs
## intentions sont triées, pas appliquées dans l'ordre où elles ont pulsé.

enum Forme { BOITE, SPHERE }

var duree: float = 3.0
var intervalle: float = 0.5
var degats: int = 0
var soin: int = 0
## Facteur de vitesse appliqué aux monstres présents. 1.0 = aucun ralentissement.
var ralentissement: float = 1.0
var source_player_id: int = 0
var source_slot: int = -1
var couleur: Color = Color.WHITE

var _restant: float = 0.0
var _prochain_battement: float = 0.0
var _visuel: MeshInstance3D
var _materiau: StandardMaterial3D


static func cree(forme: Forme, dimensions: Vector3, position_monde: Vector3,
		rotation_y: float = 0.0) -> ZoneEffet:
	var zone := ZoneEffet.new()
	zone.position = position_monde
	zone.rotation.y = rotation_y

	var collision := CollisionShape3D.new()
	var visuel := MeshInstance3D.new()

	if forme == Forme.SPHERE:
		var sphere := SphereShape3D.new()
		sphere.radius = dimensions.x
		collision.shape = sphere
		var mesh := SphereMesh.new()
		mesh.radius = dimensions.x
		mesh.height = dimensions.x * 2.0
		visuel.mesh = mesh
	else:
		var boite := BoxShape3D.new()
		boite.size = dimensions
		collision.shape = boite
		var mesh := BoxMesh.new()
		mesh.size = dimensions
		visuel.mesh = mesh

	zone.add_child(collision)
	visuel.name = "Visuel"
	zone.add_child(visuel)
	zone._visuel = visuel
	return zone


func _ready() -> void:
	_restant = duree
	_prochain_battement = 0.0
	monitoring = true

	_materiau = StandardMaterial3D.new()
	_materiau.albedo_color = Color(couleur.r, couleur.g, couleur.b, 0.32)
	_materiau.emission_enabled = true
	_materiau.emission = couleur
	_materiau.emission_energy_multiplier = 0.6
	_materiau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materiau.cull_mode = BaseMaterial3D.CULL_DISABLED
	if _visuel != null:
		_visuel.material_override = _materiau


func _physics_process(delta: float) -> void:
	_restant -= delta
	if _restant <= 0.0:
		queue_free()
		return

	# La zone s'estompe en fin de vie : on voit qu'elle va disparaître.
	if _materiau != null:
		var reste: float = clampf(_restant / maxf(duree, 0.01), 0.0, 1.0)
		_materiau.albedo_color.a = 0.10 + 0.26 * reste

	_prochain_battement -= delta
	if _prochain_battement > 0.0:
		return
	_prochain_battement = intervalle
	_bat()


func _bat() -> void:
	var cibles: Array = []
	var touche_le_joueur: bool = false

	for corps: Node3D in get_overlapping_bodies():
		var monstre := corps as MonsterAvatar
		if monstre != null:
			cibles.append(monstre.monster_id)
			if ralentissement < 1.0:
				monstre.ralentis(ralentissement, intervalle * 1.6)
			continue
		if corps is PlayerAvatar:
			touche_le_joueur = true

	if degats > 0 and not cibles.is_empty():
		var intent := EffectIntent.new()
		intent.source_player_id = source_player_id
		intent.source_slot = source_slot
		intent.kind = EffectIntent.Kind.DAMAGE
		intent.amount = degats
		intent.target_monsters = PackedInt64Array(cibles)
		EffectResolver.submit(intent)

	if soin > 0 and touche_le_joueur:
		var intent := EffectIntent.new()
		intent.source_player_id = source_player_id
		intent.source_slot = source_slot
		intent.kind = EffectIntent.Kind.HEAL
		intent.amount = soin
		intent.target_ids = PackedInt64Array([source_player_id])
		EffectResolver.submit(intent)
