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
## Les mains ont changé. `prend` distingue ramasser de lâcher ; l'élan ne vaut
## que pour un lancer. Émis seulement par l'avatar local : c'est une intention
## de joueur, pas une conséquence.
signal portage_change(corps: PropDestructible, elan: Vector3, prend: bool)

var player_id: int = 0
## Ce client contrôle-t-il cet avatar ?
##
## Un avatar distant a le même corps, la même physique et les mêmes réactions
## aux souffles — il ne lit simplement aucune entrée et ne porte pas la caméra
## active. C'est ce qui permet de tout écrire une seule fois : le jour où le
## réseau pilote un avatar distant, il n'y a rien de particulier à prévoir.
var local: bool = true
var tete: Node3D
var camera: Camera3D

var _tuning: Tuning
var _regard: MouseLook
var _trainee: TrailEmitter
## Porte la culbute de la vue. Nœud distinct de `tete` pour que la projection
## et le regard à la souris se composent au lieu de se disputer la rotation.
var _secousse: Node3D
## Le point où l'on tient ce qu'on porte. Sous le nœud de secousse, donc ce
## qu'on transporte culbute avec la vue quand on est projeté.
var _mains: Node3D
## L'objet dans les mains, ou null.
var _porte: PropDestructible = null
## Ses couches de collision d'origine, à rendre au moment de le lâcher.
var _couches_portees: Array[int] = [0, 0]

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
## Aide au saut. `_coyote` pardonne le retard — on vient de quitter le sol —
## et `_tampon` pardonne l'avance : un saut demandé juste avant de toucher.
var _coyote: float = 0.0
var _tampon_de_saut: float = 0.0


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
	# Une seule caméra active par écran. Les avatars distants gardent la leur —
	# éteinte — pour que `position_yeux()` et `direction_visee()` fonctionnent
	# sur eux aussi, sans un seul cas particulier ailleurs.
	camera.current = local
	_secousse.add_child(camera)

	_mains = Node3D.new()
	_mains.name = "Mains"
	_mains.position = Vector3(0.5, -0.5, -1.25)
	_secousse.add_child(_mains)

	if local:
		_regard = MouseLook.new(self, tete, _tuning.sensibilite_souris)
	else:
		# Un coéquipier se voit, contrairement à soi-même.
		_montre_le_corps()

	# Encaisser secoue la vue. Le voile rouge dit COMBIEN, la secousse dit QUE —
	# et elle le dit avant qu'on ait eu le temps de lire quoi que ce soit.
	EventBus.player_damaged.connect(func(id: int, degats: int, _o: Vector3) -> void:
		if id == player_id:
			secoue(float(degats) * 0.4))

	# Sans accrochage au sol, on décolle en haut d'une rampe et on redescend en
	# sautillant. 50° laisse de la marge au-dessus de la pente de 22° des rampes.
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	if local:
		MouseLook.capture(true)


## Le corps d'un coéquipier. Une capsule à sa couleur et un repère de regard :
## en co-op, savoir où un allié REGARDE vaut souvent plus que savoir où il est.
func _montre_le_corps() -> void:
	var teinte: Color = Content.palette.couleur_joueur(player_id)

	var corps := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	corps.mesh = capsule
	corps.material_override = MaterialLibrary.aplat(teinte, MaterialLibrary.Role.CREATURE)
	add_child(corps)

	var regard := MeshInstance3D.new()
	var museau := BoxMesh.new()
	museau.size = Vector3(0.34, 0.22, 0.5)
	regard.mesh = museau
	regard.position = Vector3(0, 0, -0.45)
	regard.material_override = MaterialLibrary.lumineux(teinte, 1.4)
	tete.add_child(regard)


func _unhandled_input(event: InputEvent) -> void:
	if not local:
		return
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
	_ecoute_le_portage()
	_suit_l_objet_porte()
	_ecoute_les_sorts()


func _deplace(delta: float) -> void:
	# Un avatar distant garde toute sa physique — gravité, collisions, souffles —
	# mais ne se dirige pas tout seul. Le réseau écrira sa position ; d'ici là
	# il attend, et il se fait quand même catapulter comme les autres.
	var entree := Input.get_vector(InputActions.GAUCHE, InputActions.DROITE,
		InputActions.AVANT, InputActions.ARRIERE) if local else Vector2.ZERO
	# Déplacement relatif au regard : avancer, c'est aller où l'on regarde.
	# Porter coûte de la vitesse. Sans coût, porter serait gratuit et il n'y
	# aurait aucune décision à prendre entre traverser vite et traverser armé.
	var allure: float = _tuning.vitesse_joueur
	if _porte != null:
		allure *= _tuning.portage_ralentissement
	var voulu: Vector3 = (transform.basis * Vector3(entree.x, 0.0, entree.y)) * allure
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

	_maj_les_fenetres_de_saut(delta, au_sol)

	if _projete:
		# Le sol ne reprend pas la main tant qu'on est projeté : sinon
		# l'impulsion verticale serait annulée dès la première frame, alors
		# qu'on touche encore le sol d'où l'on décolle.
		vitesse_verticale -= _tuning.gravite * delta
	else:
		vitesse_verticale = 0.0 if au_sol else vitesse_verticale - _tuning.gravite * delta
		if _peut_sauter(au_sol) and _tampon_de_saut > 0.0:
			vitesse_verticale = _tuning.impulsion_saut
			# Les deux fenêtres se referment ensemble : sans ça, un tampon
			# encore chaud relancerait un saut à la frame suivante.
			_tampon_de_saut = 0.0
			_coyote = 0.0

	velocity.y = vitesse_verticale
	_vitesse_avant_choc = vitesse_verticale
	move_and_slide()
	_bouscule_les_objets()


## Les deux pardons du saut.
##
## Le coyote laisse sauter un instant APRÈS avoir quitté le sol : sans lui,
## sauter en franchissant le bord d'une estrade échoue une fois sur trois, et le
## joueur croit que la commande a été perdue.
##
## Le tampon retient un saut demandé un instant AVANT de toucher : sans lui, on
## atterrit et il ne se passe rien, parce qu'on avait appuyé deux frames trop
## tôt. Personne ne sait nommer ces deux défauts ; tout le monde les sent.
func _maj_les_fenetres_de_saut(delta: float, au_sol: bool) -> void:
	_coyote = _tuning.saut_coyote if au_sol else maxf(0.0, _coyote - delta)
	if local and Input.is_action_just_pressed(InputActions.SAUTER) \
			and MouseLook.est_capture():
		_tampon_de_saut = _tuning.saut_tampon
	else:
		_tampon_de_saut = maxf(0.0, _tampon_de_saut - delta)


func _peut_sauter(au_sol: bool) -> bool:
	return (au_sol or _coyote > 0.0) and _releve_restant <= 0.0


## Un CharacterBody3D ne pousse pas les corps rigides tout seul : il faut lui
## dire. Sans ça, on traverse les caisses comme si elles étaient peintes au sol.
func _bouscule_les_objets() -> void:
	for i: int in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var corps := collision.get_collider() as RigidBody3D
		if corps != null:
			corps.apply_central_impulse(-collision.get_normal() * 4.0)


func _ecoute_les_sorts() -> void:
	if not local or not MouseLook.est_capture():
		return
	# Projeté, on perd la main. C'est ce qui donne son poids à une explosion :
	# sans ça on est déplacé mais on continue de jouer, et le ragdoll n'est plus
	# qu'un effet de caméra. Réglage assumé, désactivable dans le Tuning.
	if _tuning.projection_bloque_les_sorts and est_projete():
		return
	# Les mains pleines, on ne lance pas. C'est ce qui fait de « porter un
	# tonneau amorcé jusqu'au groupe » un pari plutôt qu'un geste gratuit.
	if _tuning.portage_bloque_les_sorts and _porte != null:
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
	lancee.y = minf(lancee.y, Souffle.vitesse_pour_culminer_a(
		_tuning.projection_hauteur_max, _tuning.gravite))
	velocity = lancee

	# L'accrochage au sol est coupé le temps du vol : sinon un souffle rasant
	# vous recolle au sol au lieu de vous faire décoller.
	floor_snap_length = 0.0
	_projete = true
	_temps_projete = 0.0
	_a_quitte_le_sol = false
	_releve_restant = 0.0
	_releve_du = maxf(_releve_du, duree_de_releve(impulsion.length(), _tuning))

	# On lâche ce qu'on tenait : un corps qui part en vrille ne garde pas un
	# tonneau dans les bras, et le voir s'envoler de son côté vaut tous les
	# retours du monde.
	if _porte != null:
		lache(velocity * 0.6 + Vector3.UP * 2.0)

	_arme_la_culbute(impulsion)
	EventBus.player_blasted.emit(player_id, impulsion.length(), origine)


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


## Une secousse de la vue, SANS perte de contrôle.
##
## C'est ce qui reste d'une explosion trop lointaine pour projeter, et d'un coup
## encaissé. Sans elle il existe une distance à laquelle une explosion ne fait
## absolument rien — et c'est exactement là que le joueur cesse de la craindre.
##
## Le sens est tiré au hasard sans passer par RngService : c'est de la caméra,
## pas du jeu. Deux joueurs qui la verraient partir dans des sens opposés
## verraient quand même la même partie.
func secoue(force: float) -> void:
	if _tuning == null or force <= 0.0:
		return
	var ampleur: float = minf(force, 14.0) * 0.05 * _tuning.projection_culbute
	_culbute_vitesse += Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 1.0)) * ampleur
	_culbute_vitesse = _culbute_vitesse.limit_length(9.0)


## Recul de la vue au lancer d'un sort.
##
## Vers le HAUT, et pas au hasard : c'est ce qui distingue un recul d'une
## secousse. L'un a une direction et se compense, l'autre subit.
func recul(force: float) -> void:
	if _tuning == null or force <= 0.0:
		return
	_culbute_vitesse.y += force
	_culbute_vitesse = _culbute_vitesse.limit_length(9.0)


## La vue part dans le sens du souffle : projeté vers la droite, l'horizon
## bascule ; projeté vers l'arrière, on voit le plafond arriver. C'est le seul
## endroit où une projection est VISIBLE en vue subjective.
func _arme_la_culbute(impulsion: Vector3) -> void:
	var locale: Vector3 = global_transform.basis.inverse() * impulsion
	var ampleur: float = _tuning.projection_culbute * 0.055
	_culbute_vitesse += Vector2(-locale.x, locale.z) * ampleur
	_culbute_vitesse = _culbute_vitesse.limit_length(9.0)


# ── Porter, poser, lancer ─────────────────────────────────────────────────

func porte_quelque_chose() -> bool:
	return _porte != null and is_instance_valid(_porte)


## Ce que le HUD affiche. Vide quand il n'y a rien à faire des mains.
func invite_portage() -> String:
	if porte_quelque_chose():
		return "[F] poser   ·   [G] lancer"
	var vise: PropDestructible = objet_a_portee()
	return "[F] ramasser" if vise != null else ""


## L'objet portable le plus proche devant soi.
##
## Une sphère lancée devant les yeux plutôt qu'un rayon : viser au pixel un
## tonneau qui roule serait pénible, et attraper est un geste large.
func objet_a_portee() -> PropDestructible:
	if porte_quelque_chose():
		return null
	var espace: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if espace == null:
		return null

	var centre: Vector3 = position_yeux() + direction_visee() * (_tuning.portage_portee * 0.6)
	var boule := SphereShape3D.new()
	boule.radius = _tuning.portage_portee * 0.6
	var requete := PhysicsShapeQueryParameters3D.new()
	requete.shape = boule
	requete.transform = Transform3D(Basis(), centre)
	requete.exclude = [get_rid()]

	var meilleur: PropDestructible = null
	var meilleure: float = INF
	for resultat: Dictionary in espace.intersect_shape(requete, 16):
		var corps := resultat.get("collider") as PropDestructible
		if corps == null or not is_instance_valid(corps) or not corps.portable:
			continue
		var d: float = corps.global_position.distance_to(centre)
		if d < meilleure:
			meilleure = d
			meilleur = corps
	return meilleur


func _ecoute_le_portage() -> void:
	if not local or not MouseLook.est_capture() or est_projete():
		return

	if Input.is_action_just_pressed(InputActions.PORTER):
		if porte_quelque_chose():
			pose()
		else:
			var vise: PropDestructible = objet_a_portee()
			if vise != null:
				ramasse(vise)

	if Input.is_action_just_pressed(InputActions.LANCER) and porte_quelque_chose():
		lance_l_objet()


## L'objet suit les mains sans être reparenté.
##
## Le reparenter dans l'arbre au milieu d'une frame physique demande des
## précautions à chaque étape ; le déplacer gelé n'en demande aucune, et le
## résultat à l'écran est identique.
func _suit_l_objet_porte() -> void:
	if _porte == null:
		return
	if not is_instance_valid(_porte):
		_porte = null
		return
	_porte.global_transform = _mains.global_transform


func ramasse(corps: PropDestructible) -> void:
	if corps == null or not corps.portable or porte_quelque_chose():
		return
	_porte = corps
	# Gelé en mode cinématique : il se déplace parce qu'on le déplace, et il
	# continue de pousser ce qu'il touche au lieu de le traverser.
	corps.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	corps.freeze = true
	# Sorti des collisions le temps du transport : sinon il pousse son porteur,
	# qui pousse l'objet, et les deux partent en vibration.
	_couches_portees = [corps.collision_layer, corps.collision_mask]
	corps.set_deferred(&"collision_layer", 0)
	corps.set_deferred(&"collision_mask", 0)
	if local:
		portage_change.emit(corps, Vector3.ZERO, true)


## Repose l'objet devant soi, sans force.
func pose() -> void:
	lache(velocity * 0.2)


## L'envoie devant soi. L'impulsion est divisée par la masse : une caisse part
## loin, un tonneau tombe presque à ses pieds. C'est ce qui fait qu'on choisit
## ce qu'on ramasse.
func lance_l_objet() -> void:
	if not porte_quelque_chose():
		return
	var force: float = _tuning.portage_force_de_lancer / maxf(_porte.mass, 0.5)
	var sens: Vector3 = (direction_visee() + Vector3.UP * _tuning.portage_arc).normalized()
	lache(velocity + sens * force)


## Rend l'objet au monde, avec la vitesse voulue.
func lache(elan: Vector3) -> void:
	if not porte_quelque_chose():
		_porte = null
		return
	var corps: PropDestructible = _porte
	_porte = null

	corps.set_deferred(&"collision_layer", _couches_portees[0])
	corps.set_deferred(&"collision_mask", _couches_portees[1])
	corps.freeze = false
	# Une impulsion plutôt qu'une vitesse écrite à la main : le serveur physique
	# l'applique au pas suivant, donc APRÈS le dégel. Écrite directement, la
	# vitesse était en partie avalée par le dégel et le lancer retombait mou.
	corps.linear_velocity = Vector3.ZERO
	corps.apply_central_impulse(elan * corps.mass)
	corps.lache_par_le_joueur(self)
	if local:
		portage_change.emit(corps, elan, false)


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
