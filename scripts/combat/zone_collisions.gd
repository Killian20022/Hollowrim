class_name ZoneCollisions
extends Node3D
## Zone de collisions de la scène de test du combat (prompt §15) : une rangée de « postes », chacun un cas difficile pour
## le tracé de lame. Le joueur se place sur le poste (placer(nom)), regard vers −Z ; tout ce qui compte est à moins de
## 3 m devant lui et les postes sont espacés de ECART m (hors de portée l'un de l'autre).
##   mur_fin      mur de 5 cm à 0,9 m, mannequin derrière à 1,6 m          → la lame s'arrête sur le mur, rien derrière
##   coin         angle de deux murs à ~1 m, mannequin dans l'angle mort  → arrêt sur le coin, rien derrière
##   porte        mur à 1,1 m percé d'une porte de 1,2 m, mannequin dans    → coup vertical / estoc : touché par la porte ;
##                l'embrasure à 1,9 m                                       coup horizontal : arrêté par le chambranle
##   serres       trois mannequins côte à côte à 1,4 m (0,62 m d'écart)   → 2 touchés au plus (multi_cibles), une fois chacun
##   derriere     mur à gauche, mannequin caché derrière lui              → arrêt sur le mur, mannequin intact
##   poteau       cible très fine (poteau de 8 cm) à 1 m                  → touchée par chaque coup qui la balaie
##   loin         mannequin à 2,7 m (hors de portée)                      → rien
##   draugrs      deux draugrs serrés (IA coupée ou active : `draugr`)    → vrais ennemis (capsules), une touche chacun
## Les cibles des postes sont rangées dans `cibles[nom]` (mannequins, poteau, draugrs).

const MANNEQUIN := preload("res://scripts/combat/mannequin.gd")
const ECART := 7.0
const POSTES := ["mur_fin", "coin", "porte", "serres", "derriere", "poteau", "loin", "draugrs"]

var joueur: Node3D
## Mode des draugrs du poste « draugrs » : "fige" (IA coupée, défaut), "actif" ou "aucun".
var mode_draugr := "fige"
## nom du poste -> Array de cibles (Node3D)
var cibles := {}
var murs := {}
var _roche: Material
var _bois: Material

## Position monde du poste (là où se tient le joueur).
func poste(nom: String) -> Vector3:
	return global_transform * Vector3(0, 0, -ECART * POSTES.find(nom))

func _ready() -> void:
	_roche = Palette.materiau(Palette.tex("roche", Palette.ROCHE, 4, 0.5), Vector2(2, 2))
	_bois = Palette.materiau(Palette.tex("bois_mannequin", ["#2a1c10", "#3b2a18", "#4f3a22", "#5e4a30"], 4, 0.6), Vector2(1, 3))
	for nom in POSTES:
		var o := Vector3(0, 0, -ECART * POSTES.find(nom))
		cibles[nom] = []
		murs[nom] = []
		_panneau(nom, o + Vector3(-1.6, 2.4, -0.5))
		# repère au sol : où se tenir
		_boite(nom, o + Vector3(0, 0.01, 0), Vector3(0.5, 0.02, 0.5), _bois, false)
		match nom:
			"mur_fin":
				_mur(nom, o + Vector3(0, 1.3, -0.9), Vector3(3.0, 2.6, 0.05))
				_mannequin(nom, o + Vector3(0, 0, -1.6))
			"coin":
				# deux murs en V, la pointe du V vers le joueur à ~0,95 m
				_mur(nom, o + Vector3(-0.55, 1.3, -1.5), Vector3(1.6, 2.6, 0.1), 45.0)
				_mur(nom, o + Vector3(0.55, 1.3, -1.5), Vector3(1.6, 2.6, 0.1), -45.0)
				_mannequin(nom, o + Vector3(0, 0, -2.1))
			"porte":
				_mur(nom, o + Vector3(-1.35, 1.6, -1.1), Vector3(1.5, 3.2, 0.12))
				_mur(nom, o + Vector3(1.35, 1.6, -1.1), Vector3(1.5, 3.2, 0.12))
				_mur(nom, o + Vector3(0, 3.0, -1.1), Vector3(1.2, 0.4, 0.12))   # linteau (porte de 1,2 m × 2,8 m)
				_mannequin(nom, o + Vector3(0, 0, -1.9))
			"serres":
				for x in [-0.62, 0.0, 0.62]:
					_mannequin(nom, o + Vector3(x, 0, -1.4))
			"derriere":
				_mur(nom, o + Vector3(-0.75, 1.3, -0.95), Vector3(1.3, 2.6, 0.1))
				_mannequin(nom, o + Vector3(-0.6, 0, -1.7))
			"poteau":
				var p := CiblePoteau.new()
				p.position = o + Vector3(0.15, 0, -1.0)
				add_child(p)
				cibles[nom].append(p)
			"loin":
				_mannequin(nom, o + Vector3(0, 0, -2.7))
			"draugrs":
				if mode_draugr != "aucun" and get_parent() != null and get_parent().has_method("creer_draugr"):
					for x in [-0.45, 0.45]:
						var d: CharacterBody3D = get_parent().creer_draugr(global_transform * (o + Vector3(x, 0, -1.5)), mode_draugr != "actif")
						d.rotation.y = 0.0   # face au joueur (+Z)
						d.ident = "draugr_zone_%d" % cibles[nom].size()
						cibles[nom].append(d)

func _mannequin(nom: String, p: Vector3) -> void:
	var m := StaticBody3D.new()
	m.set_script(MANNEQUIN)
	m.position = p
	add_child(m)
	m.set("joueur", joueur)
	m.set("chiffres", false)
	cibles[nom].append(m)

func _mur(nom: String, p: Vector3, taille: Vector3, lacet := 0.0) -> void:
	murs[nom].append(_boite(nom, p, taille, _roche, true, lacet))

func _boite(_nom: String, p: Vector3, taille: Vector3, m: Material, solide: bool, lacet := 0.0) -> Node3D:
	var b: Node3D = StaticBody3D.new() if solide else Node3D.new()
	b.position = p
	b.rotation.y = deg_to_rad(lacet)
	if solide:
		var f := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille
		f.shape = bs
		b.add_child(f)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = m
	b.add_child(mi)
	add_child(b)
	return b

func _panneau(nom: String, p: Vector3) -> void:
	var l := Label3D.new()
	l.text = nom
	l.font = Palette.police()
	l.font_size = 28
	l.pixel_size = 0.006
	l.outline_size = 6
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = p
	add_child(l)

## Remet les cibles à neuf (posture, journal) : aucun finisher ouvert par le cas précédent.
func remettre() -> void:
	for nom in cibles:
		for c in cibles[nom]:
			if not is_instance_valid(c):
				continue
			if c is CiblePoteau:
				(c as CiblePoteau).coups.clear()
			elif c.get("coups") != null:
				c.coups.clear()
			var cb = c.get("combat")
			if cb is CombatEnnemi:
				cb.posture = cb.profil.posture_max
				cb.etourdi = 0.0
				cb.fenetre_parade = 0.0

## Nombre de coups reçus par une cible (mannequin, poteau : journal ; draugr : compteur posé par le test).
static func nb_coups(c: Node) -> int:
	var j = c.get("coups")
	return (j as Array).size() if j is Array else 0


## Cible très fine (poteau de bois de 8 cm de diamètre, 2 m) : groupe « cibles_combat », journal des coups.
class CiblePoteau extends StaticBody3D:
	var coups: Array[Dictionary] = []
	# barre de vie du HUD (joueur.ennemi_vise)
	var vie := 100.0
	var vie_max := 100.0
	var nom_affiche := "Poteau"
	func _ready() -> void:
		add_to_group("cibles_combat")
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.04
		cyl.height = 2.0
		cs.shape = cyl
		cs.position.y = 1.0
		add_child(cs)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.04
		cm.height = 2.0
		cm.radial_segments = 8
		mi.mesh = cm
		mi.position.y = 1.0
		mi.material_override = Palette.materiau(Palette.tex("bois_mannequin", ["#2a1c10", "#3b2a18", "#4f3a22", "#5e4a30"], 4, 0.6), Vector2(1, 3))
		add_child(mi)
	func vivant() -> bool:
		return true
	func recevoir_coup(degats: float, _origine: Vector3, puissant := false, info: Dictionary = {}) -> String:
		coups.append({"degats": degats, "puissant": puissant, "info": info})
		return "touche"
