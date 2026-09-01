extends CanvasLayer
## Console de développement — autoload `Console`.
##
## Elle existe parce que les raccourcis clavier ne passent pas l'échelle : cinq
## touches se retiennent, vingt s'oublient, et aucune ne prend d'argument. Une
## graine à quatre chiffres, une vitesse à 0,25, un étage précis — tout ça se
## tape, ça ne se mappe pas.
##
## Autoload et pas composant de scène : le menu, le hub, le donjon et le terrain
## d'essai en ont autant besoin l'un que l'autre, et une console qu'il faut
## rebrancher dans chaque racine finit branchée dans une seule.
##
## Elle n'est présente qu'en build de développement. Le contrôle est le même que
## pour DebugCommands : ces commandes changent la run, donc elles ne doivent pas
## exister dans les mains d'un joueur.
##
## Elle NE JOUE PAS : elle appelle les mêmes méthodes que le jeu, jamais une
## voie détournée. Une commande qui écrirait dans l'état sans passer par
## GameState mentirait sur ce qu'elle teste.

## La touche sous Échap, à gauche du 1. On la désigne par sa POSITION physique :
## c'est « ` » en QWERTY, « ² » en AZERTY, et dans les deux cas la place
## qu'occupe une console partout ailleurs.
const TOUCHE_OUVERTURE: Key = KEY_QUOTELEFT

const MEMOIRE_LIGNES: int = 40
const HAUTEUR: float = 0.46

var _racine: Control
var _sortie: RichTextLabel
var _saisie: LineEdit
var _jauge: Label
var _perf: bool = false

var _historique: PackedStringArray = PackedStringArray()
var _rang: int = -1
## Vrai si c'est nous qui avons mis l'arbre en pause. Sans ce drapeau, refermer
## la console relancerait un jeu que quelqu'un d'autre avait suspendu.
var _pause_a_nous: bool = false

var _commandes: Dictionary[String, Callable] = {}
var _aides: Dictionary[String, String] = {}


func _ready() -> void:
	layer = 100
	# Elle doit répondre pendant qu'elle a mis le jeu en pause, sinon la seule
	# façon de la refermer serait de tuer le processus.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not disponible():
		visible = false
		return
	_declare_les_commandes()
	_construit()


func disponible() -> bool:
	return OS.is_debug_build()


func ouverte() -> bool:
	return _racine != null and _racine.visible


# ── Entrées ───────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not disponible():
		return
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo:
		return

	if touche.physical_keycode == TOUCHE_OUVERTURE:
		bascule()
		get_viewport().set_input_as_handled()
		return
	if not ouverte():
		return

	match touche.keycode:
		KEY_ESCAPE:
			bascule()
		KEY_ENTER, KEY_KP_ENTER:
			_valide()
		KEY_UP:
			_rappelle(1)
		KEY_DOWN:
			_rappelle(-1)
		KEY_TAB:
			_complete()
		_:
			return
	get_viewport().set_input_as_handled()


func bascule() -> void:
	if not disponible():
		return
	_racine.visible = not _racine.visible
	if _racine.visible:
		_ouvre()
	else:
		_ferme()


## Le jeu s'arrête pendant qu'on tape — mais SEULEMENT hors ligne.
##
## En ligne, mettre l'arbre en pause couperait la boucle réseau : la connexion
## tomberait au bout de quelques secondes et on aurait débogué un problème qu'on
## vient de créer. À plusieurs, la console laisse donc le jeu tourner.
func _ouvre() -> void:
	_pause_a_nous = not Net.en_ligne() and not get_tree().paused
	if _pause_a_nous:
		get_tree().paused = true
	MouseLook.capture(false)
	_saisie.grab_focus()
	_saisie.clear()
	_rang = -1


func _ferme() -> void:
	if _pause_a_nous:
		get_tree().paused = false
		_pause_a_nous = false
	_saisie.release_focus()


func _valide() -> void:
	var ligne: String = _saisie.text.strip_edges()
	_saisie.clear()
	if ligne.is_empty():
		return
	_historique.insert(0, ligne)
	if _historique.size() > MEMOIRE_LIGNES:
		_historique.resize(MEMOIRE_LIGNES)
	_rang = -1
	ecrit("[color=#7fd0ff]> %s[/color]" % ligne)
	ecrit(execute(ligne))


func _rappelle(pas: int) -> void:
	if _historique.is_empty():
		return
	_rang = clampi(_rang + pas, -1, _historique.size() - 1)
	_saisie.text = "" if _rang < 0 else _historique[_rang]
	_saisie.caret_column = _saisie.text.length()


func _complete() -> void:
	var debut: String = _saisie.text.strip_edges()
	if debut.is_empty():
		return
	var candidats: Array[String] = []
	for nom: String in _commandes:
		if nom.begins_with(debut):
			candidats.append(nom)
	if candidats.size() == 1:
		_saisie.text = candidats[0] + " "
		_saisie.caret_column = _saisie.text.length()
	elif candidats.size() > 1:
		candidats.sort()
		ecrit(" ".join(candidats))


# ── Exécution ─────────────────────────────────────────────────────────────

## Publique et sans interface : c'est ce qui la rend testable, et ce qui
## permettra un jour de rejouer un fichier de commandes.
func execute(ligne: String) -> String:
	var morceaux: PackedStringArray = ligne.strip_edges().split(" ", false)
	if morceaux.is_empty():
		return ""
	var nom: String = morceaux[0].to_lower()
	if not _commandes.has(nom):
		return "[color=#ff9d7a]commande inconnue : %s — tape `aide`[/color]" % nom
	var arguments: Array[String] = []
	for i: int in range(1, morceaux.size()):
		arguments.append(morceaux[i])
	return _commandes[nom].call(arguments)


func _declare_les_commandes() -> void:
	_ajoute("aide", "liste les commandes", _cmd_aide)
	_ajoute("etat", "résumé de la run en cours", _cmd_etat)
	_ajoute("graine", "`graine`, `graine <n>`, `graine libre`", _cmd_graine)
	_ajoute("rejoue", "`rejoue [rang]` relance la run sur une graine passée", _cmd_rejoue)
	_ajoute("historique", "les dernières graines jouées", _cmd_historique)
	_ajoute("tel", "`tel`, `tel ecrit|raz|coupe|actif|marque <texte>`", _cmd_tel)
	_ajoute("etage", "descend d'un étage", _cmd_etage)
	_ajoute("resonance", "`resonance <n>` ajoute au pot commun", _cmd_resonance)
	_ajoute("eclats", "`eclats <n>` ajoute à la monnaie méta", _cmd_eclats)
	_ajoute("vie", "`vie [n]` fixe les points de vie, sans argument rend tout", _cmd_vie)
	_ajoute("tue", "met le joueur local à zéro", _cmd_tue)
	_ajoute("sorts", "les quatre slots du joueur local", _cmd_sorts)
	_ajoute("net", "état de la session réseau", _cmd_net)
	_ajoute("vitesse", "`vitesse <x>` ralentit ou accélère le temps", _cmd_vitesse)
	_ajoute("perf", "affiche ou masque le compteur de performance", _cmd_perf)
	_ajoute("scene", "`scene menu|hub|jeu|labo|salon`", _cmd_scene)
	_ajoute("efface", "vide la console", _cmd_efface)
	_ajoute("quitte", "ferme le jeu", _cmd_quitte)


func _ajoute(nom: String, aide: String, action: Callable) -> void:
	_commandes[nom] = action
	_aides[nom] = aide


func _cmd_aide(_a: Array[String]) -> String:
	var noms: Array[String] = []
	noms.assign(_commandes.keys())
	noms.sort()
	var out := PackedStringArray()
	out.append("[b]Commandes[/b]  ·  Tab complète, ↑ rappelle, Échap ferme")
	for nom: String in noms:
		out.append("  [color=#9fe6a0]%s[/color] — %s" % [nom, _aides[nom]])
	return "\n".join(out)


func _cmd_etat(_a: Array[String]) -> String:
	if GameState.run == null:
		return "hors run — %s" % Net.description()
	var run: RunState = GameState.run
	var out := PackedStringArray()
	out.append("graine %d · étage %d · %d Résonance" % [
		run.run_seed, run.floor_index + 1, run.resonance_pool])
	for p: PlayerState in run.players:
		out.append("  joueur %d — %d/%d PV%s%s" % [p.player_id, p.hp, p.max_hp,
			"  (moi)" if GameState.est_local(p.player_id) else "",
			"  [à terre]" if p.hp <= 0 else ""])
	out.append("  %d monstre(s) en vie" % run.alive_monsters().size())
	return "\n".join(out)


func _cmd_graine(a: Array[String]) -> String:
	if a.is_empty():
		return "\n".join(Rejeu.lignes())
	if a[0] == "libre":
		Rejeu.libere()
		return "graine libérée — la prochaine run tirera la sienne"
	if not a[0].is_valid_int():
		return "il faut un entier, ou `libre`"
	Rejeu.force(a[0].to_int())
	return "graine %d forcée — `scene jeu` ou `rejoue` pour la lancer" % Rejeu.graine_forcee


func _cmd_rejoue(a: Array[String]) -> String:
	var rang: int = a[0].to_int() if not a.is_empty() and a[0].is_valid_int() else 0
	var graine: int = Rejeu.precedente(rang)
	if graine == 0:
		return "rien à ce rang dans l'historique"
	Rejeu.force(graine)
	_change_de_scene(ScreenUtils.CHEMIN_JEU)
	return "rejeu de la graine %d" % graine


func _cmd_historique(_a: Array[String]) -> String:
	return "\n".join(Rejeu.lignes())


func _cmd_tel(a: Array[String]) -> String:
	if a.is_empty():
		return "\n".join(Telemetrie.lignes())
	match a[0]:
		"ecrit":
			var chemin: String = Telemetrie.ecrit()
			return chemin if chemin != "" else "rien à écrire"
		"raz":
			Telemetrie.remet_a_zero()
			return "compteurs remis à zéro"
		"coupe":
			Telemetrie.enregistre = false
			return "télémétrie coupée"
		"actif":
			Telemetrie.enregistre = true
			return "télémétrie active — elle repartira à la prochaine run"
		"marque":
			var texte: String = " ".join(a.slice(1))
			Telemetrie.marque(texte)
			return "marque posée : %s" % texte
	return "`tel ecrit|raz|coupe|actif|marque <texte>`"


func _cmd_etage(_a: Array[String]) -> String:
	if not GameState.is_in_run():
		return "il faut être en run"
	# Par la même porte que le portail : si la descente de debug empruntait un
	# autre chemin, elle ne prouverait rien de la vraie descente.
	Repl.demande_descente()
	return "descente demandée"


func _cmd_resonance(a: Array[String]) -> String:
	if not GameState.is_in_run():
		return "il faut être en run"
	var montant: int = a[0].to_int() if not a.is_empty() and a[0].is_valid_int() else 100
	GameState.add_resonance(montant)
	return "+%d Résonance — pot à %d" % [montant, GameState.run.resonance_pool]


func _cmd_eclats(a: Array[String]) -> String:
	var montant: int = a[0].to_int() if not a.is_empty() and a[0].is_valid_int() else 100
	Meta.gagne_eclats(montant)
	return "+%d Éclats — total %d" % [montant, Meta.eclats]


func _cmd_vie(a: Array[String]) -> String:
	var p: PlayerState = GameState.local_player()
	if p == null:
		return "il faut être en run"
	p.hp = a[0].to_int() if not a.is_empty() and a[0].is_valid_int() else p.max_hp
	return "%d/%d PV" % [p.hp, p.max_hp]


func _cmd_tue(_a: Array[String]) -> String:
	var p: PlayerState = GameState.local_player()
	if p == null:
		return "il faut être en run"
	p.hp = 0
	return "0 PV — la chute suit au prochain tick"


func _cmd_sorts(_a: Array[String]) -> String:
	var p: PlayerState = GameState.local_player()
	if p == null:
		return "il faut être en run"
	var etage: int = GameState.run.floor_index
	var out := PackedStringArray()
	for i: int in p.slots.size():
		var slot: SpellSlot = p.slots[i]
		var ecole: School = Content.ecole(slot.school_id)
		var effet: SpellEffect = ecole.effet(slot.effect_index) if ecole != null else null
		# Le `???` de la console est le MÊME que celui du HUD : une console qui
		# révélerait le slot non découvert mentirait sur ce que le joueur voit.
		var nom: String = "???"
		if slot.is_discovered_on(etage) and effet != null:
			nom = effet.nom
		out.append("  %d · %s — %s%s" % [i + 1,
			ecole.nom if ecole != null else "?", nom,
			"   [scellé jusqu'à l'étage %d]" % (slot.locked_until_floor + 1)
				if slot.is_locked_for(etage + 1) else ""])
	return "\n".join(out)


func _cmd_net(_a: Array[String]) -> String:
	var out := PackedStringArray()
	out.append(Net.description())
	for id: int in Net.joueurs():
		out.append("  %d — %s%s" % [id, Net.nom_du_joueur(id),
			"  (moi)" if GameState.est_local(id) else ""])
	return "\n".join(out)


func _cmd_vitesse(a: Array[String]) -> String:
	if a.is_empty():
		return "vitesse %.2f" % Engine.time_scale
	Engine.time_scale = clampf(a[0].to_float(), 0.05, 8.0)
	return "vitesse %.2f" % Engine.time_scale


func _cmd_perf(_a: Array[String]) -> String:
	_perf = not _perf
	_jauge.visible = _perf
	return "compteur %s" % ("affiché" if _perf else "masqué")


func _cmd_scene(a: Array[String]) -> String:
	var chemins: Dictionary[String, String] = {
		"menu": ScreenUtils.CHEMIN_MENU,
		"hub": ScreenUtils.CHEMIN_HUB,
		"jeu": ScreenUtils.CHEMIN_JEU,
		"labo": ScreenUtils.CHEMIN_LABO,
		"salon": ScreenUtils.CHEMIN_SALON,
	}
	if a.is_empty() or not chemins.has(a[0]):
		return "`scene menu|hub|jeu|labo|salon`"
	_change_de_scene(chemins[a[0]])
	return "→ %s" % a[0]


func _cmd_efface(_a: Array[String]) -> String:
	_sortie.text = ""
	return ""


func _cmd_quitte(_a: Array[String]) -> String:
	get_tree().quit()
	return ""


## Toujours refermer avant de changer de scène : une console laissée ouverte
## garderait l'arbre en pause dans une scène qui n'a rien demandé.
func _change_de_scene(chemin: String) -> void:
	if ouverte():
		bascule()
	get_tree().change_scene_to_file(chemin)


# ── Affichage ─────────────────────────────────────────────────────────────

func ecrit(texte: String) -> void:
	if texte.strip_edges().is_empty() or _sortie == null:
		return
	_sortie.append_text(texte + "\n")


func _process(_delta: float) -> void:
	if not _perf or _jauge == null:
		return
	_jauge.text = "%d ips · %.1f ms · %d appels · %d objets · %.1f Mo" % [
		Engine.get_frames_per_second(),
		1000.0 / maxf(Engine.get_frames_per_second(), 1.0),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]


func _construit() -> void:
	_racine = Control.new()
	_racine.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_racine.anchor_bottom = HAUTEUR
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.visible = false
	add_child(_racine)

	var panneau := PanelContainer.new()
	panneau.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panneau.add_theme_stylebox_override("panel", HudStyle.panneau())
	_racine.add_child(panneau)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panneau.add_child(col)

	_sortie = RichTextLabel.new()
	_sortie.bbcode_enabled = true
	_sortie.scroll_following = true
	_sortie.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sortie.add_theme_font_size_override("normal_font_size", 14)
	col.add_child(_sortie)

	_saisie = LineEdit.new()
	_saisie.placeholder_text = "aide"
	_saisie.custom_minimum_size = Vector2(0, 32)
	col.add_child(_saisie)

	# Le compteur vit HORS du panneau : on veut lire les images par seconde en
	# jouant, pas seulement quand la console masque la moitié de l'écran.
	_jauge = Label.new()
	_jauge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_jauge.offset_left = -420
	_jauge.offset_top = 8
	_jauge.offset_right = -12
	_jauge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_jauge.add_theme_font_size_override("font_size", 13)
	_jauge.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0, 0.85))
	_jauge.visible = false
	add_child(_jauge)

	ecrit("[color=#9fe6a0]Console DepthCast[/color] — `aide` pour la liste.")
