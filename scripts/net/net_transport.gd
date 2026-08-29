class_name NetTransport
extends RefCounted
## Le tuyau par lequel passent les paquets, et rien d'autre.
##
## Règle R9. Le jeu ne connaît JAMAIS le transport qu'il utilise : il demande à
## héberger ou à rejoindre, il reçoit un pair, il s'en sert. C'est ce qui permet
## de développer et de jouer en réseau local aujourd'hui, sans client Steam, et
## d'échanger le transport le jour de la sortie sans toucher une ligne de
## gameplay.
##
## Ce n'est pas une précaution théorique : Steam impose Windows et un client
## lancé, alors que le co-op se conçoit et se calibre en jouant. Un projet qui
## ne peut essayer son multijoueur qu'en conditions de production ne l'essaie
## jamais.

## Nombre de joueurs qu'une partie accepte (GDD : co-op 2 à 4).
##
## Défini ici et pas dans la session parce que c'est le transport qui ouvre les
## connexions : deux plafonds différents laisseraient entrer un cinquième joueur
## que le jeu ne saurait pas placer.
const JOUEURS_MAX: int = 4

## Message d'erreur du dernier échec, pour l'afficher à l'écran plutôt que dans
## une console que personne ne lit.
var derniere_erreur: String = ""


## Nom lisible du transport, affiché dans le salon.
func nom() -> String:
	return "aucun"


## Ouvre une partie. Retourne false et renseigne `derniere_erreur` en cas d'échec.
func heberge(_port: int) -> MultiplayerPeer:
	push_error("NetTransport.heberge() doit être redéfini.")
	return null


func rejoint(_adresse: String, _port: int) -> MultiplayerPeer:
	push_error("NetTransport.rejoint() doit être redéfini.")
	return null


## Adresse à communiquer aux autres joueurs. Vide si le transport n'en a pas
## (Steam invite par identifiant, pas par adresse).
func adresse_affichable() -> String:
	return ""
