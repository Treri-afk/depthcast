class_name FxLibrary
extends RefCounted
## Les petits visuels partagés par les sorts : anneaux, cônes, marqueurs.
##
## Regroupés ici parce qu'ils étaient dupliqués dans chaque comportement. Ils
## seront remplacés par de vrais VFX quand la direction artistique sera posée ;
## d'ici là ils servent surtout à rendre chaque sort lisible.

## Ce qui se passe au point de contact. Même raison d'être que les allures de
## zone : en ligne claire, un impact ne peut se distinguer que par sa FORME et
## par la direction de ce qui en part. Tous les sorts faisaient jusqu'ici le
## même éclair, donc toucher avec une boule de feu ou avec un éclat de givre
## produisait exactement la même image.
enum Impact {
	ECLAT,    ## une bouffée brève et ronde — feu, énergie
	ECLATS,   ## des esquilles projetées en étoile — givre, pierre
	ONDE,     ## un anneau plat qui s'ouvre au sol — force, souffle
	BOUFFEE,  ## une colonne qui monte et se dissipe — ombre, poison
}

var monde: Node3D


func _init(p_monde: Node3D) -> void:
	monde = p_monde


## Lampe portée par un sort. Un projectile qui traverse une salle sans la faire
## réagir n'a aucun poids — et dans un couloir sombre, c'est aussi ce qui rend
## la scène lisible au moment précis où on en a besoin.
func lampe(couleur: Color, energie: float = -1.0, portee: float = -1.0) -> OmniLight3D:
	var p: Palette = Content.palette
	var lampe_node := OmniLight3D.new()
	lampe_node.light_color = couleur
	lampe_node.light_energy = energie if energie > 0.0 else p.lumiere_sort_energie
	lampe_node.omni_range = portee if portee > 0.0 else p.lumiere_sort_portee
	# Pas d'ombres portées par les sorts : quatre projectiles en vol feraient
	# quatre jeux d'ombres contradictoires, et le coût est disproportionné.
	lampe_node.shadow_enabled = false
	return lampe_node


## Éclair bref à un endroit donné : nova, cône, impact.
func eclair(position: Vector3, couleur: Color, duree: float = 0.22,
		energie: float = 5.0, portee: float = 12.0) -> void:
	var lampe_node := lampe(couleur, energie, portee)
	lampe_node.position = position
	monde.add_child(lampe_node)

	var tween := monde.create_tween()
	tween.tween_property(lampe_node, "light_energy", 0.0, duree)
	tween.tween_callback(lampe_node.queue_free)


## Marque un point de contact. Le seul appel dont les comportements ont besoin :
## la forme vient de la donnée du sort, pas d'un choix écrit dans chaque
## comportement.
func impact(genre: Impact, position: Vector3, couleur: Color,
		normale: Vector3 = Vector3.UP) -> void:
	eclair(position, couleur, 0.16, 3.2, 5.0)
	match genre:
		Impact.ECLATS:
			_esquilles(position, couleur, normale)
		Impact.ONDE:
			anneau(position, 2.6, couleur)
		Impact.BOUFFEE:
			_bouffee(position, couleur)
		_:
			_eclat(position, couleur)


## Une bouffée ronde : la forme la plus neutre, celle du feu et de l'énergie.
func _eclat(position: Vector3, couleur: Color) -> void:
	var visuel := sphere_lumineuse(0.35, couleur)
	var mat := _materiau_emissif(couleur, true)
	visuel.material_override = mat
	visuel.position = position
	monde.add_child(visuel)

	var tween := monde.create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuel, "scale", Vector3.ONE * 2.6, 0.22)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.24)
	tween.chain().tween_callback(visuel.queue_free)


## Des esquilles projetées en étoile autour de la normale. C'est la direction
## qui les distingue d'une bouffée : elles partent DE la surface touchée.
func _esquilles(position: Vector3, couleur: Color, normale: Vector3) -> void:
	var base: Basis = Basis.looking_at(normale if normale.length_squared() > 0.01
		else Vector3.UP)
	for i: int in 6:
		var angle: float = TAU * float(i) / 6.0
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 0.11
		mesh.height = 0.6
		mesh.radial_segments = 4

		var eclat := MeshInstance3D.new()
		eclat.mesh = mesh
		var mat := _materiau_emissif(couleur, true)
		eclat.material_override = mat
		eclat.position = position
		var sens: Vector3 = (base * Vector3(cos(angle), sin(angle), 0.9)).normalized()
		eclat.look_at_from_position(position, position + sens, Vector3.UP)
		eclat.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		monde.add_child(eclat)

		var tween := monde.create_tween()
		tween.set_parallel(true)
		tween.tween_property(eclat, "position", position + sens * 1.7, 0.3)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.32)
		tween.chain().tween_callback(eclat.queue_free)


## Une colonne qui monte et se dissipe : ce qui reste après, plutôt que le coup.
func _bouffee(position: Vector3, couleur: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.55
	mesh.bottom_radius = 0.2
	mesh.height = 1.2
	mesh.radial_segments = 8

	var visuel := MeshInstance3D.new()
	visuel.mesh = mesh
	var mat := _materiau_emissif(couleur, true)
	mat.albedo_color.a = 0.4
	visuel.material_override = mat
	visuel.position = position
	monde.add_child(visuel)

	var tween := monde.create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuel, "position", position + Vector3(0, 1.6, 0), 0.5)
	tween.tween_property(visuel, "scale", Vector3(1.8, 1.0, 1.8), 0.5)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(visuel.queue_free)


func sphere_lumineuse(rayon: float, couleur: Color) -> MeshInstance3D:
	var visuel := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = rayon
	mesh.height = rayon * 2.0
	visuel.mesh = mesh
	visuel.material_override = MaterialLibrary.lumineux(couleur)
	return visuel


## Onde circulaire qui s'évase depuis un point.
func anneau(centre: Vector3, rayon: float, couleur: Color) -> void:
	var visuel := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = rayon * 0.85
	mesh.outer_radius = rayon
	visuel.mesh = mesh
	var mat := _materiau_emissif(couleur, true)
	visuel.material_override = mat
	visuel.position = centre - Vector3(0, 0.8, 0)
	visuel.scale = Vector3(0.3, 1, 0.3)
	monde.add_child(visuel)

	var tween := monde.create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuel, "scale", Vector3.ONE, 0.3)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(visuel.queue_free)


func cone(origine: Vector3, direction: Vector3, portee: float, couleur: Color) -> void:
	var visuel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = portee * 0.55
	mesh.bottom_radius = 0.2
	mesh.height = portee
	visuel.mesh = mesh
	var mat := _materiau_emissif(couleur, true)
	mat.albedo_color.a = 0.5
	visuel.material_override = mat
	visuel.position = origine + direction * (portee * 0.5)
	visuel.rotation = Vector3(deg_to_rad(90), atan2(direction.x, direction.z), 0)
	monde.add_child(visuel)

	var tween := monde.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tween.tween_callback(visuel.queue_free)


## Marque un point qui vient d'être quitté ou atteint (téléportation).
func marqueur(pos: Vector3, couleur: Color) -> void:
	var visuel := sphere_lumineuse(0.6, couleur)
	var mat := _materiau_emissif(couleur, true)
	visuel.material_override = mat
	visuel.position = pos
	monde.add_child(visuel)

	var tween := monde.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(visuel.queue_free)


## Les effets translucides gardent un matériau standard : le shader de ligne
## claire ne gère pas l'alpha. Ils sont en revanche NON ÉCLAIRÉS, sinon ils
## recevraient un dégradé et réintroduiraient la troisième valeur qu'on
## s'interdit partout ailleurs.
func _materiau_emissif(couleur: Color, transparent: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = couleur
	mat.emission_enabled = true
	mat.emission = couleur
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
