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
	## Salle en cul-de-sac, hors du chemin critique.
	var annexe: bool = false
	## Arène de boss : ni marchand, ni couloir.
	var arene: bool = false


var salles: Array[Salle] = []
## Départ et direction de chaque couloir.
var couloirs: Array[Dictionary] = []


## Étage ordinaire : une chaîne de salles de longueur variable, parfois avec
## une salle en cul-de-sac.
##
## Le nombre de salles change d'un étage à l'autre — sinon chaque étage a la
## même forme et la descente perd tout relief.
static func genere(rng: RandomNumberGenerator, tuning: Tuning) -> FloorPlan:
	var plan := FloorPlan.new()
	var nombre: int = rng.randi_range(maxi(2, tuning.salles_min), maxi(2, tuning.salles_max))

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

	# Une salle en cul-de-sac, greffée sur le côté d'une salle intermédiaire.
	# Elle n'est pas sur le chemin critique : on peut l'ignorer, ce qui donne
	# une première décision de parcours.
	if nombre >= 3 and rng.randf() < 0.55:
		plan._greffe_annexe(rng, tuning, centres, cotes, directions)

	return plan


## Boss : une arène unique, sans couloir ni annexe. La lisibilité prime, on
## doit voir arriver ce qui nous tombe dessus.
static func genere_arene(rng: RandomNumberGenerator, tuning: Tuning) -> FloorPlan:
	var plan := FloorPlan.new()
	var arene := Salle.new()
	arene.centre = Vector3.ZERO
	arene.cote = maxf(tuning.taille_salle_max * 1.5, 40.0)
	arene.arene = true
	plan.salles.append(arene)
	return plan


func _greffe_annexe(rng: RandomNumberGenerator, tuning: Tuning,
		centres: Array[Vector3], cotes: Array[float],
		directions: Array[Vector3]) -> void:
	var index: int = rng.randi_range(1, salles.size() - 2)
	var principale: FloorPlan.Salle = salles[index]

	# Perpendiculaire au couloir qui traverse cette salle, et du côté libre.
	var axe: Vector3 = directions[index]
	var lateral: Vector3 = Vector3.FORWARD if axe == Vector3.RIGHT else Vector3.RIGHT
	if principale.ouvertures.has(lateral):
		lateral = -lateral
	if principale.ouvertures.has(lateral):
		return

	var cote: float = rng.randf_range(tuning.taille_salle_min * 0.7,
		tuning.taille_salle_min)
	var annexe := Salle.new()
	annexe.centre = principale.centre + lateral * (
		principale.cote * 0.5 + tuning.longueur_couloir + cote * 0.5)
	annexe.cote = cote
	annexe.annexe = true
	annexe.ouvertures.append(-lateral)

	principale.ouvertures.append(lateral)
	salles.append(annexe)
	couloirs.append({
		"depart": principale.centre + lateral * (principale.cote * 0.5),
		"direction": lateral,
	})


func salle_de_depart() -> Salle:
	return salles[0]


## La salle du marchand est la dernière de la CHAÎNE, pas la dernière ajoutée :
## une annexe greffée après coup ne doit pas voler sa place.
func salle_du_marchand() -> Salle:
	for salle: Salle in salles:
		if salle.marchand:
			return salle
	return salles[salles.size() - 1]


func est_une_arene() -> bool:
	return salles.size() == 1 and salles[0].arene
