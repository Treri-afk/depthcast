class_name TestSuite
extends RefCounted
## Base d'une suite de vérifications.
##
## Les tests d'ARCHITECTURE.md sont formulés comme des QUESTIONS auxquelles on
## répond en lisant le code. Ici elles deviennent des assertions exécutables :
## une règle enfreinte devient un test rouge, pas une découverte en jeu.

var echecs: int = 0


func nom() -> String:
	return "Suite"


func execute() -> void:
	push_error("TestSuite.execute() doit être redéfini.")


func verifie(libelle: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ %s" % libelle)
	else:
		echecs += 1
		printerr("  ✗ %s %s" % [libelle, detail])
