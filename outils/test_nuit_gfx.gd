extends SceneTree
## Test headless des retouches graphiques de la nuit du 2026-11-05 (lot gfx) :
##   godot --headless --path . --script res://outils/test_nuit_gfx.gd -- --nouvelle
## 1. intérieurs : ambiante relevée, trois bois de rondin distincts, au plus MAX_FROIDS lumières froides par maison,
##    lumières froides bleutées et sans vacillement ;
## 2. brume de nuit : plus claire qu'avant (0,04 ; 0,07 ; 0,15) et toujours bleue ;
## 3. glace du lac : AUCUNE dépendance au temps dans le bloc ajouté de eau.gdshader (T, T0, TIME) — refus d'effet sur l'eau ;
## 4. plans peints / arrière-plan : le bloc de nuit et la couche de brume du château existent, aucune dépendance au temps ;
## 5. cristaux de grotte : image 64x64 déterministe, moins saturée que la rampe d'origine.
const SCENE := preload("res://scenes/foret_test.tscn")
const CYCLE := preload("res://scripts/cycle.gd")

var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

static func _sat(c: Color) -> float:
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	return 0.0 if mx <= 0.0 else (mx - mn) / mx

func _tester() -> void:
	# --- 2. brume de nuit
	var f: Color = CYCLE.NUIT["froid"]
	_verif(f.get_luminance() > Color(0.04, 0.07, 0.15).get_luminance() * 1.2, "brume de nuit relevée (luminance %.4f)" % f.get_luminance())
	_verif(f.b > f.g and f.g > f.r, "brume de nuit bleue (r<g<b)")
	_verif(f.b < 0.3, "brume de nuit reste sombre (b = %.3f)" % f.b)
	# --- 3 et 4. shaders : texte
	var eau := FileAccess.get_file_as_string("res://shaders/eau.gdshader")
	var i := eau.find("MATIÈRE DE LA GLACE DU LAC")
	var j := eau.find("if (glace > 0.5 && (g_x < 0.5", i)
	_verif(i > 0 and j > i, "bloc de glace du lac trouvé dans eau.gdshader")
	var bloc := eau.substr(i, j - i)
	var re := RegEx.new()
	re.compile("\\b(TIME|T0|T)\\b")
	_verif(re.search(bloc) == null, "bloc de glace sans temps (TIME, T0, T) : statique")
	_verif(bloc.find("glace_ton_plaques > 0.5") >= 0, "matière réservée au lac (glace_ton_plaques)")
	for chemin in ["res://shaders/plans_peints.gdshader", "res://shaders/arriere_plan.gdshader"]:
		var s := FileAccess.get_file_as_string(chemin)
		var k := s.find("NUIT (2026-11-05)") if s.find("NUIT (2026-11-05)") >= 0 else s.find("nuit : la teinte bleu des aurores")
		_verif(k >= 0, "%s : bloc de nuit présent" % chemin.get_file())
		_verif(s.find("TIME") < 0, "%s : aucune dépendance à TIME" % chemin.get_file())
	var plans := FileAccess.get_file_as_string("res://shaders/plans_peints.gdshader")
	_verif(plans.find("brume_ch") >= 0, "couche de brume du château présente")
	var pe := FileAccess.get_file_as_string("res://shaders/peinture_plans.gdshader")
	_verif(pe.find("appareil de pierre") >= 0 and pe.find("CYLINDRES") >= 0, "château peint : appareil de pierre et tours cylindriques")
	_verif(pe.find("TIME") < 0, "peinture_plans : aucune dépendance à TIME")
	# --- 5. cristaux
	var a := GrotteTextures.cristal_face_image(false)
	var b := GrotteTextures.cristal_face_image(false)
	_verif(a.get_size() == Vector2i(64, 64), "cristal_f 64x64")
	_verif(a.get_data() == b.get_data(), "cristal_f déterministe")
	var ancien := GrotteTextures.R_CRISTAL_F
	var s_ancien := 0.0
	for c in ancien:
		s_ancien += _sat(Color(c))
	s_ancien /= ancien.size()
	var s_nouv := 0.0
	for y in 64:
		for x in 64:
			s_nouv += _sat(a.get_pixel(x, y))
	s_nouv /= 4096.0
	_verif(s_nouv < s_ancien, "cristal_f moins saturé (%.3f < %.3f)" % [s_nouv, s_ancien])
	# --- 1. intérieurs
	var mats := Interieurs.materiaux()
	_verif(Interieurs.AMBIANT.get_luminance() > 0.40, "ambiante d'intérieur relevée (%.3f)" % Interieurs.AMBIANT.get_luminance())
	for k in ["rondin", "rondin_b", "rondin_c"]:
		_verif(mats.has(k), "matière %s" % k)
	var ta: Color = (mats["rondin_b"] as ShaderMaterial).get_shader_parameter("teinte")
	var tb: Color = (mats["rondin_c"] as ShaderMaterial).get_shader_parameter("teinte")
	_verif(ta.b > ta.r and tb.r > tb.b, "rondin_b bleuté, rondin_c roux")
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for n in 8:
		await physics_frame
	var v: Node3D = m.village
	for n in 400:
		if v.prets:
			break
		await physics_frame
	_verif(v.prets, "intérieurs construits")
	var total_froids := 0
	for ip: Interieur in v.interieurs:
		var froids := 0
		for l in ip.lumieres:
			var lu: OmniLight3D = l[0]
			if lu.light_color.is_equal_approx(Interieurs.FROID):
				froids += 1
				_verif(l[2] < 0.0, "%s : lumière froide sans vacillement" % ip.nom)
				_verif(not lu.shadow_enabled, "%s : lumière froide sans ombre" % ip.nom)
		_verif(froids <= Interieurs.MAX_FROIDS, "%s : %d lumière(s) froide(s) <= %d" % [ip.nom, froids, Interieurs.MAX_FROIDS])
		total_froids += froids
	_verif(total_froids > 0, "au moins une lumière froide de fenêtre dans le village (%d)" % total_froids)
	print("ECHECS %d" % _echecs)
	m.queue_free()
	for n in 5:
		await physics_frame
	quit(1 if _echecs > 0 else 0)
