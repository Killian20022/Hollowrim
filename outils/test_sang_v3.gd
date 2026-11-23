extends SceneTree
## Test sans fenêtre du SANG V3 (combat/sang_v3, docs/SANG_V3.md) dans scenes/test_combat.tscn :
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_sang_v3.gd -- --nouvelle
## - API inchangée : signatures publiques de Sang (giclee, jet, flaque, trace, tacher_voisins, eclats_matiere, sol_sous) + ajouts ;
## - pools plafonnés : émetteurs de giclées (POOL_*), traces (MAX_TRACES_V3), gouttes en vol (MAX_V3), suivis de traînée ;
## - variantes par créature : vif / draugr (noirâtre) / troll / araignée ; squelette = pas de sang (aucune trace) ;
## - traversée : entrée + sortie, gouttes balistiques qui tachent un mur derrière la cible ; trace projetée sur un relief ;
## - neige : matériau de neige (liseré) ; arme plantée ensanglantée (SangLame.ensanglanter) ; gore à 0 : rien.

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")

var s: Node3D
var echecs := 0
var _n := 0

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _frames(n: int) -> void:
	for k in n:
		await physics_frame

func _ennemi(pos: Vector3) -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "guerrier"
	d.joueur = s.joueur
	d.hud = s.hud
	d.ident = "test_sang_v3_%d" % _n
	d.position = pos
	s.add_child(d)
	d.vie = 3000.0
	d.vie_max = 3000.0
	d.combat.profil.chance_blocage = 0.0
	return d

## Signature d'une méthode statique d'un script : [nom des arguments], nombre d'arguments par défaut.
func _signature(script: Script, nom: String) -> Dictionary:
	for m: Dictionary in script.get_script_method_list():
		if m["name"] == nom:
			var noms := []
			for a: Dictionary in m["args"]:
				noms.append(a["name"])
			return {"args": noms, "defauts": (m["default_args"] as Array).size()}
	return {}

func _boite(pos: Vector3, taille: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = taille
	cs.shape = sh
	b.add_child(cs)
	s.add_child(b)
	b.position = pos
	b.rotation = rot
	return b

func _lancer() -> void:
	Sang.niveau_force = 2
	ok(SangV3.actif, "sang v3 actif (sans --sans-sang-v3)")
	# ---- API inchangée (les anciens arguments, dans le même ordre, et autant ou plus de valeurs par défaut)
	var S: Script = load("res://scripts/combat/sang.gd")
	var attendu := {
		"giclee": ["n", "point", "direction", "intensite", "couleur", "traces"],
		"jet": ["attache", "local", "couleur", "duree"],
		"flaque": ["n", "pos", "couleur", "taille", "croissance"],
		"trace": ["n", "pos", "normale", "direction", "taille", "couleur", "sorte", "croissance", "delai"],
		"tacher_voisins": ["source", "point", "direction", "intensite", "couleur"],
		"eclats_matiere": ["n", "point", "direction", "intensite", "couleur"],
		"sol_sous": ["n", "pos", "haut", "bas"],
	}
	for nom: String in attendu:
		var sg := _signature(S, nom)
		var a: Array = attendu[nom]
		ok(not sg.is_empty() and (sg["args"] as Array).slice(0, a.size()) == a, "API inchangée : Sang.%s(%s)" % [nom, ", ".join(a)])
	for nom in ["traversee", "sortie", "trainee_corps", "saigner"]:
		ok(not _signature(S, nom).is_empty(), "ajout : Sang.%s" % nom)
	ok(not _signature(load("res://scripts/combat/gouttes_sang.gd"), "lacher").is_empty() and not _signature(load("res://scripts/combat/gouttes_sang.gd"), "lacher_balistique").is_empty(), "GouttesSang.lacher inchangé + lacher_balistique")
	ok(not _signature(load("res://scripts/combat/sang_lame.gd"), "ensanglanter").is_empty(), "ajout : SangLame.ensanglanter")
	# ---- variantes par créature
	var vif := ProfilCible.pour("bandit").couleur_sang
	var dr := ProfilCible.pour("draugr").couleur_sang
	ok(SangV3.sorte_sang(vif) == "vif", "bandit : sang vif")
	ok(SangV3.sorte_sang(dr) == "draugr", "draugr : sang de draugr")
	ok(SangV3.sorte_sang(ProfilCible.pour("draugr_guerrier").couleur_sang) == "draugr", "draugr guerrier : sang de draugr")
	var cd := SangV3.couleur(dr)
	ok(cd.v < 0.14 and cd.r < 0.13, "sang de draugr noirâtre (%s)" % cd)
	var cv := SangV3.couleur(vif)
	ok(cv.r > 0.3 and cv.r < 0.5 and cv.g < 0.06, "sang vif rouge sombre, pas fluo (%s)" % cv)
	ok(SangV3.sorte_sang(Color(0.24, 0.045, 0.07)) == "troll", "troll : sang violacé")
	ok(SangV3.sorte_sang(Color(0.22, 0.28, 0.08)) == "araignee", "araignée : sang verdâtre")
	ok(Sang.matiere_de(ProfilCible.pour("squelette").couleur_sang) == "os", "squelette : poussière d'os, pas de sang")
	# ---- scène
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	await _frames(20)
	var a := _ennemi(Vector3(0, 0, -2.0))
	a.set_physics_process(false)
	var mur := _boite(Vector3(0, 1.5, -4.2), Vector3(4, 3, 0.3))
	await _frames(10)
	var point := a.global_position + Vector3(0, 1.2, 0)
	# squelette : la giclée appelée avec sa couleur (os) ne laisse aucune trace de sang
	var t0 := Sang.nombre_traces(s)
	Sang.giclee(a, point, Vector3.FORWARD, 2.0, ProfilCible.pour("squelette").couleur_sang)
	await _frames(60)
	ok(Sang.nombre_traces(s) == t0, "squelette : aucune trace de sang (%d → %d)" % [t0, Sang.nombre_traces(s)])
	# traversée : l'objet entre côté joueur et sort dans le dos (vers le mur)
	var g0 := GouttesSang.lachees
	Sang.traversee(a, point + Vector3(0, 0, 0.25), point - Vector3(0, 0, 0.25), Vector3.FORWARD, 2.5, dr)
	await _frames(5)
	ok(GouttesSang.lachees > g0, "traversée : des gouttes balistiques partent (%d)" % (GouttesSang.lachees - g0))
	await _frames(90)
	var sur_mur := 0
	var gestion := Sang.gestion(s)
	for tr: Node in gestion.get_meta("traces"):
		if is_instance_valid(tr) and absf((tr as Node3D).global_position.z - (-4.05)) < 0.12:
			sur_mur += 1
	ok(sur_mur >= 1, "traversée : éclaboussures sur le mur derrière la cible (%d)" % sur_mur)
	var mat_ok := false
	for tr: Node in gestion.get_meta("traces"):
		if is_instance_valid(tr) and (tr as MeshInstance3D).material_override is ShaderMaterial:
			var m := (tr as MeshInstance3D).material_override as ShaderMaterial
			var fr: Color = m.get_shader_parameter("frais")
			mat_ok = fr.r < 0.13
	ok(mat_ok, "traces du draugr : couleur noirâtre")
	# pools plafonnés
	for k in 40:
		Sang.giclee(a, point, Vector3(randf_range(-1, 1), 0, -1), 3.0, vif)
		if k % 8 == 0:
			await _frames(1)
	await _frames(2)
	ok(gestion.get_meta("pool_jet", []).size() <= SangV3.POOL_JET, "pool de jets plafonné (%d ≤ %d)" % [gestion.get_meta("pool_jet", []).size(), SangV3.POOL_JET])
	ok(gestion.get_meta("pool_gouttelettes", []).size() <= SangV3.POOL_GOUTTELETTES, "pool de gouttelettes plafonné")
	ok(gestion.get_meta("pool_brume", []).size() <= SangV3.POOL_BRUME, "pool de brume plafonné")
	var gp := 0
	for c in root.find_children("*", "GPUParticles3D", true, false):
		if String(c.name).begins_with("Giclee_"):
			gp += 1
	ok(gp <= SangV3.POOL_JET + SangV3.POOL_GOUTTELETTES + SangV3.POOL_BRUME, "aucun émetteur créé au-delà des pools (%d)" % gp)
	ok(GouttesSang.en_vol() <= GouttesSang.MAX_V3, "gouttes en vol plafonnées (%d ≤ %d)" % [GouttesSang.en_vol(), GouttesSang.MAX_V3])
	ok(gp > 0, "les giclées passent par les pools (%d émetteurs)" % gp)
	# coût CPU d'une giclée (ressources déjà prêtes) : émetteurs du pool + gouttes + rayons des traces
	await _frames(30)
	var c0 := Sang.cout_us
	for k in 10:
		Sang.giclee(a, point, Vector3(randf_range(-1, 1), -0.1, -1), 2.2, vif)
		await _frames(3)
	var par := (Sang.cout_us - c0) / 10.0 / 1000.0
	print("  coût CPU d'une giclée : %.2f ms" % par)
	ok(par < 1.5, "giclée v3 : coût CPU raisonnable (%.2f ms < 1,5 ms)" % par)
	await _frames(120)
	ok(Sang.nombre_traces(s) <= Sang.MAX_TRACES_V3, "traces plafonnées (%d ≤ %d)" % [Sang.nombre_traces(s), Sang.MAX_TRACES_V3])
	# relief : une trace posée sur une marche épouse la surface (grille), sur le sol plat : plan partagé
	var marche := _boite(Vector3(3.0, 0.06, 0.0), Vector3(0.6, 0.12, 2.0))
	await _frames(3)
	var t_marche := Sang.trace(s, Vector3(3.3, 0.0, 0.0), Vector3.UP, Vector3.RIGHT, 0.5, vif, "flaque")
	var t_plat := Sang.trace(s, Vector3(-3.0, 0.0, 2.0), Vector3.UP, Vector3.RIGHT, 0.5, vif, "flaque")
	ok(t_marche != null and not (t_marche.mesh is PlaneMesh), "trace sur une marche : maillage projeté (épouse le relief)")
	ok(t_plat != null and t_plat.mesh is PlaneMesh, "trace sur sol plat : plan partagé (aucun maillage neuf)")
	# neige : matériau à liseré
	EffetsSol.forcer_neige = true
	var t_neige := Sang.trace(s, Vector3(-2.0, 0.0, 3.0), Vector3.UP, Vector3.RIGHT, 0.4, vif, "giclure")
	EffetsSol.forcer_neige = false
	ok(t_neige != null and float((t_neige.material_override as ShaderMaterial).get_shader_parameter("neige")) == 1.0, "sang sur la neige : liseré de sang dilué")
	ok(t_plat != null and float((t_plat.material_override as ShaderMaterial).get_shader_parameter("neige")) == 0.0, "hors neige : pas de liseré")
	# séchage / effacement : les uniformes d'instance avancent
	ok(t_plat.get_instance_shader_parameter("seche") == 0.0, "trace fraîche au départ")
	# arme plantée ensanglantée
	var epee := EpeesLongues.instancier("metal")
	s.add_child(epee)
	epee.global_position = Vector3(1.0, 1.0, 1.0)
	await _frames(2)
	var sa := SangLame.ensanglanter(epee, 2.0, dr)
	ok(sa != null and sa.quantite > 0.1, "arme plantée : sang sur la lame (%.2f)" % (sa.quantite if sa else 0.0))
	ok(sa != null and sa.mat.shader.code.contains("sang_quantite") and sa.mat != SangLame.instance.mat, "arme plantée : matériau propre à l'arme (variante sang)")
	var sa2 := SangLame.ensanglanter(epee, 2.0, dr)
	ok(sa2 == sa and sa.quantite > 0.2, "deuxième traversée : le sang s'accumule sur la même arme")
	# traînée de corps
	var corps := Node3D.new()
	s.add_child(corps)
	corps.global_position = Vector3(-4, 0.1, -1)
	var tr0 := Sang.nombre_traces(s)
	ok(Sang.trainee_corps(corps, vif, 2.0) != null, "traînée : suivi créé")
	for k in 40:
		corps.global_position += Vector3(0.05, 0, 0)
		await physics_frame
	ok(Sang.nombre_traces(s) > tr0 or Sang.nombre_traces(s) >= Sang.MAX_TRACES_V3, "traînée : traces laissées par le corps qui glisse")
	for k in 5:
		Sang.trainee_corps(corps, vif, 2.0)
	await _frames(1)
	var suivis: Array = gestion.get_meta("suivis", []).filter(func(x: Variant) -> bool: return is_instance_valid(x) and not (x as Node).is_queued_for_deletion())
	ok(suivis.size() <= SangV3.MAX_SUIVIS, "suivis de traînée plafonnés (%d ≤ %d)" % [suivis.size(), SangV3.MAX_SUIVIS])
	# gore à 0 : rien
	Sang.niveau_force = 0
	var g1 := GouttesSang.lachees
	Sang.traversee(a, point, point - Vector3(0, 0, 0.3), Vector3.FORWARD, 2.0, vif)
	ok(GouttesSang.lachees == g1 and Sang.trace(s, Vector3.ZERO, Vector3.UP, Vector3.RIGHT, 0.3, vif) == null, "gore désactivé : ni goutte ni trace")
	ok(SangLame.ensanglanter(epee, 1.0, vif) == null, "gore désactivé : pas de sang sur l'arme")
	Sang.niveau_force = -1
	print("cout sang v3 cumulé : %.1f ms" % (Sang.cout_us / 1000.0))
	print("ECHECS : %d" % echecs)
	quit(1 if echecs > 0 else 0)
