extends SceneTree
## Test sans fenêtre des FACTIONS (data/factions.json, scripts/combat/factions.gd, retours exe 5) :
##   godot --headless --path . -s res://outils/test_factions.gd -- --nouvelle --test [--carte=<dossier>] [--sans-combat]
## (`--test` : le décor scenes/test_troll_mage.tscn sans son troll ni son pilote)
## A. table : chaque paire de factions présente une fois, relations valides, et les règles de l'utilisateur (draugr ↔ araignée neutres,
##    pillard ↔ araignée et pillard ↔ draugr hostiles).
## B. PLACEMENT : tous les postes d'ennemis (et points de patrouille) de la grotte de Hrafn (construite), de la crypte (CrypteDonjon.plan)
##    et de la surface (draugrs de monde.DRAUGRS_SURFACE, bêtes fixes monde.BETES) : deux factions hostiles jamais à moins de
##    Factions.distance_min() m (3D) dans un même lieu. `--carte=<dossier>` : planche PNG vue de dessus par lieu, un point par poste,
##    couleur de faction, cercle rouge autour des postes en conflit.
## C. COMBAT (scène test_troll_mage, --test) : une araignée et un bandit hostiles, joueur loin : ils se trouvent, se battent, l'un
##    meurt, le joueur n'est jamais frappé ; un draugr et une araignée (neutres) côte à côte ne se battent pas.

const COULEURS := {"draugr": Color(0.55, 0.75, 1.0), "araignee": Color(0.2, 0.9, 0.3), "pillard": Color(1.0, 0.55, 0.15),
	"troll": Color(0.85, 0.85, 0.95), "mage": Color(0.8, 0.4, 1.0), "loup": Color(0.6, 0.6, 0.6), "faune": Color(0.9, 0.9, 0.4)}

## `--avant` (planche de preuve seulement) : les postes de la grotte AVANT la séparation des factions (exe 5 : araignées dans la galerie
## du retour de la mine, contre le camp ; pillards dans la caverne du troll), pour dessiner la carte d'avant. Jamais utilisé pour réussir.
const AVANT := {
	"mine_retour": [
		{"id": "araignee_mine_a", "ia": "araignee", "s": 66.0, "lat": 1.7, "face": "entree"},
		{"id": "araignee_mine_b", "ia": "araignee", "s": 71.0, "lat": 0.0, "face": "entree"}],
	"lac_caverne": [
		{"id": "bandit_8", "type": "sbire", "s": 17.0, "lat": 0.5, "patrouille": [[17.0, 0.5], [30.0, 1.5], [41.0, 0.5]]},
		{"id": "bandit_archer_2", "type": "sbire", "archer": true, "s": 27.5, "lat": 4.6, "sur": "corniche_lac", "face": "centre"},
		{"id": "troll_lac", "ia": "troll_givre", "s": 37.5, "lat": 2.1, "face": "entree", "options": {"dort": true}}],
}
var _traces := {}     # lieu -> points du fond de carte (axes des galeries)
var _ok := 0
var _ko := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ÉCHEC  ") + msg)
	if cond:
		_ok += 1
	else:
		_ko += 1

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

# ------------------------------------------------------------------ A. table

func _table() -> void:
	var t := Factions.table()
	var noms := Factions.noms()
	var vues := {}
	var valides := true
	for r: Array in t["relations"]:
		var cle := [String(r[0]), String(r[1])]
		cle.sort()
		if vues.has(str(cle)) or not Factions.existe(cle[0]) or not Factions.existe(cle[1]) or cle[0] == cle[1] or not String(r[2]) in ["allie", "neutre", "hostile"]:
			valides = false
			print("   relation invalide ou en double : ", r)
		vues[str(cle)] = true
	var attendu := noms.size() * (noms.size() - 1) / 2
	_verif(valides and vues.size() == attendu, "table : %d factions, %d paires sur %d, relations valides" % [noms.size(), vues.size(), attendu])
	_verif(Factions.relation("draugr", "araignee") == "neutre", "draugr ↔ araignée : neutres (cohabitent)")
	_verif(Factions.hostiles("pillard", "araignee") and Factions.hostiles("araignee", "pillard"), "pillard ↔ araignée : hostiles")
	_verif(Factions.hostiles("pillard", "draugr"), "pillard ↔ draugr : hostiles")
	_verif(Factions.ennemies_de("faune").is_empty(), "faune : hostile à personne")
	for ia: String in ["araignee", "loup", "cerf", "troll_givre", "mage_nordique"]:
		if Factions.de_ia(ia) == "":
			_verif(false, "IA %s sans faction" % ia)

# ------------------------------------------------------------------ B. placement

## Postes [faction, ident, position] d'un lieu ; les points de patrouille comptent comme des postes du même ennemi.
func _postes_grotte() -> Array:
	var pere := Node3D.new()
	root.add_child(pere)
	var def_g := GrotteDonnees.repaire_hrafn()
	if _arg("avant") != "":
		for z: Dictionary in def_g["zones"]:
			if AVANT.has(z["id"]):
				z["ennemis"] = AVANT[z["id"]]
	var g := Grotte.creer(pere, null, def_g)
	var r: Array = []
	var tr: Array = []
	for id: String in g.ordre:
		var s := 0.0
		while s < g.longueur(id):
			for lat in [-2.5, 0.0, 2.5]:
				tr.append(g.to_global(g.sol_en(id, s, lat)))
			s += 0.5
	_traces["grotte"] = tr
	for a: Dictionary in g.accroches:
		if a["type"] != "ennemi":
			continue
		var f := Factions.de_donnees(a["d"], "grotte")
		r.append([f, String(a["id"]), g.to_global(a["pos"])])
		for p: Vector3 in a["patrouille"]:
			r.append([f, String(a["id"]) + "~", g.to_global(p)])
	pere.queue_free()
	return r

func _postes_crypte() -> Array:
	var r: Array = []
	for m: Dictionary in CrypteDonjon.new(null).plan():
		for e: Dictionary in m.get("ennemis", []):
			var f := Factions.de_donnees(e, "crypte")
			r.append([f, String(e["id"]), e["pos"]])
			for p: Vector3 in (e.get("extra", {}) as Dictionary).get("patrouille", []):
				r.append([f, String(e["id"]) + "~", p])
	return r

func _postes_surface() -> Array:
	var monde := load("res://scripts/monde.gd")
	var r: Array = []
	for d: Array in monde.DRAUGRS_SURFACE:
		r.append([Factions.de_lieu("surface"), "draugr_" + String(d[0]), Vector3(float(d[1]), 0.0, float(d[2]))])
	for b: Array in monde.BETES:
		r.append([Factions.de_ia(String(b[0])), String(b[1]), Vector3(float(b[2]), 0.0, float(b[3]))])
	return r

func _placement(lieu: String, postes: Array) -> void:
	var dmin := Factions.distance_min()
	var conflits: Array = []
	var pire := INF
	for i in postes.size():
		for k in range(i + 1, postes.size()):
			var a: Array = postes[i]
			var b: Array = postes[k]
			if not Factions.hostiles(a[0], b[0]):
				continue
			var d := (a[2] as Vector3).distance_to(b[2])
			pire = minf(pire, d)
			if d < dmin:
				conflits.append([a, b, d])
	var par := {}
	for p: Array in postes:
		par[p[0]] = int(par.get(p[0], 0)) + 1
	for c: Array in conflits:
		print("   conflit %s : %s (%s) à %.1f m de %s (%s)" % [lieu, c[0][1], c[0][0], c[2], c[1][1], c[1][0]])
	_verif(conflits.is_empty(), "%s : %d postes %s, factions hostiles à %.1f m au plus près (min %.0f m), %d conflit(s)" % [lieu, postes.size(), par, pire, dmin, conflits.size()])
	if _arg("carte") != "":
		_carte(lieu, postes, conflits)

## Planche vue de dessus (X à droite, Z vers le bas), 6 px par mètre, marge 10 m ; fond gris : axes et bords des galeries.
func _carte(lieu: String, postes: Array, conflits: Array) -> void:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p: Array in postes:
		var v: Vector3 = p[2]
		mn = Vector2(minf(mn.x, v.x), minf(mn.y, v.z))
		mx = Vector2(maxf(mx.x, v.x), maxf(mx.y, v.z))
	mn -= Vector2(10, 10)
	mx += Vector2(10, 10)
	var k := 6.0
	var img := Image.create(int((mx.x - mn.x) * k), int((mx.y - mn.y) * k), false, Image.FORMAT_RGB8)
	img.fill(Color(0.08, 0.08, 0.1))
	var px := func(v: Vector3) -> Vector2i: return Vector2i(int((v.x - mn.x) * k), int((v.z - mn.y) * k))
	var disque := func(c: Vector2i, r: int, col: Color, plein: bool) -> void:
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var d2 := x * x + y * y
				if (plein and d2 <= r * r) or (not plein and d2 <= r * r and d2 >= (r - 2) * (r - 2)):
					var q := c + Vector2i(x, y)
					if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
						img.set_pixelv(q, col)
	for t: Vector3 in _traces.get(lieu, []):
		var q: Vector2i = px.call(t)
		if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
			img.set_pixelv(q, Color(0.3, 0.3, 0.34))
	# échelle : 10 m
	for x in int(10 * k):
		img.set_pixel(8 + x, img.get_height() - 8, Color.WHITE)
	for c: Array in conflits:
		for p: Array in [c[0], c[1]]:
			disque.call(px.call(p[2]), int(Factions.distance_min() * k * 0.5), Color(0.9, 0.1, 0.1), false)
	for p: Array in postes:
		var patr := String(p[1]).ends_with("~")
		disque.call(px.call(p[2]), 3 if patr else 7, COULEURS.get(p[0], Color.WHITE), true)
	var chemin := _arg("carte").path_join("factions_%s.png" % lieu)
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	img.save_png(chemin)
	print("CARTE ", chemin)

func _tester() -> void:
	_table()
	_placement("grotte", _postes_grotte())
	_placement("crypte", _postes_crypte())
	_placement("surface", _postes_surface())
	if _arg("sans-combat") == "":
		await _combat()
	print("\nFACTIONS : %d OK, %d ÉCHEC(S)" % [_ok, _ko])
	quit(1 if _ko > 0 else 0)

# ------------------------------------------------------------------ C. combat entre factions hostiles

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _combat() -> void:
	RetourImpact.muet = true
	var sc: Node3D = load("res://scenes/test_troll_mage.tscn").instantiate()
	root.add_child(sc)
	current_scene = sc
	await _frames(10)
	var j: CharacterBody3D = sc.joueur
	j.global_position = Vector3(0, 0, 40.0)      # loin : seuls les ennemis se voient
	var bete := load("res://scripts/bete_quat.gd")
	# --- araignée (embuscade) et bandit qui patrouille vers elle : hostiles, ils se battent jusqu'à la mort de l'un
	var ar: CharacterBody3D = sc.creer_ennemi(bete, Vector3(0, 0.05, -2.0), {"ident": "araignee_fac", "espece": "araignee"})
	var ba: CharacterBody3D = sc.creer_draugr("sbire", Vector3(0, 0.05, 6.0), {"faction": "pillard", "nom_affiche": "Bandit", "contourne": true})
	await _frames(5)
	_verif(Factions.de(ar) == "araignee" and Factions.de(ba) == "pillard", "Factions.de : araignée = %s, bandit = %s" % [Factions.de(ar), Factions.de(ba)])
	var c0: int = j.coups_recus
	var v_ar0: float = ar.vie
	var v_ba0: float = ba.vie
	var t := 0
	var vu := false
	while ar.vivant() and ba.vivant() and t < 1800:          # 30 s au plus
		await physics_frame
		t += 1
		if not vu and (ar.rival == ba or ba.rival == ar):
			vu = true
			print("   rivaux à %.1f s (araignée → %s, bandit → %s)" % [t / 60.0, ar.rival, ba.rival])
	_verif(vu, "araignée et bandit se prennent pour rivaux")
	_verif(not ar.vivant() or not ba.vivant(), "le combat finit : araignée %s (%d/%d PV), bandit %s (%d/%d PV) en %.1f s" % [
		"morte" if not ar.vivant() else "vivante", ar.vie, v_ar0, "mort" if not ba.vivant() else "vivant", ba.vie, v_ba0, t / 60.0])
	_verif(ar.vie < v_ar0 and ba.vie < v_ba0, "coups échangés dans les deux sens")
	_verif(j.coups_recus == c0, "le joueur (à 40 m) n'est jamais frappé")
	for n in [ar, ba]:
		if is_instance_valid(n):
			n.queue_free()
	await _frames(5)
	# --- draugr et araignée côte à côte : neutres, ils ne se battent pas
	var dr: CharacterBody3D = sc.creer_draugr("sbire", Vector3(-6, 0.05, -2.0), {"contourne": true})
	var ar2: CharacterBody3D = sc.creer_ennemi(bete, Vector3(-4.0, 0.05, -2.0), {"ident": "araignee_crypte", "espece": "araignee"})
	await _frames(300)
	print("   draugr %s %d/%d rival=%s, araignée %s %d/%d rival=%s" % [dr.vivant(), dr.vie, dr.vie_max, dr.rival, ar2.vivant(), ar2.vie, ar2.vie_max, ar2.rival])
	_verif(dr.vivant() and ar2.vivant() and dr.vie == dr.vie_max and ar2.vie == ar2.vie_max and dr.rival == null and ar2.rival == null,
		"draugr et araignée à 2 m pendant 5 s : aucun coup (neutres)")
	# --- le joueur revient : ils le prennent pour cible comme avant (aucun rival n'intervient)
	j.global_position = ar2.global_position + Vector3(0, 0, 3.0)
	var c1: int = j.coups_recus
	await _frames(400)
	_verif(j.coups_recus > c1, "joueur au contact : il est attaqué (%d coups)" % (j.coups_recus - c1))
	sc.queue_free()
