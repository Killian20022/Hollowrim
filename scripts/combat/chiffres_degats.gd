class_name ChiffresDegats
## CHIFFRES DE DÉGÂTS FLOTTANTS (lot L6) : OPTION du joueur, DÉSACTIVÉE PAR DÉFAUT (esprit Skyrim) —
## Options > « Chiffres de dégâts » (Jeu.option("combat", "chiffres_degats"), sauvegardée dans options.cfg).
##   ChiffresDegats.ajouter(cible, point, valeur, sorte)     sorte : NORMAL, CRITIQUE, BLOQUE, ou une école de magie (couleur)
##   ChiffresDegats.dessiner(controle, camera, police)       appelé par le HUD (hud.gd) dans son _draw
## Aucune allocation par coup : un TAMPON CIRCULAIRE de N emplacements (tableaux compacts préalloués) ; le HUD les projette à
## l'écran et les dessine en police pixel (entiers, contour sombre), ils montent et s'effacent en DUREE s de temps RÉEL (l'arrêt
## sur image ne les fige pas). Les tics d'un sort canalisé (cumul) s'additionnent dans le chiffre récent de la même cible.

const N := 16
const DUREE := 0.95
const MONTEE := 22.0          # px (écran logique) parcourus en DUREE
const CUMUL_MS := 400          # un tic canalisé rejoint le chiffre de sa cible s'il a moins de CUMUL_MS ms
enum { NORMAL, CRITIQUE, BLOQUE, FEU, GLACE, ELECTRICITE, TENEBRES, SOIN }
## Couleurs (palette du HUD : parchemin, or, acier ; écoles : palettes de GestionMagie).
const COULEURS := [Color("#e8e0c8"), Color("#e8a64a"), Color("#8a96ad"), Color("#fcb53a"), Color("#a8d8f8"),
	Color("#b4c0ff"), Color("#d08aff"), Color("#f0d070")]
const ECOLES := {"feu": FEU, "glace": GLACE, "electricite": ELECTRICITE, "tenebres": TENEBRES, "soin": SOIN}
const FOND := Color("#0b0f1a")

## -1 = option du joueur ; 0 / 1 imposé (tests, captures).
static var force_actif := -1
static var _pos := PackedVector3Array()
static var _val := PackedFloat32Array()
static var _t0 := PackedInt64Array()
static var _sorte := PackedInt32Array()
static var _cible := PackedInt64Array()
static var _dx := PackedFloat32Array()
static var _suivant := 0
## Compteur d'ajouts (tests).
static var ajouts := 0
## Temps CPU passé dans ajouter() et dessiner() (µs, mesures).
static var cout_us := 0

static func actif() -> bool:
	if force_actif >= 0:
		return force_actif == 1
	return bool(Jeu.option("combat", "chiffres_degats"))

static func _init_tampon() -> void:
	if _pos.size() == N:
		return
	_pos.resize(N)
	_val.resize(N)
	_t0.resize(N)
	_t0.fill(-100000)
	_sorte.resize(N)
	_cible.resize(N)
	_dx.resize(N)

## Sorte d'un résultat de CalculDegats (critique, école de magie, sinon normal).
static func sorte_de(r: Dictionary) -> int:
	var i: Dictionary = r.get("info", {})
	if i.has("ecole"):
		return int(ECOLES.get(String(i["ecole"]), NORMAL))
	return CRITIQUE if bool(r.get("critique", false)) else NORMAL

static func ajouter(cible: Object, point: Vector3, valeur: float, sorte := NORMAL, cumul := false) -> void:
	if not actif():
		return
	_init_tampon()
	var id := cible.get_instance_id() if cible != null else 0
	var t := Time.get_ticks_msec()
	if cumul:
		for k in N:
			if _cible[k] == id and t - _t0[k] < CUMUL_MS and _sorte[k] == sorte:
				_val[k] += valeur
				_t0[k] = t
				_pos[k] = point
				return
	var i := _suivant
	_suivant = (_suivant + 1) % N
	_pos[i] = point
	_val[i] = valeur
	_t0[i] = t
	_sorte[i] = sorte
	_cible[i] = id
	_dx[i] = randf_range(-6.0, 6.0)
	ajouts += 1

## Chiffres encore visibles (tests).
static func visibles() -> int:
	_init_tampon()
	var t := Time.get_ticks_msec()
	var n := 0
	for k in N:
		if t - _t0[k] < int(DUREE * 1000.0):
			n += 1
	return n

static func vider() -> void:
	_init_tampon()
	_t0.fill(-100000)

## Dessin dans le _draw d'un Control d'interface (coordonnées locales du contrôle : écran logique d'EchelleUi).
static func dessiner(c: CanvasItem, cam: Camera3D, police: Font) -> void:
	if _pos.size() != N or cam == null or not cam.is_inside_tree():
		return
	var t_us := Time.get_ticks_usec()
	_dessiner(c, cam, police)
	cout_us += Time.get_ticks_usec() - t_us

static func _dessiner(c: CanvasItem, cam: Camera3D, police: Font) -> void:
	var t := Time.get_ticks_msec()
	var vers_local := c.get_global_transform_with_canvas().affine_inverse()
	for k in N:
		var age := float(t - _t0[k]) / 1000.0
		if age >= DUREE or age < 0.0:
			continue
		if cam.is_position_behind(_pos[k]):
			continue
		var p: Vector2 = vers_local * cam.unproject_position(_pos[k])
		var v := maxi(roundi(_val[k]), 0)
		var texte := "Bloqué" if _sorte[k] == BLOQUE and v == 0 else str(v)
		var crit := _sorte[k] == CRITIQUE
		# taille entière (police pixel nette) : normal x2, critique x3, « Bloqué » x1
		var taille := Palette.TAILLE_POLICE * (3 if crit else (1 if _sorte[k] == BLOQUE else 2))
		# petit « saut » au départ puis montée régulière ; effacement sur le dernier tiers (3 paliers, esprit pixel)
		var y := -MONTEE * age / DUREE - (3.0 if age < 0.08 else 0.0)
		var a := clampf((DUREE - age) / (DUREE * 0.35), 0.0, 1.0)
		a = ceilf(a * 3.0) / 3.0
		var l := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		var o := Vector2(roundf(p.x + _dx[k] - l * 0.5), roundf(p.y + y))
		var coul: Color = COULEURS[clampi(_sorte[k], 0, COULEURS.size() - 1)]
		c.draw_string_outline(police, o, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 4 if taille > Palette.TAILLE_POLICE else 2, Color(FOND, a))
		c.draw_string(police, o + Vector2(1, 1), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(FOND, a))
		c.draw_string(police, o, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(coul, a))
