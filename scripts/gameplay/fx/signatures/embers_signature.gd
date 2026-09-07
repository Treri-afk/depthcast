class_name EmbersSignature
extends SpellSignature
## TRAÎNÉE ARDENTE — des plaques de braise qui crépitent et s'affaissent.
##
## Le sol embrasé n'est pas une flaque : c'est une surface qui se CRAQUELLE.
## Des dalles irrégulières, à des hauteurs légèrement différentes, avec des
## langues courtes qui montent et retombent entre elles. Ce qui distingue ça du
## gel — même emprise, même sol — c'est que la braise bouge sans arrêt là où la
## glace se fige.

const DALLES: int = 9
const LANGUES: int = 7

var _langues: Array[MeshInstance3D] = []


func monte() -> void:
	var rayon: float = maxf(dimensions.x, 0.8)

	for i: int in DALLES:
		var angle: float = float(i) * 2.399963
		var d: float = rayon * sqrt(float(i) / float(DALLES)) * 0.9
		var dalle := bloc(Vector3(rayon * 0.62, EPAISSEUR, rayon * 0.52), 0.42)
		dalle.position = Vector3(cos(angle) * d, EPAISSEUR * 0.5, sin(angle) * d)
		dalle.rotation.y = angle * 1.7
		add_child(dalle)

	for i: int in LANGUES:
		var angle: float = TAU * float(i) / float(LANGUES) + 0.4
		var d: float = rayon * 0.55
		var langue := bloc(Vector3(0.2, 0.7, 0.2), 0.6)
		langue.position = Vector3(cos(angle) * d, 0.35, sin(angle) * d)
		add_child(langue)
		_langues.append(langue)
		langue.set_meta(&"phase", float(i) * 1.31)


func anime(part: float, _delta: float) -> void:
	var temps: float = part * 26.0
	for i: int in _langues.size():
		var phase: float = float(_langues[i].get_meta(&"phase"))
		# Crépiter, pas onduler : la valeur absolue donne des reprises sèches
		# là où un sinus pur ferait une respiration.
		var h: float = 0.25 + absf(sin(temps * 0.6 + phase)) * 1.0
		_langues[i].scale = Vector3(1.0 - h * 0.2, h, 1.0 - h * 0.2)
		_langues[i].position.y = 0.35 * h
