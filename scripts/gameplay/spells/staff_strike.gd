class_name StaffStrike
extends RefCounted
## Résout les deux coups du bâton.
##
## À part des sorts, et c'est délibéré : le bâton n'a ni école, ni slot, ni
## reroll, ni verrou. Le faire passer par `SpellCaster` aurait demandé de lui
## inventer une page fantôme dans le grimoire de chaque joueur, uniquement pour
## réutiliser trois lignes.
##
## Il passe en revanche par le CONTEXTE, donc par l'EffectResolver comme tout le
## reste (R4) : deux joueurs qui frappent le même monstre dans la même image
## restent déterministes.

## Le slot déclaré au resolver pour un coup de bâton.
##
## -1 et non 0 : zéro est un vrai slot, et l'attribuer au bâton ferait compter
## ses dégâts comme ceux du premier sort dans toute mesure de télémétrie.
const SLOT_BATON: int = -1


## La frappe : tout ce qui est devant, dans un cône court.
static func frappe(ctx: SpellContext, lanceur: PlayerAvatar,
		direction: Vector3) -> void:
	var t: Tuning = ctx.tuning
	var origine: Vector3 = lanceur.global_position
	var plat: Vector3 = ctx.direction_au_sol(direction)

	var touches: Array = ctx.monstres_dans_cone(origine, plat,
		Staff.PORTEE_FRAPPE, Staff.DEMI_ANGLE_FRAPPE)
	ctx.degats(SLOT_BATON, t.baton_frappe_degats, touches)

	# Le décor encaisse aussi : un bâton qui traverse une caisse sans la marquer
	# donne l'impression que rien n'est solide.
	ctx.frappe_objets_devant(origine, plat, Staff.PORTEE_FRAPPE,
		Staff.DEMI_ANGLE_FRAPPE, t.baton_frappe_degats)

	for id: int in touches:
		var avatar: MonsterAvatar = ctx.monstres.get(id)
		if is_instance_valid(avatar):
			avatar.repousse(plat * t.baton_frappe_poussee)

	# Le coup se voit même dans le vide : sans marque, une frappe qui rate se
	# lit comme une entrée perdue.
	ctx.fx.impact(FxLibrary.Impact.ECLAT,
		origine + plat * 1.6 + Vector3(0, 1.0, 0), Content.palette.lisere_blanc)
	EventBus.sound_emitted.emit(&"impact", lanceur.position_yeux())


## Le trait : un éclat qui part droit et s'arrête au premier corps.
##
## Nommée `tire` et non `trait` : ce dernier est un mot réservé de GDScript.
static func tire(ctx: SpellContext, lanceur: PlayerAvatar,
		direction: Vector3) -> void:
	var t: Tuning = ctx.tuning
	var couleur: Color = Content.palette.lisere_blanc
	var bille := Area3D.new()
	bille.position = lanceur.position_yeux() + direction * 0.9

	var forme := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	forme.shape = sphere
	bille.add_child(forme)
	bille.add_child(ctx.fx.sphere_lumineuse(0.22, couleur))
	ctx.monde.add_child(bille)

	var consomme: Array[bool] = [false]
	bille.body_entered.connect(func(corps: Node3D) -> void:
		if consomme[0]:
			return
		var objet := corps as PropDestructible
		if objet != null:
			consomme[0] = true
			objet.encaisse(t.baton_trait_degats, bille.global_position)
			ctx.fx.impact(FxLibrary.Impact.ECLAT, bille.global_position, couleur)
			bille.queue_free()
			return
		var avatar := corps as MonsterAvatar
		if avatar == null:
			return
		consomme[0] = true
		ctx.degats(SLOT_BATON, t.baton_trait_degats, [avatar.monster_id])
		ctx.fx.impact(FxLibrary.Impact.ECLAT, bille.global_position, couleur,
			(bille.global_position - avatar.global_position).normalized())
		bille.queue_free())

	var arrivee: Vector3 = bille.position + direction * t.baton_trait_portee
	var tween := ctx.monde.create_tween()
	tween.tween_property(bille, "position", arrivee,
		t.baton_trait_portee / Staff.VITESSE_TRAIT)
	tween.tween_callback(bille.queue_free)
	EventBus.sound_emitted.emit(&"sort", lanceur.position_yeux())
