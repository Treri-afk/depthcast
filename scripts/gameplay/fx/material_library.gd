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

## Le rôle ne pilote plus le trait — celui-ci est tracé en espace écran par le
## post-traitement, d'un seul poids et sans déchirure. Il reste utile pour
## nuancer la matière : une créature est légèrement plus contrastée qu'un mur,
## ce qui la fait ressortir sans ajouter de ligne.
enum Role { DECOR, OBJET, CREATURE, INTERACTIF }

const _CONTRASTE: Dictionary = {
	Role.DECOR:      0.00,
	Role.OBJET:      0.04,
	Role.INTERACTIF: 0.08,
	Role.CREATURE:   0.12,
}


static func palette() -> Palette:
	return Content.palette


## Matériau standard : deux valeurs, ombre commune, trait selon le rôle.
static func aplat(couleur: Color, role: Role = Role.DECOR) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = LIGNE_CLAIRE
	# Un rien plus lumineux pour ce qui compte : la hiérarchie passe par le
	# contraste plutôt que par l'épaisseur d'un trait.
	var gain: float = float(_CONTRASTE[role])
	_applique_regles(mat, couleur.lightened(gain))
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
