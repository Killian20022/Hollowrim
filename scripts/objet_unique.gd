class_name ObjetUnique
extends Node3D
## Lot L9 « objets uniques et armes exposées » (docs/INSPIRATION_IGNITE.md §2.14, §2.18) : une arme UNIQUE posée dans le monde en
## modèle 3D (plus un nom dans un sac), sur son présentoir (trône, râtelier, chevalet : décor fondu, il reste quand l'arme est prise).
##   - le MODÈLE est ce nœud : glb d'épée habillé (EpeesLongues : reflet de lame compris) ou module Blender à part
##     (CrypteDecor.maillage_modele, ex. « hache_kolbeinn ») ; aucun _process ; portée de dessin bornée comme le décor ;
##   - l'INTERACTION (touche E, invite sous le réticule) est posée par l'hôte (tertre, grotte, monde) avec sa propre fonction
##     _interactif, condition = pas encore pris (+ conditions de l'hôte : ennemi vaincu, étape de quête) ; action = prendre() ;
##   - PRIS = ButinTables.pilles["unique:<objet>"] (sauvegardé avec le butin, ne réapparaît pas, même après la mort) ; l'objet
##     entre au sac par ButinTables.prendre (rareté « unique » : uniques_pris, un second exemplaire tiré d'un coffre devient des pièces) ;
##     quetes signale « ramasse:<objet> » tout seul (Inventaire.change) ;
##   - marchands : valeur de la fiche (Inventaire.objet), refus « objet de quête » géré par Marchand.de_quete.
## Fiches : FICHES ci-dessous (nom affiché, verbe, modèle) ; les objets eux-mêmes sont dans Inventaire.OBJETS / data/butin/objets.json.

const PREFIXE := "unique:"
const PORTEE := 34.0
## objet -> {nom, verbe, glb (variante EpeesLongues) | module (objets_donjon.dat), mats (matières du module)}
const FICHES := {
	"hache_kolbeinn": {"nom": "Hache de Kolbeinn le Gelé", "verbe": "Prendre la hache", "module": "hache_kolbeinn",
		"mats": {"lame": "lame", "fer": "fer", "bois": "bois", "or": "or", "noir": "noir", "entrelacs": "entrelacs"}},
	"epee_skarnholt": {"nom": "Épée de Skarnholt", "verbe": "Prendre l’épée", "glb": "skarnholt"},
	"epee_obsidienne": {"nom": "Épée d’obsidienne", "verbe": "Prendre l’épée", "glb": "obsidienne"},
	"epee_hrafn": {"nom": "Croc-Rouge, l’épée de Hrafn", "verbe": "Prendre l’épée", "glb": "rubis"},
}

var objet := ""
## Condition de présence en plus de « pas encore pris » (ex. étape de quête atteinte) ; invalide = toujours là.
var presence := Callable()

static func cle(objet_id: String) -> String:
	return PREFIXE + objet_id

## Déjà pris (sauvegardé) ?
static func pris(objet_id: String) -> bool:
	return ButinTables.est_pille(cle(objet_id))

static func nom_de(objet_id: String) -> String:
	return String(FICHES.get(objet_id, {}).get("nom", Inventaire.objet(objet_id).get("nom", objet_id)))

static func verbe_de(objet_id: String) -> String:
	return String(FICHES.get(objet_id, {}).get("verbe", "Prendre"))

## Nœud de l'objet posé en `xf` (repère du parent) ; `dcr` sert aux modules Blender (peut être null pour un glb). À appeler sur le fil
## principal (chargement du glb, matériaux du décor). null si le modèle manque.
static func creer(objet_id: String, xf: Transform3D, dcr: CrypteDecor = null) -> ObjetUnique:
	var f: Dictionary = FICHES.get(objet_id, {})
	var m: Node3D = null
	if f.has("glb") and ResourceLoader.exists(EpeesLongues.DOSSIER + String(f["glb"]) + ".glb"):
		m = EpeesLongues.instancier(String(f["glb"]))
	elif f.has("module") and dcr != null:
		m = dcr.maillage_modele(String(f["module"]), Vector3.ONE, f.get("mats", {}))
	if m == null:
		push_warning("objet unique sans modèle : " + objet_id)
		return null
	var u := ObjetUnique.new()
	u.name = "Unique_" + objet_id
	u.objet = objet_id
	u.transform = xf
	u.add_child(m)
	for g in u.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.visibility_range_end = PORTEE
		gi.visibility_range_end_margin = 3.0
	if m is GeometryInstance3D:
		var gm := m as GeometryInstance3D
		gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gm.visibility_range_end = PORTEE
		gm.visibility_range_end_margin = 3.0
	u.actualiser()
	return u

## Visible tant que l'objet n'est pas pris (partie chargée, mort du joueur : relu dans ButinTables).
func actualiser() -> void:
	visible = not pris(objet) and (not presence.is_valid() or bool(presence.call()))

## Met l'objet au sac (une seule fois), retire le modèle ; renvoie les lignes de la boîte de dialogue (aucune : un avis suffit).
## `noeud` : l'ObjetUnique posé (null : tests) ; `hud` peut être null.
static func prendre(objet_id: String, inv: Inventaire, hud: Node = null, noeud: ObjetUnique = null) -> Array:
	if pris(objet_id):
		return []
	ButinTables.piller(cle(objet_id))
	var res := ButinTables.prendre(inv, [{"id": objet_id, "n": 1, "rarete": "unique"}])
	if hud != null and hud.has_method("avis"):
		for o: Dictionary in res:
			var oid := String(o["id"])
			hud.avis(("+ %d pièces" % int(o["n"])) if oid == "pieces" else ("+ %s  (unique)" % inv.nom(oid)))
	if noeud != null and is_instance_valid(noeud):
		Sons.jouer_a(noeud, ["impactMetal_heavy_000", "cloth1"], noeud.global_position, -12.0)
		noeud.actualiser()
	return []
