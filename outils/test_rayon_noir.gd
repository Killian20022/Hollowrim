extends SceneTree
## Test sans fenêtre du RAYON NOIR (sort continu des ténèbres : data/sorts/rayon_noir.tres, scripts/magie/rayon_noir.gd ;
## docs/MAGIE.md, « Rayon noir ») :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_rayon_noir.gd -- --nouvelle
## Sort connu (raccourci Y), coût par seconde FAIBLE (≤ les autres jets continus), dégâts par tic de 0,2 s, corruption posée, petit
## drain, arrêt au mur (rien derrière), arrêt au PREMIER ennemi (celui de derrière n'est pas touché), fin au relâchement (rayon
## éteint, plus de mana dépensé), fin à mana 0 (« Mana épuisé. »), double incantation, inertie de la visée, visuel créé / libéré.

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: MainSort

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _sim(t: float) -> void:
	for i in maxi(1, roundi(t / DT)):
		mains.avancer(DT)
		await physics_frame

func _reset(pos := Vector3(0, 0, 1.2), lacet := 0.0) -> void:
	for m in ["gauche", "droite"]:
		magie._couper(m, false)
		magie.inc[m].changer(Incantation.REPOS)
		magie.inc[m].tenu = false
		magie.inc[m].tampon = -1.0
	magie.recharges.clear()
	magie.lanceur.journal.clear()
	j.mana = j.mana_max
	j.vie = j.vie_max
	for m in [s.mannequin, s.mannequin2, s.mannequin3]:
		m.total = 0.0
		m.coups.clear()
		var st := Statuts.de(m, false)
		if st != null:
			st.actifs.clear()
			st.recharge_reaction = 0.0
	s.placer_joueur(pos, lacet)
	await _sim(0.5)

func _coups_rayon() -> Array:
	return magie.lanceur.journal.filter(func(e: Dictionary) -> bool: return String(e.sort) == RayonNoir.ID)

func _draugr(p: Vector3, type := "guerrier") -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(s.DRAUGR)
	d.type = type
	d.joueur = j
	d.hud = s.hud
	d.ident = "rn_%s_%d" % [type, randi() % 100000]
	d.position = p
	d.rotation.y = atan2(j.global_position.x - p.x, j.global_position.z - p.z)
	s.add_child(d)
	d.set_physics_process(false)
	return d

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	magie = mains.magie
	mains.pas_manuel = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 20:
		await physics_frame
	await _donnees()
	await _cout_degats()
	await _mur()
	await _premier_ennemi()
	await _relachement()
	await _mana_zero()
	await _double()
	await _inertie()
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

# ------------------------------------------------------------------ données

func _donnees() -> void:
	var sd := magie.eq.sort_par_id(RayonNoir.ID)
	_verif(RayonNoir.actif and sd != null, "rayon noir : sort présent (data/sorts/rayon_noir.tres)")
	if sd == null:
		return
	_verif(sd.ecole == "tenebres" and sd.canalise() and sd.portee_mode == DonneesSort.Portee.JET and sd.forme == RayonNoir.FORME, "rayon noir : ténèbres, CANALISE, portée JET, forme « rayon_noir »")
	_verif(magie.eq.sorts_connus.has(RayonNoir.ID), "rayon noir : dans les sorts de départ (inventaire.json)")
	var autres := []
	for id in ["jet_flammes", "souffle_givre", "arc_electrique", "drain_vie"]:
		autres.append(magie.eq.sort_par_id(id).cout_par_seconde)
	_verif(sd.cout_par_seconde <= (autres.min() as float) and sd.cout_par_seconde >= 6.0, "coût FAIBLE : %.1f mana/s (autres jets continus : %s)" % [sd.cout_par_seconde, str(autres)])
	_verif(sd.statut == "corruption" and sd.traverse == 0 and is_zero_approx(sd.drain) and sd.portee >= 35.0, "v3 : corruption, premier ennemi (traverse 0), PAS de drain, portée longue (%.0f m)" % sd.portee)
	_verif(InputMap.has_action(RayonNoir.ID), "raccourci de test « rayon_noir » (touche Y)")
	magie.equiper("gauche", "vide")
	magie.raccourci_sort_gauche(RayonNoir.ID)
	_verif(String(magie.eq.mains["gauche"].get("id")) == RayonNoir.ID, "touche Y : rayon noir dans la main gauche")
	magie.raccourci_sort_gauche(RayonNoir.ID)
	_verif(String(magie.eq.mains["gauche"].get("id")) != RayonNoir.ID, "touche Y : second appui, la main d'avant revient")
	_verif(IconesCombat.connu(RayonNoir.ID), "icône du HUD « rayon_noir »")

# ------------------------------------------------------------------ coût, dégâts par tic, statut, drain

func _cout_degats() -> void:
	magie.equiper("droite", "vide")
	magie.equiper("gauche", RayonNoir.ID)
	await _reset()   # face au mannequin (0, 0, -1,75)
	var sd := magie.eq.sort("gauche")
	j.vie = 50.0
	var m0: float = j.mana
	var crees0 := int(RayonNoir.stats.crees)
	magie.appuyer("gauche")
	await _sim(sd.incantation + 0.05)
	var m1: float = j.mana
	await _sim(1.0)
	var par_s: float = m1 - j.mana
	_verif(magie.inc["gauche"].etat == Incantation.CANALISE, "maintenu : canalisation")
	_verif(absf(par_s - sd.cout_par_seconde) < 1.0, "coût par seconde : %.2f mana en 1 s (attendu %.1f)" % [par_s, sd.cout_par_seconde])
	var coups := _coups_rayon()
	var sur_m := coups.filter(func(e: Dictionary) -> bool: return e.cible == s.mannequin)
	_verif(sur_m.size() >= 4 and sur_m.size() <= 7, "tics de 0,2 s : %d coups sur le mannequin en ~1,1 s" % sur_m.size())
	var q := float(sur_m[0].degats) if not sur_m.is_empty() else 0.0
	_verif(absf(q - sd.degats * LanceurSorts.TIC_CANAL) < 0.6 and bool(sur_m[0].continu) if not sur_m.is_empty() else false, "dégâts par tic : %.2f (%.0f /s × 0,2 s), coup continu" % [q, sd.degats])
	_verif(s.mannequin.total > 10.0, "le mannequin encaisse (%.1f dégâts)" % s.mannequin.total)
	_verif(Statuts.a(s.mannequin, "corruption"), "statut « corruption » posé sur la cible")
	_verif(is_zero_approx((load("res://data/sorts/rayon_noir.tres") as DonneesSort).drain), "v3 : pas de drain (vie %.2f)" % j.vie)
	_verif(int(RayonNoir.stats.crees) > crees0 and RayonNoir.existe(magie._p("gauche")), "visuel : un RayonNoir tenu pour la main gauche")
	var b: Dictionary = magie.lanceur.derniers_bouts.get("gauche", {})
	_verif(b.get("cible") == s.mannequin, "le rayon s'arrête sur la cible visée (bout = mannequin)")
	magie.relacher("gauche")
	await _sim(0.3)
	print("       mana dépensé : %.1f ; dégâts : %.1f ; vie : %.2f" % [m0 - j.mana, s.mannequin.total, j.vie])

# ------------------------------------------------------------------ arrêt au mur

func _mur() -> void:
	# joueur en (0, 0, 1), regard vers -X : le mur (x = -3,05) ; un draugr DERRIÈRE le mur (x = -5)
	await _reset(Vector3(0, 0, 1.0), 90.0)
	var derriere := _draugr(Vector3(-5.0, 0.0, 1.0))
	var v0: float = derriere.vie
	magie.appuyer("gauche")
	await _sim(0.9)
	var b: Dictionary = magie.lanceur.derniers_bouts.get("gauche", {})
	var p: Vector3 = b.get("point", Vector3.INF)
	_verif(bool(b.get("decor", false)) and b.get("cible") == null and absf(p.x - (-3.05)) < 0.15, "arrêt au mur : bout du rayon sur le mur (x = %.2f)" % p.x)
	_verif(absf(derriere.vie - v0) < 0.01, "rien derrière le mur n'est touché (draugr : %.0f → %.0f)" % [v0, derriere.vie])
	magie.relacher("gauche")
	await _sim(0.3)
	derriere.queue_free()

# ------------------------------------------------------------------ premier ennemi

func _premier_ennemi() -> void:
	# deux draugrs en file devant le joueur (regard +X, rien d'autre sur la ligne) : seul le premier prend les tics
	await _reset(Vector3(0, 0, 3.0), -90.0)
	var a := _draugr(Vector3(3.0, 0.0, 3.0), "squelette")
	var b := _draugr(Vector3(6.0, 0.0, 3.0), "guerrier")
	await _sim(0.1)
	var va: float = a.vie
	var vb: float = b.vie
	magie.appuyer("gauche")
	await _sim(1.0)
	var bout: Dictionary = magie.lanceur.derniers_bouts.get("gauche", {})
	_verif(a.vie < va - 3.0, "premier ennemi touché (squelette : %.0f → %.0f)" % [va, a.vie])
	_verif(absf(b.vie - vb) < 0.01, "le second, derrière lui, n'est pas touché (draugr : %.0f → %.0f)" % [vb, b.vie])
	_verif(bout.get("cible") == a, "le rayon s'arrête sur le premier ennemi")
	_verif(Statuts.a(a, "corruption"), "corruption posée sur le squelette")
	magie.relacher("gauche")
	await _sim(0.3)
	a.queue_free()
	b.queue_free()

# ------------------------------------------------------------------ fin au relâchement

func _relachement() -> void:
	await _reset()
	magie.appuyer("gauche")
	await _sim(0.6)
	var arrets := int(RayonNoir.stats.arrets)
	magie.relacher("gauche")
	await _sim(0.1)
	var m1: float = j.mana
	var t1: float = s.mannequin.total
	await _sim(0.6)
	_verif(magie.inc["gauche"].etat != Incantation.CANALISE, "relâcher : fin de la canalisation")
	_verif(not RayonNoir.existe(magie._p("gauche")) and int(RayonNoir.stats.arrets) > arrets, "relâcher : le rayon s'éteint (se dissipe)")
	_verif(j.mana >= m1 - 0.01, "relâcher : plus de mana dépensé (%.1f → %.1f)" % [m1, j.mana])
	_verif(absf(s.mannequin.total - t1) < 0.01, "relâcher : plus de dégâts")

# ------------------------------------------------------------------ fin à mana 0

func _mana_zero() -> void:
	await _reset()
	j.mana = 4.0
	magie.appuyer("gauche")
	await _sim(1.2)
	_verif(magie.inc["gauche"].etat != Incantation.CANALISE, "mana à 0 : la canalisation s'arrête seule (mana %.2f)" % j.mana)
	_verif(String(magie.refus["gauche"]).contains("Mana épuisé"), "mana à 0 : refus expliqué (« %s »)" % magie.refus["gauche"])
	_verif(not RayonNoir.existe(magie._p("gauche")), "mana à 0 : le rayon s'éteint")
	magie.relacher("gauche")
	await _sim(0.3)

# ------------------------------------------------------------------ double incantation

func _double() -> void:
	magie.equiper("droite", RayonNoir.ID)
	magie.equiper("gauche", RayonNoir.ID)
	await _reset()
	var sd := magie.eq.sort("gauche")
	var m0: float = j.mana
	magie.appuyer("gauche")
	magie.appuyer("droite")
	await _sim(sd.incantation + 0.05)
	var m1: float = j.mana
	await _sim(1.0)
	var par_s: float = m1 - j.mana
	var dbl: bool = magie.inc["gauche"].double or magie.inc["droite"].double
	_verif(dbl, "double incantation : les deux mains fusionnent")
	_verif(absf(par_s - sd.cout_par_seconde * float(sd.double.cout)) < 2.0, "double : %.1f mana/s (×%.1f)" % [par_s, float(sd.double.cout)])
	var coups := _coups_rayon()
	var maxi := 0.0
	for e in coups:
		maxi = maxf(maxi, float(e.degats))
	_verif(absf(maxi - sd.degats * float(sd.double.degats) * LanceurSorts.TIC_CANAL) < 0.8, "double : tic de %.2f (dégâts ×%.1f)" % [maxi, float(sd.double.degats)])
	var n_rayons := 0
	for p in ["gauche", "droite"]:
		if RayonNoir.existe(magie._p(p)):
			n_rayons += 1
	_verif(n_rayons == 1, "double : UN seul rayon (%d)" % n_rayons)
	magie.relacher("gauche")
	magie.relacher("droite")
	await _sim(0.4)
	print("       double : %.1f mana en %.2f s" % [m0 - j.mana, sd.incantation + 1.05])
	magie.equiper("droite", "vide")

# ------------------------------------------------------------------ inertie

func _inertie() -> void:
	magie.equiper("gauche", RayonNoir.ID)
	await _reset()
	magie.appuyer("gauche")
	await _sim(0.5)
	var d0: Vector3 = magie.lanceur._dir_lisse.get("gauche", Vector3.ZERO)
	j.rotation.y += deg_to_rad(20.0)
	await _sim(DT)
	var d1: Vector3 = magie.lanceur._dir_lisse.get("gauche", Vector3.ZERO)
	var vise: Vector3 = -j.camera.global_basis.z
	var retard := rad_to_deg(d1.angle_to(vise))
	_verif(retard > 5.0 and retard < 19.5 and d0 != Vector3.ZERO, "inertie : une image après un coup de 20°, le rayon a %.1f° de retard" % retard)
	await _sim(0.4)
	var d2: Vector3 = magie.lanceur._dir_lisse.get("gauche", Vector3.ZERO)
	_verif(rad_to_deg(d2.angle_to(-j.camera.global_basis.z)) < 1.0, "inertie : rattrapée en 0,4 s (%.2f°)" % rad_to_deg(d2.angle_to(-j.camera.global_basis.z)))
	magie.relacher("gauche")
	await _sim(0.3)
