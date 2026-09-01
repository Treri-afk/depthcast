class_name WorldLighting
extends RefCounted
## Éclairage et ambiance du monde. Provisoire jusqu'à la direction artistique,
## mais isolé ici pour que la remplacer ne demande de toucher qu'un fichier.


static func installe(parent: Node3D) -> void:
	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-58, -42, 0)
	lumiere.light_energy = 1.0
	lumiere.shadow_enabled = true
	# Sans ces biais, la carte d'ombre s'auto-intersecte sur les grandes
	# surfaces planes et laisse des rayures — que le contour souligne ensuite
	# consciencieusement, ce qui les rend deux fois plus visibles.
	lumiere.shadow_bias = 0.06
	lumiere.shadow_normal_bias = 2.0
	lumiere.directional_shadow_max_distance = 90.0
	parent.add_child(lumiere)

	var ambiance := WorldEnvironment.new()
	var env := Environment.new()
	# Le ciel remplace le fond plat quand la palette en veut un. Sa couleur de
	# base EST `fond` : sans ciel, ou sous l'horizon, on retombe exactement sur
	# ce qu'on avait avant, donc aucune salle fermée ne change d'aspect.
	var ciel: Sky = CloudSky.cree()
	if ciel != null:
		env.background_mode = Environment.BG_SKY
		env.sky = ciel
	else:
		env.background_mode = Environment.BG_COLOR
	env.background_color = Content.palette.fond
	# Aucune lumière ambiante : le shader la désactive de toute façon, et une
	# ambiante viendrait éclaircir les ombres, donc introduire une troisième
	# valeur. Deux valeurs, jamais trois.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	ambiance.environment = env
	parent.add_child(ambiance)
