class_name CometSignature
extends SpellSignature
## BOULE DE FEU — un noyau qui vrille, traîné de braises.
##
## Un projectile n'est pas une sphère lumineuse. Celui-ci a un NOYAU anguleux
## qui tourne sur deux axes, et une traîne de blocs qui le suivent avec du
## retard et rétrécissent. La traîne est ce qui donne la vitesse : sans elle,
## une bille qui traverse l'écran paraît lente.
##
## La signature se déplace avec le projectile ; elle ne connaît pas sa
## trajectoire, elle ne fait que réagir à son propre déplacement.

const TRAINE: int = 7

var _noyau: MeshInstance3D = null
var _traine: Array[MeshInstance3D] = []
var _passe: Array[Vector3] = []


func monte() -> void:
	var rayon: float = maxf(dimensions.x, 0.25)

	# Deux pointes opposées : une double pyramide, qui a des arêtes franches là
	# où une sphère n'offre au contour qu'un dégradé.
	_noyau = pointe(rayon * 1.25, rayon * 2.2, 0.85)
	add_child(_noyau)
	var envers := pointe(rayon * 1.25, rayon * 2.2, 0.85)
	envers.rotation.z = PI
	_noyau.add_child(envers)

	for i: int in TRAINE:
		var t: float = float(i) / float(TRAINE)
		var b := bloc(Vector3.ONE * rayon * (1.3 - t), 0.55 - t * 0.4)
		# Détachés du noyau : ils doivent rester où le projectile ÉTAIT, pas le
		# suivre comme un enfant de scène.
		b.top_level = true
		add_child(b)
		_traine.append(b)


func _process(delta: float) -> void:
	super._process(delta)
	# La mémoire des positions passées, une par image. C'est ce qui fait une
	# traîne qui suit vraiment la trajectoire, y compris dans un virage.
	_passe.push_front(global_position)
	if _passe.size() > TRAINE * 3:
		_passe.resize(TRAINE * 3)
	for i: int in _traine.size():
		var index: int = mini((i + 1) * 3, _passe.size() - 1)
		if index >= 0:
			_traine[i].global_position = _passe[index]


func anime(_part: float, delta: float) -> void:
	if _noyau != null:
		_noyau.rotation.y += delta * 7.0
		_noyau.rotation.x += delta * 4.5
	for i: int in _traine.size():
		_traine[i].rotation += Vector3(delta * 3.0, delta * 2.2, 0) * float(i + 1)
