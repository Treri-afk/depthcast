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
	LIBERER_CURSEUR: [KEY_ESCAPE],
	&"lancer_sort_1": [KEY_1, KEY_KP_1],
	&"lancer_sort_2": [KEY_2, KEY_KP_2],
	&"lancer_sort_3": [KEY_3, KEY_KP_3],
	&"lancer_sort_4": [KEY_4, KEY_KP_4],
}

## Touches numériques, dans l'ordre des slots. Sert aux raccourcis à modificateur.
const TOUCHES_SLOTS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]


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
