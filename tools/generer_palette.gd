extends SceneTree
## Écrit la palette par défaut.
##   godot --headless --path . --script tools/generer_palette.gd

func _init() -> void:
	var code: int = ResourceSaver.save(Palette.new(), "res://resources/palette.tres")
	print("palette générée (code %d)" % code)
	quit()
