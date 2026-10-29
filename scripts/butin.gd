extends Node3D
## Butin v2 (lot L2, docs/INSPIRATION_IGNITE.md §2.7 et §2.18) : plus de bourse en BoxMesh ni de cube doré qui flotte.
## Les PIÈCES JAILLISSENT du coffre ou du corps (arcs balistiques jusqu'au sol, pièces couchées), puis sont ASPIRÉES vers le
## joueur ; les OBJETS d'un corps restent dans le corps : « Fouiller » ouvre la fenêtre de butin (scripts/fenetre_butin.gd, L3).
##   - corps d'ennemi (draugr.gd, ennemi_base.gd, dragon.gd) : les pièces attendent au sol ; elles sont versées au sac, UNE fois,
##     quand le joueur passe à moins de `aspiration` m (1,5) — comme l'ancienne bourse, perdues si on ne s'approche jamais ;
##   - coffre (tertre.gd / grotte_jeu.gd : _ouvrir_coffre) : `deja_verse` = les pièces sont déjà dans le sac (versées à l'ouverture : ni double ni
##     perte possible) ; la gerbe n'est que le spectacle, aspirée d'office vers le joueur dès que les pièces sont retombées.
## Propriétés à poser avant add_child : joueur, hud, contenu ; facultatif : depart_global, deja_verse, nom_corps, dialogue.
## Pièce : disque octogonal de 5,8 cm, face Or terni #7b5a26 cerclée d'un bord #d3b25c, tranche #d3b25c, éclat #fff0a8 quand
## elle fait face à la caméra (shader ps1 par Palette.materiau ; 1 appel de dessin par pièce, 24 pièces au plus, le temps du vol).
## Aucun tirage pris au hasard global ni aux rng du décor : la gerbe a sa propre graine (position arrondie + nombre de pièces).

const RAYON_PIECE := 0.029
const EPAISSEUR := 0.005
const GRAVITE := 9.8
const MAX_PIECES := 24
const FACE := Color("#7b5a26")
const TRANCHE := Color("#d3b25c")
const REFLET := Color("#fff0a8")

var joueur: CharacterBody3D
var hud: Control
var contenu := {}  # identifiant → nombre (pièces : « pieces »)
## Point d'où jaillissent les pièces (repère monde) ; par défaut 0,5 m au-dessus du nœud (corps couché).
var depart_global := Vector3.INF
## Coffre : le contenu est déjà dans le sac (_ouvrir_coffre) ; les pièces volent vers le joueur sans attendre.
var deja_verse := false
## Distance d'aspiration (m) d'une gerbe de corps.
var aspiration := 1.5
## Nom affiché sur l'invite « Fouiller » (nom de l'ennemi).
var nom_corps := "Dépouille"
## Boîte de dialogue (invite E) ; trouvée seule si absente. Sans elle, les objets sont versés avec les pièces (repli).
var dialogue: Control
## Objets du corps encore à prendre (fenêtre de butin) : {id: n}.
var objets := {}
## Corps d'ennemi sauvegardé : clé de ButinTables.restes / corps (« ennemi:<ident> ») ; vide = non sauvegardé (coffres, bourses…).
var cle_sauvegarde := ""

static var _mesh: ArrayMesh
static var _mats := {}

var _pieces: Array[Dictionary] = []   # {noeud, etat, t, p0, v0, p1, duree, axe, vitesse, lacet, attente}
var _verse := false
var _inter: Node3D
var _son_fait := false
var _pret := false

func _ready() -> void:
	if cle_sauvegarde.begins_with("lache:"):      # objet lâché depuis l'inventaire (scripts/lacher.gd) : petit sac visible au sol
		Lacher.habiller(self)
	var n_or := int(contenu.get("pieces", 0))
	for id in contenu:
		if id != "pieces" and int(contenu[id]) > 0:
			objets[id] = int(contenu[id])
	if deja_verse:
		objets.clear()
		process_mode = Node.PROCESS_MODE_ALWAYS     # la gerbe d'un coffre continue sous la fenêtre de butin (jeu en pause)
	elif not objets.is_empty():
		_creer_fouille()
		if cle_sauvegarde != "" and _inter != null:
			# les objets restés dans le corps sont ceux de l'état sauvegardé (même dictionnaire : la fenêtre de butin le vide en place)
			add_to_group("corps_butin")
			ButinTables.restes[cle_sauvegarde] = objets
			_noter_corps.call_deferred()
	var nb := 0 if n_or <= 0 else clampi(4 + n_or / 3, 5, MAX_PIECES)
	if nb > 0:
		_jaillir.call_deferred(nb)      # après add_child : l'appelant pose global_position juste après
	elif _inter == null:
		_verser()                                   # rien à montrer : contenu versé tel quel (repli)
		queue_free()

## Position du corps (posée par l'appelant après add_child) notée pour la sauvegarde.
func _noter_corps() -> void:
	if is_inside_tree() and cle_sauvegarde != "":
		var p := global_position
		ButinTables.corps[cle_sauvegarde] = {"pos": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)], "nom": nom_corps}

## Partie chargée (monde.gd) : repose les corps encore fouillables de la sauvegarde (ButinTables.corps) ; ceux déjà présents sont retirés
## d'abord (chargement en cours de partie). Pas de pièces : elles étaient versées ou perdues avant la sauvegarde.
static func restaurer(parent: Node, joueur_: CharacterBody3D, hud_: Control) -> void:
	for n in parent.get_tree().get_nodes_in_group("corps_butin"):
		n.remove_from_group("corps_butin")
		n.queue_free()
	for cle: String in ButinTables.corps.keys():
		if not ButinTables.a_reste(cle):
			continue
		var e: Dictionary = ButinTables.corps[cle]
		var pos: Array = e["pos"]
		var b := Node3D.new()
		b.set_script(preload("res://scripts/butin.gd"))
		b.joueur = joueur_
		b.hud = hud_
		b.nom_corps = String(e.get("nom", "Dépouille"))
		b.contenu = (ButinTables.restes[cle] as Dictionary).duplicate()
		b.cle_sauvegarde = cle
		parent.add_child(b)
		b.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))

## L3 : corps à fouiller (touche E, « Fouiller ») : ouvre la fenêtre de butin sur `objets` ; sans boîte de dialogue ni fenêtre
## (scène sans interface), pas d'invite : les objets sont versés avec les pièces (repli de _verser).
func _creer_fouille() -> void:
	if dialogue == null:
		dialogue = _trouver_dialogue()
	if dialogue == null or joueur == null:
		return
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.joueur = joueur
	it.dialogue = dialogue
	it.nom = nom_corps
	it.verbe = "Fouiller"
	it.rayon = 2.0
	it.action = func() -> Array:
		fouiller()
		return []
	it.condition = func() -> bool: return not objets.is_empty()
	it.position = Vector3(0, 0.3, 0)
	add_child(it)
	_inter = it

## Ouvre la fenêtre de butin du corps (aussi appelé par les tests). Repli sans fenêtre : tout au sac.
func fouiller() -> bool:
	if objets.is_empty():
		return false
	var f := FenetreButin.trouver(self)
	if f != null and f.ouvrir(nom_corps, objets, 0, _apres_fouille):
		return true
	var liste: Array = []
	for id: String in objets:
		liste.append({"id": id, "n": int(objets[id]), "rarete": ButinTables.rarete_de(id)})
	for o: Dictionary in ButinTables.prendre(joueur.inventaire, liste):
		if hud != null:
			hud.avis("+ %d %s" % [int(o["n"]), joueur.inventaire.nom(String(o["id"]))])
	objets.clear()
	_apres_fouille()
	return false

func _apres_fouille() -> void:
	if objets.is_empty() and _inter != null and is_instance_valid(_inter):
		_inter.actif = false
		dialogue.retirer_invite(_inter)
	_peut_partir()

## Tests : invite de fouille posée (corps avec objets).
func a_fouille() -> bool:
	return _inter != null and is_instance_valid(_inter) and _inter.actif

func _peut_partir() -> void:
	if objets.is_empty() and _pieces.is_empty() and is_inside_tree() and not is_queued_for_deletion():
		queue_free()

func _trouver_dialogue() -> Control:
	if hud != null and hud.get_parent() != null:
		for n in hud.get_parent().get_children():
			if n is Control and n.has_method("inviter") and n.get("joueur") == joueur:
				return n
	return null

# ------------------------------------------------------------------ gerbe

static func _materiau(nom: String) -> ShaderMaterial:
	if _mats.has(nom) and is_instance_valid(_mats[nom]):
		return _mats[nom]
	var img := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	var cols: Array = [FACE, TRANCHE, REFLET, REFLET] if nom != "reflet" else [REFLET, REFLET, REFLET, REFLET]
	for i in 4:
		img.set_pixel(i, 0, cols[i])
	var tex := ImageTexture.create_from_image(img)
	var m := Palette.materiau(tex)
	m.set_shader_parameter("tex_neige", tex)      # jamais de neige sur une pièce
	m.set_shader_parameter("emission", Vector3(0.05, 0.034, 0.008) if nom != "reflet" else Vector3(0.9, 0.82, 0.5))
	_mats[nom] = m
	return m

## Pièce : octogone ; dessus et dessous = face (texel 0) cerclée d'un bord clair (texel 1) ; tranche claire (texel 1). 64 triangles.
static func maillage() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 8
	var uv_face := Vector2(0.125, 0.5)
	var uv_bord := Vector2(0.375, 0.5)
	var r1 := RAYON_PIECE * 0.7
	for cote: float in [1.0, -1.0]:
		var y := EPAISSEUR * 0.5 * cote
		var nrm := Vector3(0, cote, 0)
		for k in n:
			var a0 := TAU * k / n
			var a1 := TAU * (k + 1) / n
			var i0 := Vector3(cos(a0) * r1, y, sin(a0) * r1)
			var i1 := Vector3(cos(a1) * r1, y, sin(a1) * r1)
			var o0 := Vector3(cos(a0) * RAYON_PIECE, y, sin(a0) * RAYON_PIECE)
			var o1 := Vector3(cos(a1) * RAYON_PIECE, y, sin(a1) * RAYON_PIECE)
			for t: Array in [[Vector3(0, y, 0), i0, i1, uv_face], [i0, o0, o1, uv_bord], [i0, o1, i1, uv_bord]]:
				var pts: Array = [t[0], t[2], t[1]] if cote > 0.0 else [t[0], t[1], t[2]]
				for p: Vector3 in pts:
					st.set_normal(nrm)
					st.set_uv(t[3])
					st.add_vertex(p)
	var h := EPAISSEUR * 0.5
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var b0 := Vector3(cos(a0) * RAYON_PIECE, -h, sin(a0) * RAYON_PIECE)
		var b1 := Vector3(cos(a1) * RAYON_PIECE, -h, sin(a1) * RAYON_PIECE)
		var nrm := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		var haut := Vector3(0, 2 * h, 0)
		for p: Vector3 in [b0, b0 + haut, b1 + haut, b0, b1 + haut, b1]:
			st.set_normal(nrm)
			st.set_uv(uv_bord)
			st.add_vertex(p)
	_mesh = st.commit()
	return _mesh

## Graine de la gerbe : position arrondie + nombre de pièces (même mort, même gerbe).
func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	var p := global_position
	r.seed = ButinTables.hacher("gerbe:%d:%d:%d:%d" % [roundi(p.x * 10.0), roundi(p.y * 10.0), roundi(p.z * 10.0), int(contenu.get("pieces", 0))])
	return r

func _jaillir(nb: int) -> void:
	_pret = true
	if not is_inside_tree():
		return
	var rng := _rng()
	var p0 := depart_global if depart_global != Vector3.INF else global_position + Vector3(0, 0.5, 0)
	var sol0 := global_position.y
	var espace := get_world_3d().direct_space_state
	var exclus: Array[RID] = []
	if joueur != null:
		exclus.append(joueur.get_rid())
	var vers_j := Vector3.FORWARD
	if joueur != null:
		vers_j = joueur.global_position - global_position
		vers_j.y = 0.0
		vers_j = vers_j.normalized() if vers_j.length() > 0.05 else Vector3.FORWARD
	var centre := Vector3(global_position.x, sol0, global_position.z)
	for i in nb:
		# point de chute : 0,35 à 0,95 m autour, plutôt du côté du joueur (les pièces « sortent » vers lui)
		var an := atan2(vers_j.z, vers_j.x) + rng.randf_range(-1.9, 1.9)
		var d := rng.randf_range(0.35, 0.95)
		var dir := Vector3(cos(an), 0, sin(an))
		var p1 := centre + dir * d
		if espace != null:
			# jamais dans un mur : rayon horizontal depuis le centre, puis rayon vertical pour trouver le sol (marche, dalle)
			var h0 := centre + Vector3(0, 0.3, 0)
			var q := PhysicsRayQueryParameters3D.create(h0, h0 + dir * (d + 0.08))
			q.exclude = exclus
			var r := espace.intersect_ray(q)
			if not r.is_empty():
				p1 = centre + dir * maxf(0.12, h0.distance_to(r["position"]) - 0.1)
			var qv := PhysicsRayQueryParameters3D.create(p1 + Vector3(0, 0.6, 0), p1 - Vector3(0, 1.2, 0))
			qv.exclude = exclus
			var rv := espace.intersect_ray(qv)
			if not rv.is_empty() and absf(float(rv["position"].y) - sol0) < 0.5:
				p1.y = float(rv["position"].y)
		p1.y += EPAISSEUR * 0.5 + 0.002
		var duree := rng.randf_range(0.62, 0.92)
		var v0 := (p1 - p0) / duree + Vector3(0, 0.5 * GRAVITE * duree, 0)
		var m := MeshInstance3D.new()
		m.mesh = maillage()
		m.material_override = _materiau("piece")
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		m.global_position = p0
		_pieces.append({"noeud": m, "etat": "vol", "t": -rng.randf_range(0.0, 0.18), "p0": p0, "v0": v0, "p1": p1, "duree": duree,
			"axe": Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)).normalized(),
			"vitesse": rng.randf_range(10.0, 22.0), "lacet": rng.randf_range(0, TAU), "attente": rng.randf_range(0.12, 0.4)})

func _process(dt: float) -> void:
	if not _pret or joueur == null or not is_instance_valid(joueur):
		return
	var cam: Camera3D = joueur.get("camera")
	var cible := joueur.global_position + Vector3(0, 0.9, 0)
	var proche := Vector2(joueur.global_position.x - global_position.x, joueur.global_position.z - global_position.z).length() < aspiration \
		and absf(joueur.global_position.y - global_position.y) < 2.0
	var tous_poses := true
	for p in _pieces:
		if p["etat"] == "vol":
			tous_poses = false
	# corps : versement UNE fois, quand le joueur s'approche des pièces retombées ; coffre : déjà versé, aspiration d'office
	if not _verse and tous_poses and (deja_verse or proche) and not joueur.get("mort"):
		_verser()
	var i := 0
	while i < _pieces.size():
		var p: Dictionary = _pieces[i]
		var m: MeshInstance3D = p["noeud"]
		p["t"] = float(p["t"]) + dt
		var t: float = p["t"]
		match String(p["etat"]):
			"vol":
				if t < 0.0:
					i += 1
					continue
				m.visible = true
				if t >= float(p["duree"]):
					p["etat"] = "pose"
					p["t"] = 0.0
					m.global_position = p["p1"]
					m.global_basis = Basis(Vector3.UP, float(p["lacet"])) * Basis(Vector3.RIGHT, 0.08)
					if not _son_fait:
						_son_fait = true
						Sons.jouer_a(self, ["handleCoins", "handleCoins2"], p["p1"], -6.0)
				else:
					m.global_position = (p["p0"] as Vector3) + (p["v0"] as Vector3) * t + Vector3(0, -0.5 * GRAVITE * t * t, 0)
					m.global_basis = Basis((p["axe"] as Vector3), t * float(p["vitesse"]))
			"pose":
				if _verse and t > float(p["attente"]):
					p["etat"] = "aspire"
					p["t"] = 0.0
			"aspire":
				# accélération (ease-in) vers la poitrine du joueur : arrivée en ~0,35-0,5 s, petit saut au départ
				var a: Vector3 = cible - m.global_position
				var vit := 1.5 + 22.0 * t * t
				if a.length() < 0.25 or t > 1.2:
					m.queue_free()
					_pieces.remove_at(i)
					if _pieces.is_empty():
						Sons.jouer(self, ["handleCoins", "handleCoins2"], -4.0)
						_peut_partir()
					continue
				m.global_position += a.normalized() * minf(a.length(), vit * dt) + Vector3(0, 1.2 * dt * maxf(0.0, 0.25 - t) * 4.0, 0)
				m.global_basis = Basis(Vector3.UP, t * 18.0) * Basis(Vector3.RIGHT, 1.2)
		# éclat : une pièce en vol qui fait face à la caméra prend le ton Reflet (une image ou deux)
		var mat := _materiau("piece")
		if cam != null and String(p["etat"]) != "pose":
			var vers := (cam.global_position - m.global_position).normalized()
			if absf(m.global_basis.y.normalized().dot(vers)) > 0.86:
				mat = _materiau("reflet")
		if m.material_override != mat:
			m.material_override = mat
		i += 1

## Met les pièces dans le sac (une seule fois) ; repli sans boîte de dialogue : les objets aussi.
func _verser() -> void:
	if _verse:
		return
	_verse = true
	var n_or := int(contenu.get("pieces", 0))
	if deja_verse:
		if hud != null and n_or > 0:
			hud.avis("+ %d pièces" % n_or)
		return
	if joueur == null:
		return
	if n_or > 0:
		joueur.inventaire.ajouter("pieces", n_or)
		if hud != null:
			hud.avis("+ %d pièces" % n_or)
	if _inter == null:
		for id in objets:
			joueur.inventaire.ajouter(id, objets[id])
			if hud != null:
				hud.avis("+ %d %s" % [objets[id], joueur.inventaire.nom(id)])
		objets.clear()
		if _pieces.is_empty():
			Sons.jouer(self, ["handleCoins", "handleCoins2"], -4.0)

## Tests et captures : pièces encore visibles (en vol, posées ou aspirées) ; pièces versées au sac.
func pieces_visibles() -> int:
	return _pieces.size()

func versees() -> bool:
	return _verse

## Captures : fige la gerbe au temps `s` (s) depuis le jaillissement (pièces en vol ou posées).
func figer(s: float) -> void:
	for p in _pieces:
		p["t"] = float(p["t"]) + s
	_process(0.0)
	set_process(false)

## Tests : points de chute des pièces (repère monde), dans l'ordre du tirage.
func points_de_chute() -> Array[Vector3]:
	var r: Array[Vector3] = []
	for p in _pieces:
		r.append(p["p1"])
	return r
