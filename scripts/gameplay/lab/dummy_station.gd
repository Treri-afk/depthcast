class_name DummyStation
extends LabStation
## Mannequins : des monstres bien réels, mais sans cible.
##
## Sans cible, MonsterAvatar ne demande rien à son cerveau et reste planté. Ce
## n'est donc pas un mannequin de carton : c'est le monstre du jeu privé de ses
## intentions. Mêmes points de vie, même boîte, mêmes réactions au souffle et
## au ralentissement. Un faux monstre ne mesurerait que lui-même.
##
## L'intelligence se rallume à la demande : c'est le même bouton qui fait
## passer d'un banc de dégâts à un banc de combat.

const DELAI_REARMEMENT: float = 2.0
const ESPACEMENT: float = 3.2

var spawner: MonsterSpawner = null
var ia_active: bool = false

## Ce qu'on remet en place quand un mannequin tombe : son type et sa position.
var _postes: Array[Dictionary] = []
var _etiquettes: Dictionary[int, Label3D] = {}


func titre() -> String:
	return "Mannequins"


func installe() -> void:
	pancarte("MANNEQUINS\n[E] réveiller / rendormir l'IA", 3.6, 34)
	dalle(9.0, Content.palette.estrade)

	var types: Array[StringName] = [&"rodeur", &"brute", &"rodeuse_ailee"]
	for i: int in types.size():
		var decalage := Vector3((float(i) - 1.0) * ESPACEMENT, 0.0, 0.0)
		_postes.append({"id": types[i], "decalage": decalage, "vivant": true})
		_fait_apparaitre(_postes.size() - 1)

	EventBus.monster_died.connect(_sur_mort)
	EventBus.monster_damaged.connect(_sur_degat)


func invite() -> String:
	return "[E] %s l'IA des mannequins" % ("endormir" if ia_active else "réveiller")


func interagit() -> String:
	ia_active = not ia_active
	for poste: Dictionary in _postes:
		var avatar: MonsterAvatar = poste.get("avatar")
		if is_instance_valid(avatar):
			avatar.cible = terrain.joueur if ia_active else null
	return "Mannequins : IA %s." % ("active — ils frappent" if ia_active
		else "coupée — ils encaissent sans bouger")


func _fait_apparaitre(index: int) -> void:
	var poste: Dictionary = _postes[index]
	var stats: MonsterStats = Content.monstre(poste["id"])
	if stats == null:
		return
	var pos: Vector3 = global_position + (poste["decalage"] as Vector3)
	# `cible` à null : l'avatar n'interroge pas son cerveau et reste planté.
	var avatar: MonsterAvatar = spawner.fait_apparaitre(stats, pos,
		terrain.joueur if ia_active else null, 0)
	poste["avatar"] = avatar
	poste["vivant"] = true
	_postes[index] = poste
	_etiquettes[avatar.monster_id] = _etiquette(avatar, stats)


## Les points de vie au-dessus de la tête. C'est la moitié de l'intérêt du
## poste : sans lecture chiffrée, on ne calibre pas un dégât, on le devine.
func _etiquette(avatar: MonsterAvatar, stats: MonsterStats) -> Label3D:
	var label := Label3D.new()
	label.text = "%d" % stats.pv
	label.font_size = 40
	label.pixel_size = 0.004
	label.position = Vector3(0, stats.taille.y * 0.5 + 0.9, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Content.palette.lisere_blanc
	label.outline_size = 9
	label.outline_modulate = Content.palette.encre
	avatar.add_child(label)
	return label


func _sur_degat(monster_id: int, pv_restant: int) -> void:
	var label: Label3D = _etiquettes.get(monster_id)
	if is_instance_valid(label):
		label.text = "%d" % pv_restant


func _sur_mort(monster_id: int, _tueur: int, _recompense: int) -> void:
	_etiquettes.erase(monster_id)
	for index: int in _postes.size():
		var avatar: MonsterAvatar = _postes[index].get("avatar")
		if not is_instance_valid(avatar) or avatar.monster_id != monster_id:
			continue
		avatar.meurt_en_se_dissolvant()
		spawner.avatars.erase(monster_id)
		_postes[index]["vivant"] = false
		# Le réarmement passe par un minuteur de l'arbre et non par un compteur
		# dans _process : rien d'autre ici n'a besoin d'une boucle par frame.
		get_tree().create_timer(DELAI_REARMEMENT).timeout.connect(
			func() -> void:
				if is_instance_valid(self):
					_fait_apparaitre(index))
		return
