class_name TetherSignature
extends SpellSignature
## SIPHON — un lien tendu, parcouru de perles qui remontent.
##
## Le vol de vie est le seul sort qui rend quelque chose à son lanceur, et c'est
## la seule chose qu'il doit dire. D'où un LIEN visible, et des perles qui vont
## de la cible vers le lanceur — jamais l'inverse.
##
## Le lien se règle avec `vise()` : la signature ne sait pas où est la cible,
## on la lui donne.

const PERLES: int = 5

var _lien: MeshInstance3D = null
var _perles: Array[MeshInstance3D] = []
var _vers: Vector3 = Vector3.FORWARD
var _longueur: float = 1.0


func monte() -> void:
	_lien = bloc(Vector3(0.1, 0.1, 1.0), 0.45)
	add_child(_lien)
	for i: int in PERLES:
		var p := bloc(Vector3.ONE * 0.24, 0.75)
		add_child(p)
		_perles.append(p)
		p.set_meta(&"decalage", float(i) / float(PERLES))


## Tend le lien vers un point du monde. À appeler à chaque image tant que la
## cible bouge.
func vise(point: Vector3) -> void:
	var ecart: Vector3 = point - global_position
	_longueur = maxf(ecart.length(), 0.1)
	_vers = ecart / _longueur
	if _lien != null:
		_lien.position = _vers * (_longueur * 0.5)
		_lien.scale.z = _longueur
		_lien.look_at(global_position + _vers * 2.0, Vector3.UP)


func anime(part: float, _delta: float) -> void:
	for p: MeshInstance3D in _perles:
		# Elles remontent : de 1 vers 0 le long du lien. Le sens est tout le
		# propos du sort, une perle qui descend dirait le contraire.
		var t: float = fmod(float(p.get_meta(&"decalage")) + part * 2.2, 1.0)
		p.position = _vers * (_longueur * (1.0 - t))
		p.scale = Vector3.ONE * (0.5 + (1.0 - t) * 0.9)
