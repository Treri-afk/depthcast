extends Node3D
## Racine du jeu. Elle assemble et relaie, elle n'implémente rien.
##
## Chaque responsabilité vit dans sa propre classe : les entrées, l'éclairage,
## le plan d'étage, le bâtisseur, le meublage, la salle du marchand, le
## spawner, le lanceur de sorts, l'aperçu de téléportation. Si ce fichier
## recommence à grossir, c'est qu'une responsabilité y a été glissée au lieu
## d'être extraite.

const PORTEE_INTERACTION: float = 3.2

## Le socle partagé avec le terrain d'essai : joueur, HUD, sorts.
var _terrain: PlayField
var _joueur: PlayerAvatar
var _hud: GameHud

var _fx: FxLibrary
var _contexte: SpellContext
var _marchand: MerchantRoom
var _spawner: MonsterSpawner
var _etage: FloorDirector

## Slots ayant muté à la dernière descente. Rempli par les signaux, consommé
## par la séquence de reroll.
var _mutations: Array[bool] = []
var _socle_vise: ShopPedestal = null
var _portail_a_portee: bool = false
var _debug := DebugCommands.new()


func _ready() -> void:
	_terrain = PlayField.new(self)
	_terrain.monte()
	_joueur = _terrain.joueur
	_hud = _terrain.hud
	_fx = _terrain.fx
	_contexte = _terrain.contexte

	_assemble_le_donjon()
	_branche_les_evenements()
	_contexte.objets = _etage.genere()
	_hud.journalise("Nettoie l'étage, va voir le marchand au fond, puis prends le portail.")
	_hud.aide_debug(_debug.aide())


func _physics_process(delta: float) -> void:
	# Un tick de résolution par frame physique : toutes les intentions soumises
	# pendant cette frame sont triées puis appliquées ensemble (R4).
	EffectResolver.resolve_tick()

	if _terrain.sequence_en_cours:
		return

	_terrain.seme_la_trainee(delta)
	_maj_interaction()

	if Input.is_action_just_pressed(InputActions.INTERAGIR):
		_interagit()

	var local: PlayerState = GameState.local_player()
	if GameState.is_in_run() and local != null and local.hp <= 0:
		_termine_la_run(false)


func _unhandled_input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if _debug.traite(touche):
		get_viewport().set_input_as_handled()
		return
	if _terrain.traite_raccourci(touche):
		get_viewport().set_input_as_handled()


# ── Assemblage ────────────────────────────────────────────────────────────

## Ce qui appartient au donjon, et rien d'autre. Le joueur, le HUD et les sorts
## sont montés par PlayField : ils sont identiques au terrain d'essai, et le
## jour où ils divergeraient, c'est qu'on aurait cessé de tester le vrai jeu.
func _assemble_le_donjon() -> void:
	var tuning: Tuning = Content.tuning
	var geometrie: Node3D = _terrain.geometrie

	var builder := FloorBuilder.new(geometrie, tuning)
	var furnisher := RoomFurnisher.new(builder, geometrie, tuning)
	_marchand = MerchantRoom.new(geometrie, tuning, _fx)
	_spawner = MonsterSpawner.new(_terrain.conteneur_monstres, tuning)
	_contexte.monstres = _spawner.avatars

	_etage = FloorDirector.new(geometrie, tuning, builder, furnisher,
		_marchand, _spawner, _terrain.avatars)


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
		_note_mutation(slot, true))
	EventBus.slot_kept.connect(func(_j: int, slot: int) -> void:
		_note_mutation(slot, false))
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
		# Rien à acheter, rien à franchir : restent les mains.
		_hud.invite(_joueur.invite_portage())


func _interagit() -> void:
	if _portail_a_portee:
		if not _etage.peut_descendre():
			_hud.journalise("Le portail reste scellé tant que l'étage n'est pas nettoyé.")
			return
		_descend_d_un_etage()
		return
	if _socle_vise != null:
		_marchand.achete(_socle_vise)


func _note_mutation(slot: int, mute: bool) -> void:
	while _mutations.size() <= slot:
		_mutations.append(false)
	_mutations[slot] = mute


func _descend_d_un_etage() -> void:
	_mutations.clear()
	_contexte.objets = _etage.descend()
	_terrain.montre_le_reroll(_mutations, GameState.run.floor_index)
	_hud.journalise("Étage %d. Tes sorts non scellés ont muté." %
		(GameState.run.floor_index + 1))


# ── Relais ────────────────────────────────────────────────────────────────

func _sur_tir_monstre(depuis: Vector3, direction: Vector3, degats: int) -> void:
	add_child(EnemyProjectile.cree(_fx, depuis, direction, degats))


func _sur_degat_monstre(monster_id: int, pv_restant: int, degats: int) -> void:
	var avatar: MonsterAvatar = _spawner.avatars.get(monster_id)
	if is_instance_valid(avatar):
		# Le coup fatal se lit dans les points de vie restants : rien de plus à
		# faire passer, et le chiffre qui tue s'affiche différemment.
		avatar.encaisse_visuellement(degats, pv_restant <= 0)


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
