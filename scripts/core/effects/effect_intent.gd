class_name EffectIntent
extends RefCounted
## Une intention d'effet — ce que produit `cast()`, et rien de plus.
##
## Règle R4 : un sort ne mute JAMAIS l'état. Il décrit ce qu'il voudrait faire,
## et l'Effect Resolver décide si et comment ça s'applique.
##
## C'est ce qui rend le co-op déterministe : deux clients qui reçoivent les mêmes
## intentions, même dans un ordre réseau différent, les trient identiquement grâce
## à `sort_key()` et aboutissent donc au même état.

enum Kind {
	DAMAGE,
	HEAL,
	MOVE,
	SPAWN,
	APPLY_STATUS,
}

## Qui lance.
var source_player_id: int = 0
## Quel slot (0 à 3). -1 si l'intention ne vient pas d'un sort (monstre, environnement).
var source_slot: int = -1

var kind: Kind = Kind.DAMAGE
## Identifiant de la Resource d'effet à l'origine de l'intention.
var effect_id: StringName = &""
var amount: float = 0.0
## Cibles, par identifiant. Jamais de référence directe à un node : une intention
## doit rester sérialisable pour traverser le réseau.
var target_ids: PackedInt64Array = PackedInt64Array()
## Charge utile libre pour les effets qui en ont besoin (direction, rayon…).
var payload: Dictionary = {}

## Tick logique auquel l'intention a été émise. Rempli par le resolver.
var tick: int = 0
## Rang d'arrivée dans le tick. Rempli par le resolver, sert à départager.
var sequence: int = 0


## Clé de tri déterministe.
##
## L'ordre NE DÉPEND PAS de l'ordre d'arrivée des paquets — c'est tout l'enjeu.
## `tick` d'abord, puis `source_player_id` (stable et connu de tous les clients),
## puis `sequence` en dernier recours.
func sort_key() -> Array:
	return [tick, source_player_id, source_slot, sequence]


static func sort_intents(a: EffectIntent, b: EffectIntent) -> bool:
	var ka: Array = a.sort_key()
	var kb: Array = b.sort_key()
	for i: int in ka.size():
		if ka[i] != kb[i]:
			return ka[i] < kb[i]
	return false


func to_dict() -> Dictionary:
	return {
		"source_player_id": source_player_id,
		"source_slot": source_slot,
		"kind": int(kind),
		"effect_id": String(effect_id),
		"amount": amount,
		"target_ids": Array(target_ids),
		"payload": payload,
		"tick": tick,
		"sequence": sequence,
	}
