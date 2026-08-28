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


func end_run(is_victory: bool) -> void:
	if run == null:
		return
	run.is_over = true
	run.victory = is_victory
	EventBus.run_ended.emit(run.floor_index, is_victory)


# ── Joueurs (R2 : collection, jamais de singleton) ────────────────────────

func _register_player(player_id: int, display_name: String) -> PlayerState:
	var p := PlayerState.new(player_id, display_name)
	# Les 4 écoles seront choisies avant la run. Placeholder tant que les
	# Resources d'écoles n'existent pas (tâche du cycle C2).
	for slot_index: int in PlayerState.SLOT_COUNT:
		p.slots.append(SpellSlot.new(&"placeholder", 0))
	run.players.append(p)
	EventBus.player_registered.emit(player_id)
	return p


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
		# TODO(C2) : tirer dans le pool réel de l'école, de taille 2 à 5.
		# Ne jamais coder en dur une taille de pool.
		var pool_size: int = 3
		var draw: int = rng.randi_range(0, pool_size - 1)
		if slot.try_reroll(run.floor_index, draw):
			EventBus.slot_rerolled.emit(p.player_id, i, slot.effect_index)
		else:
			EventBus.slot_kept.emit(p.player_id, i)
