class_name FloorPlan
extends RefCounted
## Le plan d'un étage : où sont les salles, de quelle taille, reliées comment.
##
## Il ne construit rien — il décide. Séparer la décision de la construction est
## ce qui permet de tester une génération sans instancier une seule Node, et
## c'est aussi ce qui a corrigé un vieux bug : l'espacement se calculait
## autrefois avec une taille tirée séparément de celle réellement bâtie, donc
## les couloirs ne tombaient jamais en face des ouvertures.

class Salle:
	var centre: Vector3
	var cote: float
	## Directions dans lesquelles un mur est percé.
	var ouvertures: Array[Vector3] = []
	var marchand: bool = false


var salles: Array[Salle] = []
## Départ et direction de chaque couloir.
var couloirs: Array[Dictionary] = []


static func genere(rng: RandomNumberGenerator, tuning: Tuning) -> FloorPlan:
	var plan := FloorPlan.new()
	var nombre: int = maxi(2, tuning.salles_par_etage)

	# 1. Toutes les tailles d'abord.
	var cotes: Array[float] = []
	for i: int in nombre:
		cotes.append(rng.randf_range(tuning.taille_salle_min, tuning.taille_salle_max))
	# La salle du marchand est toujours généreuse : il faut la place de
	# tourner autour des socles.
	cotes[nombre - 1] = maxf(cotes[nombre - 1], 24.0)

	# 2. Les directions, alternées pour éviter la ligne droite.
	var directions: Array[Vector3] = []
	var courante := Vector3.RIGHT
	for i: int in nombre - 1:
		directions.append(courante)
		courante = Vector3.FORWARD if courante == Vector3.RIGHT else Vector3.RIGHT

	# 3. Les centres, déduits des tailles réelles.
	var centres: Array[Vector3] = [Vector3.ZERO]
	for i: int in nombre - 1:
		centres.append(centres[i] + directions[i] * (
			cotes[i] * 0.5 + tuning.longueur_couloir + cotes[i + 1] * 0.5))

	for i: int in nombre:
		var salle := Salle.new()
		salle.centre = centres[i]
		salle.cote = cotes[i]
		salle.marchand = (i == nombre - 1)
		if i > 0:
			salle.ouvertures.append(-directions[i - 1])
		if i < nombre - 1:
			salle.ouvertures.append(directions[i])
		plan.salles.append(salle)

	for i: int in nombre - 1:
		plan.couloirs.append({
			"depart": centres[i] + directions[i] * (cotes[i] * 0.5),
			"direction": directions[i],
		})

	return plan


func salle_de_depart() -> Salle:
	return salles[0]


func salle_du_marchand() -> Salle:
	return salles[salles.size() - 1]
