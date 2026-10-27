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
	"affichage": {"plein_ecran": false, "champ_vision": 72.0, "reduire_mouvements": false},   # réduire : bras et tête bougent moins (mal des transports)
	"son": {"general": 1.0, "musique": 0.8, "effets": 1.0},
	"commandes": {"sensibilite": 1.0, "inverser_y": false},
	"sauvegarde": {"dossier_secours": ""},   # "" = copie de secours désactivée
	"combat": {"gore": 2},   # sang et gore : 2 complet (défaut), 1 réduit, 0 désactivé (scripts/combat/sang.gd)
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

# --- copie de secours (dossier choisi par le joueur : Google Drive, OneDrive, clé USB…) ----------------------------

const SECOURS_GARDEES := 10
## Message du dernier échec de copie ("" si la dernière a réussi) : affiché discrètement par le menu pause.
static var avertissement_secours := ""

## Dossier de la copie de secours ("" = désactivée). Test : --test-titre-secours=<dossier> (jamais enregistré).
## En mode outil (tests, captures) : désactivée, pour ne jamais mêler une sauvegarde de test aux copies du joueur.
static func dossier_secours() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test-titre-secours="):
			return a.substr(21)
	if mode_outil():
		return ""
	return str(option("sauvegarde", "dossier_secours"))

static func _prefixe_secours() -> String:
	return nom() + "_sauvegarde_"

## Après chaque sauvegarde réussie (Monde.sauvegarder) : copie horodatée de la partie (+ options.cfg) dans le dossier de
## secours, écrite en .tmp puis renommée (jamais de fichier à moitié écrit), en gardant les SECOURS_GARDEES dernières.
## Un échec ne lève rien : avertissement dans la console + avertissement_secours ; la sauvegarde locale n'en dépend pas.
static func copie_secours(fichier: String, dossier := "") -> bool:
	if dossier == "":
		dossier = dossier_secours()
	if dossier == "":
		return true
	avertissement_secours = ""
	if not DirAccess.dir_exists_absolute(dossier) and DirAccess.make_dir_recursive_absolute(dossier) != OK:
		return _echec_secours("dossier inaccessible : " + dossier)
	var horodatage := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var err := _copier_atomique(ProjectSettings.globalize_path(fichier), dossier.path_join("%s%s.json" % [_prefixe_secours(), horodatage]))
	if err != OK:
		return _echec_secours("copie impossible (%s) vers %s" % [error_string(err), dossier])
	if FileAccess.file_exists(FICHIER_OPTIONS):
		_copier_atomique(ProjectSettings.globalize_path(FICHIER_OPTIONS), dossier.path_join("%soptions_%s.cfg" % [nom() + "_", horodatage]))
	_elaguer(dossier, _prefixe_secours(), ".json")
	_elaguer(dossier, nom() + "_options_", ".cfg")
	return true

static func _echec_secours(message: String) -> bool:
	avertissement_secours = message
	push_warning("Copie de secours : " + message)
	return false

static func _copier_atomique(src: String, dst: String) -> Error:
	if not FileAccess.file_exists(src):
		return ERR_FILE_NOT_FOUND
	var donnees := FileAccess.get_file_as_bytes(src)
	if donnees.is_empty():
		return FileAccess.get_open_error() if FileAccess.get_open_error() != OK else ERR_FILE_CORRUPT
	var tmp := dst + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(donnees)
	f.close()
	if FileAccess.file_exists(dst):
		DirAccess.remove_absolute(dst)
	return DirAccess.rename_absolute(tmp, dst)

## Copies de secours (chemins absolus), de la plus ancienne à la plus récente (l'horodatage se trie comme du texte).
static func copies_secours(dossier := "") -> PackedStringArray:
	if dossier == "":
		dossier = dossier_secours()
	var res := PackedStringArray()
	if dossier == "" or not DirAccess.dir_exists_absolute(dossier):
		return res
	for f in DirAccess.get_files_at(dossier):
		if f.begins_with(_prefixe_secours()) and f.ends_with(".json"):
			res.append(dossier.path_join(f))
	res.sort()
	return res

## Ne supprime que nos propres copies (préfixe Hollowrim_…), les plus anciennes au-delà de SECOURS_GARDEES.
static func _elaguer(dossier: String, prefixe: String, suffixe: String) -> void:
	var liste := PackedStringArray()
	for f in DirAccess.get_files_at(dossier):
		if f.begins_with(prefixe) and f.ends_with(suffixe):
			liste.append(f)
	liste.sort()
	for i in maxi(0, liste.size() - SECOURS_GARDEES):
		DirAccess.remove_absolute(dossier.path_join(liste[i]))

static func sauvegarde_valide(fichier := "") -> bool:
	if fichier == "":
		fichier = load("res://scripts/monde.gd").fichier_sauvegarde()
	if not FileAccess.file_exists(fichier):
		return false
	var j := JSON.new()   # instance : une sauvegarde illisible ne remplit pas la console d'erreurs
	return j.parse(FileAccess.get_file_as_string(fichier)) == OK and j.data is Dictionary

## Restaure la copie de secours valide la plus récente à la place de la sauvegarde locale ; une sauvegarde locale
## illisible est gardée à côté (« .corrompue »), jamais effacée. Renvoie true si une copie a été restaurée.
static func restaurer_secours(dossier := "") -> bool:
	var copies := copies_secours(dossier)
	for i in range(copies.size() - 1, -1, -1):
		if restaurer_copie(copies[i]):
			return true
	return false

## Restaure UNE copie de secours (panneau « Charger » de l'écran titre) à la place de la sauvegarde locale. La sauvegarde locale
## n'est jamais effacée : gardée à côté en « .corrompue » si elle est illisible, en « .avant_restauration » sinon.
static func restaurer_copie(copie: String) -> bool:
	if not sauvegarde_valide(copie):
		return false
	var abs_locale := ProjectSettings.globalize_path(load("res://scripts/monde.gd").fichier_sauvegarde())
	if FileAccess.file_exists(abs_locale):
		_copier_atomique(abs_locale, abs_locale + (".avant_restauration" if sauvegarde_valide(abs_locale) else ".corrompue"))
	if _copier_atomique(copie, abs_locale) == OK:
		print("Copie de secours restaurée : ", copie)
		return true
	return false

## Résumé d'une sauvegarde pour le panneau « Charger » : {date (texte), heure (heure du jeu, -1 si absente), pieces, vie} ;
## {} si le fichier est absent ou illisible.
static func resume_sauvegarde(fichier := "") -> Dictionary:
	if fichier == "":
		fichier = load("res://scripts/monde.gd").fichier_sauvegarde()
	if not sauvegarde_valide(fichier):
		return {}
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fichier))
	var t := Time.get_datetime_dict_from_unix_time(FileAccess.get_modified_time(fichier) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	var inv: Variant = d.get("inventaire", {})
	var j: Variant = d.get("joueur", {})
	return {
		"date": "%02d/%02d/%04d à %02dh%02d" % [t.day, t.month, t.year, t.hour, t.minute],
		"heure": float(d.get("heure", -1.0)),
		"pieces": int(inv.get("pieces", 0)) if inv is Dictionary else 0,
		"vie": float(j.get("vie", 0.0)) if j is Dictionary else 0.0,
	}

# --- chargement étalé (écran titre → écran de chargement) ------------------------------

## Vrai pendant que l'écran de chargement de l'écran titre fait entrer le monde : Monde._ready rend alors une image entre ses étapes
## (l'écran de chargement reste animé). Faux partout ailleurs (tests, outils, captures) : chargement d'un bloc, comme avant.
static var chargement_etale := false
## Étapes de Monde._ready franchies (Monde._chrono) et nom de la dernière : avancement de l'écran de chargement.
static var etapes_chargement := 0
static var etape_chargement := ""

# --- relance du processus -------------------------------------------------------------

## Recréer le monde dans le même processus fait planter Godot (modèles importés rechargés en double, voir F9 dans monde.gd) :
## « Retour au titre », F9 (charger) et toute nouvelle partie après une partie passent par une relance du processus.
## `action` est lue par l'écran titre au démarrage suivant : "" (titre), "continuer" (charge la partie aussitôt).
static func relancer(action := "") -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("relance", "action", action)
	cfg.save(_fichier_relance())
	# get_cmdline_args() n'inclut pas les arguments utilisateur (après « -- ») : on les remet (--hors-ecran, tests…)
	var args := OS.get_cmdline_args()
	if not OS.get_cmdline_user_args().is_empty():
		args.append("--")
		args.append_array(OS.get_cmdline_user_args())
	if sortie_directe():
		OS.create_process(OS.get_executable_path(), args)   # nouveau processus détaché, puis fin directe de celui-ci
		quitter()
		return
	OS.set_restart_on_exit(true, args)
	var arbre := Engine.get_main_loop() as SceneTree
	arbre.paused = false
	arbre.quit()

## Jeu exporté (modèle « release ») : le nettoyage du moteur à la sortie PLANTE une fois le monde chargé (Windows 0xC0000374
## corruption du tas, ou 0xC0000005 ; mesuré le 2026-10-26 sur Hollowrim 0.1.0, que l'on quitte 6 s ou 45 s après le chargement ;
## l'éditeur et le modèle « debug » sortent proprement). Le plantage empêchait aussi la relance (« Retour au titre »).
## Tout étant déjà écrit (sauvegarde, options : fichiers fermés), le processus se termine donc directement (code 0).
## En développement (éditeur, build debug) : sortie normale, pour garder les avertissements de fuites.
static func sortie_directe() -> bool:
	return not OS.is_debug_build()

## Quitter le jeu (menus, fermeture de la fenêtre) : voir sortie_directe().
static func quitter(code := 0) -> void:
	if sortie_directe():
		# corps bâtis pendant le chargement : rangés AVANT la sortie directe (Monde._exit_tree, qui le fait d'habitude, n'est pas
		# appelé ici : en jouant puis en quittant par le menu, le jeu exporté ne rangeait jamais ses corps et les rebâtissait au lancement suivant)
		CachePersos.ecrire_en_attente()
		OS.kill(OS.get_process_id())
		return
	(Engine.get_main_loop() as SceneTree).quit(code)

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
