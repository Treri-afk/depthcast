class_name DissolveSignature
extends SpellSignature
## OMBRE — des fragments qui s'écartent et s'effacent.
##
## Le voile et le pas d'ombre partagent un geste : quelque chose se DÉFAIT. Une
## silhouette de blocs empilée à hauteur d'homme se disloque vers l'extérieur en
## tournant, et chaque morceau part plus vite que le précédent.
##
## C'est le seul sort du jeu qui montre une forme humaine avant de la détruire.
## C'est aussi ce qui le rend lisible d'un coup d'oeil : les autres partent d'un
## point, celui-ci part d'un corps.

const FRAGMENTS: int = 22
const TAILLE: float = 1.85


func monte() -> void:
	for i: int in FRAGMENTS:
		# Empilés en colonne étroite : c'est une silhouette, pas un nuage.
		var t: float = float(i) / float(FRAGMENTS - 1)
		var f := bloc(Vector3(0.34, TAILLE / float(FRAGMENTS) * 1.1, 0.28), 0.6)
		var ecart: float = (fmod(float(i) * 0.61, 1.0) - 0.5) * 0.3
		f.position = Vector3(ecart, t * TAILLE, ecart * 0.7)
		add_child(f)
		f.set_meta(&"repos", f.position)
		f.set_meta(&"fuite", Vector3(
			cos(float(i) * 2.1), 0.35 + t * 0.5, sin(float(i) * 2.1)).normalized())
		f.set_meta(&"retard", t * 0.4)


func anime(part: float, _delta: float) -> void:
	for enfant: Node in get_children():
		var f := enfant as MeshInstance3D
		if f == null:
			continue
		var retard: float = float(f.get_meta(&"retard"))
		# Du bas vers le haut : la silhouette se défait par les pieds, ce qui
		# se lit comme une disparition et non comme une explosion.
		var parti: float = clampf((part - retard) / maxf(1.0 - retard, 0.01), 0.0, 1.0)
		var repos: Vector3 = f.get_meta(&"repos")
		var fuite: Vector3 = f.get_meta(&"fuite")

		f.position = repos + fuite * (parti * parti * 2.4)
		f.rotation = Vector3(parti * 3.1, parti * 2.2, parti * 1.4)
		f.scale = Vector3.ONE * (1.0 - parti * 0.8)
