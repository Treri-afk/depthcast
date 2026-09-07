class_name FrostPlatesSignature
extends SpellSignature
## GEL — des plaques hexagonales qui se posent en claquant, puis se fendent.
##
## Le givre ne coule pas et ne respire pas : il PREND. Les plaques arrivent
## d'un coup, chacune à son tour, se figent, puis se soulèvent aux bords en se
## fendant. Une nappe qui tourne lentement disait exactement le contraire.

const PLAQUES: int = 14


func monte() -> void:
	var rayon: float = maxf(dimensions.x, 1.0)
	for i: int in PLAQUES:
		# Réparties en spirale de Fermat : une grille laisserait des couloirs
		# vides et un tirage pur ferait des paquets. Ici elles pavent.
		var angle: float = float(i) * 2.399963
		var d: float = rayon * sqrt(float(i) / float(PLAQUES)) * 0.92
		var cote: float = rayon * (0.42 - 0.16 * float(i) / float(PLAQUES))

		var p := fut(cote, EPAISSEUR * 1.6, 6, 0.5)
		p.position = Vector3(cos(angle) * d, EPAISSEUR, sin(angle) * d)
		p.rotation.y = angle
		add_child(p)
		# Chacune arrive à son tour, du centre vers le bord : la nappe se
		# propage au lieu d'apparaître.
		p.set_meta(&"retard", float(i) / float(PLAQUES) * 0.34)
		p.set_meta(&"cote", cote)


func anime(part: float, _delta: float) -> void:
	for enfant: Node in get_children():
		var p := enfant as MeshInstance3D
		if p == null:
			continue
		var retard: float = float(p.get_meta(&"retard"))
		# Le claquement : de rien à la taille pleine en un dixième, sans
		# rebond. Un ressort ferait du caoutchouc, pas de la glace.
		var pose: float = clampf((part - retard) / 0.09, 0.0, 1.0)
		var largeur: float = pose

		# Puis la fente : la plaque se sépare en deux moitiés qui s'écartent
		# de quelques centimètres et se soulèvent. C'est ce que fait la glace
		# sous une contrainte, et rien d'autre dans le jeu ne fait ça.
		var fente: float = smoothstep(0.45, 1.0, part)
		p.scale = Vector3(largeur * (1.0 + fente * 0.12), 1.0 + fente * 2.2,
			largeur * (1.0 - fente * 0.22))
		p.position.y = EPAISSEUR + fente * 0.16
		p.rotation.x = fente * 0.14
