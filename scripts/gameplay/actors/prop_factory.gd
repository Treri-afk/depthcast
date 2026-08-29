class_name PropFactory
extends RefCounted
## Fabrique le mobilier projetable. Une caisse est une caisse partout.
##
## Extraite du meublage parce que le terrain d'essai en pose aussi. Deux
## définitions d'un tonneau, et la masse qu'on calibre dans le donjon ne serait
## pas celle qu'on mesure au banc — le banc mentirait sans prévenir.

enum Genre { CAISSE, TONNEAU, TABLE, TONNEAU_EXPLOSIF, BALISE_LEURRE }

## Ce qu'est chaque meuble, en trois nombres. Les points de vie découlent de la
## masse : une table encaisse plus qu'un tonneau parce qu'elle est plus lourde,
## et non parce qu'on l'a décidé séparément.
const MODELES: Dictionary = {
	Genre.CAISSE: {
		"taille": Vector3(1.0, 1.0, 1.0), "masse": 7.0, "cylindrique": false,
		"portable": true,
	},
	Genre.TONNEAU: {
		"taille": Vector3(0.9, 1.2, 0.9), "masse": 9.0, "cylindrique": true,
		"portable": true,
	},
	Genre.TABLE: {
		"taille": Vector3(2.2, 0.25, 1.2), "masse": 14.0, "cylindrique": false,
		"portable": false,
	},
	# Plus léger qu'un tonneau ordinaire, donc bien moins résistant : il doit
	# partir au premier projectile. Un baril qu'il faut viser trois fois n'est
	# plus une opportunité, c'est une corvée.
	Genre.TONNEAU_EXPLOSIF: {
		"taille": Vector3(0.9, 1.2, 0.9), "masse": 6.0, "cylindrique": true,
		"portable": true,
	},
	# Légère, donc elle part loin quand on la lance. C'est voulu : une balise
	# qu'on ne peut poser qu'à ses pieds ne détourne rien de dangereux.
	Genre.BALISE_LEURRE: {
		"taille": Vector3(0.55, 0.55, 0.55), "masse": 3.5, "cylindrique": false,
		"portable": true,
	},
}


static func couleur(genre: Genre) -> Color:
	var p: Palette = Content.palette
	match genre:
		Genre.TONNEAU:
			return p.tonneau
		Genre.TABLE:
			return p.table
		Genre.TONNEAU_EXPLOSIF:
			return p.tonneau_explosif
		Genre.BALISE_LEURRE:
			return p.balise_leurre
	return p.caisse


static func nom(genre: Genre) -> String:
	match genre:
		Genre.TONNEAU:
			return "tonneau"
		Genre.TABLE:
			return "table"
		Genre.TONNEAU_EXPLOSIF:
			return "tonneau explosif"
		Genre.BALISE_LEURRE:
			return "balise de leurre"
	return "caisse"


static func cree(genre: Genre, pos: Vector3) -> PropDestructible:
	var modele: Dictionary = MODELES[genre]
	var taille: Vector3 = modele["taille"]
	var masse: float = modele["masse"]
	var teinte: Color = couleur(genre)

	var explosif: bool = genre == Genre.TONNEAU_EXPLOSIF
	var balise: bool = genre == Genre.BALISE_LEURRE
	# Construit une seule fois, dans la bonne classe. En partir d'un
	# PropDestructible pour le remplacer ensuite abandonnait un corps par
	# tonneau créé — un Node non ajouté à l'arbre ne se libère pas tout seul.
	var corps: PropDestructible
	if explosif:
		var tonneau := ExplosiveProp.new()
		ExplosiveProp.regle(tonneau, Content.tuning)
		corps = tonneau
	elif balise:
		var beacon := LureBeacon.new()
		LureBeacon.regle(beacon, Content.tuning)
		corps = beacon
	else:
		corps = PropDestructible.new()
	corps.position = Vector3(pos.x, taille.y * 0.5 + 0.1, pos.z)
	corps.mass = masse
	corps.couleur = teinte
	# Un objet plus lourd encaisse plus : une table ne part pas comme un tonneau.
	corps.pv = int(masse * 2.2)
	corps.portable = bool(modele.get("portable", false))
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
	if explosif or balise:
		corps.add_child(_bouchon(taille, teinte))
	return corps


## La charge, posée sur le tonneau. La couleur suffit de près, pas de loin :
## une salle encombrée avale une nuance, jamais une source lumineuse. Un baril
## qu'on ne repère qu'une fois à côté n'est pas une opportunité tactique.
static func _bouchon(taille: Vector3, teinte: Color) -> MeshInstance3D:
	var visuel := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = taille.x * 0.24
	mesh.height = taille.x * 0.48
	visuel.mesh = mesh
	visuel.position = Vector3(0, taille.y * 0.5, 0)
	visuel.material_override = MaterialLibrary.lumineux(teinte, 2.2)
	return visuel
