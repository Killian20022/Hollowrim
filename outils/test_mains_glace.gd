extends SceneTree
## Test des MAINS après les sorts (bugs/mains_glace, 2026-11-26) : « après le sort de glace, mes mains sont devenues ultra
## brillantes, blanches, et ça a suivi sur tous les autres sorts ». Avec rendu (fenêtre hors écran, pas --headless) :
##   godot --fixed-fps 60 --path . --script res://outils/test_mains_glace.gd -- --nouvelle [--planche <dossier>]
## Mesure, pour les bras 1re personne (calque AvantBras.CALQUE seul, effets de sort exclus) et les mains du corps 3e personne :
##   - l'empreinte des matières (matière active de chaque surface + valeurs de ses uniformes) ;
##   - la luminance moyenne rendue des mains (1P) ;
## avant tout sort, pendant la glace, puis après feu / foudre / rayon noir / mains nues / épée : matières identiques à
## l'avant et luminance à ±2 % de l'avant à équipement égal.

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0

var _ok := true
var _n := 0
var s: Node3D
var mains: Node3D
var magie: MainSort
var planche := ""
var _num := 0

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var i := a.find("--planche")
	if i >= 0 and i + 1 < a.size():
		planche = a[i + 1]
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _images(n: int) -> void:
	for i in n:
		s.joueur.mana = s.joueur.mana_max
		mains.avancer(DT)
		await process_frame

## Toutes les MeshInstance3D visibles des bras 1P (et de l'objet porté si `tout`).
func _mailles(racine: Node) -> Array:
	var r := []
	if racine == null:
		return r
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null and mi.mesh != null:
			r.append(mi)
	return r

## Empreinte des matières : pour chaque surface, la matière active, son shader (sans le fondu) et les valeurs de ses uniformes.
func _empreinte(racine: Node) -> Dictionary:
	var e := {}
	for mi: MeshInstance3D in _mailles(racine):
		e["%s/overlay" % racine.get_path_to(mi)] = str(mi.material_overlay.resource_name if mi.material_overlay else "") + ":" + (str((mi.material_overlay as ShaderMaterial).shader.resource_path) if mi.material_overlay is ShaderMaterial and (mi.material_overlay as ShaderMaterial).shader else str(mi.material_overlay != null))
		e["%s/override" % racine.get_path_to(mi)] = str(mi.material_override != null)
		for k in mi.mesh.get_surface_count():
			var m := mi.get_active_material(k)
			var cle := "%s/%d" % [racine.get_path_to(mi), k]
			if m is ShaderMaterial:
				var sm := m as ShaderMaterial
				var vals := {}
				if sm.shader != null:
					for u: Dictionary in sm.shader.get_shader_uniform_list():
						var nom := String(u["name"])
						vals[nom] = str(sm.get_shader_parameter(nom))
				e[cle] = vals
			else:
				e[cle] = str(m)
	return e

func _ecarts(a: Dictionary, b: Dictionary) -> Array:
	var r := []
	for k in a:
		if not b.has(k):
			r.append("%s absente" % k)
			continue
		if a[k] is Dictionary and b[k] is Dictionary:
			for u in a[k]:
				if (b[k] as Dictionary).get(u, "?") != a[k][u]:
					r.append("%s.%s : %s -> %s" % [k, u, a[k][u], (b[k] as Dictionary).get(u, "?")])
		elif str(a[k]) != str(b[k]):
			r.append("%s : %s -> %s" % [k, a[k], b[k]])
	return r

## Lumières qui touchent le calque des bras.
func _lumieres() -> Array:
	var r := []
	for l: Light3D in root.find_children("*", "Light3D", true, false):
		if l.is_visible_in_tree() and l.light_energy > 0.001 and (l.light_cull_mask & AvantBras.CALQUE) != 0 and not (l is DirectionalLight3D) and String(l.get_path()).contains("Runes_"):
			r.append("%s e=%.2f" % [l.get_path(), l.light_energy])
	return r

## Rendu des bras seuls : image avec le calque des bras moins image sans aucun calque (mêmes réglages, même image) ;
## rend [luminance moyenne des pixels des bras, nombre de pixels].
func _rendu() -> Array:
	# mesures loin de la cible (ses lumières d'impact éclairent aussi les mains : sans rapport avec elles)
	var pos: Vector3 = s.joueur.global_position
	s.joueur.global_position = pos + Vector3(0, 0, 60)
	var bras: Node3D = mains.bras
	var arme: Node3D = mains.get("_modele_arme_d") as Node3D if is_instance_valid(mains.get("_modele_arme_d")) else null
	bras.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var vide := root.get_viewport().get_texture().get_image()
	bras.visible = true
	if arme != null:
		arme.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var nu := root.get_viewport().get_texture().get_image()
	if arme != null:
		arme.visible = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	s.joueur.global_position = pos
	if planche != "":
		DirAccess.make_dir_recursive_absolute(planche)
		img.save_png(planche.path_join("bras_%02d.png" % _num))
		_num += 1
	# pixels des mains / bras (sans l'arme), lus sur l'image complète : une couche de l'arme qui traverse le poing compte
	var somme := 0.0
	var nb := 0
	var W := img.get_width()
	var H := img.get_height()
	for y in range(0, int(H * 0.9), 2):
		for x in range(0, W, 2):
			var c := nu.get_pixel(x, y)
			var f := vide.get_pixel(x, y)
			if absf(c.r - f.r) + absf(c.g - f.g) + absf(c.b - f.b) > 0.03:
				var ci := img.get_pixel(x, y)
				somme += 0.2126 * ci.r + 0.7152 * ci.g + 0.0722 * ci.b
				nb += 1
	return [somme / maxf(nb, 1), nb]

## Capture vue joueur complète (pour la planche).
func _capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()

func _equiper(g: String, d: String) -> void:
	magie.equiper("droite", d)
	magie.equiper("gauche", g)
	await _images(30)

## Tient le sort de la main gauche (appui long) puis relâche ; rend la mesure pendant la tenue.
func _lancer(sort: String, droite := "epee") -> Array:
	await _equiper(sort, droite)
	magie.appuyer("gauche")
	await _images(50)
	var pendant: Array = await _rendu()
	var vue: Image = await _capture()
	magie.relacher("gauche")
	await _images(70)
	return [pendant, vue]

func _tester() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	mains = s.joueur.mains
	magie = mains.magie
	magie.eq.apprendre_tout()
	mains.pas_manuel = true
	for i in 20:
		await physics_frame
	var bras: Node = mains.bras
	var corps: Node = s.joueur.corps
	# avant tout sort : mains nues (gauche vide) + épée à droite
	await _equiper("vide", "epee")
	await _images(30)
	var m0 := _empreinte(bras)
	var c0 := _empreinte(corps)
	var r0: Array = await _rendu()
	var v0: Image = await _capture()
	await _equiper("vide", "vide")
	var r0n: Array = await _rendu()
	print("AVANT  épée : lum %.4f (%d px)  mains nues : lum %.4f (%d px) ; lumières sur les bras : %s" % [r0[0], r0[1], r0n[0], r0n[1], _lumieres()])
	# glace
	var g: Array = await _lancer("eclat_glace")
	print("GLACE  pendant : lum %.4f (%d px) ; lumières %s" % [g[0][0], g[0][1], _lumieres()])
	var vg: Image = g[1]
	var e_g := _ecarts(m0, _empreinte(bras))
	print("GLACE  après relâche, matières changées : %d %s" % [e_g.size(), e_g.slice(0, 6)])
	var vf: Image = null
	for sort in ["boule_feu", "chaine_eclairs", "rayon_noir"]:
		var r: Array = await _lancer(sort)
		if sort == "boule_feu":
			vf = r[1]
		var e := _ecarts(m0, _empreinte(bras))
		_verif(e.is_empty(), "après %s : matières des bras 1P identiques à l'avant (%d écarts %s)" % [sort, e.size(), e.slice(0, 4)])
	# mains nues puis épée
	await _equiper("vide", "vide")
	await _images(30)
	var rn: Array = await _rendu()
	var en := _ecarts(m0, _empreinte(bras))
	_verif(en.is_empty(), "mains nues : matières 1P identiques (%d écarts %s)" % [en.size(), en.slice(0, 4)])
	_verif(absf(rn[0] - r0n[0]) <= 0.02 * r0n[0], "mains nues : luminance %.4f vs avant %.4f (%+.1f %%, tolérance ±2 %%)" % [rn[0], r0n[0], 100.0 * (rn[0] / r0n[0] - 1.0)])
	await _equiper("vide", "epee")
	await _images(30)
	var re: Array = await _rendu()
	var v1: Image = await _capture()
	var ee := _ecarts(m0, _empreinte(bras))
	_verif(ee.is_empty(), "épée : matières 1P identiques (%d écarts %s)" % [ee.size(), ee.slice(0, 4)])
	_verif(absf(re[0] - r0[0]) <= 0.02 * r0[0], "épée : luminance %.4f vs avant %.4f (%+.1f %%, tolérance ±2 %%)" % [re[0], r0[0], 100.0 * (re[0] / r0[0] - 1.0)])
	_verif(_lumieres().is_empty(), "épée : plus aucune lueur de sort tenue sur les bras (%s)" % [_lumieres()])
	var ec := _ecarts(c0, _empreinte(corps))
	_verif(ec.is_empty(), "corps 3e personne : matières identiques à l'avant (%d écarts %s)" % [ec.size(), ec.slice(0, 4)])
	# autres sorts de glace (lance, souffle, nova, enchantement), puis retour à l'épée
	var ve: Image = null
	for sort in ["lance_givre", "souffle_givre", "nova_gelee", "enchant_glace"]:
		var rg: Array = await _lancer(sort)
		await _equiper("vide", "epee")
		await _images(30)
		if sort == "enchant_glace":
			var rp: Array = await _rendu()
			ve = await _capture()
			print("ENCHANT glace actif (lame enchantée, sa lumière éclaire la main) : lum %.4f vs %.4f (%+.1f %%)" % [rp[0], r0[0], 100.0 * (rp[0] / r0[0] - 1.0)])
			magie.enchantement["reste"] = 0.01   # fin de l'enchantement (30 s) : les mains doivent revenir à l'avant
			await _images(40)
		var rr: Array = await _rendu()
		var eg := _ecarts(m0, _empreinte(bras))
		_verif(eg.is_empty() and absf(rr[0] - r0[0]) <= 0.02 * r0[0], "après %s (pendant lum %.4f) puis épée : %d écarts de matière, luminance %.4f vs %.4f (%+.1f %%)" % [sort, rg[0][0], eg.size(), rr[0], r0[0], 100.0 * (rr[0] / r0[0] - 1.0)])
	# 3e personne : glace puis épée, matières du corps
	s.joueur.basculer_vue(true)
	await _images(10)
	await _lancer("eclat_glace")
	await _lancer("boule_feu")
	await _equiper("vide", "epee")
	var ec3 := _ecarts(c0, _empreinte(corps))
	_verif(ec3.is_empty(), "3e personne après glace + feu : matières du corps identiques (%d écarts %s)" % [ec3.size(), ec3.slice(0, 4)])
	s.joueur.basculer_vue(false)
	await _images(10)
	var e1p := _ecarts(m0, _empreinte(bras))
	_verif(e1p.is_empty(), "retour 1re personne : matières 1P identiques (%d écarts %s)" % [e1p.size(), e1p.slice(0, 4)])
	if planche != "":
		DirAccess.make_dir_recursive_absolute(planche)
		var imgs := [v0, vg, vf, ve if ve != null else v1]
		var w := 480
		var h := int(w * v0.get_height() / float(v0.get_width()))
		var p := Image.create(w * 4 + 30, h + 10, false, Image.FORMAT_RGB8)
		p.fill(Color(0.08, 0.08, 0.08))
		for k in 4:
			var im: Image = imgs[k].duplicate()
			im.convert(Image.FORMAT_RGB8)
			im.resize(w, h, Image.INTERPOLATE_NEAREST)
			p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i(5 + k * (w + 7), 5))
		p.save_png(planche.path_join("planche.png"))
		print("planche : ", planche.path_join("planche.png"))
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)
