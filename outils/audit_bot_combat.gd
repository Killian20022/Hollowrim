extends SceneTree
## AUDIT 2026-11-04 (sonde, ne corrige rien) : un « bot manette » combat un vrai draugr dans scenes/test_combat.tscn et mesure.
##   godot --path . --script res://outils/audit_bot_combat.gd -- --mode=spam|garde|parade [--type=sbire|guerrier|squelette|draugr] [--film] [--n=3]
## spam   : clique dès que le coup précédent le permet (rythme joueur nerveux), ne garde jamais.
## garde  : clic droit tenu quand le draugr arme son coup (réaction humaine ~0,25 s après le début de l'attaque), relâché ensuite, riposte.
## parade : lève la garde pile à l'instant « parfait » (limite haute : joueur parfait).
## Sortie : lignes RESULTAT (durée, vie perdue, nb coups portés, parades, endurance min, finisher ?).
const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var mode := "spam"
var type := "guerrier"
var film := false
var n := 3

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="): mode = a.substr(7)
		elif a.begins_with("--type="): type = a.substr(7)
		elif a.begins_with("--n="): n = int(a.substr(4))
		elif a == "--film": film = true
	_go.call_deferred()

func _pas(k := 1) -> void:
	for i in k:
		if not film:
			mains.avancer(DT)
		await physics_frame

func _go() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.muet = not film
	Sang.niveau_force = 2
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	current_scene = s
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await physics_frame
	if not film:
		mains.pas_manuel = true
	s.mannequin.position = Vector3(-8, 0, -8)
	var lab: Label
	if film:
		var cl := CanvasLayer.new(); cl.layer = 60; s.add_child(cl)
		lab = Label.new(); lab.position = Vector2(8, 8)
		lab.add_theme_font_override("font", Palette.police()); lab.add_theme_font_size_override("font_size", 22)
		lab.add_theme_color_override("font_outline_color", Color.BLACK); lab.add_theme_constant_override("outline_size", 6)
		cl.add_child(lab)
		lab.text = "bot %s vs %s" % [mode, type]
	var total := []
	for essai in n:
		s.placer_joueur(Vector3.ZERO, 0.0)
		j.vie = j.vie_max; j.vigueur = j.vigueur_max
		mains.combat.forcer(EtatCombat.REPOS); mains._combo = 0; mains._depuis_coup = 9.0
		mains.entrees.relacher(); mains.entrees.forcer_garde(0.0); mains.entrees.tampon = -1.0
		var d := CharacterBody3D.new()
		d.set_script(load("res://scripts/draugr.gd"))
		d.type = type   # AVANT add_child : _ready lit le type (PV, dégâts, allures)
		d.joueur = j
		d.hud = s.hud
		d.ident = "audit_bot_%d" % essai
		d.position = Vector3(2.0 + essai * 0.5, 0, -5.0)
		d.rotation.y = atan2(d.position.x, d.position.z)
		s.add_child(d)
		await _pas(5)
		var vie0: float = j.vie
		var v_ennemi0: float = d.vie
		var t := 0.0
		var clics := 0
		var min_end: float = j.vigueur
		var parades_avant: int = mains.defense.nb_parades
		var garde_t := 0.0
		var t_clic := 0.0
		var t_vu_attaque := -1.0
		var fini := false
		var t_premier_hit := -1.0
		var vie_ennemi_min: float = d.vie
		var duree_max := 14.0 if mode == "passif" else 60.0
		var vie_prec: float = j.vie
		var coups_recus := 0
		var t_coups := []
		while t < duree_max and is_instance_valid(d) and d.etat != d.MORT and j.vie > 0.0:
			# regarder l'ennemi
			var dv: Vector3 = d.global_position - j.global_position
			var dist := Vector2(dv.x, dv.z).length()
			j.rotation.y = lerp_angle(j.rotation.y, atan2(-dv.x, -dv.z), 0.5)
			# approche
			j.velocity = Vector3.ZERO
			if dist > 2.3:
				j.global_position += Vector3(dv.x, 0, dv.z).normalized() * 3.0 * DT
			# détection de l'attaque ennemie
			if d.etat == d.ATTAQUE:
				if t_vu_attaque < 0.0: t_vu_attaque = t
			else:
				t_vu_attaque = -1.0
			if mode == "garde":
				var lever: bool = d.etat == d.ATTAQUE and t_vu_attaque >= 0.0 and t - t_vu_attaque >= 0.25
				if lever and garde_t <= 0.0: garde_t = 0.45
			elif mode == "parade":
				if d.etat == d.ATTAQUE:
					var duree: float = d._duree(d._attaque) / d._rythme
					if d._t >= duree * 0.42 - 0.07 and garde_t <= 0.0: garde_t = 0.6
			if garde_t > 0.0:
				mains.entrees.forcer_garde(0.1); garde_t -= DT
			else:
				mains.entrees.forcer_garde(0.0)
			# clics
			if mode != "passif" and (mode == "spam" or garde_t <= 0.0):
				if dist < 2.4 and t - t_clic > 0.30:
					mains.entrees.appuyer(); clics += 1; t_clic = t
					await _pas(2)
					mains.entrees.relacher()
					t += 2 * DT
					continue
			if j.vie < vie_prec - 0.01:
				coups_recus += 1; t_coups.append(snappedf(t, 0.1))
			vie_prec = j.vie
			min_end = minf(min_end, j.vigueur)
			if t_premier_hit < 0.0 and d.vie < v_ennemi0 - 0.1: t_premier_hit = t
			await _pas(1)
			t += DT
		var vivant: bool = is_instance_valid(d) and d.etat != d.MORT
		var r := "RESULTAT pv_ennemi=%.0f mode=%s type=%s essai=%d duree=%.1fs ennemi=%s vie_joueur_perdue=%.0f/%.0f clics=%d parades=%d endurance_min=%.0f 1er_hit=%.1fs coups_recus=%d a_t=%s" % [v_ennemi0, mode, type, essai, t, "VIVANT" if vivant else "mort", vie0 - j.vie, j.vie_max, clics, mains.defense.nb_parades - parades_avant, min_end, t_premier_hit, coups_recus, str(t_coups)]
		print(r)
		total.append(t)
		if is_instance_valid(d):
			d.queue_free()
		await _pas(30)
		if film and lab: lab.text = "bot %s vs %s - essai %d : %s" % [mode, type, essai + 1, "ok" if not vivant else "?"]
	quit()
