@tool
class_name School
extends Resource
## Une école de magie : une identité, une couleur, et un pool de 2 à 5 effets.
##
## Ajuster un pool ne touche à aucun code — on glisse une Resource d'effet dans
## la liste, et c'est tout (R6).

const POOL_MIN: int = 2
const POOL_MAX: int = 5

@export var id: StringName = &""
@export var nom: String = "Nouvelle école"
@export var couleur: Color = Color.WHITE
@export_multiline var identite: String = ""

## Les effets possibles. Le reroll tire dans cette liste, et rien dans le code
## ne suppose sa taille : 2 et 5 doivent fonctionner sans cas particulier.
@export var effets: Array[SpellEffect] = []

@export_group("Économie")
@export var cout_verrou_personnalise: bool = false
@export var cout_verrou: int = 0


func taille_pool() -> int:
	return effets.size()


func effet(index: int) -> SpellEffect:
	if index < 0 or index >= effets.size():
		return null
	return effets[index]


func cout_de_scellement(defaut: int) -> int:
	return cout_verrou if cout_verrou_personnalise else defaut


## Signale dans l'éditeur une école dont le pool sort des bornes du GDD.
func _get_configuration_warnings() -> PackedStringArray:
	if effets.size() < POOL_MIN or effets.size() > POOL_MAX:
		return PackedStringArray([
			"Le pool doit contenir entre %d et %d effets (actuellement %d)." % [
				POOL_MIN, POOL_MAX, effets.size()]])
	return PackedStringArray()
