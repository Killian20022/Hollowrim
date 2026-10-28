# C7 « Ossuaire en relief » (2026-10-28, chantier « anti pâte à modeler », docs INSPIRATION_IGNITE §4.1) : MODULES DES NICHES D'OSSUAIRE.
# Les rangées de niches à hauteur d'yeux (0,8 à 2,3 m) ne sont plus une texture (crânes peints dans ossuaire.res) mais de la géométrie :
# cadre de pierre par case de niche (tablette + montant + fond noir), crânes en volume (crâne entier, sans mâchoire, fendu, couché),
# fagots d'os longs (bouts renflés vers la salle, ou couchés le long du mur). Posés par CrypteDecor.panneau_os_v3 / remplir_niches_os
# (scripts/crypte_decor.gd), fusionnés dans les tampons de la case de 8 m comme tout module (aucun nœud par crâne).
#   blender.exe -b --python ossuaire.py [-- apercu=<dossier>]
# Sortie : assets/crypte/modules/ossuaire.dat, MÊME format que objets_donjon.dat (lu par CrypteDecor._charger_modeles en FileAccess).
# Repère = repère Godot (y en haut, +z = vers la salle). Niches : origine au PLAN DU MUR, bas de la case, milieu de la case (0,5 x 0,5 m).
# Contenus : origine au sol de la niche (dessus de la tablette), face avant +z.
# Helpers et classe Module recopiés de objets_donjon.py (convention : chaque script a sa copie) ; arête claire / creux sombre : aretes.py.
import bpy, bmesh, math, os, random, struct, sys
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import aretes      # C1 matières : arête claire / creux sombre en couleur de sommet (sources_blender/scripts/aretes.py)

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
DAT = os.path.join(BASE, "assets", "crypte", "modules", "ossuaire.dat")
TAU = 2 * math.pi
I3 = Matrix.Identity(3)
UP = Vector((0, 1, 0))
TEINTE = {}
BUDGET = {"niche_os_cadre": 120, "niche_os_poteau": 30, "niche_os_corniche": 110, "oss_crane": 200, "oss_fagot": 200, "niche_os_muree": 80}


def V(x, y, z):
    return Vector((x, y, z))


def Ry(a):
    return Matrix.Rotation(a, 3, 'Y')


def Rx(a):
    return Matrix.Rotation(a, 3, 'X')


def Rz(a):
    return Matrix.Rotation(a, 3, 'Z')


def newell(pts):
    n = Vector((0, 0, 0))
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


def orienter(poly, d):
    return poly if newell(poly).dot(d) >= 0 else list(reversed(poly))


def hull(pts):
    """Enveloppe convexe (triangles orientés vers l'extérieur)."""
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts[:], use_existing_faces=False)
    seuls = [v for v in bm.verts if not v.link_faces]
    if seuls:
        bmesh.ops.delete(bm, geom=seuls, context='VERTS')
    c = sum((v.co for v in bm.verts), Vector()) / max(1, len(bm.verts))
    out = []
    for f in bm.faces:
        poly = [v.co.copy() for v in f.verts]
        fc = sum(poly, Vector()) / len(poly)
        out.append(orienter(poly, fc - c))
    bm.free()
    return out


def boite(c, s, R=I3):
    """Pavé : c = centre, s = tailles (x, y, z), R = rotation."""
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    P = lambda x, y, z: c + R @ V(x * hx, y * hy, z * hz)
    faces = [[P(-1, -1, 1), P(1, -1, 1), P(1, 1, 1), P(-1, 1, 1)], [P(1, -1, -1), P(-1, -1, -1), P(-1, 1, -1), P(1, 1, -1)],
             [P(1, -1, 1), P(1, -1, -1), P(1, 1, -1), P(1, 1, 1)], [P(-1, -1, -1), P(-1, -1, 1), P(-1, 1, 1), P(-1, 1, -1)],
             [P(-1, 1, 1), P(1, 1, 1), P(1, 1, -1), P(-1, 1, -1)], [P(-1, -1, -1), P(1, -1, -1), P(1, -1, 1), P(-1, -1, 1)]]
    return [orienter(f, sum(f, Vector()) / 4 - c) for f in faces]


def boite_ch(c, s, ch=0.01, R=I3):
    """Pavé aux arêtes abattues (44 triangles)."""
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    ch = min(ch, hx * 0.45, hy * 0.45, hz * 0.45)
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                pts += [c + R @ V(sx * (hx - ch), sy * hy, sz * hz), c + R @ V(sx * hx, sy * (hy - ch), sz * hz), c + R @ V(sx * hx, sy * hy, sz * (hz - ch))]
    return hull(pts)


def poutre(a, b, w, h, up=UP):
    """Poutre de section w x h de a à b."""
    d = b - a
    side = d.cross(up)
    if side.length < 1e-6:
        side = d.cross(V(1, 0, 0))
    side.normalize()
    n = side.cross(d).normalized()
    pts = [p + side * sw * w / 2 + n * sh * h / 2 for p in (a, b) for sw in (-1, 1) for sh in (-1, 1)]
    return hull(pts)


def cylindre(a, b, r, n=6, r2=None):
    """Tige ronde de a à b (n côtés, bouts fermés)."""
    d = (b - a)
    u = d.cross(UP) if abs(d.normalized().dot(UP)) < 0.9 else d.cross(V(1, 0, 0))
    u.normalize()
    v = d.cross(u).normalized()
    r2 = r if r2 is None else r2
    pts = []
    for k in range(n):
        an = TAU * (k + 0.5) / n
        pts.append(a + (u * math.cos(an) + v * math.sin(an)) * r)
        pts.append(b + (u * math.cos(an) + v * math.sin(an)) * r2)
    return hull(pts)


def disque(c, r, n=8, R=I3, jit=0.0, rg=None):
    """Disque plat (une face vers le haut du repère R)."""
    pts = []
    for k in range(n):
        an = TAU * k / n
        rr = r * (1 + (rg.uniform(-jit, jit) if rg else 0))
        pts.append(c + R @ V(math.cos(an) * rr, 0, math.sin(an) * rr))
    return [orienter(pts, R @ UP)]


def bloc_irr(c, s, rg, jit=0.25, R=I3):
    """Pierre / éclat irrégulier : enveloppe de 8 coins bougés."""
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                pts.append(c + R @ V(sx * s[0] / 2 * (1 + rg.uniform(-jit, jit)), sy * s[1] / 2 * (1 + rg.uniform(-jit, jit)), sz * s[2] / 2 * (1 + rg.uniform(-jit, jit))))
    return hull(pts)


def tertre(r, h, rg, n=9, jit=0.12, anneaux=((1.0, 0.0), (0.8, 0.42), (0.45, 0.8), (0.12, 1.0))):
    """Monticule convexe irrégulier (rayon r, hauteur h)."""
    pts = []
    for (kr, ky) in anneaux:
        for k in range(n if kr > 0.3 else max(3, n // 2)):
            an = TAU * (k + rg.uniform(-0.3, 0.3)) / (n if kr > 0.3 else max(3, n // 2))
            rr = r * kr * (1 + rg.uniform(-jit, jit))
            pts.append(V(math.cos(an) * rr, h * ky * (1 + rg.uniform(-jit, jit) * (0 if ky == 0 else 0.6)), math.sin(an) * rr))
    return hull(pts)


def surface_tertre(rr, r, h, anneaux=((1.0, 0.0), (0.8, 0.42), (0.45, 0.8), (0.12, 1.0))):
    k = rr / r
    pts = sorted(anneaux)
    if k <= pts[0][0]:
        return h * pts[0][1]
    for (a, ya), (b, yb) in zip(pts, pts[1:]):
        if a <= k <= b:
            return h * (ya + (yb - ya) * (k - a) / (b - a))
    return 0.0


class Module:
    def __init__(self, nom, graine, sol=True):
        self.nom = nom
        self.rg = random.Random(graine)
        self.tris = []      # (matière, (a, b, c), ton)
        self.sol = sol      # posé au sol : pied assombri
        self.bandes = "hautes"      # option `bandes` d'aretes.appliquer (« aucune » : semis micro, zéro triangle de plus)
        self.sans_dessous = False    # C5 : faces tournées vers le bas au ras du sol omises (jamais vues : gravats, or, semis)
        self.bruts = set()  # C5 : indices des triangles laissés hors d'aretes.py (pièces : leur bord clair est fait en couleur de sommet)

    def add(self, mat, polys, ton=None, jt=0.0):
        if ton is None:
            ton = self.rg.uniform(0.86, 1.0)
        for p in polys:
            t = ton * (1 + self.rg.uniform(-jt, jt)) if jt else ton
            for i in range(1, len(p) - 1):
                a, b, c = p[0], p[i], p[i + 1]
                if (b - a).cross(c - a).length_squared > 1e-14 and not self._dessous(a, b, c):
                    self.tris.append((mat, (a.copy(), b.copy(), c.copy()), t))

    def _dessous(self, a, b, c):
        if not self.sans_dessous or max(a.y, b.y, c.y) > 0.012:
            return False
        n = (b - a).cross(c - a)
        return n.y < -0.7 * n.length

    def add_tons(self, mat, tris, brut=False):
        """C5 : triangles à ton PAR SOMMET : tris = [((a, b, c), (ta, tb, tc)), ...] ; brut = hors liserés d'aretes.py."""
        for (a, b, c), t in tris:
            if (b - a).cross(c - a).length_squared > 1e-14 and not self._dessous(a, b, c):
                if brut:
                    self.bruts.add(len(self.tris))
                self.tris.append((mat, (a.copy(), b.copy(), c.copy()), tuple(t)))

    def rev(self, mat, profil, n=8, c=None, R=I3, ech=(1.0, 1.0), rot=0.0, caps=(False, True), ton=None, jt=0.0, mats=None):
        """Révolution autour de y local : profil [(r, y)] ; jt = écart de ton par colonne (douelles) ; mats = matière par segment."""
        c = c if c is not None else V(0, 0, 0)
        ton = self.rg.uniform(0.86, 1.0) if ton is None else ton
        cols = [ton * (1 + self.rg.uniform(-jt, jt)) for _ in range(n)]
        P = lambda r, y, k: c + R @ V(math.cos(rot + TAU * k / n) * r * ech[0], y, math.sin(rot + TAU * k / n) * r * ech[1])
        for i in range(len(profil) - 1):
            (r0, y0), (r1, y1) = profil[i], profil[i + 1]
            m = mats[i] if mats else mat
            for k in range(n):
                an = rot + TAU * (k + 0.5) / n
                d = R @ (V(math.cos(an) / max(ech[0], 1e-3), 0, math.sin(an) / max(ech[1], 1e-3)) * (y1 - y0) - UP * (r1 - r0))
                if r0 < 1e-6 and r1 < 1e-6:
                    continue
                if r0 < 1e-6:
                    poly = [P(0, y0, k), P(r1, y1, k), P(r1, y1, k + 1)]
                elif r1 < 1e-6:
                    poly = [P(r0, y0, k), P(r0, y0, k + 1), P(0, y1, k)]
                else:
                    poly = [P(r0, y0, k), P(r0, y0, k + 1), P(r1, y1, k + 1), P(r1, y1, k)]
                self.add(m, [orienter(poly, d)], cols[k])
        if caps[0] and profil[0][0] > 1e-6:
            r, y = profil[0]
            self.add(mat, [orienter([P(r, y, k) for k in range(n)], R @ -UP)], ton)
        if caps[1] and profil[-1][0] > 1e-6:
            r, y = profil[-1]
            self.add(mats[-1] if mats else mat, [orienter([P(r, y, k) for k in range(n)], R @ UP)], ton)

    def finir(self, rayons=12, portee=0.22, force=0.55):
        verts, polys = [], []
        for (m, p, t) in self.tris:
            polys.append((len(verts), len(verts) + 1, len(verts) + 2))
            verts.extend(p)
        arbre = BVHTree.FromPolygons([tuple(v) for v in verts], polys, all_triangles=True, epsilon=1e-6)
        rg = random.Random(7)
        dirs = []
        for _ in range(rayons):
            u, v = rg.random(), rg.random()
            r = math.sqrt(u)
            th = TAU * v
            dirs.append((r * math.cos(th), r * math.sin(th), math.sqrt(max(0.0, 1.0 - u))))
        sortie = {}
        brute = {}
        for i, (m, p, t) in enumerate(self.tris):
            n = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
            tg = n.cross(UP if abs(n.y) < 0.9 else V(1, 0, 0)).normalized()
            bt = n.cross(tg)
            cols = []
            for j, q in enumerate(p):
                occ = 0.0
                o = q + n * 0.004
                for dx, dy, dz in dirs:
                    d = (tg * dx + bt * dy + n * dz).normalized()
                    h = arbre.ray_cast(o, d, portee)
                    if h[0] is not None:
                        occ += 1.0 - h[3] / portee
                ao = max(0.5, min(1.0, 1.0 - force * occ / len(dirs) * 1.6))
                pied = (0.8 + 0.2 * min(1.0, max(0.0, q.y / 0.25))) if self.sol else 1.0
                te = TEINTE.get(m, (1, 1, 1))
                k = ao * (t[j] if isinstance(t, tuple) else t) * pied
                cols.append((min(1.0, k * te[0]), min(1.0, k * te[1]), min(1.0, k * te[2]), 1.0))
            (brute if i in self.bruts else sortie).setdefault(m, []).append((p, cols))
        self.brute = brute      # C5 : rejoint la sortie APRÈS aretes.appliquer (voir main)
        return sortie




# ======================================================================= C7 : cadre des niches (pierre ; « pierre » remplacée à la pose)
L_CASE = 0.5         # largeur d'une case de niche (étirée à la pose : la rangée remplit le panneau)
H_CASE = 0.5         # hauteur d'une rangée
PROF = 0.28          # saillie du cadre devant le plan du mur
TAB = 0.06           # épaisseur de la tablette
POT = 0.07           # largeur d'un montant


def _pts_ch(c, s, ch):
    """Les 24 points d'un pavé chanfreiné (comme boite_ch), pour les déformer avant l'enveloppe."""
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                pts += [c + V(sx * (hx - ch), sy * hy, sz * hz), c + V(sx * hx, sy * (hy - ch), sz * hz), c + V(sx * hx, sy * hy, sz * (hz - ch))]
    return pts


def niche_os_cadre(var):
    """Une case de niche (0,5 x 0,5 m) : tablette du bas, montant de gauche, fond noir. a : nette ; b : tablette ébréchée au coin avant ;
    c : tablette fendue en deux et montant décalé (la maçonnerie a bougé). Le montant de droite est celui de la case voisine."""
    M = Module("niche_os_cadre_" + var, 4100 + ord(var))
    rg = M.rg
    if var == "c":
        for x0, x1, inc in ((-L_CASE / 2, 0.07, 0.02), (0.082, L_CASE / 2, -0.015)):
            M.add("pierre", hull([p for p in _pts_ch(V((x0 + x1) / 2, TAB / 2, PROF / 2), (x1 - x0, TAB, PROF), 0.012)]), rg.uniform(0.82, 0.95))
        M.add("pierre", boite(V(-L_CASE / 2, TAB + 0.22, PROF / 2 - 0.005 + 0.016), (POT, 0.44, PROF - 0.03), Rz(0.012)), 0.8)
    else:
        pts = _pts_ch(V(0, TAB / 2, PROF / 2), (L_CASE, TAB, PROF), 0.012)
        if var == "b":      # coin avant droit éclaté : les points du coin rentrent et descendent
            cx = rg.uniform(0.1, 0.18)
            pts = [V(min(p.x, cx + 0.5 * (p.y - TAB) + 0.06 * (PROF - p.z) / PROF), p.y, p.z) if (p.x > cx and p.z > PROF * 0.55) else p for p in pts]
            pts += [V(cx, TAB, PROF), V(cx + 0.05, TAB * 0.35, PROF), V(cx + 0.03, TAB, PROF * 0.62), V(L_CASE / 2, TAB * 0.3, PROF * 0.6), V(L_CASE / 2, 0.0, PROF * 0.7)]
        M.add("pierre", hull(pts), rg.uniform(0.88, 1.0))
        M.add("pierre", boite(V(-L_CASE / 2, TAB + 0.22, PROF / 2 - 0.01), (POT, 0.44, PROF - 0.02)), rg.uniform(0.76, 0.88))
    # fond de la niche : noir (rampe Ombre, ton 0) ; un peu en avant du mur pour ne jamais le laisser voir
    M.add("noir", [orienter([V(-0.22, TAB, 0.006), V(0.22, TAB, 0.006), V(0.22, H_CASE, 0.006), V(-0.22, H_CASE, 0.006)], V(0, 0, 1))], 1.0)
    return M


def niche_os_poteau():
    """Montant seul (bout droit d'une rangée de niches), sur toute la hauteur d'une case ; origine au pied, plan du mur."""
    M = Module("niche_os_poteau", 4200)
    M.add("pierre", boite(V(0, H_CASE / 2, PROF / 2 - 0.01), (POT, H_CASE, PROF - 0.02)), 0.82)
    return M


def niche_os_corniche(var):
    """Corniche au-dessus de la dernière rangée (sépare les niches en volume de la texture du haut) : bandeau + gradin en retrait.
    b : bandeau ébréché."""
    M = Module("niche_os_corniche_" + var, 4300 + ord(var))
    rg = M.rg
    pts = _pts_ch(V(0, 0.04, (PROF + 0.03) / 2), (L_CASE, 0.08, PROF + 0.03), 0.014)
    if var == "b":
        cx = rg.uniform(-0.15, 0.1)
        pts = [V(p.x, p.y - 0.03 if (abs(p.x - cx) < 0.09 and p.z > 0.2 and p.y < 0.03) else p.y, p.z - (0.04 if (abs(p.x - cx) < 0.09 and p.z > 0.2 and p.y < 0.03) else 0.0)) for p in pts]
    M.add("pierre", hull(pts), rg.uniform(0.9, 1.0))
    M.add("pierre", boite(V(0, 0.105, 0.11), (L_CASE, 0.05, 0.22)), 0.78)
    return M


# ======================================================================= C7 : crânes (même forme que crane_a / crane_b d'objets_donjon.py)
def _crane(M, R, o, machoire, trou=None):
    """Crâne 0,17 x 0,22 x 0,2 (copie du module `crane`) : R = rotation, o = décalage ; trou = (point, rayon) : calotte percée (les
    triangles du disque sont retirés, un fond noir ferme le trou, éclats sur le bord)."""
    T = lambda p: o + R @ p
    n0 = len(M.tris)
    M.rev("os", [(0.055, 0.0), (0.083, 0.04), (0.092, 0.09), (0.08, 0.14), (0.045, 0.172), (0.0, 0.182)], 8, c=o + R @ V(0, 0, -0.012), R=R, ech=(0.85, 1.08), caps=(True, False), ton=0.95)
    if trou is not None:
        h, r = T(trou[0]), trou[1]
        garde = []
        for i, t in enumerate(M.tris):
            if i >= n0 and (sum(t[1], Vector()) / 3 - h).length < r:
                continue
            garde.append(t)
        M.tris = garde
        ctr = T(V(0, 0.09, -0.012))
        dirn = (h - ctr).normalized()
        u = dirn.cross(UP if abs(dirn.dot(UP)) < 0.9 else V(1, 0, 0)).normalized()
        w = dirn.cross(u)
        bord = [h - dirn * 0.012 + (u * math.cos(TAU * k / 6) + w * math.sin(TAU * k / 6)) * r * 0.95 for k in range(6)]
        M.add("noir", [orienter(bord, dirn)], 1.0)
        for k in range(3):      # éclats d'os sur le bord du trou
            p = h + (u * math.cos(TAU * k / 3 + 0.4) + w * math.sin(TAU * k / 3 + 0.4)) * r * 1.05
            M.add("os", hull([p + V(M.rg.uniform(-1, 1), M.rg.uniform(-1, 1), M.rg.uniform(-1, 1)) * 0.012 for _ in range(4)] + [p + dirn * 0.006]), 1.0)
    face = [T(V(sx * 0.052, 0.112, 0.068)) for sx in (-1, 1)] + [T(V(sx * 0.046, 0.05, 0.084)) for sx in (-1, 1)] + \
           [T(V(sx * 0.03, 0.012, 0.088)) for sx in (-1, 1)] + [T(V(sx * 0.055, 0.02, 0.02)) for sx in (-1, 1)] + [T(V(sx * 0.065, 0.11, 0.02)) for sx in (-1, 1)]
    M.add("os", hull(face), 0.9)
    M.add("os", boite(T(V(0, 0.125, 0.072)), (0.125, 0.022, 0.03), R), 1.0)          # arcades
    for sx in (-1, 1):
        M.add("os", boite(T(V(sx * 0.062, 0.085, 0.045)), (0.028, 0.024, 0.06), R), 0.88)      # pommettes
        M.add("noir", hull([T(V(sx * 0.03 + math.cos(TAU * k / 6) * 0.016, 0.1 + math.sin(TAU * k / 6) * 0.014, 0.086)) for k in range(6)] + [T(V(sx * 0.03, 0.1, 0.07))]), 1.0)
    M.add("noir", hull([T(V(-0.011, 0.062, 0.091)), T(V(0.011, 0.062, 0.091)), T(V(0, 0.087, 0.09)), T(V(0, 0.07, 0.08))]), 1.0)
    M.add("os", boite(T(V(0, 0.022, 0.087)), (0.058, 0.014, 0.012), R), 1.0)          # dents
    if machoire:
        M.add("os", hull([V(sx * 0.044, 0.0, 0.075) for sx in (-1, 1)] + [V(sx * 0.052, 0.0, -0.005) for sx in (-1, 1)] +
                          [V(sx * 0.054, 0.042, -0.01) for sx in (-1, 1)] + [V(sx * 0.038, 0.03, 0.082) for sx in (-1, 1)]), 0.8)      # mâchoire au sol, crâne posé dessus (o)


def oss_crane(var):
    """Crâne de niche, face +z. a : entier (mâchoire) ; b : sans mâchoire, front relevé ; c : calotte percée (coup de hache), sans mâchoire ;
    d : couché sur la tempe, face vers la salle et de biais."""
    M = Module("oss_crane_" + var, 4400 + ord(var))
    if var == "a":
        _crane(M, I3, V(0, 0.035, 0), True)
    elif var == "b":
        _crane(M, Rx(-0.18), V(0, 0.012, 0), False)
    elif var == "c":
        _crane(M, Rx(-0.1) @ Rz(0.06), V(0, 0.008, 0), False, (V(0.045, 0.15, 0.0), 0.034))
    else:
        _crane(M, Ry(0.35) @ Rz(1.32), V(0.085, 0.07, 0), False)
    return M


# ======================================================================= C7 : fagots d'os longs
def _bout(M, c, r, rg, ton):
    """Bout d'os renflé (épiphyse à deux lobes), vu de face (+z) : enveloppe de 8 points, ~12 triangles."""
    pts = []
    for k in range(6):
        a = TAU * k / 6 + rg.uniform(-0.25, 0.25)
        lob = 1.0 + 0.22 * math.cos(2 * a)
        pts.append(c + V(math.cos(a) * r * lob, math.sin(a) * r * 0.82, rg.uniform(-0.35, -0.05) * r))
    pts.append(c + V(rg.uniform(-0.2, 0.2) * r, 0, r * 0.5))
    pts.append(c + V(0, 0, -r * 1.2))
    M.add("os", hull(pts), ton)


def oss_fagot(var):
    """Fagot d'os longs. a : bouts vers la salle, serrés en pyramide (4 + 3 + 2) ; b : pile en désordre (un os sort, un autre brisé) ;
    c : os couchés le long du mur (2 + 1 + 1), bouts renflés aux deux extrémités, une côte par-dessus."""
    M = Module("oss_fagot_" + var, 4500 + ord(var))
    M.bandes = "aucune"      # petites pièces : liserés invisibles à 640x360 (faces étroites et cœurs assombris seulement)
    rg = M.rg
    if var in ("a", "b"):
        rangs = [(4, 0.034), (3, 0.094), (2, 0.152)] if var == "a" else [(4, 0.034), (3, 0.092), (2, 0.148)]
        for (n, y) in rangs:
            for i in range(n):
                x = (i - (n - 1) / 2) * 0.074 + rg.uniform(-0.006, 0.006)
                yy = y + rg.uniform(-0.005, 0.005)
                z = 0.205 + rg.uniform(-0.012, 0.012)
                if var == "b":
                    x += rg.uniform(-0.012, 0.012)
                    if n == 3 and i == 1:
                        z += 0.055      # un os sort du fagot
                r = rg.uniform(0.031, 0.038)
                ton = rg.uniform(0.8, 1.0)
                brise = var == "b" and n == 2 and i == 0
                bout = V(x, yy, z)
                M.add("os", cylindre(V(x * 0.92, yy, 0.03), bout - V(0, 0, r * 0.8), r * 0.42, 3), ton * 0.9)
                if brise:      # os brisé : bout en biseau, sans épiphyse
                    M.add("os", hull([bout + V(rg.uniform(-1, 1) * r * 0.45, rg.uniform(-1, 1) * r * 0.45, rg.uniform(-0.8, 0.1) * r) for _ in range(5)]), ton)
                else:
                    _bout(M, bout, r, rg, ton)
    else:
        for (y, z, dx) in ((0.024, 0.1, -0.01), (0.024, 0.19, 0.015), (0.07, 0.145, 0.0), (0.112, 0.17, -0.02)):
            L = rg.uniform(0.34, 0.4)
            dx += rg.uniform(-0.015, 0.015)
            an = rg.uniform(-0.1, 0.1)
            a, b = V(dx - L / 2 * math.cos(an), y, z - L / 2 * math.sin(an)), V(dx + L / 2 * math.cos(an), y, z + L / 2 * math.sin(an))
            ton = rg.uniform(0.84, 1.0)
            M.add("os", cylindre(a, b, 0.018, 5, 0.015), ton * 0.93)
            for p, r in ((a, 0.036), (b, 0.031)):
                M.add("os", hull([p + V(rg.uniform(-0.5, 0.5) * r, rg.uniform(-0.75, 0.75) * r, (j - 2) / 2 * r) for j in range(5)] + [p + V(0, 0.85 * r, 0)]), ton * 0.96)
    return M


def niche_os_muree(var):
    """Niche murée (ou masquée par un sarcophage, une estrade, un meuble) : 3 ou 4 moellons irréguliers à 0,2 m du mur, joints ouverts sur
    le fond noir ; a : entière, b : un moellon tombé (trou noir en haut)."""
    M = Module("niche_os_muree_" + var, 4600 + ord(var))
    M.bandes = "aucune"
    rg = M.rg
    blocs = [(-0.11, 0.13, 0.2, 0.13), (0.1, 0.13, 0.2, 0.13), (-0.04, 0.27, 0.27, 0.13), (0.15, 0.27, 0.12, 0.13), (0.0, 0.41, 0.42, 0.14)]
    if var == "b":
        blocs = blocs[:3] + [(0.15, 0.27, 0.12, 0.13), (-0.13, 0.41, 0.17, 0.14)]
    for (x, y, w, h) in blocs:
        M.add("pierre", bloc_irr(V(x, y, 0.21), (w - 0.012, h - 0.012, 0.08), rg, 0.12), rg.uniform(0.62, 0.9))
    return M


def construire():
    mods = []
    for v in "abc":
        mods.append(niche_os_cadre(v))
        mods.append(oss_fagot(v))
    for v in "ab":
        mods.append(niche_os_corniche(v))
        mods.append(niche_os_muree(v))
    for v in "abcd":
        mods.append(oss_crane(v))
    mods.append(niche_os_poteau())
    return mods


def boite_mod(M):
    pts = [q for (_, p, _) in M.tris for q in p]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return lo, hi


APERCU = {"bois": (0.45, 0.31, 0.2), "fer": (0.35, 0.36, 0.4), "lame": (0.62, 0.64, 0.68), "os": (0.85, 0.8, 0.68), "noir": (0.03, 0.03, 0.04),
          "argile": (0.62, 0.38, 0.24), "entrelacs": (0.5, 0.46, 0.42), "or": (0.95, 0.72, 0.25), "jute": (0.6, 0.5, 0.34), "laine": (0.55, 0.2, 0.18),
          "parchemin": (0.85, 0.78, 0.6), "pierre": (0.45, 0.45, 0.48), "pierre2": (0.38, 0.38, 0.42), "peint": (0.55, 0.2, 0.15)}


def apercus(sorties, dossier):
    os.makedirs(dossier, exist_ok=True)
    sc = bpy.context.scene
    try:
        sc.render.engine = 'BLENDER_WORKBENCH'
    except TypeError as e:
        print("moteur :", e)
    sh = sc.display.shading
    sh.light = 'STUDIO'
    sh.color_type = 'VERTEX'
    sh.show_backface_culling = True
    sc.render.resolution_x, sc.render.resolution_y = 300, 300
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = 'ORTHO'
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    B = lambda v: (v[0], -v[2], v[1])
    for M, res in sorties:
        obs = []
        for mat, faces in res.items():
            me = bpy.data.meshes.new(M.nom + mat)
            vs = []
            cols = []
            for p, c in faces:
                for q, cc in zip(p, c):
                    vs.append(B(q))
                    t = APERCU.get(mat, (0.5, 0.5, 0.5))
                    cols.append((t[0] * cc[0], t[1] * cc[1], t[2] * cc[2], 1))
            me.from_pydata(vs, [], [(i, i + 1, i + 2) for i in range(0, len(vs), 3)])
            me.update()
            ca = me.color_attributes.new(name="c", type='FLOAT_COLOR', domain='CORNER')
            for poly in me.polygons:
                for li in poly.loop_indices:
                    ca.data[li].color = cols[me.loops[li].vertex_index]
            me.color_attributes.active_color = ca
            ob = bpy.data.objects.new(M.nom + mat, me)
            sc.collection.objects.link(ob)
            obs.append(ob)
        lo, hi = boite_mod(M)
        ctr = Vector(B(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2)))
        cam_d.ortho_scale = max(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]) * 1.35
        d = Vector((0.9, -1.4, 0.9))
        cam.location = ctr + d.normalized() * 30
        cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        cam_d.clip_end = 100
        sc.render.filepath = os.path.join(dossier, M.nom + ".png")
        bpy.ops.render.render(write_still=True)
        for ob in obs:
            bpy.data.objects.remove(ob)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mods = construire()
    sorties = []
    donnees = {}
    depasse = 0
    st = {}
    for M in mods:
        res = aretes.appliquer(M.finir(), bandes=M.bandes, stats=st)
        for mat, faces in M.brute.items():      # C5 : pièces (bord clair en couleur de sommet), hors liserés
            res.setdefault(mat, []).extend(faces)
        sorties.append((M, res))
        for mat, faces in res.items():
            donnees["%s__%s" % (M.nom, mat)] = faces
        base = M.nom.rsplit("_", 1)[0] if M.nom.rsplit("_", 1)[-1] in ("a", "b", "c", "d") else M.nom
        bud = BUDGET.get(base, 0)
        lo, hi = boite_mod(M)
        ok = len(M.tris) <= bud
        depasse += 0 if ok else 1
        print("  %-20s %4d / %4d %s  x[%.2f %.2f] y[%.2f %.2f] z[%.2f %.2f]" % (M.nom, len(M.tris), bud, "OK" if ok else "DEPASSE", lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    os.makedirs(os.path.dirname(DAT), exist_ok=True)
    with open(DAT, "wb") as f:
        f.write(struct.pack("<I", len(donnees)))
        for nom, faces in donnees.items():
            nb = nom.encode()
            f.write(struct.pack("<B", len(nb)) + nb + struct.pack("<I", len(faces) * 3))
            for p, c in faces:
                for q, cc in zip(p, c):
                    f.write(struct.pack("<7f", q.x, q.y, q.z, cc[0], cc[1], cc[2], cc[3]))
    print("ossuaire : %d modules, %d triangles, %d depassements -> %s" % (len(mods), sum(len(M.tris) for M in mods), depasse, DAT))
    print("aretes : %d -> %d triangles apres liseres" % (st.get("avant", 0), st.get("apres", 0)))
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for a in args:
        if a.startswith("apercu="):
            apercus(sorties, a[7:])


main()
