extends Node
## Réplication d'état — autoload `Repl`.
##
## Séparé de la session à dessein : `Net` est un annuaire et un cycle de vie,
## ceci est un moteur. Les deux ont des raisons de changer entièrement
## différentes.
##
## ── CE QUI SE RÉPLIQUE, ET CE QUI NE SE RÉPLIQUE PAS ────────────────────
##
## AUTORITATIF — l'état de jeu. Points de vie, Résonance, monstres, sorts
## découverts. Le host décide, les clients obéissent. Tout ce sur quoi un joueur
## prend une décision doit être identique chez tout le monde, sinon deux
## personnes jouent deux parties différentes en croyant jouer la même.
##
## PRÉDIT — son propre corps. On bouge immédiatement chez soi et on annonce sa
## position ; attendre l'aller-retour rendrait le jeu injouable.
##
## JAMAIS RÉPLIQUÉ — le ressenti. Secousse de caméra, arrêt sur image, chiffres
## de dégâts, émotes, culbutes, sons. Chaque machine les joue pour elle. Les
## faire voyager coûterait de la bande passante pour un résultat PIRE : un
## arrêt sur image qui arrive avec quarante millisecondes de retard n'est plus
## un impact, c'est un hoquet.
##
## ── POURQUOI L'ÉTAT ENTIER, ET PAS DES DELTAS ───────────────────────────
##
## GameState se sérialise déjà en entier (R1) — c'était l'une des raisons
## d'écrire cette règle. Diffuser la photo complète dix fois par seconde coûte
## quelques kilo-octets pour une poignée de monstres, et garantit la
## convergence sans protocole à déboguer. Un jeu de deltas se paie en
## divergences silencieuses qu'on découvre trois semaines plus tard.
##
## Le jour où ça devient trop gros, ce sera mesurable et ciblé. Pas avant.

## Photos par seconde. Dix suffisent : les évènements ponctuels partent à part,
## et la photo ne sert qu'à rattraper ce qui aurait glissé.
const TAUX_ETAT: float = 10.0

var _restant: float = 0.0


func _ready() -> void:
	# Le host écoute son propre bus et relaie. Les clients ne relaient rien :
	# ils reçoivent et ré-émettent, ce qui fait marcher toute la présentation
	# existante sans qu'une seule ligne d'interface sache qu'il y a un réseau.
	EventBus.monster_damaged.connect(_relaie_degats_monstre)
	EventBus.monster_died.connect(_relaie_mort_monstre)
	EventBus.player_damaged.connect(_relaie_degats_joueur)


func _process(delta: float) -> void:
	if not Net.en_ligne() or not Net.est_host() or not GameState.is_in_run():
		return
	_restant -= delta
	if _restant > 0.0:
		return
	_restant = 1.0 / TAUX_ETAT
	_recois_l_etat.rpc(GameState.serialize())


## Un client ne modifie jamais l'état lui-même : il décrit son intention et le
## host arbitre. C'est la règle R8, et c'est aussi ce qui empêche un client
## bricolé de s'offrir mille points de vie.
func soumets(intent: EffectIntent) -> void:
	if Net.en_ligne():
		_recois_une_intention.rpc_id(1, intent.to_dict())


# ── Relais du host vers les clients ───────────────────────────────────────

func _peut_relayer() -> bool:
	return Net.en_ligne() and Net.est_host()


func _relaie_degats_monstre(id: int, hp: int, degats: int) -> void:
	if _peut_relayer():
		_recois_degats_monstre.rpc(id, hp, degats)


func _relaie_mort_monstre(id: int, tueur: int, recompense: int) -> void:
	if _peut_relayer():
		_recois_mort_monstre.rpc(id, tueur, recompense)


func _relaie_degats_joueur(id: int, degats: int, origine: Vector3) -> void:
	if _peut_relayer():
		_recois_degats_joueur.rpc(id, degats, origine)


# ── Réception chez les clients ────────────────────────────────────────────

## Les évènements sont RÉ-ÉMIS sur le bus local, à l'identique. Tout ce qui
## écoutait déjà — le son, les chiffres, l'arrêt sur image, la dissolution —
## fonctionne alors sans savoir que l'information vient du réseau.
@rpc("authority", "call_remote", "reliable")
func _recois_degats_monstre(id: int, hp: int, degats: int) -> void:
	EventBus.monster_damaged.emit(id, hp, degats)


@rpc("authority", "call_remote", "reliable")
func _recois_mort_monstre(id: int, tueur: int, recompense: int) -> void:
	EventBus.monster_died.emit(id, tueur, recompense)


@rpc("authority", "call_remote", "reliable")
func _recois_degats_joueur(id: int, degats: int, origine: Vector3) -> void:
	EventBus.player_damaged.emit(id, degats, origine)


@rpc("authority", "call_remote", "unreliable_ordered")
func _recois_l_etat(etat: Dictionary) -> void:
	GameState.deserialize(etat)


@rpc("any_peer", "call_remote", "reliable")
func _recois_une_intention(brut: Dictionary) -> void:
	if not Net.est_host():
		return
	var intent: EffectIntent = EffectIntent.from_dict(brut)
	# L'expéditeur fait foi sur QUI a lancé : un client ne doit pas pouvoir
	# soumettre une intention au nom d'un autre joueur.
	intent.source_player_id = Net.player_id_de(multiplayer.get_remote_sender_id())
	EffectResolver.submit(intent)
