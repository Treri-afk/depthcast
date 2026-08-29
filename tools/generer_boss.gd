extends SceneTree
## Génère la Resource du boss de la V1.
##   godot --headless --path . --script tools/generer_boss.gd

func _init() -> void:
	var boss := BossStats.new()
	boss.id = &"gardien_du_seuil"
	boss.nom = "Gardien du Seuil"
	boss.titre = "Gardien du Seuil"
	boss.couleur = Color(0.85, 0.28, 0.42)
	boss.taille = Vector3(3.2, 4.0, 3.2)
	boss.pv = 420
	boss.degats = 22
	boss.resonance = 120
	boss.portee_frappe = 4.0
	boss.vitesse = 3.0
	boss.distance_garde = 8.0
	boss.delai_assaut = 2.2
	boss.duree_assaut = 0.55
	boss.duree_repli = 0.5
	boss.seuils_de_phase = [0.66, 0.33]
	boss.delai_special = 6.0
	boss.degats_special = 26
	boss.rayon_special = 9.0
	var code: int = ResourceSaver.save(boss, "res://resources/monsters/gardien_du_seuil.tres")
	print("boss généré (code %d)" % code)
	quit()
