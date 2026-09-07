class_name TotemSignature
extends SpellSignature
## INVOCATION — un fût qui pousse, ceint d'anneaux qui tournent.
##
## Une balise doit se voir de loin et se distinguer d'une zone au sol : elle est
## VERTICALE et elle est PERMANENTE tant qu'elle vit. Le fût pousse une fois,
## puis ne bouge plus ; ce sont les anneaux qui tournent, à contresens l'un de
## l'autre, pour qu'on la voie active sans qu'elle s'agite.

const HAUTEUR: float = 2.6

var _bas: Array[MeshInstance3D] = []
var _haut: Array[MeshInstance3D] = []
var _fut: MeshInstance3D = null


func monte() -> void:
	var rayon: float = maxf(dimensions.x, 0.7)

	_fut = fut(rayon * 0.22, HAUTEUR, 6, 0.55)
	_fut.position = Vector3(0, HAUTEUR * 0.5, 0)
	add_child(_fut)

	# Deux anneaux à des hauteurs différentes : un seul se lirait comme un
	# accessoire, deux font une machine.
	_bas = anneau(rayon * 0.8, 0.16, 10, 0.4)
	for p: MeshInstance3D in _bas:
		p.position.y = HAUTEUR * 0.32
	_haut = anneau(rayon * 0.55, 0.14, 8, 0.5)
	for p: MeshInstance3D in _haut:
		p.position.y = HAUTEUR * 0.78

	for piece: MeshInstance3D in anneau(rayon, 0.2, 14, 0.28):
		piece.position.y = 0.07


func anime(part: float, delta: float) -> void:
	# La pousse : rapide, une fois, et terminée. Un totem qui pousserait tout du
	# long n'aurait jamais l'air posé.
	var pousse: float = smoothstep(0.0, 0.14, part)
	if _fut != null:
		_fut.scale.y = pousse
		_fut.position.y = HAUTEUR * 0.5 * pousse

	for p: MeshInstance3D in _bas:
		p.position = p.position.rotated(Vector3.UP, delta * 1.1)
		p.rotation.y += delta * 1.1
	for p: MeshInstance3D in _haut:
		p.position = p.position.rotated(Vector3.UP, -delta * 1.7)
		p.rotation.y -= delta * 1.7
