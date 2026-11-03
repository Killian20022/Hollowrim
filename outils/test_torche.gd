extends SceneTree
## Test de la flamme de torche en gros pixels (scripts/torche.gd, scripts/flamme_torche.gd, shaders/flamme_pixels.gdshader) :
##   godot --headless --path . --script res://outils/test_torche.gd -- --nouvelle
## Le pilote est mené à la main (_process(dt) avec dt fixe) : au repos la pointe est droite, en marche elle recule à l'opposé de la
## vitesse, en course plus, à l'arrêt elle se redresse, un atterrissage secoue la flamme, la lumière reste bornée et sans saut brutal.

var _ok := true
var _n := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _avancer(p: Node3D, pilote: Node, v: Vector3, images: int) -> void:
	for i in images:
		p.position += v / 60.0
		pilote._process(1.0 / 60.0)

func _tester() -> void:
	var p := Node3D.new()
	root.add_child(p)
	var t := Torche.construire(p)
	await process_frame
	var pilote: Node3D = t["pilote"]
	var mat: ShaderMaterial = pilote.get("mat")
	_verif(pilote != null and mat != null and mat.shader.resource_path.ends_with("flamme_pixels.gdshader"), "la torche utilise le shader flamme_pixels (gros pixels)")
	_verif((t["flamme"] as Array).size() == 1 and (t["visuels"] as Array).has(pilote), "braises et visuels déclarés (masquage par le propriétaire)")
	_verif(t["lumiere"] is OmniLight3D, "lumière présente")
	_avancer(p, pilote, Vector3.ZERO, 90)
	var rep: Vector3 = mat.get_shader_parameter("pointe")
	_verif(absf(rep.x) < 0.01 and absf(rep.z) < 0.01 and rep.y > 0.18, "à l'arrêt : flamme droite (%s)" % rep)
	_avancer(p, pilote, Vector3(0, 0, -2.0), 60)
	var marche: Vector3 = mat.get_shader_parameter("pointe")
	_verif(marche.z > 0.05 and marche.y < rep.y, "marche : la pointe recule (+Z) et se couche (%s)" % marche)
	_avancer(p, pilote, Vector3(0, 0, -6.0), 60)
	var course: Vector3 = mat.get_shader_parameter("pointe")
	_verif(course.z > marche.z and course.y < marche.y + 0.001, "course : plus couchée que la marche (%s)" % course)
	_verif(Vector2(course.x, course.z).length() <= 0.32, "recul borné")
	var ag_course: float = mat.get_shader_parameter("agitation")
	var e_min := 9.0
	var e_max := 0.0
	var saut_max := 0.0
	var prec := float(pilote.get("facteur_lumiere"))
	_avancer(p, pilote, Vector3(0, 0, -6.0), 1)
	# atterrissage : chute puis arrêt net
	_avancer(p, pilote, Vector3(0, -8.0, 0), 20)
	_avancer(p, pilote, Vector3.ZERO, 3)
	var ag_atterr: float = mat.get_shader_parameter("agitation")
	_verif(ag_atterr > 0.5, "atterrissage : la flamme est secouée (agitation %.2f)" % ag_atterr)
	for i in 240:
		_avancer(p, pilote, Vector3.ZERO, 1)
		var f := float(pilote.get("facteur_lumiere"))
		e_min = minf(e_min, f)
		e_max = maxf(e_max, f)
		if i > 0:
			saut_max = maxf(saut_max, absf(f - prec))
		prec = f
	var fin: Vector3 = mat.get_shader_parameter("pointe")
	_verif(Vector2(fin.x, fin.z).length() < 0.02 and fin.y > 0.17, "après arrêt : la flamme se redresse (%s)" % fin)
	_verif(e_min > 0.8 and e_max < 1.25, "lumière bornée [%.2f ; %.2f]" % [e_min, e_max])
	_verif(saut_max < 0.05, "lumière sans stroboscope (saut max par image %.3f)" % saut_max)
	_verif(ag_course >= 0.15, "agitation en course >= repos")
	# torche rangée puis ressortie : pas de vitesse fantôme
	pilote.visible = false
	_avancer(p, pilote, Vector3.ZERO, 2)
	p.position += Vector3(30, 0, 0)
	pilote.visible = true
	_avancer(p, pilote, Vector3.ZERO, 2)
	var apres: Vector3 = mat.get_shader_parameter("pointe")
	_verif(Vector2(apres.x, apres.z).length() < 0.03, "ressortie après téléportation : flamme droite")
	print("%s : %d vérifications" % ["TOUT OK" if _ok else "ECHECS", _n])
	quit(0 if _ok else 1)
