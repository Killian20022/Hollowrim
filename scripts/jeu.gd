class_name Jeu
## Identité du jeu, options du joueur, migration des sauvegardes et relance du processus.
##
## NOM : le nom officiel est lu dans project.godot (application/config/name) — c'est LE réglage à changer pour renommer
## le jeu (penser aussi à application/config/custom_user_dir_name, qui fixe le dossier des sauvegardes, et à relancer
## outils/exporter_windows.sh qui recopie nom et version dans export_presets.cfg).
## Dossier des sauvegardes (Windows) : %APPDATA%\Hollowrim\ (use_custom_user_dir).
##
## Options : user://options.cfg (sections « affichage », « son », « commandes »), lues par l'autoload Lancement.

const NOM_PAR_DEFAUT := "Hollowrim"
const FICHIER_OPTIONS := "user://options.cfg"
const SCENE_JEU := "res://scenes/foret_test.tscn"
const SCENE_TITRE := "res://scenes/ecran_titre.tscn"
## Dossier des sauvegardes avant le renommage (application/config/name = « Nordique (nom provisoire) », sans dossier perso).
const ANCIEN_DOSSIER := "Godot/app_userdata/Nordique (nom provisoire)"
## Fichiers repris de l'ancien dossier au premier lancement (copiés, jamais déplacés ni effacés).
const FICHIERS_MIGRES := ["sauvegarde.json", "fenetre.cfg"]

static func nom() -> String:
	return str(ProjectSettings.get_setting("application/config/name", NOM_PAR_DEFAUT))

static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## Lancement d'outil ou de test : arguments utilisateur (après « -- ») autres que ceux qui ne changent pas le jeu
## (--hors-ecran des agents, --test-titre=… du test des menus), --script, ou sans fenêtre.
## En mode outil, l'écran titre passe directement au monde (les captures et scripts d'agents restent inchangés)
## et les options du joueur ne sont pas appliquées (images et sons comparables d'un lancement à l'autre).
static func mode_outil() -> bool:
	var args := OS.get_cmdline_args()
	if "--script" in args or "-s" in args:
		return true
	for a in OS.get_cmdline_user_args():
		if a != "--hors-ecran" and not a.begins_with("--test-titre"):
			return true
	return false

## Argument --test-titre=<étape> (test automatique des menus, outils/test_menus.sh) ; "" sinon.
static func test_titre() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test-titre="):
			return a.substr(13)
	return ""

# --- options ------------------------------------------------------------------------

const OPTIONS_DEFAUT := {
	"affichage": {"plein_ecran": false, "champ_vision": 72.0},
	"son": {"general": 1.0, "musique": 0.8, "effets": 1.0},
	"commandes": {"sensibilite": 1.0, "inverser_y": false},
}
static var options := {}
## Choisi à l'écran titre : vrai = « Nouvelle partie » (le monde ne lit pas la sauvegarde, comme --nouvelle).
static var nouvelle_partie := false
## Lus à chaque mouvement de souris (joueur.gd) : multiplicateur de SENSIBILITE et signe de l'axe vertical.
static var sensibilite := 1.0
static var inverser_y := false
static var champ_vision := 72.0

static func charger_options() -> void:
	options = OPTIONS_DEFAUT.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(FICHIER_OPTIONS) == OK:
		for section: String in options:
			for cle: String in options[section]:
				var v: Variant = cfg.get_value(section, cle, options[section][cle])
				if typeof(v) == typeof(options[section][cle]) or (v is int and options[section][cle] is float):
					options[section][cle] = v
	elif FileAccess.file_exists("user://fenetre.cfg"):   # réglage de F11 d'avant options.cfg
		cfg.load("user://fenetre.cfg")
		options["affichage"]["plein_ecran"] = bool(cfg.get_value("fenetre", "plein_ecran", false))
	_copier_dans_statiques()

static func option(section: String, cle: String) -> Variant:
	if options.is_empty():
		charger_options()
	return options[section][cle]

static func regler(section: String, cle: String, valeur: Variant) -> void:
	if options.is_empty():
		charger_options()
	options[section][cle] = valeur
	_copier_dans_statiques()
	appliquer_son()
	var cfg := ConfigFile.new()
	cfg.load(FICHIER_OPTIONS)   # garde les clés inconnues (versions futures)
	for s: String in options:
		for c: String in options[s]:
			cfg.set_value(s, c, options[s][c])
	cfg.save(FICHIER_OPTIONS)

static func _copier_dans_statiques() -> void:
	sensibilite = clampf(float(options["commandes"]["sensibilite"]), 0.2, 3.0)
	inverser_y = bool(options["commandes"]["inverser_y"])
	champ_vision = clampf(float(options["affichage"]["champ_vision"]), 60.0, 90.0)

## Bus « Musique » et « Effets » (enfants de Master) ; créés par l'autoload Lancement.
static func creer_bus() -> void:
	for nom_bus in ["Musique", "Effets"]:
		if AudioServer.get_bus_index(nom_bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nom_bus)
			AudioServer.set_bus_send(i, &"Master")

static func appliquer_son() -> void:
	if options.is_empty():
		return
	for p in [["Master", "general"], ["Musique", "musique"], ["Effets", "effets"]]:
		var i := AudioServer.get_bus_index(p[0])
		if i == -1:
			continue
		var v := clampf(float(options["son"][p[1]]), 0.0, 1.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)

## Champ de vision des caméras du joueur (1re et 3e personne).
static func appliquer_camera(joueur: Node) -> void:
	if joueur == null:
		return
	if joueur.get("camera") is Camera3D:
		joueur.camera.fov = champ_vision
	var tp: Node = joueur.get("camera_tp")
	if tp != null and tp.get("camera") is Camera3D:
		tp.camera.fov = champ_vision

# --- sauvegarde ----------------------------------------------------------------------

## Vrai si la partie que « Continuer » chargerait existe (même fichier que Monde.fichier_sauvegarde()).
static func sauvegarde_existe() -> bool:
	return FileAccess.file_exists(load("res://scripts/monde.gd").fichier_sauvegarde())

## Migration au premier lancement sous le nom Hollowrim : si le dossier des sauvegardes neuf n'a pas de partie et que
## l'ancien (app_userdata/Nordique (nom provisoire)) en a une, on COPIE les fichiers (l'ancien dossier n'est ni modifié ni effacé).
## Renvoie la liste des fichiers copiés. `ancien` / `neuf` : chemins absolus (paramètres pour le test, sur des copies).
static func migrer(ancien: String, neuf: String) -> PackedStringArray:
	var copies := PackedStringArray()
	if ancien == "" or neuf == "" or ancien.simplify_path() == neuf.simplify_path():
		return copies
	if FileAccess.file_exists(neuf.path_join("sauvegarde.json")) or not FileAccess.file_exists(ancien.path_join("sauvegarde.json")):
		return copies
	DirAccess.make_dir_recursive_absolute(neuf)
	for f: String in FICHIERS_MIGRES:
		var src := ancien.path_join(f)
		var dst := neuf.path_join(f)
		if FileAccess.file_exists(src) and not FileAccess.file_exists(dst):
			if DirAccess.copy_absolute(src, dst) == OK:
				copies.append(f)
	return copies

static func dossier_ancien() -> String:
	return OS.get_config_dir().path_join(ANCIEN_DOSSIER)   # Windows : %APPDATA%

# --- relance du processus -------------------------------------------------------------

## Recréer le monde dans le même processus fait planter Godot (modèles importés rechargés en double, voir F9 dans monde.gd) :
## « Retour au titre », F9 (charger) et toute nouvelle partie après une partie passent par une relance du processus.
## `action` est lue par l'écran titre au démarrage suivant : "" (titre), "continuer" (charge la partie aussitôt).
static func relancer(action := "") -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("relance", "action", action)
	cfg.save(_fichier_relance())
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	var arbre := Engine.get_main_loop() as SceneTree
	arbre.paused = false
	arbre.quit()

## Lit l'action laissée par relancer() et la consomme (une seule fois).
static func lire_relance() -> String:
	var f := _fichier_relance()
	if not FileAccess.file_exists(f):
		return ""
	var cfg := ConfigFile.new()
	cfg.load(f)
	var action := str(cfg.get_value("relance", "action", ""))
	if action != "":
		cfg.set_value("relance", "action", "")
		cfg.save(f)
	return action

## Un fichier par copie du projet (comme la sauvegarde de test) : deux worktrees lancés en même temps ne se mélangent pas.
static func _fichier_relance() -> String:
	return "user://relance_%08x.cfg" % (hash(ProjectSettings.globalize_path("res://")) & 0xffffffff)
