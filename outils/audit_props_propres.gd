extends SceneTree
## AUDIT AUTOMATIQUE des ensembles extérieurs (compositions des abords, v5 village) : flottants, enfoncés, jours entre pièces, interpénétrations,
## isolés. Lit AbordsProps.registre (rempli par _poser) dans le vrai monde (headless possible).
##   godot --headless --path . --script res://outils/audit_props_propres.gd -- --nouvelle --paisible [--json=<fichier>]
## Mesures par item (boîte alignée de la pièce posée, donc approchée pour les pièces tournées) :
##   FLOTTANT  : dessous > 0,15 m au-dessus du sol sous l'emprise ET non posé sur une autre pièce (dessus à 0,12 m près et recouvrement en plan)
##   ENFONCE   : sol le plus haut de l'emprise > 0,30 m au-dessus du dessous (hors piquets : hauteur > 1,2 m)
##   JOUR      : deux pièces de bois / pierre structurelles dont les boîtes sont séparées de 3 à 25 cm (poutres qui ne se touchent pas)
##   INTERPEN  : recouvrement > 55 % du volume de la plus petite boîte, sans posé-dessus (pièces qui se traversent)
##   ISOLE     : pièce à plus de 2,5 m de toute autre de sa composition
const SCENE := preload("res://scenes/foret_test.tscn")
const STRUCT := ["q_poutre_ronde", "q_rondin", "q_tronc", "q_bordure_1"]      # pièces de charpente / tas (les bûches isolées et les planches de signalisation sont volontairement espacées)
const MEUBLES := ["pq_rack_armes", "pq_table_petite_2", "pq_grande_table", "pq_etabli", "pq_tabouret", "pq_banc"]      # objets posés dessus / dessous : recouvrement normal

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _aabb(id: String, xf: Transform3D) -> AABB:
	var bb := PropsQuaternius.boite(id)
	var r := AABB(xf * bb.position, Vector3.ZERO)
	for cx: float in [bb.position.x, bb.end.x]:
		for cy: float in [bb.position.y, bb.end.y]:
			for cz: float in [bb.position.z, bb.end.z]:
				r = r.expand(xf * Vector3(cx, cy, cz))
	return r

func _go() -> void:
	var s: Node3D = SCENE.instantiate()
	root.add_child(s)
	current_scene = s
	for i in 3000:
		await process_frame
		if s.village != null and s.village.get("prets") == true and s.has_node("AbordsProps"):
			break
	for i in 30:
		await process_frame
	for id in _arg("boites", "").split(",", false):
		var bb := PropsQuaternius.boite(id)
		print("BOITE %s pos %s taille %s" % [id, bb.position, bb.size])
	var par_lieu := {}
	for e: Array in AbordsProps.registre:
		if not par_lieu.has(e[0]):
			par_lieu[e[0]] = []
		par_lieu[e[0]].append(e)
	var total := {"FLOTTANT": 0, "ENFONCE": 0, "JOUR": 0, "INTERPEN": 0, "ISOLE": 0, "PENCHE": 0}
	var rapport := {}
	for lieu: String in par_lieu:
		var items: Array = par_lieu[lieu]
		var boxes: Array = []
		for e: Array in items:
			boxes.append(_aabb(e[1], e[2]))
		var lignes: Array = []
		for i in items.size():
			var e: Array = items[i]
			var b: AABB = boxes[i]
			var bas := b.position.y
			var porte := false
			for j in items.size():
				if j == i:
					continue
				var o: AABB = boxes[j]
				var recouvre := b.position.x < o.end.x and b.end.x > o.position.x and b.position.z < o.end.z and b.end.z > o.position.z
				if recouvre and absf(bas - o.end.y) < 0.12:
					porte = true
				if recouvre and absf(b.end.y - o.position.y) < 0.12:
					porte = true      # pendu sous une traverse
				if recouvre and bas > o.position.y and bas < o.end.y and o.get_volume() > b.get_volume():
					porte = true      # cloué / posé contre une pièce plus grosse (planche au poteau, lanterne)
			if e[1] == "q_poutre_ronde" or e[1] == "q_tronc":
				var ax: Vector3 = ((e[2] as Transform3D).basis.x if e[1] == "q_poutre_ronde" else (e[2] as Transform3D).basis.z).normalized()
				var ang := rad_to_deg(acos(clampf(absf(ax.y), 0.0, 1.0)))      # 0 = debout, 90 = couché
				if (ang > 3.0 and ang < 87.0) and e[1] == "q_poutre_ronde":
					lignes.append("PENCHE %s à %.0f° de la verticale" % [e[1], ang])
			var hsol: float = e[5]
			if bas - hsol > 0.15 and not porte and float(e[3]) < 0.05:
				lignes.append("FLOTTANT %s dessous %.2f m au-dessus du sol" % [e[1], bas - hsol])
			elif float(e[3]) >= 0.05 and not porte and bas - s.hauteur(b.get_center().x, b.get_center().z) > 0.2:
				lignes.append("FLOTTANT %s (posé en hauteur, rien dessous) à %.2f m" % [e[1], bas - s.hauteur(b.get_center().x, b.get_center().z)])
			if b.size.y < 1.2 and float(e[3]) < 0.05 and float(e[6]) - bas > 0.30:
				lignes.append("ENFONCE %s sol %.2f m au-dessus du dessous" % [e[1], float(e[6]) - bas])
			var dmin := INF
			for j in items.size():
				if j == i:
					continue
				var o: AABB = boxes[j]
				var gx := maxf(maxf(o.position.x - b.end.x, b.position.x - o.end.x), 0.0)
				var gy := maxf(maxf(o.position.y - b.end.y, b.position.y - o.end.y), 0.0)
				var gz := maxf(maxf(o.position.z - b.end.z, b.position.z - o.end.z), 0.0)
				var g := Vector3(gx, gy, gz).length()
				dmin = minf(dmin, g)
				if j > i and e[1] in STRUCT and items[j][1] in STRUCT and g > 0.03 and g < 0.25:
					lignes.append("JOUR %s / %s écart %.0f cm" % [e[1], items[j][1], g * 100.0])
				var inter := b.intersection(o)
				if j > i and inter.has_volume():
					var vmin := minf(b.get_volume(), o.get_volume())
					var seuil := 0.85 if (e[1] in STRUCT and items[j][1] in STRUCT) else 0.55      # boîtes alignées : deux rondins en lacet se recouvrent à tort
					var exclu: bool = e[1] in MEUBLES or items[j][1] in MEUBLES or float(e[3]) > 0.05 or float(items[j][3]) > 0.05
					if vmin > 0.001 and inter.get_volume() / vmin > seuil and not porte and not exclu:
						lignes.append("INTERPEN %s / %s %.0f %%" % [e[1], items[j][1], 100.0 * inter.get_volume() / vmin])
			if items.size() > 1 and dmin > 2.5:
				lignes.append("ISOLE %s à %.1f m des autres" % [e[1], dmin])
		for l: String in lignes:
			total[l.split(" ")[0]] += 1
		rapport[lieu] = lignes
		print("== %s (%d pièces, %d anomalies)" % [lieu, items.size(), lignes.size()])
		for l: String in lignes:
			print("   ", l)
	print("TOTAL ", total)
	var f := _arg("json", "")
	if f != "":
		var fa := FileAccess.open(f, FileAccess.WRITE)
		fa.store_string(JSON.stringify({"total": total, "lieux": rapport}, "  "))
	quit(0)
