class_name SpellBehaviour
extends RefCounted
## Classe de base d'un comportement de sort.
##
## C'est ici que se joue la règle R6 : ajouter un effet qui réutilise un
## comportement existant ne demande QUE de créer une Resource. Ajouter un
## comportement inédit demande une sous-classe, et ne touche à aucune autre.
##
## Un comportement ne mute jamais l'état lui-même. Il agit sur la scène et
## soumet des intentions via le contexte, qui les fait passer par le resolver.

func lance(_ctx: SpellContext, _slot_index: int, _effet: SpellEffect,
		_couleur: Color, _direction: Vector3) -> void:
	push_error("SpellBehaviour.lance() doit être redéfini par la sous-classe.")
