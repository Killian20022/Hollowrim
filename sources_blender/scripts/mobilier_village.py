# Village v2 : MODULES DE MOBILIER (puits couvert, étal, bannière, brasero, banc, tonneaux, caisses, charrette, tas de bois).
#   blender.exe -b --python mobilier_village.py            (ajouter « -- apercu » pour rendre des aperçus dans captures/mobilier/)
# Sorties : assets/modeles/mobilier_village.dat (+ .glb d'inspection) et sources_blender/mobilier_village.blend
# Format .dat identique à roches_sol_v2.dat : [u32 nb][u8 long][nom][u32 nb sommets][x y z r g b a float32]..., repère Godot.
# Une entrée = « <module>/<matiere> » ; matières appliquées en triplanaire par le jeu (aucune UV).
# Couleurs de sommets : rgb = occlusion peinte (pied et dessous sombres), a = 0 là où la neige recouvre.
# Chaque module : origine au sol au centre de l'emprise, face avant vers +Y Blender (= -Z Godot), mètres réels, normales plates.
# « banniere_tissu » a son origine au point d'accroche (haut centre du tissu) pour le balancement en jeu.
import bpy, math, os, random, struct, sys
from mathutils import Vector, Matrix, Euler, noise

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
GLB = os.path.join(BASE, "assets", "modeles", "mobilier_village.glb")
DAT = os.path.join(BASE, "assets", "modeles", "mobilier_village.dat")
BLEND = os.path.join(BASE, "sources_blender", "mobilier_village.blend")
CAPT = os.path.join(BASE, "captures", "mobilier")
MATIERES = ("pierre_brute", "pierre_fine", "planches_h", "planches_v", "fer", "cuir", "tenture_rouge", "peau", "foin", "braises")
BUDGET = {"puits": 1800, "etal": 1500, "banniere": 500, "brasero": 500, "banc": 250, "tonneau_a": 300, "tonneau_b": 300,
          "caisse_a": 150, "caisse_b": 150, "charrette": 1300, "tas_bois": 900}
DONNEES = {}      # "module/matiere" -> [(Vector Blender, (r, g, b, a))]
ORIGINES = {}     # entrée -> décalage de l'origine dans le repère du module parent (Blender)
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
TAU = 2 * math.pi


def V(x, y, z):
    return Vector((x, y, z))


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def newell(pts):
    n = Vector((0, 0, 0))
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n.normalized() if n.length > 1e-12 else Vector((0, 0, 1))


def rev(faces):
    return [list(reversed(f)) for f in faces]


def orient(f, d):
    return f if newell(f).dot(d) >= 0 else list(reversed(f))


def deux_faces(faces, ep=0.004):
    """Tissu fin : face avant + copie retournée décalée de ep vers l'arrière."""
    out = list(faces)
    for f in faces:
        n = newell(f)
        out.append([p - n * ep for p in reversed(f)])
    return out


# ------------------------------------------------------------------------------------------------ primitives
def box_frame(o, U, Vv, N, jit=0.0, rg=None, omit=()):
    if U.cross(Vv).dot(N) < 0:
        U, Vv = Vv, U
    c = [o, o + U, o + U + Vv, o + Vv]
    c = c + [p + N for p in c]
    if jit:
        c = [p + V(rg.uniform(-jit, jit), rg.uniform(-jit, jit), rg.uniform(-jit, jit)) for p in c]
    idx = {"bas": (0, 3, 2, 1), "haut": (4, 5, 6, 7), "f1": (0, 1, 5, 4), "f2": (1, 2, 6, 5), "f3": (2, 3, 7, 6), "f4": (3, 0, 4, 7)}
    return [[c[i] for i in f] for k, f in idx.items() if k not in omit]


def box(c, sx, sy, sz, rz=0.0, tx=0.0, ty=0.0, jit=0.0, rg=None, omit=()):
    """Bloc posé : c = centre de la base."""
    R = Euler((tx, ty, rz)).to_matrix()
    U, Vv, N = R @ V(sx, 0, 0), R @ V(0, sy, 0), R @ V(0, 0, sz)
    return box_frame(c - U / 2 - Vv / 2, U, Vv, N, jit, rg, omit)


def beam(a, b, w, h, up=Z, jit=0.0, rg=None, omit=()):
    """Poutre de section w x h de a à b (h dans le plan vertical)."""
    d = b - a
    side = d.cross(up)
    if side.length < 1e-6:
        side = d.cross(X)
    side.normalize()
    N = side.cross(d).normalized()
    return box_frame(a - side * w / 2 - N * h / 2, d, side * w, N * h, jit, rg, omit)


def cyl(a, b, r, n=6, r2=None, caps=(True, True), rot=0.0, jit=0.0, rg=None, ts=(0.0, 1.0), rfn=None, ech=(1.0, 1.0)):
    d = b - a
    L = d.length
    M = d.to_track_quat('Z', 'Y').to_matrix()
    rr2 = r if r2 is None else r2
    rings = []
    for t in ts:
        rr = r + (rr2 - r) * t
        if rfn:
            rr *= rfn(t)
        ring = []
        for k in range(n):
            an = rot + TAU * k / n
            p = V(math.cos(an) * rr * ech[0], math.sin(an) * rr * ech[1], t * L)
            if jit:
                p += V(rg.uniform(-jit, jit), rg.uniform(-jit, jit), rg.uniform(-jit, jit) * 0.5)
            ring.append(a + M @ p)
        rings.append(ring)
    faces = []
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for k in range(n):
            k1 = (k + 1) % n
            faces.append([r0[k], r0[k1], r1[k1], r1[k]])
    if caps[0]:
        faces.append(list(reversed(rings[0])))
    if caps[1]:
        faces.append(list(rings[-1]))
    return faces


def secteur(rin, rout, z0, z1, a0, a1, nseg, ferme=False, M=None, c=None, jit=0.0, rg=None, quoi=("ext", "int", "haut", "bas")):
    """Anneau / portion d'anneau à section rectangulaire autour de l'axe local Z (M : rotation, c : centre)."""
    M = M or Matrix.Identity(3)
    c = c if c is not None else V(0, 0, 0)
    nb = nseg if ferme else nseg + 1
    ib, ob, ot, it = [], [], [], []
    for k in range(nb):
        an = a0 + (a1 - a0) * k / nseg
        co, si = math.cos(an), math.sin(an)
        def P(r, z):
            p = V(co * r, si * r, z)
            if jit:
                p += V(rg.uniform(-jit, jit), rg.uniform(-jit, jit), rg.uniform(-jit, jit))
            return c + M @ p
        ib.append(P(rin, z0)); ob.append(P(rout, z0)); ot.append(P(rout, z1)); it.append(P(rin, z1))
    faces = []
    for k in range(nseg):
        k1 = (k + 1) % nb
        if "ext" in quoi:
            faces.append([ob[k], ob[k1], ot[k1], ot[k]])
        if "int" in quoi:
            faces.append([ib[k1], ib[k], it[k], it[k1]])
        if "haut" in quoi:
            faces.append([it[k], ot[k], ot[k1], it[k1]])
        if "bas" in quoi:
            faces.append([ib[k], ib[k1], ob[k1], ob[k]])
    if not ferme:
        faces.append([ib[0], ob[0], ot[0], it[0]])
        faces.append([it[-1], ot[-1], ob[-1], ib[-1]])
    return faces


def disque(c, r, n, z_up=True, rot=0.0, jit=0.0, rg=None, M=None):
    M = M or Matrix.Identity(3)
    pts = []
    for k in range(n):
        an = rot + TAU * k / n
        rr = r + (rg.uniform(-jit, jit) if jit else 0.0)
        pts.append(c + M @ V(math.cos(an) * rr, math.sin(an) * rr, 0))
    return [pts if z_up else list(reversed(pts))]


# ------------------------------------------------------------------------------------------------ modules
class Module:
    def __init__(self, nom, graine, hs=1.0):
        self.nom = nom
        self.rg = random.Random(graine)
        self.hs = hs
        self.off = V(graine * 0.311, graine * 0.173, graine * 0.071)
        self.parts = []

    def j(self, s):
        return self.rg.uniform(-s, s)

    def add(self, mat, faces, neige=True, ao=1.0, rgb=None, a=None, seuil=-0.45, nzmin=0.62, entree=None, fn=None,
            teinte=(1.0, 1.0, 1.0), org=None):
        assert mat in MATIERES, mat
        self.parts.append(dict(mat=mat, faces=faces, neige=neige, ao=ao, rgb=rgb, a=a, seuil=seuil, nzmin=nzmin,
                               entree=entree or self.nom, fn=fn, teinte=teinte, org=org if org is not None else V(0, 0, 0)))

    def couleur(self, part, p, n):
        w = p + part["org"]
        if part["rgb"] is not None:
            r, g, b = part["rgb"]
        else:
            ao = 0.55 + 0.45 * smooth(0.0, self.hs, w.z)
            if n.z < -0.5:
                ao *= 0.8
            elif n.z > 0.5:
                ao = min(1.0, ao * 1.05)
            k = part["ao"](w, n) if callable(part["ao"]) else part["ao"]
            ao *= k
            ao *= 0.93 + 0.07 * noise.noise(w * 3.3 + self.off)
            ao = max(0.15, min(1.0, ao))
            r, g, b = (min(1.0, ao * t) for t in part["teinte"])
        if part["a"] is not None:
            a = part["a"]
        elif part["fn"] is not None:
            a = 0.0 if part["fn"](w, n) else 1.0
        elif part["neige"] and n.z > part["nzmin"] and noise.noise(w * 2.6 + self.off * 1.7) > part["seuil"]:
            a = 0.0
        else:
            a = 1.0
        return (r, g, b, a)

    def compiler(self):
        for part in self.parts:
            cle = f"{part['entree']}/{part['mat']}"
            lst = DONNEES.setdefault(cle, [])
            for f in part["faces"]:
                n = newell(f)
                cols = [self.couleur(part, p, n) for p in f]
                for i in range(1, len(f) - 1):
                    for k in (0, i, i + 1):
                        lst.append((f[k].copy(), cols[k]))


# ------------------------------------------------------------------------------------------------ 1. puits
def puits():
    m = Module("puits", 101, hs=1.6)
    rg = m.rg
    # margelle : 2 rangs de 7 blocs, joints de 1,5 cm, rang du haut décalé d'un demi-bloc
    for rang in range(2):
        z0, z1 = rang * 0.4, 0.4 + rang * 0.4
        dec = (math.pi / 7) * rang + 0.1
        for i in range(7):
            a0 = dec + TAU * i / 7 + 0.009 + m.j(0.03)
            a1 = dec + TAU * (i + 1) / 7 - 0.009 + m.j(0.03)
            rin = 1.25 + m.j(0.03) + 0.02 * rang
            rout = 1.70 + m.j(0.06) - 0.03 * rang
            zz0 = z0 + (0.006 if rang else -0.02)
            zz1 = z1 + m.j(0.06 if rang else 0.03) - (0.006 if rang == 0 else 0.0)
            q = ("ext", "int", "haut") if rang == 0 else ("ext", "int", "haut", "bas")
            f = secteur(rin, rout, zz0, zz1, a0, a1, 3, jit=0.022, rg=rg, quoi=q)
            ton = rg.uniform(0.85, 1.0)
            m.add("pierre_brute", f, ao=lambda w, n, t=ton: t * (0.62 if math.hypot(w.x, w.y) < 1.4 and n.z < 0.5 else 1.0),
                  seuil=-0.6 if rang else 0.2)
    # puits intérieur sombre + eau noire
    m.add("pierre_fine", rev(cyl(V(0, 0, -0.55), V(0, 0, 0.02), 1.26, 12, caps=(False, False))), neige=False, ao=0.42)
    m.add("fer", disque(V(0, 0, -0.5), 1.27, 12), rgb=(0.2, 0.2, 0.2), neige=False)
    # 4 poteaux aux coins d'un carré de 2,6 m
    for sx in (-1, 1):
        for sy in (-1, 1):
            b = V(sx * 1.3 + m.j(0.03), sy * 1.3 + m.j(0.03), 0)
            t = V(sx * 1.3 + m.j(0.02), sy * 1.3 + m.j(0.02), 2.43)
            m.add("planches_v", beam(b, t, 0.16 + m.j(0.01), 0.16 + m.j(0.01), up=Y, jit=0.008, rg=rg, omit=("bas",)), neige=False)
            # jambe de force poteau -> sablière
            m.add("planches_v", beam(V(sx * 1.3, sy * 1.3, 1.95), V(sx * 0.85, sy * 1.3, 2.47), 0.08, 0.09, jit=0.006, rg=rg),
                  neige=False)
    # sablières le long de X
    for sy in (-1, 1):
        m.add("planches_h", beam(V(-1.78, sy * 1.3 + m.j(0.02), 2.49), V(1.78, sy * 1.3 + m.j(0.02), 2.49 + m.j(0.02)),
                                 0.15, 0.13, jit=0.008, rg=rg), seuil=0.1)
    # chevrons aux pignons + faîtière
    zu = lambda y: 3.32 - 0.5 * abs(y)
    for x in (-1.66, 1.66):
        for sy in (-1, 1):
            m.add("planches_h", beam(V(x, sy * 1.78, zu(1.78) - 0.065), V(x, sy * 0.02, zu(0.0) - 0.065), 0.10, 0.12,
                                     jit=0.006, rg=rg), neige=False)
    m.add("planches_h", beam(V(-1.74, 0, 3.22), V(1.74, 0.01, 3.23), 0.12, 0.12, jit=0.006, rg=rg), neige=False)
    # toit : 2 pans de 4 planches (3,6 x 3,6 m), épaisseur 8 cm, faîte à 3,40 m
    al = math.atan(0.5)
    Lp = 1.8 / math.cos(al)
    O = V(0, 0, 3.32)
    for sy in (-1, 1):
        v = V(0, sy * math.cos(al), -math.sin(al))
        n = V(0, sy * math.sin(al), math.cos(al))
        u = X
        bornes = [0.0, 0.52, 1.02, 1.52, Lp + 0.01]
        for i in range(4):
            v0, v1 = bornes[i] - (0.0 if i == 0 else 0.03), bornes[i + 1]
            u0, u1 = -1.8 + m.j(0.04), 1.8 + m.j(0.04)
            n0 = 0.012 * (i % 2) + m.j(0.004)
            o = O + u * u0 + v * v0 + n * n0
            m.add("planches_h", box_frame(o, u * (u1 - u0), v * (v1 - v0), n * 0.08, jit=0.01, rg=rg), seuil=-0.2)
        # neige épaisse sur le pan (a = 0), bord avant irrégulier
        o = O + u * (-1.74 + m.j(0.03)) + v * (-0.07) + n * 0.078
        m.add("planches_h", box_frame(o, u * (3.46 + m.j(0.04)), v * (1.80 + m.j(0.06)), n * 0.05, jit=0.02, rg=rg), a=0.0)
    # treuil : montants sur la margelle, axe, enroulement de corde, manivelle
    for sx in (-1, 1):
        m.add("planches_v", beam(V(sx * 1.48, m.j(0.02), 0.78), V(sx * 1.48 + m.j(0.02), m.j(0.02), 1.64), 0.12, 0.12,
                                 up=Y, jit=0.006, rg=rg), seuil=0.0)
    m.add("planches_h", cyl(V(-1.62, 0, 1.50), V(1.74, 0, 1.50), 0.055, 6, jit=0.004, rg=rg), neige=False)
    m.add("cuir", cyl(V(0.12, 0, 1.50), V(0.62, 0, 1.50), 0.085, 8, rot=0.2, jit=0.006, rg=rg), neige=False)
    m.add("fer", beam(V(1.76, 0, 1.53), V(1.76, 0.0, 1.16), 0.04, 0.035, up=Y))
    m.add("fer", beam(V(1.74, 0, 1.17), V(1.94, 0, 1.17), 0.035, 0.035))
    m.add("cuir", beam(V(0.36, 0, 1.47), V(0.36, 0.0, 1.30), 0.025, 0.025, up=Y), neige=False)
    # seau suspendu
    bc = V(0.36, 0, 0.98)
    m.add("planches_v", cyl(bc, bc + V(0, 0, 0.27), 0.13, 8, r2=0.16, caps=(True, False), jit=0.004, rg=rg), neige=False)
    m.add("planches_v", rev(cyl(bc + V(0, 0, 0.05), bc + V(0, 0, 0.27), 0.115, 8, r2=0.14, caps=(False, False))),
          neige=False, ao=0.6)
    m.add("planches_v", secteur(0.14, 0.16, 0.265, 0.27, 0, TAU, 8, ferme=True, c=bc, quoi=("haut",)), neige=False)
    for zc, rr in ((0.05, 0.138), (0.21, 0.157)):
        m.add("fer", secteur(rr - 0.01, rr + 0.012, zc, zc + 0.035, 0, TAU, 8, ferme=True, c=bc, quoi=("ext", "haut")))
    m.add("fer", beam(bc + V(-0.16, 0, 0.27), bc + V(0, 0, 0.33), 0.015, 0.015, up=Y))
    m.add("fer", beam(bc + V(0, 0, 0.33), bc + V(0.16, 0, 0.27), 0.015, 0.015, up=Y))
    return m


# ------------------------------------------------------------------------------------------------ 2. étal
def etal():
    m = Module("etal", 202, hs=1.3)
    rg = m.rg
    # poteaux : 2,4 m devant (+Y), 2,1 m derrière
    pts = {}
    for sx in (-1, 1):
        for sy, h in ((1, 2.4), (-1, 2.1)):
            b = V(sx * 1.55 + m.j(0.02), sy * 0.85 + m.j(0.02), 0)
            t = V(b.x + m.j(0.03), b.y + m.j(0.03), h)
            pts[(sx, sy)] = t
            m.add("planches_v", beam(b, t, 0.13, 0.13, up=Y, jit=0.007, rg=rg, omit=("bas",)), seuil=0.0)
    # cadre haut
    for sx in (-1, 1):
        a, b = pts[(sx, -1)], pts[(sx, 1)]
        m.add("planches_h", beam(a + V(0, -0.12, -0.05), b + V(0, 0.12, -0.05), 0.1, 0.1, jit=0.006, rg=rg), neige=False)
    for sy in (-1, 1):
        a, b = pts[(-1, sy)], pts[(1, sy)]
        m.add("planches_h", beam(a + V(-0.12, 0, -0.04), b + V(0.12, 0, -0.04), 0.1, 0.11, jit=0.006, rg=rg), neige=False)
    # comptoir : plateau 3 x 0,8 m à 0,9 m sur 2 tréteaux
    yc = 0.55
    for i, (y0, y1) in enumerate(((yc - 0.4, yc - 0.13), (yc - 0.14, yc + 0.13), (yc + 0.12, yc + 0.4))):
        m.add("planches_h", box(V(m.j(0.02), (y0 + y1) / 2, 0.83 + m.j(0.006)), 3.0 + m.j(0.04), y1 - y0, 0.07, rz=m.j(0.012),
                                jit=0.006, rg=rg), seuil=-0.1)
    for sx in (-1.1, 1.1):
        m.add("planches_h", beam(V(sx, yc - 0.36, 0.78), V(sx + m.j(0.02), yc + 0.36, 0.78), 0.08, 0.09, jit=0.005, rg=rg),
              neige=False)
        for dy in (-0.3, 0.3):
            for dx in (-0.16, 0.16):
                m.add("planches_v", beam(V(sx + dx * 0.25, yc + dy * 0.8, 0.76), V(sx + dx, yc + dy, 0.0), 0.06, 0.06, up=X,
                                         jit=0.004, rg=rg), neige=False)
    # marchandises : 3 petites caisses, fromage, miche
    for (x, y, s, rz) in ((-1.15, 0.45, 0.30, 0.15), (-0.78, 0.62, 0.24, -0.25), (0.95, 0.5, 0.28, 0.4)):
        m.add("planches_h", box(V(x, y, 0.9), s, s * 0.85, s * 0.75, rz=rz, jit=0.008, rg=rg), seuil=0.2)
    m.add("peau", cyl(V(0.25, 0.55, 0.9), V(0.25, 0.55, 1.01), 0.16, 8, rot=0.3, jit=0.006, rg=rg, caps=(False, True)),
          neige=False, teinte=(1.0, 0.92, 0.7))
    m.add("peau", cyl(V(0.48, 0.62, 0.9), V(0.48, 0.62, 0.97), 0.11, 8, jit=0.005, rg=rg, caps=(False, True)), neige=False,
          teinte=(1.0, 0.92, 0.7))
    m.add("peau", cyl(V(-0.42, 0.5, 0.96), V(-0.12, 0.56, 0.96), 0.075, 6, ech=(1.0, 0.8), rfn=lambda t: 0.7 + 0.6 * math.sin(math.pi * t),
                      ts=(0.0, 0.5, 1.0), jit=0.008, rg=rg), neige=False, teinte=(0.95, 0.75, 0.5))
    # auvent : bandes alternées rouge / crème, incliné (devant 2,47 m, derrière 2,17 m), affaissement doux
    W, D = 3.3, 2.2
    nb = 7
    bord = [-W / 2 + W * i / nb for i in range(nb + 1)]
    xs = sorted(set([round(b, 4) for b in bord] + [round((bord[i] + bord[i + 1]) / 2, 4) for i in range(nb)]))
    zaw = lambda x, y: 2.32 + 0.15 * (y / 0.85) - 0.05 * math.sin(math.pi * (y + D / 2) / D) + 0.012 * math.sin(x * 7.0)
    rows = [-D / 2, -0.5, 0.05, 0.6, D / 2]
    def bande(x):
        return min(nb - 1, max(0, int((x + W / 2) / (W / nb))))
    auvent = {"tenture_rouge": [], "peau": []}
    for i in range(len(xs) - 1):
        x0, x1 = xs[i], xs[i + 1]
        mat = "tenture_rouge" if bande((x0 + x1) / 2) % 2 == 0 else "peau"
        for k in range(len(rows) - 1):
            y0, y1 = rows[k], rows[k + 1]
            f = [V(x0, y0, zaw(x0, y0)), V(x1, y0, zaw(x1, y0)), V(x1, y1, zaw(x1, y1)), V(x0, y1, zaw(x0, y1))]
            auvent[mat].append(f)
    # lambrequin avant : 5 festons
    nf = 5
    fest = [-W / 2 + W * i / (nf * 4) for i in range(nf * 4 + 1)]
    xv = sorted(set([round(b, 4) for b in bord] + [round(f, 4) for f in fest]))
    yf = D / 2 + 0.005
    def chute(x):
        fr = ((x + W / 2) / (W / nf)) % 1.0
        return 0.16 + 0.12 * math.sin(math.pi * fr)
    val = {"tenture_rouge": [], "peau": []}
    for i in range(len(xv) - 1):
        x0, x1 = xv[i], xv[i + 1]
        mat = "tenture_rouge" if bande((x0 + x1) / 2) % 2 == 0 else "peau"
        t0, t1 = zaw(x0, D / 2), zaw(x1, D / 2)
        f = [V(x0, yf, t0), V(x0, yf + 0.02, t0 - chute(x0)), V(x1, yf + 0.02, t1 - chute(x1)), V(x1, yf, t1)]
        val[mat].append(orient(f, Y))
    neige_auvent = lambda w, n: n.z > 0.6 and (w.y > 0.82 or noise.noise(w * 1.7 + V(3, 1, 0)) > 0.3)
    for mat in ("tenture_rouge", "peau"):
        m.add(mat, deux_faces(auvent[mat]), fn=neige_auvent)
        m.add(mat, deux_faces(val[mat]), neige=False)
    # peaux pendues sur le côté droit
    for (yc2, h) in ((-0.35, 0.7), (0.25, 0.6)):
        pts2 = []
        for (u, v) in ((-0.22, 0), (0.22, 0), (0.28, -0.35), (0.18, -h), (0.0, -h - 0.08), (-0.2, -h + 0.04), (-0.27, -0.3)):
            pts2.append(V(1.63 + m.j(0.02), yc2 + u + m.j(0.02), 2.2 + v + m.j(0.02)))
        m.add("cuir", deux_faces([orient(pts2, X)], 0.006), neige=False)
    return m


# ------------------------------------------------------------------------------------------------ 3. bannière
ACCROCHE = V(0.55, 0.0, 3.72)


def banniere():
    m = Module("banniere", 303, hs=1.5)
    rg = m.rg
    # mât irrégulier, 6 pans, 3 tronçons
    m.add("planches_v", cyl(V(0, 0, 0), V(0.01, 0.005, 4.0), 0.075, 6, r2=0.062, ts=(0, 0.33, 0.7, 1.0), jit=0.008, rg=rg,
                            caps=(False, True)), seuil=-0.2)
    # pied en croix : 2 traverses au sol + 4 jambes de force
    for an in (0.12, 0.12 + math.pi / 2):
        d = V(math.cos(an), math.sin(an), 0)
        m.add("planches_h", beam(-d * 0.55, d * 0.55, 0.11, 0.1, jit=0.008, rg=rg), seuil=0.0)
        for s in (-1, 1):
            m.add("planches_v", beam(d * s * 0.06 + V(0, 0, 0.5), d * s * 0.42 + V(0, 0, 0.1), 0.07, 0.07, jit=0.005, rg=rg),
                  neige=False)
    # potence 1,0 m à 3,8 m + contrefiche
    m.add("planches_h", beam(V(-0.05, 0, 3.8), V(1.0, 0, 3.8 + m.j(0.015)), 0.09, 0.1, jit=0.006, rg=rg), seuil=0.0)
    m.add("planches_h", beam(V(0.03, 0, 3.32), V(0.45, 0, 3.78), 0.06, 0.07, jit=0.004, rg=rg), neige=False)
    m.add("fer", beam(ACCROCHE + V(-0.2, 0, 0.0), ACCROCHE + V(-0.2, 0, 0.04), 0.02, 0.02, up=Y), neige=False)
    m.add("fer", beam(ACCROCHE + V(0.2, 0, 0.0), ACCROCHE + V(0.2, 0, 0.04), 0.02, 0.02, up=Y), neige=False)
    # tissu 0,8 x 1,8 m, 4 x 8 quads, drapé léger, bas en queue d'aronde ; origine = accroche
    Wt, Ht, ent = 0.8, 1.8, "banniere_tissu"
    def S(u, v):
        L = Ht - 0.32 * (1.0 - abs(2 * u - 1))
        x = (u - 0.5) * Wt * (1.0 - 0.03 * v)
        y = 0.03 * math.sin(u * TAU * 1.0 + v * 1.5) * (0.3 + v) + 0.02 * math.sin(v * 4.0)
        return V(x, y, -v * L)
    def Nrm(u, v):
        e = 1e-3
        du = S(min(1, u + e), v) - S(max(0, u - e), v)
        dv = S(u, min(1, v + e)) - S(u, max(0, v - e))
        n = du.cross(dv).normalized()
        return n if n.y > 0 else -n
    us = [i / 4 for i in range(5)]
    vs = [i / 8 for i in range(9)]
    tissu = []
    for i in range(4):
        for k in range(8):
            u0, u1, v0, v1 = us[i], us[i + 1], vs[k], vs[k + 1]
            tissu.append(orient([S(u0, v0), S(u1, v0), S(u1, v1), S(u0, v1)], Y))
    org = ACCROCHE
    m.add("tenture_rouge", deux_faces(tissu, 0.004), neige=False, entree=ent, org=org)
    # emblème : ourlet clair en haut + ramure stylisée en relief de 1 cm (des deux côtés)
    embl = []
    for s in (1, -1):
        dec = 0.006 if s > 0 else 0.010
        def P(u, v, h=0.0):
            return S(u, v) + Nrm(u, v) * s * (dec + h)
        for i in range(4):
            u0, u1 = us[i], us[i + 1]
            embl.append(orient([P(u0, 0.0), P(u1, 0.0), P(u1, 0.06), P(u0, 0.06)], Y * s))
        bars = [((0.5, 0.64), (0.5, 0.36)), ((0.5, 0.5), (0.31, 0.37)), ((0.31, 0.37), (0.24, 0.19)),
                ((0.5, 0.5), (0.69, 0.37)), ((0.69, 0.37), (0.76, 0.19)), ((0.36, 0.41), (0.39, 0.22)), ((0.64, 0.41), (0.61, 0.22)),
                ((0.44, 0.66), (0.56, 0.66))]
        for (ua, va), (ub, vb) in bars:
            dx, dy = (ub - ua) * Wt, (vb - va) * Ht
            ln = math.hypot(dx, dy)
            px, py = -dy / ln * 0.028 / Wt, dx / ln * 0.028 / Ht
            q = [(ua + px, va + py), (ub + px, vb + py), (ub - px, vb - py), (ua - px, va - py)]
            haut = [P(a, b, 0.01) for a, b in q]
            bas = [P(a, b, 0.0) for a, b in q]
            embl.append(orient(haut, Nrm(ua, va) * s))
            for e0, e1 in ((0, 1), (2, 3)):
                f = [bas[e0], bas[e1], haut[e1], haut[e0]]
                c = (haut[0] + haut[2]) / 2
                embl.append(orient(f, ((bas[e0] + bas[e1]) / 2 - c)))
    m.add("peau", embl, neige=False, entree=ent, org=org, teinte=(1.0, 0.95, 0.85))
    return m


# ------------------------------------------------------------------------------------------------ 4. brasero
def brasero():
    m = Module("brasero", 404, hs=1.0)
    rg = m.rg
    z = 0.0
    for (s, h, rz) in ((0.58, 0.25, 0.1), (0.5, 0.23, 0.42), (0.43, 0.22, -0.15)):
        m.add("pierre_brute", box(V(m.j(0.015), m.j(0.015), z), s + m.j(0.02), s + m.j(0.02), h, rz=rz, jit=0.02, rg=rg,
                                  omit=("bas",) if z == 0 else ()), seuil=-0.1)
        z += h
    z = 0.70
    # vasque Ø 0,9 m, bord à 1,0 m
    prof = {0.0: 0.17, 0.4: 0.34, 0.9: 0.45, 1.0: 0.47}    # hauteur relative (x 0,30 m) -> rayon
    n = 10
    faces = cyl(V(0, 0, z), V(0, 0, z + 0.3), 1.0, n, caps=(True, False), ts=tuple(prof), rfn=lambda t: prof[t], rot=0.1)
    m.add("fer", faces, neige=False)
    m.add("fer", secteur(0.42, 0.47, z + 0.297, z + 0.30, 0.1, 0.1 + TAU, n, ferme=True, quoi=("haut",)), neige=False)
    m.add("fer", rev(cyl(V(0, 0, z + 0.22), V(0, 0, z + 0.30), 0.40, n, r2=0.42, caps=(False, False), rot=0.1)), neige=False,
          ao=0.6)
    # 4 pointes décoratives
    for i in range(4):
        an = 0.5 + TAU * i / 4
        b = V(math.cos(an) * 0.45, math.sin(an) * 0.45, z + 0.29)
        m.add("fer", cyl(b, b + V(math.cos(an) * 0.03, math.sin(an) * 0.03, 0.16), 0.025, 4, r2=0.002, caps=(False, False)),
              neige=False)
    # braises : dôme bruité + quelques tisons
    zb = z + 0.23
    br = []
    ring1 = [V(math.cos(TAU * k / 10) * 0.415, math.sin(TAU * k / 10) * 0.415, zb + m.j(0.01)) for k in range(10)]
    ring2 = [V(math.cos(TAU * (k + 0.5) / 10) * 0.24, math.sin(TAU * (k + 0.5) / 10) * 0.24, zb + 0.07 + m.j(0.02)) for k in range(10)]
    top = V(m.j(0.03), m.j(0.03), zb + 0.12)
    for k in range(10):
        k1 = (k + 1) % 10
        br.append([ring1[k], ring1[k1], ring2[k]])
        br.append([ring1[k1], ring2[k1], ring2[k]])
        br.append([ring2[k], ring2[k1], top])
    for i in range(6):
        an = rg.uniform(0, TAU)
        r = rg.uniform(0.05, 0.3)
        c = V(math.cos(an) * r, math.sin(an) * r, zb + 0.10 - r * 0.25)
        d = V(math.cos(an + 1.7), math.sin(an + 1.7), rg.uniform(-0.2, 0.2)) * rg.uniform(0.12, 0.2)
        br += cyl(c - d / 2, c + d / 2, 0.025, 4, rot=rg.uniform(0, 1), caps=(False, False))
    m.add("braises", br, neige=False, ao=lambda w, n: 0.75 + 0.25 * noise.noise(w * 9.0) + (0.15 if n.z > 0.5 else -0.1))
    return m


# ------------------------------------------------------------------------------------------------ 5. banc
def banc():
    m = Module("banc", 505, hs=0.5)
    rg = m.rg
    for i, y in enumerate((-0.09, 0.085)):
        m.add("planches_h", box(V(m.j(0.02), y + m.j(0.01), 0.37 + m.j(0.006)), 1.8 + m.j(0.04), 0.17, 0.08, rz=m.j(0.015),
                                jit=0.006, rg=rg), seuil=-0.2)
    for x in (-0.62, 0.64):
        m.add("planches_v", cyl(V(x, m.j(0.02), 0), V(x + m.j(0.02), m.j(0.02), 0.37), 0.14, 6, rot=rg.uniform(0, 1), jit=0.012,
                                rg=rg, caps=(False, False)), neige=False)
    m.add("planches_h", box(V(-0.18, m.j(0.02), 0.45), 1.2, 0.27, 0.03, rz=0.03, jit=0.012, rg=rg, omit=("bas",)), a=0.0)
    m.add("planches_h", box(V(0.62, 0.02, 0.45), 0.35, 0.22, 0.025, rz=-0.2, jit=0.01, rg=rg, omit=("bas",)), a=0.0)
    return m


# ------------------------------------------------------------------------------------------------ 6. tonneaux
def tonneau(nom, graine, R, H, ouvert):
    m = Module(nom, graine, hs=H)
    rg = m.rg
    n = 12
    prof = lambda t: R * (0.86 + 0.14 * math.sin(math.pi * t))
    ts = (0.0, 0.22, 0.78, 1.0)
    dmes = []
    for k in range(n):
        a0, a1 = TAU * k / n, TAU * (k + 1) / n
        dr = m.j(0.006)
        hk = H + m.j(0.012)
        P = lambda a, t, rr=0.0: V(math.cos(a) * (prof(t) + dr + rr), math.sin(a) * (prof(t) + dr + rr), t * hk)
        for i in range(3):
            dmes.append([P(a0, ts[i]), P(a1, ts[i]), P(a1, ts[i + 1]), P(a0, ts[i + 1])])
        dmes.append([P(a0, 1, -0.025), P(a0, 1), P(a1, 1), P(a1, 1, -0.025)])          # tranche du haut
        bas = hk - (0.05 if not ouvert else 0.45)
        q = lambda a, z: V(math.cos(a) * (prof(1) + dr - 0.025), math.sin(a) * (prof(1) + dr - 0.025), z)
        dmes.append([q(a1, bas), q(a0, bas), q(a0, hk), q(a1, hk)])                    # paroi intérieure
    m.add("planches_v", dmes, seuil=-0.3)
    zf = H - (0.05 if not ouvert else 0.45)
    m.add("planches_h", disque(V(0, 0, zf), prof(1) - 0.024, n), seuil=-0.6 if not ouvert else 9, ao=1.0 if not ouvert else 0.45)
    m.add("planches_v", disque(V(0, 0, 0.0), prof(0), n, z_up=False), neige=False)
    # cercles de fer
    cercles = (0.07, 0.86) if ouvert else (0.07, 0.84, 0.46)
    for i, t in enumerate(cercles):
        h = 0.045
        r = prof(t + 0.03) + 0.008
        q = ("ext", "haut") if i < 2 else ("ext",)
        m.add("fer", secteur(r - 0.012, r + 0.004, t * H, t * H + h, 0.13, 0.13 + TAU, n, ferme=True, quoi=q))
    if not ouvert:
        # neige posée sur le couvercle
        m.add("planches_h", disque(V(0.02, -0.01, zf + 0.035), prof(1) - 0.045, n, rot=0.2, jit=0.02, rg=rg), a=0.0)
    else:
        # couvercle appuyé contre le flanc (+X), posé au sol
        phi = math.radians(22)
        rl = R - 0.03
        nrm = V(math.cos(phi), 0, math.sin(phi))
        c = V(prof(0.6) + rl * math.sin(phi) + 0.035, 0.0, rl * math.cos(phi) + 0.02)
        Mx = nrm.to_track_quat('Z', 'Y').to_matrix()
        m.add("planches_h", cyl(c - nrm * 0.015, c + nrm * 0.015, rl, 10, rot=0.1), seuil=-0.2)
        m.add("fer", secteur(rl * 0.4, rl * 0.4 + 0.05, 0.015, 0.025, 0, TAU, 4, ferme=True, M=Mx, c=c, quoi=("haut",)))
    return m


# ------------------------------------------------------------------------------------------------ 7. caisses
def caisse(nom, graine, sx, sy, sz, coins_fer):
    m = Module(nom, graine, hs=sz)
    rg = m.rg
    rz = m.j(0.05)
    R = Euler((0, 0, rz)).to_matrix()
    m.add("planches_h", box(V(0, 0, 0), sx, sy, sz, rz=rz, jit=0.006, rg=rg, omit=("bas",)), seuil=-0.3)
    e = 0.055
    for cx in (-1, 1):
        for cy in (-1, 1):
            c = R @ V(cx * (sx / 2 - e / 2 + 0.012), cy * (sy / 2 - e / 2 + 0.012), 0)
            m.add("planches_v", box(c, e, e, sz + 0.005, rz=rz + m.j(0.02), jit=0.004, rg=rg, omit=("bas",)), seuil=-0.3)
            if coins_fer:
                c2 = R @ V(cx * (sx / 2 - 0.03 + 0.02), cy * (sy / 2 - 0.03 + 0.02), sz - 0.06)
                m.add("fer", box(c2, 0.085, 0.085, 0.075, rz=rz, omit=("bas",)), seuil=0.2)
    if not coins_fer:
        for cy in (-1, 1):
            for z0 in (0.0, sz - e):
                c = R @ V(0, cy * (sy / 2 + 0.006), z0)
                m.add("planches_h", box(c, sx - 2 * e, 0.025, e, rz=rz, jit=0.004, rg=rg, omit=("bas",)), seuil=-0.3)
    m.add("planches_h", box(R @ V(m.j(0.03), m.j(0.03), sz + 0.005), sx * 0.82, sy * 0.78, 0.035, rz=rz + m.j(0.1), jit=0.015,
                            rg=rg, omit=("bas",)), a=0.0)
    return m


# ------------------------------------------------------------------------------------------------ 8. charrette
def charrette():
    m = Module("charrette", 808, hs=0.9)
    rg = m.rg
    dy = -0.5     # recentre l'emprise (plateau + brancards)
    zt = 0.70
    # plateau 2,0 x 1,1 m : 3 planches + 2 traverses
    for i, x in enumerate((-0.37, 0.0, 0.37)):
        m.add("planches_h", box(V(x + m.j(0.01), dy + m.j(0.02), zt - 0.065), 0.36, 2.0 + m.j(0.03), 0.065, rz=m.j(0.01), jit=0.006,
                                rg=rg), seuil=-0.2)
    for y in (-0.75, 0.75):
        m.add("planches_h", beam(V(-0.6, dy + y, zt - 0.11), V(0.6, dy + y + m.j(0.02), zt - 0.11), 0.09, 0.09, jit=0.005, rg=rg),
              neige=False)
    # ridelles basses + piquets d'angle
    for sx in (-1, 1):
        m.add("planches_h", box(V(sx * 0.53, dy + m.j(0.01), zt), 0.04, 1.96, 0.22 + m.j(0.02), jit=0.008, rg=rg), seuil=0.0)
    for sy in (-1, 1):
        m.add("planches_h", box(V(m.j(0.01), dy + sy * 0.98, zt), 1.02, 0.04, 0.2 + m.j(0.02), jit=0.008, rg=rg), seuil=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b = V(sx * 0.53, dy + sy * 0.98, zt - 0.08)
            m.add("planches_v", beam(b, b + V(m.j(0.02), m.j(0.02), 0.38), 0.06, 0.06, up=Y, jit=0.004, rg=rg), seuil=-0.2)
    # brancards 1,6 m posés au sol devant
    for sx in (-1, 1):
        m.add("planches_h", beam(V(sx * 0.43, dy + 0.5, zt - 0.1), V(sx * 0.47, dy + 2.0, 0.05), 0.07, 0.08, jit=0.006, rg=rg),
              neige=False)
    m.add("planches_h", beam(V(-0.45, dy + 1.65, 0.19), V(0.45, dy + 1.65, 0.19), 0.05, 0.05), neige=False)
    # essieu + roues Ø 1,1 m à 8 rayons
    yr, zr = dy - 0.15, 0.55
    m.add("planches_h", cyl(V(-0.76, yr, zr), V(0.76, yr, zr), 0.05, 6, caps=(False, False)), neige=False)
    for sx in (-1, 1):
        m.add("planches_h", box(V(sx * 0.45, yr, zr), 0.14, 0.16, zt - 0.11 - zr - 0.045, omit=()), neige=False)
        c = V(sx * 0.66, yr, zr)
        Mw = X.to_track_quat('Z', 'Y').to_matrix()
        m.add("planches_v", secteur(0.44, 0.515, -0.04, 0.04, 0.2, 0.2 + TAU, 12, ferme=True, M=Mw, c=c, jit=0.004, rg=rg,
                                    quoi=("int", "haut", "bas")), neige=False)
        m.add("fer", secteur(0.505, 0.55, -0.045, 0.045, 0.2, 0.2 + TAU, 12, ferme=True, M=Mw, c=c, quoi=("ext", "haut", "bas")))
        m.add("planches_v", cyl(c - X * 0.1, c + X * 0.1, 0.09, 8), neige=False)
        for k in range(8):
            an = TAU * k / 8 + 0.15 * sx
            d = V(0, math.cos(an), math.sin(an))
            m.add("planches_v", beam(c + d * 0.08, c + d * 0.45, 0.035, 0.045, up=X, omit=("bas", "haut")), neige=False)
    # chargement : 2 sacs de cuir + un tas de foin
    for (x, y, rz, ln) in ((-0.22, dy - 0.45, 0.25, 0.55), (0.2, dy - 0.15, -0.5, 0.5)):
        d = V(math.cos(rz), math.sin(rz), 0) * ln
        c = V(x, y, zt + 0.17)
        m.add("cuir", cyl(c - d / 2, c + d / 2, 0.19, 6, ts=(0, 0.5, 1), rfn=lambda t: 0.6 + 0.4 * math.sin(math.pi * t) + 0.2,
                          ech=(1.0, 0.85), jit=0.02, rg=rg, rot=0.5), seuil=0.35)
    fo = []
    cf = V(0.05, dy + 0.5, zt)
    r1 = [cf + V(math.cos(TAU * k / 8) * 0.42, math.sin(TAU * k / 8) * 0.38, 0.0) for k in range(8)]
    r2 = [cf + V(math.cos(TAU * (k + 0.5) / 8) * 0.25 + m.j(0.04), math.sin(TAU * (k + 0.5) / 8) * 0.22 + m.j(0.04), 0.2 + m.j(0.04))
          for k in range(8)]
    tp = cf + V(m.j(0.05), m.j(0.05), 0.3)
    for k in range(8):
        k1 = (k + 1) % 8
        fo += [[r1[k], r1[k1], r2[k]], [r1[k1], r2[k1], r2[k]], [r2[k], r2[k1], tp]]
    m.add("foin", fo, seuil=0.1)
    return m


# ------------------------------------------------------------------------------------------------ 9. tas de bois
def tas_bois():
    m = Module("tas_bois", 909, hs=1.2)
    rg = m.rg
    logs = []
    bouts = []
    r = 0.11
    for rang in range(5):
        nbl = 7 if rang % 2 == 0 else 6
        z = r + rang * r * 1.72
        for i in range(nbl):
            x = (i - (nbl - 1) / 2) * 2 * r + m.j(0.012)
            rr = r * rg.uniform(0.8, 1.0)
            y0, y1 = -0.3 + m.j(0.04), 0.3 + m.j(0.04)
            f = cyl(V(x, y0, z + m.j(0.01)), V(x + m.j(0.01), y1, z + m.j(0.01)), rr, 6, rot=rg.uniform(0, 1), jit=0.006, rg=rg)
            logs += f[:-2]
            bouts += f[-2:]
    sous_toit = lambda w, n: 0.85 - 0.15 * smooth(-0.3, 0.3, -w.y)
    m.add("planches_h", logs, neige=False, ao=lambda w, n: 0.72 * sous_toit(w, n))
    m.add("planches_h", bouts, neige=False, ao=lambda w, n: 1.0 if w.y > 0 else 0.8, teinte=(1.0, 0.95, 0.85))
    # 2 piquets + traverse
    for sx in (-1, 1):
        m.add("planches_v", cyl(V(sx * 0.88, 0.0, 0), V(sx * 0.88 + m.j(0.02), m.j(0.02), 1.3), 0.06, 6, rot=0.3, jit=0.006, rg=rg,
                                caps=(False, True)), seuil=-0.2)
    m.add("planches_h", beam(V(-0.98, 0.0, 1.255), V(0.98, 0.0, 1.265), 0.08, 0.08, jit=0.005, rg=rg), neige=False)
    # petit toit de 7 planches incliné vers l'arrière + neige
    zr = lambda y: 1.305 + 0.27 * y
    for i in range(7):
        x0 = -0.98 + i * 0.28 + m.j(0.01)
        x1 = x0 + 0.27
        y0, y1 = -0.5 + m.j(0.03), 0.5 + m.j(0.03)
        dz = 0.008 * (i % 2)
        o = V(x0, y0, zr(y0) + dz)
        U = V(x1 - x0, 0, 0)
        Vv = V(0, y1 - y0, zr(y1) - zr(y0))
        N = U.cross(Vv).normalized() * 0.04
        m.add("planches_h", box_frame(o, U, Vv, N, jit=0.006, rg=rg), seuil=-0.2)
    o = V(-0.92, -0.42, zr(-0.42) + 0.045)
    U = V(1.82, 0, 0)
    Vv = V(0, 0.86, 0.86 * 0.27)
    m.add("planches_h", box_frame(o, U, Vv, U.cross(Vv).normalized() * 0.045, jit=0.02, rg=rg), a=0.0)
    return m


# ------------------------------------------------------------------------------------------------ sortie
def godot(p):
    return (p.x, p.z, -p.y)


def ecrire_dat():
    with open(DAT, "wb") as f:
        f.write(struct.pack("<I", len(DONNEES)))
        for nom, verts in DONNEES.items():
            nb = nom.encode()
            f.write(struct.pack("<B", len(nb)) + nb + struct.pack("<I", len(verts)))
            for p, c in verts:
                g = godot(p)
                f.write(struct.pack("<7f", g[0], g[1], g[2], c[0], c[1], c[2], c[3]))


def relire_dat():
    with open(DAT, "rb") as f:
        b = f.read()
    o = 0
    (nb,) = struct.unpack_from("<I", b, o); o += 4
    res = {}
    for _ in range(nb):
        ln = b[o]; o += 1
        nom = b[o:o + ln].decode(); o += ln
        (nv,) = struct.unpack_from("<I", b, o); o += 4
        vals = struct.unpack_from("<%df" % (nv * 7), b, o); o += nv * 28
        assert nv % 3 == 0, nom
        mod, mat = nom.split("/")
        assert mat in MATIERES, nom
        assert all(math.isfinite(v) for v in vals), nom
        res[nom] = nv
    assert o == len(b), "octets restants"
    return res


TEINTE_APERCU = {"pierre_brute": (0.42, 0.47, 0.55), "pierre_fine": (0.48, 0.5, 0.55), "planches_h": (0.36, 0.25, 0.16),
                 "planches_v": (0.3, 0.21, 0.13), "fer": (0.24, 0.25, 0.28), "cuir": (0.42, 0.26, 0.14),
                 "tenture_rouge": (0.62, 0.08, 0.06), "peau": (0.86, 0.78, 0.62), "foin": (0.78, 0.66, 0.3),
                 "braises": (1.0, 0.45, 0.08)}


def creer_objets(espacement):
    objs = {}
    for nom, verts in DONNEES.items():
        mod, mat = nom.split("/")
        me = bpy.data.meshes.new(nom)
        vs = [tuple(p) for p, _ in verts]
        me.from_pydata(vs, [], [(i, i + 1, i + 2) for i in range(0, len(vs), 3)])
        me.update()
        ca = me.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
        ap = me.color_attributes.new(name="apercu", type='FLOAT_COLOR', domain='CORNER')
        t = TEINTE_APERCU[mat]
        for poly in me.polygons:
            poly.use_smooth = False
            for li in poly.loop_indices:
                c = verts[li][1]
                ca.data[li].color = c
                if c[3] < 0.5:
                    ap.data[li].color = (0.88 * c[0] + 0.1, 0.9 * c[0] + 0.1, 0.98 * c[0] + 0.1, 1)
                else:
                    ap.data[li].color = (t[0] * c[0], t[1] * c[1], t[2] * c[2], 1)
        me.color_attributes.active_color = ca
        ob = bpy.data.objects.new(nom, me)
        bpy.context.scene.collection.objects.link(ob)
        base = mod if mod != "banniere_tissu" else "banniere"
        ob.location = espacement.get(base, V(0, 0, 0)) + ORIGINES.get(mod, V(0, 0, 0))
        objs[nom] = ob
    return objs


def boites(mods):
    res = {}
    for mod in mods:
        pts = []
        for nom, verts in DONNEES.items():
            mm = nom.split("/")[0]
            if mm == mod or (mod == "banniere" and mm == "banniere_tissu"):
                o = ORIGINES.get(mm, V(0, 0, 0))
                pts += [godot(p + o) for p, _ in verts]
        lo = [min(p[i] for p in pts) for i in range(3)]
        hi = [max(p[i] for p in pts) for i in range(3)]
        res[mod] = (lo, hi)
    return res


def apercus(objs, espacement):
    os.makedirs(CAPT, exist_ok=True)
    sc = bpy.context.scene
    try:
        sc.render.engine = 'BLENDER_WORKBENCH'
    except TypeError as e:
        print("moteur :", e)
    sh = sc.display.shading
    sh.light = 'STUDIO'
    sh.color_type = 'VERTEX'
    sh.show_backface_culling = True
    sc.render.resolution_x, sc.render.resolution_y = 480, 360
    sc.render.film_transparent = False
    sc.world = bpy.data.worlds.new("w") if sc.world is None else sc.world
    for ob in objs.values():
        ob.data.color_attributes.active_color = ob.data.color_attributes["apercu"]
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = 'ORTHO'
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    for mod, pos in espacement.items():
        for vue, d in (("34", V(1.0, 1.5, 0.9)), ("dos", V(-1.2, -1.4, 0.7))):
            lo, hi = BOITES[mod]
            centre = pos + V((lo[0] + hi[0]) / 2, -(lo[2] + hi[2]) / 2, (lo[1] + hi[1]) / 2)
            taille = max(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
            cam_d.ortho_scale = taille * 1.45
            cam.location = centre + d.normalized() * 30
            cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
            cam_d.clip_end = 100
            sc.render.filepath = os.path.join(CAPT, f"{mod}_{vue}.png")
            bpy.ops.render.render(write_still=True)
    for ob in objs.values():
        ob.data.color_attributes.active_color = ob.data.color_attributes["Color"]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mods = [puits(), etal(), banniere(), brasero(), banc(), tonneau("tonneau_a", 606, 0.3, 0.85, False),
            tonneau("tonneau_b", 617, 0.25, 0.7, True), caisse("caisse_a", 707, 0.6, 0.6, 0.6, False),
            caisse("caisse_b", 717, 0.8, 0.6, 0.55, True), charrette(), tas_bois()]
    for m in mods:
        m.compiler()
    # tissu de la bannière : origine au point d'accroche
    ORIGINES["banniere_tissu"] = ACCROCHE.copy()
    noms = [m.nom for m in mods]
    global BOITES
    BOITES = boites(noms)
    espacement = {}
    x = 0.0
    for nm in noms:
        lo, hi = BOITES[nm]
        x += -lo[0] + 0.5
        espacement[nm] = V(x, 0, 0)
        x += hi[0] + 0.5
    os.makedirs(os.path.dirname(GLB), exist_ok=True)
    objs = creer_objets(espacement)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs.values():
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, export_format='GLB', use_selection=True, export_apply=False,
                              export_normals=True, export_vertex_color='ACTIVE', export_active_vertex_color_when_no_material=True,
                              export_materials='NONE', export_yup=True)
    ecrire_dat()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    relu = relire_dat()
    assert set(relu) == set(DONNEES), "entrées relues différentes"
    print("=== mobilier village : %d entrées relues" % len(relu))
    for nom in sorted(relu):
        print("  %-28s %5d triangles" % (nom, relu[nom] // 3))
    print("=== triangles par module (budget)")
    for nm in noms:
        t = sum(v // 3 for k, v in relu.items() if k.split("/")[0] in ((nm, "banniere_tissu") if nm == "banniere" else (nm,)))
        lo, hi = BOITES[nm]
        print("  %-10s %5d / %5d %s  boîte Godot x[%.2f %.2f] y[%.2f %.2f] z[%.2f %.2f]" % (
            nm, t, BUDGET[nm], "OK" if t <= BUDGET[nm] else "DÉPASSE", lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    g = godot(ACCROCHE)
    print("=== accroche banniere_tissu (repère du mât, Godot) : (%.3f, %.3f, %.3f)" % g)
    zb = max(p.z for p, _ in DONNEES["brasero/braises"])
    print("=== dessus des braises : %.3f m" % zb)
    if "apercu" in sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else False:
        apercus(objs, espacement)


main()
