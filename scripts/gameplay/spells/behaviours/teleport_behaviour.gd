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
	# Aux DEUX bouts : sans la dislocation au départ, on ne comprend pas qu'on
	# vient de quitter un endroit — on croit avoir été poussé.
	_disloque(ctx, effet, couleur, depart)
	ctx.fx.marqueur(depart, couleur)
	ctx.joueur.teleporte(but)
	_disloque(ctx, effet, couleur, but)
	ctx.fx.marqueur(but, couleur)
	ctx.fx.eclair(depart + Vector3(0, 1.0, 0), couleur, 0.3, 4.0, 7.0)
	ctx.fx.eclair(but + Vector3(0, 1.0, 0), couleur, 0.3, 4.0, 7.0)


func _disloque(ctx: SpellContext, effet: SpellEffect, couleur: Color,
		ou: Vector3) -> void:
	if effet.signature == SpellSignature.Genre.NAPPE:
		return
	var geste := SpellSignature.cree(effet.signature, couleur, Vector3.ONE, 0.55)
	geste.position = ou
	ctx.monde.add_child(geste)
