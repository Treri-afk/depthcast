class_name DamageNumber
extends Node3D
## Le chiffre qui monte au-dessus de ce qu'on vient de toucher.
##
## C'est la seule chose du jeu qui dise si l'on progresse. Sans lui, deux sorts
## dont l'un fait le double de dégâts de l'autre se ressemblent : on voit la
## créature blanchir dans les deux cas, et on ne saura jamais lequel choisir.
##
## Il ne dure pas : moins d'une seconde, et il s'efface en montant. Un chiffre
## qui traîne devient un tableau de bord, et on cesse de regarder le combat.

const MONTEE: float = 1.1
const DUREE: float = 0.75

## Décalage horizontal maximal. Deux coups coup sur coup au même endroit se
## superposeraient sans lui, et on ne lirait ni l'un ni l'autre.
const DISPERSION: float = 0.45


static func cree(montant: int, position_monde: Vector3, fatal: bool) -> DamageNumber:
	var chiffre := DamageNumber.new()
	var p: Palette = Content.palette

	var label := Label3D.new()
	label.text = str(montant)
	# Le coup fatal est plus gros et d'une autre couleur : c'est l'information
	# qu'on cherche du coin de l'œil au milieu d'un combat.
	label.font_size = 64 if fatal else 46
	label.pixel_size = 0.0042
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = p.chiffre_fatal if fatal else p.chiffre_degats
	label.outline_size = 12
	label.outline_modulate = p.encre
	chiffre.add_child(label)

	chiffre.position = position_monde + Vector3(
		randf_range(-DISPERSION, DISPERSION), 0.0,
		randf_range(-DISPERSION, DISPERSION))
	chiffre._anime(label)
	return chiffre


func _anime(label: Label3D) -> void:
	# Monté en différé : les tweens demandent d'être dans l'arbre, et l'appelant
	# n'ajoute le nœud qu'après l'avoir construit.
	ready.connect(func() -> void:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "position:y", position.y + MONTEE, DUREE) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "modulate:a", 0.0, DUREE) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(queue_free))
