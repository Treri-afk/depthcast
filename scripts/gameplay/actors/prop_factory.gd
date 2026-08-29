class_name PropFactory
extends RefCounted
## Fabrique le mobilier projetable. Une caisse est une caisse partout.
##
## Extraite du meublage parce que le terrain d'essai en pose aussi. Deux
## définitions d'un tonneau, et la masse qu'on calibre dans le donjon ne serait
## pas celle qu'on mesure au banc — le banc mentirait sans prévenir.

enum Genre { CAISSE, TONNEAU, TABLE }

## Ce qu'est chaque meuble, en trois nombres. Les points de vie découlent de la
## masse : une table encaisse plus qu'un tonneau parce qu'elle est plus lourde,
## et non parce qu'on l'a décidé séparément.
const MODELES: Dictionary = {
	Genre.CAISSE: {
		"taille": Vector3(1.0, 1.0, 1.0), "masse": 7.0, "cylindrique": false,
	},
	Genre.TONNEAU: {
		"taille": Vector3(0.9, 1.2, 0.9), "masse": 9.0, "cylindrique": true,
	},
	Genre.TABLE: {
		"taille": Vector3(2.2, 0.25, 1.2), "masse": 14.0, "cylindrique": false,
	},
}


static func couleur(genre: Genre) -> Color:
	var p: Palette = Content.palette
	match genre:
		Genre.TONNEAU:
			return p.tonneau
		Genre.TABLE:
			return p.table
	return p.caisse


static func nom(genre: Genre) -> String:
	match genre:
		Genre.TONNEAU:
			return "tonneau"
		Genre.TABLE:
			return "table"
	return "caisse"


static func cree(genre: Genre, pos: Vector3) -> PropDestructible:
	var modele: Dictionary = MODELES[genre]
	var taille: Vector3 = modele["taille"]
	var masse: float = modele["masse"]
	var teinte: Color = couleur(genre)

	var corps := PropDestructible.new()
	corps.position = Vector3(pos.x, taille.y * 0.5 + 0.1, pos.z)
	corps.mass = masse
	corps.couleur = teinte
	# Un objet plus lourd encaisse plus : une table ne part pas comme un tonneau.
	corps.pv = int(masse * 2.2)
	corps.linear_damp = 1.6
	corps.angular_damp = 2.4

	var forme := CollisionShape3D.new()
	var visuel := MeshInstance3D.new()
	visuel.name = "Mesh"

	if bool(modele["cylindrique"]):
		var cyl := CylinderShape3D.new()
		cyl.radius = taille.x * 0.5
		cyl.height = taille.y
		forme.shape = cyl
		var mesh := CylinderMesh.new()
		mesh.top_radius = taille.x * 0.5
		mesh.bottom_radius = taille.x * 0.5
		mesh.height = taille.y
		visuel.mesh = mesh
	else:
		var boite := BoxShape3D.new()
		boite.size = taille
		forme.shape = boite
		var mesh := BoxMesh.new()
		mesh.size = taille
		visuel.mesh = mesh

	visuel.material_override = MaterialLibrary.aplat(teinte, MaterialLibrary.Role.OBJET)
	corps.add_child(forme)
	corps.add_child(visuel)
	return corps
