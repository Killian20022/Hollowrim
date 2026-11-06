extends SceneTree
## Test sans fenêtre : reprises de shaders PS1 libres (THIRD_PARTY.md).
##  - neige : les anciens flocons (billboard StandardMaterial3D) sont rétablis, plus de shader de flocons en carrés de pixels ;
##  - fondu au noir soustractif en 32 pas (ps1_post.gdshader, uniform fondu_psx) : actif par défaut, ancien fondu gardé ;
##  - mention de la licence MIT.
##   godot --headless --path . --script res://outils/test_shaders_tiers.gd
var echecs := 0

func _init() -> void:
	_lancer.call_deferred()

func verifier(cond: bool, texte: String) -> void:
	print(("  ok  " if cond else "  ÉCHEC ") + texte)
	if not cond:
		echecs += 1

func _lancer() -> void:
	verifier(not FileAccess.file_exists("res://shaders/ps1_flocon.gdshader"), "ps1_flocon.gdshader retiré (anciens flocons)")
	var monde := FileAccess.get_file_as_string("res://scripts/monde.gd")
	verifier(monde.find("ps1_flocon") < 0 and monde.find("neige-psx") < 0, "monde.gd : plus de neige en carrés de pixels")
	verifier(monde.find("BaseMaterial3D.BILLBOARD_PARTICLES") >= 0 and monde.find("DISTANCE_FADE_PIXEL_DITHER") >= 0, "monde.gd : flocons billboard à fondu tramé")
	var post := FileAccess.get_file_as_string("res://shaders/ps1_post.gdshader")
	verifier(post.find("uniform bool fondu_psx = true;") >= 0, "ps1_post : fondu PS1 actif par défaut")
	verifier(post.find("floor(fondu * 32.0") >= 0 and post.find("c *= 1.0 - fondu;") >= 0, "ps1_post : fondu en 32 pas + ancien fondu gardé")
	# même calcul que le shader : à mi-fondu, un noir reste noir, un clair garde la moitié de sa valeur
	var f := 0.5
	var pas := floorf(f * 32.0 + 0.001) / 32.0
	verifier(is_equal_approx(maxf(0.2 - pas, 0.0), 0.0) and is_equal_approx(maxf(0.9 - pas, 0.0), 0.4), "fondu soustractif : ombres au noir d'abord")
	var tiers := FileAccess.get_file_as_string("res://THIRD_PARTY.md")
	verifier(tiers.find("Analog Feelings") >= 0 and tiers.find("dragthelake") < 0 and tiers.count("MIT License") >= 1, "THIRD_PARTY.md : licence MIT du fondu seule")
	print("ECHECS : %d" % echecs)
	quit(echecs)
