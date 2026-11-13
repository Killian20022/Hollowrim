"""Mesure du DÉCOLLEMENT des armures portées par rapport au corps habillé du héros (pose de repos).
  blender -b --python mesure_epaisseur.py -- <sortie.json> <id> [<id> ...]   (ids de assets/modeles/armures/porte/ ou chausses:<famille>)
Pour chaque sommet de la pièce : distance (mm) au plus proche point du héros visible (peau, tunique, pantalon, bottes, brassards).
Par zone (torse, epaules, bras, avant_bras, cuisses, tibias, casque) : médiane, p90, max. Les sommets des ornements (éclats) gonflent le max ;
la médiane et le p90 disent l'épaisseur réelle de la coque.
v3 (2026-11-12) : « coque » = ÉPAISSEUR propre des plaques/pans : depuis chaque sommet, rayon vers l'intérieur (-normale) jusqu'à la
face suivante de la MÊME pièce (dos de la plaque) ; médiane / p90 en mm des rayons qui touchent à moins de 40 mm (épaisseur visible
d'un bord, indépendante du jeu au corps)."""
import bpy, sys, os, json
import numpy as np
from mathutils.bvhtree import BVHTree
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, ".."))
import armures_lib as L

argv = sys.argv[sys.argv.index("--") + 1:]
sortie, ids = argv[0], argv[1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
corps = L.bvh_de((), ("peau", "tunique", "pantalon", "bottes", "brassards"))


def zone(p):
    x, y, z = abs(p[0]), p[1], p[2]
    if y > 1.55 and x < 0.16:
        return "casque"
    if y > 1.28 and x > 0.17:
        if x < 0.30:
            return "epaules"
        return "bras" if x < 0.47 else "avant_bras"
    if 0.95 < y <= 1.55 and x <= 0.2:
        return "torse"
    if 0.5 < y <= 0.95:
        return "cuisses"
    if 0.08 < y <= 0.5:
        return "tibias"
    return "autre"


res = {}
for ident in ids:
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    if ident.startswith("chausses:"):
        f = os.path.join(L.ROOT, "assets/modeles/armures/chausses", ident.split(":")[1] + ".glb")
    else:
        f = os.path.join(L.PORTE, ident + ".glb")
    bpy.ops.import_scene.gltf(filepath=f)
    zs = {}
    ep = {}
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        dg = bpy.context.evaluated_depsgraph_get()
        me = o.evaluated_get(dg).to_mesh()
        mw = o.matrix_world
        bv = BVHTree.FromPolygons([mw @ v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
        for v in me.vertices:
            w = mw @ v.co
            nn = (mw.to_3x3() @ v.normal).normalized()
            h = bv.ray_cast(w - nn * 0.0004, -nn, 0.04)
            if h[0] is not None:
                ep.setdefault(zone(L.G(w)), []).append(h[3] * 1000.0 + 0.4)
        for v in me.vertices:
            w = o.matrix_world @ v.co
            hit = corps.find_nearest(w, 0.5)
            d = hit[3] * 1000.0 if hit[0] is not None else 500.0
            zs.setdefault(zone(L.G(w)), []).append(d)
    r = {}
    for k, ds in zs.items():
        a = np.array(ds)
        r[k] = dict(n=len(a), med=round(float(np.median(a)), 1), p90=round(float(np.percentile(a, 90)), 1), max=round(float(a.max()), 1))
        if k in ep and len(ep[k]) > 5:
            e = np.array(ep[k])
            r[k]["coque_med"] = round(float(np.median(e)), 1)
            r[k]["coque_p90"] = round(float(np.percentile(e, 90)), 1)
    for k in [k for k in r if r[k]["n"] < 40 or r[k]["med"] >= 400]:
        del r[k]
    res[ident] = r
    print("MESURE", ident, json.dumps(r))
json.dump(res, open(sortie, "w"), indent=1)
