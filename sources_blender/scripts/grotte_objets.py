# Lot L5 (camp de la grotte des bandits) : MODULES D'OBJETS PROPRES À LA GROTTE (sacs, couchages, tabourets, râtelier, pique à
# trophée, tas de pièces, caisses, estrade de l'autel, brasero sur trépied du dehors).
#   blender.exe -b --python grotte_objets.py            (« -- apercu » : planche Workbench dans captures/grotte_objets/)
# Sortie : assets/grotte/modules/grotte_objets.dat, MÊME format que crypte_v2.dat (crypte_modules_v2.py) :
#   [u32 nb entrées] puis par entrée : [u8 long][« module__matiere »][u32 nb sommets][x y z r g b a float32, 3 par triangle]
#   repère GODOT (y haut, +z = avant), triangles dans le sens direct vu de dehors (CrypteDecor.modele les retourne pour Godot).
#   Lu par GrotteDecor (FileAccess, versé dans les tables de CrypteDecor) : sûr dans le fil de construction, aucun .glb.
# On modélise en repère Blender (Z haut, AVANT = -Y), converti en Godot (x, z, -y) à l'écriture. Origine de chaque module : au sol,
# au centre de l'emprise de l'ancien objet procédural (mêmes dimensions extérieures : emprises, solides et pose inchangés).
# Matières = noms des matières de la grotte (GrotteDecor.mat) : bois, planches, fer, lame, os, peau, paille, or, toile, braise, noir ;
# « pierre » et « roche » sont remplacées à la pose (strate et roche nue de la coque).
# Couleur de sommet : rgb = occlusion peinte x teinte (la toile de jute est teintée brune ici), a = 1.
import bpy, math, os, random, struct, sys
from mathutils import Vector, Matrix, Euler, noise

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
DAT = os.path.join(BASE, "assets", "grotte", "modules", "grotte_objets.dat")
CAPT = os.path.join(BASE, "captures", "grotte_objets")
MATIERES = ("bois", "planches", "fer", "lame", "os", "peau", "paille", "or", "toile", "braise", "noir", "pierre", "roche")
# budget de triangles par module (≈ 150-400 pour un objet courant ; l'autel, unique, a droit à plus)
BUDGET = {"g_sac": 330, "g_couchage": 520, "g_tabouret": 260, "g_ratelier": 600, "g_trophee": 260, "g_pieces": 420,
          "g_caisse": 460, "g_autel": 1500, "g_brasero": 400}
DONNEES = {}      # "module__matiere" -> [(Vector Blender, (r, g, b, a))]
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
TAU = 2 * math.pi
JUTE = (0.92, 0.72, 0.46)        # toile de sac : matière « paille » teintée brun (la « toile » de la crypte ressort blanche et tachée ici)
LIN = (0.92, 0.84, 0.7)


def V(x, y, z):
    return Vector((x, y, z))


def GV(x, y, z):
    """Point donné en repère Godot (x, y haut, z avant) -> Blender."""
    return Vector((x, -z, y))


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


def centre(faces):
    s = V(0, 0, 0)
    k = 0
    for f in faces:
        for p in f:
            s += p
            k += 1
    return s / max(k, 1)


def dehors(faces, c=None):
    c = centre(faces) if c is None else c
    out = []
    for f in faces:
        fc = sum(f, V(0, 0, 0)) / len(f)
        out.append(f if newell(f).dot(fc - c) >= 0 else list(reversed(f)))
    return out


def rev(faces):
    return [list(reversed(f)) for f in faces]


def orient(f, d):
    return f if newell(f).dot(d) >= 0 else list(reversed(f))


def cisaille(faces, kx, h):
    """Incline une pièce verticale : x += kx * z / h (perche penchée)."""
    return [[p + V(kx * p.z / h, 0, 0) for p in f] for f in faces]


def Rz(a):
    return Matrix.Rotation(a, 3, 'Z')


def Rx(a):
    return Matrix.Rotation(a, 3, 'X')


def Ry(a):
    return Matrix.Rotation(a, 3, 'Y')


# ------------------------------------------------------------------------------------------------ primitives
def box_frame(o, U, Vv, N, omit=(), jit=0.0, rg=None):
    if U.cross(Vv).dot(N) < 0:
        U, Vv = Vv, U
    c = [o, o + U, o + U + Vv, o + Vv]
    c = c + [p + N for p in c]
    if jit:
        c = [p + V(rg.uniform(-jit, jit), rg.uniform(-jit, jit), rg.uniform(-jit, jit)) for p in c]
    idx = {"bas": (0, 3, 2, 1), "haut": (4, 5, 6, 7), "f1": (0, 1, 5, 4), "f2": (1, 2, 6, 5), "f3": (2, 3, 7, 6), "f4": (3, 0, 4, 7)}
    return [[c[i] for i in f] for k, f in idx.items() if k not in omit]


def box(c, sx, sy, sz, rz=0.0, tx=0.0, ty=0.0, omit=(), jit=0.0, rg=None):
    """Bloc : c = centre de la base."""
    R = Euler((tx, ty, rz)).to_matrix()
    U, Vv, N = R @ V(sx, 0, 0), R @ V(0, sy, 0), R @ V(0, 0, sz)
    return box_frame(c - U / 2 - Vv / 2, U, Vv, N, omit, jit, rg)


def prisme_ch(c, sx, sy, sz, ch=0.01, rz=0.0, M=None, haut=True, bas=True, jit=0.0, rg=None):
    """Boîte aux arêtes haut/bas chanfreinées : c = centre de la base, rotation rz puis M."""
    R = (M or Matrix.Identity(3)) @ Rz(rz)

    def ring(z, ins):
        hx, hy = sx / 2 - ins, sy / 2 - ins
        return [c + R @ V(x, y, z) for x, y in [(hx, -hy), (hx, hy), (-hx, hy), (-hx, -hy)]]
    rings = [ring(0.0, ch), ring(ch, 0.0), ring(sz - ch, 0.0), ring(sz, ch)] if ch > 1e-5 else [ring(0.0, 0.0), ring(sz, 0.0)]
    if jit:
        rings = [[p + V(rg.uniform(-jit, jit), rg.uniform(-jit, jit), rg.uniform(-jit, jit) * 0.5) for p in r] for r in rings]
    faces = []
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(4):
            k1 = (k + 1) % 4
            faces.append([a[k], a[k1], b[k1], b[k]])
    if bas:
        faces.append(list(reversed(rings[0])))
    if haut:
        faces.append(list(rings[-1]))
    return dehors(faces, c + R @ V(0, 0, sz / 2))


def poutre_ch(a, b, w, h, ch=0.008, up=Z):
    d = b - a
    side = d.cross(up)
    if side.length < 1e-6:
        side = d.cross(X)
    side.normalize()
    N = side.cross(d).normalized()
    M = Matrix((side, N, d.normalized())).transposed()
    return prisme_ch(a, w, h, d.length, ch, M=M)


def tour(profil, n, c=None, M=None, rot=0.0, caps=(True, True), ech=(1.0, 1.0), jit=0.0, rg=None):
    """Solide de révolution autour de Z local : profil = [(r, z)]."""
    M = M or Matrix.Identity(3)
    c = c if c is not None else V(0, 0, 0)
    rings = []
    for (r, z) in profil:
        ring = []
        for k in range(n):
            an = rot + TAU * k / n
            p = V(math.cos(an) * r * ech[0], math.sin(an) * r * ech[1], z)
            if jit and r > 1e-4:
                p += V(rg.uniform(-jit, jit), rg.uniform(-jit, jit), 0.0)
            ring.append(c + M @ p)
        rings.append(ring)
    faces = []
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        if profil[i][0] < 1e-5 and profil[i + 1][0] < 1e-5:
            continue
        for k in range(n):
            k1 = (k + 1) % n
            if profil[i][0] < 1e-5:
                faces.append([r0[k], r1[k1], r1[k]])
            elif profil[i + 1][0] < 1e-5:
                faces.append([r0[k], r0[k1], r1[k]])
            else:
                faces.append([r0[k], r0[k1], r1[k1], r1[k]])
    if caps[0] and profil[0][0] > 1e-5:
        faces.append(list(reversed(rings[0])))
    if caps[1] and profil[-1][0] > 1e-5:
        faces.append(list(rings[-1]))
    return faces


def cyl(a, b, r, n=6, r2=None, caps=(True, True), rot=0.0):
    d = b - a
    Mq = d.to_track_quat('Z', 'Y').to_matrix()
    return tour([(r, 0.0), (r if r2 is None else r2, d.length)], n, c=a, M=Mq, rot=rot, caps=caps)


def anneau(rin, rout, z0, z1, n, c=None, M=None, quoi=("ext", "int", "haut", "bas"), rot=0.0):
    M = M or Matrix.Identity(3)
    c = c if c is not None else V(0, 0, 0)
    P = lambda r, z, k: c + M @ V(math.cos(rot + TAU * k / n) * r, math.sin(rot + TAU * k / n) * r, z)
    faces = []
    for k in range(n):
        k1 = k + 1
        if "ext" in quoi:
            faces.append([P(rout, z0, k), P(rout, z0, k1), P(rout, z1, k1), P(rout, z1, k)])
        if "int" in quoi:
            faces.append([P(rin, z0, k1), P(rin, z0, k), P(rin, z1, k), P(rin, z1, k1)])
        if "haut" in quoi:
            faces.append([P(rin, z1, k), P(rout, z1, k), P(rout, z1, k1), P(rin, z1, k1)])
        if "bas" in quoi:
            faces.append([P(rin, z0, k), P(rin, z0, k1), P(rout, z0, k1), P(rout, z0, k)])
    return faces


def tore(R, r, n, m, c=None, M=None):
    M = M or Matrix.Identity(3)
    c = c if c is not None else V(0, 0, 0)
    rings = []
    for i in range(n):
        a = TAU * i / n
        ce = V(math.cos(a) * R, math.sin(a) * R, 0)
        ra = V(math.cos(a), math.sin(a), 0)
        rings.append([c + M @ (ce + ra * math.cos(TAU * j / m) * r + Z * math.sin(TAU * j / m) * r) for j in range(m)])
    faces = []
    for i in range(n):
        r0, r1 = rings[i], rings[(i + 1) % n]
        for j in range(m):
            j1 = (j + 1) % m
            faces.append([r0[j], r1[j], r1[j1], r0[j1]])
    return faces


def grille(fn, nu, nv):
    P = [[fn(i / nu, j / nv) for j in range(nv + 1)] for i in range(nu + 1)]
    return [[P[i][j], P[i + 1][j], P[i + 1][j + 1], P[i][j + 1]] for i in range(nu) for j in range(nv)]


def lame(a, b, larg, ep, pointe=0.12):
    """Lame plate à arête centrale (losange) de a (talon) à b (pointe), plat de la lame dans le plan de `larg` horizontal."""
    d = b - a
    L = d.length
    u = d.normalized()
    s = u.cross(Y) if abs(u.dot(Y)) < 0.9 else u.cross(X)
    s.normalize()
    t = s.cross(u).normalized()
    secs = [(0.0, 1.0), (L - pointe * L, 0.86), (L, 0.0)]
    rings = []
    for z, f in secs:
        o = a + u * z
        rings.append([o + s * larg / 2 * f, o + t * ep / 2 * f, o - s * larg / 2 * f, o - t * ep / 2 * f])
    faces = []
    for i in range(2):
        r0, r1 = rings[i], rings[i + 1]
        for k in range(4):
            k1 = (k + 1) % 4
            if i == 1:
                faces.append([r0[k], r0[k1], r1[0]])
            else:
                faces.append([r0[k], r0[k1], r1[k1], r1[k]])
    faces.append(list(reversed(rings[0])))
    return dehors(faces, a + u * L * 0.4)


# ------------------------------------------------------------------------------------------------ modules
class Module:
    def __init__(self, nom, graine, hs=1.0):
        self.nom = nom
        self.rg = random.Random(graine)
        self.hs = hs
        self.off = V(graine * 0.311, graine * 0.173, graine * 0.071)
        self.parts = []
        self.teintes = {}

    def j(self, s):
        return self.rg.uniform(-s, s)

    def add(self, mat, faces, ao=1.0, teinte=(1.0, 1.0, 1.0), creux=False, plat=False):
        assert mat in MATIERES, mat
        self.parts.append(dict(mat=mat, faces=faces, ao=ao, teinte=teinte, creux=creux, plat=plat))

    def couleur(self, part, p, n):
        if part["plat"]:
            k = part["ao"]
        else:
            k = 0.62 + 0.38 * smooth(-0.02, self.hs, p.z)
            if n.z < -0.5:
                k *= 0.75
            elif n.z > 0.5:
                k = min(1.0, k * 1.08)
            k *= part["ao"](p, n) if callable(part["ao"]) else part["ao"]
            if part["creux"]:
                k *= 0.5
            k *= 0.9 + 0.1 * noise.noise(p * 5.3 + self.off)
        k = max(0.1, min(1.0, k))
        t = part["teinte"]
        if part["mat"] in self.teintes:      # teinte de matière propre au module (ex. pierre chaude de l'autel)
            t = tuple(a * b for a, b in zip(t, self.teintes[part["mat"]]))
        return (k * t[0], k * t[1], k * t[2], 1.0)

    def compiler(self):
        for part in self.parts:
            cle = f"{self.nom}__{part['mat']}"
            lst = DONNEES.setdefault(cle, [])
            for f in part["faces"]:
                n = newell(f)
                cols = [self.couleur(part, p, n) for p in f]
                for i in range(1, len(f) - 1):
                    for k in (0, i, i + 1):
                        lst.append((f[k].copy(), cols[k]))

    def tris(self):
        return sum(sum(len(f) - 2 for f in p["faces"]) for p in self.parts)


# ---------------------------------------------------------------------------- sac (ancien : révolution r 0,26 x h 0,56)
def sac(var):
    """Sac de jute h 0,56 (x e), panse tassée bosselée, col noué d'une cordelette, houppe ; b : affaissé, rapiécé ; c : ouvert, grain."""
    m = Module(f"g_sac_{var}", 5100 + ord(var), hs=0.56)
    tass = {"a": 1.0, "b": 0.86, "c": 0.94}[var]
    ech = {"a": (1.0, 0.86), "b": (1.04, 0.92), "c": (1.0, 0.95)}[var]
    prof = [(0.0, 0.0), (0.19, 0.0), (0.245, 0.07), (0.255, 0.2 * tass), (0.235, 0.32 * tass), (0.17, 0.42 * tass), (0.085, 0.47 * tass)]
    if var == "c":     # col ouvert, rabattu : bord épais, grain visible
        prof += [(0.15, 0.5 * tass), (0.16, 0.53 * tass)]
        m.add("paille", tour(prof, 10, ech=ech, jit=0.012, rg=m.rg, rot=m.rg.uniform(0, 1), caps=(True, False)), teinte=JUTE)
        m.add("paille", rev(tour([(0.15, 0.44 * tass), (0.155, 0.53 * tass)], 10, ech=ech, caps=(False, False))), teinte=JUTE, ao=0.55)
        m.add("paille", tour([(0.15, 0.47 * tass), (0.1, 0.5 * tass), (0.0, 0.515 * tass)], 10, ech=ech, jit=0.01, rg=m.rg), ao=0.85)
        m.add("paille", box(V(0.0, -0.215, 0.06), 0.02, 0.012, 0.3 * tass), teinte=JUTE, ao=0.65)
        return m
    m.add("paille", tour(prof, 10, ech=ech, jit=0.014, rg=m.rg, rot=m.rg.uniform(0, 1)), teinte=JUTE)
    zc = 0.47 * tass
    m.add("paille", tour([(0.06, zc - 0.01), (0.05, zc + 0.03), (0.09, zc + 0.08), (0.06, zc + 0.1), (0.0, zc + 0.09)], 7, jit=0.012, rg=m.rg),
          teinte=JUTE, ao=0.95)
    m.add("peau", tore(0.06, 0.012, 7, 4, c=V(0, 0, zc + 0.025)), teinte=(0.55, 0.42, 0.3), ao=0.8)
    m.add("peau", cyl(V(0.05, -0.03, zc + 0.02), V(0.1, -0.06, zc - 0.1), 0.008, 4), teinte=(0.55, 0.42, 0.3), ao=0.8)   # bout de corde
    m.add("paille", box(V(0.0, -0.215 * ech[1], 0.06), 0.02, 0.012, 0.3 * tass), teinte=JUTE, ao=0.65)     # couture
    if var == "b":     # pièce cousue sur le flanc
        q = [V(-0.2, -0.13, 0.12), V(-0.13, -0.2, 0.11), V(-0.12, -0.2, 0.25), V(-0.2, -0.13, 0.26)]
        m.add("peau", [q], teinte=(0.65, 0.52, 0.38), ao=0.85)
    return m


# ---------------------------------------------------------------------------- couchage (ancien : 1,0 x 2,0 m, h 0,65)
def couchage(var):
    """Châlit de bandit : 4 pieds, longerons, planches, paillasse de toile, fourrure drapée, fourrure roulée, oreiller.
    Tête vers +Y Blender (-Z Godot). a : oreiller de toile et paille qui déborde ; b : oreiller de fourrure."""
    m = Module(f"g_couchage_{var}", 5200 + ord(var), hs=0.6)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.add("bois", prisme_ch(V(sx * 0.44, sy * 0.9, 0.0), 0.09, 0.09, 0.42, 0.01, rz=m.j(0.05)), ao=0.85)
        m.add("bois", poutre_ch(V(sx * 0.46, -1.0, 0.33), V(sx * 0.46, 1.0, 0.33 + m.j(0.01)), 0.07, 0.1, 0.01))
    for sy in (-1, 1):
        m.add("bois", poutre_ch(V(-0.5, sy * 0.95, 0.31), V(0.5, sy * 0.95, 0.31), 0.06, 0.09, 0.008))
    for i in range(4):     # planches du fond
        x = -0.33 + i * 0.22
        m.add("planches", prisme_ch(V(x + m.j(0.006), m.j(0.01), 0.27), 0.205, 1.86, 0.04, 0.006), ao=0.8)
    # paillasse de toile bourrée (bords arrondis)
    m.add("paille", prisme_ch(V(0, 0.0, 0.31), 0.88, 1.88, 0.15, 0.04, jit=0.01, rg=m.rg), teinte=(0.62, 0.52, 0.4))
    # fourrure drapée : couvre les 2/3 du pied, retombe sur les côtés
    def drap(u, v):
        x = (u - 0.5) * 1.0
        y = -0.95 + v * 1.25
        bord = smooth(0.4, 0.53, abs(x))
        z = 0.48 + 0.025 * noise.noise(V(x * 4, y * 3, 0.5) + m.off) - bord * 0.2
        x *= 1.0 - 0.07 * bord
        return V(x, y, z)
    m.add("peau", grille(drap, 6, 6), teinte=(0.92, 0.85, 0.75))
    # fourrure roulée au pied, en travers
    m.add("peau", cyl(V(-0.36, -0.82, 0.55), V(0.34, -0.8, 0.55), 0.075, 7, rot=0.3), teinte=(0.6, 0.5, 0.42), ao=0.9)
    if var == "a":
        m.add("paille", prisme_ch(V(0.0, 0.73, 0.46), 0.5, 0.3, 0.12, 0.04, jit=0.01, rg=m.rg), teinte=LIN)
        for k in range(6):         # paille qui déborde de la paillasse
            a = m.rg.uniform(0, TAU)
            x = m.rg.choice((-1, 1)) * 0.44
            y = m.rg.uniform(-0.8, 0.8)
            p0 = V(x, y, 0.4)
            p1 = p0 + V(math.copysign(0.09, x), math.cos(a) * 0.05, -0.02)
            m.add("paille", [[p0 + V(0, -0.03, 0), p0 + V(0, 0.03, 0), p1]], ao=0.9)
            m.add("paille", [[p0 + V(0, 0.03, 0), p0 + V(0, -0.03, 0), p1]], ao=0.7)
    else:
        m.add("peau", cyl(V(-0.24, 0.74, 0.52), V(0.24, 0.74, 0.52), 0.09, 7, rot=0.1), teinte=(0.85, 0.8, 0.74))
    return m


# ---------------------------------------------------------------------------- tabouret (ancien : assise 0,34 à 0,45 m)
def tabouret(var):
    m = Module(f"g_tabouret_{var}", 5300 + ord(var), hs=0.45)
    h = 0.45
    if var == "a":     # rondelle de tronc fendue, 3 pieds écartés
        m.add("bois", tour([(0.0, h - 0.065), (0.15, h - 0.065), (0.175, h - 0.05), (0.18, h - 0.012), (0.165, h), (0.0, h)], 9,
                           rot=0.2, jit=0.006, rg=m.rg))
        for k in range(3):
            a = TAU * k / 3 + 0.3
            d = V(math.cos(a), math.sin(a), 0)
            m.add("bois", cyl(d * 0.08 + V(0, 0, h - 0.06), d * 0.15, 0.026, 5, r2=0.021))
        m.add("bois", [[V(-0.12, -0.04, h + 0.001), V(0.1, -0.06, h + 0.001), V(0.11, -0.05, h + 0.001), V(-0.12, -0.03, h + 0.001)]],
              plat=True, ao=0.4)    # fente
    else:              # assise de deux planches, 4 pieds, barreaux
        for sy in (-1, 1):
            m.add("planches", prisme_ch(V(m.j(0.005), sy * 0.083, h - 0.05), 0.34, 0.16, 0.05, 0.008, rz=m.j(0.03)))
        m.add("bois", poutre_ch(V(0, -0.15, h - 0.08), V(0, 0.15, h - 0.08), 0.06, 0.04, 0.006))
        for sx in (-1, 1):
            for sy in (-1, 1):
                m.add("bois", cyl(V(sx * 0.11, sy * 0.11, h - 0.05), V(sx * 0.14, sy * 0.14, 0.0), 0.022, 5))
        for sx in (-1, 1):
            m.add("bois", cyl(V(sx * 0.127, -0.13, 0.17), V(sx * 0.127, 0.13, 0.17), 0.013, 4))
    return m


# ---------------------------------------------------------------------------- râtelier (ancien : 1,7 x 1,8 m, prof. 0,3)
def ratelier():
    """Râtelier d'armes : 2 montants sur patins, traverses, peigne d'encoches en haut, auge à pointes en bas ; 2 lances, 4 épées.
    Les armes partent du pied (+0,28 Godot, devant) et s'appuient sur la traverse haute (+0,04)."""
    m = Module("g_ratelier", 5400, hs=1.6)
    zs = lambda z: -z    # Godot z -> Blender y
    for sx in (-0.8, 0.8):
        m.add("bois", prisme_ch(V(sx, 0.0, 0.0), 0.1, 0.1, 1.42, 0.012, rz=m.j(0.02)))
        m.add("fer", box(V(sx, 0.0, 0.0), 0.13, 0.13, 0.05, omit=("bas",)), ao=0.7)                # sabot de fer au pied du montant
        m.add("fer", box(V(sx, 0.0, 1.1), 0.12, 0.12, 0.04, omit=("bas",)), ao=0.8)            # frette
    m.add("bois", poutre_ch(V(-0.86, 0.0, 1.15), V(0.86, 0.0, 1.15 + m.j(0.01)), 0.08, 0.08, 0.0))
    m.add("bois", poutre_ch(V(-0.86, 0.0, 0.45), V(0.86, 0.0, 0.45), 0.08, 0.08, 0.0))
    m.add("bois", poutre_ch(V(-0.86, zs(0.04), 1.42), V(0.86, zs(0.04), 1.42), 0.1, 0.06, 0.008))     # peigne
    for k in range(7):
        x = -0.745 + k * 0.25
        m.add("bois", box(V(x, zs(0.04), 1.45), 0.05, 0.1, 0.07, omit=("bas", "f2", "f4")), ao=0.85)  # dents du peigne
    # (pas d'auge basse : le bas du râtelier reste vide entre les montants, comme avant ; les cailloux du sol s'y posent)
    for k in range(6):
        x = -0.62 + k * 0.25
        pied = V(x, zs(0.28), 0.03)
        if k % 3 == 0:     # lance : hampe, ligature, fer en feuille
            tete = V(x, zs(0.04), 1.8)
            u = (tete - pied).normalized()
            m.add("bois", cyl(pied, tete, 0.018, 5))
            m.add("peau", cyl(tete - u * 0.12, tete - u * 0.02, 0.022, 5), teinte=(0.55, 0.42, 0.3), ao=0.8)
            m.add("lame", lame(tete - u * 0.03, tete + u * 0.24, 0.07, 0.016, 0.45))
        else:              # épée : lame, garde, fusée gainée, pommeau
            tete = V(x, zs(0.04), 1.55)
            u = (tete - pied).normalized()
            garde = tete - u * 0.2
            m.add("lame", lame(garde, pied + u * 0.02, 0.05, 0.012, 0.12))
            m.add("fer", poutre_ch(garde - X * 0.11, garde + X * 0.11, 0.035, 0.03, 0.0))
            m.add("peau", cyl(garde, tete - u * 0.03, 0.017, 5), teinte=(0.45, 0.32, 0.22))
            m.add("fer", prisme_ch(tete - u * 0.035, 0.045, 0.045, 0.045, 0.0))
    return m


# ---------------------------------------------------------------------------- pique à trophée (ancien : perche r 0,04, h 1,6)
def trophee():
    """Pique de 1,6 m (étirée en hauteur par le jeu), légère inclinaison vers +X, ligatures, lanières de peau et os pendus.
    Le crâne du sommet reste posé par CrypteDecor.crane (fonction commune)."""
    m = Module("g_trophee", 5500, hs=1.6)
    h = 1.6
    m.add("bois", cisaille(tour([(0.045, 0.0), (0.04, 0.6), (0.034, 1.2), (0.03, h - 0.02), (0.012, h + 0.06)], 6,
                                jit=0.004, rg=m.rg, caps=(False, True)), 0.03, h), ao=1.0)
    # traverse ligaturée sous le crâne
    yb = h - 0.3
    m.add("bois", cyl(V(-0.2, 0.0, yb + 0.02), V(0.24, 0.01, yb - 0.02), 0.018, 5))
    for z in (yb, h - 0.12):
        m.add("peau", anneau(0.034, 0.046, z - 0.02, z + 0.02, 6, c=V(0.03 * z / h, 0, 0), quoi=("ext", "haut", "bas")), teinte=(0.5, 0.38, 0.28))
    # lanières de peau qui pendent de la traverse
    for x, l, a in ((-0.16, 0.42, 0.1), (-0.06, 0.3, -0.15), (0.17, 0.5, 0.2)):
        p0 = V(x, 0.0, yb)
        q = [p0 + V(-0.03, 0, 0), p0 + V(0.03, 0, 0), p0 + V(0.03 + a * 0.1, 0.01, -l), p0 + V(-0.02 + a * 0.1, 0.01, -l + 0.04)]
        m.add("peau", [q, list(reversed(q))], teinte=(0.7, 0.58, 0.45), ao=0.85)
    # deux os longs pendus à la traverse
    for x, l in ((0.08, 0.28), (0.22, 0.22)):
        m.add("os", cyl(V(x, 0.0, yb - 0.02), V(x + 0.01, 0.0, yb - 0.08), 0.004, 3), ao=0.6)
        m.add("os", cyl(V(x, 0.0, yb - 0.08), V(x + 0.015, 0.01, yb - 0.08 - l), 0.016, 5))
        for e in (0.0, 1.0):
            m.add("os", box(V(x + 0.015 * e, 0.01 * e, yb - 0.1 - l * e), 0.045, 0.03, 0.03), ao=0.9)
    return m


# ---------------------------------------------------------------------------- tas de pièces (ancien : n pièces sur r 0,3)
def piece_faces(c, r, ep, a):
    return dehors(tour([(r, 0.0), (r, ep)], 6, c=c, rot=a), c + V(0, 0, ep / 2))


def pieces(var):
    """Butin répandu : petit tas conique de pièces, piles, pièces éparses sur un rayon de 0,3 (étiré par le jeu)."""
    m = Module(f"g_pieces_{var}", 5600 + ord(var), hs=0.08)
    rg = m.rg
    cx, cy = (0.04, -0.03) if var == "a" else (-0.06, 0.05)
    # tas : cône bosselé de pièces (anneaux de pièces approchés par une révolution dentelée)
    m.add("or", tour([(0.13, 0.0), (0.11, 0.025), (0.07, 0.05), (0.03, 0.065), (0.0, 0.068)], 9, c=V(cx, cy, 0.0), jit=0.012, rg=rg))
    for k in range(9):     # pièces posées en écailles sur le tas
        a = TAU * k / 9 + rg.uniform(-0.2, 0.2)
        rr = rg.uniform(0.05, 0.11)
        c = V(cx + math.cos(a) * rr, cy + math.sin(a) * rr, 0.06 - rr * 0.45)
        M = Rx(rg.uniform(-0.4, 0.4)) @ Ry(rg.uniform(-0.4, 0.4))
        m.add("or", [[c + M @ V(math.cos(TAU * i / 6 + a) * 0.03, math.sin(TAU * i / 6 + a) * 0.03, 0.004) for i in range(6)]], ao=1.0)
    # piles
    for (x, y, nb) in ((-0.17, 0.1, 4), (0.18, 0.12, 3)) if var == "a" else ((0.17, -0.12, 5), (-0.2, -0.1, 2)):
        for i in range(nb):
            m.add("or", piece_faces(V(x + rg.uniform(-0.005, 0.005), y + rg.uniform(-0.005, 0.005), 0.007 * i), 0.03, 0.007, rg.uniform(0, 1)))
    # éparses
    for k in range(10):
        a = rg.uniform(0, TAU)
        d = rg.uniform(0.14, 0.3)
        c = V(math.cos(a) * d, math.sin(a) * d, 0.0)
        m.add("or", [[c + V(math.cos(TAU * i / 6 + a) * 0.03, math.sin(TAU * i / 6 + a) * 0.03, 0.006) for i in range(6)]], ao=0.95)
    if var == "b":         # bourse de cuir crevée
        m.add("peau", tour([(0.0, 0.0), (0.06, 0.0), (0.075, 0.03), (0.05, 0.065), (0.025, 0.08), (0.0, 0.078)], 7, c=V(-0.02, 0.18, 0.0),
                           ech=(1.3, 1.0), jit=0.006, rg=rg), teinte=(0.55, 0.4, 0.28))
    return m


# ---------------------------------------------------------------------------- caisse (ancien : 0,7 x 0,5 x 0,5, étirée)
def caisse(var):
    """Caisse de planches 0,7 (x) x 0,5 (h) x 0,5 (prof.) : 3 planches par face avec joints, montants d'angle, écharpes (a),
    cercles de fer, cornières ; couvercle de 3 planches (b : couvercle décalé). Hors-tout 0,72 x 0,5 x 0,52 : rien ne dépasse le dessus
    (caisses empilées) ni l'ancienne emprise de plus de 1-2 cm."""
    m = Module(f"g_caisse_{var}", 5700 + ord(var), hs=0.5)
    tx, ty, tz = 0.7, 0.5, 0.5          # Godot x, y (haut), z
    W, D, H = tx, tz, ty                # Blender x, y, z
    m.add("noir", box(V(0, 0, 0.02), W - 0.04, D - 0.04, H - 0.06, omit=("bas", "haut")), plat=True, ao=0.1)   # âme sombre (joints)
    gap = 0.008
    hb = H - 0.03                       # haut du corps ; couvercle de 3 cm au-dessus
    hp = (hb - 0.02) / 3
    for i in range(3):
        z0 = 0.01 + i * hp + gap / 2
        for sy in (-1, 1):
            m.add("planches", prisme_ch(V(m.j(0.004), sy * (D / 2 - 0.011), z0), W - 0.1, 0.022, hp - gap, 0.0), ao=m.rg.uniform(0.85, 1.0))
        for sx in (-1, 1):
            m.add("planches", prisme_ch(V(sx * (W / 2 - 0.011), 0, z0), 0.022, D - 0.1, hp - gap, 0.0), ao=m.rg.uniform(0.85, 1.0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.add("bois", prisme_ch(V(sx * (W / 2 - 0.03), sy * (D / 2 - 0.03), 0.0), 0.075, 0.075, hb, 0.0, bas=False))
    if var == "a":     # écharpes sur les deux grandes faces
        for sy in (-1, 1):
            a = V(-W / 2 + 0.07, sy * (D / 2 + 0.006), 0.07)
            b = V(W / 2 - 0.07, sy * (D / 2 + 0.006), hb - 0.07)
            m.add("bois", poutre_ch(a if sy < 0 else V(a.x, a.y, b.z), b if sy < 0 else V(b.x, b.y, a.z), 0.07, 0.024, 0.0, up=Y))
    # couvercle
    zc = hb
    rz = 0.0 if var == "a" else 0.05
    dx = 0.0 if var == "a" else 0.02
    for i in range(3):
        y = -D / 2 + 0.005 + D * (i + 0.5) / 3
        m.add("planches", prisme_ch(Rz(rz) @ V(dx + m.j(0.006), y, 0) + V(0, 0, zc), W + 0.01, D / 3 - 0.008, 0.03, 0.0, rz=rz), ao=0.95)
    # cercles de fer rivetés (bas et haut)
    for zb in (0.06, hb - 0.1):
        for sy in (-1, 1):
            m.add("fer", box(V(0, sy * (D / 2 + 0.008), zb), W + 0.02, 0.012, 0.04, omit=("bas",)))
        for sx in (-1, 1):
            m.add("fer", box(V(sx * (W / 2 + 0.008), 0, zb), 0.012, D + 0.02, 0.04, omit=("bas", "haut")))
    # cornières du haut
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.add("fer", prisme_ch(V(sx * (W / 2 - 0.02), sy * (D / 2 - 0.02), hb - 0.11), 0.09, 0.09, 0.12, 0.0, bas=False))
    # poignées : tasseaux cloués sur les petits côtés (rien ne dépasse de l'emprise)
    for sx in (-1, 1):
        m.add("bois", box(V(sx * (W / 2 + 0.01), 0, hb * 0.66), 0.02, D * 0.5, 0.045, omit=("bas",)), ao=0.85)
    return m


# ---------------------------------------------------------------------------- estrade de l'autel (ancien : 11 blocs, e = 1)
def autel():
    """Estrade de pierre en ruine (e = 1 ; le jeu l'étire de e) : gradins de dalles appareillées aux joints creux, massif en fer à
    cheval ouvert côté salle (-Z Godot), stèle runique brisée, piliers rompus, chapiteau et linteau tombés, table d'offrande sur
    deux dés, éboulis devant, peau tendue et os. Hauteurs des dessus INCHANGÉES (bougies posées par le jeu) : gradin bas 0,56,
    gradin haut 1,12, table d'offrande 1,425. Coordonnées écrites en repère Godot (GV)."""
    m = Module("g_autel", 5800, hs=2.6)
    rg = m.rg

    def bloc(cx, cy, cz, sx, sy, sz, lac=0.0, ch=0.035, mat="pierre", ao=1.0, jit=0.012):
        # (cx, cy, cz) : centre du bloc en repère Godot ; lacet autour de y
        m.add(mat, prisme_ch(GV(cx, cy - sy / 2, cz), sx, sz, sy, ch, rz=lac, jit=jit, rg=rg), ao=ao)

    def assise(cx, y0, cz, sx, sy, sz, nx, nz, lac=0.0, ech=0.03):
        """Gradin de nx x nz dalles (joints de 3 cm), dessus à y0 + sy ; une âme sombre bouche les joints."""
        m.add("pierre", prisme_ch(GV(cx, y0, cz), sx - 0.08, sz - 0.08, sy - 0.02, 0.0, rz=lac), ao=0.35, creux=True)
        for i in range(nx):
            for k in range(nz):
                w = sx / nx
                d = sz / nz
                x = cx - sx / 2 + w * (i + 0.5)
                z = cz - sz / 2 + d * (k + 0.5)
                c = Rz(lac) @ (GV(x - cx, 0, z - cz)) + GV(cx, 0, cz)
                h = sy - (0.0 if (i + k) % 3 else rg.uniform(0.0, 0.03))
                m.add("pierre", prisme_ch(V(c.x, c.y, y0), w - ech, d - ech, h, 0.03, rz=lac + m.j(0.02), jit=0.01, rg=rg),
                      ao=rg.uniform(0.82, 1.0))
    assise(0.0, 0.0, 0.0, 4.8, 0.56, 3.2, 4, 3, 0.03)
    assise(0.0, 0.56, 0.25, 3.7, 0.56, 2.4, 3, 2, -0.05)
    # stèle (dossier) : dalle dressée à rebord, sommet brisé en biseau, entrelacs gravés (rainures creuses)
    sz_ = 0.75
    m.add("pierre", dehors([
        [GV(-1.45, 1.12, 0.85 - sz_ / 2), GV(1.45, 1.12, 0.85 - sz_ / 2), GV(1.45, 2.3, 0.85 - sz_ / 2), GV(0.35, 2.58, 0.85 - sz_ / 2), GV(-1.45, 2.52, 0.85 - sz_ / 2)],
        [GV(-1.45, 1.12, 0.85 + sz_ / 2), GV(-1.45, 2.52, 0.85 + sz_ / 2), GV(0.35, 2.58, 0.85 + sz_ / 2), GV(1.45, 2.3, 0.85 + sz_ / 2), GV(1.45, 1.12, 0.85 + sz_ / 2)],
        [GV(-1.45, 1.12, 0.85 - sz_ / 2), GV(-1.45, 2.52, 0.85 - sz_ / 2), GV(-1.45, 2.52, 0.85 + sz_ / 2), GV(-1.45, 1.12, 0.85 + sz_ / 2)],
        [GV(1.45, 1.12, 0.85 - sz_ / 2), GV(1.45, 1.12, 0.85 + sz_ / 2), GV(1.45, 2.3, 0.85 + sz_ / 2), GV(1.45, 2.3, 0.85 - sz_ / 2)],
        [GV(-1.45, 2.52, 0.85 - sz_ / 2), GV(0.35, 2.58, 0.85 - sz_ / 2), GV(0.35, 2.58, 0.85 + sz_ / 2), GV(-1.45, 2.52, 0.85 + sz_ / 2)],
        [GV(0.35, 2.58, 0.85 - sz_ / 2), GV(1.45, 2.3, 0.85 - sz_ / 2), GV(1.45, 2.3, 0.85 + sz_ / 2), GV(0.35, 2.58, 0.85 + sz_ / 2)],
    ], GV(0.0, 1.8, 0.85)))
    zf = 0.85 - sz_ / 2 - 0.004       # face avant de la stèle (vers la salle)
    # cadre en relief et entrelacs (bandes en saillie de 2 cm : lisibles sous la lumière rasante des bougies)
    def bande(x0, y0, x1, y1, w=0.07):
        a, b = GV(x0, y0, zf), GV(x1, y1, zf)
        d = (b - a).normalized()
        s = d.cross(Y).normalized() * w / 2
        f = [a - s, b - s, b + s, a + s]
        m.add("pierre", dehors(box_frame(f[0], f[1] - f[0], f[3] - f[0], V(0, 0.022, 0)), (a + b) / 2 + V(0, 0.011, 0)), ao=1.0)
    bande(-1.3, 1.3, 1.3, 1.3)
    bande(-1.3, 1.3, -1.3, 2.38)
    bande(1.3, 1.3, 1.3, 2.2)
    for k in range(5):     # entrelacs en chevrons croisés
        x0 = -1.05 + k * 0.5
        bande(x0, 1.45, x0 + 0.38, 2.05 - 0.04 * k, 0.06)
        bande(x0 + 0.38, 1.45, x0, 2.05 - 0.04 * k, 0.06)
    # disque solaire en relief (rune centrale)
    for k in range(4):
        a0 = TAU * k / 8
        bande(math.cos(a0) * 0.18, 2.2 + math.sin(a0) * 0.18, -math.cos(a0) * 0.18, 2.2 - math.sin(a0) * 0.18, 0.05)
    # piliers rompus (flancs) : fûts octogonaux à base et chapiteau
    for (x, h, br) in ((-1.45, 1.25, 0.25), (1.45, 0.95, -0.3)):
        m.add("pierre", prisme_ch(GV(x, 1.12, 0.2) + V(0, 0, 0), 0.8, 1.1, 0.16, 0.03), ao=0.9)
        prof = [(0.32, 0.0), (0.3, h * 0.7), (0.29, h - 0.12)]
        f = tour(prof, 8, c=GV(x, 1.28, 0.2), rot=0.3, jit=0.012, rg=rg, caps=(False, False))
        m.add("pierre", f)
        top = [GV(x + math.cos(TAU * i / 8 + 0.3) * 0.29, 1.28 + h - 0.12 + (0.1 + br * 0.3) * math.cos(TAU * i / 8 + 1.0), 0.2 + math.sin(TAU * i / 8 + 0.3) * 0.29) for i in range(8)]
        m.add("pierre", [orient(top, Z)], ao=0.9)
    m.add("pierre", prisme_ch(GV(-1.45, 2.32, 0.25), 0.6, 0.8, 0.45, 0.04, rz=0.35, jit=0.015, rg=rg), ao=0.95)      # chapiteau tombé
    m.add("pierre", prisme_ch(GV(0.2, 2.55, 0.9), 1.3, 0.6, 0.4, 0.04, rz=-0.2, M=Ry(0.08), jit=0.015, rg=rg), ao=0.95)   # linteau brisé
    # table d'offrande : dalle sur deux dés, dessus à 1,425
    for x in (-0.55, 0.55):
        bloc(x, 1.12 + 0.12, -0.2, 0.32, 0.24, 0.6, 0.0, 0.02, ao=0.8)
    bloc(0.0, 1.425 - 0.07, -0.2, 1.5, 0.14, 0.9, 0.0, 0.025)
    # peau tendue sur la table (débord à l'avant)
    def peau_t(u, v):
        x = (u - 0.5) * 0.9
        z = -0.6 + v * 0.75
        y = 1.43 - smooth(0.0, 0.15, -0.6 - z + 0.15) * 0.18 + 0.01 * math.sin(u * 9)
        return GV(x, y, z)
    m.add("peau", grille(peau_t, 3, 3), teinte=(0.78, 0.66, 0.52))
    # éboulis devant (blocs isolés et dalles brisées)
    for (x, y, z, sx, sy, sz, lac) in ((-2.2, 0.0, -1.5, 0.9, 0.4, 0.7, 0.5), (2.0, 0.0, -1.48, 0.66, 0.34, 0.56, -0.4), (0.9, 0.0, -2.0, 0.5, 0.24, 0.45, 0.9),
                                        (-1.0, 0.0, -2.05, 0.45, 0.16, 0.38, 0.2)):
        m.add("roche", prisme_ch(GV(x, y, z), sx, sz, sy, 0.05, rz=lac, jit=0.02, rg=rg), ao=0.9)
    # os épars sur le gradin bas
    for (x, z, a) in ((-1.2, -1.1, 0.4), (1.5, -1.0, -0.8)):
        c = GV(x, 0.585, z)
        d = Rz(a) @ V(0.17, 0, 0)
        m.add("os", cyl(c - d, c + d, 0.022, 5), ao=0.85)
    return m


# ---------------------------------------------------------------------------- brasero sur trépied (dehors, ancien : prismes)
def brasero():
    """Brasero de fer : 3 pieds forgés (pied en volute), cerclage à mi-hauteur, cuve évasée rivetée à bord roulé, braises."""
    m = Module("g_brasero", 5900, hs=0.9)
    for k in range(3):
        a = TAU * k / 3 + 0.4
        d = V(math.cos(a), math.sin(a), 0)
        m.add("fer", poutre_ch(d * 0.3, d * 0.12 + V(0, 0, 0.62), 0.04, 0.03, 0.004, up=Z))
        m.add("fer", prisme_ch(d * 0.32, 0.09, 0.09, 0.02, 0.0, rz=a, bas=False), ao=0.8)              # patte
        m.add("fer", cyl(d * 0.12 + V(0, 0, 0.62), d * 0.2 + V(0, 0, 0.78), 0.014, 4))                  # agrafe de cuve
    m.add("fer", anneau(0.205, 0.225, 0.3, 0.33, 8, quoi=("ext", "haut")))
    prof = [(0.0, 0.6), (0.18, 0.6), (0.33, 0.66), (0.43, 0.76), (0.46, 0.9)]
    m.add("fer", tour(prof, 8, rot=math.pi / 8, caps=(False, False)))
    m.add("fer", rev(tour([(0.4, 0.78), (0.43, 0.9)], 8, rot=math.pi / 8, caps=(False, False))), ao=0.5)
    m.add("fer", anneau(0.43, 0.48, 0.88, 0.92, 8, quoi=("ext", "haut", "bas"), rot=math.pi / 8))
    for k in range(5):
        a = TAU * k / 5
        m.add("fer", box(V(math.cos(a) * 0.41, math.sin(a) * 0.41, 0.75), 0.03, 0.03, 0.03, rz=a, omit=("bas", "haut")), ao=0.75)
    m.add("braise", tour([(0.4, 0.84), (0.28, 0.88), (0.12, 0.905), (0.0, 0.91)], 9, jit=0.02, rg=m.rg),
          ao=lambda p, n: 0.8 + 0.2 * noise.noise(p * 9.0))
    return m


# ------------------------------------------------------------------------------------------------ export
def godot(p):
    return (p.x, p.z, -p.y)


def ecrire_dat():
    os.makedirs(os.path.dirname(DAT), exist_ok=True)
    with open(DAT, "wb") as f:
        f.write(struct.pack("<I", len(DONNEES)))
        for nom, verts in DONNEES.items():
            nb = nom.encode()
            f.write(struct.pack("<B", len(nb)) + nb + struct.pack("<I", len(verts)))
            for p, c in verts:
                g = godot(p)
                f.write(struct.pack("<7f", g[0], g[1], g[2], c[0], c[1], c[2], c[3]))


def boite(mod):
    pts = []
    for nom, verts in DONNEES.items():
        if nom.split("__")[0] == mod:
            pts += [godot(p) for p, _ in verts]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return lo, hi


TEINTE_APERCU = {"bois": (0.32, 0.24, 0.17), "planches": (0.45, 0.33, 0.22), "fer": (0.32, 0.33, 0.36), "lame": (0.62, 0.64, 0.68),
                 "os": (0.86, 0.82, 0.7), "peau": (0.6, 0.48, 0.34), "paille": (0.75, 0.62, 0.3), "or": (0.95, 0.75, 0.25),
                 "toile": (0.85, 0.8, 0.7), "braise": (1.0, 0.45, 0.08), "noir": (0.04, 0.04, 0.05), "pierre": (0.55, 0.58, 0.62),
                 "roche": (0.45, 0.45, 0.47)}


def apercu(mods):
    """Une planche : tous les modules alignés, vue 3/4 orthographique (Workbench, couleurs de sommet x teinte de matière)."""
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
    x = 0.0
    lim = [1e9, -1e9, -1e9]
    for M in mods:
        lo, hi = boite(M.nom)
        x += -lo[0] + 0.3
        for nom, verts in DONNEES.items():
            if nom.split("__")[0] != M.nom:
                continue
            me = bpy.data.meshes.new(nom)
            vs = [tuple(p) for p, _ in verts]
            me.from_pydata(vs, [], [(i, i + 1, i + 2) for i in range(0, len(vs), 3)])
            me.update()
            ca = me.color_attributes.new(name="apercu", type='FLOAT_COLOR', domain='CORNER')
            t = TEINTE_APERCU[nom.split("__")[1]]
            for poly in me.polygons:
                for li in poly.loop_indices:
                    c = verts[li][1]
                    ca.data[li].color = (t[0] * c[0] * 1.6, t[1] * c[1] * 1.6, t[2] * c[2] * 1.6, 1)
            me.color_attributes.active_color = ca
            ob = bpy.data.objects.new(nom, me)
            ob.location = (x, 0, 0)
            sc.collection.objects.link(ob)
        lim[0] = min(lim[0], x + lo[0])
        x += hi[0] + 0.3
        lim[1] = max(lim[1], x)
        lim[2] = max(lim[2], hi[1])
    sc.render.resolution_x, sc.render.resolution_y = 2400, 700
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = 'ORTHO'
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    ctr = V((lim[0] + lim[1]) / 2, 0, lim[2] / 2)
    cam_d.ortho_scale = (lim[1] - lim[0]) * 1.02
    d = V(0.35, -1.0, 0.45)
    cam.location = ctr + d.normalized() * 40
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    cam_d.clip_end = 200
    sc.render.filepath = os.path.join(CAPT, "planche.png")
    bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mods = []
    for v in "abc":
        mods.append(sac(v))
    for v in "ab":
        mods += [couchage(v), tabouret(v), pieces(v), caisse(v)]
    mods += [ratelier(), trophee(), autel(), brasero()]
    for M in mods:
        M.compiler()
    ecrire_dat()
    print("=== grotte objets : %d entrées -> %s" % (len(DONNEES), DAT))
    depasse = 0
    total = 0
    for M in sorted(mods, key=lambda M: M.nom):
        t = sum(len(v) // 3 for k, v in DONNEES.items() if k.split("__")[0] == M.nom)
        total += t
        base = M.nom.rsplit("_", 1)[0] if M.nom.rsplit("_", 1)[-1] in ("a", "b", "c") else M.nom
        bud = BUDGET[base]
        lo, hi = boite(M.nom)
        depasse += 0 if t <= bud else 1
        print("  %-16s %5d / %5d %s  x[%.2f %.2f] y[%.2f %.2f] z[%.2f %.2f]" % (M.nom, t, bud, "OK" if t <= bud else "DÉPASSE",
                                                                              lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    print("=== total %d triangles, %d dépassements de budget" % (total, depasse))
    if "--" in sys.argv and "apercu" in sys.argv[sys.argv.index("--") + 1:]:
        apercu(mods)


main()
