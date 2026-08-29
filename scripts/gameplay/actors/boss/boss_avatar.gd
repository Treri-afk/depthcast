class_name BossAvatar
extends MonsterAvatar
## Le corps d'un boss. Il réutilise tout du monstre ordinaire — déplacement,
## collisions, encaissement — et n'ajoute que ce qui lui est propre : le suivi
## des phases et l'onde de choc de son attaque spéciale.
##
## Écrire un boss singulier passe par BossBrain, pas par ce fichier.

signal phase_changee(phase: int, total: int)

var boss_stats: BossStats


func _ready() -> void:
	super()
	boss_stats = stats as BossStats
	if boss_stats == null:
		push_error("BossAvatar attend des BossStats.")
		return

	var cerveau := _cerveau as BossBrain
	cerveau.veut_special.connect(_lance_le_special)
	cerveau.phase_changee.connect(func(p: int, total: int) -> void:
		_signale_la_phase(p)
		phase_changee.emit(p, total))

	EventBus.monster_damaged.connect(_sur_degat)


## Le cerveau d'un boss n'est pas celui d'un monstre ordinaire.
func _cree_cerveau() -> MonsterBrain:
	return BossBrain.new(stats as BossStats, 1.0)


func _sur_degat(id: int, pv_restants: int) -> void:
	if id != monster_id or boss_stats == null:
		return
	var etat: MonsterState = GameState.run.get_monster(monster_id)
	if etat == null or etat.max_hp <= 0:
		return
	(_cerveau as BossBrain).evalue_les_phases(float(pv_restants) / float(etat.max_hp))


## Onde de choc autour du boss. Elle passe par le resolver comme tout le reste :
## le boss décrit une intention, il n'inflige rien lui-même (R4).
func _lance_le_special(_phase: int) -> void:
	var joueurs: Array = []
	var distance: float = global_position.distance_to(
		_position_de_la_cible())
	if distance <= boss_stats.rayon_special:
		joueurs.append(0)

	if not joueurs.is_empty():
		var intent := EffectIntent.new()
		intent.source_player_id = -1
		intent.source_slot = -1
		intent.kind = EffectIntent.Kind.DAMAGE
		intent.amount = boss_stats.degats_special
		intent.target_ids = PackedInt64Array(joueurs)
		EffectResolver.submit(intent)

	_onde_visuelle()


func _position_de_la_cible() -> Vector3:
	return cible.global_position if cible != null else global_position


func _signale_la_phase(phase: int) -> void:
	# Le boss grossit et s'assombrit à chaque phase : on doit voir qu'il change
	# sans lire une barre de vie.
	var facteur: float = 1.0 + 0.12 * float(phase)
	create_tween().tween_property(self, "scale", Vector3.ONE * facteur, 0.35)


func _onde_visuelle() -> void:
	var visuel := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = boss_stats.rayon_special * 0.8
	mesh.outer_radius = boss_stats.rayon_special
	visuel.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = stats.couleur
	mat.emission_enabled = true
	mat.emission = stats.couleur
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visuel.material_override = mat
	visuel.position = global_position - Vector3(0, 1.0, 0)
	visuel.scale = Vector3(0.2, 1, 0.2)
	get_parent().add_child(visuel)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuel, "scale", Vector3.ONE, 0.45)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(visuel.queue_free)
