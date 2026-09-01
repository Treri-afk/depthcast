class_name ZoneEffet
extends Area3D
## Une zone qui agit dans la durée : mur de flammes, sol embrasé, totem de soin,
## nappe de gel.
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
## La zone brûle aussi le joueur.
##
## Faux pour tout ce qu'il lance lui-même : un mur de flammes qui brûle son
## lanceur ferait de chaque sort de zone un piège. Vrai pour ce que le décor
## déclenche — une flaque de braise laissée par un tonneau ne demande pas qui a
## allumé le feu, et c'est ce qui empêche de faire sauter un baril à ses pieds
## sans y penser.
var blesse_le_joueur: bool = false
var couleur: Color = Color.WHITE

var _restant: float = 0.0
var _prochain_battement: float = 0.0
var _visuel: MeshInstance3D
var _lampe: OmniLight3D
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

	# Une nappe de flammes doit éclairer la salle, pas seulement s'y voir.
	var lampe := OmniLight3D.new()
	lampe.light_color = couleur
	lampe.light_energy = Content.palette.lumiere_sort_energie
	lampe.omni_range = Content.palette.lumiere_sort_portee * 1.4
	lampe.shadow_enabled = false
	lampe.position = Vector3(0, 0.8, 0)
	add_child(lampe)
	_lampe = lampe

	_materiau = StandardMaterial3D.new()
	# Non éclairée : une nappe est de la lumière, pas une surface.
	_materiau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	var reste: float = clampf(_restant / maxf(duree, 0.01), 0.0, 1.0)
	if _materiau != null:
		_materiau.albedo_color.a = 0.10 + 0.26 * reste
	if _lampe != null:
		_lampe.light_energy = Content.palette.lumiere_sort_energie * reste

	_prochain_battement -= delta
	if _prochain_battement > 0.0:
		return
	_prochain_battement = intervalle
	_bat()


func _bat() -> void:
	var cibles: Array = []
	var joueurs: Array = []
	var touche_le_joueur: bool = false

	for corps: Node3D in get_overlapping_bodies():
		var monstre := corps as MonsterAvatar
		if monstre != null:
			cibles.append(monstre.monster_id)
			if ralentissement < 1.0:
				monstre.ralentis(ralentissement, intervalle * 1.6)
			continue
		# Une caisse posée dans un mur de flammes finit par brûler. Et un
		# tonneau explosif posé dedans finit par sauter, ce qui n'a jamais été
		# écrit nulle part : c'est la conséquence de deux règles simples.
		var objet := corps as PropDestructible
		if objet != null:
			if degats > 0:
				objet.encaisse(degats, global_position)
			continue
		var joueur := corps as PlayerAvatar
		if joueur != null:
			touche_le_joueur = true
			joueurs.append(joueur.player_id)

	# Les dégâts ne visent les joueurs que si la zone est hostile ; le soin, lui,
	# va à tous ceux qui sont dedans. D'où deux listes tirées du même passage.
	var brules: Array = joueurs if blesse_le_joueur else []
	if degats > 0 and not (cibles.is_empty() and brules.is_empty()):
		var intent := EffectIntent.new()
		intent.source_player_id = source_player_id
		intent.source_slot = source_slot
		intent.kind = EffectIntent.Kind.DAMAGE
		intent.amount = degats
		# L'interface a besoin de savoir OÙ ça brûle pour l'indiquer : en vue
		# subjective, encaisser sans savoir d'où ça vient est illisible.
		intent.origine = global_position
		intent.target_monsters = PackedInt64Array(cibles)
		intent.target_ids = PackedInt64Array(brules)
		EffectResolver.submit(intent)

	# Le soin va à QUI se tient dedans, pas à celui qui a posé le totem. Une
	# nappe qui ne soignerait que son auteur ne pourrait relever personne, et
	# c'est justement par là que passe la relève.
	if soin > 0 and not joueurs.is_empty():
		var intent := EffectIntent.new()
		intent.source_player_id = source_player_id
		intent.source_slot = source_slot
		intent.kind = EffectIntent.Kind.HEAL
		intent.amount = soin
		intent.origine = global_position
		intent.target_ids = PackedInt64Array(joueurs)
		EffectResolver.submit(intent)
