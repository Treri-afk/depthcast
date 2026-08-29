class_name RoomFurnisher
extends RefCounted
## Meuble une salle : piliers, estrade avec sa rampe, caisses et tables.
##
## Deux intentions. Casser la ligne de vue — un espace vide se traverse en
## ligne droite, un espace encombré force à choisir un chemin. Et donner de la
## matière aux sorts : une Répulsion dans une pièce nue ne se voit qu'à moitié.

var _builder: FloorBuilder
var _parent: Node3D
var _tuning: Tuning
## Les objets projetables et cassables créés au passage.
var objets: Array[PropDestructible] = []


func _init(builder: FloorBuilder, parent: Node3D, tuning: Tuning) -> void:
	_builder = builder
	_parent = parent
	_tuning = tuning


func meuble(salle: FloorPlan.Salle, rng: RandomNumberGenerator) -> void:
	var demi: float = salle.cote * 0.5

	# Une arène reste dégagée : on doit voir arriver ce qui nous tombe dessus.
	# Quelques piliers seulement, pour donner de quoi se couvrir.
	if salle.arene:
		for i: int in 4:
			var angle: float = TAU * float(i) / 4.0 + PI * 0.25
			_builder.bloc(salle.centre + Vector3(cos(angle), 0, sin(angle)) * (demi * 0.55)
				+ Vector3(0, _tuning.hauteur_pilier * 0.5, 0),
				Vector3(2.0, _tuning.hauteur_pilier, 2.0), Content.palette.pilier)
		return

	# Piliers en retrait des murs : ils créent des angles morts.
	var recul: float = demi * 0.52
	for signe_x: float in [-1.0, 1.0]:
		for signe_z: float in [-1.0, 1.0]:
			if rng.randf() < 0.25:
				continue
			_builder.bloc(
				salle.centre + Vector3(signe_x * recul, _tuning.hauteur_pilier * 0.5,
					signe_z * recul),
				Vector3(1.5, _tuning.hauteur_pilier, 1.5), Content.palette.pilier)

	if salle.marchand:
		_estrade(salle.centre + Vector3(0, 0, -demi * 0.62), 7.0, rng)
		return

	if rng.randf() < 0.7:
		var angle: float = rng.randf() * TAU
		_estrade(salle.centre + Vector3(cos(angle), 0, sin(angle)) * (demi * 0.55),
			rng.randf_range(4.5, 6.5), rng)

	var combien: int = int(rng.randf_range(5, 9))
	for i: int in combien:
		var pos: Vector3 = salle.centre + Vector3(
			rng.randf_range(-demi * 0.78, demi * 0.78), 0.0,
			rng.randf_range(-demi * 0.78, demi * 0.78))
		if pos.distance_to(salle.centre) < 3.0:
			continue
		var tirage: float = rng.randf()
		if tirage < 0.45:
			_objet(pos, Vector3(1.0, 1.0, 1.0), 7.0, Content.palette.caisse, false)
		elif tirage < 0.8:
			_objet(pos, Vector3(0.9, 1.2, 0.9), 9.0, Content.palette.tonneau, true)
		else:
			_objet(pos + Vector3(0, 0.35, 0), Vector3(2.2, 0.25, 1.2), 14.0,
				Content.palette.table, false)


func _estrade(centre: Vector3, cote: float, rng: RandomNumberGenerator) -> void:
	var hauteur: float = rng.randf_range(1.0, 1.9)
	_builder.bloc(centre + Vector3(0, hauteur * 0.5, 0),
		Vector3(cote, hauteur, cote), Content.palette.estrade)
	_builder.rampe(centre + Vector3(0, 0, cote * 0.5), Vector3.BACK, hauteur, cote * 0.6)


func _objet(pos: Vector3, taille: Vector3, masse: float, couleur: Color,
		cylindrique: bool) -> void:
	var corps := PropDestructible.new()
	corps.position = Vector3(pos.x, taille.y * 0.5 + 0.1, pos.z)
	corps.mass = masse
	corps.couleur = couleur
	# Un objet plus lourd encaisse plus : une table ne part pas comme un tonneau.
	corps.pv = int(masse * 2.2)
	corps.linear_damp = 1.6
	corps.angular_damp = 2.4

	var forme := CollisionShape3D.new()
	var visuel := MeshInstance3D.new()
	visuel.name = "Mesh"
	if cylindrique:
		var cyl := CylinderShape3D.new()
		cyl.radius = taille.x * 0.5
		cyl.height = taille.y
		forme.shape = cyl
		var mesh := CylinderMesh.new()
		mesh.top_radius = taille.x * 0.5
		mesh.bottom_radius = taille.x * 0.5
		mesh.height = taille.y
		visuel.mesh = mesh
	else:
		var boite := BoxShape3D.new()
		boite.size = taille
		forme.shape = boite
		var mesh := BoxMesh.new()
		mesh.size = taille
		visuel.mesh = mesh

	visuel.material_override = MaterialLibrary.aplat(couleur, MaterialLibrary.Role.OBJET)
	corps.add_child(forme)
	corps.add_child(visuel)
	_parent.add_child(corps)
	objets.append(corps)
