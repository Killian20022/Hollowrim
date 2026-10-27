extends SceneTree
## Latences du combat à l'épée (audit, docs/COMBAT_AUDIT.md), sans fenêtre, à 60 i/s, dans scenes/test_combat.tscn :
##   godot --headless --path . --script res://outils/mesure_latence_combat.gd -- --nouvelle [--clic=0.05]
## Pour chaque coup du combo léger (clic de `clic` s, le suivant appuyé dès que possible = mémoire d'entrée) puis pour un
## coup lourd (appui 0,6 s) : instant (ms après l'appui) où
##   anim     la pointe de la lame bouge (> 5 mm de la pose précédente),
##   active   la phase active commence (la lame blesse),
##   impact   le mannequin (à 1,6 m) est touché,
##   combo    un nouvel appui serait pris (fenêtre de combo ouverte),
##   repos    le bras est revenu au repos (état Idle).
## Ligne LATENCE par coup, RESUME à la fin.

const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0

var s: Node3D
var j: CharacterBody3D
var mains: Node3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _pointe() -> Vector3:
	return mains._pose_courante * mains._pointe_lame

func _go() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	RetourImpact.muet = true
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	var clic := float(_arg("clic", "0.05"))
	s.placer_joueur(s.POS_MANNEQUIN + Vector3(0, 0, 1.6), 0.0)
	mains.combat.forcer(EtatCombat.REPOS)
	for i in 60:
		mains.avancer(DT)
	var touches := []
	var t := [0.0]
	s.mannequin.touche.connect(func(_d: float, _p: bool) -> void: touches.append(t[0]))
	var lignes := []
	# combo : 3 coups ; chaque appui tombe dès que la fenêtre du précédent est ouverte
	var debut := 0.0
	for coup in 4:
		var lourd := coup == 3
		if lourd:
			# attendre le repos
			while mains.combat.etat != EtatCombat.REPOS and t[0] - debut < 3.0:
				mains.avancer(DT)
				t[0] += DT
			for i in 20:
				mains.avancer(DT)
				t[0] += DT
		debut = t[0]
		mains.entrees.appuyer()
		var relache := false
		var m := {"anim": -1.0, "active": -1.0, "impact": -1.0, "combo": -1.0, "repos": -1.0}
		var n0 := touches.size()
		var p_prec := _pointe()
		var geste := ""
		var fini := false
		while t[0] - debut < 2.5 and not fini:
			if not relache and t[0] - debut >= (0.6 if lourd else clic):
				mains.entrees.relacher()
				relache = true
			mains.avancer(DT)
			t[0] += DT
			var e: float = t[0] - debut
			if geste == "" and mains.combat.attaque():
				geste = mains._geste_nom
			var p := _pointe()
			if m["anim"] < 0.0 and p.distance_to(p_prec) > 0.005:
				m["anim"] = e
			p_prec = p
			if m["active"] < 0.0 and mains._actif_lance:
				m["active"] = e
			if m["impact"] < 0.0 and touches.size() > n0:
				m["impact"] = e
			if m["combo"] < 0.0 and mains.combat.etat == EtatCombat.RECUPERATION:
				var fen: Array = mains._geste.get("enchainement", [0.05, 1.0])
				if mains.combat.t >= float(fen[0]):
					m["combo"] = e
					if coup < 2:
						fini = true   # le coup suivant part ici
			if m["repos"] < 0.0 and mains.combat.etat == EtatCombat.REPOS and m["active"] >= 0.0:
				m["repos"] = e
				fini = true
		var f := func(v: float) -> String: return "%4d" % roundi(v * 1000.0) if v >= 0.0 else "   -"
		var l := "LATENCE coup %d %-12s anim %s ms  active %s ms  impact %s ms  combo %s ms  repos %s ms" % [coup + 1, ("lourd(" + geste + ")") if lourd else geste, f.call(m["anim"]), f.call(m["active"]), f.call(m["impact"]), f.call(m["combo"]), f.call(m["repos"])]
		print(l)
		lignes.append(l)
	print("RESUME clic %d ms, 60 i/s, mannequin à 1,6 m" % roundi(clic * 1000.0))
	quit()
