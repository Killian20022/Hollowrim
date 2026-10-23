extends SceneTree
## AUDIT DES INTERPÉNÉTRATIONS (« des éléments se fondent dans le décor ») : pour chaque objet posé, mesure
##   - l'ENFONCEMENT dans le sol (sommets sous le sol : profondeur, part de la hauteur),
##   - le vide dessous : objet FLOTTANT (aucun sommet ne touche le sol, > 5 cm) ou en porte-à-faux,
##   - la PÉNÉTRATION dans les parois (rayons horizontaux depuis l'axe de l'objet, à trois hauteurs, 8 directions),
##   - le CHEVAUCHEMENT entre objets (part des sommets de l'un dans la boîte de l'autre),
##   - les INTERACTIFS inatteignables (aucune place debout libre à portée, ou vue coupée par la roche),
##   - les points d'APPARITION des ennemis (sol, paroi, objets) et les LUMIÈRES dans la roche.
## Liste classée par gravité (GRAVE / MOYEN / LEGER) puis par mesure ; résumé par catégorie ; code de sortie = nombre de cas graves.
##
##   godot --headless --path . --script res://outils/audit_interpenetrations.gd -- --nouvelle --paisible --lieu=grotte
##        [--max=40]            lignes de cas affichées (défaut 60 ; les résumés comptent tout)
##        [--poses=<fichier>]   écrit les poses de capture (format --captures) des --vues=N pires cas (défaut 15)
##        [--tous]              affiche aussi les cas légers
##
## Lieux :
##   grotte  : complet. Registre du décor (CrypteDecor.audit_actif → decor.objets_audit : objet_debut/objet_fin autour de chaque pose),
##             instances du kit (GrotteKit._inst x gabarits), accroches (apparitions, patrouilles), interactifs, lumières.
##             Sol et parois : triangles de collision exacts de la coque (decor.coll, orientés vers le côté visible).
##   crypte, village, exterieur : registre CrypteDecor s'il existe (crypte), sinon nœuds (MeshInstance3D / MultiMeshInstance3D sous la
##             racine du lieu) + Interactifs + lumières ; sol et parois par rayons physiques (moins précis : à affiner par lieu,
##             voir _collecter_* et TerrainPhysique). Pour la crypte : entourer les poses de CrypteDecor de objet_debut/objet_fin.
##
## Seuils (constantes ci-dessous) : enfoncement signalé au-delà de 10 % de la hauteur ou 8 cm, grave au-delà de 25 % ou 15 cm ;
## flottant au-delà de 5 cm (grave 15 cm) ; paroi 5 cm (grave 12 cm ou 30 % du rayon) ; chevauchement 25 % des sommets (grave 50 %).

const SCENE := "res://scenes/foret_test.tscn"
const AUDIT_CRYPTE := preload("res://outils/audit_crypte.gd")

# familles : comment juger un genre
const OBJET := 0      # posé au sol, ne doit ni s'enfoncer, ni flotter, ni entrer dans la paroi ni dans un autre objet
const PLANTE := 1     # poteau planté (enfoncement voulu) : flottant, paroi, chevauchement seulement
const ROCHE := 2      # roche naturelle : enfoncement libre (sauf avalée), flottant, porte-à-faux
const MUR := 3        # accroché à la paroi ou à la voûte : seulement « entièrement dans la roche »
const IGNORE := 4     # nappes, cascades, structures traversantes

const GENRES := {
	"coffre": OBJET, "ressource": OBJET, "interaction": OBJET, "caisse": OBJET, "coffre_ouvert": OBJET, "sac": OBJET, "tabouret": OBJET,
	"couchage": OBJET, "ratelier": OBJET, "feu_camp": OBJET, "brasero": OBJET, "tonneau": OBJET, "urne": OBJET, "table": OBJET,
	"chariot": OBJET, "autel": OBJET, "etagere": OBJET, "lit": OBJET, "barricade": OBJET, "socle": OBJET, "statue": OBJET, "sarcophage": OBJET,
	"os": OBJET, "arme": OBJET, "crane": OBJET, "pieces": OBJET, "bougie": OBJET, "trone": OBJET, "gravats": OBJET,
	"trophee": PLANTE, "etai": PLANTE, "pieu": PLANTE, "portique": PLANTE, "poteau_lanterne": PLANTE,
	"rocher": ROCHE, "caillou": ROCHE, "stalagmite": ROCHE, "pointe": ROCHE, "colonne": ROCHE, "congere": ROCHE, "cristal": MUR, "cristaux": ROCHE,
	"champignons": ROCHE, "grappe": MUR,
	"bloc": ROCHE, "dalle": ROCHE, "stalag": ROCHE, "pic": ROCHE, "neige": ROCHE,
	"stalactite": MUR, "stalac": MUR, "frange": MUR, "pan": MUR, "nez": MUR, "toile": MUR, "banniere": MUR, "applique": MUR, "lanterne": MUR,
	"lustre": MUR,
	"pont": IGNORE, "cascade": IGNORE, "nappe": IGNORE,
}
const PETITS := ["os", "arme", "crane", "pieces", "bougie"]            # menus objets posés en tas : chevauchements entre eux permis
const IMPORTANTS_MUR := ["lanterne", "toile", "banniere", "applique"]  # accroches jugées aussi contre la paroi (lanterne) / la roche

const ENF_RATIO := 0.10
const ENF_M := 0.08
const ENF_GRAVE_RATIO := 0.25
const ENF_GRAVE_M := 0.15
const FLOT_M := 0.05
const FLOT_GRAVE_M := 0.15
const PAROI_M := 0.05
const PAROI_GRAVE_M := 0.12
const CHEV := 0.25
const CHEV_GRAVE := 0.5
const ECH_MAX := 160              # sommets échantillonnés par objet

var lieu := "grotte"
var args := {}
var cas: Array = []               # {grav, cat, genre, id, p, mesure, txt}
var objets: Array = []            # {src, genre, id, fam, v, aabb, xf, boite, solides, petit}
var terrain                        # TerrainTris ou TerrainPhysique
var g: Grotte
var _bsamp := {}                  # branche -> PackedVector3Array (points d'axe tous les 0,5 m)

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	lieu = String(args.get("lieu", "grotte"))
	CrypteDecor.audit_actif = true
	if lieu == "crypte":
		AUDIT_CRYPTE.preparer()      # journal des objets de la crypte (outils/audit_crypte.gd)
	_go.call_deferred()

func _attendre(n: int) -> void:
	for i in n:
		await physics_frame

func _go() -> void:
	if args.has("planche"):      # planche des cas (crypte) : cas.txt + captures -> planche.png
		AUDIT_CRYPTE.planche(String(args["planche"]), String(args.get("titre", "")), int(args.get("colonnes", "3")), int(args.get("largeur", "640")))
		quit(0)
		return
	var t0 := Time.get_ticks_msec()
	var m: Node3D = (load(SCENE) as PackedScene).instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(60)
	match lieu:
		"grotte":
			await _collecter_grotte(m)
		"crypte":
			# crypte : audit dédié (journal des objets, boîtes orientées, collisions du décor, emprises) — outils/audit_crypte.gd
			var graves: int = await AUDIT_CRYPTE.new().lancer(self, m, args)
			quit(graves)
			return
		"village", "exterieur":
			await _collecter_exterieur(m)
		_:
			print("lieu inconnu : %s (grotte|crypte|village|exterieur)" % lieu)
			quit(2)
			return
	var tc := Time.get_ticks_msec()
	print("AUDIT %s : %d objets, collecte %.1f s" % [lieu, objets.size(), (tc - t0) / 1000.0])
	if args.has("sonde"):        # --sonde=x,y,z : surfaces de la verticale et objets proches (mise au point)
		var q := String(args["sonde"]).split_floats(",")
		var pq := Vector3(q[0], q[1], q[2])
		print("SONDE colonne ", terrain.colonne(pq.x, pq.z))
		for o: Dictionary in objets:
			if (o["aabb"] as AABB).grow(0.3).has_point(pq):
				print("SONDE objet %s %s %s aabb=%s solides=%s" % [o["src"], o["genre"], o["id"], o["aabb"], o["solides"]])
	_verifier_objets()
	_verifier_chevauchements()
	var t1 := Time.get_ticks_msec()
	print("AUDIT : vérifications %.1f s" % ((t1 - tc) / 1000.0))
	var graves := _rapport()
	if args.has("poses"):
		_ecrire_poses(String(args["poses"]), int(args.get("vues", "15")))
	quit(graves)

# =================================================================== collecte : grotte
func _collecter_grotte(m: Node3D) -> void:
	var a: Node3D = m.grotte_acces
	a.attendre_exterieur()
	g = a.obtenir()
	a.montrer(true)
	m._aller_grotte("4,0,0,0")
	await _attendre(30)
	terrain = TerrainTris.new(g.decor.coll)
	for id: String in g.ordre:
		var pts := PackedVector3Array()
		var L := g.longueur(id)
		var s := 0.0
		while s <= L:
			pts.append(g.sol_en(id, s, 0.0))
			s += 0.5
		_bsamp[id] = pts
	# 1. décor (registre)
	for o: Dictionary in g.decor.objets_audit:
		_ajouter("decor", String(o["genre"]), String(o["id"]), o["v"], null, AABB(), o["solides"])
	# 2. kit : instances x gabarits
	if g.kit != null:
		var gab_v := {}
		for cle: String in g.kit._inst:
			var nom := cle.get_slice("|", 0)
			if not gab_v.has(nom):
				var tous := PackedVector3Array()
				var G: Dictionary = g.kit.gab[nom]
				for mn: String in G["surf"]:
					tous.append_array(G["surf"][mn]["v"])
				gab_v[nom] = tous
			var vl: PackedVector3Array = gab_v[nom]
			var bl := _aabb_de(vl)
			for xf: Transform3D in g.kit._inst[cle]:
				var vw := PackedVector3Array()
				var pas := maxi(1, vl.size() / 60)
				for i in range(0, vl.size(), pas):
					vw.append(xf * vl[i])
				_ajouter("kit", nom.get_slice("_", 0), nom, vw, xf, bl, [])
	# 3. interactifs
	var jeu: GrotteJeu = a.jeu
	for id: String in jeu.interactifs:
		var it: Node3D = jeu.interactifs[id]
		_verifier_interactif(id, it.position, float(it.rayon))
	# 4. apparitions et patrouilles
	for ac: Dictionary in g.accroches:
		if ac["type"] == "ennemi":
			_verifier_apparition(String(ac["id"]), ac["pos"], false)
			var k := 0
			for q: Vector3 in ac["patrouille"]:
				_verifier_apparition("%s/patrouille%d" % [ac["id"], k], q + Vector3(0, 0.05, 0), true)
				k += 1
	# 5. lumières
	for l: Node in g.find_children("*", "Light3D", true, false):
		var p := g.to_local((l as Node3D).global_position)
		if terrain.dedans_roche(p):
			_cas(2, "lumiere_roche", "lumiere", String(l.name), p, 1.0, "lumière dans la roche")

# =================================================================== collecte : crypte / extérieurs (générique, rayons physiques)
func _collecter_crypte(m: Node3D) -> void:
	m.tertre._passer(true)
	await _attendre(90)
	var c: Node3D = m.tertre.crypte
	terrain = TerrainPhysique.new(c, root.get_world_3d().direct_space_state)
	var dec = c.get("decor")
	if dec is CrypteDecor and not (dec as CrypteDecor).objets_audit.is_empty():
		for o: Dictionary in (dec as CrypteDecor).objets_audit:
			_ajouter("decor", String(o["genre"]), String(o["id"]), o["v"], null, AABB(), o["solides"])
	else:
		_noeuds(c, c)
	_interactifs_et_lumieres(c)

func _collecter_exterieur(m: Node3D) -> void:
	var rac: Node3D = m.village if lieu == "village" and m.village != null else m
	terrain = TerrainPhysique.new(m, root.get_world_3d().direct_space_state)
	_noeuds(rac, m)
	_interactifs_et_lumieres(m)

## Objets lus dans l'arbre (lieux sans registre) : un MeshInstance3D = un objet (sauf maillages géants : sol, coque) ; un MultiMesh = une
## instance par objet. Le genre est tiré du nom du nœud (à affiner par lieu).
func _noeuds(rac: Node3D, repere: Node3D) -> void:
	for n: Node in rac.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var ab := mi.mesh.get_aabb()
		if ab.size.length() > 12.0:
			continue
		var xf := repere.global_transform.affine_inverse() * mi.global_transform
		var vw := PackedVector3Array()
		for i in 8:
			vw.append(xf * ab.get_endpoint(i))
		_ajouter("noeud", String(mi.name).to_lower(), String(mi.get_path()), vw, xf, ab, [])
	for n: Node in rac.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null:
			continue
		var ab := mm.mesh.get_aabb()
		if ab.size.length() > 12.0:
			continue
		for i in mm.instance_count:
			var xf := repere.global_transform.affine_inverse() * (n as Node3D).global_transform * mm.get_instance_transform(i)
			var vw := PackedVector3Array()
			for k in 8:
				vw.append(xf * ab.get_endpoint(k))
			_ajouter("noeud", String(n.name).to_lower(), "%s#%d" % [n.name, i], vw, xf, ab, [])

func _interactifs_et_lumieres(rac: Node3D) -> void:
	for n: Node in rac.find_children("*", "Node3D", true, false):
		if n.get_script() != null and String((n.get_script() as Script).resource_path).ends_with("interactif.gd"):
			_verifier_interactif(String(n.name), rac.to_local((n as Node3D).global_position), float(n.get("rayon")))
	for l: Node in rac.find_children("*", "Light3D", true, false):
		var p := rac.to_local((l as Node3D).global_position)
		if terrain.dedans_roche(p):
			_cas(2, "lumiere_roche", "lumiere", String(l.name), p, 1.0, "lumière dans la roche / un mur")

# =================================================================== objets
func _famille(genre: String) -> int:
	if GENRES.has(genre):
		return GENRES[genre]
	for k: String in GENRES:                 # lieux sans registre : genre tiré du nom du nœud
		if genre.contains(k):
			return GENRES[k]
	return IGNORE if lieu == "grotte" else OBJET

static func _aabb_de(v: PackedVector3Array) -> AABB:
	if v.is_empty():
		return AABB()
	var mn := v[0]
	var mx := v[0]
	for p in v:
		mn = mn.min(p)
		mx = mx.max(p)
	return AABB(mn, mx - mn)

func _ajouter(src: String, genre: String, id: String, v: PackedVector3Array, xf: Variant, boite: AABB, solides: Array) -> void:
	if v.is_empty() and solides.is_empty():
		return
	var ab := _aabb_de(v)
	for s: AABB in solides:
		ab = ab.merge(s) if ab.size != Vector3.ZERO else s
	var ech := v
	if v.size() > ECH_MAX:
		ech = PackedVector3Array()
		var pas := float(v.size()) / ECH_MAX
		var f := 0.0
		while int(f) < v.size():
			ech.append(v[int(f)])
			f += pas
		# les extrêmes comptent toujours (pied, sommet, flancs)
		var ext := [0, 0, 0, 0, 0, 0]
		for i in v.size():
			if v[i].y < v[ext[0]].y: ext[0] = i
			if v[i].y > v[ext[1]].y: ext[1] = i
			if v[i].x < v[ext[2]].x: ext[2] = i
			if v[i].x > v[ext[3]].x: ext[3] = i
			if v[i].z < v[ext[4]].z: ext[4] = i
			if v[i].z > v[ext[5]].z: ext[5] = i
		for i: int in ext:
			ech.append(v[i])
	objets.append({"n": objets.size(), "src": src, "genre": genre, "id": id, "fam": _famille(genre), "v": ech, "aabb": ab, "xf": xf, "boite": boite,
		"solides": solides, "petit": genre in PETITS, "tris": v if (xf == null and v.size() % 3 == 0) else PackedVector3Array()})

func _cas(grav: int, cat: String, genre: String, id: String, p: Vector3, mesure: float, txt: String) -> void:
	cas.append({"grav": grav, "cat": cat, "genre": genre, "id": id, "p": p, "mesure": mesure, "txt": txt})

## Écart d'un sommet au sol : > 0 = au-dessus (vide), < 0 = enfoui (profondeur jusqu'à la surface du sol au-dessus), NAN = pas de sol.
## La surface juste sous le sommet décide : tournée vers le haut = air libre ; tournée vers le bas = le sommet est dans la roche (sous un
## surplomb, une corniche…). Les dessus des solides des AUTRES objets comptent comme sol (caisse posée sur une caisse, pont).
func _ecart_sol(p: Vector3, soi: Dictionary, h_max := 1.0) -> float:
	var dessous := -1e9
	var ny_dessous := 0.0
	var dessus := 1e9
	var ny_dessus := 0.0
	for e: Vector2 in terrain.colonne(p.x, p.z):
		if e.x <= p.y + 0.001:
			if e.x > dessous:
				dessous = e.x
				ny_dessous = e.y
		elif e.x < dessus:
			dessus = e.x
			ny_dessus = e.y
	for o: Dictionary in _supports_pres(p.x, p.z):
		if int(o["n"]) == int(soi.get("n", -1)):
			continue
		for b: AABB in o["solides"]:
			if p.x >= b.position.x and p.x <= b.end.x and p.z >= b.position.z and p.z <= b.end.z and b.end.y <= p.y + 0.001 and b.end.y > dessous:
				dessous = b.end.y
				ny_dessous = 1.0
	if dessous > -1e8 and ny_dessous > 0.0:
		return p.y - dessous
	if dessus < 1e8 and ny_dessus > 0.5 and dessus - p.y <= h_max:     # sous un sol presque plat : enfoui (plus profond que l'objet
		return p.y - dessus                                              # n'est haut : hors de la galerie, affaire de paroi)
	return NAN

var _grille_sup := {}
func _indexer_supports() -> void:
	for o: Dictionary in objets:
		if (o["solides"] as Array).is_empty():
			continue
		var ab: AABB = o["aabb"]
		for cx in range(floori(ab.position.x / 2.0), floori(ab.end.x / 2.0) + 1):
			for cz in range(floori(ab.position.z / 2.0), floori(ab.end.z / 2.0) + 1):
				var k := Vector2i(cx, cz)
				if not _grille_sup.has(k):
					_grille_sup[k] = []
				(_grille_sup[k] as Array).append(o)

func _supports_pres(x: float, z: float) -> Array:
	return _grille_sup.get(Vector2i(floori(x / 2.0), floori(z / 2.0)), [])

func _verifier_objets() -> void:
	_indexer_supports()
	var grille := _grille_objets()
	for o: Dictionary in objets:
		var fam: int = o["fam"]
		if fam == IGNORE:
			continue
		var ab: AABB = o["aabb"]
		var h := maxf(ab.size.y, 0.02)
		var c := ab.get_center()
		var genre: String = o["genre"]
		if fam == MUR:
			if genre in IMPORTANTS_MUR and terrain.dedans_roche(c):
				_cas(2, "paroi", genre, o["id"], c, 1.0, "entièrement dans la roche")
			if genre == "lanterne":
				_paroi(o, c, h)
			continue
		if h > 0.25 and fam != ROCHE and terrain.dedans_roche(Vector3(c.x, ab.position.y + h * 0.5, c.z)):
			_cas(2, "paroi", genre, o["id"], c, 1.0, "centre dans la roche")
			continue
		# --- sol
		var v: PackedVector3Array = o["v"]
		var enf := 0.0
		var flot := 1e9
		var vide := 0.0
		var y_bas := ab.position.y
		var n_ok := 0
		var n_enf := 0
		for p in v:
			var d := _ecart_sol(p, o, h + 0.25)
			if is_nan(d):
				continue
			n_ok += 1
			enf = maxf(enf, -d)
			if d < -0.01:
				n_enf += 1
			flot = minf(flot, d)
			if p.y < y_bas + 0.04 + 0.05 * h:
				vide = maxf(vide, d)
		if n_ok == 0:
			_cas(2, "paroi", genre, o["id"], c, 1.0, "aucun sol sous l'objet (hors de la galerie)")
			continue
		if flot > FLOT_M and fam != MUR:
			if not _pose_sur_objet(o, grille):
				var gr := 2 if flot > FLOT_GRAVE_M else 1
				if fam == ROCHE and h < 0.25:
					gr = mini(gr, 1)
				_cas(gr, "flottant", genre, o["id"], c, flot, "flotte à %.0f cm du sol" % (flot * 100.0))
		elif vide > maxf(0.1, 0.2 * h) and fam != PLANTE and not _pose_sur_objet(o, grille):
			_cas(1 if fam == OBJET else 0, "porte_a_faux", genre, o["id"], c, vide, "vide de %.0f cm sous un côté" % (vide * 100.0))
		if fam == OBJET:
			if (enf > 0.04 and (enf > ENF_RATIO * h or enf > ENF_M)) or (o["petit"] and enf > 0.01 and enf > 0.4 * h):
				var gr2 := 2 if (enf > ENF_GRAVE_RATIO * h or enf > ENF_GRAVE_M) else 1
				if o["petit"]:
					gr2 = mini(gr2, 1)
				_cas(gr2, "enfoncement", genre, o["id"], c, enf, "enfoncé de %.0f cm (%.0f %% de %.2f m)" % [enf * 100.0, enf / h * 100.0, h])
		elif fam == ROCHE:
			var part := float(n_enf) / n_ok
			if part > 0.85 and h > 0.12:
				_cas(1 if genre != "caillou" else 0, "enfoncement", genre, o["id"], c, part, "avalé par le sol (%.0f %% des sommets, %.2f m)" % [part * 100.0, h])
		# --- parois
		if fam == OBJET or fam == PLANTE:
			_paroi(o, c, h)

## Pénétration dans la paroi : rayons horizontaux depuis l'axe de l'objet (3 hauteurs x 8 directions) contre l'étendue de ses sommets.
func _paroi(o: Dictionary, c: Vector3, h: float) -> void:
	var ab: AABB = o["aabb"]
	var v: PackedVector3Array = o["v"]
	var pire := 0.0
	var rmax := 0.0
	for f: float in [0.2, 0.5, 0.85]:
		var y := ab.position.y + maxf(h * f, 0.08)
		var bande := maxf(h * 0.2, 0.06)
		for k in 8:
			var a := TAU * k / 8.0
			var d := Vector3(cos(a), 0.0, sin(a))
			var ext := 0.0
			for p in v:
				if absf(p.y - y) <= bande:
					ext = maxf(ext, (p - c).dot(d))
			if ext <= 0.0:
				continue
			rmax = maxf(rmax, ext)
			var hit: Dictionary = terrain.rayon(Vector3(c.x, y, c.z), d, ext + 0.5)
			if hit.is_empty() or absf((hit["n"] as Vector3).y) > 0.7:
				continue
			if not hit["avant"]:
				pire = maxf(pire, ext)
				continue
			pire = maxf(pire, ext - float(hit["t"]))
	if pire > PAROI_M:
		var gr := 2 if (pire > PAROI_GRAVE_M or pire > 0.3 * rmax) else 1
		if o["petit"]:
			gr = mini(gr, 1)
		_cas(gr, "paroi", o["genre"], o["id"], c, pire, "entre de %.0f cm dans la paroi" % (pire * 100.0))

# --- chevauchements
func _grille_objets() -> Dictionary:
	var gr := {}
	for o: Dictionary in objets:
		if o["fam"] == IGNORE:
			continue
		var ab: AABB = o["aabb"]
		for cx in range(floori(ab.position.x / 2.0), floori(ab.end.x / 2.0) + 1):
			for cz in range(floori(ab.position.z / 2.0), floori(ab.end.z / 2.0) + 1):
				var k := Vector2i(cx, cz)
				if not gr.has(k):
					gr[k] = []
				(gr[k] as Array).append(o)
	return gr

func _voisins(o: Dictionary, gr: Dictionary) -> Array:
	var ab: AABB = o["aabb"]
	var vus := {}
	var res: Array = []
	for cx in range(floori(ab.position.x / 2.0), floori(ab.end.x / 2.0) + 1):
		for cz in range(floori(ab.position.z / 2.0), floori(ab.end.z / 2.0) + 1):
			for q: Dictionary in gr.get(Vector2i(cx, cz), []):
				if int(q["n"]) != int(o["n"]) and not vus.has(int(q["n"])):
					vus[int(q["n"])] = true
					res.append(q)
	return res

## Boîte « pleine » d'un objet : rétrécie pour les roches (formes arrondies), exacte pour les objets manufacturés.
func _dedans(q: Dictionary, p: Vector3) -> float:
	var fam: int = q["fam"]
	var k_h := 0.72 if fam == ROCHE or fam == MUR else 0.92
	var k_v := 0.85 if fam == ROCHE or fam == MUR else 0.95
	var pl := p
	var b: AABB = q["aabb"]
	if q["xf"] != null:
		pl = (q["xf"] as Transform3D).affine_inverse() * p
		b = q["boite"]
	var cc := b.get_center()
	var he := b.size * 0.5 * Vector3(k_h, k_v, k_h)
	var dl := (pl - cc).abs()
	if dl.x > he.x or dl.y > he.y or dl.z > he.z:
		return -1.0
	var prof := minf(he.x - dl.x, minf(he.y - dl.y, he.z - dl.z))
	if q["xf"] != null:
		prof *= (q["xf"] as Transform3D).basis.get_scale().x
	return prof

func _dedans_obj(o: Dictionary, p: Vector3) -> float:
	if o["xf"] != null or (o["tris"] as PackedVector3Array).is_empty():
		return _dedans(o, p)
	return 0.05 if _vox_dedans(o, p) else -1.0

func _pose_sur_objet(o: Dictionary, gr: Dictionary) -> bool:
	var ab: AABB = o["aabb"]
	for q: Dictionary in _voisins(o, gr):
		var qb: AABB = q["aabb"]
		if absf(qb.end.y - ab.position.y) < 0.1 or (qb.position.y < ab.position.y and qb.end.y > ab.position.y):
			var ix := minf(ab.end.x, qb.end.x) - maxf(ab.position.x, qb.position.x)
			var iz := minf(ab.end.z, qb.end.z) - maxf(ab.position.z, qb.position.z)
			if ix > 0.25 * ab.size.x and iz > 0.25 * ab.size.z:
				return true
	return false

func _verifier_chevauchements() -> void:
	var gr := _grille_objets()
	var vus := {}
	for o: Dictionary in objets:
		var fo: int = o["fam"]
		var imp: bool = (fo == OBJET or fo == PLANTE or o["genre"] == "lanterne") and not o["petit"]
		if not imp:
			continue
		for q: Dictionary in _voisins(o, gr):
			if q["petit"] or (q["fam"] == MUR and q["genre"] in ["toile", "stalactite", "stalac", "frange"]):
				continue
			var cle := Vector2i(mini(int(o["n"]), int(q["n"])), maxi(int(o["n"]), int(q["n"])))
			if vus.has(cle):
				continue
			vus[cle] = true
			if not (o["aabb"] as AABB).intersects(q["aabb"]):
				continue
			var cm := _commun(o, q)
			var f: float = cm[0]
			var litres: float = cm[1]
			if f < CHEV or litres < 3.0:
				continue
			var gq := 2 if f >= CHEV_GRAVE else 1
			var ab: AABB = o["aabb"]
			_cas(gq, "chevauchement", o["genre"], o["id"], ab.get_center(), f,
				"%.0f %% commun avec %s %s (%.0f L)" % [f * 100.0, q["genre"], q["id"], litres])

## Occupation d'un objet du décor : voxels de 10 cm touchés par ses triangles, remplis colonne par colonne (du plus bas au plus haut
## voxel de chaque colonne) : un étai reste un portique (poteaux + chapeau), une caisse devient pleine.
const VOX := 0.1
var _occ_cache := {}
func _occupation(o: Dictionary) -> Dictionary:
	var n: int = o["n"]
	if _occ_cache.has(n):
		return _occ_cache[n]
	var surf := {}
	var t: PackedVector3Array = o["tris"]
	for i in range(0, t.size() - 2, 3):
		var a := t[i]
		var b := t[i + 1]
		var c := t[i + 2]
		var m := ceili(maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a))) / (VOX * 0.5))
		m = clampi(m, 1, 400)
		for u in m + 1:
			for w in m + 1 - u:
				var q := a + (b - a) * (float(u) / m) + (c - a) * (float(w) / m)
				surf[Vector3i(floori(q.x / VOX), floori(q.y / VOX), floori(q.z / VOX))] = true
	var cols := {}
	for k: Vector3i in surf:
		var kc := Vector2i(k.x, k.z)
		var mm: Vector2i = cols.get(kc, Vector2i(k.y, k.y))
		cols[kc] = Vector2i(mini(mm.x, k.y), maxi(mm.y, k.y))
	var plein := {}
	for kc: Vector2i in cols:
		var mm: Vector2i = cols[kc]
		for y in range(mm.x, mm.y + 1):
			plein[Vector3i(kc.x, y, kc.y)] = true
	_occ_cache[n] = plein
	return plein

func _vox_dedans(o: Dictionary, p: Vector3) -> bool:
	return _occupation(o).has(Vector3i(floori(p.x / VOX), floori(p.y / VOX), floori(p.z / VOX)))

## Part commune de deux objets, rapportée au plus petit : [part, litres communs].
func _commun(a: Dictionary, b: Dictionary) -> Array:
	var a_kit: bool = a["xf"] != null
	var b_kit: bool = b["xf"] != null
	if a_kit and b_kit:
		return [0.0, 0.0]
	if a_kit:
		var t := a
		a = b
		b = t
		b_kit = true
	var va := _occupation(a)
	if va.is_empty():
		return [0.0, 0.0]
	var nc := 0
	if b_kit:
		for k: Vector3i in va:
			if _dedans(b, (Vector3(k) + Vector3(0.5, 0.5, 0.5)) * VOX) >= 0.0:
				nc += 1
		var bv: PackedVector3Array = b["v"]
		var nb := 0
		for p in bv:
			if va.has(Vector3i(floori(p.x / VOX), floori(p.y / VOX), floori(p.z / VOX))):
				nb += 1
		var part := maxf(float(nc) / va.size(), float(nb) / maxi(bv.size(), 1))
		return [part, nc * VOX * VOX * VOX * 1000.0]
	var vb := _occupation(b)
	if vb.is_empty():
		return [0.0, 0.0]
	var petit := va if va.size() <= vb.size() else vb
	var grand := vb if va.size() <= vb.size() else va
	for k: Vector3i in petit:
		if grand.has(k):
			nc += 1
	return [float(nc) / petit.size(), nc * VOX * VOX * VOX * 1000.0]

func _part_dedans(a: Dictionary, b: Dictionary) -> Array:
	var v: PackedVector3Array = a["v"]
	if v.is_empty():
		return [0.0, 0.0]
	var n := 0
	var prof := 0.0
	for p in v:
		var d := _dedans(b, p)
		if d >= 0.0:
			n += 1
			prof = maxf(prof, d)
	return [float(n) / v.size(), prof]

# =================================================================== interactifs, apparitions
## Atteignable : une place debout (sol, pente douce, capsule libre de paroi et d'objets solides) à moins de `rayon` à l'horizontale, d'où
## la caméra (1,6 m) voit le point sans roche entre les deux et à moins de rayon + 1 m (règle d'interactif.gd).
func _verifier_interactif(id: String, p: Vector3, rayon: float) -> void:
	if terrain.dedans_roche(p):
		_cas(2, "inatteignable", "interactif", id, p, 1.0, "point d'interaction dans la roche")
		return
	var ok := false
	for r: float in [0.6, 1.0, 1.4, 1.8]:
		if r >= rayon:
			break
		for k in 12:
			var a := TAU * k / 12.0
			var q := p + Vector3(cos(a) * r, 0.0, sin(a) * r)
			var s: float = terrain.sol_sous(q.x, q.z, p.y + 1.2)
			if s < -1e8 or s < p.y - 2.5:
				continue
			var pied := Vector3(q.x, s, q.z)
			if not _place_libre(pied, 0.3):
				continue
			var oeil := pied + Vector3(0, 1.6, 0)
			if oeil.distance_to(p) > rayon + 1.0:
				continue
			var h: Dictionary = terrain.rayon(oeil, p - oeil, oeil.distance_to(p) - 0.05)
			if not h.is_empty():
				continue
			ok = true
			break
		if ok:
			break
	if not ok:
		_cas(2, "inatteignable", "interactif", id, p, 1.0, "aucune place debout libre à portée (rayon %.1f m)" % rayon)

## Place libre pour une capsule de rayon r posée en `pied` : parois (rayons à 0,3 / 1,0 / 1,6 m) et solides des objets.
func _place_libre(pied: Vector3, r: float) -> bool:
	for hh: float in [0.35, 1.0, 1.6]:
		var o := pied + Vector3(0, hh, 0)
		if terrain.dedans_roche(o):
			return false
		for k in 8:
			var a := TAU * k / 8.0
			var hit: Dictionary = terrain.rayon(o, Vector3(cos(a), 0, sin(a)), r)
			if not hit.is_empty():
				return false
	for ob: Dictionary in _supports_pres(pied.x, pied.z):
		for b: AABB in ob["solides"]:
			if b.grow(r).has_point(pied + Vector3(0, 0.5, 0)):
				return false
	return true

func _verifier_apparition(id: String, p: Vector3, patrouille: bool) -> void:
	var pied := p - Vector3(0, 0.05, 0)
	var s: float = terrain.sol_sous(pied.x, pied.z, pied.y + 0.6)
	if s < -1e8:
		_cas(2, "apparition", "ennemi", id, p, 1.0, "aucun sol sous le point")
		return
	var dy := pied.y - s
	if absf(dy) > 0.1:
		_cas(2 if absf(dy) > 0.25 and not patrouille else 1, "apparition", "ennemi", id, p, absf(dy), ("à %.0f cm au-dessus du sol" if dy > 0 else "à %.0f cm sous le sol") % (absf(dy) * 100.0))
	var mini_d := 9.0
	for hh: float in [0.35, 1.0, 1.6]:
		var o := Vector3(pied.x, s + hh, pied.z)
		if terrain.dedans_roche(o):
			mini_d = -1.0
			break
		for k in 8:
			var a := TAU * k / 8.0
			var hit: Dictionary = terrain.rayon(o, Vector3(cos(a), 0, sin(a)), 1.0)
			if not hit.is_empty() and absf((hit["n"] as Vector3).y) < 0.7:
				mini_d = minf(mini_d, float(hit["t"]))
	if mini_d < 0.3:
		_cas(2 if (mini_d < 0.15 and not patrouille) else 1, "apparition", "ennemi", id, p, 0.3 - mini_d,
			"dans la paroi" if mini_d < 0.0 else "à %.0f cm de la paroi" % (mini_d * 100.0))
	# objets : capsule (r 0,3, 1,8 m) contre les solides et les objets / roches pleines
	var cap := AABB(Vector3(pied.x - 0.3, s + 0.15, pied.z - 0.3), Vector3(0.6, 1.6, 0.6))
	for o: Dictionary in objets:
		var fam: int = o["fam"]
		if fam == IGNORE or fam == MUR or o["petit"]:
			continue
		var ab: AABB = o["aabb"]
		if not ab.intersects(cap) or ab.size.y < 0.3:
			continue
		var pire := -1.0
		for hh: float in [0.3, 0.9, 1.5]:
			for dx: float in [-0.25, 0.0, 0.25]:
				for dz: float in [-0.25, 0.0, 0.25]:
					pire = maxf(pire, _dedans_obj(o, Vector3(pied.x + dx, s + hh, pied.z + dz)))
		if pire > 0.02:
			var centre := _dedans_obj(o, Vector3(pied.x, s + 0.9, pied.z)) > 0.0 or _dedans_obj(o, Vector3(pied.x, s + 0.3, pied.z)) > 0.0
			_cas(2 if (centre and not patrouille) else 1, "apparition", "ennemi", id, p, pire, "dans %s %s" % [o["genre"], o["id"]])

# =================================================================== rapport
const NOMS_G := ["LEGER", "MOYEN", "GRAVE"]
func _rapport() -> int:
	cas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["grav"] != b["grav"]:
			return a["grav"] > b["grav"]
		return float(a["mesure"]) > float(b["mesure"]))
	var parcat := {}
	for c: Dictionary in cas:
		var k: String = c["cat"]
		if not parcat.has(k):
			parcat[k] = [0, 0, 0]
		parcat[k][c["grav"]] += 1
	var mx := int(args.get("max", "60"))
	var n := 0
	for c: Dictionary in cas:
		if c["grav"] == 0 and not args.has("tous"):
			continue
		if n >= mx:
			break
		n += 1
		var p: Vector3 = c["p"]
		print("CAS %-5s %-14s %-16s %-26s (%6.1f,%6.1f,%6.1f) %s  %s" % [NOMS_G[c["grav"]], c["cat"], c["genre"], String(c["id"]).left(26), p.x, p.y, p.z, _lieu_txt(p), c["txt"]])
	var tot := [0, 0, 0]
	for k: String in parcat:
		print("RESUME %-14s grave %3d  moyen %3d  leger %3d" % [k, parcat[k][2], parcat[k][1], parcat[k][0]])
		for i in 3:
			tot[i] += parcat[k][i]
	print("TOTAL %s : grave %d  moyen %d  leger %d  (%d objets)" % [lieu, tot[2], tot[1], tot[0], objets.size()])
	return tot[2]

## Repère lisible (grotte) : branche, abscisse globale et décalage latéral (format des poses de capture).
func _situer(p: Vector3) -> Array:
	var best := ""
	var bs := 0.0
	var bd := 1e9
	for id: String in _bsamp:
		var pts: PackedVector3Array = _bsamp[id]
		for i in pts.size():
			var q := pts[i]
			var d := Vector2(q.x - p.x, q.z - p.z).length() + absf(q.y - p.y) * 0.5
			if d < bd:
				bd = d
				best = id
				bs = i * 0.5
	if best == "":
		return ["", 0.0, 0.0]
	var lat := (p - g.sol_en(best, bs, 0.0)).dot(g.droite(best, bs))
	return [best, bs, lat]

func _lieu_txt(p: Vector3) -> String:
	if g == null:
		return ""
	var si := _situer(p)
	if si[0] == "":
		return ""
	return "s=%.1f lat=%.1f" % [float(g.br[si[0]]["decalage"]) + float(si[1]), float(si[2])]

## Poses de capture (format --captures) des pires cas : point de vue sur l'axe de la galerie, 2,5 à 5 m avant ou après l'objet, regard sur lui.
func _ecrire_poses(chemin: String, nb: int) -> void:
	if g == null:
		return
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	var pris: Array = []
	var k := 0
	var filtre := String(args.get("filtre", ""))
	for c: Dictionary in cas:
		if k >= nb:
			break
		if filtre != "" and not (filtre in String(c["cat"]) + ":" + String(c["genre"])):
			continue
		var p: Vector3 = c["p"]
		var trop_pres := false
		for q: Vector3 in pris:
			if q.distance_to(p) < 2.0:
				trop_pres = true
		if trop_pres:
			continue
		var si := _situer(p)
		if si[0] == "":
			continue
		var id: String = si[0]
		var vue := _point_de_vue(id, float(si[1]), float(si[2]), p)
		if vue.is_empty():
			continue
		pris.append(p)
		k += 1
		var nom := "%02d_%s_%s" % [k, c["cat"], String(c["genre"])]
		f.store_line("%s grotte %.2f,%.2f,%.1f,%.1f sans-mains  # %s %s : %s" % [nom, vue[0], vue[1], vue[2], vue[3], c["genre"], c["id"], c["txt"]])
	f.close()
	print("POSES : %d vues écrites dans %s" % [k, chemin])

## Point de vue : anneau de points debout autour de l'objet (2 à 4 m), sol libre, vue dégagée sur le centre ; préfère le côté de l'axe
## de la galerie. Rend [s, lat, lacet°, tangage°] dans la branche `id` (format des poses) ou [].
func _point_de_vue(id: String, s: float, lat: float, p: Vector3) -> Array:
	var axe := g.sol_en(id, s, 0.0)
	var vers_axe := Vector3(axe.x - p.x, 0, axe.z - p.z)
	var a0 := atan2(vers_axe.z, vers_axe.x) if vers_axe.length() > 0.3 else 0.0
	for dist: float in [2.4, 3.2, 1.8, 4.2]:
		for k in 12:
			var a := a0 + (TAU / 12.0) * ((k + 1) / 2) * (1 if k % 2 == 0 else -1)
			var q := p + Vector3(cos(a), 0, sin(a)) * dist
			var sy: float = terrain.sol_sous(q.x, q.z, p.y + 2.0)
			if sy < -1e8 or absf(sy - p.y) > 2.5:
				continue
			var pied := Vector3(q.x, sy, q.z)
			if not _place_libre(pied, 0.25):
				continue
			var si := _situer(pied)
			if si[0] == "":
				continue
			var idv: String = si[0]
			var pv := g.sol_en(idv, float(si[1]), float(si[2]))
			if pv.distance_to(pied) > 0.6:
				continue
			var oeil := pv + Vector3(0, 1.6, 0)
			var vers := p - oeil
			if not terrain.rayon(oeil, vers, vers.length() - 0.25).is_empty():
				continue
			var cap := atan2(-vers.x, -vers.z)
			var yaw := wrapf(rad_to_deg(cap - g.lacet_en(idv, float(si[1]))), -180.0, 180.0)
			var pitch := rad_to_deg(atan2(vers.y, Vector2(vers.x, vers.z).length()))
			return [float(g.br[idv]["decalage"]) + float(si[1]), float(si[2]), yaw, clampf(pitch, -60.0, 40.0)]
	return []

# =================================================================== terrains
## Triangles exacts (repère du lieu), normales tournées vers le côté visible ; grille de 1 m sur (x, z).
class TerrainTris:
	var t: PackedVector3Array
	var nrm := PackedVector3Array()
	var grille := {}
	var _col := {}

	func _init(tris: PackedVector3Array) -> void:
		t = tris
		var n := t.size() / 3
		nrm.resize(n)
		for i in n:
			var a := t[i * 3]
			var b := t[i * 3 + 1]
			var c := t[i * 3 + 2]
			nrm[i] = (b - a).cross(c - a).normalized()
			for cx in range(floori(minf(a.x, minf(b.x, c.x))), floori(maxf(a.x, maxf(b.x, c.x))) + 1):
				for cz in range(floori(minf(a.z, minf(b.z, c.z))), floori(maxf(a.z, maxf(b.z, c.z))) + 1):
					var k := Vector2i(cx, cz)
					if not grille.has(k):
						grille[k] = PackedInt32Array()
					var l: PackedInt32Array = grille[k]
					l.append(i)
					grille[k] = l

	## Toutes les surfaces traversées par la verticale (x, z) : [y, n.y].
	func colonne(x: float, z: float) -> Array:
		var kq := Vector2i(roundi(x * 25.0), roundi(z * 25.0))
		if _col.has(kq):
			return _col[kq]
		var res: Array = []
		for i: int in grille.get(Vector2i(floori(x), floori(z)), PackedInt32Array()):
			var n := nrm[i]
			if absf(n.y) < 0.02:
				continue
			var a := t[i * 3]
			var b := t[i * 3 + 1]
			var d := t[i * 3 + 2]
			var den := (b.z - d.z) * (a.x - d.x) + (d.x - b.x) * (a.z - d.z)
			if absf(den) < 1e-12:
				continue
			var l1 := ((b.z - d.z) * (x - d.x) + (d.x - b.x) * (z - d.z)) / den
			var l2 := ((d.z - a.z) * (x - d.x) + (a.x - d.x) * (z - d.z)) / den
			var l3 := 1.0 - l1 - l2
			if l1 < -1e-5 or l2 < -1e-5 or l3 < -1e-5:
				continue
			res.append(Vector2(l1 * a.y + l2 * b.y + l3 * d.y, n.y))
		_col[kq] = res
		return res

	func sol_sous(x: float, z: float, y_max: float) -> float:
		var best := -1e9
		for e: Vector2 in colonne(x, z):
			if e.y > 0.2 and e.x <= y_max and e.x > best:
				best = e.x
		return best

	## Premier triangle touché : {"t", "n" (normale visible), "avant" (vrai si on arrive par le côté visible)} ou {}.
	func rayon(o: Vector3, d: Vector3, lmax: float) -> Dictionary:
		if d.length_squared() < 1e-12:
			return {}
		d = d.normalized()
		var best := lmax
		var bi := -1
		var vus := {}
		# parcours des cases (DDA 2D sur x, z)
		var cx := floori(o.x)
		var cz := floori(o.z)
		var sx := 1 if d.x > 0.0 else -1
		var sz := 1 if d.z > 0.0 else -1
		var tdx := absf(1.0 / d.x) if absf(d.x) > 1e-9 else 1e30
		var tdz := absf(1.0 / d.z) if absf(d.z) > 1e-9 else 1e30
		var tmx := ((cx + 1 - o.x) if sx > 0 else (o.x - cx)) * tdx if absf(d.x) > 1e-9 else 1e30
		var tmz := ((cz + 1 - o.z) if sz > 0 else (o.z - cz)) * tdz if absf(d.z) > 1e-9 else 1e30
		var tc := 0.0
		while tc <= best:
			for i: int in grille.get(Vector2i(cx, cz), PackedInt32Array()):
				if vus.has(i):
					continue
				vus[i] = true
				var a := t[i * 3]
				var e1 := t[i * 3 + 1] - a
				var e2 := t[i * 3 + 2] - a
				var pv := d.cross(e2)
				var det := e1.dot(pv)
				if absf(det) < 1e-12:
					continue
				var inv := 1.0 / det
				var tv := o - a
				var u := tv.dot(pv) * inv
				if u < 0.0 or u > 1.0:
					continue
				var qv := tv.cross(e1)
				var vv := d.dot(qv) * inv
				if vv < 0.0 or u + vv > 1.0:
					continue
				var tt := e2.dot(qv) * inv
				if tt > 1e-4 and tt < best:
					best = tt
					bi = i
			if tmx < tmz:
				tc = tmx
				tmx += tdx
				cx += sx
			else:
				tc = tmz
				tmz += tdz
				cz += sz
			if tc > 1e20:
				break
		if bi < 0:
			return {}
		return {"t": best, "n": nrm[bi], "avant": nrm[bi].dot(d) < 0.0}

	## Dans la roche : la majorité des rayons (10 directions) touchent d'abord une face par l'arrière.
	func dedans_roche(p: Vector3) -> bool:
		var arr := 0
		var av := 0
		for d: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK,
				Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
			var h := rayon(p, d, 60.0)
			if h.is_empty():
				continue
			if h["avant"]:
				av += 1
			else:
				arr += 1
		return arr >= 3 and arr > av

## Repli générique (crypte, extérieurs) : rayons physiques du moteur, repère du nœud `rep`. Les solides des objets eux-mêmes peuvent
## répondre : à n'utiliser que pour un premier tri.
class TerrainPhysique:
	var rep: Node3D
	var esp: PhysicsDirectSpaceState3D

	func _init(rep_: Node3D, esp_: PhysicsDirectSpaceState3D) -> void:
		rep = rep_
		esp = esp_

	func _r(o: Vector3, d: Vector3, lmax: float) -> Dictionary:
		var og := rep.to_global(o)
		var q := PhysicsRayQueryParameters3D.create(og, rep.to_global(o + d.normalized() * lmax))
		q.hit_back_faces = true
		var h := esp.intersect_ray(q)
		if h.is_empty():
			return {}
		var n: Vector3 = rep.global_transform.basis.inverse() * (h["normal"] as Vector3)
		return {"t": og.distance_to(h["position"]), "n": n.normalized(), "avant": n.dot(d) < 0.0}

	func sol_sous(x: float, z: float, y_max: float) -> float:
		var h := _r(Vector3(x, y_max, z), Vector3.DOWN, 40.0)
		return -1e9 if h.is_empty() else y_max - float(h["t"])

	func rayon(o: Vector3, d: Vector3, lmax: float) -> Dictionary:
		return _r(o, d, lmax)

	func dedans_roche(_p: Vector3) -> bool:
		return false
