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
const COUT_VERROU: int = 20
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
	_hud.journalise("ZQSD pour bouger · souris pour viser · clic ou 1-4 pour lancer · F pour descendre · Échap pour le curseur")


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
	elif touche.ctrl_pressed or touche.meta_pressed:
		_sur_verrou_demande(index)
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	# Un tick de résolution par frame physique. Toutes les intentions soumises
	# pendant cette frame sont triées puis appliquées ensemble (R4).
	EffectResolver.resolve_tick()

	if Input.is_action_just_pressed("proto_etage_suivant"):
		_descend()

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
		"proto_etage_suivant": [KEY_F],
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


## Assemble l'étage : une chaîne de salles reliées par des couloirs.
##
## C'est une version minuscule du principe posé au GDD §5 — des salles
## pré-conçues assemblées selon une seed, jamais de géométrie inventée à la
## volée. Ici les salles sont de simples boîtes, mais le générateur ne connaît
## déjà que des connecteurs et une seed : c'est la structure qui compte.
func _assemble_l_etage() -> void:
	for enfant: Node in _geometrie.get_children():
		enfant.queue_free()
	_salles.clear()

	var rng: RandomNumberGenerator = RngService.stream(RngService.STREAM_DUNGEON)
	var centre := Vector3.ZERO
	var direction := Vector3.RIGHT

	for i: int in SALLES_PAR_ETAGE:
		var cote: float = rng.randf_range(TAILLE_SALLE_MIN, TAILLE_SALLE_MAX)
		var salle := {"centre": centre, "taille": cote}
		_salles.append(salle)

		var ouverture_entree: bool = i > 0
		var ouverture_sortie: bool = i < SALLES_PAR_ETAGE - 1
		_batit_salle(centre, cote, direction, ouverture_entree, ouverture_sortie)

		if not ouverture_sortie:
			break

		# La direction alterne pour que l'étage ne soit pas une ligne droite.
		var suivante: Vector3 = Vector3.FORWARD if direction == Vector3.RIGHT else Vector3.RIGHT
		var cote_suivant: float = rng.randf_range(TAILLE_SALLE_MIN, TAILLE_SALLE_MAX)
		var depart: Vector3 = centre + direction * (cote * 0.5)
		_batit_couloir(depart, direction)
		centre = centre + direction * (cote * 0.5 + LONGUEUR_COULOIR + cote_suivant * 0.5)
		direction = suivante


func _batit_salle(centre: Vector3, cote: float, direction_sortie: Vector3,
		ouverture_entree: bool, ouverture_sortie: bool) -> void:
	_ajoute_bloc(centre + Vector3(0, -0.5, 0), Vector3(cote, 1, cote),
		Color(0.30, 0.31, 0.36))

	var demi: float = cote * 0.5
	# Les quatre murs. Celui qui porte la sortie — et celui d'où l'on vient —
	# reçoivent une ouverture de la largeur du couloir.
	var murs := [
		{"pos": Vector3(demi, 0, 0), "axe_z": true, "dir": Vector3.RIGHT},
		{"pos": Vector3(-demi, 0, 0), "axe_z": true, "dir": Vector3.LEFT},
		{"pos": Vector3(0, 0, demi), "axe_z": false, "dir": Vector3.BACK},
		{"pos": Vector3(0, 0, -demi), "axe_z": false, "dir": Vector3.FORWARD},
	]
	# L'entrée vient forcément du côté opposé à la sortie précédente.
	var entree_dir: Vector3 = -direction_sortie if not ouverture_sortie else Vector3.LEFT
	if ouverture_entree and ouverture_sortie:
		entree_dir = Vector3.LEFT if direction_sortie == Vector3.FORWARD else Vector3.FORWARD

	for mur: Dictionary in murs:
		var perce: bool = (ouverture_sortie and mur["dir"] == direction_sortie) \
			or (ouverture_entree and mur["dir"] == entree_dir)
		_batit_mur(centre + mur["pos"], cote, mur["axe_z"], perce)


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


func _construit_le_hud() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	_hud = PrototypeHud.new()
	_hud.joueur = _joueur
	_hud.verrou_demande.connect(_sur_verrou_demande)
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
			_tire_projectile(slot_index, eff, direction, couleur)
		PrototypeCatalogue.Behaviour.NOVA:
			_declenche_nova(slot_index, eff, couleur)
		PrototypeCatalogue.Behaviour.SOIN:
			_lance_soin(slot_index, eff, couleur)


func _tire_projectile(slot_index: int, eff: Dictionary, direction: Vector3,
		couleur: Color) -> void:
	var portee: float = float(eff.get("portee", 20.0))
	var degats: int = int(eff.get("degats", 10))

	var bille := Area3D.new()
	bille.position = _joueur.position_yeux() + direction * 0.8
	var forme := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	forme.shape = sphere
	bille.add_child(forme)

	var visuel := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	visuel.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = couleur
	mat.emission_enabled = true
	mat.emission = couleur
	visuel.material_override = mat
	bille.add_child(visuel)
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
		bille.queue_free()
	)

	var arrivee: Vector3 = bille.position + direction * portee
	var duree: float = portee / VITESSE_PROJECTILE
	var tween := create_tween()
	tween.tween_property(bille, "position", arrivee, duree)
	tween.tween_callback(bille.queue_free)


func _declenche_nova(slot_index: int, eff: Dictionary, couleur: Color) -> void:
	var rayon: float = float(eff.get("rayon", 4.0))
	var degats: int = int(eff.get("degats", 10))

	var cibles: Array = []
	for id: int in _avatars:
		var avatar: MonsterAvatar = _avatars[id]
		if is_instance_valid(avatar) and \
				avatar.global_position.distance_to(_joueur.global_position) <= rayon:
			cibles.append(id)
	_soumet_degats(slot_index, degats, cibles)
	_anneau(rayon, couleur)


func _lance_soin(slot_index: int, eff: Dictionary, couleur: Color) -> void:
	var intent := EffectIntent.new()
	intent.source_player_id = 0
	intent.source_slot = slot_index
	intent.kind = EffectIntent.Kind.HEAL
	intent.amount = float(eff.get("soin", 20))
	intent.target_ids = PackedInt64Array([0])
	EffectResolver.submit(intent)
	_anneau(2.2, couleur)


func _soumet_degats(slot_index: int, degats: int, monstres: Array) -> void:
	var intent := EffectIntent.new()
	intent.source_player_id = 0
	intent.source_slot = slot_index
	intent.kind = EffectIntent.Kind.DAMAGE
	intent.amount = degats
	intent.target_monsters = PackedInt64Array(monstres)
	EffectResolver.submit(intent)


## Petit anneau qui s'évase, pour que la nova et le soin se voient.
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


func _sur_verrou_demande(slot_index: int) -> void:
	if GameState.try_lock_slot(0, slot_index, COUT_VERROU):
		_hud.journalise("Slot %d verrouillé pour %d de Résonance." % [slot_index + 1, COUT_VERROU])


func _descend() -> void:
	if not GameState.is_in_run():
		return
	GameState.complete_floor()
	GameState.advance_floor()
	_assemble_l_etage()
	_joueur.position = Vector3(0, 1.0, 0)
	_peuple_l_etage()


func _redemarre() -> void:
	GameState.start_run(0, 1)
	GameState.set_player_schools(0, PrototypeCatalogue.school_defs([0, 1, 2, 4]))
	_assemble_l_etage()
	_joueur.position = Vector3(0, 1.0, 0)
	_peuple_l_etage()
