# Extrait la MAIN GAUCHE du maillage de base MakeHuman (hm08, base.obj de MPFB2, CC0 1.0 : en-tête du fichier et
# LICENSE.md du dépôt github.com/makehumancommunity/mpfb2) avec ses poids Mixamo (rigs/standard/weights.mixamo.json, CC0)
# et la position des os de la main (rig.mixamo.json) -> sources_blender/mpfb/main_gauche_mh.json, lu par
# main_humaine.py (avant_bras_runes.py). Python seul (pas Blender) :
#   python3 extraire_main_mpfb.py <dossier src/mpfb/data de mpfb2>
# Repère de sortie : Blender (Z en haut, mètres) : obj (x, y, z) -> (0,1 x, -0,1 z, 0,1 y).
import json, os, sys

data = sys.argv[1]
ici = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POIDS = json.load(open(os.path.join(data, "rigs/standard/weights.mixamo.json")))["weights"]
RIG = json.load(open(os.path.join(data, "rigs/standard/rig.mixamo.json")))["bones"]
NOMS = {"LeftHand": "hand_l"}
for mh, nous in (("Thumb", "thumb"), ("Index", "index"), ("Middle", "middle"), ("Ring", "ring"), ("Pinky", "pinky")):
    for k in (1, 2, 3):
        NOMS["LeftHand%s%d" % (mh, k)] = "%s_0%d_l" % (nous, k)
v, faces, groupe = [], [], ""
for ligne in open(os.path.join(data, "3dobjs/base.obj")):
    if ligne.startswith("v "):
        x, y, z = map(float, ligne.split()[1:4])
        v.append((0.1 * x, -0.1 * z, 0.1 * y))
    elif ligne.startswith("g "):
        groupe = ligne.split()[1]
    elif ligne.startswith("f ") and groupe == "body":
        faces.append([int(t.split("/")[0]) - 1 for t in ligne.split()[1:]])
w = {}
for os_mh, liste in POIDS.items():
    court = os_mh.split(":")[-1]
    for i, p in liste:
        w.setdefault(i, {})[court] = w.setdefault(i, {}).get(court, 0.0) + p
def main(i):
    # part de la main (poids MakeHuman non normalisés : rapportés au total du sommet)
    tot = sum(w.get(i, {}).values())
    return sum(p for o, p in w.get(i, {}).items() if o in NOMS) / tot if tot > 0 else 0.0
garde = [f for f in faces if all(main(i) >= 0.5 for i in f)]
idx = sorted({i for f in garde for i in f})
ren = {o: n for n, o in enumerate(idx)}
sommets, poids = [], []
for i in idx:
    sommets.append([round(c, 6) for c in v[i]])
    tot = sum(w[i].values())
    pp = {NOMS[o]: p / tot for o, p in w[i].items() if o in NOMS}
    reste = 1.0 - sum(pp.values())
    if reste > 1e-4:
        pp["hand_l"] = pp.get("hand_l", 0.0) + reste      # part de l'avant-bras au bord du poignet (caché sous le revers)
    poids.append({k: round(p, 4) for k, p in pp.items() if p > 1e-4})
# os : centres des cubes d'articulation du maillage (basemesh_vertex_groups.json), même repère que les sommets
G = json.load(open(os.path.join(data, "mesh_metadata/basemesh_vertex_groups.json")))
def cube(nom):
    pts = [v[i] for a, b in G[nom] for i in range(a, b + 1)]
    return [round(sum(p[k] for p in pts) / len(pts), 6) for k in range(3)]
os_ = {"hand_l": [cube("joint-l-hand"), cube("joint-l-finger-3-1")]}
for n_mh, nous in ((1, "thumb"), (2, "index"), (3, "middle"), (4, "ring"), (5, "pinky")):
    for k in (1, 2, 3):
        os_["%s_0%d_l" % (nous, k)] = [cube("joint-l-finger-%d-%d" % (n_mh, k)), cube("joint-l-finger-%d-%d" % (n_mh, k + 1))]
out = {"licence": "CC0 1.0 (MakeHuman hm08 base.obj, weights/rig mixamo de MPFB2)", "sommets": sommets,
       "faces": [[ren[i] for i in f] for f in garde], "poids": poids, "os": os_}
f = os.path.join(ici, "mpfb", "main_gauche_mh.json")
json.dump(out, open(f, "w"))
print("MAIN MH", len(sommets), "sommets", len(garde), "faces ->", f)
