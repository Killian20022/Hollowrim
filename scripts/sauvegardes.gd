class_name Sauvegardes
extends RefCounted
## Emplacements de sauvegarde : 3 emplacements manuels (1 à 3) + 1 automatique (0).
##   - emplacement 1 = le fichier d'avant les emplacements (user://sauvegarde.json) : les parties existantes n'ont rien à migrer ;
##   - emplacements 2 et 3 : sauvegarde_2.json, sauvegarde_3.json ; automatique : sauvegarde_auto.json (même dossier) ;
##   - tests et captures (arguments utilisateur, --script, sans fenêtre) : mêmes noms sur le fichier de TEST de la copie du projet.
## L'écriture est atomique : fichier temporaire (.tmp), relu et vérifié, puis renommé sur la cible ; une sauvegarde en cours
## d'écriture n'écrase donc jamais la précédente. Le format du contenu (JSON versionné, Migration) n'a pas changé.
## `actif` : l'emplacement de la partie en cours (celui que lisent Monde.charger et Monde.fichier_sauvegarde, et où écrivent
## F5, la fermeture du jeu et « Retour au titre »). L'écran titre le règle sur la sauvegarde la plus récente.

const AUTO := 0
const NB_MANUELS := 3
const SAUVEGARDE_REELLE := "user://sauvegarde.json"

static var actif := 1

## Fichier de TEST de cette copie du projet : un par worktree, pour que deux tests lancés ensemble ne s'écrasent pas.
static func fichier_test() -> String:
	return "user://sauvegarde_test_%08x.json" % (hash(ProjectSettings.globalize_path("res://")) & 0xffffffff)

## Fichier de l'emplacement 1 (celui d'avant les emplacements).
static func fichier_base() -> String:
	var args := OS.get_cmdline_args()
	if OS.get_cmdline_user_args().size() > 0 or "--script" in args or "-s" in args or DisplayServer.get_name() == "headless":
		return fichier_test()
	return SAUVEGARDE_REELLE

## Fichier d'un emplacement (0 = automatique, 1 à 3 = manuels).
static func fichier(emplacement: int) -> String:
	var base := fichier_base()
	match emplacement:
		1:
			return base
		AUTO:
			return base.get_basename() + "_auto.json"
	return base.get_basename() + "_%d.json" % emplacement

static func nom(emplacement: int) -> String:
	return "Sauvegarde automatique" if emplacement == AUTO else "Emplacement %d" % emplacement

## Les quatre emplacements, dans l'ordre d'affichage : automatique d'abord, puis 1 à 3.
static func tous() -> Array:
	return [AUTO, 1, 2, 3]

static func valide(emplacement: int) -> bool:
	return Jeu.sauvegarde_valide(fichier(emplacement))

## Emplacement lisible le plus récemment écrit (date du fichier) ; -1 s'il n'y en a aucun. Égalité : le manuel l'emporte.
static func plus_recent() -> int:
	var meilleur := -1
	var t_max := -1
	for e: int in [1, 2, 3, AUTO]:
		if not valide(e):
			continue
		var t := int(FileAccess.get_modified_time(fichier(e)))
		if t > t_max:
			t_max = t
			meilleur = e
	return meilleur

## Premier emplacement manuel sans partie valide (nouvelle partie, F5 depuis l'automatique) ; -1 si les trois sont pris.
static func premier_libre() -> int:
	for e in range(1, NB_MANUELS + 1):
		if not valide(e):
			return e
	return -1

## Emplacement où F5 écrit : celui de la partie en cours s'il est manuel, sinon le premier libre, sinon le 1.
static func emplacement_rapide() -> int:
	if actif >= 1:
		return actif
	var libre := premier_libre()
	return libre if libre >= 1 else 1

## Écrit `texte` dans `chemin` de façon atomique. Renvoie OK ou le code d'erreur ; la cible reste intacte en cas d'échec.
static func ecrire(chemin: String, texte: String) -> Error:
	var tmp := chemin + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(texte)
	var err := f.get_error()
	f.close()
	if err != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return err
	var relu := JSON.new()   # on ne remplace la bonne sauvegarde que par un fichier relu et valide
	if relu.parse(FileAccess.get_file_as_string(tmp)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return ERR_FILE_CORRUPT
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_cible := ProjectSettings.globalize_path(chemin)
	err = DirAccess.rename_absolute(abs_tmp, abs_cible)
	if err != OK and FileAccess.file_exists(chemin):   # Windows : renommer sur un fichier existant peut exiger de le retirer d'abord
		DirAccess.remove_absolute(abs_cible)
		err = DirAccess.rename_absolute(abs_tmp, abs_cible)
	return err

## Résumé d'un emplacement pour les listes : {emplacement, nom, vide (bool), date, heure, pieces, niveau}.
static func resume(emplacement: int) -> Dictionary:
	var r := {"emplacement": emplacement, "nom": nom(emplacement), "vide": true, "date": "", "heure": -1.0, "pieces": 0, "niveau": 0}
	var f := fichier(emplacement)
	var base := Jeu.resume_sauvegarde(f)
	if base.is_empty():
		return r
	r["vide"] = false
	r["date"] = base["date"]
	r["heure"] = base["heure"]
	r["pieces"] = base["pieces"]
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(f))
	var prog: Variant = d.get("progression", {})
	if prog is Dictionary:
		r["niveau"] = int((prog as Dictionary).get("niveau", 0))
	return r

## Une ligne lisible : « Emplacement 2 — niveau 4 — 12 pièces — 04/11/2026 à 21h30 » ou « Emplacement 3 — vide ».
static func ligne(r: Dictionary) -> String:
	if r["vide"]:
		return "%s — vide" % r["nom"]
	var niveau := " — niveau %d" % r["niveau"] if int(r["niveau"]) > 0 else ""
	return "%s%s — %d pièces — %s" % [r["nom"], niveau, r["pieces"], r["date"]]
