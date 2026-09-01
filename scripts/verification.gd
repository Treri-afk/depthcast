extends Node3D
## Banc de vérification. Il n'exécute rien lui-même : il enchaîne les suites
## de scripts/tests/ et rend un verdict.
##
## Sort en code 1 si une vérification échoue, ce qui fait rougir la CI.

func _suites() -> Array[TestSuite]:
	return [
		ArchitectureTests.new(),
		RulesTests.new(),
		CombatTests.new(),
		ContentTests.new(),
		MetaTests.new(),
		StyleTests.new(),
		FeedbackTests.new(),
		LabTests.new(),
		CoopTests.new(),
		StatusTests.new(),
		DebugTests.new(),
	]


## Nombre minimal de vérifications attendues.
##
## GDScript ne permet pas d'intercepter une erreur d'exécution : une suite qui
## plante s'interrompt en silence, et sans ce garde le lanceur annoncerait
## « tout passe » en ayant sauté la moitié des tests. Si ce nombre baisse après
## une suppression volontaire, ajuste-le — mais regarde d'abord POURQUOI.
const MINIMUM_ATTENDU: int = 260


func _ready() -> void:
	print("─── DepthCast — vérification ───")
	var echecs: int = 0
	var total: int = 0

	for suite: TestSuite in _suites():
		print(suite.nom())
		suite.execute()
		echecs += suite.echecs
		total += suite.executees

	print("────────────────────────────────")
	if total < MINIMUM_ATTENDU:
		echecs += 1
		printerr("✗ %d vérifications exécutées, %d attendues au minimum — "
			% [total, MINIMUM_ATTENDU]
			+ "une suite s'est probablement interrompue.")

	if echecs == 0:
		print("✓ %d vérifications passent" % total)
	else:
		printerr("✗ %d vérification(s) en échec sur %d" % [echecs, total])

	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if echecs > 0 else 0)
