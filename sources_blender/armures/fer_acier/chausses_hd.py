# Chausses HD des familles « fer » et « acier » (planche de référence : jambes en cuir brun sous les pans) :
# même maillage que les chausses de l'agent X (pantalon du héros, mêmes poids : legeres/gen_legeres.py -- chausses), texture
# 512² cuite en 3D : acier = cuir brun matelassé (piqûres en losanges, coutures), fer = laine brune grossière + pièces de cuir
# aux genoux. Écrit SEULEMENT assets/modeles/armures/chausses/fer.glb et acier.glb.
#   blender.exe -b --python sources_blender/armures/fer_acier/chausses_hd.py
import bpy, sys, os, importlib
import numpy as np
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
sys.path.insert(1, os.path.join(ICI, ".."))
import armures_lib as L
import hd as H
importlib.reload(L); importlib.reload(H)

CHAUSSES = os.path.join(L.ROOT, "assets", "modeles", "armures", "chausses")
U = 0.0086          # m par unité de peinture (même densité que la cuirasse HD)


def coords(P):
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    s = np.where(x >= 0, 1.0, -1.0)
    a = np.arctan2(x - s * 0.11, z - 0.02)
    return a * 0.07 / U + (s > 0) * 200.0, y / U


def matelasse(P, N, pa, bd):
    X, Y = coords(P)
    rgb, bri, h = H.cuir(H.CUIR, 401, base=0.40, use=0.6)(X, Y, X * 0, Y * 0)
    d1 = np.abs(np.mod(X + Y, 7.0) - 3.5); d2 = np.abs(np.mod(X - Y, 7.0) - 3.5)
    pique = np.minimum(d1, d2)
    rgb = rgb * (0.62 + 0.38 * np.clip(pique / 1.2, 0, 1))[:, None] * (0.92 + 0.12 * np.clip(np.minimum(3.5 - d1, 3.5 - d2) / 3.5, 0, 1))[:, None]
    fil = (pique < 0.25) & (np.mod(X * 1.3, 1.0) < 0.55)
    rgb[fil] = H.rampe(["#5a4733", "#7a6247"], np.full(fil.sum(), 0.5))
    rgb = rgb * (0.55 + 0.45 * np.clip(bd / 0.012, 0, 1))[:, None]
    return np.concatenate([rgb, np.clip(bri, 0, 1)[:, None]], 1)


def laine(P, N, pa, bd):
    X, Y = coords(P)
    n = H.fbm(X, Y, 411, oct=((6, 0.4), (2, 0.35), (0.7, 0.25)))
    trame = H.bruit(X * 3.0, Y * 0.6, 1.0, 413) * 0.5 + H.bruit(X * 0.6, Y * 3.0, 1.0, 414) * 0.5
    t = 0.42 + (n - 0.5) * 0.35 + (trame - 0.5) * 0.18
    rgb = H.rampe(["#140f0b", "#1f1812", "#2b221a", "#382d22", "#463a2c", "#554737", "#655543"], t)
    bri = np.full(len(P), 0.05)
    # pièces de cuir cousues aux genoux (devant, 0,42-0,62 m)
    y, z = P[:, 1], P[:, 2]
    gen = (y > 0.42) & (y < 0.62) & (z > 0.03)
    if gen.any():
        c, b, _ = H.cuir(H.CUIR, 415, base=0.36)(X[gen], Y[gen], X[gen] * 0, Y[gen] * 0)
        bord = (np.abs(y[gen] - 0.425) < 0.006) | (np.abs(y[gen] - 0.615) < 0.006)
        c[bord] *= 0.6
        rgb[gen] = c; bri[gen] = b
    rgb = rgb * (0.55 + 0.45 * np.clip(bd / 0.012, 0, 1))[:, None]
    return np.concatenate([rgb, bri[:, None]], 1)


ARM = L.scene_base()
o = L.copie("pantalon", "chausses", lambda c, n: c.y < 0.93)
L.ajuster(o, L.bvh_de(["pantalon"]), lambda p: 0.004, lissage=1, force=0.2)
L.ecrire_poids(o, L.normaliser(L.poids(o)))
L.lisser_normales(o)
L.uv_auto(o, 0.01, 80)
print("PIECE chausses : %d triangles" % L.nb_tris(o))
for fam, fn in (("acier", matelasse), ("fer", laine)):
    c = o.copy(); c.data = o.data.copy()
    bpy.context.scene.collection.objects.link(c)
    c.name = "chausses_" + fam
    img = L.cuire(c, fn, 512, "chausses_" + fam)
    c.data.materials.clear()
    c.data.materials.append(L.materiau("cuir", img))
    L.exporter(c, ARM, fam, None, CHAUSSES)
    print("EXPORT chausses", fam)
