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

signal a_lance(slot_index: int, direction: Vector3)

var player_id: int = 0
var tete: Node3D
var camera: Camera3D

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

	var taux: float = ACCELERATION if entree.length_squared() > 0.01 else FREINAGE
	velocity.x = move_toward(velocity.x, voulu.x, taux * delta)
	velocity.z = move_toward(velocity.z, voulu.z, taux * delta)
	velocity.y = 0.0
	move_and_slide()

	_ecoute_les_sorts()


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


func demarre_cooldown(slot_index: int, duree: float) -> void:
	if slot_index >= 0 and slot_index < _cooldowns.size():
		_cooldowns[slot_index] = duree


func cooldown_restant(slot_index: int) -> float:
	return _cooldowns[slot_index] if slot_index < _cooldowns.size() else 0.0
