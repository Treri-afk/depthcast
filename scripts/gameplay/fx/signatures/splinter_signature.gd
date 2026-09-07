class_name SplinterSignature
extends SpellSignature
## ÉCLAT NOCTURNE — une lame plate qui vrille.
##
## L'autre projectile du jeu, et il ne doit pas ressembler à la comète. Là où
## celle-ci est un noyau rond entouré de braises, celui-ci est PLAT : une lame
## unique, large et fine, qui tourne sur son axe de vol comme une carte lancée.
## Deux silhouettes opposées pour deux écoles opposées.

var _lame: MeshInstance3D = null
var _echos: Array[MeshInstance3D] = []


func monte() -> void:
	var rayon: float = maxf(dimensions.x, 0.25)
	_lame = bloc(Vector3(rayon * 3.2, rayon * 0.35, rayon * 1.1), 0.8)
	add_child(_lame)

	# Trois échos immobiles derrière, de plus en plus pâles : la lame laisse
	# une rémanence au lieu d'une traîne de braises.
	for i: int in 3:
		var e := bloc(Vector3(rayon * 2.6, rayon * 0.3, rayon * 0.9),
			0.3 - float(i) * 0.08)
		e.top_level = true
		add_child(e)
		_echos.append(e)


func anime(_part: float, delta: float) -> void:
	if _lame != null:
		_lame.rotation.z += delta * 16.0
	for i: int in _echos.size():
		# Ils rattrapent la lame avec du retard, ce qui les étale derrière elle
		# sans avoir à mémoriser la trajectoire.
		var vitesse: float = 9.0 - float(i) * 2.4
		_echos[i].global_position = _echos[i].global_position.lerp(
			global_position, clampf(delta * vitesse, 0.0, 1.0))
		_echos[i].rotation.z += delta * (11.0 - float(i) * 2.0)
