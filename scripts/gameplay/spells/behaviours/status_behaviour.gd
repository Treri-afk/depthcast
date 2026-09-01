class_name StatusBehaviour
extends SpellBehaviour
## Pose un état temporaire — et c'est le seul comportement qui en pose.
##
## Protection, vulnérabilité, hâte, lenteur, provocation : tout passe par ici,
## et tout se décrit dans la Resource du sort. Ajouter « Carapace » ou « Cri de
## guerre » ne demande donc AUCUNE ligne de code, seulement un fichier — c'est
## littéralement la promesse de R6, et c'est ici qu'elle se tient ou qu'elle
## tombe.
##
## Ce comportement ne sait pas ce qu'est une protection. Il lit des facteurs et
## les transmet.


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, _direction: Vector3) -> void:
	if effet.statut_id == &"" or effet.statut_duree <= 0.0:
		return

	var rayon: float = maxf(effet.rayon, effet.portee)
	match effet.statut_cible:
		2:
			ctx.pose_un_etat_sur_les_monstres(slot_index, effet, rayon)
		_:
			# « Soi » est le cas où le rayon ne compte pas : on ne touche que le
			# lanceur, même si des alliés se tiennent à côté.
			ctx.pose_un_etat_sur_les_joueurs(slot_index, effet,
				rayon if effet.statut_cible == 1 else 0.0)

	ctx.fx.anneau(ctx.joueur.global_position, maxf(rayon, 2.0), couleur)
	ctx.fx.eclair(ctx.joueur.global_position + Vector3(0, 1.0, 0), couleur,
		0.3, 4.0, maxf(rayon, 2.0) * 1.6)
