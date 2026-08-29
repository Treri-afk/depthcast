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

## Ressort de la culbute. Sa RAIDEUR change selon qu'on vole ou qu'on tient
## debout, et c'est ce qui fait toute la lecture : en l'air le ressort est mou,
## la vue dérive et tangue comme un corps qui ne se tient plus ; au sol il se
## raidit d'un coup et redresse l'horizon. Un ressort unique donnerait soit une
## caméra rigide en vol, soit un horizon qui flotte une fois debout.
const CULBUTE_RAIDEUR_VOL: float = 3.2
const CULBUTE_RAIDEUR_SOL: float = 26.0
const CULBUTE_AMORTI: float = 4.5
## Au-delà, on aurait la tête à l'envers. En radians.
const CULBUTE_MAX: float = 0.95

## Accrochage au sol en marche normale. Coupé pendant une projection : sinon un
## souffle rasant vous recolle au sol au lieu de vous faire décoller, et vous ne
## quittez jamais le bord d'une estrade.
const SNAP_SOL: float = 0.5
## Si l'on n'a toujours pas décollé après ce délai, c'est qu'on ne décollera
## pas — souffle rasant, plafond bas, corps coincé dans un angle. On considère
## alors la projection terminée plutôt que d'attendre un envol qui ne vient pas.
const DELAI_DECOLLAGE: float = 0.25

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
## Projection par un souffle. On y reste TANT QU'ON N'A PAS RETOUCHÉ LE SOL :
## c'est la seule règle qui fasse dépendre la durée du ragdoll de la violence de
## l'explosion, sans avoir à la calculer — une grosse explosion envoie plus
## haut, donc plus longtemps.
var _projete: bool = false
var _temps_projete: float = 0.0
## Temps à passer à terre une fois retombé. Calculé au lancement, consommé
## après l'impact : c'est là que la violence de l'explosion se paie.
var _releve_du: float = 0.0
## Vrai dès qu'on a effectivement quitté le sol. Sans ce témoin, un souffle
## rasant terminerait la projection à la frame suivante.
var _a_quitte_le_sol: bool = false
## Relevé après l'impact : on est au sol, on ne conduit pas encore.
var _releve_restant: float = 0.0
## Vitesse verticale de la frame précédente, relevée AVANT move_and_slide.
## Après, la collision l'a déjà remise à zéro : lue là, la violence d'un impact
## vaut toujours zéro et la réception ne se voit ni ne s'entend.
var _vitesse_avant_choc: float = 0.0
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

	# Ressort amorti : la vue part, dépasse, puis se recale. Un retour linéaire
	# ferait une caméra qui glisse ; un ressort fait un corps.
	# Mou tant qu'on n'a pas repris la main — le relevé compris : à terre on est
	# sonné, et l'horizon met un moment à redevenir horizontal.
	var raideur: float = CULBUTE_RAIDEUR_VOL if est_projete() else CULBUTE_RAIDEUR_SOL
	_culbute_vitesse -= (_culbute * raideur
		+ _culbute_vitesse * CULBUTE_AMORTI) * delta
	_culbute += _culbute_vitesse * delta
	_culbute.x = clampf(_culbute.x, -CULBUTE_MAX, CULBUTE_MAX)
	_culbute.y = clampf(_culbute.y, -CULBUTE_MAX, CULBUTE_MAX)
	_secousse.rotation = Vector3(_culbute.y, 0.0, _culbute.x)


func _physics_process(delta: float) -> void:
	for i: int in _cooldowns.size():
		_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
	_voile_restant = maxf(0.0, _voile_restant - delta)
	_releve_restant = maxf(0.0, _releve_restant - delta)

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
	if _projete:
		_suit_la_projection(delta, au_sol)
	_etait_au_sol = au_sol

	if _projete or _releve_restant > 0.0:
		# Contrôle confisqué : on ne conduit plus, on subit. C'est exactement ce
		# qu'un ragdoll donne à ressentir, et la seule partie qui se transpose
		# en vue subjective — un squelette qui s'affale, on ne le verrait pas.
		#
		# En vol le freinage est quasi nul : un corps projeté garde sa
		# trajectoire. Au relevé il redevient franc, on se remet debout.
		var frein: float = (_tuning.projection_amortissement if _projete
			else _tuning.freinage_joueur) * delta
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

	if _projete:
		# Le sol ne reprend pas la main tant qu'on est projeté : sinon
		# l'impulsion verticale serait annulée dès la première frame, alors
		# qu'on touche encore le sol d'où l'on décolle.
		vitesse_verticale -= _tuning.gravite * delta
	elif au_sol:
		vitesse_verticale = 0.0
		if _releve_restant <= 0.0 \
				and Input.is_action_just_pressed(InputActions.SAUTER) \
				and MouseLook.est_capture():
			vitesse_verticale = _tuning.impulsion_saut
	else:
		vitesse_verticale -= _tuning.gravite * delta

	velocity.y = vitesse_verticale
	_vitesse_avant_choc = vitesse_verticale
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
	# Projeté, on perd la main. C'est ce qui donne son poids à une explosion :
	# sans ça on est déplacé mais on continue de jouer, et le ragdoll n'est plus
	# qu'un effet de caméra. Réglage assumé, désactivable dans le Tuning.
	if _tuning.projection_bloque_les_sorts and est_projete():
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


## Projeté par un souffle. Le corps part, la vue se relâche, et le contrôle
## n'est rendu qu'après être retombé — puis être resté à terre un moment.
##
## DEUX PHASES, et c'est la clé du ressenti.
##
## Le VOL dure exactement tant qu'on n'a pas retouché le sol. Aucun minuteur :
## un minuteur fixe donne la même secousse qu'on ait été déplacé de deux mètres
## ou envoyé par-dessus une estrade. En attendant l'atterrissage, la durée
## découle de la trajectoire — donc de l'explosion — sans calcul nulle part.
##
## Le RELEVÉ, lui, est proportionnel à la violence reçue. C'est la moitié qui
## fait « plusieurs secondes » : après un gros souffle on ne se remet pas debout
## comme après une bourrade.
##
## Cumulatif à dessein : deux explosions coup sur coup projettent plus loin
## qu'une seule.
func projete(impulsion: Vector3, origine: Vector3 = Vector3.ZERO) -> void:
	if _tuning == null or impulsion.length_squared() < 0.01:
		return

	var lancee: Vector3 = velocity + impulsion
	if lancee.length() > _tuning.projection_vitesse_max:
		lancee = lancee.normalized() * _tuning.projection_vitesse_max
	# La verticale seule est bornée : on part loin, pas haut. Un souffle qui
	# envoie à vingt mètres sort d'une salle qui en fait cinq et demi.
	lancee.y = minf(lancee.y, vitesse_pour_culminer_a(_tuning.projection_hauteur_max,
		_tuning.gravite))
	velocity = lancee

	# L'accrochage au sol est coupé le temps du vol : sinon un souffle rasant
	# vous recolle au sol au lieu de vous faire décoller.
	floor_snap_length = 0.0
	_projete = true
	_temps_projete = 0.0
	_a_quitte_le_sol = false
	_releve_restant = 0.0
	_releve_du = maxf(_releve_du, duree_de_releve(impulsion.length(), _tuning))

	_arme_la_culbute(impulsion)
	EventBus.player_blasted.emit(player_id, impulsion.length(), origine)


## Vitesse verticale nécessaire pour culminer à une hauteur donnée.
## Fonctions pures et à part : vérifiables sans moteur.
static func vitesse_pour_culminer_a(hauteur: float, gravite: float) -> float:
	return sqrt(2.0 * maxf(gravite, 0.001) * maxf(hauteur, 0.0))


## Temps passé à terre après l'impact, pour une vitesse reçue donnée.
static func duree_de_releve(vitesse: float, tuning: Tuning) -> float:
	return clampf(vitesse * tuning.projection_releve_par_vitesse,
		tuning.projection_releve_min, tuning.projection_releve_max)


## Tant que c'est vrai, le joueur subit une projection et ne se dirige plus.
## Le relevé en fait partie : on est retombé, on n'est pas encore reparti.
func est_projete() -> bool:
	return _projete or _releve_restant > 0.0


func _suit_la_projection(delta: float, au_sol: bool) -> void:
	_temps_projete += delta
	if not au_sol:
		_a_quitte_le_sol = true
	if _fin_du_vol(au_sol):
		_atterrit()


func _fin_du_vol(au_sol: bool) -> bool:
	# Garde-fou : une chute qui n'en finit pas — trou dans le décor, corps
	# coincé — ne doit jamais confisquer le contrôle indéfiniment.
	if _temps_projete >= _tuning.projection_duree_max:
		return true
	if not au_sol:
		return false
	# Si l'on n'a toujours pas décollé passé le délai, c'est qu'on ne décollera
	# pas : souffle rasant, plafond bas, angle de mur.
	return _a_quitte_le_sol or _temps_projete >= DELAI_DECOLLAGE


## L'impact. C'est le moment qui vend le ragdoll : sans lui la projection se
## termine en flottant, on retouche le sol et il ne se passe rien.
func _atterrit() -> void:
	var choc: float = absf(_vitesse_avant_choc)
	_projete = false
	_temps_projete = 0.0
	_a_quitte_le_sol = false
	_releve_restant = _releve_du
	_releve_du = 0.0
	floor_snap_length = SNAP_SOL

	# La secousse de réception suit la vitesse de chute : on ne s'écrase pas de
	# la même façon d'un mètre et de dix.
	_culbute_vitesse.y += minf(choc * 0.14, 4.0)
	_culbute_vitesse = _culbute_vitesse.limit_length(9.0)
	EventBus.player_slammed.emit(player_id, choc)


## La vue part dans le sens du souffle : projeté vers la droite, l'horizon
## bascule ; projeté vers l'arrière, on voit le plafond arriver. C'est le seul
## endroit où une projection est VISIBLE en vue subjective.
func _arme_la_culbute(impulsion: Vector3) -> void:
	var locale: Vector3 = global_transform.basis.inverse() * impulsion
	var ampleur: float = _tuning.projection_culbute * 0.055
	_culbute_vitesse += Vector2(-locale.x, locale.z) * ampleur
	_culbute_vitesse = _culbute_vitesse.limit_length(9.0)


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
