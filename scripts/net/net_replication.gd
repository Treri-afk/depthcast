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
## Envois par seconde pour le mobilier EN MOUVEMENT. Un objet posé n'occupe
## aucune bande passante : on n'envoie que ce qui bouge, et un seul paquet pour
## tout l'étage plutôt qu'un par caisse.
const TAUX_OBJETS: float = 12.0
## En dessous, l'objet est considéré comme immobile et cesse d'être annoncé.
const IMMOBILE: float = 0.05

var _restant: float = 0.0
var _restant_objets: float = 0.0
## Le mobilier de l'étage, dans l'ordre de création. Cet ordre est identique sur
## toutes les machines — la génération est déterministe — donc le RANG suffit à
## désigner une caisse à travers le réseau, sans identifiant à inventer.
var _objets: Array = []


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


func _physics_process(delta: float) -> void:
	if not Net.en_ligne() or not Net.est_host():
		return
	_restant_objets -= delta
	if _restant_objets > 0.0:
		return
	_restant_objets = 1.0 / TAUX_OBJETS

	var bouges: Array = []
	for i: int in _objets.size():
		var corps: PropDestructible = _objets[i]
		if corps == null or not is_instance_valid(corps) or corps.freeze:
			continue
		if corps.linear_velocity.length_squared() < IMMOBILE:
			continue
		bouges.append([i, corps.global_position, corps.rotation])
	if not bouges.is_empty():
		_recois_les_objets.rpc(bouges)


## Le mobilier du nouvel étage. Appelé après chaque génération : les rangs ne
## valent que pour l'étage courant.
func enregistre_les_objets(objets: Array) -> void:
	_objets = objets
	_restant_objets = 0.0


func index_de(corps: PropDestructible) -> int:
	return _objets.find(corps)


func objet_a(index: int) -> PropDestructible:
	if index < 0 or index >= _objets.size():
		return null
	var corps: PropDestructible = _objets[index]
	return corps if is_instance_valid(corps) else null


# ── Ordres du host ────────────────────────────────────────────────────────

## Émis chez tout le monde en même temps, sur l'ordre du host.
signal descente_ordonnee()
## Quelqu'un vient de lancer un sort. Émis chez TOUT LE MONDE, y compris chez
## le lanceur : chaque machine rejoue le comportement pour son propre écran.
signal sort_lance(player_id: int, slot_index: int, direction: Vector3)
## Un monstre vient de tirer. Seul l'hôte fait tourner les cerveaux, donc seul
## lui sait qu'un tir part : sans cette annonce, un client encaisse des
## projectiles qu'il ne voit jamais quitter le canon.
signal tir_ennemi(depuis: Vector3, direction: Vector3, degats: int)
## Le mobilier, par son rang dans la liste de l'étage.
signal objet_amorce(index: int)
signal objet_detruit(index: int)
signal balise_activee(index: int)
signal portage_change(player_id: int, index: int, elan: Vector3)
## Un socle du marchand vient d'être consommé, chez tout le monde.
signal achat_confirme(index_du_socle: int)


## Un joueur veut descendre. Seul le host tranche : sinon un client changerait
## d'étage tout seul et se retrouverait dans un donjon que personne d'autre
## n'habite.
func demande_descente() -> void:
	if Net.est_host():
		_ordonne_la_descente()
	else:
		_demande_la_descente.rpc_id(1)


## Un joueur veut acheter. Même règle : c'est le pot COMMUN qu'on dépense, donc
## c'est le host qui vérifie qu'il y a de quoi. Un client qui déciderait seul
## verrait son achat s'annuler à la photo suivante — ce qui est exactement ce
## qui se passait avant.
func demande_achat(index_du_socle: int) -> void:
	if Net.est_host():
		_traite_achat(index_du_socle)
	else:
		_demande_un_achat.rpc_id(1, index_du_socle)


## Annonce un lancer.
##
## Le sort est REJOUÉ partout, et pas seulement chez son lanceur : c'est ce qui
## fait qu'on voit le mur de flammes d'un coéquipier au lieu d'encaisser des
## dégâts venus de nulle part.
##
## Les dégâts, eux, ne sont comptés qu'une fois — voir EffectResolver.submit().
func annonce_lancer(player_id: int, slot_index: int, direction: Vector3) -> void:
	if Net.en_ligne():
		_recois_un_lancer.rpc(player_id, slot_index, direction)
	else:
		sort_lance.emit(player_id, slot_index, direction)


## `any_peer` : un client lance ses propres sorts. L'identifiant annoncé est
## réécrit d'après l'expéditeur — personne ne lance au nom d'un autre.
@rpc("any_peer", "call_local", "reliable")
func _recois_un_lancer(player_id: int, slot_index: int, direction: Vector3) -> void:
	var expediteur: int = multiplayer.get_remote_sender_id()
	var vrai_id: int = player_id
	if expediteur != 0:
		var declare: int = Net.player_id_de(expediteur)
		if declare >= 0:
			vrai_id = declare
	sort_lance.emit(vrai_id, slot_index, direction)


## Annonces de l'hôte vers tout le monde. Toutes suivent le même patron que les
## sorts : on transporte le FAIT, chaque machine en tire les conséquences chez
## elle. Aucune ne transporte de dégâts — ceux-là ne sont comptés que par
## l'hôte, dans le resolver.
func annonce_tir(depuis: Vector3, direction: Vector3, degats: int) -> void:
	if not Net.est_host():
		return
	if Net.en_ligne():
		_recois_un_tir.rpc(depuis, direction, degats)
	else:
		tir_ennemi.emit(depuis, direction, degats)


func annonce_amorce(corps: PropDestructible) -> void:
	_annonce_sur_objet(corps, &"amorce")


func annonce_destruction(corps: PropDestructible) -> void:
	_annonce_sur_objet(corps, &"detruit")


func annonce_balise(corps: PropDestructible) -> void:
	_annonce_sur_objet(corps, &"balise")


## Porter et lâcher se répliquent comme des ACTIONS, pas comme des positions :
## une fois l'objet dans les mains d'un avatar, il suit ces mains chez tout le
## monde sans qu'un seul octet de plus ne circule.
func annonce_portage(player_id: int, corps: PropDestructible, elan: Vector3) -> void:
	var index: int = index_de(corps) if corps != null else -1
	if Net.en_ligne():
		_recois_un_portage.rpc(player_id, index, elan)
	else:
		portage_change.emit(player_id, index, elan)


func _annonce_sur_objet(corps: PropDestructible, quoi: StringName) -> void:
	# Le mobilier appartient à l'hôte. Un client qui annoncerait se ferait
	# refuser l'appel — autant ne pas l'émettre, et surtout ne pas boucler
	# quand il rejoue ce qu'il vient de recevoir.
	if not Net.est_host():
		return
	var index: int = index_de(corps)
	if index < 0:
		return
	if Net.en_ligne():
		_recois_sur_objet.rpc(index, quoi)
	else:
		_emet_sur_objet(index, quoi)


func _emet_sur_objet(index: int, quoi: StringName) -> void:
	match quoi:
		&"amorce":
			objet_amorce.emit(index)
		&"detruit":
			objet_detruit.emit(index)
		&"balise":
			balise_activee.emit(index)


@rpc("authority", "call_remote", "reliable")
func _recois_un_tir(depuis: Vector3, direction: Vector3, degats: int) -> void:
	tir_ennemi.emit(depuis, direction, degats)


@rpc("authority", "call_remote", "reliable")
func _recois_sur_objet(index: int, quoi: StringName) -> void:
	_emet_sur_objet(index, quoi)


@rpc("any_peer", "call_local", "reliable")
func _recois_un_portage(player_id: int, index: int, elan: Vector3) -> void:
	var expediteur: int = multiplayer.get_remote_sender_id()
	var vrai_id: int = player_id
	if expediteur != 0:
		var declare: int = Net.player_id_de(expediteur)
		if declare >= 0:
			vrai_id = declare
	portage_change.emit(vrai_id, index, elan)


@rpc("authority", "call_remote", "unreliable_ordered")
func _recois_les_objets(bouges: Array) -> void:
	for ligne: Array in bouges:
		var corps: PropDestructible = objet_a(int(ligne[0]))
		if corps != null and not corps.freeze:
			corps.global_position = ligne[1]
			corps.rotation = ligne[2]


func _ordonne_la_descente() -> void:
	if Net.en_ligne():
		_recois_la_descente.rpc()
	else:
		_recois_la_descente()


func _traite_achat(index_du_socle: int) -> void:
	# L'arbitrage lui-même appartient à la salle du marchand : la réplication
	# transporte des décisions, elle n'en prend aucune.
	if Net.en_ligne():
		_recois_un_achat.rpc(index_du_socle)
	else:
		achat_confirme.emit(index_du_socle)


@rpc("any_peer", "call_remote", "reliable")
func _demande_la_descente() -> void:
	if Net.est_host():
		_ordonne_la_descente()


@rpc("any_peer", "call_remote", "reliable")
func _demande_un_achat(index_du_socle: int) -> void:
	if Net.est_host():
		_traite_achat(index_du_socle)


## `call_local` : le host joue l'ordre en même temps que ceux qui le reçoivent.
@rpc("authority", "call_local", "reliable")
func _recois_la_descente() -> void:
	descente_ordonnee.emit()


@rpc("authority", "call_local", "reliable")
func _recois_un_achat(index_du_socle: int) -> void:
	achat_confirme.emit(index_du_socle)


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
