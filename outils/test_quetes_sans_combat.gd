extends SceneTree
## Test sans fenêtre : les deux quêtes sans combat (data/quetes.json « grenier_maigre » et « fil_rouge », docs/ACCUEIL_ET_QUETES.md),
## jouées par le VRAI dialogue (dialogue.engager, choix de la dernière réplique), chaque fin l'une après l'autre (état remis entre
## deux fins) : indices dans le monde (serrure, trappe de la grange), heure (Ylva ne s'arrête que le soir), choix, journal par
## issue, récompenses, disposition des PNJ, répliques « après », causeries, repères de carte, sauvegarde (aller-retour JSON).
##   godot --headless --path . --script res://outils/test_quetes_sans_combat.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node
var q: Node
var d: Control
var bon := true

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	bon = bon and ok

func _villageois(id: String) -> Node:
	for v in m.get_tree().get_nodes_in_group("villageois"):
		if v.donnees.get("id") == id:
			return v
	return null

func _txt(l: Array) -> String:
	return " ".join(PackedStringArray(l.map(func(x: Variant) -> String: return str(x))))

## Ouvre la conversation (comme la touche E) : [répliques, textes des choix]. La boîte reste ouverte.
func _ouvrir(id: String) -> Array:
	if d._ouvert:
		d._fermer()
	var ok: bool = d.engager(_villageois(id))
	if not ok:
		return [[], []]
	return [d._lignes.duplicate(), d._options.map(func(o: Dictionary) -> String: return String(o["texte"]))]

## Conversation complète sans choix (la boîte se referme).
func _parler(id: String) -> Array:
	var r := _ouvrir(id)
	d._fermer()
	return r

## Dans la conversation ouverte : valide le choix dont le texte commence par `debut` ; renvoie la réponse du PNJ (puis referme).
func _choisir(debut: String) -> Array:
	var k := -1
	for i in d._options.size():
		if String(d._options[i]["texte"]).begins_with(debut):
			k = i
	if k < 0:
		d._fermer()
		return []
	d._choisir(k)
	d._valider_choix()
	var rep: Array = d._lignes.duplicate() if d._ouvert else []
	if d._ouvert:
		d._fermer()
	return rep

func _cible(id: String) -> Dictionary:
	for c: Dictionary in Lieux.cibles_quetes(q, m):
		if c["quete"] == id:
			return c
	return {}

func _memoire(id: String) -> float:
	return float(Disposition.courante.memoire.get("pnj:" + id, 0.0)) if Disposition.courante != null else 0.0

func _instantane() -> Array:
	return [JSON.parse_string(JSON.stringify(q.exporter())), m.joueur.inventaire.exporter().duplicate(true),
		Disposition.courante.memoire.duplicate() if Disposition.courante != null else {}]

func _restaurer(s: Array) -> void:
	q.importer(s[0])
	m.joueur.inventaire.importer(s[1])
	if Disposition.courante != null:
		Disposition.courante.memoire = (s[2] as Dictionary).duplicate()
	await process_frame

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 20:
		await process_frame
	q = m.quetes
	d = m.dialogue
	var inv: Inventaire = m.joueur.inventaire
	m.cycle.heure = 11.0
	var recits: RecitsVillage = m.get_node_or_null("RecitsVillage")
	_verif(recits != null and recits.serrure != null and recits.paille != null, "décor des récits posé (serrure du grenier, paille de la grange)")
	_verif(recits != null and recits.paille.get_parent().get_parent() is Interieur, "la trappe est DANS la grange de l'est (intérieur grange_a)")
	_verif(recits != null and recits.trappe_fermee.visible and not recits.trappe_ouverte.visible, "nouvelle partie : la trappe est fermée sous la paille")

	print("== 1. Le grenier qui maigrit (Grima) ==")
	var r := _parler("ancienne")
	_verif(q.index("grenier_maigre") == 0 and q.index("expedition_sigrun") >= 1, "1re visite à Grima : sa petite-fille d'abord, pas encore le grenier")
	r = _parler("ancienne")
	_verif(q.index("grenier_maigre") == 1 and _txt(r[0]).contains("deux par semaine"), "2e visite : Grima confie le grenier (quête lancée)")
	var pc: Vector3 = _cible("grenier_maigre").get("pos", Vector3(1e4, 0, 1e4))
	_verif(Vector2(pc.x, pc.z).distance_to(Vector2(58.9, 22.9)) < 0.1, "repère de quête sur la serrure du grenier")
	_verif(not (recits.paille.condition.call() as bool), "la paille de la grange n'est pas encore proposée")
	r = _parler("garde")
	_verif(_txt(r[0]).contains("lanterne") and _txt(r[0]).contains("dors"), "Haldor (témoin facultatif) : il dort parfois, une lanterne vers l'est")
	var l: Array = recits.serrure.action.call()
	_verif(q.index("grenier_maigre") == 2 and _txt(l).contains("graissée") and _txt(l).contains("balles d’orge"), "serrure examinée : intacte, graissée, balles d'orge vers l'est")
	_verif(_cible("grenier_maigre").get("lieu", "") == "fermes", "repère suivant : la grange des fermes")
	l = recits.paille.action.call()
	await process_frame
	_verif(inv.a("baton_taille") and q.index("grenier_maigre") == 3 and _txt(l).contains("onze sacs"), "paille fouillée : trappe, onze sacs, bâton de taille de Gunnar")
	r = _parler("chef")
	_verif(q.index("grenier_maigre") == 4 and _txt(r[0]).contains("Un sac sur trois"), "Gunnar avoue : un sac sur trois pour le mois noir")
	r = _ouvrir("ancienne")
	_verif(r[1] == ["Commercer", "Dire la vérité : la réserve de Gunnar", "Mentir : « Des rats, et un toit qui fuit »", "Au revoir"], "Grima : Commercer, vérité, mensonge, Au revoir %s" % str(r[1]))
	d._fermer()
	var avant := _instantane()

	print("-- fin A : la vérité")
	var p0 := inv.pieces
	var m_chef := _memoire("chef")
	_ouvrir("ancienne")
	var rep := _choisir("Dire la vérité")
	_verif(_txt(rep).contains("miches") and q.fini("grenier_maigre") and q.issue("grenier_maigre") == "issue:grenier_maigre:verite", "vérité : Grima répond, quête terminée sur l'issue « vérité »")
	_verif(inv.nombre("pain_seigle") == 2 and inv.pieces == p0 and not inv.a("baton_taille"), "récompense : 2 pains de seigle, pas d'or ; bâton rendu")
	_verif(_memoire("chef") < m_chef, "Gunnar s'en souvient (disposition en baisse : %.0f → %.0f)" % [m_chef, _memoire("chef")])
	var j: Array = q.entrees("grenier_maigre")
	_verif(j.size() == 5 and String(j[-1]["texte"]).contains("réserve du chef"), "journal : l'entrée finale raconte la vérité")
	_une_fois("chef", "deux sacs", "après : Gunnar, amer (« ils ont ouvert deux sacs »)")
	_une_fois("ancienne", "en face", "après : Grima (« ils se regardent de nouveau en face »)")
	await create_timer(0.7).timeout
	_verif(recits.trappe_ouverte.visible and not recits.trappe_fermee.visible, "conséquence visible : la trappe de la grange reste ouverte")
	_verif(_causerie("grenier_verite"), "causerie du hameau sur la réserve du chef")
	var sv: Variant = JSON.parse_string(JSON.stringify(q.exporter()))
	q.importer(sv)
	_verif(q.fini("grenier_maigre") and q.issue("grenier_maigre") == "issue:grenier_maigre:verite" and String(q.entrees("grenier_maigre")[-1]["texte"]).contains("réserve du chef"),
		"sauvegarde : l'issue et son journal survivent à l'aller-retour JSON")
	await _restaurer(avant)

	print("-- fin B : le silence")
	p0 = inv.pieces
	m_chef = _memoire("chef")
	var m_grima := _memoire("ancienne")
	_verif(q.index("grenier_maigre") == 4 and inv.a("baton_taille"), "état remis avant le choix")
	_ouvrir("ancienne")
	rep = _choisir("Mentir")
	_verif(_txt(rep).contains("rats") and q.issue("grenier_maigre") == "issue:grenier_maigre:silence" and q.fini("grenier_maigre"), "silence : Grima n'est pas dupe, quête terminée sur l'issue « silence »")
	_verif(inv.pieces == p0 + 60 and inv.nombre("pain_seigle") == 0, "récompense : la bourse de Gunnar (+60 pièces)")
	_verif(_memoire("chef") > m_chef and _memoire("ancienne") < m_grima + 15.0, "Gunnar reconnaissant, Grima moins (mensonge)")
	_verif(String(q.entrees("grenier_maigre")[-1]["texte"]).contains("rats"), "journal : l'entrée finale raconte le silence")
	_une_fois("ancienne", "lavandière", "après : Grima (« quelqu'un a craché devant la porte de la lavandière »)")
	_une_fois("chef", "sous la paille", "après : Gunnar (« le grain dort sous la paille »)")
	await create_timer(0.7).timeout
	_verif(recits.trappe_fermee.visible and not recits.trappe_ouverte.visible and _txt(recits.paille.action.call()).contains("remise en place"), "conséquence : la paille recouvre la trappe")
	_verif(_causerie("grenier_silence"), "causerie : les joues rondes des petits de la lavandière")
	var rec: Dictionary = q.recompense_de("grenier_maigre")
	_verif(int(rec.get("pieces", 0)) == 60 and int(rec.get("xp", 0)) == 120, "onglet Quêtes : récompense de l'issue (%s)" % str(rec))

	print("== 2. L'écorce au fil rouge (Sigrún) ==")
	_parler("chasseuse")   # Ylva et Brodd déjà rencontrés (leurs quêtes à eux se lancent à la 1re visite)
	_parler("forgeron")
	_parler("volva")
	_verif(q.index("sceaux_brises") >= 1 and q.index("fil_rouge") == 0, "1re visite à Sigrún : les sceaux d'abord")
	r = _parler("volva")
	_verif(q.index("fil_rouge") == 1 and inv.a("ecorce_sigrun") and _txt(r[0]).contains("pas seul"), "2e visite : Sigrún confie l'écorce au fil rouge")
	_verif(_cible("fil_rouge").get("pos", Vector3.INF).distance_to(_villageois("chasseuse").global_position) < 0.1, "repère : Ylva elle-même")
	m.cycle.heure = 12.0
	r = _ouvrir("chasseuse")
	_verif(q.index("fil_rouge") == 1 and _txt(r[0]).contains("ce soir") and not (r[1] as Array).has("Lui tendre l’écorce"), "le jour, Ylva ne s'arrête pas (« ce soir, au feu »)")
	d._fermer()
	m.cycle.heure = 19.0
	r = _ouvrir("chasseuse")
	_verif(q.index("fil_rouge") == 2 and _txt(r[0]).contains("fil rouge") and (r[1] as Array).has("Lui tendre l’écorce"), "le soir, au feu : Ylva reconnaît le fil rouge ; choix « Lui tendre l'écorce »")
	d._fermer()
	r = _ouvrir("forgeron")
	_verif((r[1] as Array).has("Jeter l’écorce dans le foyer") and _txt(r[0]).contains("brûle bien"), "Brodd remarque l'écorce : choix « Jeter l'écorce dans le foyer »")
	d._fermer()
	r = _ouvrir("volva")
	_verif((r[1] as Array).any(func(t: String) -> bool: return t.begins_with("Lui rendre l’écorce")), "Sigrún : choix « Lui rendre l'écorce »")
	d._fermer()
	var avant2 := _instantane()

	print("-- fin A : l'écorce donnée (Eirik pas encore retrouvé)")
	_ouvrir("chasseuse")
	rep = _choisir("Lui tendre")
	_verif(_txt(rep).contains("Quelqu’un l’a payé") and not inv.a("ecorce_sigrun") and q.index("fil_rouge") == 3, "Ylva lit : « quelqu'un l'a payé » (elle cherche encore son frère)")
	var rep2: Array = q.repliques("volva", _villageois("volva"))
	_verif(q.fini("fil_rouge") and _txt(rep2).contains("coupé net") and inv.a("talisman_os"), "Sigrún sait (fil coupé net) ; talisman d'os, quête terminée")
	_verif(String(q.entrees("fil_rouge")[-2]["texte"]).contains("capuchon de renard") and String(q.entrees("fil_rouge")[-1]["texte"]).contains("coupé net"), "journal : les deux dernières entrées suivent l'issue")
	_une_fois("chasseuse", "capuchon de renard", "après : Ylva guette la femme au capuchon de renard")
	_une_fois("volva", "gibier", "après : Sigrún (« Ylva ne m'apporte plus de gibier »)")
	_verif(_causerie("ecorce_renard"), "causerie d'Ylva sur la route du sud")
	await _restaurer(avant2)

	print("-- fin A bis : l'écorce donnée (Eirik déjà pleuré)")
	q.etat["frere_ylva"] = 3
	_ouvrir("chasseuse")
	rep = _choisir("Lui tendre")
	_verif(_txt(rep).contains("vers sa mort") and q.issue("fil_rouge") == "issue:fil_rouge:donnee", "Ylva, qui sait son frère mort : « elle l'a vu partir vers sa mort »")
	await _restaurer(avant2)

	print("-- fin B : l'écorce brûlée chez Brodd")
	m_grima = _memoire("volva")
	_ouvrir("forgeron")
	rep = _choisir("Jeter l’écorce")
	_verif(_txt(rep).contains("Prends-le") and inv.a("anneau_cuivre") and not inv.a("ecorce_sigrun") and q.index("fil_rouge") == 3, "Brodd brûle l'écorce, parle de son fer, donne l'anneau de cuivre")
	_verif(_memoire("volva") < m_grima, "Sigrún s'en souvient (disposition en baisse)")
	r = _parler("volva")
	_verif(q.fini("fil_rouge") and _txt(r[0]).contains("bouleau"), "Sigrún a senti le bouleau : quête terminée")
	_verif(String(q.entrees("fil_rouge")[-1]["texte"]).contains("deux, maintenant"), "journal : le silence partagé")
	_verif(int((q.recu_de("fil_rouge").get("objets", {}) as Dictionary).get("anneau_cuivre", 0)) == 1, "journal : l'anneau de cuivre figure dans la ligne « Reçu »")
	_une_fois("chasseuse", "drôle de tête", "après : Ylva devine qu'on lui cache quelque chose")
	_une_fois("forgeron", "flamme verte", "après : Brodd et la flamme verte")
	await _restaurer(avant2)

	print("-- fin C : l'écorce rendue à Sigrún")
	_ouvrir("volva")
	rep = _choisir("Lui rendre")
	_verif(_txt(rep).contains("avec ma bouche") and q.fini("fil_rouge") and inv.nombre("potion_mana") >= 2 and q.issue("fil_rouge") == "issue:fil_rouge:rendue",
		"Sigrún ira parler elle-même ; fioles de mana, quête terminée")
	_verif(String(q.entrees("fil_rouge")[-1]["texte"]).contains("Ce soir, au feu"), "journal : « Ce soir, au feu. »")
	_une_fois("chasseuse", "pas chassée", "après : Ylva (« je ne l'ai pas chassée non plus »)")
	_verif(_causerie("ecorce_feu"), "causerie : la völva au feu, à côté d'Ylva")
	sv = JSON.parse_string(JSON.stringify(q.exporter()))
	q.importer(sv)
	_verif(q.issue("fil_rouge") == "issue:fil_rouge:rendue" and q.fini("fil_rouge"), "sauvegarde : issue « rendue » relue")

	print("== 3. Données ==")
	var sans := []
	for qq: Dictionary in q.donnees["quetes"]:
		if not qq["id"] in ["grenier_maigre", "fil_rouge"]:
			continue
		for e: Dictionary in qq["etapes"]:
			var ok: bool = e.has("carte")
			for evt: String in String(e["declencheur"]).split("|"):
				ok = ok or Lieux.lieu_du_declencheur(evt) != ""
			if not ok:
				sans.append(e["id"])
	_verif(sans.is_empty(), "chaque étape a un lieu sur la carte")
	_verif(RepliquesFiltrees.inatteignables(RepliquesFiltrees.charger(), q.donnees).is_empty(), "aucune réplique inatteignable")
	print("TEST QUÊTES SANS COMBAT : ", "OK" if bon else "ÉCHEC")
	quit(0 if bon else 1)

## Conséquence dite UNE fois à la conversation suivante (sujet « quete », pas_vu « dit:… »), puis plus ; la version durable est
## dans les « apres » (vérifiée par les données : choisir("apres") la retient pour ce PNJ).
func _une_fois(id: String, mot: String, msg: String) -> void:
	var a := _txt(_parler(id)[0])
	var b := _txt(_parler(id)[0])
	var ap := _txt(RepliquesFiltrees.lignes(RepliquesFiltrees.choisir("apres", q._contexte(id, _villageois(id)))))
	_verif(a.contains(mot) and not b.contains(mot), msg + " — dite une fois")
	_verif(ap.contains(mot), msg + " — durable dans les « après » (%s)" % ap.left(60))

## Une causerie de data/vie/conversations.json existe et ses filtres passent dans l'état du monde (scripts/vie/conversations.gd).
func _causerie(id: String) -> bool:
	for e: Dictionary in ConversationsVie.charger():
		if e.get("id") == id:
			return RepliquesFiltrees.valide({"filtres": e.get("filtres", {})}, RepliquesFiltrees.contexte(null, q))
	return false
