extends Node3D
## Terrain d'essai : une salle, des postes, aucun enjeu.
##
## Il existe parce que tester une sensation dans le donjon coûte trop cher. Pour
## juger d'une projection il faut la subir vingt fois d'affilée ; pour calibrer
## un dégât il faut voir le chiffre descendre ; pour juger du reroll il faut le
## rejouer sans nettoyer trois étages d'abord. Le donjon rend chacune de ces
## boucles longue, donc on ne les fait pas, donc rien ne se règle.
##
## Il monte le MÊME PlayField que le jeu : même joueur, même HUD, mêmes sorts,
## mêmes matériaux. Un banc d'essai qui reconstruit une version simplifiée du
## jeu finit par mesurer le banc.
##
## On n'y meurt pas. Une mort ici n'apprend rien et coûte un rechargement.

const COTE_SALLE: float = 52.0

var _terrain: PlayField
var _spawner: MonsterSpawner
var _postes: Array[LabStation] = []
var _poste_vise: LabStation = null
var _debug := DebugCommands.new()


func _ready() -> void:
	_terrain = PlayField.new(self)
	_terrain.monte()
	_terrain.joueur.position = Vector3(0, 1.2, 18.0)

	_batit_la_salle()

	# Une run est ouverte comme en jeu : les slots, la Résonance et les
	# monstres n'existent qu'à l'intérieur d'une run (R1). Le terrain d'essai
	# ne fait pas exception, sinon il testerait un autre état que le jeu.
	GameState.start_run(1, 1)
	GameState.set_player_schools(0, PlayField.definitions_choisies())

	_spawner = MonsterSpawner.new(_terrain.conteneur_monstres, Content.tuning)
	_spawner.monstre_veut_tirer.connect(func(depuis: Vector3, dir: Vector3,
			degats: int) -> void:
		add_child(EnemyProjectile.cree(_terrain.fx, depuis, dir, degats)))
	_terrain.contexte.monstres = _spawner.avatars

	_installe_les_postes()
	_terrain.hud.aide_debug(_aide())
	_terrain.hud.journalise(
		"Terrain d'essai. Fais le tour des postes — ici, rien ne compte.")

	EventBus.monster_damaged.connect(func(id: int, pv: int, degats: int) -> void:
		var avatar: MonsterAvatar = _spawner.avatars.get(id)
		if is_instance_valid(avatar):
			avatar.encaisse_visuellement(degats, pv <= 0))


func _physics_process(delta: float) -> void:
	EffectResolver.resolve_tick()
	if _terrain.sequence_en_cours:
		return

	_terrain.seme_la_trainee(delta)
	_maj_interaction()

	if Input.is_action_just_pressed(InputActions.INTERAGIR) and _poste_vise != null:
		var message: String = _poste_vise.interagit()
		if message != "":
			_terrain.hud.journalise(message)

	_empeche_la_mort()


func _unhandled_input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if _debug.traite(touche):
		get_viewport().set_input_as_handled()
		return
	if _terrain.traite_raccourci(touche):
		get_viewport().set_input_as_handled()
		return
	if touche != null and touche.pressed and touche.physical_keycode == KEY_BACKSPACE:
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_MENU)


# ── Construction ──────────────────────────────────────────────────────────

func _batit_la_salle() -> void:
	var builder := FloorBuilder.new(_terrain.geometrie, Content.tuning)
	var salle := FloorPlan.Salle.new()
	salle.centre = Vector3.ZERO
	salle.cote = COTE_SALLE
	var plan := FloorPlan.new()
	plan.salles.append(salle)
	builder.batit(plan)


## Les postes sont posés à la main, largement espacés : deux bancs qui se
## touchent se contaminent, et on ne sait plus lequel a projeté quoi.
func _installe_les_postes() -> void:
	var mannequins := DummyStation.new()
	mannequins.spawner = _spawner
	_ajoute(mannequins, Vector3(-14, 0, -14))

	_ajoute(BlastStation.new(), Vector3(14, 0, -14))
	_ajoute(PropsStation.new(), Vector3(-14, 0, 6))
	_ajoute(RerollStation.new(), Vector3(14, 0, 6))
	_ajoute(RangeStation.new(), Vector3(-18, 0, 18))


func _ajoute(poste: LabStation, pos: Vector3) -> void:
	poste.terrain = _terrain
	poste.position = pos
	add_child(poste)
	poste.installe()
	_postes.append(poste)


# ── Boucle ────────────────────────────────────────────────────────────────

func _maj_interaction() -> void:
	_poste_vise = null
	var meilleure: float = INF
	for poste: LabStation in _postes:
		var d: float = _terrain.joueur.global_position.distance_to(
			poste.global_position)
		if d <= LabStation.PORTEE_INTERACTION and d < meilleure:
			meilleure = d
			_poste_vise = poste

	_terrain.hud.invite(_poste_vise.invite() if _poste_vise != null
		else _terrain.joueur.invite_portage())


## Ici on ne meurt pas : on se relève. Une mort au banc d'essai n'apprend rien
## et coûte un rechargement de scène — c'est-à-dire l'abandon de l'essai en
## cours, qui était justement la chose intéressante.
func _empeche_la_mort() -> void:
	if not GameState.is_in_run():
		return
	var p: PlayerState = GameState.run.players[0]
	if p.hp > 0:
		return
	p.hp = p.max_hp
	_terrain.hud.journalise("Au terrain d'essai, on ne meurt pas. Points de vie rendus.")


func _aide() -> String:
	var lignes: String = ("[color=#7fd0ff][b]Terrain d'essai[/b]  "
		+ "Retour arrière — revenir au menu[/color]")
	var texte: String = _debug.aide()
	return (texte + "\n" + lignes) if texte != "" else lignes
