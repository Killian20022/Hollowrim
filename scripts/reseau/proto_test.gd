class_name ProtoTest
extends Node
## Lot 1 : scénario automatique des deux instances (hôte + invité) pour le test headless ; asserts imprimés « TEST ok/ECHEC ».
## Phases pilotées par l'hôte (événement « test_phase ») : 1 marche, 2 ramassage simultané, 3 porte (demandée par l'invité),
## 4 bilan (l'hôte envoie ses mesures, l'invité vérifie et répond « test_resultat », l'hôte conclut et quitte).

const MARCHE_DUREE := 3.0
const HOTE_DEPART := Vector3(0, 0, 0)
const HOTE_FIN := Vector3(2.5, 0, 3.0)
const INVITE_DEPART := Vector3(-1.5, 0, 0.5)
const INVITE_FIN := Vector3(-2.0, 0, 4.0)
const DELAI_MAX := 40.0

var coop: ProtoCoop
var _t := 0.0
var _phase := 0
var _t_phase := 0.0
var _marche_t := -1.0
var _echecs: Array[String] = []
var _res_invite: Dictionary = {}
var _fini := false

func _ready() -> void:
	coop.joueur.vie = 1.0e6   # le draugr frappe : le test ne doit pas dépendre de la mort
	coop.joueur.vie_max = 1.0e6
	Reseau.abonner("test_phase", _sur_phase)
	Reseau.abonner("test_fin", _sur_fin)
	Reseau.abonner("test_resultat", _sur_resultat)

func _verifier(nom: String, ok: bool, detail := "") -> void:
	print("TEST ", "ok    " if ok else "ECHEC ", nom, " ", detail)
	if not ok:
		_echecs.append(nom)

func _physics_process(dt: float) -> void:
	if _fini:
		return
	_t += dt
	if _t > DELAI_MAX:
		print("TEST ECHEC délai dépassé")
		_quitter(1)
		return
	# la marche (position imposée : aucune entrée en headless)
	if _marche_t >= 0.0:
		_marche_t += dt
		var k := clampf(_marche_t / MARCHE_DUREE, 0.0, 1.0)
		var depart := HOTE_DEPART if coop.est_hote else INVITE_DEPART
		var fin := HOTE_FIN if coop.est_hote else INVITE_FIN
		var j := coop.joueur
		var v := (fin - depart) / MARCHE_DUREE if k < 1.0 else Vector3.ZERO
		j.global_position = depart.lerp(fin, k)
		j.velocity = v
	# l'hôte déroule le scénario quand l'invité est là
	if coop.est_hote:
		if _phase == 0 and coop.avatars.size() >= 1 and _t > 2.0:
			_changer_phase(1)
		elif _phase == 1 and _t - _t_phase > MARCHE_DUREE + 1.5:
			_changer_phase(2)
		elif _phase == 2 and _t - _t_phase > 1.5:
			_changer_phase(3)
		elif _phase == 3 and _t - _t_phase > 1.5:
			_changer_phase(4)

func _changer_phase(n: int) -> void:
	_phase = n
	_t_phase = _t
	Reseau.emettre("test_phase", n, null)
	_sur_phase(Reseau.mon_id(), n, null)   # l'évènement ne revient pas à l'émetteur : l'hôte l'applique aussi pour lui

func _sur_phase(expediteur: int, n: Variant, _d: Variant) -> void:
	if expediteur != 1:
		return
	match int(n):
		1:
			_marche_t = 0.0
		2:
			coop.monde.demander_ramasser()   # hôte ET invité ensemble : une seule prise
		3:
			if not coop.est_hote:
				coop.monde.demander_porte()
		4:
			if coop.est_hote:
				_bilan_hote()

func _bilan_hote() -> void:
	var av: ProtoAvatar = coop.avatars.values()[0] if not coop.avatars.is_empty() else null
	_verifier("hôte voit l'avatar Joueur_<id> de l'invité", av != null and av.noeud.name == "Joueur_%d" % av.id, str(av.noeud.name) if av else "")
	if av != null:
		var d := av.noeud.global_position.distance_to(INVITE_FIN)
		_verifier("mouvement de l'invité répliqué chez l'hôte", d < 0.4, "écart %.2f m" % d)
	var d_pos: Vector3 = coop.draugr.global_position if is_instance_valid(coop.draugr) else Vector3.ZERO
	var cible: Node = coop.draugr.joueur if is_instance_valid(coop.draugr) else null
	var proche: Node = coop.joueur if coop.joueur.global_position.distance_to(d_pos) < av.noeud.global_position.distance_to(d_pos) else av.noeud
	_verifier("cible du draugr = joueur le plus proche", cible == proche, str(cible.name) if cible else "null")
	_verifier("porte ouverte côté hôte", coop.monde.porte_ouverte)
	Reseau.emettre("test_fin", 0, {"hote_pos": coop.joueur.global_position, "draugr_pos": d_pos, "porte": coop.monde.porte_ouverte, "objet_hote": coop.monde.nb_objets_locaux()})

func _sur_fin(expediteur: int, _id: Variant, d: Variant) -> void:
	if expediteur != 1 or coop.est_hote:
		return
	var av: ProtoAvatar = coop.avatars.get(1)
	_verifier("avatar Joueur_1 présent chez l'invité", av != null and av.noeud.name == "Joueur_1")
	if av != null:
		var e := av.noeud.global_position.distance_to(d["hote_pos"])
		_verifier("mouvement de l'hôte répliqué chez l'invité", e < 0.4, "écart %.2f m" % e)
		_verifier("avatar = corps 3e personne", av.noeud.corps != null and av.noeud.troisieme)
	var dr := coop.draugr
	_verifier("draugr visible chez l'invité", dr != null and is_instance_valid(dr))
	if dr != null and is_instance_valid(dr):
		var e2: float = dr.global_position.distance_to(d["draugr_pos"])
		_verifier("draugr marionnette suit l'hôte", e2 < 1.5 and dr.global_position.distance_to(Vector3(3.2, 0, -3.6)) > 0.5, "écart %.2f m" % e2)
	_verifier("porte ouverte côté invité", coop.monde.porte_ouverte and d["porte"])
	_verifier("objet retiré chez l'invité", coop.monde.objet == null)
	var total := int(d["objet_hote"]) + coop.monde.nb_objets_locaux()
	_verifier("objet pris UNE seule fois", total == 1, "hôte=%d invité=%d" % [d["objet_hote"], coop.monde.nb_objets_locaux()])
	_verifier("objet retiré chez l'hôte (qui = %d)" % coop.monde.objet_pris_par, coop.monde.objet_pris_par != 0)
	Reseau.emettre("test_resultat", 0, {"echecs": _echecs.size(), "objet_invite": coop.monde.nb_objets_locaux()}, 1)
	_quitter(1 if not _echecs.is_empty() else 0)

func _sur_resultat(expediteur: int, _id: Variant, d: Variant) -> void:
	if not coop.est_hote or _fini:
		return
	var total := coop.monde.nb_objets_locaux() + int(d["objet_invite"])
	_verifier("objet pris une seule fois (bilan hôte)", total == 1, "total=%d" % total)
	_verifier("l'invité n'a aucun échec", int(d["echecs"]) == 0, "échecs invité=%d" % int(d["echecs"]))
	print("TEST ", "RESULTAT GLOBAL OK" if _echecs.is_empty() else "RESULTAT GLOBAL ECHEC")
	_quitter(1 if not _echecs.is_empty() else 0)

func _quitter(code: int) -> void:
	_fini = true
	await get_tree().create_timer(0.7).timeout   # laisse partir les derniers paquets
	get_tree().quit(code)
