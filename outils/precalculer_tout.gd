extends SceneTree
## Régénère TOUT ce qui est précalculé (textures et cartes) d'un seul coup, chaque générateur dans son propre Godot :
##   godot --headless --path . --script res://outils/precalculer_tout.gd
## Options (après `--`) :  --verifier   ne rien écrire : compare chaque précalcul au calcul direct (octet par octet)
##                         seulement=a,b  ne lancer que ces étapes (arbres, ecorces, sol, crypte, grotte, bati, petites, rues, carte_sol)
## RÈGLE : après toute modification d'un générateur (textures_arbres.gd, ecorces.gd, crypte_textures.gd, grotte_textures.gd,
## peinture_bati.gd, sol_tuiles.gd…), incrémenter sa constante VERSION (quand elle existe) puis relancer cet outil.
## La carte de sol (carte_sol.res) porte une signature de ses entrées : elle se périme toute seule dès que le relief, les
## arbres, les rochers ou les chemins changent, et il faut alors relancer cet outil (le jeu recalcule en attendant).
const ETAPES := {
	"arbres": ["generer_arbres.gd", ["--"]],
	"ecorces": ["generer_ecorces.gd", ["--"]],
	"sol": ["generer_sol.gd", []],
	"crypte": ["generer_crypte.gd", []],
	"grotte": ["generer_grotte.gd", []],
	"bati": ["cuire_bati.gd", []],
	"petites": ["generer_petites.gd", []],
	"rues": ["generer_rues_village.gd", ["--", "--nouvelle"]],     # C7a : géométrie du village v2 (suit le relief)
	"carte_sol": ["generer_carte_sol.gd", ["--", "--nouvelle"]],   # en dernier : lit les autres précalculs
}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var verifier := args.has("--verifier")
	var seulement: PackedStringArray = []
	for a in args:
		if a.begins_with("--seulement="):
			seulement = a.substr(12).split(",")
	var t0 := Time.get_ticks_msec()
	var echecs := 0
	for nom: String in ETAPES:
		if not seulement.is_empty() and not seulement.has(nom):
			continue
		if verifier and not ["carte_sol", "rues", "arbres", "ecorces"].has(nom):
			echecs += _verifier_en_place(nom)
			continue
		var t := Time.get_ticks_msec()
		var cmd: Array = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://outils/" + ETAPES[nom][0]]
		cmd.append_array(ETAPES[nom][1])
		if verifier:
			cmd.append("--verifier")
		var sortie := []
		var code := OS.execute(OS.get_executable_path(), cmd, sortie, true)
		var texte := str(sortie[0]) if sortie.size() > 0 else ""
		var resume := ""
		for l in texte.split("\n"):
			if l.strip_edges() != "" and not l.begins_with("ERROR") and not l.begins_with("WARNING") and not l.begins_with("   at:") and not l.begins_with("Godot Engine"):
				resume = l.strip_edges()
		print("[%s] code %d en %d ms : %s" % [nom, code, _depuis(t), resume])
		if code != 0:
			echecs += 1
			print(texte)
	print("précalcul terminé en %d ms%s" % [Time.get_ticks_msec() - t0, "" if echecs == 0 else " : %d ÉCHEC(S)" % echecs])
	quit(1 if echecs > 0 else 0)

func _depuis(t: int) -> int:
	return Time.get_ticks_msec() - t

## Vérification en place (sans sous-processus) des familles dont le générateur n'a pas de mode --verifier :
## chaque fichier .res est comparé au calcul direct, octet par octet. Renvoie le nombre de différences.
func _verifier_en_place(nom: String) -> int:
	var diff := 0
	var n := 0
	var t := Time.get_ticks_msec()
	match nom:
		"crypte":
			for tex: String in CrypteDecor.AVEC_MIPS + CrypteDecor.SANS_MIPS:
				var p := CrypteTextures.paire(tex)
				var a: Image = CrypteTextures.mips_image(p[0]) if tex in CrypteDecor.AVEC_MIPS else p[0]
				diff += _cmp(a, "%s/%s.res" % [CrypteTextures.DOSSIER, tex]); n += 1
				if p[1] != null:
					diff += _cmp(p[1], "%s/%s_nm.res" % [CrypteTextures.DOSSIER, tex]); n += 1
		"sol":
			var r := SolTuiles.calculer()
			for cle: Array in [["atlas_index", "sol_index"], ["atlas_couleur", "sol_couleur"], ["image_details", "sol_details"], ["atlas_index2", "sol_index2"], ["image_details2", "sol_details2"]]:
				diff += _cmp(r[cle[0]], "%s/%s.res" % [SolTuiles.DOSSIER, cle[1]]); n += 1
		"grotte":
			for tex: String in GrotteDecor.PROPRES_MIPS + GrotteDecor.PROPRES_PLATES:
				diff += _cmp(GrotteDecor.image_finale(tex), "%s/%s.res" % [GrotteDecor.DOSSIER, tex]); n += 1
		"bati":
			var f := PeintureBati.fabriques()
			for tex: String in f:
				var r: Array = (f[tex] as Callable).call()
				diff += _cmp(PeintureBati.avec_mips(r[0]).get_image(), PeintureBati.DOSSIER + tex + ".res"); n += 1
				if r[1] != null:
					diff += _cmp(PeintureBati.relief_mips(r[1]).get_image(), PeintureBati.DOSSIER + tex + "_relief.res"); n += 1
		"petites":
			var f := TexturesPetites.fabriques()
			for tex: String in f:
				var r: Array = (f[tex] as Callable).call()
				diff += _cmp(PeintureBati.avec_mips(r[0]).get_image(), TexturesPetites.DOSSIER + tex + ".res"); n += 1
				if r[1] != null:
					diff += _cmp(PeintureBati.relief_mips(r[1]).get_image(), TexturesPetites.DOSSIER + tex + "_relief.res"); n += 1
		_:
			print("[%s] pas de vérification en place" % nom)
			return 0
	print("[%s] %d fichiers comparés au calcul direct : %d différence(s) (%d ms)" % [nom, n, diff, Time.get_ticks_msec() - t])
	return diff

func _cmp(calcule: Image, chemin: String) -> int:
	var f = load(chemin)
	var img: Image = f.get_image() if f is Texture2D else f
	if img == null or img.get_data() != calcule.get_data() or img.get_format() != calcule.get_format() or img.has_mipmaps() != calcule.has_mipmaps():
		print("  DIFFÉRENT : ", chemin)
		return 1
	return 0
