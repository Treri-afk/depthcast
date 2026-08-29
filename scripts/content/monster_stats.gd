@tool
class_name MonsterStats
extends Resource
## Les caractéristiques d'un type de monstre. Créer un nouveau monstre standard
## revient à créer une Resource, sans écrire de code (R6).
##
## Ces valeurs décrivent un TYPE. L'état d'une instance — ses points de vie
## courants — vit dans MonsterState, à l'intérieur de GameState (R1).

@export var id: StringName = &""
@export var nom: String = "Nouveau monstre"
@export var couleur: Color = Color(0.75, 0.3, 0.35)
@export var taille: Vector3 = Vector3(1.1, 1.5, 1.1)

@export_group("Combat")
@export var pv: int = 30
@export var degats: int = 7
@export var resonance: int = 12
@export var portee_frappe: float = 2.0

@export_group("Déplacement")
@export var vitesse: float = 4.0
## Distance à laquelle le monstre tourne autour de sa cible. 0 = il fonce.
@export var distance_garde: float = 5.5

@export_group("Rythme d'attaque")
@export var delai_assaut: float = 2.4
## Durée de la phase de charge. 0 = il frappe dès qu'il est à portée.
@export var duree_assaut: float = 0.45
@export var duree_repli: float = 0.7

@export_group("Vol")
@export var vole: bool = false
@export var hauteur_vol: float = 3.4

@export_group("Tir")
@export var tire: bool = false
@export var vitesse_projectile: float = 13.0
