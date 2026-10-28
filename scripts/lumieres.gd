class_name Lumieres
extends RefCounted
## Préréglages de lumière partagés (docs/DIRECTION_ARTISTIQUE.md §6) et ATMOSPHÈRE de la crypte (lot C9, docs/INSPIRATION_IGNITE.md §2.11-2.12).
##
## Atmosphère (aucune lumière de plus, sauf l'accent compté ci-dessous) :
## - brume au sol : les nappes déjà posées par le kit (CrypteDecor.brume, matière « brume ») passent par shaders/brume_sol.gdshader :
##   paliers de densité découpés par un BRUIT de valeur fixé au monde (jamais de Bayer, rien d'animé), couleur et épaisseur par salle
##   (couleur de sommet : accent de la salle, plus épaisse dans les salles basses) ;
## - halos de brume : carte face à la caméra (MultiMesh par salle, shaders/brume_halo.gdshader) autour des braseros et des lustres,
##   rampe Braise tons 1-2 (#5a1a1c → #b3341f), anneaux en paliers de bruit, bas fondu (ne coupe pas le sol) ;
## - accent de couleur par salle (champ `accent` des modules, CrypteDonjon.ACCENTS) : couleur de la brume au sol, teinte de la brume
##   en profondeur quand la caméra est dans la salle (noeud AccentBrume → BrumePortee.teinter), et AU PLUS UNE lumière d'accent
##   (préréglage Rune ou Cristal) si la salle n'en a pas déjà une froide et si le budget le permet (≤ 7 par salle, ≤ 8 par maillage).
## Désactivable pour les comparaisons : --sans-atmosphere (A/B de perf et captures avant/après).

# ------------------------------------------------------------------ préréglages (DA §6, couleurs en linéaire Godot)
const TORCHE := {"couleur": Color(1.0, 0.56, 0.24), "energie": 1.6, "portee": 8.0, "att": 1.5}
const LANTERNE := {"couleur": Color(1.0, 0.62, 0.32), "energie": 1.1, "portee": 6.0, "att": 1.6}
const BRASERO := {"couleur": Color(1.0, 0.52, 0.20), "energie": 2.4, "portee": 10.0, "att": 1.4}
const BOUGIE := {"couleur": Color(1.0, 0.66, 0.36), "energie": 0.6, "portee": 3.0, "att": 1.8}
const CRISTAL := {"couleur": Color(0.36, 0.62, 1.0), "energie": 0.7, "portee": 4.0, "att": 1.6}
const RUNE := {"couleur": Color(0.35, 0.80, 1.0), "energie": 0.9, "portee": 5.0, "att": 1.5}
const LUNE := {"couleur": Color(0.62, 0.72, 1.0), "energie": 0.75}
const CREPUSCULE := {"couleur": Color(1.0, 0.60, 0.32), "energie": 1.3}
const AMBIANCE_DONJON := {"couleur": Color(0.30, 0.33, 0.40), "energie": 0.55}

## Rampe Braise (bible) : tons 1 et 2 pour les halos de brume.
const BRAISE_1 := Color("#5a1a1c")
const BRAISE_2 := Color("#b3341f")

## Accents de salle (INSPIRATION_IGNITE §2.11 : rune cyan, glace bleue, braise, noir total ; pas de vert ni de violet).
##   brume  : couleur de la brume au sol (rampe de la bible, ton sombre) ; force : multiplicateur d'épaisseur ;
##   fond   : couleur de la brume en profondeur (et du fond) quand la caméra est dans la salle (base crypte : BrumePortee.COULEUR_CRYPTE) ;
##   lumiere: préréglage de la lumière d'accent (ou {}), halos : multiplicateur des halos de brume chauds.
const ACCENTS := {
	"": {"brume": Color("#2c3444"), "force": 1.0, "fond": Color(0.03, 0.045, 0.08), "lumiere": {}, "halos": 1.0},
	"rune": {"brume": Color("#0c4a5e"), "force": 1.25, "fond": Color(0.008, 0.07, 0.08), "lumiere": RUNE, "halos": 0.85},
	"glace": {"brume": Color("#33577f"), "force": 1.15, "fond": Color(0.02, 0.055, 0.125), "lumiere": CRISTAL, "halos": 0.85},
	"braise": {"brume": Color("#5a1a1c"), "force": 1.0, "fond": Color(0.07, 0.03, 0.02), "lumiere": {}, "halos": 1.15},
	"noir": {"brume": Color("#14161a"), "force": 0.35, "fond": Color(0.004, 0.005, 0.007), "lumiere": {}, "halos": 0.55},
}

const SHADER_SOL := preload("res://shaders/brume_sol.gdshader")
const SHADER_HALO := preload("res://shaders/brume_halo.gdshader")

const R_BRASERO := 1.25         # rayon des halos de brume (m) : brasero, lustre
const R_LUSTRE := 1.25
const H_REF := 4.6              # hauteur sous plafond de référence : la brume au sol s'épaissit dans les salles plus basses

static func actif() -> bool:
	return not OS.get_cmdline_user_args().has("--sans-atmosphere")

static func accent(nom: String) -> Dictionary:
	return ACCENTS.get(nom, ACCENTS[""])

# ------------------------------------------------------------------ atmosphère d'un décor de crypte
## À appeler APRÈS la pose du décor et AVANT `CrypteDecor.finir()` (les tampons de brume et les flammes ne sont pas encore fusionnés).
## `dj` : le donjon (zones, modules et accents) ou null (décor du tertre : vestibule, alcôve, herse → accent par défaut).
## Fil d'exécution : ne crée que des ressources et des noeuds hors de l'arbre.
static func atmosphere(d: CrypteDecor, dj: DonjonKit) -> void:
	if not actif():
		return
	var salles := _salles(dj)
	var nb_nappes := _brume_sol(d, salles)
	var nb_halos := _halos(d, salles)
	var avec_lum: Array = []
	if dj != null:
		_lumieres_accent(d, salles)
		for sl: Dictionary in salles:
			if sl.has("accent_lumiere"):
				avec_lum.append("%s=%s" % [sl["id"], "oui" if sl["accent_lumiere"] else "non"])
		var n := AccentBrume.new()
		n.name = "AccentBrume"
		n.salles = salles
		for sl: Dictionary in salles:
			n.bornes = (sl["rect"] as Rect2) if n.bornes.size == Vector2.ZERO else n.bornes.merge(sl["rect"])
		n.bornes = n.bornes.grow(8.0)       # vestibule, alcôve et couloir de la herse (bâtis par le tertre) compris
		d.racine.add_child(n)
	if OS.get_cmdline_user_args().has("--essai-fogvolume"):
		_essai_fogvolume(d, salles)
	print("Atmosphère (C9) : %d nappes de brume, %d halos de brume, lumières d'accent %s" % [nb_nappes, nb_halos, str(avec_lum)])

## Salles du donjon en repère de la crypte : [{id, rect, y, h, accent}] (couloirs et escaliers compris : accent par défaut).
static func _salles(dj: DonjonKit) -> Array:
	var l: Array = []
	if dj == null:
		return l
	for z: Dictionary in dj.zones:
		var id: String = z["nom"]
		var mo: Dictionary = dj.modules.get(id, {})
		var e := {"id": id, "rect": z["rect"], "y": float(z["y"]), "h": float(mo.get("h", 3.0)), "accent": String(mo.get("accent", ""))}
		if mo.has("accent_pos"):
			e["accent_pos"] = mo["accent_pos"]
		l.append(e)
	return l

static func salle_de(salles: Array, p: Vector3) -> Dictionary:
	for s: Dictionary in salles:
		var y: float = s["y"]
		if (s["rect"] as Rect2).has_point(Vector2(p.x, p.z)) and p.y > y - 1.0 and p.y < y + float(s["h"]) + 0.5:
			return s
	return {}

## Brume au sol : matière « brume » remplacée par le shader en paliers de bruit ; chaque nappe (2 triangles = 6 sommets consécutifs)
## prend la couleur et l'épaisseur de sa salle en couleur de sommet (rgb = teinte normalisée, a = épaisseur).
static func _brume_sol(d: CrypteDecor, salles: Array) -> int:
	var nb := 0
	var sm := ShaderMaterial.new()
	sm.shader = SHADER_SOL
	sm.set_shader_parameter("fin_brume", BrumePortee.FIN)
	d._mats["brume"] = sm
	for cle in d._bufs:
		var b: Dictionary = d._bufs[cle]
		if b["nom"] != "brume":
			continue
		var v: PackedVector3Array = b["v"]
		var c: PackedColorArray = b["c"]
		var i := 0
		while i + 5 < v.size():
			var centre := (v[i] + v[i + 1] + v[i + 2] + v[i + 3] + v[i + 4] + v[i + 5]) / 6.0
			var s := salle_de(salles, centre)
			var ac := accent(s.get("accent", ""))
			var h: float = s.get("h", 3.4)
			var ep: float = clampf(H_REF / maxf(h, 2.5), 0.75, 1.45) * float(ac["force"])
			var col: Color = ac["brume"]
			var m := maxf(col.r, maxf(col.g, col.b))
			var k := Color(col.r / m, col.g / m, col.b / m, clampf(ep * m / 0.5, 0.0, 1.0))      # a : épaisseur x luminance du ton (0,5 = plein)
			for j in 6:
				c[i + j] = k
			i += 6
			nb += 1
		b["c"] = c
	return nb

## Halos de brume des braseros (flamme d'échelle 1,7) et des lustres (grappes de flammes 0,55) : un MultiMesh de cartes face à la
## caméra par salle (un appel de dessin par salle visible), AABB exacte (classement SalleActive, culling).
static func _halos(d: CrypteDecor, salles: Array) -> int:
	var points: Array = []      # [centre, rayon, sol]
	var lustres: Array = []
	for f: Array in d._flammes_def:
		var p: Vector3 = f[0]
		var e: float = f[1]
		if absf(e - 1.7) < 0.03:
			points.append([p + Vector3(0, 0.12, 0), R_BRASERO, 1.0])
		elif absf(e - 0.55) < 0.02:
			var g: Array = []
			for gr: Array in lustres:
				if (gr[0] as Vector3).distance_to(p) < 1.1:
					g = gr
					break
			if g.is_empty():
				lustres.append([p, 1, p])
			else:
				g[1] = int(g[1]) + 1
				g[2] = (g[2] as Vector3) + p
				g[0] = (g[2] as Vector3) / float(g[1])
	for gr: Array in lustres:
		if int(gr[1]) >= 4:
			points.append([(gr[0] as Vector3) + Vector3(0, 0.05, 0), R_LUSTRE, 0.6])
	if points.is_empty():
		return 0
	var par_salle := {}
	for pt: Array in points:
		var c: Vector3 = pt[0]
		var s := salle_de(salles, c)
		var id: String = s.get("id", "_")
		var sol: float = s.get("y", c.y - 1.2)
		var r: float = minf(pt[1], maxf(c.y - sol - 0.05, 0.6))      # la carte ne descend pas sous le sol
		var ac := accent(s.get("accent", ""))
		if not par_salle.has(id):
			par_salle[id] = []
		(par_salle[id] as Array).append([c, r, float(pt[2]) * float(ac["halos"])])
	var sm := ShaderMaterial.new()
	sm.shader = SHADER_HALO
	sm.set_shader_parameter("ton_1", BRAISE_1)
	sm.set_shader_parameter("ton_2", BRAISE_2)
	sm.set_shader_parameter("fin_brume", BrumePortee.FIN)
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)        # -1..1 : le shader le pose face à la caméra, à l'échelle du rayon
	for id: String in par_salle:
		var l: Array = par_salle[id]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = q
		mm.instance_count = l.size()
		var bb := AABB()
		for i in l.size():
			var c: Vector3 = l[i][0]
			var r: float = l[i][1]
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r, r, r)), c))
			mm.set_instance_custom_data(i, Color(float(l[i][2]), float(i % 7) / 7.0, 0.0, 0.0))     # intensité, graine du bruit
			var bi := AABB(c - Vector3(r, r, r), Vector3(r, r, r) * 2.0)
			bb = bi if i == 0 else bb.merge(bi)
		mm.custom_aabb = AABB(bb.position, bb.size)       # repère du MultiMesh = repère de la crypte (noeud à l'origine)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = sm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.name = "HalosBrume_" + id
		d.racine.add_child(mmi)
	return points.size()

## Au plus UNE lumière d'accent par salle à accent froid (Rune / Cristal), au point le plus haut de la carte de la salle (`accent_pos`,
## sinon le centre), seulement si la salle n'a pas déjà une lumière froide, a moins de 7 lumières et si aucun maillage touché n'en
## voit déjà 8 (CrypteDecor.lumiere_possible : même règle que test_crypte).
static func _lumieres_accent(d: CrypteDecor, salles: Array) -> void:
	for s: Dictionary in salles:
		var ac := accent(s["accent"])
		var pr: Dictionary = ac["lumiere"]
		if pr.is_empty():
			continue
		var r: Rect2 = s["rect"]
		var y: float = s["y"]
		var nb := 0
		var froide := false
		for l: OmniLight3D in d.toutes:
			var info: Array = d.pos_lum.get(l, [])
			if info.is_empty():
				continue
			var lp: Vector3 = info[0]
			if r.grow(0.4).has_point(Vector2(lp.x, lp.z)) and absf(lp.y - y) < 5.5:
				nb += 1
				if l.light_color.b > l.light_color.r:
					froide = true
		var p: Vector3 = s.get("accent_pos", Vector3(r.get_center().x, y + 2.2, r.get_center().y))
		if froide or nb >= 7 or not d.lumiere_possible(p, float(pr["portee"]), 8):
			s["accent_lumiere"] = false
			continue
		d.lumiere(p, pr["couleur"], float(pr["energie"]), float(pr["portee"]), float(pr["att"]), false)
		s["accent_lumiere"] = true

## Essai mesuré (INSPIRATION_IGNITE §2.12) : une FogVolume par grande salle + brume volumétrique. Option --essai-fogvolume seulement.
static func _essai_fogvolume(d: CrypteDecor, salles: Array) -> void:
	for s: Dictionary in salles:
		var r: Rect2 = s["rect"]
		if r.get_area() < 100.0:
			continue
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		fv.size = Vector3(r.size.x, 1.2, r.size.y)
		fv.position = Vector3(r.get_center().x, float(s["y"]) + 0.6, r.get_center().y)
		var fm := FogMaterial.new()
		fm.density = 0.6
		fm.albedo = accent(s["accent"])["brume"]
		fv.material = fm
		fv.name = "EssaiFogVolume_" + String(s["id"])
		d.racine.add_child(fv)

# ------------------------------------------------------------------ teinte de la brume en profondeur selon la salle de la caméra
## Noeud posé dans le donjon : suit la caméra active (repère de la crypte) et fait glisser la couleur de la brume de profondeur (et du
## fond) vers la teinte de la salle où elle se trouve (0,8 s). N'écrit RIEN hors de la crypte : il faut un environnement « sous terre »
## (fond uni, brume en profondeur pleine à BrumePortee.FIN) ET une caméra dans l'emprise de la crypte (salles du donjon + 8 m).
class AccentBrume extends Node:
	var salles: Array = []
	var bornes := Rect2()
	var _courante := BrumePortee.COULEUR_CRYPTE

	func _process(dt: float) -> void:
		var cam := get_viewport().get_camera_3d()
		var parent := get_parent() as Node3D
		if cam == null or parent == null:
			return
		var env := _env(cam)
		if env == null or not BrumePortee.sous_terre(env):
			return
		var p := parent.global_transform.affine_inverse() * cam.global_position
		var s := Lumieres.salle_de(salles, p)
		if s.is_empty() and not (bornes.has_point(Vector2(p.x, p.z)) and p.y > -9.0 and p.y < 9.0):
			return      # hors de la crypte : la grotte ou dehors ne sont jamais touchés
		var cible: Color = Lumieres.accent(s.get("accent", ""))["fond"]
		_courante = _courante.lerp(cible, clampf(dt / 0.8, 0.0, 1.0))
		if not env.fog_light_color.is_equal_approx(_courante):
			BrumePortee.teinter(env, _courante)

	func _env(cam: Camera3D) -> Environment:
		if cam.environment != null:
			return cam.environment
		var w := get_viewport().find_world_3d()
		return w.environment if w != null else null
