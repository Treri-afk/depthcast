class_name HealBehaviour
extends SpellBehaviour
## Soin instantané, autour du lanceur.
##
## Il atteint les coéquipiers à portée, et pas seulement soi. C'est par lui que
## passe la relève : quelqu'un à terre est une cible de soin comme une autre.

## Rayon de repli si la Resource n'en déclare pas. Non nul à dessein : un soin
## strictement personnel ne pourrait relever personne, et le jeu perdrait sa
## seule façon de se relever à plusieurs.
const RAYON_MINIMAL: float = 7.0


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, _direction: Vector3) -> void:
	var rayon: float = maxf(effet.rayon, RAYON_MINIMAL)
	ctx.soin(slot_index, effet.soin, rayon)
	ctx.fx.anneau(ctx.joueur.global_position, rayon, couleur)
	ctx.fx.eclair(ctx.joueur.global_position + Vector3(0, 1.0, 0), couleur, 0.35, 4.0, 7.0)
