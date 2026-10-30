#!/usr/bin/env python3
"""Enveloppes .tscn des armes Quaternius CC0 intégrées (branche armes/integration).

Chaque modèle de assets/modeles/armes/cc0_essai/ est remis à l'échelle autour du centre du poing (y = 0,03 : repère
commun des épées, +Y le long de la lame, +X tranchant) et reçoit les nœuds vides prise / garde / pointe lus par
mains.gd (tracé de lame) et CatalogueArmes. Les boucliers sont tournés pour le bras gauche (face peinte +X, poignées au
poing, repère de bouclier_nordique.glb) et reçoivent prise / umbo.
Usage :  python3 outils/generer_enveloppes_armes.py     (réécrit assets/modeles/armes/integrees/*.tscn)
Mesures des glb (étendue Y des matériaux « cuir » = fusée, « lame » = lame/tête) : outils/_mesure_armes.gd.
"""
import os
ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ICI, 'assets/modeles/armes/integrees/')
PRISE = 0.03
# id, glb, échelle (défauts relevés sur la planche armes_cc0 : dague minuscule, masses et marteaux trop petits),
# garde et pointe dans le repère du glb (avant échelle)
ARMES = [
	("epee_soldat", "01_sword", 1.0, (0, 0.175, 0), (0, 0.928, 0)),
	("sabre_pillard", "02_sword_2", 1.0, (0.01, 0.164, 0), (0.02, 0.928, 0)),
	("epee_doree", "03_sword_golden", 1.0, (0, 0.172, 0), (0, 0.921, 0)),
	("dague_acier", "04_dagger", 1.3, (0, 0.087, 0), (0.01, 0.351, 0)),           # 0,40 -> 0,52 m
	("claymore", "05_claymore", 1.0, (0, 0.245, 0), (0, 1.225, 0)),
	("hache_guerre", "06_axe", 1.0, (0.09, 0.29, 0), (0.12, 0.69, 0)),
	("hachette", "07_axe_small", 1.15, (0.11, 0.21, 0), (0.14, 0.50, 0)),        # 0,60 -> 0,69 m
	("marteau_guerre", "08_hammer_small", 1.3, (0.0, 0.30, 0), (0.0, 0.537, 0)),   # 0,65 -> 0,85 m
	("grand_marteau", "09_hammer_double", 1.25, (0.0, 0.45, 0), (0.0, 0.888, 0)),  # 1,10 -> 1,38 m
	("masse_cloutee", "10_club_mace", 1.35, (0.0, 0.30, 0), (0.0, 0.498, 0)),      # 0,60 -> 0,81 m
]
# boucliers : id, glb, centre (y) ; poignées du glb à z ~ -0,085 (dos), face peinte vers +Z
BOUCLIERS = [("bouclier_cercle", "11_shield_round", 0.03), ("ecu_chevalier", "12_shield_heater", 0.03)]


# RÉALISME (branche armes/realisme) : matériaux PS1 à projection boîte de EpeesLongues (fini les aplats « camouflage » des UV
# automatiques Quaternius). Clé = nom de surface du glb (« lame.3 ») ou nom court (« lame ») ; la claymore n'est pas remappée
# (refaite sur la branche combat/claymore_2mains).
LAME_Q = {"lame.0": "acier_q", "lame.3": "acier_fil", "fer": "fer", "cuir": "cuir"}   # lame.0 = plats, lame.3 = tranchants
MANCHE_Q = {"lame.0": "acier_q", "lame.3": "acier_fil", "cuir.2": "bois", "cuir.1": "cuir"}   # cuir.2 = fût, cuir.1 = lanières
REMAP = {
	"epee_soldat": LAME_Q, "sabre_pillard": LAME_Q, "dague_acier": LAME_Q,
	"epee_doree": {"or.0": "or_lame", "or.4": "or", "fer": "fer", "cuir": "cuir"},
	"hache_guerre": MANCHE_Q, "hachette": MANCHE_Q,
	"marteau_guerre": {"lame.0": "fer", "lame.3": "acier_fil", "cuir.2": "bois", "cuir.1": "cuir"},
	"grand_marteau": {"lame.0": "fer", "lame.3": "acier_fil", "cuir.2": "bois", "cuir.1": "cuir"},
}
REMAP_BOUCLIER = {"lame": "fer_rivete", "cuir": "planches"}


def f(v):
	return ('%.4f' % v).rstrip('0').rstrip('.') if abs(v) > 1e-9 else '0'


def tr(lignes, o):
	"""Transform3D du .tscn : base en LIGNES (format de Godot 4), puis origine."""
	return 'Transform3D(%s)' % ', '.join(f(x) for x in list(lignes) + list(o))


def ech(p, s):
	return (p[0] * s, PRISE + s * (p[1] - PRISE), p[2] * s)


ID = (1, 0, 0, 0, 1, 0, 0, 0, 1)


def scene(id_, glb, t_modele, reperes, remap=None):
	txt = '[gd_scene load_steps=2 format=3]\n\n'
	txt += '[ext_resource type="PackedScene" path="res://assets/modeles/armes/cc0_essai/%s.glb" id="1_glb"]\n\n' % glb
	txt += '[node name="%s" type="Node3D"]\n' % id_
	if remap:   # EpeesLongues.habiller : nom Blender -> matériau PS1
		txt += 'metadata/remap_materiaux = {%s}\n' % ', '.join('"%s": "%s"' % kv for kv in remap.items())
	txt += '\n'
	txt += '[node name="modele" parent="." instance=ExtResource("1_glb")]\ntransform = %s\n' % t_modele
	for nom, o in reperes:
		txt += '\n[node name="%s" type="Marker3D" parent="."]\ntransform = %s\n' % (nom, tr(ID, o))
	return txt


os.makedirs(D, exist_ok=True)
for id_, glb, s, g, p in ARMES:
	t = tr((s, 0, 0, 0, s, 0, 0, 0, s), (0, PRISE * (1 - s), 0))
	open(D + id_ + '.tscn', 'w').write(scene(id_, glb, t, [("prise", (0, PRISE, 0)), ("garde", ech(g, s)), ("pointe", ech(p, s))], REMAP.get(id_)))
for id_, glb, cy in BOUCLIERS:
	# rotation +90° autour de Y : x' = z, z' = -x (la face +Z du glb devient +X)
	t = tr((0, 0, 1, 0, 1, 0, -1, 0, 0), (0.085, -cy, 0))
	# dos, cerclage et clous nommés « lame » dans le glb : fer riveté ; face et dos « cuir » : planches de bois veiné
	open(D + id_ + '.tscn', 'w').write(scene(id_, glb, t, [("prise", (0, 0, 0)), ("umbo", (0.19, 0, 0))], REMAP_BOUCLIER))
print('enveloppes :', len(ARMES) + len(BOUCLIERS), '->', D)
