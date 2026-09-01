class_name Status
extends RefCounted
## Un état temporaire posé sur un joueur ou un monstre.
##
## C'est la tuyauterie de tout ce qui n'est ni un dégât ni un soin : protection,
## provocation, hâte, lenteur, vulnérabilité. Aucun de ces mots n'apparaît dans
## le code — ce sont des noms que la DONNÉE choisit, et le moteur ne connaît que
## les quelques leviers ci-dessous.
##
## ── POURQUOI DES LEVIERS FIXES ET PAS UN ÉTAT PAR COMPORTEMENT ──────────
##
## Un système où chaque état apporte son propre code aurait l'air plus souple ;
## il obligerait surtout à écrire une classe par sort défensif, et R6 serait
## mort dans l'année. Ici un nouvel état est une Resource : un nom, une durée,
## et des facteurs. Aucune ligne de code.
##
## Le vocabulaire est volontairement court. S'il faut un jour un levier de plus,
## on l'ajoute ICI, une fois, et toutes les Resources existantes continuent de
## fonctionner — ce qu'un système à comportements ne permet jamais.
##
## ── POURQUOI DANS L'ÉTAT ────────────────────────────────────────────────
##
## Sérialisé avec le reste (R1), donc répliqué gratuitement par la photo du
## host : un allié voit ta protection s'éteindre au même instant que toi, sans
## qu'une seule ligne de réseau ait été écrite pour ça.

## Le nom porté par l'état. Sert à l'affichage et au remplacement : reposer le
## même état rafraîchit sa durée au lieu de l'empiler indéfiniment.
var id: StringName = &""
## Temps restant, en secondes. Zéro ou moins = l'état est fini.
var restant: float = 0.0
## Qui l'a posé. Sert à la provocation — un monstre provoqué poursuit CELUI qui
## l'a provoqué, et il faut donc savoir qui c'est.
var source_player_id: int = -1

## Multiplie les dégâts REÇUS par le porteur. 0.6 = protégé, 1.4 = vulnérable.
var degats_recus: float = 1.0
## Multiplie les dégâts INFLIGÉS par le porteur.
var degats_infliges: float = 1.0
## Multiplie la vitesse de déplacement.
var vitesse: float = 1.0
## Le porteur — un monstre — poursuit `source_player_id` tant que ça dure.
var provoque: bool = false


static func cree(p_id: StringName, duree: float, source: int = -1) -> Status:
	var etat := Status.new()
	etat.id = p_id
	etat.restant = duree
	etat.source_player_id = source
	return etat


func actif() -> bool:
	return restant > 0.0


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"restant": restant,
		"source_player_id": source_player_id,
		"degats_recus": degats_recus,
		"degats_infliges": degats_infliges,
		"vitesse": vitesse,
		"provoque": provoque,
	}


static func from_dict(d: Dictionary) -> Status:
	var etat := Status.new()
	etat.id = StringName(d.get("id", ""))
	etat.restant = float(d.get("restant", 0.0))
	etat.source_player_id = int(d.get("source_player_id", -1))
	etat.degats_recus = float(d.get("degats_recus", 1.0))
	etat.degats_infliges = float(d.get("degats_infliges", 1.0))
	etat.vitesse = float(d.get("vitesse", 1.0))
	etat.provoque = bool(d.get("provoque", false))
	return etat
