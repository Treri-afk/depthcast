class_name CloudSky
extends RefCounted
## Le ciel en aplats. Fabrique le `Sky` et rien d'autre.
##
## Séparé de `WorldLighting` parce que ce sont deux sujets : l'un décide d'où
## vient la lumière, l'autre de ce qu'on voit quand on lève les yeux. Le jour où
## le ciel change de biome, c'est ce fichier qu'on remplace, pas l'éclairage.
##
## Toutes les valeurs viennent de la palette (R6) : la couleur du ciel est une
## couleur du jeu comme une autre, elle n'a pas à vivre dans un script.

const CHEMIN_SHADER := "res://shaders/ciel_nuages.gdshader"


## Le ciel de la palette, ou `null` si elle le désactive — auquel cas
## l'appelant garde un fond plat.
static func cree() -> Sky:
	var p: Palette = Content.palette
	if not p.ciel_actif:
		return null

	var materiau := ShaderMaterial.new()
	materiau.shader = load(CHEMIN_SHADER)
	materiau.set_shader_parameter("couleur_ciel", p.fond)
	materiau.set_shader_parameter("couleur_nuage", p.ciel_nuage)
	materiau.set_shader_parameter("couleur_nuage_ombre", p.ciel_nuage_ombre)
	materiau.set_shader_parameter("couverture", p.ciel_couverture)
	materiau.set_shader_parameter("echelle", p.ciel_echelle)
	materiau.set_shader_parameter("derive", p.ciel_derive)
	materiau.set_shader_parameter("bord", p.ciel_bord)
	materiau.set_shader_parameter("epaisseur_ombre", p.ciel_epaisseur_ombre)

	var ciel := Sky.new()
	ciel.sky_material = materiau
	# Le ciel ne s'actualise qu'une fois par seconde : les nuages dérivent
	# beaucoup trop lentement pour qu'on voie la différence, et un ciel
	# procédural rafraîchi à chaque image coûte plus cher que tout le donjon.
	ciel.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	ciel.radiance_size = Sky.RADIANCE_SIZE_128
	return ciel
