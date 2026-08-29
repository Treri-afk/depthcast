class_name BlastStation
extends LabStation
## Fosse aux explosions : un souffle au même endroit, toutes les N secondes.
##
## C'est le banc du ressenti. Une projection ne se règle pas en lisant un
## nombre — il faut se mettre dedans, plusieurs fois de suite, et changer un
## réglage entre deux essais. D'où la boucle, et d'où le fait qu'elle parte
## toute seule : devoir la déclencher, c'est déjà ne plus être dedans.
##
## Le souffle du banc ne BLESSE pas. On vient y mesurer une trajectoire, pas y
## mourir toutes les trois secondes.

const RAYON: float = 6.0
const INTERVALLE: float = 3.0

## Les crans de puissance, arrêt compris. Nommés parce qu'on les annonce.
const CRANS: Array[Dictionary] = [
	{"nom": "arrêt", "puissance": 0.0},
	{"nom": "faible", "puissance": 9.0},
	{"nom": "moyen", "puissance": 18.0},
	{"nom": "violent", "puissance": 30.0},
]

var _cran: int = 2
var _restant: float = INTERVALLE
var _compte: Label3D
var _disque: MeshInstance3D
var _materiau: ShaderMaterial


func titre() -> String:
	return "Fosse aux explosions"


func installe() -> void:
	pancarte("FOSSE AUX EXPLOSIONS\n[E] changer la puissance", 4.2, 34)
	_compte = pancarte("", 3.2, 38)

	_disque = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = RAYON
	mesh.bottom_radius = RAYON
	mesh.height = 0.14
	_disque.mesh = mesh
	_disque.position = Vector3(0, 0.07, 0)
	_materiau = MaterialLibrary.aplat(Content.palette.creature_commune,
		MaterialLibrary.Role.INTERACTIF)
	_disque.material_override = _materiau
	add_child(_disque)


func invite() -> String:
	return "[E] puissance du souffle : %s" % CRANS[_cran]["nom"]


func interagit() -> String:
	_cran = (_cran + 1) % CRANS.size()
	_restant = INTERVALLE
	return "Fosse : souffle %s (%.0f)." % [CRANS[_cran]["nom"], _puissance()]


func _process(delta: float) -> void:
	if _puissance() <= 0.0:
		_compte.text = "arrêt"
		_teinte(0.0)
		return

	_restant -= delta
	if _restant <= 0.0:
		_restant = INTERVALLE
		_explose()

	_compte.text = "%.1f s" % _restant
	# La dalle chauffe à l'approche : le compte à rebours se lit du coin de
	# l'œil, sans avoir à revenir lire le chiffre.
	_teinte(1.0 - clampf(_restant / INTERVALLE, 0.0, 1.0))


func _puissance() -> float:
	return float(CRANS[_cran]["puissance"])


func _teinte(chaleur: float) -> void:
	_materiau.set_shader_parameter("albedo",
		Content.palette.mur.lerp(Content.palette.creature_commune, chaleur))


## Exactement le chemin d'un sort de zone : même contexte, même Souffle, même
## atténuation. Si la projection se sent bien ici, elle se sentira bien en jeu.
func _explose() -> void:
	var centre: Vector3 = global_position + Vector3(0, 0.4, 0)
	terrain.contexte.souffle(centre, RAYON, _puissance(), true, 0)
	terrain.fx.anneau(centre, RAYON, Content.palette.creature_commune)
	terrain.fx.eclair(centre + Vector3(0, 1.0, 0),
		Content.palette.creature_commune, 0.3, 7.0, RAYON * 2.4)
