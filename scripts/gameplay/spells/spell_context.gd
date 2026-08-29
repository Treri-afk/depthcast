class_name SpellContext
extends RefCounted
## Ce qu'un comportement de sort a le droit de toucher, et rien de plus.
##
## Ce passage obligé est ce qui empêche un sort d'aller modifier l'état
## directement : les seules mutations possibles sont `degats` et `soin`, qui
## soumettent une intention à l'EffectResolver (R4). Un comportement ne peut
## pas retirer des points de vie même s'il le voulait.

var monde: Node3D
var joueur: PlayerAvatar
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


func objets_valides() -> Array:
	var out: Array = []
	for corps: PropDestructible in objets:
		if is_instance_valid(corps):
			out.append(corps)
	return out


# ── Décor ─────────────────────────────────────────────────────────────────

## Souffle sur le mobilier. `degats_decor` peut rester à zéro : un souffle
## projette le décor, il n'est pas censé le pulvériser.
func souffle_sur_objets(centre: Vector3, rayon: float, puissance: float,
		repousse: bool, degats_decor: int = 0) -> void:
	for corps: PropDestructible in objets_valides():
		var vers: Vector3 = corps.global_position - centre
		var distance: float = vers.length()
		if distance > rayon or distance < 0.05:
			continue
		var sens: Vector3 = vers.normalized() * (1.0 if repousse else -1.0)
		var attenuation: float = 1.0 - clampf(distance / rayon, 0.0, 0.85)
		# Divisé par la masse : une table lourde bouge moins qu'un tonneau.
		corps.apply_central_impulse(
			(sens + Vector3.UP * 0.25) * puissance * attenuation * corps.mass * 0.5)
		if degats_decor > 0:
			corps.encaisse(int(degats_decor * attenuation), centre)


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
