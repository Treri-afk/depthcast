class_name MerchantRoom
extends RefCounted
## La dernière salle d'un étage : le marchand, ses socles, et le portail.
##
## C'est LE moment de décision de la boucle. On y scelle ses sorts avant de
## descendre, jamais après : un portail qui rerollerait avant l'achat rendrait
## les sceaux inutiles.

signal achat_effectue(libelle: String)

var socles: Array[Dictionary] = []
var portail: Node3D = null

var _parent: Node3D
var _tuning: Tuning
var _fx: FxLibrary


func _init(parent: Node3D, tuning: Tuning, fx: FxLibrary) -> void:
	_parent = parent
	_tuning = tuning
	_fx = fx


func installe(salle: FloorPlan.Salle) -> void:
	socles.clear()
	var centre: Vector3 = salle.centre
	var cote: float = salle.cote

	_silhouette_marchand(centre + Vector3(0, 1.2, -cote * 0.28))

	# Un socle par slot : sceller devient un objet qu'on va chercher, pas une
	# case à cocher dans un menu.
	var largeur: float = cote * 0.62
	for i: int in PlayerState.SLOT_COUNT:
		var pos: Vector3 = centre + Vector3(
			-largeur * 0.5 + largeur * (float(i) / float(PlayerState.SLOT_COUNT - 1)),
			0.0, cote * 0.06)
		_socle(pos, {"type": "verrou", "slot": i})

	# Deux consommables : sans usage concurrent de la Résonance, sceller serait
	# toujours le bon choix et il n'y aurait aucun arbitrage.
	_socle(centre + Vector3(-largeur * 0.36, 0, cote * 0.3),
		{"type": "soin", "cout": _tuning.cout_fiole_soin,
		 "valeur": _tuning.valeur_fiole_soin})
	_socle(centre + Vector3(largeur * 0.36, 0, cote * 0.3),
		{"type": "vigueur", "cout": _tuning.cout_eclat_vigueur,
		 "valeur": _tuning.valeur_eclat_vigueur})

	portail = _portail(centre + Vector3(0, 0, -cote * 0.42))


func _silhouette_marchand(pos: Vector3) -> void:
	var marchand := Node3D.new()
	marchand.position = pos
	marchand.add_child(_fx.sphere_lumineuse(0.9, Color(0.95, 0.85, 0.45)))

	var chapeau := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.85
	cone.height = 1.1
	chapeau.mesh = cone
	chapeau.position = Vector3(0, 1.1, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.28, 0.55)
	chapeau.material_override = mat
	marchand.add_child(chapeau)
	_parent.add_child(marchand)


func _socle(pos: Vector3, donnees: Dictionary) -> void:
	var socle := Node3D.new()
	socle.position = Vector3(pos.x, 0.0, pos.z)

	var pied := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.55
	mesh.bottom_radius = 0.7
	mesh.height = 0.9
	pied.mesh = mesh
	pied.position = Vector3(0, 0.45, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.34, 0.42)
	pied.material_override = mat
	socle.add_child(pied)

	var objet := _fx.sphere_lumineuse(0.32, _couleur(donnees))
	objet.position = Vector3(0, 1.35, 0)
	socle.add_child(objet)

	_parent.add_child(socle)
	donnees["node"] = socle
	donnees["objet"] = objet
	donnees["achete"] = false
	socles.append(donnees)


func _couleur(donnees: Dictionary) -> Color:
	match String(donnees.get("type", "")):
		"soin":
			return Color(0.42, 0.92, 0.48)
		"vigueur":
			return Color(0.95, 0.55, 0.35)
	var slot: SpellSlot = GameState.run.players[0].slots[int(donnees.get("slot", 0))]
	var ecole: School = Content.ecole(slot.school_id)
	return ecole.couleur if ecole != null else Color.WHITE


func _portail(pos: Vector3) -> Node3D:
	var portail_node := Node3D.new()
	portail_node.position = Vector3(pos.x, 0.1, pos.z)
	var anneau := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.5
	mesh.outer_radius = 2.0
	anneau.mesh = mesh
	anneau.rotation_degrees = Vector3(90, 0, 0)
	anneau.position = Vector3(0, 2.0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.75, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.7, 1.0)
	mat.emission_energy_multiplier = 1.6
	anneau.material_override = mat
	portail_node.add_child(anneau)
	_parent.add_child(portail_node)
	return portail_node


# ── Interaction ───────────────────────────────────────────────────────────

## Objet interactif le plus proche du joueur, ou un dictionnaire vide.
func cible_proche(depuis: Vector3, portee: float) -> Dictionary:
	var meilleure: float = portee
	var trouvee: Dictionary = {}

	for socle: Dictionary in socles:
		if socle["achete"]:
			continue
		var d: float = depuis.distance_to((socle["node"] as Node3D).global_position)
		if d < meilleure:
			meilleure = d
			trouvee = socle

	if portail != null and depuis.distance_to(portail.global_position) < meilleure:
		return {"type": "portail"}
	return trouvee


func cout_du_prochain_sceau() -> int:
	var effet: SpellEffect = null
	return _tuning.cout_scelle(GameState.run.players[0].locks_bought_this_floor)


func libelle(cible: Dictionary) -> String:
	if cible.is_empty():
		return ""
	match String(cible.get("type", "")):
		"portail":
			var restants: int = GameState.run.alive_monsters().size()
			if restants > 0:
				return "[E] Portail scellé — %d monstre(s) à éliminer" % restants
			return "[E] Descendre à l'étage suivant"
		"verrou":
			var i: int = int(cible["slot"])
			var ecole: School = Content.ecole(GameState.run.players[0].slots[i].school_id)
			return "[E] Sceller le slot %d (%s) — %d Résonance" % [
				i + 1, ecole.nom if ecole != null else "?", cout_du_prochain_sceau()]
		"soin":
			return "[E] Fiole de soin (+%d PV) — %d Résonance" % [
				int(cible["valeur"]), int(cible["cout"])]
		"vigueur":
			return "[E] Éclat de vigueur (+%d PV max) — %d Résonance" % [
				int(cible["valeur"]), int(cible["cout"])]
	return ""


## Tente l'achat. Retourne false si l'achat n'a pas eu lieu.
func achete(cible: Dictionary) -> bool:
	match String(cible.get("type", "")):
		"verrou":
			var i: int = int(cible["slot"])
			var cout: int = cout_du_prochain_sceau()
			if not GameState.try_lock_slot(0, i, cout):
				return false
			_consomme(cible)
			achat_effectue.emit("Slot %d scellé pour %d Résonance. Le prochain coûtera %d." % [
				i + 1, cout, cout_du_prochain_sceau()])
			return true

		"soin", "vigueur":
			var cout: int = int(cible["cout"])
			if not GameState.try_spend_resonance(0, cout):
				return false
			var p: PlayerState = GameState.run.players[0]
			if String(cible["type"]) == "vigueur":
				p.max_hp += int(cible["valeur"])
				p.hp += int(cible["valeur"])
				achat_effectue.emit("Vigueur : %d PV max." % p.max_hp)
			else:
				p.hp = mini(p.max_hp, p.hp + int(cible["valeur"]))
				achat_effectue.emit("Fiole bue.")
			_consomme(cible)
			return true
	return false


func _consomme(socle: Dictionary) -> void:
	socle["achete"] = true
	var objet: Node3D = socle["objet"]
	if is_instance_valid(objet):
		objet.queue_free()
