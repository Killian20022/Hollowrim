extends SceneTree
## Lot C3 « midi » : vérifie le cycle jour/nuit sans fenêtre.
##   godot --headless --path . --script res://outils/test_cycle_midi.gd -- --nouvelle
## 1) crépuscule (17 h 30) identique aux constantes CREPUSCULE (validé, ne doit pas bouger) ;
## 2) continuité : de 0 h à 24 h par pas de 36 s de jeu, aucun saut de lumière/ambiant/brume/ciel/étalonnage
##    (hors bascule soleil ↔ lune, faite lumière éteinte) ;
## 3) midi : ciel bleu, brume bleu pâle (pas lavande), ambiant froid, soleil presque blanc et plus fort qu'au matin.
const CYCLE := preload("res://scripts/cycle.gd")
var echecs := 0

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ÉCHEC ") + msg)
	if not ok:
		echecs += 1

class FauxMonde extends Node:
	var post := ShaderMaterial.new()

func _etat(c) -> Dictionary:
	var post: ShaderMaterial = c.get_parent().post
	return {
		"amb": c.env.ambient_light_color, "amb_e": c.env.ambient_light_energy, "expo": c.env.tonemap_exposure,
		"brume": c._froid, "haut": c._haut, "fin": c._fin_base, "lum": c.lumiere.light_color * c.lumiere.light_energy,
		"e": c.lumiere.light_energy, "dir": -c.lumiere.basis.z,
		"sat": post.get_shader_parameter("etal_sat"), "contr": post.get_shader_parameter("etal_contraste"),
		"ombre": post.get_shader_parameter("etal_ombre"),
	}

func _ecart(a: Dictionary, b: Dictionary) -> float:
	var d := 0.0
	for k in ["amb", "brume", "haut", "lum"]:
		var x: Color = a[k]
		var y: Color = b[k]
		d = maxf(d, maxf(absf(x.r - y.r), maxf(absf(x.g - y.g), absf(x.b - y.b))))
	for k in ["amb_e", "expo", "sat", "contr", "e"]:
		d = maxf(d, absf(float(a[k]) - float(b[k])))
	d = maxf(d, absf(a["fin"] - b["fin"]) / 60.0)
	d = maxf(d, (a["ombre"] - b["ombre"]).length())
	return d

func _init() -> void:
	var monde := FauxMonde.new()
	root.add_child(monde)
	var c = CYCLE.new()
	c.env = Environment.new()
	c.lumiere = DirectionalLight3D.new()
	monde.add_child(c.lumiere)
	c.ciel = ShaderMaterial.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	monde.add_child(c)

	# 1) crépuscule validé
	c.heure = 17.5
	c._process(0.0)
	var cr: Dictionary = c.CREPUSCULE
	var e := _etat(c)
	_verif(c.chaleur() > 0.999 and c.clarte() < 0.001, "17 h 30 : pleine lueur crépusculaire, clarté nulle")
	_verif(e["amb"].is_equal_approx(cr["ambiant"]) and is_equal_approx(e["amb_e"], cr["ambiant_e"]), "17 h 30 : ambiant = CREPUSCULE")
	_verif(e["brume"].is_equal_approx(cr["froid"]) and e["haut"].is_equal_approx(cr["haut"]) and is_equal_approx(e["fin"], cr["fin"]), "17 h 30 : brume, zénith et portée = CREPUSCULE")
	_verif(c.lumiere.light_color.is_equal_approx(Color(1.0, 0.60, 0.32)) and is_equal_approx(e["expo"], cr["expo"]), "17 h 30 : soleil couchant et exposition inchangés")
	_verif(is_equal_approx(e["sat"], c.ETAL["crep"]["sat"]) and is_equal_approx(e["contr"], c.ETAL["crep"]["contraste"]), "17 h 30 : étalonnage = crep")

	# 2) continuité
	var pas := 0.01
	var pire := 0.0
	var pire_h := 0.0
	c.heure = 0.0
	c._process(0.0)
	var prec := _etat(c)
	var h := pas
	while h < 24.0:
		c.heure = h
		c._process(0.0)
		var cur := _etat(c)
		var d := _ecart(prec, cur)
		var bascule := absf(h - 8.0) < 0.02 or absf(h - 18.95) < 0.02  # changement d'astre, lumière éteinte
		if not bascule and d > pire:
			pire = d
			pire_h = h
		prec = cur
		h += pas
	_verif(pire < 0.03, "continuité : plus grand saut en 36 s de jeu = %.4f (à %s h)" % [pire, str(snappedf(pire_h, 0.01))])
	for b in [7.99, 18.94]:
		c.heure = b
		c._process(0.0)
		_verif(c.lumiere.light_energy < 0.05, "bascule soleil/lune à %.2f h : lumière éteinte (%.3f)" % [b, c.lumiere.light_energy])

	# 3) midi
	c.heure = 12.0
	c._process(0.0)
	var m := _etat(c)
	var br: Color = m["brume"]
	var ht: Color = m["haut"]
	var am: Color = m["amb"]
	_verif(ht.b > ht.r * 2.0 and ht.b > 0.5, "12 h : zénith bleu franc %s" % ht)
	_verif(br.b > br.r + 0.15 and br.g > br.r + 0.05, "12 h : brume bleu pâle, pas lavande (vert > rouge) %s" % br)
	_verif(am.b > am.r + 0.2 and am.g > am.r, "12 h : ambiant froid (ombres bleues) %s" % am)
	_verif(m["e"] > 1.5 and c.lumiere.light_color.b > 0.85, "12 h : soleil fort et presque blanc (%.2f, %s)" % [m["e"], c.lumiere.light_color])
	_verif(float(m["contr"]) > 0.42 and float(m["sat"]) > 0.8, "12 h : contraste %.2f, saturation %.2f" % [m["contr"], m["sat"]])
	_verif((m["dir"] as Vector3).y < -0.2, "12 h : soleil au-dessus de l'horizon (ombres portées)")
	print("ECHECS : %d" % echecs)
	quit(1 if echecs > 0 else 0)
