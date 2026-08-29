class_name Emote
extends Node3D
## Une bulle au-dessus d'une créature : ce qu'elle est en train de comprendre.
##
## Le système est volontairement plus général que son seul usage d'aujourd'hui.
## Une émote a un genre, une couleur, un remplissage et une façon d'éclater ;
## ajouter « ? » quand un monstre perd la trace du joueur, ou « ! » quand il
## repère un coéquipier, ne demandera qu'une ligne dans la table ci-dessous.
##
## Le rectangle jaune tient lieu de point d'exclamation en attendant la
## direction artistique. Le jour où un vrai signe arrive, il se pose ICI et
## nulle part ailleurs — c'est exactement pourquoi ceci est une classe plutôt
## que trois nœuds bricolés dans le monstre.
##
## Elle n'est PAS enfant de la créature, et c'est délibéré : l'avatar se fait
## écraser à chaque coup encaissé et vriller quand il est projeté. Une émote
## accrochée dessus hériterait des deux, et une bulle qui se déforme quand son
## porteur encaisse ne se lit plus. Elle le suit, elle ne lui appartient pas.

enum Genre { SURPRISE }

const HAUTEUR: float = 0.55
const LARGEUR: float = 0.17
const MARGE: float = 0.045

## Genre → couleur. Une ligne par émote, et c'est tout ce qu'il y a à ajouter.
const COULEURS: Dictionary = {
	Genre.SURPRISE: &"emote_surprise",
}

## Ce que l'émote suit, et à quelle hauteur au-dessus.
var cible: Node3D = null
var decalage: Vector3 = Vector3.UP

var _jauge: MeshInstance3D
var _remplissage: float = 0.0


static func cree(genre: Genre, suit: Node3D, hauteur: Vector3) -> Emote:
	var emote := Emote.new()
	emote.cible = suit
	emote.decalage = hauteur
	emote._monte(genre)
	return emote


func _ready() -> void:
	# Le placement attend l'entrée dans l'arbre : une position globale lue ou
	# écrite avant n'a pas de sens, et le moteur le dit assez fort.
	_suit()


## Part remplie, de 0 à 1. C'est l'attention de la créature rendue visible :
## le joueur voit qu'elle est en train de comprendre AVANT qu'elle ait compris,
## ce qui lui laisse une fenêtre pour agir.
var remplissage: float:
	get:
		return _remplissage
	set(valeur):
		_remplissage = clampf(valeur, 0.0, 1.0)
		if _jauge != null:
			_jauge.scale.y = maxf(_remplissage, 0.001)


func _monte(genre: Genre) -> void:
	var teinte: Color = Content.palette.get(COULEURS[genre])

	var fond := _plaque(LARGEUR + MARGE * 2.0, HAUTEUR + MARGE * 2.0,
		Content.palette.encre)
	fond.position = Vector3(0, (HAUTEUR + MARGE * 2.0) * 0.5, 0)
	add_child(fond)

	# La jauge monte depuis le bas : son maillage est décalé vers le haut, donc
	# la mettre à l'échelle en Y la fait grandir au lieu de la centrer.
	_jauge = _plaque(LARGEUR, HAUTEUR, teinte)
	(_jauge.mesh as QuadMesh).center_offset = Vector3(0, HAUTEUR * 0.5, 0)
	_jauge.position = Vector3(0, MARGE, 0.01)
	_jauge.scale.y = 0.001
	add_child(_jauge)


func _plaque(largeur: float, hauteur: float, teinte: Color) -> MeshInstance3D:
	var visuel := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(largeur, hauteur)
	visuel.mesh = quad

	var mat := StandardMaterial3D.new()
	# Non éclairée : une émote est un signe posé sur l'image, pas une surface du
	# décor. L'éclairer la ferait disparaître dans les salles sombres, c'est-à-
	# dire exactement là où on en a le plus besoin.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = teinte
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	visuel.material_override = mat
	return visuel


func _process(_delta: float) -> void:
	if cible == null or not is_instance_valid(cible):
		queue_free()
		return
	_suit()


func _suit() -> void:
	if cible == null or not is_instance_valid(cible):
		return
	global_position = cible.global_position + decalage
	_fait_face()


## Orientée à la main plutôt qu'en mode panneau d'affichage : le mode intégré
## se combine mal avec une mise à l'échelle non uniforme, et la jauge en est
## une. On garde aussi l'émote DROITE — inclinée, elle cesse d'être un signe.
func _fait_face() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var vers: Vector3 = camera.global_position - global_position
	vers.y = 0.0
	if vers.length_squared() < 0.0001:
		return
	look_at(global_position - vers, Vector3.UP)


## Le sursaut au moment où la créature comprend. C'est ce battement qui fait la
## différence entre une jauge qui se remplit et une réaction.
func eclate() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.6, 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.16)


func efface() -> void:
	cible = null
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.12)
	tween.tween_callback(queue_free)
