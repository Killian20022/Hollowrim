extends SceneTree
## BANC « BOT » de la menace des ennemis courants (nuit 2026-11-05, docs/COMBAT.md « Menace des ennemis courants »).
## Dérivé de la sonde d'audit outils/audit_bot_combat.gd : un bot « manette » combat de VRAIS draugrs dans scenes/test_combat.tscn.
##   godot --headless --path . --script res://outils/test_menace_bot.gd -- [--n=10] [--film=mode] [--type=draugr]
## Modes du bot (la même vision de l'ennemi pour tous, aucune triche sur le tracé de lame ni sur les dégâts) :
##   spam    clique dès que le coup précédent le permet, ne se défend JAMAIS (c'est le cas de l'audit : 14 essais sur 15 à 0 dégât).
##   garde   lève la garde ~0,25 s après le début du geste ennemi (réaction humaine), la relâche après l'impact, riposte.
##   parade  lève la garde pile à l'instant « parfait » des coups légers (limite haute de la parade) ; esquive le geste annoncé.
##   esquive esquive (pas de côté) au bon moment, ~0,1 s avant l'impact de chaque geste, puis riposte.
## Mesures : durée du combat, vie perdue, nombre de coups reçus, ennemi tué ?
## SEUILS (échec du test s'ils ne sont pas tenus) : voir _verifier().
const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var n := 10
var type := "draugr"
var film := ""
var etiq := ""      # texte de l'étiquette du film (sinon APRES / AVANT exe 4)
var trace := false
var ancien := false   # film « avant » : reproduit le comportement de l'exe 4 (80 PV, posture 55, pas de série ni de geste annoncé)
var nb_film := 2
var etiquette: Label
var _ok := true
var _seuils := {}
## Cadence ennemie mesurée (tous essais) : préavis (début du geste → impact), écarts entre coups d'une série et entre séries.
var _pre_n: Array = []      # coups normaux
var _pre_l: Array = []      # gestes annoncés (imparables)
var _ecart_serie: Array = []
var _ecart_entre: Array = []
var _hits := 0
var _tmps := 0.0            # secondes de combat x ennemis

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="): n = int(a.substr(4))
		elif a.begins_with("--type="): type = a.substr(7)
		elif a.begins_with("--film="): film = a.substr(7)
		elif a.begins_with("--etiq="): etiq = a.substr(7)
		elif a == "--trace": trace = true
		elif a == "--ancien": ancien = true
		elif a.begins_with("--nb="): nb_film = int(a.substr(5))
	_go.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _pas(k := 1) -> void:
	for i in k:
		if film == "":
			mains.avancer(DT)
		await physics_frame

## Instant (s depuis le début du geste) de l'impact du geste en cours de `d`, et fin de la préparation.
func _impact(d: Node) -> float:
	if d._lourd:
		return ReglagesCombat.MENACE_LOURD_ANNONCE
	var duree: float = d._duree(d._attaque) / d._rythme
	var f := 0.42
	var a: Animation = d.anim.get_animation(d._clip(d._attaque))
	if a.has_meta("impact") and float(a.get_meta("impact")) > 0.0:
		f = float(a.get_meta("impact"))
	return duree * f

func _vivants(liste: Array) -> Array:
	return liste.filter(func(d): return is_instance_valid(d) and d.etat != d.MORT)

func _go() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.muet = film == ""
	Sang.niveau_force = 2
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	current_scene = s
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	seed(20261105)   # tirages de l'IA (séries, replis, côtés) reproductibles d'un lancement à l'autre
	for i in 30:
		await physics_frame
	if film == "":
		mains.pas_manuel = true
	s.mannequin.position = Vector3(-8, 0, -8)
	var res := {}
	if film != "":
		var cl := CanvasLayer.new()
		cl.layer = 60
		s.add_child(cl)
		etiquette = Label.new()
		etiquette.position = Vector2(8, 8)
		etiquette.add_theme_font_override("font", Palette.police())
		etiquette.add_theme_font_size_override("font_size", 20)
		etiquette.add_theme_color_override("font_outline_color", Color.BLACK)
		etiquette.add_theme_constant_override("outline_size", 6)
		cl.add_child(etiquette)
		etiquette.text = "%s - %s (%d x %s)" % [etiq if etiq != "" else ("AVANT (exe 4)" if ancien else "APRES"), film, nb_film, type]
		await _essai(film, type, nb_film, 0)
		quit()
		return
	if trace:
		await _essai("spam", type, 1, 0)
		quit()
		return
	res["passif_1"] = []
	for e in 4:
		res["passif_1"].append(await _essai("passif", type, 1, e))
	for mode in ["spam", "garde", "parade", "esquive"]:
		res[mode + "_1"] = []
		for e in n:
			res[mode + "_1"].append(await _essai(mode, type, 1, e))
	for mode in ["spam", "parade", "esquive"]:
		res[mode + "_2"] = []
		for e in maxi(n / 2, 4):
			res[mode + "_2"].append(await _essai(mode, type, 2, e))
	_verifier(res)
	print("TEST_MENACE_BOT ", "OK" if _ok else "ECHECS")
	quit(0 if _ok else 1)

func _moy(l: Array, cle: String) -> float:
	var t := 0.0
	for r in l:
		t += float(r[cle])
	return t / maxf(l.size(), 1)

func _frac(l: Array, cle: String) -> float:
	var c := 0
	for r in l:
		if float(r[cle]) > 0.0:
			c += 1
	return float(c) / maxf(l.size(), 1)

func _verifier(res: Dictionary) -> void:
	for k in res:
		var l: Array = res[k]
		if k == "passif_1":
			print("BILAN passif_1  n=%d  dégâts moy=%.1f  durée moy=%.1fs (joueur mort : %.0f %%)" % [l.size(), _moy(l, "degats"), _moy(l, "duree"), (1.0 - _moy(l, "tues")) * 100.0])
			continue
		print("BILAN %-9s n=%d  dégâts moy=%.1f  essais avec dégâts=%.0f %%  durée moy=%.1fs  coups reçus moy=%.1f  ennemis tués=%.0f %%" % [k, l.size(), _moy(l, "degats"), _frac(l, "degats") * 100.0, _moy(l, "duree"), _moy(l, "coups"), _moy(l, "tues") * 100.0 / (2.0 if k.ends_with("_2") else 1.0)])
	var moy := func(l: Array) -> float:
		var t := 0.0
		for v in l: t += float(v)
		return t / maxf(l.size(), 1)
	print("CADENCE préavis coup normal moy=%.2f s (min %.2f, n=%d) | geste annoncé moy=%.2f s (min %.2f, n=%d) | écart dans une série moy=%.2f s | écart entre séries moy=%.2f s | coups/s/ennemi = %.2f" % [
		moy.call(_pre_n), (_pre_n.min() if not _pre_n.is_empty() else 0.0), _pre_n.size(), moy.call(_pre_l), (_pre_l.min() if not _pre_l.is_empty() else 0.0), _pre_l.size(), moy.call(_ecart_serie), moy.call(_ecart_entre), _hits / maxf(_tmps, 1.0)])
	var spam: Array = res["spam_1"]
	_verif(_frac(spam, "degats") >= 0.6, "un draugr face au bot qui spamme inflige des dégâts dans ≥ 60 %% des essais (%.0f %%)" % (_frac(spam, "degats") * 100.0))
	_verif(_moy(spam, "duree") >= 3.0 and _moy(spam, "duree") <= 12.0, "combat contre un draugr seul : 3 à 12 s pour le bot qui ne se défend pas (plafond ; un vrai joueur : plus long) (%.1f s ; avant : 2,5-3,2 s)" % _moy(spam, "duree"))
	_verif(_moy(spam, "degats") >= 6.0, "le spam coûte au moins 6 PV en moyenne (%.1f ; avant le ralentissement : 19)" % _moy(spam, "degats"))
	# un joueur PASSIF (ni coup, ni garde, ni esquive) doit toujours pouvoir être tué par un seul draugr : la menace reste réelle
	var pas: Array = res["passif_1"]
	_verif(_moy(pas, "tues") == 0.0 and _frac(pas, "degats") == 1.0 and _moy(pas, "duree") <= 30.0, "un draugr tue un joueur passif en ≤ 30 s (%.1f s, %.0f PV perdus en moyenne)" % [_moy(pas, "duree"), _moy(pas, "degats")])
	_verif(_pre_n.is_empty() or _pre_n.min() >= 0.4, "anticipation de tout coup normal ≥ 0,4 s (min %.2f s)" % (_pre_n.min() if not _pre_n.is_empty() else 0.0))
	_verif(_pre_l.is_empty() or _pre_l.min() >= 1.0, "anticipation du geste imparable annoncé ≥ 1,0 s (min %.2f s)" % (_pre_l.min() if not _pre_l.is_empty() else 0.0))
	_verif(_moy(res["garde_1"], "degats") <= _moy(spam, "degats") * 0.7, "garder après avoir vu le geste : ≤ 70 %% des dégâts du spam (%.1f contre %.1f)" % [_moy(res["garde_1"], "degats"), _moy(spam, "degats")])
	_verif(_moy(res["parade_1"], "degats") <= _moy(spam, "degats") * 0.5, "parer au bon moment : ≤ 50 %% des dégâts du spam (%.1f contre %.1f)" % [_moy(res["parade_1"], "degats"), _moy(spam, "degats")])
	_verif(_moy(res["esquive_1"], "degats") <= _moy(spam, "degats") * 0.6, "esquiver au bon moment : ≤ 60 %% des dégâts du spam (%.1f contre %.1f)" % [_moy(res["esquive_1"], "degats"), _moy(spam, "degats")])
	for k in ["garde_1", "parade_1", "esquive_1"]:
		_verif(_moy(res[k], "tues") >= 0.9, "%s : le joueur finit par gagner (%.0f %%)" % [k, _moy(res[k], "tues") * 100.0])
	var s2: Array = res["spam_2"]
	_verif(_moy(s2, "degats") >= maxf(2.0 * _moy(spam, "degats") * 0.8, 25.0), "2 draugrs sont dangereux pour qui spamme : ≥ 25 PV et ≥ 1,6× un seul (%.1f contre %.1f)" % [_moy(s2, "degats"), _moy(spam, "degats")])
	_verif(_moy(res["parade_2"], "degats") <= _moy(s2, "degats") * 0.6, "2 draugrs : parer au bon moment (et esquiver le geste annoncé) : ≤ 60 %% des dégâts du spam (%.1f contre %.1f)" % [_moy(res["parade_2"], "degats"), _moy(s2, "degats")])
	# esquive_2 : INFORMATIF (le bot « esquive » est timide, il ne frappe pas tant qu'un coup arrive ; 2 ennemis = coups presque continus)

## Un essai : `nb` ennemis du type `t` (2 = en flanc), renvoie les mesures.
func _essai(mode: String, t: String, nb: int, idx: int) -> Dictionary:
	s.placer_joueur(Vector3.ZERO, 0.0)
	if j.mort:
		j.ressusciter(Vector3.ZERO, 0.0)   # mort à l'essai précédent (joueur passif) : sans cela plus rien ne l'atteint
	j.vie = j.vie_max
	j.vigueur = j.vigueur_max
	mains.combat.forcer(EtatCombat.REPOS)
	mains._combo = 0
	mains._depuis_coup = 9.0
	mains.entrees.relacher()
	mains.entrees.forcer_garde(0.0)
	mains.entrees.tampon = -1.0
	var liste := []
	for k in nb:
		var d := CharacterBody3D.new()
		d.set_script(load("res://scripts/draugr.gd"))
		d.type = t   # AVANT add_child : _ready lit le type (PV, dégâts, allures)
		d.joueur = j
		d.hud = s.hud
		d.ident = "bot_%s_%d_%d" % [mode, idx, k]
		if ancien:
			d.vie_imposee = ReglagesCombat.vie(t) / 1.3 if t == "draugr" else 0.0
		d.position = Vector3(2.0 + idx * 0.37 + k * 1.6, 0, -5.0 - k * 1.5)
		d.rotation.y = atan2(d.position.x, d.position.z)
		s.add_child(d)
		if ancien:
			d._menace = false
			d._rythme = 1.0
			d.combat.profil.posture_max = 55.0
			d.combat.posture = 55.0
		liste.append(d)
	await _pas(5)
	var vie0: float = j.vie
	var t_ := 0.0
	var t_clic := -1.0
	var garde_t := 0.0
	var coups := 0
	var vie_prec: float = j.vie
	var t_esquive := -1.0
	var vus := {}
	var cad_prec := {}
	var cad_dernier := {}
	while t_ < 40.0 and not _vivants(liste).is_empty() and j.vie > 0.0:
		var cible: Node3D = null
		var dmin := 1e9
		for d in _vivants(liste):
			var dd: float = (d.global_position - j.global_position).length()
			if dd < dmin:
				dmin = dd
				cible = d
		var dv: Vector3 = cible.global_position - j.global_position
		var dist := Vector2(dv.x, dv.z).length()
		j.rotation.y = lerp_angle(j.rotation.y, atan2(-dv.x, -dv.z), 0.5)
		if j.esquive_t < 0.0:
			j.velocity = Vector3.ZERO
			if dist > 2.3:
				j.global_position += Vector3(dv.x, 0, dv.z).normalized() * 3.0 * DT
		# lecture des gestes ennemis (un seul suivi par ennemi)
		var menace_proche := false
		var impact_dans := 9.0
		for d in _vivants(liste):
			var dd: float = Vector2(d.global_position.x - j.global_position.x, d.global_position.z - j.global_position.z).length()
			if d.etat == d.ATTAQUE and dd < 3.4:
				var id: int = d.get_instance_id()
				if not vus.has(id):
					vus[id] = t_
				var avant: float = _impact(d) - d._t
				if not d._coup_donne and avant > -0.05:
					menace_proche = true
					impact_dans = minf(impact_dans, avant)
					# l'ennemi lourd annoncé se lit tout de suite : esquive voulue ~0,12 s avant l'impact
			else:
				vus.erase(d.get_instance_id())
		if trace and int(t_ * 60.0) % 6 == 0:
			var ds := []
			for d in _vivants(liste):
				ds.append("%s/%.2f/pv%.0f/arm%.1f/rech%.1f" % [["DORT", "REVEIL", "GARDE", "TRAQUE", "ATTAQUE", "TITUBE", "MORT", "PATROUILLE", "VISE", "APPEL", "ANNONCE", "SOUFFLE", "ETOURDI", "CHUTE"][d.etat], d._t, d.vie, d._armure, d._recharge])
			print("TRACE t=%.2f dist=%.1f joueur=%s %s" % [t_, dist, mains.combat.nom(), str(ds)])
		for d in _vivants(liste):
			var did: int = d.get_instance_id()
			var vu_donne: bool = d.etat == d.ATTAQUE and d._coup_donne
			if vu_donne and not bool(cad_prec.get(did, false)):
				(_pre_l if d._lourd else _pre_n).append(d._t)
				_hits += 1
				if cad_dernier.has(did):
					(_ecart_serie if d._serie > 1 else _ecart_entre).append(t_ - float(cad_dernier[did]))
				cad_dernier[did] = t_
			cad_prec[did] = vu_donne
		var lourd_vu := false
		for d in _vivants(liste):
			if d.etat == d.ATTAQUE and d._lourd and not d._coup_donne:
				lourd_vu = true
				if not vus.has(-d.get_instance_id()):
					vus[-d.get_instance_id()] = true
					print("EVENT lourd_debut film_t=%.2f" % (Engine.get_process_frames() / 30.0))
			elif d.etat != d.ATTAQUE:
				vus.erase(-d.get_instance_id())
		match mode:
			"garde":
				# réaction humaine : 0,25 s après le début du geste, la garde reste levée jusqu'à 0,2 s après l'impact
				var lever := false
				for d in _vivants(liste):
					if d.etat == d.ATTAQUE and vus.has(d.get_instance_id()) and t_ - float(vus[d.get_instance_id()]) >= 0.25 and d._t < _impact(d) + 0.25:
						lever = true
				if lever:
					garde_t = 0.15
			"parade":
				if menace_proche and not lourd_vu and impact_dans <= 0.12 and impact_dans > -0.05:
					garde_t = 0.5
				if lourd_vu and impact_dans <= 0.14 and t_esquive < 0.0:
					t_esquive = t_
					j.esquiver(Vector2(1.0 if (idx + nb) % 2 == 0 else -1.0, 0))
			"esquive":
				if menace_proche and impact_dans <= 0.12 and impact_dans > -0.02 and j.esquive_t < 0.0 and t_ - t_esquive > 0.25:
					t_esquive = t_
					# côté : à l'opposé des autres ennemis (un joueur ne saute pas dans le flanc)
					var somme := 0.0
					for d in _vivants(liste):
						somme += (d.global_position - j.global_position).dot(j.global_transform.basis.x)
					if j.esquiver(Vector2(-signf(somme) if absf(somme) > 0.1 else (1.0 if int(t_ * 10.0) % 2 == 0 else -1.0), 0)):
						print("EVENT esquive film_t=%.2f" % (Engine.get_process_frames() / 30.0))
		if garde_t > 0.0:
			mains.entrees.forcer_garde(0.1)
			garde_t -= DT
		else:
			mains.entrees.forcer_garde(0.0)
		# clics : le bot « spam » ne se défend jamais ; les autres ne frappent pas quand ils gardent
		var peut_cliquer: bool = garde_t <= 0.0 and j.esquive_t < 0.0 and mode != "passif"
		if mode == "esquive" or mode == "parade":
			peut_cliquer = peut_cliquer and not (menace_proche and impact_dans < 0.8)   # un coup lancé ne s'annule pas : on le finit AVANT l'impact ennemi
		if peut_cliquer and dist < 2.4 and t_ - t_clic > 0.30:
			mains.entrees.appuyer()
			t_clic = t_
			await _pas(2)
			mains.entrees.relacher()
			t_ += 2 * DT
			continue
		if j.vie < vie_prec - 0.01:
			coups += 1
		vie_prec = j.vie
		await _pas(1)
		t_ += DT
	var tues := 0
	for d in liste:
		if not is_instance_valid(d) or d.etat == d.MORT:
			tues += 1
	_tmps += t_ * nb
	var r := {"mode": mode, "nb": nb, "duree": t_, "degats": vie0 - j.vie, "coups": coups, "tues": tues}
	print("ESSAI mode=%s ennemis=%d essai=%d durée=%.1fs dégâts=%.0f coups=%d tués=%d/%d esquives=%d" % [mode, nb, idx, t_, vie0 - j.vie, coups, tues, nb, j.esquives])
	for d in liste:
		if is_instance_valid(d):
			d.queue_free()
	await _pas(30)
	return r
