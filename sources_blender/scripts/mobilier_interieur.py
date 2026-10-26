# Lot L6 (intérieurs du village) : MODULES DE MOBILIER INTÉRIEUR (tables, bancs, coffres, tonneaux, lits, étagères,
# vaisselle, sacs, crânes, boucliers, armes, trône et estrade de la halle, enclume, soufflet, bac, meule de la forge).
#   blender.exe -b --python mobilier_interieur.py            (« -- apercu » : aperçus Workbench dans captures/mobilier_interieur/)
# Sortie : assets/modeles/mobilier_interieur.dat = encodage Godot `var_to_bytes` d'un Dictionary
#   {"<module>/<matiere>": [PackedVector3Array sommets, PackedVector3Array normales, PackedColorArray couleurs, PackedInt32Array index]}
#   lu par `Interieurs.modele()` (bytes_to_var, aucun .glb : les intérieurs se bâtissent dans un fil).
# Repère : on modélise en Blender (Z en haut, AVANT = -Y) ; le .dat est écrit dans le repère GODOT (Y en haut, AVANT = +Z),
#   triangles dans l'ordre Godot (face avant = sens horaire), normales plates. Origine de chaque module : au sol, au centre
#   de l'emprise, sauf mention (plateaux et assises : origine au DESSUS du plateau).
# Matières = clés des matières d'intérieur (`Interieurs.materiaux()`), projetées en triplanaire 64 texels/m par le shader
#   ps1_interieur ; trois noms génériques sont remplacés au moment de la pose : PEAU (couverture du lit), MAT (vaisselle bois
#   ou étain), BOUCLIER (peinture du bouclier).
# Couleur de sommet : rgb = occlusion peinte (dessous, pieds, creux), a = 1 (jamais de neige dedans).
import bpy, math, os, random, struct, sys
from mathutils import Vector, Matrix, Euler, noise

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
DAT = os.path.join(BASE, "assets", "modeles", "mobilier_interieur.dat")
CAPT = os.path.join(BASE, "captures", "mobilier_interieur")
VERSION = 1
MATIERES = ("bois", "bois_v", "bois_sombre", "bois_clair", "bois_suie", "rondin_sombre", "bout", "fer", "fer_noir", "etain",
            "cuir", "foin", "jute", "peau", "peau_claire", "peau_sombre", "terre", "argile", "os", "parchemin", "noir", "brute",
            "cire", "eau", "braises", "charbon", "PEAU", "MAT", "BOUCLIER")
# budget de triangles par module (perf des intérieurs : ≤ +0,5 ms)
BUDGET = {"table_plateau": 420, "table_treteau": 200, "table_entretoise": 40, "banc_assise": 200, "banc_pied": 120,
          "tabouret": 260, "coffre": 1300, "tonneau": 760, "lit": 1000, "fourrure_froissee": 160, "etagere": 700,
          "chope": 200, "assiette": 110, "cruche": 320, "bol": 170, "chaudron": 460, "livre": 120, "parchemin": 90,
          "sac": 320, "crane": 260, "bouclier": 560, "hache": 120, "epee": 120, "lance_hampe": 30, "lance_fer": 40, "trone_halle": 3200,
          "estrade_halle": 1500, "enclume": 700, "soufflet": 600, "bac_trempe": 540, "meule": 500}
DONNEES = {}      # "module/matiere" -> [(Vector Blender, Vector normale Blender, (r, g, b, a))]
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


def centre(faces):
    s = V(0, 0, 0)
    k = 0
    for f in faces:
        for p in f:
            s += p
            k += 1
    return s / max(k, 1)


def dehors(faces, c=None):
    """Oriente chaque face d'un solide convexe vers l'extérieur (normale opposée au centre)."""
    c = centre(faces) if c is None else c
    out = []
    for f in faces:
        fc = sum(f, V(0, 0, 0)) / len(f)
        out.append(f if newell(f).dot(fc - c) >= 0 else list(reversed(f)))
    return out


def rev(faces):
    return [list(reversed(f)) for f in faces]


def xf(faces, M=None, t=None):
    M = M or Matrix.Identity(3)
    t = t if t is not None else V(0, 0, 0)
    return [[t + M @ p for p in f] for f in faces]


def Rz(a):
    return Matrix.Rotation(a, 3, 'Z')


def Rx(a):
    return Matrix.Rotation(a, 3, 'X')


def Ry(a):
    return Matrix.Rotation(a, 3, 'Y')


# ------------------------------------------------------------------------------------------------ primitives
def box_frame(o, U, Vv, N, omit=()):
    if U.cross(Vv).dot(N) < 0:
        U, Vv = Vv, U
    c = [o, o + U, o + U + Vv, o + Vv]
    c = c + [p + N for p in c]
    idx = {"bas": (0, 3, 2, 1), "haut": (4, 5, 6, 7), "f1": (0, 1, 5, 4), "f2": (1, 2, 6, 5), "f3": (2, 3, 7, 6), "f4": (3, 0, 4, 7)}
    return [[c[i] for i in f] for k, f in idx.items() if k not in omit]


def box(c, sx, sy, sz, rz=0.0, tx=0.0, ty=0.0, omit=()):
    """Bloc : c = centre de la base."""
    R = Euler((tx, ty, rz)).to_matrix()
    U, Vv, N = R @ V(sx, 0, 0), R @ V(0, sy, 0), R @ V(0, 0, sz)
    return box_frame(c - U / 2 - Vv / 2, U, Vv, N, omit)


def beam(a, b, w, h, up=Z, omit=()):
    """Poutre de section w x h de a à b."""
    d = b - a
    side = d.cross(up)
    if side.length < 1e-6:
        side = d.cross(X)
    side.normalize()
    N = side.cross(d).normalized()
    return box_frame(a - side * w / 2 - N * h / 2, d, side * w, N * h, omit)


def prisme_ch(c, sx, sy, sz, ch=0.01, rz=0.0, coin=None, M=None, haut=True, bas=True):
    """Boîte aux arêtes chanfreinées (haut, bas et verticales) : c = centre de la base, rotation rz puis M."""
    coin = 0.0 if coin is None else coin   # arêtes verticales vives par défaut (budget de triangles)
    R = (M or Matrix.Identity(3)) @ Rz(rz)
    huit = min(coin, sx * 0.45, sy * 0.45) > 1e-5

    def ring(z, ins):
        hx, hy = sx / 2 - ins, sy / 2 - ins
        k = max(0.0, min(coin, hx * 0.45, hy * 0.45))
        if huit:
            k = max(k, 1e-4)
        if not huit:
            pts = [(hx, -hy), (hx, hy), (-hx, hy), (-hx, -hy)]
        else:
            pts = [(hx - k, -hy), (hx, -hy + k), (hx, hy - k), (hx - k, hy), (-hx + k, hy), (-hx, hy - k), (-hx, -hy + k), (-hx + k, -hy)]
        return [c + R @ V(x, y, z) for x, y in pts]
    if ch > 1e-5:
        rings = [ring(0.0, ch), ring(ch, 0.0), ring(sz - ch, 0.0), ring(sz, ch)]
    else:
        rings = [ring(0.0, 0.0), ring(sz, 0.0)]
    faces = []
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        n = len(a)
        for k in range(n):
            k1 = (k + 1) % n
            faces.append([a[k], a[k1], b[k1], b[k]])
    if bas:
        faces.append(list(reversed(rings[0])))
    if haut:
        faces.append(list(rings[-1]))
    return dehors(faces, c + R @ V(0, 0, sz / 2))


def poutre_ch(a, b, w, h, ch=0.008, up=Z):
    """Poutre chanfreinée de a à b (section w x h)."""
    d = b - a
    L = d.length
    side = d.cross(up)
    if side.length < 1e-6:
        side = d.cross(X)
    side.normalize()
    N = side.cross(d).normalized()
    M = Matrix((side, N, d.normalized())).transposed()
    # prisme local : x = side, y = N, z = d
    return prisme_ch(a, w, h, L, ch, M=M)


def tour(profil, n, c=None, M=None, rot=0.0, caps=(True, True), ech=(1.0, 1.0), jit=0.0, rg=None, a0=0.0, a1=None):
    """Solide de révolution autour de Z local : profil = [(r, z)] (montant puis redescendant pour les creux)."""
    M = M or Matrix.Identity(3)
    c = c if c is not None else V(0, 0, 0)
    ferme = a1 is None
    nb = n if ferme else n + 1
    span = TAU if ferme else (a1 - a0)
    rings = []
    for (r, z) in profil:
        ring = []
        for k in range(nb):
            an = rot + a0 + span * k / n
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
            k1 = (k + 1) % nb
            if profil[i][0] < 1e-5:
                faces.append([r0[k], r1[k1], r1[k]])
            elif profil[i + 1][0] < 1e-5:
                faces.append([r0[k], r0[k1], r1[k]])
            else:
                faces.append([r0[k], r0[k1], r1[k1], r1[k]])
    if ferme:
        if caps[0] and profil[0][0] > 1e-5:
            faces.append(list(reversed(rings[0])))
        if caps[1] and profil[-1][0] > 1e-5:
            faces.append(list(rings[-1]))
    return faces


def cyl(a, b, r, n=8, r2=None, caps=(True, True), rot=0.0):
    d = b - a
    L = d.length
    Mq = d.to_track_quat('Z', 'Y').to_matrix()
    rr2 = r if r2 is None else r2
    return tour([(r, 0.0), (rr2, L)], n, c=a, M=Mq, rot=rot, caps=caps)


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


def tore(R, r, n, m, c=None, M=None, a0=0.0, a1=TAU):
    """Anneau de section ronde (poignées, anses) : rayon R, section r, n segments sur l'arc, m côtés."""
    M = M or Matrix.Identity(3)
    c = c if c is not None else V(0, 0, 0)
    ferme = abs(a1 - a0 - TAU) < 1e-6
    nb = n if ferme else n + 1
    rings = []
    for i in range(nb):
        a = a0 + (a1 - a0) * i / n
        ce = V(math.cos(a) * R, math.sin(a) * R, 0)
        ra = V(math.cos(a), math.sin(a), 0)
        rings.append([c + M @ (ce + ra * math.cos(TAU * j / m) * r + Z * math.sin(TAU * j / m) * r) for j in range(m)])
    faces = []
    for i in range(n):
        r0, r1 = rings[i], rings[(i + 1) % nb]
        for j in range(m):
            j1 = (j + 1) % m
            faces.append([r0[j], r1[j], r1[j1], r0[j1]])
    return faces


def plaque(pts2, ep, M=None, c=None):
    """Plaque convexe extrudée : contour 2D (x, z) dans le plan XZ, épaisseur ep vers +Y (avant = -Y)."""
    M = M or Matrix.Identity(3)
    c = c if c is not None else V(0, 0, 0)
    av = [c + M @ V(x, 0.0, z) for x, z in pts2]
    ar = [c + M @ V(x, ep, z) for x, z in pts2]
    faces = [av, list(reversed(ar))]
    n = len(pts2)
    for k in range(n):
        k1 = (k + 1) % n
        faces.append([av[k], ar[k], ar[k1], av[k1]])
    return dehors(faces)


def grille(fn, nu, nv):
    """Surface paramétrée fn(u, v) -> point, u, v dans [0, 1] (tissus drapés)."""
    P = [[fn(i / nu, j / nv) for j in range(nv + 1)] for i in range(nu + 1)]
    return [[P[i][j], P[i + 1][j], P[i + 1][j + 1], P[i][j + 1]] for i in range(nu) for j in range(nv)]


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

    def add(self, mat, faces, ao=1.0, creux=False, plat=False):
        assert mat in MATIERES, mat
        self.parts.append(dict(mat=mat, faces=faces, ao=ao, creux=creux, plat=plat))

    def couleur(self, part, p, n):
        if part["plat"]:
            k = part["ao"] if not callable(part["ao"]) else part["ao"](p, n)
            return (k, k, k, 1.0)
        ao = 0.74 + 0.26 * smooth(-0.02, self.hs, p.z)
        if n.z < -0.5:
            ao *= 0.8
        elif n.z > 0.5:
            ao = min(1.0, ao * 1.06)
        ao *= part["ao"](p, n) if callable(part["ao"]) else part["ao"]
        if part["creux"]:
            ao *= 0.5
        ao *= 0.9 + 0.1 * noise.noise(p * 5.3 + self.off)
        ao = max(0.12, min(1.0, ao))
        return (ao, ao, ao, 1.0)

    def compiler(self):
        for part in self.parts:
            cle = f"{self.nom}/{part['mat']}"
            lst = DONNEES.setdefault(cle, [])
            for f in part["faces"]:
                n = newell(f)
                cols = [self.couleur(part, p, n) for p in f]
                for i in range(1, len(f) - 1):
                    for k in (0, i, i + 1):
                        lst.append((f[k].copy(), n, cols[k]))

    def tris(self):
        return sum(sum(len(f) - 2 for f in p["faces"]) for p in self.parts)


# ---------------------------------------------------------------------------- table (plateau + tréteaux + entretoise)
def table_plateau(var):
    """Plateau de 2,0 x 0,8 m (étiré en X par le jeu), dessus à z = 0, épaisseur 0,1 (planches 6,5 cm + traverses)."""
    m = Module(f"table_plateau_{var}", 1100 + ord(var), hs=0.0)
    nb = 3 if var == "a" else 4
    lg = 0.8
    gap = 0.007
    w = (lg - gap * (nb - 1)) / nb
    y = -lg / 2
    for i in range(nb):
        yc = y + w / 2
        dz = m.j(0.003)
        long = 2.0 - (0.0 if (var == "b" and i != 1) else m.rg.uniform(0.0, 0.03))
        m.add("bois", prisme_ch(V(m.j(0.01), yc, -0.065 + dz), long, w, 0.065, 0.011, rz=m.j(0.004)),
              ao=m.rg.uniform(0.88, 1.0))
        y += w + gap
    # traverses sous le plateau, chevilles de bois sur le dessus
    for sx in (-0.78, 0.78):
        m.add("bois_sombre", prisme_ch(V(sx, 0, -0.1), 0.07, lg - 0.06, 0.036, 0.006), ao=0.7)
        for i in range(nb):
            yc = -lg / 2 + w / 2 + i * (w + gap)
            m.add("bois_sombre", cyl(V(sx, yc, -0.002), V(sx, yc, 0.003), 0.012, 5), plat=True, ao=0.55)
    if var == "b":   # entaille d'usure et tache sombre sur le bord avant
        m.add("bois_sombre", box(V(0.35, -lg / 2 + 0.06, -0.001), 0.3, 0.1, 0.002, rz=0.3), plat=True, ao=0.6)
    return m


def table_treteau(var):
    """Tréteau (hauteur 0,68 sous le plateau, profondeur 0,8) : chapeau, deux jambes écartées, traverse basse."""
    m = Module(f"table_treteau_{var}", 1200 + ord(var), hs=0.7)
    h = 0.68
    m.add("bois_sombre", poutre_ch(V(0, -0.36, h - 0.06), V(0, 0.36, h - 0.06), 0.09, 0.06, 0.008))
    ex = 0.04 if var == "b" else 0.0
    for sy in (-1, 1):
        a = V(0, sy * 0.24, h - 0.06)
        b = V(ex * sy, sy * 0.33, 0.0)
        m.add("bois_v", poutre_ch(b, a, 0.075, 0.07, 0.008, up=X))
        m.add("bois_sombre", prisme_ch(V(ex * sy, sy * 0.33, 0), 0.1, 0.12, 0.03, 0.006), ao=0.8)
    m.add("bois_v", poutre_ch(V(0, -0.29, 0.2), V(0, 0.29, 0.2), 0.05, 0.05, 0.006))
    if var == "b":   # cheville de fer qui traverse le chapeau
        for sy in (-1, 1):
            m.add("fer_noir", box(V(0, sy * 0.24, h - 0.03), 0.11, 0.02, 0.02))
    return m


def table_entretoise():
    m = Module("table_entretoise", 1300, hs=0.3)
    m.add("bois_sombre", poutre_ch(V(-0.5, 0, 0), V(0.5, 0, 0), 0.07, 0.055, 0.008))
    return m


# ---------------------------------------------------------------------------- banc
def banc_assise(var):
    """Assise de 2,0 x 0,34 m (étirée en X), dessus à z = 0, épaisseur 0,08."""
    m = Module(f"banc_assise_{var}", 1400 + ord(var), hs=0.0)
    if var == "a":
        m.add("bois", prisme_ch(V(0, 0, -0.07), 2.0, 0.34, 0.07, 0.014), ao=0.95)
    else:
        for sy in (-1, 1):
            m.add("bois", prisme_ch(V(m.j(0.01), sy * 0.0855, -0.07 + m.j(0.003)), 2.0 - m.rg.uniform(0, 0.03), 0.165, 0.07, 0.012),
                  ao=m.rg.uniform(0.85, 1.0))
    m.add("bois_sombre", prisme_ch(V(0, 0, -0.1), 1.6, 0.07, 0.03, 0.006), ao=0.7)
    return m


def banc_pied():
    """Pied-planche (0,09 x 0,28 x 0,38) à arche découpée et tenon chevillé."""
    m = Module("banc_pied", 1500, hs=0.4)
    for sy in (-1, 1):
        m.add("bois_v", prisme_ch(V(0, sy * 0.1, 0), 0.09, 0.08, 0.3, 0.008))
    m.add("bois_v", prisme_ch(V(0, 0, 0.27), 0.09, 0.28, 0.11, 0.008))
    # arche (dessous du linteau du pied)
    pts = [V(-0.045, -0.06, 0.27), V(-0.045, -0.035, 0.235), V(-0.045, 0.0, 0.225), V(-0.045, 0.035, 0.235), V(-0.045, 0.06, 0.27)]
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        m.add("bois_v", [[a, b, b + V(0.09, 0, 0), a + V(0.09, 0, 0)]], ao=0.7)
        m.add("bois_v", [[a, b, V(-0.045, b.y, 0.27)], ], ao=0.8)
        m.add("bois_v", rev([[a + V(0.09, 0, 0), b + V(0.09, 0, 0), V(0.045, b.y, 0.27)]]), ao=0.8)
    m.add("bois_sombre", cyl(V(-0.06, 0, 0.33), V(0.06, 0, 0.33), 0.012, 5), ao=0.6)
    return m


# ---------------------------------------------------------------------------- tabouret
def tabouret(var):
    """Tabouret (assise r 0,19 à 0,45 m), 3 pieds (a) ou 4 pieds et barreaux (b)."""
    m = Module(f"tabouret_{var}", 1600 + ord(var), hs=0.45)
    h = 0.45
    m.add("bois", tour([(0.0, h - 0.06), (0.17, h - 0.06), (0.19, h - 0.045), (0.19, h - 0.012), (0.175, h), (0.0, h)], 10,
                       rot=0.2, jit=0.004, rg=m.rg))
    n = 3 if var == "a" else 4
    for k in range(n):
        a = TAU * k / n + 0.3
        d = V(math.cos(a), math.sin(a), 0)
        m.add("bois_v", cyl(d * 0.09 + V(0, 0, h - 0.06), d * 0.16 + V(0, 0, 0), 0.024, 6, r2=0.02))
    if var == "b":
        for k in range(n):
            a0 = TAU * k / n + 0.3
            a1 = TAU * (k + 1) / n + 0.3
            p0 = V(math.cos(a0), math.sin(a0), 0) * 0.135 + V(0, 0, 0.16)
            p1 = V(math.cos(a1), math.sin(a1), 0) * 0.135 + V(0, 0, 0.16 + (0.03 if k % 2 else 0.0))
            m.add("bois_v", cyl(p0, p1, 0.012, 5))
    return m


# ---------------------------------------------------------------------------- coffre
def coffre(var):
    """Coffre ferré 0,9 x 0,55 x 0,46 (caisse) + couvercle (dessus vers 0,63 m). a : couvercle bombé, b : plat, c : en bâtière."""
    m = Module(f"coffre_{var}", 1700 + ord(var), hs=0.62)
    w, d, h = 0.9, 0.55, 0.46
    # socle de planches sombres
    m.add("bois_sombre", prisme_ch(V(0, 0, 0), w + 0.04, d + 0.04, 0.06, 0.008), ao=0.75)
    # caisse : âme, puis planches horizontales en saillie sur les 4 faces, montants d'angle
    m.add("bois_v", box(V(0, 0, 0.06), w - 0.02, d - 0.02, h - 0.06), ao=0.8)
    nb = 3
    hp = (h - 0.06) / nb
    for i in range(nb):
        z0 = 0.06 + i * hp + 0.004
        for sy in (-1, 1):
            m.add("bois_v", prisme_ch(V(m.j(0.004), sy * (d / 2 - 0.006), z0), w - 0.1, 0.022, hp - 0.008, 0.006), ao=m.rg.uniform(0.85, 1.0))
        for sx in (-1, 1):
            m.add("bois_v", prisme_ch(V(sx * (w / 2 - 0.006), 0, z0), 0.022, d - 0.1, hp - 0.008, 0.006), ao=m.rg.uniform(0.85, 1.0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.add("bois_sombre", prisme_ch(V(sx * (w / 2 - 0.025), sy * (d / 2 - 0.025), 0.05), 0.07, 0.07, h - 0.05, 0.008))
            # équerres de fer d'angle (haut et bas)
            for zc in (0.08, h - 0.08):
                m.add("fer_noir", box(V(sx * (w / 2 + 0.008), sy * (d / 2 - 0.05), zc - 0.035), 0.012, 0.1, 0.07))
                m.add("fer_noir", box(V(sx * (w / 2 - 0.05), sy * (d / 2 + 0.008), zc - 0.035), 0.1, 0.012, 0.07))
    # couvercle
    yb = h
    if var == "a":
        n = 6
        hb = 0.17
        arc = [(math.cos(math.pi * k / n) * (d / 2 + 0.012), yb + 0.025 + math.sin(math.pi * k / n) * hb) for k in range(n + 1)]
        L = w + 0.02
        for k in range(n):
            (y0, z0), (y1, z1) = arc[k], arc[k + 1]
            q = [V(-L / 2, y0, z0), V(L / 2, y0, z0), V(L / 2, y1, z1), V(-L / 2, y1, z1)]
            m.add("bois", [q if newell(q).dot(V(0, (y0 + y1) / 2, (z0 + z1) / 2 - yb)) > 0 else list(reversed(q))],
                  ao=0.9 + 0.1 * (k % 2))
        for sx in (-1, 1):
            pts = [V(sx * L / 2, y, z) for y, z in arc] + [V(sx * L / 2, -d / 2 - 0.012, yb + 0.025)]
            f = pts
            m.add("bois", [f if newell(f).x * sx > 0 else list(reversed(f))], ao=0.85)
        m.add("bois", box(V(0, 0, yb), L, d + 0.024, 0.025), ao=0.8)
        # 3 bandes de fer cintrées + clous
        for xb in (-0.3, 0.0, 0.3):
            for k in range(n):
                (y0, z0), (y1, z1) = arc[k], arc[k + 1]
                p0 = V(xb, y0 * 1.04, yb + 0.025 + (z0 - yb - 0.025) * 1.04 + 0.002)
                p1 = V(xb, y1 * 1.04, yb + 0.025 + (z1 - yb - 0.025) * 1.04 + 0.002)
                m.add("fer", poutre_ch(p0, p1, 0.055, 0.01, 0.0, up=X if abs((p1 - p0).normalized().z) < 0.99 else Y))
            for sy in (-1, 1):
                m.add("fer", box(V(xb, sy * (d / 2 + 0.005), 0.08), 0.055, 0.012, h - 0.05))
    elif var == "b":
        m.add("bois", prisme_ch(V(0, 0, yb), w + 0.04, d + 0.04, 0.06, 0.014), ao=0.92)
        m.add("bois", prisme_ch(V(0, 0, yb + 0.06), w - 0.08, d - 0.12, 0.035, 0.012), ao=1.0)
        for xb in (-0.28, 0.28):
            m.add("fer", box(V(xb, 0, yb + 0.06), 0.06, d + 0.05, 0.008))
            for sy in (-1, 1):
                m.add("fer", box(V(xb, sy * (d / 2 + 0.006), 0.07), 0.06, 0.012, h + 0.0))
            for k in range(4):
                yy = -d / 2 + 0.07 + k * (d - 0.14) / 3
                m.add("fer_noir", cyl(V(xb, yy, yb + 0.066), V(xb, yy, yb + 0.078), 0.012, 5))
    else:
        L = w + 0.03
        za = yb + 0.03
        zt = yb + 0.17
        for sy in (-1, 1):
            q = [V(-L / 2, sy * (d / 2 + 0.015), za), V(L / 2, sy * (d / 2 + 0.015), za), V(L / 2, 0, zt), V(-L / 2, 0, zt)]
            m.add("bois", dehors(box_frame(q[0], q[1] - q[0], q[3] - q[0], V(0, 0, 0.03))), ao=0.92)
        for sx in (-1, 1):
            tri = [V(sx * L / 2 * 0.98, -d / 2, za), V(sx * L / 2 * 0.98, d / 2, za), V(sx * L / 2 * 0.98, 0, zt - 0.01)]
            m.add("bois", [tri if newell(tri).x * sx > 0 else list(reversed(tri))], ao=0.8)
        m.add("bois", box(V(0, 0, yb), L, d + 0.03, 0.03), ao=0.8)
        m.add("bois_sombre", poutre_ch(V(-L / 2 - 0.01, 0, zt + 0.015), V(L / 2 + 0.01, 0, zt + 0.015), 0.05, 0.04, 0.008))
        for xb in (-0.32, 0.32):
            for sy in (-1, 1):
                p0 = V(xb, sy * (d / 2 + 0.03), za + 0.03)
                p1 = V(xb, 0, zt + 0.03)
                m.add("fer", poutre_ch(p0, p1, 0.05, 0.01, 0.0, up=X))
                m.add("fer", box(V(xb, sy * (d / 2 + 0.006), 0.07), 0.05, 0.012, h))
    # moraillon, serrure, anneaux de manutention
    m.add("fer_noir", prisme_ch(V(0, -d / 2 - 0.012, h - 0.17), 0.13, 0.016, 0.14, 0.004))
    m.add("fer", box(V(0, -d / 2 - 0.024, h - 0.11), 0.03, 0.01, 0.05))
    m.add("noir", box(V(0, -d / 2 - 0.0215, h - 0.135), 0.012, 0.004, 0.025), plat=True, ao=0.3)
    m.add("fer_noir", box(V(0, -d / 2 - 0.03, h - 0.03), 0.045, 0.02, 0.11))
    for sx in (-1, 1):
        m.add("fer_noir", box(V(sx * (w / 2 + 0.01), 0, 0.3), 0.02, 0.05, 0.05))
        m.add("fer_noir", tore(0.055, 0.009, 8, 4, c=V(sx * (w / 2 + 0.03), 0, 0.27), M=Ry(math.pi / 2) @ Rz(0.0)))
    return m


# ---------------------------------------------------------------------------- tonneau
def tonneau(var):
    """Tonneau h 0,9, rayon 0,34 au ventre, 0,286 aux fonds ; douelles en saillie alternée, jable, 4 cercles de fer."""
    m = Module(f"tonneau_{var}", 1800 + ord(var), hs=0.9)
    h, r = 0.9, 0.34
    n = 13
    ventre = lambda t: r * (0.84 + 0.16 * (1.0 - (2 * t - 1) ** 2))
    ts = [0.0, 0.18, 0.38, 0.62, 0.82, 1.0]
    rot = m.rg.uniform(0, 1)
    for k in range(n):
        a0 = rot + TAU * k / n
        a1 = rot + TAU * (k + 1) / n
        dr = (0.006 if k % 2 else -0.002) + m.j(0.003)
        top = h + 0.0 + m.j(0.008)
        anneaux = []
        for t in ts:
            rr = ventre(t) + dr
            z = t * top
            anneaux.append([V(math.cos(a0) * rr, math.sin(a0) * rr, z), V(math.cos(a1) * rr, math.sin(a1) * rr, z)])
        faces = []
        for i in range(len(ts) - 1):
            (p0, p1), (q0, q1) = anneaux[i], anneaux[i + 1]
            faces.append([p0, p1, q1, q0])
        # chant supérieur de la douelle (épaisseur 2,2 cm) et paroi intérieure du jable
        (p0, p1) = anneaux[-1]
        ri = 0.93
        faces.append([p0, p0 * ri + V(0, 0, p0.z * (1 - ri)), p1 * ri + V(0, 0, p1.z * (1 - ri)), p1])
        i0 = V(p0.x * ri, p0.y * ri, top)
        i1 = V(p1.x * ri, p1.y * ri, top)
        faces.append([i1, i0, V(i0.x, i0.y, h - 0.05), V(i1.x, i1.y, h - 0.05)])
        m.add("bois_v", faces, ao=m.rg.uniform(0.8, 1.0))
    # fond (planches du dessus, en retrait de 5 cm) + bonde
    rf = ventre(1.0) * 0.93
    for i, (y0, y1) in enumerate(((-1.0, -0.36), (-0.34, 0.34), (0.36, 1.0))):
        pts = []
        for k in range(17):
            a = TAU * k / 16
            px, py = math.cos(a) * rf, math.sin(a) * rf
            if y0 * rf <= py <= y1 * rf:
                pts.append(V(px, py, h - 0.05 + 0.003 * (i % 2)))
        if len(pts) >= 3:
            pts.sort(key=lambda p: math.atan2(p.y - (y0 + y1) / 2 * rf, p.x))
            m.add("bois", [pts if newell(pts).z > 0 else list(reversed(pts))], ao=0.75)
    m.add("bois", tour([(0.0, h - 0.05), (rf, h - 0.05)], 12), ao=0.6)
    m.add("bois_sombre", cyl(V(0.12, 0.05, h - 0.05), V(0.12, 0.05, h - 0.03), 0.03, 6), ao=0.7)
    # cercles de fer
    for t in (0.07, 0.24, 0.76, 0.93):
        rr = ventre(t) + 0.008
        m.add("fer", anneau(rr - 0.012, rr, t * h - 0.022, t * h + 0.022, n, rot=rot, quoi=("ext", "haut", "bas")))
    if var == "b":   # bonde latérale et cannelle
        m.add("bois_sombre", cyl(V(0, -r, 0.45), V(0, -r - 0.05, 0.45), 0.035, 6))
        m.add("fer_noir", cyl(V(0, -r - 0.05, 0.45), V(0, -r - 0.09, 0.42), 0.012, 5))
    elif var == "c":   # couvercle de planches avec poignée, louche posée
        m.add("bois", tour([(0.0, h + 0.005), (rf * 1.02, h + 0.005), (rf * 1.02, h + 0.03), (0.0, h + 0.03)], 12), ao=0.9)
        m.add("bois_sombre", poutre_ch(V(-0.12, 0, h + 0.03), V(0.12, 0, h + 0.03), 0.04, 0.04, 0.006), ao=0.8)
        m.add("bois_clair", cyl(V(0.0, 0.1, h + 0.04), V(0.28, 0.2, h + 0.06), 0.012, 5))
        m.add("bois_clair", tour([(0.0, h + 0.03), (0.05, h + 0.035), (0.055, h + 0.07), (0.0, h + 0.07)], 7, c=V(-0.02, 0.06, 0.0)))
    return m


# ---------------------------------------------------------------------------- lit
def lit(var):
    """Lit 2,0 x 1,0 m (tête à -X) : montants, chevets de planches, longs pans, paillasse, couverture drapée (PEAU), coussin."""
    m = Module(f"lit_{var}", 1900 + ord(var), hs=0.6)
    L, W = 2.0, 1.0
    for sx, ht in ((-1, 0.98 if var == "b" else 0.82), (1, 0.6)):
        for sy in (-1, 1):
            p = V(sx * (L / 2 - 0.05), sy * (W / 2 - 0.0), 0)
            m.add("bois_v", prisme_ch(p, 0.1, 0.1, ht, 0.012))
            m.add("bois_sombre", tour([(0.06, ht), (0.065, ht + 0.02), (0.035, ht + 0.07), (0.0, ht + 0.08)], 6, c=p, rot=math.pi / 6))
        # chevet : planches horizontales entre les montants
        hc = (ht - 0.36) if sx < 0 else 0.22
        nb = 3 if sx < 0 else 2
        for i in range(nb):
            z0 = 0.34 + i * hc / nb
            m.add("bois", prisme_ch(V(sx * (L / 2 - 0.05), 0, z0), 0.04, W - 0.08, hc / nb - 0.01, 0.006), ao=0.9 + m.j(0.06))
    if var == "b":   # fronton sculpté du chevet : deux volutes et une rosace
        xh = -L / 2 + 0.05
        m.add("bois_sombre", prisme_ch(V(xh, 0, 0.96), 0.05, W - 0.1, 0.06, 0.01))
        for sy in (-1, 1):
            m.add("bois_sombre", tore(0.07, 0.022, 6, 5, c=V(xh, sy * 0.24, 1.06), M=Rx(math.pi / 2), a0=0.0, a1=math.pi * 1.3))
        m.add("bois_sombre", tour([(0.0, -0.02), (0.08, -0.02), (0.08, 0.02), (0.05, 0.035), (0.0, 0.04)], 8, c=V(xh - 0.03, 0, 1.08), M=Ry(-math.pi / 2)))
    for sy in (-1, 1):
        m.add("bois", poutre_ch(V(-L / 2 + 0.1, sy * (W / 2 + 0.01), 0.42), V(L / 2 - 0.1, sy * (W / 2 + 0.01), 0.42), 0.06, 0.17, 0.01))
    # sangles / lattes sous la paillasse
    for k in range(6):
        x = -L / 2 + 0.22 + k * (L - 0.44) / 5
        m.add("bois_sombre", box(V(x, 0, 0.34), 0.08, W - 0.02, 0.03), ao=0.6)
    # paillasse de foin bombée
    m.add("foin", prisme_ch(V(0, 0, 0.36), L - 0.2, W - 0.08, 0.15, 0.05, coin=0.08))
    # couverture drapée (PEAU) : couvre 70 % du lit depuis le pied, retombe de 16 cm sur les côtés, bord ondulé
    x0, x1 = -L / 2 + 0.55, L / 2 - 0.12
    def drap(u, v):
        x = x0 + (x1 - x0) * u
        a = math.pi * (v - 0.5)
        yy = (W / 2 + 0.03) * math.sin(a * 1.0) * 1.0
        bord = abs(v - 0.5) * 2
        z = 0.53 + 0.025 * math.cos(a) - 0.2 * smooth(0.72, 1.0, bord) + 0.015 * math.sin(u * 17 + v * 3)
        if bord > 0.72:
            yy = math.copysign(W / 2 + 0.03 + 0.02 * smooth(0.72, 1.0, bord), v - 0.5)
        return V(x, yy, z + 0.01 * noise.noise(V(u * 4, v * 4, 1.3)))
    f = grille(drap, 5, 8)
    m.add("PEAU", [q if newell(q).z > -0.2 or True else q for q in f], ao=1.0)
    m.add("PEAU", rev(f), ao=0.5)
    # coussin
    m.add("cuir", prisme_ch(V(-L / 2 + 0.33, 0, 0.5), 0.34, W - 0.32, 0.12, 0.04, coin=0.06, M=Ry(-0.12)))
    return m


def fourrure_froissee():
    m = Module("fourrure_froissee", 1950, hs=0.6)
    def f(u, v):
        x = (u - 0.5) * 0.75
        y = (v - 0.5) * 0.55
        z = 0.56 + 0.07 * math.sin(u * 7.0) * math.cos(v * 5.0) + 0.05 * (1 - abs(u - 0.5) * 2)
        return V(x, y, z)
    g = grille(f, 4, 3)
    m.add("PEAU", g)
    m.add("PEAU", rev(g), ao=0.5)
    return m


# ---------------------------------------------------------------------------- étagère
def etagere(var):
    """Étagère 1,5 x 0,3 x 2,0 à 4 tablettes (centres à 2,0 (i+0,8)/4,5), montants à pieds, fond de planches debout."""
    m = Module(f"etagere_{var}", 2000 + ord(var), hs=2.0)
    L, P, H = 1.5, 0.3, 2.0
    for sx in (-1, 1):
        x = sx * (L / 2 - 0.035)
        m.add("bois_v", prisme_ch(V(x, 0.0, 0.0), 0.06, P, H - 0.04, 0.008))
        # tête biseautée et pied avant
        m.add("bois_v", plaque([(-0.03, H - 0.04), (0.03, H - 0.04), (0.03, H + 0.03), (-0.03, H - 0.0)], P, M=Rz(0.0),
                               c=V(x, -P / 2, 0)) if False else prisme_ch(V(x, 0.02, H - 0.04), 0.06, P - 0.04, 0.05, 0.01))
        m.add("bois_sombre", prisme_ch(V(x, -0.01, 0), 0.08, P + 0.04, 0.05, 0.008), ao=0.8)
    for i in range(4):
        zc = H * (i + 0.8) / 4.5
        m.add("bois", prisme_ch(V(0, 0, zc - 0.0225), L - 0.02, P, 0.045, 0.008), ao=0.92)
        m.add("bois_sombre", poutre_ch(V(-L / 2 + 0.07, -P / 2 + 0.015, zc + 0.02), V(L / 2 - 0.07, -P / 2 + 0.015, zc + 0.02), 0.02, 0.03, 0.004), ao=0.85)
        if var == "b":   # consoles de fer sous les tablettes
            for sx in (-1, 1):
                m.add("fer_noir", beam(V(sx * (L / 2 - 0.08), P / 2 - 0.02, zc - 0.03), V(sx * (L / 2 - 0.08), P / 2 - 0.2, zc - 0.03), 0.015, 0.02))
                m.add("fer_noir", beam(V(sx * (L / 2 - 0.08), P / 2 - 0.02, zc - 0.17), V(sx * (L / 2 - 0.08), P / 2 - 0.18, zc - 0.035), 0.012, 0.015, up=X))
    nb = 5
    wp = (L - 0.14) / nb
    for k in range(nb):
        x = -L / 2 + 0.07 + wp * (k + 0.5)
        m.add("bois_sombre", box(V(x, P / 2 - 0.01, 0.05), wp - 0.008, 0.02, H - 0.12), ao=0.55 + m.j(0.08))
    if var == "a":   # traverse haute
        m.add("bois_sombre", poutre_ch(V(-L / 2 + 0.06, -P / 2 + 0.03, H - 0.08), V(L / 2 - 0.06, -P / 2 + 0.03, H - 0.08), 0.05, 0.06, 0.008))
    return m


# ---------------------------------------------------------------------------- vaisselle
def chope(var):
    m = Module(f"chope_{var}", 2100 + ord(var), hs=0.14)
    if var == "a":   # chope à douelles cerclée
        m.add("MAT", tour([(0.0, 0.0), (0.046, 0.0), (0.05, 0.005), (0.043, 0.14), (0.036, 0.14), (0.04, 0.02), (0.0, 0.02)], 9, rot=0.3))
        for z in (0.03, 0.11):
            m.add("fer", anneau(0.045, 0.05 - (z - 0.03) * 0.06, z - 0.006, z + 0.006, 9, quoi=("ext",)))
    else:            # gobelet tourné à pied
        m.add("MAT", tour([(0.0, 0.0), (0.04, 0.0), (0.04, 0.012), (0.022, 0.03), (0.042, 0.075), (0.05, 0.14), (0.043, 0.14), (0.034, 0.08), (0.0, 0.04)], 9))
    m.add("noir", tour([(0.0, 0.11), (0.038, 0.11)], 9), plat=True, ao=0.5)
    m.add("MAT", tore(0.04, 0.009, 5, 4, c=V(0.055, 0, 0.075), M=Rx(math.pi / 2), a0=-math.pi / 2, a1=math.pi / 2))
    return m


def assiette():
    m = Module("assiette", 2200, hs=0.03)
    m.add("MAT", tour([(0.0, 0.0), (0.075, 0.0), (0.08, 0.008), (0.11, 0.022), (0.105, 0.026), (0.076, 0.012), (0.0, 0.01)], 10))
    return m


def cruche(var):
    """Cruche h 0,3 (le jeu la met à l'échelle) : panse tournée, col, bec, anse."""
    m = Module(f"cruche_{var}", 2300 + ord(var), hs=0.3)
    mat = "argile" if var == "a" else "bois_sombre"
    if var == "a":
        prof = [(0.0, 0.0), (0.07, 0.0), (0.105, 0.04), (0.125, 0.12), (0.11, 0.19), (0.06, 0.24), (0.05, 0.27), (0.062, 0.3),
                (0.05, 0.3), (0.04, 0.26), (0.0, 0.25)]
    else:
        prof = [(0.0, 0.0), (0.1, 0.0), (0.112, 0.06), (0.112, 0.17), (0.09, 0.24), (0.07, 0.28), (0.075, 0.3), (0.062, 0.3), (0.05, 0.27), (0.0, 0.26)]
    m.add(mat, tour(prof, 10, rot=0.1))
    m.add("noir", tour([(0.0, 0.285), (0.052, 0.285)], 8), plat=True, ao=0.45)
    # bec pincé
    m.add(mat, [[V(-0.05, -0.03, 0.29), V(-0.05, 0.03, 0.29), V(-0.085, 0.0, 0.31)]], ao=0.9)
    m.add(mat, [[V(-0.05, 0.03, 0.28), V(-0.05, -0.03, 0.28), V(-0.085, 0.0, 0.305)]], ao=0.7)
    m.add(mat, tore(0.075, 0.013, 6, 4, c=V(0.1, 0, 0.18), M=Rx(math.pi / 2), a0=-math.pi * 0.55, a1=math.pi * 0.6))
    if var == "b":
        for z in (0.04, 0.15):
            m.add("fer", anneau(0.11, 0.118, z - 0.008, z + 0.008, 10, quoi=("ext", "haut")))
    return m


def bol():
    m = Module("bol", 2400, hs=0.08)
    m.add("argile", tour([(0.0, 0.0), (0.05, 0.0), (0.055, 0.01), (0.088, 0.05), (0.092, 0.08), (0.082, 0.08), (0.076, 0.052), (0.045, 0.02), (0.0, 0.018)], 10))
    m.add("foin", tour([(0.0, 0.055), (0.079, 0.055)], 10), ao=0.8)   # bouillie / grain
    return m


def chaudron():
    """Marmite de fer r 0,3 : panse, lèvre, trois pieds, anse, ragoût sombre."""
    m = Module("chaudron", 2500, hs=0.5)
    r = 0.3
    prof = [(0.0, 0.03), (0.16, 0.035), (0.26, 0.09), (0.3, 0.2), (0.29, 0.29), (0.255, 0.33), (0.275, 0.35), (0.272, 0.37),
            (0.245, 0.37), (0.235, 0.33), (0.0, 0.3)]
    m.add("fer_noir", tour(prof, 12))
    m.add("noir", tour([(0.0, 0.3), (0.24, 0.3)], 12), plat=True, ao=0.35)
    for k in range(3):
        a = TAU * k / 3 + 0.4
        d = V(math.cos(a), math.sin(a), 0)
        m.add("fer_noir", cyl(d * 0.17 + V(0, 0, 0.06), d * 0.2, 0.025, 5, r2=0.018))
    for sx in (-1, 1):
        m.add("fer", tore(0.025, 0.008, 5, 4, c=V(sx * 0.285, 0, 0.35), M=Rx(math.pi / 2)))
    m.add("fer", tore(0.29, 0.009, 9, 4, c=V(0, 0, 0.36), M=Rx(math.pi / 2), a0=0.15, a1=math.pi - 0.15))
    return m


def livre():
    m = Module("livre", 2600, hs=0.05)
    m.add("cuir", prisme_ch(V(0, 0, 0.0), 0.2, 0.28, 0.008, 0.002))
    m.add("cuir", prisme_ch(V(0, 0, 0.044), 0.2, 0.28, 0.008, 0.002))
    m.add("parchemin", box(V(0.005, 0, 0.008), 0.18, 0.265, 0.036), ao=0.95)
    m.add("cuir", tour([(0.026, 0.0), (0.026, 0.28)], 6, c=V(-0.1, -0.14, 0.026), M=Rx(-math.pi / 2), a0=math.pi / 2, a1=math.pi * 1.5))
    m.add("etain", box(V(0.1, 0.0, 0.015), 0.012, 0.04, 0.03))
    for sy in (-1, 1):
        m.add("etain", box(V(0.09, sy * 0.13, 0.05), 0.025, 0.025, 0.004))
    return m


def parchemin():
    m = Module("parchemin", 2700, hs=0.06)
    m.add("parchemin", cyl(V(-0.13, 0, 0.026), V(0.13, 0, 0.026), 0.024, 7))
    m.add("parchemin", box(V(0.0, -0.06, 0.0), 0.24, 0.07, 0.003), ao=0.9)   # feuille déroulée
    m.add("cuir", anneau(0.024, 0.028, -0.008, 0.008, 7, c=V(0.03, 0, 0.026), M=Ry(math.pi / 2), quoi=("ext",)))
    return m


def sac(var):
    """Sac de jute 0,42 x 0,3 x 0,5 : panse ovale tassée, col noué (corde de cuir), houppe."""
    m = Module(f"sac_{var}", 2800 + ord(var), hs=0.5)
    h = 0.5
    tass = {"a": 1.0, "b": 0.85, "c": 1.1}[var]
    prof = [(0.0, 0.0), (0.17, 0.0), (0.21, 0.06), (0.215, 0.2 * tass), (0.19, 0.32 * tass), (0.12, 0.41 * tass), (0.055, 0.45 * tass),
            (0.045, 0.47 * tass), (0.0, 0.47 * tass)]
    m.add("jute", tour(prof, 9, ech=(1.0, 0.72), jit=0.012, rg=m.rg, rot=m.rg.uniform(0, 1)))
    zc = 0.46 * tass
    m.add("cuir", anneau(0.045, 0.052, zc - 0.012, zc + 0.012, 7, quoi=("ext", "haut", "bas")))
    m.add("jute", tour([(0.045, zc + 0.01), (0.07, zc + 0.06), (0.04, zc + 0.09), (0.0, zc + 0.08)], 7, jit=0.01, rg=m.rg), ao=0.9)
    # pli vertical (couture)
    m.add("jute", box(V(0.0, -0.152, 0.05), 0.02, 0.01, 0.3 * tass), ao=0.7)
    return m


# ---------------------------------------------------------------------------- crâne
def crane():
    """Crâne humain (≈ 13 x 15 x 12 cm, origine à la base de la mâchoire, face vers l'avant -Y)."""
    m = Module("crane", 2900, hs=0.15)
    prof = [(0.0, 0.03), (0.045, 0.032), (0.062, 0.06), (0.066, 0.1), (0.056, 0.135), (0.032, 0.155), (0.0, 0.16)]
    m.add("os", tour(prof, 9, c=V(0, 0.012, 0), ech=(1.0, 1.18)))
    # face : pommettes, maxillaire, mâchoire
    m.add("os", prisme_ch(V(0, -0.055, 0.035), 0.1, 0.05, 0.05, 0.012), ao=0.95)
    m.add("os", prisme_ch(V(0, -0.045, 0.0), 0.08, 0.055, 0.03, 0.01), ao=0.85)
    m.add("os", box(V(0, -0.072, 0.028), 0.06, 0.012, 0.012), ao=0.9)   # dents
    for sx in (-1, 1):
        e0 = V(sx * 0.024, -0.0815, 0.068)
        m.add("noir", [[e0 + V(-0.015, 0, -0.012), e0 + V(0.015, 0, -0.012), e0 + V(0.013, 0, 0.012), e0 + V(-0.013, 0, 0.012)]], plat=True, ao=0.25)
    m.add("noir", [[V(-0.008, -0.081, 0.048), V(0.008, -0.081, 0.048), V(0.0, -0.081, 0.064)]], plat=True, ao=0.2)
    return m


# ---------------------------------------------------------------------------- bouclier
def bouclier(var):
    """Bouclier rond r 0,36 dans le plan XZ, face vers l'avant (-Y), dos contre le mur (y = 0) ; épaisseur 6-12 cm."""
    m = Module(f"bouclier_{var}", 3000 + ord(var), hs=1.0)
    r = 0.36
    n = 16
    nb = 5
    for i in range(nb):
        x0 = -r + 2 * r * i / nb + 0.003
        x1 = -r + 2 * r * (i + 1) / nb - 0.003
        pts = []
        for k in range(n + 1):
            a = TAU * k / n
            px, pz = math.cos(a) * r, math.sin(a) * r
            pts.append((px, pz))
        # contour de la planche = disque ∩ bande [x0, x1]
        poly = []
        for k in range(n):
            (ax, az), (bx_, bz) = pts[k], pts[k + 1]
            for (px, pz) in ((ax, az),):
                if x0 <= px <= x1:
                    poly.append((px, pz))
            for xc in (x0, x1):
                if (ax - xc) * (bx_ - xc) < 0:
                    t = (xc - ax) / (bx_ - ax)
                    poly.append((xc, az + (bz - az) * t))
        cx = (x0 + x1) / 2
        poly.sort(key=lambda p: math.atan2(p[1], p[0] - cx))
        ep = 0.022 + m.j(0.003)
        m.add("BOUCLIER", plaque(poly, ep, c=V(0, -0.055 - ep + 0.022, 0)), ao=0.85 + m.j(0.1))
    # bordure (cuir ou fer), umbo et sa platine, rivets
    bord = "fer" if var == "a" else "cuir"
    m.add(bord, anneau(r - 0.02, r + 0.012, 0.03, 0.065, n, M=Rx(math.pi / 2), quoi=("ext", "int", "haut", "bas")))
    m.add("fer", tour([(0.11, 0.0), (0.11, 0.008), (0.085, 0.012), (0.08, 0.04), (0.06, 0.07), (0.03, 0.085), (0.0, 0.088)], 10,
                      c=V(0, -0.06, 0), M=Rx(math.pi / 2)))
    for k in range(8):
        a = TAU * k / 8 + 0.2
        m.add("fer_noir", cyl(V(math.cos(a) * (r - 0.04), -0.07, math.sin(a) * (r - 0.04)), V(math.cos(a) * (r - 0.04), -0.078, math.sin(a) * (r - 0.04)), 0.011, 5))
    if var == "b":   # deux renforts de fer en croix
        for a in (0.0, math.pi / 2):
            d = V(math.cos(a), 0, math.sin(a))
            m.add("fer", poutre_ch(-d * (r - 0.03) + V(0, -0.064, 0), d * (r - 0.03) + V(0, -0.064, 0), 0.04, 0.008, 0.0, up=Y))
    # anse au dos (tenue au mur)
    m.add("bois_sombre", box(V(0, -0.025, -0.25), 0.05, 0.03, 0.5), ao=0.5)
    return m


# ---------------------------------------------------------------------------- armes
def hache():
    """Hache de 0,82 m (centre du manche à l'origine, manche selon Z), fer barbu vers l'avant (-Y)."""
    m = Module("hache", 3100, hs=0.4)
    m.add("bois", cyl(V(0, 0, -0.41), V(0, 0, 0.41), 0.021, 6, r2=0.017))
    m.add("cuir", cyl(V(0, 0, -0.41), V(0, 0, -0.26), 0.025, 6))
    # fer barbu : profil extrudé (épaisseur 1,6 cm), douille
    prof = [(-0.025, 0.24), (-0.03, 0.36), (-0.06, 0.37), (-0.17, 0.42), (-0.19, 0.33), (-0.17, 0.22), (-0.07, 0.26)]
    pts = [(z, -y) for (y, z) in prof]
    M = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))   # plaque XZ -> plan YZ
    faces = [[V(-0.008, y, z) for (y, z) in prof], [V(0.008, y, z) for (y, z) in reversed(prof)]]
    for k in range(len(prof)):
        (y0, z0), (y1, z1) = prof[k], prof[(k + 1) % len(prof)]
        faces.append([V(-0.008, y0, z0), V(0.008, y0, z0), V(0.008, y1, z1), V(-0.008, y1, z1)])
    m.add("fer", dehors(faces))
    m.add("fer", [[V(-0.003, -0.19, 0.33), V(0.003, -0.19, 0.33), V(0.003, -0.17, 0.42), V(-0.003, -0.17, 0.42)]], ao=1.0)
    m.add("fer_noir", prisme_ch(V(0, 0.0, 0.25), 0.05, 0.06, 0.12, 0.008))
    return m


def epee():
    """Épée de 0,85 m de lame (centre de la lame à l'origine, lame selon Z), fil vers ±X, plat vers l'avant (-Y)."""
    m = Module("epee", 3200, hs=0.4)
    zb, zt = -0.4, 0.43
    w, e = 0.024, 0.006
    sec = lambda z, s: [V(s * w, 0, z), V(0, -e, z), V(-s * w, 0, z), V(0, e, z)]
    a = [V(w, 0, zb), V(0, -e, zb), V(-w, 0, zb), V(0, e, zb)]
    b = [V(w * 0.8, 0, zt - 0.07), V(0, -e, zt - 0.07), V(-w * 0.8, 0, zt - 0.07), V(0, e, zt - 0.07)]
    pt = V(0, 0, zt)
    faces = []
    for k in range(4):
        k1 = (k + 1) % 4
        faces.append([a[k], a[k1], b[k1], b[k]])
        faces.append([b[k], b[k1], pt])
    m.add("etain", dehors(faces + [list(reversed(a))]))
    m.add("fer_noir", prisme_ch(V(0, 0, zb - 0.03), 0.2, 0.035, 0.03, 0.006))
    m.add("cuir", cyl(V(0, 0, zb - 0.03), V(0, 0, zb - 0.15), 0.017, 6))
    m.add("fer_noir", tour([(0.0, 0.0), (0.025, 0.005), (0.03, 0.025), (0.0, 0.04)], 6, c=V(0, 0, zb - 0.19)))
    return m


def lance_hampe():
    """Hampe de lance de 1,0 m centrée (le jeu l'étire en Z à la longueur voulue)."""
    m = Module("lance_hampe", 3300, hs=1.0)
    m.add("bois", cyl(V(0, 0, -0.5), V(0, 0, 0.5), 0.018, 6))
    return m


def lance_fer():
    """Fer de lance (douille + feuille de saule), origine au bas de la douille."""
    m = Module("lance_fer", 3310, hs=0.3)
    m.add("fer_noir", cyl(V(0, 0, -0.03), V(0, 0, 0.06), 0.022, 6, r2=0.016))
    a = [V(0.035, 0, 0.1), V(0, -0.006, 0.1), V(-0.035, 0, 0.1), V(0, 0.006, 0.1)]
    m.add("etain", dehors([[V(0, 0, 0.06), a[k], a[(k + 1) % 4]] for k in range(4)] + [[a[k], a[(k + 1) % 4], V(0, 0, 0.3)] for k in range(4)]))
    return m


# ---------------------------------------------------------------------------- halle : trône et estrade
def trone_halle():
    """Haut-siège de la cheffe (origine : dessus de l'estrade, centre du siège en x = 0, y = 0 ; dos vers +Y = mur).
    Emprise ≈ 1,08 x 0,66 m, hauteur 2,0 m (le plafond de la halle descend à ~2,1 m au-dessus de l'estrade contre le mur). Bois clair sculpté, poteaux à têtes de dragon, fourrure drapée."""
    m = Module("trone_halle", 3400, hs=2.3)
    rg = m.rg
    # assise : caisse à panneaux, ceinture moulurée, galette de bois
    m.add("bois_sombre", prisme_ch(V(0, 0.0, 0.0), 0.74, 0.6, 0.06, 0.01), ao=0.7)
    m.add("bois_v", box(V(0, 0.01, 0.06), 0.68, 0.54, 0.34), ao=0.85)
    for sx in (-1, 1):   # panneaux sculptés de la façade (losanges en saillie)
        m.add("bois_clair", prisme_ch(V(sx * 0.17, -0.275, 0.1), 0.28, 0.02, 0.26, 0.012))
        for k in range(3):
            c = V(sx * 0.17, -0.29, 0.14 + k * 0.08)
            m.add("bois_sombre", [[c + V(-0.05, 0, 0.03), c + V(0.0, -0.008, 0.0), c + V(0.05, 0, 0.03), c + V(0.0, 0.0, 0.06)][::-1]], ao=0.8)
            m.add("bois_sombre", plaque([(-0.04, 0.0), (0.0, -0.03), (0.04, 0.0), (0.0, 0.03)], 0.012, c=c + V(0, -0.006, 0.03)), ao=0.85)
    m.add("bois_clair", prisme_ch(V(0, -0.02, 0.4), 0.8, 0.66, 0.05, 0.015))
    m.add("bois_clair", prisme_ch(V(0, -0.02, 0.45), 0.76, 0.62, 0.035, 0.012))
    # côtés pleins jusqu'aux accoudoirs, accoudoirs à volute
    for sx in (-1, 1):
        x = sx * 0.4
        m.add("bois_clair", prisme_ch(V(x, 0.0, 0.06), 0.07, 0.56, 0.6, 0.01))
        m.add("bois_clair", poutre_ch(V(x, 0.26, 0.7), V(x, -0.3, 0.7), 0.11, 0.07, 0.012))
        m.add("bois_sombre", tore(0.05, 0.025, 7, 5, c=V(x, -0.3, 0.65), M=Rz(math.pi / 2) @ Rx(math.pi / 2), a0=-math.pi / 2, a1=math.pi * 0.9))
        m.add("bois_clair", poutre_ch(V(x, -0.26, 0.06), V(x, -0.28, 0.66), 0.08, 0.08, 0.01, up=Y))
        # entrelacs du flanc : deux bandes croisées
        for s in (-1, 1):
            m.add("bois_sombre", poutre_ch(V(x + sx * 0.04, -0.22, 0.12 if s > 0 else 0.56), V(x + sx * 0.04, 0.22, 0.56 if s > 0 else 0.12), 0.012, 0.03, 0.004, up=X), ao=0.8)
    # poteaux octogonaux à bagues, têtes de dragon
    for sx in (-1, 1):
        p = V(sx * 0.46, 0.22, 0.0)
        m.add("bois_clair", tour([(0.1, 0.0), (0.1, 0.1), (0.075, 0.13), (0.07, 1.55), (0.09, 1.58), (0.09, 1.64), (0.07, 1.67)], 8, c=p, rot=math.pi / 8))
        for zc in (0.5, 1.0, 1.35):
            m.add("bois_sombre", anneau(0.07, 0.085, zc - 0.025, zc + 0.025, 8, c=p, rot=math.pi / 8, quoi=("ext", "haut", "bas")))
        # tête : cou incliné vers l'avant, crâne, mâchoires ouvertes, crête, yeux
        cou0 = p + V(0, 0, 1.65)
        cou1 = p + V(0, -0.12, 1.85)
        m.add("bois_clair", poutre_ch(cou0, cou1, 0.11, 0.11, 0.02, up=X))
        tete = cou1 + V(0, -0.02, 0.0)
        m.add("bois_clair", prisme_ch(tete + V(0, -0.03, -0.06), 0.13, 0.16, 0.13, 0.025))
        m.add("bois_clair", poutre_ch(tete + V(0, -0.1, 0.02), tete + V(0, -0.3, 0.0), 0.09, 0.06, 0.012, up=X))     # mâchoire haute
        m.add("bois_clair", poutre_ch(tete + V(0, -0.1, -0.04), tete + V(0, -0.26, -0.11), 0.07, 0.04, 0.01, up=X))   # mâchoire basse
        m.add("bois_sombre", box(V(tete.x, tete.y - 0.27, tete.z - 0.045), 0.08, 0.02, 0.05), ao=0.4)
        for sz in (-1, 1):
            m.add("noir", box(tete + V(sz * 0.066, -0.1, 0.03), 0.006, 0.03, 0.02), plat=True, ao=0.25)   # yeux
        for k in range(3):   # crête de cornes recourbées vers l'arrière
            b0 = tete + V(0, 0.02 + k * 0.05, 0.06)
            m.add("bois_sombre", cyl(b0, b0 + V(0, 0.08 + k * 0.02, 0.1 - k * 0.02), 0.022 - k * 0.004, 5, r2=0.004))
        m.add("bois_clair", tore(0.06, 0.018, 6, 4, c=tete + V(0, 0.08, -0.05), M=Rz(math.pi / 2) @ Rx(math.pi / 2), a0=0.3, a1=math.pi * 1.4))
    # dossier : planches debout, traverses, fronton cintré, roue solaire
    nb = 5
    for k in range(nb):
        x = -0.34 + 0.68 * (k + 0.5) / nb
        hk = 1.5 + 0.06 * math.cos((k - 2) / 2.0 * math.pi / 2)
        m.add("bois_clair", prisme_ch(V(x, 0.26, 0.45), 0.68 / nb - 0.008, 0.06, hk - 0.45, 0.008), ao=0.85 + m.j(0.08))
    for zc in (0.78, 1.5):
        m.add("bois_sombre", poutre_ch(V(-0.4, 0.22, zc), V(0.4, 0.22, zc), 0.07, 0.06, 0.01))
    # fronton : arc de 7 segments au-dessus des planches
    arcp = [(-0.4 + 0.8 * k / 7, 1.56 + 0.1 * math.sin(math.pi * k / 7)) for k in range(8)]
    for k in range(7):
        (x0, z0), (x1, z1) = arcp[k], arcp[k + 1]
        m.add("bois_sombre", poutre_ch(V(x0, 0.24, z0), V(x1, 0.24, z1), 0.09, 0.07, 0.01, up=-Y))
    roue = V(0, 0.22, 1.16)
    m.add("bois_sombre", tour([(0.0, 0.0), (0.2, 0.0), (0.2, 0.025), (0.17, 0.035), (0.0, 0.035)], 14, c=roue, M=Rx(math.pi / 2)))
    m.add("etain", anneau(0.15, 0.175, 0.03, 0.045, 14, c=roue, M=Rx(math.pi / 2), quoi=("ext", "int", "haut")))
    for k in range(4):   # quatre rayons en svastika solaire nordique (« sól ») : bras coudés
        a = TAU * k / 4 + 0.3
        d = V(math.cos(a), 0, math.sin(a))
        e = V(-math.sin(a), 0, math.cos(a))
        m.add("bois_clair", poutre_ch(roue + V(0, -0.04, 0), roue + d * 0.13 + V(0, -0.04, 0), 0.03, 0.02, 0.004, up=Y))
        m.add("bois_clair", poutre_ch(roue + d * 0.13 + V(0, -0.04, 0), roue + d * 0.13 + e * 0.06 + V(0, -0.04, 0), 0.03, 0.02, 0.004, up=Y))
    m.add("etain", tour([(0.0, 0.0), (0.035, 0.0), (0.03, 0.025), (0.0, 0.035)], 6, c=roue + V(0, -0.04, 0), M=Rx(math.pi / 2)))
    # clous de fer sur la ceinture du siège
    for k in range(7):
        x = -0.33 + k * 0.11
        m.add("fer_noir", cyl(V(x, -0.351, 0.425), V(x, -0.36, 0.425), 0.012, 5))
    # fourrure claire : jetée sur l'assise et sur le haut du dossier, retombe devant
    def assise(u, v):
        x = (u - 0.5) * 0.66
        y = -0.32 + 0.6 * v
        z = 0.49 + 0.02 * math.sin(u * 9) * (1 - v) - 0.25 * smooth(0.0, 0.12, -y - 0.22) if y < -0.22 else 0.49 + 0.015 * math.sin(u * 9 + v * 4)
        yy = y if y > -0.3 else -0.3 - 0.02 * math.sin(u * 7)
        return V(x, yy, z)
    def assise2(u, v):
        x = (u - 0.5) * (0.62 + 0.06 * v)
        s = v * 0.62
        if s < 0.48:
            p = V(x, 0.24 - s, 0.492 + 0.012 * math.sin(u * 11 + v * 5))
        else:
            k = (s - 0.48) / 0.14
            p = V(x, -0.24 - 0.04 * k, 0.49 - 0.24 * k + 0.02 * math.sin(u * 13))
        return p
    f = grille(assise2, 5, 6)
    m.add("peau_claire", f)
    m.add("peau_claire", rev(f), ao=0.5)
    def dos(u, v):
        x = (u - 0.5) * 0.5
        s = v
        if s < 0.6:
            p = V(x, 0.215 - 0.01 * math.sin(u * 8), 1.36 + 0.2 * (s / 0.6) + 0.015 * math.sin(u * 10))
        else:
            k = (s - 0.6) / 0.4
            p = V(x, 0.215 + 0.1 * k, 1.58 + 0.03 * math.sin(k * math.pi))
        return p
    f = grille(dos, 5, 5)
    m.add("peau_claire", f)
    m.add("peau_claire", rev(f), ao=0.5)
    return m


def estrade_halle():
    """Estrade de la halle (repère : origine au sol au centre de la grande marche ; avant -Y = vers la salle).
    Grande marche 3,1 x 1,3 x 0,22 (dessus à 0,225), marche basse 3,1 x 0,34 x 0,1 devant (centre à y = -0,8)."""
    m = Module("estrade_halle", 3500, hs=0.25)
    L, P, H = 3.1, 1.3, 0.22
    # contremarches de planches debout sur la face avant et les côtés
    nb = 14
    for k in range(nb):
        x = -L / 2 + L * (k + 0.5) / nb
        m.add("bois_v", prisme_ch(V(x + m.j(0.004), -P / 2 + 0.012, 0.0), L / nb - 0.008, 0.024, H - 0.005, 0.005), ao=0.75 + m.j(0.1))
    for sx in (-1, 1):
        for k in range(5):
            y = -P / 2 + P * (k + 0.5) / 5
            m.add("bois_v", prisme_ch(V(sx * (L / 2 - 0.012), y, 0.0), 0.024, P / 5 - 0.008, H - 0.005, 0.005), ao=0.75 + m.j(0.1))
    m.add("bois_sombre", box(V(0, 0.02, 0.0), L - 0.06, P - 0.04, H - 0.01), ao=0.5)
    # plancher du dessus : 7 planches le long de X, nez de marche arrondi, clous
    nbp = 7
    for k in range(nbp):
        y = -P / 2 + 0.06 + (P - 0.06) * (k + 0.5) / nbp
        m.add("bois_clair", prisme_ch(V(m.j(0.01), y, H - 0.02), L - 0.02 - m.rg.uniform(0, 0.02), (P - 0.06) / nbp - 0.006, 0.025 + m.j(0.002), 0.006),
              ao=0.88 + m.j(0.08))
        for xc in (-1.4, -0.47, 0.47, 1.4):
            m.add("fer_noir", cyl(V(xc, y, H + 0.004), V(xc, y, H + 0.008), 0.01, 4), plat=True, ao=0.4)
    m.add("bois", poutre_ch(V(-L / 2, -P / 2 + 0.03, H - 0.02), V(L / 2, -P / 2 + 0.03, H - 0.02), 0.08, 0.05, 0.015))
    # marche basse
    yb = -0.8
    m.add("bois_sombre", box(V(0, yb, 0.0), L - 0.04, 0.32, 0.08), ao=0.6)
    for k in range(2):
        m.add("bois", prisme_ch(V(m.j(0.01), yb - 0.08 + k * 0.165, 0.075), L - 0.01, 0.16, 0.025, 0.006), ao=0.9 + m.j(0.06))
    # poteaux d'angle courts (bornes sculptées) aux coins avant de la grande marche
    for sx in (-1, 1):
        c = V(sx * (L / 2 - 0.06), -P / 2 + 0.06, 0)
        m.add("bois_sombre", tour([(0.075, 0.0), (0.075, 0.26), (0.085, 0.28), (0.06, 0.33), (0.0, 0.36)], 8, c=c, rot=math.pi / 8))
    return m


# ---------------------------------------------------------------------------- forge
def enclume():
    """Billot (r 0,25-0,28, h 0,6) cerclé de fer + enclume à bigorne vers l'avant (-Y Blender = +Z Godot), table à 1,0 m."""
    m = Module("enclume", 3600, hs=1.0)
    rg = m.rg
    m.add("rondin_sombre", tour([(0.29, 0.0), (0.28, 0.08), (0.26, 0.3), (0.25, 0.6), (0.0, 0.6)], 11, jit=0.012, rg=rg, caps=(False, False)))
    m.add("bout", tour([(0.0, 0.6), (0.25, 0.6)], 11), ao=0.8)
    m.add("fer_noir", anneau(0.282, 0.3, 0.1, 0.14, 11, quoi=("ext", "haut", "bas")))
    m.add("fer_noir", anneau(0.256, 0.272, 0.48, 0.52, 11, quoi=("ext", "haut", "bas")))
    z = 0.6
    # pied évasé, taille, corps
    m.add("fer", prisme_ch(V(0, 0, z), 0.36, 0.5, 0.06, 0.012))
    m.add("fer", plaque([(-0.18, 0.0), (0.18, 0.0), (0.1, 0.1), (-0.1, 0.1)], 0.42, c=V(0, -0.21, z + 0.06)))
    m.add("fer", prisme_ch(V(0, 0, z + 0.16), 0.2, 0.36, 0.1, 0.01))
    m.add("fer", plaque([(-0.1, 0.0), (0.1, 0.0), (0.17, 0.08), (-0.17, 0.08)], 0.5, c=V(0, -0.25, z + 0.26)))
    m.add("fer_noir", prisme_ch(V(0, 0.02, z + 0.34), 0.36, 0.6, 0.06, 0.008))
    m.add("etain", box(V(0, 0.03, z + 0.4), 0.33, 0.55, 0.004), ao=1.0)   # table polie
    m.add("noir", box(V(0.0, 0.25, z + 0.401), 0.03, 0.03, 0.003), plat=True, ao=0.2)   # trou de tranche
    # bigorne : cône aplati vers l'avant
    b0 = V(0, -0.28, z + 0.36)
    m.add("fer", tour([(0.075, 0.0), (0.06, 0.08), (0.04, 0.17), (0.012, 0.26), (0.0, 0.28)], 8, c=b0, M=Rx(math.pi / 2), ech=(1.0, 0.75)))
    # talon à l'arrière
    m.add("fer", plaque([(-0.12, 0.0), (0.12, 0.0), (0.12, 0.06), (-0.12, 0.06)], 0.12, c=V(0, 0.32, z + 0.34)))
    # barre chauffée et marteau posé sur le billot
    m.add("braises", box(V(0.02, 0.02, z + 0.405), 0.045, 0.5, 0.03, rz=0.2), plat=True, ao=1.0)
    m.add("bois", cyl(V(0.22, -0.05, 0.62), V(0.38, -0.35, 0.62), 0.016, 6))
    m.add("fer_noir", prisme_ch(V(0.2, -0.03, 0.6), 0.1, 0.06, 0.05, 0.006, rz=-1.1))
    return m


def soufflet():
    """Soufflet de forge sur tréteau (0,75 x 0,4) : planches en poire, flancs de cuir plissé, buse vers -X, manche vers +X."""
    m = Module("soufflet", 3700, hs=1.0)
    m.add("bois_v", prisme_ch(V(-0.25, 0, 0), 0.08, 0.12, 0.62, 0.01))
    m.add("bois_v", prisme_ch(V(0.25, 0, 0), 0.08, 0.12, 0.62, 0.01))
    m.add("bois_v", poutre_ch(V(-0.3, 0, 0.6), V(0.3, 0, 0.6), 0.1, 0.12, 0.01))
    m.add("bois_sombre", poutre_ch(V(-0.25, 0, 0.18), V(0.25, 0, 0.18), 0.05, 0.05, 0.008))
    poire = [(-0.38, 0.0)] + [(0.1 + math.cos(a) * 0.27 * 0.95, math.sin(a) * 0.2) for a in [-math.pi / 2 + i * math.pi / 6 for i in range(7)]]
    # pts en (x, y) ; plaques horizontales : bas à 0,66, haut incliné de 0,12 rad autour de la buse
    def planche(zb, incl):
        pts = [V(x, y, 0) for x, y in [(-0.36, -0.05), (-0.2, -0.17), (0.0, -0.2), (0.2, -0.19), (0.36, -0.1), (0.38, 0.0), (0.36, 0.1), (0.2, 0.19), (0.0, 0.2), (-0.2, 0.17), (-0.36, 0.05)]]
        R = Ry(-incl)
        bas = [V(-0.36, 0, zb) + R @ (p - V(-0.36, 0, 0)) for p in pts]
        haut = [p + R @ V(0, 0, 0.04) for p in bas]
        faces = [list(reversed(bas)), haut]
        for k in range(len(pts)):
            k1 = (k + 1) % len(pts)
            faces.append([bas[k], bas[k1], haut[k1], haut[k]])
        return dehors(faces), bas, haut
    f1, b1, h1 = planche(0.66, 0.0)
    f2, b2, h2 = planche(0.82, 0.14)
    m.add("bois", f1, ao=0.9)
    m.add("bois", f2, ao=0.95)
    # flanc de cuir plissé entre les deux planches (3 plis)
    nplis = 3
    for k in range(len(h1)):
        k1 = (k + 1) % len(h1)
        prev = [h1[k], h1[k1]]
        for i in range(1, nplis * 2 + 1):
            t = i / (nplis * 2)
            ins = 0.82 if i % 2 else 1.0
            c = lambda a, b: a.lerp(b, t)
            q = [c(h1[k], b2[k]), c(h1[k1], b2[k1])]
            cen = V(0.0, 0.0, q[0].z)
            q = [V(p.x * ins + 0.0 * (1 - ins), p.y * ins, p.z) for p in q]
            m.add("cuir", [[prev[0], prev[1], q[1], q[0]]], ao=0.75 if i % 2 else 0.95)
            prev = q
    m.add("fer_noir", cyl(V(-0.34, 0, 0.72), V(-0.62, 0, 0.7), 0.045, 6, r2=0.025))
    m.add("bois", cyl(V(0.36, 0, 0.88), V(0.6, 0, 1.1), 0.025, 6))
    m.add("fer_noir", box(V(0.25, 0, 0.86), 0.12, 0.2, 0.012))
    return m


def bac_trempe():
    """Bac de trempe 0,55 x 1,1 x 0,44 : parois de planches (4 cm), cerclages, eau noire à 0,425, tenailles, seau."""
    m = Module("bac_trempe", 3800, hs=0.45)
    W, L, H = 0.55, 1.1, 0.44
    e = 0.045
    for sy in (-1, 1):
        for k in range(3):
            m.add("bois_v", prisme_ch(V(0, sy * (L / 2 - e / 2), k * H / 3 + 0.003), W, e, H / 3 - 0.006, 0.006), ao=0.85 + m.j(0.08))
    for sx in (-1, 1):
        for k in range(3):
            m.add("bois_v", prisme_ch(V(sx * (W / 2 - e / 2), 0, k * H / 3 + 0.003), e, L - 2 * e, H / 3 - 0.006, 0.006), ao=0.85 + m.j(0.08))
    m.add("bois_sombre", box(V(0, 0, 0), W - 2 * e, L - 2 * e, 0.04), ao=0.5)
    m.add("eau", box(V(0, 0, 0.405), W - 2 * e, L - 2 * e, 0.02), plat=True, ao=1.0)
    for y in (-0.4, 0.4):
        m.add("fer", prisme_ch(V(0, y, 0.18), W + 0.02, 0.05, 0.08, 0.004))
    for sy in (-1, 1):
        m.add("bois_sombre", poutre_ch(V(-W / 2 - 0.02, sy * (L / 2 - 0.01), H), V(W / 2 + 0.02, sy * (L / 2 - 0.01), H), 0.07, 0.04, 0.008))
    # tenailles qui trempent
    for s in (-1, 1):
        m.add("fer_noir", poutre_ch(V(0.02, 0.2, 0.3), V(0.02 + s * 0.06, 0.2, 0.62), 0.02, 0.014, 0.0, up=Y))
    m.add("fer_noir", cyl(V(0.02, 0.19, 0.42), V(0.02, 0.21, 0.42), 0.015, 5))
    return m


def meule():
    """Meule à aiguiser : bâti (montants, traverse), roue de grès r 0,31 sur axe en Z Godot (Y Blender), manivelle, auge."""
    m = Module("meule", 3900, hs=0.9)
    for sy in (-1, 1):
        m.add("bois_v", poutre_ch(V(-0.12, sy * 0.22, 0.0), V(0.0, sy * 0.22, 0.62), 0.08, 0.07, 0.008, up=Y))
        m.add("bois_v", poutre_ch(V(0.12, sy * 0.22, 0.0), V(0.0, sy * 0.22, 0.62), 0.08, 0.07, 0.008, up=Y))
        m.add("fer_noir", box(V(0.0, sy * 0.22, 0.6), 0.08, 0.09, 0.05))
    m.add("bois", poutre_ch(V(-0.18, 0, 0.12), V(0.18, 0, 0.12), 0.06, 0.5, 0.008))
    m.add("brute", tour([(0.0, -0.06), (0.29, -0.06), (0.31, -0.04), (0.31, 0.04), (0.29, 0.06), (0.0, 0.06)], 12, c=V(0, 0, 0.62), M=Rx(math.pi / 2)))
    m.add("fer_noir", cyl(V(0, -0.3, 0.62), V(0, 0.3, 0.62), 0.03, 6))
    m.add("fer_noir", poutre_ch(V(0, -0.3, 0.62), V(0, -0.3, 0.78), 0.03, 0.02, 0.0, up=Y))
    m.add("bois", cyl(V(0, -0.3, 0.78), V(0, -0.44, 0.78), 0.022, 6))
    # auge d'eau sous la roue
    m.add("bois_v", tour([(0.0, 0.15), (0.17, 0.15), (0.17, 0.26), (0.15, 0.26), (0.15, 0.17), (0.0, 0.17)], 8, c=V(0, 0, 0), ech=(1.0, 0.9)))
    m.add("eau", tour([(0.0, 0.235), (0.15, 0.235)], 8, ech=(1.0, 0.9)), plat=True, ao=1.0)
    return m


# ------------------------------------------------------------------------------------------------ export
def godot(p):
    return (p.x, p.z, -p.y)


def _pad(b):
    return b + b"\0" * ((4 - len(b) % 4) % 4)


def v_str(s):
    b = s.encode()
    return struct.pack("<II", 4, len(b)) + _pad(b)


def v_int(i):
    return struct.pack("<Ii", 2, i)


def ecrire_dat():
    """Encodage Variant de Godot 4 (var_to_bytes) : Dictionary{String: Array[PackedVector3Array, PackedVector3Array, PackedColorArray, PackedInt32Array]}."""
    sortie = [struct.pack("<II", 27, len(DONNEES) + 1), v_str("_version"), v_int(VERSION)]
    stats = {}
    for nom, verts in DONNEES.items():
        idx = {}
        pos, nor, col, ind = [], [], [], []
        for t in range(0, len(verts), 3):
            tri = verts[t:t + 3]
            for p, n, c in (tri[0], tri[2], tri[1]):     # ordre Godot : sens inverse de Blender
                g = godot(p)
                gn = godot(n)
                cle = (round(g[0], 5), round(g[1], 5), round(g[2], 5), round(gn[0], 3), round(gn[1], 3), round(gn[2], 3),
                       round(c[0], 3))
                if cle not in idx:
                    idx[cle] = len(pos)
                    pos.append(g)
                    nor.append(gn)
                    col.append(c)
                ind.append(idx[cle])
        stats[nom] = (len(pos), len(ind) // 3)
        b = [struct.pack("<II", 28, 4)]
        b.append(struct.pack("<II", 36, len(pos)) + b"".join(struct.pack("<3f", *p) for p in pos))
        b.append(struct.pack("<II", 36, len(nor)) + b"".join(struct.pack("<3f", *p) for p in nor))
        b.append(struct.pack("<II", 37, len(col)) + b"".join(struct.pack("<4f", *c) for c in col))
        b.append(struct.pack("<II", 30, len(ind)) + struct.pack("<%di" % len(ind), *ind))
        sortie.append(v_str(nom))
        sortie.append(b"".join(b))
    os.makedirs(os.path.dirname(DAT), exist_ok=True)
    with open(DAT, "wb") as f:
        f.write(b"".join(sortie))
    return stats


def boite(mod):
    pts = []
    for nom, verts in DONNEES.items():
        if nom.split("/")[0] == mod:
            pts += [godot(p) for p, _, _ in verts]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return lo, hi


TEINTE_APERCU = {"bois": (0.42, 0.29, 0.18), "bois_v": (0.38, 0.26, 0.16), "bois_sombre": (0.25, 0.18, 0.12), "bois_clair": (0.55, 0.4, 0.25),
                 "bois_suie": (0.15, 0.13, 0.12), "rondin_sombre": (0.3, 0.22, 0.15), "bout": (0.6, 0.48, 0.3), "fer": (0.32, 0.33, 0.36),
                 "fer_noir": (0.16, 0.16, 0.18), "etain": (0.6, 0.62, 0.66), "cuir": (0.42, 0.26, 0.14), "foin": (0.7, 0.6, 0.3),
                 "jute": (0.6, 0.5, 0.35), "peau": (0.6, 0.48, 0.34), "peau_claire": (0.82, 0.72, 0.58), "peau_sombre": (0.3, 0.24, 0.2),
                 "terre": (0.3, 0.25, 0.2), "argile": (0.62, 0.36, 0.22), "os": (0.86, 0.82, 0.7), "parchemin": (0.85, 0.78, 0.6),
                 "noir": (0.04, 0.04, 0.05), "brute": (0.5, 0.5, 0.52), "cire": (0.9, 0.85, 0.6), "eau": (0.1, 0.14, 0.22),
                 "braises": (1.0, 0.45, 0.08), "charbon": (0.12, 0.12, 0.12), "PEAU": (0.6, 0.48, 0.34), "MAT": (0.42, 0.29, 0.18),
                 "BOUCLIER": (0.6, 0.15, 0.12)}


def apercus(noms):
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
    sc.render.resolution_x, sc.render.resolution_y = 320, 320
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = 'ORTHO'
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    for mod in noms:
        obs = []
        for nom, verts in DONNEES.items():
            if nom.split("/")[0] != mod:
                continue
            me = bpy.data.meshes.new(nom)
            vs = [tuple(p) for p, _, _ in verts]
            me.from_pydata(vs, [], [(i, i + 1, i + 2) for i in range(0, len(vs), 3)])
            me.update()
            ca = me.color_attributes.new(name="apercu", type='FLOAT_COLOR', domain='CORNER')
            t = TEINTE_APERCU[nom.split("/")[1]]
            for poly in me.polygons:
                for li in poly.loop_indices:
                    c = verts[li][2]
                    ca.data[li].color = (t[0] * c[0], t[1] * c[1], t[2] * c[2], 1)
            me.color_attributes.active_color = ca
            ob = bpy.data.objects.new(nom, me)
            sc.collection.objects.link(ob)
            obs.append(ob)
        lo, hi = boite(mod)
        ctr = V((lo[0] + hi[0]) / 2, -(lo[2] + hi[2]) / 2, (lo[1] + hi[1]) / 2)
        taille = max(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
        cam_d.ortho_scale = taille * 1.3
        d = V(0.9, -1.4, 0.8)
        cam.location = ctr + d.normalized() * 30
        cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        cam_d.clip_end = 100
        sc.render.filepath = os.path.join(CAPT, f"{mod}.png")
        bpy.ops.render.render(write_still=True)
        for ob in obs:
            bpy.data.objects.remove(ob)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mods = []
    for v in "ab":
        mods += [table_plateau(v), table_treteau(v), banc_assise(v), tabouret(v), lit(v), etagere(v), chope(v), cruche(v), bouclier(v)]
    for v in "abc":
        mods += [coffre(v), tonneau(v), sac(v)]
    mods += [table_entretoise(), banc_pied(), fourrure_froissee(), assiette(), bol(), chaudron(), livre(), parchemin(), crane(),
             hache(), epee(), lance_hampe(), lance_fer(), trone_halle(), estrade_halle(), enclume(), soufflet(), bac_trempe(), meule()]
    for m in mods:
        m.compiler()
    stats = ecrire_dat()
    print("=== mobilier intérieur v%d : %d entrées, %s" % (VERSION, len(stats), DAT))
    total = 0
    depasse = 0
    for m in sorted(mods, key=lambda m: m.nom):
        t = sum(s[1] for k, s in stats.items() if k.split("/")[0] == m.nom)
        total += t
        base = m.nom.rsplit("_", 1)[0] if m.nom.rsplit("_", 1)[-1] in ("a", "b", "c") else m.nom
        bud = BUDGET.get(base, BUDGET.get(m.nom, 0))
        lo, hi = boite(m.nom)
        ok = t <= bud
        depasse += 0 if ok else 1
        print("  %-20s %5d / %5d %s  x[%.2f %.2f] y[%.2f %.2f] z[%.2f %.2f]" % (m.nom, t, bud, "OK" if ok else "DÉPASSE", lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    print("=== total %d triangles, %d dépassements de budget" % (total, depasse))
    if "--" in sys.argv and "apercu" in sys.argv[sys.argv.index("--") + 1:]:
        apercus([m.nom for m in mods])


main()
