class_name ShockwaveSignature
extends SpellSignature
## RÉPULSION — une vraie onde de choc.
##
## Pas une lueur au sol qui grandit : un anneau de blocs CHASSÉS vers
## l'extérieur, qui se couchent en s'éloignant et laissent derrière eux un
## cercle de poussière. Ce qui se lit, c'est que quelque chose a été poussé —
## et c'est précisément ce que le sort fait aux monstres.

const SEGMENTS: int = 20
const HAUTEUR: float = 1.5

var _blocs: Array[MeshInstance3D] = []
var _socles: Array[MeshInstance3D] = []


func monte() -> void:
	var rayon: float = maxf(dimensions.x, 1.0)
	for i: int in SEGMENTS:
		var angle: float = TAU * float(i) / float(SEGMENTS)
		var direction := Vector3(cos(angle), 0.0, sin(angle))

		# Le bloc chassé. Large et mince, orienté perpendiculairement à sa
		# course : c'est un front qui avance, pas un projectile qui part.
		var front := bloc(Vector3(rayon * 0.32, HAUTEUR, 0.22), 0.55)
		front.position = direction * (rayon * 0.12) + Vector3(0, HAUTEUR * 0.5, 0)
		front.rotation.y = -angle
		add_child(front)
		_blocs.append(front)
		front.set_meta(&"direction", direction)

		# Le sillage au sol, plus sourd, qui reste une fraction de seconde de
		# plus : sans lui l'onde n'a pas de trace et paraît ne rien avoir touché.
		var trace := bloc(Vector3(rayon * 0.30, EPAISSEUR, 0.5), 0.3)
		trace.position = direction * (rayon * 0.12) + Vector3(0, 0.07, 0)
		trace.rotation.y = -angle
		add_child(trace)
		_socles.append(trace)
		trace.set_meta(&"direction", direction)


func anime(part: float, _delta: float) -> void:
	var rayon: float = maxf(dimensions.x, 1.0)
	# Départ sec, fin qui traîne : une onde de choc n'accélère jamais.
	var course: float = 1.0 - pow(1.0 - part, 2.6)

	for i: int in _blocs.size():
		var direction: Vector3 = _blocs[i].get_meta(&"direction")
		var d: float = rayon * (0.12 + 0.95 * course)
		# Les blocs se COUCHENT en s'éloignant : ils partent debout, ils
		# finissent à plat. C'est ce basculement qui fait lire la poussée.
		var couche: float = course * PI * 0.42
		_blocs[i].position = direction * d + Vector3(0, HAUTEUR * 0.5 * cos(couche), 0)
		_blocs[i].rotation = Vector3(0, -atan2(direction.z, direction.x) + PI * 0.5, 0)
		_blocs[i].rotate_object_local(Vector3.RIGHT, couche)
		_blocs[i].scale = Vector3(1.0 + course * 0.7, 1.0 - course * 0.45, 1.0)

		_socles[i].position = direction * (d * 0.94) + Vector3(0, 0.07, 0)
		_socles[i].scale = Vector3(1.0 + course * 1.1, 1.0, 1.0 + course * 0.5)
