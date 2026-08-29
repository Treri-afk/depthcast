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

	var largeur: float = cote * 0.62
	for i: int in PlayerState.SLOT_COUNT:
		var pos: Vector3 = centre + Vector3(
			-largeur * 0.5 + largeur * (float(i) / float(PlayerState.SLOT_COUNT - 1)),
			0.0, cote * 0.06)
		var socle := ShopPedestal.cree(_fx, pos, ShopPedestal.Genre.SCEAU,
			_couleur_ecole(i))
		socle.slot_index = i
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

	portail = Portal.cree(centre + Vector3(0, 0, -cote * 0.42))
	_parent.add_child(portail)


func cout_du_prochain_sceau() -> int:
	return _tuning.cout_scelle(GameState.run.players[0].locks_bought_this_floor)


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
			var ecole: School = Content.ecole(
				GameState.run.players[0].slots[socle.slot_index].school_id)
			return "[E] Sceller le slot %d (%s) — %d Résonance" % [
				socle.slot_index + 1, ecole.nom if ecole != null else "?",
				cout_du_prochain_sceau()]
		ShopPedestal.Genre.SOIN:
			return "[E] Fiole de soin (+%d PV) — %d Résonance" % [socle.valeur, socle.cout]
		ShopPedestal.Genre.VIGUEUR:
			return "[E] Éclat de vigueur (+%d PV max) — %d Résonance" % [
				socle.valeur, socle.cout]
	return ""


func achete(socle: ShopPedestal) -> bool:
	match socle.genre:
		ShopPedestal.Genre.SCEAU:
			return _achete_sceau(socle)
		ShopPedestal.Genre.SOIN, ShopPedestal.Genre.VIGUEUR:
			return _achete_consommable(socle)
	return false


func _achete_sceau(socle: ShopPedestal) -> bool:
	var cout: int = cout_du_prochain_sceau()
	if not GameState.try_lock_slot(0, socle.slot_index, cout):
		return false
	socle.consomme()
	achat_effectue.emit("Slot %d scellé pour %d Résonance. Le prochain coûtera %d." % [
		socle.slot_index + 1, cout, cout_du_prochain_sceau()])
	return true


func _achete_consommable(socle: ShopPedestal) -> bool:
	if not GameState.try_spend_resonance(0, socle.cout):
		return false
	var p: PlayerState = GameState.run.players[0]
	if socle.genre == ShopPedestal.Genre.VIGUEUR:
		p.max_hp += socle.valeur
		p.hp += socle.valeur
		achat_effectue.emit("Vigueur : %d PV max." % p.max_hp)
	else:
		p.hp = mini(p.max_hp, p.hp + socle.valeur)
		achat_effectue.emit("Fiole bue.")
	socle.consomme()
	return true


func _ajoute(socle: ShopPedestal) -> void:
	_parent.add_child(socle)
	socles.append(socle)


func _couleur_ecole(slot_index: int) -> Color:
	var ecole: School = Content.ecole(
		GameState.run.players[0].slots[slot_index].school_id)
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
