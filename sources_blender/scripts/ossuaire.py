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
BUDGET = {"niche_os_cadre": 120, "niche_os_poteau": 30, "niche_os_corniche": 110, "oss_crane": 520, "oss_fagot": 380, "niche_os_muree": 80,
          "oss_long": 100, "oss_monticule": 3400}      # v2 : crânes et os anatomiques (champs de distance, voir plus bas)


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
        self.organique = False      # v2 : os anatomiques (occlusion courte + patine, pas de liserés)
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


# ======================================================================= Ossuaire v2 (2026-10-30) : crânes et os ANATOMIQUES
# « Ça fait jouet en plastique » : les crânes (enveloppes convexes + pavés) et les os (cylindres à 3 pans + bouts en losange) sont
# remplacés par la MÊME anatomie que le squelette ennemi (squelette_nordique.py) : champs de distance signés du crâne (voûte, occiput,
# masque facial, arcades sourcilières, pommettes + arcades zygomatiques, tempes creusées, orbites en entonnoir, cavité nasale en cœur
# inversé, maxillaire) et de la mandibule, maillés en « surface nets » puis décimés (budget PS1) ; dents une à une devant une plaque
# noire ; os longs (fémur, humérus, tibia) en champs eux aussi : diaphyse, épiphyses, condyles, tête et col, trochanter.
# Matière : pas d'aplat lisse. Couleur de sommet = occlusion courte (creux sombres : orbites, sutures, entre les os) x convexité
# (arêtes osseuses claires, creux sombres) x patine (taches de terre brunes, base enterrée, grain, jaunissement) ; orbites, cavité
# nasale, trou de la calotte et fond de la bouche en matière « noir ». Pas de liserés d'aretes.py sur ces formes organiques.
# Fonctions de champ recopiées de squelette_nordique.py (convention : chaque script a sa copie) ; repère Blender du perso (x gauche,
# -y devant, z haut, tête vers z = 1,7) converti en repère Godot du module (x, z, -y).
import numpy as np


def _ell(P, c, r):
    q = (P - np.array(c)) / np.array(r)
    k0 = np.linalg.norm(q, axis=-1)
    k1 = np.linalg.norm(q / np.array(r), axis=-1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def _caps(P, a, b, r):
    a = np.array(a); b = np.array(b)
    pa = P - a; ba = b - a
    h = np.clip((pa @ ba) / ba.dot(ba), 0.0, 1.0)
    return np.linalg.norm(pa - h[..., None] * ba, axis=-1) - r


def _rbox(Q, b, r):
    q = np.abs(Q) - np.array(b)
    return np.linalg.norm(np.maximum(q, 0.0), axis=-1) + np.minimum(q.max(axis=-1), 0.0) - r


def _smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)


def _smax(a, b, k):
    return -_smin(-a, -b, k)


def _courbe(P, k=9.0):
    Q = P.copy(); Q[..., 1] -= k * Q[..., 0] ** 2
    return Q


ORB_C = (0.031, -0.095, 1.693)


def sd_orbite(P):
    d = None
    for sg in (1.0, -1.0):
        Q = P - np.array((sg * ORB_C[0], ORB_C[1], ORB_C[2]))
        a = math.radians(11.0) * sg
        x = Q[..., 0] * math.cos(a) - Q[..., 2] * math.sin(a)
        z = Q[..., 0] * math.sin(a) + Q[..., 2] * math.cos(a)
        f = np.clip(1.0 - 7.5 * (Q[..., 1] + 0.010), 0.55, 1.0)
        R = np.stack([x / f, Q[..., 1], z / f], axis=-1)
        di = _rbox(R, (0.0135, 0.042, 0.0113), 0.0075) * f
        d = di if d is None else np.minimum(d, di)
    return d


def sd_nez(P):
    d = _ell(P, (0.0, -0.090, 1.669), (0.0050, 0.032, 0.0135))
    for sg in (1.0, -1.0):
        d = _smin(d, _ell(P, (sg * 0.0080, -0.090, 1.6520), (0.0095, 0.032, 0.0110)), 0.004)
    return d


def sd_crane(P):
    z = P[..., 2]
    d = _ell(P, (0.0, 0.028, 1.738), (0.073, 0.097, 0.085))
    d = _smin(d, _ell(P, (0.0, 0.058, 1.700), (0.063, 0.070, 0.066)), 0.020)
    d = _smin(d, _ell(P, (0.0, 0.040, 1.690), (0.060, 0.062, 0.040)), 0.020)
    F = _courbe(P)
    tap = 1.0 + np.clip((1.668 - z) / 0.040, 0.0, 1.0) * 0.70
    Fm = F - np.array((0.0, -0.052, 1.675)); Fm[..., 0] *= tap
    d = _smin(d, _rbox(Fm, (0.044, 0.019, 0.034), 0.012), 0.016)
    for sg in (1.0, -1.0):
        d = _smin(d, _caps(F, (sg * 0.006, -0.0845, 1.7125), (sg * 0.050, -0.0800, 1.7085), 0.0058), 0.010)
    for sg in (1.0, -1.0):
        d = _smin(d, _ell(P, (sg * 0.046, -0.066, 1.666), (0.012, 0.011, 0.012)), 0.012)
        d = _smin(d, _ell(P, (sg * 0.050, 0.024, 1.664), (0.013, 0.022, 0.020)), 0.012)
        d = _smin(d, _caps(P, (sg * 0.056, -0.050, 1.664), (sg * 0.064, 0.006, 1.668), 0.0055), 0.008)
        d = _smax(d, -_ell(P, (sg * 0.089, -0.020, 1.704), (0.026, 0.040, 0.030)), 0.010)
    d = _smin(d, _ell(P, (0.0, -0.058, 1.633), (0.034, 0.028, 0.019)), 0.012)
    d = _smax(d, 1.6215 - z, 0.003)
    d = _smax(d, -sd_orbite(P), 0.0035)
    d = _smax(d, -sd_nez(P), 0.0025)
    return d


MAND_PIV = Vector((0.0, 0.020, 1.665))


def sd_mandibule(P):
    d = None
    for sg in (1.0, -1.0):
        haut = [(0.0, -0.079, 1.6055), (sg * 0.026, -0.068, 1.6060), (sg * 0.042, -0.040, 1.6075), (sg * 0.050, -0.002, 1.6090)]
        bas = [(0.0, -0.080, 1.5835), (sg * 0.028, -0.068, 1.5850), (sg * 0.045, -0.038, 1.5880), (sg * 0.053, 0.004, 1.5940)]
        for L, r in ((haut, 0.0058), (bas, 0.0068)):
            for a, b in zip(L[:-1], L[1:]):
                di = _caps(P, a, b, r)
                d = di if d is None else _smin(d, di, 0.010)
        d = _smin(d, _caps(P, (sg * 0.050, -0.002, 1.6060), (sg * 0.053, 0.004, 1.5940), 0.0068), 0.010)
        d = _smin(d, _caps(P, (sg * 0.052, 0.006, 1.6000), (sg * 0.056, 0.018, 1.6560), 0.0060), 0.008)
        d = _smin(d, _ell(P, (sg * 0.0565, 0.019, 1.6595), (0.0075, 0.0060, 0.0045)), 0.004)
        d = _smin(d, _caps(P, (sg * 0.050, -0.010, 1.6080), (sg * 0.051, -0.014, 1.6440), 0.0042), 0.006)
    d = _smin(d, _ell(P, (0.0, -0.0835, 1.5865), (0.013, 0.0075, 0.0095)), 0.006)
    return d


def surface_nets(sdf, lo, hi, h):
    """Maillage (sommets, quads) de l'isosurface 0 d'un champ signé (négatif dedans) : un sommet par cellule traversée."""
    nx, ny, nz = [int(round((hi[i] - lo[i]) / h)) + 1 for i in range(3)]
    X = lo[0] + np.arange(nx) * h; Y = lo[1] + np.arange(ny) * h; Z = lo[2] + np.arange(nz) * h
    G = np.stack(np.meshgrid(X, Y, Z, indexing="ij"), axis=-1)
    f = sdf(G.reshape(-1, 3)).reshape(nx, ny, nz)
    cs = np.array([(i, j, k) for k in (0, 1) for j in (0, 1) for i in (0, 1)])
    cv = np.stack([f[i:nx - 1 + i, j:ny - 1 + j, k:nz - 1 + k] for i, j, k in cs], axis=-1)
    actif = (cv.min(-1) < 0) & (cv.max(-1) >= 0)
    edges = [(a, b) for a in range(8) for b in range(a + 1, 8) if np.abs(cs[a] - cs[b]).sum() == 1]
    acc = np.zeros(actif.shape + (3,)); n = np.zeros(actif.shape)
    for a, b in edges:
        fa, fb = cv[..., a], cv[..., b]
        s = (fa < 0) != (fb < 0)
        t = np.where(s, fa / np.where(s, fa - fb, 1.0), 0.0)
        p = cs[a] + (cs[b] - cs[a]) * t[..., None]
        acc += p * s[..., None]; n += s
    idx = -np.ones(actif.shape, dtype=np.int64)
    ci = np.argwhere(actif)
    idx[actif] = np.arange(len(ci))
    pos = (ci + acc[actif] / n[actif][..., None]) * h + np.array(lo)
    quads = []
    for ax in range(3):
        o1, o2 = [a for a in range(3) if a != ax]
        sl0 = [slice(None)] * 3; sl1 = [slice(None)] * 3
        sl0[ax] = slice(0, -1); sl1[ax] = slice(1, None)
        s = (f[tuple(sl0)] < 0) != (f[tuple(sl1)] < 0)
        for e in np.argwhere(s):
            if e[o1] == 0 or e[o2] == 0 or e[o1] >= f.shape[o1] - 1 or e[o2] >= f.shape[o2] - 1:
                continue
            c = []
            for d1, d2 in ((0, 0), (1, 0), (1, 1), (0, 1)):
                q = e.copy(); q[o1] -= d1; q[o2] -= d2
                c.append(idx[tuple(q)])
            if min(c) >= 0:
                quads.append(c)
    return pos, quads


def sdf_maille(sdf, lo, hi, h, nb_tris, sym=False, perso=True):
    """Champ -> surface nets -> décimation -> triangles orientés vers l'extérieur, en repère GODOT du module.
    Renvoie [((a, b, c), (ka, kb, kc), centre_blender)] : k = ton de convexité par sommet (arête osseuse claire, creux sombre)."""
    pos, quads = surface_nets(sdf, lo, hi, h)
    me = bpy.data.meshes.new("tmp_sdf")
    me.from_pydata([tuple(p) for p in pos], [], [tuple(q) for q in quads])
    me.validate()
    ob = bpy.data.objects.new("tmp_sdf", me)
    bpy.context.collection.objects.link(ob)
    mo = ob.modifiers.new("dec", 'DECIMATE')
    mo.decimate_type = 'COLLAPSE'
    mo.ratio = min(1.0, nb_tris / (2.0 * len(quads)))
    mo.use_symmetry = sym
    mo.symmetry_axis = 'X'
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    m2 = ev.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(m2)
    ev.to_mesh_clear()
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    conv = {}
    for v in bm.verts:      # convexité : les voisins sous le plan tangent = bosse (claire), au-dessus = creux (sombre)
        s, n = 0.0, 0
        for e in v.link_edges:
            o = e.other_vert(v)
            d = o.co - v.co
            if d.length > 1e-7:
                s += d.normalized().dot(v.normal)
                n += 1
        c = s / max(1, n)
        conv[v.index] = max(0.62, min(1.12, 1.0 - c * 1.5))
    G = (lambda p: V(p.x, p.z, -p.y)) if perso else (lambda p: p.copy())
    out = []
    for f in bm.faces:
        vs = list(f.verts)
        out.append((tuple(G(v.co) for v in vs), tuple(conv[v.index] for v in vs), sum((v.co for v in vs), Vector()) / 3))
    bm.free()
    return out


def _reposer(tris, R, sink=0.003):
    """Tourne (R) puis pose sur y = 0 (le point le plus bas enfoncé de `sink`)."""
    t2 = [(tuple(R @ q for q in p), k, c) for (p, k, c) in tris]
    y0 = min(q.y for (p, _, _) in t2 for q in p)
    return [(tuple(q - V(0, y0 + sink, 0) for q in p), k, c) for (p, k, c) in t2]


# ---------------------------------------------------------------- crâne
_CACHE = {}
TROU_C = (0.038, -0.004, 1.806)       # coup de hache sur le pariétal gauche (repère Blender)
TROU_R = (0.026, 0.030, 0.022)


def _crane_tris(trou):
    cle = "crane_trou" if trou else "crane"
    if cle not in _CACHE:
        if trou:
            sdf = lambda P: _smax(sd_crane(P), -_ell(P, TROU_C, TROU_R), 0.003)
        else:
            sdf = sd_crane
        tris = sdf_maille(sdf, (-0.096, -0.112, 1.605), (0.096, 0.140, 1.840), 0.0025, 210, sym=not trou)
        cen = np.array([[c.x, c.y, c.z] for (_, _, c) in tris])
        d_or = sd_orbite(cen); d_nz = sd_nez(cen)
        d_tr = _ell(cen, TROU_C, (TROU_R[0] * 1.2, TROU_R[1] * 1.2, TROU_R[2] * 1.2)) if trou else np.ones(len(tris))
        out = []
        for (p, k, c), do, dn, dt in zip(tris, d_or, d_nz, d_tr):
            creux = (do < 0.0030 and c.y > -0.0825) or (dn < 0.0030 and c.y > -0.0845) or dt < 0.0
            out.append((p, k, "noir" if creux else "os"))
        _CACHE[cle] = out
    return _CACHE[cle]


def _mand_tris():
    if "mand" not in _CACHE:
        tris = sdf_maille(sd_mandibule, (-0.068, -0.096, 1.570), (0.068, 0.034, 1.672), 0.0025, 48, sym=True)
        _CACHE["mand"] = [(p, k, "os") for (p, k, c) in tris]      # mâchoire fermée (champ au repos, sans l'ouverture de 9° du squelette)
    return _CACHE["mand"]


def _dents(bas):
    """Rangée de 8 dents (face + pointe : 4 triangles chacune) et plaque noire derrière : repère Godot."""
    out = []
    ax, ay, y0, z = (0.0300, 0.0370, -0.0440, 1.6255) if not bas else (0.0255, 0.0330, -0.0435, 1.5985)
    sgn = 1 if not bas else -1      # 1 : pointes vers le bas
    G = lambda p: V(p.x, p.z, -p.y)
    for t in np.linspace(-1.08, 1.08, 8):
        p = V(ax * math.sin(t), y0 - ay * math.cos(t), z)
        tg = V(ax * math.cos(t), ay * math.sin(t), 0.0).normalized()
        ext = V(math.sin(t) * ay, -math.cos(t) * ax, 0.0).normalized()
        av = abs(t) / 1.08
        w = (0.0068 + 0.0022 * av)
        hh = (0.0110 - 0.0028 * av)
        ep = (0.0050 + 0.0030 * av)
        dz = V(0, 0, -hh * sgn)
        f0 = [p + ext * ep * 0.5 - tg * w * 0.5, p + ext * ep * 0.5 + tg * w * 0.5]
        f1 = [p + dz + ext * ep * 0.39 + tg * w * 0.39, p + dz + ext * ep * 0.39 - tg * w * 0.39]
        b1 = [p + dz - ext * ep * 0.39 + tg * w * 0.39, p + dz - ext * ep * 0.39 - tg * w * 0.39]
        face = [G(q) for q in f0 + f1]
        pointe = [G(q) for q in (f1[0], f1[1], b1[1], b1[0])]
        out.append((orienter(face, G(ext)), "os"))
        out.append((orienter(pointe, G(dz)), "os"))
    # plaque noire derrière la rangée (les jours entre les dents se lisent noirs)
    arc = [V(0.9 * ax * math.sin(t), y0 - 0.9 * ay * math.cos(t) + 0.004, z) for t in np.linspace(-1.2, 1.2, 6)]
    for a, b in zip(arc, arc[1:]):
        q = [a, b, b - V(0, 0, 0.012 * sgn), a - V(0, 0, 0.012 * sgn)]
        mid = (a + b) / 2
        out.append((orienter([G(x) for x in q], G(V(mid.x, mid.y - y0, 0))), "noir"))
    return out


def _crane(M, R, machoire, trou=False, sink=0.003, ton=0.84):
    """Crâne anatomique (0,15 x 0,19 x 0,24 avec mâchoire) tourné de R, posé sur y = 0, face +z. ~330 triangles (+120 avec mâchoire)."""
    tris = [(p, k, m) for (p, k, m) in _crane_tris(trou)]
    tris += [((a, b, c), (1.0, 1.0, 1.0), m) for (poly, m) in _dents(False) for (a, b, c) in [(poly[0], poly[i], poly[i + 1]) for i in range(1, len(poly) - 1)]]
    if machoire:
        tris += _mand_tris()
        tris += [((a, b, c), (1.0, 1.0, 1.0), m) for (poly, m) in _dents(True) for (a, b, c) in [(poly[0], poly[i], poly[i + 1]) for i in range(1, len(poly) - 1)]]
    # centre du crâne au-dessus de l'origine avant rotation (la voûte vers z = 1,72 en Blender -> y Godot)
    c0 = V(0, 1.70, -0.02)
    t2 = [(tuple(R @ (q - c0) for q in p), k, m) for (p, k, m) in tris]
    y0 = min(q.y for (p, _, _) in t2 for q in p)
    for (p, k, m) in t2:
        p = tuple(q - V(0, y0 + sink, 0) for q in p)
        if m == "noir":
            M.add_tons("noir", [(p, (1.0, 1.0, 1.0))])
        else:
            M.add_tons("os", [(p, tuple(ton * x for x in k))])


def oss_crane(var):
    """Crâne de niche (et crâne posé au sol, CrypteDecor.crane), face +z. a : entier (mâchoire) ; b : sans mâchoire, front relevé ;
    c : calotte percée (coup de hache), sans mâchoire ; d : couché sur la tempe, face vers la salle et de biais."""
    M = Module("oss_crane_" + var, 4400 + ord(var))
    M.organique = True
    if var == "a":
        _crane(M, I3, True)
    elif var == "b":
        _crane(M, Rx(-0.30), False, sink=0.006, ton=0.8)
    elif var == "c":
        _crane(M, Rx(-0.12) @ Rz(0.08), False, trou=True, ton=0.78)
    else:
        _crane(M, Ry(0.35) @ Rz(1.32), False, sink=0.01, ton=0.82)
    return M


# ---------------------------------------------------------------- os longs (repère Godot : le long de x, ~0,30 m)
def sd_femur(P):
    d = _caps(P, (-0.125, 0.0, 0.0), (0.0, 0.005, 0.0), 0.0125)
    d = _smin(d, _caps(P, (0.0, 0.005, 0.0), (0.12, 0.0, 0.0), 0.0118), 0.01)
    for sz in (1.0, -1.0):      # condyles (bout distal, -x), échancrure entre eux
        d = _smin(d, _ell(P, (-0.146, -0.003, sz * 0.0155), (0.021, 0.020, 0.0145)), 0.018)
    d = _smax(d, -_ell(P, (-0.166, -0.006, 0.0), (0.014, 0.03, 0.0048)), 0.003)
    d = _smin(d, _ell(P, (-0.135, 0.012, 0.0), (0.012, 0.006, 0.010)), 0.008)      # trochlée (face avant)
    d = _smin(d, _caps(P, (0.115, 0.0, 0.0), (0.142, 0.007, 0.026), 0.0095), 0.008)   # col
    d = _smin(d, _ell(P, (0.148, 0.008, 0.034), (0.0195, 0.0195, 0.0195)), 0.005)     # tête
    d = _smin(d, _ell(P, (0.136, 0.003, -0.012), (0.018, 0.016, 0.013)), 0.01)        # grand trochanter
    d = _smin(d, _ell(P, (0.108, -0.006, 0.012), (0.008, 0.007, 0.007)), 0.006)       # petit trochanter
    return d


def sd_humerus(P):
    d = _caps(P, (-0.12, 0.0, 0.0), (0.0, -0.002, 0.0), 0.0098)
    d = _smin(d, _caps(P, (0.0, -0.002, 0.0), (0.118, 0.0, 0.0), 0.0108), 0.008)
    d = _smin(d, _ell(P, (0.132, 0.005, 0.007), (0.0195, 0.0195, 0.0195)), 0.012)     # tête
    d = _smin(d, _ell(P, (0.12, 0.0, -0.013), (0.013, 0.012, 0.010)), 0.008)          # tubercule
    d = _smin(d, _ell(P, (-0.134, 0.0, 0.0), (0.012, 0.010, 0.025)), 0.012)           # palette distale
    for sz in (1.0, -1.0):
        d = _smin(d, _ell(P, (-0.13, 0.0, sz * 0.026), (0.008, 0.008, 0.009)), 0.006) # épicondyles
    d = _smax(d, -_ell(P, (-0.13, 0.011, 0.0), (0.007, 0.006, 0.011)), 0.003)         # fosse olécrânienne
    return d


def sd_tibia(P):
    d = _caps(P, (-0.12, 0.0, 0.0), (0.11, 0.0, 0.0), 0.0102)
    d = _smin(d, _caps(P, (0.09, 0.009, 0.0), (-0.03, 0.006, 0.0), 0.0055), 0.012)    # crête tibiale
    d = _smin(d, _ell(P, (0.132, 0.0, 0.0), (0.016, 0.0145, 0.031)), 0.022)           # plateau
    d = _smax(d, -_ell(P, (0.149, 0.004, 0.0), (0.005, 0.02, 0.004)), 0.003)          # éminence (entre les deux glènes)
    d = _smin(d, _ell(P, (-0.132, 0.0, 0.0), (0.012, 0.0125, 0.017)), 0.012)
    d = _smin(d, _ell(P, (-0.138, -0.001, 0.018), (0.010, 0.008, 0.007)), 0.006)      # malléole
    return d


OS_SDF = {"femur": sd_femur, "humerus": sd_humerus, "tibia": sd_tibia}


def _os_tris(genre, nb):
    cle = "%s_%d" % (genre, nb)
    if cle not in _CACHE:
        _CACHE[cle] = [(p, k, "os") for (p, k, c) in sdf_maille(OS_SDF[genre], (-0.18, -0.035, -0.05), (0.18, 0.035, 0.065), 0.0035, nb, perso=False)]
    return _CACHE[cle]


def _cote_tris(rg, L=0.3, courbe=0.07):
    """Côte : bande plate (1,4 x 0,6 cm) en arc, 4 pans, 6 tronçons ; repère Godot, posée à plat, le long de x."""
    pts = [V(-L / 2 + L * i / 6, 0.004 + 0.012 * math.sin(math.pi * i / 6), courbe * math.sin(math.pi * i / 6) - courbe * 0.5) for i in range(7)]
    out = []
    ring = []
    for i, c in enumerate(pts):
        t = (pts[min(i + 1, 6)] - pts[max(i - 1, 0)]).normalized()
        n = UP - t * UP.dot(t)
        n.normalize()
        b = t.cross(n)
        w = 0.0075 * (0.6 if i in (0, 6) else 1.0)
        h = 0.0032
        ring.append([c + b * w, c + n * h, c - b * w, c - n * h])
    for i in range(6):
        for j in range(4):
            q = [ring[i][j], ring[i][(j + 1) % 4], ring[i + 1][(j + 1) % 4], ring[i + 1][j]]
            mid = sum(q, Vector()) / 4
            ctr = (pts[i] + pts[i + 1]) / 2
            q = orienter(q, mid - ctr)
            out.append(((q[0], q[1], q[2]), (0.95, 1.0, 1.0), "os"))
            out.append(((q[0], q[2], q[3]), (0.95, 1.0, 0.95), "os"))
    return out


def _verser(M, tris, R, o, ton, zmin=None):
    """Verse des triangles (repère du module source) dans M, tournés de R et posés en o ; zmin : triangles entièrement derrière
    ce plan omis (bout d'os enfoncé dans le fond de la niche, jamais vu)."""
    for (p, k, m) in tris:
        q = tuple(o + R @ x for x in p)
        if zmin is not None and max(x.z for x in q) < zmin:
            continue
        if m == "noir":
            M.add_tons("noir", [(q, (1.0, 1.0, 1.0))])
        else:
            M.add_tons("os", [(q, tuple(ton * x for x in k))])


def oss_long(var):
    """Os long posé au sol (CrypteDecor.os_tas), 0,30 m le long de x (étiré à la pose) : a : fémur, b : côte, c : tibia."""
    M = Module("oss_long_" + var, 4700 + ord(var))
    M.organique = True
    if var == "b":
        _verser(M, _reposer(_cote_tris(M.rg), I3), I3, V(0, 0, 0), 0.84)
    else:
        _verser(M, _reposer(_os_tris("femur" if var == "a" else "tibia", 84), Rx(0.3 if var == "a" else -0.2)), I3, V(0, 0, 0), 0.84)
    return M


# ---------------------------------------------------------------- fagots
def oss_fagot(var):
    """Fagot d'os longs. a : bouts vers la salle, serrés en pyramide (4 + 3 + 2) ; b : pile en désordre (un os sort, un autre de
    biais) ; c : os entiers couchés le long du mur (2 + 1 + 1) et une côte par-dessus. Les bouts montrent la vraie épiphyse : condyles
    du fémur, tête et col, plateau du tibia, palette de l'humérus (tournés au hasard autour de leur axe)."""
    M = Module("oss_fagot_" + var, 4500 + ord(var))
    M.organique = True
    rg = M.rg
    if var in ("a", "b"):
        rangs = [(4, 0.022), (3, 0.064), (2, 0.106)] if var == "a" else [(4, 0.022), (3, 0.062), (2, 0.102)]
        for (n, y) in rangs:
            for i in range(n):
                x = (i - (n - 1) / 2) * 0.062 + rg.uniform(-0.005, 0.005)
                genre = rg.choice(("femur", "femur", "humerus", "tibia"))
                bout = rg.random() < 0.5                       # True : bout +x (tête / plateau) vers la salle
                R0 = Ry(-math.pi / 2) if bout else Ry(math.pi / 2)
                R = Rx(rg.uniform(-0.06, 0.06)) @ Ry(rg.uniform(-0.07, 0.07)) @ Rz(rg.uniform(0, TAU)) @ R0
                z = 0.205 + rg.uniform(-0.015, 0.012)
                if var == "b":
                    x += rg.uniform(-0.01, 0.01)
                    if n == 3 and i == 1:
                        z += 0.05
                    if n == 2 and i == 0:
                        R = Ry(0.35) @ Rx(-0.12) @ R
                yy = y + rg.uniform(-0.004, 0.004)
                # bout de l'os à z : le bout (tête ou condyles) est à ~0,15-0,17 du centre de l'os
                o = V(x, yy, z - 0.16)
                _verser(M, _os_tris(genre, 44), R, o, rg.uniform(0.74, 0.92), zmin=0.05)
    else:
        for (y, z, dx) in ((0.016, 0.1, -0.01), (0.016, 0.19, 0.015), (0.044, 0.145, 0.0), (0.074, 0.17, -0.02)):
            genre = rg.choice(("femur", "humerus", "tibia"))
            R = Ry(rg.uniform(-0.1, 0.1) + (math.pi if rg.random() < 0.5 else 0.0)) @ Rx(rg.uniform(-0.5, 0.5))
            _verser(M, _os_tris(genre, 72), R, V(dx + rg.uniform(-0.015, 0.015), y, z), rg.uniform(0.76, 0.92))
        _verser(M, _cote_tris(rg, 0.26, 0.06), Ry(0.2) @ Rz(0.05), V(0.02, 0.092, 0.15), 0.86)
    return M


# ---------------------------------------------------------------- monticule de l'autel (DonjonKit.os_monticule)
def oss_monticule():
    """Monticule d'os (r 0,9, h 0,6 ; étiré à la pose) : noyau de terre et d'os brisés très sombre, couvert d'os longs ENTIERS
    (fémurs, humérus, tibias, côtes) couchés selon la pente, en désordre ; les crânes sont posés à part (CrypteDecor.crane)."""
    M = Module("oss_monticule", 4800)
    M.organique = True
    rg = M.rg
    an_ = ((1.0, 0.0), (0.85, 0.4), (0.55, 0.8), (0.2, 1.0))
    M.add("os", tertre(0.86, 0.56, rg, 10, 0.08, an_), 0.13)      # même hauteur que l'ancien (crâne posé au sommet)
    for k in range(64):
        u = rg.random()
        rr = 0.86 * math.sqrt(u) * 0.95
        an = rg.uniform(0, TAU)
        rad = V(math.cos(an), 0, math.sin(an))
        tg = V(-rad.z, 0, rad.x)
        y = surface_tertre(rr, 0.86, 0.56, an_)
        pente = 0.56 / 0.86 * (1.2 if rr > 0.35 else 0.5)
        nrm = (UP + rad * pente).normalized()      # normale approchée de la pente
        d = (tg * math.cos(rg.uniform(-1.0, 1.0)) + rad * rg.uniform(-0.6, 0.6))
        d = (d - nrm * d.dot(nrm)).normalized()
        b = d.cross(nrm)
        Rb = Matrix((d, nrm, b)).transposed()      # x -> le long de la pente, y -> normale
        if k % 6 == 5:
            tris = _cote_tris(rg, rg.uniform(0.22, 0.3), 0.06)
        else:
            tris = _os_tris(rg.choice(("femur", "femur", "humerus", "tibia")), 26)
        s = rg.uniform(0.9, 1.25)
        Rf = Rb @ Rx(rg.uniform(0, TAU) if k % 6 != 5 else 0.0) @ Matrix.Diagonal((s, s, s))
        _verser(M, tris, Rf, rad * rr + V(0, y + rg.uniform(-0.008, 0.01), 0), rg.uniform(0.66, 0.92))
    return M


# ---------------------------------------------------------------- patine (couleur de sommet des os : terre, grain, jaunissement)
def _h3(i, j, k, s):
    n = (i * 73856093) ^ (j * 19349663) ^ (k * 83492791) ^ (s * 2654435761)
    n &= 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0


def bruit3(p, f, s):
    x, y, z = p.x * f, p.y * f, p.z * f
    i, j, k = math.floor(x), math.floor(y), math.floor(z)
    fx, fy, fz = x - i, y - j, z - k
    fx, fy, fz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    r = 0.0
    for di in (0, 1):
        for dj in (0, 1):
            for dk in (0, 1):
                w = (fx if di else 1 - fx) * (fy if dj else 1 - fy) * (fz if dk else 1 - fz)
                r += w * _h3(i + di, j + dj, k + dk, s)
    return r


def patiner(res, M):
    """Os : taches de terre brunes (~3 cm), base enterrée plus brune, grain fin clair / sombre, jaunissement général."""
    faces = res.get("os", [])
    if not faces:
        return
    haut = max(q.y for (p, _) in faces for q in p)
    s = 17 + (hash(M.nom) & 0xff)
    out = []
    for p, cols in faces:
        nc = []
        for q, c in zip(p, cols):
            n1 = bruit3(q, 30.0, s)
            n2 = bruit3(q, 85.0, s + 1)
            terre = max(0.0, min(1.0, (n1 - 0.44) * 2.6)) * 0.8
            if M.nom != "oss_monticule":
                terre += max(0.0, min(1.0, 1.0 - q.y / max(0.035, haut * 0.35))) * 0.35
            terre = min(1.0, terre)
            g = 0.8 * (0.84 + 0.3 * n2)      # os vieux : plus sombres que l'ivoire de la texture (rampe « ivoire » du squelette ennemi)
            nc.append((min(1.0, c[0] * g * (1 - terre * 0.32)), min(1.0, c[1] * g * 0.9 * (1 - terre * 0.44)),
                       min(1.0, c[2] * g * 0.72 * (1 - terre * 0.6)), c[3]))
        out.append((p, nc))
    res["os"] = out


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
    for v in "abc":
        mods.append(oss_long(v))
    mods.append(oss_monticule())
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
        if M.organique:      # v2 : occlusion à courte portée (orbites, sutures, entre les os), patine ; pas de liserés
            res = M.finir(rayons=16, portee=0.06, force=0.8)
            patiner(res, M)
        else:
            res = aretes.appliquer(M.finir(), bandes=M.bandes, stats=st)
        for mat, faces in M.brute.items():      # C5 : pièces (bord clair en couleur de sommet), hors liserés
            res.setdefault(mat, []).extend(faces)
        sorties.append((M, res))
        for mat, faces in res.items():
            donnees["%s__%s" % (M.nom, mat)] = faces
        base = M.nom.rsplit("_", 1)[0] if M.nom.rsplit("_", 1)[-1] in ("a", "b", "c", "d") and M.nom != "oss_monticule" else M.nom
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
