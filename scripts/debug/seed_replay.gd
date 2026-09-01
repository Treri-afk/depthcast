extends Node
## Rejeu par graine — autoload `Rejeu`.
##
## R3 promet qu'une même graine redonne le même donjon, les mêmes rerolls et le
## même butin. Cette promesse ne vaut rien tant qu'on ne peut pas la déclencher :
## quand une run part de travers, il faut pouvoir la relancer À L'IDENTIQUE,
## sinon on corrige à l'aveugle sur une autre partie que celle qui a cassé.
##
## Deux usages, et ils se rejoignent :
##   - forcer une graine connue, copiée depuis l'écran de fin ou un rapport
##   - reprendre la précédente, sans avoir rien copié — c'est le cas fréquent,
##     parce qu'on ne sait qu'APRÈS coup qu'une run méritait d'être revue
##
## L'historique survit à une fermeture du jeu : le plantage qu'on veut rejouer
## est justement celui qui a emporté le processus avec lui.

const CHEMIN := "user://rejeu.json"
const MEMOIRE: int = 20

## Émis quand la graine forcée change. Les écrans qui l'affichent écoutent —
## jouer sur une graine figée sans le savoir ferait passer un bug reproductible
## pour un bug permanent.
signal graine_forcee_changee(graine: int)

## 0 = aucune contrainte, chaque run tire la sienne.
var graine_forcee: int = 0

## Les dernières graines jouées, la plus récente en tête.
var historique: Array[int] = []


func _ready() -> void:
	_charge()
	EventBus.run_started.connect(_note)


func actif() -> bool:
	return graine_forcee != 0


## La graine à employer pour la run qui démarre.
##
## `proposee` est ce que la situation dicte — la graine du salon en ligne, ou
## zéro en solo. La contrainte de rejeu passe devant : c'est tout son objet.
func graine_a_utiliser(proposee: int) -> int:
	return graine_forcee if actif() else proposee


func force(graine: int) -> void:
	graine_forcee = graine
	graine_forcee_changee.emit(graine)


func libere() -> void:
	force(0)


## La n-ième graine en remontant : 0 est la dernière jouée. Retourne 0 si
## l'historique ne va pas si loin.
func precedente(rang: int = 0) -> int:
	return 0 if rang < 0 or rang >= historique.size() else historique[rang]


func lignes() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("graine forcée : %d" % graine_forcee if actif()
		else "graine libre — chaque run tire la sienne")
	if historique.is_empty():
		out.append("aucune run enregistrée")
		return out
	for rang: int in historique.size():
		out.append("  [%d] %d%s" % [rang, historique[rang],
			"  ← forcée" if historique[rang] == graine_forcee else ""])
	return out


## Une graine jouée entre dans l'historique. Rejouer la même ne la duplique
## pas : on veut vingt runs différentes en mémoire, pas vingt fois la même.
func _note(graine: int) -> void:
	if graine == 0:
		return
	historique.erase(graine)
	historique.push_front(graine)
	if historique.size() > MEMOIRE:
		historique.resize(MEMOIRE)
	_sauve()


func _sauve() -> void:
	var f := FileAccess.open(CHEMIN, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"historique": historique}))
	f.close()


func _charge() -> void:
	if not FileAccess.file_exists(CHEMIN):
		return
	var f := FileAccess.open(CHEMIN, FileAccess.READ)
	if f == null:
		return
	var contenu: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if contenu is not Dictionary:
		return
	# Le fichier vient du disque : il a pu être édité à la main, tronqué par un
	# plantage ou écrit par une version plus ancienne. On ne lui fait confiance
	# sur rien, et un fichier illisible coûte l'historique, jamais le démarrage.
	for valeur: Variant in (contenu as Dictionary).get("historique", []):
		if valeur is float or valeur is int:
			historique.append(int(valeur))
	if historique.size() > MEMOIRE:
		historique.resize(MEMOIRE)
