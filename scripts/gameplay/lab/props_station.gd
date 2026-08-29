class_name PropsStation
extends LabStation
## Étal du mobilier : des caisses, des tonneaux et une table qui reviennent.
##
## Casser du décor est le retour le plus immédiat du jeu, et le plus vite épuisé
## en test : au troisième essai il ne reste plus rien à casser et on arrête de
## mesurer. L'étal se réarme, donc l'essai peut durer.

const DELAI_REARMEMENT: float = 2.5

## Ce qui compose l'étal, et où. Une table au fond, des tonneaux au milieu, des
## caisses devant : trois masses différentes côte à côte, pour voir d'un seul
## souffle laquelle part et laquelle résiste.
const ETAL: Array[Dictionary] = [
	{"genre": PropFactory.Genre.CAISSE, "pos": Vector3(-2.0, 0, 1.6)},
	{"genre": PropFactory.Genre.CAISSE, "pos": Vector3(-0.7, 0, 1.6)},
	{"genre": PropFactory.Genre.CAISSE, "pos": Vector3(0.7, 0, 1.6)},
	{"genre": PropFactory.Genre.TONNEAU, "pos": Vector3(-1.4, 0, 0.0)},
	{"genre": PropFactory.Genre.TONNEAU, "pos": Vector3(0.0, 0, 0.0)},
	{"genre": PropFactory.Genre.TONNEAU, "pos": Vector3(1.4, 0, 0.0)},
	{"genre": PropFactory.Genre.TABLE, "pos": Vector3(0.0, 0, -1.8)},
	# Deux, et espacés : c'est la distance à laquelle on vérifie si la chaîne
	# se propage. Collés, ils n'auraient rien appris.
	{"genre": PropFactory.Genre.TONNEAU_EXPLOSIF, "pos": Vector3(-2.25, 0, -1.0)},
	{"genre": PropFactory.Genre.TONNEAU_EXPLOSIF, "pos": Vector3(2.25, 0, -1.0)},
	# Une balise, pour essayer le verbe porter/lancer sur autre chose qu'un
	# tonneau — et pour vérifier qu'elle détourne bien les mannequins d'à côté.
	{"genre": PropFactory.Genre.BALISE_LEURRE, "pos": Vector3(0.0, 0, 2.8)},
]


func titre() -> String:
	return "Étal du mobilier"


func installe() -> void:
	pancarte("ÉTAL DU MOBILIER\nil se réarme tout seul", 3.4, 34)
	dalle(7.0, Content.palette.estrade)
	for index: int in ETAL.size():
		_pose(index)


func _pose(index: int) -> void:
	var modele: Dictionary = ETAL[index]
	var corps := PropFactory.cree(modele["genre"], global_position
		+ (modele["pos"] as Vector3))
	# Accroché au terrain et non au poste : les positions ci-dessus sont
	# converties en coordonnées du monde, et un corps rigide sous un parent
	# décalé les subirait une seconde fois.
	get_parent().add_child(corps)
	# Enregistré auprès du contexte : sans ça les sorts et les souffles ne le
	# voient pas, et l'étal ne serait qu'un décor de plus.
	terrain.contexte.enregistre_objet(corps)
	corps.detruit.connect(func() -> void:
		get_tree().create_timer(DELAI_REARMEMENT).timeout.connect(
			func() -> void:
				if is_instance_valid(self):
					_pose(index)))
