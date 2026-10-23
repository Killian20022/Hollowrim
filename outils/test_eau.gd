extends SceneTree
## Test sans fenêtre du système d'eau : préréglages, variantes de glace, carte de profondeur, requêtes, cascade, shaders.
##   godot --headless --path . --script res://outils/test_eau.gd -- --nouvelle
## (La compilation GPU des shaders ne se vérifie qu'avec une fenêtre : outils/captures_eau.gd ; ici on contrôle que les shaders
## se chargent, sont de bon type et déclarent les paramètres que le code leur envoie.)
var ok := true

func _init() -> void:
	_lancer.call_deferred()

func _verifie(cond: bool, msg: String) -> void:
	if not cond:
		print("ECHEC : ", msg)
		ok = false

func _lancer() -> void:
	# --- shaders
	var shader: Shader = load("res://shaders/eau.gdshader")
	_verifie(shader != null and shader.get_mode() == Shader.MODE_SPATIAL, "shaders/eau.gdshader chargeable (spatial)")
	var noms := {}
	for u in shader.get_shader_uniform_list():
		noms[u["name"]] = true
	for n in ["carte", "carte_rect", "ruido", "carte_glace", "c_peu", "c_moyen", "c_profond", "absorption", "transparence", "vitesse", "cadence",
			"ond_amp", "reflet_force", "ecume_force", "grille", "temps_force", "ciel_froid", "ciel_haut", "debug_masque"]:
		_verifie(noms.has(n), "uniform « %s » déclaré dans eau.gdshader" % n)
	var chute: Shader = load("res://shaders/eau_chute.gdshader")
	_verifie(chute != null and chute.get_mode() == Shader.MODE_SPATIAL, "shaders/eau_chute.gdshader chargeable (spatial)")
	# --- bruit partagé
	var tex := Eau.texture_ruido()
	_verifie(tex != null and tex.get_width() == 128, "texture de bruit 128²")
	var img := tex.get_image()
	var mn := 1.0
	var mx := 0.0
	for y in 128:
		for x in 128:
			var c := img.get_pixel(x, y)
			mn = minf(mn, minf(c.r, minf(c.g, c.b)))
			mx = maxf(mx, maxf(c.r, maxf(c.g, c.b)))
	_verifie(mn >= 0.0 and mx <= 1.0 and mx - mn > 0.7, "bruit étalé sur [0, 1] (min %.2f max %.2f)" % [mn, mx])
	# --- préréglages × variantes : cuvette circulaire de 3 m de rayon (fond à -1 m), eau à 0
	var cuvette := func(x: float, z: float) -> float:
		var r := Vector2(x, z).length()
		return -1.0 * (1.0 - smoothstep(0.0, 3.0, r)) + 0.4 * smoothstep(3.0, 3.6, r)
	var n_eaux := 0
	for p in Eau.noms_presets():
		for v in Eau.Variante.values():
			var e := Eau.creer(p, Rect2(-6, -6, 12, 12), 0.0, cuvette, {"variante": v, "courant": func(_x: float, _z: float) -> Vector2: return Vector2(0.5, 0.0),
				"turbulences": [[Vector2(1, 0), 1.5, 1.0]]})
			root.add_child(e)
			n_eaux += 1
			_verifie(e.surface != null and e.surface.mesh != null and e.surface.mesh.get_surface_count() == 1, "%s/%d : maillage de surface" % [p, v])
			_verifie(e.materiau.shader == shader, "%s/%d : shader eau" % [p, v])
			_verifie(e.surface_m2() > 15.0 and e.surface_m2() < 40.0, "%s/%d : surface d'eau plausible (%.1f m²)" % [p, v, e.surface_m2()])
			_verifie(e.contient(0.0, 0.0) and not e.contient(5.0, 5.0), "%s/%d : contient()" % [p, v])
			_verifie(absf(e.profondeur_en(0.1, 0.1) - 1.0) < 0.1, "%s/%d : profondeur au centre ≈ 1 m (%.2f)" % [p, v, e.profondeur_en(0.1, 0.1)])
			_verifie((p == &"lac") == (e.brume != null), "%s/%d : brume seulement pour le lac" % [p, v])
			# changement de variante à chaud
			e.definir_variante(Eau.Variante.GLACE)
			e.definir_variante(Eau.Variante.LIQUIDE)
			e.regler("ond_amp", 0.5)
			# chaque paramètre du préréglage existe dans le shader
			for k in Eau.reglages(p):
				if not String(k).begins_with("_"):
					_verifie(noms.has(String(k)), "préréglage %s : paramètre « %s » existe dans le shader" % [p, k])
	# --- carte : le bord (profondeur <= 0) ne doit pas être dessiné
	var e2 := Eau.creer(&"flaque", Rect2(-4, -4, 8, 8), 0.0, cuvette, {})
	_verifie(e2.profondeur_en(3.9, 3.9) < 0.0, "hors cuvette : profondeur négative")
	# --- cascade
	var casc := Cascade.creer(1.5, 2.6)
	root.add_child(casc)
	_verifie(casc.chute != null and casc.chute.mesh != null, "cascade : nappe Blender chargée")
	_verifie(casc.falaise != null and casc.falaise.mesh != null, "cascade : falaise Blender chargée")
	_verifie(casc.gouttes != null and casc.ecume != null and casc.brume != null, "cascade : gouttelettes, écume, brume")
	var zt: Array = casc.zone_turbulence()
	_verifie(zt.size() == 3 and zt[2] > 0.0, "cascade : zone de turbulence")
	for i in 3:
		await process_frame
	for c in root.get_children():
		c.queue_free()
	await process_frame
	print("test_eau : %d eaux créées, %s" % [n_eaux, "TOUT OK" if ok else "ECHEC"])
	quit(0 if ok else 1)
