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
		var genre: PropFactory.Genre = PropFactory.Genre.TABLE
		if tirage < 0.45:
			genre = PropFactory.Genre.CAISSE
		elif tirage < 0.8:
			genre = PropFactory.Genre.TONNEAU
		_pose(genre, pos)


func _estrade(centre: Vector3, cote: float, rng: RandomNumberGenerator) -> void:
	var hauteur: float = rng.randf_range(1.0, 1.9)
	_builder.bloc(centre + Vector3(0, hauteur * 0.5, 0),
		Vector3(cote, hauteur, cote), Content.palette.estrade)
	_builder.rampe(centre + Vector3(0, 0, cote * 0.5), Vector3.BACK, hauteur, cote * 0.6)


## Ce qu'est un meuble vit dans PropFactory : le terrain d'essai en pose les
## mêmes, et deux définitions divergeraient au premier réglage de masse.
func _pose(genre: PropFactory.Genre, pos: Vector3) -> void:
	var corps := PropFactory.cree(genre, pos)
	_parent.add_child(corps)
	objets.append(corps)
