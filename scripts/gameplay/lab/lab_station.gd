class_name LabStation
extends Node3D
## Un poste du terrain d'essai : un socle, une pancarte, une chose à observer.
##
## Chaque poste est autonome — il se construit, se met à jour et se réarme tout
## seul. C'est ce qui permet d'en ajouter un sans toucher au terrain, et d'en
## retirer un sans rien casser ailleurs.
##
## Un poste ne SIMULE jamais ce qu'il mesure : il utilise les classes du jeu,
## le vrai Souffle, les vrais monstres, le vrai mobilier. Un banc d'essai qui
## reconstruit une version simplifiée de ce qu'il teste ne mesure que lui-même.

const PORTEE_INTERACTION: float = 3.6

## Le socle commun : le poste y prend le joueur, le contexte de sorts et le HUD.
var terrain: PlayField = null


func titre() -> String:
	return "Poste"


## Construit le poste. Appelée une fois, après l'entrée dans l'arbre.
func installe() -> void:
	pass


## Ce que le HUD affiche quand on est à portée. Vide = aucune invite.
func invite() -> String:
	return ""


## Réaction à la touche d'interaction. Retourne la ligne à journaliser.
func interagit() -> String:
	return ""


func a_portee(depuis: Vector3) -> bool:
	return depuis.distance_to(global_position) <= PORTEE_INTERACTION


# ── Éléments partagés ─────────────────────────────────────────────────────

## Pancarte lisible de loin.
##
## Orientée vers la caméra, contrairement à tout le reste du jeu. C'est assumé :
## un terrain d'essai est un outil, et une pancarte qu'il faut contourner pour
## lire coûte plus cher en temps qu'elle ne rapporte en cohérence.
func pancarte(texte: String, hauteur: float, taille: int = 44) -> Label3D:
	var label := Label3D.new()
	label.text = texte
	label.font_size = taille
	label.pixel_size = 0.004
	label.position = Vector3(0, hauteur, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Content.palette.lisere_blanc
	label.outline_size = 10
	label.outline_modulate = Content.palette.encre
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label


## Dalle au sol qui délimite le poste. Sans elle, les postes se confondent avec
## le décor et on ne sait plus où commence ce qu'on mesure.
func dalle(cote: float, couleur: Color) -> void:
	var visuel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(cote, 0.12, cote)
	visuel.mesh = mesh
	visuel.position = Vector3(0, 0.06, 0)
	visuel.material_override = MaterialLibrary.aplat(couleur,
		MaterialLibrary.Role.INTERACTIF)
	add_child(visuel)
