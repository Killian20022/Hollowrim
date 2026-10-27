extends SceneTree
## Réactivité du combat à l'épée (prompt §6) : pour chaque coup, temps entre l'appui et
##   visuel       première image où la pointe de la lame a bougé de plus de SEUIL_PX pixels (écran 480×270) ;
##   actif        début de la phase active (endurance payée, tracé de lame lancé) ;
##   impact       première touche sur le mannequin à 1,5 m (temps de phase active de l'impact, grille de 1/240 s) ;
##   enchainement premier instant où un appui mémorisé lance le coup suivant (fenêtre de combo ouverte) ;
##   garde        premier instant où le clic droit lève la garde ;
##   fin          retour au repos (Idle) sans nouvel appui.
## Lancement (sans fenêtre, via godot_slot.sh) :
##   godot --headless --path . --script res://outils/mesures_latence.gd -- --nouvelle [--fps=30,60,144] [--appui=0.05] [--armes]
## Lignes LATENCE (une par coup et par fréquence), VITESSE (vitesse de la pointe dans la fenêtre active du clip),
## ARME (cycle du combo, dégâts par seconde et endurance par seconde de chaque épée, --armes).

const SCENE := preload("res://scenes/test_combat.tscn")
## Déplacement de la pointe (pixels de l'écran 480×270) à partir duquel le coup « se voit ».
const SEUIL_PX := 3.0
const GESTES := ["diag_dg", "horizontale_b", "verticale_l", "horizontale_gd", "horizontale", "diag_gd", "estoc"]
const LOURDS := ["lourd", "verticale", "lourd_gd", "lourd_revers"]

var s: Node3D
var j: CharacterBody3D
var mains: Node3D

func _init() -> void:
	_mesurer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _a(nom: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + nom)

func _reset() -> void:
	s.placer_joueur(Vector3(0, 0, s.POS_MANNEQUIN.z + 1.5), 0.0)
	j.vigueur = j.vigueur_max
	j.competences = Competences.new()
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains._depuis_coup = 9.0
	mains.defense = DefenseJoueur.new()
	var mc: CombatEnnemi = s.mannequin.combat
	mc.posture = mc.profil.posture_max
	mc.etourdi = 0.0
	mc.fenetre_parade = 0.0
	# repos stabilisé (fondus finis)
	for i in 40:
		mains.avancer(1.0 / 60.0)
	await physics_frame
	await physics_frame

## Pointe de la lame affichée, en pixels de l'écran 480×270 (repère caméra → écran).
func _pointe_px() -> Vector2:
	var p: Vector3 = mains.transform * (mains.pivot_epee.transform * mains._pointe_lame)
	var e := ProfilsAnimation.vers_ecran(p)
	return Vector2(e.x * 240.0, -e.y * 135.0)

## Un coup mesuré : appui à l'image 0 (le clic est lu au début de l'image, comme _unhandled_input), relâché après `appui` s.
## `lourd` : bouton tenu `appui` s (charge), temps aussi donnés depuis le relâchement.
func _coup(geste: String, fps: int, appui: float, lourd := false, contre := false) -> Dictionary:
	await _reset()
	var dt := 1.0 / float(fps)
	var repos := _pointe_px()
	var r := {"visuel": -1.0, "actif": -1.0, "impact": -1.0, "enchainement": -1.0, "garde": -1.0, "fin": -1.0, "relache": -1.0}
	var n0: int = s.mannequin.coups.size()
	var t_actif := -1.0
	if contre:
		mains.defense.contre = DefenseJoueur.FENETRE_CONTRE
	mains.entrees.appuyer()
	var force := not lourd and not contre
	var t := 0.0
	var tenu := true
	var fen: Array = []
	for k in roundi(2.6 / dt):
		# image k : entrées lues, puis mains.avancer (comme _process)
		if tenu and t >= appui - 1e-9:
			mains.entrees.relacher()
			tenu = false
			r["relache"] = t
		mains.avancer(dt)
		if force and k == 0 and mains._geste_nom != geste:
			# geste imposé (le choix contextuel dépend du déplacement) : même départ que le vrai appui
			mains._geste_nom = geste
			mains._preparer_geste(false)
		if lourd and mains.combat.etat == EtatCombat.CHARGE_LOURDE:
			mains._lourd_nom = geste
		if mains.combat.etat == EtatCombat.RECUPERATION and fen.is_empty():
			fen = mains._geste.get("enchainement", [mains.DELAI_COMBO, 1.0])
		if r["visuel"] < 0.0 and _pointe_px().distance_to(repos) > SEUIL_PX:
			r["visuel"] = t
		if t_actif < 0.0 and mains._actif_lance:
			# la phase active a commencé dans cette image : son instant exact est la fin de la préparation
			t_actif = t + dt - (mains._t_geste - (mains._duree_prep + mains._duree_tenue))
			r["actif"] = t_actif
		if r["impact"] < 0.0 and s.mannequin.coups.size() > n0:
			var info: Dictionary = s.mannequin.coups[n0]["info"]
			r["impact"] = t_actif + float(info.get("instant", 0.0))
		var et: int = mains.combat.etat
		if r["enchainement"] < 0.0 and et == EtatCombat.RECUPERATION and fen.size() == 2 and mains.combat.t >= float(fen[0]) - 1e-9:
			r["enchainement"] = t + dt - (mains.combat.t - float(fen[0]))
		if r["garde"] < 0.0 and et == EtatCombat.RECUPERATION and mains.combat.t > 0.12:
			r["garde"] = t + dt
		if r["fin"] < 0.0 and t_actif >= 0.0 and et == EtatCombat.REPOS:
			r["fin"] = t + dt
			break
		t += dt
	r["geste"] = mains._geste_nom
	r["prep"] = mains._duree_prep + mains._duree_tenue
	return r

func _ms(v: float) -> String:
	return "—" if v < 0.0 else "%d" % roundi(v * 1000.0)

## Vitesse angulaire de la pointe (vue de l'œil, °/s) dans le clip, échantillonnée à 240 Hz : part du pic au début et à la fin
## de la fenêtre active, et fenêtre « rapide » (> 35 % du pic).
func _vitesse(geste: String) -> void:
	var g := ProfilsAnimation.geste(mains.arme.profil, geste)
	var clip := String(g["clip"])
	var m: Dictionary = mains.anim.marqueurs(clip)
	var oeil := mains.transform.affine_inverse() * Vector3.ZERO
	var pas := 1.0 / 240.0
	var vit := []
	var tc := 0.0
	var fin := float(m["fin"])
	var prec: Vector3 = (mains.anim.pose_arme(clip, 0.0) * mains._pointe_lame - oeil).normalized()
	while tc <= fin:
		tc += pas
		var d: Vector3 = (mains.anim.pose_arme(clip, tc) * mains._pointe_lame - oeil).normalized()
		vit.append([tc, rad_to_deg(prec.angle_to(d)) / pas])
		prec = d
	var pic := 0.0
	for v in vit:
		pic = maxf(pic, v[1])
	var a := float(m["frappe"])
	var b := float(m["fin_frappe"])
	var fen: Array = g["fenetre"]
	var da := a + (b - a) * float(fen[0])
	var va := 0.0
	var vb := 0.0
	var r0 := -1.0
	var r1 := -1.0
	for v in vit:
		if absf(v[0] - da) < pas * 0.6:
			va = v[1]
		if absf(v[0] - b) < pas * 0.6:
			vb = v[1]
		if v[1] > pic * 0.35:
			if r0 < 0.0:
				r0 = v[0]
			r1 = v[0]
	print("VITESSE geste=%s clip=%s pic=%d°/s fenetre=[%.3f-%.3f] debut=%d%% fin=%d%% rapide=[%.3f-%.3f]" % [geste, clip, roundi(pic), da, b, roundi(va / pic * 100.0), roundi(vb / pic * 100.0), r0, r1])

func _mesurer() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	var appui := float(_arg("appui", "0.05"))
	var liste_fps := Array(_arg("fps", "30,60,144").split(",")).map(func(x: String) -> int: return int(x))
	for fps in liste_fps:
		for g in GESTES:
			var r := await _coup(g, fps, appui)
			print("LATENCE fps=%d geste=%s appui=%s visuel=%s actif=%s impact=%s enchainement=%s garde=%s fin=%s" % [fps, r["geste"], _ms(appui), _ms(r["visuel"]), _ms(r["actif"]), _ms(r["impact"]), _ms(r["enchainement"]), _ms(r["garde"]), _ms(r["fin"])])
		var rc := await _coup("contre", fps, appui, false, true)
		print("LATENCE fps=%d geste=%s appui=%s visuel=%s actif=%s impact=%s enchainement=%s garde=%s fin=%s" % [fps, rc["geste"], _ms(appui), _ms(rc["visuel"]), _ms(rc["actif"]), _ms(rc["impact"]), _ms(rc["enchainement"]), _ms(rc["garde"]), _ms(rc["fin"])])
		for g in LOURDS:
			var r := await _coup(g, fps, 0.6, true)
			var rel: float = r["relache"]
			print("LATENCE fps=%d geste=%s appui=600 (depuis le relachement) actif=%s impact=%s enchainement=%s garde=%s fin=%s" % [fps, r["geste"], _ms(r["actif"] - rel if r["actif"] >= 0.0 else -1.0), _ms(r["impact"] - rel if r["impact"] >= 0.0 else -1.0), _ms(r["enchainement"] - rel if r["enchainement"] >= 0.0 else -1.0), _ms(r["garde"] - rel if r["garde"] >= 0.0 else -1.0), _ms(r["fin"] - rel if r["fin"] >= 0.0 else -1.0)])
	# durée d'appui : un clic lent retarde-t-il le coup ?
	for ap in [0.05, 0.12, 0.2, 0.26]:
		var r := await _coup("diag_dg", 60, ap)
		print("APPUI duree=%s actif=%s impact=%s" % [_ms(ap), _ms(r["actif"]), _ms(r["impact"])])
	for g in GESTES + LOURDS:
		_vitesse(g)
	if _a("armes"):
		await _armes()
	print("FIN mesures_latence")
	quit(0)

## Cycle du combo à l'arrêt (3 coups enchaînés au plus tôt) par épée : durée, dégâts sur le mannequin, endurance.
func _armes() -> void:
	for id in ["epee_metal", "epee_or", "epee_rubis", "epee_verre", "epee_obsidienne"]:
		mains.equipement.equiper("droite", load("res://data/armes/%s.tres" % id))
		await _reset()
		var dt := 1.0 / 60.0
		var n0: int = s.mannequin.coups.size()
		var tot0: float = s.mannequin.total
		var v0: float = j.vigueur
		var t := 0.0
		var coups := 0
		# 6 coups légers : chaque appui est fait dès que la fenêtre de combo s'ouvre
		mains.entrees.appuyer()
		var tenu := true
		var debut_appui := 0.0
		while coups < 6 and t < 6.0:
			if tenu and t - debut_appui >= 0.05:
				mains.entrees.relacher()
				tenu = false
			mains.avancer(dt)
			t += dt
			var fen: Array = mains._geste.get("enchainement", [mains.DELAI_COMBO, 1.0]) if not mains._geste.is_empty() else [0.06, 1.0]
			if not tenu and mains.combat.etat == EtatCombat.RECUPERATION and mains.combat.t >= float(fen[0]) and mains.entrees.tampon < 0.0:
				coups += 1
				if coups < 6:
					mains.entrees.appuyer()
					tenu = true
					debut_appui = t
		# dernière récupération
		for k in 60:
			mains.avancer(dt)
		var nb: int = s.mannequin.coups.size() - n0
		var deg: float = s.mannequin.total - tot0
		var a: DonneesArme = mains.arme
		print("ARME id=%s cycle6=%.2fs touches=%d degats=%.1f dps=%.1f endurance=%.0f endurance_s=%.1f prep_A=%d ms" % [id, t, nb, deg, deg / t, v0 - j.vigueur, (v0 - j.vigueur) / t, roundi((float(mains.anim.marqueurs("coup_a")["frappe"])) / a.vitesse * a.preparation * 1000.0) if "preparation" in a else roundi(float(mains.anim.marqueurs("coup_a")["frappe"]) / a.vitesse * 1000.0)])
	mains.equipement.equiper("droite", Equipement.EPEE_METAL)
