class_name CrimeCoop
extends Node
## LOT 5a — crime et justice PAR JOUEUR en réseau (docs/reseau_lot5a.md). Enfant du nœud Crime ; inerte hors ligne.
##  - L'HÔTE arbitre : témoins, gardes, primes. Chaque joueur (hôte compris) a son état de justice (Crime.Perso : primes, réputation,
##    hostilité, objets volés, arrestation) ; un garde ne réagit qu'au joueur qui a commis le crime (PnjCombat.peer / cibler).
##  - L'INVITÉ signale ses gestes (vol, intrusion, crochetage) à l'hôte ; l'hôte lui renvoie son état (« miroir ») : l'invité l'affiche et le
##    SAUVEGARDE dans son personnage ; à la connexion il renvoie à l'hôte l'état de son personnage (crime_perso).
##  - Ce qui touche le sac, les rangs ou la position du joueur (amende payée, objets saisis, peine de geôle, réputation de faction) s'exécute
##    CHEZ LE JOUEUR sur ordre de l'hôte (crime_rangs, crime_prison) ; l'arrestation d'un invité s'ouvre dans SON dialogue (crime_arret).
## Évènements invité -> hôte : crime_vol, crime_intrusion, crime_choix, crime_perso. Hôte -> invité : crime_miroir, crime_avis, crime_dire,
## crime_rangs, crime_arret, crime_plaidoyer, crime_prison, crime_morts.

const EV_INVITE := ["crime_vol", "crime_intrusion", "crime_choix", "crime_perso"]
const EV_HOTE := ["crime_miroir", "crime_avis", "crime_dire", "crime_rangs", "crime_arret", "crime_plaidoyer", "crime_prison", "crime_morts"]

var crime: Crime
var _derniers := {}            # contexte -> hachage du dernier miroir envoyé
var _accroches := {}           # peer -> avatar dont « deces » est branché
var _t := 0.0
var _perso_envoye := false
var _decide := true            # invité : l'arrestation affichée est réglée (sinon Échap = résister)
var _boite: ArretDistant = null

## Installe le nœud sous `c` (appelé par Crime._ready).
static func installer(c: Crime) -> CrimeCoop:
	var n := CrimeCoop.new()
	n.name = "CrimeCoop"
	n.crime = c
	c.add_child(n)
	return n

func _r() -> Node:
	return PauseCoop.R()

func _ready() -> void:
	var r := _r()
	if r == null:
		return
	for t: String in EV_INVITE:
		r.abonner(t, Callable(self, "_sur_" + t.substr(6)))
	for t: String in EV_HOTE:
		r.abonner(t, Callable(self, "_sur_" + t.substr(6)))
	r.joueur_deconnecte.connect(_sur_deconnecte)
	r.connexion_reussie.connect(func() -> void: _perso_envoye = false)
	var rj := r.get_node_or_null("/root/Rejoindre")
	if rj == null:
		rj = get_node_or_null("/root/Rejoindre")
	if rj != null:
		rj.contributeur("crime", Callable(self, "exporter_monde"), Callable(self, "importer_monde"))

func _exit_tree() -> void:
	var r := _r()
	if r == null:
		return
	for t: String in EV_INVITE + EV_HOTE:
		r.desabonner(t, Callable(self, "_sur_" + t.substr(6)))

# ---------------------------------------------------------------------------------------------------- envoi

## Invité -> hôte.
func envoyer(type: String, donnees: Variant) -> void:
	var r := _r()
	if r != null and r.est_en_ligne() and not r.est_hote():
		r.envoyer_evenement(type, 0, donnees)

## Hôte -> un invité (`peer` = son identifiant réseau, donc le contexte de Crime).
func envoyer_a(peer: int, type: String, donnees: Variant) -> void:
	var r := _r()
	if r != null and r.est_en_ligne() and r.est_hote() and peer > 1:
		r.envoyer_evenement(type, 0, donnees, peer)

## Hôte : les PNJ tués (partagés par tous : un mort reste mort pour chacun).
func diffuser_morts() -> void:
	var r := _r()
	if r != null and r.est_en_ligne() and r.est_hote():
		r.envoyer_evenement("crime_morts", 0, crime.morts.duplicate())

## Hôte : état de justice de l'invité `ctx` (primes, réputation, hostilité, réputation perdue), renvoyé seulement s'il a changé.
func miroir(ctx: int) -> void:
	var p: Crime.Perso = crime._persos.get(ctx)
	if p == null:
		return
	var d := {"primes": p.primes.duplicate(), "reputation": p.reputation.duplicate(), "hostile": p.hostile.duplicate(), "perdue": p.perdue.duplicate()}
	var h := hash(d)
	if _derniers.get(ctx, -1) == h:
		return
	_derniers[ctx] = h
	envoyer_a(ctx, "crime_miroir", d)

## État de justice d'un personnage (ce qui est sauvegardé dans SON fichier : l'invité l'envoie à l'hôte à la connexion).
func exporter_perso() -> Dictionary:
	return {"primes": crime.primes.duplicate(), "reputation": crime.reputation.duplicate(), "hostile": crime.hostile.duplicate(),
		"perdue": crime.perdue.duplicate(), "perdue_factions": crime.perdue_factions.duplicate(), "niveau": crime._niveau()}

## État de justice reçu pour le joueur courant (dictionnaires de primes, etc. ; tolère l'absence de clés).
func _adopter(p: Crime.Perso, d: Dictionary, avec_factions: bool) -> void:
	for k: String in ["primes", "reputation", "hostile", "perdue"]:
		if d.get(k) is Dictionary:
			p.set(k, (d[k] as Dictionary).duplicate())
	if avec_factions and d.get("perdue_factions") is Dictionary:
		p.perdue_factions = (d["perdue_factions"] as Dictionary).duplicate()
	if d.has("niveau"):
		p.niveau = int(d["niveau"])

## Invité : le personnage sauvegardé vient d'être appliqué (apport 5b) : l'hôte doit adopter SA prime, pas l'état neuf déjà envoyé à la connexion.
func renvoyer_perso() -> void:
	_perso_envoye = false

## Instantané « rejoindre en cours de partie » : les PNJ tués (le reste de la justice est PAR personnage, il n'est pas partagé).
func exporter_monde() -> Dictionary:
	return {"morts": crime.morts.duplicate()}

func importer_monde(d: Dictionary) -> void:
	var r := _r()
	if r != null and r.est_hote():
		return
	if d.get("morts") is Array:
		for m in d["morts"]:
			if not crime.morts.has(m):
				crime.morts.append(m)

# ---------------------------------------------------------------------------------------------------- suivi
func _process(dt: float) -> void:
	var r := _r()
	if r == null or not r.est_en_ligne():
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 1.0
	if r.est_hote():
		for id: int in r.registre.ids():
			if id == 1:
				continue
			var av: Node = r.registre.noeud(id)
			if av != null and _accroches.get(id) != av and av.has_signal("deces"):
				_accroches[id] = av
				av.connect("deces", func() -> void: crime.dans_contexte(id, crime.apaiser_tous))
	else:
		if not _perso_envoye and r.mon_id() > 1 and r.multiplayer.multiplayer_peer != null \
				and r.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_perso_envoye = true
			envoyer("crime_perso", exporter_perso())
		crime._ronde_monde()          # les PNJ tués par un autre joueur disparaissent aussi chez l'invité

func _sur_deconnecte(id: int) -> void:
	if id == 1 or not _r().est_hote():
		return
	for c: PnjCombat in crime.combattants.duplicate():
		if is_instance_valid(c) and c.peer == id:
			c.pacifier()
	for a: Dictionary in crime._alertes.duplicate():
		if int(a.get("peer", 0)) == id:
			crime._alertes.erase(a)
	crime._persos.erase(id)
	_derniers.erase(id)
	_accroches.erase(id)

# ---------------------------------------------------------------------------------------------------- hôte : demandes d'un invité

func _sur_vol(exp: int, _id: Variant, d: Variant) -> void:
	if not _r().est_hote() or not (d is Dictionary):
		return
	crime.en_tant_que(exp, func() -> void:
		crime._p().niveau = int(d.get("niveau", 1))
		crime.vol_arbitre(String(d["id"]), int(d["n"]), String(d["proprietaire"]), d["pos"] as Vector3))

func _sur_intrusion(exp: int, _id: Variant, d: Variant) -> void:
	if not _r().est_hote() or not (d is Dictionary):
		return
	crime.en_tant_que(exp, func() -> void:
		crime.intrusion_arbitree(d["pos"] as Vector3, String(d["proprietaire"]), String(d["type"])))

## Un invité arrive avec l'état de justice de SON personnage : l'hôte l'adopte (une fois, sans écraser une prime déjà arbitrée).
func _sur_perso(exp: int, _id: Variant, d: Variant) -> void:
	if not _r().est_hote() or not (d is Dictionary):
		return
	var p: Crime.Perso = crime._persos.get(exp)
	if p == null:
		p = Crime.Perso.new()
		crime._persos[exp] = p
	_adopter(p, d, true)
	miroir(exp)

## Choix de l'invité arrêté (amende payée chez lui, geôle, plaidoyer, résistance).
func _sur_choix(exp: int, _id: Variant, d: Variant) -> void:
	if not _r().est_hote() or not (d is Dictionary):
		return
	crime.en_tant_que(exp, _choix_arbitre.bind(exp, d as Dictionary))

func _choix_arbitre(exp: int, d: Dictionary) -> void:
	crime._p().niveau = int(d.get("niveau", crime._p().niveau))
	match String(d.get("choix", "")):
		"amende":
			crime._dire(crime.arrestation, "amende")
			crime._rendre_reputation("amende")
			crime._gracier()
		"geole":
			crime.aller_en_prison()
		"plaider":
			var ok := crime.plaider(float(d.get("jet", -1.0)))
			envoyer_a(exp, "crime_plaidoyer", {"reussi": ok, "ligne": crime._ligne_plaidoyer, "prime": crime.prime()})
		"resister":
			crime.resister()

## Hôte : un garde au contact d'un invité recherché lui propose l'arrestation (dialogue chez l'invité). Vrai = proposée.
func proposer_arrestation_distante(g: PnjCombat) -> bool:
	var ctx := crime.contexte()
	var av := crime.joueur
	if av == null or bool(av.get("mort")):
		return false
	if crime.prime() < 1.0:
		crime._dire(g, "pardon")
		g.pacifier()
		return false
	crime.arrestation = g
	crime.treve = true
	crime.plaide = false
	crime._ligne_plaidoyer = ""
	envoyer_a(ctx, "crime_arret", {"nom": Crime.nom_de(g), "prime": crime.prime(), "lignes": crime.lignes_arrestation(g.rends_toi),
		"chance": crime.chance_plaider()})
	return true

# ---------------------------------------------------------------------------------------------------- invité : ordres de l'hôte

func _sur_miroir(exp: int, _id: Variant, d: Variant) -> void:
	if exp != 1 or _r().est_hote() or not (d is Dictionary):
		return
	var p := crime._persos.get(0) as Crime.Perso
	if p == null:
		p = Crime.Perso.new()
		crime._persos[0] = p
	_adopter(p, d, false)
	for j: String in p.primes:
		crime.prime_change.emit(j, float(p.primes[j]))

func _sur_avis(exp: int, _id: Variant, d: Variant) -> void:
	if exp == 1 and not _r().est_hote():
		crime._avis(String(d))

func _sur_dire(exp: int, _id: Variant, d: Variant) -> void:
	if exp == 1 and not _r().est_hote() and d is Array and crime.dialogue != null and is_instance_valid(crime.dialogue):
		crime.dialogue.dire_au_passage(String(d[0]), String(d[1]))

func _sur_morts(exp: int, _id: Variant, d: Variant) -> void:
	if exp == 1 and not _r().est_hote() and d is Array:
		for m in d:
			if not crime.morts.has(m):
				crime.morts.append(m)

## Réputation de faction du personnage (rangs.gd chez lui) : punie / rendue sur ordre de l'hôte.
func _sur_rangs(exp: int, _id: Variant, d: Variant) -> void:
	if exp != 1 or _r().est_hote() or not (d is Dictionary):
		return
	var rg := Rangs.courant
	if rg == null or not is_instance_valid(rg):
		return
	match String(d.get("op", "")):
		"punir":
			var f := rg.faction_juridiction(Crime.JURIDICTION)
			if f != "":
				var perdu := rg.retirer_reputation(f, rg.perte_crime(String(d["type"])))
				crime.perdue_factions[f] = float(crime.perdue_factions.get(f, 0.0)) + perdu
		"membre_tue":
			var f2 := rg.faction_du_membre(String(d["cle"]))
			if f2 != "":
				rg.retirer_reputation(f2, rg.perte_membre_tue(f2))
		"rendre":
			for f3: String in crime.perdue_factions:
				rg.rendre_reputation(f3, float(crime.perdue_factions[f3]) * float(d.get("part", 0.5)))
			crime.perdue_factions = {}

## Arrestation proposée par l'hôte : le dialogue (amende / plaidoyer / geôle / résister) s'ouvre ICI.
func _sur_arret(exp: int, _id: Variant, d: Variant) -> void:
	if exp != 1 or _r().est_hote() or not (d is Dictionary):
		return
	ouvrir_arret(d)

func ouvrir_arret(d: Dictionary) -> bool:
	if _boite != null and is_instance_valid(_boite):
		_boite.queue_free()
	_boite = ArretDistant.new()
	_boite.coop = self
	_boite.nom = String(d.get("nom", "Garde"))
	_boite.prime = float(d.get("prime", 0.0))
	_boite.lignes = (d.get("lignes", ["Halte !"]) as Array).duplicate()
	_boite.chance = float(d.get("chance", 50.0))
	crime.add_child(_boite)
	_decide = false
	crime.plaide = false
	if crime.dialogue != null and crime.dialogue.has_method("engager") and crime.dialogue.engager(_boite):
		return true
	_decide = true
	choisir("resister")           # pas de dialogue possible (déjà ouvert) : c'est une résistance
	return false

## Choix du joueur arrêté (appelé par la boîte de dialogue ; testable sans interface).
func choisir(choix: String, jet := -1.0) -> void:
	_decide = true
	if choix == "amende":
		var p := ceili(_boite.prime if _boite != null else crime.prime())
		if crime.joueur.inventaire.pieces < p:
			crime._avis("Tu n'as que %d pièces : en geôle." % crime.joueur.inventaire.pieces)
			choix = "geole"
		else:
			crime.joueur.inventaire.retirer("pieces", p)
			var n := crime._confisquer()
			crime._avis("Amende payée : %d pièces.%s" % [p, (" %d objets volés saisis." % n) if n > 0 else ""])
	envoyer("crime_choix", {"choix": choix, "niveau": crime._niveau(), "jet": jet})
	if choix == "plaider":
		crime.plaide = true
		_decide = false          # on attend la réponse (_sur_plaidoyer)

func _sur_plaidoyer(exp: int, _id: Variant, d: Variant) -> void:
	if exp != 1 or _r().est_hote() or not (d is Dictionary):
		return
	if bool(d.get("reussi", false)):
		_decide = true
		crime._avis("Ta plaidoirie a convaincu le garde : prime levée.")
		return
	crime._avis("Plaidoirie rejetée : prime de %d pièces." % roundi(float(d.get("prime", 0.0))))
	if _boite != null and is_instance_valid(_boite):
		_boite.prime = float(d.get("prime", _boite.prime))
		_boite.lignes = [String(d.get("ligne", "…")), (_boite.lignes[_boite.lignes.size() - 1] if not _boite.lignes.is_empty() else "")]
		_decide = false
		if crime.dialogue == null or not crime.dialogue.engager(_boite):
			choisir("resister")

## Peine de geôle prononcée par l'hôte : objets volés saisis, XP perdue, sortie devant la longue maison, vie pleine — chez le joueur.
func _sur_prison(exp: int, _id: Variant, d: Variant) -> void:
	if exp != 1 or _r().est_hote() or not (d is Dictionary):
		return
	_decide = true
	var j := crime.joueur
	var heures := float(d.get("heures", 12.0))
	var n := crime._confisquer()
	var prog: Progression = j.get("progression")
	if prog != null:
		prog.xp_niveau *= 0.85
		for k in prog.competences.experience:
			prog.competences.experience[k] = float(prog.competences.experience[k]) * 0.6
		prog.change.emit()
	j.global_position = d.get("sortie", j.global_position) as Vector3
	j.velocity = Vector3.ZERO
	j.vie = j.vie_max
	if crime.hud != null and crime.hud.has_method("annonce"):
		crime.hud.annonce("Peine purgée", "%d heures en geôle%s" % [roundi(heures), (", %d objets saisis" % n) if n > 0 else ""])

## Fermeture du dialogue sans choix (Échap) : résistance.
func arret_ferme() -> void:
	if not _decide:
		_decide = true
		choisir("resister")

# ---------------------------------------------------------------------------------------------------- dialogue d'arrestation (invité)
## « PNJ » fictif présenté au Dialogue de l'invité : mêmes méthodes qu'un PnjCombat (parler, options_dialogue, nom_affiche, fin_conversation).
class ArretDistant extends Node3D:
	var coop: CrimeCoop
	var nom := "Garde"
	var prime := 0.0
	var lignes: Array = []
	var chance := 50.0

	func nom_affiche() -> String:
		return nom

	func parler() -> Array:
		return lignes

	func options_dialogue() -> Array:
		var p := ceili(prime)
		var o: Array = []
		var pauvre: bool = coop.crime.joueur.inventaire.pieces < p
		o.append({"texte": ("Payer l'amende (%d pièces)" if not pauvre else "Payer l'amende (%d pièces) : trop pauvre") % p, "action": coop.choisir.bind("amende"), "seul": true})
		if not coop.crime.plaide:
			o.append({"texte": "Plaider ta cause (%d %%)" % roundi(chance), "action": coop.choisir.bind("plaider"), "seul": true})
		o.append({"texte": "Aller en geôle", "action": coop.choisir.bind("geole"), "seul": true})
		o.append({"texte": "Résister", "action": coop.choisir.bind("resister"), "seul": true})
		return o

	func fin_conversation() -> void:
		(func() -> void:
			if is_instance_valid(coop):
				coop.arret_ferme()).call_deferred()
