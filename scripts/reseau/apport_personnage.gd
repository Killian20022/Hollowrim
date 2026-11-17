class_name ApportPersonnage
extends Node
## Lot 5b : un invité apporte SON personnage à l'hôte (nœud enfant du monde ; inerte hors ligne).
##
##   invité : au monde prêt, lit user://personnages/<nom>.json et l'envoie (compressé) à l'hôte  -> évènement « apport_perso »
##   hôte   : valide (SauvegardeMulti.valider : types, plafonds, objets inconnus, position) puis renvoie la version ASSAINIE
##            et un point d'apparition près de lui                                                   -> évènement « apport_resultat »
##   invité : applique le personnage assaini (Monde.importer_personnage, sans la position de retour) et apparaît près de l'hôte
##
## À la sortie (menu pause, fermeture, sauvegarde automatique) et si l'hôte disparaît, l'invité écrit son personnage chez lui
## (Monde.sauvegarder_personnage). L'hôte, lui, sauvegarde le monde (et son propre personnage) comme en solo.
## Voir docs/reseau_lot5b.md.

signal resultat(infos: Dictionary)   ## invité : {"ok", "restaure" (un fichier existait), "corrections", "position", "raison"}

const DELAI_REPONSE := 12.0

var monde: Node
var etat := ""   ## invité : "" | "attente" | "ok" | "refuse" | "sans_reponse"
var derniere_infos := {}
var _fait := false

static func installer(m: Node) -> ApportPersonnage:
	var a := ApportPersonnage.new()
	a.name = "ApportPersonnage"
	a.monde = m
	m.add_child(a)
	return a

func _R() -> Node:
	return get_node_or_null("/root/Reseau")

func _ready() -> void:
	var r := _R()
	if r == null:
		return
	r.call("abonner", "apport_perso", _sur_apport)
	r.call("abonner", "apport_resultat", _sur_resultat)
	r.connect("joueur_deconnecte", _sur_deconnecte)
	if r.has_signal("hote_perdu"):
		r.connect("hote_perdu", _sur_hote_perdu)   # lot 7 : émis AVANT le retour en solo / au titre : l'état du personnage est intact
	if bool(r.call("est_en_ligne")) and not bool(r.call("est_hote")):
		_envoyer.call_deferred()

func _exit_tree() -> void:
	var r := _R()
	if r != null:
		r.call("desabonner", "apport_perso", _sur_apport)
		r.call("desabonner", "apport_resultat", _sur_resultat)

# ---------- invité ----------

func _envoyer() -> void:
	if _fait:
		return
	_fait = true
	var r := _R()
	var nom := String(r.get("nom_joueur"))
	var perso := SauvegardeMulti.lire_personnage(nom)
	etat = "attente"
	r.call("envoyer_evenement", "apport_perso", int(r.call("mon_id")), _emballer({"nom": nom, "existe": not perso.is_empty(), "perso": perso}))
	get_tree().create_timer(DELAI_REPONSE).timeout.connect(func() -> void:
		if etat == "attente":
			etat = "sans_reponse"
			_avis("L'hôte n'a pas confirmé le personnage : partie avec un personnage neuf."))

func _sur_resultat(expediteur: int, _id: Variant, d: Variant) -> void:
	if expediteur != 1 or etat != "attente":
		return
	var r := _deballer(d)
	derniere_infos = r
	if not bool(r.get("ok", false)):
		etat = "refuse"
		_avis("Personnage refusé par l'hôte : %s" % String(r.get("raison", "")))
		resultat.emit(r)
		return
	etat = "ok"
	var perso: Dictionary = r.get("perso", {}) if r.get("perso") is Dictionary else {}
	if not perso.is_empty() and monde != null:
		monde.call("importer_personnage", perso, false)
		var cr: Variant = monde.get("crime")   # la prime restaurée repart vers l'hôte (crime_perso envoyé trop tôt avec l'état neuf)
		if cr != null and cr.get("coop") != null:
			cr.coop.renvoyer_perso()
	var p: Variant = r.get("position")
	if p is Array and (p as Array).size() == 3 and monde != null and monde.get("joueur") != null:
		var j: Node3D = monde.joueur
		var cible := Vector3(float(p[0]), float(p[1]) + 0.2, float(p[2]))
		j.position = monde.village.position_sure(cible) if monde.get("village") != null else cible
		if "velocity" in j:
			j.velocity = Vector3.ZERO
	var corr: Array = r.get("corrections", [])
	_avis("Personnage restauré" if not perso.is_empty() else "Nouveau personnage dans cette partie")
	if not corr.is_empty():
		_avis("L'hôte a corrigé : " + ", ".join(corr))
	resultat.emit(r)

var hote_perdu_sauvegarde := false   # vrai si la sauvegarde a été faite à l'annonce « hôte perdu » (test)
func _sur_hote_perdu(_raison: String) -> void:
	if monde != null and etat in ["ok", "sans_reponse", "refuse"] and monde.has_method("sauvegarder_personnage"):
		hote_perdu_sauvegarde = bool(monde.call("sauvegarder_personnage"))

func _sur_deconnecte(id: int) -> void:
	# l'hôte est parti : l'invité garde son personnage chez lui
	if id == 1 and monde != null and etat in ["ok", "sans_reponse", "refuse"] and monde.has_method("sauvegarder_personnage"):
		monde.call("sauvegarder_personnage")

# ---------- hôte ----------

func _sur_apport(expediteur: int, _id: Variant, d: Variant) -> void:
	var r := _R()
	if r == null or not bool(r.call("est_hote")) or monde == null:
		return
	print("APPORT : reçu de %d" % expediteur)
	var recu := _deballer(d)
	var v := SauvegardeMulti.valider(recu.get("perso", {}))
	var rep := {"ok": bool(v["ok"]), "raison": String(v["raison"]), "corrections": v["corrections"], "perso": v["personnage"]}
	if bool(v["ok"]):
		var j: Node3D = monde.joueur
		var rang := maxi(0, (r.call("joueurs") as Array).find(expediteur))
		var ang := 0.8 + TAU * float(rang) / 4.0
		var base := j.global_position
		var pos := base + Vector3(cos(ang), 0.0, sin(ang)) * 2.2
		rep["position"] = [pos.x, base.y, pos.z]
		var nom := String(recu.get("nom", ""))
		var niv := int((v["personnage"].get("progression", {}) as Dictionary).get("niveau", 1)) if v["personnage"].get("progression") is Dictionary else 1
		var reg: Variant = r.get("registre")
		reg.call("definir_info", expediteur, "niveau", niv)
		reg.call("definir_info", expediteur, "personnage_valide", true)
		print("APPORT : %s (pair %d) niveau %d, %d correction(s)%s" % [nom, expediteur, niv, (v["corrections"] as Array).size(), " : " + ", ".join(v["corrections"]) if not (v["corrections"] as Array).is_empty() else ""])
	r.call("envoyer_evenement", "apport_resultat", expediteur, _emballer(rep), expediteur)


# ---------- transport ----------

## Dictionnaire -> {"taille", "octets"} (var_to_bytes + zstd) : un personnage fait vite plusieurs dizaines de Ko.
static func _emballer(d: Dictionary) -> Dictionary:
	var brut := var_to_bytes(d)
	return {"taille": brut.size(), "octets": brut.compress(FileAccess.COMPRESSION_ZSTD)}

static func _deballer(d: Variant) -> Dictionary:
	if not d is Dictionary or not (d as Dictionary).has("octets"):
		return {}
	var taille := int((d as Dictionary).get("taille", 0))
	if taille <= 0 or taille > SauvegardeMulti.TAILLE_MAX * 2:
		return {}
	var brut: PackedByteArray = ((d as Dictionary)["octets"] as PackedByteArray).decompress(taille, FileAccess.COMPRESSION_ZSTD)
	var r: Variant = bytes_to_var(brut)   # sans objets : jamais bytes_to_var_with_objects sur des données d'un pair
	return r if r is Dictionary else {}

func _avis(texte: String) -> void:
	print("APPORT : ", texte)
	if monde != null and monde.get("hud") != null and (monde.hud as Object).has_method("avis"):
		monde.hud.avis(texte)
