class_name MerchantRoom
extends RefCounted
## La dernière salle d'un étage : le marchand, ses socles, et le portail.
##
## C'est LE moment de décision de la boucle. On y scelle ses sorts avant de
## descendre, jamais après : un portail qui rerollerait avant l'achat rendrait
## les sceaux inutiles.
##
## Cette classe assemble et arbitre les achats. La présentation d'un socle vit
## dans ShopPedestal, celle du portail dans Portal.

signal achat_effectue(libelle: String)

var socles: Array[ShopPedestal] = []
var portail: Portal = null

var _parent: Node3D
var _tuning: Tuning
var _fx: FxLibrary


func _init(parent: Node3D, tuning: Tuning, fx: FxLibrary) -> void:
	_parent = parent
	_tuning = tuning
	_fx = fx


## Oublie l'étage précédent. Indispensable quand aucun marchand n'est installé
## — une arène de boss — sinon les références des socles libérés survivent.
func vide() -> void:
	socles.clear()
	portail = null


func installe(salle: FloorPlan.Salle) -> void:
	vide()
	var centre: Vector3 = salle.centre
	var cote: float = salle.cote

	_silhouette(centre + Vector3(0, 1.2, -cote * 0.28))

	# UN SOCLE PAR PAGE POSSIBLE, ET NON PAR PAGE TENUE.
	#
	# Le grimoire grandit en cours de run et n'a pas la même taille chez tous
	# les joueurs. Bâtir la rangée sur le grimoire local donnerait un magasin
	# différent d'une machine à l'autre — or c'est le RANG du socle qui le
	# désigne à travers le réseau (voir `index_du_socle`). On bâtit donc
	# toujours la même rangée, et on éteint les socles sans page derrière eux.
	var largeur: float = cote * 0.62
	var tenues: int = _pages_du_joueur_local()
	for i: int in PlayerState.SLOTS_MAX:
		var pos: Vector3 = centre + Vector3(
			-largeur * 0.5 + largeur * (float(i) / float(PlayerState.SLOTS_MAX - 1)),
			0.0, cote * 0.06)
		var socle := ShopPedestal.cree(_fx, pos, ShopPedestal.Genre.SCEAU,
			_couleur_ecole(i))
		socle.slot_index = i
		if i >= tenues:
			# Pas de page à sceller : le socle reste en place pour que les rangs
			# concordent, mais il n'est ni visible ni achetable.
			socle.visible = false
			socle.achete = true
		_ajoute(socle)

	# Deux consommables : sans usage concurrent de la Résonance, sceller serait
	# toujours le bon choix et il n'y aurait aucun arbitrage.
	var fiole := ShopPedestal.cree(_fx, centre + Vector3(-largeur * 0.36, 0, cote * 0.3),
		ShopPedestal.Genre.SOIN, Color(0.42, 0.92, 0.48))
	fiole.cout = _tuning.cout_fiole_soin
	fiole.valeur = _tuning.valeur_fiole_soin
	_ajoute(fiole)

	var vigueur := ShopPedestal.cree(_fx, centre + Vector3(largeur * 0.36, 0, cote * 0.3),
		ShopPedestal.Genre.VIGUEUR, Color(0.95, 0.55, 0.35))
	vigueur.cout = _tuning.cout_eclat_vigueur
	vigueur.valeur = _tuning.valeur_eclat_vigueur
	_ajoute(vigueur)

	# La balise n'est pas un consommable comme les autres : on n'achète pas un
	# effet, on achète un OBJET, qui tombe au sol et qu'il faut ramasser.
	var balise := ShopPedestal.cree(_fx, centre + Vector3(0, 0, cote * 0.34),
		ShopPedestal.Genre.LEURRE, Content.palette.balise_leurre)
	balise.cout = _tuning.leurre_cout
	_ajoute(balise)

	# LA PAGE. Elle n'apparaît que s'il reste de la place au grimoire : un socle
	# qu'on ne peut pas acheter et qui ne dit pas pourquoi est pire qu'un socle
	# absent.
	if _peut_vendre_une_page():
		var ecole: School = _ecole_de_la_page()
		if ecole != null:
			var page := ShopPedestal.cree(_fx,
				centre + Vector3(largeur * 0.18, 0, cote * 0.34),
				ShopPedestal.Genre.PAGE, ecole.couleur)
			page.cout = _tuning.page_cout
			page.ecole_id = ecole.id
			_ajoute(page)

	portail = Portal.cree(centre + Vector3(0, 0, -cote * 0.42))
	_parent.add_child(portail)


## Les socles sont construits dans le même ordre sur toutes les machines : leur
## rang suffit donc à les désigner à travers le réseau, sans identifiant à
## inventer ni à synchroniser.
## Reste-t-il de la place pour une page ?
func _peut_vendre_une_page() -> bool:
	var p: PlayerState = GameState.local_player()
	return p != null and p.peut_ajouter_une_page()


## L'école proposée à cet étage.
##
## Tirée dans le flux d'étage et non au hasard : deux clients doivent voir la
## MÊME page sur le socle, sinon l'un achète Givre et l'autre Braise au même
## rang de socle. Et jamais une école qu'on porte déjà — le sujet de la page est
## d'ouvrir le grimoire à autre chose.
func _ecole_de_la_page() -> School:
	var p: PlayerState = GameState.local_player()
	if p == null:
		return null
	var deja: Array[StringName] = []
	for slot: SpellSlot in p.slots:
		if not deja.has(slot.school_id):
			deja.append(slot.school_id)

	var possibles: Array[School] = []
	for ecole: School in Content.ecoles:
		if not deja.has(ecole.id):
			possibles.append(ecole)
	if possibles.is_empty():
		return null

	var rng: RandomNumberGenerator = RngService.floor_stream(
		RngService.STREAM_LOOT, GameState.run.floor_index)
	return possibles[rng.randi_range(0, possibles.size() - 1)]


func _pages_du_joueur_local() -> int:
	var p: PlayerState = GameState.local_player()
	return PlayerState.SLOTS_DEPART if p == null else p.slots.size()


func index_du_socle(socle: ShopPedestal) -> int:
	return socles.find(socle)


func socle_par_index(index: int) -> ShopPedestal:
	if index < 0 or index >= socles.size():
		return null
	var socle: ShopPedestal = socles[index]
	return socle if is_instance_valid(socle) else null


func cout_du_prochain_sceau() -> int:
	return _tuning.cout_scelle(GameState.local_player().locks_bought_this_floor)


## Socle disponible le plus proche, ou null. Le portail est traité à part par
## l'appelant : ce n'est pas un achat.
func socle_proche(depuis: Vector3, portee: float) -> ShopPedestal:
	var meilleure: float = portee
	var trouve: ShopPedestal = null
	for socle: ShopPedestal in socles:
		# La validité se teste AVANT toute lecture de propriété : à l'étage du
		# boss la géométrie est libérée sans que installe() soit rappelé, donc
		# la liste peut contenir des références mortes.
		if not is_instance_valid(socle) or socle.achete:
			continue
		var d: float = depuis.distance_to(socle.global_position)
		if d < meilleure:
			meilleure = d
			trouve = socle
	return trouve


func distance_au_portail(depuis: Vector3) -> float:
	return INF if portail == null or not is_instance_valid(portail) \
		else depuis.distance_to(portail.global_position)


func libelle(socle: ShopPedestal) -> String:
	match socle.genre:
		ShopPedestal.Genre.SCEAU:
			var p: PlayerState = GameState.local_player()
			if p == null or socle.slot_index >= p.slots.size():
				return ""
			var ecole: School = Content.ecole(p.slots[socle.slot_index].school_id)
			return "[E] Sceller le slot %d (%s) — %d Résonance" % [
				socle.slot_index + 1, ecole.nom if ecole != null else "?",
				cout_du_prochain_sceau()]
		ShopPedestal.Genre.SOIN:
			return "[E] Fiole de soin (+%d PV) — %d Résonance" % [socle.valeur, socle.cout]
		ShopPedestal.Genre.VIGUEUR:
			return "[E] Éclat de vigueur (+%d PV max) — %d Résonance" % [
				socle.valeur, socle.cout]
		ShopPedestal.Genre.LEURRE:
			return "[E] Balise de leurre — %d Résonance" % socle.cout
		ShopPedestal.Genre.PAGE:
			var page: School = Content.ecole(socle.ecole_id)
			return "[E] Page de %s — %d Résonance (sort inconnu)" % [
				page.nom if page != null else "?", socle.cout]
	return ""


func achete(socle: ShopPedestal) -> bool:
	match socle.genre:
		ShopPedestal.Genre.SCEAU:
			return _achete_sceau(socle)
		ShopPedestal.Genre.SOIN, ShopPedestal.Genre.VIGUEUR:
			return _achete_consommable(socle)
		ShopPedestal.Genre.LEURRE:
			return _achete_balise(socle)
		ShopPedestal.Genre.PAGE:
			return _achete_page(socle)
	return false


## Acheter une page : une école de plus au grimoire, un sort tiré dedans.
##
## Le sort n'est PAS annoncé. On sait quelle école on ajoute, jamais lequel de
## ses sorts on obtient — et il rerollera dès l'étage suivant comme les deux
## autres. C'est la promesse du jeu appliquée à l'économie.
func _achete_page(socle: ShopPedestal) -> bool:
	var ecole: School = Content.ecole(socle.ecole_id)
	if ecole == null:
		return false
	if not GameState.try_spend_resonance(GameState.local_player_id, socle.cout):
		return false
	var index: int = GameState.ajoute_une_page(GameState.local_player_id,
		ecole.id, ecole.taille_pool())
	if index < 0:
		return false
	socle.consomme()
	achat_effectue.emit("Page de %s ajoutée au grimoire — slot %d. Ce qu'elle "
		% [ecole.nom, index + 1] + "contient, tu le découvriras en le lançant.")
	return true


func _achete_sceau(socle: ShopPedestal) -> bool:
	var cout: int = cout_du_prochain_sceau()
	if not GameState.try_lock_slot(GameState.local_player_id, socle.slot_index, cout):
		return false
	socle.consomme()
	achat_effectue.emit("Slot %d scellé pour %d Résonance. Le prochain coûtera %d." % [
		socle.slot_index + 1, cout, cout_du_prochain_sceau()])
	return true


func _achete_consommable(socle: ShopPedestal) -> bool:
	if not GameState.try_spend_resonance(GameState.local_player_id, socle.cout):
		return false
	var p: PlayerState = GameState.local_player()
	if socle.genre == ShopPedestal.Genre.VIGUEUR:
		p.max_hp += socle.valeur
		p.hp += socle.valeur
		achat_effectue.emit("Vigueur : %d PV max." % p.max_hp)
	else:
		p.hp = mini(p.max_hp, p.hp + socle.valeur)
		achat_effectue.emit("Fiole bue.")
	socle.consomme()
	return true


## La balise achetée tombe au pied du socle : c'est un objet du monde, pas une
## ligne d'inventaire. Il faut se baisser pour la prendre, et on peut l'oublier.
func _achete_balise(socle: ShopPedestal) -> bool:
	if not GameState.try_spend_resonance(GameState.local_player_id, socle.cout):
		return false
	var balise := PropFactory.cree(PropFactory.Genre.BALISE_LEURRE,
		socle.global_position + Vector3(0, 0, 1.4))
	_parent.add_child(balise)
	socle.consomme()
	achat_effectue.emit("Balise de leurre posée devant le socle. [F] pour la prendre.")
	return true


func _ajoute(socle: ShopPedestal) -> void:
	_parent.add_child(socle)
	socles.append(socle)


## La couleur du socle d'un rang donné.
##
## La rangée compte toujours `SLOTS_MAX` socles pour que les rangs concordent
## entre machines, mais le grimoire, lui, en tient moins au début. Les rangs
## sans page derrière eux existent donc bel et bien — ils sont simplement
## éteints — et lire leur école faisait sortir du tableau au montage du
## marchand, avant même que le socle ne soit désactivé.
func _couleur_ecole(slot_index: int) -> Color:
	var p: PlayerState = GameState.local_player()
	if p == null or slot_index < 0 or slot_index >= p.slots.size():
		return Content.palette.lisere_blanc
	var ecole: School = Content.ecole(p.slots[slot_index].school_id)
	return ecole.couleur if ecole != null else Color.WHITE


func _silhouette(pos: Vector3) -> void:
	var marchand := Node3D.new()
	marchand.position = pos
	marchand.add_child(_fx.sphere_lumineuse(0.9, Content.palette.marchand))

	var chapeau := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.85
	cone.height = 1.1
	chapeau.mesh = cone
	chapeau.position = Vector3(0, 1.1, 0)
	chapeau.material_override = MaterialLibrary.aplat(
		Content.palette.chapeau_marchand, MaterialLibrary.Role.INTERACTIF)
	marchand.add_child(chapeau)
	_parent.add_child(marchand)
