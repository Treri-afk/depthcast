class_name PostProcess
extends CanvasLayer
## Le passage plein écran de la trame pixel.
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
	mat.set_shader_parameter("niveaux_couleur", palette.pixel_niveaux_couleur)

	var voile := ColorRect.new()
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	voile.material = mat
	post.add_child(voile)
	return post
