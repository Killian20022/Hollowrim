class_name ServicesPnj
extends Node
## Lot E : services du village autour du stockage, branchés sur le monde par deux lignes de monde.gd (_interface, _villageois).
##   - crée les fenêtres FenetreCoffre (coffre sûr ↔ sac) et Forge (Brodd), et garde les armes forgées équipables
##     (Forge.synchroniser à chaque changement du sac) ;
##   - pose dans les intérieurs : le COFFRE LOUÉ chez Grima (son coffre près de la porte, dès le début), le coffre et le RÂTELIER
##     de la maison des Frostmark (Stockage.MAISON, accessibles après l'achat) ; le râtelier montre les armes rangées dans le
##     coffre de la maison (4 au plus, modèles 3D des armes) ;
##   - options de dialogue (Dialogue : liste de choix sur la dernière réplique) : Brodd « Forge », Gunnhild « Acheter la maison »,
##     Sigrún « Réinitialiser l'arbre » (Progression.reinitialiser_perks, lot B ; Progression.PRIX_REINITIALISATION pièces).

const GROUPE := "services_pnj"
## Coffre de Grima : InterieursMaisons._grima pose `b.coffre(Vector3(L/2 - 0.14 - 0.35, F, 0.6))` (L = 7) ; point d'action dessus.
const COFFRE_GRIMA := Vector3(3.01, Interieurs.F + 0.45, 0.6)
## Maison des Frostmark : coffre de InterieursMaisons._chasseurs (2,5 ; 2,05), râtelier neuf contre le mur ouest (x = -L/2).
const COFFRE_MAISON := Vector3(2.5, Interieurs.F + 0.45, 2.05)
const RATELIER := Vector3(-3.84, Interieurs.F, -0.35)
const RATELIER_PLACES := 4

var joueur: CharacterBody3D
var hud: Control
var monde: Node
var fenetre_coffre: FenetreCoffre
var forge: Forge
var ratelier: Node3D          # râtelier posé (null sans village)
var _armes_rack: Node3D
var _rack_vu := "?"
var _porte_maison: Node3D
var _t := 0.0

static func trouver(n: Node) -> ServicesPnj:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group(GROUPE) as ServicesPnj

func _ready() -> void:
	add_to_group(GROUPE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	fenetre_coffre = FenetreCoffre.new()
	fenetre_coffre.joueur = joueur
	fenetre_coffre.hud = hud
	add_child(fenetre_coffre)
	forge = Forge.new()
	forge.joueur = joueur
	forge.hud = hud
	add_child(forge)
	if joueur != null:
		joueur.inventaire.change.connect(func() -> void: Forge.synchroniser(joueur))
		Forge.synchroniser(joueur)

func _avis(t: String) -> void:
	if hud != null and hud.has_method("avis"):
		hud.avis(t)

# ------------------------------------------------------------------ options de dialogue

## Options de dialogue d'un villageois (id de data/villageois.json) : [{texte, action: Callable()}], [] s'il n'a rien à proposer.
func options(id_pnj: String) -> Array:
	var r: Array = []
	match id_pnj:
		"forgeron":
			r.append({"texte": "Forge", "action": func() -> void: forge.ouvrir()})
		"chef":
			if not Stockage.maison_achetee:
				r.append({"texte": "Acheter la maison (%s pièces)" % LivreParchemin.nombre(Stockage.PRIX_MAISON), "action": acheter_maison})
		"volva":
			r.append({"texte": "Oublier mes talents (%d pièces)" % Progression.PRIX_REINITIALISATION, "action": reinitialiser_arbre})
	return r

## Gunnhild vend la maison des Frostmark.
func acheter_maison() -> String:
	var r := Stockage.acheter_maison(joueur.inventaire)
	if r != "":
		_avis(r)
		return r
	_avis("Maison achetée : %s." % Stockage.NOM_MAISON)
	_avis("+ 1 %s" % joueur.inventaire.nom(Stockage.CLE_MAISON))
	actualiser_maison()
	Sons.jouer(self, ["handleCoins", "handleCoins2"], -6.0)
	return ""

## Sigrún rend les points de l'arbre (lot B : Progression.reinitialiser_perks) contre PRIX_REINITIALISATION pièces.
func reinitialiser_arbre() -> String:
	var p: Progression = joueur.get("progression")
	var r := refus_reinitialisation()
	if r != "":
		_avis(r)
		return r
	joueur.inventaire.retirer("pieces", Progression.PRIX_REINITIALISATION)
	var avant := p.points_perk
	p.reinitialiser_perks()
	_avis("Sigrún efface vos talents : %d point%s à replacer." % [p.points_perk, "s" if p.points_perk > 1 else ""] if p.points_perk > avant else "Sigrún efface vos talents.")
	return ""

func refus_reinitialisation() -> String:
	var p: Progression = joueur.get("progression") if joueur != null else null
	if p == null:
		return "Impossible ici."
	if p.perks.is_empty():
		return "Vous n'avez aucun talent à oublier."
	if joueur.inventaire.pieces < Progression.PRIX_REINITIALISATION:
		return "Il faut %d pièces." % Progression.PRIX_REINITIALISATION
	return ""

# ------------------------------------------------------------------ intérieurs

## Pose les coffres et le râtelier dans les intérieurs du village (après Village.activer_interieurs).
func poser(village: Node, dialogue: Control) -> void:
	if village == null or not village.has_method("interieur"):
		return
	var ig: Interieur = village.interieur("grima")
	if ig != null:
		var it := _interactif(dialogue, Stockage.COFFRES["coffre_grima"]["nom"], "Ouvrir le coffre loué", COFFRE_GRIMA)
		it.action = func() -> Array:
			fenetre_coffre.ouvrir("coffre_grima")
			return []
		ig.add_child(it)
	var im: Interieur = village.interieur(Stockage.MAISON)
	if im != null:
		var it := _interactif(dialogue, Stockage.COFFRES["coffre_maison"]["nom"], "Ouvrir le coffre de la maison", COFFRE_MAISON)
		it.condition = func() -> bool: return Stockage.maison_achetee
		it.action = func() -> Array:
			fenetre_coffre.ouvrir("coffre_maison")
			return []
		im.add_child(it)
		var mats: Dictionary = village.get("mats_int") if village.get("mats_int") is Dictionary else {}
		ratelier = _construire_ratelier(mats)
		ratelier.position = RATELIER
		im.racine.add_child(ratelier)
		var ir := _interactif(dialogue, "Râtelier d'armes", "Ranger des armes", RATELIER + Vector3(0.45, 0.85, 0))
		ir.condition = func() -> bool: return Stockage.maison_achetee
		ir.action = func() -> Array:
			fenetre_coffre.ouvrir("coffre_maison")
			return []
		im.add_child(ir)
		_porte_maison = im.interactif
		actualiser_maison()

func _interactif(dialogue: Control, nom: String, verbe: String, pos: Vector3) -> Node3D:
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.joueur = joueur
	it.dialogue = dialogue
	it.nom = nom
	it.verbe = verbe
	it.rayon = 1.7
	it.position = pos
	return it

## Après l'achat ou un chargement : nom de la porte, armes du râtelier.
func actualiser_maison() -> void:
	if _porte_maison != null and is_instance_valid(_porte_maison):
		_porte_maison.nom = "Votre maison" if Stockage.maison_achetee else String(_porte_maison.get_parent().get("nom"))
	_actualiser_ratelier()

func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	if ratelier != null:
		_actualiser_ratelier()
		if _porte_maison != null and is_instance_valid(_porte_maison) and (_porte_maison.nom == "Votre maison") != Stockage.maison_achetee:
			actualiser_maison()

## Armes du coffre de la maison montrées sur le râtelier (au plus RATELIER_PLACES, celles qui ont un modèle).
static func armes_exposees() -> Array[String]:
	var r: Array[String] = []
	if not Stockage.maison_achetee:
		return r
	var k := Stockage.conteneur("coffre_maison")
	for id: String in k.objets:
		if r.size() >= RATELIER_PLACES:
			break
		var d := Forge.arme_de_base(Forge.base_de(id))
		if d != null and d.categorie != DonneesArme.Categorie.BOUCLIER and d.modele != "" and ResourceLoader.exists(d.modele):
			r.append(id)
	return r

func _actualiser_ratelier() -> void:
	if ratelier == null or not is_instance_valid(ratelier):
		return
	var ex := armes_exposees()
	var cle := ",".join(ex)
	if cle == _rack_vu:
		return
	_rack_vu = cle
	if _armes_rack != null:
		_armes_rack.queue_free()
	_armes_rack = Node3D.new()
	_armes_rack.name = "Armes"
	ratelier.add_child(_armes_rack)
	for i in ex.size():
		var d := Forge.arme_de_base(Forge.base_de(ex[i]))
		var scene: Variant = load(d.modele)
		var m: Node3D = (scene as PackedScene).instantiate() if scene is PackedScene else null
		if m == null:
			continue
		EpeesLongues.habiller(m)
		var z := (i - (RATELIER_PLACES - 1) * 0.5) * 0.36
		# lame en haut, tranchant le long du mur, appuyée contre la traverse haute
		m.transform = Transform3D(Basis(Vector3.BACK, 0.1) * Basis(Vector3.UP, PI * 0.5), Vector3(0.16, 0.38, z))
		_armes_rack.add_child(m)

## Râtelier simple : deux montants, une traverse basse à encoches (pommeaux), une traverse haute contre le mur.
func _construire_ratelier(mats: Dictionary) -> Node3D:
	var r := Node3D.new()
	r.name = "Ratelier"
	var bois: Material = mats.get("bois_sombre", null)
	var fer: Material = mats.get("fer_noir", null)
	var pieces := [
		[Vector3(0.06, 1.35, 0.07), Vector3(0.04, 0.675, -0.78), bois],
		[Vector3(0.06, 1.35, 0.07), Vector3(0.04, 0.675, 0.78), bois],
		[Vector3(0.3, 0.06, 1.62), Vector3(0.15, 0.14, 0.0), bois],
		[Vector3(0.1, 0.07, 1.62), Vector3(0.06, 1.05, 0.0), bois],
		[Vector3(0.02, 0.02, 1.64), Vector3(0.115, 1.09, 0.0), fer],
		[Vector3(0.32, 0.02, 1.64), Vector3(0.15, 0.175, 0.0), fer],
	]
	for p: Array in pieces:
		var mi := MeshInstance3D.new()
		mi.mesh = PrimGeo.maillage(PrimGeo.boite(p[0]))
		mi.position = p[1]
		if p[2] != null:
			mi.material_override = p[2]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.add_child(mi)
	# encoches de la traverse basse (une par place)
	for i in RATELIER_PLACES:
		var mi := MeshInstance3D.new()
		mi.mesh = PrimGeo.maillage(PrimGeo.boite(Vector3(0.1, 0.03, 0.05)))
		mi.position = Vector3(0.2, 0.19, (i - (RATELIER_PLACES - 1) * 0.5) * 0.36)
		mi.material_override = fer
		r.add_child(mi)
	return r
