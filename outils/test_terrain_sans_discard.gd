extends SceneTree
## Test sans fenêtre : le TERRAIN ne doit jamais utiliser un shader avec `discard`.
## Un `discard` dans le fragment shader du sol désactive le test de profondeur précoce : mesuré 2026-11-05, le shader « terrain »
## du relief de la neige (troue le sol sous la couche) passait le feu de camp de 8,4 à 16-17 ms de GPU (×1,9, Iris Xe).
## Le creux de la neige est donc dessiné PAR-DESSUS le sol (variante « couche », profondeur ramenée au niveau du sol).
##   godot --headless --path . --script res://outils/test_terrain_sans_discard.gd
var echecs := 0

func _init() -> void:
	_lancer.call_deferred()

func verifier(cond: bool, texte: String) -> void:
	if cond:
		print("  ok  ", texte)
	else:
		print("  ÉCHEC ", texte)
		echecs += 1

## Les `discard;` de ps1.gdshader (hors commentaires) et le bloc #ifdef qui les contient.
func _discards(code: String) -> Array:
	var piles: Array = []
	var trouves: Array = []
	for ligne in code.split("\n"):
		var l := ligne.strip_edges()
		if l.begins_with("#ifdef ") or l.begins_with("#ifndef "):
			piles.append(l)
		elif l.begins_with("#endif") and not piles.is_empty():
			piles.pop_back()
		var sans_commentaire := l.split("//")[0]
		if sans_commentaire.contains("discard;"):
			trouves.append(piles.duplicate())
	return trouves

func _lancer() -> void:
	var code: String = Palette.PS1.code
	var d := _discards(code)
	verifier(d.size() >= 1, "ps1.gdshader : %d discard (la couche de neige en garde un)" % d.size())
	var tous_dans_couche := true
	for pile in d:
		if not (pile as Array).has("#ifdef RELIEF_COUCHE"):
			tous_dans_couche = false
	verifier(tous_dans_couche, "ps1.gdshader : tout discard est dans #ifdef RELIEF_COUCHE (le shader commun, celui du terrain, n'en a aucun)")
	var m := Palette.materiau(null)
	verifier((m.shader as Shader).code == code, "matériau PS1 commun = ps1.gdshader sans variante")
	verifier(not code.contains("RELIEF_TERRAIN"), "plus de variante RELIEF_TERRAIN")
	verifier(not FileAccess.get_file_as_string("res://scripts/monde.gd").contains("shader_terrain"), "monde.gd ne pose plus de variante de terrain")
	verifier(Palette.shader_couche().code.begins_with("#define RELIEF\n#define RELIEF_COUCHE\n"), "la couche garde sa variante")
	print("ECHECS : %d" % echecs)
	quit(echecs)
