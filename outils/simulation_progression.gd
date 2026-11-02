extends SceneTree
## Simulation de progression (lot B) avec le VRAI code (Progression, Competences, data/quetes.json, arbre.json) :
## temps de jeu -> niveau du personnage et niveaux de compétences, pour 3 profils de joueur ; écrit aussi le tableau de
## l'arbre. Sorties (Markdown + SVG) dans le dossier passé en argument (défaut : Desktop/Skyrim captures/rpg_progression).
##   godot --headless --path . --script res://outils/simulation_progression.gd -- [dossier]
## Gains par heure dérivés des gains du jeu (docs/RPG.md §13) : coup porté 1 (fort 1,8), garde 0,6 + 0,08 × dégâts (+0,6
## parade parfaite), coup encaissé 0,3 + 0,04 × dégâts, course 0,12 / s, sort qui touche 0,06 × dégâts, soin 0,06 × vie
## rendue, protection 0,06 × absorbé, attaque furtive 3 + 0,02 × dégâts. Aucun perk « xp_* » pris (base).

const DOSSIER := "C:/Users/lopezk19/Desktop/Skyrim captures/rpg_progression"
## XP de compétence par heure de jeu (moyenne, exploration comprise).
const PROFILS := {
	"Épéiste (épée + bouclier)": {"une_main": 348.0, "parade": 120.0, "armure": 45.0, "athletisme": 108.0, "furtivite": 16.0, "restauration": 10.0},
	"Mage (destruction + soin)": {"destruction": 240.0, "restauration": 54.0, "athletisme": 108.0, "armure": 30.0, "une_main": 40.0, "parade": 15.0},
	"Mixte (épée + sorts)": {"une_main": 200.0, "parade": 80.0, "armure": 40.0, "athletisme": 108.0, "destruction": 120.0, "restauration": 30.0, "furtivite": 16.0},
}
## Heures de jeu où une quête se termine (ordre de data/quetes.json).
const QUETES_H := [0.3, 0.8, 1.5, 2.2, 3.0, 4.0, 5.5]
const REPERES_MIN := [5, 10, 15, 30, 60, 120, 180, 300, 480, 720, 1200, 1800, 2400]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := DOSSIER
	for a in args:
		if not a.begins_with("--"):
			dossier = a
	DirAccess.make_dir_recursive_absolute(dossier)
	var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/quetes.json"))
	var quetes: Array = lu["quetes"]
	var md := "# Hollowrim — simulation de progression (lot B)\n\n"
	md += "Calculée par `outils/simulation_progression.gd` avec le code du jeu : courbe des compétences `seuil(n) = 0,025 n² − 1,5`, "
	md += "XP de niveau = niveau de compétence atteint, seuil de niveau `100 + 50 n`, XP des quêtes de `data/quetes.json` "
	md += "(%s). Aucun perk d'apprentissage pris.\n\n" % ", ".join(quetes.map(func(q) -> String: return "%s %d" % [q["id"], int(q["recompense"].get("xp", 150))]))
	var courbes := {}
	for nom in PROFILS:
		var r := _simuler(PROFILS[nom], quetes)
		courbes[nom] = r["courbe"]
		md += "## %s\n\nXP de compétence par heure : %s\n\n" % [nom, ", ".join(PROFILS[nom].keys().map(func(k) -> String: return "%s %d" % [k, int(PROFILS[nom][k])]))]
		md += "| Temps de jeu | Niveau perso | Points d'arbre gagnés | Une main | Deux mains | Parade | Armure | Destruction | Restauration | Furtivité | Athlétisme |\n"
		md += "|---|---|---|---|---|---|---|---|---|---|---|\n"
		for ligne in r["lignes"]:
			md += ligne + "\n"
		md += "\n"
	md += "Lecture : niveau 2 vers 10 min (la première quête en donne un de plus), niveau 5 vers 30 min, niveau 10 vers 3 h, puis "
	md += "la progression ralentit (niveau 15 vers 8 h, niveau 20 vers 20 h). L'arbre compte %d rangs : à 40 h (~24 points) " % _rangs_total()
	md += "on en possède un quart, d'où des choix ; Sigrún permet de tout redistribuer (500 pièces).\n"
	_ecrire(dossier + "/simulation_progression.md", md)
	_ecrire(dossier + "/simulation_progression.svg", _svg(courbes))
	_ecrire(dossier + "/arbre_perks.md", tableau_arbre())
	print("Simulation écrite dans ", dossier)
	quit(0)

func _simuler(taux: Dictionary, quetes: Array) -> Dictionary:
	var p := Progression.new()
	var lignes := []
	var courbe := []
	var qi := 0
	var rep := 0
	for minute in range(0, 2401):
		if minute > 0:
			for c in taux:
				p.pratiquer(c, float(taux[c]) / 60.0)
		while qi < quetes.size() and qi < QUETES_H.size() and minute >= int(QUETES_H[qi] * 60.0):
			p.gagner_xp(float(quetes[qi]["recompense"].get("xp", Progression.XP_QUETE_DEFAUT)))
			qi += 1
		if minute % 10 == 0:
			courbe.append(Vector2(minute, p.niveau))
		if rep < REPERES_MIN.size() and minute == REPERES_MIN[rep]:
			var t := "%d min" % minute if minute < 60 else ("%d h" % (minute / 60) if minute % 60 == 0 else "%.1f h" % (minute / 60.0))
			var l := "| %s | **%d** | %d |" % [t, p.niveau, p.points_perk]
			for c in Progression.COMPETENCES:
				l += " %d |" % p.competence(c)
			lignes.append(l)
			rep += 1
	return {"lignes": lignes, "courbe": courbe}

func _rangs_total() -> int:
	var n := 0
	for id in Progression.arbre()["perks"]:
		n += Progression.rangs_max(id)
	return n

## Tableau Markdown de l'arbre (docs/RPG.md §13 et livrable).
static func tableau_arbre() -> String:
	var a := Progression.arbre()
	var md := "# Hollowrim — arbre de compétences (lot B)\n\nSource : `data/competences/arbre.json` (%d perks, 8 pierres). " % a["perks"].size()
	md += "Un rang = 1 point d'arbre (1 par niveau du personnage). Prérequis : niveau de la compétence de la pierre + UN des perks parents. "
	md += "Réinitialisation chez Sigrún la Voyante : %d pièces.\n\n" % Progression.PRIX_REINITIALISATION
	for pid in a["ordre_pierres"]:
		var pi: Dictionary = a["pierres"][pid]
		md += "## %s — %s\n\n%s\n\n| Perk | Rangs (niveau requis : effet) | Parents |\n|---|---|---|\n" % [pi["nom"], pi["titre"], pi["description"]]
		for id in Progression.perks_de(pid):
			var f := Progression.perk(id)
			var rangs := []
			for r: Dictionary in f["rangs"]:
				rangs.append("%d : %s" % [int(r["niveau"]), r["texte"]])
			var parents := []
			for x in f["parents"]:
				parents.append(String(Progression.perk(x)["nom"]))
			md += "| **%s** (`%s`) | %s | %s |\n" % [f["nom"], id, "<br>".join(rangs), " ou ".join(parents) if not parents.is_empty() else "— (racine)"]
		md += "\n"
	return md

func _svg(courbes: Dictionary) -> String:
	var w := 720.0
	var h := 360.0
	var g := 50.0
	var couleurs := ["#8b2a1a", "#2a4a8b", "#3b6b2a"]
	var s := "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' style='background:#efe3c6;font-family:serif'>\n" % [w, h]
	s += "<text x='%d' y='24' fill='#4a2e1a' font-size='16'>Niveau du personnage selon le temps de jeu (0 à 40 h)</text>\n" % g
	for niv in [5, 10, 15, 20, 25, 30]:
		var y: float = h - g - (h - 2 * g) * niv / 30.0
		s += "<line x1='%d' y1='%.1f' x2='%d' y2='%.1f' stroke='#c9b48a'/><text x='18' y='%.1f' fill='#4a2e1a' font-size='11'>%d</text>\n" % [g, y, w - 20, y, y + 4, niv]
	for hh in [0, 5, 10, 20, 30, 40]:
		var x: float = g + (w - g - 20) * hh / 40.0
		s += "<text x='%.1f' y='%d' fill='#4a2e1a' font-size='11'>%d h</text>\n" % [x - 8, h - g + 18, hh]
	var i := 0
	for nom in courbes:
		var pts := []
		for v: Vector2 in courbes[nom]:
			pts.append("%.1f,%.1f" % [g + (w - g - 20) * v.x / 2400.0, h - g - (h - 2 * g) * v.y / 30.0])
		s += "<polyline fill='none' stroke='%s' stroke-width='2' points='%s'/>\n" % [couleurs[i % 3], " ".join(pts)]
		s += "<text x='%d' y='%d' fill='%s' font-size='12'>%s</text>\n" % [w - 260, 60 + 16 * i, couleurs[i % 3], nom]
		i += 1
	return s + "</svg>\n"

func _ecrire(chemin: String, texte: String) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		push_error("écriture impossible : " + chemin)
		return
	f.store_string(texte)
	f.close()
