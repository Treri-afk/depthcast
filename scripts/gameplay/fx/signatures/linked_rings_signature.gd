class_name LinkedRingsSignature
extends SpellSignature
## PERMUTATION — deux anneaux qui échangent leurs places.
##
## Le seul sort dont l'effet est une SYMÉTRIE, et le visuel le dit littéralement :
## deux anneaux, un à chaque bout, qui se croisent en tournant l'un autour de
## l'autre. Rien d'autre dans le jeu ne fait ce geste, donc on le reconnaît sans
## avoir à lire ce qui s'est passé.

var _ici: Array[MeshInstance3D] = []
var _la_bas: Array[MeshInstance3D] = []
var _vers: Vector3 = Vector3.FORWARD
var _distance: float = 2.0


func monte() -> void:
	_ici = anneau(0.85, 0.16, 12, 0.6)
	_la_bas = anneau(0.85, 0.16, 12, 0.6)
	for p: MeshInstance3D in _ici:
		p.position.y = 1.0
	for p: MeshInstance3D in _la_bas:
		p.position.y = 1.0


## Où se trouve l'autre bout de l'échange.
func relie(point: Vector3) -> void:
	var ecart: Vector3 = point - global_position
	_distance = maxf(ecart.length(), 0.2)
	_vers = ecart / _distance


func anime(part: float, _delta: float) -> void:
	# Ils se croisent une fois, au milieu, et repartent : c'est un ÉCHANGE, pas
	# une rotation continue.
	var t: float = smoothstep(0.0, 1.0, part)
	var lateral: Vector3 = _vers.cross(Vector3.UP).normalized()
	var arc: float = sin(t * PI) * _distance * 0.28

	for p: MeshInstance3D in _ici:
		p.position = _decale(p, _vers * (_distance * t) + lateral * arc)
		p.rotation.y += 0.06
	for p: MeshInstance3D in _la_bas:
		p.position = _decale(p, _vers * (_distance * (1.0 - t)) - lateral * arc)
		p.rotation.y -= 0.06


## Conserve la place de la pièce DANS son anneau, et n'applique que le
## déplacement d'ensemble : sans ça les anneaux s'effondreraient sur un point.
func _decale(piece: MeshInstance3D, deplacement: Vector3) -> Vector3:
	if not piece.has_meta(&"local"):
		piece.set_meta(&"local", piece.position)
	return (piece.get_meta(&"local") as Vector3) + deplacement
