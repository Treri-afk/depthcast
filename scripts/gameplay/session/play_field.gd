class_name PlayField
extends RefCounted
## Le socle commun au donjon et au terrain d'essai.
##
## Un joueur en vue subjective, son HUD, la bibliothèque d'effets, le contexte
## et le lanceur de sorts : exactement ce qu'il faut pour lancer un sort dans un
## décor, et rien qui concerne le donjon.
##
## Il existe parce que le terrain d'essai a besoin du MÊME équipement que le
## jeu. Sans lui, la seconde copie de l'assemblage divergerait dès la première
## retouche — et on testerait alors autre chose que le jeu.
##
## Comme MerchantRoom ou RoomFurnisher, c'est un assembleur : il n'entre pas
## dans l'arbre, il y accroche des nœuds.

var racine: Node3D
var geometrie: Node3D
var conteneur_monstres: Node3D
var couche_ui: CanvasLayer

## Émis quand la séquence de reroll se referme et que le contrôle est rendu.
signal sequence_terminee()
## Un corps vient d'apparaître pour quelqu'un qui a rejoint en cours de partie.
signal avatar_ajoute(avatar: PlayerAvatar)

## Vrai pendant la séquence de reroll : la racine doit suspendre sa boucle.
var sequence_en_cours: bool = false

## Tous les avatars, dans l'ordre des identifiants de joueur.
var avatars: Array[PlayerAvatar] = []
## Celui que ce client contrôle. Toujours présent dans `avatars`.
var joueur: PlayerAvatar
var hud: GameHud
var fx: FxLibrary
var contexte: SpellContext
var caster: SpellCaster


func _init(p_racine: Node3D) -> void:
	racine = p_racine


## Monte une session complète.
##
## Elle ouvre la run elle-même, et c'est délibéré : le nombre de joueurs décide
## du nombre d'avatars, donc l'état doit exister avant le monde. Les racines
## dupliquaient cet appel, chacune avec ses propres oublis.
## `combat` à faux monte un terrain SANS run, sans sorts et sans HUD de jeu :
## c'est le hub. Il y a quand même des corps, une caméra et une réplication —
## c'est exactement ce qui manquait au hub pour être jouable à plusieurs, et
## c'est déjà écrit ici.
func monte(graine: int = 0, combat: bool = true) -> void:
	InputActions.declare()
	WorldLighting.installe(racine)
	_conteneurs()
	if combat:
		if Net.reprise_en_cours:
			# L'état vient d'arriver du host : l'écraser par une run neuve
			# effacerait exactement ce qu'on vient de recevoir.
			RngService.seed_run(graine)
		else:
			_ouvre_la_run(graine)
	_joueurs()
	if combat:
		_interface()
		_services()
		_branche_le_ressenti()


func _ouvre_la_run(graine: int) -> void:
	GameState.start_run(graine, Net.nombre_de_joueurs())
	# Chacun descend avec SA composition. C'est tout l'objet du hub : se
	# répartir les écoles plutôt que partir avec le même grimoire.
	for etat: PlayerState in GameState.run.players:
		GameState.set_player_schools(etat.player_id, definitions_de(etat.player_id))


func _conteneurs() -> void:
	geometrie = Node3D.new()
	geometrie.name = "Geometrie"
	racine.add_child(geometrie)

	conteneur_monstres = Node3D.new()
	conteneur_monstres.name = "Monstres"
	racine.add_child(conteneur_monstres)


func _joueurs() -> void:
	# La liste vient de la SESSION, pas de la run : le hub n'a pas de run, et
	# pourtant il a besoin d'un corps par joueur connecté.
	for player_id: int in Net.joueurs():
		var avatar := _cree_avatar(player_id)
		avatars.append(avatar)
		if avatar.local:
			joueur = avatar
	# Il y a toujours un avatar local : sans lui, personne ne tient la caméra
	# et l'écran reste noir sans dire pourquoi.
	if joueur == null and not avatars.is_empty():
		push_error("Aucun avatar local : local_player_id ne correspond à personne.")

	# Quelqu'un peut arriver APRÈS le montage du monde. Sans ça, celui qui
	# rejoint voyait tout le monde, et personne ne le voyait — le pire des deux
	# cas, parce qu'il se croit là et se demande pourquoi on l'ignore.
	Net.roster_change.connect(_accueille_les_nouveaux)


## Crée les corps manquants et retire ceux qui sont partis.
func _accueille_les_nouveaux() -> void:
	var attendus: Array[int] = Net.joueurs()
	for player_id: int in attendus:
		if avatar_de(player_id) == null:
			var avatar := _cree_avatar(player_id)
			avatars.append(avatar)
			avatar_ajoute.emit(avatar)

	# Et le corps de celui qui s'en va s'en va avec lui : le laisser planté au
	# milieu de la salle ferait tirer dessus.
	for avatar: PlayerAvatar in avatars.duplicate():
		if not attendus.has(avatar.player_id):
			avatars.erase(avatar)
			if is_instance_valid(avatar):
				avatar.queue_free()


func _cree_avatar(player_id: int) -> PlayerAvatar:
	var avatar := PlayerAvatar.new()
	avatar.player_id = player_id
	avatar.local = GameState.est_local(player_id)
	avatar.name = "Joueur%d" % player_id
	# Écartés au départ : empilés au même point, les corps se repoussent et
	# partent en gerbe au premier tick physique.
	avatar.position = Vector3(float(player_id) * 1.6, 1.2, 0)

	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.0
	forme.shape = capsule
	avatar.add_child(forme)
	racine.add_child(avatar)

	# Le post-traitement s'accroche à la SEULE caméra active : c'est un quad de
	# la passe 3D, et il n'y a qu'un écran.
	if avatar.local:
		avatar.camera.add_child(PostProcess.cree(Content.palette))
		# La poussière est accrochée à la RACINE et suit la caméra : enfant de
		# la caméra, elle tournerait avec le regard et les grains colleraient à
		# l'écran comme de la saleté sur l'objectif.
		racine.add_child(DustMotes.cree(avatar.camera))

	# La réplication est posée même hors ligne : elle ne fait alors rien, et
	# l'arbre reste identique dans les deux modes. Un arbre qui change selon
	# qu'on est connecté est un arbre dont les chemins d'appel distant ne
	# correspondent plus d'une machine à l'autre.
	var peer: int = Net.peer_de(player_id)
	avatar.add_child(AvatarSync.cree(avatar, peer if peer > 0 else 1))
	return avatar


func _interface() -> void:
	couche_ui = CanvasLayer.new()
	# Calque 0 : au-dessus de la trame pixel, qui vit en -1. Le texte reste net.
	couche_ui.layer = 0
	racine.add_child(couche_ui)

	hud = GameHud.new()
	hud.joueur = joueur
	hud.ecole_changee.connect(change_ecole)
	couche_ui.add_child(hud)

	var degats := DamageIndicator.new()
	degats.joueur = joueur
	couche_ui.add_child(degats)


func _services() -> void:
	fx = FxLibrary.new(racine)

	contexte = SpellContext.new()
	contexte.monde = racine
	contexte.joueur = joueur
	contexte.joueurs = avatars
	contexte.fx = fx
	contexte.tuning = Content.tuning
	caster = SpellCaster.new(contexte)
	hud.caster = caster

	# On ANNONCE le lancer au lieu de l'exécuter directement. Hors ligne
	# l'annonce revient immédiatement et rien ne change ; en ligne elle part
	# chez tout le monde, et chaque machine rejoue le sort pour son écran.
	joueur.a_lance.connect(func(slot: int, dir: Vector3) -> void:
		Repl.annonce_lancer(joueur.player_id, slot, dir))
	Repl.sort_lance.connect(_joue_un_sort)
	Repl.portage_change.connect(_joue_un_portage)
	for avatar: PlayerAvatar in avatars:
		avatar.portage_change.connect(
			func(corps: PropDestructible, elan: Vector3, prend: bool) -> void:
				Repl.annonce_portage(avatar.player_id, corps if prend else null, elan))

	var apercu := TeleportPreview.new()
	apercu.joueur = joueur
	apercu.caster = caster
	racine.add_child(apercu)


## L'arrêt sur image, branché ici et pas dans les racines : c'est du ressenti,
## il vaut pour le donjon comme pour le terrain d'essai, et il ne doit exister
## qu'en un seul exemplaire — deux abonnements figeraient le jeu deux fois.
func _branche_le_ressenti() -> void:
	var t: Tuning = Content.tuning
	EventBus.monster_died.connect(func(_id: int, _tueur: int, _r: int) -> void:
		HitStop.frappe(t.hitstop_mort, t.hitstop_echelle))
	# Seulement les vrais coups : figer le jeu à chaque égratignure le ferait
	# hoqueter en permanence, et l'effet perdrait tout son sens.
	EventBus.player_damaged.connect(func(_j: int, degats: int, _o: Vector3) -> void:
		if degats >= t.hitstop_seuil_degats:
			HitStop.frappe(t.hitstop_blessure, t.hitstop_echelle))


## Rejoue le sort de n'importe quel joueur, y compris le nôtre.
func _joue_un_sort(player_id: int, slot_index: int, direction: Vector3) -> void:
	var lanceur: PlayerAvatar = avatar_de(player_id)
	if lanceur != null:
		caster.lance(slot_index, direction, lanceur)


## Rejoue le geste d'un coéquipier. Le nôtre a déjà eu lieu — on l'ignore, sinon
## on lâcherait ce qu'on vient de prendre.
func _joue_un_portage(player_id: int, index: int, elan: Vector3) -> void:
	var porteur: PlayerAvatar = avatar_de(player_id)
	if porteur == null or porteur.local:
		return
	if index >= 0:
		porteur.ramasse(Repl.objet_a(index))
	else:
		porteur.lache(elan)


func avatar_de(player_id: int) -> PlayerAvatar:
	for avatar: PlayerAvatar in avatars:
		if is_instance_valid(avatar) and avatar.player_id == player_id:
			return avatar
	return null


## La traînée s'étale dans le temps : le joueur mémorise où semer, le terrain
## instancie. Aucun des deux ne connaît la logique de l'autre.
func seme_la_trainee(delta: float) -> void:
	# TOUS les avatars, pas seulement le nôtre : une traînée ardente est armée
	# sur l'avatar de celui qui l'a lancée, et si l'on ne consommait que la
	# sienne, le sol ne s'embraserait jamais sous les pas d'un coéquipier.
	for avatar: PlayerAvatar in avatars:
		if is_instance_valid(avatar):
			_seme_pour(avatar, delta)


func _seme_pour(avatar: PlayerAvatar, delta: float) -> void:
	var flaque: Dictionary = avatar.consomme_flaque(delta)
	if flaque.is_empty():
		return
	var effet: SpellEffect = flaque["effet"]
	var pos: Vector3 = flaque["position"]
	var zone := ZoneEffet.cree(ZoneEffet.Forme.SPHERE,
		Vector3(effet.rayon, 0, 0), Vector3(pos.x, 0.4, pos.z))
	zone.duree = effet.duree_secondaire
	zone.intervalle = effet.intervalle
	zone.degats = effet.degats
	zone.source_slot = int(flaque["slot"])
	zone.couleur = flaque["couleur"]
	zone.allure = flaque["allure"]
	racine.add_child(zone)


## Arrête le jeu et présente ce que le grimoire a réécrit.
##
## Le contrôle est confisqué pendant la séquence : un évènement qu'on peut
## ignorer en courant n'est pas un évènement.
##
## Ici et pas dans la racine du donjon, parce que le terrain d'essai doit
## pouvoir rejouer ce moment à volonté — c'est le plus difficile à calibrer du
## jeu, et le seul qu'on ne voyait qu'en jouant un étage entier.
func montre_le_reroll(mutations: Array[bool], etage: int) -> void:
	sequence_en_cours = true
	MouseLook.capture(false)
	joueur.set_physics_process(false)

	var sequence := RerollSequence.new()
	sequence.mutations = mutations.duplicate()
	sequence.etage = etage

	var couche := CanvasLayer.new()
	couche.layer = 5
	couche.add_child(sequence)
	racine.add_child(couche)

	sequence.terminee.connect(func() -> void:
		sequence_en_cours = false
		joueur.set_physics_process(true)
		MouseLook.capture(true)
		couche.queue_free()
		sequence_terminee.emit())


## Maj + 1 à 4 fait défiler les écoles sur un slot. Outil de comparaison : en
## jeu, les écoles se choisissent au hub et ne bougent plus de la descente.
## Retourne true si la touche a été consommée.
func traite_raccourci(touche: InputEventKey) -> bool:
	if touche == null or not touche.pressed or touche.echo or not touche.shift_pressed:
		return false
	var index: int = InputActions.TOUCHES_SLOTS.find(touche.physical_keycode)
	if index < 0:
		return false
	change_ecole(index, 1)
	return true


func change_ecole(slot_index: int, pas: int) -> void:
	var total: int = Content.ecoles.size()
	if total == 0 or not GameState.is_in_run():
		return
	var slot: SpellSlot = GameState.local_player().slots[slot_index]
	var index: int = (Content.index_ecole(slot.school_id) + pas + total) % total
	var suivante: School = Content.ecoles[index]
	GameState.set_slot_school(GameState.local_player_id, slot_index,
		suivante.id, suivante.taille_pool())
	hud.journalise("Slot %d passe à %s — %d effets possibles." % [
		slot_index + 1, suivante.nom, suivante.taille_pool()])


## Les écoles composées au hub par UN joueur. En leur absence — lancement direct
## d'une scène pendant le développement — on retombe sur les premières
## débloquées plutôt que de planter.
static func definitions_de(player_id: int) -> Array:
	var ids: Array = GameState.ecoles_de(player_id)
	if ids.is_empty():
		for ecole: School in Meta.ecoles_disponibles():
			if ids.size() < PlayerState.SLOT_COUNT:
				ids.append(ecole.id)
	var out: Array = []
	for id: StringName in ids:
		var ecole: School = Content.ecole(id)
		if ecole != null:
			out.append({"id": ecole.id, "pool_size": ecole.taille_pool()})
	return out
