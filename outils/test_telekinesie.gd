extends SceneTree
## Test sans fenêtre de la TÉLÉKINÉSIE (scripts/magie/telekinesie.gd ; docs/MAGIE.md, « Télékinésie ») :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_telekinesie.gd -- --nouvelle
## Sort équipable (école esprit), visée aidée, saisie (arrachement, coût), maintien (lévitation devant la main, drain de mana
## proportionnel à la masse), chute à mana 0, refus « Trop lourd. » / « Pas assez de mana. », lancer qui touche un draugr
## (dégâts > 0), arme saisissable (ObjetMonde et arme lâchée par un ennemi), arme lancée pointe en avant qui touche un squelette,
## geste capturé « lance » au relâchement, molette.

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: MainSort
var tk: Telekinesie
var sd: DonneesSort

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _sim(t: float) -> void:
	for i in roundi(t / DT):
		mains.avancer(DT)
		await physics_frame

func _viser_point(c: Vector3) -> void:
	for k in 3:
		var o: Vector3 = j.camera.global_position
		var d := c - o
		j.rotation.y = atan2(-d.x, -d.z)
		j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		await physics_frame

func _reset() -> void:
	for m in ["gauche", "droite"]:
		magie._couper(m, false)
		magie.inc[m].changer(Incantation.REPOS)
		magie.inc[m].tenu = false
	tk.tout_lacher()
	tk.journal.clear()
	tk.dernier_refus = ""
	tk._refus_t.clear()
	magie.journal.clear()
	j.mana = j.mana_max
	await _sim(0.4)

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	magie = mains.magie
	magie.eq.apprendre_tout()
	mains.pas_manuel = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 20:
		await physics_frame
	tk = magie.tk
	_verif(Telekinesie.actif and tk != null, "télékinésie installée (MainSort.tk)")
	sd = magie.eq.sort_par_id("telekinesie")
	_verif(sd != null and Telekinesie.est_sort(sd) and sd.canalise() and sd.ecole == "esprit", "sort « telekinesie » : canalisé, portée TELEKINESIE, école esprit")
	_verif(magie.eq.sorts_connus.has("telekinesie"), "sort connu (sorts de départ)")
	magie.equiper("droite", "epee")
	var r := magie.equiper("gauche", "telekinesie")
	_verif(r == "" and magie.eq.sort("gauche") == sd, "équipé main gauche (épée à droite) : %s" % ("ok" if r == "" else r))
	magie.raccourci_telekinesie()
	_verif(String(magie.eq.mains["gauche"].get("id")) != "telekinesie", "touche X : rend la main d'avant")
	magie.raccourci_telekinesie()
	_verif(String(magie.eq.mains["gauche"].get("id")) == "telekinesie", "touche X : télékinésie à gauche")
	await _saisie_maintien()
	await _refus()
	await _lancer_draugr()
	await _tps()
	await _armes()
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

# ------------------------------------------------------------------ saisie, maintien, drain, chute

func _saisie_maintien() -> void:
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0)
	var chaise := CorpsTelekinesie.creer("pq_chaise", s, Transform3D(Basis(), Vector3(0.4, 0.0, 1.2)))
	await _sim(1.0)
	await _reset()
	await _viser_point(Telekinesie.centre(chaise) + Vector3(0.25, 0.1, 0))   # un peu à côté : l'aide à la visée le prend
	var vise := tk.viser(j.camera.global_position, -j.camera.global_basis.z, sd.portee)
	_verif(vise == chaise, "visée aidée : la chaise est prise à côté du réticule")
	await _sim(0.3)
	_verif(tk.visee["gauche"] == chaise and tk._coques.has(chaise.get_instance_id()), "surbrillance de l'objet visé au repos")
	var y0 := chaise.global_position.y
	var m0: float = j.mana
	magie.appuyer("gauche")
	await _sim(0.4)
	_verif(tk.tient("gauche") and tk.objet_tenu("gauche") == chaise, "maintenir en visant : la chaise est saisie")
	var cout_att := sd.cout + sd.cout_par_kg * chaise.mass
	var paye: float = m0 - float(j.mana)
	_verif(paye >= cout_att * 0.95 and paye <= cout_att + 3.0, "arrachement payé : %.1f (attendu %.1f + drain)" % [paye, cout_att])
	_verif(chaise.global_position.y > y0 + 0.25, "arrachée du sol : +%.2f m" % (chaise.global_position.y - y0))
	_verif(chaise.gravity_scale == 0.0, "sans gravité pendant la tenue")
	var m1: float = j.mana
	await _sim(1.0)
	var drain: float = m1 - float(j.mana)
	var drain_att := sd.cout_par_seconde + sd.drain_par_kg * chaise.mass
	_verif(absf(drain - drain_att) < drain_att * 0.25, "drain continu ∝ masse : %.1f /s (attendu %.1f)" % [drain, drain_att])
	var e: Dictionary = tk.tenue["gauche"]
	var oeil: Vector3 = j.camera.global_position
	var dist := oeil.distance_to(chaise.global_position)
	_verif(dist > 1.3 and dist < 2.8, "lévite devant la main : %.2f m de l'œil" % dist)
	_verif(String(magie.gestes._etat["gauche"]["geste"]) == "jet", "geste capturé « jet » tenu pendant la saisie")
	# la tenue suit le regard (inertie) : on tourne la tête de 30°
	var avant_p := chaise.global_position
	j.rotation.y += deg_to_rad(30.0)
	await _sim(0.6)
	_verif(chaise.global_position.distance_to(avant_p) > 0.6, "suit le regard (%.2f m)" % chaise.global_position.distance_to(avant_p))
	# molette : éloigner
	var d0 := float(e["dist"])
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	magie.intercepter(ev)
	_verif(float(tk.tenue["gauche"]["dist"]) > d0, "molette : l'objet s'éloigne (%.2f -> %.2f m)" % [d0, float(tk.tenue["gauche"]["dist"])])
	# mana à zéro : l'objet tombe
	j.mana = 1.0
	await _sim(0.5)
	_verif(not tk.tient("gauche"), "mana épuisé : l'objet est lâché")
	_verif(magie.refus["gauche"] == "Mana épuisé.", "refus lisible : « %s »" % magie.refus["gauche"])
	_verif(chaise.gravity_scale == 1.0, "gravité rendue")
	var y1 := chaise.global_position.y
	await _sim(0.6)
	_verif(chaise.global_position.y < y1 - 0.2 or chaise.global_position.y < 0.6, "il retombe (%.2f -> %.2f m)" % [y1, chaise.global_position.y])
	magie.relacher("gauche")
	await _sim(0.3)
	chaise.queue_free()

# ------------------------------------------------------------------ refus

func _refus() -> void:
	await _reset()
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0)
	var lourd := CorpsTelekinesie.creer("pq_tonneau", s, Transform3D(Basis(), Vector3(0.0, 0.0, 1.5)), 90.0)
	await _sim(0.6)
	await _viser_point(Telekinesie.centre(lourd))
	magie.appuyer("gauche")
	await _sim(0.5)
	_verif(not tk.tient("gauche") and tk.dernier_refus == "Trop lourd.", "objet de 90 kg : « %s »" % tk.dernier_refus)
	magie.relacher("gauche")
	await _sim(0.4)
	lourd.queue_free()
	await _reset()
	var leger := CorpsTelekinesie.creer("pq_tabouret", s, Transform3D(Basis(), Vector3(0.0, 0.0, 1.8)))
	await _sim(0.6)
	await _viser_point(Telekinesie.centre(leger))
	j.mana = 5.0
	magie.appuyer("gauche")
	await _sim(0.4)
	_verif(not tk.tient("gauche") and tk.dernier_refus == "Pas assez de mana.", "mana insuffisant pour l'arrachement : « %s »" % tk.dernier_refus)
	magie.relacher("gauche")
	await _sim(0.4)
	leger.queue_free()

# ------------------------------------------------------------------ lancer sur un draugr

func _draugr(p: Vector3, type := "guerrier") -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(s.DRAUGR)
	d.type = type
	d.joueur = j
	d.hud = s.hud
	d.ident = "tk_" + type
	d.position = p
	d.rotation.y = atan2(p.x - j.global_position.x, p.z - j.global_position.z)
	s.add_child(d)
	d.set_physics_process(false)
	d.set_process(false)
	return d

func _lancer_draugr() -> void:
	await _reset()
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0)
	var d := _draugr(Vector3(2.8, 0.0, 0.2))   # hors de la ligne des mannequins de la scène
	var chaise := CorpsTelekinesie.creer("pq_chaise", s, Transform3D(Basis(), Vector3(-0.3, 0.0, 2.6)))
	await _sim(1.0)
	await _viser_point(Telekinesie.centre(chaise))
	magie.appuyer("gauche")
	await _sim(1.3)
	_verif(tk.tient("gauche"), "chaise tenue avant le lancer")
	await _viser_point(Elements._centre(d) + Vector3(0.35, 0.0, 0.0))   # à côté du centre : l'aide au lancer le prend
	var vie0: float = d.vie
	magie.relacher("gauche")
	await _sim(0.05)
	_verif(not tk.tient("gauche") and chaise.linear_velocity.length() > 8.0, "relâcher : lancé à %.1f m/s" % chaise.linear_velocity.length())
	_verif(String(magie.gestes._etat["gauche"]["geste"]) == "lance", "geste capturé « lance » au relâchement")
	var touche := false
	for k in 90:
		await _sim(DT)
		if d.vie < vie0:
			touche = true
			break
	_verif(touche, "le draugr est touché : %.1f -> %.1f PV" % [vie0, d.vie])
	var t_imp := tk.journal.filter(func(x): return String(x[1]).begins_with("suivi ImpactsLances"))
	_verif(not t_imp.is_empty(), "lancer suivi par ImpactsLances.suivre (pas de détection en double)")
	_verif(not tk.journal.any(func(x): return String(x[1]).begins_with("repli")), "aucun dégât de repli quand ImpactsLances existe")
	await _sim(1.0)
	d.queue_free()
	chaise.queue_free()

# ------------------------------------------------------------------ 3e personne

func _tps() -> void:
	await _reset()
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0)
	j.basculer_vue(true)
	await _sim(0.5)
	var tab := CorpsTelekinesie.creer("pq_tabouret", s, Transform3D(Basis(), Vector3(0.2, 0.0, 1.6)))
	await _sim(0.6)
	await _viser_point(Telekinesie.centre(tab))
	var vue: Array = magie._vue()
	var vise := tk.viser(vue[0], vue[1], sd.portee)
	_verif(vise == tab, "3e personne : visée depuis la caméra à l'épaule")
	magie.appuyer("gauche")
	await _sim(0.8)
	_verif(tk.tient("gauche"), "3e personne : saisie")
	var e: Dictionary = tk.tenue["gauche"]
	_verif(e.get("paume") == magie._p("gauche"), "3e personne : le fil part de la paume utilisée par les effets (%s)" % str(magie.paumes_effets["gauche"] != null))
	magie.relacher("gauche")
	await _sim(0.4)
	_verif(not tk.tient("gauche"), "3e personne : lancé au relâchement")
	j.basculer_vue(false)
	await _sim(0.4)
	tab.queue_free()

# ------------------------------------------------------------------ armes

func _armes() -> void:
	await _reset()
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0)
	var o := ObjetMonde.creer("epee_soldat", 1)
	s.add_child(o)
	o.global_position = Vector3(0.3, 0.0, 2.4)
	_verif(o.is_in_group(Telekinesie.GROUPE) and o.donnees_arme() != null, "arme posée (ObjetMonde) : groupe telekinesable + donnees_arme()")
	# arme lâchée par un ennemi mort : visuel « ArmeSol » d'un butin
	var b := Node3D.new()
	var gs := GDScript.new()
	gs.source_code = "extends Node3D\nvar contenu := {}\nvar joueur\nvar dialogue\n"
	gs.reload()
	b.set_script(gs)
	s.add_child(b)
	b.global_position = Vector3(-2.0, 0.0, 2.0)
	b.set("contenu", {"hache_guerre": 1})
	var v := ArmesEnnemis.poser_au_sol(b, "hache_guerre", Vector3.ZERO, 0.3)
	_verif(v.is_in_group(Telekinesie.GROUPE) and v.has_meta("tk_arme"), "arme lâchée par un ennemi : saisissable (meta tk_arme)")
	var squelette := _draugr(Vector3(-2.8, 0.0, 0.4), "squelette")
	await _sim(1.0)
	await _viser_point(Telekinesie.centre(o))
	magie.appuyer("gauche")
	await _sim(1.3)
	var a := tk.objet_tenu("gauche")
	_verif(a is ArmeLancee and (a as ArmeLancee).donnees_arme() != null, "épée saisie : changée en ArmeLancee (%s)" % (a.name if a != null else "rien"))
	_verif(not is_instance_valid(o) or o.is_queued_for_deletion(), "la source au sol a disparu (pas de double)")
	if a == null:
		return
	await _viser_point(Elements._centre(squelette))
	var vie0: float = squelette.vie
	magie.relacher("gauche")
	await _sim(0.1)
	var vel := a.linear_velocity
	_verif(vel.length() > 12.0, "épée lancée à %.1f m/s (légère : plus vite)" % vel.length())
	_verif(a.global_basis.y.normalized().dot(vel.normalized()) > 0.9, "elle vole pointe en avant (%.2f)" % a.global_basis.y.normalized().dot(vel.normalized()))
	var touche := false
	for k in 60:
		await _sim(DT)
		if squelette.vie < vie0:
			touche = true
			break
	_verif(touche, "le squelette est touché par l'épée : %.1f -> %.1f PV" % [vie0, squelette.vie])
	# arme du butin : saisie -> sortie du contenu du corps
	await _reset()
	await _viser_point(Telekinesie.centre(v))
	magie.appuyer("gauche")
	await _sim(0.5)
	var h := tk.objet_tenu("gauche")
	_verif(h is ArmeLancee and not (b.get("contenu") as Dictionary).has("hache_guerre"), "hache du corps saisie et retirée de son butin")
	magie.relacher("gauche")
	await _sim(1.5)
	if h != null and is_instance_valid(h):
		_verif(ImpactsLances.plantee(h) or h.linear_velocity.length() < 1.0, "l'arme lancée finit plantée ou posée (%s)" % ("plantée" if ImpactsLances.plantee(h) else "posée"))
