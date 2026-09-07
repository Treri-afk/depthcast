class_name MonsterBody
extends Node3D
## Le corps d'une créature : son anatomie et sa démarche.
##
## ── CE QU'IL REMPLACE ────────────────────────────────────────────────────
##
## Un monstre était UNE boîte à la taille de sa boîte de collision. Rôdeur,
## Brute et Rôdeuse ailée ne différaient que par leur volume et leur teinte —
## trois cubes de tailles différentes. On ne pouvait pas savoir ce qui chargeait
## sans lire sa couleur, ce qui est le pire cas en combat : la couleur est ce
## qu'on lit en DERNIER, après la silhouette et après le mouvement.
##
## ── LA SILHOUETTE D'ABORD, ET LA DÉMARCHE ENSUITE ────────────────────────
##
## En ligne claire il n'y a ni dégradé, ni volume, ni matière : deux surfaces de
## la même couleur sont indiscernables. Une créature ne peut donc se distinguer
## que par sa FORME et par son MOUVEMENT. C'est une contrainte, et elle tombe
## bien : c'est exactement dans cet ordre que l'oeil lit une menace.
##
## Le Rôdeur est bas et penché en avant, il court sur de longues jambes ; la
## Brute est une paire d'épaules avec une tête enfoncée dedans, elle roule des
## bras ; la Rôdeuse ailée est un noyau qui bat des ailes. On les reconnaît de
## dos, de loin, et en filtre monochrome.
##
## ── DEUX VALEURS, COMME LE DÉCOR ─────────────────────────────────────────
##
## Chaque corps n'emploie que deux teintes : la teinte de l'espèce, et une
## version assombrie pour les membres. Une troisième vaudrait un dégradé.

## Les pièces, pour que l'avatar puisse toutes les faire clignoter à l'encaisse
## et toutes les dissoudre à la mort. Une seule liste, tenue ici : l'avatar n'a
## pas à connaître l'anatomie de ce qu'il porte.
var pieces: Array[MeshInstance3D] = []

var _stats: MonsterStats
## Membres animés, avec leur phase de départ. Une phase par membre : en phase,
## deux jambes font un saut à pieds joints.
var _membres: Array[Dictionary] = []
var _tronc: Node3D = null
var _phase: float = 0.0


static func cree(stats: MonsterStats) -> MonsterBody:
	var corps := MonsterBody.new()
	corps.name = "Corps"
	corps._stats = stats
	corps._monte()
	return corps


## `vitesse_plate` est la vitesse au sol : c'est elle qui cadence la marche.
## Un monstre à l'arrêt respire, un monstre qui court galope, et il n'y a rien à
## déclarer pour passer de l'un à l'autre.
func anime(delta: float, vitesse_plate: float) -> void:
	var cadence: float = 2.2 + clampf(vitesse_plate, 0.0, 8.0) * 1.5
	_phase += delta * cadence
	var amplitude: float = 0.12 + clampf(vitesse_plate / 5.0, 0.0, 1.0) * 0.85

	for membre: Dictionary in _membres:
		var noeud: Node3D = membre["noeud"]
		if not is_instance_valid(noeud):
			continue
		var balance: float = sin(_phase + float(membre["phase"]))
		var axe: Vector3 = membre["axe"]
		var repos: Vector3 = membre["repos"]
		noeud.rotation = repos + axe * balance * amplitude * float(membre["gain"])

	# Le tronc monte et descend à DEUX fois la cadence des membres : un pas à
	# gauche et un pas à droite le font plonger chacun leur tour.
	if _tronc != null:
		_tronc.position.y = float(_tronc.get_meta(&"repos_y")) \
			+ sin(_phase * 2.0) * 0.035 * (0.4 + amplitude)


# ── Les anatomies ─────────────────────────────────────────────────────────

func _monte() -> void:
	match _stats.id:
		&"brute":
			_monte_la_brute()
		&"rodeuse_ailee":
			_monte_la_volante()
		&"gardien_du_seuil":
			_monte_le_gardien()
		_:
			_monte_le_rodeur()


## LE RÔDEUR — bas, penché, sur de longues jambes.
##
## Tout est tiré vers l'avant : le tronc plonge, la tête dépasse des épaules,
## les bras pendent en arrière. Un corps qui se lit comme « il arrive », même
## immobile.
func _monte_le_rodeur() -> void:
	var t: Vector3 = _stats.taille
	var h: float = t.y

	_tronc = _articulation(Vector3(0, h * 0.14, 0))
	_tronc.rotation.x = deg_to_rad(26.0)
	add_child(_tronc)

	_piece(_tronc, Vector3(t.x * 0.62, h * 0.5, t.z * 0.5),
		Vector3(0, h * 0.1, 0), false)
	# La tête en pointe, tendue vers l'avant : c'est elle qui donne la direction
	# de la charge avant que le corps ne bouge.
	_piece(_tronc, Vector3(t.x * 0.34, h * 0.2, t.z * 0.44),
		Vector3(0, h * 0.36, -t.z * 0.16), true)

	for cote: int in [-1, 1]:
		var epaule := _articulation(Vector3(float(cote) * t.x * 0.32, h * 0.28, 0))
		_tronc.add_child(epaule)
		_piece(epaule, Vector3(t.x * 0.14, h * 0.42, t.z * 0.14),
			Vector3(0, -h * 0.21, 0), true)
		_anime(epaule, Vector3.RIGHT, 0.0 if cote > 0 else PI, 1.0)

		var hanche := _articulation(Vector3(float(cote) * t.x * 0.2, -h * 0.02, 0))
		add_child(hanche)
		_piece(hanche, Vector3(t.x * 0.17, h * 0.34, t.z * 0.17),
			Vector3(0, -h * 0.17, 0), false)
		var genou := _articulation(Vector3(0, -h * 0.34, 0))
		hanche.add_child(genou)
		_piece(genou, Vector3(t.x * 0.14, h * 0.32, t.z * 0.14),
			Vector3(0, -h * 0.16, 0), true)
		# Les jambes battent à contretemps des bras : c'est ce qui fait une
		# marche plutôt qu'une gigue.
		_anime(hanche, Vector3.RIGHT, PI if cote > 0 else 0.0, 1.25)
		_anime(genou, Vector3.RIGHT, (PI if cote > 0 else 0.0) + 1.1, 0.6)


## LA BRUTE — une paire d'épaules avec une tête enfoncée dedans.
##
## Large en haut, courte en bas, les bras plus longs que les jambes. La masse
## est portée par les épaules et non par le ventre : c'est ce qui la fait lire
## comme lente et lourde plutôt que grosse.
func _monte_la_brute() -> void:
	var t: Vector3 = _stats.taille
	var h: float = t.y

	_tronc = _articulation(Vector3(0, h * 0.06, 0))
	add_child(_tronc)

	_piece(_tronc, Vector3(t.x * 0.95, h * 0.4, t.z * 0.72),
		Vector3(0, h * 0.3, 0), false)
	_piece(_tronc, Vector3(t.x * 0.6, h * 0.26, t.z * 0.56),
		Vector3(0, h * 0.04, 0), false)
	# La tête, petite et basse, calée entre les épaules. Une grosse tête ferait
	# une mascotte ; celle-ci fait une enclume.
	_piece(_tronc, Vector3(t.x * 0.26, h * 0.16, t.z * 0.26),
		Vector3(0, h * 0.46, -t.z * 0.06), true)

	for cote: int in [-1, 1]:
		var epaule := _articulation(Vector3(float(cote) * t.x * 0.48, h * 0.42, 0))
		_tronc.add_child(epaule)
		_piece(epaule, Vector3(t.x * 0.26, h * 0.34, t.z * 0.26),
			Vector3(0, -h * 0.17, 0), false)
		var coude := _articulation(Vector3(0, -h * 0.3, 0))
		epaule.add_child(coude)
		# L'avant-bras plus GROS que le bras : la masse est au bout, comme une
		# massue. C'est ce qui donne son inertie au balancement.
		_piece(coude, Vector3(t.x * 0.3, h * 0.3, t.z * 0.3),
			Vector3(0, -h * 0.15, 0), true)
		_anime(epaule, Vector3.RIGHT, 0.0 if cote > 0 else PI, 0.7)
		_anime(coude, Vector3.RIGHT, (0.0 if cote > 0 else PI) + 0.8, 0.35)

		var jambe := _articulation(Vector3(float(cote) * t.x * 0.24, -h * 0.04, 0))
		add_child(jambe)
		_piece(jambe, Vector3(t.x * 0.28, h * 0.24, t.z * 0.28),
			Vector3(0, -h * 0.12, 0), true)
		_anime(jambe, Vector3.RIGHT, PI if cote > 0 else 0.0, 0.55)


## LA RÔDEUSE AILÉE — un noyau qui bat des ailes.
##
## Pas de jambes : elle ne touche jamais le sol. Les ailes battent en
## permanence, et c'est le seul corps du jeu dont l'animation ne dépend pas de
## la vitesse — un vol stationnaire bat autant qu'un vol piqué.
func _monte_la_volante() -> void:
	var t: Vector3 = _stats.taille
	var h: float = maxf(t.y, 0.8)

	_tronc = _articulation(Vector3.ZERO)
	add_child(_tronc)

	_piece(_tronc, Vector3(t.x * 0.5, h * 0.7, t.z * 0.5), Vector3.ZERO, false)
	_piece(_tronc, Vector3(t.x * 0.3, h * 0.34, t.z * 0.3),
		Vector3(0, h * 0.42, -t.z * 0.1), true)
	# La queue, en arrière et en bas : elle donne un sens à la silhouette, sinon
	# le noyau seul est symétrique et on ne sait pas où elle regarde.
	_piece(_tronc, Vector3(t.x * 0.16, h * 0.16, t.z * 0.9),
		Vector3(0, -h * 0.16, t.z * 0.5), true)

	for cote: int in [-1, 1]:
		var attache := _articulation(Vector3(float(cote) * t.x * 0.22, h * 0.18, 0))
		_tronc.add_child(attache)
		# Deux segments par aile : une aile d'un seul tenant bat comme une
		# planche. Le second segment traîne, et le battement devient souple.
		_piece(attache, Vector3(t.x * 0.9, h * 0.06, t.z * 0.42),
			Vector3(float(cote) * t.x * 0.45, 0, 0), false)
		var bout := _articulation(Vector3(float(cote) * t.x * 0.9, 0, 0))
		attache.add_child(bout)
		_piece(bout, Vector3(t.x * 0.7, h * 0.05, t.z * 0.3),
			Vector3(float(cote) * t.x * 0.35, 0, 0), true)
		# Autour de l'axe AVANT : une aile bat de haut en bas, pas d'avant en
		# arrière. Les deux côtés en phase — un oiseau ne rame pas en alternance.
		_anime(attache, Vector3.FORWARD * float(cote), 0.0, 3.2)
		_anime(bout, Vector3.FORWARD * float(cote), 0.9, 2.4)


## LE GARDIEN DU SEUIL — haut, cuirassé, couronné.
##
## Le seul corps bâti à la verticale : il ne se penche pas et ne court pas. Sa
## couronne dépasse de tout le reste, ce qui le rend identifiable par-dessus une
## salle pleine de créatures.
func _monte_le_gardien() -> void:
	var t: Vector3 = _stats.taille
	var h: float = t.y

	_tronc = _articulation(Vector3(0, h * 0.04, 0))
	add_child(_tronc)

	_piece(_tronc, Vector3(t.x * 0.52, h * 0.46, t.z * 0.44),
		Vector3(0, h * 0.2, 0), false)
	_piece(_tronc, Vector3(t.x * 0.72, h * 0.2, t.z * 0.52),
		Vector3(0, h * 0.38, 0), false)
	_piece(_tronc, Vector3(t.x * 0.24, h * 0.14, t.z * 0.24),
		Vector3(0, h * 0.52, 0), true)

	# La couronne : quatre pointes en croix. C'est sa signature, et elle se voit
	# de l'autre bout de l'arène.
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0
		var pointe := _piece(_tronc, Vector3(t.x * 0.08, h * 0.24, t.z * 0.08),
			Vector3(cos(a) * t.x * 0.2, h * 0.66, sin(a) * t.z * 0.2), true)
		pointe.rotation = Vector3(sin(a) * 0.4, 0.0, -cos(a) * 0.4)

	for cote: int in [-1, 1]:
		var epaule := _articulation(Vector3(float(cote) * t.x * 0.4, h * 0.4, 0))
		_tronc.add_child(epaule)
		_piece(epaule, Vector3(t.x * 0.18, h * 0.36, t.z * 0.18),
			Vector3(0, -h * 0.18, 0), false)
		var poing := _articulation(Vector3(0, -h * 0.34, 0))
		epaule.add_child(poing)
		_piece(poing, Vector3(t.x * 0.24, h * 0.2, t.z * 0.24),
			Vector3(0, -h * 0.1, 0), true)
		_anime(epaule, Vector3.RIGHT, 0.0 if cote > 0 else PI, 0.5)

		var jambe := _articulation(Vector3(float(cote) * t.x * 0.18, -h * 0.06, 0))
		add_child(jambe)
		_piece(jambe, Vector3(t.x * 0.22, h * 0.36, t.z * 0.22),
			Vector3(0, -h * 0.18, 0), true)
		_anime(jambe, Vector3.RIGHT, PI if cote > 0 else 0.0, 0.8)


# ── Fabrique ──────────────────────────────────────────────────────────────

## Un point d'articulation : un nœud vide autour duquel un membre pivote.
##
## Indispensable pour que le membre tourne depuis son ATTACHE et non depuis son
## milieu — c'est la différence entre un bras et un essuie-glace.
func _articulation(ou: Vector3) -> Node3D:
	var noeud := Node3D.new()
	noeud.position = ou
	# Mémorisée à la construction : le ballant du tronc s'ajoute à sa hauteur de
	# repos, il ne l'écrase pas.
	noeud.set_meta(&"repos_y", ou.y)
	return noeud


## Une pièce de corps. `sombre` la passe sur la seconde valeur : les membres
## sont plus sourds que le tronc, ce qui détache la silhouette sans ajouter de
## troisième teinte.
func _piece(parent: Node3D, taille: Vector3, ou: Vector3,
		sombre: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = taille
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.position = ou
	var teinte: Color = _stats.couleur.darkened(0.3) if sombre else _stats.couleur
	var mat: ShaderMaterial = MaterialLibrary.aplat(teinte,
		MaterialLibrary.Role.CREATURE)
	# La teinte de départ voyage AVEC le matériau : l'éclat d'encaisse blanchit
	# depuis elle et y revient, sans que l'avatar ait à savoir quelle pièce est
	# sombre et laquelle ne l'est pas.
	mat.set_meta(&"teinte_base", teinte)
	piece.set_surface_override_material(0, mat)
	parent.add_child(piece)
	pieces.append(piece)
	return piece


func _anime(noeud: Node3D, axe: Vector3, phase: float, gain: float) -> void:
	_membres.append({
		"noeud": noeud, "axe": axe, "phase": phase, "gain": gain,
		"repos": noeud.rotation,
	})
