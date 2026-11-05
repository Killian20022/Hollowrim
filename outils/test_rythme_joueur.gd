extends SceneTree
## Rythme des coups du joueur (retour exe 5 : coups plus posés, plus lourds ; ReglagesCombat.JOUEUR_LENTEUR*).
##   godot --headless --path . --script res://outils/test_rythme_joueur.gd
## Le joueur frappe un mannequin (scenes/test_combat.tscn) :
##   1. un clic isolé : délai clic -> touche, puis délai jusqu'à la fin de la récupération (combat redevenu libre) ;
##   2. 8 s de clics répétés (un toutes les 0,1 s) : intervalle moyen entre deux touches, le combo reste STRICT (clic n -> coup n) ;
##   3. synchronisation : la touche (donc l'impact et son son) tombe dans la phase active du geste (tracé de lame), jamais avant l'armement.
## Seuils : coup léger posé, mais pas au ralenti (attaque, enchaînement et récupération bornés).
const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0
var _ok := true
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var touches: Array = []   # [temps, geste, phase_active]
var _tt := 0.0

func _init() -> void:
	_go.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _pas(n := 1) -> void:
	for k in n:
		mains.avancer(DT)
		_tt += DT

func _reset() -> void:
	s.placer_joueur(s.POS_MANNEQUIN + Vector3(0, 0, 1.6), 0.0)
	j.vigueur = j.vigueur_max
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains._depuis_coup = 9.0
	mains._pose_courante = mains._pose_repos()
	var mc: CombatEnnemi = s.mannequin.combat
	mc.posture = mc.profil.posture_max
	mc.etourdi = 0.0
	touches.clear()
	await physics_frame
	await physics_frame

func _go() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.muet = true
	s = SCENE.instantiate()
	s.options = {"draugr": "fige", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	s.mannequin.touche.connect(func(_d: float, _p: bool) -> void:
		touches.append([_tt, mains._geste_nom, mains.combat.etat]))
	# --- 1. coup isolé (coup 1)
	await _reset()
	_tt = 0.0
	mains.entrees.appuyer()
	_pas(3)
	mains.entrees.relacher()
	var t_libre := -1.0
	var duree_prep: float = mains._duree_prep
	var duree_tenue: float = mains._duree_tenue
	var duree_active: float = mains._duree_active
	var duree_recup: float = mains._duree_recup
	var duree_suivi: float = mains._duree_suivi
	for k in 150:
		_pas()
		if t_libre < 0.0 and k > 5 and not mains.combat.attaque() and mains.combat.etat != EtatCombat.RECUPERATION:
			t_libre = _tt
	var t_touche: float = touches[0][0] if not touches.is_empty() else -1.0
	var phase_attendue: float = duree_prep + duree_tenue
	print("RYTHME_JOUEUR coup 1 : armement+tenue %.2f s, phase active %.2f s, récupération %.2f s (suivi %.2f) ; clic -> touche %.2f s ; clic -> libre %.2f s" % [phase_attendue, duree_active, duree_recup, duree_suivi, t_touche, t_libre])
	_verif(t_touche > 0.0, "le coup isolé touche le mannequin")
	_verif(t_touche >= phase_attendue - 0.05 and t_touche <= phase_attendue + duree_active + 0.1, "synchro : la touche (%.2f s) tombe dans la phase active [%.2f ; %.2f]" % [t_touche, phase_attendue, phase_attendue + duree_active])
	# --- 2. clics répétés pendant 8 s : combo strict, intervalle moyen
	await _reset()
	_tt = 0.0
	var gestes: Array = []
	var prec := ""
	for k in roundi(8.0 / DT):
		if k % 6 == 0:
			mains.entrees.appuyer()
		elif k % 6 == 2:
			mains.entrees.relacher()
		var mc: CombatEnnemi = s.mannequin.combat
		mc.posture = mc.profil.posture_max   # pas d'étourdissement : pas de finisher au milieu du combo mesuré
		_pas()
		if mains._geste_nom != prec:
			prec = mains._geste_nom
			gestes.append(prec)
	var n := touches.size()
	var ecarts: Array = []
	for i in range(1, n):
		ecarts.append(float(touches[i][0]) - float(touches[i - 1][0]))
	var moy := 0.0
	for e in ecarts:
		moy += e
	moy /= maxf(ecarts.size(), 1)
	print("RYTHME_JOUEUR clics répétés : %d touches en 8 s, intervalle moyen %.2f s (%.2f coups/s)" % [n, moy, 1.0 / maxf(moy, 0.01)])
	var combo_ok := true
	for i in gestes.size():
		if gestes[i] != CoupsUneMain.COMBO[i % CoupsUneMain.COMBO.size()]:
			combo_ok = false
			print("   écart au combo à l'indice %d : %s" % [i, gestes.slice(maxi(i - 2, 0), i + 2)])
			break
	_verif(combo_ok and gestes.size() >= 6, "combo strict : clic n -> coup n (%s)" % [gestes.slice(0, 6)])
	_verif(moy >= 0.38 and moy <= 0.65, "enchaînement posé mais pas au ralenti : 0,38 à 0,65 s entre deux touches (avant : 0,32) (%.2f)" % moy)
	_verif(t_touche >= 0.2 and t_touche <= 0.45, "clic -> touche du premier coup : 0,20 à 0,45 s (%.2f)" % t_touche)
	print("TEST_RYTHME_JOUEUR ", "OK" if _ok else "ECHECS")
	quit(0 if _ok else 1)
