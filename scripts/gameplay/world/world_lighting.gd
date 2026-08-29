class_name WorldLighting
extends RefCounted
## Éclairage et ambiance du monde. Provisoire jusqu'à la direction artistique,
## mais isolé ici pour que la remplacer ne demande de toucher qu'un fichier.


static func installe(parent: Node3D) -> void:
	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-58, -42, 0)
	lumiere.light_energy = 1.0
	lumiere.shadow_enabled = true
	parent.add_child(lumiere)

	var ambiance := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Content.palette.fond
	# Aucune lumière ambiante : le shader la désactive de toute façon, et une
	# ambiante viendrait éclaircir les ombres, donc introduire une troisième
	# valeur. Deux valeurs, jamais trois.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	ambiance.environment = env
	parent.add_child(ambiance)
