extends Node3D
## Prototype jouable. JETABLE — il existe pour répondre à une seule question :
## subir un reroll et devoir s'adapter, est-ce excitant ou pénible ?
##
## Il construit sa scène par code plutôt qu'en .tscn : c'est plus lisible ici, et
## ça évite d'éditer un fichier de scène à la main. Tout est provisoire.
##
## Ce qu'il respecte scrupuleusement, en revanche :
##   - aucun état de gameplay ici (R1) — les PV vivent dans GameState
##   - aucun randi() direct (R3) — tout passe par RngService
##   - aucun dégât appliqué à la main (R4) — tout passe par l'EffectResolver

# ── Réglages du prototype. Trituré librement. ─────────────────────────────
const MONSTRES_PAR_SALLE: int = 3
const PV_MONSTRE: int = 34
const RESONANCE_PAR_MONSTRE: int = 12
const COUT_VERROU_BASE: int = 18
## Multiplicateur cumulatif par verrou acheté dans l'étage (GDD §4).
## Sans lui, dès qu'on a de la Résonance on fige tout et le jeu n'a plus de sujet.
const MULTIPLICATEURS: Array[float] = [1.0, 1.5, 2.0, 3.0]
const PORTEE_INTERACTION: float = 3.2
const SALLES_PAR_ETAGE: int = 3
const TAILLE_SALLE_MIN: float = 13.0
const TAILLE_SALLE_MAX: float = 19.0
const LONGUEUR_COULOIR: float = 7.0
const LARGEUR_COULOIR: float = 4.0
const HAUTEUR_MUR: float = 4.0
const VITESSE_PROJECTILE: float = 34.0

var _joueur: PlayerAvatar
var _camera: Camera3D
var _hud: PrototypeHud
var _avatars: Dictionary[int, MonsterAvatar] = {}
var _conteneur_monstres: Node3D
var _geometrie: Node3D
var _salles: Array[Dictionary] = []

## Traînée ardente en cours : elle sème des flaques tant qu'elle dure.
var _trainee_restante: float = 0.0
var _trainee_prochaine: float = 0.0
var _trainee_eff: Dictionary = {}
var _trainee_slot: int = -1
var _trainee_couleur: Color = Color.WHITE
var _derniere_flaque: Vector3 = Vector3.ZERO

## Marqueur d'atterrissage de la téléportation.
var _apercu: MeshInstance3D

## Socles du marchand et portail de descente.
var _socles: Array[Dictionary] = []
var _portail: Node3D = null
var _cible_interaction: Dictionary = {}


func _ready() -> void:
	_declare_les_touches()
	_construit_l_eclairage()
	_construit_le_joueur()
	_construit_le_hud()

	GameState.start_run(0, 1)
	# 4 écoles sur les 5 : Braise, Givre, Force (pool de 2), Ombre (pool de 4).
	# Les tailles différentes sont volontaires — elles vérifient que rien ne
	# suppose un pool de 3.
	GameState.set_player_schools(0, PrototypeCatalogue.school_defs([0, 1, 2, 4]))

	EventBus.monster_damaged.connect(_sur_degat_monstre)
	EventBus.monster_died.connect(_sur_mort_monstre)
	EventBus.slot_rerolled.connect(_sur_reroll)
	EventBus.slot_kept.connect(_sur_slot_garde)
	EventBus.resonance_spend_rejected.connect(
		func(_id: int, raison: String) -> void: _hud.journalise("Achat refusé : " + raison)
	)

	_assemble_l_etage()
	_peuple_l_etage()
	_hud.journalise("Nettoie l'étage, va voir le marchand au fond, puis prends le portail.")


## Raccourcis clavier pour l'école et le verrou.
##
## Ils existent parce qu'en vue subjective la souris est capturée : sans eux,
## les boutons du HUD seraient inatteignables sans passer par Échap à chaque
## fois, ce qui rend le test pénible.
func _unhandled_input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo:
		return
	var index: int = [KEY_1, KEY_2, KEY_3, KEY_4].find(touche.physical_keycode)
	if index < 0:
		return
	if touche.shift_pressed:
		_sur_ecole_changee(index, 1)
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	# Un tick de résolution par frame physique. Toutes les intentions soumises
	# pendant cette frame sont triées puis appliquées ensemble (R4).
	EffectResolver.resolve_tick()

	_maj_trainee(_delta)
	_maj_apercu_teleport()
	_maj_interaction()

	if Input.is_action_just_pressed("proto_interagir"):
		_interagit()

	if GameState.is_in_run() and GameState.run.players[0].hp <= 0:
		_hud.journalise("Mort à l'étage %d. La run redémarre." % (GameState.run.floor_index + 1))
		_redemarre()


# ── Construction de la scène ──────────────────────────────────────────────

## Les actions sont déclarées à l'exécution plutôt que dans les réglages du
## projet : le prototype reste ainsi entièrement contenu dans ses fichiers.
func _declare_les_touches() -> void:
	var touches := {
		"proto_haut": [KEY_W, KEY_Z, KEY_UP],
		"proto_bas": [KEY_S, KEY_DOWN],
		"proto_gauche": [KEY_A, KEY_Q, KEY_LEFT],
		"proto_droite": [KEY_D, KEY_RIGHT],
		"proto_sort_1": [KEY_1, KEY_KP_1],
		"proto_sort_2": [KEY_2, KEY_KP_2],
		"proto_sort_3": [KEY_3, KEY_KP_3],
		"proto_sort_4": [KEY_4, KEY_KP_4],
		"proto_interagir": [KEY_E],
		"proto_saut": [KEY_SPACE],
		"proto_liberer_souris": [KEY_ESCAPE],
	}
	for action: String in touches:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code: int in touches[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)

	if not InputMap.has_action("proto_tir"):
		InputMap.add_action("proto_tir")
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("proto_tir", clic)


func _construit_l_eclairage() -> void:
	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-58, -42, 0)
	lumiere.light_energy = 1.15
	lumiere.shadow_enabled = true
	add_child(lumiere)

	var ambiance := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.09, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.36, 0.42)
	env.ambient_light_energy = 0.85
	ambiance.environment = env
	add_child(ambiance)

	_geometrie = Node3D.new()
	_geometrie.name = "Geometrie"
	add_child(_geometrie)


## Assemble l'étage : une chaîne de salles reliées par des couloirs, la
## dernière servant de salle du marchand.
##
## Le plan est calculé EN ENTIER avant de bâtir quoi que ce soit. La version
## précédente tirait la taille de la salle suivante pour calculer l'espacement,
## puis en retirait une autre au tour d'après : les couloirs ne tombaient donc
## pas en face des ouvertures, et les murs les bouchaient.
func _assemble_l_etage() -> void:
	for enfant: Node in _geometrie.get_children():
		enfant.queue_free()
	_salles.clear()
	_socles.clear()
	_portail = null

	var rng: RandomNumberGenerator = RngService.stream(RngService.STREAM_DUNGEON)

	# 1. Toutes les tailles d'abord.
	var cotes: Array[float] = []
	for i: int in SALLES_PAR_ETAGE:
		cotes.append(rng.randf_range(TAILLE_SALLE_MIN, TAILLE_SALLE_MAX))
	# La salle du marchand est toujours généreuse : il faut la place de
	# tourner autour des socles.
	cotes[SALLES_PAR_ETAGE - 1] = maxf(cotes[SALLES_PAR_ETAGE - 1], 17.0)

	# 2. Les directions, alternées pour éviter la ligne droite.
	var directions: Array[Vector3] = []
	var courante := Vector3.RIGHT
	for i: int in SALLES_PAR_ETAGE - 1:
		directions.append(courante)
		courante = Vector3.FORWARD if courante == Vector3.RIGHT else Vector3.RIGHT

	# 3. Les centres, déduits des tailles réelles.
	var centres: Array[Vector3] = [Vector3.ZERO]
	for i: int in SALLES_PAR_ETAGE - 1:
		centres.append(centres[i] + directions[i] * (
			cotes[i] * 0.5 + LONGUEUR_COULOIR + cotes[i + 1] * 0.5
		))

	# 4. Construction.
	for i: int in SALLES_PAR_ETAGE:
		var ouvertures: Array[Vector3] = []
		if i > 0:
			ouvertures.append(-directions[i - 1])
		if i < SALLES_PAR_ETAGE - 1:
			ouvertures.append(directions[i])
		_batit_salle(centres[i], cotes[i], ouvertures)
		_salles.append({"centre": centres[i], "taille": cotes[i],
			"marchand": i == SALLES_PAR_ETAGE - 1})

	for i: int in SALLES_PAR_ETAGE - 1:
		_batit_couloir(centres[i] + directions[i] * (cotes[i] * 0.5), directions[i])

	_installe_le_marchand(centres[SALLES_PAR_ETAGE - 1], cotes[SALLES_PAR_ETAGE - 1])


func _batit_salle(centre: Vector3, cote: float, ouvertures: Array[Vector3]) -> void:
	_ajoute_bloc(centre + Vector3(0, -0.5, 0), Vector3(cote, 1, cote),
		Color(0.30, 0.31, 0.36))

	var demi: float = cote * 0.5
	var murs := [
		{"pos": Vector3(demi, 0, 0), "le_long_de_z": true, "dir": Vector3.RIGHT},
		{"pos": Vector3(-demi, 0, 0), "le_long_de_z": true, "dir": Vector3.LEFT},
		{"pos": Vector3(0, 0, demi), "le_long_de_z": false, "dir": Vector3.BACK},
		{"pos": Vector3(0, 0, -demi), "le_long_de_z": false, "dir": Vector3.FORWARD},
	]
	for mur: Dictionary in murs:
		_batit_mur(centre + mur["pos"], cote, mur["le_long_de_z"],
			ouvertures.has(mur["dir"]))


func _batit_mur(centre: Vector3, longueur: float, le_long_de_z: bool, perce: bool) -> void:
	var hauteur := Vector3(0, HAUTEUR_MUR * 0.5, 0)
	var couleur := Color(0.20, 0.21, 0.26)
	if not perce:
		var taille: Vector3 = Vector3(1, HAUTEUR_MUR, longueur) if le_long_de_z \
			else Vector3(longueur, HAUTEUR_MUR, 1)
		_ajoute_bloc(centre + hauteur, taille, couleur)
		return

	# Deux segments de part et d'autre de l'ouverture.
	var segment: float = (longueur - LARGEUR_COULOIR) * 0.5
	if segment <= 0.2:
		return
	var decalage: float = (LARGEUR_COULOIR + segment) * 0.5
	for signe: float in [-1.0, 1.0]:
		var pos: Vector3 = centre + hauteur
		var taille: Vector3
		if le_long_de_z:
			pos.z += signe * decalage
			taille = Vector3(1, HAUTEUR_MUR, segment)
		else:
			pos.x += signe * decalage
			taille = Vector3(segment, HAUTEUR_MUR, 1)
		_ajoute_bloc(pos, taille, couleur)


func _batit_couloir(depart: Vector3, direction: Vector3) -> void:
	var milieu: Vector3 = depart + direction * (LONGUEUR_COULOIR * 0.5)
	var le_long_de_x: bool = absf(direction.x) > 0.5
	var sol: Vector3 = Vector3(LONGUEUR_COULOIR, 1, LARGEUR_COULOIR) if le_long_de_x \
		else Vector3(LARGEUR_COULOIR, 1, LONGUEUR_COULOIR)
	_ajoute_bloc(milieu + Vector3(0, -0.5, 0), sol, Color(0.26, 0.27, 0.32))

	var hauteur := Vector3(0, HAUTEUR_MUR * 0.5, 0)
	var demi_large: float = LARGEUR_COULOIR * 0.5
	for signe: float in [-1.0, 1.0]:
		if le_long_de_x:
			_ajoute_bloc(milieu + hauteur + Vector3(0, 0, signe * demi_large),
				Vector3(LONGUEUR_COULOIR, HAUTEUR_MUR, 1), Color(0.18, 0.19, 0.24))
		else:
			_ajoute_bloc(milieu + hauteur + Vector3(signe * demi_large, 0, 0),
				Vector3(1, HAUTEUR_MUR, LONGUEUR_COULOIR), Color(0.18, 0.19, 0.24))


func _ajoute_bloc(pos: Vector3, taille: Vector3, couleur: Color) -> void:
	var corps := StaticBody3D.new()
	corps.position = pos

	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = taille
	forme.shape = boite
	corps.add_child(forme)

	var visuel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = taille
	visuel.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = couleur
	visuel.material_override = mat
	corps.add_child(visuel)

	_geometrie.add_child(corps)


func _construit_le_joueur() -> void:
	_joueur = PlayerAvatar.new()
	_joueur.name = "Joueur"
	_joueur.position = Vector3(0, 1.0, 0)

	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	forme.shape = capsule
	_joueur.add_child(forme)

	# Aucun mesh : en vue subjective, on ne se voit pas soi-même.
	# La caméra est créée par PlayerAvatar, à hauteur des yeux.
	_joueur.a_lance.connect(_sur_lancer)
	add_child(_joueur)
	_camera = _joueur.camera

	_conteneur_monstres = Node3D.new()
	_conteneur_monstres.name = "Monstres"
	add_child(_conteneur_monstres)

	# Aperçu de téléportation. Il n'apparaît QUE si un slot prêt porte un
	# effet de téléportation déjà découvert : le montrer sur un slot en ???
	# révélerait le sort avant de l'avoir lancé.
	_apercu = MeshInstance3D.new()
	var cylindre := CylinderMesh.new()
	cylindre.top_radius = 0.75
	cylindre.bottom_radius = 0.75
	cylindre.height = 0.12
	_apercu.mesh = cylindre
	var mat_apercu := StandardMaterial3D.new()
	mat_apercu.albedo_color = Color(0.66, 0.44, 0.95, 0.45)
	mat_apercu.emission_enabled = true
	mat_apercu.emission = Color(0.66, 0.44, 0.95)
	mat_apercu.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_apercu.material_override = mat_apercu
	_apercu.visible = false
	add_child(_apercu)


func _construit_le_hud() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	_hud = PrototypeHud.new()
	_hud.joueur = _joueur
	_hud.etage_suivant_demande.connect(_descend)
	_hud.ecole_changee.connect(_sur_ecole_changee)
	couche.add_child(_hud)


# ── Peuplement des étages ─────────────────────────────────────────────────

func _peuple_l_etage() -> void:
	for enfant: Node in _conteneur_monstres.get_children():
		enfant.queue_free()
	_avatars.clear()

	# Placement seedé : la même seed rejoue le même étage (R3).
	var rng: RandomNumberGenerator = RngService.stream(RngService.STREAM_DUNGEON)
	var pv: int = PV_MONSTRE + GameState.run.floor_index * 8

	for index_salle: int in _salles.size():
		var salle: Dictionary = _salles[index_salle]
		# La salle du marchand est un sas : on y respire et on y décide.
		if salle.get("marchand", false):
			continue
		var centre: Vector3 = salle["centre"]
		var bord: float = float(salle["taille"]) * 0.5 - 2.5
		# La première salle en contient moins : on y arrive sans être encerclé.
		var combien: int = MONSTRES_PAR_SALLE - (1 if index_salle == 0 else 0)

		for i: int in combien:
			var id: int = GameState.spawn_monster(pv, RESONANCE_PAR_MONSTRE)
			var avatar := MonsterAvatar.new()
			avatar.monster_id = id
			avatar.cible = _joueur

			var forme := CollisionShape3D.new()
			var boite := BoxShape3D.new()
			boite.size = Vector3(1.2, 1.6, 1.2)
			forme.shape = boite
			avatar.add_child(forme)

			var visuel := MeshInstance3D.new()
			visuel.name = "Mesh"
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.2, 1.6, 1.2)
			visuel.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.75, 0.3, 0.35)
			visuel.set_surface_override_material(0, mat)
			avatar.add_child(visuel)

			avatar.position = centre + Vector3(
				rng.randf_range(-bord, bord), 0.9, rng.randf_range(-bord, bord)
			)
			_conteneur_monstres.add_child(avatar)
			_avatars[id] = avatar


# ── Lancer de sorts ───────────────────────────────────────────────────────

func _sur_lancer(slot_index: int, direction: Vector3) -> void:
	var p: PlayerState = GameState.run.players[0]
	var slot: SpellSlot = p.slots[slot_index]
	var eff: Dictionary = PrototypeCatalogue.effect(slot.school_id, slot.effect_index)
	if eff.is_empty():
		return

	var ecole: Dictionary = PrototypeCatalogue.school_by_id(slot.school_id)
	var couleur: Color = ecole.get("couleur", Color.WHITE)
	_joueur.demarre_cooldown(slot_index, float(eff.get("cooldown", 1.0)))

	match int(eff["comportement"]):
		PrototypeCatalogue.Behaviour.PROJECTILE:
			_tire_projectile(slot_index, eff, direction, couleur, false)
		PrototypeCatalogue.Behaviour.DRAIN:
			_tire_projectile(slot_index, eff, direction, couleur, true)
		PrototypeCatalogue.Behaviour.MUR:
			_pose_mur(slot_index, eff, direction, couleur)
		PrototypeCatalogue.Behaviour.TRAINEE:
			_demarre_trainee(slot_index, eff, couleur)
		PrototypeCatalogue.Behaviour.NOVA:
			_declenche_nova(slot_index, eff, couleur)
		PrototypeCatalogue.Behaviour.CONE:
			_souffle_conique(slot_index, eff, direction, couleur)
		PrototypeCatalogue.Behaviour.GEL:
			_pose_nappe_de_gel(slot_index, eff, couleur)
		PrototypeCatalogue.Behaviour.REPULSION:
			_pousse_ou_attire(slot_index, eff, couleur, true)
		PrototypeCatalogue.Behaviour.ATTRACTION:
			_pousse_ou_attire(slot_index, eff, couleur, false)
		PrototypeCatalogue.Behaviour.DASH:
			_charge(slot_index, eff, direction, couleur)
		PrototypeCatalogue.Behaviour.TELEPORT:
			_teleporte(eff, couleur)
		PrototypeCatalogue.Behaviour.SOIN:
			_lance_soin(slot_index, eff, couleur)
		PrototypeCatalogue.Behaviour.TOTEM:
			_pose_totem(slot_index, eff, couleur)
		PrototypeCatalogue.Behaviour.VOILE:
			_active_voile(eff)
		PrototypeCatalogue.Behaviour.LEURRE:
			_pose_leurre(eff, direction, couleur)


# ── À distance ────────────────────────────────────────────────────────────

func _tire_projectile(slot_index: int, eff: Dictionary, direction: Vector3,
		couleur: Color, draine: bool) -> void:
	var portee: float = float(eff.get("portee", 20.0))
	var degats: int = int(eff.get("degats", 10))

	var bille := Area3D.new()
	bille.position = _joueur.position_yeux() + direction * 0.8
	var forme := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	forme.shape = sphere
	bille.add_child(forme)
	bille.add_child(_sphere_lumineuse(0.35, couleur))
	add_child(bille)

	var touche: Array[bool] = [false]
	bille.body_entered.connect(func(corps: Node3D) -> void:
		if touche[0]:
			return
		var avatar := corps as MonsterAvatar
		if avatar == null:
			return
		touche[0] = true
		_soumet_degats(slot_index, degats, [avatar.monster_id])
		# Le Siphon rend une part des dégâts en soin : c'est ce qui le
		# distingue d'un projectile ordinaire.
		if draine:
			_soumet_soin(slot_index, int(degats * float(eff.get("ratio_soin", 0.5))))
		bille.queue_free()
	)

	var arrivee: Vector3 = bille.position + direction * portee
	var tween := create_tween()
	tween.tween_property(bille, "position", arrivee, portee / VITESSE_PROJECTILE)
	tween.tween_callback(bille.queue_free)


## Un vrai mur : une nappe posée devant soi, qui reste et brûle qui la traverse.
func _pose_mur(slot_index: int, eff: Dictionary, direction: Vector3,
		couleur: Color) -> void:
	var plat := Vector3(direction.x, 0.0, direction.z).normalized()
	if plat.length_squared() < 0.01:
		plat = Vector3.FORWARD
	var centre: Vector3 = _joueur.global_position + plat * float(eff.get("distance", 4.0))
	centre.y = 1.4

	var zone := ZoneEffet.cree(
		ZoneEffet.Forme.BOITE,
		Vector3(float(eff.get("largeur", 8.0)), 2.8, 0.9),
		centre,
		atan2(plat.x, plat.z),
	)
	zone.duree = float(eff.get("duree", 5.0))
	zone.intervalle = float(eff.get("intervalle", 0.4))
	zone.degats = int(eff.get("degats", 6))
	zone.source_slot = slot_index
	zone.couleur = couleur
	add_child(zone)


## Le sol s'embrase sous nos pas pendant un moment : chaque foulée laisse une
## flaque qui vit sa propre vie.
func _demarre_trainee(slot_index: int, eff: Dictionary, couleur: Color) -> void:
	_trainee_restante = float(eff.get("duree", 5.0))
	_trainee_eff = eff.duplicate()
	_trainee_slot = slot_index
	_trainee_couleur = couleur
	_trainee_prochaine = 0.0


func _pose_flaque(slot_index: int, eff: Dictionary, couleur: Color,
		position_monde: Vector3) -> void:
	var zone := ZoneEffet.cree(
		ZoneEffet.Forme.SPHERE,
		Vector3(float(eff.get("rayon", 1.5)), 0, 0),
		Vector3(position_monde.x, 0.4, position_monde.z),
	)
	zone.duree = float(eff.get("duree_flaque", 3.0))
	zone.intervalle = float(eff.get("intervalle", 0.4))
	zone.degats = int(eff.get("degats", 4))
	zone.source_slot = slot_index
	zone.couleur = couleur
	add_child(zone)


# ── Autour de soi ─────────────────────────────────────────────────────────

func _declenche_nova(slot_index: int, eff: Dictionary, couleur: Color) -> void:
	var rayon: float = float(eff.get("rayon", 4.0))
	_soumet_degats(slot_index, int(eff.get("degats", 10)),
		_monstres_dans_rayon(rayon))
	_anneau(rayon, couleur)


## Un éventail devant soi : très différent d'une nova, on doit être orienté.
func _souffle_conique(slot_index: int, eff: Dictionary, direction: Vector3,
		couleur: Color) -> void:
	var portee: float = float(eff.get("portee", 10.0))
	var demi_angle: float = deg_to_rad(float(eff.get("angle", 45.0)) * 0.5)
	var plat := Vector3(direction.x, 0.0, direction.z).normalized()

	var cibles: Array = []
	for id: int in _avatars:
		var avatar: MonsterAvatar = _avatars[id]
		if not is_instance_valid(avatar):
			continue
		var vers: Vector3 = avatar.global_position - _joueur.global_position
		vers.y = 0.0
		if vers.length() > portee:
			continue
		if plat.angle_to(vers.normalized()) <= demi_angle:
			cibles.append(id)
	_soumet_degats(slot_index, int(eff.get("degats", 15)), cibles)
	_cone_visuel(plat, portee, couleur)


func _pose_nappe_de_gel(slot_index: int, eff: Dictionary, couleur: Color) -> void:
	var zone := ZoneEffet.cree(
		ZoneEffet.Forme.SPHERE,
		Vector3(float(eff.get("rayon", 5.0)), 0, 0),
		Vector3(_joueur.global_position.x, 0.5, _joueur.global_position.z),
	)
	zone.duree = float(eff.get("duree", 6.0))
	zone.intervalle = float(eff.get("intervalle", 0.5))
	zone.degats = int(eff.get("degats", 3))
	zone.ralentissement = float(eff.get("ralentissement", 0.3))
	zone.source_slot = slot_index
	zone.couleur = couleur
	add_child(zone)


## Repousser et attirer partagent leur code mais pas leur ressenti : le signe
## change tout, l'un dégage la place, l'autre rassemble pour frapper ensuite.
func _pousse_ou_attire(slot_index: int, eff: Dictionary, couleur: Color,
		repousse: bool) -> void:
	var rayon: float = float(eff.get("rayon", 7.0))
	var puissance: float = float(eff.get("puissance", 20.0))
	var cibles: Array = []

	for id: int in _monstres_dans_rayon(rayon):
		var avatar: MonsterAvatar = _avatars[id]
		var vers: Vector3 = avatar.global_position - _joueur.global_position
		vers.y = 0.0
		if vers.length_squared() < 0.01:
			vers = Vector3.FORWARD
		var sens: Vector3 = vers.normalized() * (1.0 if repousse else -1.0)
		# L'effet faiblit avec la distance : au bord du rayon, on est à peine bousculé.
		var attenuation: float = 1.0 - clampf(vers.length() / rayon, 0.0, 0.85)
		avatar.repousse(sens * puissance * attenuation)
		cibles.append(id)

	_soumet_degats(slot_index, int(eff.get("degats", 5)), cibles)
	_anneau(rayon, couleur)


# ── Déplacement ───────────────────────────────────────────────────────────

func _charge(slot_index: int, eff: Dictionary, direction: Vector3,
		couleur: Color) -> void:
	var plat := Vector3(direction.x, 0.0, direction.z).normalized()
	_joueur.charge(plat, float(eff.get("distance", 9.0)))
	# On blesse ce qu'on traverse : la charge est une attaque, pas un sprint.
	var touches: Array = []
	for id: int in _avatars:
		var avatar: MonsterAvatar = _avatars[id]
		if not is_instance_valid(avatar):
			continue
		var vers: Vector3 = avatar.global_position - _joueur.global_position
		vers.y = 0.0
		var le_long: float = vers.dot(plat)
		if le_long < 0.0 or le_long > float(eff.get("distance", 9.0)):
			continue
		if (vers - plat * le_long).length() <= float(eff.get("rayon", 2.0)):
			touches.append(id)
			avatar.repousse(plat * 12.0)
	_soumet_degats(slot_index, int(eff.get("degats", 18)), touches)
	_anneau(2.0, couleur)


func _teleporte(eff: Dictionary, couleur: Color) -> void:
	var but: Vector3 = _joueur.point_vise(float(eff.get("portee", 15.0)))
	_marque_position(_joueur.global_position, couleur)
	_joueur.teleporte(but)
	_marque_position(but, couleur)


# ── Soutien ───────────────────────────────────────────────────────────────

func _lance_soin(slot_index: int, eff: Dictionary, couleur: Color) -> void:
	_soumet_soin(slot_index, int(eff.get("soin", 20)))
	_anneau(2.2, couleur)


## Une balise posée au sol qui soigne tant qu'on reste dedans. Rien à voir avec
## un soin instantané : elle demande de tenir une position.
func _pose_totem(slot_index: int, eff: Dictionary, couleur: Color) -> void:
	var zone := ZoneEffet.cree(
		ZoneEffet.Forme.SPHERE,
		Vector3(float(eff.get("rayon", 3.0)), 0, 0),
		Vector3(_joueur.global_position.x, 0.6, _joueur.global_position.z),
	)
	zone.duree = float(eff.get("duree", 8.0))
	zone.intervalle = float(eff.get("intervalle", 0.8))
	zone.soin = int(eff.get("soin", 5))
	zone.source_slot = slot_index
	zone.couleur = couleur
	add_child(zone)


func _active_voile(eff: Dictionary) -> void:
	var duree: float = float(eff.get("duree", 4.0))
	_joueur.voile(duree)
	for id: int in _avatars:
		var avatar: MonsterAvatar = _avatars[id]
		if is_instance_valid(avatar):
			avatar.aveugle = true
	_hud.journalise("Voile actif — les monstres ont perdu ta trace (%.0fs)." % duree)
	get_tree().create_timer(duree).timeout.connect(func() -> void:
		for id: int in _avatars:
			var avatar: MonsterAvatar = _avatars[id]
			if is_instance_valid(avatar):
				avatar.aveugle = false
	)


## Un mannequin qui vole l'attention : les monstres le poursuivent au lieu de
## nous, et ne le frappent pas.
func _pose_leurre(eff: Dictionary, direction: Vector3, couleur: Color) -> void:
	var plat := Vector3(direction.x, 0.0, direction.z).normalized()
	var leurre := Node3D.new()
	leurre.add_to_group("leurre")
	leurre.position = _joueur.global_position + plat * float(eff.get("distance", 5.0))
	leurre.add_child(_sphere_lumineuse(0.7, couleur))
	add_child(leurre)

	for id: int in _avatars:
		var avatar: MonsterAvatar = _avatars[id]
		if is_instance_valid(avatar):
			avatar.cible = leurre

	var duree: float = float(eff.get("duree", 6.0))
	get_tree().create_timer(duree).timeout.connect(func() -> void:
		for id: int in _avatars:
			var avatar: MonsterAvatar = _avatars[id]
			if is_instance_valid(avatar) and avatar.cible == leurre:
				avatar.cible = _joueur
		if is_instance_valid(leurre):
			leurre.queue_free()
	)


# ── Soumission au resolver ────────────────────────────────────────────────

func _soumet_degats(slot_index: int, degats: int, monstres: Array) -> void:
	if degats <= 0:
		return
	var intent := EffectIntent.new()
	intent.source_player_id = 0
	intent.source_slot = slot_index
	intent.kind = EffectIntent.Kind.DAMAGE
	intent.amount = degats
	intent.target_monsters = PackedInt64Array(monstres)
	EffectResolver.submit(intent)


func _soumet_soin(slot_index: int, montant: int) -> void:
	if montant <= 0:
		return
	var intent := EffectIntent.new()
	intent.source_player_id = 0
	intent.source_slot = slot_index
	intent.kind = EffectIntent.Kind.HEAL
	intent.amount = montant
	intent.target_ids = PackedInt64Array([0])
	EffectResolver.submit(intent)


func _monstres_dans_rayon(rayon: float) -> Array:
	var out: Array = []
	for id: int in _avatars:
		var avatar: MonsterAvatar = _avatars[id]
		if is_instance_valid(avatar) and \
				avatar.global_position.distance_to(_joueur.global_position) <= rayon:
			out.append(id)
	return out


# ── Petits visuels jetables ───────────────────────────────────────────────

func _sphere_lumineuse(rayon: float, couleur: Color) -> MeshInstance3D:
	var visuel := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = rayon
	mesh.height = rayon * 2.0
	visuel.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = couleur
	mat.emission_enabled = true
	mat.emission = couleur
	visuel.material_override = mat
	return visuel


func _anneau(rayon: float, couleur: Color) -> void:
	var visuel := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = rayon * 0.85
	mesh.outer_radius = rayon
	visuel.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = couleur
	mat.emission_enabled = true
	mat.emission = couleur
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visuel.material_override = mat
	visuel.position = _joueur.global_position - Vector3(0, 0.8, 0)
	visuel.scale = Vector3(0.3, 1, 0.3)
	add_child(visuel)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuel, "scale", Vector3.ONE, 0.3)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(visuel.queue_free)


func _cone_visuel(direction: Vector3, portee: float, couleur: Color) -> void:
	var visuel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = portee * 0.55
	mesh.bottom_radius = 0.2
	mesh.height = portee
	visuel.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(couleur.r, couleur.g, couleur.b, 0.5)
	mat.emission_enabled = true
	mat.emission = couleur
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	visuel.material_override = mat
	visuel.position = _joueur.global_position + direction * (portee * 0.5)
	visuel.rotation = Vector3(deg_to_rad(90), atan2(direction.x, direction.z), 0)
	add_child(visuel)

	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tween.tween_callback(visuel.queue_free)


func _marque_position(pos: Vector3, couleur: Color) -> void:
	var visuel := _sphere_lumineuse(0.6, couleur)
	visuel.position = pos
	add_child(visuel)
	var mat: StandardMaterial3D = visuel.material_override
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(visuel.queue_free)


## Sème une flaque tous les tant de mètres, pas toutes les tant de secondes :
## rester immobile ne doit pas empiler dix flaques au même endroit.
func _maj_trainee(delta: float) -> void:
	if _trainee_restante <= 0.0:
		return
	_trainee_restante -= delta
	_trainee_prochaine -= delta
	var assez_loin: bool = _joueur.global_position.distance_to(_derniere_flaque) > 1.6
	if _trainee_prochaine <= 0.0 and assez_loin:
		_trainee_prochaine = 0.18
		_derniere_flaque = _joueur.global_position
		_pose_flaque(_trainee_slot, _trainee_eff, _trainee_couleur,
			_joueur.global_position)


func _maj_apercu_teleport() -> void:
	var p: PlayerState = GameState.run.players[0]
	var etage: int = GameState.run.floor_index
	var portee: float = 0.0

	for i: int in p.slots.size():
		var slot: SpellSlot = p.slots[i]
		if not slot.is_discovered_on(etage) or _joueur.cooldown_restant(i) > 0.0:
			continue
		var eff: Dictionary = PrototypeCatalogue.effect(slot.school_id, slot.effect_index)
		if int(eff.get("comportement", -1)) == PrototypeCatalogue.Behaviour.TELEPORT:
			portee = float(eff.get("portee", 15.0))
			break

	_apercu.visible = portee > 0.0
	if _apercu.visible:
		_apercu.global_position = _joueur.point_vise(portee) - Vector3(0, 0.9, 0)


# ── Le marchand ───────────────────────────────────────────────────────────

## La dernière salle de chaque étage. On y achète ses verrous — c'est LE moment
## de décision de la boucle — puis on prend le portail, qui déclenche le reroll.
##
## L'ordre compte et il est celui du GDD : on achète d'ABORD, on reroll ENSUITE.
## Un portail qui rerollerait avant l'achat rendrait les verrous inutiles.
func _installe_le_marchand(centre: Vector3, cote: float) -> void:
	var marchand := Node3D.new()
	marchand.position = centre + Vector3(0, 1.2, -cote * 0.28)
	var corps := _sphere_lumineuse(0.9, Color(0.95, 0.85, 0.45))
	marchand.add_child(corps)
	var chapeau := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.85
	cone.height = 1.1
	chapeau.mesh = cone
	chapeau.position = Vector3(0, 1.1, 0)
	var mat_chapeau := StandardMaterial3D.new()
	mat_chapeau.albedo_color = Color(0.35, 0.28, 0.55)
	chapeau.material_override = mat_chapeau
	marchand.add_child(chapeau)
	_geometrie.add_child(marchand)

	# Un socle par slot : le verrou devient un objet posé au sol qu'on va
	# chercher, pas une case à cocher dans un menu.
	var largeur: float = cote * 0.62
	for i: int in 4:
		var pos: Vector3 = centre + Vector3(
			-largeur * 0.5 + largeur * (float(i) / 3.0), 0.0, cote * 0.06
		)
		_ajoute_socle(pos, {"type": "verrou", "slot": i})

	# Deux consommables, pour que la Résonance ait un usage concurrent.
	_ajoute_socle(centre + Vector3(-largeur * 0.36, 0, cote * 0.3),
		{"type": "soin", "cout": 25, "valeur": 45})
	_ajoute_socle(centre + Vector3(largeur * 0.36, 0, cote * 0.3),
		{"type": "vigueur", "cout": 40, "valeur": 15})

	_portail = _cree_portail(centre + Vector3(0, 0, -cote * 0.42))


func _ajoute_socle(pos: Vector3, donnees: Dictionary) -> void:
	var socle := Node3D.new()
	socle.position = Vector3(pos.x, 0.0, pos.z)

	var pied := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.55
	mesh.bottom_radius = 0.7
	mesh.height = 0.9
	pied.mesh = mesh
	pied.position = Vector3(0, 0.45, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.34, 0.42)
	pied.material_override = mat
	socle.add_child(pied)

	var objet := _sphere_lumineuse(0.32, _couleur_objet(donnees))
	objet.position = Vector3(0, 1.35, 0)
	objet.name = "Objet"
	socle.add_child(objet)

	_geometrie.add_child(socle)
	donnees["node"] = socle
	donnees["objet"] = objet
	donnees["achete"] = false
	_socles.append(donnees)


func _couleur_objet(donnees: Dictionary) -> Color:
	match String(donnees.get("type", "")):
		"soin":
			return Color(0.42, 0.92, 0.48)
		"vigueur":
			return Color(0.95, 0.55, 0.35)
		_:
			var slot: SpellSlot = GameState.run.players[0].slots[int(donnees.get("slot", 0))]
			var ecole: Dictionary = PrototypeCatalogue.school_by_id(slot.school_id)
			return ecole.get("couleur", Color.WHITE)


func _cree_portail(pos: Vector3) -> Node3D:
	var portail := Node3D.new()
	portail.position = Vector3(pos.x, 0.1, pos.z)
	var anneau := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.5
	mesh.outer_radius = 2.0
	anneau.mesh = mesh
	anneau.rotation_degrees = Vector3(90, 0, 0)
	anneau.position = Vector3(0, 2.0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.75, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.7, 1.0)
	mat.emission_energy_multiplier = 1.6
	anneau.material_override = mat
	portail.add_child(anneau)
	_geometrie.add_child(portail)
	return portail


## Coût du prochain verrou, multiplicateur cumulatif compris.
func _cout_verrou() -> int:
	var deja: int = GameState.run.players[0].locks_bought_this_floor
	var facteur: float = MULTIPLICATEURS[mini(deja, MULTIPLICATEURS.size() - 1)]
	return int(round(COUT_VERROU_BASE * facteur))


## Cherche l'objet interactif le plus proche et met à jour l'invite.
func _maj_interaction() -> void:
	_cible_interaction = {}
	var meilleure: float = PORTEE_INTERACTION

	for socle: Dictionary in _socles:
		if socle["achete"]:
			continue
		var d: float = _joueur.global_position.distance_to(
			(socle["node"] as Node3D).global_position
		)
		if d < meilleure:
			meilleure = d
			_cible_interaction = socle

	if _portail != null:
		var d: float = _joueur.global_position.distance_to(_portail.global_position)
		if d < meilleure:
			_cible_interaction = {"type": "portail"}

	_hud.invite(_libelle_interaction())


func _libelle_interaction() -> String:
	if _cible_interaction.is_empty():
		return ""
	match String(_cible_interaction.get("type", "")):
		"portail":
			var restants: int = GameState.run.alive_monsters().size()
			if restants > 0:
				return "[E] Portail scellé — %d monstre(s) à éliminer" % restants
			return "[E] Descendre à l'étage suivant"
		"verrou":
			var i: int = int(_cible_interaction["slot"])
			var nom: String = String(PrototypeCatalogue.school_by_id(
				GameState.run.players[0].slots[i].school_id).get("nom", "?"))
			return "[E] Sceller le slot %d (%s) — %d Résonance" % [
				i + 1, nom, _cout_verrou()]
		"soin":
			return "[E] Fiole de soin (+%d PV) — %d Résonance" % [
				int(_cible_interaction["valeur"]), int(_cible_interaction["cout"])]
		"vigueur":
			return "[E] Éclat de vigueur (+%d PV max) — %d Résonance" % [
				int(_cible_interaction["valeur"]), int(_cible_interaction["cout"])]
	return ""


func _interagit() -> void:
	if _cible_interaction.is_empty():
		return
	match String(_cible_interaction.get("type", "")):
		"portail":
			_prend_le_portail()
		"verrou":
			_achete_verrou(_cible_interaction)
		"soin", "vigueur":
			_achete_consommable(_cible_interaction)


func _achete_verrou(socle: Dictionary) -> void:
	var i: int = int(socle["slot"])
	var cout: int = _cout_verrou()
	if not GameState.try_lock_slot(0, i, cout):
		return
	_consomme_socle(socle)
	_hud.journalise("Slot %d scellé pour %d Résonance. Le prochain coûtera %d." % [
		i + 1, cout, _cout_verrou()])


func _achete_consommable(socle: Dictionary) -> void:
	var cout: int = int(socle["cout"])
	if not GameState.try_spend_resonance(0, cout):
		return
	var p: PlayerState = GameState.run.players[0]
	if String(socle["type"]) == "vigueur":
		p.max_hp += int(socle["valeur"])
		p.hp += int(socle["valeur"])
		_hud.journalise("Vigueur : %d PV max." % p.max_hp)
	else:
		_soumet_soin(-1, int(socle["valeur"]))
		_hud.journalise("Fiole bue.")
	_consomme_socle(socle)


func _consomme_socle(socle: Dictionary) -> void:
	socle["achete"] = true
	var objet: Node3D = socle["objet"]
	if is_instance_valid(objet):
		objet.queue_free()


## Le portail ne s'ouvre qu'une fois l'étage nettoyé : sans ça, on peut
## traverser le donjon sans jamais combattre, et il n'y a plus de boucle.
func _prend_le_portail() -> void:
	if GameState.run.alive_monsters().size() > 0:
		_hud.journalise("Le portail reste scellé tant que l'étage n'est pas nettoyé.")
		return
	_descend()


# ── Réactions aux évènements du moteur ────────────────────────────────────

func _sur_degat_monstre(monster_id: int, _pv: int) -> void:
	var avatar: MonsterAvatar = _avatars.get(monster_id)
	if is_instance_valid(avatar):
		avatar.encaisse_visuellement()


func _sur_mort_monstre(monster_id: int, _tueur: int, recompense: int) -> void:
	var avatar: MonsterAvatar = _avatars.get(monster_id)
	if is_instance_valid(avatar):
		avatar.queue_free()
	_avatars.erase(monster_id)
	_hud.journalise("+%d Résonance   ·   %d monstre(s) restant(s)" % [
		recompense, GameState.run.alive_monsters().size(),
	])


func _sur_reroll(_joueur_id: int, slot_index: int, _effet: int) -> void:
	_hud.journalise("Le slot %d a muté. Lance-le pour découvrir ce qu'il fait." % (slot_index + 1))


func _sur_slot_garde(_joueur_id: int, slot_index: int) -> void:
	_hud.journalise("Le slot %d a résisté au reroll — le verrou a tenu." % (slot_index + 1))


# ── Boucle d'étage ────────────────────────────────────────────────────────

## Fait défiler les 5 écoles sur un slot. Purement un outil de comparaison :
## en jeu, les écoles se choisissent avant la descente et ne bougent plus.
func _sur_ecole_changee(slot_index: int, pas: int) -> void:
	var slot: SpellSlot = GameState.run.players[0].slots[slot_index]
	var actuelle: int = 0
	for i: int in PrototypeCatalogue.SCHOOLS.size():
		if PrototypeCatalogue.SCHOOLS[i]["id"] == slot.school_id:
			actuelle = i
			break
	var total: int = PrototypeCatalogue.SCHOOLS.size()
	var suivante: Dictionary = PrototypeCatalogue.SCHOOLS[(actuelle + pas + total) % total]
	GameState.set_slot_school(0, slot_index, suivante["id"],
		(suivante["effets"] as Array).size())
	_hud.journalise("Slot %d passe à %s — %d effets possibles." % [
		slot_index + 1, suivante["nom"], (suivante["effets"] as Array).size(),
	])


func _descend() -> void:
	if not GameState.is_in_run():
		return
	# complete_floor puis advance_floor : l'achat a déjà eu lieu chez le
	# marchand, le reroll se produit maintenant. Jamais l'inverse.
	GameState.complete_floor()
	GameState.advance_floor()
	_assemble_l_etage()
	_joueur.global_position = Vector3(0, 1.2, 0)
	_peuple_l_etage()
	_hud.journalise("Étage %d. Tes sorts non scellés ont muté." % (GameState.run.floor_index + 1))


func _redemarre() -> void:
	GameState.start_run(0, 1)
	GameState.set_player_schools(0, PrototypeCatalogue.school_defs([0, 1, 2, 4]))
	_assemble_l_etage()
	_joueur.global_position = Vector3(0, 1.2, 0)
	_peuple_l_etage()
