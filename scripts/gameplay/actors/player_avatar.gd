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

## Ressort de la culbute : raideur et amortissement. Ces deux nombres seuls
## décident si une projection se sent comme un corps ou comme une caméra qui
## glisse — d'où le ressort plutôt qu'un retour linéaire.
const CULBUTE_RAIDEUR: float = 26.0
const CULBUTE_AMORTI: float = 7.5
## Au-delà, on aurait la tête à l'envers. En radians.
const CULBUTE_MAX: float = 0.7

signal a_lance(slot_index: int, direction: Vector3)

var player_id: int = 0
var tete: Node3D
var camera: Camera3D

var _tuning: Tuning
var _regard: MouseLook
var _trainee: TrailEmitter
## Porte la culbute de la vue. Nœud distinct de `tete` pour que la projection
## et le regard à la souris se composent au lieu de se disputer la rotation.
var _secousse: Node3D

## Cooldown restant par slot, en secondes.
var _cooldowns: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
## Charge en cours (Ruée) : direction et temps restant.
var _dash: Vector3 = Vector3.ZERO
var _dash_restant: float = 0.0
## Tant que c'est > 0, les monstres ont perdu notre trace (Voile).
var _voile_restant: float = 0.0
## Projection par un souffle : temps de contrôle confisqué restant.
var _projection_restant: float = 0.0
## Culbute de la vue — x roulis, y tangage — et sa vitesse angulaire.
var _culbute: Vector2 = Vector2.ZERO
var _culbute_vitesse: Vector2 = Vector2.ZERO
var _etait_au_sol: bool = true


func _ready() -> void:
	_tuning = Content.tuning
	_trainee = TrailEmitter.new()

	tete = Node3D.new()
	tete.name = "Tete"
	tete.position = Vector3(0, HAUTEUR_YEUX, 0)
	add_child(tete)

	_secousse = Node3D.new()
	_secousse.name = "Secousse"
	tete.add_child(_secousse)

	camera = Camera3D.new()
	camera.fov = 78.0
	camera.current = true
	_secousse.add_child(camera)

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


## La culbute vit dans _process et non dans la physique : c'est du regard, et
## le regard se met à jour à chaque image affichée, pas à chaque tick physique.
func _process(delta: float) -> void:
	if _secousse == null:
		return
	if _culbute.is_zero_approx() and _culbute_vitesse.is_zero_approx():
		return

	# Ressort amorti : la vue part, dépasse une fois, puis se recale. Un retour
	# linéaire ferait une caméra qui glisse ; un ressort fait un corps.
	_culbute_vitesse -= (_culbute * CULBUTE_RAIDEUR
		+ _culbute_vitesse * CULBUTE_AMORTI) * delta
	_culbute += _culbute_vitesse * delta
	_culbute.x = clampf(_culbute.x, -CULBUTE_MAX, CULBUTE_MAX)
	_culbute.y = clampf(_culbute.y, -CULBUTE_MAX, CULBUTE_MAX)
	_secousse.rotation = Vector3(_culbute.y, 0.0, _culbute.x)


func _physics_process(delta: float) -> void:
	for i: int in _cooldowns.size():
		_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
	_voile_restant = maxf(0.0, _voile_restant - delta)
	_projection_restant = maxf(0.0, _projection_restant - delta)

	_deplace(delta)
	_ecoute_les_sorts()


func _deplace(delta: float) -> void:
	var entree := Input.get_vector(InputActions.GAUCHE, InputActions.DROITE,
		InputActions.AVANT, InputActions.ARRIERE)
	# Déplacement relatif au regard : avancer, c'est aller où l'on regarde.
	var voulu: Vector3 = (transform.basis * Vector3(entree.x, 0.0, entree.y)) \
		* _tuning.vitesse_joueur
	var vitesse_verticale: float = velocity.y

	var au_sol: bool = is_on_floor()
	if au_sol and not _etait_au_sol and _projection_restant > 0.0:
		_encaisse_l_atterrissage()
	_etait_au_sol = au_sol

	if _projection_restant > 0.0:
		# Contrôle confisqué : on ne conduit plus, on subit. C'est exactement ce
		# qu'un ragdoll donne à ressentir, et la seule partie qui se transpose
		# en vue subjective — un squelette qui s'affale, on ne le verrait pas.
		var frein: float = _tuning.projection_amortissement * delta
		velocity.x = move_toward(velocity.x, 0.0, frein)
		velocity.z = move_toward(velocity.z, 0.0, frein)
	elif _dash_restant > 0.0:
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

	if _projection_restant > 0.0:
		# Le sol ne reprend pas la main tant qu'on est projeté : sinon
		# l'impulsion verticale serait annulée dès la première frame, alors
		# qu'on touche encore le sol d'où l'on décolle.
		vitesse_verticale -= _tuning.gravite * delta
	elif au_sol:
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


## Projeté par un souffle. Le corps part, la vue culbute, le contrôle est rendu
## une demi-seconde plus tard.
##
## Cumulatif à dessein : deux explosions coup sur coup projettent plus loin
## qu'une seule. Le plafond de vitesse empêche que ça sorte de la salle.
func projete(impulsion: Vector3, origine: Vector3 = Vector3.ZERO) -> void:
	if _tuning == null or impulsion.length_squared() < 0.01:
		return

	var lancee: Vector3 = velocity + impulsion
	if lancee.length() > _tuning.projection_vitesse_max:
		lancee = lancee.normalized() * _tuning.projection_vitesse_max
	velocity = lancee

	_projection_restant = maxf(_projection_restant, _tuning.projection_controle_perdu)
	_arme_la_culbute(impulsion)
	EventBus.player_blasted.emit(player_id, impulsion.length(), origine)


## Tant que c'est vrai, le joueur subit une projection et ne se dirige plus.
func est_projete() -> bool:
	return _projection_restant > 0.0


## La vue part dans le sens du souffle : projeté vers la droite, l'horizon
## bascule ; projeté vers l'arrière, on voit le plafond arriver. C'est le seul
## endroit où une projection est VISIBLE en vue subjective.
func _arme_la_culbute(impulsion: Vector3) -> void:
	var locale: Vector3 = global_transform.basis.inverse() * impulsion
	var ampleur: float = _tuning.projection_culbute * 0.055
	_culbute_vitesse += Vector2(-locale.x, locale.z) * ampleur
	_culbute_vitesse = _culbute_vitesse.limit_length(6.0)


## Le choc de la réception. Sans lui, une projection se termine en flottant :
## on retouche le sol et il ne se passe rien.
func _encaisse_l_atterrissage() -> void:
	_culbute_vitesse.y += 1.8
	_projection_restant = minf(_projection_restant, 0.12)


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
