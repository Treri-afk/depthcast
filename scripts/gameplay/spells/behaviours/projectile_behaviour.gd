class_name ProjectileBehaviour
extends SpellBehaviour
## Part droit devant et s'arrête au premier corps touché.
##
## Sert aussi de base au vol de vie : seule la conclusion diffère, pas la
## trajectoire — d'où l'héritage plutôt qu'un drapeau dans les données.

const VITESSE: float = 34.0
const RAYON: float = 0.35


func lance(ctx: SpellContext, slot_index: int, effet: SpellEffect,
		couleur: Color, direction: Vector3) -> void:
	var bille := Area3D.new()
	bille.position = ctx.joueur.position_yeux() + direction * 0.8

	var forme := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RAYON
	forme.shape = sphere
	bille.add_child(forme)
	# La signature remplace la sphère lumineuse : deux projectiles qui se
	# ressemblent sont deux sorts qu'on confond en vol, donc deux sorts qu'on
	# n'apprend jamais à distinguer.
	if effet.signature != SpellSignature.Genre.NAPPE:
		bille.add_child(SpellSignature.cree(effet.signature, couleur,
			Vector3(RAYON, 0, 0)))
	else:
		bille.add_child(ctx.fx.sphere_lumineuse(RAYON, couleur))
	bille.add_child(ctx.fx.lampe(couleur))
	ctx.monde.add_child(bille)

	var consomme: Array[bool] = [false]
	bille.body_entered.connect(func(corps: Node3D) -> void:
		if consomme[0]:
			return

		# Le décor encaisse aussi : un projectile qui traverse une caisse sans
		# la marquer donne l'impression que rien n'est solide.
		var objet := corps as PropDestructible
		if objet != null:
			consomme[0] = true
			objet.encaisse(effet.degats, bille.global_position)
			ctx.fx.impact(effet.impact, bille.global_position, couleur)
			bille.queue_free()
			return

		var avatar := corps as MonsterAvatar
		if avatar == null:
			return
		consomme[0] = true
		ctx.degats(slot_index, effet.degats, [avatar.monster_id])
		# La marque part du point de contact et non du monstre : un projectile
		# qui touche l'épaule ne doit pas s'allumer au centre du corps.
		ctx.fx.impact(effet.impact, bille.global_position, couleur,
			(bille.global_position - avatar.global_position).normalized())
		_a_touche(ctx, slot_index, effet)
		_a_l_impact(ctx, effet, couleur, bille.global_position)
		bille.queue_free()
	)

	var arrivee: Vector3 = bille.position + direction * effet.portee
	var tween := ctx.monde.create_tween()
	tween.tween_property(bille, "position", arrivee, effet.portee / VITESSE)
	tween.tween_callback(bille.queue_free)


## Point d'extension : ne fait rien pour un projectile ordinaire.
func _a_touche(_ctx: SpellContext, _slot_index: int, _effet: SpellEffect) -> void:
	pass


## Second point d'extension, pour ce qui doit se dessiner AU POINT TOUCHÉ.
## Séparé du premier parce qu'il reçoit une position et non un slot : mélanger
## les deux obligerait chaque sous-classe à ignorer la moitié des arguments.
func _a_l_impact(_ctx: SpellContext, _effet: SpellEffect, _couleur: Color,
		_ou: Vector3) -> void:
	pass
