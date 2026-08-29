class_name PlayerAvatar
extends CharacterBody3D
## Le corps du joueur dans le prototype, en vue à la PREMIÈRE PERSONNE.
## JETABLE — remplacé en C3.
##
## Il affiche et il déplace. Il ne détient AUCUN point de vie ni aucune donnée
## de sort : tout ça vit dans GameState (R1). Il ne fait que soumettre des
## intentions à l'EffectResolver (R4).
##
## ── Les valeurs de feel sont toutes ici, en haut. C'est fait pour être trituré.

const VITESSE: float = 7.0
## Plus c'est haut, plus le personnage démarre sec. Bas = patinage.
const ACCELERATION: float = 55.0
const FREINAGE: float = 42.0
## Sensibilité de la souris, en radians par pixel.
const SENSIBILITE: float = 0.0022
## Au-delà, on se casse la nuque. En radians.
const PITCH_MAX: float = 1.45
## Hauteur des yeux, mesurée depuis le centre de la capsule.
const HAUTEUR_YEUX: float = 0.65
const GRAVITE: float = 26.0
const IMPULSION_SAUT: float = 8.4

signal a_lance(slot_index: int, direction: Vector3)

var player_id: int = 0
var tete: Node3D
var camera: Camera3D

## Charge en cours (Ruée). Direction et temps restant.
var _dash: Vector3 = Vector3.ZERO
var _dash_restant: float = 0.0
## Tant que c'est > 0, les monstres ont perdu notre trace (Voile).
var _voile_restant: float = 0.0

## Cooldown restant par slot, en secondes.
var _cooldowns: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


func _ready() -> void:
	tete = Node3D.new()
	tete.name = "Tete"
	tete.position = Vector3(0, HAUTEUR_YEUX, 0)
	add_child(tete)

	camera = Camera3D.new()
	camera.fov = 78.0
	camera.current = true
	tete.add_child(camera)

	# Sans accrochage au sol, on décolle en haut d'une rampe et on redescend en
	# sautillant. 50° laisse de la marge au-dessus de la pente de 22° des rampes.
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)

	capture_souris(true)


## La souris est capturée pour viser. Échap la relâche, ce qui permet de
## cliquer les boutons du HUD — et de reprendre la main sans tuer le jeu.
func capture_souris(actif: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if actif else Input.MOUSE_MODE_VISIBLE


func souris_capturee() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and souris_capturee():
		var mouvement := event as InputEventMouseMotion
		# Le lacet tourne le corps entier : c'est lui qui définit l'avant.
		rotate_y(-mouvement.relative.x * SENSIBILITE)
		# Le tangage ne bouge que la tête, sinon le personnage bascule.
		tete.rotation.x = clampf(
			tete.rotation.x - mouvement.relative.y * SENSIBILITE, -PITCH_MAX, PITCH_MAX
		)

	if event.is_action_pressed("proto_liberer_souris"):
		capture_souris(not souris_capturee())

	# Un clic dans la fenêtre reprend la visée après un passage par le HUD.
	if event is InputEventMouseButton and not souris_capturee():
		var clic := event as InputEventMouseButton
		if clic.pressed and clic.button_index == MOUSE_BUTTON_RIGHT:
			capture_souris(true)


func _physics_process(delta: float) -> void:
	for i: int in _cooldowns.size():
		_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)

	var entree := Input.get_vector(
		"proto_gauche", "proto_droite", "proto_haut", "proto_bas"
	)
	# Déplacement relatif au regard : avancer, c'est aller où l'on regarde.
	var voulu: Vector3 = (transform.basis * Vector3(entree.x, 0.0, entree.y)) * VITESSE

	_voile_restant = maxf(0.0, _voile_restant - delta)

	var vitesse_verticale: float = velocity.y

	if _dash_restant > 0.0:
		# Pendant la charge, le contrôle horizontal est confisqué : c'est ce qui
		# fait qu'une Ruée se sent comme une Ruée et pas comme un sprint.
		_dash_restant -= delta
		velocity.x = _dash.x
		velocity.z = _dash.z
	else:
		var taux: float = ACCELERATION if entree.length_squared() > 0.01 else FREINAGE
		velocity.x = move_toward(velocity.x, voulu.x, taux * delta)
		velocity.z = move_toward(velocity.z, voulu.z, taux * delta)

	if is_on_floor():
		vitesse_verticale = 0.0
		if Input.is_action_just_pressed("proto_saut") and souris_capturee():
			vitesse_verticale = IMPULSION_SAUT
	else:
		vitesse_verticale -= GRAVITE * delta

	velocity.y = vitesse_verticale
	move_and_slide()
	_bouscule_les_objets()

	_ecoute_les_sorts()


## Un CharacterBody3D ne pousse pas les corps rigides tout seul : il faut lui
## dire. Sans ça, on traverse les caisses comme si elles étaient peintes au sol.
func _bouscule_les_objets() -> void:
	for i: int in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var corps := collision.get_collider() as RigidBody3D
		if corps != null:
			corps.apply_central_impulse(-collision.get_normal() * 4.0)


func _ecoute_les_sorts() -> void:
	if not souris_capturee():
		return
	# Maj et Ctrl sont réservés au changement d'école et au verrouillage :
	# sans ce garde, appuyer sur Maj+1 lancerait AUSSI le sort du slot 1.
	var modificateur: bool = Input.is_key_pressed(KEY_SHIFT) \
		or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	if modificateur:
		return

	for i: int in 4:
		if Input.is_action_just_pressed("proto_sort_%d" % (i + 1)) and _cooldowns[i] <= 0.0:
			a_lance.emit(i, direction_visee())
	# Le clic gauche lance aussi le slot 1 : c'est le réflexe naturel en FPS.
	if Input.is_action_just_pressed("proto_tir") and _cooldowns[0] <= 0.0:
		a_lance.emit(0, direction_visee())


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
	var espace := get_world_3d().direct_space_state
	var requete := PhysicsRayQueryParameters3D.create(depart, depart + direction * portee)
	requete.exclude = [get_rid()]
	var touche: Dictionary = espace.intersect_ray(requete)

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


func demarre_cooldown(slot_index: int, duree: float) -> void:
	if slot_index >= 0 and slot_index < _cooldowns.size():
		_cooldowns[slot_index] = duree


func cooldown_restant(slot_index: int) -> float:
	return _cooldowns[slot_index] if slot_index < _cooldowns.size() else 0.0
