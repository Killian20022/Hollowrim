# Lots L2 + L3 objets : MODULES DU MOBILIER DE LA CRYPTE ET DE LA GROTTE (coffres, tonneaux, tables, urnes, crânes, os, armes posées,
# gravats, tas d'or, sacs éventrés, monticule d'os ; étagères, lits, râteliers, boucliers muraux, planches de barricade, tringles).
#   blender.exe -b --python objets_donjon.py [-- apercu=<dossier>]      (aperçus Workbench, un PNG par module)
# Sortie : assets/crypte/modules/objets_donjon.dat, MÊME format que crypte_v2.dat (relu par CrypteDecor._charger_modeles en FileAccess :
#   sûr dans le fil de construction, aucun .glb) : [u32 nb objets] puis par objet [u8 long][« module__matiere »][u32 nb sommets]
#   [x y z r g b a float32 ; 3 sommets par triangle, sens trigonométrique vu de l'extérieur].
# Repère = repère Godot (y en haut, +z = face avant), origine au sol au centre de l'emprise (sauf mention). Calcul direct en repère
#   Godot (BVH et bmesh n'ont pas besoin du repère Blender ; seuls les aperçus convertissent).
# Matières = noms des matières de CrypteDecor (bois, fer, lame, os, noir, argile, entrelacs, or, jute, laine, parchemin) ;
#   « pierre » / « pierre2 » / « peint » sont remplacées à la pose (mats de modele()). Grotte : seules bois, fer, lame, os, argile, or,
#   parchemin et noir y sont peintes → les modules communs crypte + grotte n'utilisent qu'elles (entrelacs remplacé par argile).
# Couleur de sommet = ton x occlusion ambiante cuite (rayons) x pied assombri. Budget : 150 à 400 triangles par objet courant.
import bpy, bmesh, math, os, random, struct, sys
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
DAT = os.path.join(BASE, "assets", "crypte", "modules", "objets_donjon.dat")
TAU = 2 * math.pi
I3 = Matrix.Identity(3)
UP = Vector((0, 1, 0))
TEINTE = {"bois": (1.0, 0.97, 0.93), "fer": (0.92, 0.94, 1.0), "or": (1.0, 0.97, 0.9)}
BUDGET = {"coffre": 550, "tonneau": 400, "table": 550, "urne": 300, "crane": 180, "os_long": 40, "os_court": 30, "arme": 170,
          "gravats": 340, "or_tas": 440, "sac": 200, "os_monticule": 800,
          "etagere_cadre": 420, "etagere_contenu": 820, "etagere_couchee": 300, "lit": 570, "ratelier_cadre": 420, "arme_v": 90,
          "bouclier": 330, "planche": 40, "poteau": 40, "tringle": 100}


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

    def add(self, mat, polys, ton=None, jt=0.0):
        if ton is None:
            ton = self.rg.uniform(0.86, 1.0)
        for p in polys:
            t = ton * (1 + self.rg.uniform(-jt, jt)) if jt else ton
            for i in range(1, len(p) - 1):
                a, b, c = p[0], p[i], p[i + 1]
                if (b - a).cross(c - a).length_squared > 1e-14:
                    self.tris.append((mat, (a.copy(), b.copy(), c.copy()), t))

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
        for (m, p, t) in self.tris:
            n = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
            tg = n.cross(UP if abs(n.y) < 0.9 else V(1, 0, 0)).normalized()
            bt = n.cross(tg)
            cols = []
            for q in p:
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
                k = ao * t * pied
                cols.append((min(1.0, k * te[0]), min(1.0, k * te[1]), min(1.0, k * te[2]), 1.0))
            sortie.setdefault(m, []).append((p, cols))
        return sortie


# ======================================================================= L2 : petit mobilier commun crypte + grotte
def coffre(var):
    """Coffre 0,9 x 0,56 (cerclages 0,6) x 0,64 m, face avant +z. a : couvercle plat ferré, b : couvercle bombé, c : coffre à moulures."""
    M = Module("coffre_" + var, 300 + ord(var))
    rg = M.rg
    M.add("bois", boite(V(0, 0.23, 0), (0.85, 0.4, 0.5)), 0.55)
    for side in (-1, 1):            # planches horizontales devant / derrière
        for i in range(3):
            y = 0.04 + i * 0.135 + 0.0625
            M.add("bois", boite(V(rg.uniform(-0.005, 0.005), y, side * 0.265), (0.88, 0.125, 0.03), Rz(rg.uniform(-0.006, 0.006))), rg.uniform(0.78, 1.0))
    for sx in (-1, 1):
        for i in range(3):
            y = 0.04 + i * 0.135 + 0.0625
            M.add("bois", boite(V(sx * 0.43, y, 0), (0.03, 0.125, 0.5)), rg.uniform(0.75, 0.95))
    if var == "b":                  # couvercle bombé : arc de 6 pans extrudé en x
        arc = [(0.29 * math.cos(math.pi * k / 6), 0.44 + 0.17 * math.sin(math.pi * k / 6)) for k in range(7)]
        for k in range(6):
            (z0, y0), (z1, y1) = arc[k], arc[k + 1]
            q = [V(-0.45, y0, z0), V(0.45, y0, z0), V(0.45, y1, z1), V(-0.45, y1, z1)]
            M.add("bois", [orienter(q, V(0, (y0 + y1) / 2 - 0.44, (z0 + z1) / 2))], rg.uniform(0.82, 1.0))
        for sx in (-1, 1):
            M.add("bois", [orienter([V(sx * 0.45, y, z) for (z, y) in arc], V(sx, 0, 0))], 0.8)
        for dx in (-0.3, 0.3):      # cerclages qui suivent l'arc
            for k in range(6):
                (z0, y0), (z1, y1) = arc[k], arc[k + 1]
                e0 = V(0, y0 - 0.44, z0).normalized() * 0.012
                e1 = V(0, y1 - 0.44, z1).normalized() * 0.012
                pts = [V(dx + s * 0.035, y0, z0) + e0 * f for s in (-1, 1) for f in (0, 1)] + [V(dx + s * 0.035, y1, z1) + e1 * f for s in (-1, 1) for f in (0, 1)]
                M.add("fer", hull(pts), 0.62)
        haut = 0.62
    elif var == "a":
        M.add("bois", boite_ch(V(0, 0.49, 0), (0.92, 0.09, 0.58), 0.014), 0.92)
        M.add("bois", boite(V(0, 0.55, 0), (0.86, 0.035, 0.4)), 0.8)
        haut = 0.535
    else:
        M.add("bois", boite_ch(V(0, 0.475, 0), (0.94, 0.07, 0.6), 0.012), 0.9)
        M.add("bois", boite_ch(V(0, 0.53, 0), (0.84, 0.05, 0.48), 0.012), 0.82)
        haut = 0.51
    for dx in (-0.3, 0.3):          # cerclages verticaux devant / derrière (+ dessus pour les couvercles plats)
        for side in (-1, 1):
            M.add("fer", boite(V(dx, 0.235, side * 0.287), (0.07, 0.43, 0.014)), 0.6)
        if var != "b":
            M.add("fer", boite(V(dx, haut + 0.006, 0), (0.07, 0.012, 0.6 if var == "a" else 0.62)), 0.62)
            M.add("fer", boite(V(dx, haut - 0.04, 0.297 if var == "a" else 0.305), (0.07, 0.09, 0.012)), 0.62)
        for y in (0.1, 0.3):        # rivets
            M.add("fer", hull([V(dx + sx * 0.012, y + sy * 0.012, 0.294) for sx in (-1, 1) for sy in (-1, 1)] + [V(dx, y, 0.304)]), 0.8)
    M.add("fer", boite(V(0, 0.4, 0.293), (0.11, 0.15, 0.012)), 0.7)        # moraillon et serrure
    M.add("fer", boite_ch(V(0, 0.35, 0.305), (0.09, 0.08, 0.025), 0.006), 0.5)
    M.add("noir", boite(V(0, 0.35, 0.3185), (0.012, 0.03, 0.002)), 1.0)
    if var == "c":                  # équerres de coin et socle de bois
        for sx in (-1, 1):
            for sz in (-1, 1):
                M.add("fer", boite(V(sx * 0.425, 0.24, sz * 0.284), (0.06, 0.44, 0.018)), 0.55)
                M.add("fer", boite(V(sx * 0.448, 0.24, sz * 0.25), (0.018, 0.44, 0.06)), 0.55)
        M.add("bois", boite(V(0, 0.022, 0), (0.92, 0.044, 0.58)), 0.6)
    else:
        M.add("fer", boite(V(0, 0.025, 0), (0.93, 0.05, 0.59)), 0.5)
        for sx in (-1, 1):          # poignées latérales
            M.add("fer", poutre(V(sx * 0.452, 0.36, -0.07), V(sx * 0.452, 0.36, 0.07), 0.018, 0.022), 0.6)
    return M


def tonneau(var):
    """Tonneau r 0,40 x h 1,0 : 10 douelles (tons alternés), jable et fond, cercles de fer."""
    M = Module("tonneau_" + var, 400 + ord(var))
    prof = [(0.3, 0.0), (0.355, 0.18), (0.392, 0.38), (0.4, 0.5), (0.392, 0.62), (0.355, 0.82), (0.3, 1.0)]
    n = 10
    rot = 0.3 * (ord(var) - 97)
    M.rev("bois", prof, n, rot=rot, caps=(False, False), ton=0.9, jt=0.12)
    M.rev("bois", [(0.3, 1.0), (0.282, 1.0), (0.282, 0.965), (0.0, 0.965)], n, rot=rot, caps=(False, False), ton=0.7)

    def r_a(y):
        for (r0, y0), (r1, y1) in zip(prof, prof[1:]):
            if y0 <= y <= y1:
                return r0 + (r1 - r0) * (y - y0) / (y1 - y0)
        return prof[-1][0]
    cercles = {"a": [0.07, 0.19, 0.81, 0.93], "b": [0.1, 0.36, 0.64, 0.9], "c": [0.09, 0.5, 0.91]}[var]
    for y in cercles:
        w = 0.05 if var != "b" else 0.04
        ra, rb = r_a(y - w / 2) + 0.009, r_a(y + w / 2) + 0.009
        M.rev("fer", [(ra, y - w / 2), (rb, y + w / 2), (rb - 0.016, y + w / 2)], n, rot=rot, caps=(False, False), ton=0.6)
    if var == "b":                  # couvercle de planches et cannelle
        for dz in (-0.1, 0.1):
            M.add("bois", boite(V(0, 0.975, dz), (0.5, 0.022, 0.06)), 0.85)
        M.add("fer", cylindre(V(0, 0.28, 0.36), V(0, 0.28, 0.42), 0.02, 6), 0.55)
        M.add("fer", boite(V(0, 0.255, 0.41), (0.024, 0.05, 0.024)), 0.5)
    if var == "c":                  # bonde au sommet, douelle fendue
        M.add("noir", disque(V(0.12, 0.967, 0.05), 0.03, 6), 1.0)
        M.add("bois", cylindre(V(0.12, 0.965, 0.05), V(0.12, 0.99, 0.05), 0.028, 6), 0.6)
    return M


def table(var):
    """Table 1,1 x 0,65 x 0,8 : plateau de 3 planches ; a : pieds carrés et ceinture, b : tréteaux, c : pieds écartés et entretoises."""
    M = Module("table_" + var, 500 + ord(var))
    rg = M.rg
    w = (0.65 - 0.014) / 3
    for i in range(3):
        z = -0.325 + w / 2 + i * (w + 0.007)
        M.add("bois", boite_ch(V(rg.uniform(-0.01, 0.01), 0.7575 + rg.uniform(-0.003, 0.003), z), (1.1 - rg.uniform(0, 0.025), 0.065, w), 0.008), rg.uniform(0.82, 1.0))
    for sx in (-0.42, 0.42):        # traverses sous le plateau
        M.add("bois", boite(V(sx, 0.705, 0), (0.07, 0.04, 0.58)), 0.6)
    if var == "a":
        for sx in (-0.47, 0.47):
            for sz in (-0.25, 0.25):
                M.add("bois", hull([V(sx + a * 0.04, 0.685, sz + b * 0.04) for a in (-1, 1) for b in (-1, 1)] + [V(sx + a * 0.032, 0, sz + b * 0.032) for a in (-1, 1) for b in (-1, 1)]), 0.85)
        for sz in (-0.25, 0.25):
            M.add("bois", boite(V(0, 0.64, sz), (0.86, 0.09, 0.03)), 0.7)
        M.add("bois", boite(V(0, 0.2, 0), (0.9, 0.05, 0.05)), 0.75)
        for sx in (-0.47, 0.47):
            M.add("bois", boite(V(sx, 0.2, 0), (0.05, 0.05, 0.46)), 0.75)
    elif var == "b":
        for sx in (-0.42, 0.42):
            M.add("bois", boite_ch(V(sx, 0.665, 0), (0.09, 0.04, 0.56), 0.008), 0.75)
            for sz in (-1, 1):
                M.add("bois", poutre(V(sx, 0.04, sz * 0.27), V(sx, 0.65, sz * 0.15), 0.07, 0.065, up=V(1, 0, 0)), 0.85)
            M.add("bois", boite_ch(V(sx, 0.025, 0), (0.09, 0.05, 0.62), 0.008), 0.7)
        M.add("bois", boite(V(0, 0.32, 0), (0.94, 0.06, 0.05)), 0.8)
        for sx in (-0.47, 0.47):
            M.add("bois", boite(V(sx, 0.32, 0), (0.03, 0.09, 0.025)), 0.6)
    else:
        for sx in (-1, 1):
            for sz in (-1, 1):
                M.add("bois", poutre(V(sx * 0.5, 0.0, sz * 0.27), V(sx * 0.44, 0.69, sz * 0.22), 0.075, 0.075), 0.85)
            M.add("bois", boite(V(sx * 0.48, 0.18, 0), (0.05, 0.055, 0.54)), 0.75)
        M.add("bois", boite(V(0, 0.24, 0), (0.94, 0.05, 0.05)), 0.75)
        M.add("fer", boite(V(0.2, 0.7915, -0.2), (0.06, 0.003, 0.24)), 0.5)
    # sur le plateau : feuillet et vaisselle d'étain
    M.add("parchemin", boite(V(-0.25, 0.793, 0.05), (0.3, 0.006, 0.22), Ry(0.2)), 0.95)
    M.rev("fer", [(0.07, 0.79), (0.1, 0.795), (0.115, 0.806), (0.1, 0.806), (0.0, 0.8)], 8, c=V(0.28, 0, -0.08), ton=0.75)
    if var != "b":
        M.rev("fer", [(0.04, 0.79), (0.06, 0.8), (0.07, 0.812), (0.06, 0.812), (0.0, 0.8)], 8, c=V(0.38, 0, 0.14), ton=0.7)      # écuelle (plateau ≤ 0,815 : les bougies s'y posent)
    else:
        M.rev("fer", [(0.05, 0.79), (0.07, 0.797), (0.085, 0.805), (0.07, 0.805), (0.0, 0.8)], 8, c=V(0.36, 0, 0.14), ton=0.75)
    return M


def urne(var):
    """Urne (e = 1 : r 0,25, h 0,56) : a : panse et anses, b : jarre à couvercle, c : vase élancé. Bandeau « entrelacs » sur la panse."""
    M = Module("urne_" + var, 600 + ord(var))
    if var == "a":
        prof = [(0.13, 0.0), (0.2, 0.08), (0.235, 0.15), (0.25, 0.22), (0.24, 0.29), (0.21, 0.4), (0.12, 0.5), (0.14, 0.555), (0.105, 0.555), (0.1, 0.5)]
        mats = ["argile", "argile", "entrelacs", "entrelacs", "argile", "argile", "argile", "argile", "argile"]
        M.rev("argile", prof, 12, caps=(False, False), mats=mats, ton=0.92, jt=0.04)
        M.add("noir", disque(V(0, 0.5, 0), 0.1, 12), 1.0)
        for sx in (-1, 1):
            a, b, c = V(sx * 0.2, 0.41, 0), V(sx * 0.2, 0.5, 0), V(sx * 0.13, 0.52, 0)
            M.add("argile", poutre(a, b, 0.025, 0.02, up=V(0, 0, 1)), 0.85)
            M.add("argile", poutre(b, c, 0.025, 0.02, up=V(0, 0, 1)), 0.85)
    elif var == "b":
        prof = [(0.15, 0.0), (0.22, 0.06), (0.245, 0.14), (0.25, 0.2), (0.235, 0.27), (0.16, 0.36), (0.15, 0.4), (0.172, 0.42)]
        mats = ["argile", "argile", "entrelacs", "entrelacs", "argile", "argile", "argile"]
        M.rev("argile", prof, 12, caps=(False, False), mats=mats, ton=0.9, jt=0.04)
        M.rev("argile", [(0.172, 0.42), (0.17, 0.435), (0.12, 0.47), (0.04, 0.485), (0.035, 0.515), (0.045, 0.53), (0.0, 0.535)], 12, ton=0.8)
    else:
        prof = [(0.1, 0.0), (0.16, 0.06), (0.21, 0.16), (0.23, 0.24), (0.215, 0.31), (0.16, 0.39), (0.09, 0.46), (0.08, 0.5), (0.115, 0.555), (0.085, 0.555), (0.075, 0.52)]
        mats = ["argile", "argile", "entrelacs", "entrelacs", "argile", "argile", "argile", "argile", "argile", "argile"]
        M.rev("argile", prof, 12, caps=(False, False), mats=mats, ton=0.95, jt=0.04)
        M.add("noir", disque(V(0, 0.52, 0), 0.075, 12), 1.0)
    return M


def crane(var):
    """Crâne (0,17 x 0,22 x 0,2), face +z ; a : avec mâchoire, b : sans mâchoire (posé de travers)."""
    M = Module("crane_" + var, 700 + ord(var))
    R = Rx(-0.18) if var == "b" else I3
    o = V(0, 0.035 if var == "a" else 0.012, 0)
    T = lambda p: o + R @ p
    M.rev("os", [(0.055, 0.0), (0.083, 0.04), (0.092, 0.09), (0.08, 0.14), (0.045, 0.172), (0.0, 0.182)], 8, c=o + R @ V(0, 0, -0.012), R=R, ech=(0.85, 1.08), caps=(True, False), ton=0.95)
    face = [T(V(sx * 0.052, 0.112, 0.068)) for sx in (-1, 1)] + [T(V(sx * 0.046, 0.05, 0.084)) for sx in (-1, 1)] + \
           [T(V(sx * 0.03, 0.012, 0.088)) for sx in (-1, 1)] + [T(V(sx * 0.055, 0.02, 0.02)) for sx in (-1, 1)] + [T(V(sx * 0.065, 0.11, 0.02)) for sx in (-1, 1)]
    M.add("os", hull(face), 0.9)
    M.add("os", boite(T(V(0, 0.125, 0.072)), (0.125, 0.022, 0.03), R), 1.0)          # arcades
    for sx in (-1, 1):
        M.add("os", boite(T(V(sx * 0.062, 0.085, 0.045)), (0.028, 0.024, 0.06), R), 0.88)      # pommettes
        M.add("noir", hull([T(V(sx * 0.03 + math.cos(TAU * k / 6) * 0.016, 0.1 + math.sin(TAU * k / 6) * 0.014, 0.086)) for k in range(6)] + [T(V(sx * 0.03, 0.1, 0.07))]), 1.0)
    M.add("noir", hull([T(V(-0.011, 0.062, 0.091)), T(V(0.011, 0.062, 0.091)), T(V(0, 0.087, 0.09)), T(V(0, 0.07, 0.08))]), 1.0)
    M.add("os", boite(T(V(0, 0.022, 0.087)), (0.058, 0.014, 0.012), R), 1.0)          # dents
    if var == "a":
        M.add("os", hull([V(sx * 0.044, 0.0, 0.075) for sx in (-1, 1)] + [V(sx * 0.052, 0.0, -0.005) for sx in (-1, 1)] +
                          [V(sx * 0.054, 0.042, -0.01) for sx in (-1, 1)] + [V(sx * 0.038, 0.03, 0.082) for sx in (-1, 1)]), 0.8)
    return M


def os_long(var):
    """Os long couché, 0,3 m le long de x (étiré à la pose), 4 cm d'épaisseur ; a : fémur, b : côte courbe, c : humérus brisé."""
    M = Module("os_long_" + var, 800 + ord(var))
    rg = M.rg
    if var == "b":
        pts = [V(-0.15 + 0.1 * k, 0.012, 0.05 * math.sin(math.pi * k / 3) - 0.025) for k in range(4)]
        for a, b in zip(pts, pts[1:]):
            M.add("os", poutre(a, b, 0.022, 0.012), rg.uniform(0.85, 1.0))
        return M
    M.add("os", cylindre(V(-0.12, 0.018, 0), V(0.12, 0.018, 0), 0.014, 5, 0.012), 0.95)
    for sx, r in ((-1, 0.028), (1, 0.024 if var == "a" else 0.016)):
        c = V(sx * 0.135, 0.022, 0)
        pts = [c + V(rg.uniform(-0.6, 0.6) * r, rg.uniform(-0.8, 0.8) * r, (k - 2.5) / 2.5 * r * 1.2) for k in range(6)]
        if var == "c" and sx > 0:
            pts = [c + V(rg.uniform(-0.8, 0.4) * r, rg.uniform(-0.6, 0.6) * r, rg.uniform(-1, 1) * r) for k in range(5)]
        M.add("os", hull(pts), 0.9)
    return M


def os_court(var):
    """Fragment (0,07 x 0,05 x 0,07) : a : vertèbre, b : éclat de bassin."""
    M = Module("os_court_" + var, 900 + ord(var))
    rg = M.rg
    if var == "a":
        M.add("os", cylindre(V(0, 0.0, 0), V(0, 0.03, 0), 0.026, 6), 0.95)
        M.add("os", hull([V(-0.008, 0.01, 0.02), V(0.008, 0.01, 0.02), V(0, 0.035, 0.022), V(0, 0.02, 0.06), V(-0.03, 0.02, 0.0), V(0.03, 0.02, 0.0)]), 0.9)
    else:
        M.add("os", hull([V(rg.uniform(-0.04, 0.04), rg.uniform(0, 0.03), rg.uniform(-0.04, 0.04)) for _ in range(8)] + [V(0, 0.0, 0)]), 0.88)
    return M


def arme(var):
    """Arme couchée au sol, lame vers +x (repère de l'ancienne arme : garde à x = 0,03). a : épée, b : hache, c : seax brisé."""
    M = Module("arme_" + var, 1000 + ord(var))
    if var == "b":
        M.add("bois", cylindre(V(-0.26, 0.018, 0), V(0.64, 0.018, 0), 0.017, 6), 0.85)
        M.add("fer", hull([V(0.52, 0.004, -0.035), V(0.63, 0.004, -0.035), V(0.52, 0.034, -0.035), V(0.63, 0.034, -0.035),
                           V(0.5, 0.008, 0.03), V(0.65, 0.008, 0.03), V(0.5, 0.03, 0.03), V(0.65, 0.03, 0.03)]), 0.7)
        M.add("lame", hull([V(0.5, 0.01, 0.03), V(0.65, 0.01, 0.03), V(0.5, 0.028, 0.03), V(0.65, 0.028, 0.03),
                            V(0.42, 0.014, 0.115), V(0.7, 0.014, 0.115), V(0.42, 0.024, 0.115), V(0.7, 0.024, 0.115)]), 0.95)
        for x in (-0.12, -0.2):
            M.add("fer", cylindre(V(x, 0.018, 0), V(x + 0.025, 0.018, 0), 0.02, 6), 0.55)
        return M
    long = 0.86 if var == "a" else 0.55
    M.add("lame", hull([V(0.05, 0.006, s * 0.038) for s in (-1, 1)] + [V(0.05, 0.02, s * 0.038) for s in (-1, 1)] +
                       [V(long - 0.16, 0.006, s * 0.032) for s in (-1, 1)] + [V(long - 0.16, 0.02, s * 0.032) for s in (-1, 1)] +
                       [V(long, 0.013, 0.0 if var == "a" else 0.02), V(0.3, 0.025, 0.0)]), 0.95)
    if var == "c":
        M.add("lame", hull([V(0.66, 0.006, 0.05), V(0.66, 0.02, 0.05), V(0.75, 0.006, 0.09), V(0.75, 0.02, 0.09), V(0.8, 0.013, 0.07), V(0.7, 0.006, 0.11)]), 0.85)
    M.add("fer", boite_ch(V(0.03, 0.018, 0), (0.045, 0.03, 0.24 if var == "a" else 0.13), 0.008), 0.65)
    M.add("bois", cylindre(V(-0.19, 0.018, 0), V(0.01, 0.018, 0), 0.016, 6), 0.75)
    for x in (-0.15, -0.09, -0.03):
        M.add("fer", cylindre(V(x, 0.018, 0), V(x + 0.012, 0.018, 0), 0.0175, 6), 0.5)
    M.add("fer", hull([V(-0.21 + a * 0.028, 0.02 + b * 0.019, c * 0.034) for a in (-1, 0.6) for b in (-1, 1) for c in (-1, 1)] + [V(-0.245, 0.02, 0)]), 0.7)
    return M


def gravats(var):
    """Tas de gravats (r = 1, h = 0,7, mis à la taille) : tertre de blocaille, moellons tombés, éclats. pierre / pierre2 remplacées à la pose."""
    M = Module("gravats_" + var, 1100 + ord(var))
    rg = M.rg
    M.add("pierre", tertre(0.88, 0.62, rg, 9), 0.6)
    for k in range(11):
        an = rg.uniform(0, TAU)
        rr = rg.uniform(0.2, 0.95)
        t = rg.uniform(0.16, 0.34)
        y = surface_tertre(rr, 0.88, 0.62) + t * 0.15
        M.add("pierre" if k % 2 == 0 else "pierre2", bloc_irr(V(math.cos(an) * rr, y, math.sin(an) * rr), (t * 1.4, t * 0.75, t), rg, 0.22,
                                                              Ry(rg.uniform(0, TAU)) @ Rx(rg.uniform(-0.4, 0.4))), rg.uniform(0.7, 1.0))
    for k in range(9):
        an = rg.uniform(0, TAU)
        rr = rg.uniform(0.85, 1.05)
        t = rg.uniform(0.06, 0.13)
        M.add("pierre2", bloc_irr(V(math.cos(an) * rr, t * 0.3, math.sin(an) * rr), (t * 1.3, t * 0.7, t), rg, 0.3, Ry(rg.uniform(0, TAU))), rg.uniform(0.65, 0.95))
    return M


def or_tas(var):
    """Tas d'or (r 0,6, h 0,3, mis à la taille) : monceau de pièces, pièces éparses ; a : coupe, b : couronne, c : plat et lingots."""
    M = Module("or_tas_" + var, 1200 + ord(var))
    rg = M.rg
    M.add("or", tertre(0.58, 0.28, rg, 10, 0.1), 0.85)
    for k in range(2):
        an = rg.uniform(0, TAU)
        sat = tertre(0.2, 0.11, rg, 6, 0.15)
        M.add("or", [[p + V(math.cos(an) * 0.5, 0, math.sin(an) * 0.5) for p in poly] for poly in sat], 0.8)
    for k in range(26):             # pièces posées sur le monceau
        an = rg.uniform(0, TAU)
        rr = rg.uniform(0.05, 0.62)
        y = surface_tertre(min(rr, 0.58), 0.58, 0.28) + 0.006 if rr < 0.58 else 0.004
        M.add("or", disque(V(math.cos(an) * rr, y, math.sin(an) * rr), rg.uniform(0.022, 0.03), 6, Rx(rg.uniform(-0.5, 0.5)) @ Rz(rg.uniform(-0.5, 0.5))), rg.uniform(0.8, 1.0))
    if var == "a":
        M.rev("or", [(0.05, 0.2), (0.055, 0.21), (0.012, 0.23), (0.012, 0.3), (0.06, 0.34), (0.07, 0.42), (0.064, 0.42), (0.0, 0.37)], 8, c=V(0.12, 0, 0.05), ton=0.95)
    elif var == "b":
        for k in range(8):
            a0, a1 = TAU * k / 8, TAU * (k + 1) / 8
            M.add("or", poutre(V(math.cos(a0) * 0.1, 0.27, math.sin(a0) * 0.1), V(math.cos(a1) * 0.1, 0.27, math.sin(a1) * 0.1), 0.014, 0.04), 1.0)
            M.add("or", hull([V(math.cos(a0) * 0.1, 0.29, math.sin(a0) * 0.1) + V(s * 0.012, 0, t * 0.012) for s in (-1, 1) for t in (-1, 1)] + [V(math.cos(a0) * 0.1, 0.33, math.sin(a0) * 0.1)]), 1.0)
    else:
        M.rev("or", [(0.0, 0.0), (0.16, 0.0), (0.2, 0.025), (0.19, 0.03), (0.0, 0.012)], 10, c=V(0.62, 0, -0.2), R=Rx(0.08), ton=0.85)
        for k in range(3):
            M.add("or", boite_ch(V(-0.62 + k * 0.03, 0.025 + k * 0.045, 0.15 + k * 0.01), (0.16, 0.045, 0.07), 0.01, Ry(0.3 + k * 0.4)), 0.95)
    return M


def sac(var):
    """Sac de toile éventré couché (0,55 x 0,34 x 0,22), ouverture vers +x ; pan de toile arraché devant."""
    M = Module("sac_" + var, 1300 + ord(var))
    rg = M.rg
    R = Rz(-math.pi / 2) if var == "a" else Ry(0.5) @ Rz(-math.pi / 2)
    prof = [(0.02, -0.27), (0.09, -0.25), (0.15, -0.16), (0.17, -0.02), (0.16, 0.12), (0.13, 0.22), (0.12, 0.26), (0.09, 0.24)]
    M.rev("jute", prof, 8, c=V(0, 0.105, 0), R=R, ech=(0.62, 1.0), caps=(True, False), ton=0.9, jt=0.08)
    bouche = [V(0, 0.105, 0) + R @ V(math.cos(TAU * k / 8) * 0.085 * 0.62, 0.235, math.sin(TAU * k / 8) * 0.085) for k in range(8)]
    M.add("noir", [orienter(bouche, R @ UP)], 1.0)
    # pan arraché : toile froissée posée au sol
    pts = []
    for i in range(4):
        for j in range(3):
            pts.append(V(0.05 + i * 0.13, 0.008 + rg.uniform(0, 0.025) * (i % 2), 0.08 + j * 0.12))
    for i in range(3):
        for j in range(2):
            q = [pts[i * 3 + j], pts[(i + 1) * 3 + j], pts[(i + 1) * 3 + j + 1], pts[i * 3 + j + 1]]
            M.add("jute", [orienter(q, UP)], rg.uniform(0.75, 0.95))
    return M


def os_monticule():
    """Monticule d'os (r 0,9, h 0,6) : noyau sombre couvert d'os longs couchés selon la pente."""
    M = Module("os_monticule", 1400)
    rg = M.rg
    an_ = ((1.0, 0.0), (0.85, 0.4), (0.55, 0.8), (0.2, 1.0))
    M.add("os", tertre(0.86, 0.56, rg, 10, 0.08, an_), 0.5)
    for k in range(46):
        u = rg.random()
        rr = 0.86 * math.sqrt(u) * 0.97
        an = rg.uniform(0, TAU)
        y = surface_tertre(rr, 0.86, 0.56, an_) + 0.012
        rad = V(math.cos(an), 0, math.sin(an))
        tg = V(-rad.z, 0, rad.x)
        d = (tg * math.cos(rg.uniform(-0.8, 0.8)) + rad * rg.uniform(-0.4, 0.4)).normalized()
        L = rg.uniform(0.18, 0.36)
        c = rad * rr + V(0, y, 0)
        a, b = c - d * L / 2, c + d * L / 2
        pente = 0.56 / 0.86 * 1.2
        a.y = max(0.01, surface_tertre(min(0.86, Vector((a.x, 0, a.z)).length), 0.86, 0.56, an_) + 0.012)
        b.y = max(0.01, surface_tertre(min(0.86, Vector((b.x, 0, b.z)).length), 0.86, 0.56, an_) + 0.012)
        r = rg.uniform(0.012, 0.018)
        pts = [a, b]
        nn = d.cross(UP).normalized()
        for p, s in ((a, 1.9), (b, 1.6)):
            pts += [p + nn * r * s, p - nn * r * s, p + UP * r * s * 0.9]
        M.add("os", hull(pts + [a.lerp(b, 0.5) + UP * r]), rg.uniform(0.78, 1.0))
    return M


# ======================================================================= L3 : mobilier de bois et tissus de la crypte
def etagere_cadre(var):
    """Bâti d'étagère 1,8 x 2,0 x 0,34 (mis à la taille), dos vers -z : montants, 4 rayons, dos de planches ; b : corniche et pieds."""
    M = Module("etagere_cadre_" + var, 2000 + ord(var))
    rg = M.rg
    for sx in (-1, 1):
        M.add("bois", boite_ch(V(sx * 0.9, 1.0, 0), (0.07, 2.0, 0.34), 0.012), 0.85)
    for y in (0.05, 0.7, 1.35, 1.97):
        M.add("bois", boite(V(0, y, 0), (1.76, 0.05, 0.33)), rg.uniform(0.82, 0.98))
        M.add("bois", boite(V(0, y - 0.035, 0.155), (1.76, 0.03, 0.025)), 0.6)
    for i in range(5):
        x = -0.88 + 0.176 + i * 0.352
        M.add("bois", boite(V(x + rg.uniform(-0.004, 0.004), 1.0, -0.155), (0.345, 1.96, 0.022)), rg.uniform(0.55, 0.75))
    if var == "b":
        M.add("bois", boite_ch(V(0, 2.03, 0.01), (1.9, 0.06, 0.36), 0.012), 0.8)
        for sx in (-1, 1):
            M.add("bois", boite(V(sx * 0.9, 0.04, 0.0), (0.1, 0.08, 0.34)), 0.6)
            M.add("fer", boite(V(sx * 0.9, 1.0, 0.172), (0.05, 0.08, 0.008)), 0.55)
    else:
        M.add("bois", boite(V(0, 2.0, -0.135), (1.76, 0.1, 0.03)), 0.7)
    return M


def etagere_contenu(var):
    """Garniture d'étagère (mêmes cotes que le bâti) : livres debout, couchés, rouleaux, coffret ; place libre pour l'urne (x 0,4 à 0,7, 3e rayon)."""
    M = Module("etagere_contenu_" + var, 2100 + ord(var), sol=False)
    rg = M.rg
    for rang, y in enumerate((0.075, 0.725, 1.375)):
        x = -0.84
        fin = 0.36 if rang == 2 else 0.84
        while x < fin:
            choix = rg.random()
            if x + 0.33 > fin:
                choix = 0.0             # fin de rayon : seulement des livres debout
            if choix < 0.55:            # rangée de livres debout
                for _ in range(rg.randint(3, 6)):
                    w = rg.uniform(0.035, 0.065)
                    h = rg.uniform(0.17, 0.27)
                    if x + w > fin:
                        break
                    inc = rg.uniform(-0.05, 0.05)
                    M.add("bois", boite(V(x + w / 2, y + h / 2, 0.02), (w, h, rg.uniform(0.16, 0.22)), Rz(inc)), rg.uniform(0.45, 0.8))
                    if rg.random() < 0.25:
                        M.add("parchemin", [[V(x + w * 0.15, y + 0.01, 0.131), V(x + w * 0.85, y + 0.01, 0.131), V(x + w * 0.85, y + h * 0.9, 0.131), V(x + w * 0.15, y + h * 0.9, 0.131)]], 0.75)
                    x += w + 0.004
                x += rg.uniform(0.03, 0.08)
            elif choix < 0.75:          # pile de livres couchés
                yy = y
                for _ in range(rg.randint(2, 4)):
                    h = rg.uniform(0.035, 0.06)
                    M.add("bois", boite(V(x + 0.11, yy + h / 2, 0.02), (0.2, h, 0.15), Ry(rg.uniform(-0.2, 0.2))), rg.uniform(0.45, 0.8))
                    yy += h
                x += 0.26
            elif choix < 0.92:          # rouleaux
                for k in range(rg.randint(2, 3)):
                    zc = -0.06 + k * 0.07
                    M.add("parchemin", cylindre(V(x, y + 0.03 + (0.05 if k == 2 else 0), zc), V(x + 0.26, y + 0.03 + (0.05 if k == 2 else 0), zc), 0.028, 5), rg.uniform(0.8, 1.0))
                x += 0.32
            else:                       # coffret ferré
                M.add("bois", boite_ch(V(x + 0.1, y + 0.06, 0.0), (0.2, 0.12, 0.14), 0.008), 0.7)
                M.add("fer", boite(V(x + 0.1, y + 0.08, 0.071), (0.04, 0.05, 0.006)), 0.6)
                x += 0.26
    return M


def etagere_couchee(var):
    """Étagère renversée sur le dos (1,8 x 0,8, h 0,42) : flancs couchés, rayons brisés, livres tombés devant."""
    M = Module("etagere_couchee_" + var, 2200 + ord(var))
    rg = M.rg
    M.add("bois", boite(V(0, 0.03, -0.05), (1.76, 0.03, 0.68)), 0.55)        # dos de planches (dessous)
    for i in range(5):
        M.add("bois", boite(V(-0.7 + i * 0.35, 0.05, -0.05 + rg.uniform(-0.01, 0.01)), (0.33, 0.012, 0.68), Ry(rg.uniform(-0.02, 0.02))), rg.uniform(0.6, 0.8))
    for sx in (-1, 1):
        M.add("bois", boite_ch(V(sx * 0.9, 0.2, -0.05), (0.07, 0.34, 0.72), 0.01, Rz(sx * 0.12)), 0.8)
    for k, z in enumerate((-0.32, 0.0, 0.3)):
        if k == 1 and var == "b":       # rayon cassé : deux moitiés de travers
            M.add("bois", boite(V(-0.45, 0.22, z), (0.85, 0.04, 0.05), Rz(0.25)), 0.85)
            M.add("bois", boite(V(0.48, 0.12, z + 0.05), (0.8, 0.04, 0.05), Rz(-0.18) @ Ry(0.15)), 0.85)
        else:
            M.add("bois", boite(V(0, 0.2, z), (1.76, 0.33, 0.05), Rx(0.08 * (k - 1))), rg.uniform(0.75, 0.95))
    for k in range(5):
        an = rg.uniform(-0.6, 0.6)
        M.add("bois", boite(V(rg.uniform(-0.7, 0.7), 0.02 + 0.01 * k, rg.uniform(0.26, 0.31)), (0.2, 0.04, 0.14), Ry(an) @ Rx(rg.uniform(-0.15, 0.15))), rg.uniform(0.45, 0.75))
    return M


def lit(var):
    """Lit de caserne 2,0 x 0,9 (tête vers -x, 0,8 m), paillasse de jute, couverture de laine drapée."""
    M = Module("lit_" + var, 2300 + ord(var))
    rg = M.rg
    for sz in (-1, 1):
        M.add("bois", boite_ch(V(0, 0.3, sz * 0.41), (1.86, 0.11, 0.07), 0.01), 0.85)
        for sx, h in ((-0.95, 0.8), (0.95, 0.52)):
            M.add("bois", boite_ch(V(sx, h / 2, sz * 0.41), (0.09, h, 0.09), 0.012), 0.8)
            if var == "b":
                M.add("bois", hull([V(sx + a * 0.035, h, sz * 0.41 + b * 0.035) for a in (-1, 1) for b in (-1, 1)] + [V(sx, h + 0.08, sz * 0.41)]), 0.8)
    for i, y in enumerate((0.42, 0.56, 0.7)):         # tête
        M.add("bois", boite(V(-0.95, y, 0), (0.05, 0.12, 0.74)), rg.uniform(0.7, 0.9))
    M.add("bois", boite(V(0.95, 0.42, 0), (0.05, 0.16, 0.74)), 0.8)
    for x in (-0.6, 0.0, 0.6):
        M.add("bois", boite(V(x, 0.33, 0), (0.08, 0.04, 0.76)), 0.6)
    M.add("jute", boite_ch(V(0, 0.4, 0), (1.8, 0.12, 0.76), 0.04), 0.9)        # paillasse
    M.add("jute", boite_ch(V(-0.74, 0.49, 0), (0.28, 0.08, 0.5), 0.035, Ry(rg.uniform(-0.15, 0.15))), 0.95)      # traversin
    x0, x1 = (-0.3, 0.88) if var == "a" else (-0.1, 0.9)
    zs = [-0.47, -0.43, -0.3, 0.0, 0.3, 0.43, 0.47]
    ys = [0.3, 0.44, 0.475, 0.485, 0.475, 0.44, 0.3]
    nu = 5
    P = [[V(x0 + (x1 - x0) * i / nu + (rg.uniform(-0.02, 0.02) if 0 < j < 6 else 0), ys[j] + (rg.uniform(0, 0.02) if 1 < j < 5 else 0) - (0.04 if j in (0, 6) and i % 2 else 0), zs[j]) for j in range(7)] for i in range(nu + 1)]
    for i in range(nu):
        for j in range(6):
            q = [P[i][j], P[i + 1][j], P[i + 1][j + 1], P[i][j + 1]]
            zc = (zs[j] + zs[j + 1]) / 2
            M.add("laine", [orienter(q, V(0, 0.4, zc))], 0.92 - 0.12 * (j in (0, 5)))
    for i in (0, nu):                   # tranches de la couverture (épaisseur)
        for j in range(6):
            a, b = P[i][j], P[i][j + 1]
            q = [a, b, b - V(0, 0.015, 0), a - V(0, 0.015, 0)]
            M.add("laine", [orienter(q, V(-1 if i == 0 else 1, 0, 0))], 0.6)
    if var == "b":                      # couverture roulée au pied
        M.add("laine", cylindre(V(0.82, 0.53, -0.3), V(0.82, 0.53, 0.3), 0.06, 6), 0.75)
    return M


def ratelier_cadre(var):
    """Râtelier mural 1,8 x 2,0 (mis à la taille), dos contre le mur (z = 0) : dos de planches, traverses entaillées, montants."""
    M = Module("ratelier_cadre_" + var, 2400 + ord(var))
    rg = M.rg
    for i in range(6):
        M.add("bois", boite(V(-0.75 + i * 0.3 + rg.uniform(-0.004, 0.004), 0.95, 0.0), (0.29, 1.5, 0.04)), rg.uniform(0.55, 0.75))
    for y in (0.55, 1.3):
        M.add("bois", boite_ch(V(0, y, 0.09), (1.74, 0.06, 0.1), 0.008), 0.85)
        if y > 1:
            for k in range(6):
                M.add("bois", boite(V(-0.7 + k * 0.28, y + 0.04, 0.12), (0.03, 0.03, 0.06)), 0.7)
    for sx in (-1, 1):
        M.add("bois", boite_ch(V(sx * 0.9, 0.9, 0.04), (0.08, 1.8, 0.1), 0.012), 0.85)
        M.add("fer", boite(V(sx * 0.86, 1.3, 0.141), (0.1, 0.07, 0.006)), 0.55)
        M.add("fer", boite(V(sx * 0.86, 0.55, 0.141), (0.1, 0.07, 0.006)), 0.55)
    if var == "b":
        M.add("bois", boite_ch(V(0, 1.82, 0.03), (1.86, 0.07, 0.12), 0.012), 0.8)
    return M


def arme_v(var):
    """Arme dressée au râtelier (origine au sol sous l'arme) : a : épée pointe en haut, b : lance, c : hache."""
    M = Module("arme_v_" + var, 2500 + ord(var), sol=False)
    if var == "a":
        M.add("lame", hull([V(s * 0.03, 0.54, t * 0.008) for s in (-1, 1) for t in (-1, 1)] + [V(s * 0.026, 1.36, t * 0.008) for s in (-1, 1) for t in (-1, 1)] + [V(0, 1.48, 0)]), 0.95)
        M.add("fer", boite_ch(V(0, 0.52, 0), (0.2, 0.035, 0.04), 0.008), 0.65)
        M.add("bois", cylindre(V(0, 0.36, 0), V(0, 0.5, 0), 0.016, 6), 0.7)
        M.add("fer", hull([V(a * 0.026, 0.34 + b * 0.022, c * 0.02) for a in (-1, 1) for b in (-1, 1) for c in (-1, 1)]), 0.7)
    elif var == "b":
        M.add("bois", cylindre(V(0, 0.15, 0), V(0, 1.8, 0), 0.02, 6), 0.75)
        M.add("lame", hull([V(s * 0.035, 1.82, t * 0.008) for s in (-1, 1) for t in (-1, 1)] + [V(0, 2.01, 0), V(0, 1.76, 0)]), 0.95)
        M.add("fer", cylindre(V(0, 1.72, 0), V(0, 1.82, 0), 0.025, 6), 0.6)
    else:
        M.add("bois", cylindre(V(0, 0.35, 0), V(0, 1.55, 0), 0.02, 6), 0.75)
        M.add("lame", hull([V(0.02, 1.4, t * 0.012) for t in (-1, 1)] + [V(0.02, 1.52, t * 0.012) for t in (-1, 1)] +
                           [V(0.17, 1.33, t * 0.005) for t in (-1, 1)] + [V(0.17, 1.57, t * 0.005) for t in (-1, 1)]), 0.9)
        M.add("fer", boite(V(0, 1.46, 0), (0.05, 0.12, 0.04)), 0.6)
    return M


def _clip_x(poly, x0, x1):
    def clip(pts, x, garde):
        out = []
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            ia, ib = garde(a[0]), garde(b[0])
            if ia:
                out.append(a)
            if ia != ib:
                t = (x - a[0]) / (b[0] - a[0])
                out.append((x, a[1] + (b[1] - a[1]) * t))
        return out
    p = clip(poly, x0, lambda v: v >= x0)
    return clip(p, x1, lambda v: v <= x1) if p else []


def bouclier(var):
    """Bouclier rond r 0,32 accroché au mur (dos à z = 0, face +z, origine au centre) : planches (« peint » teinté à la pose), cerclage, umbo."""
    M = Module("bouclier_" + var, 2600 + ord(var), sol=False)
    rg = M.rg
    n = 16
    cercle = [(math.cos(TAU * k / n) * 0.31, math.sin(TAU * k / n) * 0.31) for k in range(n)]
    nb = 5
    for i in range(nb):
        x0, x1 = -0.31 + i * 0.124, -0.31 + (i + 1) * 0.124
        pl = _clip_x(cercle, x0 + 0.002, x1 - 0.002)
        if len(pl) < 3:
            continue
        mat = "peint" if (var != "b" or i % 2 == 0) else "bois"
        if var == "c" and i == 4:
            mat = "bois"
        zf = 0.035 + rg.uniform(-0.002, 0.002)
        av = [V(x, y, zf) for x, y in pl]
        ar = [V(x, y, 0.012) for x, y in pl]
        ton = rg.uniform(0.75, 0.95)
        M.add(mat, [orienter(av, V(0, 0, 1))], ton)
        for k in range(len(pl)):
            a, b = av[k], av[(k + 1) % len(pl)]
            c2, d = ar[(k + 1) % len(pl)], ar[k]
            mid = (a + b) / 2
            M.add(mat, [orienter([a, b, c2, d], V(mid.x, mid.y, 0))], ton * 0.7)
    if var != "c":                      # cerclage de fer
        for k in range(12):
            a0, a1 = TAU * k / 12, TAU * (k + 1) / 12
            pts = [V(math.cos(a) * r, math.sin(a) * r, z) for a in (a0, a1) for r in (0.29, 0.325) for z in (0.03, 0.045)]
            M.add("fer", hull(pts), 0.6)
    M.rev("fer", [(0.075, 0.034), (0.072, 0.05), (0.05, 0.072), (0.02, 0.082), (0.0, 0.083)], 8, R=Rx(math.pi / 2), ton=0.75)
    for k in range(6):
        a = TAU * k / 6 + 0.3
        c = V(math.cos(a) * 0.2, math.sin(a) * 0.2, 0.036)
        M.add("fer", hull([c + V(s * 0.01, t * 0.01, 0) for s in (-1, 1) for t in (-1, 1)] + [c + V(0, 0, 0.01)]), 0.8)
    return M


def planche(var):
    """Planche de barricade 1,0 x 0,15 x 0,06 (centrée, étirée à la pose) : bouts éclatés, clous."""
    M = Module("planche_" + var, 2700 + ord(var), sol=False)
    rg = M.rg
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                pts.append(V(sx * (0.5 - (rg.uniform(0, 0.06) if sy > 0 else rg.uniform(0, 0.02))), sy * 0.075, sz * 0.03))
    if var == "c":
        pts.append(V(0.53, 0.0, 0.0))
    M.add("bois", hull(pts), rg.uniform(0.75, 0.95))
    for sx in (-0.42, 0.42):
        M.add("fer", boite(V(sx, 0.0, 0.031), (0.016, 0.016, 0.004)), 0.5)
    return M


def poteau():
    M = Module("poteau", 2800, sol=False)
    rg = M.rg
    M.add("bois", hull([V(sx * 0.05, -0.85, sz * 0.05) for sx in (-1, 1) for sz in (-1, 1)] + [V(sx * 0.048, 0.76, sz * 0.048) for sx in (-1, 1) for sz in (-1, 1)] + [V(0.01, 0.85, 0.0)]), 0.8)
    return M


def tringle(var):
    """Tringle de bannière (longueur 0,99, centrée, étirée à la pose) : hampe ronde, pommeaux de fer, deux pattes vers le mur (-z)."""
    M = Module("tringle_" + var, 2900 + ord(var), sol=False)
    M.add("bois", cylindre(V(-0.47, 0, 0), V(0.47, 0, 0), 0.022, 6), 0.8)
    for sx in (-1, 1):
        if var == "a":
            M.add("fer", hull([V(sx * 0.47, 0, 0) + V(sx * a * 0.05, b * 0.03, c * 0.03) for a in (0, 0.6) for b in (-1, 1) for c in (-1, 1)] + [V(sx * 0.53, 0, 0)]), 0.7)
        else:
            M.add("fer", cylindre(V(sx * 0.47, 0, 0), V(sx * 0.5, 0, 0), 0.03, 6), 0.6)
            M.add("fer", hull([V(sx * 0.5, b * 0.02, c * 0.02) for b in (-1, 1) for c in (-1, 1)] + [V(sx * 0.535, 0, 0)]), 0.7)
        M.add("fer", poutre(V(sx * 0.4, 0, 0), V(sx * 0.4, 0.0, -0.1), 0.02, 0.03), 0.55)
    return M


def _l3():
    mods = []
    for v in "ab":
        mods += [etagere_cadre(v), etagere_couchee(v), lit(v), ratelier_cadre(v), tringle(v)]
    for v in "abc":
        mods += [etagere_contenu(v), arme_v(v), bouclier(v), planche(v)]
    mods.append(poteau())
    return mods


L3 = [_l3]


def construire():
    mods = []
    for v in "abc":
        mods += [coffre(v), tonneau(v), table(v), urne(v), arme(v), gravats(v), or_tas(v), os_long(v)]
    for v in "ab":
        mods += [crane(v), os_court(v), sac(v)]
    mods.append(os_monticule())
    for f in L3:
        mods += f()
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
    for M in mods:
        res = M.finir()
        sorties.append((M, res))
        for mat, faces in res.items():
            donnees["%s__%s" % (M.nom, mat)] = faces
        base = M.nom.rsplit("_", 1)[0] if M.nom.rsplit("_", 1)[-1] in ("a", "b", "c") else M.nom
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
    print("objets donjon : %d modules, %d triangles, %d depassements -> %s" % (len(mods), sum(len(M.tris) for M in mods), depasse, DAT))
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for a in args:
        if a.startswith("apercu="):
            apercus(sorties, a[7:])


main()
