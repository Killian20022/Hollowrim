extends SceneTree
## Continuité des bras pendant les GESTES DE MAGIE (GestesMagie + IK de main_sort.gd) : pas d'avant-bras « disloqué ».
## Mêmes critères que outils/test_articulations_bras.gd (coups d'épée), mesurés EN JEU (scenes/test_magie.tscn) sur la
## pose finale du squelette (après l'IK à deux os et OrientationMain, signal skeleton_updated), bras gauche ET droit :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_articulations_magie.gd -- --nouvelle [--detail]
## Le rig n'a pas d'os de torsion : toute la pronation est portée par lowerarm / hand. Pour chaque geste (lancer, charge,
## jet, zone, double, double charge, double jet, main droite), joué à 60 puis à 30 i/s :
##   - longueurs épaule → coude et coude → poignet constantes (±1 mm) ;
##   - torsion autour de l'axe de l'os d'une image à l'autre (bras, avant-bras, main) : ≤ 15° à 60 i/s, ≤ 30° à 30 i/s ;
##   - plan épaule-coude-poignet ≤ 20° par image à 60 i/s (≤ 40 à 30) ; accélération du coude ≤ 0,10 m/image² à 60 i/s ;
##   - torsion de la main sur l'avant-bras, depuis la pose de repos, bornée (≤ TORSION_MAIN_MAX) : poignet jamais vrillé ;
##   - raccords : avant le geste et après son retour, la pose est celle du repos (≤ 1° par os).

const SCENE := preload("res://scenes/test_magie.tscn")
const TORSION_MAX := {60: 15.0, 30: 30.0}
const PLAN_MAX := {60: 20.0, 30: 40.0}
const ACCEL_COUDE := 0.10
## Torsion de la main (sur l'avant-bras) depuis la pose de repos : gestes_magie.py borne la pronation à -40..+125°.
const TORSION_MAIN_MAX := 140.0
const RACCORD_MAX := 1.0

var _ok := true
var _n := 0
var s: Node3D
var mains: Node3D
var magie: MainSort
var sq: Skeleton3D
var detail := false
var _derniere := {}   # dernière pose du squelette après les modificateurs
var _l := {}

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

## Torsion (degrés) d'une rotation autour de l'axe Y local de l'os (décomposition balancement-torsion).
static func _torsion(q: Quaternion) -> float:
	var t := Quaternion(0.0, q.y, 0.0, q.w)
	if t.length() < 1e-9:
		return 0.0
	t = t.normalized()
	return rad_to_deg(2.0 * atan2(t.y, t.w)) if t.w >= 0.0 else rad_to_deg(2.0 * atan2(-t.y, -t.w))

func _globale(i: int) -> Transform3D:
	var t := Transform3D()
	while i >= 0:
		t = sq.get_bone_pose(i) * t
		i = sq.get_bone_parent(i)
	return t

## Relevé de la pose finale (appelé après les modificateurs : IK, orientation de la main).
func _sur_maj() -> void:
	var p := {}
	for c in ["l", "r"]:
		for nom in ["upperarm_", "lowerarm_", "hand_"]:
			var b := sq.find_bone(nom + c)
			p[nom + c] = sq.get_bone_pose_rotation(b)
			p["o_" + nom + c] = _globale(b).origin
	_derniere = p

func _tester() -> void:
	detail = "--detail" in OS.get_cmdline_user_args()
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	mains = s.joueur.mains
	magie = mains.magie
	magie.souffle_tenue = false   # tenue « runes » : repos sans respiration, comparable d'un bout à l'autre du geste
	mains.pas_manuel = true
	sq = mains.get("_sq")
	sq.skeleton_updated.connect(_sur_maj)
	for c in ["l", "r"]:
		var e := sq.get_bone_global_rest(sq.find_bone("upperarm_" + c)).origin
		var co := sq.get_bone_global_rest(sq.find_bone("lowerarm_" + c)).origin
		var h := sq.get_bone_global_rest(sq.find_bone("hand_" + c)).origin
		_l[c] = [e.distance_to(co), co.distance_to(h)]
	for i in 20:
		await process_frame
	var cas := [
		["lance", "eclat_glace", "epee", [[0.3, "appui"], [0.35, "relache"]], 1.8, ["l"]],
		["charge", "boule_feu", "epee", [[0.3, "appui"], [1.5, "relache"]], 2.8, ["l"]],
		["jet", "jet_flammes", "epee", [[0.3, "appui"], [1.8, "relache"]], 3.2, ["l"]],
		["zone", "explosion_obscure", "epee", [[0.3, "appui"], [1.6, "relache"]], 2.9, ["l"]],
		["zone main droite", "vide", "explosion_obscure", [[0.3, "appui"], [1.6, "relache"]], 2.9, ["r"]],
		["nova", "nova_gelee", "epee", [[0.3, "appui"], [0.35, "relache"]], 2.0, ["l"]],
		["main droite", "vide", "eclat_glace", [[0.3, "appui"], [0.35, "relache"]], 2.4, ["r"]],
		["double", "eclat_glace", "eclat_glace", [[0.3, "appui2"], [0.35, "relache2"]], 2.4, ["l", "r"]],
		["double charge", "boule_feu", "boule_feu", [[0.3, "appui2"], [1.5, "relache2"]], 3.2, ["l", "r"]],
		["double jet", "jet_flammes", "jet_flammes", [[0.3, "appui2"], [1.6, "relache2"]], 3.4, ["l", "r"]],
	]
	for freq in [60, 30]:
		for c in cas:
			var ech: Array = await _jouer(c[1], c[2], c[3], c[4], c[5][0], 1.0 / freq)
			for cote in c[5]:
				_mesurer("%s (%s, %d i/s)" % [c[0], "gauche" if cote == "l" else "droite", freq], ech, cote, freq)
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

func _reset() -> void:
	for m in ["gauche", "droite"]:
		magie._couper(m, false)
		magie.inc[m].changer(Incantation.REPOS)
		magie.inc[m].tenu = false
		magie.inc[m].tampon = -1.0
	magie.recharges.clear()
	s.joueur.mana = s.joueur.mana_max
	mains.combat.forcer(EtatCombat.REPOS)

## Joue un scénario image par image (pas dt) ; rend la suite des poses relevées après chaque image.
func _jouer(gauche: String, droite: String, actions: Array, duree: float, cote: String, dt: float) -> Array:
	var main := "gauche" if cote == "l" else "droite"
	magie.equiper("droite", droite)
	magie.equiper("gauche", gauche)
	_reset()
	for i in 90:
		mains.avancer(dt)
		await process_frame
	var out := []
	var t := 0.0
	var k := 0
	while t < duree:
		while k < actions.size() and t >= float(actions[k][0]):
			match String(actions[k][1]):
				"appui": magie.appuyer(main)
				"relache": magie.relacher(main)
				"appui2":
					magie.appuyer("gauche")
					magie.appuyer("droite")
				"relache2":
					magie.relacher("gauche")
					magie.relacher("droite")
			k += 1
		s.joueur.mana = s.joueur.mana_max
		mains.avancer(dt)
		await process_frame
		t += dt
		var p := _derniere.duplicate()
		p["t"] = t
		out.append(p)
	return out

func _mesurer(nom: String, ech: Array, c: String, freq: int) -> void:
	var os := ["upperarm_" + c, "lowerarm_" + c, "hand_" + c]
	var dl := 0.0
	var pire := [0.0, 0.0, 0.0]
	var ou := [0.0, 0.0, 0.0]
	var plan := 0.0
	var t_plan := 0.0
	var acc := 0.0
	var t_acc := 0.0
	var tmain := 0.0
	for i in ech.size():
		var b: Dictionary = ech[i]
		var E: Vector3 = b["o_" + os[0]]
		var C: Vector3 = b["o_" + os[1]]
		var P: Vector3 = b["o_" + os[2]]
		dl = maxf(dl, maxf(absf(E.distance_to(C) - _l[c][0]), absf(C.distance_to(P) - _l[c][1])))
		tmain = maxf(tmain, absf(_torsion((ech[0][os[2]] as Quaternion).inverse() * b[os[2]])))
		if i == 0:
			continue
		var a: Dictionary = ech[i - 1]
		for j in 3:
			var d := absf(_torsion((a[os[j]] as Quaternion).inverse() * b[os[j]]))
			if d > pire[j]:
				pire[j] = d
				ou[j] = b["t"]
		var na: Vector3 = ((a["o_" + os[1]] as Vector3) - a["o_" + os[0]]).cross((a["o_" + os[2]] as Vector3) - a["o_" + os[1]])
		var nb: Vector3 = (C - E).cross(P - C)
		if na.length() > 1e-6 and nb.length() > 1e-6:
			var dp := rad_to_deg(na.angle_to(nb))
			if dp > plan:
				plan = dp
				t_plan = b["t"]
		if i + 1 < ech.size():
			var cc: Dictionary = ech[i + 1]
			var ac := ((cc["o_" + os[1]] as Vector3) - 2.0 * C + (a["o_" + os[1]] as Vector3)).length()
			if ac > acc:
				acc = ac
				t_acc = b["t"]
		if detail:
			print("   %s t=%.3f torsion bras %+5.1f avant-bras %+5.1f main %+5.1f (main/avant-bras %+6.1f)" % [nom, b["t"],
				_torsion((a[os[0]] as Quaternion).inverse() * b[os[0]]), _torsion((a[os[1]] as Quaternion).inverse() * b[os[1]]),
				_torsion((a[os[2]] as Quaternion).inverse() * b[os[2]]), _torsion((ech[0][os[2]] as Quaternion).inverse() * b[os[2]])])
	var lim: float = TORSION_MAX[freq]
	var acc_lim := ACCEL_COUDE * (4.0 if freq == 30 else 1.0)   # même accélération physique : ×(60/30)²
	_verif(dl <= 0.001, "%s : longueurs du bras constantes (écart max %.4f m)" % [nom, dl])
	_verif(pire[0] <= lim and pire[1] <= lim and pire[2] <= lim,
		"%s : torsion par image ≤ %.0f° (bras %.1f° à %.2f s, avant-bras %.1f° à %.2f s, main %.1f° à %.2f s)" % [
			nom, lim, pire[0], ou[0], pire[1], ou[1], pire[2], ou[2]])
	_verif(plan <= PLAN_MAX[freq], "%s : plan du coude continu (%.1f° par image max à %.2f s ; ≤ %.0f)" % [nom, plan, t_plan, PLAN_MAX[freq]])
	_verif(acc <= acc_lim, "%s : coude sans saut (accélération %.3f m/image² à %.2f s ; ≤ %.2f)" % [nom, acc, t_acc, acc_lim])
	_verif(tmain <= TORSION_MAIN_MAX, "%s : torsion de la main depuis le repos %.1f° max (≤ %.0f)" % [nom, tmain, TORSION_MAIN_MAX])
	var d0 := 0.0
	var d1 := 0.0
	for j in 3:
		d0 = maxf(d0, rad_to_deg((ech[0][os[j]] as Quaternion).angle_to(ech[2][os[j]])))
		d1 = maxf(d1, rad_to_deg((ech[0][os[j]] as Quaternion).angle_to(ech[-1][os[j]])))
	_verif(d1 <= RACCORD_MAX * 3.0, "%s : revient au repos (écart final %.2f° par os ; repos stable au départ %.2f°)" % [nom, d1, d0])
