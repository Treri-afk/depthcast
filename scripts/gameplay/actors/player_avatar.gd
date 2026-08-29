class_name PlayerAvatar
extends CharacterBody3D
## Le corps du joueur, en vue à la première personne.
##
## Il affiche et il déplace. Il ne détient AUCUN point de vie ni aucune donnée
## de sort : tout ça vit dans GameState (R1). Il signale ce que le joueur veut
## lancer ; c'est le SpellCaster qui décide de ce que ça produit.
##
## Les valeurs de ressenti viennent de la table de tuning, éditable dans
## l'inspecteur : c'est du calibrage, pas du code.

## Hauteur des yeux, mesurée depuis le centre de la capsule.
const HAUTEUR_YEUX: float = 0.65

signal a_lance(slot_index: int, direction: Vector3)

var player_id: int = 0
var tete: Node3D
var camera: Camera3D

var _tuning: Tuning
var _regard: MouseLook
var _trainee: TrailEmitter

## Cooldown restant par slot, en secondes.
var _cooldowns: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
## Charge en cours (Ruée) : direction et temps restant.
var _dash: Vector3 = Vector3.ZERO
var _dash_restant: float = 0.0
## Tant que c'est > 0, les monstres ont perdu notre trace (Voile).
var _voile_restant: float = 0.0


func _ready() -> void:
	_tuning = Content.tuning
	_trainee = TrailEmitter.new()

	tete = Node3D.new()
	tete.name = "Tete"
	tete.position = Vector3(0, HAUTEUR_YEUX, 0)
	add_child(tete)

	camera = Camera3D.new()
	camera.fov = 78.0
	camera.current = true
	tete.add_child(camera)

	_regard = MouseLook.new(self, tete, _tuning.sensibilite_souris)

	# Sans accrochage au sol, on décolle en haut d'une rampe et on redescend en
	# sautillant. 50° laisse de la marge au-dessus de la pente de 22° des rampes.
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	MouseLook.capture(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and MouseLook.est_capture():
		_regard.applique(event as InputEventMouseMotion)

	if event.is_action_pressed(InputActions.LIBERER_CURSEUR):
		MouseLook.capture(not MouseLook.est_capture())

	# Un clic droit reprend la visée après un passage par l'interface.
	if event is InputEventMouseButton and not MouseLook.est_capture():
		var clic := event as InputEventMouseButton
		if clic.pressed and clic.button_index == MOUSE_BUTTON_RIGHT:
			MouseLook.capture(true)


func _physics_process(delta: float) -> void:
	for i: int in _cooldowns.size():
		_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
	_voile_restant = maxf(0.0, _voile_restant - delta)

	_deplace(delta)
	_ecoute_les_sorts()


func _deplace(delta: float) -> void:
	var entree := Input.get_vector(InputActions.GAUCHE, InputActions.DROITE,
		InputActions.AVANT, InputActions.ARRIERE)
	# Déplacement relatif au regard : avancer, c'est aller où l'on regarde.
	var voulu: Vector3 = (transform.basis * Vector3(entree.x, 0.0, entree.y)) \
		* _tuning.vitesse_joueur
	var vitesse_verticale: float = velocity.y

	if _dash_restant > 0.0:
		# Pendant la charge, le contrôle horizontal est confisqué : c'est ce qui
		# fait qu'une Ruée se sent comme une Ruée et pas comme un sprint.
		_dash_restant -= delta
		velocity.x = _dash.x
		velocity.z = _dash.z
	else:
		var taux: float = _tuning.acceleration_joueur \
			if entree.length_squared() > 0.01 else _tuning.freinage_joueur
		velocity.x = move_toward(velocity.x, voulu.x, taux * delta)
		velocity.z = move_toward(velocity.z, voulu.z, taux * delta)

	if is_on_floor():
		vitesse_verticale = 0.0
		if Input.is_action_just_pressed(InputActions.SAUTER) and MouseLook.est_capture():
			vitesse_verticale = _tuning.impulsion_saut
	else:
		vitesse_verticale -= _tuning.gravite * delta

	velocity.y = vitesse_verticale
	move_and_slide()
	_bouscule_les_objets()


## Un CharacterBody3D ne pousse pas les corps rigides tout seul : il faut lui
## dire. Sans ça, on traverse les caisses comme si elles étaient peintes au sol.
func _bouscule_les_objets() -> void:
	for i: int in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var corps := collision.get_collider() as RigidBody3D
		if corps != null:
			corps.apply_central_impulse(-collision.get_normal() * 4.0)


func _ecoute_les_sorts() -> void:
	if not MouseLook.est_capture():
		return
	# Maj et Ctrl sont réservés aux raccourcis d'interface : sans ce garde,
	# Maj+1 lancerait aussi le sort du slot 1.
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL) \
			or Input.is_key_pressed(KEY_META):
		return

	for i: int in PlayerState.SLOT_COUNT:
		if Input.is_action_just_pressed(InputActions.sort(i)) and _cooldowns[i] <= 0.0:
			a_lance.emit(i, direction_visee())
	# Le clic gauche lance aussi le slot 1 : c'est le réflexe naturel en FPS.
	if Input.is_action_just_pressed(InputActions.TIRER) and _cooldowns[0] <= 0.0:
		a_lance.emit(0, direction_visee())


# ── Ce que les sorts pilotent ─────────────────────────────────────────────

## Là où pointe la caméra, tangage compris.
func direction_visee() -> Vector3:
	return -camera.global_transform.basis.z.normalized()


func position_yeux() -> Vector3:
	return camera.global_position


## Point visé, projeté sur le décor. Sert à l'aperçu de téléportation : on veut
## savoir OÙ l'on atterrira avant d'appuyer, pas après.
func point_vise(portee: float) -> Vector3:
	var depart: Vector3 = position_yeux()
	var direction: Vector3 = direction_visee()
	var requete := PhysicsRayQueryParameters3D.create(depart, depart + direction * portee)
	requete.exclude = [get_rid()]
	var touche: Dictionary = get_world_3d().direct_space_state.intersect_ray(requete)

	var but: Vector3 = touche["position"] if touche.has("position") \
		else depart + direction * portee
	# On atterrit au sol, jamais dans un mur ni en l'air.
	but -= direction * 0.9
	but.y = global_position.y
	return but


func teleporte(vers: Vector3) -> void:
	global_position = vers + Vector3(0, 0.2, 0)
	velocity = Vector3.ZERO


func charge(direction: Vector3, distance: float, duree: float = 0.18) -> void:
	_dash = direction.normalized() * (distance / maxf(duree, 0.01))
	_dash.y = 0.0
	_dash_restant = duree


func voile(duree: float) -> void:
	_voile_restant = duree


func est_voile() -> bool:
	return _voile_restant > 0.0


func arme_trainee(effet: SpellEffect, couleur: Color, slot_index: int) -> void:
	_trainee.arme(effet, couleur, slot_index)


func consomme_flaque(delta: float) -> Dictionary:
	return _trainee.consomme(delta, global_position)


func souris_capturee() -> bool:
	return MouseLook.est_capture()


func demarre_cooldown(slot_index: int, duree: float) -> void:
	if slot_index >= 0 and slot_index < _cooldowns.size():
		_cooldowns[slot_index] = duree


func cooldown_restant(slot_index: int) -> float:
	return _cooldowns[slot_index] if slot_index < _cooldowns.size() else 0.0
