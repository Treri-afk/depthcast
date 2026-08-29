extends Node3D
## Racine du jeu. Elle assemble et relaie, elle n'implémente rien.
##
## Chaque responsabilité vit dans sa propre classe : les entrées, l'éclairage,
## le plan d'étage, le bâtisseur, le meublage, la salle du marchand, le
## spawner, le lanceur de sorts, l'aperçu de téléportation. Si ce fichier
## recommence à grossir, c'est qu'une responsabilité y a été glissée au lieu
## d'être extraite.

const PORTEE_INTERACTION: float = 3.2

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
var _debug := DebugCommands.new()


func _ready() -> void:
	InputActions.declare()
	WorldLighting.installe(self)
	_construit_les_conteneurs()
	_construit_le_joueur()
	_construit_le_hud()
	_assemble_les_services()
	_branche_les_evenements()

	GameState.start_run(0, 1)
	GameState.set_player_schools(0, _definitions_choisies())
	_contexte.objets = _etage.genere()
	_hud.journalise("Nettoie l'étage, va voir le marchand au fond, puis prends le portail.")
	_hud.aide_debug(_debug.aide())


func _physics_process(delta: float) -> void:
	# Un tick de résolution par frame physique : toutes les intentions soumises
	# pendant cette frame sont triées puis appliquées ensemble (R4).
	EffectResolver.resolve_tick()

	_seme_la_trainee(delta)
	_maj_interaction()

	if Input.is_action_just_pressed(InputActions.INTERAGIR):
		_interagit()

	if GameState.is_in_run() and GameState.run.players[0].hp <= 0:
		_termine_la_run(false)


func _unhandled_input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if _debug.traite(touche):
		get_viewport().set_input_as_handled()
		return
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


## Les écoles composées au hub. En leur absence — lancement direct de la scène
## de jeu pendant le développement — on retombe sur les quatre premières
## débloquées plutôt que de planter.
func _definitions_choisies() -> Array:
	var ids: Array[StringName] = GameState.ecoles_choisies
	if ids.is_empty():
		for ecole: School in Meta.ecoles_disponibles():
			if ids.size() < PlayerState.SLOT_COUNT:
				ids.append(ecole.id)
	var out: Array = []
	for id: StringName in ids:
		var ecole: School = Content.ecole(id)
		if ecole != null:
			out.append({"id": ecole.id, "pool_size": ecole.taille_pool()})
	return out


## Fin de run : par la mort, ou par la chute du boss.
func _termine_la_run(victoire: bool) -> void:
	if not GameState.is_in_run():
		return
	var etage: int = GameState.run.floor_index
	var graine: int = GameState.run.run_seed
	GameState.end_run(victoire)
	MouseLook.capture(false)

	var ecran := RunEndScreen.new()
	ecran.victoire = victoire
	ecran.etage_atteint = etage
	ecran.seed_run = graine
	var couche := CanvasLayer.new()
	couche.layer = 10
	couche.add_child(ecran)
	add_child(couche)


func _branche_les_evenements() -> void:
	_joueur.a_lance.connect(func(slot: int, dir: Vector3) -> void: _caster.lance(slot, dir))
	_marchand.achat_effectue.connect(_hud.journalise)
	_spawner.monstre_veut_tirer.connect(_sur_tir_monstre)
	_etage.boss_invoque.connect(_sur_boss_invoque)
	# Sauter un étage passe par la même porte que le portail : le reroll et la
	# régénération doivent se produire exactement comme en jeu normal, sinon on
	# ne teste pas la vraie boucle.
	_debug.saut_d_etage_demande.connect(func() -> void:
		if GameState.is_in_run():
			_descend_d_un_etage())
	_debug.message.connect(_hud.journalise)

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

	# Pas de portail dans l'arène : la seule sortie est la victoire.
	if _portail_a_portee and not _etage.est_etage_de_boss():
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
		_descend_d_un_etage()
		return
	if _socle_vise != null:
		_marchand.achete(_socle_vise)


func _descend_d_un_etage() -> void:
	_contexte.objets = _etage.descend()
	_hud.journalise("Étage %d. Tes sorts non scellés ont muté." %
		(GameState.run.floor_index + 1))


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
	var etait_le_boss: bool = avatar is BossAvatar
	if is_instance_valid(avatar):
		avatar.meurt_en_se_dissolvant()
	# Retiré du registre immédiatement : la dissolution est un effet visuel,
	# le monstre ne doit plus compter comme vivant pendant qu'elle joue.
	_spawner.avatars.erase(monster_id)

	if etait_le_boss:
		_termine_la_run(true)
		return

	_hud.journalise("+%d Résonance   ·   %d monstre(s) restant(s)" % [
		recompense, GameState.run.alive_monsters().size()])


func _sur_boss_invoque(avatar: BossAvatar) -> void:
	var titre: String = (avatar.stats as BossStats).titre
	_hud.journalise("%s — %d phases. Aucun marchand ici." % [
		titre, (avatar.stats as BossStats).nombre_de_phases()])
	avatar.phase_changee.connect(func(phase: int, total: int) -> void:
		_hud.journalise("%s entre en phase %d sur %d." % [titre, phase + 1, total]))


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
