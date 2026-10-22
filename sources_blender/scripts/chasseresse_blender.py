# Chasseresse nordique : passe BLENDER (revers et ourlets modelés + touffes de col + bake du relief).
#   blender.exe -b --python chasseresse_blender.py -- <dossier_projet> [homme]
# Entrées  : sources_blender/chasseresse/{tunique,brassards,cape,mante}.obj (+ os.json) exportés par outils/dump_chasseresse.gd
#            (repère Godot, Y haut : on travaille dans ce repère tel quel, l'export glb ne le tourne pas).
# Sorties  : assets/persos/chasseresse/blender/revers.glb  (4 maillages : jupe, manches, cape, col ; normales sortantes, UV dans l'atlas
#            des accessoires, SANS poids : le code Godot copie les poids du sommet le plus proche de la pièce habillée)
#            assets/persos/chasseresse/blender/relief_bl.png (région 64 x 48 de l'atlas, relief CUIT puis QUANTIFIÉ en palette)
#            sources_blender/chasseresse/chasseresse_revers.blend (+ planches de bake)
# Principe  : pièces modélisées par modules (patron de cuir, lamelle de manchette, lame de fourrure, segment d'ourlet) ; UV identiques
#            pour toutes les instances. Pour le bake, chaque module existe en version LÉGÈRE (livrée) et en version DÉTAILLÉE (maillage
#            dense, relief : grain, coutures, plis, brins) ; Cycles cuit AO + pointiness (cavité) du détaillé vers le léger, puis le
#            tout est quantifié dans la palette du perso (aplats, 2-4 tons, arêtes claires, creux sombres). Jamais de normal map.
import bpy, bmesh, math, sys, json, os, random
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = argv[0] if argv else "C:/Users/lopezk19/Jeux/nordique_pb_chasseresse"
HOMME = "homme" in argv
PRE = "homme_" if HOMME else ""
SRC = ROOT + "/sources_blender/chasseresse/"
OUT = ROOT + "/assets/persos/chasseresse/blender/"
os.makedirs(OUT, exist_ok=True)
random.seed(7)
rng = np.random.default_rng(7)

# ------------------------------------------------------------------------------------------------ feuille de textures (texels)
SHEET_W, SHEET_H = 64, 48
ATLAS_X0, ATLAS_Y0, ATLAS = 136, 128, 256        # position de la feuille dans l'atlas des accessoires (256 x 256)
TPM = 128.0                                       # texels par mètre
MOD = {                                           # nom: (x, y, largeur, hauteur) en texels de la feuille
    "tabA": (0, 0, 12, 20), "tabB": (12, 0, 12, 20),
    "manch": (24, 0, 6, 10),
    "touffe0": (32, 0, 6, 12), "touffe1": (38, 0, 6, 12), "touffe2": (44, 0, 6, 12),
    "ourlet": (0, 24, 24, 12),
}

# ------------------------------------------------------------------------------------------------ outils géométrie
def load_obj(nom):
    vs, fs = [], []
    for l in open(SRC + PRE + nom + ".obj"):
        p = l.split()
        if not p:
            continue
        if p[0] == "v":
            vs.append(Vector((float(p[1]), float(p[2]), float(p[3]))))
        elif p[0] == "f":
            fs.append([int(x) - 1 for x in p[1:4]])
    return vs, fs

def bvh_de(nom):
    vs, fs = load_obj(nom)
    return BVHTree.FromPolygons([tuple(v) for v in vs], fs), vs, fs

class Maillage:
    """Sommets + triangles + UV (texels de la feuille). Les triangles sont orientés vers le côté `dehors`."""
    def __init__(s, nom):
        s.nom = nom; s.v = []; s.uv = []; s.t = []

    def tri(s, pts, uvs, dehors):
        a, b, c = [Vector(p) for p in pts]
        n = (b - a).cross(c - a)
        if n.length < 1e-9:
            return
        ordre = (0, 1, 2) if n.dot(dehors) >= 0 else (0, 2, 1)
        base = len(s.v)
        for k in ordre:
            s.v.append([a, b, c][k]); s.uv.append(uvs[k])
        s.t.append((base, base + 1, base + 2))

    def quad(s, p, uvs, dehors):
        s.tri((p[0], p[1], p[2]), (uvs[0], uvs[1], uvs[2]), dehors)
        s.tri((p[0], p[2], p[3]), (uvs[0], uvs[2], uvs[3]), dehors)

def uv_atlas(u, v):
    return ((ATLAS_X0 + u) / ATLAS, 1.0 - (ATLAS_Y0 + v) / ATLAS)

def uv_feuille(u, v):
    return (u / SHEET_W, 1.0 - v / SHEET_H)

def vers_blender(m, uvf):
    me = bpy.data.meshes.new(m.nom)
    # sommets non partagés (une face = 3 sommets) : normales franches, UV propres
    me.from_pydata([tuple(p) for p in m.v], [], m.t)
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            uvl.data[li].uv = uvf(*m.uv[vi])
    for poly in me.polygons:
        poly.use_smooth = False
    ob = bpy.data.objects.new(m.nom, me)
    bpy.context.collection.objects.link(ob)
    return ob

def module_uv(nom, fu, fv):
    x, y, w, h = MOD[nom]
    return (x + fu * w, y + fv * h)

def decalages():
    """Écarts du corps (femme = 0) : hauteur de l'ourlet de jupe, bout des manches, haut de la mante."""
    t, _, _ = None, None, None
    vt, _ = load_obj("tunique")
    vm, _ = load_obj("mante")
    return min(v.y for v in vt) - 0.606, max(abs(v.x) for v in vt) - 0.585, max(v.y for v in vm) - 1.569
DY_JUPE, DX_MANCHE, DY_COL = decalages()

# ------------------------------------------------------------------------------------------------ 1. JUPE : patrons de cuir à revers
def construire_jupe():
    bvh, vs, fs = bvh_de("tunique")
    ys = [v.y for v in vs]
    y_top = 0.668 + DY_JUPE
    def centre(y):
        sel = [v for v in vs if abs(v.y - y) < 0.03 and abs(v.x) < 0.5]
        return Vector((0, y, sum(v.z for v in sel) / max(1, len(sel))))
    # anneau fin (360 rayons) à y_top : position de la surface de la jupe
    pts = []
    c = centre(y_top)
    for k in range(360):
        th = 2 * math.pi * k / 360
        d = Vector((math.cos(th), 0, math.sin(th)))
        hit = bvh.ray_cast(c, d, 2.0)
        pts.append(hit[0] if hit[0] is not None else None)
    pts = [p for p in pts if p is not None]
    # abscisse curviligne
    cum = [0.0]
    for i in range(1, len(pts) + 1):
        cum.append(cum[-1] + (pts[i % len(pts)] - pts[i - 1]).length)
    per = cum[-1]
    n = max(10, round(per / 0.086))
    m = Maillage("jupe")
    rangs = [(0.000, 0.006, 1.00, 0.0), (0.030, 0.014, 1.00, 3.8), (0.040, 0.008, 0.98, 5.1), (0.100, 0.012, 0.90, 12.8), (0.140, 0.015, 0.0, 17.9)]
    k0 = 0
    for k in range(n):
        s = per * (k + 0.5) / n
        # point et tangente à l'abscisse s
        i = max(j for j in range(len(cum) - 1) if cum[j] <= s)
        f = (s - cum[i]) / max(1e-6, cum[i + 1] - cum[i])
        P = pts[i].lerp(pts[(i + 1) % len(pts)], f)
        T = pts[(i + 1) % len(pts)] - pts[i - 1] if i > 0 else pts[1] - pts[-1]
        T.y = 0; T.normalize()
        N = Vector((T.z, 0, -T.x))                      # normale horizontale
        if N.dot(P - c) < 0:
            N = -N
        if N.z > 0.80 and abs(P.x) < 0.06:                # devant, au milieu : le tabard reste visible
            continue
        var = "tabA" if k % 2 == 0 else "tabB"
        rel = 0.004 if k % 2 == 0 else 0.0                # une lame sur deux un peu plus sortie (chevauchement)
        hw = 0.5 * MOD[var][2] / TPM
        cols = (-hw, 0.0, hw)
        grille = []
        for (h, d, wf, vt) in rangs:
            ligne = []
            for ci, a in enumerate(cols):
                dd = d + rel + (0.004 if ci == 1 and wf > 0 else 0.0) + (h - 0.04) * 0.10 * (1 if h > 0.04 else 0)
                q = P + T * (a * wf) + N * dd + Vector((0, -h, 0))
                ligne.append((q, None))
            grille.append(ligne)
        # UV colonne : fu = 0, 0.5, 1
        for r in range(len(rangs) - 1):
            for ci in range(2):
                a0, a1 = grille[r][ci], grille[r][ci + 1]
                b0, b1 = grille[r + 1][ci], grille[r + 1][ci + 1]
                vt0, vt1 = rangs[r][3] / MOD[var][3], rangs[r + 1][3] / MOD[var][3]
                u0, u1 = ci * 0.5, ci * 0.5 + 0.5
                if rangs[r + 1][2] == 0.0:                # pointe
                    m.tri((a0[0], a1[0], b0[0]), (module_uv(var, u0, vt0), module_uv(var, u1, vt0), module_uv(var, 0.5, vt1)), N)
                else:
                    m.quad((a0[0], a1[0], b1[0], b0[0]), (module_uv(var, u0, vt0), module_uv(var, u1, vt0), module_uv(var, u1, vt1), module_uv(var, u0, vt1)), N)
    return m

# ------------------------------------------------------------------------------------------------ 2. MANCHES : revers de manchette
def construire_manches():
    bvh, vs, fs = bvh_de("tunique")
    m = Maillage("manches")
    for s in (1, -1):
        sel = [v for v in vs if abs(abs(v.x) - (0.57 + DX_MANCHE)) < 0.015 and v.x * s > 0]
        yc = sum(v.y for v in sel) / len(sel); zc = sum(v.z for v in sel) / len(sel)
        r0 = sum(math.hypot(v.y - yc, v.z - zc) for v in sel) / len(sel)
        N = 8
        for j in range(N):
            th0 = 2 * math.pi * j / N; th1 = 2 * math.pi * (j + 1) / N
            def at(x, r, th):
                return Vector((s * x, yc + math.sin(th) * r, zc + math.cos(th) * r))
            dent = -0.014 if j % 2 else 0.0
            dx = DX_MANCHE
            rows = [(0.592 + dx, r0 + 0.004, 0.0), (0.574 + dx, r0 + 0.016, 3.2), (0.548 + dx + dent, r0 + 0.012, 6.5)]
            thm = (th0 + th1) / 2
            ext = Vector((0, math.sin(thm), math.cos(thm)))
            for r in range(2):
                x0, rr0, v0 = rows[r]; x1, rr1, v1 = rows[r + 1]
                pq = (at(x0, rr0, th0), at(x0, rr0, th1), at(x1, rr1, th1), at(x1, rr1, th0))
                uvs = (module_uv("manch", 0, v0 / 10), module_uv("manch", 1, v0 / 10), module_uv("manch", 1, v1 / 10), module_uv("manch", 0, v1 / 10))
                m.quad(pq, uvs, ext)
            # dent de fourrure au bord libre
            xb, rb, vb = rows[2]
            pa, pb = at(xb, rb, th0), at(xb, rb, th1)
            tip = at(xb - 0.022, rb - 0.004, thm)
            m.tri((pa, pb, tip), (module_uv("manch", 0, 6.5 / 10), module_uv("manch", 1, 6.5 / 10), module_uv("manch", 0.5, 9.8 / 10)), ext)
    return m

# ------------------------------------------------------------------------------------------------ 3. CAPE : ourlet roulé
def construire_cape():
    bvh, vs, fs = bvh_de("cape")
    xs = [v.x for v in vs if v.y < 0.7]
    x0, x1 = min(xs) + 0.012, max(xs) - 0.012
    NS = 10
    seg_w = (x1 - x0) / NS
    m = Maillage("cape")
    def y_bas(x):
        for y in np.arange(0.25, 0.6, 0.004):
            h = bvh.ray_cast(Vector((x, y, -0.9)), Vector((0, 0, 1)), 2.0)
            if h[0] is not None:
                return y
        return 0.32
    def surf(x, y):
        h = bvh.ray_cast(Vector((x, y, -0.9)), Vector((0, 0, 1)), 2.0)
        if h[0] is None:
            return None, Vector((0, 0, -1))
        n = h[1]
        if n.z > 0:
            n = -n
        return h[0], n
    rangs = [(0.030, 0.004, 0.0), (0.044, 0.012, 3.2), (0.088, 0.008, 8.0), (0.095, 0.011, 11.6)]
    cols = []
    for i in range(NS + 1):
        x = x0 + seg_w * i
        yb = y_bas(x)
        col = []
        for (h, d, v) in rangs:
            wave = 0.006 * math.sin(i * 1.9) if h < 0.04 else 0.0
            p, n = surf(x, yb + h + wave)
            col.append((p + n * d if p is not None else None, n, v))
        cols.append(col)
    for i in range(NS):
        u0 = (i % 4) / 4.0; u1 = u0 + 0.25
        for r in range(len(rangs) - 1):
            a0, a1, b0, b1 = cols[i][r], cols[i + 1][r], cols[i + 1][r + 1], cols[i][r + 1]
            if None in (a0[0], a1[0], b0[0], b1[0]):
                continue
            uv = (module_uv("ourlet", u0, a0[2] / 12), module_uv("ourlet", u1, a1[2] / 12), module_uv("ourlet", u1, b0[2] / 12), module_uv("ourlet", u0, b1[2] / 12))
            m.quad((a0[0], a1[0], b0[0], b1[0]), uv, a0[1] * 1.0 + Vector((0, 0, -1)))
    return m

# ------------------------------------------------------------------------------------------------ 4. COL : touffes de fourrure
def construire_col():
    bvh, vs, fs = bvh_de("mante")
    # surfaces candidates (triangles, aire)
    tris = []
    for f in fs:
        a, b, c = [vs[i] for i in f]
        n = (b - a).cross(c - a)
        aire = n.length * 0.5
        if aire < 1e-7:
            continue
        tris.append((a, b, c, n.normalized(), aire))
    tot = sum(t[4] for t in tris)
    def tirer():
        r = random.random() * tot
        for t in tris:
            r -= t[4]
            if r <= 0:
                u, v = random.random(), random.random()
                if u + v > 1: u, v = 1 - u, 1 - v
                return t[0] + (t[1] - t[0]) * u + (t[2] - t[0]) * v, t[3]
        return tris[-1][0], tris[-1][3]
    zone = {"A": 18, "B": 12, "C": 8}
    choisis = []
    essais = 0
    while any(zone.values()) and essais < 20000:
        essais += 1
        p, n = tirer()
        if n.dot(p - Vector((0, p.y, 0.0))) < 0 and abs(n.y) < 0.9:
            n = -n                                         # normale vers l'extérieur du col
        if p.y > 1.45 + DY_COL and zone["A"]:
            z = "A"
        elif p.y < 1.34 + DY_COL and zone["B"]:
            z = "B"
        elif 1.34 + DY_COL <= p.y <= 1.45 + DY_COL and abs(p.x) > 0.2 and zone["C"]:
            z = "C"
        else:
            continue
        if any((p - q[0]).length < 0.06 for q in choisis):
            continue
        choisis.append((p, n, z)); zone[z] -= 1
    m = Maillage("col")
    for idx, (p, n, z) in enumerate(choisis):
        rad = Vector((p.x, 0, p.z - 0.0)); rad = rad.normalized() if rad.length > 1e-4 else Vector((0, 0, 1))
        if z == "B":
            d = (n * 0.3 + Vector((0, -0.85, 0)) + rad * 0.35).normalized()
        else:
            d = (n + Vector((0, 0.15, 0)) + rad * 0.45).normalized()
        t1 = d.cross(Vector((0, 1, 0)))
        if t1.length < 0.1:
            t1 = d.cross(Vector((1, 0, 0)))
        t1.normalize(); t2 = d.cross(t1).normalized()
        for b in range(2):
            ang = (-1 if b == 0 else 1) * math.radians(15)
            axe = (d * math.cos(ang) + t1 * math.sin(ang)).normalized()
            lg = 0.07 + 0.035 * random.random() + (0.02 if z == "A" else 0)
            base = p + n * 0.004 + t1 * (0.012 * (1 if b else -1))
            tip = base + axe * lg + Vector((0, -0.012, 0))
            var = "touffe%d" % ((idx + b) % 3)
            hb = 0.019
            c3 = [base + t1 * hb * math.cos(a) + t2 * hb * math.sin(a) for a in (0, 2.094, 4.189)]
            u = lambda fu, fv: module_uv(var, fu, fv)
            for k in range(3):
                a, bb = c3[k], c3[(k + 1) % 3]
                centre = (c3[0] + c3[1] + c3[2]) / 3
                m.tri((a, bb, tip), (u(0.0, 1.0), u(1.0, 1.0), u(0.5, 0.0)), ((a + bb) / 2 - centre))
    return m

# ------------------------------------------------------------------------------------------------ 5. RELIEF : modules détaillés + bake
PAL = {
    "cuir": ["#1c150e", "#30251b", "#45372a", "#5c4936", "#755d45", "#8f7558", "#a98e6e"],
    "four": ["#2e2318", "#5a4632", "#7f6a4b", "#a68e69", "#c6ae89", "#ddcaa5"],
    "laine": ["#0d1015", "#151a22", "#1e252f", "#28313d", "#343e4b", "#444f5d"],
}
def rgb(h):
    return [int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]

def hsh(x, y, g):
    v = np.sin(x * 127.1 + y * 311.7 + g * 74.7) * 43758.5453
    return v - np.floor(v)

def hauteur(nom, I, J):
    """Relief (m) du module `nom` aux coordonnées de texel (I, J) (tableaux) : grain, coutures, plis, brins. Amplitudes un peu
    exagérées (à 128 texels/m le millimètre ne se lit pas)."""
    x, y, w, h = MOD[nom]
    H = np.zeros_like(I, dtype=float)
    if nom.startswith("tab"):
        grain = (hsh(np.floor(I * 2), np.floor(J * 2), 3) - 0.5) * 0.0022
        H += grain
        H += 0.0030 * np.exp(-((J - 4.4) ** 2) / 0.35)      # arête du revers (bord de la lèvre)
        H -= 0.0035 * np.exp(-((J - 4.9) ** 2) / 0.2)       # creux sous le revers
        H += 0.0032 * np.exp(-((J - 0.6) ** 2) / 0.8) * (J < 3)  # lèvre pliée
        bord = np.minimum(I, w - I)
        H -= 0.0030 * np.exp(-(bord ** 2) / 0.5)             # bords arrondis
        # couture : points tous les 3 texels à 2 texels du bord
        for cote in (2.0, w - 2.0):
            H -= 0.0030 * np.exp(-((I - cote) ** 2) / 0.12) * (np.mod(J, 3.0) < 1.4) * (J > 6)
        H += 0.0026 * np.exp(-((I - w / 2) ** 2) / 3.0) * (J > 6)    # arête centrale (lame bombée)
    elif nom == "manch":
        H += (hsh(np.floor(I * 2), np.floor(J * 2), 5) - 0.5) * 0.0020
        H += 0.0035 * np.exp(-((J - 3.2) ** 2) / 0.5)        # crête du pli
        H -= 0.0030 * np.exp(-((J - 4.2) ** 2) / 0.25)
        brins = np.sin(I * 2.6 + np.sin(J) * 0.7)
        H += 0.0028 * brins * (J > 6.3)                      # brins de fourrure au bord libre
    elif nom.startswith("touffe"):
        brins = np.sin(I * 3.1 + (hsh(np.floor(J / 2), 0, 11) - 0.5) * 2.0)
        H += 0.0045 * brins                                   # sillons le long de la touffe
        H -= 0.0030 * np.exp(-((I - w / 2) ** 2) / 0.4)       # fente centrale
        H += (hsh(np.floor(I), np.floor(J), 9) - 0.5) * 0.0012
    elif nom == "ourlet":
        H += (hsh(np.floor(I), np.floor(J), 13) - 0.5) * 0.0016
        torsade = np.sin((I + J * 1.2) * math.pi / 3.0)
        H += 0.0042 * torsade * (J > 8.6) * np.sin(np.clip((J - 8.6) / 3.4, 0, 1) * math.pi)  # cordon torsadé
        for lj in (4.0, 8.0):
            H -= 0.0028 * np.exp(-((J - lj) ** 2) / 0.12) * (np.mod(I, 3.0) < 1.5)            # couture
        H += 0.0032 * np.exp(-((J - 3.2) ** 2) / 0.6)         # crête du pli
    return H

SS = 4                                                         # suréchantillonnage du bake (texels -> pixels)
def construire_modules_bake():
    """Une version LÉGÈRE (un rectangle par module, UV de la feuille) et une version DÉTAILLÉE (maillage dense relief) par module."""
    bas, haut = [], []
    for i, (nom, (x, y, w, h)) in enumerate(MOD.items()):
        ox, oy = i * 0.6, 0.0
        lo = Maillage("bas_" + nom)
        p = [Vector((ox + a / TPM, oy + (h - b) / TPM, 0)) for a, b in ((0, 0), (w, 0), (w, h), (0, h))]
        lo.quad(p, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)], Vector((0, 0, 1)))
        bas.append((nom, lo))
        # détaillé : grille (SS*2 points par texel), relief le long de +z
        nx, ny = w * SS * 2, h * SS * 2
        me = bpy.data.meshes.new("haut_" + nom)
        I, J = np.meshgrid(np.linspace(0, w, nx + 1), np.linspace(0, h, ny + 1))
        Z = hauteur(nom, I, J)
        vs = [(ox + I[r, c] / TPM, oy + (h - J[r, c]) / TPM, Z[r, c]) for r in range(ny + 1) for c in range(nx + 1)]
        fs = [(r * (nx + 1) + c, (r + 1) * (nx + 1) + c, (r + 1) * (nx + 1) + c + 1, r * (nx + 1) + c + 1) for r in range(ny) for c in range(nx)]
        me.from_pydata(vs, [], fs); me.update()
        ob = bpy.data.objects.new("haut_" + nom, me)
        bpy.context.collection.objects.link(ob)
        haut.append(ob)
    return bas, haut

def cuire(bas, haut):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        sc.cycles.device = "CPU"
    except Exception:
        pass
    sc.cycles.samples = 24
    mw = bpy.data.worlds.new('w'); sc.world = mw
    mw.light_settings.distance = 0.04
    W, H = SHEET_W * SS, SHEET_H * SS
    res = {}
    # objets bas : un seul objet réunissant tous les modules (UV disjoints dans la feuille)
    objs = []
    for nom, lo in bas:
        objs.append(vers_blender(lo, uv_feuille))
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    cible = bpy.context.view_layer.objects.active
    cible.name = "bas_feuille"
    for passe in ("AO", "CAVITE"):
        img = bpy.data.images.new("bake_" + passe, W, H, alpha=False, float_buffer=True)
        img.colorspace_settings.name = "Non-Color"
        mat = bpy.data.materials.new("m_" + passe)
        mat.use_nodes = True
        nt = mat.node_tree
        nd = nt.nodes.new("ShaderNodeTexImage"); nd.image = img
        nt.nodes.active = nd
        cible.data.materials.clear(); cible.data.materials.append(mat)
        if passe == "CAVITE":
            # émission = pointiness du détaillé (courbure : > 0,5 saillant, < 0,5 creux)
            for ob in haut:
                mh = bpy.data.materials.new("mh")
                mh.use_nodes = True
                t = mh.node_tree
                for n in list(t.nodes):
                    t.nodes.remove(n)
                geo = t.nodes.new("ShaderNodeNewGeometry"); em = t.nodes.new("ShaderNodeEmission"); out = t.nodes.new("ShaderNodeOutputMaterial")
                t.links.new(geo.outputs["Pointiness"], em.inputs["Color"]); t.links.new(em.outputs["Emission"], out.inputs["Surface"])
                ob.data.materials.clear(); ob.data.materials.append(mh)
        bpy.ops.object.select_all(action="DESELECT")
        for ob in haut:
            ob.select_set(True)
        cible.select_set(True)
        bpy.context.view_layer.objects.active = cible
        bpy.ops.object.bake(type="AO" if passe == "AO" else "EMIT", use_selected_to_active=True, cage_extrusion=0.012,
                            max_ray_distance=0.03, margin=2, margin_type="EXTEND", normal_space="TANGENT")
        px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[:, :, 0]
        res[passe] = px[::-1]                                  # ligne 0 = haut de la feuille
        img.filepath_raw = SRC + PRE + "bake_" + passe.lower() + ".png"
        img.file_format = "PNG"
        img.save()
    return res

def reduire(a):
    h, w = a.shape
    return a.reshape(h // SS, SS, w // SS, SS).mean(axis=(1, 3))

def hexcol(pal, i):
    return rgb(PAL[pal][int(np.clip(i, 0, len(PAL[pal]) - 1))])

def peindre(res):
    """Palette + AO/cavité cuits -> feuille 64 x 48 quantifiée. Retourne un tableau (SHEET_H, SHEET_W, 4)."""
    ao = reduire(res["AO"]); cav = reduire(res["CAVITE"])
    # normalisations : relief seulement ; ao ~ 1 plat, < 1 creux ; cav ~ 0,5 plat, > 0,5 saillant
    img = np.zeros((SHEET_H, SHEET_W, 4), dtype=np.float32)
    img[:] = [*hexcol("cuir", 2), 1.0]
    def tone(nom, base_fn, pal):
        x, y, w, h = MOD[nom]
        ra, rc = ao[y:y + h, x:x + w], cav[y:y + h, x:x + w]
        s_ao, s_hi, s_lo = np.percentile(ra, 20), np.percentile(rc, 86), np.percentile(rc, 12)
        for j in range(h):
            for i in range(w):
                t = base_fn(i, j, w, h)
                if t is None:
                    continue
                a = ao[y + j, x + i]; c = cav[y + j, x + i]
                bruit = (hsh(i + x, j + y, 21) - 0.5) * 0.02
                if a < s_ao + bruit:
                    t -= 1
                if c > s_hi + bruit * 0.2:
                    t += 1
                elif c < s_lo + bruit * 0.2:
                    t -= 1
                img[y + j, x + i, :3] = hexcol(pal, t)
    def tab(i, j, w, h):
        if j < 2: return 5                                     # lèvre pliée, accrochée par la lumière
        if j < 4.4: return 4                                   # revers
        if j < 5.2: return 1                                   # ombre sous le revers
        bord = min(i, w - 1 - i)
        if bord == 0: return 1
        if (bord == 2 and j > 6 and j % 3 < 2): return 5      # couture claire
        if abs(i - (w - 1) / 2) < 1 and j > 6: return 4        # arête de la lame
        t = 3 + (1 if hsh(i, j, 33) > 0.82 else 0) - (1 if hsh(i, j, 34) > 0.88 else 0)
        return t
    for n in ("tabA", "tabB"):
        tone(n, tab, "cuir")
    def manch(i, j, w, h):
        if j < 2: return 3
        if j < 4: return 4                                     # crête du pli
        if j < 5: return 1
        # fourrure au bord libre : brins
        brin = (i + (j // 2)) % 3
        return 3 + (1 if brin == 0 else 0) + (1 if j > 7 else 0) - (1 if brin == 2 else 0)
    tone("manch", manch, "four")
    def touffe(i, j, w, h):
        t = j / (h - 1)
        if i == 0 or i == w - 1: return 1                       # bord sombre
        if t < 0.25: return 5 if i in (2, 3) else 4              # pointe claire
        if t > 0.8: return 1                                    # racine sombre
        return 3 if i <= 2 else 2
    for n in ("touffe0", "touffe1", "touffe2"):
        tone(n, touffe, "four")
    def ourlet(i, j, w, h):
        if j in (4, 8) and i % 3 < 2: return 5 if False else 3   # couture crème (ton 3 de la laine = trop sombre -> on peint la fourrure ci-dessous)
        if j < 3: return 3
        if j < 5: return 2
        if j >= 9: return 4 if (i + j) % 4 < 2 else 2             # cordon torsadé
        return 2
    tone("ourlet", ourlet, "laine")
    # coutures de l'ourlet en fil crème (palette fourrure)
    x, y, w, h = MOD["ourlet"]
    for j in (4, 8):
        for i in range(w):
            if i % 3 < 2:
                img[y + j, x + i, :3] = hexcol("four", 3 if (i % 6) < 3 else 2)
    return img

def ecrire_png(img, chemin):
    h, w = img.shape[:2]
    im = bpy.data.images.new("sortie", w, h, alpha=True)
    flat = img[::-1].reshape(-1)                                # Blender : ligne 0 = bas
    im.pixels = flat.tolist()
    im.filepath_raw = chemin; im.file_format = "PNG"; im.save()

# ------------------------------------------------------------------------------------------------ export
def exporter(maillages):
    objs = []
    for m in maillages:
        if not m.t:
            continue
        ob = vers_blender(m, uv_atlas)
        objs.append(ob)
    mat = bpy.data.materials.new("relief")
    for ob in objs:
        ob.data.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT + PRE + "revers.glb", export_format="GLB", use_selection=True, export_yup=False,
                              export_apply=False, export_normals=True, export_texcoords=True, export_materials="NONE")

def main():
    bas, haut = construire_modules_bake()
    res = cuire(bas, haut)
    img = peindre(res)
    ecrire_png(img, OUT + "relief_bl.png")
    print("RELIEF ecrit", OUT + "relief_bl.png")
    pieces = [construire_jupe(), construire_manches(), construire_cape(), construire_col()]
    for p in pieces:
        print("TRIS %s %d" % (p.nom, len(p.t)))
    print("TRIS_TOTAL", sum(len(p.t) for p in pieces))
    exporter(pieces)
    print("EXPORT", OUT + PRE + "revers.glb")
    bpy.ops.wm.save_as_mainfile(filepath=SRC + PRE + "chasseresse_revers.blend")

main()
