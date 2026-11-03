class_name Progression
extends RefCounted
## État du personnage (docs/RPG.md §5) : niveau, expérience de niveau, points à dépenser, attributs, perks, compétences.
## Tenue par le joueur (joueur.progression) ; joueur.competences reste l'objet Competences de la progression (alias : aucun
## appel existant ne change). Progression hybride (Q1 c) : chaque niveau de compétence gagné rapporte autant d'XP de niveau
## que le niveau atteint, les quêtes en donnent aussi ; chaque niveau = 1 choix d'attribut (+10 vie / magie / vigueur) et
## 1 point d'arbre.
## LOT B (progression) : 8 compétences réelles (Competences), arbre data/competences/arbre.json (55 perks sur 8 pierres,
## docs/RPG.md §13), mult / bonus des perks, perks spéciaux (saignement, vol de vie, étourdissement, riposte…, appliqués par
## les fonctions statiques « points d'accroche » plus bas), réinitialisation chez Sigrún. Les noms et signatures du socle
## NE CHANGENT PAS (fonctions ajoutées seulement).

signal niveau_perso(niveau: int)                  ## niveau du personnage gagné (une fois par niveau)
signal niveau_competence(nom: String, niveau: int) ## nom canonique (COMPETENCES), relais de Competences.niveau_gagne
signal change                                      ## tout changement (points, attributs, perks, niveau) : UI, recalculer_stats

## Les 8 compétences (noms canoniques, ceux de la sauvegarde v2 et de l'arbre). Q1 c.
const COMPETENCES := ["une_main", "deux_mains", "parade", "armure", "destruction", "restauration", "furtivite", "athletisme"]
## Nom interne de Competences -> nom canonique (le lot B pourra renommer « epee » en « une_main » : vider alors l'entrée).
const ALIAS_COMPETENCES := {"epee": "une_main"}
const ATTRIBUTS := ["vie", "magie", "vigueur"]
const GAIN_ATTRIBUT := 10            ## +10 à la jauge choisie, par niveau
const CHARGE_PAR_VIGUEUR := 0.5      ## +5 de charge par choix « vigueur » (10 points)
const NIVEAU_MAX := 81               ## plafond technique (tout au maximum ≈ 80) ; de fait ~50 (docs/CONCEPTION_RPG §2.7)
## XP d'une quête terminée sans champ `recompense.xp` dans data/quetes.json (migration v1 et lot B : même valeur).
const XP_QUETE_DEFAUT := 150
const PRIX_REINITIALISATION := 500   ## Sigrún (Q6 b), lot B

var niveau := 1
var xp_niveau := 0.0                 ## XP accumulée vers le niveau suivant (0 .. seuil_niveau(niveau))
var points_perk := 0                 ## points d'arbre non dépensés
var points_attribut := 0             ## choix d'attribut en attente (écran de niveau, lot D)
var attributs := {"vie": 0, "magie": 0, "vigueur": 0}
var perks := {}                      ## id -> rang acheté (lot B)
var competences := Competences.new() ## progression à l'usage (scripts/competences.gd)
## Équipement de corps, pour bonus() (posé par le joueur) ; null dans les tests unitaires.
var equipement_corps: EquipementCorps = null
## Données de compétences de la sauvegarde que Competences ne connaît pas encore (5 nouvelles avant le lot B) : rendues
## telles quelles à l'export, rien ne se perd.
var _comp_inconnues := {"niveaux": {}, "experience": {}}

# ------------------------------------------------------------------ joueur courant (ReglagesCombat.competence)

static var _courant: WeakRef = null

## Le joueur rend sa progression « courante » : ReglagesCombat.competence() lit alors ses multiplicateurs.
func activer() -> void:
	_courant = weakref(self)

static func courante() -> Progression:
	return _courant.get_ref() as Progression if _courant != null else null

## Multiplicateur de l'arbre pour une clé de ReglagesCombat.COMPETENCES (« une_main », « destruction », « armure »…) :
## 1,0 si aucun joueur (tests, scènes d'essai) ou rien d'acheté.
static func mult_global(cle: String) -> float:
	var p := courante()
	return p.mult(cle) if p != null else 1.0

func _init() -> void:
	competences.niveau_gagne.connect(_sur_niveau_competence)

# ------------------------------------------------------------------ compétences

static func canonique(nom: String) -> String:
	return String(ALIAS_COMPETENCES.get(nom, nom))

static func interne(nom: String) -> String:
	for k in ALIAS_COMPETENCES:
		if ALIAS_COMPETENCES[k] == nom:
			return String(k)
	return nom

## Niveau 15..100 d'une compétence (nom canonique ou interne).
func competence(nom: String) -> int:
	var i := interne(canonique(nom))
	if competences.niveaux.has(i):
		return int(competences.niveaux[i])
	return int(_comp_inconnues["niveaux"].get(canonique(nom), Competences.DEPART))

## Pratique d'une compétence (remplace Competences.pratiquer, qui reste valable). Perks « xp_<compétence> » : gain accru.
## Compétence inconnue : ignorée.
func pratiquer(nom: String, quantite: float) -> void:
	var i := interne(canonique(nom))
	if competences.niveaux.has(i):
		competences.pratiquer(i, quantite * (1.0 + perk_total("xp_" + canonique(nom))))

## Pratique pour la progression courante (sorts, calcul des dégâts : pas de référence au joueur). Sans joueur : rien.
static func pratiquer_global(nom: String, quantite: float) -> void:
	var p := courante()
	if p != null:
		p.pratiquer(nom, quantite)

func _sur_niveau_competence(nom: String, n: int) -> void:
	niveau_competence.emit(canonique(nom), n)
	gagner_xp(float(n))

# ------------------------------------------------------------------ niveau du personnage

## XP de niveau pour passer de n à n+1.
static func seuil_niveau(n: int) -> float:
	return 100.0 + 50.0 * n

## XP de niveau rapportée par une compétence montée de DEPART à `n` (somme des niveaux atteints).
static func xp_competence_jusqua(n: int) -> float:
	var t := 0.0
	for k in range(Competences.DEPART + 1, n + 1):
		t += k
	return t

## Ajoute de l'XP de niveau (montée de compétence, quête). Chaque niveau : +1 point d'arbre, +1 choix d'attribut.
func gagner_xp(quantite: float, annoncer := true) -> void:
	if quantite <= 0.0:
		return
	xp_niveau += quantite
	while niveau < NIVEAU_MAX and xp_niveau >= seuil_niveau(niveau):
		xp_niveau -= seuil_niveau(niveau)
		niveau += 1
		points_perk += 1
		points_attribut += 1
		if annoncer:
			niveau_perso.emit(niveau)
	change.emit()

## Part de la barre de niveau (0 → 1).
func part_niveau() -> float:
	return clampf(xp_niveau / seuil_niveau(niveau), 0.0, 1.0)

## Dépense un choix d'attribut : "" si fait, sinon la raison.
func choisir_attribut(nom: String) -> String:
	if not nom in ATTRIBUTS:
		return "Attribut inconnu."
	if points_attribut <= 0:
		return "Aucun niveau en attente."
	points_attribut -= 1
	attributs[nom] = int(attributs[nom]) + GAIN_ATTRIBUT
	change.emit()
	return ""

# ------------------------------------------------------------------ arbre (lot B, data/competences/arbre.json)

const FICHIER_ARBRE := "res://data/competences/arbre.json"
## Clés « degats_* » de l'équipement (docs/RPG.md §3) multipliées dans mult() de la clé de compétence correspondante.
const DEGATS_EQUIPEMENT := {"une_main": "degats_une_main", "deux_mains": "degats_deux_mains", "destruction": "degats_destruction"}
## Écoles de sorts de la Restauration (les autres sont de la Destruction).
const ECOLES_RESTAURATION := ["soin", "protection"]
const COUT_SORT_MIN := 0.25          ## plancher du facteur de coût des sorts (perks + équipement)
const DUREE_SAIGNEMENT := 3.0
const DUREE_ETOURDI := 0.7           ## choc (Statuts) posé par les perks d'étourdissement
const PORTEE_RIPOSTE := 4.5          ## m : l'attaquant paré est l'ennemi le plus proche du point d'origine du coup

static var _arbre := {}

## Contenu de arbre.json : {pierres {id: {nom, competence, titre, description}}, ordre_pierres [], perks {id: fiche}}.
static func arbre() -> Dictionary:
	if _arbre.is_empty():
		var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_ARBRE)) if FileAccess.file_exists(FICHIER_ARBRE) else null
		_arbre = lu if lu is Dictionary else {"pierres": {}, "ordre_pierres": [], "perks": {}}
	return _arbre

## Fiche d'un perk ({nom, pierre, pos, parents, description, rangs [{niveau, effets, texte}]}) ou {}.
static func perk(id: String) -> Dictionary:
	return arbre()["perks"].get(id, {})

## Perks d'une pierre (= d'une compétence canonique), dans l'ordre du fichier.
static func perks_de(pierre: String) -> Array:
	var r := []
	for id in arbre()["perks"]:
		if String(arbre()["perks"][id].get("pierre", "")) == pierre:
			r.append(String(id))
	return r

static func rangs_max(id: String) -> int:
	return (perk(id).get("rangs", []) as Array).size()

func a_perk(id: String) -> bool:
	return int(perks.get(id, 0)) > 0

func rang_perk(id: String) -> int:
	return int(perks.get(id, 0))

## Raison pour laquelle le prochain rang de `id` ne peut pas être acheté ("" = possible). Pour l'interface (lot D).
func refus_perk(id: String) -> String:
	var f := perk(id)
	if f.is_empty():
		return "Perk inconnu."
	var r := rang_perk(id)
	var rangs: Array = f.get("rangs", [])
	if r >= rangs.size():
		return "Rang maximal atteint."
	var parents: Array = f.get("parents", [])
	if not parents.is_empty():
		var un := false
		for pa in parents:
			un = un or a_perk(String(pa))
		if not un:
			var noms := []
			for pa in parents:
				noms.append(String(perk(String(pa)).get("nom", pa)))
			return "Il faut d'abord : %s." % " ou ".join(noms)
	var comp := String(f.get("pierre", ""))
	var requis := int(rangs[r].get("niveau", 0))
	if competence(comp) < requis:
		return "%s %d requis." % [String(arbre()["pierres"].get(comp, {}).get("titre", comp)), requis]
	if points_perk <= 0:
		return "Aucun point d'arbre."
	return ""

## Achète un rang de perk : "" si fait, sinon la raison (refus_perk). Coûte 1 point d'arbre.
func acheter_perk(id: String) -> String:
	var raison := refus_perk(id)
	if raison != "":
		return raison
	points_perk -= 1
	perks[id] = rang_perk(id) + 1
	_effets_cache = {}
	change.emit()
	return ""

## Rend tous les points d'arbre (Sigrún, PRIX_REINITIALISATION pièces : le paiement est fait par l'appelant, voir
## reinitialiser_chez_sigrun).
func reinitialiser_perks() -> void:
	for id in perks:
		points_perk += int(perks[id])
	perks = {}
	_effets_cache = {}
	change.emit()

## Points dépensés dans l'arbre (affichage, réinitialisation).
func points_depenses() -> int:
	var n := 0
	for id in perks:
		n += int(perks[id])
	return n

## Raison du refus de la réinitialisation chez Sigrún ("" = possible) : rien à rendre, ou pas assez de pièces.
func refus_reinitialisation(pieces: int) -> String:
	if points_depenses() <= 0:
		return "Aucun perk à oublier."
	if pieces < PRIX_REINITIALISATION:
		return "Il faut %d pièces." % PRIX_REINITIALISATION
	return ""

## Point d'accroche du dialogue de Sigrún (lot D / E) : paie PRIX_REINITIALISATION pièces depuis `bourse` (le sac du
## joueur, un Conteneur) et rend tous les points d'arbre. "" si fait, sinon la raison (rien n'est payé).
func reinitialiser_chez_sigrun(bourse: Conteneur) -> String:
	var raison := refus_reinitialisation(bourse.pieces if bourse != null else 0)
	if raison != "":
		return raison
	bourse.retirer("pieces", PRIX_REINITIALISATION)
	reinitialiser_perks()
	return ""

var _effets_cache := {}

## Somme des effets des perks achetés (effets du rang atteint : les rangs de arbre.json donnent des TOTAUX).
func effets_perks() -> Dictionary:
	if _effets_cache.is_empty() and not perks.is_empty():
		var t := {"_": 0.0}
		for id in perks:
			var rangs: Array = perk(String(id)).get("rangs", [])
			var r := mini(int(perks[id]), rangs.size())
			if r <= 0:
				continue
			var ef: Dictionary = rangs[r - 1].get("effets", {})
			for k in ef:
				t[k] = float(t.get(k, 0.0)) + float(ef[k])
		_effets_cache = t
	return _effets_cache

## Total des perks pour une clé (0 si aucun).
func perk_total(cle: String) -> float:
	return float(effets_perks().get(cle, 0.0))

## Multiplicateur d'une clé (1,0 = neutre) : 1 + somme des perks (ex. « une_main » +0,1 par rang de Lame aguerrie) ;
## une_main / deux_mains / destruction : × (1 + équipement « degats_* »). Clés : docs/RPG.md §3.
func mult(cle: String) -> float:
	var m := 1.0 + perk_total(cle)
	if DEGATS_EQUIPEMENT.has(cle) and equipement_corps != null:
		m *= 1.0 + float(equipement_corps.effets_totaux().get(DEGATS_EQUIPEMENT[cle], 0.0))
	return m

## Bonus additif d'une clé (« vie_max », « charge », « resist_froid », « cout_sorts »…) : perks + équipement de corps.
func bonus(cle: String) -> float:
	var b := perk_total(cle)
	if equipement_corps != null:
		b += float(equipement_corps.effets_totaux().get(cle, 0.0))
	return b

## Facteur « 1 + bonus » (régénérations : « regen_vie », « regen_magie », « regen_vigueur »).
func facteur(cle: String) -> float:
	return maxf(0.0, 1.0 + bonus(cle))

## bonus() du joueur courant (0 sans joueur).
static func bonus_global(cle: String) -> float:
	var p := courante()
	return p.bonus(cle) if p != null else 0.0

# ------------------------------------------------------------------ points d'accroche (effets spéciaux des perks)

## Compétence d'une arme (DonneesArme) : « deux_mains » (deux mains, marteau) ou « une_main » (même règle que
## ReglagesCombat.competence_arme).
static func competence_arme(arme: DonneesArme) -> String:
	if arme != null and (arme.deux_mains or arme.famille in ["deux_mains", "marteau"]):
		return "deux_mains"
	return "une_main"

static func de_joueur(joueur: Object) -> Progression:
	if joueur == null:
		return null
	var p: Variant = joueur.get("progression")
	return p as Progression if p is Progression else null

## Pratique pour un joueur (mains.gd) : sa progression, ou ses Competences seules (faux joueurs des tests).
static func pratiquer_de(joueur: Object, nom: String, quantite: float) -> void:
	var p := de_joueur(joueur)
	if p != null:
		p.pratiquer(nom, quantite)
	elif joueur != null and joueur.get("competences") is Competences:
		(joueur.get("competences") as Competences).pratiquer(interne(canonique(nom)), quantite)

## Coup d'arme du joueur qui a porté (mains.gd, `resultat` « touche » / « tue ») : pratique de la compétence de l'arme
## (1,0 ; 1,8 si `fort` : lourd ou contre) et perks de cette compétence : saignement_*, vol_vie_*, etourdir_* (coups forts),
## vigueur_tue_* (ennemi tué).
static func coup_porte(joueur: Node, cible: Node, arme: DonneesArme, degats: float, resultat: String, fort: bool) -> void:
	var c := competence_arme(arme)
	pratiquer_de(joueur, c, 1.8 if fort else 1.0)
	var p := de_joueur(joueur)
	if p == null or not resultat in ["touche", "tue"]:
		return
	# vol de vie de l'équipement (« vol_vie » : toute arme, armures enchantées 2026-11-02), même sans perk
	var vol_eq := p.bonus("vol_vie")
	if vol_eq > 0.0 and joueur.has_method("soigner"):
		joueur.soigner(degats * vol_eq)
	if p.perks.is_empty():
		return
	var sang := p.bonus("saignement_" + c)
	if sang > 0.0 and resultat == "touche":
		Saignement.poser(cible, degats * sang, DUREE_SAIGNEMENT, joueur)
	var vol := p.bonus("vol_vie_" + c)
	if vol > 0.0 and joueur.has_method("soigner"):
		joueur.soigner(degats * vol)
	var etourdir := p.bonus("etourdir_" + c)
	if fort and resultat == "touche" and etourdir > 0.0 and randf() < etourdir:
		var st := Statuts.de(cible)
		if st != null:
			st.appliquer("choc", DUREE_ETOURDI, DUREE_ETOURDI, joueur)
	var vt := p.bonus("vigueur_tue_" + c)
	if vt > 0.0 and resultat == "tue" and joueur.get("vigueur") != null:
		joueur.set("vigueur", minf(float(joueur.get("vigueur_max")), float(joueur.get("vigueur")) + vt))

## Coup reçu en garde (joueur.recevoir_coup, `garde` = résultat de mains.defendre {issue, degats, cout}) : pratique de la
## Parade et, sur une parade parfaite, perks riposte (part du coup renvoyée à l'attaquant), vigueur_parade, etourdir_parade.
static func garde_tenue(joueur: Node3D, garde: Dictionary, degats: float, origine: Vector3) -> void:
	var parfaite := String(garde.get("issue", "")) == "parade"
	pratiquer_de(joueur, "parade", 0.6 + degats * 0.08 + (0.6 if parfaite else 0.0))
	var p := de_joueur(joueur)
	if p == null or p.perks.is_empty() or not parfaite:
		return
	var vp := p.bonus("vigueur_parade")
	if vp > 0.0 and joueur.get("vigueur") != null:
		joueur.set("vigueur", minf(float(joueur.get("vigueur_max")), float(joueur.get("vigueur")) + vp))
	var riposte := p.bonus("riposte")
	var etourdir := p.bonus("etourdir_parade")
	if riposte <= 0.0 and etourdir <= 0.0:
		return
	var att := attaquant_pres(joueur, origine)
	if att == null:
		return
	var st := Statuts.de(att)
	if st == null:
		return
	if riposte > 0.0:
		st.infliger(degats * riposte, "tranchant", joueur)
	if etourdir > 0.0 and randf() < etourdir:
		st.appliquer("choc", DUREE_ETOURDI, DUREE_ETOURDI, joueur)

## Ennemi vivant (groupe « ennemis ») le plus proche de `origine`, à moins de PORTEE_RIPOSTE m ; null sinon.
static func attaquant_pres(n: Node, origine: Vector3) -> Node3D:
	if n == null or not n.is_inside_tree():
		return null
	var meilleur: Node3D = null
	var d_min := PORTEE_RIPOSTE
	for e in n.get_tree().get_nodes_in_group("ennemis"):
		if not e is Node3D or e.get("est_mort") == true or (e.has_method("vivant") and not e.vivant()):
			continue
		var d := (e as Node3D).global_position.distance_to(origine)
		if d < d_min:
			d_min = d
			meilleur = e
	return meilleur

## Facteur de coût d'un sort du joueur (MainSort) : 1 − cout_sorts − cout_destruction | cout_restauration (selon l'école)
## − cout_double (double incantation) ; plancher COUT_SORT_MIN. 1,0 sans joueur.
static func facteur_cout_sort(ecole: String, double := false) -> float:
	var p := courante()
	if p == null:
		return 1.0
	var r := p.bonus("cout_sorts") + p.bonus("cout_restauration" if ecole in ECOLES_RESTAURATION else "cout_destruction")
	if double:
		r += p.bonus("cout_double")
	return clampf(1.0 - r, COUT_SORT_MIN, 1.0)

## Récupération en attente (perk « recup_furtif ») : posée par attaque_furtive, prise par joueur (lignes de régén.).
var recup_furtive := 0.0

## Attaque furtive qui a porté (CalculDegats) : pratique de la Furtivité (3 + 2 % des dégâts) et récupération des perks.
static func attaque_furtive(degats: float) -> void:
	var p := courante()
	if p == null:
		return
	p.pratiquer("furtivite", 3.0 + degats * 0.02)
	p.recup_furtive += p.bonus("recup_furtif")

## Vigueur et mana à rendre (perk Mémoire de Muninn) ; remis à 0.
func prendre_recup_furtive() -> float:
	var r := recup_furtive
	recup_furtive = 0.0
	return r

## Maxima dérivés (joueur.recalculer_stats) : jamais stockés, toujours recalculés.
func bonus_vie() -> float:
	return float(attributs["vie"]) + bonus("vie_max")

func bonus_magie() -> float:
	return float(attributs["magie"]) + bonus("magie_max")

func bonus_vigueur() -> float:
	return float(attributs["vigueur"]) + bonus("vigueur_max")

func bonus_charge() -> float:
	return float(attributs["vigueur"]) * CHARGE_PAR_VIGUEUR + bonus("charge")

# ------------------------------------------------------------------ sauvegarde (clé « progression », version 2)

func exporter() -> Dictionary:
	var c := competences.exporter()
	var niv := {}
	var xp := {}
	for k in _comp_inconnues["niveaux"]:
		niv[k] = _comp_inconnues["niveaux"][k]
	for k in _comp_inconnues["experience"]:
		xp[k] = _comp_inconnues["experience"][k]
	for k in c["niveaux"]:
		niv[canonique(k)] = c["niveaux"][k]
	for k in c["experience"]:
		xp[canonique(k)] = c["experience"][k]
	return {"niveau": niveau, "xp_niveau": xp_niveau, "points_perk": points_perk, "points_attribut": points_attribut,
		"attributs": attributs.duplicate(), "perks": perks.duplicate(), "competences": {"niveaux": niv, "experience": xp}}

func importer(d: Dictionary) -> void:
	niveau = clampi(int(d.get("niveau", 1)), 1, NIVEAU_MAX)
	xp_niveau = maxf(0.0, float(d.get("xp_niveau", 0.0)))
	points_perk = maxi(0, int(d.get("points_perk", 0)))
	points_attribut = maxi(0, int(d.get("points_attribut", 0)))
	var a: Dictionary = d.get("attributs", {})
	for k in ATTRIBUTS:
		attributs[k] = int(a.get(k, 0))
	perks = {}
	_effets_cache = {}
	var p: Dictionary = d.get("perks", {})
	for k in p:
		if not perk(String(k)).is_empty() and int(p[k]) > 0:   # perk retiré de l'arbre : son point est rendu
			perks[String(k)] = mini(int(p[k]), rangs_max(String(k)))
			points_perk += maxi(0, int(p[k]) - perks[String(k)])
		elif int(p[k]) > 0:
			points_perk += int(p[k])
	var c: Dictionary = d.get("competences", {})
	var niv: Dictionary = c.get("niveaux", {})
	var xp: Dictionary = c.get("experience", {})
	var interne_niv := {}
	var interne_xp := {}
	_comp_inconnues = {"niveaux": {}, "experience": {}}
	for k in niv:
		var i := interne(String(k))
		if competences.niveaux.has(i):
			interne_niv[i] = niv[k]
		else:
			_comp_inconnues["niveaux"][String(k)] = int(niv[k])
	for k in xp:
		var i := interne(String(k))
		if competences.niveaux.has(i):
			interne_xp[i] = xp[k]
		else:
			_comp_inconnues["experience"][String(k)] = float(xp[k])
	competences.importer({"niveaux": interne_niv, "experience": interne_xp})
	change.emit()
