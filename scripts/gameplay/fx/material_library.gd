class_name MaterialLibrary
extends RefCounted
## Fabrique les matériaux du jeu à partir des shaders de shaders/.
##
## Tout passe par ici pour une raison simple : la patte graphique doit pouvoir
## changer en un endroit. Si chaque bâtisseur créait son StandardMaterial3D,
## essayer un autre rendu demanderait de repasser sur dix fichiers.
##
## Les paramètres sont volontairement peu nombreux — une couleur, un rôle. Le
## reste est décidé ici pour rester cohérent d'un objet à l'autre.

const TOON := preload("res://shaders/toon.gdshader")
const CONTOUR := preload("res://shaders/contour.gdshader")
const DISSOLUTION := preload("res://shaders/dissolution.gdshader")

## Rôle d'une surface. Il décide de l'épaisseur du trait et de la vivacité du
## liseré : un mur ne doit pas attirer l'oeil autant qu'un monstre.
enum Role { DECOR, OBJET, CREATURE, INTERACTIF }

const _REGLAGES: Dictionary = {
	Role.DECOR:      {"contour": 0.0,   "lisere": 0.10, "bandes": 3},
	Role.OBJET:      {"contour": 0.018, "lisere": 0.22, "bandes": 3},
	Role.CREATURE:   {"contour": 0.030, "lisere": 0.55, "bandes": 4},
	Role.INTERACTIF: {"contour": 0.026, "lisere": 0.85, "bandes": 4},
}


## Matériau cel-shadé, avec contour selon le rôle.
static func toon(couleur: Color, role: Role = Role.DECOR) -> ShaderMaterial:
	var reglages: Dictionary = _REGLAGES[role]

	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("albedo", couleur)
	mat.set_shader_parameter("bandes", int(reglages["bandes"]))
	mat.set_shader_parameter("durete", 0.55)
	mat.set_shader_parameter("teinte_ombre", Color(0.16, 0.17, 0.26))
	mat.set_shader_parameter("force_lisere", float(reglages["lisere"]))
	mat.set_shader_parameter("couleur_lisere", _lisere(couleur, role))
	mat.set_shader_parameter("finesse_lisere", 3.2)

	var epaisseur: float = float(reglages["contour"])
	if epaisseur > 0.0:
		mat.next_pass = contour(epaisseur)
	return mat


## Trait d'encre autour d'une silhouette.
static func contour(epaisseur: float = 0.025,
		couleur := Color(0.05, 0.05, 0.08)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CONTOUR
	mat.set_shader_parameter("couleur", couleur)
	mat.set_shader_parameter("epaisseur", epaisseur)
	mat.set_shader_parameter("epaisseur_constante", true)
	return mat


## Matériau de désagrégation, piloté par `progression` de 0 à 1.
static func dissolution(couleur: Color, bord: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = DISSOLUTION
	mat.set_shader_parameter("albedo", couleur)
	mat.set_shader_parameter("couleur_bord", bord)
	mat.set_shader_parameter("progression", 0.0)
	mat.set_shader_parameter("largeur_bord", 0.08)
	mat.set_shader_parameter("echelle_bruit", 12.0)
	return mat


## Surface qui s'éclaire d'elle-même : projectiles, portail, socles.
static func lumineux(couleur: Color, force: float = 1.4) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("albedo", couleur)
	mat.set_shader_parameter("bandes", 2)
	mat.set_shader_parameter("durete", 0.2)
	mat.set_shader_parameter("emission_force", force)
	mat.set_shader_parameter("force_lisere", 0.9)
	mat.set_shader_parameter("couleur_lisere", couleur.lightened(0.4))
	return mat


## Le liseré emprunte à la couleur de l'objet pour le décor, et tire vers le
## froid sur les créatures : elles se détachent ainsi même sur un mur clair.
static func _lisere(couleur: Color, role: Role) -> Color:
	if role == Role.CREATURE:
		return Color(0.6, 0.78, 1.0)
	return couleur.lightened(0.55)
