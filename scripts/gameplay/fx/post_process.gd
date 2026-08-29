class_name PostProcess
extends MeshInstance3D
## Le passage plein écran : trame pixel, contour et filtre de couleur.
##
## C'est un quad dessiné dans la passe 3D, et non un calque d'interface : Godot
## refuse la lecture de profondeur dans un shader canvas_item, et sans elle on
## ne peut pas souligner les arêtes géométriques.
##
## Il s'attache à la caméra et écrit POSITION directement, donc il couvre
## l'écran quelle que soit son placement. Le HUD vit sur un CanvasLayer dessiné
## après la 3D : il n'est pas affecté, et le texte reste net.

const PIXEL := preload("res://shaders/pixel_fin.gdshader")


static func cree(palette: Palette) -> PostProcess:
	var post := PostProcess.new()

	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	post.mesh = quad

	# Dessiné en dernier, après toute la géométrie opaque.
	post.material_override = _materiau(palette)
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Sans volume englobant démesuré, le quad se fait éliminer par le frustum
	# dès que la caméra tourne — alors qu'il couvre l'écran par construction.
	post.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	post.extra_cull_margin = 16384.0
	return post


static func _materiau(palette: Palette) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PIXEL
	mat.render_priority = 100

	mat.set_shader_parameter("taille_bloc", palette.pixel_taille)
	mat.set_shader_parameter("contour_couleur", palette.encre)
	mat.set_shader_parameter("contour_epaisseur", palette.contour_epaisseur)
	mat.set_shader_parameter("contour_seuil", palette.contour_seuil)
	mat.set_shader_parameter("contour_seuil_profondeur", palette.contour_seuil_profondeur)
	mat.set_shader_parameter("contour_seuil_normale", palette.contour_seuil_normale)
	mat.set_shader_parameter("grain_force", palette.grain_force)
	mat.set_shader_parameter("filtre", palette.filtre)
	mat.set_shader_parameter("filtre_teinte", palette.filtre_teinte)
	mat.set_shader_parameter("filtre_ombre", palette.filtre_ombre)
	mat.set_shader_parameter("filtre_force", palette.filtre_force)
	return mat
