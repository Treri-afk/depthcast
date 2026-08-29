extends SceneTree
## Aligne les couleurs des monstres sur la palette fermée.
##   godot --headless --path . --script tools/aligner_couleurs.gd
##
## Les couleurs de créatures vivent dans leur propre Resource — c'est là qu'un
## artiste les règle. La palette en donne les valeurs de référence ; cet outil
## les y ramène après un changement de palette.

func _init() -> void:
	var p := load("res://resources/palette.tres") as Palette
	var couples := {
		"rodeur": p.creature_commune,
		"brute": p.creature_lourde,
		"rodeuse_ailee": p.creature_ailee,
		"gardien_du_seuil": p.boss,
	}
	for id: String in couples:
		var chemin: String = "res://resources/monsters/%s.tres" % id
		var stats := load(chemin) as MonsterStats
		if stats == null:
			continue
		stats.couleur = couples[id]
		ResourceSaver.save(stats, chemin)
		print("  %s alignée sur la palette" % stats.nom)
	quit()
