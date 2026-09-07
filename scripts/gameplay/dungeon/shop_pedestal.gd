class_name ShopPedestal
extends Node3D
## Un socle du marchand : un objet posé au sol qu'on va chercher.
##
## Sceller un sort est ainsi un geste dans l'espace plutôt qu'une case à cocher
## dans un menu — c'est ce qui donne du poids à la décision.

enum Genre { SCEAU, SOIN, VIGUEUR, LEURRE, PAGE }

var genre: Genre = Genre.SCEAU
var slot_index: int = 0
var cout: int = 0
## L'école dont la page vient. Vide pour tous les autres genres.
var ecole_id: StringName = &""
var valeur: int = 0
var achete: bool = false

var _objet: Node3D


static func cree(fx: FxLibrary, pos: Vector3, genre_voulu: Genre,
		couleur: Color) -> ShopPedestal:
	var socle := ShopPedestal.new()
	socle.genre = genre_voulu
	socle.position = Vector3(pos.x, 0.0, pos.z)

	var pied := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.55
	mesh.bottom_radius = 0.7
	mesh.height = 0.9
	pied.mesh = mesh
	pied.position = Vector3(0, 0.45, 0)
	pied.material_override = MaterialLibrary.aplat(Content.palette.socle,
		MaterialLibrary.Role.INTERACTIF)
	socle.add_child(pied)

	var objet := fx.sphere_lumineuse(0.32, couleur)
	objet.position = Vector3(0, 1.35, 0)
	socle.add_child(objet)
	socle._objet = objet
	return socle


func consomme() -> void:
	achete = true
	if is_instance_valid(_objet):
		_objet.queue_free()
