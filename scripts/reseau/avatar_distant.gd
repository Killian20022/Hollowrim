class_name AvatarDistant
extends RefCounted
## LOT 4b — AVATAR COMPLET d'un joueur distant (promotion de proto_avatar.gd, qui reste pour les tests du lot 1).
## Un avatar = une instance de joueur.gd avec est_local = false (aucune entrée lue, aucune caméra courante, corps à la 3e personne :
## corps_joueur.gd + CorpsCoupsTps + CorpsMainsTps + ArmureVisible). Cette classe REÇOIT l'état du joueur distant et l'applique :
##   - ÉTAT COMPACT (20 Hz, non fiable) : [pos, lacet, tangage, vitesse, drapeaux, état de combat, n° de clip, temps du clip]
##     capturé chez le joueur propriétaire par AvatarDistant.capturer(joueur) ; ici interpolé ~100 ms en retard (DELAI, comme le Replicateur).
##   - GESTES : le clip des mains (mains.anim.clip) et son temps sont posés tels quels sur l'avatar ; CorpsCoupsTps rejoue alors le même
##     coup de capture que chez le propriétaire (mains.pas_manuel = true : la machine à états locale est coupée, seul le clip répliqué compte).
##   - ÉQUIPEMENT (évènement fiable « avatar_equip », voir avatars_coop.gd) : armes / bouclier des deux mains + pièces d'armure, rejoués sur
##     mains.magie.eq et equipement_corps (ArmureVisible les rend visibles, CorpsMainsTps montre l'arme / le bouclier tenus).
##   - À TERRE : corps couché (animation « Death01 » tenue sur sa dernière image), relevé = la même animation à l'envers ; MORT : cadavre
##     (ragdoll de corps_joueur), position gelée jusqu'à la réapparition (mort = faux : le corps est recréé).
##   - NOM : Label3D discret au-dessus de la tête (police par défaut, filtre « nearest », contour noir), qui s'efface avec la distance.
## Scripts préchargés par des tests « -s » : jamais l'identifiant nu Reseau ici (voir ReseauLieux.reseau() / PauseCoop.R()).

const JOUEUR := preload("res://scripts/joueur.gd")

const DELAI := 0.1             # s : lecture en retard (toujours deux instantanés autour)
const TAMPON_MAX := 40
const F_ACCROUPI := 1
const F_GARDE := 2
const F_A_TERRE := 4
const F_MORT := 8
const F_SOL := 16
const NOM_PLEIN := 12.0        # m : nom pleinement visible en deçà
const NOM_PORTEE := 28.0       # m : nom effacé au-delà
const TOMBER_S := 2.4          # s : durée de Death01 (remplacée par sa vraie longueur si lue)
const VITESSE_CHUTE := 1.6     # la chute (Death01) est jouée plus vite que la mort : un allié à terre doit l'être vite
const VITESSE_RELEVE := 2.0    # relevé = Death01 à l'envers, ×2

var id := 0
var noeud: CharacterBody3D
var nom := ""
var etiquette: Label3D
var equipement := {}           # dernier équipement reçu (évènement « avatar_equip »)
var flags := 0                 # drapeaux du dernier état reçu
var _tampon: Array = []        # [t_reçu, état]
var _couche := false           # corps couché (à terre) en cours
var _relevant := 0.0           # s restantes du relevé
var _pos_gelee := false
static var _noms_clips: Array = []

# ------------------------------------------------------------------------------------------------ création

## Crée l'avatar `peer_id` sous `parent` (caché sous le sol jusqu'au premier instantané) et l'inscrit au registre des joueurs.
static func creer(parent: Node, peer_id: int, nom_joueur := "", pos := Vector3(0, -100, 0)) -> AvatarDistant:
	var a := AvatarDistant.new()
	a.id = peer_id
	a.nom = nom_joueur if nom_joueur != "" else "Joueur %d" % peer_id
	a.noeud = CharacterBody3D.new()
	a.noeud.set_script(JOUEUR)
	a.noeud.set("est_local", false)   # AVANT add_child (lu par _ready)
	a.noeud.name = "Joueur_%d" % peer_id
	a.noeud.position = pos
	parent.add_child(a.noeud)
	var r := PauseCoop.R()
	if r != null:
		r.registre.definir_noeud(peer_id, a.noeud)   # pertinence par distance, « joueur le plus proche », ATerre
	var m: Node3D = a.noeud.mains
	m.set("pas_manuel", true)   # la machine à états des mains est celle du propriétaire : ici seul le clip répliqué compte
	if m.get("magie") != null and m.magie.get("eq") != null:
		m.magie.eq.apprendre_tout()   # les sorts de l'équipement distant ne doivent pas être refusés (« Sort inconnu »)
	a._etiquette()
	return a

func _etiquette() -> void:
	etiquette = Label3D.new()
	etiquette.name = "Nom"
	etiquette.text = nom
	etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiquette.pixel_size = 0.0045
	etiquette.font_size = 28
	etiquette.outline_size = 10
	etiquette.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	etiquette.modulate = Color(0.93, 0.86, 0.7)
	etiquette.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST   # gros pixels : même rendu que le reste (PS1)
	etiquette.shaded = false
	etiquette.double_sided = true
	etiquette.no_depth_test = false
	etiquette.position = Vector3(0, 2.2, 0)
	noeud.add_child(etiquette)

func definir_nom(n: String) -> void:
	nom = n if n != "" else "Joueur %d" % id
	if etiquette != null:
		etiquette.text = nom

func liberer() -> void:
	var r := PauseCoop.R()
	if r != null and r.registre.noeud(id) == noeud:
		r.registre.definir_noeud(id, null)
	if is_instance_valid(noeud):
		noeud.queue_free()

# ------------------------------------------------------------------------------------------------ émission (chez le propriétaire)

## Noms de clips des mains (tous les clips de AnimateurBras, triés) : l'état envoie l'indice, pas la chaîne.
static func noms_clips() -> Array:
	if _noms_clips.is_empty():
		var d := {}
		for b: AnimationLibrary in [AnimateurBras.BIBLIOTHEQUE, AnimateurBras.DEUX_MAINS, AnimateurBras.LOURDS, AnimateurBras.GARDES, AnimateurBras.FINISHERS]:   # GARDES : gardes par famille (combat/gardes_toutes_armes)
			for n in b.get_animation_list():
				d[String(n)] = true
		_noms_clips = d.keys()
		_noms_clips.sort()
	return _noms_clips

## État compact du joueur LOCAL : [pos, lacet, tangage, vitesse, drapeaux, état de combat, n° de clip (-1 : aucun), temps du clip].
static func capturer(j: CharacterBody3D) -> Array:
	var m: Node3D = j.mains
	var fl := 0
	if j.accroupi:
		fl |= F_ACCROUPI
	if m != null and bool(m.get("bloque")):
		fl |= F_GARDE
	if j.a_terre:
		fl |= F_A_TERRE
	if j.mort:
		fl |= F_MORT
	if j.is_on_floor():
		fl |= F_SOL
	var etat := 0
	var clip := -1
	var t := 0.0
	if m != null:
		etat = m.combat.etat
		if m.anim.clip != "":
			clip = noms_clips().find(m.anim.clip)
			t = m.anim.t
	return [j.global_position, j.rotation.y, j.tete.rotation.x, j.velocity, fl, etat, clip, t]

## Équipement du joueur LOCAL (évènement « avatar_equip ») : ids des deux mains (EquipementMains) et pièces d'armure portées.
static func capturer_equipement(j: CharacterBody3D, nom_joueur: String) -> Dictionary:
	var d := {"nom": nom_joueur, "droite": "vide", "gauche": "vide", "corps": {}, "apparence": String(j.get("apparence"))}   # joueur_base : homme / femme
	var m: Node3D = j.mains
	if m != null and m.get("magie") != null and m.magie.get("eq") != null:
		var eq: EquipementMains = m.magie.eq
		for main: String in ["droite", "gauche"]:
			var id_main := String(eq.mains[main].get("id", "vide"))
			d[main] = "vide" if id_main == "main_vide" else id_main
	for e: String in j.equipement_corps.emplacements:
		d["corps"][e] = String(j.equipement_corps.emplacements[e])
	return d

# ------------------------------------------------------------------------------------------------ réception

func recevoir(etat: Array) -> void:
	_tampon.append([Time.get_ticks_msec() / 1000.0, etat])
	if _tampon.size() > TAMPON_MAX:
		_tampon.pop_front()
	flags = int(etat[4])

func vide() -> bool:
	return _tampon.is_empty()

## Équipement reçu : rejoué sur l'avatar (mains.magie.eq pour les mains, equipement_corps pour l'armure ; sans passer par le sac).
func appliquer_equipement(d: Dictionary) -> void:
	if d == equipement or not is_instance_valid(noeud):
		return
	equipement = d.duplicate(true)
	definir_nom(String(d.get("nom", nom)))
	if d.has("apparence") and String(d["apparence"]) != String(noeud.get("apparence")):
		noeud.definir_apparence(String(d["apparence"]))   # joueur_base : corps de l'autre joueur (homme / femme), avant l'armure
	var m: Node3D = noeud.mains
	if m != null and m.get("magie") != null and m.magie.get("eq") != null:
		var eq: EquipementMains = m.magie.eq
		for main: String in ["droite", "gauche"]:   # droite d'abord : une arme à deux mains vide la gauche
			var voulu := String(d.get(main, "vide"))
			var present := String(eq.mains[main].get("id", "vide"))
			if (voulu if voulu != "main_vide" else "vide") != (present if present != "main_vide" else "vide"):
				var refus := eq.equiper(main, voulu)
				if refus != "":
					push_warning("AvatarDistant %d : %s refusé en main %s (%s)" % [id, voulu, main, refus])
	var ec: EquipementCorps = noeud.equipement_corps
	var corps: Dictionary = d.get("corps", {})
	for e: String in corps:
		if ec.emplacements.has(e) and String(ec.emplacements[e]) != String(corps[e]):
			ec.emplacements[e] = String(corps[e])   # directement : le sac de l'avatar est vide (equiper() refuserait)
			ec.change.emit(e)

# ------------------------------------------------------------------------------------------------ application (chaque image physique)

func _lire() -> Dictionary:
	if _tampon.is_empty():
		return {}
	var t := Time.get_ticks_msec() / 1000.0 - DELAI
	var a: Array = _tampon[0]
	var b: Array = _tampon[0]
	var k := 0.0
	if t > _tampon[0][0]:
		a = _tampon[-1]
		b = _tampon[-1]
		for i in range(_tampon.size() - 1):
			if t <= _tampon[i + 1][0]:
				a = _tampon[i]
				b = _tampon[i + 1]
				k = clampf((t - a[0]) / maxf(b[0] - a[0], 0.0001), 0.0, 1.0)
				break
	var ea: Array = a[1]
	var eb: Array = b[1]
	var tc: float = float(eb[7]) if int(ea[6]) != int(eb[6]) else lerpf(float(ea[7]), float(eb[7]), k)
	return {"pos": (ea[0] as Vector3).lerp(eb[0], k), "lacet": lerp_angle(float(ea[1]), float(eb[1]), k), "tangage": lerpf(float(ea[2]), float(eb[2]), k),
		"vel": (ea[3] as Vector3).lerp(eb[3], k), "flags": int(eb[4]), "etat": int(eb[5]), "clip": int(eb[6]), "t": tc}

func avancer(dt: float) -> void:
	if not is_instance_valid(noeud) or noeud.mains == null:
		return
	var r := _lire()
	if r.is_empty():
		return
	var fl: int = r["flags"]
	var mort := (fl & F_MORT) != 0
	var a_terre := (fl & F_A_TERRE) != 0
	# position : gelée tant que le joueur est mort (le cadavre reste où il est tombé) ; le saut de réapparition est appliqué d'un coup
	if not mort:
		_pos_gelee = false
		var pos: Vector3 = r["pos"]
		noeud.global_position = pos
		noeud.rotation.y = r["lacet"]
		noeud.tete.rotation.x = r["tangage"]
		# is_on_floor() n'est vrai qu'après un move_and_slide : petit pas vers le bas puis retour à la position exacte
		noeud.velocity = Vector3(0.0, -1.0, 0.0)
		noeud.move_and_slide()
		noeud.global_position = pos
		noeud.velocity = r["vel"]
	elif not _pos_gelee:
		_pos_gelee = true
		noeud.velocity = Vector3.ZERO
	# accroupi : transition (joueur._furtivite ne tourne pas sur un avatar) — corps écrasé, yeux plus bas
	var acc := (fl & F_ACCROUPI) != 0
	noeud.accroupi = acc
	noeud.accroupi_k = move_toward(noeud.accroupi_k, 1.0 if acc else 0.0, JOUEUR.ACCROUPI_TRANSITION * dt)
	noeud.tete.position.y = lerpf(1.62, JOUEUR.ACCROUPI_TETE, noeud.accroupi_k)
	noeud.corps.scale.y = lerpf(1.0, JOUEUR.ACCROUPI_CORPS, noeud.accroupi_k)
	# mort / à terre : « hors jeu » (cibles des ennemis, secours) ; la mort recrée le corps à la réapparition (corps_joueur)
	if mort and not noeud.mort:
		noeud.origine_dernier_coup = noeud.global_position - noeud.global_transform.basis.z * 1.0   # le coup vient de devant : il tombe en arrière
		noeud.degats_dernier_coup = 20.0
	noeud.mort = mort
	noeud.a_terre = a_terre or mort
	# mains : le geste en cours (clip + temps) et l'état de combat du propriétaire
	var m: Node3D = noeud.mains
	if int(r["etat"]) != m.combat.etat:
		m.combat.forcer(int(r["etat"]))
	var noms := noms_clips()
	var ic: int = r["clip"]
	if a_terre or mort or ic < 0 or ic >= noms.size():
		m.anim.clip = "repos"
		m.anim.t = 0.0
	else:
		m.anim.clip = String(noms[ic])
		m.anim.t = float(r["t"])
	_corps_couche(a_terre and not mort, dt)
	_nom_visible()

## Corps couché (animation de chute de corps_joueur tenue) / relevé (la même à l'envers) ; corps_joueur ne joue rien d'autre tant que _action est posée.
func _corps_couche(couche: bool, dt: float) -> void:
	var c: Node3D = noeud.corps
	if c == null or c.get("anim") == null or noeud.mort:
		_couche = false
		return
	var ap: AnimationPlayer = c.anim
	if couche and not _couche:
		_couche = true
		_relevant = 0.0
		c._action = "Death01"
		c._fin_action = INF
		c._jouer("Death01", 0.15, VITESSE_CHUTE, 0.0, -1.0, true)
	elif not couche and _couche:
		_couche = false
		var d := (ap.get_animation("Death01").length if ap.has_animation("Death01") else TOMBER_S) / VITESSE_RELEVE
		_relevant = d
		c._action = "Death01"
		c._fin_action = c._t + d
		c._cle = ""
		ap.speed_scale = VITESSE_RELEVE
		ap.play_backwards("Death01", 0.1)
	elif _relevant > 0.0:
		_relevant -= dt
		if _relevant <= 0.0 and c._action == "Death01":
			c._action = ""
	if _couche:
		c._action = "Death01"
		c._fin_action = INF

func _nom_visible() -> void:
	if etiquette == null:
		return
	var cam := noeud.get_viewport().get_camera_3d() if noeud.is_inside_tree() else null
	var d := 0.0 if cam == null else cam.global_position.distance_to(noeud.global_position + Vector3(0, 2.0, 0))
	var a := 1.0 - smoothstep(NOM_PLEIN, NOM_PORTEE, d)
	etiquette.visible = a > 0.02
	etiquette.modulate.a = a * (0.55 if noeud.mort else 1.0)
	etiquette.position.y = 0.95 if (flags & (F_A_TERRE | F_MORT)) != 0 else noeud.tete.position.y + 0.5
