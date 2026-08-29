class_name MonsterSpawner
extends RefCounted
## Fait apparaître les monstres d'un étage à partir des Resources de contenu.
##
## Il n'écrit aucune caractéristique : tout vient des MonsterStats posées dans
## resources/monsters/. Ajouter un type de monstre au jeu revient donc à
## déposer un fichier, pas à toucher ce script (R6).

signal monstre_veut_tirer(depuis: Vector3, direction: Vector3, degats: int)

var avatars: Dictionary = {}

var _parent: Node3D
var _tuning: Tuning


func _init(parent: Node3D, tuning: Tuning) -> void:
	_parent = parent
	_tuning = tuning


## Composition d'un étage. Elle se durcit en descendant : d'abord des rôdeurs,
## puis du volant qui force à lever les yeux, puis de la brute.
func composition(etage: int, rng: RandomNumberGenerator) -> Array:
	var rodeur: MonsterStats = Content.monstre(&"rodeur")
	var brute: MonsterStats = Content.monstre(&"brute")
	var ailee: MonsterStats = Content.monstre(&"rodeuse_ailee")

	var out: Array = []
	if rodeur != null:
		out.append(rodeur)
		out.append(rodeur)
	if etage >= 1 and ailee != null:
		out.append(ailee)
	if etage >= 2 and brute != null:
		out.append(brute)
	if etage >= 3:
		out.append(ailee if (ailee != null and rng.randf() < 0.5) else rodeur)
	return out


func vide() -> void:
	for enfant: Node in _parent.get_children():
		enfant.queue_free()
	avatars.clear()


## Fait apparaître le boss au centre de l'arène.
func invoque_le_boss(plan: FloorPlan, cible: Node3D, etage: int) -> BossAvatar:
	vide()
	var stats: BossStats = Content.monstre(&"gardien_du_seuil") as BossStats
	if stats == null:
		push_error("Boss introuvable dans le contenu.")
		return null
	var centre: Vector3 = plan.salles[0].centre
	return fait_apparaitre(stats, centre + Vector3(0, 0, -8.0), cible, etage) as BossAvatar


func peuple(plan: FloorPlan, cible: Node3D, etage: int,
		rng: RandomNumberGenerator) -> void:
	vide()
	for index: int in plan.salles.size():
		var salle: FloorPlan.Salle = plan.salles[index]
		# La salle du marchand est un sas : on y respire et on y décide.
		if salle.marchand:
			continue
		var bord: float = salle.cote * 0.5 - 3.0
		for stats: MonsterStats in composition(etage, rng):
			# La première salle est allégée : on ne doit pas être encerclé dès
			# la première seconde d'un étage.
			if index == 0 and rng.randf() < 0.3:
				continue
			fait_apparaitre(stats, salle.centre + Vector3(
				rng.randf_range(-bord, bord), 0.0, rng.randf_range(-bord, bord)),
				cible, etage)


func fait_apparaitre(stats: MonsterStats, pos: Vector3, cible: Node3D,
		etage: int) -> MonsterAvatar:
	var pv: int = stats.pv + etage * _tuning.pv_monstre_par_etage
	var id: int = GameState.spawn_monster(pv, stats.resonance, stats.id)

	# Un boss a son propre corps, mais entre dans l'état par le même chemin.
	var avatar: MonsterAvatar = BossAvatar.new() if stats is BossStats \
		else MonsterAvatar.new()
	avatar.monster_id = id
	avatar.cible = cible
	avatar.cible_par_defaut = cible
	avatar.stats = stats

	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = stats.taille
	forme.shape = boite
	avatar.add_child(forme)

	var visuel := MeshInstance3D.new()
	visuel.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = stats.taille
	visuel.mesh = mesh
	visuel.set_surface_override_material(0,
		MaterialLibrary.aplat(stats.couleur, MaterialLibrary.Role.CREATURE))
	avatar.add_child(visuel)

	# Le volant démarre déjà en l'air, sinon on le voit décoller bêtement.
	var hauteur: float = stats.hauteur_vol if stats.vole else stats.taille.y * 0.5 + 0.2
	avatar.position = Vector3(pos.x, hauteur, pos.z)
	avatar.veut_tirer.connect(_relaie_le_tir)
	_parent.add_child(avatar)
	avatars[id] = avatar
	return avatar


func _relaie_le_tir(depuis: Vector3, direction: Vector3, degats: int) -> void:
	monstre_veut_tirer.emit(depuis, direction, degats)
