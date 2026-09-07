extends Node
## État central du jeu — autoload `GameState`.
##
## Règle R1 : c'est la feuille de match. Toute donnée de gameplay vit ici, dans
## `run`, jamais en propriété libre sur un node. Les nodes AFFICHENT cet état,
## ils ne le détiennent pas.
##
## Règle R8 : en co-op, seul le host exécute ces méthodes. Un client envoie une
## intention, le host décide, le résultat est diffusé. Les méthodes de mutation
## sont donc écrites comme des opérations autoritaires, sérialisées, qui peuvent
## REFUSER — d'où les `try_*` qui retournent un booléen plutôt que de supposer
## que l'action réussit.

## L'état de la run en cours. `null` hors run (menu, hub).
var run: RunState = null

## Écoles composées au hub, en attente de la descente. Elles traversent le
## changement de scène par l'état plutôt que par un paramètre : GameState fait
## foi, y compris entre deux scènes (R1).
## Les écoles composées au hub, PAR joueur. Clé : `player_id`.
##
## Par joueur et pas globale : en co-op chacun compose la sienne, et c'est le
## sujet même de la préparation — se répartir les écoles au lieu de prendre les
## mêmes. Une liste unique faisait jouer tout le monde avec le même grimoire.
##
## Hors de `run` comme le joueur local : elle survit au changement de scène
## entre le hub et le donjon, mais elle n'appartient à aucune partie en cours.
var ecoles_choisies: Dictionary = {}


## Les écoles d'un joueur. Toujours un tableau, jamais null.
func ecoles_de(player_id: int) -> Array:
	if not ecoles_choisies.has(player_id):
		ecoles_choisies[player_id] = []
	return ecoles_choisies[player_id]


## Prend ou rend une école. Retourne ce qui s'est passé, pour que l'appelant
## sache quoi dire et quel son jouer sans refaire le calcul.
enum Bascule { RETIREE, PRISE, REFUSEE }

func bascule_ecole(player_id: int, id: StringName) -> Bascule:
	var miennes: Array = ecoles_de(player_id)
	if miennes.has(id):
		miennes.erase(id)
		return Bascule.RETIREE
	if miennes.size() >= PlayerState.ECOLES_DEPART:
		return Bascule.REFUSEE
	miennes.append(id)
	return Bascule.PRISE


## Qui a pris cette école. Sert au hub : voir ce que prennent les autres est la
## moitié de l'intérêt d'une préparation à plusieurs.
func porteurs_de(id: StringName) -> Array:
	var out: Array = []
	for player_id: int in ecoles_choisies:
		if (ecoles_choisies[player_id] as Array).has(id):
			out.append(player_id)
	out.sort()
	return out

## Le joueur que CE client contrôle.
##
## Hors de `run` à dessein : il diffère d'une machine à l'autre, donc il ne doit
## ni être sérialisé, ni traverser le réseau, ni entrer dans une comparaison
## d'états entre host et client. Deux clients qui joueraient la même run avec
## des `local_player_id` différents doivent produire exactement le même
## `serialize()`.
##
## C'est le SEUL endroit où la présentation a le droit de demander « qui suis
## je ». Partout ailleurs, un système prend un `player_id` en paramètre (R2).
var local_player_id: int = 0


## L'état du joueur local, ou null hors run.
##
## Remplace les `run.players[0]` semés dans l'interface : en solo le résultat
## est identique, en co-op c'est la seule version correcte.
func local_player() -> PlayerState:
	return null if run == null else run.get_player(local_player_id)


func est_local(player_id: int) -> bool:
	return player_id == local_player_id


## Les états s'écoulent ici, une fois par frame physique, et CHEZ L'HÔTE SEUL.
##
## Le temps qui passe est de l'état comme le reste (R1) : un client qui
## décompterait le sien verrait sa protection s'éteindre à un moment différent
## de celui où elle s'éteint vraiment. La photo le tient à jour.
func _physics_process(delta: float) -> void:
	if run == null or not Net.est_host():
		return
	for p: PlayerState in run.players:
		p.statuts.avance(delta)
	for m: MonsterState in run.monsters:
		m.statuts.avance(delta)


## Pose un état sur un joueur. Passe par ici et pas par le porteur directement :
## c'est le seul endroit qui a le droit d'écrire dans l'état (R1).
func pose_statut_joueur(player_id: int, etat: Status) -> void:
	var p: PlayerState = null if run == null else run.get_player(player_id)
	if p != null:
		p.statuts.pose(etat)
		EventBus.status_applied.emit(player_id, -1, etat.id)


func pose_statut_monstre(monster_id: int, etat: Status) -> void:
	var m: MonsterState = null if run == null else run.get_monster(monster_id)
	if m != null:
		m.statuts.pose(etat)
		EventBus.status_applied.emit(-1, monster_id, etat.id)


func is_in_run() -> bool:
	return run != null and not run.is_over


# ── Cycle de run ──────────────────────────────────────────────────────────

## Démarre une run. `run_seed` à 0 en tire une au hasard.
## Retourne la seed effectivement utilisée, pour l'afficher et la logger.
func start_run(run_seed: int = 0, player_count: int = 1) -> int:
	var effective_seed: int = RngService.seed_run(run_seed)
	run = RunState.new()
	run.run_seed = effective_seed
	run.floor_index = 0
	for i: int in player_count:
		_register_player(i, "Joueur %d" % (i + 1))
	run.begin_floor()
	EventBus.run_started.emit(effective_seed)
	EventBus.floor_entered.emit(run.floor_index)
	print("[GameState] run démarrée — seed %d, %d joueur(s)" % [effective_seed, player_count])
	return effective_seed


## Clôt l'étage courant. C'est la fenêtre d'achat de verrous : le reroll n'a pas
## encore eu lieu. L'ordre importe (ARCHITECTURE.md) — acheter PUIS rerouler.
func complete_floor() -> void:
	if not is_in_run():
		return
	EventBus.floor_completed.emit(run.floor_index)


## Passe à l'étage suivant : reroll des slots non verrouillés, puis remise à zéro
## des compteurs d'étage.
func advance_floor() -> void:
	if not is_in_run():
		return
	run.floor_index += 1
	for p: PlayerState in run.players:
		_reroll_player_slots(p)
	run.begin_floor()
	EventBus.floor_entered.emit(run.floor_index)


## Rejoue la mutation des slots non scellés SANS changer d'étage.
##
## Le donjon n'en a pas besoin — advance_floor() s'en charge — mais le terrain
## d'essai doit pouvoir provoquer l'évènement à volonté, sinon le reroll ne se
## teste qu'en jouant un étage entier.
func reroll_slots(player_id: int) -> void:
	if not is_in_run():
		return
	var p: PlayerState = run.get_player(player_id)
	if p != null:
		_reroll_player_slots(p)


func end_run(is_victory: bool) -> void:
	if run == null:
		return
	run.is_over = true
	run.victory = is_victory
	EventBus.run_ended.emit(run.floor_index, is_victory)


# ── Joueurs (R2 : collection, jamais de singleton) ────────────────────────

## Ajoute un joueur à une run DÉJÀ commencée.
##
## Il arrive debout et à pleine santé : le punir de l'état d'une partie qu'il
## n'a pas jouée n'apprendrait rien à personne, et quelqu'un qui vient de perdre
## sa connexion n'a pas à revenir à terre.
func ajoute_joueur(player_id: int, nom: String = "") -> PlayerState:
	if not is_in_run():
		return null
	var deja: PlayerState = run.get_player(player_id)
	if deja != null:
		# Une reconnexion : on le remet debout plutôt que de le dupliquer.
		if not deja.is_alive():
			deja.hp = maxi(1, deja.max_hp / 2)
		return deja
	return _register_player(player_id, nom)


func _register_player(player_id: int, display_name: String) -> PlayerState:
	var p := PlayerState.new(player_id, display_name)
	# Deux pages, remplacées par `set_player_schools()` juste avant la descente.
	for slot_index: int in PlayerState.SLOTS_DEPART:
		p.slots.append(SpellSlot.new(&"placeholder", 0))
	run.players.append(p)
	EventBus.player_registered.emit(player_id)
	return p


## Compose le grimoire de départ, avant la descente.
##
## `schools` est une liste de dictionnaires {id: StringName, pool_size: int}.
## On n'en lit que la PREMIÈRE : le joueur part avec une seule école et deux
## sorts tirés dedans. La liste reste une liste parce que l'appelant, lui, peut
## en proposer plusieurs — et parce que les pages du marchand viendront s'y
## ajouter par un autre chemin.
##
## Les deux pages peuvent tomber sur le même effet, et c'est voulu : l'école a
## deux à cinq sorts, forcer deux tirages distincts sur un pool de deux
## reviendrait à supprimer le hasard là où il compte le plus.
##
## Le tirage passe par le flux du joueur : deux joueurs qui prennent la même
## école ne démarrent pas forcément sur les mêmes sorts.
func set_player_schools(player_id: int, schools: Array) -> void:
	var p: PlayerState = run.get_player(player_id) if run != null else null
	if p == null or schools.is_empty():
		return
	var rng: RandomNumberGenerator = RngService.player_stream(
		RngService.STREAM_REROLL, player_id
	)
	var def: Dictionary = schools[0]
	var id := StringName(def.get("id", "inconnue"))
	var pool: int = clampi(int(def.get("pool_size", 3)),
		School.POOL_MIN, School.POOL_MAX)

	for i: int in p.slots.size():
		var slot: SpellSlot = p.slots[i]
		slot.school_id = id
		slot.pool_size = pool
		slot.effect_index = rng.randi_range(0, pool - 1)
		slot.locked_until_floor = SpellSlot.NOT_SET
		slot.discovered_on_floor = SpellSlot.NOT_SET


## Ajoute une page d'école au grimoire d'un joueur.
##
## C'est ce que vend le marchand. On achète une ÉCOLE, pas un sort : le sort
## est tiré au hasard dans son pool, et il rerollera comme les autres à chaque
## étage. Acheter une page, c'est donc élargir son grimoire sans jamais savoir
## ce qu'on y met — ce qui est exactement la promesse du jeu, appliquée à
## l'économie plutôt qu'au seul changement d'étage.
##
## Retourne l'index de la page ajoutée, ou -1 si le grimoire est plein.
func ajoute_une_page(player_id: int, school_id: StringName,
		pool_size: int) -> int:
	var p: PlayerState = run.get_player(player_id) if run != null else null
	if p == null or not p.peut_ajouter_une_page():
		return -1
	var rng: RandomNumberGenerator = RngService.player_stream(
		RngService.STREAM_REROLL, player_id
	)
	var pool: int = clampi(pool_size, School.POOL_MIN, School.POOL_MAX)
	var slot: SpellSlot = p.ajoute_une_page(school_id, pool,
		rng.randi_range(0, pool - 1))
	if slot == null:
		return -1
	var index: int = p.slots.size() - 1
	EventBus.page_ajoutee.emit(player_id, index, school_id)
	return index


## Change l'école d'un seul slot, en cours de run.
##
## Outil de comparaison : en jeu, les écoles se choisissent avant la descente
## et ne bougent plus. Cette méthode permet de les confronter sans relancer,
## et servira aussi à l'écran de sélection d'avant-run.
func set_slot_school(player_id: int, slot_index: int, school_id: StringName,
		pool_size: int) -> void:
	var p: PlayerState = run.get_player(player_id) if run != null else null
	if p == null or slot_index < 0 or slot_index >= p.slots.size():
		return
	var slot: SpellSlot = p.slots[slot_index]
	slot.school_id = school_id
	slot.pool_size = clampi(pool_size, 2, 5)
	slot.effect_index = mini(slot.effect_index, slot.pool_size - 1)
	slot.discovered_on_floor = SpellSlot.NOT_SET
	EventBus.slot_rerolled.emit(player_id, slot_index, slot.effect_index)


# ── Monstres ──────────────────────────────────────────────────────────────

## Enregistre un monstre dans l'état de la run et retourne son identifiant.
##
## La scène qui affiche le monstre garde cet id et ne stocke AUCUN point de vie
## de son côté (R1). Les valeurs passées ici viendront d'une Resource de stats
## quand elle existera (C3) — ne jamais les coder en dur dans une scène.
func spawn_monster(max_hp: int, resonance_reward: int,
		archetype_id: StringName = &"dummy") -> int:
	if not is_in_run():
		return -1
	var id: int = run.next_monster_id
	run.next_monster_id += 1
	run.monsters.append(MonsterState.new(id, max_hp, resonance_reward, archetype_id))
	EventBus.monster_spawned.emit(id)
	return id


# ── Résonance : pot commun, autoritaire host (D3) ─────────────────────────

## Ajoute au pot commun. Appelé à la mort d'un monstre, quel que soit le tueur.
func add_resonance(amount: int) -> void:
	if not is_in_run() or amount <= 0:
		return
	run.resonance_pool += amount
	EventBus.resonance_changed.emit(run.resonance_pool)


## Tente une dépense sur le pot commun.
##
## C'est une OPÉRATION CONCURRENTE : en co-op, deux joueurs peuvent acheter au
## même instant. Le host exécute ces appels en série, donc le premier arrivé
## gagne et le second reçoit un refus explicite. Aucune double dépense possible.
func try_spend_resonance(player_id: int, cost: int) -> bool:
	if not is_in_run():
		return false
	if cost < 0:
		return false
	if run.resonance_pool < cost:
		EventBus.resonance_spend_rejected.emit(player_id, "fonds insuffisants")
		return false
	run.resonance_pool -= cost
	EventBus.resonance_changed.emit(run.resonance_pool)
	return true


## Achète un verrou sur un slot pour l'étage suivant.
##
## Le coût est passé en paramètre : il est calculé ailleurs, à partir de la
## Resource de tuning (R7, tâche du cycle C5). GameState ne connaît aucune
## valeur d'équilibrage.
func try_lock_slot(player_id: int, slot_index: int, cost: int) -> bool:
	if not is_in_run():
		return false
	var p: PlayerState = run.get_player(player_id)
	if p == null or slot_index < 0 or slot_index >= p.slots.size():
		return false
	if not try_spend_resonance(player_id, cost):
		return false
	# Un verrou vaut pour l'étage SUIVANT, et seulement lui.
	var until: int = run.floor_index + 1
	p.slots[slot_index].locked_until_floor = until
	p.locks_bought_this_floor += 1
	run.team_locks_this_floor += 1
	EventBus.slot_locked.emit(player_id, slot_index, cost, until)
	return true


# ── Éclats : monnaie méta, individuelle (GDD §3) ──────────────────────────

func add_eclats(player_id: int, amount: int) -> void:
	var p: PlayerState = run.get_player(player_id) if run != null else null
	if p == null or amount <= 0:
		return
	p.eclats += amount
	EventBus.eclats_changed.emit(player_id, p.eclats)


# ── Sérialisation (test de R1) ────────────────────────────────────────────

func serialize() -> Dictionary:
	return {} if run == null else run.to_dict()


func deserialize(d: Dictionary) -> void:
	run = null if d.is_empty() else RunState.from_dict(d)


# ── Interne ───────────────────────────────────────────────────────────────

## Reroll des slots d'un joueur, avec SON flux RNG (D4 : builds indépendants).
## L'ordre dans lequel les joueurs sont traités n'influence aucun tirage.
func _reroll_player_slots(p: PlayerState) -> void:
	var rng: RandomNumberGenerator = RngService.player_stream(
		RngService.STREAM_REROLL, p.player_id
	)
	for i: int in p.slots.size():
		var slot: SpellSlot = p.slots[i]
		# La taille du pool vient du slot, jamais d'une constante : les écoles
		# ont entre 2 et 5 effets et rien ici ne doit supposer un nombre.
		var draw: int = rng.randi_range(0, maxi(2, slot.pool_size) - 1)
		if slot.try_reroll(run.floor_index, draw):
			EventBus.slot_rerolled.emit(p.player_id, i, slot.effect_index)
		else:
			EventBus.slot_kept.emit(p.player_id, i)
