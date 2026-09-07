class_name DecoySignature
extends SpellSignature
## LEURRE — un mannequin qui appelle.
##
## Le leurre doit être pris pour quelqu'un, donc il a une SILHOUETTE : un tronc,
## deux bras, une tête. C'est le seul objet du jeu bâti à hauteur d'homme, et
## c'est exactement ce qui fait qu'un monstre s'y trompe et qu'un joueur
## comprend pourquoi.
##
## Il clignote — présent, absent, présent — pour qu'on voie tout de suite qu'il
## n'est pas réel. Le totem d'invocation, lui, ne clignote jamais : c'est ce qui
## distingue les deux d'un coup d'oeil malgré leur verticalité commune.

var _corps: Array[MeshInstance3D] = []
var _appels: Array[MeshInstance3D] = []


func monte() -> void:
	var tronc := bloc(Vector3(0.5, 1.05, 0.32), 0.62)
	tronc.position = Vector3(0, 0.95, 0)
	add_child(tronc)
	_corps.append(tronc)

	var tete := bloc(Vector3(0.34, 0.34, 0.32), 0.72)
	tete.position = Vector3(0, 1.7, 0)
	add_child(tete)
	_corps.append(tete)

	for cote: int in [-1, 1]:
		var bras := bloc(Vector3(0.16, 0.72, 0.16), 0.55)
		bras.position = Vector3(float(cote) * 0.38, 1.0, 0)
		add_child(bras)
		_corps.append(bras)

	# Trois anneaux qui montent en boucle : l'appel. Ils partent du sol et
	# s'évanouissent au-dessus de la tête, ce qui dit « regardez ici » sans
	# avoir à écrire un mot.
	for i: int in 3:
		var a: Array[MeshInstance3D] = anneau(0.75, 0.13, 9, 0.4)
		for p: MeshInstance3D in a:
			p.set_meta(&"vague", float(i) / 3.0)
			_appels.append(p)


func anime(part: float, _delta: float) -> void:
	# Le clignotement : deux valeurs franches, jamais un fondu. Un leurre qui
	# se fondrait doucement ressemblerait à un sort qui s'épuise.
	var visible_maintenant: bool = fmod(part * 9.0, 1.0) > 0.22
	for piece: MeshInstance3D in _corps:
		piece.visible = visible_maintenant

	for p: MeshInstance3D in _appels:
		var montee: float = fmod(part * 1.6 + float(p.get_meta(&"vague")), 1.0)
		p.position.y = montee * 2.4
		var large: float = 0.5 + montee * 1.1
		p.scale = Vector3(large, 1.0, large)
