class_name PushBehaviour
extends SpellBehaviour
## Répulsion et attraction. Même code, sens opposé — et deux jeux différents :
## l'une dégage la place, l'autre rassemble pour frapper ensuite.
##
## L'effet faiblit avec la distance : au bord du rayon on est à peine bousculé.
## Sans cette atténuation, un souffle a la même violence partout et devient une
## solution universelle.

var repousse: bool = true


func _init(p_repousse: bool = true) -> void:
	repousse = p_repousse


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, _direction: Vector3) -> void:
	var centre: Vector3 = ctx.joueur.global_position

	# Le lanceur est épargné : sur ce sort il est le point d'ancrage. Il pousse
	# le monde, le monde ne le pousse pas — sinon une Attraction s'annulerait
	# elle-même en tirant aussi celui qui l'a lancée.
	#
	# Un souffle projette le mobilier ; il ne le pulvérise pas. Sinon Poussée
	# deviendrait l'outil de démolition et les autres écoles perdraient leur rôle.
	var cibles: Array = ctx.souffle(centre, effet.rayon, effet.puissance,
		repousse, 2, true)
	ctx.degats(slot_index, effet.degats, cibles)
	ctx.fx.anneau(centre, effet.rayon, couleur)
	ctx.fx.eclair(centre + Vector3(0, 1.0, 0), couleur, 0.2, 4.5, effet.rayon * 1.8)
