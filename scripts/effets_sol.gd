class_name EffetsSol
extends Node
## MONDE RÉACTIF SUR LA NEIGE (rendu PS1 : gros texels, jamais de réalisme graphique) :
##   - traces de pas (joueur, ennemis, villageois) qui s'effacent texel par texel, gerbes de neige aux pas, à la course, au saut
##     et à l'atterrissage ;
##   - neige FONDUE par le feu (terre sombre ou mouillée, vapeur) qui se reforme en 30 à 60 s ; un jet continu creuse une traînée ;
##   - blocs et pics de glace en volume (GlaceFondante) à l'impact des sorts de glace, qui fondent (gouttes, flaque qui sèche),
##     plus vite près du feu ;
##   - brûlures et étincelles (électricité), taches d'ombre qui se résorbent (ténèbres).
## MÉCANISME : un masque monde de N×N texels de 1/16 m (même grille que la neige du terrain), TORIQUE, centré sur le joueur et
## lu par shaders/ps1.gdshader (terrain seulement). Chaque texel garde l'INSTANT DE FIN de chaque effet (RGBAF) : le GPU calcule
## seul l'effacement, aucun parcours par image côté CPU. Le masque n'est envoyé qu'après une écriture (≤ 20 /s), et
## `effets_rect.w` = 0 (le shader ne lit rien) tant que rien n'est vivant. Voir docs/EFFETS_SOL.md.
## Appels : EffetsSol.pas / saut / atterrissage (joueur.gd), EffetsSol.sort_* (EffetsMagie : tous les sorts passent par là).

const N := 320                       # texels par côté (20 m)
const RES := 16.0                    # texels par mètre
const DUREE_PAS := 24.0              # s : mêmes constantes que shaders/ps1.gdshader (effets_sol)
const DUREE_BRULURE := 26.0
const DUREE_OMBRE := 18.0
const FONTE_MIN := 30.0              # s : la neige fondue se reforme en 30 à 60 s
const FONTE_MAX := 60.0
const MAX_BLOCS := 10                # amas de glace vivants (le plus ancien est écrasé)
const PORTEE_MARCHEURS := 14.0       # m : ennemis et villageois qui laissent des traces
const FOULEE := 0.9                  # m entre deux empreintes d'un marcheur
const MAX_MARCHEURS := 8
# relief de la neige (couche déformable, CoucheNeige) : profondeurs en m, durées en s (mêmes constantes que le shader : fondu sur 10 s)
const DUREE_RELIEF := 26.0
const CREUX_MARCHE := 0.085          # empreinte de botte à la marche
const CREUX_COURSE := 0.12           # sillon à la course
const BOURRELET := 0.04              # neige repoussée sur le pourtour (m de hauteur)
const BOURRELET_FEU := 0.045         # lèvre épaisse autour du trou de la neige fondue

## Faux = aucun effet (mesures de coût). `forcer_neige` : tout le sol compte comme neige (tests sans carte de sol).
static var actif := true
static var forcer_neige := false
static var instance: EffetsSol
## Compteurs (tests, mesures) : écritures de texels, envois du masque, empreintes, fontes, blocs.
static var stats := {"texels": 0, "envois": 0, "pas": 0, "fontes": 0, "blocs": 0}

var t := 10.0                        # horloge du masque (s) ; le shader reçoit la même (effets_temps)
var _donnees := PackedFloat32Array()
var _img: Image
var _tex: ImageTexture
var _rdonnees := PackedFloat32Array()   # relief : N×N × (amplitude, fin) ; amplitude > 0 creux, < 0 bourrelet
var _rimg: Image
var _rtex: ImageTexture
var _relief_fin := 0.0                  # instant après lequel plus aucun relief n'est vivant
var _couche: CoucheNeige
var _acc_couche := 99.0
var _prec_pied := {}                    # pied (bool) -> {pos: Vector2, t: float} : dernier sillon de course
var _ox := 0                         # coin (texels monde) de la fenêtre
var _oz := 0
var _fin_vie := 0.0                  # instant après lequel tout est effacé
var _sale := false
var _dernier_envoi := -1.0
var _rect_actif := false
var _blocs: Array = []
var _joueur: Node3D
var _marcheurs := {}                 # id -> {pos: Vector3, reste: float, pied: bool}
var _acc := 0.0
var _eaux: Array = []                # nœuds Eau (groupe « eaux »), relus toutes les 2 s
var _acc_eaux := 99.0
var _jets := {}                      # id de la main -> {fin: Vector3, t: float, vapeur: float}
var _rng := RandomNumberGenerator.new()

# ------------------------------------------------------------------ cycle de vie

static func obtenir() -> EffetsSol:
	if instance != null and is_instance_valid(instance) and not instance.is_queued_for_deletion():
		return instance
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre == null:
		return null
	var e := EffetsSol.new()
	e.name = "EffetsSol"
	instance = e
	var s: Node = arbre.current_scene if arbre.current_scene != null else arbre.root
	if s.is_node_ready():
		s.add_child(e)
	else:
		s.add_child.call_deferred(e)
	return e

func _ready() -> void:
	_rng.seed = 4242
	_donnees.resize(N * N * 4)
	_img = Image.create_from_data(N, N, false, Image.FORMAT_RGBAF, _donnees.to_byte_array())
	_tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set("effets_masque", _tex)
	_rdonnees.resize(N * N * 2)
	_rimg = Image.create_from_data(N, N, false, Image.FORMAT_RGF, _rdonnees.to_byte_array())
	_rtex = ImageTexture.create_from_image(_rimg)
	RenderingServer.global_shader_parameter_set("relief_masque", _rtex)
	RenderingServer.global_shader_parameter_set("relief_zone", Vector4(0, 0, 0, 0))
	_regler_rect(false)
	_centrer(Vector2.ZERO)

func _exit_tree() -> void:
	if instance == self:
		instance = null
		RenderingServer.global_shader_parameter_set("effets_rect", Vector4(0, 0, 0, 0))
		RenderingServer.global_shader_parameter_set("relief_zone", Vector4(0, 0, 0, 0))

func _process(dt: float) -> void:
	t += dt
	_acc += dt
	_acc_eaux += dt
	if _acc_eaux >= 2.0:
		_acc_eaux = 0.0
		_eaux = get_tree().get_nodes_in_group("eaux")
	if _acc >= 0.1:
		_acc = 0.0
		_sonder_marcheurs()
	_gerer_couche(dt)
	if _fin_vie > t:
		if not _rect_actif:
			_regler_rect(true)
		RenderingServer.global_shader_parameter_set("effets_temps", t)
		if _sale and t - _dernier_envoi >= 0.05:
			_envoyer()
	elif _rect_actif:
		_regler_rect(false)   # tout est effacé : le shader ne lit plus rien

## Couche de neige en relief : créée dès que le monde existe, visible (et la zone envoyée aux shaders) seulement tant qu'un relief vit.
func _gerer_couche(dt: float) -> void:
	if _couche == null or not is_instance_valid(_couche):
		_acc_couche += dt
		if _acc_couche >= 1.0:
			_acc_couche = 0.0
			var cands: Array = [get_tree().current_scene] + get_tree().root.get_children()
			for c in cands:
				if c != null and c.get("mat_terrain") != null and c.get("hauteurs_maillage") != null:
					_couche = CoucheNeige.creer(c)
					if _couche != null:
						break
		return
	if not _couche.is_inside_tree():
		return
	var actif_r := actif and _relief_fin > t and _joueur != null and is_instance_valid(_joueur) and neige_dehors()
	if actif_r:
		var pj := Vector2(_joueur.global_position.x, _joueur.global_position.z)
		var p := _couche.placer(pj)
		_couche.visible = true
		RenderingServer.global_shader_parameter_set("relief_zone", Vector4(p.x, p.y, CoucheNeige.COTE / RES, 1.0))
	elif _couche.visible:
		_couche.visible = false
		RenderingServer.global_shader_parameter_set("relief_zone", Vector4(0, 0, 0, 0))

## Avance l'horloge de `s` secondes d'un coup (captures « 30 s plus tard », tests) : masque, blocs de glace.
static func saut_de_temps(s: float) -> void:
	var e := instance
	if e == null:
		return
	e.t += s
	for b in e._blocs:
		if is_instance_valid(b):
			b.vieillir(s)

## Efface tout (tests, changement de scène).
func reinitialiser() -> void:
	_donnees.fill(0.0)
	_rdonnees.fill(0.0)
	_relief_fin = 0.0
	_prec_pied.clear()
	_fin_vie = 0.0
	_sale = true
	for b in _blocs:
		if is_instance_valid(b):
			b.queue_free()
	_blocs.clear()
	_marcheurs.clear()
	_jets.clear()
	_envoyer()
	_regler_rect(false)

func _regler_rect(on: bool) -> void:
	_rect_actif = on
	RenderingServer.global_shader_parameter_set("effets_rect", Vector4(_ox, _oz, N, 1.0 if on else 0.0))
	RenderingServer.global_shader_parameter_set("effets_temps", t)

func _envoyer() -> void:
	_img.set_data(N, N, false, Image.FORMAT_RGBAF, _donnees.to_byte_array())
	_tex.update(_img)
	_rimg.set_data(N, N, false, Image.FORMAT_RGF, _rdonnees.to_byte_array())
	_rtex.update(_rimg)
	_sale = false
	_dernier_envoi = t
	stats["envois"] = int(stats["envois"]) + 1

# ------------------------------------------------------------------ masque (fenêtre torique)

func _indice(tx: int, tz: int) -> int:
	return (posmod(tz, N) * N + posmod(tx, N)) * 4

func dans_fenetre(tx: int, tz: int) -> bool:
	return tx >= _ox and tz >= _oz and tx < _ox + N and tz < _oz + N

## Valeur du masque (R fonte, G durée, B empreinte, A brûlure/ombre) au point monde (x, z) en m.
func lire(x: float, z: float) -> Vector4:
	var tx := floori(x * RES)
	var tz := floori(z * RES)
	if not dans_fenetre(tx, tz):
		return Vector4.ZERO
	var i := _indice(tx, tz)
	return Vector4(_donnees[i], _donnees[i + 1], _donnees[i + 2], _donnees[i + 3])

## Relief au point monde (x, z) : Vector2(amplitude en m, fin) ; amplitude > 0 = creux, < 0 = bourrelet. Zéro hors fenêtre.
func lire_relief(x: float, z: float) -> Vector2:
	var tx := floori(x * RES)
	var tz := floori(z * RES)
	if not dans_fenetre(tx, tz):
		return Vector2.ZERO
	var i := _indice(tx, tz) / 2
	return Vector2(_rdonnees[i], _rdonnees[i + 1])

## Profondeur effective (m) au texel (fondu de fin compris), comme le shader.
func profondeur(x: float, z: float) -> float:
	var r := lire_relief(x, z)
	return r.x * smoothstep(0.0, 1.0, clampf((r.y - t) / 10.0, 0.0, 1.0))

## Recentre la fenêtre sur `c` (x, z en m) : seules les bandes qui ENTRENT sont vidées (le reste est conservé).
func _centrer(c: Vector2) -> void:
	var nx := floori(c.x * RES) - N / 2
	var nz := floori(c.y * RES) - N / 2
	var dx := nx - _ox
	var dz := nz - _oz
	if absi(dx) >= N or absi(dz) >= N:
		_donnees.fill(0.0)
		_rdonnees.fill(0.0)
	else:
		for k in absi(dx):
			var tx := (nx + N - 1 - k) if dx > 0 else (nx + k)
			for tz in range(nz, nz + N):
				var i := _indice(tx, tz)
				_donnees[i] = 0.0
				_donnees[i + 1] = 0.0
				_donnees[i + 2] = 0.0
				_donnees[i + 3] = 0.0
				_rdonnees[i / 2] = 0.0
				_rdonnees[i / 2 + 1] = 0.0
		for k in absi(dz):
			var tz := (nz + N - 1 - k) if dz > 0 else (nz + k)
			for tx in range(nx, nx + N):
				var i := _indice(tx, tz)
				_donnees[i] = 0.0
				_donnees[i + 1] = 0.0
				_donnees[i + 2] = 0.0
				_donnees[i + 3] = 0.0
				_rdonnees[i / 2] = 0.0
				_rdonnees[i / 2 + 1] = 0.0
	_ox = nx
	_oz = nz
	_sale = true
	if _rect_actif:
		_regler_rect(true)

## S'assure que (x, z) est dans la fenêtre ; sinon la recentre entre le joueur et ce point (si c'est à moins de 12 m du joueur).
func _assurer(x: float, z: float) -> bool:
	if dans_fenetre(floori(x * RES), floori(z * RES)):
		return true
	var c := Vector2(x, z)
	if _joueur != null and is_instance_valid(_joueur):
		var pj := Vector2(_joueur.global_position.x, _joueur.global_position.z)
		if pj.distance_to(c) > 12.0:
			return false
		c = (pj + c) * 0.5
	_centrer(c)
	return dans_fenetre(floori(x * RES), floori(z * RES))

func _suivre_joueur(j: Node3D) -> void:
	_joueur = j
	var p := Vector2(j.global_position.x, j.global_position.z)
	var cx := (_ox + N / 2) / RES
	var cz := (_oz + N / 2) / RES
	if absf(p.x - cx) > 2.5 or absf(p.y - cz) > 2.5:   # la grille de relief (±7 m) reste dans la fenêtre (±10 m)
		_centrer(p)

static func _hash(tx: int, tz: int) -> float:
	var n: int = (tx * 374761393 + tz * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0

## Dehors (vrai) ou sous terre / dans un intérieur (faux) : posé par cycle.gd avec l'uniforme global `neige_objets`.
static var dehors := true

static func neige_dehors() -> bool:
	return forcer_neige or dehors

## Sol enneigé (neige, piétinée ou croûtée) au point monde (x, z), dehors.
static func est_neige(x: float, z: float) -> bool:
	if forcer_neige:
		return true
	if not (Sol.est_neige(x, z) and neige_dehors()):
		return false
	if instance != null:
		for w in instance._eaux:
			if is_instance_valid(w) and w.contient(x, z):
				return false   # le sol sous un lac ou une mare n'est pas de la neige
	return true

func _vivre(fin: float) -> void:
	_fin_vie = maxf(_fin_vie, fin)
	_sale = true

# ------------------------------------------------------------------ pas, saut, atterrissage

## Un pas du joueur : empreinte (pied gauche ou droit), petite gerbe, plus marquée en courant.
static func pas(j: Node3D, vitesse: Vector2, gauche: bool, court: bool) -> void:
	if not actif or j == null:
		return
	var p := j.global_position
	if not est_neige(p.x, p.z):
		return
	var e := obtenir()
	if e == null or not e.is_node_ready():
		return
	e._suivre_joueur(j)
	var dir3 := Vector3(-vitesse.x, 0.0, -vitesse.y).normalized() * 0.35 if vitesse.length() > 0.05 else Vector3.ZERO
	GerbePixels.emettre(e, p + Vector3(0, 0.04, 0), Vector3.UP + dir3, "neige", 2.2 if court else 1.1)

## Une empreinte de botte (appelée par le joueur tous les ~0,7 m de marche, indépendamment du rythme des sons).
static func empreinte_pas(j: Node3D, vitesse: Vector2, gauche: bool, court: bool) -> void:
	if not actif or j == null:
		return
	var p := j.global_position
	if not est_neige(p.x, p.z):
		return
	var e := obtenir()
	if e == null or not e.is_node_ready():
		return
	e._suivre_joueur(j)
	e._empreinte(p, vitesse.normalized() if vitesse.length() > 0.05 else Vector2(0, 1), gauche, court)

## Saut : deux empreintes côte à côte à l'appel et une gerbe.
static func saut(j: Node3D) -> void:
	if not actif or j == null:
		return
	var p := j.global_position
	if not est_neige(p.x, p.z):
		return
	var e := obtenir()
	if e == null or not e.is_node_ready():
		return
	e._suivre_joueur(j)
	var dir := Vector2(-sin(j.rotation.y), -cos(j.rotation.y))
	e._empreinte(p, dir, true, true)
	e._empreinte(p, dir, false, true)
	GerbePixels.emettre(e, p + Vector3(0, 0.04, 0), Vector3.UP, "neige", 2.4)

## Atterrissage à `vitesse` m/s de chute : cuvette plus marquée (anneau d'empreintes) et grosse gerbe.
static func atterrissage(j: Node3D, vitesse: float) -> void:
	if not actif or j == null:
		return
	var p := j.global_position
	if not est_neige(p.x, p.z):
		return
	var e := obtenir()
	if e == null or not e.is_node_ready():
		return
	e._suivre_joueur(j)
	var force := clampf((vitesse - 3.0) / 8.0, 0.0, 1.0)
	e._cuvette(p, lerpf(0.28, 0.6, force))
	GerbePixels.emettre(e, p + Vector3(0, 0.05, 0), Vector3.UP, "neige", lerpf(2.0, 3.6, force))

## Marque une empreinte de botte (rectangle arrondi, 5×11 échantillons de 3 cm) au pied gauche ou droit.
func _empreinte(pos: Vector3, dir: Vector2, gauche: bool, court: bool) -> void:
	var lat := Vector2(-dir.y, dir.x)
	var ecart := 0.34 if court else 0.27   # demi-écart entre les pieds : piste de deux files de bottes
	var c := Vector2(pos.x, pos.z) + lat * (ecart if gauche else -ecart)
	if not _assurer(c.x, c.y):
		return
	# creux (B = fin) entouré d'un bourrelet clair (B = -fin) ; en course : plus long, plus large, sillon plus net
	var demi_l := 7 if court else 5   # marche : ~55×27 cm, ovale allongé (texels de 6 cm : plus petit ne se lit plus) ; course : sillon ~75×36 cm
	var demi_w := 4 if court else 3
	var fin := t + DUREE_PAS
	for a in range(-demi_w - 1, demi_w + 2):
		for b in range(-demi_l - 1, demi_l + 2):
			var bord := absi(a) > demi_w or absi(b) > demi_l
			var coin := absi(a) >= demi_w and absi(b) >= demi_l - 1   # bout arrondi
			if coin and not bord:
				continue
			if bord and absi(a) > demi_w and absi(b) > demi_l - 1:
				continue
			var q := c + lat * (a * 0.045) + dir * (b * 0.05)
			_ecrire_empreinte(q.x, q.y, -fin if bord else fin)
	var cr := Vector2(pos.x, pos.z) + lat * ((0.21 if gauche else -0.21) if court else (0.17 if gauche else -0.17))
	_relief_botte(cr, dir, gauche, court)
	stats["pas"] = int(stats["pas"]) + 1
	_vivre(fin)

# ------------------------------------------------------------------ relief : bottes, sillon, lèvre du trou de feu

## Écrit un texel de relief : `amp` > 0 creuse, < 0 relève. Un creux vivant n'est jamais recouvert par un bourrelet ;
## un creux plus profond remplace un creux moins profond ; l'eau et le sol sans neige n'en reçoivent jamais.
func _relief_ecrire(tx: int, tz: int, amp: float, fin: float) -> void:
	if not dans_fenetre(tx, tz) or not est_neige((tx + 0.5) / RES, (tz + 0.5) / RES):
		return
	var i := _indice(tx, tz) / 2
	var vivant := _rdonnees[i + 1] > t
	var a_old := _rdonnees[i] if vivant else 0.0
	if amp > 0.0:
		if a_old > 0.0 and a_old > amp:
			_rdonnees[i + 1] = maxf(_rdonnees[i + 1], fin)   # déjà plus profond : on rafraîchit seulement
			return
	elif a_old > 0.0 or (a_old < 0.0 and a_old < amp):
		return
	_rdonnees[i] = amp
	_rdonnees[i + 1] = fin
	_relief_fin = maxf(_relief_fin, fin)
	stats["texels"] = int(stats["texels"]) + 1

## Forme d'une botte en coordonnées locales (u : latéral, v : vers l'avant, en m) : > 0 à l'intérieur (1 au centre d'une
## ellipse). Avant-pied large, talon plus étroit, cambrure entre les deux.
static func _forme_botte(u: float, v: float, e: float) -> float:
	var avant := 1.0 - (pow(u / (0.105 * e), 2.0) + pow((v - 0.085 * e) / (0.135 * e), 2.0))
	var talon := 1.0 - (pow(u / (0.08 * e), 2.0) + pow((v + 0.145 * e) / (0.095 * e), 2.0))
	return maxf(avant, talon)

## Empreinte en relief : creux en forme de botte (talon + avant-pied) entouré d'un bourrelet ; en course, plus grande, plus
## profonde à l'avant-pied, avec un sillon traîné depuis l'empreinte précédente du même pied.
func _relief_botte(c: Vector2, dir: Vector2, gauche: bool, court: bool) -> void:
	var lat := Vector2(-dir.y, dir.x)
	var e := 1.18 if court else 1.0
	var amp := CREUX_COURSE if court else CREUX_MARCHE
	var fin := t + DUREE_RELIEF
	var box: Dictionary = {}   # Vector2i -> amplitude (creux seulement)
	var r := ceili(0.34 * e * RES) + 1
	var c0 := Vector2i(floori(c.x * RES), floori(c.y * RES))
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := Vector2((c0.x + dx + 0.5) / RES, (c0.y + dz + 0.5) / RES) - c
			var u := p.dot(lat)
			var v := p.dot(dir)
			var s := _forme_botte(u, v, e)
			if s > 0.0:
				var kv := 0.8 + 0.2 * clampf((v / e + 0.15) / 0.3, 0.0, 1.0) if court else 1.0 - 0.15 * clampf((v / e + 0.15) / 0.3, 0.0, 1.0)
				box[Vector2i(c0.x + dx, c0.y + dz)] = amp * kv * smoothstep(0.0, 0.5, s)
	if court:
		_sillon(c, gauche, box)
	_relief_bord(box, fin, amp)
	_vivre(fin)

## Écrit les creux de `box` et, tout autour, le bourrelet de neige repoussée (2 couronnes, la 2e plus basse).
func _relief_bord(box: Dictionary, fin: float, amp: float) -> void:
	for k: Vector2i in box:
		_relief_ecrire(k.x, k.y, box[k], fin)
	var bords: Dictionary = {}
	for k: Vector2i in box:
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var q := k + o
			if not box.has(q):
				bords[q] = true
	for q: Vector2i in bords:
		_relief_ecrire(q.x, q.y, -BOURRELET * clampf(amp / CREUX_MARCHE, 1.0, 1.4), fin)

## Sillon traîné entre deux empreintes de course successives du même pied.
func _sillon(c: Vector2, gauche: bool, box: Dictionary) -> void:
	var prec: Variant = _prec_pied.get(gauche)
	_prec_pied[gauche] = {"pos": c, "t": t}
	if prec == null or t - float(prec["t"]) > 1.5:
		return
	var a: Vector2 = prec["pos"]
	var d := c - a
	var L := d.length()
	if L < 0.25 or L > 2.6:
		return
	var dn := d / L
	var r := ceili(0.16 * RES) + 1
	var pas_n := int(L * RES * 1.5)
	for k in pas_n:
		var q := a.lerp(c, (k + 0.5) / pas_n)
		var q0 := Vector2i(floori(q.x * RES), floori(q.y * RES))
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cell := Vector2i(q0.x + dx, q0.y + dz)
				var p := Vector2((cell.x + 0.5) / RES, (cell.y + 0.5) / RES)
				var dist := absf((p - a).dot(Vector2(-dn.y, dn.x)))
				var along := (p - a).dot(dn)
				if along < 0.12 or along > L - 0.12 or dist > 0.07:
					continue
				var amp_s := CREUX_COURSE * 0.55 * smoothstep(0.07, 0.02, dist)
				if amp_s > 0.0 and amp_s > float(box.get(cell, 0.0)):
					box[cell] = amp_s

## Cuvette d'atterrissage : disque de rayon `r`, creux au centre.
func _cuvette(pos: Vector3, r: float) -> void:
	if not _assurer(pos.x, pos.z):
		return
	var fin := t + DUREE_PAS
	var n := int(r * RES * 1.5)
	for i in range(-n, n + 1):
		for k in range(-n, n + 1):
			var q := Vector2(pos.x, pos.z) + Vector2(i, k) / (RES * 1.5)
			if q.distance_to(Vector2(pos.x, pos.z)) <= r:
				_ecrire_empreinte(q.x, q.y, fin)
	stats["pas"] = int(stats["pas"]) + 1
	_vivre(fin)

func _ecrire_empreinte(x: float, z: float, fin: float) -> void:
	var tx := floori(x * RES)
	var tz := floori(z * RES)
	if not dans_fenetre(tx, tz) or not est_neige((tx + 0.5) / RES, (tz + 0.5) / RES):
		return
	var i := _indice(tx, tz) + 2
	if fin < 0.0 and _donnees[i] > t:
		return   # le bourrelet ne recouvre pas un creux vivant
	_donnees[i] = fin
	stats["texels"] = int(stats["texels"]) + 1

## Ennemis et villageois proches : une empreinte par foulée (sans toucher à leurs scripts).
func _sonder_marcheurs() -> void:
	if not actif or _joueur == null or not is_instance_valid(_joueur):
		return
	var pj := _joueur.global_position
	if not est_neige(pj.x, pj.z):
		return
	var vus := {}
	var n := 0
	for g in ["ennemis", "villageois", "gardes_village"]:
		for m in get_tree().get_nodes_in_group(g):
			if n >= MAX_MARCHEURS:
				break
			var nd := m as Node3D
			if nd == null or not nd.is_inside_tree() or nd == _joueur:
				continue
			var mort: Variant = nd.get("mort")
			if mort is bool and mort:
				continue
			var p := nd.global_position
			if p.distance_to(pj) > PORTEE_MARCHEURS:
				continue
			n += 1
			var id := nd.get_instance_id()
			vus[id] = true
			var d: Dictionary = _marcheurs.get(id, {"pos": p, "reste": 0.0, "pied": false})
			var dep := Vector2(p.x - d["pos"].x, p.z - d["pos"].z)
			if dep.length() < 3.0:   # téléportation : on repart de là
				d["reste"] = float(d["reste"]) + dep.length()
				if float(d["reste"]) >= FOULEE and dep.length() > 0.02 and est_neige(p.x, p.z):
					d["reste"] = 0.0
					d["pied"] = not bool(d["pied"])
					_empreinte(p, dep.normalized(), bool(d["pied"]), false)
					if dep.length() > 0.5:
						GerbePixels.emettre(self, p + Vector3(0, 0.04, 0), Vector3.UP, "neige", 0.5)
			d["pos"] = p
			_marcheurs[id] = d
	for id in _marcheurs.keys():
		if not vus.has(id):
			_marcheurs.erase(id)

# ------------------------------------------------------------------ neige fondue

## Fait fondre la neige dans le disque (x, z, rayon) : terre sombre ou mouillée (flaque : eau), qui redevient neige en
## 30 à 60 s (`duree` > 0 pour la fixer). Le centre dure plus longtemps que le bord, le bord est irrégulier.
func fondre(x: float, z: float, rayon: float, flaque := false, duree := -1.0) -> void:
	if not actif or not _assurer(x, z):
		return
	var dur := duree if duree > 0.0 else _rng.randf_range(FONTE_MIN, FONTE_MAX)
	var n := ceili(rayon * RES) + 1
	var cx := floori(x * RES)
	var cz := floori(z * RES)
	var ecrits := 0
	var cellule := Vector2i(-99999, -99999)
	var neige := false
	var fondus: Dictionary = {}
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var tx := cx + dx
			var tz := cz + dz
			var px := (tx + 0.5) / RES
			var pz := (tz + 0.5) / RES
			var d := Vector2(px - x, pz - z).length() / rayon
			var bord := 0.82 + 0.3 * _hash(tx, tz)
			if d > bord or not dans_fenetre(tx, tz):
				continue
			var c := Vector2i(floori(px * 4.0), floori(pz * 4.0))
			if c != cellule:
				cellule = c
				neige = est_neige(px, pz)
			if not neige:
				continue
			var i := _indice(tx, tz)
			var fin := t + dur * (1.0 - 0.5 * minf(d, 1.0))
			if fin > _donnees[i] or flaque != (_donnees[i + 1] < 0.0):
				_donnees[i] = fin
				_donnees[i + 1] = -dur if flaque else dur
			ecrits += 1
			fondus[Vector2i(tx, tz)] = true
	# lèvre épaisse : la neige repoussée par la chaleur forme un bourrelet autour du trou (relief seulement)
	var fin_lev := t + dur * 0.85
	var vus: Dictionary = {}
	for k: Vector2i in fondus:
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var q := k + o
			if not fondus.has(q) and not vus.has(q):
				vus[q] = true
				_relief_ecrire(q.x, q.y, -BOURRELET_FEU, fin_lev)
	_relief_fin = maxf(_relief_fin, t + dur)
	stats["fontes"] = int(stats["fontes"]) + 1
	stats["texels"] = int(stats["texels"]) + ecrits
	_vivre(t + dur)

func vapeur(pos: Vector3, force := 1.0) -> void:
	GerbePixels.emettre(self, pos + Vector3(0, 0.1, 0), Vector3.UP, "vapeur", force)

# ------------------------------------------------------------------ brûlures et ombres

## Brûlure au sol : tache sombre irrégulière et quelques traînées qui rayonnent (ramification de l'éclair).
func bruler(x: float, z: float, rayon: float) -> void:
	if not actif or not _assurer(x, z):
		return
	var fin := t + DUREE_BRULURE
	var cx := floori(x * RES)
	var cz := floori(z * RES)
	var n := ceili(rayon * RES) + 1
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var d := Vector2(dx, dz).length() / (rayon * RES)
			if d <= 0.55 + 0.3 * _hash(cx + dx, cz + dz) and dans_fenetre(cx + dx, cz + dz):
				_donnees[_indice(cx + dx, cz + dz) + 3] = fin
				stats["texels"] = int(stats["texels"]) + 1
	for k in 7:   # branches de l'étoile, larges de 2 texels, qui rayonnent et bifurquent
		var a := TAU * (k + _rng.randf() * 0.5) / 7.0
		var longueur := int(rayon * RES * _rng.randf_range(2.2, 3.6))
		var p := Vector2(cx, cz)
		for s in longueur:
			a += _rng.randf_range(-0.3, 0.3)
			p += Vector2(cos(a), sin(a))
			for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				var tx := int(p.x) + o.x
				var tz := int(p.y) + o.y
				if dans_fenetre(tx, tz):
					_donnees[_indice(tx, tz) + 3] = fin
	_vivre(fin)

## Tache d'ombre : disque qui se résorbe du bord vers le centre en 14 s.
func ombrer(x: float, z: float, rayon: float) -> void:
	if not actif or not _assurer(x, z):
		return
	var cx := floori(x * RES)
	var cz := floori(z * RES)
	var n := ceili(rayon * RES) + 1
	var plus_long := 0.0
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var d := Vector2(dx, dz).length() / (rayon * RES)
			if d <= 0.8 + 0.2 * _hash(cx + dx, cz + dz) and dans_fenetre(cx + dx, cz + dz):
				var fin := t + DUREE_OMBRE * (1.0 - 0.75 * minf(d, 1.0))
				_donnees[_indice(cx + dx, cz + dz) + 3] = -fin
				plus_long = maxf(plus_long, fin)
				stats["texels"] = int(stats["texels"]) + 1
			elif d <= 1.2 and _hash(cx + dx * 7, cz + dz * 3) < 0.35 and dans_fenetre(cx + dx, cz + dz):
				var fin2 := t + DUREE_OMBRE * 0.35   # bord qui fume : texels épars, vite résorbés
				_donnees[_indice(cx + dx, cz + dz) + 3] = -fin2
	_vivre(plus_long)

# ------------------------------------------------------------------ glace

func bloc_glace(pos: Vector3, normale: Vector3, echelle: float, pics: int, avec_bloc := true) -> void:
	if not actif or not is_inside_tree():
		return
	while _blocs.size() >= MAX_BLOCS:
		var vieux = _blocs.pop_front()
		if is_instance_valid(vieux):
			vieux.queue_free()
	_blocs = _blocs.filter(func(b) -> bool: return is_instance_valid(b))
	var g := GlaceFondante.creer(self, pos, normale, minf(echelle * 1.8, 2.2), pics, avec_bloc, _rng.randi())
	_blocs.append(g)
	stats["blocs"] = int(stats["blocs"]) + 1

## Chaleur : les blocs de glace à moins de `rayon` (+ leur taille) fondent beaucoup plus vite.
func chauffer(pos: Vector3, rayon: float) -> void:
	for b in _blocs:
		if is_instance_valid(b) and b.global_position.distance_to(pos) <= rayon + b.rayon:
			b.chauffer()

# ------------------------------------------------------------------ sorts (appelés par EffetsMagie)

## Point du sol sous `p` (rayon court : un impact sur un corps en hauteur ne compte pas). {} si rien.
func _sol_sous(p: Vector3, haut := 0.3, bas := 0.6) -> Dictionary:
	var monde: World3D = get_viewport().world_3d
	if monde == null:
		return {}
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * haut, p + Vector3.DOWN * bas)
	q.collide_with_areas = false
	var r: Dictionary = monde.direct_space_state.intersect_ray(q)
	if r.is_empty() or Vector3(r["normal"]).y < 0.7:
		return {}
	return r

static func sort_impact(ecole: String, pos: Vector3, normale: Vector3, force: float) -> void:
	if not actif or ecole in ["soin", "protection"]:
		return
	var e := obtenir()
	if e == null or not e.is_node_ready():
		return
	var r := e._sol_sous(pos)
	if r.is_empty():
		return
	var sol: Vector3 = r["position"]
	var n: Vector3 = r["normal"]
	match ecole:
		"feu":
			var rayon := clampf(0.35 + 0.5 * force, 0.45, 1.6)
			e.fondre(sol.x, sol.z, rayon)
			e.vapeur(sol, clampf(force, 0.6, 2.0))
			e.chauffer(sol, rayon)
		"glace":
			e.bloc_glace(sol, n, clampf(0.55 + 0.35 * force, 0.6, 1.4), 2 + int(force))
		"electricite":
			e.bruler(sol.x, sol.z, clampf(0.3 + 0.15 * force, 0.3, 0.75))
			var f := clampf(force, 0.8, 1.8) * 1.6
			GerbePixels.emettre(e, sol + Vector3(0, 0.05, 0), Vector3.UP, "etincelles", f)
			for k in range(1, 4):   # étincelles qui crépitent encore quelques secondes
				e.get_tree().create_timer(0.5 * k).timeout.connect(func() -> void:
					if is_instance_valid(e):
						GerbePixels.emettre(e, sol + Vector3(0, 0.05, 0), Vector3.UP, "etincelles", f * 0.8))
		"tenebres":
			e.ombrer(sol.x, sol.z, clampf(0.7 + 0.3 * force, 0.7, 1.6))

static func sort_zone(ecole: String, pos: Vector3, rayon: float, duree: float) -> void:
	if not actif or ecole in ["soin", "protection"]:
		return
	var e := obtenir()
	if e == null or not e.is_node_ready():
		return
	var r := e._sol_sous(pos, 0.6, 1.2)
	if r.is_empty():
		return
	var sol: Vector3 = r["position"]
	var n: Vector3 = r["normal"]
	var rr := minf(rayon, 2.4)
	match ecole:
		"feu":
			e.fondre(sol.x, sol.z, rr)
			e.vapeur(sol, 2.0)
			e.chauffer(sol, rr)
		"glace":
			# nova : un bloc central et des pics en couronne (amas séparés pour rester sous le plafond)
			e.bloc_glace(sol, n, clampf(rr / 2.5, 0.7, 1.4), 2, true)
			for k in 3:
				var a := TAU * (k + e._rng.randf()) / 3.0
				var q := sol + Vector3(cos(a), 0.0, sin(a)) * rr * 0.7
				var rq := e._sol_sous(q, 0.8, 1.5)
				if not rq.is_empty():
					e.bloc_glace(rq["position"], rq["normal"], clampf(rr / 3.0, 0.6, 1.2), 2, false)
		"electricite":
			for k in 4:
				var a := e._rng.randf() * TAU
				var d := e._rng.randf_range(0.2, 0.8) * rr
				e.bruler(sol.x + cos(a) * d, sol.z + sin(a) * d, 0.28)
		"tenebres":
			e.ombrer(sol.x, sol.z, rr)

## Jet canalisé (appelé chaque image) : au plus un traitement tous les 0,1 s et par main. Le feu creuse une traînée.
static func sort_jet(ecole: String, origine: Node3D, direction: Vector3, portee: float, largeur: float, actif_jet: bool) -> void:
	if not actif or not actif_jet or origine == null or ecole in ["soin", "protection", "glace"]:
		return
	var e := obtenir()
	if e == null or not e.is_node_ready():
		return
	var id := origine.get_instance_id()
	var j: Dictionary = e._jets.get(id, {"t": -1.0, "fin": Vector3.INF, "vapeur": 0.0})
	if e.t - float(j["t"]) < 0.1:
		return
	var bout := origine.global_position + direction.normalized() * portee
	var r := e._sol_sous(bout, 0.6, 1.0)
	if r.is_empty():
		j["t"] = e.t
		j["fin"] = Vector3.INF
		e._jets[id] = j
		return
	var sol: Vector3 = r["position"]
	var prec: Vector3 = j["fin"]
	j["t"] = e.t
	j["fin"] = sol
	match ecole:
		"feu":
			var rayon := clampf(largeur * 0.4, 0.4, 0.8)
			# du point précédent à celui-ci (balayage rapide : pas de trous dans la traînée)
			var depart: Vector3 = prec if (prec != Vector3.INF and prec.distance_to(sol) < 3.0) else sol
			var pas_n := maxi(1, ceili(depart.distance_to(sol) / (rayon * 0.6)))
			for k in pas_n:
				var q := depart.lerp(sol, float(k + 1) / pas_n)
				e.fondre(q.x, q.z, rayon, false, FONTE_MIN + 15.0)
			e.chauffer(sol, rayon)
			if e.t - float(j["vapeur"]) > 0.3:
				j["vapeur"] = e.t
				e.vapeur(sol, 0.8)
		"electricite":
			e.bruler(sol.x, sol.z, 0.22)
		"tenebres":
			e.ombrer(sol.x, sol.z, 0.5)
	e._jets[id] = j

## Fin d'une chaîne d'éclairs ou d'une décharge : brûlure là où ça touche le sol.
static func sort_points(ecole: String, points: Array) -> void:
	if not actif or points.is_empty() or ecole not in ["electricite", "tenebres"]:
		return
	for p in points.slice(1):
		sort_impact(ecole, p, Vector3.UP, 0.8)
