class_name InventaireMains
extends MenuPersonnage
## Menu du personnage + ACTIONS sur l'équipement (lot C). Depuis le lot C, l'ancien écran I (catégories Armes / Sorts /
## Potions / Divers dessinées en panneau sombre) et le panneau Tab du HUD sont remplacés par le codex MenuPersonnage
## (scripts/menu/menu_personnage.gd) : I ouvre l'onglet Sac, Tab le dernier onglet. Le nom de la classe est gardé (monde.gd,
## scenes/test_combat, tests) ; elle porte les actions que les onglets appellent (aucune règle ici : tout passe par
## EquipementMains, EquipementCorps, Consommables, Lacher) :
##   - equiper(main, id) : une main (MainSort.equiper, règles de data/magie/regles_mains.json), un objet de corps (porter), un
##     consommable (utiliser) ; refus jamais muet (raison dans le bandeau du menu) ;
##   - porter / retirer un objet de corps (EquipementCorps), retirer ce que tient une main ;
##   - utiliser un consommable, lâcher (1 ou toute la pile ; uniques et quête refusés), favoris ;
##   - raccourcis 1-0 : les deux mains actuelles (ou la potion choisie) rangées dans la touche ; vider une case.
## Compatibilité : `categorie` (armes / sorts / consommables / divers), `choisi`, `_changer_categorie`, `_choisir` pilotent
## les onglets Sac et Magie comme l'ancien écran (outils de capture, tests).

## Favoris du Sac (ids). Pas encore sauvegardés : clé de sauvegarde à demander à Max (docs/RPG.md §7).
var favoris := {}

## Catégorie de l'ancien écran : armes / sorts / consommables / divers (lecture et écriture).
var categorie: String:
	get:
		if onglet_actif == "magie":
			return "sorts"
		var s := onglet("sac")
		var f := String(s.get("filtre")) if s != null else "tout"
		return {"arme": "armes", "consommable": "consommables"}.get(f, "divers")
	set(v):
		_changer_categorie(v)

## Objet choisi dans l'onglet affiché (Sac ou Magie) ; "" sinon.
var choisi: String:
	get:
		var o := onglet_courant()
		return String(o.get("choisi")) if o != null and "choisi" in o else ""

func _magie() -> Node:
	if joueur == null or joueur.get("mains") == null:
		return null
	return joueur.mains.get("magie")

func _eq() -> EquipementMains:
	var m := _magie()
	return m.eq if m != null else null

## Identifiant de ce que tient une main, au format des raccourcis et du catalogue ("vide" pour la main nue).
func tenu(m: String) -> String:
	var eq := _eq()
	if eq == null or eq.categorie(m) == "vide":
		return "vide"
	return String(eq.mains[m].get("id", "vide"))

## L'objet `id` est-il tenu par la main `m` ? (« epee » et « epee_skarnholt » désignent la même lame quand Skarnholt est au sac).
func tient(m: String, id: String) -> bool:
	var t := tenu(m)
	if t == id:
		return true
	var eq := _eq()
	return eq != null and t != "vide" and id != "vide" and (t == "epee" or id == "epee") and eq.objet(t) != null and eq.objet(t) == eq.objet(id)

## L'objet se tient-il en main (arme, bouclier, torche, sort) ?
func tenable(id: String) -> bool:
	var eq := _eq()
	return eq != null and id != "" and eq.objet(id) != null

# ------------------------------------------------------------------ actions

## Équipe `id` : une main (`main` = gauche / droite), un objet de corps (porté), un consommable (utilisé).
## Renvoie "" ou la raison du refus (affichée dans le bandeau). Préfixes de l'ancien écran acceptés (conso:, sac:).
func equiper(main: String, id: String) -> String:
	var eq := _eq()
	if eq == null or id == "":
		return _dire("Rien à équiper.", true)
	if id.begins_with("conso:"):
		return utiliser(id.substr(6))
	if id.begins_with("sac:"):
		id = id.substr(4)
		if not tenable(id) and Inventaire.emplacement_de(id) == "":
			return _dire("Cet objet ne se tient pas en main.", true)
	if Inventaire.emplacement_de(id) != "":
		return porter(id)
	if Consommables.est(id):
		return utiliser(id)
	if not tenable(id):
		if Inventaire.categorie_de(id) == "arme":
			return _dire("%s ne se tient pas encore en main : c'est un trophée." % Inventaire.objet(id).get("nom", id), true)
		return _dire("Cet objet ne se tient pas en main.", true)
	var cote := "gauche" if main == "gauche" else "droite"
	if tenu(main) == id:
		return _dire("%s est déjà dans la main %s." % [eq.fiche(id)["nom"], cote], false)
	var essai := eq.essai(main, id)
	if String(essai["refus"]) != "":
		Sons.jouer(self, ["cloth1"], -18.0)
		return _dire("Main %s : %s" % [cote, essai["refus"]], true)
	var r: String = _magie().equiper(main, id)
	if r != "":
		return _dire("Main %s : %s" % [cote, r], true)
	Sons.jouer(self, ["sword-unsheathe"] if eq.categorie(main).begins_with("arme") else ["cloth1", "cloth2"], -12.0)
	var texte := "%s : main %s." % [eq.fiche(id)["nom"], cote]
	if String(essai["effet"]) != "":
		texte += " " + String(essai["effet"])
	_dire(texte, false)
	_rafraichir()
	return ""

## Vide une main (main nue). "" ou la raison.
func retirer_main(main: String) -> String:
	if tenu(main) == "vide":
		return _dire("La main %s est déjà vide." % main, true)
	var nom := String(_eq().fiche(tenu(main))["nom"])
	var r: String = _magie().equiper(main, "vide")
	if r != "":
		return _dire(r, true)
	Sons.jouer(self, ["cloth1", "cloth2"], -14.0)
	_dire("Rangé : %s (main %s nue)." % [nom, main], false)
	_rafraichir()
	return ""

## Porte un objet de corps (tête, torse, mains, pieds, cou, anneau) : EquipementCorps. "" ou la raison.
func porter(id: String) -> String:
	var ec: EquipementCorps = joueur.equipement_corps
	var nom := String(Inventaire.objet(id).get("nom", id))
	if ec.est_equipe(id):
		return _dire("%s est déjà porté." % nom, false)
	var avant := ec.objet_a(Inventaire.emplacement_de(id))
	var r := ec.equiper(id)
	if r != "":
		Sons.jouer(self, ["cloth1"], -18.0)
		return _dire(r, true)
	Sons.jouer(self, ["cloth1", "cloth2"], -12.0)
	_dire("Porté : %s%s." % [nom, "" if avant == "" else " (à la place de %s)" % Inventaire.objet(avant).get("nom", avant)], false)
	_rafraichir()
	return ""

## Retire l'objet porté à un emplacement de corps. "" ou la raison.
func retirer_corps(emplacement: String) -> String:
	var ec: EquipementCorps = joueur.equipement_corps
	var id := ec.objet_a(emplacement)
	if id == "":
		return _dire("Rien n'est porté là.", true)
	ec.retirer(emplacement)
	Sons.jouer(self, ["cloth1", "cloth2"], -14.0)
	_dire("Retiré : %s (il reste dans le sac)." % Inventaire.objet(id).get("nom", id), false)
	_rafraichir()
	return ""

## Utilise un consommable du sac (potion, nourriture, tome) : effet sur les stats du joueur. "" ou la raison du refus.
func utiliser(id: String) -> String:
	var r := Consommables.utiliser(joueur, id)
	if r != "":
		Sons.jouer(self, ["cloth1"], -18.0)
		return _dire("%s : %s" % [joueur.inventaire.nom(id), r], true)
	var reste: int = joueur.inventaire.nombre(id)
	_dire("Utilisé : %s. %s Reste : %d." % [joueur.inventaire.nom(id), Consommables.description(id), reste], false)
	_rafraichir()
	return ""

## Lâche l'objet `id` (par défaut : celui choisi dans le Sac) : 1 exemplaire, ou toute la pile si `tout`. "" ou la raison.
func lacher(tout := false, id := "") -> String:
	if id == "":
		id = choisi.trim_prefix("conso:").trim_prefix("sac:")
	if id == "" or joueur == null or not joueur.inventaire.a(id):
		if id != "" and tenable(id):
			return _dire("%s est toujours sur vous : il ne se lâche pas." % _eq().fiche(id)["nom"], true)
		return _dire("Choisissez d'abord un objet du sac.", true)
	var n: int = joueur.inventaire.nombre(id) if tout else 1
	var r := Lacher.lacher(joueur, hud, id, n)
	if r != "":
		Sons.jouer(self, ["cloth1"], -18.0)
		return _dire(r, true)
	Sons.jouer(self, ["cloth1", "cloth2"], -10.0)
	_dire("Lâché : %d %s. Il est devant vous : E pour le reprendre." % [n, joueur.inventaire.nom(id)], false)
	_rafraichir()
	return ""

## Ajoute / retire un favori du Sac. Renvoie true s'il est favori après l'appel.
func basculer_favori(id: String) -> bool:
	if id == "":
		return false
	if favoris.has(id):
		favoris.erase(id)
		_dire("Retiré des favoris.", false)
	else:
		favoris[id] = true
		_dire("Ajouté aux favoris.", false)
	_rafraichir()
	return favoris.has(id)

func est_favori(id: String) -> bool:
	return favoris.has(id)

## Sauvegarde : clé « menu » → {"favoris": [ids triés]}.
func exporter_menu() -> Dictionary:
	var ids: Array = favoris.keys()
	ids.sort()
	return {"favoris": ids}

## Relecture tolérante : clé absente (sauvegardes d'avant), mauvais type, favoris en tableau ou en dictionnaire ; alias
## traduits (Inventaire.ALIAS), identifiants inconnus ignorés.
func importer_menu(d: Variant) -> void:
	favoris.clear()
	if not d is Dictionary:
		return
	var f: Variant = (d as Dictionary).get("favoris", [])
	var ids: Array = []
	if f is Array:
		ids = f
	elif f is Dictionary:
		ids = (f as Dictionary).keys()
	for v: Variant in ids:
		if not (v is String or v is StringName):
			continue
		var id := Inventaire.alias(String(v))
		if Inventaire.connu(id) or id in ["epee", "torche", "bouclier"]:
			favoris[id] = true

## Range les deux mains actuelles dans le raccourci i (0..9 = touches 1..0) ; potion choisie dans le Sac : la potion.
func memoriser(i: int) -> String:
	var eq := _eq()
	if eq == null:
		return ""
	var c := choisi.trim_prefix("conso:")
	if onglet_actif == "sac" and c != "" and Consommables.est(c):
		var rc := eq.assigner_conso(i, c)
		if rc != "":
			return _dire(rc, true)
		_dire("Raccourci %d : %s (la touche l'utilise, les mains ne changent pas)." % [(i + 1) % 10, joueur.inventaire.nom(c)], false)
		Sons.jouer(self, ["cloth1", "cloth2"], -12.0)
		_rafraichir()
		return ""
	var g := tenu("gauche")
	var d := tenu("droite")
	var r := eq.assigner_raccourci(i, g, d)
	if r != "":
		return _dire(r, true)
	_dire("Raccourci %d : %s | %s" % [(i + 1) % 10, eq.fiche(g)["nom"], eq.fiche(d)["nom"]], false)
	Sons.jouer(self, ["cloth1", "cloth2"], -12.0)
	_rafraichir()
	return ""

func vider_raccourci(i: int) -> void:
	var eq := _eq()
	if eq == null:
		return
	eq.vider_raccourci(i)
	_dire("Raccourci %d vidé : la touche ne change plus les mains." % ((i + 1) % 10), false)
	_rafraichir()

func _dire(texte: String, refus: bool) -> String:
	return dire(texte, refus)

## Relit l'état dans l'onglet affiché (après une action).
func _rafraichir() -> void:
	var o := onglet_courant()
	if o != null and o.visible and o.has_method("relire"):
		o.call("relire")
	if o != null:
		o.queue_redraw()
	if _vue != null:
		_vue.queue_redraw()

# ------------------------------------------------------------------ compatibilité de l'ancien écran (outils, tests)

## armes / consommables / divers → onglet Sac filtré ; sorts → onglet Magie.
func _changer_categorie(id: String) -> void:
	if id == "sorts":
		if ouvert:
			changer_onglet("magie")
		onglet_actif = "magie"
		return
	var s := onglet("sac")
	if s != null and s.has_method("filtrer"):
		s.call("filtrer", {"armes": "arme", "consommables": "consommable", "divers": "tout"}.get(id, id))
	if ouvert:
		changer_onglet("sac")
	onglet_actif = "sac"

## Choisit un objet dans l'onglet affiché (préfixes conso: / sac: acceptés).
func _choisir(id: String) -> void:
	var o := onglet_courant()
	if o != null and o.has_method("choisir"):
		o.call("choisir", id.trim_prefix("conso:").trim_prefix("sac:"))
