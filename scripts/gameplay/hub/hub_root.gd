extends Node3D
## Le hub : un lieu, pas un menu.
##
## On s'y déplace, on fait le tour des autels, on compose son équipe et on
## franchit le portail. C'est aussi le point de rendez-vous prévu pour le
## co-op : les joueurs s'y retrouvent, chacun prépare son build, puis on
## descend ensemble.
##
## Il réutilise tout du jeu — même avatar, même bâtisseur, même post-traitement.
## Un hub construit avec d'autres briques deviendrait une seconde base de code
## à maintenir, et se mettrait à diverger visuellement dès la première retouche.

const COTE_SALLE: float = 34.0
const RAYON_AUTELS: float = 11.0
const PORTEE_INTERACTION: float = 3.6

var _terrain: PlayField
var _joueur: PlayerAvatar
var _autels: Array[SchoolAltar] = []
var _portail: Portal
var _fx: FxLibrary
var _hud: HubHud
var _cible: SchoolAltar = null
var _portail_a_portee: bool = false


func _ready() -> void:
	# Le MÊME terrain que le donjon, sans combat : des corps, une caméra, la
	# réplication. C'est exactement ce qui manquait au hub pour tenir à
	# plusieurs, et c'était déjà écrit ailleurs.
	_terrain = PlayField.new(self)
	_terrain.monte(0, false)
	_joueur = _terrain.joueur
	_fx = FxLibrary.new(self)

	_batit_la_salle()
	_place_les_joueurs()
	_pose_les_autels()
	_construit_le_hud()
	_synchronise()

	Meta.eclats_changes.connect(func(_t: int) -> void: _synchronise())
	Repl.ecoles_changees.connect(func(_p: int) -> void: _synchronise())
	# Le départ est donné par l'hôte, et tout le monde bascule ensemble.
	Net.partie_lancee.connect(func(_g: int) -> void:
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_JEU))


func _physics_process(_delta: float) -> void:
	_maj_interaction()
	if Input.is_action_just_pressed(InputActions.INTERAGIR):
		_interagit()


## Tout le monde arrive côte à côte, à l'entrée. Empilés au même point, les
## corps se repoussent et partent en gerbe au premier tick physique.
func _place_les_joueurs() -> void:
	var total: int = maxi(_terrain.avatars.size(), 1)
	for i: int in _terrain.avatars.size():
		var ecart: float = (float(i) - float(total - 1) * 0.5) * 1.8
		_terrain.avatars[i].global_position = Vector3(ecart, 1.2, COTE_SALLE * 0.32)


func _batit_la_salle() -> void:
	var tuning: Tuning = Content.tuning
	var conteneur: Node3D = _terrain.geometrie

	var builder := FloorBuilder.new(conteneur, tuning)
	var salle := FloorPlan.Salle.new()
	salle.centre = Vector3.ZERO
	salle.cote = COTE_SALLE
	# Aucune ouverture : d'ici on ne sort que par le portail.
	builder.batit(_plan_d_une_salle(salle))

	# Quelques piliers pour que la salle ait une échelle lisible.
	for i: int in 6:
		var angle: float = TAU * float(i) / 6.0
		builder.bloc(Vector3(cos(angle), 0, sin(angle)) * (COTE_SALLE * 0.42)
			+ Vector3(0, tuning.hauteur_pilier * 0.5, 0),
			Vector3(1.4, tuning.hauteur_pilier, 1.4), Content.palette.pilier)


func _plan_d_une_salle(salle: FloorPlan.Salle) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.salles.append(salle)
	return plan


func _pose_les_autels() -> void:
	var total: int = Content.ecoles.size()
	for i: int in total:
		# En arc plutôt qu'en cercle complet : on doit pouvoir tous les voir
		# depuis l'entrée, sans en avoir un dans le dos.
		var angle: float = PI * (0.15 + 0.7 * (float(i) / float(maxi(total - 1, 1))))
		var pos := Vector3(cos(angle), 0, -sin(angle)) * RAYON_AUTELS
		var autel := SchoolAltar.cree(Content.ecoles[i], pos, _fx)
		add_child(autel)
		_autels.append(autel)

	_portail = Portal.cree(Vector3(0, 0, -COTE_SALLE * 0.38))
	add_child(_portail)


func _construit_le_hud() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	_hud = HubHud.new()
	couche.add_child(_hud)


func _synchronise() -> void:
	var miennes: Array = GameState.ecoles_de(GameState.local_player_id)
	for autel: SchoolAltar in _autels:
		autel.debloquee = Meta.est_debloquee(autel.ecole.id)
		autel.choisie = miennes.has(autel.ecole.id)
		# Voir ce que prennent les autres est la moitié de l'intérêt d'une
		# préparation à plusieurs : sans ça, on découvre la répartition en plein
		# combat, quand il est trop tard pour en changer.
		autel.montre_les_porteurs(GameState.porteurs_de(autel.ecole.id))
	_hud.rafraichit(miennes.size())


func _maj_interaction() -> void:
	_cible = null
	var meilleure: float = PORTEE_INTERACTION
	for autel: SchoolAltar in _autels:
		var d: float = _joueur.global_position.distance_to(autel.global_position)
		if d < meilleure:
			meilleure = d
			_cible = autel

	_portail_a_portee = _joueur.global_position.distance_to(
		_portail.global_position) < PORTEE_INTERACTION and _cible == null

	if _portail_a_portee:
		var manquantes: int = PlayerState.SLOT_COUNT \
			- GameState.ecoles_de(GameState.local_player_id).size()
		if manquantes > 0:
			_hud.invite("Il te manque %d école(s) pour descendre" % manquantes)
		elif Net.est_host():
			_hud.invite("[E] Descendre — tout le monde part avec toi")
		else:
			_hud.invite("[E] Demander à l'hôte de lancer la descente")
	elif _cible != null:
		_hud.invite(_cible.libelle(Meta.cout_deblocage()))
	else:
		_hud.invite("")


func _interagit() -> void:
	if _portail_a_portee:
		if GameState.ecoles_de(GameState.local_player_id).size() < PlayerState.SLOT_COUNT:
			Audio.joue(&"refus")
			return
		# On demande, on ne part pas : le changement de scène viendra de
		# l'ordre de l'hôte, pour tout le monde en même temps.
		Repl.demande_le_depart()
		if not Net.est_host():
			_hud.journalise("Demande envoyée. L'hôte lance quand l'équipe est prête.")
		return

	if _cible == null:
		return

	if not _cible.debloquee:
		if Meta.tente_deblocage(_cible.ecole.id):
			Audio.joue(&"victoire")
		else:
			Audio.joue(&"refus")
			_hud.journalise("Éclats insuffisants — il en faut %d." % Meta.cout_deblocage())
		_synchronise()
		return

	_bascule_l_ecole(_cible.ecole.id)


func _bascule_l_ecole(id: StringName) -> void:
	var moi: int = GameState.local_player_id
	match GameState.bascule_ecole(moi, id):
		GameState.Bascule.RETIREE:
			Audio.joue(&"sceau_tient")
		GameState.Bascule.PRISE:
			Audio.joue(&"achat")
		GameState.Bascule.REFUSEE:
			Audio.joue(&"refus")
			_hud.journalise("Tes quatre écoles sont prises — retires-en une d'abord.")
			return
	# Deux joueurs PEUVENT prendre la même école : rien ne l'interdit, et s'en
	# rendre compte au hub fait partie de la discussion. C'est ce que les
	# marques sur les autels servent à montrer.
	Repl.annonce_ecoles(moi, GameState.ecoles_de(moi))
	_synchronise()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.LIBERER_CURSEUR):
		return
	var touche := event as InputEventKey
	if touche != null and touche.pressed and touche.physical_keycode == KEY_BACKSPACE:
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_MENU)
