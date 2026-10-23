class_name CrypteDonjon
extends DonjonKit
## La crypte de Svanhild, assemblée avec le KIT de donjon (scripts/donjon_kit.gd) : `plan()` est une TABLE de modules (salles, couloirs,
## escaliers) avec leurs liaisons, leurs graines et leurs accroches gameplay (identifiants fixes) ; ce fichier ne contient ensuite que les
## récits propres à chaque salle (méthodes `_x_*`), en repère de la crypte (x est, z sud ; l'entrée est en z = +4, on s'enfonce vers -Z ;
## étage inférieur : y = -6). Les pièces maîtresses (arène, tombeau) sont aussi des modules, avec un `extra` spécifique.
## Construit dans un fil d'exécution, hors de l'arbre : ne produit que des maillages, collisions, lumières et des listes de données
## (interactions, gardiens, demandes de pièges/mécanismes, zones) que `tertre.gd` instancie ensuite. Plan des étages : docs/DONJONS.md.

# fragments de sceau (objets de l'inventaire) et événements
const FRAG_OS := "fragment_sceau_os"
const FRAG_GIVRE := "fragment_sceau_givre"
const FRAG_EAU := "fragment_sceau_eau"
const EVT_OS := "crypte:fragment_os"                 # marqueur « fragment pris » (l'interaction disparaît)
const EVT_GIVRE := "crypte:fragment_givre"
const EVT_EAU := "crypte:fragment_eau"
const REVEIL_OS := "ramasse:fragment_sceau_os"       # événement de quête qui réveille le gardien (émis à l'entrée dans le sac)
const REVEIL_GIVRE := "ramasse:fragment_sceau_givre"
const REVEIL_EAU := "ramasse:fragment_sceau_eau"

# ------------------------------------------------------------------ crypte v2 : tables de données (voir docs/DONJONS.md §13 et scripts/crypte_v2.gd)
# Positions en repère de la CRYPTE (comme les accroches). Salle et couloir pilotes de la refonte graphique (références/crypte_v2_planche.png, vues 2/6 et 3).
const V2_NICHES := {
	"auto": false,
	"arche": "arche_2p0", "pilier": "pilier_mur_1p6", "naissance": 1.6,
	"eboulis": [{"pos": Vector3(1.0, 0, -9.3), "mod": "eboulis_c", "lacet": 0.6}, {"pos": Vector3(-1.0, 0, -15.0), "mod": "eboulis_a", "lacet": 2.1}],
	"dalles": [{"pos": Vector3(0.25, 0, -10.6), "mod": "dalles_a"}, {"pos": Vector3(-0.35, 0, -14.3), "mod": "dalles_b"}, {"pos": Vector3(0.4, 0, -17.0), "mod": "dalles_c"}],
	"flaques": [{"pos": Vector3(-0.15, 0, -11.9), "r": 0.55, "graine": 3}],
}
const V2_RITUELLE := {
	"auto": false,
	"piliers": [-6.2, -3.4, 3.4, 6.2], "pilier": "pilier_mur_3p2", "naissance": 3.2, "arche": "arche_10p7",
	"statues": [{"pos": Vector3(-4.8, 0, -53.15), "lacet": 0.0}, {"pos": Vector3(4.8, 0, -53.15), "lacet": 0.0}],
	"bannieres": [{"pos": Vector3(-4.8, 5.3, -53.7), "vers": Vector3(0, 0, 1), "long": 2.6}, {"pos": Vector3(4.8, 5.3, -53.7), "vers": Vector3(0, 0, 1), "long": 2.6}],
	"sarcophages": [{"pos": Vector3(-5.75, 0, -47.5), "lacet": PI * 0.5}],
	"bougies": [Vector3(-4.95, 0, -45.3), Vector3(-4.95, 0, -49.7)],
	"candelabres": [{"pos": Vector3(-5.9, 0, -45.85), "lumiere": true}, {"pos": Vector3(-3.55, 0, -52.3)}, {"pos": Vector3(3.55, 0, -52.3)}],
	"eboulis": [{"pos": Vector3(5.7, 0, -46.9), "mod": "eboulis_b", "lacet": 0.4}, {"pos": Vector3(-5.9, 0, -53.0), "mod": "eboulis_a", "lacet": 1.1}, {"pos": Vector3(5.7, 0, -43.3), "mod": "eboulis_c", "lacet": 2.6}],
	"dalles": [{"pos": Vector3(2.2, 0, -44.4), "mod": "dalles_a"}, {"pos": Vector3(-1.8, 0, -51.5), "mod": "dalles_b"}, {"pos": Vector3(3.4, 0, -49.2), "mod": "dalles_c"}],
	"flaques": [{"pos": Vector3(-2.7, 0, -43.9), "r": 0.9, "graine": 1}, {"pos": Vector3(3.9, 0, -52.0), "r": 0.8, "graine": 2}],
	"givre": 7,
}

## Réglages v2 des salles en mode auto (le reste est déduit de la forme de la salle) : pas de statue de plus là où le récit en a déjà
## (tombeau, trône, chapelle, antichambre) ni dans la galerie des statues (l'énigme doit rester lisible).
const V2_SALLES := {
	"reliquaires": {"statues_auto": 0},
	"tombeau": {"statues_auto": 0},
	"g4": {"statues_auto": 0},
	"lb2a": {"statues_auto": 0},
	"antichambre": {"statues_auto": 0},
}

func construire() -> void:
	for m: Dictionary in plan():
		module(m)
	verifier()

## Portée de dessin ~30 m (bord proche) pour tous les maillages d'une racine de crypte. À appeler APRÈS `CrypteDecor.finir()` (les
## maillages fusionnés par case de 8 m n'existent pas avant : l'ancienne boucle de `construire()` ne voyait rien et la portée de 70 m
## n'a jamais été appliquée). La portée se mesure au centre de l'objet : on ajoute son demi-diamètre (borné). Au-delà, la brume
## (densité 0,028) noie déjà l'essentiel. Sans effet sur ce qui a déjà une portée.
const PORTEE_DESSIN := 30.0
static func limiter_portee(racine: Node) -> void:
	for n in racine.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.visibility_range_end > 0.0:
			continue
		var d := g.get_aabb().size.length() * 0.5
		if d > 30.0:
			continue
		g.visibility_range_end = PORTEE_DESSIN + d
		g.visibility_range_end_margin = 3.0

# ------------------------------------------------------------------ la table
func _salle(id: String, o: Vector2, dim: Vector2, h: float, theme: String, role: String, graine: int, ouv: Array, plus := {}) -> Dictionary:
	var m := {"id": id, "type": "salle", "o": o, "dim": dim, "h": h, "theme": theme, "role": role, "graine": graine, "ouv": ouv}
	m.merge(plus, true)
	return m

## Couloir : `o` = centre, `longueur` le long de l'axe ; rot 0 = le long de Z (N = nord), rot 1 = le long de X (N = ouest, S = est).
func _cl(id: String, o: Vector2, longueur: float, rot: int, h: float, theme: String, graine: int, vers_n: String, vers_s: String, plus := {}) -> Dictionary:
	var m := {"id": id, "type": "couloir", "o": o, "dim": Vector2(3.2, longueur), "h": h, "rot": rot, "theme": theme, "role": "passage", "graine": graine,
		"ouv": [["N", 0.0, 3.2, false, vers_n], ["S", 0.0, 3.2, false, vers_s]]}
	m.merge(plus, true)
	return m

func _es(id: String, o: Vector2, rot: int, y_haut: float, y_bas: float, longueur: float, vers_haut: String, vers_bas: String, theme := "tombeau") -> Dictionary:
	return {"id": id, "type": "escalier", "o": o, "dim": Vector2(3.2, longueur), "rot": rot, "y_haut": y_haut, "y_bas": y_bas, "theme": theme, "vers_haut": vers_haut, "vers_bas": vers_bas}

func _it(id: String, pos: Vector3, nom: String, verbe: String, genre: String, extra := {}) -> Dictionary:
	var it := {"id": id, "pos": pos, "nom": nom, "verbe": verbe, "genre": genre}
	it.merge(extra, true)
	return it

func _texte(id: String, pos: Vector3, nom: String, verbe: String, lignes: Array) -> Dictionary:
	return _it(id, pos, nom, verbe, "texte", {"texte": lignes})

## Texte tiré de data/quetes.json (quetes.texte(cle)) ; `plus` : lignes ajoutées.
func _cle(id: String, pos: Vector3, nom: String, verbe: String, cle: String, plus := []) -> Dictionary:
	return _it(id, pos, nom, verbe, "texte", {"cle": cle, "plus": plus})

func _e(id: String, type: String, pos: Vector3, lacet := 0.0, dort := true, debout := false, extra := {}) -> Dictionary:
	return {"id": id, "type": type, "pos": pos, "lacet": lacet, "dort": dort, "debout": debout, "extra": extra}

func plan() -> Array:
	var B := BAS
	var r: Array = []
	var serment := {"reveil_evt": "vague_gardiens", "vie_imposee": 90.0, "degats_imposes": 18.0, "nom_affiche": "Gardien du serment"}
	# ============================================================ COLONNE VERTÉBRALE (étage 0)
	# vestibule (entrée), alcôve d'Eirik et couloir de la herse : bâtis par tertre.gd (pièces uniques : levier, herse, corps d'Eirik)
	r.append(_cl("niches", Vector2(0, -12), 12.0, 0, 3.0, "tombeau", 3, "prep", "",
		{"role": "combat", "extra": "_x_niches", "detritus": false, "lum": {"appliques": 2},
		"v2": V2_NICHES,
		"ouv": [["N", 0.0, 3.2, false, "prep"], ["S", 0.0, 3.2, false, ""], ["O", 3.0, 3.2, false, "s1"]],
		"ennemis": [_e("cr_niches_1", "sbire", Vector3(0.85, 0, -13.0), -PI * 0.5, true, true), _e("cr_niches_2", "sbire", Vector3(-0.85, 0, -16.8), PI * 0.5, true, true)]}))
	r.append(_salle("prep", Vector2(0, -25), Vector2(14, 14), 4.6, "tombeau", "combat", 5,
		[["S", 0.0, 3.2, false, "niches"], ["N", 0.0, 3.2, false, ""], ["O", 0.0, 3.0, false, ""], ["O", 5.2, 3.2, false, "w1"], ["E", -4.7, 3.2, false, "g0"]],
		{"lum": {"braseros": 2, "appliques": 2}, "extra": "_x_prep",
		"garnitures": [["piliers", {"pts": [Vector3(-3.5, 0, -28.5), Vector3(-3.5, 0, -21.5), Vector3(3.5, 0, -28.5), Vector3(3.5, 0, -21.5)], "h": 4.6, "largeur": 0.9}], ["oculus", {"pos": Vector3(0, 0, -25)}]],
		"ennemis": [_e("cr_prep_1", "guerrier", Vector3(4.6, 0, -26.8), -PI * 0.5, false), _e("cr_prep_2", "sbire", Vector3(2.5, 0, -23.5), 2.0, true), _e("cr_prep_3", "sbire", Vector3(-2.0, 0, -30.0), -0.8, true)],
		"coffres": [{"id": "cof_prep", "pos": Vector3(-6.2, 0, -30.9), "lacet": PI * 0.5, "butin": {"pieces": 22, "os_draugr": 1}}],
		"interactions": [_it("cach_prep", Vector3(-4.9, 0.45, -26.9), "Bandelettes cousues", "Défaire les bandelettes", "coffre", {"butin": {"pieces": 25, "poussiere_tombe": 1}, "coffre": Vector3(-4.9, 0, -26.9)})]}))
	# salle rituelle (hub) : trois socles, porte scellée de l'arène, rituel interrompu
	r.append(_salle("rituelle", Vector2(0, -48), Vector2(14, 12), 6.0, "tombeau", "enigme", 59,
		[["S", 0.0, 3.2, false, ""], ["N", 0.0, 4.0, false, "antichambre"]],
		{"lum": {"braseros": 1, "appliques": 2}, "extra": "_x_rituelle", "v2": V2_RITUELLE,
		"ennemis": [_e("cr_rituelle_1", "guerrier", Vector3(-2.7, 0, -52.0), 0.0, true, true), _e("cr_rituelle_2", "guerrier", Vector3(2.7, 0, -52.0), 0.0, true, true)],
		"meca": [{"genre": "socles", "id": "socles_rituel", "positions": [Vector3(-4.4, 0, -45.0), Vector3(4.4, 0, -45.0), Vector3(0, 0, -51.4)], "objets": [FRAG_OS, FRAG_GIVRE, FRAG_EAU]}]}))
	r.append(_salle("antichambre", Vector2(0, -58), Vector2(10, 8), 5.0, "tombeau", "repos", 61,
		[["S", 0.0, 4.0, false, "rituelle"], ["N", 0.0, 4.0, false, "arene"]],
		{"lum": {"braseros": 1, "appliques": 2}, "extra": "_x_antichambre",
		"coffres": [{"id": "cof_antichambre", "pos": Vector3(4.1, 0, -55.1), "lacet": -PI * 0.5, "nom": "Coffre de la Dame", "butin": {"pieces": 110, "amulette_givre": 1}}]}))
	r.append(_salle("arene", Vector2(0, -71), Vector2(24, 18), 8.0, "givre", "combat", 67,
		[["S", 0.0, 4.0, false, "antichambre"], ["E", -1.0, 3.2, false, "tombeau"]],
		{"lum": {"braseros": 0, "appliques": 0}, "extra": "_x_arene"}))
	r.append(_salle("tombeau", Vector2(18, -72), Vector2(12, 12), 5.0, "tombeau", "recit", 71,
		[["O", 0.0, 3.2, false, "arene"]],
		{"lum": {"braseros": 2, "appliques": 2}, "extra": "_x_tombeau",
		"ennemis": [_e("cr_serment_1", "guerrier", Vector3(14.6, 0, -75.4), PI * 0.5, true, true, serment),
			_e("cr_serment_2", "guerrier", Vector3(14.6, 0, -68.6), PI * 0.5, true, true, serment),
			_e("cr_serment_3", "guerrier", Vector3(19.0, 0, -77.0), 0.0, true, true, serment)]}))

	# ============================================================ AILE OUEST : sceau des Os
	r.append(_cl("w1", Vector2(-10, -19.8), 6.0, 1, 3.0, "tombeau", 7, "ossuaire", "prep"))
	r.append(_cl("s1", Vector2(-7.3, -9), 11.4, 1, 3.0, "tombeau", 9, "ossuaire", "niches", {"extra": "_x_s1"}))
	r.append(_salle("ossuaire", Vector2(-21, -16), Vector2(16, 20), 5.0, "ossuaire", "combat", 11,
		[["N", -4.0, 3.2, false, "w3"], ["N", 5.0, 3.2, false, "u1"], ["E", -3.8, 3.2, false, "w1"], ["E", 7.0, 3.2, false, "s1"], ["O", 2.0, 2.4, true, "ossuaire_secret"]],
		{"usure": 1, "lum": {"braseros": 2, "appliques": 2}, "extra": "_x_ossuaire",
		"garnitures": [["piliers", {"pts": [Vector3(-24.5, 0, -21.0), Vector3(-24.5, 0, -11.0), Vector3(-17.5, 0, -21.0), Vector3(-17.5, 0, -11.0)], "h": 5.0, "largeur": 1.0}],
			["panneaux_os", {"murs": ["O", "S", "E", "N"], "max": 2}],
			["sarcophages", {"cote": "S", "n": 3, "pille": [1]}],
			["estrade", {"pos": Vector3(-27.0, 0, -11.0), "taille": Vector3(3.2, 0.9, 4.0), "rampe": "E"}],
			["oculus", {"pos": Vector3(-21, 0, -16), "cote": 1.4}]],
		"ennemis": [_e("cr_ossuaire_1", "sbire", Vector3(-23.0, 0, -22.5), 0.8),
			_e("cr_ossuaire_2", "guerrier", Vector3(-14.5, 0, -22.0), -1.2, true, true),
			_e("cr_ossuaire_3", "sbire", Vector3(-23.0, 0, -8.8), PI),
			_e("cr_ossuaire_sq1", "squelette", Vector3(-27.7, 0, -21.5), 1.5, true, true),
			_e("cr_ossuaire_sq2", "squelette", Vector3(-27.7, 0, -18.2), 1.5, true, true),
			_e("cr_ossuaire_sqa", "squelette_archer", Vector3(-27.0, 0.9, -11.0), -1.2, true, true, {"archer": true, "poste": true}),
			_e("cr_ossuaire_gardien", "guerrier", Vector3(-21.0, 0, -12.0), 0.0, true, false, {"reveil_evt": REVEIL_OS, "vie_imposee": 120.0, "degats_imposes": 20.0, "nom_affiche": "Gardien des Os"})],
		"coffres": [{"id": "cof_ossuaire", "pos": Vector3(-28.2, 0, -24.7), "lacet": PI * 0.5, "butin": {"pieces": 34, "os_draugr": 2, "poussiere_tombe": 1}}],
		"interactions": [_it("urne_ossuaire", Vector3(-28.4, 0.5, -19.0), "Urne funéraire", "Fouiller l’urne", "coffre", {"butin": {"pieces": 9}, "coffre": Vector3(-28.4, 0, -19.0)}),
			_it("fragment_os", Vector3(-21.0, 1.9, -16.0), "Fragment du sceau des Os", "Prendre le fragment", "fragment", {"objet": FRAG_OS, "evt": EVT_OS,
				"texte": ["Un éclat d’os poli, gravé du sceau des Os. Il est glacé.", "Autour de vous, quelque chose bouge dans l’ombre des sarcophages…"]})],
		"meca": [{"genre": "mur_fragile", "id": "mur_ossuaire", "pos": Vector3(-29.0, 1.5, -14.0), "taille": Vector3(0.6, 3.0, 2.4), "lacet": 0.0, "materiau": "mur1"}]}))
	r.append(_salle("ossuaire_secret", Vector2(-31.5, -14), Vector2(5, 6), 3.2, "ossuaire", "tresor", 13,
		[["E", 0.0, 2.4, true, "ossuaire"]],
		{"lum": {"braseros": 0, "appliques": 1}, "extra": "_x_ossuaire_secret",
		"coffres": [{"id": "cof_mur1", "pos": Vector3(-33.2, 0, -16.2), "lacet": PI * 0.5, "nom": "Reliquaire des Os", "butin": {"pieces": 70, "lame_antique": 1, "relique_offrande": 1}}]}))
	r.append(_cl("w3", Vector2(-25, -30.5), 9.0, 0, 3.0, "tombeau", 15, "reliquaires", "ossuaire"))
	r.append(_es("u1", Vector2(-16, -32), 2, 0.0, B, 12.0, "ossuaire", "lb2"))
	r.append(_salle("reliquaires", Vector2(-29, -43), Vector2(14, 16), 4.6, "tombeau", "enigme", 17,
		[["S", 4.0, 3.2, false, "w3"], ["O", -1.0, 3.2, true, "tresor"]],
		{"usure": 1, "lum": {"braseros": 2, "appliques": 2}, "extra": "_x_galerie",
		"ennemis": [_e("cr_reliquaires_5", "guerrier", Vector3(-25.5, 0, -47.5), PI * 0.5, true, true)],
		"coffres": [{"id": "cof_reliq1", "pos": Vector3(-35.2, 0, -36.4), "lacet": PI * 0.5, "butin": {"pieces": 42, "lame_antique": 1}},
			{"id": "cof_reliq2", "pos": Vector3(-35.2, 0, -49.8), "lacet": PI * 0.5, "butin": {"pieces": 26, "poussiere_tombe": 2}}],
		"interactions": [_it("urne_reliq", Vector3(-22.8, 0.5, -36.6), "Urne funéraire", "Fouiller l’urne", "coffre", {"butin": {"pieces": 12, "os_draugr": 1}, "coffre": Vector3(-22.8, 0, -36.6)})],
		"meca": [{"genre": "statues", "id": "statues_galerie", "positions": [Vector3(-33.0, 0, -41.0), Vector3(-28.0, 0, -46.5), Vector3(-31.0, 0, -38.2)], "solution": [0, 1, 2]}]}))
	r.append(_salle("tresor", Vector2(-40.5, -44), Vector2(9, 8), 4.0, "tresor", "tresor", 19,
		[["E", 0.0, 3.2, true, "reliquaires"]],
		{"lum": {"braseros": 2, "appliques": 2}, "extra": "_x_tresor",
		"ennemis": [_e("cr_tresor_8", "guerrier", Vector3(-41.0, 0, -41.2), 0.0, true, true)],
		"coffres": [{"id": "cof_tresor1", "pos": Vector3(-44.2, 0, -41.3), "lacet": PI * 0.5, "nom": "Coffre du jarl", "butin": {"pieces": 120, "lame_antique": 1}},
			{"id": "cof_tresor2", "pos": Vector3(-44.2, 0, -46.7), "lacet": PI * 0.5, "nom": "Coffre du jarl", "butin": {"pieces": 90, "poussiere_tombe": 3}},
			{"id": "cof_tresor3", "pos": Vector3(-42.0, 0, -44.0), "lacet": PI * 0.5, "nom": "Grand coffre", "butin": {"pieces": 160, "lame_antique": 2, "os_draugr": 3}}]}))

	# ============================================================ AILE EST : sceau du Givre
	r.append(_cl("g0", Vector2(12, -29.7), 10.0, 1, 3.2, "givre", 21, "prep", "g1"))
	r.append(_salle("g1", Vector2(26, -26), Vector2(18, 16), 5.2, "glace", "piege", 23,
		[["O", -3.7, 3.2, false, "g0"], ["E", -4.0, 3.2, false, "g3"], ["S", -2.0, 3.2, false, "g2"], ["N", -5.0, 3.2, false, "d1"]],
		{"lum": {"braseros": 2, "appliques": 2}, "extra": "_x_glaces",
		"garnitures": [["piliers", {"pts": [Vector3(22.0, 0, -22.0), Vector3(31.0, 0, -22.0)], "h": 5.2, "largeur": 1.0}]],
		"ennemis": [_e("cr_g1_9", "guerrier", Vector3(21.0, 0, -32.0), 0.4, true, true),
			_e("cr_g1_10", "sbire", Vector3(30.0, 0, -20.0), 3.5),
			_e("cr_g1_arch", "squelette_archer", Vector3(33.0, 0, -24.3), -1.9, true, true, {"archer": true}),
			_e("cr_g1_gardien", "guerrier", Vector3(28.0, 0, -19.6), 0.0, true, false, {"reveil_evt": REVEIL_GIVRE, "vie_imposee": 110.0, "degats_imposes": 19.0, "nom_affiche": "Gardien du Givre"})],
		"coffres": [{"id": "cof_g1", "pos": Vector3(34.3, 0, -19.0), "lacet": -PI * 0.5, "nom": "Coffre givré", "butin": {"pieces": 38, "poussiere_tombe": 1}}],
		"interactions": [_it("fragment_givre", Vector3(33.2, 1.5, -32.2), "Fragment du sceau du Givre", "Prendre le fragment", "fragment", {"objet": FRAG_GIVRE, "evt": EVT_GIVRE,
			"texte": ["Un éclat de glace qui ne fond pas, gravé du sceau du Givre.", "Sous la glace du sol, un corps cuirassé s’éveille."]})],
		"meca": [{"genre": "souffle_givre", "id": "souffle_g1a", "pos": Vector3(27.0, 1.0, -33.55), "dir": Vector3(0, 0, 1), "longueur": 10.0, "periode": 4.2},
			{"genre": "souffle_givre", "id": "souffle_g1b", "pos": Vector3(31.0, 1.0, -33.55), "dir": Vector3(0, 0, 1), "longueur": 10.0, "periode": 3.1}]}))
	r.append(_cl("g2", Vector2(24, -13.5), 9.0, 0, 3.2, "givre", 25, "g1", "quartiers",
		{"coffres": [{"id": "cof_g2", "pos": Vector3(23.0, 0, -11.5), "lacet": PI * 0.5, "nom": "Coffre givré", "butin": {"pieces": 18}}]}))
	r.append(_salle("quartiers", Vector2(21, -4), Vector2(12, 10), 3.6, "tombeau", "repos", 29,
		[["N", 3.0, 3.2, false, "g2"], ["O", 2.0, 3.2, false, "s2"], ["E", 0.0, 2.4, true, "armurerie"]],
		{"lum": {"braseros": 1, "appliques": 3}, "extra": "_x_quartiers",
		"coffres": [{"id": "cof_quartiers", "pos": Vector3(15.9, 0, -7.9), "lacet": PI * 0.5, "butin": {"pieces": 55, "os_draugr": 1, "poussiere_tombe": 2}}],
		"interactions": [_cle("journal_quartiers", Vector3(24.2, 0.9, -0.6), "Journal de la garde", "Lire le journal", "journal_gardien"),
			_it("cach_quartiers", Vector3(19.5, 0.3, -1.4), "Planche disjointe", "Soulever la planche", "coffre", {"butin": {"pieces": 40, "amulette_givre": 1}, "coffre": Vector3(19.5, 0, -1.4)})],
		"meca": [{"genre": "mur_fragile", "id": "mur_quartiers", "pos": Vector3(27.0, 1.5, -4.0), "taille": Vector3(0.6, 3.0, 2.4), "lacet": 0.0, "materiau": "mur0"}]}))
	r.append(_salle("armurerie", Vector2(30, -4), Vector2(6, 6), 3.2, "tombeau", "tresor", 33,
		[["O", 0.0, 2.4, true, "quartiers"]],
		{"lum": {"braseros": 0, "appliques": 1}, "extra": "_x_armurerie",
		"coffres": [{"id": "cof_mur2", "pos": Vector3(31.8, 0, -6.0), "lacet": PI, "nom": "Coffre de l’armurerie", "butin": {"pieces": 90, "lame_antique": 1, "amulette_givre": 1}}]}))
	r.append(_cl("s2", Vector2(9, -2), 12.0, 1, 3.0, "givre", 35, "", "quartiers", {"extra": "_x_s2",
		"ennemis": [_e("cr_s2_11", "sbire", Vector3(10.0, 0, -2.0), PI * 0.5, true, true)]}))
	r.append(_cl("g3", Vector2(39, -30), 8.0, 1, 3.2, "glace", 37, "g1", "g4", {"extra": "_x_g3",
		"meca": [{"genre": "dalle_flechettes", "id": "piege_g3", "pos_dalle": Vector3(39.0, 0, -30.0), "pos_bouche": Vector3(39.0, 1.1, -31.3), "dir": Vector3(0, 0, 1)}]}))
	r.append(_salle("g4", Vector2(51, -30), Vector2(16, 16), 4.6, "glace", "combat", 31,
		[["O", 0.0, 3.2, false, "g3"]],
		{"usure": 1, "lum": {"braseros": 2, "appliques": 2}, "extra": "_x_trone",
		"garnitures": [["piliers", {"pts": [Vector3(47.0, 0, -34.0), Vector3(47.0, 0, -26.0), Vector3(53.0, 0, -34.0), Vector3(53.0, 0, -26.0)], "h": 4.6, "largeur": 0.9}]],
		"ennemis": [_e("jarl", "guerrier", Vector3(53.8, 0, -30.0), -PI * 0.5, true, true, {"boss": "jarl"}),
			_e("cr_g4_arch1", "squelette_archer", Vector3(56.2, 0, -35.8), -PI * 0.5, true, true, {"archer": true}),
			_e("cr_g4_arch2", "squelette_archer", Vector3(56.2, 0, -24.2), -PI * 0.5, true, true, {"archer": true})],
		"coffres": [{"id": "cof_g4a", "pos": Vector3(57.9, 0, -36.8), "lacet": -PI * 0.5, "nom": "Coffre givré", "butin": {"pieces": 58, "lame_antique": 1}},
			{"id": "cof_g4b", "pos": Vector3(57.9, 0, -23.2), "lacet": -PI * 0.5, "nom": "Coffre givré", "butin": {"pieces": 44, "os_draugr": 2}},
			{"id": "cof_jarl", "pos": Vector3(57.9, 0, -34.3), "lacet": -PI * 0.5, "nom": "Coffre du Jarl", "butin": {"hache_kolbeinn": 1, "pieces": 80}}]}))
	r.append(_es("d1", Vector2(21, -40), 2, 0.0, B, 12.0, "g1", "lb1"))

	# ============================================================ ÉTAGE −1 : sceau de l'Eau
	r.append(_salle("lb2", Vector2(-14, -43), Vector2(16, 10), 4.4, "ossuaire", "recit", 37,
		[["S", -2.0, 3.2, false, "u1"], ["N", 0.0, 3.2, false, "lb2b"], ["O", 0.0, 3.2, false, "lb2w"], ["E", 0.0, 3.2, false, "lb2e"]],
		{"y": B, "usure": 2, "lum": {"braseros": 1, "appliques": 3}, "extra": "_x_archives",
		"ennemis": [_e("cr_lb2_17", "sbire", Vector3(-18.0, B, -45.0), PI * 0.5, false, false, {"patrouille": [Vector3(-18.0, B, -45.0), Vector3(-10.0, B, -45.0), Vector3(-10.0, B, -40.5)]})],
		"coffres": [{"id": "cof_archives", "pos": Vector3(-21.1, B, -46.8), "lacet": PI * 0.5, "nom": "Coffre des archivistes", "butin": {"pieces": 48, "poussiere_tombe": 2}}],
		"interactions": [_it("cach_archives", Vector3(-17.2, B + 0.35, -41.0), "Rayon creux", "Fouiller le rayonnage", "coffre", {"butin": {"pieces": 35, "poussiere_tombe": 2}, "coffre": Vector3(-17.2, B, -41.0)}),
			_texte("notes_archives", Vector3(-9.0, B + 0.9, -45.2), "Registre des morts", "Lire le feuillet", [
			"Le registre des morts de la Dame Svanhild, rongé par l’humidité.",
			"Un feuillet récent, d’une autre main : « Eirik a brisé le sceau des Os, puis celui du Givre. Les morts se lèvent derrière nous. »",
			"« Nous nous retranchons dans la salle du fond. Que les dieux nous gardent. »"])]}))
	r.append(_salle("lb2b", Vector2(-14, -52), Vector2(8, 8), 3.6, "tombeau", "recit", 41,
		[["S", 0.0, 3.2, false, "lb2"]],
		{"y": B, "lum": {"braseros": 0, "appliques": 1}, "extra": "_x_barricade",
		"coffres": [{"id": "cof_lb2b", "pos": Vector3(-17.2, B, -54.8), "lacet": PI * 0.5, "nom": "Bagages de l’expédition", "butin": {"pieces": 60, "poussiere_tombe": 1}}],
		"interactions": [_cle("note_compagnon_1", Vector3(-11.9, B + 0.9, -52.2), "Carnet d’un compagnon", "Lire le carnet", "note_compagnon_1"),
			_cle("note_compagnon_2", Vector3(-16.0, B + 0.5, -53.0), "Corps d’un compagnon", "Fouiller le corps", "note_compagnon_2"),
			_cle("note_compagnon_3", Vector3(-12.6, B + 0.5, -54.2), "Dernier mot", "Lire le mot", "note_compagnon_3",
				["Au dos : « La citerne : quatre braseros, à allumer dans l’ordre des bannières. L’Eau garde le dernier sceau. »"])]}))
	r.append(_cl("lb2w", Vector2(-25, -43), 6.0, 1, 3.2, "tombeau", 39, "lb3", "lb2", {"y": B, "extra": "_x_piege_lb2w",
		"meca": [{"genre": "dalle_flechettes", "id": "piege_lb2w", "pos_dalle": Vector3(-25.0, B, -43.0), "pos_bouche": Vector3(-25.0, B + 1.1, -44.3), "dir": Vector3(0, 0, 1)}]}))
	r.append(_salle("lb3", Vector2(-35, -43), Vector2(14, 14), 5.0, "eau", "enigme", 43,
		[["E", 0.0, 3.2, false, "lb2w"]],
		{"y": B, "usure": 1, "lum": {"braseros": 0, "appliques": 2}, "extra": "_x_cisterne",
		"ennemis": [_e("cr_lb3_18", "guerrier", Vector3(-33.0, B, -38.0), 0.0, true, true),
			_e("cr_lb3_19", "sbire", Vector3(-37.8, B, -47.6), 1.5),
			_e("cr_lb3_arch", "squelette_archer", Vector3(-40.6, B, -47.4), 0.8, true, true, {"archer": true, "poste": true}),
			_e("cr_lb3_noye", "guerrier", Vector3(-38.0, B, -39.6), 0.0, true, false, {"reveil_evt": REVEIL_EAU, "vie_imposee": 115.0, "degats_imposes": 19.0, "nom_affiche": "Gardien de l’Eau"})],
		"coffres": [{"id": "cof_lb3", "pos": Vector3(-28.6, B, -37.7), "lacet": -PI * 0.5, "butin": {"pieces": 47, "lame_antique": 1, "os_draugr": 2}}],
		"interactions": [_it("fragment_eau", Vector3(-40.6, B + 1.5, -43.0), "Fragment du sceau de l’Eau", "Prendre le fragment", "fragment", {"objet": FRAG_EAU, "evt": EVT_EAU, "requiert": ["meca:braseros_cisterne:resolu"],
			"texte": ["Un éclat de pierre humide, gravé du sceau de l’Eau.", "Les eaux de la citerne frémissent derrière vous."]})],
		"meca": [{"genre": "braseros", "id": "braseros_cisterne", "positions": [Vector3(-39.2, B, -47.2), Vector3(-30.8, B, -47.2), Vector3(-39.2, B, -38.8), Vector3(-30.8, B, -38.8)], "ordre": [2, 0, 3, 1]}]}))
	r.append(_cl("lb2e", Vector2(-2, -43), 8.0, 1, 3.2, "tombeau", 45, "lb2", "lb2a", {"y": B, "extra": "_x_piege_lb2e",
		"meca": [{"genre": "dalle_flechettes", "id": "piege_lb2e", "pos_dalle": Vector3(-2.0, B, -43.0), "pos_bouche": Vector3(-2.0, B + 1.1, -41.7), "dir": Vector3(0, 0, -1)}]}))
	r.append(_salle("lb2a", Vector2(6, -48), Vector2(8, 16), 4.2, "tombeau", "repos", 47,
		[["O", 5.0, 3.2, false, "lb2e"], ["E", -4.0, 3.2, false, "lb1c"]],
		{"y": B, "lum": {"braseros": 1, "appliques": 2}, "extra": "_x_chapelle",
		"coffres": [{"id": "cof_lb2a", "pos": Vector3(9.4, B, -41.0), "lacet": -PI * 0.5, "butin": {"pieces": 31, "poussiere_tombe": 1}}],
		"interactions": [_cle("inscription_chapelle", Vector3(6.0, B + 1.25, -53.9), "Inscription", "Lire l’inscription", "inscription_chapelle"),
			_it("cach_chapelle", Vector3(7.6, B + 0.35, -54.3), "Pierre descellée", "Soulever la pierre", "coffre", {"butin": {"pieces": 45, "amulette_givre": 1}, "coffre": Vector3(7.6, B, -54.3)})]}))
	r.append(_cl("lb1c", Vector2(13, -52), 6.0, 1, 3.2, "tombeau", 49, "lb2a", "lb1", {"y": B}))
	r.append(_salle("lb1", Vector2(22, -53), Vector2(12, 14), 4.6, "garde", "combat", 53,
		[["O", 1.0, 3.2, false, "lb1c"], ["S", -1.0, 3.2, false, "d1"]],
		{"y": B, "usure": 1, "lum": {"braseros": 2, "appliques": 2}, "extra": "_x_garde",
		"garnitures": [["couverts", {"n": 2}]],
		"ennemis": [_e("cr_lb1_15", "guerrier", Vector3(19.0, B, -57.0), 0.0, false, false, {"patrouille": [Vector3(19.0, B, -57.0), Vector3(25.0, B, -57.0), Vector3(25.0, B, -50.0)]}),
			_e("cr_lb1_16", "sbire", Vector3(18.0, B, -49.0), 2.5),
			_e("cr_lb1_arch", "squelette_archer", Vector3(22.0, B, -58.8), 0.0, true, true, {"archer": true})],
		"coffres": [{"id": "cof_lb1", "pos": Vector3(27.1, B, -58.6), "lacet": -PI * 0.5, "butin": {"pieces": 52, "lame_antique": 1}},
			{"id": "cof_lb1b", "pos": Vector3(27.1, B, -56.3), "lacet": -PI * 0.5, "nom": "Coffre de la garde", "butin": {"pieces": 80, "amulette_givre": 1, "relique_offrande": 1}}]}))
	# crypte v2 (lot C4, 2026-10-23) : TOUTES les salles en style v2 ; sans table propre = mode auto (scripts/crypte_v2.gd)
	for mm: Dictionary in r:
		if not mm.has("v2"):
			mm["v2"] = (V2_SALLES.get(mm["id"], {}) as Dictionary).duplicate(true)
	return r

# ------------------------------------------------------------------ outils des récits (coordonnées de la crypte -> repère du module)
func _l(wx: float, wz: float, y := 0.0) -> Vector3:
	return lw(Vector3(wx, y, wz))

func _ll(lacet: float) -> float:
	return lw_lacet(lacet)

## Dalle fendue + plaque de bouche dans le mur d'en face d'un piège à fléchettes (le piège lui-même est posé par tertre : Piege.dalle_flechettes).
func _indice_dalle(wx: float, wz: float, y: float, lacet_monde: float, bouche_w: Vector3) -> void:
	d.dalle_fendue(_l(wx, wz, y), _ll(lacet_monde))
	var vers := lw(bouche_w)
	d.boite("mur0", vers, Vector3(0.14, 0.46, 0.46), 0.0)
	d.boite("noir", vers, Vector3(0.15, 0.18, 0.18), 0.0)

# ------------------------------------------------------------------ colonne vertébrale
func _x_niches(_m: Dictionary) -> void:
	niche(1.3, -1.0, -1.0)
	niche(1.3, -4.8, -1.0)
	niche(-1.3, -4.8, 1.0)
	# embuscade lisible : os frais, sac d'expédition éventré, épée brisée devant les niches
	d.os_tas(Vector3(0.3, 0, -1.6), 4, 0.4)
	d.os_tas(Vector3(-0.4, 0, -3.8), 3, 0.35)
	d.sac_dechire(Vector3(0.5, 0, 1.8), 0.4)
	d.arme(Vector3(-0.3, 0, -0.6), 2.4)
	d.arme(Vector3(0.2, 0, -6.2), 0.5)
	d.boite("lame", Vector3(0.6, 0.012, -2.9), Vector3(0.35, 0.012, 0.06), 0.3)

func _x_prep(_m: Dictionary) -> void:
	for k in 3:      # voie processionnelle gravée
		d.boite("gravure", _l(0, -20.3 - k * 4.0, 0.015), Vector3(2.0, 0.03, 4.0), 0.0, true, Vector3(1.0, 0, 20.3 + k * 4.0))
	# tables d'embaumement : obstacles du combat, hors des passages (porte de l'alcôve à l'ouest, levier à l'est)
	d.table_embaumement(_l(-4.9, -28.2), 0.0, true)
	d.table_embaumement(_l(4.9, -21.8), 0.0, false)
	for k in 3:
		d.tonneau(_l(6.2, -22.6 - k * 0.8), 0.9)
	d.urne(_l(-6.2, -21.0), 1.0)
	d.urne(_l(-6.2, -21.7), 0.8)
	d.parchemins_epars(_l(-3.0, -27.0), 1.6, 6)
	d.os_tas(_l(0.5, -23.5), 3, 0.5)
	d.arme(_l(2.0, -22.8), 2.3)
	d.crane(_l(-3.1, -29.4), 2.4)
	d.chaine(_l(-5.2, -28.2, 4.4), _l(-5.2, -28.2, 3.4))
	d.chaine(_l(-4.6, -28.2, 4.4), _l(-4.6, -28.2, 3.3))
	d.banniere(_l(-6.55, -23.0, 3.4), Vector3(1, 0, 0), 1.9, 0.8, Color(0.5, 0.42, 0.34), "os", 1)

func _x_rituelle(_m: Dictionary) -> void:
	# vasque centrale et cercle du rituel gravé au sol
	if d.v2:      # crypte v2 : vasque en blocs taillés, margelle et bassin (emplacement d'eau pour le lot eau)
		d.modele("vasque_rituel", _l(0, -47.5), 0.0)
		d.eau_slot(_l(0, -47.5, 0.74), 1.15, "vasque")
	else:
		d.tour("mur0", _l(0, -47.5), [Vector2(2.2, 0.0), Vector2(2.2, 0.4), Vector2(1.7, 0.4), Vector2(1.7, 0.9)], 8, PI / 8.0, true)
		d.tour("gravure", _l(0, -47.5, 0.9), [Vector2(1.7, 0.0), Vector2(1.4, 0.0)], 8, PI / 8.0, true)
	d.solide(_l(0, -47.5, 0.45), Vector3(3.6, 0.9, 3.6))
	d.lumiere(_l(0, -47.5, 1.6), Color(0.4, 0.8, 1.0), 1.5, 7.0, 1.5, false)
	if CrypteV2.actif(_m):
		d.cercle_grave(_l(0, -47.5, 0.0), 2.55)      # crypte v2 : anneaux fins gravés (plus de grosses barres claires)
	else:
		d.embleme("cercle", _l(0, -47.5, 0.02), Vector3.UP, 7.4)
	# plaques des sceaux au pied de chaque socle (os, givre, eau) : l'objectif se lit au sol
	d.embleme("os", _l(-4.4, -46.4, 0.03), Vector3.UP, 1.1)
	d.embleme("givre", _l(4.4, -46.4, 0.03), Vector3.UP, 1.1)
	d.embleme("eau", _l(0, -52.9, 0.03), Vector3.UP, 1.1)
	# bannières des trois sceaux, déchirées
	d.banniere(_l(-6.55, -44.5, 3.6), Vector3(1, 0, 0), 2.2, 0.9, Color(0.72, 0.62, 0.42), "os", 1)
	d.banniere(_l(6.55, -44.5, 3.6), Vector3(-1, 0, 0), 2.2, 0.9, Color(0.45, 0.6, 0.82), "givre", 1)
	d.banniere(_l(-6.55, -50.5, 3.6), Vector3(1, 0, 0), 2.2, 0.9, Color(0.3, 0.6, 0.55), "eau", 2)
	# porte de l'arène scellée : le cadre des trois sceaux sur sa face
	porte_coulissante("arene", _l(0, -54.0), "z", 4.0)
	d.frise(["os", "givre", "eau"], _l(0, -53.62, 1.6), Vector3(0, 0, 1), 0.8, 1.35)
	# rituel interrompu : brasero renversé, os, chaînes, bougies éteintes
	d.tour("mur0", _l(3.2, -49.8), [Vector2(0.36, 0.0), Vector2(0.32, 0.1), Vector2(0.24, 0.36)], 8, 0.0, false)
	d.boite("mur0", _l(3.8, -50.4, 0.15), Vector3(0.5, 0.3, 0.5), 0.7)
	d.os_tas(_l(-2.2, -49.5), 5, 0.6)
	d.os_tas(_l(2.0, -44.0), 4, 0.5)
	d.sac_dechire(_l(-3.2, -42.8), 1.0)
	d.chaine(_l(-1.4, -51.6, 5.9), _l(-1.4, -51.6, 3.4))
	d.chaine(_l(1.4, -51.6, 5.9), _l(1.4, -51.6, 3.8))
	d.arme(_l(0.5, -43.6), 2.0)
	d.crane(_l(3.0, -45.4), 0.8)
	d.bougie(_l(-3.9, -46.3), false)
	d.bougie(_l(3.9, -46.3), false)
	d.bougie(_l(0.6, -53.0), false)
	interaction("inscription_rituel", _l(0, -53.0, 1.3), "Porte scellée", "Lire les sceaux", "texte", {"cle": "inscription_rituel"})
	interaction("rituel_interrompu", _l(3.5, -49.8, 0.7), "Brasero renversé", "Examiner le rituel", "texte", {"cle": "rituel_interrompu"})

func _x_antichambre(_m: Dictionary) -> void:
	d.tapis(_l(0, -58), Vector2(2.4, 7.2), 0.0, Color(0.34, 0.16, 0.18))
	d.ratelier_armes(_l(-4.62, -56.6), PI * 0.5, 1.8)
	d.ratelier_armes(_l(4.62, -56.6), -PI * 0.5, 1.8)
	d.statue(_l(-3.4, -60.6), 0.0, 1.15, "guerrier", true, "mur0")
	d.statue(_l(3.4, -60.6), 0.0, 1.15, "guerrier", true, "mur0")
	d.banniere(_l(-4.62, -59.5, 3.8), Vector3(1, 0, 0), 2.4, 0.9, Color(0.4, 0.5, 0.78), "couronne", 1)
	d.banniere(_l(4.62, -59.5, 3.8), Vector3(-1, 0, 0), 2.4, 0.9, Color(0.4, 0.5, 0.78), "couronne", 2)
	d.table(_l(-3.1, -55.0), 0.0)
	d.bougie(_l(-3.1, -55.0, 0.8), false)
	d.urne(_l(3.1, -61.1), 1.3)
	d.os_tas(_l(0.6, -56.5), 2, 0.3)

# ------------------------------------------------------------------ arène : pièce maîtresse (estrade, piliers, glace)
func _x_arene(_m: Dictionary) -> void:
	for x in [-8.5, 8.5]:
		for z in [-66.0, -72.0, -77.5]:
			var p := _l(x, z)
			d.pilier(p.x, p.z, 8.0, 1.2)
	for z in [-66.0, -72.0, -77.5]:
		d.arc("mur0", "x", 0.0, _l(0, z).z, 15.8, 6.2, 1.4, 0.4, 0.6, 12)
	for x in [-8.5, 8.5]:
		d.arc("mur0", "z", _l(x, 0).x, _l(0, -69.0).z, 4.8, 6.2, 1.2, 0.4, 0.6)
		d.arc("mur0", "z", _l(x, 0).x, _l(0, -74.75).z, 4.3, 6.2, 1.2, 0.4, 0.6)
	# estrade à trois degrés de 0,2 m ; le sarcophage est posé par tertre.gd
	if d.v2:      # crypte v2 : degrés en blocs taillés (module Blender), MÊMES collisions
		d.solide(_l(0, -72.0, 0.1), Vector3(11.0, 0.2, 9.0))
		d.solide(_l(0, -72.0, 0.3), Vector3(8.0, 0.2, 7.0))
		d.solide(_l(0, -72.0, 0.5), Vector3(5.4, 0.2, 5.6))
		d.modele("degres_arene", _l(0, -72.0), 0.0)
	else:
		d.boite_pleine("dalle0", _l(0, -72.0, 0.1), Vector3(11.0, 0.2, 9.0))
		d.boite_pleine("dalle0", _l(0, -72.0, 0.3), Vector3(8.0, 0.2, 7.0))
		d.boite_pleine("dalle0", _l(0, -72.0, 0.5), Vector3(5.4, 0.2, 5.6))
	for k in 12:
		var a := TAU * k / 12.0
		stalagmite(_l(cos(a) * 7.2, -72.0 + sin(a) * 5.8), alea(0.5, 1.1), 0.14)
	for k in 16:
		glacon(_l(alea(-11.0, 11.0), alea(-78.0, -63.0), 8.0), alea(0.7, 1.8), 0.14)
	for c in [Vector2(-11.0, -79.0), Vector2(11.0, -79.0), Vector2(-11.0, -63.0), Vector2(11.0, -63.0)]:
		congere(_l(c.x, c.y), alea(1.6, 2.3), alea(0.6, 0.9))
	congere(_l(-5.0, -79.0), 1.2, 0.45)
	congere(_l(6.5, -79.0), 1.4, 0.5)
	d.urne(_l(-11.0, -65.0), 1.2)
	d.urne(_l(11.0, -65.0), 1.2)
	d.os_tas(_l(-5.0, -63.5), 5, 0.6)
	d.os_tas(_l(6.0, -77.0), 4, 0.6)
	d.arme(_l(3.0, -63.5), 0.4)
	d.arme(_l(-7.0, -76.0), 2.2)
	d.crane(_l(-3.0, -66.0), 0.5)
	d.crane(_l(4.0, -66.5), 2.0)
	# lumière : braseros chauds aux coins de l'entrée, lampes froides à l'estrade
	d.brasero(_l(-10.6, -63.4))
	d.brasero(_l(10.6, -63.4))
	d.brasero(_l(-5.6, -67.2))
	d.brasero(_l(5.6, -67.2))
	d.applique(_l(0, -79.7), Vector3(0, 0, 1), 3.0, 6.0, 1.6, true)
	d.oculus(_l(0, -72.0, 8.0), 2.0)
	d.rai(_l(0, -72.0, 0.7), 7.2, 2.0)
	d.flaque_froide(_l(0, -72.0, 0.62), 6.0)
	d.poussiere(_l(0, -72.0, 4.0), Vector3(1.0, 3.0, 1.4), 34)
	souffle(_l(0, -70.0, 0.8), Vector3(5.0, 0.5, 4.0), Vector3(0, 0.3, -1), 36)
	# porte du tombeau (côté est) : scellée jusqu'à la mort de Svanhild ; chaînes et sceau gravé
	porte_coulissante("tombe", _l(12.0, -72.0), "x", 3.2)
	d.boite("gravure", _l(11.55, -72.0, 3.55), Vector3(0.1, 0.5, 2.8), 0.0)
	for z in [-71.0, -73.0]:
		d.chaine(_l(11.7, z, 3.1), _l(11.7, z, 1.9))

# ------------------------------------------------------------------ tombeau : fresque, offrandes royales, choix moral
func _x_tombeau(_m: Dictionary) -> void:
	# fresque de Svanhild sur le mur du fond (nord) : la mer, la couronne, la hache, l'épée, le givre
	d.frise(["navire", "couronne", "hache", "epee", "givre"], _l(18.0, -77.68, 2.3), Vector3(0, 0, 1), 1.25, 2.1)
	# offrandes royales sur un autel le long du mur est : couronne, coupes, épée, or
	d.autel(_l(22.9, -72.0), -PI * 0.5, 5.2)
	d.tour("or", _l(22.9, -72.0, 1.0), [Vector2(0.24, 0.0), Vector2(0.28, 0.1), Vector2(0.26, 0.2), Vector2(0.3, 0.32)], 10, 0.0, false)
	for k in 5:
		d.boite("or", _l(22.9, -72.0 + (k - 2) * 0.1, 1.42), Vector3(0.06, 0.18, 0.06), 0.0)
	d.tour("or", _l(22.9, -73.7, 1.0), [Vector2(0.07, 0.0), Vector2(0.11, 0.12), Vector2(0.14, 0.24)], 8, 0.0, false)
	d.tour("or", _l(22.9, -70.3, 1.0), [Vector2(0.07, 0.0), Vector2(0.11, 0.12), Vector2(0.14, 0.24)], 8, 0.0, false)
	d.arme(_l(22.7, -74.3), PI * 0.5)
	or_tas(_l(21.6, -75.8), 0.8, 0.45)
	or_tas(_l(21.6, -68.2), 0.7, 0.4)
	or_tas(_l(20.6, -72.0), 0.6, 0.3)
	d.statue(_l(14.0, -66.8), PI * 0.5, 1.1, "ancetre", true, "mur1")
	d.statue(_l(14.0, -77.2), PI * 0.5, 1.1, "ancetre", true, "mur1")
	d.statue(_l(22.0, -66.8), -PI * 0.5, 1.1, "jarl", true, "mur1")
	d.statue(_l(22.0, -77.2), -PI * 0.5, 1.1, "gardienne", true, "mur1")
	d.banniere(_l(18.0, -66.3, 3.9), Vector3(0, 0, -1), 2.2, 0.9, Color(0.45, 0.5, 0.75), "couronne", 0)
	d.tapis(_l(17.0, -72.0), Vector2(7.0, 2.2), 0.0, Color(0.34, 0.16, 0.18))
	d.lumiere(_l(22.6, -72.0, 1.8), Color(1.0, 0.8, 0.45), 0.8, 4.5, 1.6, false)
	d.bougie(_l(22.5, -69.3, 1.0), false)
	d.bougie(_l(22.5, -74.8, 1.0), false)
	# récit, choix moral : piller (beaucoup d'or, relique, gardiens du serment) ou respecter (bénédiction des ancêtres)
	interaction("fresque_svanhild", _l(18.0, -77.0, 1.3), "Fresque de Svanhild", "Lire la fresque", "texte", {"cle": "fresque_svanhild"})
	interaction("inscription_offrandes", _l(22.2, -72.0, 1.2), "Inscription des offrandes", "Lire l’inscription", "texte", {"cle": "inscription_offrandes"})
	var interdit := ["choix:piller_offrandes", "choix:respecter_offrandes"]
	interaction("piller_offrandes", _l(22.1, -74.6, 1.1), "Offrandes royales", "Piller les offrandes", "choix", {"choix": "piller_offrandes", "interdit": interdit})
	interaction("honorer_ancetres", _l(22.1, -69.4, 1.1), "Autel des ancêtres", "S’incliner devant les ancêtres", "choix", {"choix": "respecter_offrandes", "interdit": interdit})

# ------------------------------------------------------------------ aile ouest
func _x_s1(_m: Dictionary) -> void:
	porte_coulissante("s1", _l(-1.6, -9.0), "z")
	interaction("s1_barree", _l(-0.7, -9.0, 1.2), "Porte barrée", "Pousser la porte", "texte", {"texte": ["La porte est barrée de l’autre côté. Il doit y avoir une barre que l’on soulève."], "condition_non": "s1"})
	interaction("s1", _l(-3.0, -9.0, 1.2), "Barre de la porte", "Soulever la barre", "porte", {"condition_non": "s1"})
	d.os_tas(_l(-5.0, -9.4), 3, 0.4)
	d.sac_dechire(_l(-9.0, -8.2), 2.0)

func _x_ossuaire(_m: Dictionary) -> void:
	# autel d'os central, où repose le fragment du sceau des Os
	if d.v2:      # crypte v2 : autel octogonal à deux degrés en blocs taillés
		d.modele("autel_octo", _l(-21, -16), 0.0)
	else:
		d.tour("dalle0", _l(-21, -16), [Vector2(2.6, 0.0), Vector2(2.6, 0.25), Vector2(2.0, 0.25), Vector2(2.0, 0.5)], 8, PI / 8.0, true)
	os_monticule(_l(-21, -16, 0.5), 1.5, 1.1)
	d.crane(_l(-21, -16, 1.6), 0.3)
	d.tour("os", _l(-21, -16, 1.6), [Vector2(0.08, 0.0), Vector2(0.14, 0.18), Vector2(0.06, 0.4)], 6, 0.2, true)
	d.lumiere(_l(-21, -16, 2.1), Color(0.88, 0.82, 0.62), 0.6, 4.0, 1.7, false)
	d.urne(_l(-26.5, -7.4), 1.1)
	d.urne(_l(-15.0, -7.4), 1.1)
	d.etagere(_l(-13.8, -14.5), -PI * 0.5, 1.8, 2.0)
	d.os_tas(_l(-18.0, -15.0), 5, 0.6)
	d.os_tas(_l(-24.0, -17.5), 5, 0.6)
	d.arme(_l(-19.0, -9.5), 1.0)
	d.arme(_l(-23.0, -24.5), 4.2)
	d.bougie(_l(-21.4, -17.2, 0.5), false)
	# les pillards de l'expédition sont passés par la porte de l'est : sac éventré, arme perdue
	d.sac_dechire(_l(-14.8, -18.6), 0.6)
	d.arme(_l(-15.6, -20.4), 2.8)
	# mur fragile (aile ouest) : fissures, gravats et courant d'air vers la chambre secrète
	d.fissures(_l(-28.66, -14.0, 1.4), Vector3(1, 0, 0), 2.2, 2.6, 3)
	souffle(_l(-28.4, -14.0, 0.3), Vector3(0.1, 0.12, 1.1), Vector3(1, 0, 0), 12)

func _x_ossuaire_secret(_m: Dictionary) -> void:
	d.sarcophage(_l(-32.0, -11.6), Vector3(2.2, 0.7, 0.9), 0.0)
	or_tas(_l(-33.0, -14.0), 0.7, 0.35)
	d.os_tas(_l(-31.0, -16.0), 4, 0.5)
	d.urne(_l(-33.2, -12.2), 1.0)
	d.crane(_l(-32.2, -15.0), 0.4)
	d.bougie(_l(-33.0, -11.9, 0.8), false)

func _x_galerie(_m: Dictionary) -> void:
	# les trois gravures murales que les statues doivent regarder : couronne (nord), navire (est), hache (sud)
	d.embleme("couronne", _l(-29.0, -50.68, 2.0), Vector3(0, 0, 1), 1.5)
	d.embleme("navire", _l(-22.32, -43.0, 2.0), Vector3(-1, 0, 0), 1.5)
	d.embleme("hache", _l(-32.0, -35.32, 2.0), Vector3(0, 0, -1), 1.5)
	# plaque au sol près de chaque statue : le même symbole que le mur qu'elle doit regarder
	d.embleme("couronne", _l(-33.0, -42.4, 0.03), Vector3.UP, 0.9)
	d.embleme("navire", _l(-28.0, -48.0, 0.03), Vector3.UP, 0.9)
	d.embleme("hache", _l(-31.0, -39.6, 0.03), Vector3.UP, 0.9)
	# ancêtres de pierre, sarcophages, crâne-indice
	d.statue(_l(-34.0, -49.8), 0.0, 1.15, "ancetre", true, "mur1")
	d.statue(_l(-24.0, -49.8), 0.0, 1.15, "ancetre", true, "mur1")
	d.statue(_l(-22.9, -39.2), -PI * 0.5, 1.15, "gardienne", true, "mur1")
	d.statue(_l(-22.9, -46.6), -PI * 0.5, 1.15, "guerrier", true, "mur1")
	d.sarcophage(_l(-35.2, -48.5), Vector3(2.2, 0.7, 0.9), PI * 0.5)
	d.sarcophage(_l(-35.2, -39.4), Vector3(2.2, 0.7, 0.9), PI * 0.5)
	var sk := _l(-23.4, -35.9)
	d.socle(sk, Vector3(0.7, 1.0, 0.7))
	d.crane(sk + Vector3(0, 1.08, 0), -PI * 0.5)
	interaction("secret_indice", sk + Vector3(0, 1.4, 0), "Crâne descellé", "Examiner le crâne", "texte", {"texte": [
		"Le crâne a été tourné, comme pour fixer la salle. Il regarde des gravures.",
		"« Que les visages de pierre regardent les anciens : la couronne au nord, le navire à l’est, la hache au sud. »"]})
	d.table(_l(-33.0, -36.4), 0.0)
	d.parchemins_epars(_l(-30.0, -44.0), 2.4, 5)
	d.os_tas(_l(-26.5, -41.5), 4, 0.5)
	d.arme(_l(-27.5, -37.5), 0.6)
	# pivot du mur secret : charnière au nord de l'ouverture (z = -45,3), bat vers l'ouest dans la chambre du trésor
	var pv := Node3D.new()
	var w := mw(_l(-36.0, -45.3))
	pv.position = Vector3(w.x, 0.0, w.z)
	d.racine.add_child(pv)
	var sb := StaticBody3D.new()
	pv.add_child(sb)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.6, 3.0, 3.2)
	cs.shape = bs
	cs.position = Vector3(0, 1.5, 1.6 - 0.3)
	sb.add_child(cs)
	var saved := d.xf
	d.xf = Transform3D.IDENTITY
	d.instance_boite(pv, "mur0", Vector3(0.56, 3.0, 2.6), Vector3(-0.02, 1.5, 1.3)).name = "PanneauSecret"
	d.instance_boite(pv, "mur1", Vector3(0.62, 0.3, 2.6), Vector3(0.03, 0.15, 1.3))
	d.xf = saved
	portes["secret"] = pv

func _x_tresor(_m: Dictionary) -> void:
	or_tas(_l(-42.4, -42.0), 0.9, 0.5)
	or_tas(_l(-42.8, -46.2), 0.7, 0.4)
	or_tas(_l(-38.6, -41.2), 0.6, 0.3)
	d.table(_l(-38.2, -46.6), 0.0)
	for k in 4:
		d.arme(_l(-41.0 + k * 0.5, -47.5), 1.6)
	d.urne(_l(-37.2, -47.0), 1.2)
	d.urne(_l(-37.2, -41.0), 1.0)
	d.os_tas(_l(-40.0, -44.6), 3, 0.5)
	d.lumiere(_l(-42.0, -44.0, 1.0), Color(1.0, 0.8, 0.4), 0.8, 4.5, 1.6, false)
	d.banniere(_l(-44.65, -44.0, 3.2), Vector3(1, 0, 0), 1.8, 0.9, Color(0.7, 0.55, 0.25), "couronne", 1)

# ------------------------------------------------------------------ aile est
func _x_glaces(_m: Dictionary) -> void:
	# dais de glace central et lampe
	d.tour("dalle4", _l(26.5, -26.0), [Vector2(2.5, 0.0), Vector2(2.5, 0.2), Vector2(2.0, 0.3), Vector2(1.1, 0.4)], 8, PI / 8.0, true)
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		stalagmite(_l(26.5 + cos(a) * 1.8, -26.0 + sin(a) * 1.8, 0.3), 0.7 + alea(0.0, 0.7), 0.16)
	lampe_glace(_l(26.5, -26.0, 0.4), 1.4)
	# les deux bouches de souffle dans le mur nord : cadres de pierre, givre au sol sur la zone balayée (contournable par le sud)
	for x in [27.0, 31.0]:
		var p := _l(x, -33.55, 1.0)
		d.boite("mur0", p + Vector3(0, 0.38, 0), Vector3(0.62, 0.14, 0.2))
		d.boite("mur0", p - Vector3(0, 0.38, 0), Vector3(0.62, 0.14, 0.2))
		d.boite("mur0", p + Vector3(0.38, 0, 0), Vector3(0.14, 0.9, 0.2))
		d.boite("mur0", p - Vector3(0.38, 0, 0), Vector3(0.14, 0.9, 0.2))
		d.boite("neige", _l(x, -28.6, 0.011), Vector3(1.9, 0.02, 9.3), 0.0, true)
		d.boite("dalle4", _l(x, -28.6, 0.012), Vector3(1.4, 0.02, 9.0), 0.0, true)
	# fragment du Givre sur son socle (coin nord-est), cristal et lueur froide
	d.socle(_l(33.2, -32.2), Vector3(0.8, 1.0, 0.8), 0.0, "mur4")
	d.tour("mur4", _l(33.2, -32.2, 1.14), [Vector2(0.1, 0.0), Vector2(0.16, 0.18), Vector2(0.08, 0.42), Vector2(0.0, 0.58)], 6, 0.3, false)
	d.lumiere(_l(33.2, -32.2, 1.9), Color(0.55, 0.85, 1.0), 0.9, 4.0, 1.6, false)
	d.embleme("givre", _l(34.38, -32.2, 1.9), Vector3(-1, 0, 0), 0.9)
	congere(_l(34.0, -33.0), 1.3, 0.6)
	d.urne(_l(17.8, -32.5), 1.0)
	d.os_tas(_l(33.5, -22.0), 4, 0.5)
	d.arme(_l(19.5, -20.5), 0.8)
	d.crane(_l(24.0, -32.4), 0.9)
	d.banniere(_l(17.3, -26.0, 3.9), Vector3(1, 0, 0), 2.4, 1.0, Color(0.45, 0.58, 0.8), "givre", 2)

func _x_g3(_m: Dictionary) -> void:
	_indice_dalle(39.0, -30.0, 0.0, -PI * 0.5, Vector3(39.0, 1.1, -31.3))

func _x_s2(_m: Dictionary) -> void:
	porte_coulissante("s2", _l(3.0, -2.0), "z")
	interaction("s2_barree", _l(2.0, -2.0, 1.2), "Porte barrée", "Pousser la porte", "texte", {"texte": ["La porte est barrée de l’autre côté. La barre est hors de portée d’ici."], "condition_non": "s2"})
	interaction("s2", _l(4.4, -2.0, 1.2), "Barre de la porte", "Soulever la barre", "porte", {"condition_non": "s2"})
	d.os_tas(_l(6.5, -2.4), 3, 0.4)

func _x_quartiers(_m: Dictionary) -> void:
	# lits (deux rangées), râteliers, boucliers : le calme avant le Givre
	for x in [17.8, 20.0, 23.4]:
		d.lit(_l(x, 0.2), 0.0, Color(0.5, 0.4, 0.34))
	for x in [17.8, 20.0]:
		d.lit(_l(x, -8.2), PI, Color(0.46, 0.4, 0.4))
	d.ratelier_armes(_l(26.62, -7.0), -PI * 0.5, 1.8)
	d.ratelier_armes(_l(26.62, -0.6), -PI * 0.5, 1.4)
	d.bouclier_mural(_l(15.3, -4.0, 1.7), Vector3(1, 0, 0), 0.34, Color(0.55, 0.3, 0.25))
	d.bouclier_mural(_l(15.3, -5.2, 1.7), Vector3(1, 0, 0), 0.34, Color(0.3, 0.38, 0.55))
	d.bouclier_mural(_l(22.0, -8.7, 1.8), Vector3(0, 0, 1), 0.34, Color(0.5, 0.4, 0.3))
	d.table(_l(24.2, -0.6), 0.0)
	d.boite("parchemin", _l(24.2, -0.6, 0.82), Vector3(0.34, 0.012, 0.26), 0.4)
	d.bougie(_l(24.5, -0.7, 0.8), false)
	d.urne(_l(26.0, -8.0), 1.0)
	d.tonneau(_l(16.2, -1.2), 0.9)
	d.boite("bois", _l(19.5, -1.4, 0.02), Vector3(0.9, 0.02, 0.2), 0.1)     # la planche disjointe (cachette)
	d.os_tas(_l(21.0, -4.5), 2, 0.3)
	# mur fragile : fissures et poussière au pied du mur est, courant d'air
	d.fissures(_l(26.66, -4.0, 1.4), Vector3(-1, 0, 0), 2.2, 2.6, 3)
	souffle(_l(26.4, -4.0, 0.3), Vector3(0.1, 0.12, 1.1), Vector3(-1, 0, 0), 12)

func _x_armurerie(_m: Dictionary) -> void:
	d.ratelier_armes(_l(32.62, -2.8), -PI * 0.5, 1.8)
	d.ratelier_armes(_l(32.62, -5.2), -PI * 0.5, 1.4)
	d.arme(_l(30.0, -2.4), 0.5)
	d.arme(_l(29.0, -6.0), 2.1)
	d.bouclier_mural(_l(30.0, -6.7, 1.8), Vector3(0, 0, 1), 0.34, Color(0.5, 0.35, 0.3))
	d.os_tas(_l(29.5, -4.0), 3, 0.4)
	d.urne(_l(32.2, -6.4), 1.0)

func _x_trone(_m: Dictionary) -> void:
	d.trone(_l(56.5, -30.0), -PI * 0.5, "mur4")
	d.statue(_l(44.2, -36.6), 0.0, 1.2, "guerrier", true, "mur4")
	d.statue(_l(44.2, -23.4), PI, 1.2, "guerrier", true, "mur4")
	d.statue(_l(50.0, -37.2), 0.0, 1.2, "jarl", true, "mur4")
	d.statue(_l(50.0, -22.8), PI, 1.2, "ancetre", true, "mur4")
	d.sarcophage(_l(58.0, -26.6), Vector3(2.2, 0.7, 0.9), PI * 0.5)
	lampe_glace(_l(54.8, -33.5), 1.2)
	lampe_glace(_l(54.8, -26.5), 1.2)
	d.tapis(_l(50.0, -30.0), Vector2(10.0, 2.4), 0.0, Color(0.3, 0.38, 0.55))
	d.banniere(_l(58.66, -34.4, 3.9), Vector3(-1, 0, 0), 2.4, 1.0, Color(0.45, 0.58, 0.8), "couronne", 1)
	d.banniere(_l(58.66, -25.6, 3.9), Vector3(-1, 0, 0), 2.4, 1.0, Color(0.45, 0.58, 0.8), "epee", 2)
	d.os_tas(_l(48.0, -30.0), 5, 0.6)
	d.arme(_l(52.0, -32.5), 2.0)
	d.crane(_l(46.0, -27.5), 0.9)
	interaction("inscription_jarl", _l(50.0, -36.0, 1.4), "Stèle du Jarl", "Lire la stèle", "texte", {"cle": "inscription_jarl"})

# ------------------------------------------------------------------ étage -1
func _x_archives(_m: Dictionary) -> void:
	var y := BAS
	# rayonnages debout contre les murs nord et sud, renversés au centre : archives en ruine
	d.etagere(_l(-19.7, -38.5, y), PI, 1.8, 2.0)
	d.etagere(_l(-10.5, -38.5, y), PI, 1.8, 2.0)
	d.etagere(_l(-19.5, -47.5, y), 0.0, 1.8, 2.0)
	d.etagere(_l(-9.0, -47.5, y), 0.0, 1.8, 2.0)
	d.etagere_renversee(_l(-17.2, -42.0, y), 0.5, 1.8)
	d.etagere_renversee(_l(-9.4, -41.0, y), -0.4, 1.6)
	d.parchemins_epars(_l(-14.0, -43.0, y), 4.2, 22)
	d.table(_l(-9.0, -45.4, y), PI * 0.5)
	d.boite("parchemin", _l(-9.0, -45.2, y + 0.82), Vector3(0.3, 0.012, 0.24), 0.3)
	d.bougie(_l(-8.8, -45.7, y + 0.8), false)
	d.boite("bois", _l(-8.0, -39.6, y + 0.35), Vector3(3.4, 0.3, 0.3), 0.5)       # poutre tombée
	d.os_tas(_l(-12.0, -44.8, y), 3, 0.4)
	d.banniere(_l(-6.34, -42.0, y + 3.5), Vector3(-1, 0, 0), 2.0, 0.9, Color(0.3, 0.6, 0.55), "eau", 2)

func _x_barricade(_m: Dictionary) -> void:
	var y := BAS
	# barricade de l'intérieur contre la porte, brèche à l'est ; les compagnons d'Eirik sont morts ici
	d.barricade(_l(-14.0, -49.1, y), 0.0, 3.0, 1.3, 0.9)
	d.os_tas(_l(-16.0, -53.0, y), 5, 0.6)
	d.os_tas(_l(-12.6, -54.2, y), 4, 0.5)
	d.os_tas(_l(-15.0, -51.4, y), 4, 0.5)
	d.sac_dechire(_l(-16.8, -52.2, y), 0.5)
	d.sac_dechire(_l(-11.5, -50.8, y), 2.0)
	d.arme(_l(-13.6, -52.6, y), 1.5)
	d.table(_l(-11.9, -52.2, y), PI * 0.5)
	d.bougie(_l(-11.9, -51.7, y + 0.8), true)
	d.boite("parchemin", _l(-11.9, -52.5, y + 0.82), Vector3(0.3, 0.012, 0.22), 0.1)
	d.etagere_renversee(_l(-16.6, -50.4, y), PI * 0.5, 1.4)
	d.tonneau(_l(-11.2, -54.8, y), 0.8)

func _x_piege_lb2w(_m: Dictionary) -> void:
	_indice_dalle(-25.0, -43.0, BAS, PI * 0.5, Vector3(-25.0, BAS + 1.1, -44.3))

func _x_piege_lb2e(_m: Dictionary) -> void:
	_indice_dalle(-2.0, -43.0, BAS, -PI * 0.5, Vector3(-2.0, BAS + 1.1, -41.7))

func _x_cisterne(_m: Dictionary) -> void:
	var y := BAS
	d.bassin(_l(-35.0, -43.0, y), 5.0, 4.4, 0.5)
	# emblèmes des quatre braseros au sol (cercle, triangle, croix, vague) ; les bannières du mur nord donnent l'ordre : croix, cercle, vague, triangle
	var bp := [Vector2(-39.2, -47.2), Vector2(-30.8, -47.2), Vector2(-39.2, -38.8), Vector2(-30.8, -38.8)]
	var sy := ["cercle", "triangle", "croix", "vague"]
	var ordre := [2, 0, 3, 1]
	for i in 4:
		var b: Vector2 = bp[i]
		d.embleme(sy[i], _l(b.x, b.y + (1.0 if b.y < -43.0 else -1.0), y + 0.03), Vector3.UP, 0.9)
	var teintes := [Color(0.3, 0.6, 0.55), Color(0.35, 0.55, 0.65), Color(0.4, 0.6, 0.55), Color(0.32, 0.5, 0.6)]
	for k in 4:
		d.banniere(_l(-39.6 + k * 2.4, -49.66, y + 3.8), Vector3(0, 0, 1), 2.3, 0.9, teintes[k], sy[ordre[k]], 1 if k != 2 else 2)
	# fragment de l'Eau sur son socle contre le mur ouest (accessible quand les braseros sont allumés dans l'ordre)
	d.socle(_l(-40.6, -43.0, y), Vector3(0.8, 1.0, 0.8), 0.0, "mur2")
	d.tour("mur2", _l(-40.6, -43.0, y + 1.14), [Vector2(0.12, 0.0), Vector2(0.16, 0.16), Vector2(0.08, 0.4), Vector2(0.0, 0.55)], 6, 0.3, false)
	d.lumiere(_l(-40.6, -43.0, y + 1.8), Color(0.3, 0.8, 0.75), 0.9, 4.0, 1.6, false)
	d.embleme("eau", _l(-41.68, -43.0, y + 1.9), Vector3(1, 0, 0), 0.9)
	for k in 4:     # cuves et tonneaux contre le mur sud
		d.tonneau(_l(-35.0 + (k - 1.5) * 1.2, -36.8, y), 1.1)
	d.os_tas(_l(-38.0, -43.0, y), 4, 0.6)
	d.arme(_l(-33.0, -37.6, y), 2.0)
	d.crane(_l(-36.0, -40.2, y + 0.5), 0.0)
	d.parchemins_epars(_l(-33.0, -48.0, y), 1.4, 5)

func _x_chapelle(_m: Dictionary) -> void:
	var y := BAS
	d.autel(_l(6.0, -55.15, y), 0.0, 2.4)
	d.embleme("eau", _l(6.0, -55.66, y + 2.2), Vector3(0, 0, 1), 1.3)
	for k in 3:   # bancs
		d.table(_l(4.2, -43.5 - k * 2.2, y), PI * 0.5)
		d.table(_l(7.8, -43.5 - k * 2.2, y), PI * 0.5)
	d.banniere(_l(2.34, -48.0, y + 3.3), Vector3(1, 0, 0), 2.0, 0.9, Color(0.3, 0.6, 0.55), "eau", 1)
	d.banniere(_l(9.66, -48.0, y + 3.3), Vector3(-1, 0, 0), 2.0, 0.9, Color(0.3, 0.6, 0.55), "eau", 2)
	d.statue(_l(3.3, -53.4, y), 0.0, 1.1, "ancetre", true, "mur1")
	d.statue(_l(8.7, -53.4, y), 0.0, 1.1, "gardienne", true, "mur1")
	d.bougie(_l(3.0, -44.5, y + 0.8), false)
	d.os_tas(_l(5.5, -47.0, y), 2, 0.3)

func _x_garde(_m: Dictionary) -> void:
	var y := BAS
	# salle de garde : réserve de tonneaux, râtelier, table de jeu ; le butin est au fond
	for k in 4:
		d.tonneau(_l(27.0, -48.0 - k * 0.9, y), 1.0)
	d.tonneau(_l(27.0, -49.0, y + 1.0), 1.0)
	d.ratelier_armes(_l(16.62, -57.0, y), PI * 0.5, 1.8)
	d.table(_l(18.5, -52.0, y), 0.0)
	d.arme(_l(21.0, -50.0, y), 1.1)
	d.os_tas(_l(24.0, -55.0, y), 4, 0.5)
	d.sac_dechire(_l(26.0, -54.0, y), 0.8)
	d.bouclier_mural(_l(22.0, -59.7, y + 1.9), Vector3(0, 0, 1), 0.34, Color(0.5, 0.4, 0.3))
