class_name MonsterAvatar
extends CharacterBody3D
## Le corps d'un monstre : il se déplace, il encaisse visuellement, il bouscule.
##
## Il ne décide de rien — c'est MonsterBrain qui choisit. Il ne calcule aucun
## dégât non plus : il soumet une intention au resolver (R4). Ses points de vie
## vivent dans MonsterState, à l'intérieur de GameState (R1).

const AMORTISSEMENT: float = 6.0
const GRAVITE: float = 26.0
## Force avec laquelle un monstre bouscule les caisses et les tables.
const POUSSEE_OBJETS: float = 3.0

signal veut_tirer(depuis: Vector3, direction: Vector3, degats: int)

var monster_id: int = -1
## Ce que le monstre poursuit. Un leurre peut prendre la place du joueur.
var cible: Node3D = null
## Ce vers quoi il revient quand une diversion s'achève. Mémorisé plutôt que
## reconstruit : c'est ce qui rend `distrait_par()` sûr — un leurre n'a pas à
## savoir qui poursuivait qui avant lui.
var cible_par_defaut: Node3D = null
## Tant que c'est vrai, le monstre a perdu la trace du joueur (Voile).
var aveugle: bool = false
var stats: MonsterStats = null

var _cerveau: MonsterBrain
## L'attention aux menaces du décor. Séparée du cerveau : l'un décide comment
## attaquer, l'autre quand arrêter.
var _vigilance: ThreatSense
## La bulle au-dessus de la tête. Créée quand il y a quelque chose à montrer,
## libérée dès qu'il n'y a plus rien.
var _emote: Emote = null
var _impulsion: Vector3 = Vector3.ZERO
var _facteur_vitesse: float = 1.0
var _ralenti_restant: float = 0.0
var _teinte_restante: float = 0.0
var _telegraphe: float = 0.0
## Temps restant en vol balistique après un souffle. Pendant ce temps la gravité
## seule décide : le sol ne remet pas la vitesse verticale à zéro, et le volant
## cesse de tenir son altitude — c'est ce qui permet de le décrocher du ciel.
var _envol_restant: float = 0.0
## Rotation propre du maillage pendant la culbute. Portée par le MESH et non par
## le corps : faire tourner le corps ferait tourner sa boîte de collision, et un
## monstre qui se coince dans un mur en vrillant n'est drôle qu'une fois.
var _vrille: Vector3 = Vector3.ZERO
## Cap de déambulation quand la créature a perdu sa trace, et ce qu'il en reste.
var _errance: Vector3 = Vector3.ZERO
var _errance_restante: float = 0.0
## Temps restant de diversion. Zéro = il poursuit sa cible par défaut.
var _distraction_restante: float = 0.0
var _mesh: MeshInstance3D = null
var _materiau: ShaderMaterial = null


func _ready() -> void:
	# Repérable par le monde physique. Un leurre posé au sol n'a pas de raison
	# de connaître le registre des monstres, exactement comme un tonneau n'a
	# pas de raison de le connaître pour exploser.
	add_to_group(&"monstre")
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)

	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	if _mesh != null:
		_materiau = _mesh.get_surface_override_material(0) as ShaderMaterial

	_cerveau = _cree_cerveau()
	_cerveau.veut_frapper.connect(_frappe)
	_cerveau.veut_tirer.connect(_tire)
	_cerveau.engage_l_attaque.connect(_signale_attaque)

	_vigilance = ThreatSense.new(stats, Content.tuning.vigilance_duree_de_fuite)
	_vigilance.remarque.connect(_sur_alerte)
	EventBus.explosion_armed.connect(_sur_meche_allumee)


## Point d'extension : un boss redéfinit cette méthode pour installer le sien.
func _cree_cerveau() -> MonsterBrain:
	return MonsterBrain.new(stats, 1.0 if (monster_id % 2 == 0) else -1.0)


func _physics_process(delta: float) -> void:
	_telegraphe = maxf(0.0, _telegraphe - delta)
	_envol_restant = maxf(0.0, _envol_restant - delta)
	_maj_vrille(delta)
	_maj_distraction(delta)
	_maj_ralentissement(delta)
	_maj_teinte(delta)
	_impulsion = _impulsion.move_toward(Vector3.ZERO, AMORTISSEMENT * delta)

	var deplacement := Vector3.ZERO
	var fuite: Vector3 = _vigilance.avance(delta, global_position)
	if fuite != Vector3.ZERO:
		# Fuir REMPLACE la décision du cerveau. Sans ça, la créature s'écarterait
		# du tonneau tout en continuant d'orbiter autour du joueur, et on ne
		# lirait ni l'un ni l'autre.
		deplacement = fuite * stats.vitesse * _facteur_vitesse \
			* Content.tuning.vigilance_vitesse_de_fuite
	elif aveugle:
		# Aveuglée, elle CHERCHE. Se figer sur place se lit comme un bug plutôt
		# que comme un sort — c'était le défaut du Voile, invisible faute de
		# quoi que ce soit à regarder.
		deplacement = _cherche(delta)
	elif cible != null:
		deplacement = _cerveau.decide(delta, global_position, cible, _facteur_vitesse)
	_maj_emote()

	velocity.x = deplacement.x + _impulsion.x
	velocity.z = deplacement.z + _impulsion.z
	_maj_vertical(delta)
	move_and_slide()
	_bouscule_les_objets()


func _maj_vertical(delta: float) -> void:
	if _envol_restant > 0.0:
		# En vol balistique, volant compris. Le sol ne reprend pas la main :
		# sinon l'impulsion verticale serait annulée dès la première frame,
		# alors qu'on touche encore le sol d'où l'on décolle.
		velocity.y -= GRAVITE * delta
		return
	if not stats.vole:
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITE * delta
		return
	# Le volant se maintient à son altitude, avec un léger flottement pour
	# qu'il ne ressemble pas à une cible fixe.
	var voulue: float = stats.hauteur_vol \
		+ sin(float(Time.get_ticks_msec()) * 0.002 + float(monster_id)) * 0.35
	velocity.y = (voulue - global_position.y) * 3.0


## Déambulation d'une créature qui a perdu sa trace. Un cap tenu quelques
## secondes, puis un autre — ni une patrouille, ni un tremblement sur place.
##
## Le cap est tiré au hasard hors de RngService : c'est de la présentation d'un
## état, pas une décision de jeu. Deux clients qui la verraient chercher dans
## des directions différentes verraient quand même la même créature aveuglée
## au même endroit.
func _cherche(delta: float) -> Vector3:
	_errance_restante -= delta
	if _errance_restante <= 0.0:
		var t: Tuning = Content.tuning
		_errance_restante = t.errance_duree_du_cap
		var angle: float = randf() * TAU
		_errance = Vector3(cos(angle), 0.0, sin(angle))
	return _errance * stats.vitesse * Content.tuning.errance_vitesse * _facteur_vitesse


# ── Vigilance ─────────────────────────────────────────────────────────────

func _sur_meche_allumee(origine: Vector3, rayon: float, _delai: float) -> void:
	_vigilance.signale(origine, rayon, global_position)


## Le moment où la créature comprend. Le sursaut de l'émote et l'interruption de
## l'assaut sont la même chose vue de deux endroits : elle lâche ce qu'elle
## faisait.
func _sur_alerte() -> void:
	if _emote != null:
		_emote.eclate()
	if _cerveau != null:
		_cerveau.interrompt_l_assaut()


func _maj_emote() -> void:
	# La surprise passe avant l'interrogation : une créature qui cherche et qui
	# voit une mèche s'allumer a un problème plus urgent que sa recherche.
	var genre: int = -1
	if _vigilance.attentif():
		genre = Emote.Genre.SURPRISE
	elif aveugle:
		genre = Emote.Genre.INTERROGATION

	if genre < 0:
		if _emote != null:
			_emote.efface()
			_emote = null
		return

	# Changer de genre change le signe, pas seulement sa couleur : on remplace.
	if _emote != null and _emote.genre != genre:
		_emote.efface()
		_emote = null

	if _emote == null:
		var parent: Node = get_parent()
		if parent == null:
			return
		_emote = Emote.cree(genre, self, Vector3(0, stats.taille.y * 0.5 + 0.7, 0))
		parent.add_child(_emote)
		if genre == Emote.Genre.INTERROGATION:
			_emote.eclate()

	# L'interrogation est un ÉTAT, pas une progression : elle s'affiche pleine.
	_emote.remplissage = _vigilance.progression() \
		if genre == Emote.Genre.SURPRISE else 1.0


## Un monstre qui traverse une caisse sans la bouger casse l'illusion.
func _bouscule_les_objets() -> void:
	for i: int in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var corps := collision.get_collider() as RigidBody3D
		if corps != null:
			corps.apply_central_impulse(-collision.get_normal() * POUSSEE_OBJETS)


# ── Attaques : toujours via le resolver ───────────────────────────────────

func _frappe() -> void:
	var intent := EffectIntent.new()
	intent.source_player_id = -1
	intent.source_slot = -1
	intent.kind = EffectIntent.Kind.DAMAGE
	intent.amount = stats.degats
	intent.origine = global_position
	intent.target_ids = PackedInt64Array([0])
	EffectResolver.submit(intent)


func _tire(direction: Vector3) -> void:
	veut_tirer.emit(global_position, direction, stats.degats)


## Un éclat juste avant de frapper : sans télégraphe, une attaque n'est pas
## esquivable, elle est seulement subie.
func _signale_attaque() -> void:
	_telegraphe = 0.35
	_teinte_shader(Color(1.0, 0.85, 0.4), 1.5)


# ── Effets subis ──────────────────────────────────────────────────────────

## Repoussé par un souffle. La composante verticale le décolle — y compris un
## volant, qui perd alors son altitude et retombe.
##
## L'envol dure le temps d'une balistique et pas une seconde de plus : voir un
## rôdeur partir en l'air est la moitié du plaisir d'une explosion, l'y voir
## rester en ferait une immobilisation, donc une mécanique de contrôle.
func repousse(vecteur: Vector3) -> void:
	_impulsion += Vector3(vecteur.x, 0.0, vecteur.z)
	if vecteur.y > 0.0:
		velocity.y = maxf(velocity.y, vecteur.y)
		_envol_restant = maxf(_envol_restant, vecteur.y / GRAVITE * 2.1)
		_arme_la_vrille(vecteur)
	if _cerveau != null:
		_cerveau.interrompt_l_assaut()


## La vrille suit le sens du souffle. Purement visuelle, donc tirée au hasard
## sans passer par RngService : deux clients qui la verraient tourner dans des
## sens opposés verraient quand même le même monstre au même endroit.
func _arme_la_vrille(vecteur: Vector3) -> void:
	var force: float = clampf(vecteur.length() * 0.4, 1.5, 10.0)
	var axe := Vector3(vecteur.z, randf_range(-1.0, 1.0) * vecteur.length(), -vecteur.x)
	if axe.length_squared() < 0.001:
		axe = Vector3.UP
	_vrille = axe.normalized() * force


func _maj_vrille(delta: float) -> void:
	if _mesh == null:
		return
	if _envol_restant > 0.0:
		_mesh.rotation += _vrille * delta
		return
	if _mesh.rotation.length_squared() < 0.0001:
		return
	# Retombé : il se remet d'aplomb. Vite, mais pas instantanément — un
	# redressement sec annulerait la culbute qu'on vient de regarder.
	_mesh.rotation = _mesh.rotation.lerp(Vector3.ZERO, minf(delta * 7.0, 1.0))


## Détourné vers un leurre pour un temps. Le leurre redirige la menace, il ne
## la supprime pas : le monstre le poursuit sans le frapper, exactement comme
## avec le sort.
func distrait_par(leurre: Node3D, duree: float) -> void:
	if leurre == null or duree <= 0.0:
		return
	cible = leurre
	_distraction_restante = duree
	desoriente()


func _maj_distraction(delta: float) -> void:
	if _distraction_restante <= 0.0:
		return
	_distraction_restante -= delta
	# On revient aussi si le leurre disparaît avant la fin : poursuivre une
	# référence morte laisserait le monstre planté pour de bon.
	if _distraction_restante <= 0.0 or not is_instance_valid(cible):
		_distraction_restante = 0.0
		cible = cible_par_defaut


## Perdre le fil de son assaut sans être bousculé. Se faire permuter ne pousse
## personne, mais on ne poursuit pas une charge vers un endroit où l'on n'est
## plus.
func desoriente() -> void:
	if _cerveau != null:
		_cerveau.interrompt_l_assaut()


func ralentis(facteur: float, duree: float) -> void:
	_facteur_vitesse = minf(_facteur_vitesse, facteur)
	_ralenti_restant = maxf(_ralenti_restant, duree)
	_teinte_shader(Color(0.35, 0.7, 1.0), 0.9)


func encaisse_visuellement(degats: int = 0, fatal: bool = false) -> void:
	_teinte_restante = 1.0
	scale = Vector3(1.2, 0.85, 1.2)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.18)

	# Le bruit et le chiffre partent d'ICI, parce que c'est ici qu'on connaît
	# la position. Le resolver, lui, ne sait pas où se tiennent les corps.
	EventBus.sound_emitted.emit(&"impact", global_position)
	if degats > 0:
		_montre_les_degats(degats, fatal)


func _montre_les_degats(degats: int, fatal: bool) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	parent.add_child(DamageNumber.cree(degats,
		global_position + Vector3(0, stats.taille.y * 0.55, 0), fatal))


func _maj_ralentissement(delta: float) -> void:
	if _ralenti_restant <= 0.0:
		_facteur_vitesse = 1.0
		return
	_ralenti_restant -= delta
	if _ralenti_restant <= 0.0:
		_facteur_vitesse = 1.0
		if _telegraphe <= 0.0:
			_teinte_shader(Color.BLACK, 0.0)


func _maj_teinte(delta: float) -> void:
	if _teinte_restante <= 0.0:
		return
	_teinte_restante = maxf(0.0, _teinte_restante - delta * 4.0)
	if _materiau != null:
		_materiau.set_shader_parameter("albedo",
			stats.couleur.lerp(Color.WHITE, _teinte_restante))


func _teinte_shader(couleur: Color, force: float) -> void:
	if _materiau == null:
		return
	_materiau.set_shader_parameter("couleur_lisere", couleur)
	_materiau.set_shader_parameter("force_lisere", maxf(force, 0.55))


## Désagrégation à la mort. Un ennemi qui disparaît d'un coup laisse un doute —
## l'a-t-on tué, ou est-il sorti du champ ? La dissolution répond sans texte.
##
## L'avatar se détache de la scène de jeu le temps de l'effet : il ne doit plus
## ni bouger, ni bloquer, ni être ciblé.
func meurt_en_se_dissolvant() -> void:
	EventBus.sound_emitted.emit(&"mort", global_position)
	set_physics_process(false)
	if _emote != null:
		_emote.efface()
		_emote = null
	for enfant: Node in get_children():
		if enfant is CollisionShape3D:
			(enfant as CollisionShape3D).disabled = true

	if _mesh == null:
		queue_free()
		return

	var mat := MaterialLibrary.dissolution(stats.couleur)
	_mesh.set_surface_override_material(0, mat)

	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("progression", v), 0.0, 1.0, 0.55)
	tween.tween_callback(queue_free)
