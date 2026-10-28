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
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import aretes      # C1 matières : arête claire / creux sombre en couleur de sommet (sources_blender/scripts/aretes.py)

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
DAT = os.path.join(BASE, "assets", "crypte", "modules", "objets_donjon.dat")
TAU = 2 * math.pi
I3 = Matrix.Identity(3)
UP = Vector((0, 1, 0))
TEINTE = {"bois": (1.0, 0.97, 0.93), "fer": (0.92, 0.94, 1.0), "or": (1.0, 0.97, 0.9)}
BUDGET = {"coffre": 550, "tonneau": 400, "table": 550, "urne": 420, "crane": 180, "os_long": 40, "os_court": 30, "arme": 170,
          "gravats": 480, "or_tas": 1100,
          "micro_eclats": 60, "micro_planche": 60, "micro_os": 50, "micro_cire": 70, "micro_pieces": 30, "micro_chaine": 100, "sac": 200, "os_monticule": 800,
          "etagere_cadre": 420, "etagere_contenu": 820, "etagere_couchee": 300, "lit": 570, "ratelier_cadre": 420, "arme_v": 90,
          "bouclier": 330, "planche": 40, "poteau": 40, "tringle": 100,
          "garniture": 260, "garniture_autel": 520, "garniture_etagere": 700}      # garniture : par objet de table


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


def _ecorner(M, an, larg, y_min, dy, dr=0.0, i0=0):
    """C6 : éclat (lèvre ébréchée) : les sommets du secteur d'angle `an` ± `larg` au-dessus de y_min descendent de dy et rentrent de dr
    (dégradé vers les bords du secteur) ; triangles i0.. seulement (la pièce qu'on vient de tourner)."""
    for j in range(i0, len(M.tris)):
        m, p, t = M.tris[j]
        q = []
        for v in p:
            if v.y > y_min:
                da = abs((math.atan2(v.z, v.x) - an + math.pi) % TAU - math.pi)
                if da < larg:
                    f = 1.0 - (da / larg) ** 2
                    rr = math.hypot(v.x, v.z)
                    k = max(0.0, rr - dr * f) / max(rr, 1e-6)
                    v = V(v.x * k, max(y_min, v.y - dy * f), v.z * k)
            q.append(v)
        M.tris[j] = (m, tuple(q), t)


def _anse(M, pts, w=0.026, h=0.02, ton=0.85):
    """Anse en tronçons de poutre le long d'une polyligne (repère du module)."""
    for a, b in zip(pts, pts[1:]):
        M.add("argile", poutre(a, b, w, h, up=V(0, 0, 1) if abs(a.x) > abs(a.z) else V(1, 0, 0)), ton)


def urne(var):
    """Urne v2 (lot C6 ; e = 1 : r 0,25, h 0,56, MÊME encombrement) : col, lèvre éversée épaisse, bourrelet d'épaule, anses, éclat.
    a : panse à deux anses et lèvre ébréchée, tesson au pied ; b : jarre à couvercle, cordon d'épaule, oreilles, couvercle écorné ;
    c : vase élancé à col haut, lèvre en trompette, anses hautes d'amphore. Bandeau « entrelacs » sur la panse."""
    M = Module("urne_" + var, 600 + ord(var))
    rg = M.rg
    n = 10
    if var == "a":
        prof = [(0.13, 0.0), (0.2, 0.08), (0.235, 0.15), (0.25, 0.22), (0.24, 0.29), (0.21, 0.37), (0.218, 0.385), (0.175, 0.42),
                (0.1, 0.455), (0.092, 0.5), (0.122, 0.528), (0.135, 0.552), (0.112, 0.558), (0.086, 0.535), (0.08, 0.49)]
        mats = ["argile", "argile", "entrelacs", "entrelacs"] + ["argile"] * 10
        M.rev("argile", prof, n, caps=(False, False), mats=mats, ton=0.92, jt=0.04)
        _ecorner(M, rg.uniform(0, TAU), 0.42, 0.49, 0.04, 0.012)
        M.add("noir", disque(V(0, 0.49, 0), 0.08, n), 1.0)
        for sx in (-1, 1):
            _anse(M, [V(sx * 0.2, 0.39, 0), V(sx * 0.243, 0.45, 0), V(sx * 0.215, 0.515, 0), V(sx * 0.1, 0.51, 0)])
        M.add("argile", bloc_irr(V(0.17, 0.008, 0.17), (0.07, 0.014, 0.05), rg, 0.3, Ry(0.7)), 0.8)      # tesson tombé de la lèvre
    elif var == "b":
        prof = [(0.15, 0.0), (0.22, 0.06), (0.245, 0.14), (0.25, 0.2), (0.235, 0.27), (0.2, 0.33), (0.208, 0.345), (0.2, 0.36),
                (0.155, 0.39), (0.15, 0.405), (0.175, 0.418)]
        mats = ["argile", "argile", "entrelacs", "entrelacs"] + ["argile"] * 6
        M.rev("argile", prof, n, caps=(False, False), mats=mats, ton=0.9, jt=0.04)
        i0 = len(M.tris)
        M.rev("argile", [(0.175, 0.418), (0.172, 0.435), (0.12, 0.47), (0.045, 0.485), (0.04, 0.505), (0.052, 0.522), (0.0, 0.532)], n, ton=0.8)
        _ecorner(M, rg.uniform(0, TAU), 0.5, 0.41, 0.012, 0.03, i0)
        for k in range(2):      # oreilles de préhension sur l'épaule
            an = k * math.pi + 0.3
            d, tg = V(math.cos(an), 0, math.sin(an)), V(-math.sin(an), 0, math.cos(an))
            M.add("argile", hull([d * 0.2 + tg * sx * 0.035 + V(0, y, 0) for sx in (-1, 1) for y in (0.3, 0.33)] +
                                 [d * 0.238 + tg * sx * 0.026 + V(0, y, 0) for sx in (-1, 1) for y in (0.305, 0.325)]), 0.82)
    else:
        prof = [(0.1, 0.0), (0.16, 0.06), (0.21, 0.16), (0.23, 0.24), (0.215, 0.31), (0.16, 0.38), (0.168, 0.392), (0.1, 0.43),
                (0.072, 0.47), (0.07, 0.5), (0.1, 0.535), (0.128, 0.556), (0.104, 0.558), (0.08, 0.53), (0.064, 0.5)]
        mats = ["argile", "argile", "entrelacs", "entrelacs"] + ["argile"] * 10
        M.rev("argile", prof, n, caps=(False, False), mats=mats, ton=0.95, jt=0.04)
        _ecorner(M, rg.uniform(0, TAU), 0.36, 0.5, 0.03, 0.01)
        M.add("noir", disque(V(0, 0.5, 0), 0.064, n), 1.0)
        for sx in (-1, 1):
            _anse(M, [V(sx * 0.19, 0.33, 0), V(sx * 0.215, 0.4, 0), V(sx * 0.2, 0.48, 0), V(sx * 0.08, 0.5, 0)], 0.022, 0.018)
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


# ======================================================================= C5 (2026-10-28) : gravats v2, or en pièces, semis micro
# docs INSPIRATION_IGNITE §2.4 / §2.7 / §6 règle 3 : des tas faits de PIÈCES DISTINCTES (blocs taillés cassés à arêtes vives, planches en
# éclisses, pièces lisibles) au lieu de dômes lisses ; une couche de petits débris posée au sol par CrypteV2.semis (scripts/crypte_v2.gd).
def _pts_boite(c, s, R=I3, ch=0.0):
    """Coins d'un pavé (ch > 0 : arêtes abattues, 24 points)."""
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    if ch <= 0.0:
        return [c + R @ V(sx * hx, sy * hy, sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    ch = min(ch, hx * 0.45, hy * 0.45, hz * 0.45)
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                pts += [c + R @ V(sx * (hx - ch), sy * hy, sz * hz), c + R @ V(sx * hx, sy * (hy - ch), sz * hz), c + R @ V(sx * hx, sy * hy, sz * (hz - ch))]
    return pts


def _casser(pts, rg, n=1, prof=(0.12, 0.32), haut=False):
    """Casse un volume convexe : n plans tranchent des coins (les points au-delà sont ramenés sur le plan) -> facettes vives.
    haut : les cassures prennent plutôt le dessus (éclat visible d'en haut)."""
    c = sum(pts, Vector()) / len(pts)
    for _ in range(n):
        d = V(rg.uniform(-1, 1), rg.uniform(0.2, 1.0) if haut else rg.uniform(-0.4, 1.0), rg.uniform(-1, 1)).normalized()
        ext = max((p - c).dot(d) for p in pts)
        lim = ext * (1.0 - rg.uniform(*prof))
        pts = [p if (p - c).dot(d) <= lim else p - d * ((p - c).dot(d) - lim) for p in pts]
    vus, res = set(), []
    for p in pts:
        k = (round(p.x * 2000), round(p.y * 2000), round(p.z * 2000))
        if k not in vus:
            vus.add(k)
            res.append(p)
    return res


def _poser(polys, y0=0.0):
    """Remonte (ou descend) un volume pour que son point le plus bas soit à y0."""
    lo = min(q.y for p in polys for q in p)
    d = V(0, y0 - lo, 0)
    return [[q + d for q in p] for p in polys]


def bloc_taille(c, s, rg, R=I3, ch=0.018, coupes=2, y0=None):
    """Moellon TAILLÉ cassé : pavé chanfreiné (arêtes vives qui accrochent la torche) dont 1 à 3 coins sont emportés."""
    polys = hull(_casser(_pts_boite(c, s, R, ch), rg, coupes, haut=True))
    return _poser(polys, y0) if y0 is not None else polys


def eclat(c, t, rg, R=I3, plat=0.45):
    """Éclat de pierre : 5-6 points (6 à 8 triangles), arêtes vives."""
    pts = [c + R @ V(rg.uniform(-0.5, 0.5) * t, rg.uniform(0.0, plat * 0.3) * t, rg.uniform(-0.5, 0.5) * t) for _ in range(4)]
    pts.append(c + R @ V(rg.uniform(-0.15, 0.15) * t, plat * t, rg.uniform(-0.15, 0.15) * t))
    return _poser(hull(pts), c.y)


def planche_cassee(M, c, L, w, e, an, rg, incl=0.0, ton=None, eclisses=2):
    """Planche cassée couchée (longueur L vers +x local tourné de an) : un bout franc, l'autre en éclisses (pointes de bois)."""
    R = Ry(an) @ Rz(incl)
    ton = rg.uniform(0.6, 0.95) if ton is None else ton
    x1 = L * 0.5 - rg.uniform(0.05, 0.12)
    corps = [c + R @ V(x, y, z) for x in (-L * 0.5, x1) for y in (0.0, e) for z in (-w * 0.5, w * 0.5)]
    M.add("bois", hull(corps), ton)
    for k in range(eclisses):       # éclisses : pointes fines qui dépassent du bout cassé
        z0 = -w * 0.5 + w * (k + 0.5) / eclisses
        lp = rg.uniform(0.05, 0.16)
        pts = [c + R @ V(x1 - 0.01, y, z0 + dz) for y in (0.002, e * 0.8) for dz in (-w * 0.22, w * 0.22)]
        pts.append(c + R @ V(x1 + lp, e * rg.uniform(0.2, 0.6), z0 + rg.uniform(-0.3, 0.3) * w))
        M.add("bois", hull(pts), ton * rg.uniform(0.85, 1.05))


def piece(c, r, R, ton=(0.55, 1.0), n=5):
    """Pièce d'or LISIBLE : disque à n pans en éventail autour du centre ; centre sombre (face, rampe Or terni #7b5a26), bord clair
    (tranche #d3b25c) en couleur de sommet : le bord clair se lit à 3 m sans liseré géométrique. 5 triangles."""
    up = R @ UP
    pts = [c + R @ V(math.cos(TAU * k / n) * r, 0.0, math.sin(TAU * k / n) * r) for k in range(n)]
    tris = []
    for k in range(n):
        a, b = pts[k], pts[(k + 1) % n]
        tri = (c, a, b) if (a - c).cross(b - c).dot(up) >= 0 else (c, b, a)
        tris.append((tri, (ton[0], ton[1], ton[1])))
    return tris


def gravats(var):
    """Tas de gravats v2 (r = 1, h ≈ 0,7, mis à la taille) : PLUS DE DÔME. Gros blocs taillés cassés empilés (silhouette dentelée), moellons
    moyens, planches cassées en éclisses (b : dalle brisée dressée ; c : poutre tombée), traînée d'éclats vers +x ; noyau sombre réduit,
    caché dessous. pierre / pierre2 remplacées à la pose. Tout tient dans r 1,15 (CrypteDecor : emprise r, différé jusqu'à 1,3 r)."""
    M = Module("gravats_" + var, 1100 + ord(var))
    M.sans_dessous = True
    rg = M.rg
    M.add("pierre2", tertre(0.5, 0.2, rg, 7, 0.15), 0.32)          # noyau : 30 % de la hauteur, dans l'ombre des blocs
    a0 = rg.uniform(0, TAU)
    # gros blocs au sol, puis un ou deux par-dessus, basculés
    gros = [(0.3, 0.0, 0.0, (0.62, 0.34, 0.42)), (0.36, 2.3, 0.0, (0.54, 0.3, 0.4)), (0.42, 4.2, 0.0, (0.5, 0.32, 0.36)),
            (0.12, 1.1, 0.24, (0.5, 0.28, 0.38))]
    if var != "a":
        gros.append((0.2, 3.4, 0.2, (0.44, 0.26, 0.34)))
    for k, (rr, da, y0, sz) in enumerate(gros):
        an = a0 + da + rg.uniform(-0.3, 0.3)
        s = tuple(v * rg.uniform(0.88, 1.08) for v in sz)
        R = Ry(rg.uniform(0, TAU)) @ Rx(rg.uniform(-0.18, 0.18) + (0.35 if y0 > 0 else 0.0)) @ Rz(rg.uniform(-0.15, 0.15) + (0.3 if y0 > 0 else 0.0))
        M.add("pierre" if k % 2 == 0 else "pierre2", bloc_taille(V(math.cos(an) * rr, 0, math.sin(an) * rr), s, rg, R, 0.02, 2, y0 - 0.01), rg.uniform(0.78, 1.0))
    # moellons moyens autour et sur les flancs
    for k in range(7 if var == "a" else 6):
        an = a0 + k * TAU / 6 + rg.uniform(-0.4, 0.4)
        rr = rg.uniform(0.5, 0.82)
        t = rg.uniform(0.17, 0.27)
        y0 = 0.0 if rr > 0.62 else rg.uniform(0.05, 0.18)
        R = Ry(rg.uniform(0, TAU)) @ Rx(rg.uniform(-0.5, 0.5)) @ Rz(rg.uniform(-0.4, 0.4))
        M.add("pierre2" if k % 2 else "pierre", bloc_taille(V(math.cos(an) * rr, 0, math.sin(an) * rr), (t * 1.35, t * 0.7, t), rg, R, 0.0, 2, y0 - 0.008), rg.uniform(0.62, 1.0))
    # planches cassées (rampe Bois) posées en travers, appuyées sur les blocs
    npl = {"a": 2, "b": 3, "c": 2}[var]
    for k in range(npl):            # pied au sol, tête sur le tas (bout cassé en l'air, vers le centre)
        an = a0 + 0.8 + k * 2.1 + rg.uniform(-0.3, 0.3)
        rr = rg.uniform(0.62, 0.78)
        L = rg.uniform(0.62, 0.85)
        inc = rg.uniform(0.3, 0.45)
        planche_cassee(M, V(math.cos(an) * rr, L * 0.5 * math.sin(inc) + 0.004, math.sin(an) * rr), L, rg.uniform(0.12, 0.16), 0.03,
                       math.pi - an + rg.uniform(-0.35, 0.35), rg, inc)
    if var == "b":                 # dalle brisée dressée contre le tas
        an = a0 + 3.0
        R = Ry(an) @ Rz(1.05)
        M.add("pierre", bloc_taille(V(math.cos(an) * 0.62, 0, math.sin(an) * 0.62), (0.5, 0.07, 0.42), rg, R, 0.012, 2, -0.01), 0.85)
    if var == "c":                 # poutre tombée, un bout au sol, l'autre sur le tas, bout cassé en éclisses
        an = a0 + 1.6
        d = V(math.cos(an), 0, math.sin(an))
        a_, b_ = d * -0.95 + V(0, 0.08, 0), d * 0.25 + V(0, 0.5, 0)
        M.add("bois", poutre(a_, b_, 0.14, 0.13), 0.7)
        for k in range(3):
            M.add("bois", hull([b_ + V(rg.uniform(-0.05, 0.05), rg.uniform(-0.05, 0.05), rg.uniform(-0.05, 0.05)) for _ in range(4)] + [b_ + d * rg.uniform(0.1, 0.2) + V(0, rg.uniform(-0.04, 0.04), 0)]), 0.75)
    # traînée d'éclats vers +x (1,5 r de long au plus, dans l'emprise différée)
    for k in range(9):
        u = k / 8.0
        x = 0.62 + u * 0.5 + rg.uniform(-0.05, 0.05)
        z = rg.uniform(-0.35, 0.35) * (1.0 - u * 0.6)
        t = rg.uniform(0.05, 0.11) * (1.0 - u * 0.4)
        M.add("pierre2" if k % 3 else "pierre", eclat(V(x, 0, z), t, rg, Ry(rg.uniform(0, TAU))), rg.uniform(0.55, 1.0))
    return M


def or_tas(var):
    """Tas d'or v2 (r 0,6, h 0,3, mis à la taille) : COUCHES DE PIÈCES distinctes de 4,8 cm (bord clair, face sombre, matière « or » :
    reflet ponctuel du lot C1) sur un noyau sombre (les creux entre les pièces descendent au noir de l'or), pièces éparses en traînée,
    piles ; a : coupe, b : couronne, c : plat et lingots."""
    M = Module("or_tas_" + var, 1200 + ord(var))
    M.sans_dessous = True
    rg = M.rg
    R0, H0 = 0.46, 0.26
    an_ = ((1.0, 0.0), (0.78, 0.38), (0.45, 0.78), (0.12, 1.0))
    M.add("or", tertre(R0 * 0.9, H0 * 0.88, rg, 9, 0.1, an_), 0.2)      # noyau sous la surface nominale : les pièces restent dessus
    rp = 0.028
    def sur(rr, an, dy, incl):
        y = surface_tertre(min(rr, R0), R0, H0, an_) + dy if rr < R0 else 0.004 + dy
        c = V(math.cos(an) * rr, y, math.sin(an) * rr)
        pente = math.atan2(H0, R0) * (0.8 if rr < R0 else 0.0)
        R = Ry(-an) @ Rz(-pente) @ Rx(rg.uniform(-incl, incl)) @ Rz(rg.uniform(-incl, incl))
        return c, R
    n_couche = (80, 26)              # deux couches : la 2e décalée, plus haut d'une épaisseur (les pièces se chevauchent)
    for couche, n in enumerate(n_couche):
        for k in range(n):
            rr = R0 * 1.02 * math.sqrt((k + rg.random()) / n)
            an = k * 2.39996 + rg.uniform(-0.3, 0.3) + couche * 1.3
            c, R = sur(rr, an, 0.007 + couche * 0.009, 0.45)
            f = rg.uniform(0.85, 1.0)
            M.add_tons("or", piece(c, rp * rg.uniform(0.92, 1.08), R, (0.5 * f, 1.0 * f)), brut=True)
    for k in range(10):              # pièces éparses en traînée autour du tas
        an = rg.uniform(0, TAU)
        rr = rg.uniform(0.5, 0.78)
        c = V(math.cos(an) * rr, 0.006, math.sin(an) * rr)
        M.add_tons("or", piece(c, rp, Ry(rg.uniform(0, TAU)) @ Rx(rg.uniform(-0.12, 0.12)), (0.5, 0.95)), brut=True)
    for k in range(2):               # piles de pièces au pied du tas
        an = rg.uniform(0, TAU)
        c = V(math.cos(an) * 0.54, 0, math.sin(an) * 0.54)
        h = rg.uniform(0.03, 0.06)
        M.rev("or", [(rp, 0.0), (rp, h)], 6, c=c, ton=0.75)
        M.add_tons("or", piece(c + V(0, h + 0.001, 0), rp, I3, (0.55, 1.0)), brut=True)
    if var == "a":
        M.rev("or", [(0.05, 0.2), (0.055, 0.21), (0.012, 0.23), (0.012, 0.3), (0.06, 0.34), (0.07, 0.42), (0.064, 0.42), (0.0, 0.37)], 8, c=V(0.12, 0, 0.05), ton=0.95)
    elif var == "b":
        for k in range(8):
            a0, a1 = TAU * k / 8, TAU * (k + 1) / 8
            M.add("or", poutre(V(math.cos(a0) * 0.1, 0.25, math.sin(a0) * 0.1), V(math.cos(a1) * 0.1, 0.25, math.sin(a1) * 0.1), 0.014, 0.04), 1.0)
            M.add("or", hull([V(math.cos(a0) * 0.1, 0.27, math.sin(a0) * 0.1) + V(s * 0.012, 0, t * 0.012) for s in (-1, 1) for t in (-1, 1)] + [V(math.cos(a0) * 0.1, 0.31, math.sin(a0) * 0.1)]), 1.0)
    else:
        M.rev("or", [(0.0, 0.0), (0.16, 0.0), (0.2, 0.025), (0.19, 0.03), (0.0, 0.012)], 10, c=V(0.62, 0, -0.2), R=Rx(0.08), ton=0.85)
        for k in range(3):
            M.add("or", boite_ch(V(-0.62 + k * 0.03, 0.025 + k * 0.045, 0.15 + k * 0.01), (0.16, 0.045, 0.07), 0.01, Ry(0.3 + k * 0.4)), 0.95)
    return M


# ----------------------------------------------------------------------- semis micro (C5) : petits objets au sol, 15 à 60 triangles
# Origine au sol au centre ; emprise ≤ 0,3 m de rayon (CrypteV2.semis ne vérifie que ce rayon). Sans collision.
def micro_eclats(var):
    """Éclats de pierre (3-6) d'un bloc tombé ; pierre remplacée à la pose (pierre_v2 des murs)."""
    M = Module("micro_eclats_" + var, 3000 + ord(var))
    M.sans_dessous = True
    M.bandes = "aucune"
    rg = M.rg
    n = {"a": 4, "b": 6, "c": 3}[var]
    for k in range(n):
        an = rg.uniform(0, TAU)
        rr = rg.uniform(0.0, 0.24) if k else 0.0
        t = rg.uniform(0.11, 0.15) if k == 0 else rg.uniform(0.05, 0.1)
        if k == 0:
            M.add("pierre", bloc_taille(V(0, 0, 0), (t, t * 0.55, t * 0.75), rg, Ry(rg.uniform(0, TAU)), 0.0, 2, 0.0), rg.uniform(0.75, 1.0))
            continue
        M.add("pierre", eclat(V(math.cos(an) * rr, 0, math.sin(an) * rr), t, rg, Ry(rg.uniform(0, TAU)), 0.5 if k == 0 else 0.4), rg.uniform(0.6, 1.0))
    if var == "c":                  # un moellon taillé brisé (gros éclat d'angle)
        M.add("pierre", bloc_taille(V(0.12, 0, -0.08), (0.2, 0.1, 0.14), rg, Ry(rg.uniform(0, TAU)), 0.0, 2, 0.0), 0.85)
    return M


def micro_planche(var):
    """Planches cassées au sol : a : une longue + un éclat, b : deux courtes croisées."""
    M = Module("micro_planche_" + var, 3100 + ord(var))
    M.sans_dessous = True
    M.bandes = "aucune"
    rg = M.rg
    if var == "a":
        planche_cassee(M, V(0, 0, 0), 0.62, 0.12, 0.025, 0.0, rg, 0.0, 0.8, 3)
        M.add("bois", eclat(V(0.05, 0, 0.16), 0.07, rg, Ry(0.4), 0.3), 0.7)
    else:
        planche_cassee(M, V(-0.04, 0, 0.02), 0.42, 0.11, 0.025, 0.4, rg, 0.0, 0.75, 2)
        planche_cassee(M, V(0.05, 0.024, -0.02), 0.34, 0.1, 0.022, -0.9, rg, 0.06, 0.62, 2)
    return M


def micro_os(var):
    """Os au sol, agrandis (lisibles) : a : os long à épiphyses + fragment, b : deux côtes courbes + vertèbre."""
    M = Module("micro_os_" + var, 3200 + ord(var))
    M.sans_dessous = True
    M.bandes = "aucune"
    rg = M.rg
    if var == "a":
        a, b = V(-0.17, 0.02, 0.0), V(0.17, 0.02, 0.02)
        M.add("os", cylindre(a, b, 0.016, 5, 0.014), 0.92)
        for p, r in ((a, 0.032), (b, 0.028)):
            M.add("os", hull([p + V(rg.uniform(-0.6, 0.6) * r, rg.uniform(-0.6, 0.6) * r, (j - 2) / 2 * r) for j in range(5)]), 0.88)
        M.add("os", eclat(V(0.06, 0, 0.12), 0.06, rg, Ry(0.7), 0.4), 0.8)
    else:
        for s in (1,):
            pts = [V(-0.13 + 0.135 * j, 0.012 + 0.02 * math.sin(math.pi * j / 2), s * 0.05 + 0.06 * math.sin(math.pi * j / 2)) for j in range(3)]
            for p0, p1 in zip(pts, pts[1:]):
                M.add("os", poutre(p0, p1, 0.022, 0.012), rg.uniform(0.82, 0.98))
        M.add("os", cylindre(V(0.15, 0.0, 0), V(0.15, 0.03, 0), 0.026, 5), 0.9)
    return M


def micro_cire(var):
    """Coulure de cire : flaque irrégulière à bourrelet + chicots de bougie fondue (a : deux, b : un couché). Sans lumière."""
    M = Module("micro_cire_" + var, 3300 + ord(var))
    M.sans_dessous = True
    M.bandes = "aucune"
    rg = M.rg
    n = 8
    rr = [rg.uniform(0.09, 0.15) for _ in range(n)]
    bord = [V(math.cos(TAU * k / n) * rr[k], 0.004, math.sin(TAU * k / n) * rr[k] * 0.8) for k in range(n)]
    haut = [V(p.x * 0.8, 0.012, p.z * 0.8) for p in bord]
    M.add("cire", [orienter(haut, UP)], 0.95)
    for k in range(n):
        a, b = bord[k], bord[(k + 1) % n]
        c, d = haut[(k + 1) % n], haut[k]
        M.add("cire", [orienter([a, b, c, d], (a + b) * 0.5)], 0.75)
    if var == "a":
        for (x, z, h) in ((0.02, -0.01, 0.07), (-0.06, 0.04, 0.035)):
            M.rev("cire", [(0.026, 0.0), (0.018, h), (0.008, h + 0.006)], 5, c=V(x, 0.008, z), ton=0.9)
    else:
        M.add("cire", cylindre(V(-0.08, 0.02, 0.0), V(0.06, 0.02, 0.03), 0.018, 6), 0.85)
    return M


def micro_pieces(var):
    """Pièces isolées (4,8 cm, bord clair) : a : trois éparses, b : cinq dont une sur la tranche contre une autre."""
    M = Module("micro_pieces_" + var, 3400 + ord(var))
    M.sans_dessous = True
    M.bandes = "aucune"
    rg = M.rg
    n = 3 if var == "a" else 5
    for k in range(n):
        an = rg.uniform(0, TAU)
        rr = rg.uniform(0.02, 0.2)
        c = V(math.cos(an) * rr, 0.004 + 0.006 * (k % 2), math.sin(an) * rr)
        R = Ry(rg.uniform(0, TAU)) @ Rx(rg.uniform(-0.15, 0.15))
        if var == "b" and k == n - 1:
            c = V(0.0, 0.026, 0.0)
            R = Rx(1.25)
        M.add_tons("or", piece(c, 0.024, R, (0.5, 1.0)), brut=True)
    return M


def micro_chaine(var):
    """Bout de chaîne au sol (fer, maillons alternés à plat / sur la tranche), a : droit, b : en S."""
    M = Module("micro_chaine_" + var, 3500 + ord(var))
    M.sans_dessous = True
    M.bandes = "aucune"
    rg = M.rg
    n = 6
    for k in range(n):
        u = k - (n - 1) * 0.5
        x = u * 0.075
        z = 0.0 if var == "a" else 0.07 * math.sin(u * 0.8)
        dz = 0.0 if var == "a" else 0.056 * math.cos(u * 0.8)
        an = math.atan2(-dz, 0.075)
        R = Ry(an) @ (Rx(math.pi / 2) if k % 2 else I3)
        c = V(x, 0.012 if not (k % 2) else 0.03, z)
        pts = [c + R @ V(math.cos(TAU * j / 4) * 0.05, e, math.sin(TAU * j / 4) * 0.026) for j in range(4) for e in (-0.009, 0.009)]
        M.add("fer", _poser(hull(pts), 0.0), rg.uniform(0.75, 0.95))
    return M


MICRO = [micro_eclats, micro_planche, micro_os, micro_cire, micro_pieces, micro_chaine]


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


# ======================================================================= C6 (2026-10-28) : garnitures de surface (tables, autels, étagères)
# « Tout objet porte d'autres objets » (INSPIRATION_IGNITE §2.8) : petites compositions posées PAR-DESSUS les meubles par
# ObjGarnitures (scripts/objets/garnitures.gd), même repère que le meuble (origine = celle de la table / de l'étagère ; autel : dessus
# de la nappe en y = 0). Livres, rouleaux, bols, cruche, gobelet, crâne, pièces, chandelier ÉTEINT (aucune lumière, aucune flamme).
def _copier(M, src, c, R=I3):
    """Verse les triangles d'un autre module (crâne…) dans M, tournés de R et posés en c."""
    for (m, p, t) in src.tris:
        M.tris.append((m, tuple(c + R @ q for q in p), t))


def g_livre(M, c, L, t, W, an=0.0, cuir="laine", ton=None):
    """Livre fermé posé à plat (L x t x W) : plats et dos de cuir, tranche de pages claire visible sur trois côtés."""
    rg = M.rg
    R = Ry(an)
    ton = rg.uniform(0.5, 0.8) if ton is None else ton
    e = max(0.005, t * 0.16)
    M.add(cuir, boite(c + R @ V(0, e / 2, 0), (L, e, W), R), ton)
    M.add(cuir, boite(c + R @ V(0, t - e / 2, 0), (L, e, W), R), ton * 1.05)
    M.add(cuir, boite(c + R @ V(-L / 2 + e / 2, t / 2, 0), (e, t, W), R), ton * 0.9)
    M.add("parchemin", boite(c + R @ V(e * 0.5, t / 2, 0), (L - e * 2.2, t - 2 * e, W - e * 1.4), R), rg.uniform(0.7, 0.85))


def g_livre_ouvert(M, c, L, W, an=0.0, cuir="laine"):
    """Livre ouvert : couverture à plat, deux blocs de pages en V léger, pages claires."""
    rg = M.rg
    R = Ry(an)
    M.add(cuir, boite(c + R @ V(0, 0.004, 0), (2 * L + 0.012, 0.008, W + 0.012), R), rg.uniform(0.5, 0.7))
    for sx in (-1, 1):
        M.add("parchemin", boite(c + R @ V(sx * L * 0.5, 0.017, 0), (L * 0.98, 0.016, W), R @ Rz(-sx * 0.07)), rg.uniform(0.85, 1.0))
    M.add("noir", [orienter([c + R @ V(-0.003, 0.0265, -W * 0.45), c + R @ V(0.003, 0.0265, -W * 0.45), c + R @ V(0.003, 0.0265, W * 0.45),
                             c + R @ V(-0.003, 0.0265, W * 0.45)], UP)], 1.0)          # pli du milieu


def g_bol(M, c, r, h, mat="fer", ton=0.72, contenu=None):
    """Bol / écuelle à paroi épaisse (dedans visible), contenu : « os », « or » (pièces), « noir » (fond de liquide figé) ou rien."""
    rg = M.rg
    M.rev(mat, [(r * 0.55, 0.0), (r * 0.88, h * 0.4), (r, h), (r * 0.86, h), (r * 0.7, h * 0.5), (0.0, h * 0.25)], 8, c=c, caps=(False, False), ton=ton)
    if contenu == "os":
        for k in range(3):
            an = rg.uniform(0, TAU)
            M.add("os", boite(c + V(math.cos(an) * r * 0.3, h * 0.5 + k * 0.012, math.sin(an) * r * 0.3), (r * 1.2, 0.016, 0.018), Ry(an + 1.2) @ Rz(0.25)), rg.uniform(0.85, 1.0))
    elif contenu == "or":
        for k in range(4):
            an = rg.uniform(0, TAU)
            q = c + V(math.cos(an) * r * 0.35, h * 0.42 + k * 0.006, math.sin(an) * r * 0.35)
            M.add_tons("or", piece(q, 0.022, Ry(rg.uniform(0, TAU)) @ Rx(rg.uniform(-0.3, 0.3))), brut=True)
    elif contenu == "noir":
        M.add("noir", disque(c + V(0, h * 0.62, 0), r * 0.78, 8), 1.0)


def g_cruche(M, c, an=0.0):
    """Cruche de terre (h 0,19) : panse, col, bec pincé, anse."""
    R = Ry(an)
    M.rev("argile", [(0.045, 0.0), (0.065, 0.045), (0.066, 0.09), (0.045, 0.14), (0.034, 0.165), (0.04, 0.19), (0.033, 0.19), (0.026, 0.17)], 8, c=c, caps=(True, False), ton=0.85)
    M.add("noir", disque(c + V(0, 0.17, 0), 0.026, 8), 1.0)
    M.add("argile", hull([c + R @ V(0.03, 0.18, sz * 0.012) for sz in (-1, 1)] + [c + R @ V(0.058, 0.195, 0), c + R @ V(0.035, 0.192, 0)]), 0.82)       # bec
    pts = [c + R @ V(-0.06, 0.07, 0), c + R @ V(-0.085, 0.12, 0), c + R @ V(-0.07, 0.165, 0), c + R @ V(-0.035, 0.172, 0)]
    for a, b in zip(pts, pts[1:]):
        M.add("argile", poutre(a, b, 0.016, 0.012, up=R @ V(0, 0, 1)), 0.8)


def g_gobelet(M, c):
    """Gobelet d'étain à pied (h 0,09)."""
    M.rev("fer", [(0.03, 0.0), (0.03, 0.007), (0.009, 0.014), (0.009, 0.038), (0.032, 0.068), (0.036, 0.09), (0.03, 0.09), (0.0, 0.064)], 8, c=c, caps=(True, False), ton=0.78)


def g_chandelier(M, c):
    """Chandelier ÉTEINT (h 0,2) : pied en coupelle, fût, bobèche, chicot de cire à coulures, mèche noire. Aucune flamme."""
    rg = M.rg
    M.rev("fer", [(0.055, 0.0), (0.06, 0.008), (0.03, 0.02), (0.011, 0.032), (0.011, 0.125), (0.022, 0.13), (0.04, 0.14), (0.042, 0.15), (0.03, 0.15), (0.0, 0.142)], 8, c=c, caps=(True, False), ton=0.72)
    h = rg.uniform(0.035, 0.06)
    M.rev("cire", [(0.019, 0.14), (0.018, 0.14 + h), (0.012, 0.145 + h), (0.0, 0.142 + h)], 6, c=c, caps=(False, False), ton=0.92)
    M.rev("cire", [(0.03, 0.149), (0.024, 0.157), (0.0, 0.158)], 6, c=c, caps=(False, False), ton=0.85)       # flaque figée dans la bobèche
    M.add("cire", poutre(c + V(0.03, 0.15, 0.0), c + V(0.04, 0.128, 0.004), 0.009, 0.007), 0.9)               # larme qui pend
    M.add("noir", boite(c + V(0, 0.147 + h, 0), (0.005, 0.012, 0.005)), 1.0)


def g_rouleau(M, c, L, an=0.0, r=0.022):
    R = Ry(an)
    M.add("parchemin", cylindre(c + R @ V(-L / 2, r, 0), c + R @ V(L / 2, r, 0), r, 6), M.rg.uniform(0.8, 0.95))


def g_pieces(M, c, n, rr=0.06):
    rg = M.rg
    for k in range(n):
        an = rg.uniform(0, TAU)
        q = c + V(math.cos(an) * rg.uniform(0, rr), 0.003 + 0.004 * (k % 2), math.sin(an) * rg.uniform(0, rr))
        M.add_tons("or", piece(q, 0.024, Ry(rg.uniform(0, TAU)) @ Rx(rg.uniform(-0.12, 0.12)), (0.5, 1.0)), brut=True)


def g_crane(M, c, an, var="a"):
    _copier(M, crane(var), c, Ry(an))


def garniture_table(var):
    """Dessus de table (repère de la table, plateau à y 0,79) : zones laissées libres par le feuillet et la vaisselle du module table
    (bout gauche x < -0,43, bande arrière z < -0,12, milieu x -0,06..0,15). UN MODULE PAR OBJET (« garniture_table_a1 »…) : chacun est
    un petit objet à part pour l'audit (les bougies posées ensuite sur la table s'écartent de son disque, ObjGarnitures.DISQUES)."""
    y = 0.79
    if var == "a":      # pile de livres, chandelier éteint, pièces
        objets = [lambda M: (g_livre(M, V(-0.33, y, -0.22), 0.22, 0.045, 0.15, 0.15), g_livre(M, V(-0.32, y + 0.045, -0.225), 0.19, 0.04, 0.13, -0.12, "bois")),
                  lambda M: g_chandelier(M, V(0.06, y, 0.17)),
                  lambda M: g_pieces(M, V(0.04, y, -0.22), 3, 0.04)]
    elif var == "b":    # cruche, gobelet, bol d'os
        objets = [lambda M: g_cruche(M, V(-0.47, y, 0.17), 2.4),
                  lambda M: g_gobelet(M, V(-0.45, y, -0.12)),
                  lambda M: g_bol(M, V(0.05, y, 0.14), 0.075, 0.05, "argile", 0.8, "os")]
    else:               # crâne, livre ouvert, rouleau
        objets = [lambda M: g_crane(M, V(0.05, y, 0.1), -0.45, "b"),
                  lambda M: g_livre_ouvert(M, V(-0.3, y, -0.215), 0.12, 0.16, 0.1),
                  lambda M: g_rouleau(M, V(0.47, y, -0.18), 0.2, math.pi / 2)]
    mods = []
    for k, f in enumerate(objets):
        M = Module("garniture_table_%s%d" % (var, k + 1), 4000 + ord(var) * 8 + k, sol=False)
        f(M)
        mods.append(M)
    return mods


def garniture_autel(var):
    """Dessus d'autel (y = 0 : dessus de la nappe ; tient dans |x| < 0,45 m, entre les bougies posées à ±0,35 x largeur)."""
    M = Module("garniture_autel_" + var, 4100 + ord(var), sol=False)
    if var == "a":      # bol d'offrandes plein de pièces, crâne, livre fermé
        g_bol(M, V(0.0, 0.0, 0.05), 0.11, 0.06, "fer", 0.75, "or")
        g_crane(M, V(-0.3, 0.0, -0.18), 0.4, "a")
        g_livre(M, V(0.32, 0.0, -0.2), 0.24, 0.05, 0.17, -0.3, "laine")
        g_pieces(M, V(0.12, 0.0, 0.22), 3, 0.05)
    else:               # chandelier éteint, bol noirci, gobelet, rouleau
        g_chandelier(M, V(-0.28, 0.0, -0.25))
        g_bol(M, V(0.06, 0.0, 0.02), 0.09, 0.05, "fer", 0.7, "noir")
        g_gobelet(M, V(0.3, 0.0, -0.14))
        g_rouleau(M, V(-0.12, 0.0, 0.22), 0.22, 0.25)
    return M


def garniture_etagere(var):
    """Étagère (repère du bâti « etagere_cadre_<var> ») : bout libre du 3e rayon (x > 0,7, à côté de l'urne) et dessus du bâti
    (a : planche à y 1,995, dos jusqu'à 2,05 en z -0,135 ; b : corniche à y 2,06)."""
    M = Module("garniture_etagere_" + var, 4200 + ord(var), sol=False)
    g_crane(M, V(0.76, 1.375, 0.01), 0.25 if var == "a" else -0.3, "a" if var == "a" else "b")
    top = 1.995 if var == "a" else 2.06
    if var == "a":
        g_crane(M, V(-0.55, top, 0.03), -0.2, "b")
        g_bol(M, V(-0.05, top, 0.03), 0.08, 0.05, "argile", 0.8, "os")
        g_chandelier(M, V(0.5, top, 0.02))
    else:
        g_livre(M, V(-0.45, top, 0.02), 0.24, 0.05, 0.17, 0.1, "bois")
        g_livre(M, V(-0.44, top + 0.05, 0.02), 0.2, 0.045, 0.15, -0.15, "laine")
        g_gobelet(M, V(0.12, top, 0.04))
        g_crane(M, V(0.58, top, 0.03), 0.35, "a")
    return M


GARNITURES = [garniture_table, garniture_autel, garniture_etagere]


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
    for f in MICRO:                 # C5 : semis micro
        for v in ("abc" if f is micro_eclats else "ab"):
            mods.append(f(v))
    for f in L3:
        mods += f()
    for f in GARNITURES:            # C6 : garnitures de surface (tables : un module par objet)
        for v in ("abc" if f is garniture_table else "ab"):
            r = f(v)
            mods += r if isinstance(r, list) else [r]
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
        base = M.nom.rsplit("_", 1)[0] if M.nom.rsplit("_", 1)[-1] in ("a", "b", "c") else M.nom
        bud = BUDGET.get(base, BUDGET.get(base.split("_")[0], 0))
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
    print("aretes : %d -> %d triangles apres liseres" % (st.get("avant", 0), st.get("apres", 0)))
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for a in args:
        if a.startswith("apercu="):
            apercus(sorties, a[7:])


main()
