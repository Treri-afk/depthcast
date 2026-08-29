class_name FloorBuilder
extends RefCounted
## Bâtit la géométrie d'un étage à partir d'un FloorPlan : sols, murs percés,
## couloirs, rampes.

var _parent: Node3D
var _tuning: Tuning


func _init(parent: Node3D, tuning: Tuning) -> void:
	_parent = parent
	_tuning = tuning


func batit(plan: FloorPlan) -> void:
	for salle: FloorPlan.Salle in plan.salles:
		_batit_salle(salle)
	for couloir: Dictionary in plan.couloirs:
		_batit_couloir(couloir["depart"], couloir["direction"])


func _batit_salle(salle: FloorPlan.Salle) -> void:
	bloc(salle.centre + Vector3(0, -0.5, 0), Vector3(salle.cote, 1, salle.cote),
		Color(0.30, 0.31, 0.36))

	var demi: float = salle.cote * 0.5
	var murs := [
		{"pos": Vector3(demi, 0, 0), "le_long_de_z": true, "dir": Vector3.RIGHT},
		{"pos": Vector3(-demi, 0, 0), "le_long_de_z": true, "dir": Vector3.LEFT},
		{"pos": Vector3(0, 0, demi), "le_long_de_z": false, "dir": Vector3.BACK},
		{"pos": Vector3(0, 0, -demi), "le_long_de_z": false, "dir": Vector3.FORWARD},
	]
	for mur: Dictionary in murs:
		_batit_mur(salle.centre + mur["pos"], salle.cote, mur["le_long_de_z"],
			salle.ouvertures.has(mur["dir"]))


func _batit_mur(centre: Vector3, longueur: float, le_long_de_z: bool,
		perce: bool) -> void:
	var hauteur := Vector3(0, _tuning.hauteur_mur * 0.5, 0)
	var couleur := Color(0.20, 0.21, 0.26)

	if not perce:
		var taille: Vector3 = Vector3(1, _tuning.hauteur_mur, longueur) if le_long_de_z \
			else Vector3(longueur, _tuning.hauteur_mur, 1)
		bloc(centre + hauteur, taille, couleur)
		return

	# Deux segments de part et d'autre de l'ouverture, plutôt qu'un bloc percé.
	var segment: float = (longueur - _tuning.largeur_couloir) * 0.5
	if segment <= 0.2:
		return
	var decalage: float = (_tuning.largeur_couloir + segment) * 0.5
	for signe: float in [-1.0, 1.0]:
		var pos: Vector3 = centre + hauteur
		var taille: Vector3
		if le_long_de_z:
			pos.z += signe * decalage
			taille = Vector3(1, _tuning.hauteur_mur, segment)
		else:
			pos.x += signe * decalage
			taille = Vector3(segment, _tuning.hauteur_mur, 1)
		bloc(pos, taille, couleur)


func _batit_couloir(depart: Vector3, direction: Vector3) -> void:
	var milieu: Vector3 = depart + direction * (_tuning.longueur_couloir * 0.5)
	var le_long_de_x: bool = absf(direction.x) > 0.5
	var sol: Vector3 = Vector3(_tuning.longueur_couloir, 1, _tuning.largeur_couloir) \
		if le_long_de_x else Vector3(_tuning.largeur_couloir, 1, _tuning.longueur_couloir)
	bloc(milieu + Vector3(0, -0.5, 0), sol, Color(0.26, 0.27, 0.32))

	var hauteur := Vector3(0, _tuning.hauteur_mur * 0.5, 0)
	var demi_large: float = _tuning.largeur_couloir * 0.5
	for signe: float in [-1.0, 1.0]:
		if le_long_de_x:
			bloc(milieu + hauteur + Vector3(0, 0, signe * demi_large),
				Vector3(_tuning.longueur_couloir, _tuning.hauteur_mur, 1),
				Color(0.18, 0.19, 0.24))
		else:
			bloc(milieu + hauteur + Vector3(signe * demi_large, 0, 0),
				Vector3(1, _tuning.hauteur_mur, _tuning.longueur_couloir),
				Color(0.18, 0.19, 0.24))


## Bloc statique. Utilisé aussi par le meublage, d'où sa visibilité.
func bloc(pos: Vector3, taille: Vector3, couleur: Color,
		rotation_euler: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var corps := StaticBody3D.new()
	corps.position = pos
	corps.rotation = rotation_euler

	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = taille
	forme.shape = boite
	corps.add_child(forme)

	var visuel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = taille
	visuel.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = couleur
	visuel.material_override = mat
	corps.add_child(visuel)

	_parent.add_child(corps)
	return corps


## Rampe praticable. En vue subjective, des marches obligent à sauter à chaque
## montée : c'est pénible et ça donne l'impression d'un décor qui résiste. Une
## pente à 22° se monte sans y penser, et les monstres l'empruntent aussi sans
## aucun code de navigation.
func rampe(pied: Vector3, direction: Vector3, hauteur: float, largeur: float) -> void:
	var longueur: float = hauteur / tan(deg_to_rad(22.0))
	var pente: float = sqrt(hauteur * hauteur + longueur * longueur)
	var centre: Vector3 = pied + direction * (longueur * 0.5) + Vector3(0, hauteur * 0.5, 0)
	bloc(centre, Vector3(largeur, 0.6, pente), Color(0.23, 0.24, 0.29),
		Vector3(atan2(hauteur, longueur), atan2(direction.x, direction.z), 0))
