class_name Disposition
extends Node
## DISPOSITION DES PNJ envers le joueur (retours exe 5, idées 1 et 2 de docs : idees_daggerfall_openmw). Enfant du nœud Crime (créé
## par Crime._ready) ; données : data/disposition.json. Lit enfin `Crime.reputation` (0-100) et la prime :
##   score(pnj) = réputation − min(malus max, prime × k) + mémoire du PNJ (vol vu, coup reçu, aide) − malus si l'arme est brandie ;
##   palier(pnj) : « chaleureux », « neutre », « froid », « refus » (aussi dès que la prime dépasse `prime_refus`).
## Effets : salut ajouté en tête des répliques (dialogue.gd ; neutre = répliques habituelles), refus de parler (et donc de commercer),
## interpellations au passage froides, prix des marchands (Marchand.prix_achat / prix_vente : ±15 % selon le score du marchand).
## MENACE (idée 2) : arme brandie (garde levée, coup armé ou chargé : il n'y a pas de fourreau, l'épée au repos dans la main ne compte
## pas) ou sort en cours d'incantation, dans le village et HORS combat légitime (aucun ennemi en combat, garde non hostile, pas
## d'arrestation). Un civil qui voit le joueur à portée fait une remarque (« Range ça. »), les frêles s'éloignent ; un garde avertit,
## avertit une 2e fois, puis attaque si l'on persiste près de lui (crime « menace », Crime.menace_persistante). Arme baissée : il se calme.
## Idée de la disposition : OpenMW (concept seulement, aucun code repris) ; paliers d'accueil : Daggerfall Unity (TalkManager, MIT, Interkarma).

const DONNEES := "res://data/disposition.json"
const PAS := 0.25                      # s entre deux examens de la menace
const MERCI_APRES := 1.5               # s d'arme baissée avant le « Bien. » d'un garde qui avertissait

## Disposition en service (une par monde) : lue par Marchand (fonctions statiques) et le dialogue.
static var courante: Disposition = null

var crime: Crime
var d := {}
## Mémoire de chaque PNJ (clé Crime.cle_pnj : « pnj:forgeron », « garde:so ») : somme des événements, bornée.
var memoire := {}
## Gardes qui avertissent : instance_id -> {"n": garde, "niveau": 1|2, "m": s de menace depuis le 1er avertissement}.
var avertis := {}
var remarques := 0                     # remarques de civils (tests)
var derniere_reaction := ""            # « civil », « garde_1 », « garde_2 », « hostile », « merci » (tests)
var _remarque_t := {}                  # instance_id -> horloge de la dernière remarque
var _horloge := 0.0
var _t := 0.0
var _baisse := 0.0                     # s depuis que l'arme est baissée

func _init() -> void:
	if FileAccess.file_exists(DONNEES):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
		if j is Dictionary:
			d = j

func _enter_tree() -> void:
	courante = self

func _exit_tree() -> void:
	if courante == self:
		courante = null

func _ready() -> void:
	var q: Node = crime.monde.get("quetes") if crime != null and crime.monde != null else null
	if q != null and q.has_signal("quete_terminee"):
		q.quete_terminee.connect(_sur_quete)

# ======================================================================================================== score et paliers

func _f(cle: String, defaut: float) -> float:
	return float(d.get(cle, defaut))

func _sous(cle: String, sous: String, defaut: float) -> float:
	var s: Variant = d.get(cle)
	return float((s as Dictionary).get(sous, defaut)) if s is Dictionary else defaut

## Score de `n` (0..100 environ ; 50 = un étranger sans histoire). `n` null : score du village (sans mémoire).
func score(n: Node) -> float:
	return score_cle(crime.cle_pnj(n) if n != null else "")

func score_cle(cle: String) -> float:
	var s := crime.reputation_de() - minf(_f("prime_malus_max", 45.0), crime.prime() * _f("prime_k", 0.4))
	s += float(memoire.get(cle, 0.0))
	if menace():
		s -= _f("malus_menace", 10.0)
	return s

func palier(n: Node) -> String:
	return palier_cle(crime.cle_pnj(n) if n != null else "")

func palier_cle(cle: String) -> String:
	if crime.prime() >= _f("prime_refus", 40.0):
		return "refus"
	var s := score_cle(cle)
	var p: Dictionary = d.get("paliers", {})
	if s >= float(p.get("chaleureux", 65.0)):
		return "chaleureux"
	if s >= float(p.get("neutre", 35.0)):
		return "neutre"
	if s >= float(p.get("froid", 15.0)):
		return "froid"
	return "refus"

## Accueil d'une conversation : {"palier", "refus": bool, "salut": String} (salut vide au palier neutre). Rien pour un combattant
## (arrestation) ni pour ce qui n'est pas un PNJ du village.
func accueil(n: Node) -> Dictionary:
	if n == null or n is PnjCombat or crime.cle_pnj(n) == "":
		return {}
	var p := palier(n)
	if p == "neutre":
		return {"palier": p, "refus": false, "salut": ""}
	# saluts : sujet « salut » de data/dialogue/repliques.json (première réplique valide : disposition, garde, marchand refusé…)
	var ctx := RepliquesFiltrees.contexte(n, crime.monde.get("quetes"))
	var l := RepliquesFiltrees.lignes(RepliquesFiltrees.choisir("salut", ctx))
	var salut := String(l[0]) if not l.is_empty() else ""
	return {"palier": p, "refus": p == "refus", "salut": salut}

static func accueil_de(n: Node) -> Dictionary:
	return courante.accueil(n) if courante != null and is_instance_valid(courante) else {}

## Interpellation au passage selon le palier (froid / refus : une réplique sèche, chaleureux : un salut) ; "" = la réplique habituelle.
static func interpellation(n: Node) -> String:
	if courante == null or not is_instance_valid(courante):
		return ""
	var a := courante.accueil(n)
	if a.is_empty() or String(a.get("palier", "neutre")) == "neutre" or randf() < 0.4:
		return ""
	return String(a.get("salut", ""))

## Part du prix en faveur du joueur chez le marchand `id` (villageois de même id) : de −max (score 0) à +max (score 100).
static func mod_prix(id: String) -> float:
	if courante == null or not is_instance_valid(courante) or id == "":
		return 0.0
	var mx := courante._sous("prix", "max", 0.15)
	return clampf((courante.score_cle("pnj:" + id) - 50.0) / 50.0, -1.0, 1.0) * mx

## Un événement marque la mémoire de `n` (« vol_vu », « vol_victime », « coup », « avertissement », « aide »).
func noter(n: Node, evt: String) -> void:
	noter_cle(crime.cle_pnj(n), evt)

func noter_cle(cle: String, evt: String) -> void:
	if cle == "":
		return
	var v := float(memoire.get(cle, 0.0)) + _sous("memoire", evt, 0.0)
	memoire[cle] = clampf(v, _sous("memoire", "min", -60.0), _sous("memoire", "max", 30.0))

## Quête terminée : son donneur s'en souvient (aide rendue).
func _sur_quete(id: String) -> void:
	var q: Node = crime.monde.get("quetes")
	if q == null or not q.has_method("_quete"):
		return
	var def: Dictionary = q._quete(id)
	var donneur := String(def.get("donneur", ""))
	if donneur != "":
		noter_cle("pnj:" + donneur, "aide")

# ======================================================================================================== menace (arme brandie)

## Arme brandie (garde, coup armé, chargé, retour du coup) avec une arme en main droite, ou sort en cours d'incantation.
func menace() -> bool:
	var j := crime.joueur
	if j == null or not is_instance_valid(j):
		return false
	var m: Node = j.get("mains")
	if m == null:
		return false
	var eq: Variant = m.get("equipement")
	if eq is Equipement and EquipementMains.categorie_de((eq as Equipement).main_droite) in ["arme", "arme_deux_mains"]:
		var e := int(m.get("etat"))
		if e >= 1 and e <= 5:          # ARMER, CHARGE, FRAPPE, RETOUR, GARDE (mains.gd ; REPOS = 0, ENCAISSE = 6)
			return true
	return sort_en_main()

func sort_en_main() -> bool:
	var m: Node = crime.joueur.get("mains")
	var mg: Node = m.get("magie") if m != null else null
	var inc: Variant = mg.get("inc") if mg != null else null
	if inc is Dictionary:
		for k in inc:
			var i: Variant = inc[k]
			if i != null and i.has_method("active") and i.active():
				return true
	return false

## Combat légitime ou situation où brandir l'arme ne choque personne : rien à faire.
func _hors_jeu() -> bool:
	var j := crime.joueur
	if j.mort or j.en_dialogue or crime.arrestation != null or crime.est_hostile():
		return true
	if crime.monde != null and crime.monde.has_method("en_combat") and crime.monde.en_combat():
		return true
	return false

func _process(dt: float) -> void:
	_horloge += dt
	if crime == null or crime.joueur == null or not is_instance_valid(crime.joueur):
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = PAS
	if _hors_jeu():
		avertis.clear()
		_baisse = 0.0
		return
	if menace():
		_baisse = 0.0
		_reagir_menace(PAS)
	else:
		_baisse += PAS
		if not avertis.is_empty() and _baisse >= MERCI_APRES and _baisse < MERCI_APRES + PAS:
			for a: Dictionary in avertis.values():
				var g: Node3D = a["n"] as Node3D if is_instance_valid(a["n"]) else null
				if g != null and g.global_position.distance_to(crime.joueur.global_position) < 14.0:
					_dire(g, "arme_garde_merci")
					derniere_reaction = "merci"
					break
		if _baisse >= _sous("menace", "oubli", 6.0):
			avertis.clear()

func _reagir_menace(pas: float) -> void:
	var pj := crime.joueur.global_position
	var sort := sort_en_main()
	var r_civil := _sous("menace", "portee_civil", 7.0)
	var r_garde := _sous("menace", "portee_garde", 10.0)
	var delai := _sous("menace", "delai_remarque", 14.0)
	var gardes_vus := {}
	for n: Node3D in crime.pnj_actifs():
		if n is PnjCombat:
			continue
		var dist := n.global_position.distance_to(pj)
		if crime.est_garde(n):
			if n.get("service") == "vigie" or dist > r_garde or not crime.voit(n, pj):
				continue
			gardes_vus[n.get_instance_id()] = n
		elif dist < r_civil and crime.voit(n, pj):
			var iid := n.get_instance_id()
			if _horloge - float(_remarque_t.get(iid, -1.0e9)) < delai:
				continue
			_remarque_t[iid] = _horloge
			remarques += 1
			derniere_reaction = "civil"
			_dire(n, "arme_civil_sort" if sort else "arme_civil")
			if crime._frele(n):
				crime._fuir(n)              # les frêles s'éloignent (abri le plus proche)
	# gardes : avertissement, dernier avertissement, puis il attaque s'il est encore tout près
	var t2 := _sous("menace", "avert_2", 4.0)
	var th := _sous("menace", "hostile", 8.0)
	for iid in gardes_vus:
		var g: Node3D = gardes_vus[iid]
		if not avertis.has(iid):
			avertis[iid] = {"n": g, "niveau": 1, "m": 0.0}
			derniere_reaction = "garde_1"
			_dire(g, "arme_garde_1")
			continue
		var a: Dictionary = avertis[iid]
		a["m"] = float(a["m"]) + pas
		if int(a["niveau"]) == 1 and float(a["m"]) >= t2:
			a["niveau"] = 2
			derniere_reaction = "garde_2"
			_dire(g, "arme_garde_2")
		elif int(a["niveau"]) == 2 and float(a["m"]) >= th:
			avertis.erase(iid)
			derniere_reaction = "hostile"
			_dire(g, "arme_garde_hostile")
			crime.menace_persistante(g)
			return

func _dire(n: Node, cle: String) -> void:
	var l: Array = d.get(cle, [])
	if l.is_empty() or crime.dialogue == null or not is_instance_valid(crime.dialogue):
		return
	crime.dialogue.dire_au_passage(Crime.nom_de(n), String(l.pick_random()))

func texte(cle: String) -> String:
	var l: Variant = d.get(cle, [])
	if l is Array:
		return String((l as Array).pick_random()) if not (l as Array).is_empty() else ""
	return String(l)

# ======================================================================================================== sauvegarde

func exporter() -> Dictionary:
	return memoire.duplicate()

func restaurer(m: Variant) -> void:
	memoire = {}
	if m is Dictionary:
		for k in m:
			memoire[String(k)] = float(m[k])
	avertis.clear()
