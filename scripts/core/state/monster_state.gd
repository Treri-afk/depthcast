class_name MonsterState
extends RefCounted
## État d'un monstre. Vit dans RunState, jamais sur le node qui l'affiche.
##
## Même règle que pour les joueurs (R1) : la scène montre le monstre, elle ne
## détient pas ses points de vie. C'est ce qui permettra de répliquer le combat
## en co-op sans que chaque client ait sa propre version de la vérité.
##
## Ce type ne contient que l'état MUTABLE d'une instance. Les caractéristiques
## d'un type de monstre — vitesse, pattern, dégâts — vivront dans une Resource
## `MonsterStats` référencée par `archetype_id` (tâche du cycle C3). C'est la
## séparation donnée / instance exigée par R6.

var monster_id: int = 0

## Identifiant du type. Pointera vers la Resource de stats quand elle existera.
var archetype_id: StringName = &"dummy"

var max_hp: int = 10
var hp: int = 10

## Résonance versée au pot commun à la mort. Proviendra de la Resource de stats,
## jamais d'une valeur en dur dans le code (R7).
var resonance_reward: int = 0

## Les états temporaires portés. Dans l'état, donc sérialisés, donc répliqués
## gratuitement par la photo du host (R1).
var statuts := StatusHolder.new()



func _init(p_id: int = 0, p_max_hp: int = 10, p_reward: int = 0,
		p_archetype: StringName = &"dummy") -> void:
	monster_id = p_id
	max_hp = p_max_hp
	hp = p_max_hp
	resonance_reward = p_reward
	archetype_id = p_archetype


func is_alive() -> bool:
	return hp > 0


## Applique des dégâts et indique si ce coup a tué. Appelé UNIQUEMENT par
## l'EffectResolver (R4) — jamais depuis une scène ni un contrôleur.
func take_damage(amount: int) -> bool:
	if not is_alive() or amount <= 0:
		return false
	hp = maxi(0, hp - amount)
	return hp == 0


func to_dict() -> Dictionary:
	return {
		"monster_id": monster_id,
		"archetype_id": String(archetype_id),
		"max_hp": max_hp,
		"hp": hp,
		"resonance_reward": resonance_reward,
		"statuts": statuts.to_array(),
	}


static func from_dict(d: Dictionary) -> MonsterState:
	var m := MonsterState.new(
		int(d.get("monster_id", 0)),
		int(d.get("max_hp", 10)),
		int(d.get("resonance_reward", 0)),
		StringName(d.get("archetype_id", "dummy")),
	)
	m.hp = int(d.get("hp", m.max_hp))
	m.statuts.depuis_array(d.get("statuts", []))
	return m
