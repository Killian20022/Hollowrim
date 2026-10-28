extends SceneTree
## Liste les objets du journal de la crypte (types contenant un des filtres) : centre (repère de la crypte), lacet, module, et une pose
## de capture (format --captures) à 1,8 m devant l'objet (+z local), regard vers son centre. Sert à cadrer les planches avant / après.
##   godot --headless --path . --script res://outils/lister_objets_crypte.gd -- --nouvelle --paisible --filtre=coffre,tonneau,or_tas [--max=6]
##   [--mats] : liste aussi les matériaux des deux décors (variante BRILLANT, brillance, saturation, teinte : lot C1)
const SCENE := "res://scenes/foret_test.tscn"

func _init() -> void:
	CrypteDecor.journal_actif = true
	_go.call_deferred()

func _go() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var filtres: PackedStringArray = String(args.get("filtre", "coffre")).split(",")
	var nmax := int(args.get("max", "6"))
	var m: Node3D = (load(SCENE) as PackedScene).instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 60:
		await physics_frame
	m.tertre.attendre_donjon()
	for i in 3:
		await physics_frame
	var compte := {}
	if args.has("mats"):      # matériaux de chaque décor : shader (base / BRILLANT) et réglages C1
		for dec: CrypteDecor in [m.tertre.d, m.tertre.d2]:
			for k: String in dec._mats:
				var mt: Material = dec._mats[k]
				if mt is ShaderMaterial:
					var sm := mt as ShaderMaterial
					print("MAT %-10s brillant=%s brillance=%s saturation=%s teinte=%s" % [k, sm.shader == CrypteDecor._shader_brillant, sm.get_shader_parameter("brillance"), sm.get_shader_parameter("saturation"), sm.get_shader_parameter("teinte")])
	for dec: CrypteDecor in [m.tertre.d, m.tertre.d2]:
		var vus := {}
		for e0: Dictionary in dec.journal:
			var e := e0
			if e.get("partie", false):      # grand module noté par morceaux : une seule fois, bornes globales
				if vus.has(e["gid"]):
					continue
				vus[e["gid"]] = true
				e = e.duplicate()
				e["min"] = e["gmin"]
				e["max"] = e["gmax"]
			var t: String = e["t"]
			var f := ""
			for x: String in filtres:
				if t.contains(x):
					f = x
			if f == "" or int(compte.get(f, 0)) >= nmax:
				continue
			compte[f] = int(compte.get(f, 0)) + 1
			var a: float = e["lacet"]
			var c := Basis(Vector3.UP, a) * (((e["min"] as Vector3) + (e["max"] as Vector3)) * 0.5)
			var avant := Basis(Vector3.UP, a) * Vector3(0, 0, 1)
			var cam := c + avant * 1.8
			var sol: float = -6.0 if c.y < -3.0 else 0.0
			var d := c - Vector3(cam.x, sol + 1.6, cam.z)
			var lacet := rad_to_deg(atan2(-d.x, -d.z))
			var tang := rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
			print("OBJ %-18s mod=%-14s c=(%.2f, %.2f, %.2f) lacet=%.0f  POSE %s crypte %.2f,%.2f,%.1f,%.1f,%.1f" % [t, e["mod"], c.x, c.y, c.z, rad_to_deg(a), t, cam.x, cam.z, lacet, tang, sol])
	quit(0)
