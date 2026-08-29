class_name MonsterAvatar
extends CharacterBody3D
## Le corps et le comportement d'un monstre. JETABLE — remplacé en C3.
##
## Il ne connaît que son `monster_id`. Ses points de vie vivent dans
## MonsterState, à l'intérieur de GameState (R1). Il n'applique jamais de
## dégâts lui-même : il soumet une intention au resolver (R4).
##
## L'IA est une petite machine à états, et c'est volontaire : un monstre qui
## fonce tout droit ne crée aucune décision chez le joueur. Ici il approche,
## tourne autour, choisit son moment, frappe, se replie. C'est ce cycle qui
## rend un combat lisible et anticipable.

enum Etat { APPROCHE, GARDE, ASSAUT, REPLI }

const AMORTISSEMENT: float = 6.0
const GRAVITE: float = 26.0
## Force avec laquelle un monstre bouscule les caisses et les tables.
const POUSSEE_OBJETS: float = 3.0

signal veut_tirer(depuis: Vector3, direction: Vector3, degats: int)

var monster_id: int = -1
## Ce que le monstre poursuit. Un leurre peut prendre la place du joueur.
var cible: Node3D = null
## Tant que c'est vrai, le monstre a perdu la trace du joueur (Voile).
var aveugle: bool = false
var stats: Dictionary = {}

var _etat: Etat = Etat.APPROCHE
var _minuteur: float = 0.0
var _recharge: float = 0.0
var _sens_orbite: float = 1.0
var _impulsion: Vector3 = Vector3.ZERO
var _facteur_vitesse: float = 1.0
var _ralenti_restant: float = 0.0
var _mesh: MeshInstance3D = null
var _materiau: StandardMaterial3D = null
var _teinte_restante: float = 0.0
var _telegraphe: float = 0.0


func _ready() -> void:
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	if _mesh != null:
		_materiau = _mesh.get_surface_override_material(0) as StandardMaterial3D
	# Un sens de rotation par monstre : sinon ils tournent tous du même côté
	# et forment une ronde parfaitement lisible, donc sans danger.
	_sens_orbite = 1.0 if (monster_id % 2 == 0) else -1.0
	_recharge = float(stats.get("delai_assaut", 2.0)) * 0.5


func _physics_process(delta: float) -> void:
	_recharge = maxf(0.0, _recharge - delta)
	_minuteur = maxf(0.0, _minuteur - delta)
	_telegraphe = maxf(0.0, _telegraphe - delta)
	_maj_ralentissement(delta)
	_maj_teinte(delta)

	_impulsion = _impulsion.move_toward(Vector3.ZERO, AMORTISSEMENT * delta)

	var deplacement := Vector3.ZERO
	if cible != null and not aveugle:
		deplacement = _decide(delta)

	velocity.x = deplacement.x + _impulsion.x
	velocity.z = deplacement.z + _impulsion.z
	_maj_vertical(delta)
	move_and_slide()
	_bouscule_les_objets()


## Le coeur de l'IA. Retourne la vitesse horizontale voulue.
func _decide(delta: float) -> Vector3:
	var vers: Vector3 = cible.global_position - global_position
	vers.y = 0.0
	var distance: float = vers.length()
	if distance < 0.01:
		return Vector3.ZERO
	var direction: Vector3 = vers / distance

	var vitesse: float = float(stats.get("vitesse", 3.0)) * _facteur_vitesse
	var garde: float = float(stats.get("distance_garde", 0.0))
	var sur_un_leurre: bool = cible.is_in_group("leurre")

	match _etat:
		Etat.APPROCHE:
			# Une brute n'a pas de distance de garde : elle arrive au contact.
			if distance <= maxf(garde, float(stats.get("portee_frappe", 2.0))):
				_etat = Etat.GARDE
			return direction * vitesse

		Etat.GARDE:
			if distance > garde * 1.45:
				_etat = Etat.APPROCHE
				return direction * vitesse

			if _recharge <= 0.0 and not sur_un_leurre:
				_engage(distance)
				return Vector3.ZERO

			# Rotation autour de la cible, avec une légère correction radiale
			# pour ne pas dériver au fil des tours.
			var tangente: Vector3 = direction.cross(Vector3.UP) * _sens_orbite
			var correction: float = clampf((distance - garde) / maxf(garde, 1.0), -1.0, 1.0)
			return (tangente + direction * correction).normalized() * vitesse * 0.85

		Etat.ASSAUT:
			if distance <= float(stats.get("portee_frappe", 2.0)):
				_frappe()
				_etat = Etat.REPLI
				_minuteur = float(stats.get("duree_repli", 0.6))
				_recharge = float(stats.get("delai_assaut", 2.0))
				return Vector3.ZERO
			if _minuteur <= 0.0:
				_etat = Etat.GARDE
				_recharge = float(stats.get("delai_assaut", 2.0)) * 0.6
			# L'assaut est plus rapide que la marche : c'est ce qui le rend
			# menaçant, et ce qui donne au joueur quelque chose à esquiver.
			return direction * vitesse * 2.1

		Etat.REPLI:
			if _minuteur <= 0.0:
				_etat = Etat.GARDE
			return -direction * vitesse * 0.9

	return Vector3.ZERO


## Passage à l'attaque. Les tireurs frappent à distance, les autres chargent.
func _engage(distance: float) -> void:
	if bool(stats.get("tire", false)):
		if distance <= float(stats.get("portee_frappe", 12.0)):
			var vers: Vector3 = (cible.global_position - global_position).normalized()
			veut_tirer.emit(global_position, vers, int(stats.get("degats", 8)))
			_recharge = float(stats.get("delai_assaut", 2.0))
			_signale_attaque()
		return

	if float(stats.get("duree_assaut", 0.0)) <= 0.0:
		# Sans phase de charge (la brute), on frappe dès qu'on est à portée.
		if distance <= float(stats.get("portee_frappe", 2.0)):
			_frappe()
			_recharge = float(stats.get("delai_assaut", 2.0))
		return

	_etat = Etat.ASSAUT
	_minuteur = float(stats.get("duree_assaut", 0.4))
	_signale_attaque()


## Un éclat juste avant de frapper : sans télégraphe, une attaque n'est pas
## esquivable, elle est seulement subie.
func _signale_attaque() -> void:
	_telegraphe = 0.35
	if _materiau != null:
		_materiau.emission_enabled = true
		_materiau.emission = Color(1.0, 0.85, 0.4)
		_materiau.emission_energy_multiplier = 1.4


func _maj_vertical(delta: float) -> void:
	if not bool(stats.get("vole", false)):
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITE * delta
		return
	# Le volant se maintient à son altitude, avec un léger flottement pour
	# qu'il ne ressemble pas à une cible fixe.
	var voulue: float = float(stats.get("hauteur_vol", 3.2)) \
		+ sin(float(Time.get_ticks_msec()) * 0.002 + float(monster_id)) * 0.35
	velocity.y = (voulue - global_position.y) * 3.0


## Un monstre qui traverse une caisse sans la bouger casse l'illusion.
func _bouscule_les_objets() -> void:
	for i: int in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var corps := collision.get_collider() as RigidBody3D
		if corps != null:
			corps.apply_central_impulse(-collision.get_normal() * POUSSEE_OBJETS)


func _maj_ralentissement(delta: float) -> void:
	if _ralenti_restant <= 0.0:
		_facteur_vitesse = 1.0
		return
	_ralenti_restant -= delta
	if _ralenti_restant <= 0.0:
		_facteur_vitesse = 1.0
		if _materiau != null and _telegraphe <= 0.0:
			_materiau.emission_enabled = false


func _maj_teinte(delta: float) -> void:
	if _telegraphe <= 0.0 and _materiau != null and _ralenti_restant <= 0.0 \
			and _materiau.emission_enabled and _teinte_restante <= 0.0:
		_materiau.emission_enabled = false
	if _teinte_restante <= 0.0:
		return
	_teinte_restante = maxf(0.0, _teinte_restante - delta * 4.0)
	if _materiau != null:
		var base: Color = stats.get("couleur", Color(0.75, 0.3, 0.35))
		_materiau.albedo_color = base.lerp(Color.WHITE, _teinte_restante)


## Même un monstre passe par le resolver : lui seul touche aux points de vie.
func _frappe() -> void:
	var intent := EffectIntent.new()
	intent.source_player_id = -1
	intent.source_slot = -1
	intent.kind = EffectIntent.Kind.DAMAGE
	intent.amount = int(stats.get("degats", 6))
	intent.target_ids = PackedInt64Array([0])
	EffectResolver.submit(intent)


func repousse(vecteur: Vector3) -> void:
	_impulsion += Vector3(vecteur.x, 0.0, vecteur.z)
	# Être bousculé interrompt un assaut : on ne charge pas en étant projeté.
	if _etat == Etat.ASSAUT:
		_etat = Etat.GARDE


func ralentis(facteur: float, duree: float) -> void:
	_facteur_vitesse = minf(_facteur_vitesse, facteur)
	_ralenti_restant = maxf(_ralenti_restant, duree)
	if _materiau != null:
		_materiau.emission_enabled = true
		_materiau.emission = Color(0.35, 0.7, 1.0)
		_materiau.emission_energy_multiplier = 0.5


func encaisse_visuellement() -> void:
	_teinte_restante = 1.0
	scale = Vector3(1.2, 0.85, 1.2)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.18)
