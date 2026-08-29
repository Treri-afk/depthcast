class_name MaterialLibrary
extends RefCounted
## Fabrique tous les matériaux du jeu — ligne claire.
##
## Tout passe par ici, et les couleurs viennent toutes de la palette. C'est ce
## qui rend l'identité tenable : une couleur écrite en dur dans un bâtisseur est
## une entorse, et trois entorses suffisent à faire disparaître un style.
##
## Le liseré clair et le trait d'encre sont obtenus par deux coques inversées
## enchaînées : objet, puis coque claire fine, puis coque d'encre plus épaisse.

const LIGNE_CLAIRE := preload("res://shaders/ligne_claire.gdshader")
const CONTOUR := preload("res://shaders/contour.gdshader")
const DISSOLUTION := preload("res://shaders/dissolution.gdshader")

## Le rôle décide de l'épaisseur du trait. Un mur ne doit pas être cerné aussi
## fort qu'une créature : dans un couloir, cent blocs soulignés font une bouillie.
enum Role { DECOR, OBJET, CREATURE, INTERACTIF }

const _TRAIT: Dictionary = {
	Role.DECOR:      {"encre": 0.0,   "lisere": 0.0},
	Role.OBJET:      {"encre": 0.016, "lisere": 0.007},
	Role.CREATURE:   {"encre": 0.030, "lisere": 0.014},
	Role.INTERACTIF: {"encre": 0.024, "lisere": 0.011},
}


static func palette() -> Palette:
	return Content.palette


## Matériau standard : deux valeurs, ombre commune, trait selon le rôle.
static func aplat(couleur: Color, role: Role = Role.DECOR) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = LIGNE_CLAIRE
	_applique_regles(mat, couleur)

	# « trait » est un mot réservé de GDScript : on nomme la variable autrement.
	var reglage: Dictionary = _TRAIT[role]
	var encre: float = float(reglage["encre"])
	if encre > 0.0:
		# Ordre : liseré clair d'abord, encre par-dessus. La coque d'encre est
		# la plus épaisse, donc elle encadre la claire.
		var clair := coque(float(reglage["lisere"]), palette().lisere_blanc)
		clair.next_pass = coque(encre, palette().encre)
		mat.next_pass = clair
	return mat


## Une coque inversée : le maillage dilaté, faces arrière seulement.
static func coque(epaisseur: float, couleur: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CONTOUR
	mat.set_shader_parameter("couleur", couleur)
	mat.set_shader_parameter("epaisseur", epaisseur)
	mat.set_shader_parameter("epaisseur_constante", true)
	return mat


## Surface qui s'éclaire d'elle-même : sorts, portail, objets du marchand.
## C'est la seule chose du jeu qui a le droit d'être vive.
static func lumineux(couleur: Color, force: float = 1.5) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = LIGNE_CLAIRE
	_applique_regles(mat, couleur)
	mat.set_shader_parameter("emission_force", force)
	mat.set_shader_parameter("seuil", 0.0)
	return mat


## Désagrégation à la mort, avec un bord incandescent.
static func dissolution(couleur: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = DISSOLUTION
	mat.set_shader_parameter("albedo", couleur)
	mat.set_shader_parameter("couleur_bord", palette().lisere_blanc)
	mat.set_shader_parameter("progression", 0.0)
	mat.set_shader_parameter("largeur_bord", 0.08)
	mat.set_shader_parameter("echelle_bruit", 12.0)
	return mat


## L'ombre et son mélange sont posés au même endroit pour tout le jeu. C'est
## littéralement la règle numéro deux de la ligne claire.
static func _applique_regles(mat: ShaderMaterial, couleur: Color) -> void:
	var p: Palette = palette()
	mat.set_shader_parameter("albedo", couleur)
	mat.set_shader_parameter("couleur_ombre", p.ombre)
	mat.set_shader_parameter("melange_ombre", p.melange_ombre)
	mat.set_shader_parameter("seuil", 0.32)
	mat.set_shader_parameter("nettete", 0.02)
