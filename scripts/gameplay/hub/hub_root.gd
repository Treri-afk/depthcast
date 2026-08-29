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

var _joueur: PlayerAvatar
var _autels: Array[SchoolAltar] = []
var _portail: Portal
var _fx: FxLibrary
var _hud: HubHud
var _cible: SchoolAltar = null
var _portail_a_portee: bool = false


func _ready() -> void:
	InputActions.declare()
	WorldLighting.installe(self)
	_fx = FxLibrary.new(self)

	_batit_la_salle()
	_construit_le_joueur()
	_pose_les_autels()
	_construit_le_hud()
	_synchronise()

	Meta.eclats_changes.connect(func(_t: int) -> void: _synchronise())


func _physics_process(_delta: float) -> void:
	_maj_interaction()
	if Input.is_action_just_pressed(InputActions.INTERAGIR):
		_interagit()


func _batit_la_salle() -> void:
	var tuning: Tuning = Content.tuning
	var conteneur := Node3D.new()
	add_child(conteneur)

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


func _construit_le_joueur() -> void:
	_joueur = PlayerAvatar.new()
	_joueur.position = Vector3(0, 1.2, COTE_SALLE * 0.32)

	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	forme.shape = capsule
	_joueur.add_child(forme)
	add_child(_joueur)
	_joueur.camera.add_child(PostProcess.cree(Content.palette))


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
	for autel: SchoolAltar in _autels:
		autel.debloquee = Meta.est_debloquee(autel.ecole.id)
		autel.choisie = GameState.ecoles_choisies.has(autel.ecole.id)
	_hud.rafraichit(GameState.ecoles_choisies.size())


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
		var manquantes: int = PlayerState.SLOT_COUNT - GameState.ecoles_choisies.size()
		_hud.invite("[E] Descendre" if manquantes <= 0
			else "Il te manque %d école(s) pour descendre" % manquantes)
	elif _cible != null:
		_hud.invite(_cible.libelle(Meta.cout_deblocage()))
	else:
		_hud.invite("")


func _interagit() -> void:
	if _portail_a_portee:
		if GameState.ecoles_choisies.size() < PlayerState.SLOT_COUNT:
			Audio.joue(&"refus")
			return
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_JEU)
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
	if GameState.ecoles_choisies.has(id):
		GameState.ecoles_choisies.erase(id)
		Audio.joue(&"sceau_tient")
	elif GameState.ecoles_choisies.size() < PlayerState.SLOT_COUNT:
		GameState.ecoles_choisies.append(id)
		Audio.joue(&"achat")
	else:
		Audio.joue(&"refus")
		_hud.journalise("Ton équipe est complète — retire une école d'abord.")
	_synchronise()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.LIBERER_CURSEUR):
		return
	var touche := event as InputEventKey
	if touche != null and touche.pressed and touche.physical_keycode == KEY_BACKSPACE:
		get_tree().change_scene_to_file(ScreenUtils.CHEMIN_MENU)
