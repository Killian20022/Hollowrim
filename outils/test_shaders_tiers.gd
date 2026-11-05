extends SceneTree
## Test sans fenêtre : reprises de shaders PS1 libres (THIRD_PARTY.md).
##  - neige en carrés de pixels (shaders/ps1_flocon.gdshader) : se charge, aucun discard, plafond de taille, branchée par défaut
##    dans monde.gd avec l'interrupteur --neige-psx=0 ;
##  - fondu au noir soustractif en 32 pas (ps1_post.gdshader, uniform fondu_psx) : actif par défaut, ancien fondu gardé ;
##  - mention des licences MIT pour les deux.
##   godot --headless --path . --script res://outils/test_shaders_tiers.gd
var echecs := 0

func _init() -> void:
	_lancer.call_deferred()

func verifier(cond: bool, texte: String) -> void:
	print(("  ok  " if cond else "  ÉCHEC ") + texte)
	if not cond:
		echecs += 1

func _lancer() -> void:
	var flocon := FileAccess.get_file_as_string("res://shaders/ps1_flocon.gdshader")
	verifier(load("res://shaders/ps1_flocon.gdshader") is Shader, "ps1_flocon.gdshader se charge")
	verifier(flocon.find("discard;") < 0, "ps1_flocon : aucun discard (test de profondeur précoce)")
	verifier(flocon.find("uniform float pixels_max") >= 0, "ps1_flocon : taille plafonnée en pixels")
	verifier(flocon.find("floor(centre - cote * 0.5 + 0.5)") >= 0, "ps1_flocon : coin sur un pixel entier")
	var monde := FileAccess.get_file_as_string("res://scripts/monde.gd")
	verifier(monde.find("preload(\"res://shaders/ps1_flocon.gdshader\")") >= 0, "monde.gd charge ps1_flocon")
	verifier(monde.find("\"neige-psx\", \"1\")) != \"0\"") >= 0, "monde.gd : neige pixels par défaut, --neige-psx=0 pour l'ancienne")
	var post := FileAccess.get_file_as_string("res://shaders/ps1_post.gdshader")
	verifier(post.find("uniform bool fondu_psx = true;") >= 0, "ps1_post : fondu PS1 actif par défaut")
	verifier(post.find("floor(fondu * 32.0") >= 0 and post.find("c *= 1.0 - fondu;") >= 0, "ps1_post : fondu en 32 pas + ancien fondu gardé")
	# même calcul que le shader : à mi-fondu, un noir reste noir, un clair garde la moitié de sa valeur
	var f := 0.5
	var pas := floorf(f * 32.0 + 0.001) / 32.0
	verifier(is_equal_approx(maxf(0.2 - pas, 0.0), 0.0) and is_equal_approx(maxf(0.9 - pas, 0.0), 0.4), "fondu soustractif : ombres au noir d'abord")
	var tiers := FileAccess.get_file_as_string("res://THIRD_PARTY.md")
	verifier(tiers.find("dragthelake") >= 0 and tiers.find("Analog Feelings") >= 0 and tiers.count("MIT License") >= 2, "THIRD_PARTY.md : deux licences MIT")
	print("ECHECS : %d" % echecs)
	quit(echecs)
