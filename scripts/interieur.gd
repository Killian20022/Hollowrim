class_name Interieur
extends Node3D
## Un intérieur de maison (lot « kit intérieur ») : contenu masquable, lumières activées de près, porte animée.
## Le nœud est posé à l'origine du pivot du bâtiment (repère local : X = grand axe, Z = largeur, porte côté +Z).
## - `racine` : tout l'intérieur (maillages fusionnés, flammes, halos, lumières) ; masqué au-delà de `DIST_VISIBLE` ;
## - lumières : OmniLight3D courtes, sans ombre, allumées seulement si le joueur est dedans ou à moins de
##   `DIST_LUMIERE` m de l'emprise (socle technique § 2) ; elles vacillent au pas de 1/12 s ;
## - porte : un ou deux vantaux sur charnière (pivot animé), un blocage de collision tant qu'elle est fermée,
##   fermeture automatique quand on s'éloigne.

const DIST_VISIBLE := 13.0
const DIST_LUMIERE := 8.0
const DIST_FERMETURE := 14.0

var nom := ""
var demi := Vector2(3.0, 2.0)          # demi-emprise INTÉRIEURE (x, z)
var racine: Node3D
var lumieres: Array = []               # [OmniLight3D, énergie, phase]
var vantaux: Array = []                # [Node3D charnière, angle d'ouverture (rad)]
## Le joueur a ouvert ou fermé la porte (touche E) : `ouverte` = état après l'action.
signal porte_actionnee(ouverte: bool)
var bloc_porte: CollisionShape3D
var porte_locale := Vector3.ZERO       # centre de la porte (repère local)
var ouverte := false
var interactif: Node3D
var sans_porte := false
var sol_y := 0.42                      # dessus du sol intérieur (repère local)
## Bâtiments ouverts (retours exe 5) : identité, foyer, serrure et chargement à la demande.
var id := ""                           # id du bâtiment (village.interieur(id), data/batiments.json)
var proprietaire := ""                 # id du foyer (meta « proprietaire » du nœud et de son contenu : objets, lits)
var habitants: Array = []              # ids des PNJ du planning Vie qui y dorment (serrure de nuit)
var difficulte := 0                    # 0 = jamais fermée à clé ; 1 à 4 = difficulté du crochetage quand elle l'est
var regle_verrou := "nuit"             # « nuit » (fermée quand le foyer est rentré), « toujours », « jamais »
var deverrouille := false              # crochetée ou ouverte avec la clé : le reste jusqu'à ce que la porte se referme seule
var village: Node                      # le village (heure du jour, chargement à la demande)
## Chargement à la demande (`paresseux`) : le contenu (doublure, mobilier, lumières) n'est construit qu'à moins de
## DIST_CHARGE m de l'emprise (dans un fil, par le village) et libéré au-delà de DIST_DECHARGE m ; la coque (collisions,
## porte) existe toujours. Entrer sans qu'il soit prêt (téléportation, chargement d'une partie) le construit tout de suite.
const DIST_CHARGE := 24.0
const DIST_DECHARGE := 42.0
var paresseux := false
var construit := true
var en_cours := false
var constructeur: Callable             # (Interieur temporaire) -> Array : remplit le contenu, rend les specs des objets vivants (village)
var collisions: Array = []             # CollisionShape3D du contenu (libérées au déchargement)
var masques: Array[Node3D] = []        # nœuds du dehors masqués quand le contenu est là (âme sombre derrière les vitres)
signal contenu_charge                  # le contenu vient d'être posé (lits, objets : les autres systèmes s'y accrochent)
var _t := 0.0
var _acc := 0.0
var _allume := true
var _tween: Tween

func _init() -> void:
	racine = Node3D.new()
	racine.name = "Contenu"
	add_child(racine)

## Lumière du décor : couleur chaude par défaut, rayon court, atténuation forte, pas d'ombre.
func lumiere(pos: Vector3, energie: float, portee: float, couleur := Color(1.0, 0.56, 0.24), att := 1.7, vacille := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = couleur
	l.light_energy = energie
	l.omni_range = portee
	l.omni_attenuation = att
	l.shadow_enabled = false
	l.position = pos
	racine.add_child(l)
	lumieres.append([l, energie, randf() * 10.0 if vacille else -1.0])
	return l

## Position (repère local) du joueur/de la caméra.
func _camera() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return to_local(cam.global_position) if cam != null else Vector3(1e4, 0, 1e4)

## Vrai si la position locale est dans l'emprise intérieure (marge `m`).
func dedans(p: Vector3, m := 0.0) -> bool:
	return absf(p.x) < demi.x + m and absf(p.z) < demi.y + m and p.y < 6.5

func distance_emprise(p: Vector3) -> float:
	var d := Vector2(maxf(absf(p.x) - demi.x, 0.0), maxf(absf(p.z) - demi.y, 0.0))
	return d.length()

func _process(dt: float) -> void:
	_t += dt
	_acc += dt
	if _acc >= 0.2:
		_acc = 0.0
		var c := _camera()
		var d := distance_emprise(c)
		if paresseux:
			_gerer_chargement(c, d)
		racine.visible = d < DIST_VISIBLE
		var allume := d < DIST_LUMIERE or dedans(c, 0.5)
		if allume != _allume:
			_allume = allume
			for l in lumieres:
				(l[0] as OmniLight3D).visible = allume
		if ouverte and d > DIST_FERMETURE:
			basculer(false, false)
			deverrouille = false
		_maj_verrou()
	if _allume and racine.visible:
		for l in lumieres:
			var ph: float = l[2]
			if ph < 0.0:
				continue
			var pas := floorf(_t * 12.0 + ph * 3.0)
			var h := fposmod(sin(pas * 12.9898 + ph) * 43758.5453, 1.0)
			var f := 0.88 + sin(_t * 6.3 + ph) * 0.05 + sin(_t * 15.1 + ph * 2.0) * 0.03 + (h - 0.5) * 0.1
			(l[0] as OmniLight3D).light_energy = l[1] * f

## Ouvre ou ferme la porte (animation de 0,5 s, bruit de porte).
func basculer(ouvrir: bool, bruit := true) -> void:
	if ouvrir == ouverte:
		return
	ouverte = ouvrir
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	for v in vantaux:
		var n: Node3D = v[0]
		var cible: float = float(v[1]) if ouvrir else 0.0
		_tween.tween_property(n, "rotation:y", cible, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if bloc_porte != null:
		bloc_porte.set_deferred("disabled", ouvrir)
	if interactif != null:
		interactif.verbe = "Fermer la porte" if ouverte else "Ouvrir la porte"
	if bruit and is_inside_tree():
		Sons.jouer_a(self, ["doorOpen_1", "creak1"], to_global(porte_locale), -6.0)

## Pose l'objet « porte » (touche E) ; à appeler quand le joueur et la boîte de dialogue existent.
func activer(joueur: CharacterBody3D, dialogue: Control) -> void:
	if interactif != null or sans_porte:
		return
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.joueur = joueur
	it.dialogue = dialogue
	it.nom = nom
	it.verbe = "Fermer la porte" if ouverte else "Ouvrir la porte"
	it.rayon = 2.4
	it.action = func() -> Array:
		if not ouverte and verrou_actuel() > 0:
			var c := get_tree().get_first_node_in_group("crime")
			if c != null and c.has_method("demander_crochetage"):
				if c.has_signal("crochetage_fini") and not c.is_connected("crochetage_fini", _sur_crochetage):
					c.connect("crochetage_fini", _sur_crochetage)
				c.demander_crochetage(it)       # mini-jeu du lot crime (crochet, intrusion vue) ; réussi : _sur_crochetage
			else:
				dialogue.dire_au_passage(nom, "La porte est fermée à clé.")
				if is_inside_tree():
					Sons.jouer_a(self, ["doorOpen_1"], to_global(porte_locale), -14.0)
			return []
		basculer(not ouverte)
		porte_actionnee.emit(ouverte)   # autosauvegarde à la porte d'une maison (Monde)
		return []
	it.position = porte_locale + Vector3(0, 0.0, 0)
	it.set_meta("interieur", self)
	it.add_to_group("portes")
	add_child(it)
	interactif = it
	_maj_verrou()

# ------------------------------------------------------------------------------------------------ serrure (contrat « crime »)

## Difficulté de la serrure en ce moment (0 = ouverte) : la nuit selon le planning Vie (le foyer est rentré), toujours, ou jamais.
func verrou_actuel() -> int:
	if deverrouille or difficulte <= 0 or regle_verrou == "jamais":
		return 0
	if regle_verrou == "toujours":
		return difficulte
	return difficulte if foyer_rentre(_heure()) else 0

## Vrai si le foyer est rentré pour la nuit à l'heure `h` : un de ses habitants est en mode « maison » (EmploiDuTemps) ;
## sans habitant (ferme, grange, poste de garde), les horaires du profil « travailleur ».
func foyer_rentre(h: float) -> bool:
	if _fiches.is_empty():      # fiches du planning (fusion de dictionnaires) : une fois
		for pid in (habitants if not habitants.is_empty() else [""]):
			_fiches[String(pid)] = EmploiDuTemps.fiche(String(pid))
	for pid: String in _fiches:
		if EmploiDuTemps.mode(_fiches[pid], h, pid) == "maison":
			return true
	return false
var _fiches := {}

## Fin du crochetage (signal Crime.crochetage_fini) : réussi sur cette porte, elle s'ouvre.
func _sur_crochetage(cible: Node3D, reussi: bool) -> void:
	if reussi and cible != null and cible == interactif:
		deverrouiller()

## Appelé par le crochetage réussi (agent « crime ») ou une clé : la porte s'ouvre et reste déverrouillée jusqu'à sa fermeture.
func deverrouiller(ouvrir := true) -> void:
	deverrouille = true
	_maj_verrou()
	if ouvrir and not ouverte:
		basculer(true)
		porte_actionnee.emit(true)

func _heure() -> float:
	var m: Node = village.get("_monde") if village != null else null
	var c: Node = m.get("cycle") if m != null else null
	return float(c.heure) if c != null else 12.0

## Metas du contrat (nœud de l'intérieur et objet « porte ») : « verrou » (difficulté en ce moment), « proprietaire ».
func _maj_verrou() -> void:
	var vv := verrou_actuel()
	set_meta("verrou", vv)
	set_meta("proprietaire", proprietaire)
	if interactif != null:
		interactif.set_meta("verrou", vv)
		interactif.set_meta("proprietaire", proprietaire)
		if not ouverte:
			interactif.verbe = ("Crocheter la porte (%s)" % Crochetage.NOMS[clampi(vv, 1, 4)]) if vv > 0 else "Ouvrir la porte"

# ------------------------------------------------------------------------------------------------ chargement à la demande

func _gerer_chargement(c: Vector3, d: float) -> void:
	if not construit and not en_cours and village != null:
		if dedans(c, 0.6):
			village.construire_interieur_maintenant(self)      # téléporté dedans : tout de suite (une image plus longue)
		elif d < DIST_CHARGE:
			village.demander_interieur(self)                   # en approche : construit dans un fil, posé par petites tâches
	elif construit and not en_cours and d > DIST_DECHARGE:
		decharger()

## Libère le contenu (maillages, lumières, collisions du mobilier) : il sera reconstruit à l'identique (graines fixes).
func decharger() -> void:
	if not paresseux or not construit:
		return
	ObjetsVivants.liberer(racine)      # objets déplacés notés (sauvegarde) : reposés à l'identique au prochain chargement
	for ch in racine.get_children():
		ch.queue_free()
	for cs in collisions:
		if is_instance_valid(cs):
			cs.queue_free()
	collisions.clear()
	lumieres.clear()
	construit = false
	for n in masques:
		if is_instance_valid(n):
			n.visible = true

## Le village a posé le contenu.
func fin_chargement() -> void:
	construit = true
	en_cours = false
	_allume = not _allume      # force la remise à jour des lumières au prochain tick
	for n in masques:
		if is_instance_valid(n):
			n.visible = false
	contenu_charge.emit()
