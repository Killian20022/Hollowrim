extends SceneTree
## coups_v5 : combo à UNE MAIN au rythme des clics (scène scenes/test_combat.tscn, mannequin, sans fenêtre) :
##   godot --headless --path . --script res://outils/test_combo_une_main.gd -- --nouvelle
## 1. Clics en rythme (un clic par coup, dans la fenêtre d'enchaînement) : les 4 coups de CoupsUneMain.COMBO dans l'ordre
##    (diagonale, revers, taille horizontale, estoc), une touche chacun, puis le 5e clic repart au coup 1.
## 2. Clic trop lent (après le retour au repos) : le combo repart au coup 1.
## 3. Clic maintenu au milieu du combo : attaque puissante (lourd), touche marquée « puissant ».
## 4. Chaque coup du combo part du côté où le précédent a fini (pas de miroir) et dure moins de 0,6 s (rythme).

const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0

var _ok := true
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var touches := []

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _pas(n: int) -> void:
	for k in n:
		mains.avancer(DT)

func _reset() -> void:
	s.placer_joueur(s.POS_MANNEQUIN + Vector3(0, 0, 1.6), 0.0)
	j.vigueur = j.vigueur_max
	j.competences = Competences.new()
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains._depuis_coup = 9.0
	mains._pose_courante = mains._pose_repos()
	mains.defense = DefenseJoueur.new()
	var mc: CombatEnnemi = s.mannequin.combat
	mc.posture = mc.profil.posture_max
	mc.etourdi = 0.0
	await physics_frame
	await physics_frame

## Un clic court ; renvoie le geste lancé (lu 0,1 s après l'appui) puis laisse filer `apres` s.
func _clic(apres: float) -> String:
	mains.entrees.appuyer()
	_pas(3)
	mains.entrees.relacher()
	_pas(3)
	var g: String = mains._geste_nom
	_pas(roundi(apres / DT) - 6)
	await process_frame
	return g

func _tester() -> void:
	RetourCoups.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "fige", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	s.mannequin.touche.connect(func(d: float, p: bool) -> void: touches.append([mains._geste_nom, snappedf(d, 0.01), p]))
	_verif(CoupsUneMain.COMBO == ProfilsAnimation.profil("epee_longue")["combo"], "le profil de l'épée longue prend le combo à une main %s" % [CoupsUneMain.COMBO])

	# --- 1. en rythme : 5 clics à 0,45 s
	print("-- clics en rythme")
	await _reset()
	var gestes := []
	for i in 5:
		gestes.append(await _clic(0.45))
	_pas(roundi(0.6 / DT))
	print("   gestes %s ; touches %s" % [gestes, touches])
	_verif(gestes == CoupsUneMain.COMBO + [CoupsUneMain.COMBO[0]], "4 coups dans l'ordre puis retour au coup 1 : %s" % [gestes])
	_verif(touches.size() == 5 and touches.all(func(t: Array) -> bool: return not t[2]), "une touche légère par coup (%d)" % touches.size())

	# --- 2. trop lent : le 2e clic tombe après le retour au repos
	print("-- clic trop lent")
	await _reset()
	var a := await _clic(1.2)
	var b := await _clic(0.6)
	_verif(a == CoupsUneMain.COMBO[0] and b == CoupsUneMain.COMBO[0] and mains.combat.etat in [EtatCombat.REPOS, EtatCombat.MOUVEMENT, EtatCombat.RECUPERATION], "clic après le repos : le combo repart au coup 1 (%s, %s)" % [a, b])

	# --- 3. clic maintenu au milieu du combo : puissant
	print("-- clic maintenu")
	await _reset()
	touches.clear()
	await _clic(0.45)
	await _clic(0.45)
	mains.entrees.appuyer()
	var charge := false
	for k in roundi(1.0 / DT):
		mains.avancer(DT)
		charge = charge or mains.combat.etat == EtatCombat.CHARGE_LOURDE
	mains.entrees.relacher()
	_pas(roundi(1.2 / DT))
	print("   touches %s" % [touches])
	_verif(charge and touches.size() == 3 and touches[2][2], "clic maintenu après 2 coups : charge puis coup puissant qui touche (%s)" % [touches])

	# --- 4. continuité des côtés et durée des coups
	print("-- côtés et rythme")
	var prec_fin := 0
	for g in CoupsUneMain.COMBO:
		var ge := ProfilsAnimation.geste("epee_longue", g)
		var c: Array = ge["cotes"]
		var m: Dictionary = mains.anim.marqueurs(String(ge["clip"]))
		_verif(prec_fin == 0 or int(c[0]) == 0 or int(c[0]) == prec_fin, "%s part du côté où le précédent a fini (%s après %d)" % [g, c, prec_fin])
		_verif(float(m["fin"]) <= 0.6 and float(m["frappe"]) <= 0.16, "%s : frappe à %.2f s, fin à %.2f s (rythme du combo)" % [g, float(m["frappe"]), float(m["fin"])])
		prec_fin = int(c[1])
	print("RESULTAT : " + ("OK" if _ok else "ECHEC"))
	quit(0 if _ok else 1)
