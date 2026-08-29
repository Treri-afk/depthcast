class_name SpellContext
extends RefCounted
## Ce qu'un comportement de sort a le droit de toucher, et rien de plus.
##
## Ce passage obligé est ce qui empêche un sort d'aller modifier l'état
## directement : les seules mutations possibles sont `degats` et `soin`, qui
## soumettent une intention à l'EffectResolver (R4). Un comportement ne peut
## pas retirer des points de vie même s'il le voulait.

var monde: Node3D
## Celui qui lance. En coopération, c'est le joueur local.
var joueur: PlayerAvatar
## TOUS les avatars joueurs, lanceur compris. En solo la liste en contient un
## seul et rien ne change ; c'est le passage par une liste, et non par `joueur`,
## qui fera qu'ajouter des coéquipiers ne demandera de toucher à aucun sort.
var joueurs: Array[PlayerAvatar] = []
## monster_id -> MonsterAvatar
var monstres: Dictionary = {}
var objets: Array[PropDestructible] = []
var fx: FxLibrary
var tuning: Tuning


# ── Soumission au resolver ────────────────────────────────────────────────

func degats(slot_index: int, montant: int, ids_monstres: Array) -> void:
	if montant <= 0 or ids_monstres.is_empty():
		return
	var intent := EffectIntent.new()
	intent.source_player_id = joueur.player_id
	intent.source_slot = slot_index
	intent.kind = EffectIntent.Kind.DAMAGE
	intent.amount = montant
	intent.target_monsters = PackedInt64Array(ids_monstres)
	EffectResolver.submit(intent)


func soin(slot_index: int, montant: int) -> void:
	if montant <= 0:
		return
	var intent := EffectIntent.new()
	intent.source_player_id = joueur.player_id
	intent.source_slot = slot_index
	intent.kind = EffectIntent.Kind.HEAL
	intent.amount = montant
	intent.target_ids = PackedInt64Array([joueur.player_id])
	EffectResolver.submit(intent)


# ── Recherche de cibles ───────────────────────────────────────────────────

func monstres_dans_rayon(centre: Vector3, rayon: float) -> Array:
	var out: Array = []
	for id: int in monstres:
		var avatar: MonsterAvatar = monstres[id]
		if is_instance_valid(avatar) and avatar.global_position.distance_to(centre) <= rayon:
			out.append(id)
	return out


func monstres_dans_cone(origine: Vector3, direction: Vector3, portee: float,
		demi_angle: float) -> Array:
	var out: Array = []
	for id: int in monstres:
		var avatar: MonsterAvatar = monstres[id]
		if not is_instance_valid(avatar):
			continue
		var vers: Vector3 = avatar.global_position - origine
		vers.y = 0.0
		if vers.length() > portee or vers.length() < 0.01:
			continue
		if direction.angle_to(vers.normalized()) <= demi_angle:
			out.append(id)
	return out


## Ajoute un corps projetable, et oublie au passage ceux qui ont été détruits.
## Sans ce nettoyage la liste enfle indéfiniment sur un terrain qui réarme son
## mobilier en boucle.
## La liste des avatars, avec repli sur le lanceur seul. Le repli existe pour
## que lancer une scène de jeu directement pendant le développement ne se
## traduise pas par des sorts qui ne poussent plus personne.
func _avatars() -> Array:
	return joueurs if not joueurs.is_empty() else [joueur]


func enregistre_objet(corps: PropDestructible) -> void:
	var vivants: Array[PropDestructible] = []
	# Boucle NON typée, et c'est délibéré : un objet libéré ne se convertit plus
	# en PropDestructible, donc une variable de boucle typée — ou un `filter`
	# dont la lambda est typée — échoue précisément sur les entrées qu'on est en
	# train de venir nettoyer.
	for c in objets:
		if is_instance_valid(c):
			vivants.append(c)
	vivants.append(corps)
	objets = vivants


## Le corps le plus proche de l'AXE de visée — monstre ou coéquipier.
##
## L'angle prime sur la distance : entre une créature à dix mètres pile dans
## l'axe et une autre à trois mètres sur le côté, c'est la première qu'on
## visait. Trier par distance rendrait le sort imprévisible dans une mêlée.
func corps_vise(origine: Vector3, direction: Vector3, portee: float,
		demi_angle: float) -> Node3D:
	var meilleur: Node3D = null
	var meilleur_angle: float = demi_angle

	var candidats: Array = []
	for id: int in monstres:
		candidats.append(monstres[id])
	for avatar in _avatars():
		if avatar != joueur:
			candidats.append(avatar)

	for corps in candidats:
		if not is_instance_valid(corps):
			continue
		var vers: Vector3 = (corps as Node3D).global_position - origine
		var distance: float = vers.length()
		if distance > portee or distance < 0.2:
			continue
		var angle: float = direction.angle_to(vers / distance)
		if angle < meilleur_angle:
			meilleur_angle = angle
			meilleur = corps
	return meilleur


## Rend son cooldown à un slot. Utilisé par les sorts qui peuvent ne rien faire
## faute de cible : payer le temps de recharge pour un sort qui n'a pas eu lieu
## se lit comme une entrée perdue, pas comme une règle.
func annule_le_cooldown(slot_index: int) -> void:
	joueur.demarre_cooldown(slot_index, 0.0)


func objets_valides() -> Array:
	var out: Array = []
	# Non typée pour la même raison qu'au-dessus : la liste contient justement
	# des entrées libérées, et c'est ce qu'on vient y chercher.
	for corps in objets:
		if is_instance_valid(corps):
			out.append(corps)
	return out


# ── Décor ─────────────────────────────────────────────────────────────────

## Déclenche un souffle : il bouscule le mobilier, repousse les monstres, et
## projette le joueur s'il est trop près. Retourne les monstres touchés, que
## l'appelant passe à `degats()` s'il veut aussi les blesser.
##
## La courbe d'atténuation n'est PAS écrite ici : elle vit dans Souffle, et
## c'est la même pour un sort, pour un piège et pour le terrain d'essai. Deux
## copies, et deux explosions du jeu cesseraient de se ressembler.
func souffle(centre: Vector3, rayon: float, puissance: float, repousse: bool,
		degats_decor: int = 0, epargne_le_lanceur: bool = false) -> Array:
	var onde := Souffle.new(centre, rayon, puissance, not repousse)
	onde.epargne_le_lanceur = epargne_le_lanceur
	onde.sur_objets(objets_valides(), degats_decor)
	onde.sur_les_joueurs(_avatars(), tuning, joueur)
	return onde.sur_monstres(monstres, tuning)


func frappe_objets_devant(origine: Vector3, direction: Vector3, portee: float,
		demi_angle: float, degats_decor: int) -> void:
	for corps: PropDestructible in objets_valides():
		var vers: Vector3 = corps.global_position - origine
		vers.y = 0.0
		if vers.length() > portee or vers.length() < 0.05:
			continue
		if direction.angle_to(vers.normalized()) <= demi_angle:
			corps.encaisse(degats_decor, origine)


## Direction visée, aplatie sur le sol. Utile à tout ce qui se pose au sol.
func direction_au_sol(direction: Vector3) -> Vector3:
	var plat := Vector3(direction.x, 0.0, direction.z)
	return plat.normalized() if plat.length_squared() > 0.01 else Vector3.FORWARD
