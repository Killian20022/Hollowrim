# Chausses HD des familles « gardiens » et « braise » (uniques) : même maillage que les chausses de fer_acier (pantalon du héros, mêmes
# poids), texture 512² cuite en 3D. gardiens = cuir noir bleuté matelassé, givre aux genoux et en bas ; braise = écailles de cuir cendré
# à fentes de braise. Écrit SEULEMENT assets/modeles/armures/chausses/gardiens.glb et braise.glb.
#   blender.exe -b --python sources_blender/armures/uniques/chausses_uniques.py
import bpy, sys, os, importlib
import numpy as np
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
sys.path.insert(1, os.path.join(ICI, ".."))
sys.path.insert(2, os.path.join(ICI, "..", "lourdes"))
sys.path.insert(3, os.path.join(ICI, "..", "fer_acier"))
import armures_lib as L
import hd as H
import decor_uniques as DU
importlib.reload(L); importlib.reload(H); importlib.reload(DU)

CHAUSSES = os.path.join(L.ROOT, "assets", "modeles", "armures", "chausses")
U = 0.0086          # m par unité de peinture (même densité que la cuirasse HD)


def coords(P):
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    s = np.where(x >= 0, 1.0, -1.0)
    a = np.arctan2(x - s * 0.11, z - 0.02)
    return a * 0.07 / U + (s > 0) * 200.0, y / U


def gardiens(P, N, pa, bd):
    X, Y = coords(P)
    rgb, bri, h = H.cuir(DU.CUIR_NOIR, 501, base=0.46, use=0.5)(X, Y, X * 0, Y * 0)
    # matelassage en losanges, coutures bleu acier
    d1 = np.abs(np.mod(X + Y, 7.0) - 3.5); d2 = np.abs(np.mod(X - Y, 7.0) - 3.5)
    pique = np.minimum(d1, d2)
    rgb = rgb * (0.60 + 0.40 * np.clip(pique / 1.2, 0, 1))[:, None]
    fil = (pique < 0.25) & (np.mod(X * 1.3, 1.0) < 0.55)
    rgb[fil] = H.rampe(DU.ACIER_GIVRE, np.full(fil.sum(), 0.45))
    # teinte bleutée des gardiens
    rgb = rgb * np.array([0.92, 1.0, 1.12])
    # givre : bas des jambes et genoux (devant), plaques de bruit, cristaux fins
    y, z = P[:, 1], P[:, 2]
    n = H.fbm(X, Y, 507, oct=((8, 0.5), (2.6, 0.3), (0.8, 0.2)))
    bas = np.clip((0.40 - y) / 0.30, 0, 1)
    genou = np.exp(-((y - 0.5) / 0.07) ** 2) * (z > 0.03)
    k = H.lisse(0.52, 0.66, n + 0.25 * bas + 0.2 * genou - 0.25) * 0.9
    fr = H.rampe(["#8fa6b8", "#b4c8d6", "#d5e3ec", "#eef5f9"], np.clip(0.35 + 0.5 * n, 0, 1))
    rgb = rgb * (1 - k[:, None]) + fr * k[:, None]
    bri = bri * (1 - k)
    rgb = rgb * (0.55 + 0.45 * np.clip(bd / 0.012, 0, 1))[:, None]
    return np.concatenate([np.clip(rgb, 0, 1), np.clip(bri, 0, 1)[:, None]], 1)


def braise(P, N, pa, bd):
    X, Y = coords(P)
    rgb, bri, h = DU.ecailles(DU.CENDRE, 511, tip=2.6, base=0.5, braise=1.0, brillant=0.18)(X, Y, X * 0, Y * 0)
    rgb = rgb * (0.55 + 0.45 * np.clip(bd / 0.012, 0, 1))[:, None]
    return np.concatenate([np.clip(rgb, 0, 1), np.clip(bri, 0, 1)[:, None]], 1)


ARM = L.scene_base()
o = L.copie("pantalon", "chausses", lambda c, n: c.y < 0.93)
L.ajuster(o, L.bvh_de(["pantalon"]), lambda p: 0.004, lissage=1, force=0.2)
L.ecrire_poids(o, L.normaliser(L.poids(o)))
L.lisser_normales(o)
L.uv_auto(o, 0.01, 80)
print("PIECE chausses : %d triangles" % L.nb_tris(o))
for fam, fn, mat in (("gardiens", gardiens, "cuir"), ("braise", braise, "cuir.braise")):
    c = o.copy(); c.data = o.data.copy()
    bpy.context.scene.collection.objects.link(c)
    c.name = "chausses_" + fam
    img = L.cuire(c, fn, 512, "chausses_" + fam)
    c.data.materials.clear()
    c.data.materials.append(L.materiau(mat, img))
    L.exporter(c, ARM, fam, None, CHAUSSES)
    print("EXPORT chausses", fam)
