class_name WorldLighting
extends RefCounted
## Éclairage et ambiance du monde. Provisoire jusqu'à la direction artistique,
## mais isolé ici pour que la remplacer ne demande de toucher qu'un fichier.


static func installe(parent: Node3D) -> void:
	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-58, -42, 0)
	lumiere.light_energy = 1.15
	lumiere.shadow_enabled = true
	parent.add_child(lumiere)

	var ambiance := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.09, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.36, 0.42)
	env.ambient_light_energy = 0.85
	ambiance.environment = env
	parent.add_child(ambiance)
