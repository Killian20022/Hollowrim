# Squelette nordique (refonte D/squelettes, au niveau du draugr) : ossements détaillés + restes d'équipement nordique.
#   blender.exe -b --python squelette_nordique.py -- [--apercu=<dossier>] [--sans-bake]
# Écrit : assets/modeles/squelettes/squelette_nordique.glb  (maillages : squelette, lambeaux, casque, capuche, bouclier, epee, hache, arc, carquois)
#         sources_blender/squelette_nordique_atlas.png      (atlas RGBA : bake Cycles AO + cavité + arêtes + position/normale -> peinture quantifiée)
# Rig = celui de homme_vetu_lot1.glb réduit à RIG18 + 4 feuilles (mêmes os, même pose de repos que les humains) : animations et ragdoll inchangés.
# Skinning rigide (1 os par sommet) pour les os ; les étoffes pendantes mêlent bassin et cuisses.
# Repère Blender : x = gauche du perso (os *_l), -y = devant, z = haut.
# Couleur de sommet « lueur » : alpha 0 = fond des orbites (lueur froide du shader ps1_draugr), 1 partout ailleurs.
import bpy, bmesh, math, os, sys, random
import numpy as np
from mathutils import Vector, Matrix

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(BASE, "sources_blender", "homme_vetu_lot1.glb")
RIG18 = os.path.join(BASE, "sources_blender", "rig18.txt")
OUT_GLB = os.path.join(BASE, "assets", "modeles", "squelettes", "squelette_nordique.glb")
OUT_PNG = os.path.join(BASE, "sources_blender", "squelette_nordique_atlas.png")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
APERCU = next((a.split("=", 1)[1] for a in ARGS if a.startswith("--apercu=")), "")
SANS_BAKE = "--sans-bake" in ARGS
ATLAS = 512
SUPER = 2
FEUILLES = ["ball_l", "ball_r", "middle_01_l", "middle_01_r"]
rng = random.Random(11)

def V(x, y, z):
    return Vector((x, y, z))

# ============================================================================ 1. rig
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for o in list(bpy.data.objects):
    if o.type != 'ARMATURE':
        bpy.data.objects.remove(o)
garde = [l.strip() for l in open(RIG18) if l.strip()]
garde += [n for n in FEUILLES if n not in garde]
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
for eb in list(arm.data.edit_bones):
    if eb.name not in garde:
        arm.data.edit_bones.remove(eb)
bpy.ops.object.mode_set(mode='OBJECT')
print("OS gardes :", len(arm.data.bones))

# ============================================================================ 2. constructeur
CLASSES = ["os", "dent", "orbite", "fer", "cuir", "tissu", "bois", "bois_peint", "corde", "plume", "oeil"]
CID = {c: i for i, c in enumerate(CLASSES)}

class Obj:
    def __init__(s, nom):
        s.nom = nom; s.v = []; s.w = []; s.a = []; s.f = []; s.c = []; s.sharp = True
    def pt(s, p, w, a=1.0):
        s.v.append(Vector(p)); s.w.append(w if isinstance(w, dict) else {w: 1.0}); s.a.append(a)
        return len(s.v) - 1
    def face(s, ids, cls):
        s.f.append(list(ids)); s.c.append(CID[cls])

OBJS = {}
def obj(nom):
    if nom not in OBJS:
        OBJS[nom] = Obj(nom)
    return OBJS[nom]

def circle(n, phase=0.5):
    return [(math.cos(2 * math.pi * (i + phase) / n), math.sin(2 * math.pi * (i + phase) / n)) for i in range(n)]

def frames(path, up):
    n = len(path)
    T = []
    for i in range(n):
        a = path[max(i - 1, 0)]; b = path[min(i + 1, n - 1)]
        T.append((b - a).normalized())
    N = []
    u = Vector(up)
    n0 = u - T[0] * u.dot(T[0])
    if n0.length < 1e-6:
        n0 = T[0].orthogonal()
    N.append(n0.normalized())
    for i in range(1, n):
        q = T[i - 1].rotation_difference(T[i])
        m = q @ N[-1]
        m = m - T[i] * m.dot(T[i])
        N.append(m.normalized())
    B = [T[i].cross(N[i]).normalized() for i in range(n)]
    return T, N, B

def tube(o, path, prof, sides, w, cls, up=(0, 0, 1), caps=True, shape=None, loop=False, alpha=None, cap_cls=None):
    """Tube le long de `path` ; prof = rayon ou (r_N, r_B) par station ; w = os ou fonction(station) -> poids."""
    path = [Vector(p) for p in path]
    if loop:
        T, N, B = frames(path + path[:2], up)
        T, N, B = T[:len(path)], N[:len(path)], B[:len(path)]
    else:
        T, N, B = frames(path, up)
    shp = shape or circle(sides)
    rings = []
    for i, p in enumerate(path):
        r = prof[i] if isinstance(prof, list) else prof
        rn, rb = (r, r) if not isinstance(r, (list, tuple)) else r
        wi = w(i) if callable(w) else w
        ai = alpha[i] if alpha else 1.0
        rings.append([o.pt(p + N[i] * cx * rn + B[i] * cy * rb, wi, ai) for cx, cy in shp])
    m = len(shp)
    segs = len(rings) if loop else len(rings) - 1
    for k in range(segs):
        r0 = rings[k]; r1 = rings[(k + 1) % len(rings)]
        for i in range(m):
            j = (i + 1) % m
            o.face([r0[i], r0[j], r1[j], r1[i]], cls)
    if caps and not loop:
        o.face(rings[0][::-1], cap_cls or cls)
        o.face(rings[-1], cap_cls or cls)
    return rings

def ellipsoid(o, c, r, seg, rings, w, cls, deform=None, alpha=None, rot=None):
    c = Vector(c)
    ids = []
    top = None
    pts = []
    for k in range(rings + 1):
        th = math.pi * k / rings
        row = []
        for i in range(seg if 0 < k < rings else 1):
            ph = 2 * math.pi * i / seg
            d = Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))
            p = Vector((d.x * r[0], d.y * r[1], d.z * r[2]))
            if rot is not None:
                p = rot @ p
            p = c + p
            if deform:
                p = deform(p, d)
            a = alpha(p, d) if alpha else 1.0
            row.append(o.pt(p, w, a))
        pts.append(row)
    for k in range(rings):
        a, b = pts[k], pts[k + 1]
        for i in range(seg):
            j = (i + 1) % seg
            if len(a) == 1:
                o.face([a[0], b[j], b[i]], cls)
            elif len(b) == 1:
                o.face([a[i], a[j], b[0]], cls)
            else:
                o.face([a[i], a[j], b[j], b[i]], cls)
    return pts

def boite(o, c, sx, sy, sz, w, cls, rot=None):
    c = Vector(c)
    p = []
    for z in (-1, 1):
        for y in (-1, 1):
            for x in (-1, 1):
                v = Vector((x * sx, y * sy, z * sz))
                if rot is not None:
                    v = rot @ v
                p.append(o.pt(c + v, w))
    for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
        o.face([p[i] for i in f], cls)

def nappe(o, grille, w, cls, trous=None):
    """Nappe (étoffe) : grille[ligne][colonne] de points ; w(ligne, colonne, p) -> poids ; trous(l, c) -> True = quad supprimé."""
    ids = [[o.pt(p, w(l, c, p)) for c, p in enumerate(row)] for l, row in enumerate(grille)]
    for l in range(len(grille) - 1):
        for c in range(len(grille[0]) - 1):
            if trous and trous(l, c):
                continue
            o.face([ids[l][c], ids[l][c + 1], ids[l + 1][c + 1], ids[l + 1][c]], cls)
    return ids

def plaque(o, contour, normale, ep, w, cls):
    """Plaque épaisse : contour 3D (polygone convexe ou presque), extrudée de ep le long de normale (centrée)."""
    n = Vector(normale).normalized() * ep * 0.5
    a = [o.pt(Vector(p) - n, w) for p in contour]
    b = [o.pt(Vector(p) + n, w) for p in contour]
    o.face(a[::-1], cls)
    o.face(b, cls)
    m = len(contour)
    for i in range(m):
        j = (i + 1) % m
        o.face([a[i], a[j], b[j], b[i]], cls)

def mirx(p):
    return V(-p[0], p[1], p[2])

def lerp(a, b, t):
    return a + (b - a) * t

def bez(pts, n):
    """Courbe de Catmull-Rom passant par pts, n points."""
    P = [Vector(p) for p in pts]
    out = []
    for k in range(n):
        t = k / (n - 1) * (len(P) - 1)
        i = min(int(t), len(P) - 2); u = t - i
        p0 = P[max(i - 1, 0)]; p1 = P[i]; p2 = P[i + 1]; p3 = P[min(i + 2, len(P) - 1)]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u))
    return out

# ============================================================================ 3. ossements
S = obj("squelette")

# ---------------------------------------------------------------- crâne (os Head) : sections horizontales de 24 points (loft)
ORB = [V(0.034, -0.077, 1.697), V(-0.034, -0.077, 1.697)]
# (z, rx, ry, yc, plan facial y (None = aucun), creux orbites, creux nez)
SECTIONS = [
    (1.817, 0.034, 0.046, 0.030, None, 0.0, 0.0),
    (1.806, 0.052, 0.068, 0.028, None, 0.0, 0.0),
    (1.790, 0.062, 0.082, 0.026, None, 0.0, 0.0),
    (1.768, 0.070, 0.092, 0.024, None, 0.0, 0.0),
    (1.743, 0.074, 0.097, 0.021, -0.079, 0.0, 0.0),
    (1.722, 0.075, 0.098, 0.019, -0.084, 0.0, 0.0),
    (1.708, 0.073, 0.097, 0.017, -0.081, 0.020, 0.0),
    (1.694, 0.072, 0.095, 0.015, -0.079, 0.030, 0.0),
    (1.680, 0.074, 0.093, 0.013, -0.080, 0.022, 0.008),
    (1.666, 0.066, 0.088, 0.012, -0.082, 0.0, 0.022),
    (1.652, 0.050, 0.064, -0.016, -0.081, 0.0, 0.016),
    (1.638, 0.038, 0.042, -0.038, -0.080, 0.0, 0.0),
    (1.627, 0.032, 0.035, -0.045, -0.079, 0.0, 0.0),
]
NP = 24
anneaux = []
for z, rx, ry, yc, yf, d_orb, d_nez in SECTIONS:
    row = []
    for k in range(NP):
        a = 2 * math.pi * (k + 0.5) / NP
        x = rx * math.sin(a)
        y = yc - ry * math.cos(a)
        if yf is not None and math.cos(a) > 0.2:
            t = min(1.0, (math.cos(a) - 0.2) / 0.4)
            y = lerp(y, yf + 9.0 * x * x, t)
        ax = abs(x)
        if d_orb > 0 and 0.012 < ax < 0.054 and math.cos(a) > 0.3:
            y += d_orb * math.sin(math.pi * (ax - 0.012) / 0.042)
        if d_nez > 0 and ax < 0.013 and math.cos(a) > 0.3:
            y += d_nez
        row.append(V(x, y, z))
    anneaux.append(row)
ids = [[S.pt(p, "Head") for p in r] for r in anneaux]
for l in range(len(ids) - 1):
    for k in range(NP):
        j = (k + 1) % NP
        S.face([ids[l][k], ids[l + 1][k], ids[l + 1][j], ids[l][j]], "os")
som = S.pt(V(0, 0.030, 1.822), "Head")
for k in range(NP):
    S.face([ids[0][(k + 1) % NP], som, ids[0][k]][::-1], "os")
S.face(ids[-1], "os")
for sg in (1, -1):
    c = ORB[0 if sg > 0 else 1]
    rim = [c + V(0.019 * math.cos(a) * sg, 0.005 + 0.004 * math.sin(a) ** 2, 0.018 * math.sin(a)) for a in [2 * math.pi * (k + 0.5) / 8 for k in range(8)]]
    tube(S, rim, 0.0040, 4, "Head", "os", up=(0, -1, 0), loop=True)
    # fond de l'orbite : petite coupe dont le centre luit (alpha 0)
    fond = c + V(0, 0.026, 0)
    ids = [S.pt(c + V(0.013 * math.cos(a), 0.016, 0.012 * math.sin(a)), "Head", 0.85) for a in [2 * math.pi * k / 8 for k in range(8)]]
    ap = S.pt(fond, "Head", 0.0)
    for k in range(8):
        S.face([ids[k], ids[(k + 1) % 8], ap], "oeil")
# ouverture nasale (bord) et épine nasale
nez = [V(0.0, -0.085, 1.684), V(0.011, -0.083, 1.670), V(0.013, -0.082, 1.656), V(0.004, -0.083, 1.647), V(-0.004, -0.083, 1.647), V(-0.013, -0.082, 1.656), V(-0.011, -0.083, 1.670)]
tube(S, nez, 0.0028, 3, "Head", "os", up=(0, -1, 0), loop=True)
ids = [S.pt(p + V(0, 0.006, 0) * 0.5 + (V(0, -0.0, 1.664) - p) * 0.25, "Head") for p in nez]
apn = S.pt(V(0, -0.058, 1.664), "Head")
for k in range(len(nez)):
    S.face([ids[k], ids[(k + 1) % len(nez)], apn], "orbite")
# maxillaire : bande en U, dents du haut à son bord inférieur
dh = bez([V(-0.030, -0.040, 1.623), V(-0.024, -0.072, 1.622), V(0.0, -0.084, 1.621), V(0.024, -0.072, 1.622), V(0.030, -0.040, 1.623)], 7)
tube(S, dh, [(0.0068, 0.0045)] * 7, 4, "Head", "dent", up=(0, 0, 1))
# mandibule (légèrement entrouverte : la mâchoire pend, 9°)
pivot = V(0.0, 0.020, 1.668)
Rm = Matrix.Rotation(math.radians(-6), 3, 'X')
def mand(p):
    return pivot + Rm @ (Vector(p) - pivot)
mb = [mand(p) for p in bez([V(-0.050, 0.012, 1.600), V(-0.042, -0.040, 1.592), V(-0.020, -0.072, 1.588), V(0.0, -0.079, 1.586), V(0.020, -0.072, 1.588), V(0.042, -0.040, 1.592), V(0.050, 0.012, 1.600)], 9)]
tube(S, mb, [(0.011, 0.006), (0.013, 0.0065), (0.016, 0.007), (0.019, 0.0075), (0.020, 0.008), (0.019, 0.0075), (0.016, 0.007), (0.013, 0.0065), (0.011, 0.006)], 4, "Head", "os", up=(0, 0, 1))
db = [mand(p) for p in bez([V(-0.029, -0.042, 1.608), V(-0.023, -0.068, 1.607), V(0.0, -0.078, 1.606), V(0.023, -0.068, 1.607), V(0.029, -0.042, 1.608)], 7)]
tube(S, db, [(0.0062, 0.0042)] * 7, 4, "Head", "dent", up=(0, 0, 1))
for sg in (1, -1):
    ra = [mand(V(sg * 0.050, 0.012, 1.602)), mand(V(sg * 0.054, 0.020, 1.638)), V(sg * 0.056, 0.024, 1.662)]
    tube(S, ra, [(0.0055, 0.022), (0.005, 0.018), (0.006, 0.010)], 4, "Head", "os", up=(1, 0, 0))

print('TRI crane', len(S.f))
# ---------------------------------------------------------------- colonne
def vertebre(c, up, r, h, bone, kind):
    up = Vector(up).normalized()
    tube(S, [c - up * h * 0.5, c + up * h * 0.5], [(r, r * 0.85)] * 2, 6, bone, "os", up=(1, 0, 0))
    arr = V(0, 1, 0)
    if kind == "lombaire":
        boite(S, c + arr * (r + 0.016) - up * 0.004, 0.005, 0.016, h * 0.42, bone, "os")
        for sg in (1, -1):
            boite(S, c + V(sg * (r + 0.014), 0.008, 0), 0.016, 0.005, 0.0045, bone, "os")
    elif kind == "dorsale":
        boite(S, c + arr * (r + 0.015) - up * 0.008, 0.0045, 0.015, h * 0.40, bone, "os", rot=Matrix.Rotation(math.radians(-25), 3, 'X'))
    else:
        boite(S, c + arr * (r + 0.008) - up * 0.004, 0.0035, 0.009, h * 0.30, bone, "os")

col = bez([V(0, 0.050, 1.075), V(0, 0.036, 1.170), V(0, 0.060, 1.300), V(0, 0.078, 1.400), V(0, 0.060, 1.495), V(0, 0.040, 1.560), V(0, 0.030, 1.630)], 200)
def col_at(z):
    best = min(col, key=lambda p: abs(p.z - z))
    i = col.index(best)
    t = (col[min(i + 1, len(col) - 1)] - col[max(i - 1, 0)]).normalized()
    return best, t
for z in [1.088, 1.128, 1.168, 1.208, 1.248]:
    c, t = col_at(z)
    vertebre(c, t, 0.019, 0.031, "spine_01" if z < 1.178 else "spine_02", "lombaire")
for k in range(10):
    z = 1.272 + k * 0.0245
    c, t = col_at(z)
    vertebre(c, t, 0.0145, 0.020, "spine_02" if z < 1.311 else "spine_03", "dorsale")
for z in [1.520, 1.546, 1.572, 1.598, 1.622]:
    c, t = col_at(z)
    vertebre(c, t, 0.0125, 0.021, "neck_01", "cervicale")

print('TRI colonne', len(S.f))
# ---------------------------------------------------------------- cage thoracique
for k in range(10):
    z0 = 1.468 - k * 0.0265
    c0, _ = col_at(z0)
    rx = [0.062, 0.088, 0.108, 0.124, 0.136, 0.142, 0.145, 0.144, 0.138, 0.128][k]
    ry = [0.060, 0.072, 0.082, 0.090, 0.095, 0.098, 0.100, 0.100, 0.096, 0.090][k]
    t1 = [2.75, 2.80, 2.80, 2.78, 2.74, 2.68, 2.55, 2.38, 2.0, 1.75][k]
    drop = [0.030, 0.050, 0.065, 0.075, 0.085, 0.090, 0.095, 0.090, 0.075, 0.060][k]
    yc = c0.y + 0.012 - ry
    bone = "spine_03" if z0 > 1.311 else "spine_02"
    for sg in (1, -1):
        pts = []
        n = 6
        for i in range(n):
            t = 0.22 + (t1 - 0.22) * i / (n - 1)
            x = sg * (0.016 + rx * math.sin(t))
            y = yc + ry * math.cos(t)
            z = z0 - drop * (t / math.pi) ** 1.3 + 0.012 * math.sin(t * 1.2)
            pts.append(V(x, y, z))
        pts[0] = V(sg * 0.014, c0.y + 0.006, z0 + 0.004)
        h = [0.006, 0.008, 0.009, 0.0095, 0.0095, 0.0085]
        tube(S, pts, [(hh * 1.15, 0.0050) for hh in h], 4, bone, "os", up=(0, 0, 1))
# sternum (manubrium + corps + xiphoïde)
st = [V(0, -0.098, 1.478), V(0, -0.108, 1.430), V(0, -0.114, 1.360), V(0, -0.112, 1.300), V(0, -0.104, 1.272)]
tube(S, st, [(0.0055, 0.024), (0.005, 0.018), (0.005, 0.016), (0.005, 0.013), (0.004, 0.005)], 4, "spine_03", "os", up=(0, 1, 0))
# clavicules (S) et omoplates
for sg, cote in ((1, "l"), (-1, "r")):
    cl = bez([V(sg * 0.018, -0.096, 1.482), V(sg * 0.070, -0.090, 1.490), V(sg * 0.140, -0.050, 1.500), V(sg * 0.198, 0.010, 1.500)], 6)
    tube(S, cl, [0.0075, 0.0068, 0.0062, 0.0062, 0.007, 0.0085], 5, "clavicle_" + cote, "os", up=(0, 0, 1))
    om = [V(sg * 0.072, 0.112, 1.462), V(sg * 0.178, 0.078, 1.448), V(sg * 0.190, 0.065, 1.425), V(sg * 0.112, 0.108, 1.300), V(sg * 0.075, 0.114, 1.410)]
    plaque(S, om, V(0, 1, 0), 0.007, "clavicle_" + cote, "os")
    ep = bez([V(sg * 0.076, 0.120, 1.432), V(sg * 0.140, 0.112, 1.455), V(sg * 0.196, 0.072, 1.488)], 4)
    tube(S, ep, [(0.004, 0.009), (0.005, 0.011), (0.004, 0.012), (0.004, 0.012)], 4, "clavicle_" + cote, "os", up=(0, 0, 1))
    ellipsoid(S, V(sg * 0.192, 0.068, 1.452), (0.010, 0.014, 0.016), 6, 4, "clavicle_" + cote, "os")

print('TRI cage', len(S.f))
# ---------------------------------------------------------------- bassin
sac = [V(0, 0.070, 1.062), V(0, 0.084, 1.010), V(0, 0.098, 0.960), V(0, 0.100, 0.925)]
tube(S, sac, [(0.010, 0.048), (0.010, 0.038), (0.009, 0.024), (0.006, 0.010)], 4, "pelvis", "os", up=(0, 1, 0))
for sg in (1, -1):
    crete = bez([V(sg * 0.046, 0.086, 1.064), V(sg * 0.110, 0.074, 1.112), V(sg * 0.152, 0.020, 1.106), V(sg * 0.138, -0.040, 1.068)], 6)
    base = bez([V(sg * 0.052, 0.074, 0.995), V(sg * 0.082, 0.060, 0.988), V(sg * 0.098, 0.034, 0.990), V(sg * 0.108, -0.006, 1.004)], 6)
    ga = []
    gb = []
    for l in range(4):
        t = l / 3
        ra = []; rb = []
        for i in range(6):
            p = lerp(base[i], crete[i], t)
            bomb = math.sin(math.pi * t) * math.sin(math.pi * i / 5)
            p = p + V(sg * 0.012 * bomb, 0, 0)
            n = V(sg, 0, 0) * 0.0045
            ra.append(p - n); rb.append(p + n)
        ga.append(ra); gb.append(rb)
    ia = [[S.pt(p, "pelvis") for p in r] for r in ga]
    ib = [[S.pt(p, "pelvis") for p in r] for r in gb]
    for l in range(3):
        for i in range(5):
            S.face([ia[l][i], ia[l + 1][i], ia[l + 1][i + 1], ia[l][i + 1]], "os")
            S.face([ib[l][i], ib[l][i + 1], ib[l + 1][i + 1], ib[l + 1][i]], "os")
    bord = [ia[0][i] for i in range(6)] + [ia[l][5] for l in range(1, 4)] + [ia[3][i] for i in range(4, -1, -1)] + [ia[l][0] for l in range(2, 0, -1)]
    bordb = [ib[0][i] for i in range(6)] + [ib[l][5] for l in range(1, 4)] + [ib[3][i] for i in range(4, -1, -1)] + [ib[l][0] for l in range(2, 0, -1)]
    for i in range(len(bord)):
        j = (i + 1) % len(bord)
        S.face([bord[i], bord[j], bordb[j], bordb[i]], "os")
    # cotyle (anneau) et cadre du trou obturateur (pubis + ischion)
    cot = [V(sg * 0.100, 0.036, 0.975) + V(sg * 0.012 * math.cos(a) * 0.0, 0.028 * math.cos(a), 0.028 * math.sin(a)) for a in [2 * math.pi * k / 7 for k in range(7)]]
    tube(S, cot, 0.007, 4, "pelvis", "os", up=(1, 0, 0), loop=True)
    ob = [V(sg * 0.098, 0.004, 0.952), V(sg * 0.050, -0.040, 0.935), V(sg * 0.010, -0.050, 0.918), V(sg * 0.016, -0.034, 0.888), V(sg * 0.050, 0.010, 0.872), V(sg * 0.078, 0.046, 0.874), V(sg * 0.094, 0.062, 0.920)]
    tube(S, ob, [0.009, 0.010, 0.011, 0.009, 0.010, 0.015, 0.011], 5, "pelvis", "os", up=(1, 0, 0), caps=True)

print('TRI bassin', len(S.f))
# ---------------------------------------------------------------- membres
# os des membres épaissis (EP) : lisibles à 8 m en 480x270 (un vrai fémur de 2,5 cm y fait moins d'un pixel)
EP = 1.30
def _ep(prof):
    if isinstance(prof, list):
        return [_ep(x) for x in prof]
    if isinstance(prof, tuple):
        return tuple(x * EP for x in prof)
    return prof * EP
def tubeE(o, path, prof, *a, **k):
    return tube(o, path, _ep(prof), *a, **k)
def ellipsoidE(o, c, r, *a, **k):
    return ellipsoid(o, c, tuple(x * 1.15 for x in r), *a, **k)
def os_long(path, rayons, bone, sides=6, up=(0, 1, 0)):
    tubeE(S, path, rayons, sides, bone, "os", up=up)

for sg, c in ((1, "l"), (-1, "r")):
    th = "thigh_" + c; ca = "calf_" + c; ft = "foot_" + c
    # fémur : tête, col, grand trochanter, diaphyse arquée, condyles, rotule
    ellipsoidE(S, V(sg * 0.100, 0.036, 0.972), (0.022, 0.022, 0.022), 6, 4, th, "os")
    os_long([V(sg * 0.104, 0.036, 0.968), V(sg * 0.140, 0.036, 0.940)], [0.012, 0.015], th, 6, up=(0, 1, 0))
    ellipsoidE(S, V(sg * 0.150, 0.046, 0.952), (0.014, 0.016, 0.022), 5, 3, th, "os")
    fe = bez([V(sg * 0.142, 0.034, 0.935), V(sg * 0.134, 0.026, 0.800), V(sg * 0.124, 0.024, 0.680), V(sg * 0.116, 0.034, 0.590)], 6)
    os_long(fe, [0.019, 0.015, 0.014, 0.0145, 0.017, 0.021], th, 6)
    ellipsoidE(S, V(sg * 0.1143, 0.044, 0.560), (0.034, 0.028, 0.020), 6, 4, th, "os")
    ellipsoidE(S, V(sg * 0.1143, 0.010, 0.556), (0.017, 0.008, 0.021), 5, 3, th, "os")
    # tibia (plateau, diaphyse triangulaire, malléole), péroné
    ellipsoidE(S, V(sg * 0.1143, 0.040, 0.528), (0.034, 0.028, 0.013), 6, 3, ca, "os")
    tri = [(math.cos(a), math.sin(a) * (0.75 if i % 2 else 1.0)) for i, a in enumerate([2 * math.pi * (k + 0.5) / 6 for k in range(6)])]
    ti = bez([V(sg * 0.1143, 0.040, 0.520), V(sg * 0.112, 0.048, 0.400), V(sg * 0.110, 0.064, 0.250), V(sg * 0.110, 0.082, 0.105)], 6)
    tubeE(S, ti, [0.020, 0.0155, 0.0135, 0.013, 0.014, 0.018], 6, ca, "os", up=(0, -1, 0), shape=tri)
    ellipsoidE(S, V(sg * 0.098, 0.086, 0.094), (0.008, 0.012, 0.016), 5, 3, ca, "os")
    pe = [V(sg * 0.140, 0.052, 0.505), V(sg * 0.142, 0.060, 0.350), V(sg * 0.138, 0.080, 0.180), V(sg * 0.134, 0.090, 0.088)]
    tubeE(S, pe, [0.0085, 0.006, 0.0055, 0.0095], 4, ca, "os", up=(0, 1, 0))
    # pied : talus, calcanéum, tarse, 5 rayons (métatarse + orteils)
    ellipsoidE(S, V(sg * 0.1143, 0.082, 0.064), (0.020, 0.026, 0.014), 6, 4, ft, "os")
    tubeE(S, [V(sg * 0.1143, 0.135, 0.030), V(sg * 0.1143, 0.100, 0.035), V(sg * 0.1143, 0.070, 0.042)], [0.016, 0.019, 0.016], 6, ft, "os", up=(0, 0, 1))
    ellipsoidE(S, V(sg * 0.118, 0.025, 0.045), (0.032, 0.032, 0.015), 6, 4, ft, "os")
    for i in range(5):
        x = sg * (0.092 + i * 0.0135)
        L = [0.0, 0.006, 0.010, 0.016, 0.024][i]
        mt = [V(x * 0.98 + sg * 0.004, 0.005, 0.042), V(x, -0.050 + L * 0.7, 0.020), V(x, -0.098 + L * 1.4, 0.010)]
        tubeE(S, mt, [0.0075 if i == 0 else 0.0052, 0.0068 if i == 0 else 0.0048, 0.0045 if i == 0 else 0.0032], 4, ft, "os", up=(0, 0, 1))
    # humérus
    ua = "upperarm_" + c; la = "lowerarm_" + c; ha = "hand_" + c
    ellipsoidE(S, V(sg * 0.214, 0.068, 1.458), (0.022, 0.024, 0.024), 6, 4, ua, "os")
    hu = bez([V(sg * 0.228, 0.068, 1.456), V(sg * 0.300, 0.068, 1.457), V(sg * 0.380, 0.070, 1.456), V(sg * 0.440, 0.073, 1.455)], 6)
    os_long(hu, [0.018, 0.014, 0.012, 0.012, 0.014, 0.017], ua, 6, up=(0, 0, 1))
    ellipsoidE(S, V(sg * 0.452, 0.073, 1.4555), (0.014, 0.028, 0.015), 6, 4, ua, "os")
    # cubitus (olécrane en arrière) et radius
    ul = [V(sg * 0.448, 0.092, 1.458), V(sg * 0.475, 0.086, 1.456), V(sg * 0.590, 0.080, 1.452), V(sg * 0.700, 0.076, 1.447)]
    tubeE(S, ul, [0.012, 0.0105, 0.0075, 0.0085], 5, la, "os", up=(0, 0, 1))
    ra = [V(sg * 0.468, 0.058, 1.460), V(sg * 0.580, 0.054, 1.458), V(sg * 0.690, 0.052, 1.455), V(sg * 0.705, 0.052, 1.455)]
    tubeE(S, ra, [0.0085, 0.0075, 0.0120, 0.0125], 5, la, "os", up=(0, 0, 1))
    # main en poing (autour de la poignée de l'arme / de la sangle du bouclier) : carpe + 4 doigts + pouce
    ellipsoidE(S, V(sg * 0.726, 0.064, 1.453), (0.017, 0.028, 0.010), 6, 4, ha, "os")
    for i in range(4):
        y = 0.040 + i * 0.0165
        r = [0.0058, 0.0054, 0.0048, 0.0038]
        dg = [V(sg * 0.738, y + 0.002, 1.456), V(sg * 0.815, y, 1.468), V(sg * 0.870, y, 1.458), V(sg * 0.856, y, 1.426)]
        tube(S, dg, [x * 1.1 for x in r], 4, ha, "os", up=(0, 1, 0))
    po = [V(sg * 0.735, 0.034, 1.448), V(sg * 0.770, 0.020, 1.432), V(sg * 0.810, 0.022, 1.424), V(sg * 0.838, 0.030, 1.426)]
    tube(S, po, [0.0070, 0.0062, 0.0054, 0.0045], 4, ha, "os", up=(0, 0, 1))

print('TRI membres', len(S.f))
# ============================================================================ 4. équipement
# ---------------------------------------------------------------- étoffes et cuir communs (lambeaux)
L_ = obj("lambeaux")
def poids_jupe(l, c, p):
    t = min(1.0, max(0.0, (1.03 - p.z) / 0.30))
    if t <= 0.0:
        return {"pelvis": 1.0}
    if abs(p.x) < 0.03:
        return {"pelvis": 1.0 - 0.5 * t, "thigh_l": 0.25 * t, "thigh_r": 0.25 * t}
    return {"pelvis": 1.0 - 0.6 * t, ("thigh_l" if p.x > 0 else "thigh_r"): 0.6 * t}
# ceinture de cuir (sur la crête iliaque) + boucle de fer
cein = [V(0.162 * math.sin(a), 0.004 - 0.100 * math.cos(a), 1.075 + 0.012 * math.cos(a)) for a in [2 * math.pi * k / 18 for k in range(18)]]
tube(L_, cein, (0.017, 0.005), 4, "pelvis", "cuir", up=(0, 0, 1), loop=True)
boite(L_, V(0.03, -0.100, 1.075), 0.016, 0.004, 0.019, "pelvis", "fer")
# pagne avant / arrière, bords en dents de scie, trous
def jupe(x0, x1, ytop, ztop, zbas, ncol, nlig, arriere, graine):
    r = random.Random(graine)
    dents = [r.uniform(0.0, 0.09) for _ in range(ncol + 1)]
    grille = []
    for l in range(nlig + 1):
        t = l / nlig
        row = []
        for c in range(ncol + 1):
            u = c / ncol
            x = lerp(x0, x1, u)
            z = lerp(ztop, zbas + (dents[c] if l == nlig else 0.0), t)
            pli = 0.008 * math.sin(u * math.pi * ncol * 0.9 + graine)
            y = ytop + (1 if arriere else -1) * (0.020 * t * t + pli + 0.008 * t)
            row.append(V(x, y, z))
        grille.append(row)
    trous = lambda l, c: l > 0 and r.random() < 0.10
    nappe(L_, grille, poids_jupe, "tissu", trous)
jupe(-0.085, 0.090, -0.100, 1.065, 0.770, 5, 4, False, 3)
jupe(0.105, -0.100, 0.106, 1.068, 0.700, 6, 4, True, 7)
for sg in (1, -1):
    jupe(sg * 0.158, sg * 0.164, -0.030, 1.066, 0.850, 1, 3, False, 13 + sg)
# reste de cape déchirée sur le haut du dos (os spine_03 ; le bas suit spine_02)
def poids_cape(l, c, p):
    if p.z > 1.33:
        return {"spine_03": 1.0}
    return {"spine_03": 0.5, "spine_02": 0.5}
rc = random.Random(5)
dents = [rc.uniform(0.0, 0.10) for _ in range(7)]
grille = []
for l in range(5):
    t = l / 4
    row = []
    for cc in range(7):
        u = cc / 6
        a = lerp(-0.80, 0.80, u)
        rx_ = lerp(0.165, 0.185, t); ry_ = lerp(0.140, 0.150, t)
        z = lerp(1.500, 1.200 + dents[cc], t) if l == 4 else lerp(1.500, 1.200, t)
        row.append(V(rx_ * math.sin(a), ry_ * math.cos(a) - 0.005, z))
    grille.append(row)
nappe(L_, grille, poids_cape, "tissu", lambda l, c: l > 0 and rc.random() < 0.12)
# brassard de cuir lacé sur l'avant-bras gauche et bandes sur le droit
tube(L_, [V(0.600, 0.068, 1.455), V(0.680, 0.066, 1.452)], [(0.022, 0.024), (0.019, 0.021)], 6, "lowerarm_l", "cuir", up=(0, 0, 1), caps=False)
tube(L_, [V(-0.620, 0.068, 1.455), V(-0.650, 0.067, 1.454)], [(0.019, 0.021), (0.018, 0.020)], 6, "lowerarm_r", "tissu", up=(0, 0, 1), caps=False)

# ---------------------------------------------------------------- casque à nasal (spangenhelm rouillé, de travers)
K = obj("casque")
Rk = Matrix.Rotation(math.radians(5), 3, 'Y') @ Matrix.Rotation(math.radians(-4), 3, 'X')
KC = V(0.0, 0.018, 1.736)
def kdef(p, d):
    q = p - KC
    if d.z < 0.0:
        q.z = 0.0
    q.z *= 1.0 + 0.25 * max(0.0, d.z) ** 3        # pointe légère
    # bosse (enfoncement) sur le côté droit
    dd = (Vector((d.x, d.y, d.z)) - Vector((-0.6, -0.3, 0.6)).normalized()).length
    if dd < 0.35:
        q *= 1.0 - 0.08 * (1.0 - dd / 0.35)
    return KC + Rk @ q
pts = ellipsoid(K, KC, (0.086, 0.106, 0.082), 16, 6, "Head", "fer", deform=kdef)
bande = [KC + Rk @ V(0.088 * math.sin(a), -0.108 * math.cos(a), 0.004) for a in [2 * math.pi * k / 16 for k in range(16)]]
tube(K, bande, (0.010, 0.0045), 4, "Head", "fer", up=(0, 0, 1), loop=True)
tube(K, [KC + Rk @ V(0, -0.112, 0.004), KC + Rk @ V(0, -0.113, -0.040), KC + Rk @ V(0, -0.106, -0.064)], [(0.010, 0.003), (0.008, 0.003), (0.006, 0.003)], 4, "Head", "fer", up=(0, -1, 0))
for a in (0.0, math.pi * 0.5, math.pi, math.pi * 1.5):
    ar = [KC + Rk @ V(0.090 * math.sin(a) * (1 - t * 0.9), -0.110 * math.cos(a) * (1 - t * 0.9), 0.010 + 0.088 * math.sin(t * math.pi * 0.5)) for t in (0.0, 0.35, 0.7, 0.98)]
    tube(K, ar, 0.0045, 3, "Head", "fer", up=(0, 0, 1))
# couvre-joue gauche pendant (un seul reste)
plaque(K, [KC + Rk @ V(0.090, -0.040, -0.002), KC + Rk @ V(0.092, 0.010, -0.002), KC + Rk @ V(0.086, 0.004, -0.070), KC + Rk @ V(0.082, -0.036, -0.060)], V(1, 0, 0), 0.004, "Head", "fer")

# ---------------------------------------------------------------- capuche en lambeaux (archer)
H = obj("capuche")
HC = V(0.0, 0.026, 1.712)
def poids_cap(l, c, p):
    if p.z > 1.60:
        return {"Head": 1.0}
    if p.z > 1.52:
        return {"Head": 0.5, "neck_01": 0.5}
    return {"spine_03": 0.7, "neck_01": 0.3}
rh = random.Random(21)
grille = []
NC = 14
dh_ = [rh.uniform(0.0, 0.07) for _ in range(NC + 1)]
for l in range(7):
    row = []
    for cc in range(NC + 1):
        u = cc / NC
        a = lerp(0.62, 2 * math.pi - 0.62, u)            # ouverture du visage devant (a = 0 devant)
        if l < 4:
            el = math.radians([80, 55, 25, -5][l])
            r = [0.050, 0.100, 0.110, 0.104][l]
            x = r * math.sin(a) * math.cos(el) * 1.0
            y = -r * 1.15 * math.cos(a) * math.cos(el)
            z = HC.z + 0.100 * math.sin(el) + 0.02
            row.append(V(x * 1.02, HC.y + y, z))
        else:
            t = (l - 3) / 3
            r = lerp(0.105, 0.230, t)
            z = lerp(1.600, 1.395, t) - (dh_[cc] if l == 6 else 0.0)
            row.append(V(r * math.sin(a), 0.035 - r * 0.85 * math.cos(a), z))
    grille.append(row)
nappe(H, grille, poids_cap, "tissu", lambda l, c: l > 3 and rh.random() < 0.10)

# ---------------------------------------------------------------- bouclier rond (avant-bras gauche) : planches, bord de fer, umbo, morceau arraché
B = obj("bouclier")
SC = V(0.600, 0.065 - 0.08, 1.456)
R = 0.19
N16 = 16
manque = {11, 12}                       # secteurs arrachés (bas, côté extérieur)
def rr(k, r):
    return r * (0.62 if k in manque else 1.0) * (1.0 + 0.03 * math.sin(k * 2.1))
for face, dy in ((0, -0.007), (1, 0.007)):
    centre = B.pt(SC + V(0, dy, 0), "lowerarm_l")
    an = []
    for r in (0.05, 0.13, R):
        an.append([B.pt(SC + V(rr(k, r) * math.cos(2 * math.pi * k / N16) if r == R else r * math.cos(2 * math.pi * k / N16), dy - (0.006 if r < R and face == 0 else 0.0) * (1 - r / R), rr(k, r) * math.sin(2 * math.pi * k / N16) if r == R else r * math.sin(2 * math.pi * k / N16)), "lowerarm_l") for k in range(N16)])
    cls = "bois_peint" if face == 0 else "bois"
    for k in range(N16):
        j = (k + 1) % N16
        f = [centre, an[0][k], an[0][j]] if face == 1 else [centre, an[0][j], an[0][k]]
        B.face(f, cls)
        for a_ in range(2):
            q = [an[a_][k], an[a_ + 1][k], an[a_ + 1][j], an[a_][j]]
            B.face(q if face == 0 else q[::-1], cls)
    if face == 0:
        avant = an[2]
    else:
        arriere = an[2]
for k in range(N16):
    j = (k + 1) % N16
    B.face([avant[k], arriere[k], arriere[j], avant[j]], "bois")
bord = [SC + V(rr(k, R) * math.cos(2 * math.pi * k / N16), 0, rr(k, R) * math.sin(2 * math.pi * k / N16)) for k in range(N16) if k not in manque and (k - 1) not in manque]
arcb = [SC + V(R * 1.01 * math.cos(2 * math.pi * (k + 0.0) / N16), 0, R * 1.01 * math.sin(2 * math.pi * k / N16)) for k in list(range(13, 16)) + list(range(0, 11))]
tube(B, arcb, (0.010, 0.006), 4, "lowerarm_l", "fer", up=(0, 1, 0))
ellipsoid(B, SC + V(0, -0.010, 0), (0.050, 0.030, 0.050), 8, 4, "lowerarm_l", "fer", deform=lambda p, d: p if d.y < 0.05 else V(p.x, SC.y - 0.006, p.z))
# sangle (le poing gauche la tient)
tube(B, [SC + V(-0.07, 0.010, 0.0), SC + V(0.0, 0.026, 0.0), SC + V(0.07, 0.010, 0.0)], (0.004, 0.014), 4, "lowerarm_l", "cuir", up=(0, 1, 0))

# ---------------------------------------------------------------- armes, repère de la prise de l'épée du joueur (draugr.gd : prise)
O = V(-0.849425, 0.063159, 1.447565)
XB = V(0.038334, 0.005288, -0.999251)
YB = V(-0.24307, -0.969901, -0.014458)
ZB = V(-0.969252, 0.243442, -0.035895)
def P(lx, ly, lz):
    return O + XB * lx + YB * ly + ZB * lz
# épée rouillée ébréchée
E = obj("epee")
tube(E, [P(0, -0.048, 0), P(0, -0.030, 0)], [0.020, 0.016], 6, "hand_r", "fer", up=tuple(XB))
tube(E, [P(0, -0.030, 0), P(0, 0.010, 0), P(0, 0.060, 0), P(0, 0.098, 0)], [0.013, 0.014, 0.014, 0.012], 6, "hand_r", "cuir", up=tuple(XB), caps=False)
tube(E, [P(-0.090, 0.104, 0), P(-0.030, 0.112, 0), P(0.030, 0.112, 0), P(0.090, 0.104, 0)], [(0.009, 0.007)] * 4, 4, "hand_r", "fer", up=tuple(YB))
nick = [1.0, 1.0, 0.82, 1.0, 1.0, 0.86, 1.0, 0.9, 1.0]
lames = []
for i, ly in enumerate([0.118, 0.19, 0.27, 0.35, 0.43, 0.51, 0.59, 0.67, 0.74]):
    w = 0.026 - 0.006 * (ly - 0.118) / 0.62
    wl = w * nick[i]; wr = w * nick[(i + 3) % 9]
    lames.append([P(wl, ly, 0), P(wl * 0.4, ly, 0.0055), P(-wr * 0.4, ly, 0.0055), P(-wr, ly, 0), P(-wr * 0.4, ly, -0.0055), P(wl * 0.4, ly, -0.0055)])
ids = [[E.pt(p, "hand_r") for p in r] for r in lames]
for k in range(len(ids) - 1):
    for i in range(6):
        j = (i + 1) % 6
        E.face([ids[k][i], ids[k][j], ids[k + 1][j], ids[k + 1][i]], "fer")
pointe = E.pt(P(0.002, 0.79, 0), "hand_r")
for i in range(6):
    E.face([ids[-1][i], ids[-1][(i + 1) % 6], pointe], "fer")
E.face(ids[0][::-1], "fer")
# hache barbue (manche passé dans le poing)
X = obj("hache")
tube(X, [P(0, -0.12, 0), P(0, 0.10, 0), P(0, 0.40, 0), P(0, 0.56, 0)], [0.014, 0.015, 0.014, 0.0135], 6, "hand_r", "bois", up=tuple(XB))
tube(X, [P(0, -0.02, 0), P(0, 0.08, 0)], [0.0155, 0.0155], 6, "hand_r", "cuir", up=tuple(XB), caps=False)
prof_h = [(0.0, 0.47), (0.050, 0.47), (0.100, 0.40), (0.145, 0.37), (0.150, 0.50), (0.120, 0.58), (0.050, 0.555), (0.0, 0.555)]
for e_, sgn in ((0.012, 1), (0.003, 1)):
    pass
fa = [X.pt(P(-x * 1.0 - 0.012, y, 0.0085 * (1.0 - x / 0.16)), "hand_r") for x, y in prof_h]
fb = [X.pt(P(-x * 1.0 - 0.012, y, -0.0085 * (1.0 - x / 0.16)), "hand_r") for x, y in prof_h]
X.face(fa, "fer"); X.face(fb[::-1], "fer")
for i in range(len(prof_h)):
    j = (i + 1) % len(prof_h)
    X.face([fa[i], fb[i], fb[j], fa[j]], "fer")
# arc (même place que l'ancien maillage « arc » : les archers bandits et draugrs le reprennent)
A = obj("arc")
pts_arc = [(-0.50, -0.16), (-0.44, -0.12), (-0.30, -0.05), (-0.14, -0.012), (0.0, 0.0), (0.14, -0.012), (0.30, -0.05), (0.44, -0.12), (0.50, -0.16)]
cen = [P(lx, 0.040, lz) for lx, lz in pts_arc]
cen[0] = P(-0.52, 0.040, -0.135); cen[-1] = P(0.52, 0.040, -0.135)
dem = [0.006, 0.008, 0.011, 0.014, 0.017, 0.014, 0.011, 0.008, 0.006]
tube(A, cen, [(d, d * 0.8) for d in dem], 5, "hand_r", "bois", up=tuple(YB))
tube(A, [P(-0.06, 0.040, 0.0), P(0.06, 0.040, 0.0)], [0.0185, 0.0185], 6, "hand_r", "cuir", up=tuple(YB), caps=False)
tube(A, [P(-0.49, 0.040, -0.150), P(0.49, 0.040, -0.150)], 0.0022, 3, "hand_r", "corde", up=tuple(YB))
# carquois au dos (archer) + baudrier
Q = obj("carquois")
qa = V(0.085, 0.130, 1.140); qb = V(-0.060, 0.140, 1.480)
tube(Q, [qa, lerp(qa, qb, 0.5), qb], [0.034, 0.038, 0.040], 8, "spine_03", "cuir", up=(0, 1, 0))
ax = (qb - qa).normalized()
for i in range(7):
    a = 2 * math.pi * i / 7
    off = V(math.cos(a) * 0.022, 0.0, math.sin(a) * 0.022)
    off = off - ax * off.dot(ax)
    b0 = qb + off - ax * 0.02
    b1 = qb + off + ax * (0.10 + 0.02 * (i % 3))
    tube(Q, [b0, b1], 0.0035, 3, "spine_03", "bois", up=(0, 1, 0))
    fl = [b1 - ax * 0.06 + off.normalized() * 0.002, b1 - ax * 0.005 + off.normalized() * 0.002, b1 - ax * 0.005 + off.normalized() * 0.012, b1 - ax * 0.05 + off.normalized() * 0.012]
    i4 = [Q.pt(p, "spine_03") for p in fl]
    Q.face(i4, "plume")
bd = bez([V(-0.130, 0.090, 1.495), V(-0.150, -0.020, 1.470), V(-0.080, -0.128, 1.380), V(0.060, -0.132, 1.230), V(0.150, -0.060, 1.130), V(0.120, 0.100, 1.120)], 9)
tube(Q, bd, (0.016, 0.004), 4, "spine_03", "cuir", up=(0, 0, 1))

# ============================================================================ 5. maillages Blender
def fabriquer(o):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in o.v]
    bm.verts.index_update()
    cl = bm.faces.layers.int.new("cls")
    for ids, c in zip(o.f, o.c):
        try:
            f = bm.faces.new([vs[i] for i in ids])
        except ValueError:
            continue
        f[cl] = c
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(52):
            e.smooth = False
    me = bpy.data.meshes.new(o.nom)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(o.nom, me)
    bpy.context.collection.objects.link(ob)
    # poids
    grp = {}
    for i, w in enumerate(o.w):
        for b, x in w.items():
            if b not in grp:
                grp[b] = ob.vertex_groups.new(name=b)
            grp[b].add([i], x, 'REPLACE')
    # couleur de sommet « lueur » (alpha) et classe par coin
    ca = me.color_attributes.new("lueur", 'FLOAT_COLOR', 'POINT')
    for i, a in enumerate(o.a):
        ca.data[i].color = (1.0, 1.0, 1.0, a)
    me.color_attributes.active_color = ca
    me.color_attributes.render_color_index = me.color_attributes.find("lueur")
    cc = me.color_attributes.new("classe", 'FLOAT_COLOR', 'CORNER')
    clsl = me.attributes["cls"].data
    for p in me.polygons:
        c = clsl[p.index].value
        for li in p.loop_indices:
            cc.data[li].color = ((c + 0.5) / 16.0, 0.0, 0.0, 1.0)
    return ob

objets = {nom: fabriquer(o) for nom, o in OBJS.items()}
tris = {nom: sum(len(p.vertices) - 2 for p in ob.data.polygons) for nom, ob in objets.items()}
print("TRIANGLES :", tris)
print("VARIANTES : guerrier %d, archer %d, hache %d" % (tris["squelette"] + tris["lambeaux"] + tris["casque"] + tris["bouclier"] + tris["epee"],
      tris["squelette"] + tris["lambeaux"] + tris["capuche"] + tris["carquois"] + tris["arc"], tris["squelette"] + tris["lambeaux"] + tris["hache"]))

# ============================================================================ 6. UV (un seul atlas, densité uniforme)
bpy.ops.object.select_all(action='DESELECT')
for ob in objets.values():
    ob.select_set(True)
    ob.data.uv_layers.new(name="UVMap")
bpy.context.view_layer.objects.active = objets["squelette"]
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(88), island_margin=0.0, area_weight=0.0, scale_to_bounds=False)
bpy.ops.uv.select_all(action='SELECT')
bpy.ops.uv.pack_islands(udim_source='CLOSEST_UDIM', rotate=True, margin_method="FRACTION", margin=0.004)
bpy.ops.object.mode_set(mode='OBJECT')
a3 = 0.0; a2 = 0.0
for ob in objets.values():
    me = ob.data
    uv = me.uv_layers.active.data
    for p in me.polygons:
        a3 += p.area
        li = list(p.loop_indices)
        u0 = uv[li[0]].uv
        for k in range(1, len(li) - 1):
            u1 = uv[li[k]].uv; u2 = uv[li[k + 1]].uv
            a2 += abs((u1 - u0).cross(u2 - u0)) * 0.5
DENS = math.sqrt(a2 / a3) * ATLAS
print("UV : surface 3D %.3f m2, remplissage %.0f %%, densite %.0f texels/m" % (a3, a2 * 100, DENS))

# ============================================================================ 7. bake + peinture
def hexc(h):
    return np.array([int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)], dtype=np.float32) / 255.0
def rampe(*hs):
    return np.stack([hexc(h) for h in hs])
RAMPES = {
    "ivoire": rampe("#1b1713", "#2b251e", "#433a2f", "#5f5444", "#7d705b", "#998b71", "#b3a588", "#cbbf9f", "#ddd3b6"),
    "tache": rampe("#1c1712", "#2e261c", "#433727", "#5a4a34", "#6f5c41", "#84704f"),
    "crasse": rampe("#141310", "#1f1d18", "#2c2a22", "#3a372c"),
    "dent": rampe("#2a241b", "#5e5442", "#958667", "#bdb08c", "#d8cda9"),
    "fer": rampe("#14120f", "#29251f", "#3f3931", "#585046", "#776d5f", "#9c9180"),
    "rouille": rampe("#20160f", "#33231a", "#4a3222", "#61432c", "#775436", "#8a6440"),
    "cuir": rampe("#17110c", "#281e15", "#3b2c1f", "#4f3c2b", "#644d38", "#7b6047"),
    "tissu": rampe("#171513", "#24211d", "#332f29", "#443f37", "#565046", "#6a6255"),
    "bois": rampe("#100e0c", "#1c1915", "#29251f", "#37322a", "#464036", "#575045", "#6a6255"),
    "peint": rampe("#1f0f0c", "#331812", "#4a2219", "#5e2d20", "#73392a", "#874834"),
    "corde": rampe("#3b3226", "#5a4d3a", "#7a6a51", "#958466"),
    "plume": rampe("#1d1b19", "#34302c", "#4d4741", "#6a635a"),
}
ORBITE = hexc("#070606")
OEIL = hexc("#24323e")

def bruit(P, f, s):
    X = P[..., 0] * f + s * 17.1; Y = P[..., 1] * f + s * 3.7; Z = P[..., 2] * f + s * 9.3
    ix, iy, iz = np.floor(X), np.floor(Y), np.floor(Z)
    fx, fy, fz = X - ix, Y - iy, Z - iz
    fx, fy, fz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    def h(a, b, c):
        v = np.sin((ix + a) * 127.1 + (iy + b) * 311.7 + (iz + c) * 74.7) * 43758.5453
        return v - np.floor(v)
    x00 = h(0, 0, 0) * (1 - fx) + h(1, 0, 0) * fx; x10 = h(0, 1, 0) * (1 - fx) + h(1, 1, 0) * fx
    x01 = h(0, 0, 1) * (1 - fx) + h(1, 0, 1) * fx; x11 = h(0, 1, 1) * (1 - fx) + h(1, 1, 1) * fx
    return (x00 * (1 - fy) + x10 * fy) * (1 - fz) + (x01 * (1 - fy) + x11 * fy) * fz

def fbm(P, f, s, o=3):
    t = 0.0; a = 1.0; n = 0.0
    for k in range(o):
        t = t + bruit(P, f * (2 ** k), s + k) * a; n += a; a *= 0.5
    return t / n

def quant(nom, ton, jit):
    r = RAMPES[nom]
    i = np.clip(np.floor(ton * (len(r) - 1) + 0.5 + jit), 0, len(r) - 1).astype(int)
    return r[i]

def cuire_tout():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = False
    sc.render.bake.margin = 3
    sc.render.bake.margin_type = "EXTEND"
    sc.view_settings.view_transform = "Standard"
    W = ATLAS * SUPER
    mat = bpy.data.materials.new("bake")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    tx = nt.nodes.new("ShaderNodeTexImage")
    nt.nodes.active = tx
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = 24
    ca = nt.nodes.new("ShaderNodeVertexColor"); ca.layer_name = "classe"
    la = nt.nodes.new("ShaderNodeVertexColor"); la.layer_name = "lueur"
    for ob in objets.values():
        ob.data.materials.clear()
        ob.data.materials.append(mat)
    res = {}
    def passe(nom, sortie, samples, cacher=()):
        img = bpy.data.images.new("b_" + nom, W, W, float_buffer=True, alpha=True)
        img.colorspace_settings.name = "Non-Color"
        img.generated_color = (0, 0, 0, 0)
        tx.image = img
        for l in list(em.inputs["Color"].links):
            nt.links.remove(l)
        nt.links.new(sortie, em.inputs["Color"])
        sc.cycles.samples = samples
        for n_ in cacher:
            objets[n_].hide_render = True
        bpy.ops.object.select_all(action='DESELECT')
        for n_, ob in objets.items():
            if n_ not in cacher:
                ob.select_set(True)
        bpy.context.view_layer.objects.active = objets["squelette"]
        bpy.ops.object.bake(type="EMIT", margin=3)
        for n_ in cacher:
            objets[n_].hide_render = False
        px = np.empty(W * W * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        res[nom] = px.reshape(W, W, 4)[::-1].copy()
        print("bake", nom)
    passe("pos", geo.outputs["Position"], 1)
    passe("nrm", geo.outputs["Normal"], 1)
    passe("cls", ca.outputs["Color"], 1)
    passe("lueur", la.outputs["Alpha"], 1)
    passe("arete", geo.outputs["Pointiness"], 1)
    ao.inputs["Distance"].default_value = 0.10
    nt.links.new(ao.outputs["AO"], em.inputs["Color"])
    # AO large : la capuche (archer) et le casque (guerrier) ne se portent pas d'ombre l'un l'autre ; armes non portées cachées
    passe("ao_l", ao.outputs["AO"], 24)
    ao.inputs["Distance"].default_value = 0.02
    passe("ao_p", ao.outputs["AO"], 24)
    return res

if not SANS_BAKE:
    R_ = cuire_tout()
    W = ATLAS * SUPER
    def red(a):
        sh = a.shape
        return a.reshape(ATLAS, SUPER, ATLAS, SUPER, *sh[2:]).mean((1, 3))
    # couverture : texels où la classe est écrite (bake : alpha 1)
    cov = red((R_["cls"][..., 3] > 0.5).astype(np.float32)) > 0.25
    # la classe, la position, la normale : échantillon du centre (pas de moyenne entre classes)
    cls = np.floor(R_["cls"][SUPER // 2::SUPER, SUPER // 2::SUPER, 0] * 16.0).astype(int)
    Pp = R_["pos"][SUPER // 2::SUPER, SUPER // 2::SUPER, :3]
    Nn = R_["nrm"][SUPER // 2::SUPER, SUPER // 2::SUPER, :3]
    ao_l = red(R_["ao_l"][..., 0]); ao_p = red(R_["ao_p"][..., 0]); ar = red(R_["arete"][..., 0]); lu = red(R_["lueur"][..., 0])
    print("pointiness p5/50/95 :", np.percentile(ar[cov], [5, 50, 95]).round(3), " ao_l moy %.2f ao_p moy %.2f" % (ao_l[cov].mean(), ao_p[cov].mean()))
    img = np.zeros((ATLAS, ATLAS, 3), dtype=np.float32)
    alpha = np.ones((ATLAS, ATLAS), dtype=np.float32)
    jit = (bruit(Pp, 1.0 / 0.0045, 41) - 0.5) * 0.75 + (bruit(Pp, 1.0 / 0.011, 43) - 0.5) * 0.35
    L = 0.45 * ao_l + 0.55 * ao_p
    arete = np.clip((ar - 0.515) / 0.05, 0, 1)
    creux = np.clip((0.48 - ar) / 0.05, 0, 1)
    haut = Nn[..., 2]
    eclair = 0.10 * haut - 0.04 * np.abs(Nn[..., 1])
    n1 = fbm(Pp, 1.0 / 0.06, 1); n2 = fbm(Pp, 1.0 / 0.018, 2); n3 = bruit(Pp, 1.0 / 0.20, 3)
    def m(nom):
        return cov & (cls == CID[nom])
    # --- os : ivoire patiné, taches brunes, crasse dans les creux, poussière vers le bas, fêlures
    k = m("os")
    ton = 0.45 + eclair + (L - 0.80) * 1.05 + (n1 - 0.5) * 0.30 + (n2 - 0.5) * 0.18 + arete * 0.22 - creux * 0.22
    ton -= 0.16 * np.clip((0.55 - Pp[..., 2]) / 0.5, 0, 1)             # bas des jambes plus sales
    tache = (fbm(Pp, 1.0 / 0.03, 7) + 0.20 * (n3 - 0.5)) > 0.66
    crasse = ((L < 0.55) | (creux > 0.6)) & (n2 > 0.40)
    fel = (np.abs(fbm(Pp, 1.0 / 0.035, 9) - 0.5) < 0.012) & (arete < 0.5)
    c = quant("ivoire", np.clip(ton, 0, 1), jit)
    c = np.where(tache[..., None], quant("tache", np.clip(ton * 1.05, 0, 1), jit), c)
    c = np.where(crasse[..., None], quant("crasse", np.clip(ton * 1.4, 0, 1), jit), c)
    c = np.where(fel[..., None], RAMPES["tache"][1], c)
    img[k] = c[k]
    # --- dents : alternance dent / interstice le long de l'arcade
    k = m("dent")
    ang = np.arctan2(Pp[..., 0], -(Pp[..., 1] - 0.02))
    inter = (np.abs(((ang / 0.14) % 1.0) - 0.5) > 0.40) | (np.abs(Nn[..., 2]) > 0.75)
    ton = 0.62 + (L - 0.85) * 1.2 + (n2 - 0.5) * 0.3
    c = quant("dent", np.clip(ton, 0, 1), jit)
    c = np.where(inter[..., None], RAMPES["crasse"][0], c)
    cass = (bruit(Pp, 1.0 / 0.008, 12) > 0.80)
    c = np.where(cass[..., None], RAMPES["crasse"][1], c)
    img[k] = c[k]
    # --- orbites, cavité nasale, œil
    img[m("orbite")] = ORBITE
    k = m("oeil")
    img[k] = np.where((lu[k] < 0.5)[..., None], OEIL, ORBITE * 1.5)
    # --- fer rouillé : plaques de rouille, arêtes usées claires, rivets
    k = m("fer")
    ton = 0.45 + eclair * 1.3 + (L - 0.8) * 1.1 + arete * 0.35 + (n2 - 0.5) * 0.25
    rou = (fbm(Pp, 1.0 / 0.035, 21) * 0.7 + n2 * 0.3) > 0.52
    c = np.where(rou[..., None], quant("rouille", np.clip(ton * 0.95 + (n1 - 0.5) * 0.3, 0, 1), jit), quant("fer", np.clip(ton, 0, 1), jit))
    # rivets du casque (bande du front et arêtes)
    dk = Pp - np.array([0.0, 0.018, 1.736])
    angk = np.arctan2(dk[..., 0], -dk[..., 1])
    riv = (np.abs(dk[..., 2] - 0.004) < 0.007) & (np.abs(((angk / (2 * np.pi / 18)) % 1.0) - 0.5) < 0.10) & (np.linalg.norm(dk, axis=-1) < 0.13)
    c = np.where(riv[..., None], RAMPES["fer"][5], c)
    img[k] = c[k]
    # --- cuir : craquelé, bords usés
    k = m("cuir")
    ton = 0.48 + eclair + (L - 0.8) * 1.1 + arete * 0.28 + (n2 - 0.5) * 0.35
    cr = np.abs(fbm(Pp, 1.0 / 0.012, 25) - 0.5) < 0.03
    c = quant("cuir", np.clip(ton - cr * 0.25, 0, 1), jit)
    img[k] = c[k]
    # --- étoffe : laine cendrée pourrie, fil vertical, saleté, trous (alpha)
    k = m("tissu")
    fil = bruit(Pp * np.array([1.0, 1.0, 0.15]), 1.0 / 0.006, 31)
    ton = 0.46 + eclair * 0.6 + (L - 0.8) * 1.0 + (n1 - 0.5) * 0.45 + (fil - 0.5) * 0.25
    ton -= 0.18 * np.clip((1.0 - Pp[..., 2]) / 0.3, 0, 1) * (Pp[..., 2] < 1.0)
    c = quant("tissu", np.clip(ton, 0, 1), jit)
    img[k] = c[k]
    trou = k & (fbm(Pp, 1.0 / 0.03, 33) > 0.66)
    alpha[trou] = 0.0
    # --- bois (revers du bouclier, manche, arc, flèches) et face peinte du bouclier
    for nom in ("bois", "bois_peint"):
        k = m(nom)
        rel = Pp - np.array([SC.x, SC.y, SC.z])
        pl = np.floor((rel[..., 0] + 0.4) / 0.066)
        grain = bruit(Pp * np.array([3.0, 3.0, 0.25]), 1.0 / 0.01, 51 + pl * 0.0)
        joint = np.abs(((rel[..., 0] + 0.4) / 0.066) % 1.0 - 0.5) > 0.44
        ton = 0.45 + eclair + (L - 0.8) * 1.0 + (grain - 0.5) * 0.4 + ((pl % 3) - 1) * 0.07 + arete * 0.2
        c = quant("bois", np.clip(ton, 0, 1), jit)
        if nom == "bois_peint":
            r_ = np.hypot(rel[..., 0], rel[..., 2])
            a_ = np.arctan2(rel[..., 2], rel[..., 0])
            secteur = (np.floor((a_ + np.pi) / (np.pi / 4)) % 2) == 0
            ecaille = fbm(Pp, 1.0 / 0.025, 55) > 0.50
            peint = secteur & ~ecaille & (r_ > 0.055)
            c = np.where(peint[..., None], quant("peint", np.clip(ton * 0.95, 0, 1), jit), c)
            c = np.where((joint & (r_ > 0.05))[..., None], RAMPES["bois"][0], c)
        img[k] = c[k]
    for nom, rp in (("corde", "corde"), ("plume", "plume")):
        k = m(nom)
        img[k] = quant(rp, np.clip(0.5 + (L - 0.8) + (n2 - 0.5) * 0.4, 0, 1), jit)[k]
    # dilatation des couleurs dans les marges (mipmaps sans franges noires)
    remp = cov.copy()
    for it in range(12):
        nouv = np.zeros_like(remp)
        acc = np.zeros_like(img); cnt = np.zeros(remp.shape, dtype=np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sh = np.roll(np.roll(remp, dy, 0), dx, 1)
            shc = np.roll(np.roll(img, dy, 0), dx, 1)
            acc += shc * sh[..., None]; cnt += sh
        nouv = (~remp) & (cnt > 0)
        img[nouv] = acc[nouv] / cnt[nouv][..., None]
        remp |= nouv
    q = np.round(img * 31.0) / 31.0                              # palette 15 bits
    rgba = np.ones((ATLAS, ATLAS, 4), dtype=np.float32)
    rgba[..., :3] = q
    rgba[..., 3] = alpha
    pim = bpy.data.images.new("squelette_nordique_atlas", ATLAS, ATLAS, alpha=True)
    pim.pixels.foreach_set(rgba[::-1].ravel())
    pim.filepath_raw = OUT_PNG
    pim.file_format = 'PNG'
    pim.save()
    print("ATLAS ecrit", OUT_PNG, " couverture %.0f %%" % (cov.mean() * 100))

# ============================================================================ 8. export
mat_os = bpy.data.materials.new("squelette_os")
mat_os.use_nodes = True
for ob in objets.values():
    ob.data.materials.clear()
    ob.data.materials.append(mat_os)
    ob.parent = arm
    mod = ob.modifiers.new("Armature", 'ARMATURE'); mod.object = arm
    me = ob.data
    if "classe" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["classe"])
    if "cls" in me.attributes:
        me.attributes.remove(me.attributes["cls"])
    me.color_attributes.active_color = me.color_attributes["lueur"]
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
kw = dict(filepath=OUT_GLB, export_format='GLB', use_selection=True, export_skins=True, export_animations=False, export_apply=False)
try:
    bpy.ops.export_scene.gltf(**kw, export_vertex_color='ACTIVE', export_all_vertex_colors=False)
except TypeError as e:
    print("options couleur :", e)
    bpy.ops.export_scene.gltf(**kw, export_colors=True)
print("EXPORT OK", OUT_GLB)

# ============================================================================ 9. aperçu (facultatif)
if APERCU:
    os.makedirs(APERCU, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE" if os.path.exists(OUT_PNG) else "SINGLE"
    sc.render.resolution_x = 640; sc.render.resolution_y = 900
    timg = bpy.data.images.load(OUT_PNG) if os.path.exists(OUT_PNG) else None
    mt = bpy.data.materials.new("apercu"); mt.use_nodes = True
    if timg:
        tn = mt.node_tree.nodes.new("ShaderNodeTexImage"); tn.image = timg; tn.interpolation = "Closest"
        bsdf = next(n for n in mt.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        mt.node_tree.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    for ob in objets.values():
        ob.data.materials.clear(); ob.data.materials.append(mt)
    variante = [a.split("=", 1)[1] for a in ARGS if a.startswith("--montrer=")]
    montrer = variante[0].split(",") if variante else ["squelette", "lambeaux", "casque", "bouclier", "epee"]
    for n_, ob in objets.items():
        ob.hide_render = n_ not in montrer
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = "ORTHO"
    zoom = next((a.split("=", 1)[1] for a in ARGS if a.startswith("--zoom=")), "")
    for nom, d in (("face", V(0, -1, 0)), ("profil", V(1, 0, 0)), ("dos", V(0, 1, 0)), ("34", V(0.7, -0.7, 0.15))):
        if zoom == "tete":
            cam.data.ortho_scale = 0.36; cible = V(0, 0, 1.68)
        else:
            cam.data.ortho_scale = 2.0; cible = V(0, 0, 0.95)
        cam.location = cible + d.normalized() * 4
        cam.rotation_euler = (cible - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(APERCU, "%s%s.png" % (nom, "_" + zoom if zoom else ""))
        bpy.ops.render.render(write_still=True)
    print("APERCU", APERCU)
