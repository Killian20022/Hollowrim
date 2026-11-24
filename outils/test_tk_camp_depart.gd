extends SceneTree
## TÉLÉKINÉSIE PARTOUT, camp de départ (2026-11-24) : les réserves du bivouac à côté de la tente (tonneaux, caisse, cageot, sac, seau) et les
## troncs-bancs sont des objets physiques « telekinesable » ET cassables (règle unique ObjetsVivants.mobile) ; la tente et le foyer restent fixes.
##   godot --headless --path . --script res://outils/test_tk_camp_depart.gd -- --nouvelle

const SCENE := preload("res://scenes/foret_test.tscn")

var _ok := true
var _n := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _tester() -> void:
	# la règle elle-même
	for id in ["pq_tonneau", "pq_caisse", "pq_cageot_vide", "pq_sac", "pq_seau_bois", "q_tronc", "pq_marmite_camp", "q_rondin", "q_hache_camp", "q_buche"]:
		_verif(ObjetsVivants.mobile(id), "règle : %s est mobile" % id)
	for id in ["q_tente", "q_grande_table", "q_etal", "q_lit", "q_puits", "q_chariot", "q_poutre_ronde", "q_porte", "q_etabli", "q_roc_1", "q_souche", "q_feu_bois", "q_brique_1", "q_barriere_bois", "pq_bougie_1", "q_enclume"]:
		_verif(not ObjetsVivants.mobile(id), "règle : %s reste fixe" % id)
	var s: Node3D = SCENE.instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	for i in 1800:
		await process_frame
		if s.village != null and s.village.get("prets") == true:
			break
	for i in 30:
		await physics_frame
	var camp: Array[ObjetVivant] = []
	for o: ObjetVivant in ObjetsVivants._vivants():
		if o.ident.begins_with("camp:"):
			camp.append(o)
	var genres := {}
	for o in camp:
		genres[o.genre] = int(genres.get(o.genre, 0)) + 1
	print("INFO   objets du camp : ", genres)
	for base in ["tonneau", "caisse", "cageot_vide", "sac", "seau_bois", "tronc"]:
		var trouve: ObjetVivant = null
		for o in camp:
			if o.genre.ends_with(base):
				trouve = o
				break
		_verif(trouve != null, "camp : %s présent comme objet physique" % base)
		if trouve == null:
			continue
		_verif(trouve.is_in_group("telekinesable"), "camp : %s est telekinesable" % base)
		_verif(trouve.seuil_casse < INF, "camp : %s est cassable (seuil %.0f J, matière %s)" % [base, trouve.seuil_casse, trouve.matiere])
		_verif(trouve.freeze, "camp : %s dort (gelé)" % base)
		_verif(trouve.mass <= 60.0, "camp : %s saisissable (%.1f kg <= 60)" % [base, trouve.mass])
	# les fixes ne sont pas des objets vivants
	var tente := false
	for o in camp:
		if o.genre.contains("tente") or o.genre.contains("brique") or o.genre.contains("feu_bois"):
			tente = true
	_verif(not tente, "camp : tente, briques et bûches du foyer restent du décor fixe")
	# un tonneau lancé contre un mur se casse ; un coup d'épée léger ne casse pas un tonneau
	var t: ObjetVivant = null
	for o in camp:
		if o.genre.ends_with("tonneau"):
			t = o
			break
	if t != null:
		_verif(not t.recevoir_choc(Vector3(2, 0, 0), t.mass, t.global_position), "tonneau du camp : petit choc sans casse")
		t.reveiller(true)
		_verif(t.recevoir_choc(Vector3(9, 0, 0), t.mass, t.global_position) and t.casse, "tonneau du camp lancé à 9 m/s : brisé")
		for i in 3:
			await physics_frame
		_verif(CasseObjets.nb_eclats() > 0, "tonneau du camp brisé : %d éclats physiques" % CasseObjets.nb_eclats())
	# aucun saisissable incassable (hors métal solide et papier/livres : incassables au lancer par choix de casse_realiste, ils rebondissent)
	var incassables := {}
	for n in get_nodes_in_group("telekinesable"):
		if n is ObjetVivant and (n as ObjetVivant).seuil_casse == INF and (n as ObjetVivant).matiere not in ["fer", "papier"]:
			var k := "%s [%s]" % [(n as ObjetVivant).genre, (n as ObjetVivant).matiere]
			incassables[k] = int(incassables.get(k, 0)) + 1
		elif n is Cassable and (n as Cassable).genre == "objet" and CasseObjets.seuil((n as Cassable).matiere_objet) == INF and (n as Cassable).matiere_objet not in ["fer", "papier"]:
			incassables["objet"] = int(incassables.get("objet", 0)) + 1
	_verif(incassables.is_empty(), "aucun saisissable incassable hors métal solide (%s)" % str(incassables))
	print("ECHECS : %d" % (0 if _ok else 1))
	print("RESULTAT ", "OK" if _ok else "ECHEC", " (%d vérifications)" % _n)
	quit(0 if _ok else 1)
