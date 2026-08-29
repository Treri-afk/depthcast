extends Node3D
## Racine du jeu. Elle assemble et relaie, elle n'implémente rien.
##
## Chaque responsabilité vit dans sa propre classe : les entrées, l'éclairage,
## le plan d'étage, le bâtisseur, le meublage, la salle du marchand, le
## spawner, le lanceur de sorts, l'aperçu de téléportation. Si ce fichier
## recommence à grossir, c'est qu'une responsabilité y a été glissée au lieu
## d'être extraite.

const PORTEE_INTERACTION: float = 3.2
## Les quatre écoles emmenées en descente. Passera par un écran de sélection.
const ECOLES_DE_DEPART: Array[int] = [0, 1, 2, 4]

var _joueur: PlayerAvatar
var _hud: GameHud
var _geometrie: Node3D
var _conteneur_monstres: Node3D

var _fx: FxLibrary
var _contexte: SpellContext
var _caster: SpellCaster
var _marchand: MerchantRoom
var _spawner: MonsterSpawner
var _etage: FloorDirector

var _socle_vise: ShopPedestal = null
var _portail_a_portee: bool = false


func _ready() -> void:
	InputActions.declare()
	WorldLighting.installe(self)
	_construit_les_conteneurs()
	_construit_le_joueur()
	_construit_le_hud()
	_assemble_les_services()
	_branche_les_evenements()

	GameState.start_run(0, 1)
	GameState.set_player_schools(0, Content.definitions_ecoles(ECOLES_DE_DEPART))
	_contexte.objets = _etage.genere()
	_hud.journalise("Nettoie l'étage, va voir le marchand au fond, puis prends le portail.")


func _physics_process(delta: float) -> void:
	# Un tick de résolution par frame physique : toutes les intentions soumises
	# pendant cette frame sont triées puis appliquées ensemble (R4).
	EffectResolver.resolve_tick()

	_seme_la_trainee(delta)
	_maj_interaction()

	if Input.is_action_just_pressed(InputActions.INTERAGIR):
		_interagit()

	if GameState.is_in_run() and GameState.run.players[0].hp <= 0:
		_hud.journalise("Mort à l'étage %d. La run redémarre." %
			(GameState.run.floor_index + 1))
		_contexte.objets = _etage.redemarre(
			Content.definitions_ecoles(ECOLES_DE_DEPART))


func _unhandled_input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo or not touche.shift_pressed:
		return
	var index: int = InputActions.TOUCHES_SLOTS.find(touche.physical_keycode)
	if index >= 0:
		_change_ecole(index, 1)
		get_viewport().set_input_as_handled()


# ── Assemblage ────────────────────────────────────────────────────────────

func _construit_les_conteneurs() -> void:
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
	add_child(_joueur)


func _construit_le_hud() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	_hud = GameHud.new()
	_hud.joueur = _joueur
	_hud.ecole_changee.connect(_change_ecole)
	couche.add_child(_hud)


func _assemble_les_services() -> void:
	var tuning: Tuning = Content.tuning
	_fx = FxLibrary.new(self)

	_contexte = SpellContext.new()
	_contexte.monde = self
	_contexte.joueur = _joueur
	_contexte.fx = _fx
	_contexte.tuning = tuning
	_caster = SpellCaster.new(_contexte)
	_hud.caster = _caster

	var builder := FloorBuilder.new(_geometrie, tuning)
	var furnisher := RoomFurnisher.new(builder, _geometrie, tuning)
	_marchand = MerchantRoom.new(_geometrie, tuning, _fx)
	_spawner = MonsterSpawner.new(_conteneur_monstres, tuning)
	_contexte.monstres = _spawner.avatars

	_etage = FloorDirector.new(_geometrie, tuning, builder, furnisher,
		_marchand, _spawner, _joueur)

	var apercu := TeleportPreview.new()
	apercu.joueur = _joueur
	apercu.caster = _caster
	add_child(apercu)


func _branche_les_evenements() -> void:
	_joueur.a_lance.connect(func(slot: int, dir: Vector3) -> void: _caster.lance(slot, dir))
	_marchand.achat_effectue.connect(_hud.journalise)
	_spawner.monstre_veut_tirer.connect(_sur_tir_monstre)

	EventBus.monster_damaged.connect(_sur_degat_monstre)
	EventBus.monster_died.connect(_sur_mort_monstre)
	EventBus.slot_rerolled.connect(func(_j: int, slot: int, _e: int) -> void:
		_hud.journalise("Le slot %d a muté. Lance-le pour découvrir ce qu'il fait." % (slot + 1)))
	EventBus.slot_kept.connect(func(_j: int, slot: int) -> void:
		_hud.journalise("Le slot %d a résisté au reroll — le sceau a tenu." % (slot + 1)))
	EventBus.resonance_spend_rejected.connect(func(_id: int, raison: String) -> void:
		_hud.journalise("Achat refusé : " + raison))


# ── Interaction ───────────────────────────────────────────────────────────

func _maj_interaction() -> void:
	_socle_vise = _marchand.socle_proche(_joueur.global_position, PORTEE_INTERACTION)
	var distance_portail: float = _marchand.distance_au_portail(_joueur.global_position)
	_portail_a_portee = distance_portail < PORTEE_INTERACTION and _socle_vise == null

	if _portail_a_portee:
		var restants: int = GameState.run.alive_monsters().size()
		_hud.invite("[E] Descendre à l'étage suivant" if restants == 0
			else "[E] Portail scellé — %d monstre(s) à éliminer" % restants)
	elif _socle_vise != null:
		_hud.invite(_marchand.libelle(_socle_vise))
	else:
		_hud.invite("")


func _interagit() -> void:
	if _portail_a_portee:
		if not _etage.peut_descendre():
			_hud.journalise("Le portail reste scellé tant que l'étage n'est pas nettoyé.")
			return
		_contexte.objets = _etage.descend()
		_hud.journalise("Étage %d. Tes sorts non scellés ont muté." %
			(GameState.run.floor_index + 1))
		return
	if _socle_vise != null:
		_marchand.achete(_socle_vise)


# ── Relais ────────────────────────────────────────────────────────────────

## La traînée s'étale dans le temps : le joueur mémorise où semer, la racine
## instancie. Aucun des deux ne connaît la logique de l'autre.
func _seme_la_trainee(delta: float) -> void:
	var flaque: Dictionary = _joueur.consomme_flaque(delta)
	if flaque.is_empty():
		return
	var effet: SpellEffect = flaque["effet"]
	var pos: Vector3 = flaque["position"]
	var zone := ZoneEffet.cree(ZoneEffet.Forme.SPHERE,
		Vector3(effet.rayon, 0, 0), Vector3(pos.x, 0.4, pos.z))
	zone.duree = effet.duree_secondaire
	zone.intervalle = effet.intervalle
	zone.degats = effet.degats
	zone.source_slot = int(flaque["slot"])
	zone.couleur = flaque["couleur"]
	add_child(zone)


func _sur_tir_monstre(depuis: Vector3, direction: Vector3, degats: int) -> void:
	add_child(EnemyProjectile.cree(_fx, depuis, direction, degats))


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


## Fait défiler les écoles sur un slot. Outil de comparaison : en jeu, les
## écoles se choisissent avant la descente et ne bougent plus.
func _change_ecole(slot_index: int, pas: int) -> void:
	var total: int = Content.ecoles.size()
	if total == 0:
		return
	var slot: SpellSlot = GameState.run.players[0].slots[slot_index]
	var index: int = (Content.index_ecole(slot.school_id) + pas + total) % total
	var suivante: School = Content.ecoles[index]
	GameState.set_slot_school(0, slot_index, suivante.id, suivante.taille_pool())
	_hud.journalise("Slot %d passe à %s — %d effets possibles." % [
		slot_index + 1, suivante.nom, suivante.taille_pool()])
