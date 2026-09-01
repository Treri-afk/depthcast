class_name SchoolAltar
extends Node3D
## Un autel d'école dans le hub.
##
## Chaque école a son socle, et son état se lit à la couleur : éteinte si elle
## est verrouillée, allumée si elle est disponible, flamme haute si elle est
## dans l'équipe. On sait où on en est en traversant la salle, sans lire un
## menu — et à plusieurs, on verra d'un coup d'œil ce que les autres ont pris.

const HAUTEUR_FLAMME_ETEINTE: float = 0.0
const HAUTEUR_FLAMME_PRETE: float = 0.9
const HAUTEUR_FLAMME_CHOISIE: float = 2.1

var ecole: School
var choisie: bool = false
var debloquee: bool = false

var _flamme: MeshInstance3D
var _lampe: OmniLight3D
var _materiau_flamme: ShaderMaterial
## Les marques des joueurs qui ont pris cette école.
var _porteurs: Label3D = null


static func cree(p_ecole: School, position_monde: Vector3, fx: FxLibrary) -> SchoolAltar:
	var autel := SchoolAltar.new()
	autel.ecole = p_ecole
	autel.position = position_monde

	var socle := MeshInstance3D.new()
	var forme_socle := CylinderMesh.new()
	forme_socle.top_radius = 0.9
	forme_socle.bottom_radius = 1.15
	forme_socle.height = 1.5
	socle.mesh = forme_socle
	socle.position = Vector3(0, 0.75, 0)
	socle.material_override = MaterialLibrary.aplat(Content.palette.socle,
		MaterialLibrary.Role.INTERACTIF)
	autel.add_child(socle)

	var collision := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var cylindre := CylinderShape3D.new()
	cylindre.radius = 1.15
	cylindre.height = 1.5
	forme.shape = cylindre
	collision.position = Vector3(0, 0.75, 0)
	collision.add_child(forme)
	autel.add_child(collision)

	autel._flamme = fx.sphere_lumineuse(0.45, p_ecole.couleur)
	autel._flamme.position = Vector3(0, 1.9, 0)
	autel._materiau_flamme = autel._flamme.material_override as ShaderMaterial
	autel.add_child(autel._flamme)

	autel._lampe = fx.lampe(p_ecole.couleur, 1.4, 5.5)
	autel._lampe.position = Vector3(0, 2.2, 0)
	autel.add_child(autel._lampe)

	return autel


## Affiche qui a pris cette école, à sa couleur de joueur.
##
## En solo la ligne reste vide et l'autel est exactement comme avant. À
## plusieurs, c'est ce qui permet de se répartir : découvrir en plein combat
## qu'on a tous pris Braise est trop tard pour en changer.
func montre_les_porteurs(joueurs: Array) -> void:
	if _porteurs == null:
		_porteurs = Label3D.new()
		_porteurs.font_size = 40
		_porteurs.pixel_size = 0.004
		_porteurs.position = Vector3(0, 2.6, 0)
		_porteurs.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_porteurs.outline_size = 10
		_porteurs.outline_modulate = Content.palette.encre
		add_child(_porteurs)

	# Une seule couleur possible sur un Label3D : au-delà d'un porteur, on
	# revient au blanc et ce sont les numéros qui portent l'information.
	if joueurs.is_empty():
		_porteurs.text = ""
		return
	var marques: PackedStringArray = []
	for player_id: int in joueurs:
		marques.append("J%d" % (player_id + 1))
	_porteurs.text = " ".join(marques)
	_porteurs.modulate = Content.palette.couleur_joueur(int(joueurs[0])) \
		if joueurs.size() == 1 else Content.palette.lisere_blanc


func _process(delta: float) -> void:
	var voulue: float = HAUTEUR_FLAMME_ETEINTE
	if choisie:
		voulue = HAUTEUR_FLAMME_CHOISIE
	elif debloquee:
		voulue = HAUTEUR_FLAMME_PRETE

	_flamme.visible = debloquee
	_lampe.visible = debloquee
	if not debloquee:
		return

	# La flamme monte quand l'école est prise, et respire légèrement : un objet
	# parfaitement immobile a l'air éteint même quand il est allumé.
	var souffle: float = sin(float(Time.get_ticks_msec()) * 0.003) * 0.08
	_flamme.position.y = lerpf(_flamme.position.y, voulue + souffle, delta * 6.0)
	_lampe.position.y = _flamme.position.y + 0.3
	_lampe.light_energy = 2.4 if choisie else 1.1


func libelle(cout_deblocage: int) -> String:
	if not debloquee:
		return "[E] Débloquer %s — %d Éclats  ·  %d effets possibles" % [
			ecole.nom, cout_deblocage, ecole.taille_pool()]
	if choisie:
		return "[E] Retirer %s de l'équipe" % ecole.nom
	return "[E] Prendre %s — %s  ·  %d effets" % [
		ecole.nom, ecole.identite, ecole.taille_pool()]
