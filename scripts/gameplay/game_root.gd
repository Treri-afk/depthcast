extends Node3D
## Racine du jeu. Elle orchestre, elle n'implémente rien.
##
## Chaque responsabilité vit dans sa propre classe : le plan d'étage, le
## bâtisseur, le meublage, la salle du marchand, le spawner, le lanceur de
## sorts. Si ce fichier recommence à grossir, c'est qu'une responsabilité y a
## été glissée au lieu d'être extraite.

const PORTEE_INTERACTION: float = 3.2

var _joueur: PlayerAvatar
var _hud: GameHud
var _geometrie: Node3D
var _conteneur_monstres: Node3D

var _tuning: Tuning
var _fx: FxLibrary
var _contexte: SpellContext
var _caster: SpellCaster
var _builder: FloorBuilder
var _furnisher: RoomFurnisher
var _marchand: MerchantRoom
var _spawner: MonsterSpawner

var _plan: FloorPlan
var _cible_interaction: Dictionary = {}
var _apercu: MeshInstance3D


func _ready() -> void:
	_tuning = Content.tuning
	_declare_les_touches()
	_construit_le_decor_permanent()
	_construit_le_joueur()
	_construit_le_hud()
	_assemble_les_services()

	GameState.start_run(0, 1)
	GameState.set_player_schools(0, Content.definitions_ecoles([0, 1, 2, 4]))

	EventBus.monster_damaged.connect(_sur_degat_monstre)
	EventBus.monster_died.connect(_sur_mort_monstre)
	EventBus.slot_rerolled.connect(_sur_reroll)
	EventBus.slot_kept.connect(_sur_slot_garde)
	EventBus.resonance_spend_rejected.connect(
		func(_id: int, raison: String) -> void: _hud.journalise("Achat refusé : " + raison))

	_nouvel_etage()
	_hud.journalise("Nettoie l'étage, va voir le marchand au fond, puis prends le portail.")


func _physics_process(_delta: float) -> void:
	# Un tick de résolution par frame physique : toutes les intentions soumises
	# pendant cette frame sont triées puis appliquées ensemble (R4).
	EffectResolver.resolve_tick()

	_maj_trainee(_delta)
	_maj_apercu_teleport()
	_maj_interaction()

	if Input.is_action_just_pressed("proto_interagir"):
		_interagit()

	if GameState.is_in_run() and GameState.run.players[0].hp <= 0:
		_hud.journalise("Mort à l'étage %d. La run redémarre." %
			(GameState.run.floor_index + 1))
		_redemarre()


# ── Assemblage ────────────────────────────────────────────────────────────

func _assemble_les_services() -> void:
	_fx = FxLibrary.new(self)

	_contexte = SpellContext.new()
	_contexte.monde = self
	_contexte.joueur = _joueur
	_contexte.fx = _fx
	_contexte.tuning = _tuning
	_caster = SpellCaster.new(_contexte)
	_hud.caster = _caster

	_builder = FloorBuilder.new(_geometrie, _tuning)
	_furnisher = RoomFurnisher.new(_builder, _geometrie, _tuning)
	_marchand = MerchantRoom.new(_geometrie, _tuning, _fx)
	_marchand.achat_effectue.connect(_hud.journalise)

	_spawner = MonsterSpawner.new(_conteneur_monstres, _tuning)
	_spawner.monstre_veut_tirer.connect(_sur_tir_monstre)
	_contexte.monstres = _spawner.avatars


func _construit_le_decor_permanent() -> void:
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

	_conteneur_monstres = Node3D.new()
	_conteneur_monstres.name = "Monstres"
	add_child(_conteneur_monstres)


func _construit_le_joueur() -> void:
	_joueur = PlayerAvatar.new()
	_joueur.name = "Joueur"
	_joueur.position = Vector3(0, 1.2, 0)

	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	forme.shape = capsule
	_joueur.add_child(forme)
	# Aucun mesh : en vue subjective, on ne se voit pas soi-même.
	_joueur.a_lance.connect(_sur_lancer)
	add_child(_joueur)

	# Aperçu de téléportation, affiché seulement quand un slot PRÊT et DÉCOUVERT
	# porte une téléportation. Le montrer sur un slot en ??? révélerait le sort
	# avant de l'avoir lancé.
	_apercu = MeshInstance3D.new()
	var cylindre := CylinderMesh.new()
	cylindre.top_radius = 0.75
	cylindre.bottom_radius = 0.75
	cylindre.height = 0.12
	_apercu.mesh = cylindre
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.66, 0.44, 0.95, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.66, 0.44, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_apercu.material_override = mat
	_apercu.visible = false
	add_child(_apercu)


func _construit_le_hud() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	_hud = GameHud.new()
	_hud.joueur = _joueur
	_hud.ecole_changee.connect(_sur_ecole_changee)
	couche.add_child(_hud)


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


# ── Boucle d'étage ────────────────────────────────────────────────────────

func _nouvel_etage() -> void:
	var rng: RandomNumberGenerator = RngService.stream(RngService.STREAM_DUNGEON)

	for enfant: Node in _geometrie.get_children():
		enfant.queue_free()
	_furnisher.objets.clear()

	_plan = FloorPlan.genere(rng, _tuning)
	_builder.batit(_plan)
	for salle: FloorPlan.Salle in _plan.salles:
		_furnisher.meuble(salle, rng)
	_marchand.installe(_plan.salle_du_marchand())
	_contexte.objets = _furnisher.objets

	_spawner.peuple(_plan, _joueur, GameState.run.floor_index, rng)
	_joueur.global_position = _plan.salle_de_depart().centre + Vector3(0, 1.2, 0)


func _descend() -> void:
	if not GameState.is_in_run():
		return
	# L'achat a déjà eu lieu chez le marchand ; le reroll se produit maintenant.
	# Jamais l'inverse, sinon les sceaux ne serviraient à rien.
	GameState.complete_floor()
	GameState.advance_floor()
	_nouvel_etage()
	_hud.journalise("Étage %d. Tes sorts non scellés ont muté." %
		(GameState.run.floor_index + 1))


func _redemarre() -> void:
	GameState.start_run(0, 1)
	GameState.set_player_schools(0, Content.definitions_ecoles([0, 1, 2, 4]))
	_nouvel_etage()


# ── Interaction ───────────────────────────────────────────────────────────

func _maj_interaction() -> void:
	_cible_interaction = _marchand.cible_proche(
		_joueur.global_position, PORTEE_INTERACTION)
	_hud.invite(_marchand.libelle(_cible_interaction))


func _interagit() -> void:
	if _cible_interaction.is_empty():
		return
	if String(_cible_interaction.get("type", "")) == "portail":
		# Le portail reste scellé tant que l'étage n'est pas nettoyé : sinon on
		# traverse le donjon sans jamais combattre, et il n'y a plus de boucle.
		if GameState.run.alive_monsters().size() > 0:
			_hud.journalise("Le portail reste scellé tant que l'étage n'est pas nettoyé.")
			return
		_descend()
		return
	_marchand.achete(_cible_interaction)


# ── Sorts ─────────────────────────────────────────────────────────────────

func _sur_lancer(slot_index: int, direction: Vector3) -> void:
	_caster.lance(slot_index, direction)


## La traînée s'étale dans le temps : elle sème une flaque tous les 1,6 mètre
## et non toutes les N secondes, sinon rester immobile empilerait dix flaques
## au même endroit.
func _maj_trainee(delta: float) -> void:
	var flaque: Dictionary = _joueur.consomme_flaque(delta)
	if flaque.is_empty():
		return
	var effet: SpellEffect = flaque["effet"]
	var zone := ZoneEffet.cree(ZoneEffet.Forme.SPHERE,
		Vector3(effet.rayon, 0, 0),
		Vector3(flaque["position"].x, 0.4, flaque["position"].z))
	zone.duree = effet.duree_secondaire
	zone.intervalle = effet.intervalle
	zone.degats = effet.degats
	zone.source_slot = int(flaque["slot"])
	zone.couleur = flaque["couleur"]
	add_child(zone)


func _maj_apercu_teleport() -> void:
	var etage: int = GameState.run.floor_index
	var portee: float = 0.0

	for i: int in PlayerState.SLOT_COUNT:
		var slot: SpellSlot = GameState.run.players[0].slots[i]
		if not slot.is_discovered_on(etage) or _joueur.cooldown_restant(i) > 0.0:
			continue
		var effet: SpellEffect = _caster.effet_actif(0, i)
		if effet != null and effet.comportement == SpellEffect.Comportement.TELEPORT:
			portee = effet.portee
			break

	_apercu.visible = portee > 0.0
	if _apercu.visible:
		_apercu.global_position = _joueur.point_vise(portee) - Vector3(0, 0.9, 0)


## Projectile ennemi. Il passe par le resolver comme tout le reste (R4).
func _sur_tir_monstre(depuis: Vector3, direction: Vector3, degats: int) -> void:
	var bille := Area3D.new()
	bille.position = depuis
	var forme := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	forme.shape = sphere
	bille.add_child(forme)
	bille.add_child(_fx.sphere_lumineuse(0.3, Color(0.85, 0.4, 0.9)))
	add_child(bille)

	var consomme: Array[bool] = [false]
	bille.body_entered.connect(func(corps: Node3D) -> void:
		if consomme[0]:
			return
		consomme[0] = true
		if corps is PlayerAvatar:
			var intent := EffectIntent.new()
			intent.source_player_id = -1
			intent.source_slot = -1
			intent.kind = EffectIntent.Kind.DAMAGE
			intent.amount = degats
			intent.target_ids = PackedInt64Array([0])
			EffectResolver.submit(intent)
		bille.queue_free()
	)

	var tween := create_tween()
	tween.tween_property(bille, "position", depuis + direction * 22.0, 1.7)
	tween.tween_callback(bille.queue_free)


# ── Réactions ─────────────────────────────────────────────────────────────

func _sur_degat_monstre(monster_id: int, _pv: int) -> void:
	var avatar: MonsterAvatar = _spawner.avatars.get(monster_id)
	if is_instance_valid(avatar):
		avatar.encaisse_visuellement()


func _sur_mort_monstre(monster_id: int, _tueur: int, recompense: int) -> void:
	var avatar: MonsterAvatar = _spawner.avatars.get(monster_id)
	if is_instance_valid(avatar):
		avatar.queue_free()
	_spawner.avatars.erase(monster_id)
	_hud.journalise("+%d Résonance   ·   %d monstre(s) restant(s)" % [
		recompense, GameState.run.alive_monsters().size()])


func _sur_reroll(_joueur_id: int, slot_index: int, _effet: int) -> void:
	_hud.journalise("Le slot %d a muté. Lance-le pour découvrir ce qu'il fait." %
		(slot_index + 1))


func _sur_slot_garde(_joueur_id: int, slot_index: int) -> void:
	_hud.journalise("Le slot %d a résisté au reroll — le sceau a tenu." % (slot_index + 1))


## Fait défiler les écoles sur un slot. Outil de comparaison du prototype : en
## jeu, les écoles se choisissent avant la descente et ne bougent plus.
func _sur_ecole_changee(slot_index: int, pas: int) -> void:
	var slot: SpellSlot = GameState.run.players[0].slots[slot_index]
	var total: int = Content.ecoles.size()
	if total == 0:
		return
	var index: int = (Content.index_ecole(slot.school_id) + pas + total) % total
	var suivante: School = Content.ecoles[index]
	GameState.set_slot_school(0, slot_index, suivante.id, suivante.taille_pool())
	_hud.journalise("Slot %d passe à %s — %d effets possibles." % [
		slot_index + 1, suivante.nom, suivante.taille_pool()])


func _unhandled_input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo:
		return
	var index: int = [KEY_1, KEY_2, KEY_3, KEY_4].find(touche.physical_keycode)
	if index >= 0 and touche.shift_pressed:
		_sur_ecole_changee(index, 1)
		get_viewport().set_input_as_handled()
