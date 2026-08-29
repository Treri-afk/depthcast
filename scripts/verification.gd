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
	]


func _ready() -> void:
	print("─── DepthCast — vérification ───")
	var echecs: int = 0

	for suite: TestSuite in _suites():
		print(suite.nom())
		suite.execute()
		echecs += suite.echecs

	print("────────────────────────────────")
	if echecs == 0:
		print("✓ toutes les vérifications passent")
	else:
		printerr("✗ %d vérification(s) en échec" % echecs)

	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if echecs > 0 else 0)
