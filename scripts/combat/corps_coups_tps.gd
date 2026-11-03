class_name CorpsCoupsTps
extends SkeletonModifier3D
## COUPS D'ARME DU CORPS À LA 3e PERSONNE (branche tps/coups, 2026-11-02 ; retour utilisateur : « pour la vue 3e personne
## c'est toujours le même coup d'épée »).
##
## Le corps (corps_joueur.gd) rejouait un seul clip Quaternius (Sword_Attack) à chaque coup. Ici, le corps joue le MÊME geste
## que les bras de la 1re personne, image par image : on lit le clip du bras FPS en cours (mains.anim.clip, son temps
## mains.anim.t et ses marqueurs arme / frappe / fin_frappe / suivi / fin) et on montre au même instant la capture de mouvement
## correspondante, sur tout le corps. Combo 1-2-3-4, coup puissant selon sa direction, charge tenue, claymore et grand
## marteau (deux mains), haches / masses / marteaux, garde, parade, coup encaissé, garde brisée, contre-attaque : tout passe
## par le clip FPS, donc tout reste synchronisé avec la machine à états de mains.gd (dégâts, fenêtre de combo, endurance)
## sans rien y changer.
##
## Captures (leçon du projet : les poses écrites à la main sont rejetées, les captures retargetées plaisent) : Mixamo
## « Sword And Shield », « Great Sword », coups isolés, et Quaternius UAL2 (CC0), reportées sur le squelette du corps par la
## méthode des draugrs zombies (outils/coups_tps_retarget.gd -> assets/animations/corps_coups_tps.res), poignet borné (pas de
## casse). CLIPS ci-dessous : clip FPS -> plage de la capture (images à 30 i/s) et images de ses propres marqueurs.
##
## Branchement (corps_joueur.gd, minimal) : CorpsCoupsTps.equiper(corps, squelette) à la création du modèle ; tant que
## pilote() est vrai, corps_joueur ne lance plus son ancien coup (Sword_Attack) ni la pose armée / garde tenue. Ce
## modificateur passe AVANT PiedsAuSol : les pieds restent posés au sol par-dessus le geste.
## Jambes : à l'arrêt, le corps entier suit la capture (appuis, poids) ; en marche, seul le haut du corps (bassin et jambes
## laissés à la marche) : on frappe en avançant sans patiner.
## Arme (fusion integration/tps) : le modèle tenu par le corps appartient à CorpsMainsTps (corps_joueur.mains_tps.arme_tenue(),
## seul à connaître les deux mains : arme cachée quand la main droite tient un sort, enchantement, bouclier) ; ici on ne fait
## que le LIRE : à deux mains, la main gauche est ramenée sur SA poignée (IK analytique, pendant le geste ; hors geste, c'est
## l'IK de CorpsMainsTps), et les mesures (poignet, écart main gauche) partent de sa prise.

const BIBLIOTHEQUE := preload("res://assets/animations/corps_coups_tps.res")
const FONDU := 0.1          # s : passage d'un geste à l'autre (pose affichée -> nouvelle capture)
const POIGNET_MAX_TEST := 40.0   # degrés : borne vérifiée par outils/test_coups_tps.gd (retarget : 38°)
const FONDU_SORTIE := 0.22  # s : retour à la locomotion
const PRISE_EPEE_CORPS := 0.04   # milieu de la poignée de epee_nordique.glb (repère du modèle) : la prise PRISE de corps_joueur y tombe

## clip FPS (nom RÉEL joué par AnimateurBras) -> capture : « src » (clip de corps_coups_tps.res), « im » = images de la
## capture alignées sur les marqueurs FPS [début, arme, frappe, fin_frappe, fin] (charges : [début, arme, fin] ; tenues :
## [début, fin] en boucle si « boucle »). Les coups de la 1re personne venant des mêmes captures (gestes_bras_epee.py,
## gestes_une_main.py, gestes_2mains.py) gardent leurs images ; ici l'armé derrière la tête, coupé en vue FPS, est rendu.
const CLIPS := {
	# --- épée à une main : combo 1-2-3-4 (coups v6) ---
	# 1 diagonale haut-droite -> bas-gauche (« Sword And Shield Slash (1) »)
	"coup_a6": {"src": "slash_1", "im": [6, 15, 17, 23, 34]},
	# 2 revers horizontal gauche -> droite (« Sword And Shield Slash (2) », début ; la vrille qui suit l'image 22 est coupée)
	"coup_b6": {"src": "slash_2", "im": [2, 10, 12, 19, 23]},
	# 3 taille horizontale droite -> gauche (Quaternius UAL2 « Sword_Regular_Combo », 3e coup)
	"coup_t6": {"src": "q_Sword_Regular_Combo", "im": [24, 31, 33, 38, 44]},
	# 4 estoc (« Stabbing »)
	"coup_c6": {"src": "estoc", "im": [1, 6, 8, 14, 30]},
	# coups v5 (mêmes captures)
	"coup_a": {"src": "slash_1", "im": [6, 15, 17, 23, 34]},
	"coup_b": {"src": "slash_2", "im": [2, 10, 12, 19, 23]},
	"coup_t": {"src": "q_Sword_Regular_Combo", "im": [24, 31, 33, 38, 44]},
	"coup_c": {"src": "estoc", "im": [1, 6, 8, 14, 30]},
	# --- coups puissants (clic maintenu), selon le déplacement au début de la charge ---
	# à l'arrêt / de côté gauche : frappe verticale de haut en bas (« Standing Melee Attack Downward »)
	"charge_lourd": {"src": "vertical", "im": [1, 19, 21]},
	"lourd": {"src": "vertical", "im": [21, 21, 22, 27, 45]},
	# en avançant : grand coup par-dessus en fendant (« Sword And Shield Attack »)
	"charge_vertical": {"src": "ss_attack", "im": [1, 14, 16]},
	"lourd_vertical": {"src": "ss_attack", "im": [16, 16, 17, 24, 45]},
	# pas de côté à droite : balayage gauche -> droite (« Stable Sword Outward Slash »)
	"charge_gd": {"src": "revers", "im": [1, 14, 16]},
	"lourd_gd": {"src": "revers", "im": [16, 16, 17, 25, 45]},
	# en reculant : revers court (« Standing Melee Attack Backhand »)
	"charge_revers": {"src": "revers_b", "im": [1, 18, 20]},
	"lourd_revers": {"src": "revers_b", "im": [20, 20, 21, 30, 50]},
	# --- finishers v2 (branche combat/finishers_v2) : mêmes captures que les clips FPS fin_* (gestes_finishers.py) ; « marq » = noms
	# des marqueurs du clip FPS auxquels « im » (une image de plus : le début) est calé, tenue plantée comprise ---
	# épée plantée / dans le dos : « Stabbing » (images 2 -> 14 estoc, 14 -> 26 tenue, 26 -> 50 retrait et retour)
	"fin_plantee": {"src": "estoc", "marq": ["arme", "frappe", "contact", "plante", "retrait", "sortie", "suivi", "fin"], "im": [2, 8, 10, 14, 14, 26, 33, 38, 50]},
	# décapitation : taille horizontale (UAL2 « Sword_Regular_Combo », 3e coup)
	"fin_decapitation": {"src": "q_Sword_Regular_Combo", "im": [24, 31, 33, 38, 44]},
	# coup plongé : « Standing Melee Attack Downward »
	"fin_plonge": {"src": "vertical", "marq": ["arme", "frappe", "contact", "plante", "retrait", "sortie", "suivi", "fin"], "im": [2, 19, 21, 27, 27, 28, 34, 40, 46]},
	# --- défense ---
	"garde": {"src": "q_Sword_Block", "im": [8, 8], "tenue": true},
	"parade": {"src": "q_Sword_Block", "im": [4, 14]},
	"encaisse": {"src": "ss_impact", "im": [0, 14]},
	"garde_brisee": {"src": "q_Idle_Shield_Break", "im": [0, 32]},
	"contre": {"src": "slash_1", "im": [12, 15, 17, 23, 34]},
	# --- deux mains (claymore, hybrides 6-8 ; captures de la claymore v3) ---
	"c2_a": {"src": "gs_slash", "im": [4, 12, 16, 24, 38]},
	"c2_b": {"src": "gs_slash_2", "im": [40, 46, 50, 57, 70]},
	"c2_c": {"src": "gs_slash_2", "im": [8, 18, 23, 31, 40]},
	"charge_2m": {"src": "gs_slash_2", "im": [8, 21, 22]},
	"lourd_2m": {"src": "gs_slash_2", "im": [22, 22, 23, 31, 45]},
	"garde_2m": {"src": "gs_block_2", "im": [10, 10], "tenue": true},
	"parade_2m": {"src": "gs_block", "im": [0, 15]},
	"encaisse_2m": {"src": "gs_impact", "im": [0, 20]},
	"brisee_2m": {"src": "gs_impact", "im": [0, 26]},
	# --- haches, masses, marteaux (gestes lourds) ---
	# hache : 1 diagonale, 2 revers, 3 taille verticale ; puissante = grand vertical
	"h_a": {"src": "slash_1", "im": [6, 15, 17, 23, 34]},
	"h_b": {"src": "interieur", "im": [1, 14, 16, 24, 40]},
	"h_c": {"src": "vertical", "im": [1, 19, 21, 27, 45]},
	"charge_h": {"src": "vertical", "im": [1, 19, 21]},
	"lourd_h": {"src": "vertical", "im": [21, 21, 22, 27, 45]},
	# masse / marteau : crochet, revers, écrasement ; puissante = écrasement à deux temps (UAL2 « Sword_Heavy_Combo »)
	"m_a": {"src": "revers_b", "im": [1, 18, 20, 30, 50]},
	"m_b": {"src": "revers", "im": [1, 14, 16, 25, 45]},
	"m_c": {"src": "vertical", "im": [1, 19, 21, 27, 45]},
	"charge_m": {"src": "vertical", "im": [1, 19, 21]},
	"lourd_m": {"src": "vertical", "im": [21, 21, 22, 27, 45]},
	# grand marteau (deux mains) : grand vertical tête -> sol
	"gm_a": {"src": "gs_slash_2", "im": [8, 18, 23, 31, 40]},
	"charge_gm": {"src": "gs_slash_2", "im": [8, 21, 22]},
	"lourd_gm": {"src": "gs_slash_2", "im": [22, 22, 23, 31, 45]},
}
const OS_BAS := ["pelvis", "thigh_l", "calf_l", "foot_l", "ball_l", "ball_leaf_l", "thigh_r", "calf_r", "foot_r", "ball_r", "ball_leaf_r"]

var corps: Node3D            # corps_joueur.gd (joueur, mains)
var sq: Skeleton3D
var _pistes := {}            # src -> {os: piste de rotation} ; « _bassin » : piste de position
var _os: Array[int] = []
var _bas := {}               # os -> true (bassin et jambes)
var _i_bassin := -1
var _clip := ""              # clip FPS suivi
var _src := ""
var _t_src := 0.0            # s dans la capture
var _poids := 0.0            # 0 : locomotion seule, 1 : geste
var _fondu := 1.0            # 0 -> 1 : fondu depuis _pose_depart
var _pose_depart := {}       # os -> Quaternion (pose affichée au changement de geste)
var _bassin_depart := Vector3.ZERO
var _derniere := {}          # os -> Quaternion (dernière pose du geste, pour la sortie)
var _bassin_dernier := Vector3.ZERO
var _poids_jambes := 1.0
var _actif_clip := false
var _force := ""             # captures : --tps-clip=src:image
var ik_gauche := true
## Bras gauche quand la main gauche tient la torche (ou un sort) : part de la capture gardée (les captures balancent le bras
## du bouclier : la torche battait l'air). 1 = capture entière. La pose de la main gauche elle-même (torche, sorts) reste à
## corps_joueur / branche tps/mains_sorts : ce réglage ne fait que ne pas la déranger.
var poids_bras_gauche_occupe := 0.0
var _gauche := {}            # os du bras gauche (clavicule -> doigts)
var prise_corps := Transform3D()   # corps_joueur.PRISE (prise de l'épée dans hand_r)

static func equiper(corps_joueur: Node3D, squelette: Skeleton3D) -> CorpsCoupsTps:
	var m := CorpsCoupsTps.new()
	m.name = "CorpsCoupsTps"
	m.corps = corps_joueur
	squelette.add_child(m)
	# avant les pieds au sol (et leur IK) : les pieds se reposent sur le sol par-dessus le geste
	var premier := squelette.get_child_count() - 1
	for c in squelette.get_children():
		if c is SkeletonModifier3D and c != m:
			premier = mini(premier, c.get_index())
	squelette.move_child(m, premier)
	m._installer(squelette)
	return m

func _installer(squelette: Skeleton3D) -> void:
	sq = squelette
	_i_bassin = sq.find_bone("pelvis")
	prise_corps = (load("res://scripts/corps_joueur.gd") as GDScript).get_script_constant_map()["PRISE"]
	for i in sq.get_bone_count():
		if sq.get_bone_parent(i) >= 0:
			_os.append(i)
		if sq.get_bone_name(i) in OS_BAS:
			_bas[i] = true
	var ic := sq.find_bone("clavicle_l")
	for i in sq.get_bone_count():
		var k := i
		while k >= 0 and k != ic:
			k = sq.get_bone_parent(k)
		if ic >= 0 and k == ic:
			_gauche[i] = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tps-clip="):
			_force = a.substr(11)

## Pistes d'une capture (indices par os), calculées une fois.
func _pistes_de(src: String) -> Dictionary:
	if _pistes.has(src):
		return _pistes[src]
	var p := {}
	var a := BIBLIOTHEQUE.get_animation(src)
	if a != null:
		for k in a.get_track_count():
			var os_nom := String(a.track_get_path(k)).get_slice(":", 1)
			var o := sq.find_bone(os_nom)
			if o < 0:
				continue
			if a.track_get_type(k) == Animation.TYPE_ROTATION_3D:
				p[o] = k
			elif a.track_get_type(k) == Animation.TYPE_POSITION_3D and o == _i_bassin:
				p["_bassin"] = k
	_pistes[src] = p
	return p

static func existe(clip: String) -> bool:
	return CLIPS.has(clip)

## Le corps est piloté par un geste de combat (corps_joueur ne joue alors ni son ancien coup ni sa pose armée / garde).
func pilote() -> bool:
	return _force != "" or _clip_courant() != ""

## Part du geste dans la pose (0 : locomotion seule, 1 : capture entière) : CorpsMainsTps y règle ses couches de bras et son IK.
func poids_geste() -> float:
	return _poids

## Clip FPS en cours s'il a sa capture (nom réel), sinon "" (repos, course : la locomotion du corps).
func _clip_courant() -> String:
	var mains: Node3D = corps.mains if corps != null else null
	if mains == null or mains.anim == null or mains.anim.clip == "" or corps.joueur.mort:
		return ""
	var reel: String = mains.anim.reel(mains.anim.clip)
	if not CLIPS.has(reel):
		return ""
	if reel in ["garde", "parade", "encaisse"] and bool(mains.call("garde_bouclier")):
		return ""   # au bouclier, l'épée reste au repos (GestesBouclier pare de la main gauche)
	return reel

## Temps de la capture (s) pour le clip FPS `clip` à son temps `t` : marqueurs FPS -> images de la capture, par morceaux.
static func temps_capture(spec: Dictionary, m: Dictionary, t: float, longueur: float) -> float:
	var im: Array = spec["im"]
	var fps := 30.0
	if spec.get("tenue", false) or im.size() == 2:
		var a := float(im[0])
		var b := float(im[1])
		if spec.get("tenue", false):
			return a / fps
		var fin := float(m.get("fin", longueur))
		return (a + (b - a) * clampf(t / maxf(fin, 1e-3), 0.0, 1.0)) / fps
	var cles: Array[float] = [0.0]
	if spec.has("marq"):
		for n: String in spec["marq"]:
			cles.append(float(m.get(n, longueur)))
	elif im.size() == 3:
		cles.append(float(m.get("arme", longueur * 0.5)))
		cles.append(float(m.get("fin", longueur)))
	else:
		for n in ["arme", "frappe", "fin_frappe", "fin"]:
			cles.append(float(m.get(n, longueur)))
	for i in range(1, cles.size()):
		cles[i] = maxf(cles[i], cles[i - 1])
	if t <= cles[0]:
		return float(im[0]) / fps
	for i in range(1, cles.size()):
		if t <= cles[i]:
			var u := (t - cles[i - 1]) / maxf(cles[i] - cles[i - 1], 1e-4)
			return lerpf(float(im[i - 1]), float(im[i]), u) / fps
	return float(im[im.size() - 1]) / fps

func _process(dt: float) -> void:
	if corps == null or corps.mains == null:
		return
	var mains: Node3D = corps.mains
	var joueur: CharacterBody3D = corps.joueur
	if joueur.mort:
		_poids = 0.0
		_actif_clip = false
		influence = 0.0
		return
	influence = 1.0
	var clip := ""
	var spec := {}
	if _force != "":
		var d := _force.split(":")
		_src = d[0]
		_t_src = float(d[1]) / 30.0 if d.size() > 1 else 0.0
		_poids = 1.0
		_fondu = 1.0
		_poids_jambes = 1.0
		_actif_clip = true
		return
	var anim: AnimateurBras = mains.anim
	clip = _clip_courant()
	if clip != "":
		spec = CLIPS[clip]
		var src: String = spec["src"]
		var t := temps_capture(spec, anim.marqueurs(anim.clip), anim.t, anim.longueur(anim.clip))
		if clip != _clip:
			# nouveau geste : fondu depuis le geste précédent encore affiché (depuis la locomotion, c'est la montée de _poids
			# qui fond)
			if _poids > 0.01 and not _derniere.is_empty():
				_pose_depart = _derniere.duplicate()
				_bassin_depart = _bassin_dernier
				_fondu = 0.0
			else:
				_fondu = 1.0
			_clip = clip
		_src = src
		_t_src = t
		_actif_clip = true
		_poids = minf(1.0, _poids + dt / FONDU)
		_fondu = minf(1.0, _fondu + dt / FONDU)
	else:
		_clip = ""
		_actif_clip = false
		_poids = maxf(0.0, _poids - dt / FONDU_SORTIE)
	# jambes : à l'arrêt elles suivent la capture, en marche elles gardent la locomotion
	var v := Vector2(joueur.velocity.x, joueur.velocity.z).length()
	var but_jambes := 1.0 - smoothstep(0.4, 1.4, v) if joueur.is_on_floor() else 0.0
	_poids_jambes = move_toward(_poids_jambes, but_jambes, dt * 5.0)

func _process_modification() -> void:
	if sq == null or (_poids <= 0.0 and not _actif_clip):
		return
	var _gauche_occupee: bool = not _deux_mains() and _main_gauche_occupee()
	var a := BIBLIOTHEQUE.get_animation(_src) if _src != "" else null
	var p := _pistes_de(_src) if a != null else {}
	var tc := clampf(_t_src, 0.0, a.length) if a != null else 0.0
	for i in _os:
		var sous := sq.get_bone_pose_rotation(i)   # locomotion (AnimationPlayer du corps)
		var geste: Quaternion
		if _actif_clip and p.has(i):
			geste = a.rotation_track_interpolate(p[i], tc)
			if _fondu < 1.0 and _pose_depart.has(i):
				geste = (_pose_depart[i] as Quaternion).slerp(geste, smoothstep(0.0, 1.0, _fondu))
			_derniere[i] = geste
		elif _derniere.has(i):
			geste = _derniere[i]
		else:
			continue
		var w := _poids * (_poids_jambes if _bas.has(i) else 1.0)
		if _gauche_occupee and _gauche.has(i):
			w *= poids_bras_gauche_occupe
		sq.set_bone_pose_rotation(i, sous.slerp(geste, w))
	# bassin : hauteur et décalage de la capture (à l'arrêt seulement)
	var sous_b := sq.get_bone_pose_position(_i_bassin)
	var geste_b := _bassin_dernier
	if _actif_clip and p.has("_bassin"):
		geste_b = a.position_track_interpolate(p["_bassin"], tc)
		if _fondu < 1.0:
			geste_b = _bassin_depart.lerp(geste_b, smoothstep(0.0, 1.0, _fondu))
		_bassin_dernier = geste_b
	sq.set_bone_pose_position(_i_bassin, sous_b.lerp(geste_b, _poids * _poids_jambes))
	if ik_gauche and _deux_mains():
		_main_gauche_sur_poignee(_poids)
	_mesurer()

## Mesures de la pose FINALE (tests, outils) : hors du modificateur, Skeleton3D rend la pose d'avant les modificateurs.
var poignet_deg := 0.0       # écart de la main droite à l'axe de l'avant-bras (degrés)
var ecart_gauche := -1.0     # deux mains : centre du poing gauche -> poignée sous la droite (m) ; -1 sinon

func _mesurer() -> void:
	var im := sq.find_bone("hand_r")
	var rel := sq.get_bone_rest(im).basis.get_rotation_quaternion().inverse() * sq.get_bone_pose_rotation(im)
	poignet_deg = rad_to_deg(Vector3.UP.angle_to(rel * Vector3.UP))
	ecart_gauche = -1.0
	if _deux_mains():
		var md := PiedsAuSol.pose_globale(sq, im)
		var mg := PiedsAuSol.pose_globale(sq, sq.find_bone("hand_l"))
		var pr := _prise_arme()
		var axe := (md.basis * pr.basis.y).normalized()
		var but := md * pr.origin - axe * float(corps.mains.arme.ecart_mains)
		var pl := _poing_gauche_local()
		ecart_gauche = (mg * pl).distance_to(but)

# --- arme tenue ---------------------------------------------------------------------------------------------------

func _deux_mains() -> bool:
	var m: Node3D = corps.mains
	return m != null and m.arme != null and m.arme.deux_mains

## Point de la main gauche (repère de hand_l) posé sur la poignée à deux mains : prise de la torche (corps_joueur.pivot_torche),
## comme l'IK de repos de CorpsMainsTps ; à défaut, le centre du poing droit en miroir.
func _poing_gauche_local() -> Vector3:
	var pv = corps.get("pivot_torche")
	if pv is Node3D and is_instance_valid(pv):
		return (pv as Node3D).transform.origin
	var p := prise_corps * Vector3(0.0, PRISE_EPEE_CORPS, 0.0)
	p.x = -p.x
	return p

## Modèle de l'arme tenue par le corps : celui de CorpsMainsTps (seul propriétaire), ou null (main droite nue ou sort).
func modele_arme() -> Node3D:
	var mt = corps.get("mains_tps") if corps != null else null
	var m: Node3D = mt.arme_tenue() if mt != null else null
	return m if is_instance_valid(m) else null

## La main gauche tient autre chose que l'arme (torche, sort, bouclier) : le bras gauche reste à CorpsMainsTps.
func _main_gauche_occupee() -> bool:
	var mt = corps.get("mains_tps")
	if mt != null:
		return mt.categorie("gauche") in ["torche", "sort", "bouclier"]
	return bool(corps.mains.torche_sortie)

## Prise de l'arme dans le repère de hand_r : origine = centre du poing droit sur la poignée, Y = axe de la lame (vers la
## pointe). Lue sur le modèle de CorpsMainsTps (enfant d'une accroche hand_r : son transform est déjà dans ce repère).
func _prise_arme() -> Transform3D:
	var m := modele_arme()
	if m == null:
		return Transform3D(prise_corps.basis, prise_corps * Vector3(0.0, PRISE_EPEE_CORPS, 0.0))
	var milieu := float(corps.mains.get("_milieu_d"))
	return Transform3D(m.transform.basis.orthonormalized(), m.transform * Vector3(0.0, milieu, 0.0))

## Deux mains : la main gauche est ramenée sur la poignée, sous la droite (IK analytique à deux os, coude vers le bas et
## l'extérieur). `w` : poids (0 : la capture seule).
func _main_gauche_sur_poignee(w: float) -> void:
	if w <= 0.0 or modele_arme() == null:
		return
	var m: Node3D = corps.mains
	var ecart: float = m.arme.ecart_mains
	var i_bras := sq.find_bone("upperarm_l")
	var i_avant := sq.find_bone("lowerarm_l")
	var i_main := sq.find_bone("hand_l")
	var i_main_d := sq.find_bone("hand_r")
	if i_bras < 0 or i_avant < 0 or i_main < 0:
		return
	var g_main_d := PiedsAuSol.pose_globale(sq, i_main_d)
	var prise := prise_corps
	# poignée : axe de la lame (Y du modèle tenu par CorpsMainsTps) ; la main gauche se place `ecart` m plus bas que la droite
	var pa := _prise_arme()
	var axe := (g_main_d.basis * pa.basis.y).normalized()
	var but_pos := g_main_d * pa.origin - axe * ecart
	var g_bras := PiedsAuSol.pose_globale(sq, i_bras)
	var g_avant := PiedsAuSol.pose_globale(sq, i_avant)
	var g_main := PiedsAuSol.pose_globale(sq, i_main)
	var la := g_bras.origin.distance_to(g_avant.origin)
	var lb := g_avant.origin.distance_to(g_main.origin)
	# point de la main qui doit tomber sur la poignée : celui de l'IK de CorpsMainsTps (prise de la torche, pivot_torche), pour que
	# les deux IK (coup / repos) posent la main au même endroit
	var poing_local := _poing_gauche_local()
	var poing_monde := g_main * poing_local
	var cible := g_main.origin + (but_pos - poing_monde)
	cible = g_main.origin.lerp(cible, w)
	var epaule := g_bras.origin
	var d := clampf(epaule.distance_to(cible), 0.05, (la + lb) * 0.999)
	var dir := (cible - epaule).normalized()
	# pôle : coude actuel (celui de la capture), poussé vers le bas
	var pole := g_avant.origin + Vector3(0, -0.1, 0)
	var cos_a := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	var perp := (pole - epaule) - dir * (pole - epaule).dot(dir)
	if perp.length() < 1e-4:
		perp = Vector3(0, -1, 0)
	perp = perp.normalized()
	var coude := epaule + dir * (la * cos_a) + perp * (la * sqrt(maxf(0.0, 1.0 - cos_a * cos_a)))
	# rotation du bras : direction épaule -> coude ; avant-bras : coude -> cible
	var parent_bras := PiedsAuSol.pose_globale(sq, sq.get_bone_parent(i_bras))
	var r_bras := Quaternion((g_avant.origin - epaule).normalized(), (coude - epaule).normalized()) if (g_avant.origin - epaule).length() > 1e-4 else Quaternion.IDENTITY
	var nb := Basis(r_bras) * g_bras.basis
	sq.set_bone_pose_rotation(i_bras, (parent_bras.basis.inverse() * nb).get_rotation_quaternion())
	var g_bras2 := Transform3D(nb, epaule)
	var g_avant2 := g_bras2 * sq.get_bone_pose(i_avant)
	var r_av := Quaternion(((g_avant2 * sq.get_bone_pose(i_main)).origin - g_avant2.origin).normalized(), (cible - g_avant2.origin).normalized())
	var na := Basis(r_av) * g_avant2.basis
	sq.set_bone_pose_rotation(i_avant, (g_bras2.basis.inverse() * na).get_rotation_quaternion())
	# main : orientation monde de la capture conservée (les deux mains de la capture Great Sword serrent déjà la poignée)
	sq.set_bone_pose_rotation(i_main, (na.inverse() * g_main.basis).get_rotation_quaternion())
