extends SceneTree
## GARDE / BLOCAGE DE TOUTES LES ARMES (branche combat/gardes_toutes_armes, brief_coups_garde_2026-11-26.md) : mesure
## automatique, image par image à 60 i/s, en vue 1re personne (bras du viewmodel) ET 3e personne (corps du joueur), de la garde
## tenue, de l'entrée en garde, d'un coup bloqué (encaisse) et de la sortie, pour CHAQUE arme :
##   épée, sabre, dague, épée longue, claymore, hybride à deux mains, haches (guerre, hachette, Kolbeinn), masses (cloutée,
##   gourdin), marteau de guerre, grand marteau.
##   godot --headless --path . --fixed-fps 60 --script res://outils/test_gardes_armes.gd -- --nouvelle [--csv=<dossier>]
##         [--armes=epee_metal,hache_guerre] [--vues=1p,3p] [--etiquette=avant|apres] [--sans-verdict]
## Mesures (os APRÈS modificateurs : BoneAttachment3D sur lowerarm / hand / index_01 / pinky_01) :
##   flex / dev   : flexion (+ extension) et déviation (+ radiale) du poignet droit (et gauche pour les armes à deux mains), même
##                  calcul que mesures_coups_v5 (axe avant-bras, axe main = poignet -> milieu index-auriculaire) ;
##   saut         : plus grande variation du poignet d'une image à l'autre (°) ;
##   arme/avbras  : angle entre l'axe de l'arme (garde -> pointe, ou manche -> tête) et l'avant-bras droit (°) ;
##   incl         : inclinaison de l'arme par rapport à la VERTICALE dans le plan de l'écran (1P : repère caméra ; 3P : plan
##                  frontal du personnage), pointe / tête vers le haut ; 0° = verticale, 90° = horizontale ;
##   avbras_v     : angle de l'avant-bras droit à la verticale dans le même plan ;
##   ecran        : (1P) part de l'écran couverte par la boîte englobante projetée du bras droit + arme (borne haute).
## Critères (brief) en garde tenue : |dev| <= 25, |flex| <= 60 (poignet NEUTRE : |dev| <= 25 et |flex| <= 35 visés), saut <= 12,
## 70 <= arme/avbras <= 110, 30 <= incl <= 60, jamais (avbras_v < 20 et incl > 70) (« avant-bras vertical + poignet à
## l'horizontale »), écran <= 35 %. Entrée / encaisse / sortie : poignet dans les butées, saut <= 12.
const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0
const ARMES := ["epee_metal", "epee_soldat", "sabre_pillard", "dague_acier", "veilleuse", "claymore", "coeur_de_braise",
	"hache_guerre", "hachette", "hache_kolbeinn", "masse_cloutee", "gourdin", "marteau_guerre", "grand_marteau"]

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var corps: Node3D
var _ok := true
var _att := {}
var _csv := ""
var _lignes: Array[String] = []
var _etiq := "x"
var _verdict := true

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond and _verdict:
		_ok = false

func _images(n: int) -> void:
	for i in n:
		j.vigueur = j.vigueur_max
		mains.avancer(DT)
		await process_frame

func _squelette(vue: String) -> Skeleton3D:
	if vue == "1p":
		return mains._sq
	return corps.modele.find_child("Skeleton3D", true, false)

func _attaches(vue: String) -> void:
	for b in _att.values():
		if is_instance_valid(b):
			b.queue_free()
	_att.clear()
	var sq := _squelette(vue)
	for c in ["l", "r"]:
		for o in ["upperarm", "lowerarm", "hand", "index_01", "pinky_01"]:
			var b := BoneAttachment3D.new()
			b.bone_name = "%s_%s" % [o, c]
			sq.add_child(b)
			_att["%s_%s" % [o, c]] = b

func _p(n: String) -> Vector3:
	return (_att[n] as Node3D).global_position

## [flexion, déviation] (degrés) du poignet `c`.
func _poignet(c: String) -> Vector2:
	var coude := _p("lowerarm_" + c)
	var p := _p("hand_" + c)
	var ix := _p("index_01_" + c)
	var au := _p("pinky_01_" + c)
	var a := (p - coude).normalized()
	var h := ((ix + au) * 0.5 - p).normalized()
	var x := ix - au
	var e2 := (x - a * x.dot(a)).normalized()
	var e3 := a.cross(e2) if c == "r" else e2.cross(a)
	return Vector2(rad_to_deg(atan2(h.dot(e3), h.dot(a))), rad_to_deg(atan2(h.dot(e2), h.dot(a))))

## Modèle de l'arme tenue dans la vue, et ses extrémités (repère du modèle) garde -> pointe.
func _arme(vue: String) -> Array:
	var m: Node3D = mains._modele_arme_d if vue == "1p" else corps.coups_tps.modele_arme()
	if m == null and vue == "3p":
		m = corps.arme_corps
	return [m, mains._garde_lame, mains._pointe_lame]

## Repère de mesure : 1P = caméra (mains), 3P = personnage (x droite, y haut, -z avant).
func _repere(vue: String) -> Transform3D:
	if vue == "1p":
		return mains.global_transform
	return j.global_transform

func _incl(v: Vector3) -> float:
	# angle à la verticale dans le plan XY du repère, pointe vers le haut (une arme qui pend : > 90)
	var a := Vector2(v.x, v.y)
	if a.length() < 1e-4:
		return 90.0
	return rad_to_deg(atan2(absf(a.x), a.y))

func _ecran(p_global: Vector3) -> Vector2:
	var p := mains.global_transform.affine_inverse() * p_global
	var z := maxf(-p.z, 0.05)
	return Vector2(p.x / z / ProfilsAnimation.TAN_H, p.y / z / ProfilsAnimation.TAN_V)

func _echantillon(vue: String) -> Dictionary:
	var R := _repere(vue)
	var Ri := R.affine_inverse()
	var wd := _poignet("r")
	var wg := _poignet("l")
	var fa := (Ri.basis * (_p("hand_r") - _p("lowerarm_r"))).normalized()
	var ar: Array = _arme(vue)
	var m: Node3D = ar[0]
	var ax := Vector3.UP
	var pts: Array[Vector3] = [_p("lowerarm_r"), _p("hand_r")]
	if m != null and is_instance_valid(m):
		var g: Vector3 = m.global_transform * (ar[1] as Vector3)
		var pt: Vector3 = m.global_transform * (ar[2] as Vector3)
		ax = (Ri.basis * (pt - g)).normalized()
		for i in 6:
			pts.append(g.lerp(pt, float(i) / 5.0))
	var d := {"wd": wd, "wg": wg, "fa_ar": rad_to_deg(fa.angle_to(ax)), "incl": _incl(ax), "fa_v": _incl(fa), "ax": ax, "fa": fa,
		"clip": String(mains.anim.reel(mains.anim.clip)), "etat": int(mains.combat.etat), "ecran": 0.0}
	if vue == "1p":
		d["mg_ecran"] = _ecran(_p("hand_l"))
		var mn := Vector2(1, 1)
		var mx := Vector2(-1, -1)
		for p in pts:
			var e := _ecran(p)
			mn = mn.min(e.clamp(Vector2(-1, -1), Vector2(1, 1)))
			mx = mx.max(e.clamp(Vector2(-1, -1), Vector2(1, 1)))
		d["ecran"] = maxf(0.0, (mx.x - mn.x) * (mx.y - mn.y)) / 4.0
	if vue == "3p":
		d["poignet_tps"] = corps.coups_tps.poignet_deg
		d["biais"] = corps.coups_tps.biais_deg
		d["w"] = corps.coups_tps._garde_w * corps.coups_tps._poids
	return d

func _remettre() -> void:
	mains.entrees.forcer_garde(0.0)
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	await _images(40)

## Une phase : `n` images, échantillons rangés sous `phase`.
func _phase(vue: String, phase: String, n: int, garde: bool, ech: Array, avant := Callable()) -> void:
	for i in n:
		if garde:
			mains.entrees.forcer_garde(0.2)
		if avant.is_valid() and i == 0:
			avant.call()
		j.vigueur = j.vigueur_max
		mains.avancer(DT)
		await process_frame
		var e := _echantillon(vue)
		e["phase"] = phase
		e["i"] = i
		ech.append(e)

func _mesurer_arme(id: String, vue: String) -> void:
	await _remettre()
	var ech: Array = []
	await _phase(vue, "repos", 10, false, ech)
	await _phase(vue, "entree", 24, true, ech)
	await _phase(vue, "tenue", 30, true, ech)
	var origine := j.global_position + (-j.global_transform.basis.z) * 2.0
	await _phase(vue, "encaisse", 30, true, ech, func(): mains.defendre(10.0, origine, true))
	await _phase(vue, "sortie", 30, false, ech)
	# parade parfaite : garde levée juste avant l'impact, depuis le repos
	await _remettre()
	await _phase(vue, "parade", 2, true, ech)
	await _phase(vue, "parade", 30, true, ech, func(): mains.defendre(10.0, origine))
	_analyser(id, vue, ech)

func _analyser(id: String, vue: String, ech: Array) -> void:
	var deux: bool = mains.arme.deux_mains
	var stats := {}
	for ph in ["repos", "entree", "tenue", "encaisse", "sortie", "parade"]:
		stats[ph] = {"flex": 0.0, "dev": 0.0, "flex_g": 0.0, "dev_g": 0.0, "saut": 0.0, "fa_min": 999.0, "fa_max": 0.0, "incl_min": 999.0,
			"incl_max": 0.0, "vert_horiz": 0, "ecran": 0.0, "clips": {}, "saut_arme": 0.0, "mg_hors": 0}
	var prec: Dictionary = {}
	for e: Dictionary in ech:
		var st: Dictionary = stats[e["phase"]]
		var wd: Vector2 = e["wd"]
		var wg: Vector2 = e["wg"]
		st["flex"] = maxf(st["flex"], absf(wd.x))
		st["dev"] = maxf(st["dev"], absf(wd.y))
		if deux:
			st["flex_g"] = maxf(st["flex_g"], absf(wg.x))
			st["dev_g"] = maxf(st["dev_g"], absf(wg.y))
		if not prec.is_empty() and not (e["phase"] == "parade" and prec["phase"] != "parade"):   # _remettre entre les deux : pas d'image commune
			var dw: Vector2 = wd - (prec["wd"] as Vector2)
			st["saut"] = maxf(st["saut"], maxf(absf(dw.x), absf(dw.y)))
			st["saut_arme"] = maxf(st["saut_arme"], rad_to_deg((e["ax"] as Vector3).angle_to(prec["ax"])))
		if e.has("mg_ecran") and deux and e["phase"] == "tenue":
			var m: Vector2 = e["mg_ecran"]
			if absf(m.x) > 0.95 or m.y < -0.95:
				st["mg_hors"] += 1
		prec = e
		st["fa_min"] = minf(st["fa_min"], e["fa_ar"])
		st["fa_max"] = maxf(st["fa_max"], e["fa_ar"])
		st["incl_min"] = minf(st["incl_min"], e["incl"])
		st["incl_max"] = maxf(st["incl_max"], e["incl"])
		if float(e["fa_v"]) < 20.0 and float(e["incl"]) > 70.0:
			st["vert_horiz"] += 1
		st["ecran"] = maxf(st["ecran"], e["ecran"])
		(st["clips"] as Dictionary)[e["clip"]] = true
		_lignes.append("%s,%s,%s,%s,%d,%s,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.3f" % [_etiq, id, vue, e["phase"], e["i"], e["clip"], wd.x, wd.y,
			wg.x, wg.y, e["fa_ar"], e["incl"], e["fa_v"], e["ecran"]])
	for ph in ["repos", "entree", "tenue", "encaisse", "sortie", "parade"]:
		var st: Dictionary = stats[ph]
		print("GARDE %s %-15s %s %-8s arme/img %5.1f | " % [_etiq, id, vue, ph, st["saut_arme"]] + "poignet flex %5.1f dev %5.1f%s saut %5.1f | arme/avbras %5.1f-%5.1f | incl %5.1f-%5.1f | vert+horiz %d | ecran %4.1f%% | clips %s" % [
			st["flex"], st["dev"], (" (g flex %5.1f dev %5.1f)" % [st["flex_g"], st["dev_g"]]) if deux else "", st["saut"],
			st["fa_min"], st["fa_max"], st["incl_min"], st["incl_max"], st["vert_horiz"], st["ecran"] * 100.0, str(st["clips"].keys())])
	var t: Dictionary = stats["tenue"]
	var n := "%s %s" % [id, vue]
	if vue == "3p":
		print("GARDE %s %s 3p biais signé (tenue, dernière image) %.1f" % [_etiq, id, float((ech.filter(func(x): return x["phase"] == "tenue")[-1] as Dictionary).get("biais", 0.0))])
	_verif(t["dev"] <= 25.0 and t["flex"] <= 35.0, "%s garde : poignet neutre (flex %.0f <= 35, dev %.0f <= 25)" % [n, t["flex"], t["dev"]])
	if deux:
		_verif(t["dev_g"] <= 25.0 and t["flex_g"] <= 60.0, "%s garde : poignet gauche (flex %.0f <= 60, dev %.0f <= 25)" % [n, t["flex_g"], t["dev_g"]])
	_verif(t["fa_min"] >= 70.0 and t["fa_max"] <= 110.0, "%s garde : arme / avant-bras %.0f-%.0f dans 70-110" % [n, t["fa_min"], t["fa_max"]])
	_verif(t["incl_min"] >= 30.0 and t["incl_max"] <= 60.0, "%s garde : arme de biais %.0f-%.0f° de la verticale (30-60)" % [n, t["incl_min"], t["incl_max"]])
	var vh := 0
	var saut := 0.0
	for ph in stats:
		vh += int(stats[ph]["vert_horiz"])
		if ph != "repos":
			saut = maxf(saut, stats[ph]["saut"])
	_verif(vh == 0 or int(stats["repos"]["vert_horiz"]) == vh, "%s : aucune image avant-bras vertical + arme à l'horizontale hors repos (%d)" % [n, vh - int(stats["repos"]["vert_horiz"])])
	var r: Dictionary = stats["repos"]
	var enc: Dictionary = stats["encaisse"]
	_verif(enc["flex"] <= 60.0 and enc["dev"] <= 25.0, "%s coup bloqué : poignet dans les butées (flex %.0f <= 60, dev %.0f <= 25)" % [n, enc["flex"], enc["dev"]])
	_verif(enc["incl_min"] >= 25.0 and enc["incl_max"] <= 65.0, "%s coup bloqué : l'arme reste de biais (%.0f-%.0f°)" % [n, enc["incl_min"], enc["incl_max"]])
	# entrée / sortie : fondu entre le repos validé (inchangé, partagé avec les coups) et la garde : le poignet ne dépasse jamais
	# ses valeurs aux deux bouts (+5°) : pas de cassure en chemin
	for ph in ["entree", "sortie"]:
		var st: Dictionary = stats[ph]
		var bf := maxf(r["flex"], t["flex"]) + 5.0
		var bd := maxf(r["dev"], t["dev"]) + 5.0
		_verif(st["flex"] <= bf and st["dev"] <= bd, "%s %s : poignet entre repos et garde (flex %.0f <= %.0f, dev %.0f <= %.0f)" % [n, ph, st["flex"], bf, st["dev"], bd])
	_verif(saut <= 12.0, "%s : aucun saut de poignet > 12° entre deux images (%.1f)" % [n, saut])
	_verif(stats["parade"]["saut_arme"] <= 15.0, "%s parade parfaite depuis le repos : l'arme tourne de <= 15° par image (%.1f)" % [n, stats["parade"]["saut_arme"]])
	if deux and vue == "1p":
		_verif(t["mg_hors"] == 0, "%s garde : main gauche sur le manche visible à l'écran (%d images hors cadre)" % [n, t["mg_hors"]])
	if vue == "1p":
		_verif(t["ecran"] <= 0.35, "%s garde : <= 35 %% de l'écran (%.0f %%)" % [n, t["ecran"] * 100.0])
	_verif((stats["encaisse"]["clips"] as Dictionary).size() >= 1, "%s : coup bloqué joué (%s)" % [n, str(stats["encaisse"]["clips"].keys())])

func _go() -> void:
	_etiq = _arg("etiquette", "x")
	_csv = _arg("csv", "")
	_verdict = _arg("sans-verdict") == ""
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	RetourImpact.muet = true
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	corps = j.corps
	if s.get("mannequin") != null:
		s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
		s.mannequin.global_position = Vector3(40, 0, 40)
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	var armes: Array = ARMES if _arg("armes") == "" else Array(_arg("armes").split(","))
	var vues: Array = Array(_arg("vues", "1p,3p").split(","))
	for vue in vues:
		j.basculer_vue(vue == "3p")
		await _images(10)
		for id in armes:
			if not CatalogueArmes.connu(id) and not ResourceLoader.exists("res://data/armes/%s.tres" % id):
				print("GARDE arme inconnue ", id)
				continue
			mains.equipement.equiper("droite", CatalogueArmes.donnees(id) if CatalogueArmes.connu(id) else load("res://data/armes/%s.tres" % id))
			await _images(50)
			_attaches(vue)
			await _images(2)
			await _mesurer_arme(id, vue)
	if _csv != "":
		DirAccess.make_dir_recursive_absolute(_csv)
		var f := FileAccess.open(_csv.path_join("gardes_%s.csv" % _etiq), FileAccess.WRITE)
		f.store_line("etiquette,arme,vue,phase,image,clip,flex_d,dev_d,flex_g,dev_g,arme_avbras,incl,avbras_v,ecran")
		for l in _lignes:
			f.store_line(l)
		f.close()
	print("FIN_TEST_GARDES ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
