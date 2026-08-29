class_name TeleportBehaviour
extends SpellBehaviour
## Se transporte au point visé.
##
## L'aperçu est géré ailleurs (par le HUD 3D), et seulement quand l'effet est
## DÉCOUVERT : montrer la destination d'un sort encore inconnu le révélerait
## avant de l'avoir lancé, ce qui viderait l'état ??? de son sens.


func lance(ctx: SpellContext, _slot_index: int, effet: SpellEffect,
		couleur: Color, _direction: Vector3) -> void:
	var depart: Vector3 = ctx.joueur.global_position
	var but: Vector3 = ctx.joueur.point_vise(effet.portee)
	ctx.fx.marqueur(depart, couleur)
	ctx.joueur.teleporte(but)
	ctx.fx.marqueur(but, couleur)
