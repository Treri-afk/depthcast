extends Node3D
## Racine du jeu. Elle assemble et relaie, elle n'implémente rien.
##
## Chaque responsabilité vit dans sa propre classe : les entrées, l'éclairage,
## le plan d'étage, le bâtisseur, le meublage, la salle du marchand, le
## spawner, le lanceur de sorts, l'aperçu de téléportation. Si ce fichier
## recommence à grossir, c'est qu'une responsabilité y a été glissée au lieu
## d'être extraite.

const PORTEE_INTERACTION: float = 3.2

## Le socle partagé avec le terrain d'essai : joueur, HUD, sorts.
var _terrain: PlayField
var _joueur: PlayerAvatar
var _hud: GameHud

var _fx: FxLibrary
var _contexte: SpellContext
var _marchand: MerchantRoom
var _spawner: MonsterSpawner
var _etage: FloorDirector

## Slots ayant muté à la dernière descente. Rempli par les signaux, consommé
## par la séquence de reroll.
var _mutations: Array[bool] = []
var _socle_vise: ShopPedestal = null
var _portail_a_portee: bool = false
var _debug := DebugCommands.new()


func _ready() -> void:
	_terrain = PlayField.new(self)
	# La graine ne vient de la session QUE si l'on est en ligne : elle n'existe
	# que pour que deux machines génèrent le même donjon. Hors ligne on passe
	# zéro, et la run en tire une — sinon une partie solo lancée après un salon
	# rejouerait le même étage indéfiniment.
	var graine: int = Net.graine if Net.en_ligne() else 0
	_terrain.monte(graine)
	_joueur = _terrain.joueur
	_hud = _terrain.hud
	_fx = _terrain.fx
	_contexte = _terrain.contexte

	_assemble_le_donjon()
	_branche_les_evenements()
	# Celui qui rejoint rebâtit le décor de l'étage courant, mais ne repeuple
	# pas : ses monstres sont ceux de la photo qu'il vient de recevoir.
	_contexte.objets = _etage.genere(Net.reprise_en_cours)
	Repl.enregistre_les_objets(_contexte.objets)
	Net.reprise_en_cours = false
	_hud.journalise("Nettoie l'étage, va voir le marchand au fond, puis prends le portail.")
	_hud.aide_debug(_debug.aide())


func _physics_process(delta: float) -> void:
	# Un tick de résolution par frame physique : toutes les intentions soumises
	# pendant cette frame sont triées puis appliquées ensemble (R4).
	EffectResolver.resolve_tick()

	if _terrain.sequence_en_cours:
		return

	_terrain.seme_la_trainee(delta)
	_maj_interaction()

	if Input.is_action_just_pressed(InputActions.INTERAGIR):
		_interagit()

	_verifie_la_fin()


func _unhandled_input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if _debug.traite(touche):
		get_viewport().set_input_as_handled()
		return
	if _terrain.traite_raccourci(touche):
		get_viewport().set_input_as_handled()


# ── Assemblage ────────────────────────────────────────────────────────────

## Ce qui appartient au donjon, et rien d'autre. Le joueur, le HUD et les sorts
## sont montés par PlayField : ils sont identiques au terrain d'essai, et le
## jour où ils divergeraient, c'est qu'on aurait cessé de tester le vrai jeu.
func _assemble_le_donjon() -> void:
	var tuning: Tuning = Content.tuning
	var geometrie: Node3D = _terrain.geometrie

	var builder := FloorBuilder.new(geometrie, tuning)
	var furnisher := RoomFurnisher.new(builder, geometrie, tuning)
	_marchand = MerchantRoom.new(geometrie, tuning, _fx)
	_spawner = MonsterSpawner.new(_terrain.conteneur_monstres, tuning)
	_contexte.monstres = _spawner.avatars

	_etage = FloorDirector.new(geometrie, tuning, builder, furnisher,
		_marchand, _spawner, _terrain.avatars)


## La run s'arrête quand PLUS PERSONNE n'est debout — pas quand quelqu'un tombe.
##
## Tomber met à terre ; il faut qu'un soin passe pour se relever. C'est aussi
## pour ça que la décision revient à l'hôte : chaque machine ne jugeait que son
## propre joueur, donc un invité tombé mettait fin à sa run pendant que les
## autres jouaient, et l'hôte tombé l'arrêtait pour toute l'équipe.
func _verifie_la_fin() -> void:
	if not Net.est_host() or not GameState.is_in_run():
		return
	if GameState.run.alive_players().is_empty():
		GameState.end_run(false)


## Fin de run : plus personne debout, ou le boss tombé. Prononcée par l'hôte,
## affichée par tout le monde — d'où le passage par le bus.
func _termine_la_run(victoire: bool) -> void:
	if not GameState.is_in_run():
		return
	GameState.end_run(victoire)


func _montre_l_ecran_de_fin(etage: int, victoire: bool) -> void:
	var graine: int = GameState.run.run_seed if GameState.run != null else 0
	MouseLook.capture(false)

	var ecran := RunEndScreen.new()
	ecran.victoire = victoire
	ecran.etage_atteint = etage
	ecran.seed_run = graine
	var couche := CanvasLayer.new()
	couche.layer = 10
	couche.add_child(ecran)
	add_child(couche)


func _branche_les_evenements() -> void:
	_marchand.achat_effectue.connect(_hud.journalise)
	# Seul l'hôte fait tourner les cerveaux, donc seul lui sait qu'un tir part.
	# Il l'annonce, et chacun crée le projectile chez soi.
	_spawner.monstre_veut_tirer.connect(Repl.annonce_tir)
	Repl.tir_ennemi.connect(_sur_tir_monstre)
	# Un arrivant doit devenir une cible possible pour les monstres déjà en
	# place : leur liste a été COPIÉE au moment de leur apparition, elle ne se
	# met pas à jour toute seule.
	_terrain.avatar_ajoute.connect(func(avatar: PlayerAvatar) -> void:
		for id: int in _spawner.avatars:
			var monstre: MonsterAvatar = _spawner.avatars[id]
			if is_instance_valid(monstre) and not monstre.cibles.has(avatar):
				monstre.cibles.append(avatar)
		_hud.journalise("%s a rejoint la partie." % Net.nom_du_joueur(avatar.player_id)))

	Repl.objet_active.connect(_sur_objet_active)
	Repl.objet_amorce.connect(_sur_objet_amorce)
	Repl.objet_detruit.connect(_sur_objet_detruit)
	Repl.balise_activee.connect(_sur_balise_activee)
	_etage.boss_invoque.connect(_sur_boss_invoque)
	# Sauter un étage passe par la même porte que le portail : le reroll et la
	# régénération doivent se produire exactement comme en jeu normal, sinon on
	# ne teste pas la vraie boucle.
	_debug.saut_d_etage_demande.connect(func() -> void:
		if GameState.is_in_run():
			Repl.demande_descente())
	_debug.message.connect(_hud.journalise)

	Repl.descente_ordonnee.connect(_descend_d_un_etage)
	Repl.achat_confirme.connect(_sur_achat_confirme)

	EventBus.run_ended.connect(_montre_l_ecran_de_fin)
	EventBus.player_downed.connect(_sur_chute)
	EventBus.player_revived.connect(_sur_releve)

	EventBus.monster_damaged.connect(_sur_degat_monstre)
	EventBus.monster_died.connect(_sur_mort_monstre)
	EventBus.slot_rerolled.connect(func(_j: int, slot: int, _e: int) -> void:
		_note_mutation(slot, true))
	EventBus.slot_kept.connect(func(_j: int, slot: int) -> void:
		_note_mutation(slot, false))
	EventBus.resonance_spend_rejected.connect(func(_id: int, raison: String) -> void:
		_hud.journalise("Achat refusé : " + raison))


# ── Interaction ───────────────────────────────────────────────────────────

func _maj_interaction() -> void:
	_socle_vise = _marchand.socle_proche(_joueur.global_position, PORTEE_INTERACTION)
	var distance_portail: float = _marchand.distance_au_portail(_joueur.global_position)
	_portail_a_portee = distance_portail < PORTEE_INTERACTION and _socle_vise == null

	# Pas de portail dans l'arène : la seule sortie est la victoire.
	if _portail_a_portee and not _etage.est_etage_de_boss():
		var restants: int = GameState.run.alive_monsters().size()
		_hud.invite("[E] Descendre à l'étage suivant" if restants == 0
			else "[E] Portail scellé — %d monstre(s) à éliminer" % restants)
	elif _socle_vise != null:
		_hud.invite(_marchand.libelle(_socle_vise))
	else:
		# Rien à acheter, rien à franchir : restent les mains.
		_hud.invite(_joueur.invite_portage())


func _interagit() -> void:
	if _portail_a_portee:
		if not _etage.peut_descendre():
			_hud.journalise("Le portail reste scellé tant que l'étage n'est pas nettoyé.")
			return
		# On DEMANDE la descente, on ne la prend pas : c'est l'hôte qui donne le
		# départ, et tout le monde bascule au même moment.
		Repl.demande_descente()
		return
	if _socle_vise != null:
		Repl.demande_achat(_marchand.index_du_socle(_socle_vise))
		return
	# Rien d'autre à portée : E sert alors les mains. Même priorité que
	# l'invite du HUD, donc ce qui est proposé est ce qui se produit.
	var tenu: PropDestructible = _joueur.objet_porte()
	if tenu != null and tenu.libelle_activation() != "":
		Repl.annonce_activation(_joueur.player_id, tenu)


## L'achat est arbitré par l'hôte, puis rejoué partout : le socle se vide sur
## tous les écrans, et pas seulement sur celui de l'acheteur.
func _sur_achat_confirme(index_du_socle: int) -> void:
	var socle: ShopPedestal = _marchand.socle_par_index(index_du_socle)
	if socle == null:
		return
	if Net.est_host():
		_marchand.achete(socle)
	else:
		# Chez un client, la dépense a déjà eu lieu chez l'hôte et la photo
		# l'apportera. Il ne reste qu'à faire disparaître l'objet du socle.
		socle.consomme()


func _sur_chute(player_id: int) -> void:
	if GameState.est_local(player_id):
		_hud.journalise("Tu es à terre. Il faut qu'un soin t'atteigne.")
	else:
		_hud.journalise("%s est à terre — un soin le relèvera." %
			Net.nom_du_joueur(player_id))


func _sur_releve(player_id: int, par: int) -> void:
	if GameState.est_local(player_id):
		_hud.journalise("Relevé par %s." % Net.nom_du_joueur(par))
	else:
		_hud.journalise("%s est relevé." % Net.nom_du_joueur(player_id))


func _note_mutation(slot: int, mute: bool) -> void:
	while _mutations.size() <= slot:
		_mutations.append(false)
	_mutations[slot] = mute


func _descend_d_un_etage() -> void:
	_mutations.clear()
	_contexte.objets = _etage.descend()
	Repl.enregistre_les_objets(_contexte.objets)
	_terrain.montre_le_reroll(_mutations, GameState.run.floor_index)
	_hud.journalise("Étage %d. Tes sorts non scellés ont muté." %
		(GameState.run.floor_index + 1))


# ── Relais ────────────────────────────────────────────────────────────────

func _sur_tir_monstre(depuis: Vector3, direction: Vector3, degats: int) -> void:
	add_child(EnemyProjectile.cree(_fx, depuis, direction, degats))


## Le mobilier obéit à l'hôte : chez un client, ces trois-là sont les seuls
## chemins par lesquels une caisse s'amorce, se casse ou s'allume.
## L'activation est rejouée chez tout le monde : la mèche s'allume sur tous les
## écrans, et pas seulement dans les mains de celui qui a appuyé.
func _sur_objet_active(player_id: int, index: int) -> void:
	var corps: PropDestructible = Repl.objet_a(index)
	if corps == null:
		return
	var porteur: PlayerAvatar = _terrain.avatar_de(player_id)
	var message: String = corps.active_par(porteur)
	if message != "" and GameState.est_local(player_id):
		_hud.journalise(message)


func _sur_objet_amorce(index: int) -> void:
	var tonneau := Repl.objet_a(index) as ExplosiveProp
	if tonneau != null and not Net.est_host():
		tonneau.amorce()


func _sur_objet_detruit(index: int) -> void:
	var corps: PropDestructible = Repl.objet_a(index)
	if corps != null and not Net.est_host():
		corps.casse_sans_annonce()


func _sur_balise_activee(index: int) -> void:
	var balise := Repl.objet_a(index) as LureBeacon
	if balise != null and not Net.est_host():
		balise.declenche_sans_annonce()


func _sur_degat_monstre(monster_id: int, pv_restant: int, degats: int) -> void:
	var avatar: MonsterAvatar = _spawner.avatars.get(monster_id)
	if is_instance_valid(avatar):
		# Le coup fatal se lit dans les points de vie restants : rien de plus à
		# faire passer, et le chiffre qui tue s'affiche différemment.
		avatar.encaisse_visuellement(degats, pv_restant <= 0)


func _sur_mort_monstre(monster_id: int, _tueur: int, recompense: int) -> void:
	var avatar: MonsterAvatar = _spawner.avatars.get(monster_id)
	var etait_le_boss: bool = avatar is BossAvatar
	if is_instance_valid(avatar):
		avatar.meurt_en_se_dissolvant()
	# Retiré du registre immédiatement : la dissolution est un effet visuel,
	# le monstre ne doit plus compter comme vivant pendant qu'elle joue.
	_spawner.avatars.erase(monster_id)

	if etait_le_boss:
		# Le boss est tombé chez tout le monde, mais un seul prononce la fin.
		if Net.est_host():
			_termine_la_run(true)
		return

	_hud.journalise("+%d Résonance   ·   %d monstre(s) restant(s)" % [
		recompense, GameState.run.alive_monsters().size()])


func _sur_boss_invoque(avatar: BossAvatar) -> void:
	var titre: String = (avatar.stats as BossStats).titre
	_hud.journalise("%s — %d phases. Aucun marchand ici." % [
		titre, (avatar.stats as BossStats).nombre_de_phases()])
	avatar.phase_changee.connect(func(phase: int, total: int) -> void:
		_hud.journalise("%s entre en phase %d sur %d." % [titre, phase + 1, total]))
