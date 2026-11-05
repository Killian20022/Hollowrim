class_name Graphismes
extends RefCounted
## Options graphiques (Options > Affichage) : taille de la fenêtre, synchronisation verticale, limite d'images par seconde et
## portée des ombres du soleil et de la lune. Valeurs enregistrées dans options.cfg (Jeu, section « affichage »).
## Rien n'est appliqué en mode outil (Jeu.mode_outil) : tests et captures restent comparables d'un lancement à l'autre.
## Le rendu interne reste en 640x360 (pixels PS1) : la résolution est la taille de la FENÊTRE, agrandie par un facteur entier.

## Tailles de fenêtre proposées (l'indice 0, « Automatique », laisse la fenêtre telle quelle). Sans effet en plein écran.
const RESOLUTIONS := [Vector2i.ZERO, Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
## Limites d'images par seconde (0 = aucune limite).
const LIMITES_IPS := [0, 30, 60, 90, 120, 144]
## Ombres : désactivées, proches, normales (réglage d'origine), lointaines. Facteur appliqué à la portée d'origine de chaque lumière.
const OMBRES := ["Désactivées", "Proches", "Normales", "Lointaines"]
const FACTEURS_OMBRES := [0.0, 0.55, 1.0, 1.7]

static func noms_resolutions() -> Array:
	var l: Array = ["Automatique"]
	for i in range(1, RESOLUTIONS.size()):
		l.append("%d × %d" % [RESOLUTIONS[i].x, RESOLUTIONS[i].y])
	return l

static func noms_limites() -> Array:
	var l: Array = []
	for v: int in LIMITES_IPS:
		l.append("Illimitée" if v == 0 else "%d i/s" % v)
	return l

## Applique vsync, limite d'images et taille de fenêtre (au lancement par l'autoload Fenetre, puis à chaque changement).
static func appliquer() -> void:
	if Jeu.mode_outil() or DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(Jeu.option("affichage", "vsync")) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(LIMITES_IPS[clampi(int(Jeu.option("affichage", "limite_ips")), 0, LIMITES_IPS.size() - 1)])
	appliquer_resolution()

static func appliquer_resolution() -> void:
	if Jeu.mode_outil() or DisplayServer.get_name() == "headless":
		return
	var i := clampi(int(Jeu.option("affichage", "resolution")), 0, RESOLUTIONS.size() - 1)
	if i == 0 or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var taille: Vector2i = RESOLUTIONS[i]
	var ecran := DisplayServer.window_get_current_screen()
	var zone := DisplayServer.screen_get_usable_rect(ecran)
	taille = Vector2i(mini(taille.x, zone.size.x), mini(taille.y, zone.size.y))   # jamais plus grande que l'écran
	DisplayServer.window_set_size(taille)
	DisplayServer.window_set_position(zone.position + (zone.size - taille) / 2)

## Portée des ombres des lumières directionnelles (soleil, lune) : facteur de OMBRES sur la portée d'origine, mémorisée dans la
## lumière (méta « ombre_origine ») pour que les changements successifs ne se cumulent pas.
static func appliquer_ombres(arbre: SceneTree, niveau := -1) -> void:
	if niveau < 0:
		niveau = int(Jeu.option("affichage", "ombres"))
	niveau = clampi(niveau, 0, OMBRES.size() - 1)
	for n in arbre.root.find_children("*", "DirectionalLight3D", true, false):
		var l := n as DirectionalLight3D
		if not l.has_meta("ombre_origine"):
			if not l.shadow_enabled:
				continue   # lumière sans ombre dans le jeu : on ne lui en donne pas
			l.set_meta("ombre_origine", Vector2(1.0, l.directional_shadow_max_distance))
		var origine: Vector2 = l.get_meta("ombre_origine")
		l.shadow_enabled = FACTEURS_OMBRES[niveau] > 0.0
		l.directional_shadow_max_distance = origine.y * maxf(FACTEURS_OMBRES[niveau], 0.01)
