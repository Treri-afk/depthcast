class_name SwapBehaviour
extends SpellBehaviour
## Permutation : on échange sa place avec celle de la créature visée.
##
## En solo c'est un outil de désengagement qui coûte cher à la cible : on sort
## d'un encerclement en y mettant quelqu'un d'autre, on se place derrière une
## brute pour la couper du reste.
##
## En coopération la cible peut être un coéquipier, et c'est là que le sort
## devient intéressant : le même geste le sauve d'un tonneau amorcé ou l'y
## envoie à sa place. Seule l'intention change. C'est ce qui en fait une
## mécanique sociale plutôt qu'un bouton pour nuire.
##
## Il ne cible pas ce qu'on survole mais ce qui est le plus proche de l'AXE de
## visée : en vue subjective, exiger un pointage au pixel sur une créature qui
## bouge rendrait le sort injouable.

const DEMI_ANGLE: float = 0.42


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, direction: Vector3) -> void:
	var cible: Node3D = ctx.corps_vise(ctx.joueur.position_yeux(), direction,
		effet.portee, DEMI_ANGLE)
	if cible == null:
		# Rien dans l'axe : le sort n'a pas eu lieu, donc il ne se paie pas.
		# Un cooldown consommé pour rien se lit comme un bug d'entrée.
		ctx.annule_le_cooldown(slot_index)
		return

	var ici: Vector3 = ctx.joueur.global_position
	var la_bas: Vector3 = cible.global_position

	ctx.joueur.teleporte(la_bas)
	_depose(cible, ici)

	# Les deux extrémités sont marquées : sans ça on se retrouve ailleurs sans
	# comprendre ce qui vient d'arriver, ni où l'on a envoyé la cible.
	ctx.fx.marqueur(ici, couleur)
	ctx.fx.marqueur(la_bas, couleur)


## Poser la cible, quelle qu'elle soit. Un joueur se téléporte comme il le fait
## partout ailleurs ; un monstre se déplace et perd le fil de son assaut.
func _depose(cible: Node3D, vers: Vector3) -> void:
	var autre := cible as PlayerAvatar
	if autre != null:
		autre.teleporte(vers)
		return

	var avatar := cible as MonsterAvatar
	if avatar != null:
		avatar.global_position = vers
		avatar.velocity = Vector3.ZERO
		avatar.desoriente()
