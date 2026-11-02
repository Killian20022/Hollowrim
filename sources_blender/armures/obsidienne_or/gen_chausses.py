# Chausses HD des ensembles OBSIDIENNE et OR (portées d'office avec la cuirasse : ArmureVisible.CHAUSSES_PAR_TORSE).
#   blender.exe -b --python sources_blender/armures/obsidienne_or/gen_chausses.py
# Même base que les chausses de l'agent X (legeres/gen_legeres.py -- chausses) : pantalon du héros copié (mêmes poids, aucune
# traversée possible avec ce qu'il remplace), un peu gonflé, coupé sous la ceinture ; texture 512² cuite (armures_lib.cuire).
#   obsidienne : mailles de fer noirci, cuissards d'obsidienne taillée sur le devant des cuisses (une fissure de magma) ;
#   or         : laine bleu nuit piquée, cuissards d'or patiné à entrelacs sur le devant des cuisses (planche : cuisses dorées).
# Un seul matériau par chausses : « obsidienne » / « or.patine » ; l'alpha (brillance) éteint le métal sur la maille et la laine.
import bpy, sys, os
import numpy as np
sys.dont_write_bytecode = True
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
sys.path.insert(0, os.path.join(ICI, ".."))
import importlib
import armures_lib as L
import hd
import peintres as PE
for m in (L, hd, PE):
    importlib.reload(m)

CHAUSSES = os.path.join(L.ROOT, "assets", "modeles", "armures", "chausses")
ARM = L.scene_base()


def _D(P, N, bd, mat):
    n = len(P)
    return {"P": P, "N": N, "mat": np.array([mat] * n), "uv": np.zeros((n, 2)), "bord": bd, "ao": np.ones(n), "piece": "chausses"}


def cuissard(P, N):
    """Plaque du devant de la cuisse (y 0,52-0,80, face avant), arrondie, une genouillère ébauchée sous les tassettes."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    cx = np.sign(x) * 0.105
    a = np.arctan2(x - cx, z - 0.01)
    return (y > 0.52) & (y < 0.80) & (np.abs(a) < 1.15), np.abs(a), y


def obsidienne(P, N, pa, bd):
    D = _D(P, N, bd, "fer.maille")
    out = PE.maille(D, PE.FER_NOIR, 0.38, 141)
    m, a, y = cuissard(P, N)
    if m.any():
        Do = {k: (v[m] if isinstance(v, np.ndarray) else v) for k, v in _D(P, N, bd, "obsidienne").items()}
        Do["piece"] = "chausses"
        o = PE.obsidienne(Do, g=143)
        # fissure de magma sur la cuisse gauche seulement (localisée)
        bordp = np.minimum(np.abs(a[m] - 1.15) * 0.1, np.minimum(np.abs(y[m] - 0.52), np.abs(y[m] - 0.80)))
        o[bordp < 0.003, :3] = o[bordp < 0.003, :3] * 0.4 + 0.18
        o[(bordp >= 0.003) & (bordp < 0.006), :3] *= 0.5
        out[m] = o
    out[:, 3] *= 0.8
    return out


def or_(P, N, pa, bd):
    D = _D(P, N, bd, "tissu.bleu")
    out = PE.tissu_bleu(D)
    out[:, 3] = 0.05
    m, a, y = cuissard(P, N)
    if m.any():
        Do = {k: (v[m] if isinstance(v, np.ndarray) else v) for k, v in _D(P, N, bd, "or.patine").items()}
        # bord du cuissard (distance angulaire / verticale au contour) -> bourrelet clair et filet sombre de l'or patiné
        bordp = np.minimum(np.abs(a[m] - 1.15) * 0.1, np.minimum(np.abs(y[m] - 0.52), np.abs(y[m] - 0.80)))
        Do["bord"] = bordp
        o = PE.or_patine(Do, g=147)
        out[m] = o
    return out


def main():
    o = L.copie("pantalon", "chausses", lambda c, n: c.y < 0.93)
    bvh = L.bvh_de(["pantalon"])
    L.ajuster(o, bvh, lambda p: 0.005, lissage=1, force=0.2)
    pw = L.poids(o)
    L.ecrire_poids(o, L.normaliser(pw))
    L.lisser_normales(o)
    print("PIECE chausses : %d triangles" % L.nb_tris(o))
    L.uv_auto(o, 0.01, 80)
    for fam, nom_mat, fn in (("obsidienne", "obsidienne", obsidienne), ("or", "or.patine", or_)):
        c = o.copy()
        c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        c.name = "chausses_" + fam
        img = L.cuire(c, fn, 512, "chausses_" + fam)
        c.data.materials.clear()
        c.data.materials.append(L.materiau(nom_mat, img))
        L.exporter(c, ARM, fam, None, CHAUSSES)
        print("EXPORT chausses", fam)


main()
