class_name InputActions
extends RefCounted
## Déclare les actions d'entrée à l'exécution.
##
## Le projet ne dépend ainsi d'aucun réglage manuel dans les paramètres du
## projet : cloner le dépôt suffit à avoir des touches qui marchent. Les
## constantes évitent qu'une faute de frappe crée silencieusement une action
## fantôme jamais déclenchée.

const AVANT := &"deplacer_avant"
const ARRIERE := &"deplacer_arriere"
const GAUCHE := &"deplacer_gauche"
const DROITE := &"deplacer_droite"
const SAUTER := &"sauter"
const INTERAGIR := &"interagir"
const LIBERER_CURSEUR := &"liberer_curseur"
const TIRER := &"tirer"
## Le trait du bâton, au clic droit. Voir `declare()` pour pourquoi il partage
## la touche avec la reprise de visée.
const TRAIT := &"trait_baton"
const PORTER := &"porter"
const LANCER := &"lancer"
const COURIR := &"courir"

## Nom de l'action de lancement d'un slot donné.
static func sort(slot_index: int) -> StringName:
	return StringName("lancer_sort_%d" % (slot_index + 1))


const TOUCHES: Dictionary = {
	AVANT: [KEY_W, KEY_Z, KEY_UP],
	ARRIERE: [KEY_S, KEY_DOWN],
	GAUCHE: [KEY_A, KEY_Q, KEY_LEFT],
	DROITE: [KEY_D, KEY_RIGHT],
	SAUTER: [KEY_SPACE],
	INTERAGIR: [KEY_E],
	PORTER: [KEY_F],
	COURIR: [KEY_SHIFT],
	LANCER: [KEY_G],
	LIBERER_CURSEUR: [KEY_ESCAPE],
	&"lancer_sort_1": [KEY_1, KEY_KP_1],
	&"lancer_sort_2": [KEY_2, KEY_KP_2],
	&"lancer_sort_3": [KEY_3, KEY_KP_3],
}

## Touches numériques, dans l'ordre des slots. Sert aux raccourcis à
## modificateur. Elle en compte autant que le grimoire peut tenir de pages —
## une touche de plus désignerait une page qui n'existe pas.
const TOUCHES_SLOTS: Array[Key] = [KEY_1, KEY_2, KEY_3]


static func declare() -> void:
	for action: StringName in TOUCHES:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code: int in TOUCHES[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)

	if not InputMap.has_action(TIRER):
		InputMap.add_action(TIRER)
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(TIRER, clic)

	# Le clic droit sert à DEUX choses, et jamais en même temps : reprendre la
	# visée quand le curseur est libre, tirer au bâton quand il est capturé.
	# C'est la convention du genre, et elle évite de sacrifier une touche pour
	# une commande qu'on n'utilise qu'en sortant du jeu.
	if not InputMap.has_action(TRAIT):
		InputMap.add_action(TRAIT)
	var clic_droit := InputEventMouseButton.new()
	clic_droit.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event(TRAIT, clic_droit)
