extends SceneTree
## Test headless des intérieurs enterables de Skarnholt (lot « kit intérieur »), sans fenêtre :
##   godot --headless --path . --script res://outils/test_interieurs.gd -- --nouvelle
## Pour chacune des cinq maisons (halle, sigrun, chasseurs, grima, forge) une capsule de joueur (rayon 0,35, haut 1,8) :
##   1. porte FERMÉE : ne peut pas entrer ;
##   2. porte ouverte : entre par la porte, atteint l'intérieur, reste sur le plancher ;
##   3. ressort par la porte ;
##   4. poussée contre les murs depuis l'intérieur (fond, ouest, est) puis depuis l'extérieur : ne traverse jamais ;
##   5. l'objet « porte » (touche E) existe, l'intérieur n'est visible et éclairé que de près.
## Retours exe 5 (« rentrer dans n'importe quel bâtiment ») : les mêmes épreuves pour CHAQUE bâtiment du village et des abords
## (data/batiments.json : maisons, auberge, grenier, moulins, tour, fermes, granges), plus : aucun bâtiment n'est resté plein,
## l'intérieur se charge à l'approche et se libère au loin, rien ne déborde du bâtiment, le terrain ne perce pas le plancher,
## emplacements de lits (contrat sommeil), metas « proprietaire » / « verrou » et serrure de nuit (contrat crime), portes de Vie.
## `-- --seulement=h1,tour` : ne teste que ces bâtiments (plus rapide).
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _marcheur(pos: Vector3) -> CharacterBody3D:
	var w := CharacterBody3D.new()
	var cap := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	cap.shape = capsule
	cap.position.y = 0.9
	w.add_child(cap)
	root.add_child(w)
	w.global_position = pos
	return w

## Marche en ligne droite vers `cible` (plan horizontal) ; vrai si arrivé à 0,3 m avant `pas` images.
func _aller(w: CharacterBody3D, cible: Vector3, pas := 500, vitesse := 3.5) -> bool:
	for i in pas:
		var d := cible - w.global_position
		d.y = 0.0
		if d.length() < 0.3:
			return true
		d = d.normalized()
		w.velocity.x = d.x * vitesse
		w.velocity.z = d.z * vitesse
		w.velocity.y -= 20.0 / 60.0
		w.move_and_slide()
		if w.is_on_floor():
			w.velocity.y = 0.0
		await physics_frame
	return false

## Pousse dans la direction locale `dir` du bâtiment pendant `pas` images (sans cible).
func _pousser(w: CharacterBody3D, ip: Interieur, dir: Vector3, pas := 200, vitesse := 3.5) -> void:
	var dg := (ip.global_transform.basis * dir).normalized()
	for i in pas:
		w.velocity.x = dg.x * vitesse
		w.velocity.z = dg.z * vitesse
		w.velocity.y -= 20.0 / 60.0
		w.move_and_slide()
		if w.is_on_floor():
			w.velocity.y = 0.0
		await physics_frame

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 8:
		await physics_frame
	var v: Node3D = m.village
	for i in 300:
		if v.prets:
			break
		await physics_frame
	_verif(v.prets, "les intérieurs sont construits après le chargement (une maison par image)")
	m.joueur.set_physics_process(false)    # le joueur reste au point où on le pose (la caméra sert à la fermeture automatique)
	m.cycle.heure = 12.0    # midi : une nouvelle partie commence à 21 h, et à 21 h 30 (rentrée) les civils passent leurs portes (lot sommeil)
	var ids: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/batiments.json"))["batiments"] as Dictionary).keys()
	_verif(v.interieurs.size() == ids.size(), "%d intérieurs enterables, un par bâtiment de data/batiments.json (trouvés : %d)" % [ids.size(), v.interieurs.size()])
	_tester_tous_ouverts(v)
	var seul := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seulement="):
			seul = a.trim_prefix("--seulement=")
	for id in ids:
		if seul != "" and not (id in seul.split(",")):
			continue
		await _tester_maison(v, id)
		if (v.interieur(id) as Interieur).paresseux:
			await _tester_contenu(v, id)
	await _tester_serrures(v)
	if seul == "":
		await _tester_visibilite(v)
		await _tester_pnj(v)
	print("ECHEC total : %d" % _echecs if _echecs > 0 else "TOUT OK")
	quit(1 if _echecs > 0 else 0)

## Point du repère de l'intérieur, en monde, relevé au-dessus du terrain s'il est enterré.
func _sur_sol(v: Node3D, ip: Interieur, l: Vector3) -> Vector3:
	var g := ip.to_global(l)
	return Vector3(g.x, maxf(g.y, v.h_sol(g.x, g.z) + 0.1), g.z)

func _tester_maison(v: Node3D, id: String) -> void:
	var ip: Interieur = v.interieur(id)
	_verif(ip != null, "[%s] intérieur trouvé" % id)
	if ip == null:
		return
	var px := ip.porte_locale.x
	var zp := ip.porte_locale.z - 0.05              # plan de la porte
	var y := ip.sol_y + 0.15
	var dehors := _sur_sol(v, ip, Vector3(px, y, zp + 2.8))      # sur le terrain (grange à rampe : le dehors est plus haut que le plancher)
	var dedans := ip.to_global(Vector3(px, y, zp - 1.5))
	var seuil := ip.to_global(Vector3(px, y, zp + 0.2))
	_verif(ip.interactif != null, "[%s] objet « porte » (touche E) posé : « %s »" % [id, ip.nom])
	_verif(not ip.ouverte, "[%s] porte fermée au départ" % id)

	# la porte se referme toute seule quand le joueur s'éloigne : il faut donc le garder près d'elle
	m.joueur.global_position = ip.to_global(Vector3(px, y, zp + 6.0))
	if ip.paresseux:      # intérieur à la demande : il se construit à l'approche (moins de 24 m)
		for i in 1500:
			if ip.construit:
				break
			await physics_frame
		_verif(ip.construit, "[%s] à 6 m de la porte, l'intérieur à la demande est construit" % id)
	# 1. porte fermée
	var w := _marcheur(dehors)
	for i in 10:
		await physics_frame
	var arrive := await _aller(w, dedans, 260)
	var loc := ip.to_local(w.global_position)
	_verif(not arrive and loc.z > zp - 0.2, "[%s] porte fermée : bloqué dehors (z local %.2f, plan de la porte %.2f)" % [id, loc.z, zp])
	# 2. porte ouverte
	ip.basculer(true, false)
	for i in 50:
		await physics_frame
	w.global_position = dehors
	w.velocity = Vector3.ZERO
	var a1 := await _aller(w, seuil, 300)
	var a2 := await _aller(w, dedans, 300)
	loc = ip.to_local(w.global_position)
	_verif(a1 and a2, "[%s] porte ouverte : franchit le seuil et atteint l'intérieur (z local %.2f)" % [id, loc.z])
	_verif(ip.dedans(loc), "[%s] la capsule est bien DANS l'emprise (x %.2f, z %.2f)" % [id, loc.x, loc.z])
	_verif(absf(loc.y - ip.sol_y) < 0.2, "[%s] debout sur le plancher (y local %.2f, sol %.2f)" % [id, loc.y, ip.sol_y])
	# 3. ressort
	var r1 := await _aller(w, seuil, 300)
	var r2 := await _aller(w, dehors, 300)
	loc = ip.to_local(w.global_position)
	# (le point de départ du dehors peut tomber dans un étal ou un banc de la rue : on demande d'avoir franchi la porte vers le dehors)
	_verif(r1 and (r2 or loc.z > zp + 0.8) and not ip.dedans(loc), "[%s] ressort par la porte (z local %.2f)" % [id, loc.z])
	# 4. murs depuis l'intérieur : fond (-Z), ouest (-X) puis est (+X), sans traverser
	var limites := Vector2(ip.demi.x + 0.35, ip.demi.y + 0.35)
	for dir in [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		w.global_position = ip.to_global(Vector3(px * 0.5, y, zp - 1.5))
		w.velocity = Vector3.ZERO
		await _pousser(w, ip, dir, 240)
		loc = ip.to_local(w.global_position)
		_verif(absf(loc.x) < limites.x + 0.15 and loc.z > -limites.y - 0.15 and loc.z < zp + 0.2, "[%s] poussée vers %s depuis l'intérieur : reste dedans (x %.2f, z %.2f)" % [id, dir, loc.x, loc.z])
	# murs depuis l'extérieur : on pousse vers le centre depuis chaque côté
	for dep in [Vector3(ip.demi.x + 2.0, y, -0.4), Vector3(-ip.demi.x - 2.0, y, -0.4), Vector3(-0.4, y, -ip.demi.y - 2.0)]:
		w.global_position = _sur_sol(v, ip, dep)
		w.velocity = Vector3.ZERO
		for i in 6:
			await physics_frame
		var vers := Vector3(-dep.x, 0, -dep.z).normalized() if absf(dep.z) < 1.0 else Vector3(0, 0, -dep.z).normalized()
		await _pousser(w, ip, vers, 240)
		loc = ip.to_local(w.global_position)
		_verif(not ip.dedans(loc, -0.1), "[%s] poussée vers l'intérieur depuis %s : reste dehors (x %.2f, z %.2f)" % [id, dep, loc.x, loc.z])
	w.queue_free()
	# fermeture automatique : le joueur s'éloigne à 30 m, la porte se referme et se bloque de nouveau
	ip.basculer(true, false)
	m.joueur.global_position = ip.to_global(Vector3(px, y, zp + 30.0))
	for i in 60:
		await physics_frame
	_verif(not ip.ouverte and not ip.bloc_porte.disabled, "[%s] à 30 m, la porte se referme et bloque de nouveau" % id)

func _tester_visibilite(v: Node3D) -> void:
	var ip: Interieur = v.interieur("halle")
	var j: CharacterBody3D = m.joueur
	j.set_physics_process(false)
	# dedans : visible et éclairé
	j.global_position = ip.to_global(Vector3(0, ip.sol_y + 0.2, 1.0))
	for i in 40:
		await process_frame
	var visibles := 0
	for l in ip.lumieres:
		if (l[0] as OmniLight3D).visible and (l[0] as OmniLight3D).is_visible_in_tree():
			visibles += 1
	_verif(ip.racine.visible and visibles == ip.lumieres.size() and visibles > 0, "halle : dedans, l'intérieur est visible et ses %d lumières sont allumées" % ip.lumieres.size())
	# loin : tout éteint
	j.global_position = ip.to_global(Vector3(0, 0.2, 60.0))
	for i in 40:
		await process_frame
	visibles = 0
	for l in ip.lumieres:
		if (l[0] as OmniLight3D).is_visible_in_tree():
			visibles += 1
	_verif(not ip.racine.visible and visibles == 0, "halle : à 50 m, l'intérieur est masqué et toutes les lumières éteintes (%d allumées)" % visibles)
	# à 12 m : visible mais lumières éteintes (> 8 m de l'emprise)
	j.global_position = ip.to_global(Vector3(0, 0.2, ip.demi.y + 11.0))
	for i in 40:
		await process_frame
	visibles = 0
	for l in ip.lumieres:
		if (l[0] as OmniLight3D).is_visible_in_tree():
			visibles += 1
	_verif(ip.racine.visible and visibles == 0, "halle : à 11 m, l'intérieur est visible (par les fenêtres) mais sans lumière locale (%d)" % visibles)
	# à 5 m : lumières allumées
	j.global_position = ip.to_global(Vector3(0, 0.2, ip.demi.y + 5.0))
	for i in 40:
		await process_frame
	visibles = 0
	for l in ip.lumieres:
		if (l[0] as OmniLight3D).is_visible_in_tree():
			visibles += 1
	_verif(visibles == ip.lumieres.size(), "halle : à 5 m, les %d lumières sont allumées" % visibles)
	# budget : au plus 8 lumières locales par bâtiment
	for ip2: Interieur in v.interieurs:
		var n := ip2.lumieres.size()
		_verif(n <= 8, "[%s] %d lumières locales (≤ 8, limite du renderer mobile)" % [ip2.id, n])

## Le forgeron vit dans sa forge : il y reste (jamais coincé dans un mur, ni sous le sol) ; les autres villageois
## ne sont dans aucun bâtiment.
func _tester_pnj(v: Node3D) -> void:
	m.cycle.heure = 12.0    # lot vie_pnj : la nuit le forgeron dort (caché) devant sa porte ; le test vise sa place de jour, dans la forge
	for i in 240:
		await physics_frame
	var forge: Interieur = v.interieur("forge")
	var n := 0
	for p in get_nodes_in_group("villageois"):
		var id: String = p.donnees.get("id", "")
		for ip in v.interieurs:
			var loc: Vector3 = ip.to_local(p.global_position)
			var dans: bool = ip.dedans(loc, 0.3) and loc.y < 3.0
			if id == "forgeron" and ip == forge:
				_verif(ip.dedans(loc, 0.0) and loc.y > -0.1 and loc.y < 0.6, "forgeron dans la forge, sur le sol (x %.2f, y %.2f, z %.2f)" % [loc.x, loc.y, loc.z])
				n += 1
			elif dans:
				_verif(false, "%s est dans « %s » (x %.2f, z %.2f)" % [id, ip.nom, loc.x, loc.z])
	_verif(n == 1, "le forgeron a été trouvé")

# ===================================================================================================== bâtiments ouverts (retours exe 5)

## Aucun bâtiment du bâti (façades, fermes, granges, tour, moulins) n'est resté plein : chacun porte un intérieur.
func _tester_tous_ouverts(v: Node3D) -> void:
	var pleins: Array = []
	var n := 0
	for c in v.get_children():
		var nom := String(c.name)
		if nom.begins_with("Bati_") or nom.begins_with("BatiQ_") or nom == "TourClocher" or nom == "MoulinVent":
			n += 1
			if c.get_node_or_null("Interieur") == null:
				pleins.append(nom)
	_verif(n >= 13 and pleins.is_empty(), "les %d bâtiments du bâti v2 ont tous une porte et un intérieur (pleins : %s)" % [n, pleins])
	for ip: Interieur in v.interieurs:
		_verif(ip.id != "" and ip.proprietaire != "" and ip.has_meta("proprietaire") and ip.racine.has_meta("proprietaire"),
			"[%s] foyer « %s » (meta proprietaire de l'intérieur et de son contenu)" % [ip.id, ip.proprietaire])

## Contenu à la demande : rien ne sort du bâtiment, le terrain ne perce pas le plancher, lits = données, puis libéré au loin.
func _tester_contenu(v: Node3D, id: String) -> void:
	var ip: Interieur = v.interieur(id)
	m.joueur.global_position = ip.to_global(Vector3(ip.porte_locale.x, ip.sol_y + 0.1, ip.porte_locale.z + 5.0))
	for i in 400:
		if ip.construit:
			break
		await physics_frame
	var demi := ip.demi / 0.78 if id == "moulin_vent" else ip.demi      # moulin à vent : pièce ronde (demi = carré inscrit)
	var marge := Vector2(demi.x + BatimentsOuverts.EP_DOUBLURE + 0.3, demi.y + BatimentsOuverts.EP_DOUBLURE + 0.3)      # embrasures et dos des meubles compris (dans l'épaisseur du mur)
	var haut_max: float = ip.get_meta("haut_max", 99.0)
	var hors := ""
	var inv := ip.global_transform.affine_inverse()
	for mi in ip.racine.find_children("*", "GeometryInstance3D", true, false):
		if mi.name in ["Halos", "Rais", "Flammes"] or not (mi is MeshInstance3D):
			continue
		var xf: Transform3D = inv * (mi as Node3D).global_transform
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			for q0: Vector3 in (mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var q: Vector3 = xf * q0
				if absf(q.x) > marge.x or absf(q.z) > marge.y + (0.25 if q.z > 0.0 else 0.0) or q.y < Interieurs.F - 0.45 or q.y > haut_max:
					hors = "matière %s, sommet (%.2f, %.2f, %.2f)" % [v.mats_int.find_key((mi as MeshInstance3D).material_override), q.x, q.y, q.z]
					break
			if hors != "":
				break
		if hors != "":
			break
	_verif(hors == "", "[%s] rien ne déborde du bâtiment (demi %.2f × %.2f, haut %.2f) %s" % [id, marge.x, marge.y, haut_max, hors])
	# terrain : sous le plancher partout dans la pièce
	var perce := 0
	var pire := -9.0
	for gx in 7:
		for gz in 7:
			var l := Vector3(lerpf(-ip.demi.x, ip.demi.x, gx / 6.0), Interieurs.F, lerpf(-ip.demi.y, ip.demi.y, gz / 6.0))
			var g := ip.to_global(l)
			var h: float = v.h_sol(g.x, g.z)
			pire = maxf(pire, h - g.y)
			if h > g.y - 0.02:
				perce += 1
	_verif(perce == 0, "[%s] le terrain reste sous le plancher (%d points percent, pire %.2f m)" % [id, perce, pire])
	# lits : un emplacement par lit des données, metas du contrat
	var lits: Array = BatimentsOuverts.donnees(id).get("lits", [])
	var mk: Array = ip.racine.find_children("*", "Marker3D", true, false).filter(func(n: Node) -> bool: return n.is_in_group("emplacement_lit"))
	var metas := true
	var poses := {}
	for k in mk:
		metas = metas and k.has_meta("proprietaire") and k.has_meta("largeur") and ip.dedans(ip.to_local((k as Node3D).global_position), 0.05)
		poses[String(k.get_meta("proprietaire", ""))] = true
	var manque: Array = []
	for l: Dictionary in lits:
		if String(l["proprietaire"]) != "" and not poses.has(String(l["proprietaire"])):
			manque.append(l["proprietaire"])
	_verif(manque.is_empty() and mk.size() <= lits.size() and metas, "[%s] %d emplacements de lit sur %d prévus (chaque habitant a le sien, manque : %s), metas proprietaire / largeur, dans la pièce" % [id, mk.size(), lits.size(), manque])
	# au loin : libéré (lumières, collisions du mobilier comprises)
	var nb_coll := ip.collisions.size()
	m.joueur.global_position = ip.to_global(Vector3(0, ip.sol_y, ip.demi.y + 60.0))
	for i in 30:
		await physics_frame
	_verif(not ip.construit and ip.racine.get_child_count() == 0 and ip.lumieres.is_empty() and ip.collisions.is_empty(),
		"[%s] à 60 m, l'intérieur est libéré (%d collisions de mobilier rendues)" % [id, nb_coll])

## Serrures (contrat « crime ») : ouvertes le jour, fermées la nuit quand le foyer est rentré ; sans agent « crime », une porte
## fermée à clé reste close (message) ; Vie connaît la porte de chaque maison habitée.
func _tester_serrures(v: Node3D) -> void:
	var cyc = m.cycle
	var garde_h: float = cyc.heure
	cyc.heure = 12.0
	var jour_ok := true
	for ip: Interieur in v.interieurs:
		var attendu := ip.difficulte if ip.regle_verrou == "toujours" else 0
		jour_ok = jour_ok and ip.verrou_actuel() == attendu
	_verif(jour_ok, "midi : toutes les portes sont ouvertes (sauf « toujours » : grenier de la halle)")
	cyc.heure = 23.5
	var nuit := 0
	var ouvertes: Array = []
	for ip: Interieur in v.interieurs:
		ip._maj_verrou()
		if ip.regle_verrou != "jamais" and ip.difficulte > 0:
			if ip.verrou_actuel() == ip.difficulte and int(ip.get_meta("verrou")) == ip.difficulte:
				nuit += 1
			else:
				ouvertes.append(ip.id)
	_verif(ouvertes.is_empty() and nuit > 10, "23 h 30 : %d portes fermées à clé (difficulté en meta « verrou »), ouvertes à tort : %s" % [nuit, ouvertes])
	var ip_h: Interieur = v.interieur("h1")
	ip_h.basculer(false, false)
	var lignes: Array = ip_h.interactif.action.call()
	_verif(lignes.is_empty() and not ip_h.ouverte and ip_h.interactif.is_in_group("portes") and ip_h.interactif.get_meta("interieur") == ip_h,
		"porte fermée à clé sans agent « crime » : elle reste close (message), objet porte du groupe « portes »")
	ip_h.deverrouiller(true)
	_verif(ip_h.ouverte and ip_h.verrou_actuel() == 0, "deverrouiller() (crochetage réussi) : la porte s'ouvre")
	ip_h.basculer(false, false)
	ip_h.deverrouille = false
	cyc.heure = garde_h
	var vie: Node = m.get_node_or_null("Vie")
	if vie != null:
		var manque: Array = []
		for ip: Interieur in v.interieurs:
			for pid in ip.habitants:
				if not vie._portes.has(ip.id) or String(EmploiDuTemps.fiche(String(pid)).get("maison", "")) != ip.id:
					manque.append("%s/%s" % [ip.id, pid])
		_verif(manque.is_empty(), "Vie : chaque habitant a sa maison au planning et la porte est connue (manque : %s)" % [manque])
		# contrat sommeil : chaque civil du planning (et la cheffe) a un lit à son nom dans les données d'un bâtiment
		var a_lit := {}
		for idb in (JSON.parse_string(FileAccess.get_file_as_string("res://data/batiments.json"))["batiments"] as Dictionary).keys():
			var db: Dictionary = BatimentsOuverts.donnees(idb)
			for l in db.get("lits", []):
				a_lit[String(l["proprietaire"])] = idb
			for o in db.get("lits_existants", []):
				a_lit[String(o)] = idb
		var sans: Array = []
		for c: Dictionary in vie.civils:
			if not a_lit.has(String(c["id"])):
				sans.append(c["id"])
		_verif(sans.is_empty() and vie.civils.size() == 17, "les %d civils ont chacun un lit à leur nom (sans lit : %s)" % [vie.civils.size(), sans])
