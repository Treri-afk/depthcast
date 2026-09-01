class_name SpellRegistry
extends RefCounted
## Associe chaque comportement déclaré dans les données à sa classe.
##
## C'est le seul endroit du projet qui connaît la liste complète. Ajouter un
## comportement inédit se fait ici, en une ligne — ajouter un SORT, lui, ne
## demande rien du tout : on crée une Resource et on choisit un comportement
## existant dans la liste déroulante.

const C := SpellEffect.Comportement

var _par_comportement: Dictionary = {}


func _init() -> void:
	_par_comportement = {
		C.PROJECTILE: ProjectileBehaviour.new(),
		C.DRAIN: DrainBehaviour.new(),
		C.MUR: WallBehaviour.new(),
		C.TRAINEE: TrailBehaviour.new(),
		C.NOVA: NovaBehaviour.new(),
		C.CONE: ConeBehaviour.new(),
		C.GEL: FrostFieldBehaviour.new(),
		C.TOTEM: TotemBehaviour.new(),
		C.REPULSION: PushBehaviour.new(true),
		C.ATTRACTION: PushBehaviour.new(false),
		C.DASH: DashBehaviour.new(),
		C.TELEPORT: TeleportBehaviour.new(),
		C.SOIN: HealBehaviour.new(),
		C.VOILE: VeilBehaviour.new(),
		C.LEURRE: DecoyBehaviour.new(),
		C.PERMUTATION: SwapBehaviour.new(),
		C.ETAT: StatusBehaviour.new(),
	}


func comportement(type: SpellEffect.Comportement) -> SpellBehaviour:
	return _par_comportement.get(type)


## Vérifie qu'aucun comportement déclaré dans l'enum n'a été oublié ici.
## Appelé par la scène de vérification : un oubli devient une erreur de test,
## pas un sort qui ne fait rien en jeu.
func comportements_manquants() -> Array:
	var out: Array = []
	for nom: String in C.keys():
		if not _par_comportement.has(C[nom]):
			out.append(nom)
	return out
