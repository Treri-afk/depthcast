class_name SignatureRegistry
extends RefCounted
## Associe chaque geste déclaré dans les données à sa classe.
##
## Même rôle que `SpellRegistry` pour les comportements, et pour la même
## raison : c'est le seul endroit qui connaît la liste complète. Ajouter un
## geste se fait ici, en une ligne ; le choisir pour un sort ne demande rien du
## tout, c'est une liste déroulante dans l'inspecteur (R6).
##
## Un `match` et non un dictionnaire constant : une référence de classe n'est
## pas une expression constante en GDScript, et un dictionnaire construit au
## chargement se paierait à chaque instanciation.

const G := SpellSignature.Genre


## Un geste inconnu retombe sur la flaque plutôt que sur `null` : un sort sans
## visuel est invisible en jeu, et invisible ne se signale à personne.
static func instancie(genre: SpellSignature.Genre) -> SpellSignature:
	match genre:
		G.ONDE_DE_CHOC:
			return ShockwaveSignature.new()
		G.SPIRALE:
			return SpiralSignature.new()
		G.BRASIER_MURAL:
			return FirewallSignature.new()
		G.BRAISE_AU_SOL:
			return EmbersSignature.new()
		G.PLAQUES_DE_GIVRE:
			return FrostPlatesSignature.new()
		G.ECLATS_DE_GIVRE:
			return FrostShardsSignature.new()
		G.REMPART:
			return BulwarkSignature.new()
		G.PETALES:
			return PetalsSignature.new()
		G.TOTEM_VIVANT:
			return TotemSignature.new()
		G.DISSOLUTION:
			return DissolveSignature.new()
		G.COMETE:
			return CometSignature.new()
		G.ESQUILLE:
			return SplinterSignature.new()
		G.FILET:
			return TetherSignature.new()
		G.ANNEAUX_LIES:
			return LinkedRingsSignature.new()
		G.SILLAGE:
			return WakeSignature.new()
		G.MANNEQUIN:
			return DecoySignature.new()
		G.PORTE_D_OMBRE:
			return ShadowGateSignature.new()
	return PoolSignature.new()


## Vérifie qu'aucun geste déclaré dans l'enum n'a de classe manquante.
##
## Appelé par la scène de vérification. Sans lui, ajouter une entrée à l'enum
## sans l'inscrire ici donnerait un sort qui s'affiche en flaque, et personne ne
## le remarquerait avant de le voir en jeu — c'est-à-dire jamais, puisque c'est
## précisément le défaut que ces signatures corrigent.
static func gestes_manquants() -> Array:
	var out: Array = []
	for nom: String in G.keys():
		var genre: SpellSignature.Genre = G[nom]
		if genre == G.NAPPE:
			continue
		if instancie(genre) is PoolSignature:
			out.append(nom)
	return out
