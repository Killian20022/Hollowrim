extends "res://scripts/test_combat.gd"
## Scène de test de la magie et des deux mains (scenes/test_magie.tscn) : la scène du combat à l'épée (joueur, mannequin,
## mur, draugr) + deux mannequins de plus (chaîne d'éclairs, zones) et un pilote automatique qui joue chaque combinaison
## du §10 du cahier des charges (references/magie/prompt_magie.md).
##   godot --path . res://scenes/test_magie.tscn -- [--pilote] [--draugr=actif|fige|aucun] [--troll] [--nuit]
## En jeu : clic gauche = main droite, clic droit = main gauche (garde si épée + main gauche vide / torche / bouclier),
## maintenir = charger / canaliser, les deux boutons ensemble (0,15 s) = double incantation, 1-0 = raccourcis
## (data/magie/raccourcis.json), F3 = débogage de l'épée.
## Le pilote émet `moment(nom)` aux instants à capturer (outils/captures_magie.gd) ; journal des étapes dans `etapes`.

signal moment(nom: String)

const TROLL := preload("res://scripts/troll_givre_ia.gd")
const POS_M2 := Vector3(-2.2, 0.0, -5.0)
const POS_M3 := Vector3(2.0, 0.0, -5.6)

var mannequin2: StaticBody3D
var mannequin3: StaticBody3D
var troll: CharacterBody3D
var magie: MainSort
var titre: Label
var etape := ""
## Journal du pilote : [{etape, mana_avant, mana_apres, degats, journal}].
var etapes: Array = []
var pilote_fini := false

func _ready() -> void:
	super()
	mannequin2 = _mannequin(POS_M2)
	mannequin3 = _mannequin(POS_M3)
	magie = joueur.mains.magie
	var a := _args()
	if a.has("troll"):
		troll = CharacterBody3D.new()
		troll.set_script(TROLL)
		troll.set("joueur", joueur)
		troll.position = Vector3(0, 0, -9)
		add_child(troll)
	titre = Label.new()
	titre.add_theme_font_override("font", Palette.police())
	titre.add_theme_font_size_override("font_size", Palette.TAILLE_POLICE)
	titre.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	titre.position = Vector2(6, 4)
	hud.get_parent().add_child(titre)
	for n in hud.get_parent().get_children():
		if n is Label and n != titre:
			n.text = "Clic G : main droite   Clic D : main gauche (garde avec épée)   maintenir : charger/canaliser   G+D : double   1-0 : raccourcis"
	if a.has("pilote"):
		pilote.call_deferred()

func _mannequin(p: Vector3) -> StaticBody3D:
	var m := StaticBody3D.new()
	m.set_script(MANNEQUIN)
	m.position = p
	add_child(m)
	m.set("joueur", joueur)
	return m

func _process(_dt: float) -> void:
	if titre == null or magie == null:
		return
	var g: Incantation = magie.inc["gauche"]
	var d: Incantation = magie.inc["droite"]
	titre.text = "%s\nG %s %s   D %s %s   mana %d  vie %d  vig %d%s" % [etape, magie.eq.mains["gauche"].get("id", ""), g.nom(),
		magie.eq.mains["droite"].get("id", ""), d.nom(), roundi(joueur.mana), roundi(joueur.vie), roundi(joueur.vigueur),
		("\n" + String(magie.journal[-1][1])) if not magie.journal.is_empty() else ""]

func total_degats() -> float:
	var t := 0.0
	for m in [mannequin, mannequin2, mannequin3]:
		t += float(m.total)
	return t

# ------------------------------------------------------------------ pilote automatique (§10)

const SCENARIO := [
	["deux_identiques", "Deux sorts identiques : jet de flammes ×2 (double incantation)"],
	["deux_differents", "Deux sorts différents : lance de givre (G, chargée) + chaîne d'éclairs (D)"],
	["epee_feu", "Épée + feu : jet de flammes puis coups d'épée (combo « embrasement »)"],
	["epee_glace", "Épée + glace : éclats de glace puis épée (combo « brise-glace »)"],
	["epee_electricite", "Épée + électricité : chaîne d'éclairs puis épée (combo « ouverture »)"],
	["epee_tenebres", "Épée + ténèbres : trait d'ombre puis épée (combo « moisson »)"],
	["epee_bouclier", "Épée + bouclier : garde au bouclier"],
	["epee_torche", "Épée + torche : explorateur"],
	["changement_rapide", "Changement rapide en combat (raccourcis 2 → 4 → 6 → 3)"],
	["interruption", "Interruption d'une incantation par un coup ennemi"],
	["doubles", "Double magie identique : glace, électricité, ténèbres"],
	["reactions", "Réactions entre écoles : vapeur, décharge, flammes obscures"],
	["enchantement", "Enchantement de la lame (feu) + coups"],
	["full_mage", "Full mage : explosion, nova, tempête, explosion obscure, soin, protection"],
]

func pilote() -> void:
	for i in 30:
		await get_tree().process_frame
	for e in SCENARIO:
		etape = e[1]
		var avant := total_degats()
		var mana_avant: float = joueur.mana
		joueur.mana = joueur.mana_max
		joueur.vie = joueur.vie_max
		magie.recharges.clear()
		await call("_e_" + e[0])
		etapes.append({"etape": e[0], "degats": total_degats() - avant, "mana_avant": mana_avant, "mana_apres": joueur.mana})
		print("PILOTE %s degats=%.1f mana=%.1f" % [e[0], total_degats() - avant, joueur.mana])
		await _attendre(0.6)
	etape = "Fin du pilote"
	pilote_fini = true
	moment.emit("fin")

func _attendre(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _tenir(main: String, t: float) -> void:
	magie.appuyer(main)
	await _attendre(t)
	magie.relacher(main)

func _coup_epee(lourd := false) -> void:
	joueur.mains.entrees.appuyer()
	await _attendre(0.35 if lourd else 0.09)
	joueur.mains.entrees.relacher()
	await _attendre(0.45)

func _viser(p: Vector3) -> void:
	var d := p - joueur.global_position
	joueur.rotation.y = atan2(-d.x, -d.z)
	joueur.tete.rotation.x = -0.05

func _e_deux_identiques() -> void:
	magie.raccourci(2)   # touche 3 : feu / feu
	placer_joueur(Vector3(0, 0, 1.2), 0.0)
	await _attendre(0.6)
	magie.appuyer("gauche")
	await _attendre(0.05)
	magie.appuyer("droite")
	await _attendre(0.5)
	moment.emit("double_feu")
	await _attendre(0.9)
	magie.relacher("gauche")
	magie.relacher("droite")
	await _attendre(0.5)

func _e_deux_differents() -> void:
	magie.raccourci(3)
	placer_joueur(Vector3(0, 0, 2.0), 0.0)
	await _attendre(0.6)
	magie.appuyer("gauche")
	await _attendre(0.5)
	magie.appuyer("droite")
	await _attendre(0.25)
	moment.emit("glace_electricite")
	await _attendre(0.5)
	magie.relacher("gauche")
	magie.relacher("droite")
	await _attendre(0.9)

func _epee_puis(sort_gauche: String, tenue: float, nom_moment: String) -> void:
	magie.equiper("droite", "epee")
	magie.equiper("gauche", sort_gauche)
	placer_joueur(Vector3(0, 0, 0), 0.0)
	await _attendre(0.6)
	await _tenir("gauche", tenue)
	await _attendre(0.25)
	moment.emit(nom_moment)
	await _coup_epee()
	await _coup_epee()
	await _attendre(0.3)

func _e_epee_feu() -> void:
	await _epee_puis("jet_flammes", 0.8, "epee_feu")

func _e_epee_glace() -> void:
	await _epee_puis("eclat_glace", 0.1, "epee_glace")

func _e_epee_electricite() -> void:
	await _epee_puis("chaine_eclairs", 0.1, "epee_electricite")

func _e_epee_tenebres() -> void:
	await _epee_puis("trait_ombre", 0.1, "epee_tenebres")

func _e_epee_bouclier() -> void:
	magie.raccourci(5)
	placer_joueur(Vector3(0, 0, 0), 0.0)
	await _attendre(0.6)
	joueur.mains.entrees.forcer_garde(1.0)
	await _attendre(0.4)
	moment.emit("epee_bouclier")
	await _attendre(0.7)
	await _coup_epee()

func _e_epee_torche() -> void:
	magie.raccourci(0)
	placer_joueur(Vector3(0, 0, 0), 0.0)
	await _attendre(0.6)
	moment.emit("epee_torche")
	await _coup_epee()
	await _coup_epee()

func _e_changement_rapide() -> void:
	placer_joueur(Vector3(0, 0, 0.5), 0.0)
	for k in [1, 3, 5, 2]:
		magie.raccourci(k)
		await _attendre(0.5)
		if k == 3:
			moment.emit("changement_rapide")
	await _tenir("droite", 0.4)
	await _attendre(0.4)

func _e_interruption() -> void:
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "boule_feu")
	placer_joueur(Vector3(0, 0, 0.5), 0.0)
	await _attendre(0.5)
	magie.appuyer("gauche")
	await _attendre(0.5)
	moment.emit("interruption_avant")
	# coup ennemi (draugr à côté, ou coup forcé s'il n'y en a pas)
	joueur.recevoir_coup(14.0, joueur.global_position + Vector3(0.8, 0, -1.0))
	await _attendre(0.1)
	moment.emit("interruption_apres")
	magie.relacher("gauche")
	await _attendre(0.6)

func _e_doubles() -> void:
	placer_joueur(Vector3(0, 0, 2.0), 0.0)
	for id in ["lance_givre", "chaine_eclairs", "drain_vie"]:
		magie.equiper("droite", id)
		magie.equiper("gauche", id)
		await _attendre(0.4)
		magie.appuyer("gauche")
		magie.appuyer("droite")
		await _attendre(0.7)
		moment.emit("double_" + id)
		magie.relacher("gauche")
		magie.relacher("droite")
		await _attendre(0.8)

func _e_reactions() -> void:
	placer_joueur(Vector3(0, 0, 1.0), 0.0)
	# gel puis feu = vapeur ; gel puis électricité = décharge ; corruption puis feu = flammes obscures
	for paire in [["eclat_glace", "boule_feu"], ["eclat_glace", "chaine_eclairs"], ["trait_ombre", "boule_feu"]]:
		magie.equiper("gauche", paire[0])
		magie.equiper("droite", paire[1])
		await _attendre(0.3)
		await _tenir("gauche", 0.05)
		await _attendre(0.45)
		await _tenir("droite", 0.05)
		await _attendre(0.25)
		moment.emit("reaction_" + paire[1])
		await _attendre(0.5)

func _e_enchantement() -> void:
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "enchant_feu")
	placer_joueur(Vector3(0, 0, 0), 0.0)
	await _attendre(0.4)
	await _tenir("gauche", 0.1)
	await _attendre(0.9)
	moment.emit("enchantement")
	await _coup_epee()
	await _coup_epee()

func _e_full_mage() -> void:
	placer_joueur(Vector3(0, 0, 2.0), 0.0)
	for id in ["explosion_incendiaire", "nova_gelee", "tempete_statique", "explosion_obscure"]:
		magie.equiper("gauche", "vide")
		magie.equiper("droite", id)
		joueur.mana = joueur.mana_max
		if id == "nova_gelee":
			placer_joueur(Vector3(0, 0, -0.2), 0.0)
		await _attendre(0.2)
		await _tenir("droite", 1.0)
		await _attendre(0.3)
		moment.emit("zone_" + id)
		await _attendre(0.5)
	magie.equiper("gauche", "soin")
	magie.equiper("droite", "protection")
	joueur.vie = 40.0
	await _attendre(0.3)
	magie.appuyer("gauche")
	magie.appuyer("droite")
	await _attendre(0.8)
	joueur.recevoir_coup(20.0, joueur.global_position + Vector3(0, 0, -1.5))
	moment.emit("soin_protection")
	await _attendre(0.5)
	magie.relacher("gauche")
	magie.relacher("droite")
