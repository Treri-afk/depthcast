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
	var cibles: Array = []

	for id: int in ctx.monstres_dans_rayon(centre, effet.rayon):
		var avatar: MonsterAvatar = ctx.monstres[id]
		var vers: Vector3 = avatar.global_position - centre
		vers.y = 0.0
		if vers.length_squared() < 0.01:
			vers = Vector3.FORWARD
		var sens: Vector3 = vers.normalized() * (1.0 if repousse else -1.0)
		var attenuation: float = 1.0 - clampf(vers.length() / effet.rayon, 0.0, 0.85)
		avatar.repousse(sens * effet.puissance * attenuation)
		cibles.append(id)

	# Un souffle projette le mobilier ; il ne le pulvérise pas. Sinon Poussée
	# deviendrait l'outil de démolition et les autres écoles perdraient leur rôle.
	ctx.souffle_sur_objets(centre, effet.rayon, effet.puissance, repousse, 2)
	ctx.degats(slot_index, effet.degats, cibles)
	ctx.fx.anneau(centre, effet.rayon, couleur)
