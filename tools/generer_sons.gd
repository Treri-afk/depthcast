extends SceneTree
## Écrit la banque de sons par défaut.
##   godot --headless --path . --script tools/generer_sons.gd
##
## Chaque son tient en six nombres. Les régler se fait ensuite dans
## l'inspecteur, fichier par fichier, sans repasser par ici.

const F := SoundDef.Forme

# id, forme, freq début, freq fin, durée, attaque, volume, gain dB
const SONS: Array = [
	["impact",      F.CARRE,  520.0, 180.0, 0.09, 0.01, 0.45, -6.0],
	["mort",        F.BRUIT,  700.0,  90.0, 0.34, 0.01, 0.55, -4.0],
	["blessure",    F.SCIE,   240.0,  70.0, 0.26, 0.01, 0.70,  0.0],
	# La mutation MONTE : c'est un évènement, pas une punition. Le son doit
	# donner envie de regarder ce qu'on est devenu.
	["mutation",    F.SINUS,  330.0, 880.0, 0.30, 0.05, 0.55, -2.0],
	# Le sceau qui tient descend et se pose : quelque chose s'est ancré.
	["sceau_tient", F.SINUS,  660.0, 330.0, 0.26, 0.03, 0.50, -3.0],
	["achat",       F.SINUS,  440.0, 660.0, 0.16, 0.02, 0.50, -4.0],
	["refus",       F.CARRE,  180.0, 110.0, 0.16, 0.01, 0.40, -6.0],
	["descente",    F.SINUS,  220.0, 110.0, 0.55, 0.10, 0.45, -5.0],
	["victoire",    F.SINUS,  330.0, 990.0, 0.80, 0.06, 0.60,  0.0],
	["defaite",     F.SCIE,   220.0,  55.0, 0.90, 0.04, 0.55, -2.0],
	["sort",        F.SINUS,  600.0, 900.0, 0.11, 0.01, 0.35, -9.0],
]


func _init() -> void:
	for entree: Array in SONS:
		var def := SoundDef.new()
		def.id = StringName(entree[0])
		def.forme = entree[1]
		def.frequence_debut = entree[2]
		def.frequence_fin = entree[3]
		def.duree = entree[4]
		def.attaque = entree[5]
		def.volume = entree[6]
		def.gain_db = entree[7]
		var code: int = ResourceSaver.save(def,
			"res://resources/sounds/%s.tres" % entree[0])
		if code != OK:
			printerr("échec sur %s" % entree[0])
	print("%d sons générés." % SONS.size())
	quit()
