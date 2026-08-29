class_name MouseLook
extends RefCounted
## Regard à la souris : lacet sur le corps, tangage sur la tête.
##
## Les deux sont séparés à dessein. Appliquer le tangage au corps ferait
## basculer le personnage au lieu de lui faire lever les yeux — c'est l'erreur
## classique de la vue subjective.

## Au-delà, on se casse la nuque. En radians.
const PITCH_MAX: float = 1.45

var corps: Node3D
var tete: Node3D
var sensibilite: float = 0.0022


func _init(p_corps: Node3D, p_tete: Node3D, p_sensibilite: float) -> void:
	corps = p_corps
	tete = p_tete
	sensibilite = p_sensibilite


func applique(mouvement: InputEventMouseMotion) -> void:
	corps.rotate_y(-mouvement.relative.x * sensibilite)
	tete.rotation.x = clampf(
		tete.rotation.x - mouvement.relative.y * sensibilite, -PITCH_MAX, PITCH_MAX)


## Le curseur est capturé pour viser. Le relâcher permet de cliquer l'interface
## sans quitter la partie.
static func capture(actif: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if actif else Input.MOUSE_MODE_VISIBLE


static func est_capture() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
