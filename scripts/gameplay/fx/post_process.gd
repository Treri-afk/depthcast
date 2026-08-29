class_name PostProcess
extends CanvasLayer
## Le passage plein écran : trame pixel, contour et filtre de couleur.
##
## Posé sur un calque NÉGATIF : il est donc dessiné avant le HUD, qui reste net.
## Pixelliser du texte le rendrait illisible sans rien apporter au style.

const PIXEL := preload("res://shaders/pixel_fin.gdshader")

## Calque négatif : avant le HUD (0) et avant l'écran de fin (10).
const CALQUE: int = -1


static func cree(palette: Palette) -> PostProcess:
	var post := PostProcess.new()
	post.layer = CALQUE

	var mat := ShaderMaterial.new()
	mat.shader = PIXEL
	mat.set_shader_parameter("taille_bloc", palette.pixel_taille)
	mat.set_shader_parameter("contour_couleur", palette.encre)
	mat.set_shader_parameter("contour_epaisseur", palette.contour_epaisseur)
	mat.set_shader_parameter("contour_seuil", palette.contour_seuil)
	mat.set_shader_parameter("grain_force", palette.grain_force)
	mat.set_shader_parameter("filtre", palette.filtre)
	mat.set_shader_parameter("filtre_teinte", palette.filtre_teinte)
	mat.set_shader_parameter("filtre_ombre", palette.filtre_ombre)
	mat.set_shader_parameter("filtre_force", palette.filtre_force)

	var voile := ColorRect.new()
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	voile.material = mat
	post.add_child(voile)
	return post
