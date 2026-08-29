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
## Cibles JOUEURS, par identifiant. Jamais de référence directe à un node : une
## intention doit rester sérialisable pour traverser le réseau.
var target_ids: PackedInt64Array = PackedInt64Array()

## Cibles MONSTRES. Volontairement un champ séparé plutôt qu'un espace
## d'identifiants partagé : un id de joueur et un id de monstre ne se
## confondront jamais par accident, et le resolver n'a rien à deviner.
var target_monsters: PackedInt64Array = PackedInt64Array()
## D'où part l'effet. Sert à l'interface pour indiquer la provenance d'un coup ;
## n'entre jamais dans le calcul des dégâts.
var origine: Vector3 = Vector3.ZERO
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


## Reconstruit une intention reçue du réseau. Le pendant exact de `to_dict()` :
## si l'un des deux oublie un champ, l'effet arrive amputé chez le host et
## personne ne comprend pourquoi le sort fait moins mal en ligne.
static func from_dict(d: Dictionary) -> EffectIntent:
	var i := EffectIntent.new()
	i.source_player_id = int(d.get("source_player_id", 0))
	i.source_slot = int(d.get("source_slot", -1))
	i.kind = int(d.get("kind", 0)) as Kind
	i.effect_id = StringName(d.get("effect_id", ""))
	i.amount = float(d.get("amount", 0.0))
	i.target_ids = PackedInt64Array(d.get("target_ids", []))
	i.target_monsters = PackedInt64Array(d.get("target_monsters", []))
	var o: Array = d.get("origine", [0.0, 0.0, 0.0])
	i.origine = Vector3(o[0], o[1], o[2])
	i.payload = d.get("payload", {})
	return i


func to_dict() -> Dictionary:
	return {
		"source_player_id": source_player_id,
		"source_slot": source_slot,
		"kind": int(kind),
		"effect_id": String(effect_id),
		"amount": amount,
		"target_ids": Array(target_ids),
		"target_monsters": Array(target_monsters),
		"origine": [origine.x, origine.y, origine.z],
		"payload": payload,
		"tick": tick,
		"sequence": sequence,
	}
