class_name ShadowGateSignature
extends SpellSignature
## PAS D'OMBRE — un cadre qui s'ouvre et se referme.
##
## La téléportation et le voile sont tous deux de l'école d'Ombre, et ils ne
## doivent pas se ressembler. Le voile DÉFAIT un corps ; celui-ci ouvre une
## PORTE : deux montants et un linteau qui jaillissent du sol, s'écartent le
## temps du passage, puis claquent.
##
## Un cadre plutôt qu'un trou : en ligne claire, un trou noir posé au sol est
## indiscernable d'une ombre, et l'on ne verrait rien du tout.

const HAUTEUR: float = 2.5
const LARGEUR: float = 1.5

var _gauche: MeshInstance3D = null
var _droit: MeshInstance3D = null
var _linteau: MeshInstance3D = null


func monte() -> void:
	_gauche = bloc(Vector3(0.2, HAUTEUR, 0.2), 0.7)
	_droit = bloc(Vector3(0.2, HAUTEUR, 0.2), 0.7)
	_linteau = bloc(Vector3(LARGEUR + 0.2, 0.2, 0.2), 0.7)
	add_child(_gauche)
	add_child(_droit)
	add_child(_linteau)


func anime(part: float, _delta: float) -> void:
	# Ouverture sèche, maintien, fermeture sèche. Le battement en cloche fait
	# une PORTE ; une simple disparition ferait un fondu de plus.
	var battant: float = sin(clampf(part, 0.0, 1.0) * PI)
	var doux: float = battant * battant * (3.0 - 2.0 * battant)
	var ecart: float = LARGEUR * 0.5 * doux

	_gauche.position = Vector3(-ecart, HAUTEUR * 0.5, 0)
	_droit.position = Vector3(ecart, HAUTEUR * 0.5, 0)
	_gauche.scale.y = doux
	_droit.scale.y = doux
	_gauche.position.y = HAUTEUR * 0.5 * doux
	_droit.position.y = HAUTEUR * 0.5 * doux

	_linteau.position = Vector3(0, HAUTEUR * doux, 0)
	_linteau.scale.x = doux
