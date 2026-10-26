class_name CachePersos
## Cache disque des CORPS d'archétypes de personnages (GuerrierNordique, GardienNordique, DraugrNordique, ChasseresseNordique) :
## la chirurgie de maillage d'un corps coûte 0,15 à 0,6 s sur le fil principal (accessoires, matières, fourrures…) et le chargement
## en bâtit une douzaine (PNJ du village, Gardiens de référence des gardes, draugrs du cercle) : ≈ 3 à 4 s. Le corps bâti est rangé
## une fois dans user://cache_persos/<worktree>/ (PackedScene binaire compressée, ~0,9 Mo) ; les lancements suivants le relisent
## (~40-60 ms) au lieu de le refaire (correctifs/chargement, 2026-10-26).
##
## SÛRETÉ (jamais de corps faux, au pire le calcul d'avant) :
## - Signature SHA-256 du code qui bâtit le corps : le script de l'archétype et TOUS les scripts qu'il nomme (fermeture des class_name
##   et des chemins res:// cités), les .gdshader cités (contenu), les autres fichiers cités (taille + date), les dossiers cités
##   par un chemin calculé (liste nom + taille + date), la version de Godot et VERSION ci-dessous (jeu exporté : + exécutable et .pck). Signature différente = cache ignoré,
##   corps rebâti puis réécrit. Clé du fichier = archétype + options (triées) + réglages statiques passés par l'archétype.
## - Pas de cache pour un corps qu'on ne sait pas restituer à l'identique : nœud scripté dont le script n'est pas un fichier ou dont
##   une variable tient un objet, connexion de signal, méta qui tient un objet autre qu'une ressource.
## - Restitué après lecture, comme au sortir de creer() : propriétaires des nœuds (find_children(owned) inchangé), groupes,
##   variables de script, scene_file_path (racine, pièces importées), paramètres des matières (état exact), bibliothèque
##   d'animations PARTAGÉE (Humain.bibliotheque(), clips propres de l'archétype rangés à part), matières réinscrites dans
##   Palette.materiaux (bascule PS1). Shaders bâtis par le code : fichiers à part cités par chemin, résolus vers les instances
##   vivantes (GuerrierNordique.shader…) : ni compilation ni pipelines en double.
## - Écriture : seulement sur le fil principal (sauvegarder une ImageTexture lit l'image du serveur de rendu : jamais dans un fil),
##   dans un fichier temporaire renommé ensuite (deux Godot du même worktree ne lisent jamais un fichier à moitié écrit).
##   Lecture : aussi dans les fils (gabarits d'EnnemisNordiques.prechauffer_fil) ; rien n'y touche à l'arbre de scène.
## `--sans-cache-persos` (argument utilisateur) : ni lecture ni écriture (mesures A/B, comparaisons).
## Outil : outils/verifier_cache_persos.gd (corps relu == corps bâti, maillage par maillage, matière par matière).

const VERSION := 2
static var actif := not OS.get_cmdline_user_args().has("--sans-cache-persos")
static var lus := 0          # mesures
static var ecrits := 0
static var refus := ""     # dernière raison de ne pas écrire un corps (mesures, outil de vérification)
static var _mx := Mutex.new()
static var _dossier := ""
static var _signatures := {}     # archétype -> signature
static var _classes := {}        # class_name -> chemin du script
static var _re_classes: RegEx = null   # \b(Classe1|Classe2|…)\b
static var _deps := {}           # chemin d'un script -> fichiers qu'il cite
static var _empreintes := {}     # chemin -> octets d'empreinte (mémo, plusieurs archétypes partagent des scripts)
static var _scenes := {}         # chemin du fichier -> PackedScene lue (plusieurs copies d'un même corps)
static var _bibs := {}           # description -> AnimationLibrary recomposée (partagée entre copies)
static var _shaders_amorces := false
static var _noms_uniformes := {}  # Shader -> noms de ses uniformes

## Corps relu du cache, ou null (absent, périmé, désactivé). `script_archetype` = chemin du script de l'archétype (signature),
## `reglages` = valeurs statiques qui changent le corps (ex. GuerrierNordique.reglage_bouclier), ajoutées à la clé.
static func lire(archetype: String, script_archetype: String, options: Dictionary, reglages := []) -> Node3D:
	if not actif:
		return null
	var chemin := _chemin(archetype, options, reglages)
	if chemin == "":
		return null
	var sig := _signature(archetype, script_archetype)
	_amorcer_shaders()
	_mx.lock()
	var ps: PackedScene = _scenes.get(chemin)
	_mx.unlock()
	if ps == null:
		if not FileAccess.file_exists(chemin):
			return null
		ps = ResourceLoader.load(chemin, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if ps == null:
			return null
		if String(ps.get_meta("signature", "")) != sig:
			return null
		_mx.lock()
		_scenes[chemin] = ps
		_mx.unlock()
	var n := ps.instantiate() as Node3D
	if n == null:
		return null
	_restituer(n)
	_mx.lock()
	lus += 1
	_mx.unlock()
	return n

## Range le corps `racine` (sortie de creer(), hors de l'arbre) ; il est rendu tel quel à l'appelant (rien de changé).
static func ecrire(archetype: String, script_archetype: String, options: Dictionary, racine: Node3D, reglages := []) -> void:
	if not actif or racine == null or not FilVerrou.fil_principal():
		return
	var chemin := _chemin(archetype, options, reglages)
	if chemin == "":
		return
	var noeuds: Array[Node] = [racine]
	noeuds.append_array(racine.find_children("*", "", true, false))
	_amorcer_shaders()
	var etat := _etat(racine, noeuds)
	if etat.is_empty() or not _ranger_shaders(noeuds):
		return
	# -- état d'origine, remis après l'empaquetage
	var proprios := {}
	var scenes := {}
	for c: Node in noeuds:
		proprios[c] = c.owner
		scenes[c] = c.scene_file_path
	var ap := racine.get_node_or_null("Animations") as AnimationPlayer
	var bib: AnimationLibrary = ap.get_animation_library("") if ap != null and ap.has_animation_library("") else null
	if bib != null:
		ap.remove_animation_library("")
	for c: Node in noeuds:
		if c != racine:
			c.owner = racine
		c.scene_file_path = ""
	racine.set_meta("_cp", etat)
	var ps := PackedScene.new()
	var err := ps.pack(racine)
	racine.remove_meta("_cp")
	for c: Node in noeuds:
		c.owner = proprios[c]
		c.scene_file_path = scenes[c]
	if bib != null:
		ap.add_animation_library("", bib)
	if err != OK:
		refus = "empaquetage : erreur %d" % err
		return
	ps.set_meta("signature", _signature(archetype, script_archetype))
	DirAccess.make_dir_recursive_absolute(_dossier_cache())
	var tmp := chemin.get_basename() + ".%d.tmp.scn" % OS.get_process_id()     # l'extension choisit le format : .scn = binaire
	var err_s := ResourceSaver.save(ps, tmp, ResourceSaver.FLAG_COMPRESS)
	_reposer(etat["params"])      # la sauvegarde a listé les propriétés des matières vivantes (voir _etat)
	if err_s != OK:
		refus = "écriture %s : erreur %d" % [tmp, err_s]
		return
	if DirAccess.rename_absolute(tmp, chemin) != OK:
		refus = "renommage de %s" % tmp
		DirAccess.remove_absolute(tmp)
		return
	_mx.lock()
	ecrits += 1
	_mx.unlock()

# ------------------------------------------------------------------------------------------------------------------- interne
## Un dossier par worktree, et un à part sans fenêtre : les textures peintes d'après les images importées ne sortent pas
## identiques du serveur de rendu factice (--headless : tests) et du vrai (peau, mesuré par outils/verifier_cache_persos.gd).
static func _dossier_cache() -> String:
	if _dossier == "":
		_dossier = "user://cache_persos/%s%s/" % [ProjectSettings.globalize_path("res://").md5_text().substr(0, 10),
			"_headless" if DisplayServer.get_name() == "headless" else ""]
	return _dossier

static func _chemin(archetype: String, options: Dictionary, reglages: Array) -> String:
	var cles := options.keys()
	cles.sort()
	var l: Array = [archetype, VERSION, reglages]
	for k: Variant in cles:
		l.append([k, options[k]])
	var txt := var_to_str(l)
	if txt.contains("Object(") or txt.contains("<"):
		return ""      # option qui tient un objet : pas de clé stable
	return _dossier_cache() + "%s_%s.scn" % [archetype, txt.md5_text().substr(0, 16)]

## Ce qu'il faut restituer après lecture (rangé en méta de la racine), ou {} si le corps n'est pas restituable à l'identique.
static func _etat(racine: Node3D, noeuds: Array[Node]) -> Dictionary:
	var proprios := {}
	var groupes := {}
	var vars := {}
	var scenes := {}
	for c: Node in noeuds:
		var ch := String(racine.get_path_to(c))
		proprios[ch] = String(racine.get_path_to(c.owner)) if c.owner != null else ""
		if c.scene_file_path != "":
			scenes[ch] = c.scene_file_path
		var g: Array = []
		for nom: StringName in c.get_groups():
			if not String(nom).begins_with("_"):
				g.append(nom)
		if not g.is_empty():
			groupes[ch] = g
		for s: Dictionary in c.get_signal_list():
			if not c.get_signal_connection_list(s["name"]).is_empty():
				refus = "%s : signal %s connecté" % [ch, s["name"]]
				return {}
		for m: StringName in c.get_meta_list():
			if not _serialisable(c.get_meta(m)):
				refus = "%s : méta %s" % [ch, m]
				return {}
		var scr := c.get_script() as Script
		if scr != null:
			if scr.resource_path == "" or scr.resource_path.contains("::"):
				refus = "%s : script sans fichier" % ch
				return {}
			var d := {}
			for p: Dictionary in c.get_property_list():
				if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
					var v: Variant = c.get(p["name"])
					if not _serialisable(v):
						refus = "%s : variable %s" % [ch, p["name"]]
						return {}
					d[p["name"]] = v
			vars[ch] = d
	var ap := racine.get_node_or_null("Animations") as AnimationPlayer
	var anims := {}
	var bib_humain := false
	if ap != null:
		if ap.get_animation_library_list().size() > 1:
			refus = "plusieurs bibliothèques d'animations"
			return {}
		if ap.has_animation_library(""):
			var bib := ap.get_animation_library("")
			var h: AnimationLibrary = Humain._bibliotheque
			bib_humain = bib == h
			if not bib_humain:
				for nom: StringName in bib.get_animation_list():
					var a := bib.get_animation(nom)
					if h != null and h.has_animation(nom) and h.get_animation(nom) == a:
						anims[nom] = ""          # clip partagé de Humain.bibliotheque()
					else:
						anims[nom] = a
	# matières inscrites dans Palette.materiaux (bascule PS1) : marquées pour être réinscrites
	var palette := {}
	for m: ShaderMaterial in Palette.materiaux:
		palette[m] = true
	var mats: Array = []
	var params: Array = []     # [matière, {nom: valeur}] : réappliqués après lecture (un vec3 « source_color » posé en Vector3 ne se relit pas)
	var vues := {}
	for c: Node in noeuds:
		for m: Material in _matieres(c):
			if vues.has(m):
				continue
			vues[m] = true
			if palette.has(m):
				mats.append(m)
			var sm := m as ShaderMaterial
			if sm != null and sm.shader != null:
				# état exact des paramètres (ceux qui sont posés, avec leur type) : ShaderMaterial EFFACE ceux posés avec un autre type que
				# l'uniforme (vec3 « source_color » posé en Vector3, sans conversion sRGB) dès qu'on liste ses propriétés (sauvegarde,
				# duplicate), et avec un vrai rendu y inscrit les valeurs par défaut des autres : on remet l'état d'avant après coup
				var d := {}
				for u: Dictionary in sm.shader.get_shader_uniform_list():
					var v: Variant = sm.get_shader_parameter(u["name"])
					if v != null and _serialisable(v):
						d[u["name"]] = v
				params.append([sm, d])
	return {"proprios": proprios, "groupes": groupes, "vars": vars, "scenes": scenes, "bib_humain": bib_humain,
		"anims": anims, "palette": mats, "params": params}

static func _serialisable(v: Variant) -> bool:
	match typeof(v):
		TYPE_OBJECT:
			return v == null or v is Resource
		TYPE_ARRAY:
			for x: Variant in v:
				if not _serialisable(x):
					return false
		TYPE_DICTIONARY:
			for k: Variant in v:
				if not _serialisable(k) or not _serialisable(v[k]):
					return false
	return true

## Matières d'un nœud (surcharges, surcharge globale, matières des surfaces, passes suivantes).
static func _matieres(c: Node) -> Array[Material]:
	var l: Array[Material] = []
	var mi := c as MeshInstance3D
	if mi == null:
		return l
	var brutes: Array = [mi.material_override, mi.material_overlay]
	if mi.mesh != null:
		for s in mi.mesh.get_surface_count():
			brutes.append(mi.get_surface_override_material(s))
			brutes.append(mi.mesh.surface_get_material(s))
	for m: Variant in brutes:
		var x := m as Material
		while x != null and not l.has(x):
			l.append(x)
			x = x.next_pass
	return l

static func _restituer(n: Node3D) -> void:
	var etat: Dictionary = n.get_meta("_cp", {})
	n.remove_meta("_cp")
	var proprios: Dictionary = etat.get("proprios", {})
	for ch: String in proprios:
		var c := n.get_node_or_null(ch)
		if c != null and c != n:
			var p := String(proprios[ch])
			c.owner = n.get_node_or_null(p) if p != "" else null
	var groupes: Dictionary = etat.get("groupes", {})
	for ch: String in groupes:
		var c := n.get_node_or_null(ch)
		if c != null:
			for g: StringName in groupes[ch]:
				c.add_to_group(g)
	var vars: Dictionary = etat.get("vars", {})
	for ch: String in vars:
		var c := n.get_node_or_null(ch)
		if c != null:
			var d: Dictionary = vars[ch]
			for k: StringName in d:
				c.set(k, d[k])
	var scenes: Dictionary = etat.get("scenes", {})
	for ch: String in scenes:
		var c := n.get_node_or_null(ch)
		if c != null:
			c.scene_file_path = scenes[ch]
	var ap := n.get_node_or_null("Animations") as AnimationPlayer
	if ap != null:
		if bool(etat.get("bib_humain", false)):
			ap.add_animation_library("", Humain.bibliotheque())
		elif not (etat.get("anims", {}) as Dictionary).is_empty():
			ap.add_animation_library("", _bibliotheque(etat["anims"]))
	_mx.lock()
	for m: Variant in etat.get("palette", []):
		if m is ShaderMaterial:
			Palette.materiaux.append(m)
	_mx.unlock()
	_reposer(etat.get("params", []))

static func _reposer(params: Array) -> void:
	for e: Array in params:
		var sm := e[0] as ShaderMaterial
		if sm == null or sm.shader == null:
			continue
		var d: Dictionary = e[1]
		for k: StringName in _uniformes(sm.shader):
			var v: Variant = sm.get_shader_parameter(k)
			if d.has(k):
				if typeof(v) != typeof(d[k]) or v != d[k]:
					sm.set_shader_parameter(k, d[k])
			elif v != null:
				sm.set_shader_parameter(k, null)

## Noms des uniformes d'un shader (la liste vient du serveur de rendu : appel coûteux, une fois par shader).
static func _uniformes(sh: Shader) -> Array:
	_mx.lock()
	var l: Variant = _noms_uniformes.get(sh)
	_mx.unlock()
	if l == null:
		var noms: Array = []
		for u: Dictionary in sh.get_shader_uniform_list():
			noms.append(StringName(u["name"]))
		l = noms
		_mx.lock()
		_noms_uniformes[sh] = noms
		_mx.unlock()
	return l

## Bibliothèque recomposée : clips de Humain.bibliotheque() + clips propres de l'archétype ; une seule instance par description.
static func _bibliotheque(anims: Dictionary) -> AnimationLibrary:
	var h := Humain.bibliotheque()
	var desc := ""
	for nom: StringName in anims:
		var a: Variant = anims[nom]
		desc += "%s=%s;" % [nom, "" if a is String else (a as Animation).get_instance_id()]
	_mx.lock()
	var bib: AnimationLibrary = _bibs.get(desc)
	if bib == null:
		bib = AnimationLibrary.new()
		for nom: StringName in anims:
			var a: Variant = anims[nom]
			bib.add_animation(nom, h.get_animation(nom) if a is String else a)
		_bibs[desc] = bib
	_mx.unlock()
	return bib

## Shaders bâtis par le code (GuerrierNordique.shader(true)…) : rangés à part, un fichier par code (shaders/<md5>.res), et le
## corps rangé les cite par CHEMIN. Les instances vivantes reçoivent ce chemin (amorcer) : à la lecture, ResourceLoader rend
## l'instance déjà en mémoire au lieu d'un shader neuf par corps (un shader neuf = une compilation, ~0,1 s avec un vrai rendu).
static func _chemin_shader(sh: Shader) -> String:
	return _dossier_cache() + "shaders/%s.res" % sh.code.md5_text()

static func _amorcer_shaders() -> void:
	_mx.lock()
	if not _shaders_amorces:
		_shaders_amorces = true
		for sh: Shader in [GuerrierNordique.shader(true), GuerrierNordique.shader(false), DraugrNordique.shader(true), DraugrNordique.shader(false),
				Humain.shader_perso(true), Humain.shader_perso(false), Palette.shader_double_face()]:
			if sh.resource_path == "":
				var p := _chemin_shader(sh)
				if not ResourceLoader.has_cached(p):
					sh.resource_path = p
	_mx.unlock()

## Avant l'empaquetage : chaque shader sans fichier du corps est écrit (s'il manque) et prend son chemin. Faux si impossible.
static func _ranger_shaders(noeuds: Array[Node]) -> bool:
	for c: Node in noeuds:
		for m: Material in _matieres(c):
			var sm := m as ShaderMaterial
			if sm == null or sm.shader == null:
				continue
			var p := _chemin_shader(sm.shader)
			if sm.shader.resource_path != "" and sm.shader.resource_path != p:
				continue      # shader d'un fichier du projet : cité tel quel
			# (un shader amorcé a déjà son chemin mais pas forcément son fichier : il est écrit ici)
			if not FileAccess.file_exists(p):
				DirAccess.make_dir_recursive_absolute(p.get_base_dir())
				if ResourceSaver.save(sm.shader, p) != OK:
					refus = "écriture du shader %s" % p
					return false
			sm.shader.take_over_path(p)
	return true

## Signature du code qui bâtit l'archétype (calculée une fois par lancement).
static func _signature(archetype: String, script_archetype: String) -> String:
	_mx.lock()
	var sig: String = _signatures.get(archetype, "")
	if sig == "":
		if _classes.is_empty():
			for d: Dictionary in ProjectSettings.get_global_class_list():
				_classes[String(d["class"])] = String(d["path"])
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(var_to_bytes([VERSION, Engine.get_version_info()["string"], archetype]))
		# fermeture : chaque script trouvé est relu pour y chercher d'autres noms de classes et chemins (dépendances mémorisées par
		# fichier : les archétypes partagent la plupart de leurs scripts)
		var vus := {}
		var a_voir: Array = [script_archetype]
		while not a_voir.is_empty():
			var ch: String = a_voir.pop_back()
			if vus.has(ch):
				continue
			vus[ch] = true
			for p: String in _dependances(ch):
				if not vus.has(p):
					a_voir.append(p)
		if not OS.has_feature("editor"):
			# jeu exporté : les scripts sont en jetons binaires (pas relus ci-dessus) ; l'exécutable et son paquet changent à chaque version
			var exe := OS.get_executable_path()
			for f: String in [exe, exe.get_basename() + ".pck"]:
				if FileAccess.file_exists(f):
					ctx.update(var_to_bytes([f.get_file(), FileAccess.get_size(f), FileAccess.get_modified_time(f)]))
		var ordre := vus.keys()
		ordre.sort()
		for ch: String in ordre:
			ctx.update(ch.to_utf8_buffer())
			var e := _empreinte(ch)
			if not e.is_empty():
				ctx.update(e)
		sig = ctx.finish().hex_encode()
		_signatures[archetype] = sig
	_mx.unlock()
	return sig

## Classes nommées et chemins res:// cités par un script (recherche de texte : un faux positif ajoute seulement un fichier à la signature).
static func _dependances(ch: String) -> Array:
	if _deps.has(ch):
		return _deps[ch]
	var l: Array = []
	# cache_persos.gd lui-même : compté (contenu) mais pas suivi (il nomme tous les archétypes)
	if ch.ends_with(".gd") and FileAccess.file_exists(ch) and ch != (CachePersos as Script).resource_path:
		var src := _sans_commentaires(FileAccess.get_file_as_string(ch))
		if _re_classes == null:
			_re_classes = RegEx.create_from_string("\\b(%s)\\b" % "|".join(PackedStringArray(_classes.keys())))
		for m: RegExMatch in _re_classes.search_all(src):
			var p: String = _classes[m.get_string()]
			if not l.has(p):
				l.append(p)
		var i := src.find("res://")
		while i >= 0:
			var j := i + 6
			while j < src.length() and not (src[j] in ["\"", "'", "%", "\n"]):
				j += 1
			l.append(src.substr(i, j - i))
			i = src.find("res://", j)
	_deps[ch] = l
	return l

## Source sans ses commentaires (« # » en début de ligne ou après un blanc, suivi d'un blanc ou d'un autre « # » ; les couleurs
## "#1c150e" restent) : les commentaires citent beaucoup d'autres scripts, qui n'entrent pas dans la construction.
static func _sans_commentaires(src: String) -> String:
	var lignes := src.split("\n")
	for i in lignes.size():
		var l := lignes[i]
		var k := l.find("#")
		while k >= 0:
			var avant := l.unicode_at(k - 1) if k > 0 else 32
			var apres := l.unicode_at(k + 1) if k + 1 < l.length() else 32
			if (avant == 32 or avant == 9) and (apres == 32 or apres == 35 or apres == 9):
				lignes[i] = l.substr(0, k)
				break
			k = l.find("#", k + 1)
	return "\n".join(lignes)

## Empreinte d'un fichier cité : contenu (scripts, shaders, petits fichiers), sinon taille + date ; dossier : liste nom + taille.
static func _empreinte(ch: String) -> PackedByteArray:
	if _empreintes.has(ch):
		return _empreintes[ch]
	var b := PackedByteArray()
	var p := ch
	if p.ends_with(".gd") and not FileAccess.file_exists(p) and FileAccess.file_exists(p + "c"):
		p += "c"      # jeu exporté : script en jetons binaires
	if FileAccess.file_exists(p):
		var ext := p.get_extension()
		if ext in ["gd", "gdc", "gdshader", "gdshaderinc", "json", "tres", "cfg"]:
			b = FileAccess.get_file_as_bytes(p)
		else:
			b = var_to_bytes([FileAccess.get_size(p), FileAccess.get_modified_time(p)])
			var imp := p + ".import"
			if FileAccess.file_exists(imp):
				b.append_array(FileAccess.get_file_as_bytes(imp))
	else:
		var dossier := p if DirAccess.dir_exists_absolute(p) else p.get_base_dir()
		if DirAccess.dir_exists_absolute(dossier):
			var l: Array = []
			for f in DirAccess.get_files_at(dossier):
				l.append([f, FileAccess.get_size(dossier.path_join(f)), FileAccess.get_modified_time(dossier.path_join(f))])
			b = var_to_bytes(l)
	_empreintes[ch] = b
	return b
