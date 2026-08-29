class_name RangeStation
extends LabStation
## Portique de mesure : des bornes tous les quatre mètres.
##
## Le poste le plus bête du terrain, et probablement le plus utile. Une portée
## de sort, une distance de projection, un rayon de souffle : tout ça se règle
## en nombres dans le Tuning, et rien ne dit à quoi douze mètres ressemblent
## tant qu'on ne les a pas sous les yeux.

const PAS: float = 4.0
const BORNES: int = 6


func titre() -> String:
	return "Portique de mesure"


func installe() -> void:
	pancarte("PORTIQUE DE MESURE\nchaque borne = 4 m", 3.4, 34)
	for i: int in range(1, BORNES + 1):
		_borne(PAS * float(i))


func _borne(distance: float) -> void:
	var visuel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 2.2, 0.22)
	visuel.mesh = mesh
	visuel.position = Vector3(distance, 1.1, 0)
	# Une borne sur deux plus claire : on compte de huit en huit sans lire.
	var pale: bool = int(distance / PAS) % 2 == 0
	visuel.material_override = MaterialLibrary.aplat(
		Content.palette.pilier if pale else Content.palette.mur,
		MaterialLibrary.Role.OBJET)
	add_child(visuel)

	var label := Label3D.new()
	label.text = "%d m" % int(distance)
	label.font_size = 34
	label.pixel_size = 0.004
	label.position = Vector3(distance, 2.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Content.palette.lisere_blanc
	label.outline_size = 8
	label.outline_modulate = Content.palette.encre
	add_child(label)
