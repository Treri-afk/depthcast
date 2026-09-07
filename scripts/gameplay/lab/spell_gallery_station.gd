class_name SpellGalleryStation
extends LabStation
## La galerie : tous les sorts du jeu, côte à côte, qui se lancent ensemble.
##
## Elle existe pour une raison précise. On ne peut pas juger le rendu d'un sort
## en jouant : il faut le tirer, mourir, remonter un étage, espérer que le
## reroll le redonne. Résultat, personne ne regarde jamais deux fois le même
## sort, et c'est comme ça qu'on se retrouve avec quinze effets qui se
## ressemblent sans que personne ne l'ait décidé.
##
## ── POURQUOI TOUS EN MÊME TEMPS ──────────────────────────────────────────
##
## Une galerie qui les montre l'un APRÈS l'autre ne répond pas à la question
## qu'on lui pose. La question n'est pas « à quoi ressemble ce sort », c'est
## « est-ce que ces deux-là se ressemblent ». Deux effets voisins vus à dix
## secondes d'intervalle passent pour distincts ; côte à côte, la parenté saute
## aux yeux en une seconde.
##
## D'où une grille, un lanceur par sort, et un lancer simultané en boucle.
##
## Les lanceurs sont de VRAIS avatars et les cibles de VRAIS monstres : une
## galerie qui simulerait le lancer ne montrerait que la simulation.

## Écartement des cases. Large : une nova et un cône débordent, et deux sorts
## qui se recouvrent ne se comparent plus.
const PAS_X: float = 9.0
const PAS_Z: float = 9.0
const COLONNES: int = 6
const DELAI: float = 2.6
const PLAYER_ID_BASE: int = 9000

## Hauteur de dépose d'un lanceur : le dessus du socle, plus la demi-capsule.
## Trop bas, il naît dans le socle et se fait éjecter ; trop haut, il tombe.
const MARGE_AU_SOL: float = 1.55

var spawner: MonsterSpawner = null

var _cases: Array[Dictionary] = []
var _minuteur: float = 0.0
var _salve: int = 0


func titre() -> String:
	return "Galerie des sorts"


func installe() -> void:
	var entrees: Array[Dictionary] = _recense()
	if entrees.is_empty():
		return

	var lignes: int = ceili(float(entrees.size()) / float(COLONNES))
	dalle_large(float(COLONNES) * PAS_X, float(lignes) * PAS_Z,
		Content.palette.estrade)

	var enseigne := pancarte("GALERIE DES SORTS\ntous les sorts, en boucle", 6.0, 44)
	enseigne.position = Vector3(0, 6.0, _origine_z() - PAS_Z * 0.7)
	enseigne.pixel_size = 0.012

	for i: int in entrees.size():
		_batit_une_case(i, entrees[i])

	# Une première salve tout de suite : une galerie qui commence par trois
	# secondes de rien laisse croire qu'elle est cassée.
	_minuteur = DELAI


func invite() -> String:
	return "[E] relancer la salve"


func interagit() -> String:
	_tire_la_salve()
	return "Galerie : salve %d." % _salve


func _process(delta: float) -> void:
	if _cases.is_empty():
		return
	_minuteur += delta
	if _minuteur >= DELAI:
		_tire_la_salve()


# ── Construction ──────────────────────────────────────────────────────────

## Tous les effets de toutes les écoles, dans l'ordre du contenu.
##
## On ne passe PAS par les slots du joueur : la galerie doit montrer le
## catalogue entier, y compris ce que le reroll n'a pas donné, et surtout elle
## ne doit pas dépendre de la structure du grimoire — celle-ci bouge, le
## catalogue non.
func _recense() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ecole: School in Content.ecoles:
		for i: int in ecole.taille_pool():
			var effet: SpellEffect = ecole.effet(i)
			if effet != null:
				out.append({"ecole": ecole, "effet": effet})
	return out


## Position locale d'une case. La grille est centrée sur le poste.
func _place(index: int) -> Vector3:
	var colonne: int = index % COLONNES
	var ligne: int = index / COLONNES
	var x: float = (float(colonne) - float(COLONNES - 1) * 0.5) * PAS_X
	return Vector3(x, 0.0, _origine_z() + float(ligne) * PAS_Z)


func _origine_z() -> float:
	return -float((_recense().size() - 1) / COLONNES) * PAS_Z * 0.5


func _batit_une_case(index: int, entree: Dictionary) -> void:
	var ecole: School = entree["ecole"]
	var effet: SpellEffect = entree["effet"]
	var local: Vector3 = _place(index)

	var socle := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.4, 0.4, 2.4)
	socle.mesh = mesh
	socle.position = local + Vector3(0, 0.2, 0)
	socle.material_override = MaterialLibrary.aplat(ecole.couleur,
		MaterialLibrary.Role.INTERACTIF)
	add_child(socle)

	var etiquette := Label3D.new()
	etiquette.text = "%s\n%s · %s" % [effet.nom, ecole.nom, effet.libelle_famille()]
	etiquette.font_size = 34
	etiquette.pixel_size = 0.010
	etiquette.position = local + Vector3(0, 3.4, 0)
	etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiquette.modulate = ecole.couleur
	etiquette.outline_size = 10
	etiquette.outline_modulate = Content.palette.encre
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(etiquette)

	_cases.append({
		"entree": entree,
		"local": local,
		"lanceur": _batit_un_lanceur(index, local),
	})


## Un lanceur par case : un avatar comme les autres, mais qui n'appartient à
## personne.
##
## Un vrai `PlayerAvatar` et non un point dans l'espace, parce que la moitié des
## comportements agissent SUR leur lanceur — la charge le propulse, la
## téléportation le déplace, le voile l'efface, la traînée s'arme sous ses pas.
## Un lanceur factice ne montrerait pas ces sorts-là, qui sont précisément ceux
## qu'on comprend le moins.
##
## Son `player_id` ne correspond à aucun joueur de la run : les intentions
## qu'il soumet au resolver ne trouvent personne et n'altèrent aucun état.
func _batit_un_lanceur(index: int, local: Vector3) -> PlayerAvatar:
	var lanceur := PlayerAvatar.new()
	lanceur.player_id = PLAYER_ID_BASE + index
	lanceur.local = false
	lanceur.name = "Lanceur%d" % index
	# Posé SUR le socle, dans le repère du monde : l'avatar est un corps
	# physique, il tombe, et un lanceur enfant du poste dériverait avec lui.
	lanceur.position = global_position + local + Vector3(0, MARGE_AU_SOL, 0)
	terrain.geometrie.add_child(lanceur)
	return lanceur


# ── Boucle ────────────────────────────────────────────────────────────────

## Tout part en même temps. C'est le sujet de la galerie.
func _tire_la_salve() -> void:
	_minuteur = 0.0
	_salve += 1
	for case: Dictionary in _cases:
		_lance(case)


func _lance(case: Dictionary) -> void:
	var lanceur: PlayerAvatar = case["lanceur"]
	if not is_instance_valid(lanceur):
		return
	var effet: SpellEffect = case["entree"]["effet"]
	var ecole: School = case["entree"]["ecole"]

	# Ramené à sa case avant chaque lancer : les sorts de déplacement l'ont
	# peut-être emmené ailleurs, et une grille dont les lanceurs dérivent finit
	# par tirer depuis n'importe où.
	lanceur.teleporte(global_position + (case["local"] as Vector3)
		+ Vector3(0, MARGE_AU_SOL, 0))

	# Appel DIRECT au comportement, sans passer par SpellCaster.
	#
	# Le lanceur ne possède ni slot ni cooldown : le passage par les slots
	# demanderait d'écrire dans l'état d'un joueur qui n'existe pas, pour
	# montrer une image. La galerie regarde le rendu, pas la plomberie.
	var comportement: SpellBehaviour = terrain.caster.registre().comportement(
		effet.comportement)
	if comportement == null:
		return
	var precedent: PlayerAvatar = terrain.contexte.joueur
	terrain.contexte.joueur = lanceur
	comportement.lance(terrain.contexte, 0, effet, ecole.couleur, Vector3(0, 0, 1))
	terrain.contexte.joueur = precedent


## Une dalle rectangulaire : la galerie est une grille, là où les autres postes
## sont carrés.
func dalle_large(largeur: float, profondeur: float, couleur: Color) -> void:
	var visuel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(largeur, 0.12, profondeur)
	visuel.mesh = mesh
	visuel.position = Vector3(0, 0.06, _origine_z() + profondeur * 0.5 - PAS_Z * 0.5)
	visuel.material_override = MaterialLibrary.aplat(couleur,
		MaterialLibrary.Role.INTERACTIF)
	add_child(visuel)
