class_name FirewallSignature
extends SpellSignature
## MUR DE FLAMMES — un vrai mur, fait de blocs.
##
## Trois rangées de blocs empilés qui montent chacun à leur rythme, se décalent
## et retombent. Ce n'est plus une nappe verticale translucide : c'est une
## maçonnerie qui bouge, et on voit qu'elle occupe l'espace.
##
## Les blocs du haut sont plus petits et plus vifs que ceux du bas. Deux
## valeurs, comme partout : la braise en bas, la flamme en haut, rien entre.

const RANGEES: int = 3
const LARGEUR_BLOC: float = 0.62

var _blocs: Array[MeshInstance3D] = []


func monte() -> void:
	var largeur: float = maxf(dimensions.x, 1.5)
	var hauteur: float = maxf(dimensions.y, 2.4)
	var colonnes: int = clampi(int(largeur / LARGEUR_BLOC), 4, 26)
	var pas: float = largeur / float(colonnes)

	for rangee: int in RANGEES:
		# Chaque rangée est plus étroite et plus haute que celle du dessous :
		# le mur s'affine en montant, comme une flamme, au lieu de rester un
		# parallélépipède.
		var retrait: float = float(rangee) * 0.16
		var taille := Vector3(pas * (0.86 - retrait * 0.5),
			hauteur / float(RANGEES) * 1.15, 0.55 - retrait * 0.6)
		for i: int in colonnes:
			var x: float = -largeur * 0.5 + pas * (float(i) + 0.5)
			var b := bloc(taille, 0.62 - float(rangee) * 0.1)
			b.position = Vector3(x, taille.y * (0.5 + float(rangee) * 0.82), 0.0)
			add_child(b)
			_blocs.append(b)
			# Une phase par bloc, tirée de sa place : en phase, les blocs
			# feraient un ascenseur ; au hasard pur, une friture. Le décalage
			# régulier fait courir une vague le long du mur.
			b.set_meta(&"phase", float(i) * 0.55 + float(rangee) * 1.9)
			b.set_meta(&"repos", b.position)
			b.set_meta(&"rangee", rangee)


func anime(part: float, _delta: float) -> void:
	# Le mur SE DRESSE : il ne surgit pas fini. Le quart de seconde de montée
	# est ce qui donne son poids au sort.
	var montee: float = smoothstep(0.0, 0.18, part)
	var temps: float = part * 14.0

	for b: MeshInstance3D in _blocs:
		var phase: float = float(b.get_meta(&"phase"))
		var repos: Vector3 = b.get_meta(&"repos")
		var rangee: float = float(b.get_meta(&"rangee"))
		var battement: float = sin(temps + phase)

		b.position = Vector3(repos.x,
			repos.y * montee + battement * 0.16 * (1.0 + rangee),
			repos.z + cos(temps * 0.7 + phase) * 0.07)
		b.scale = Vector3(1.0, montee * (0.82 + absf(battement) * 0.4), 1.0)
		b.rotation.z = battement * 0.09
