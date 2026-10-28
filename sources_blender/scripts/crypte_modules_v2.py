# Crypte v2 : MODULES RÉUTILISABLES en pierre ancienne (piliers, arches, panneaux de maçonnerie, éboulis, dalles brisées,
# sarcophage, statue encapuchonnée, candélabre, lustre, marches). Aucune texture : chaque objet porte une matière
# (pierre / fer / cire / bois) et des couleurs de sommet cuites (rgb = ton de la pierre x occlusion ambiante par rayons).
#   blender.exe -b --python crypte_modules_v2.py
# Sorties : assets/crypte/modules/crypte_v2.dat   (relu par CrypteModeles / CrypteDecor.modele : FileAccess, sûr dans le fil de construction)
#           assets/crypte/modules/crypte_v2.glb   (export de référence, pour inspection)
#           sources_blender/crypte_modules_v2.blend
# Repère des modules = repère Godot (y haut, +z = face avant, vers la pièce), origine au pied / au centre de la base.
# Le script calcule en repère Godot et convertit en Blender (x, -z, y) ; le .dat est écrit en repère Godot.
# Rejouable : graines fixes. Les objets sont nommés « module__matiere » ; « module__pts » = points d'accroche de flammes.
import bpy, bmesh, math, os, random, struct
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import aretes      # C1 matières : arête claire / creux sombre en couleur de sommet (sources_blender/scripts/aretes.py)
ARETES_SANS = ("dallage", "dalles_")      # sols (lot C2) : leurs propres réglages

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
DOSSIER = os.path.join(BASE, "assets", "crypte", "modules")
os.makedirs(DOSSIER, exist_ok=True)
DAT = os.path.join(DOSSIER, "crypte_v2.dat")
GLB = os.path.join(DOSSIER, "crypte_v2.glb")
BLEND = os.path.join(BASE, "sources_blender", "crypte_modules_v2.blend")

TEINTE = {"pierre": (1.0, 0.98, 0.95), "fer": (0.85, 0.88, 0.95), "cire": (1.0, 0.96, 0.85), "bois": (1.0, 0.95, 0.9),
          "givre": (0.92, 0.97, 1.0), "gravure": (1.0, 0.98, 0.95), "fourrure": (1.0, 0.95, 0.86), "noir": (1.0, 1.0, 1.0)}      # C4b : givre en plaques (matière « neige »), inscriptions (« gravure »)


def B(v):   # Godot -> Blender
    return Vector((v[0], -v[2], v[1]))


def G(v):   # Blender -> Godot
    return Vector((v.x, v.z, -v.y))


class Module:
    def __init__(self, nom, graine):
        self.nom = nom
        self.rg = random.Random(graine)
        self.tris = []      # (matière, (p0, p1, p2) en repère Godot, ton)
        self.pts = []       # points d'accroche (flammes)

    # ---------------------------------------------------------------- primitives
    def _emettre(self, bm, mat, ton):
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        for f in bm.faces:
            p = [G(v.co) for v in f.verts]
            if (p[1] - p[0]).cross(p[2] - p[0]).length_squared < 1e-12:
                continue
            self.tris.append((mat, (p[0], p[1], p[2]), ton))
        bm.free()

    def boite(self, taille, pos, mat="pierre", yaw=0.0, incl=(0.0, 0.0), bev=0.02, jit=0.012, ton=None, haut_ratio=1.0):
        """Bloc taillé : arêtes abattues, sommets bougés (éclats), légère inclinaison. taille/pos en repère Godot."""
        rg = self.rg
        if ton is None:
            ton = rg.uniform(0.8, 1.0)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            sx, sy, sz = taille
            top = v.co.z > 0
            k = haut_ratio if top else 1.0       # fruit : le haut peut être plus étroit
            v.co = Vector((v.co.x * sx * k, v.co.y * sz * k, v.co.z * sy))
        b = min(bev, 0.4 * min(taille))
        if b > 0.003:
            bmesh.ops.bevel(bm, geom=bm.edges[:], offset=b, offset_type='OFFSET', segments=1, profile=0.5, affect='EDGES')
        if jit > 0:
            for v in bm.verts:
                v.co += Vector((rg.uniform(-jit, jit), rg.uniform(-jit, jit), rg.uniform(-jit, jit)))
        M = Matrix.Translation(B(pos)) @ Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(incl[0], 4, 'X') @ Matrix.Rotation(incl[1], 4, 'Y')
        bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
        self._emettre(bm, mat, ton)

    def coin(self, pts_godot, mat="pierre", bev=0.012, jit=0.0, ton=None):
        """Solide convexe défini par ses sommets (repère Godot) : voussoirs, éclats, galets taillés."""
        rg = self.rg
        if ton is None:
            ton = rg.uniform(0.8, 1.0)
        bm = bmesh.new()
        for p in pts_godot:
            bm.verts.new(B(p))
        bmesh.ops.convex_hull(bm, input=bm.verts[:], use_existing_faces=False)
        interieur = [v for v in bm.verts if not v.link_faces]
        if interieur:
            bmesh.ops.delete(bm, geom=interieur, context='VERTS')
        if bev > 0.003:
            try:
                bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bev, offset_type='OFFSET', segments=1, profile=0.5, affect='EDGES')
            except Exception:
                pass
        if jit > 0:
            for v in bm.verts:
                v.co += Vector((rg.uniform(-jit, jit), rg.uniform(-jit, jit), rg.uniform(-jit, jit)))
        self._emettre(bm, mat, ton)

    def cylindre(self, r0, r1, haut, pos, cotes=8, mat="pierre", bev=0.0, jit=0.006, ton=None, rot=0.0):
        rg = self.rg
        if ton is None:
            ton = rg.uniform(0.8, 1.0)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=cotes, radius1=r0, radius2=r1, depth=haut)
        if bev > 0.003:
            bmesh.ops.bevel(bm, geom=bm.edges[:], offset=min(bev, 0.35 * min(r0, r1 if r1 > 0.01 else r0, haut)), offset_type='OFFSET', segments=1, profile=0.5, affect='EDGES')
        if jit > 0:
            for v in bm.verts:
                v.co += Vector((rg.uniform(-jit, jit), rg.uniform(-jit, jit), rg.uniform(-jit, jit)))
        M = Matrix.Translation(B(pos) + Vector((0, 0, haut * 0.5))) @ Matrix.Rotation(rot, 4, 'Z')
        bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
        self._emettre(bm, mat, ton)

    def sphere(self, r, pos, ech=(1, 1, 1), mat="pierre", seg=8, ton=None, jit=0.01):
        rg = self.rg
        if ton is None:
            ton = rg.uniform(0.8, 1.0)
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(4, seg // 2 + 1), radius=r)
        for v in bm.verts:
            v.co = Vector((v.co.x * ech[0], v.co.y * ech[2], v.co.z * ech[1])) + Vector((rg.uniform(-jit, jit), rg.uniform(-jit, jit), rg.uniform(-jit, jit)))
        bmesh.ops.transform(bm, matrix=Matrix.Translation(B(pos)), verts=bm.verts)
        self._emettre(bm, mat, ton)

    def barre(self, p0, p1, e, mat="fer", ton=0.55):
        """Tige de section carrée e entre deux points (repère Godot)."""
        d = (p1 - p0)
        d.normalize()
        u = d.cross(Vector((0, 1, 0)))
        if u.length < 0.1:
            u = d.cross(Vector((1, 0, 0)))
        u.normalize()
        v = d.cross(u)
        pts = []
        for p in (p0, p1):
            for su, sv in ((1, 1), (1, -1), (-1, -1), (-1, 1)):
                pts.append(p + u * e * su + v * e * sv)
        self.coin(pts, mat, bev=0.0, ton=ton)

    def tore_polygonal(self, R, e, pos, cotes=12, mat="fer", ton=0.7, haut=None):
        """Anneau plat (cercle de lustre) : cotes tronçons de section e x haut."""
        haut = e if haut is None else haut
        for k in range(cotes):
            a = math.tau * (k + 0.5) / cotes
            c = Vector((math.cos(a) * R, 0, math.sin(a) * R))
            long = 2 * R * math.sin(math.pi / cotes) * 1.08
            self.boite((long, haut, e), pos + c, mat, yaw=-(a + math.pi / 2), bev=0.0, jit=0.002, ton=ton)

    # ---------------------------------------------------------------- finition : occlusion cuite
    def finir(self, rayons=14, portee=0.38, force=0.5):
        bm_verts, polys = [], []
        for i, (m, p, t) in enumerate(self.tris):
            polys.append((len(bm_verts), len(bm_verts) + 1, len(bm_verts) + 2))
            bm_verts.extend(B(q) for q in p)
        arbre = BVHTree.FromPolygons([tuple(v) for v in bm_verts], polys, all_triangles=True, epsilon=1e-5)
        rg = random.Random(7)
        dirs = []
        for _ in rayons * [0]:
            u, v = rg.random(), rg.random()
            r = math.sqrt(u)
            th = math.tau * v
            dirs.append((r * math.cos(th), r * math.sin(th), math.sqrt(max(0.0, 1.0 - u))))
        sortie = {}
        for i, (m, p, t) in enumerate(self.tris):
            pb = [B(q) for q in p]
            n = (pb[1] - pb[0]).cross(pb[2] - pb[0])
            if n.length_squared < 1e-14:
                continue
            n.normalize()
            tg = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
            bt = n.cross(tg)
            cols = []
            for q in pb:
                occ = 0.0
                o = q + n * 0.012
                for dx, dy, dz in dirs:
                    d = (tg * dx + bt * dy + n * dz).normalized()
                    h = arbre.ray_cast(o, d, portee)
                    if h[0] is not None:
                        occ += 1.0 - h[3] / portee
                ao = 1.0 - force * occ / len(dirs) * 1.6
                ao = max(0.4, min(1.0, ao))
                # pied : un peu plus sombre au ras du sol (sol de la salle)
                pied = 0.78 + 0.22 * min(1.0, max(0.0, q.z / 0.5)) if m == "pierre" else 1.0
                te = TEINTE.get(m, (1, 1, 1))
                k = ao * t * pied
                cols.append((min(1.0, k * te[0]), min(1.0, k * te[1]), min(1.0, k * te[2]), 1.0))
            sortie.setdefault(m, []).append((p, cols))
        return sortie


# ======================================================================= modules
def pilier_mur(nom, h, graine, larg=0.62, prof=0.34):
    """Pilier engagé (demi-pilier contre le mur, +z vers la pièce) : socle à ressauts, fût en assises irrégulières, chapiteau mouluré.
    Hauteur totale h (le dessus touche le départ de l'arc ou la voûte). Saillie `prof` <= 0,35 m : aucune collision."""
    M = Module(nom, graine)
    rg = M.rg
    z0 = prof * 0.5 - 0.02
    M.boite((larg + 0.2, 0.16, prof + 0.12), Vector((0, 0.08, z0 + 0.04)), bev=0.025, jit=0.01)
    M.boite((larg + 0.1, 0.16, prof + 0.06), Vector((0, 0.24, z0 + 0.02)), bev=0.025, jit=0.01)
    y = 0.32
    haut_fut = h - 0.32 - 0.5
    while y < 0.32 + haut_fut - 0.05:
        hc = min(rg.uniform(0.34, 0.56), 0.32 + haut_fut - y)
        dl = rg.uniform(-0.015, 0.015)
        M.boite((larg + rg.uniform(-0.03, 0.02), hc - 0.03, prof + rg.uniform(-0.03, 0.025)), Vector((dl, y + hc * 0.5, z0)), bev=0.032, jit=0.012, incl=(0, rg.uniform(-0.006, 0.006)))
        y += hc
    M.boite((larg + 0.08, 0.2, prof + 0.06), Vector((0, h - 0.4, z0 + 0.02)), bev=0.025, jit=0.01)
    M.boite((larg + 0.22, 0.18, prof + 0.16), Vector((0, h - 0.21, z0 + 0.06)), bev=0.03, jit=0.012)
    M.boite((larg + 0.32, 0.12, prof + 0.2), Vector((0, h - 0.06, z0 + 0.08)), bev=0.025, jit=0.01)
    return M


def colonne_mur(nom, h, graine, r=0.27):
    """Demi-colonne engagée : base à tore, tambours superposés, chapiteau évasé (+z vers la pièce)."""
    M = Module(nom, graine)
    rg = M.rg
    M.boite((r * 2 + 0.34, 0.2, r * 2 + 0.2), Vector((0, 0.1, r * 0.5 + 0.02)), bev=0.03, jit=0.01)
    M.cylindre(r + 0.1, r + 0.07, 0.14, Vector((0, 0.2, r * 0.2)), 10, bev=0.012)
    y = 0.34
    fin = h - 0.5
    while y < fin - 0.05:
        hc = min(rg.uniform(0.4, 0.6), fin - y)
        M.cylindre(r + rg.uniform(-0.015, 0.012), r + rg.uniform(-0.015, 0.012), hc - 0.01, Vector((rg.uniform(-0.008, 0.008), y, r * 0.2)), 10, bev=0.016, jit=0.01)
        y += hc
    M.cylindre(r + 0.05, r + 0.16, 0.2, Vector((0, h - 0.5, r * 0.2)), 10, bev=0.02)
    M.boite((r * 2 + 0.34, 0.14, r * 2 + 0.2), Vector((0, h - 0.18, r * 0.5)), bev=0.025, jit=0.01)
    M.boite((r * 2 + 0.44, 0.1, r * 2 + 0.3), Vector((0, h - 0.05, r * 0.5)), bev=0.02, jit=0.01)
    return M


def arche(nom, portee, fleche, graine, epaisseur=0.34, prof=0.5, bloc=None):
    """Arc en voussoirs (plan x-y, centré sur x = 0, naissance à y = 0, relief vers +z). portee = distance entre les points de
    naissance de l'intrados ; fleche = montée de l'intrados. Arc brisé si fleche >= portee/2, sinon arc surbaissé. Clé légèrement saillante."""
    M = Module(nom, graine)
    rg = M.rg
    a = portee * 0.5
    f = fleche
    ep = epaisseur
    bloc = bloc or (0.36 + 0.012 * portee)

    def vouss(cx, cy, R, t0, t1, miroir, cle):
        gap = 0.011 / R
        e_out = R + ep + rg.uniform(-0.02, 0.025)
        pts = []
        for r_ in (R, e_out):
            for t in (t0 + gap, t1 - gap):
                for z in (-prof * 0.5 + rg.uniform(0, 0.02), prof * 0.5 - rg.uniform(0, 0.02)):
                    x = cx + r_ * math.cos(t)
                    y = cy + r_ * math.sin(t)
                    if miroir:
                        x = -x
                    if cle:
                        y += 0.03 if r_ == e_out else 0.0
                        z += 0.04 if z > 0 else 0.0
                    pts.append(Vector((x, y, z)))
        M.coin(pts, bev=0.03, jit=0.005)

    if f >= a:
        xc = (f * f - a * a) / (2 * a)           # la moitié droite a son centre en (-xc, 0)
        R = a + xc
        t_top = math.atan2(f, xc)
        n = max(3, int(round(R * t_top / bloc)))
        for s_ in (False, True):
            for k in range(n):
                vouss(-xc, 0.0, R, t_top * k / n, t_top * (k + 1) / n, s_, k == n - 1)
    else:
        yc = (f * f - a * a) / (2 * f)
        R = f - yc
        t_s = math.atan2(-yc, a)
        n = max(5, int(round(R * (math.pi - 2 * t_s) / bloc)))
        if n % 2 == 0:
            n += 1
        for k in range(n):
            vouss(0.0, yc, R, t_s + (math.pi - 2 * t_s) * k / n, t_s + (math.pi - 2 * t_s) * (k + 1) / n, False, k == n // 2)
    for sx in (-1, 1):                # sabots sous la naissance
        M.boite((0.34, 0.16, prof + 0.1), Vector((sx * (a + 0.02), -0.08, 0.02)), bev=0.02, jit=0.008)
    return M


def pan_mur(nom, larg, haut, graine, prof=0.22):
    """Panneau de maçonnerie en relief (+z vers la pièce) : assises irrégulières, blocs taillés qui avancent de 0 à 7 cm,
    quelques blocs tombés (creux), fond sombre. Aucune collision (saillie <= 0,25 m)."""
    M = Module(nom, graine)
    rg = M.rg
    y = 0.0
    # fond (joints noirs)
    M.boite((larg, haut, 0.04), Vector((0, haut * 0.5, 0.02)), bev=0.0, jit=0.0, ton=0.32)
    rang = 0
    while y < haut - 0.05:
        hc = min(rg.choice([0.28, 0.34, 0.4, 0.46, 0.54]), haut - y)
        if haut - y - hc < 0.2:
            hc = haut - y
        x = -larg * 0.5 + rg.uniform(0.0, 0.25) * (rang % 2)
        while x < larg * 0.5 - 0.04:
            w = rg.choice([0.42, 0.55, 0.7, 0.86, 1.05])
            if x + w > larg * 0.5 - 0.2:
                w = larg * 0.5 - x
            if w < 0.08:
                break
            tomb = rg.random() < 0.045 and rang > 0 and rang < 8
            if not tomb:
                sail = rg.uniform(0.0, 0.075)
                ep = prof - 0.04 + sail - rg.uniform(0.0, 0.03)
                M.boite((w - 0.034, hc - 0.03, ep), Vector((x + w * 0.5, y + hc * 0.5, 0.04 + ep * 0.5)), bev=0.03, jit=0.012,
                        ton=rg.uniform(0.72, 1.0) * (0.93 if rg.random() < 0.15 else 1.0), incl=(rg.uniform(-0.01, 0.01), rg.uniform(-0.012, 0.012)))
            x += w
        y += hc
        rang += 1
    return M


def eboulis(nom, rayon, haut, graine, n=12):
    """Tas de pierres de taille éboulées : blocs inclinés (arêtes abattues, éclats) et petits galets."""
    M = Module(nom, graine)
    rg = M.rg
    for k in range(n):
        r = rayon * (rg.random() ** 0.7)
        a = rg.uniform(0, math.tau)
        s = rg.uniform(0.14, 0.4) * (1.15 - 0.5 * r / rayon)
        dims = (s * rg.uniform(0.8, 1.7), s * rg.uniform(0.55, 1.0), s * rg.uniform(0.7, 1.4))
        yc = max(dims[1] * 0.42, haut * (1.0 - r / rayon) * rg.uniform(0.3, 0.9) + dims[1] * 0.25)
        M.boite(dims, Vector((math.cos(a) * r, yc, math.sin(a) * r)), yaw=rg.uniform(0, math.tau), incl=(rg.uniform(-0.5, 0.5), rg.uniform(-0.5, 0.5)),
                bev=0.025, jit=0.025, ton=rg.uniform(0.62, 1.0))
    for k in range(int(n * 0.9)):
        r = rayon * (0.4 + rg.random() * 0.8)
        a = rg.uniform(0, math.tau)
        s = rg.uniform(0.05, 0.11)
        M.boite((s * 1.3, s * 0.7, s), Vector((math.cos(a) * r, s * 0.3, math.sin(a) * r)), yaw=rg.uniform(0, 6), incl=(rg.uniform(-0.4, 0.4), 0), bev=0.012, jit=0.012, ton=rg.uniform(0.6, 1.0))
    return M


def dalles_brisees(nom, graine, n=3):
    """Dalles de sol soulevées / brisées (relief du sol : 4 à 10 cm), 2 à 3 morceaux imbriqués."""
    M = Module(nom, graine)
    rg = M.rg
    for k in range(n):
        w = rg.uniform(0.5, 0.95)
        d = rg.uniform(0.4, 0.8)
        ox = rg.uniform(-0.35, 0.35) * k
        oz = rg.uniform(-0.3, 0.3) * k
        M.boite((w, 0.075, d), Vector((ox, 0.03 + 0.01 * k, oz)), yaw=rg.uniform(0, math.tau), incl=(rg.uniform(-0.15, 0.15), rg.uniform(-0.15, 0.15)),
                bev=0.016, jit=0.014, ton=rg.uniform(0.8, 1.0))
    return M


def _givre_eclat(M, c, r, ep=0.012):
    """Éclat de givre plat et IRRÉGULIER (5 à 7 sommets sur un cercle déformé) : pas de rectangle (pas de « gros carrés »)."""
    rg = M.rg
    n = rg.randint(5, 7)
    pts = []
    for k in range(n):
        a = math.tau * (k + rg.uniform(-0.3, 0.3)) / n
        rr = r * rg.uniform(0.45, 1.0)
        q = Vector((c.x + math.cos(a) * rr, c.y, c.z + math.sin(a) * rr * rg.uniform(0.5, 0.9)))
        pts.append(q)
        pts.append(q + Vector((0, ep, 0)))
    M.coin(pts, "givre", bev=0.0, jit=0.0, ton=rg.uniform(0.5, 0.72))


def _givre_plaques(M, x0, x1, z0, z1, y, n, ep=0.012, taille=(0.12, 0.34)):
    """Givre en petits éclats irréguliers posés à plat (matière « givre » -> neige de la crypte, ton bas : pas de tache saturée)."""
    rg = M.rg
    for _ in range(n * 2):
        r = rg.uniform(taille[0], taille[1]) * 0.32
        x = rg.uniform(x0 + r, x1 - r) if x1 - x0 > 2 * r else (x0 + x1) * 0.5
        z = rg.uniform(z0 + r, z1 - r) if z1 - z0 > 2 * r else (z0 + z1) * 0.5
        _givre_eclat(M, Vector((x, y, z)), r, ep)


def _sarco(M, L, W, H, cuve=0.56, inscription=True, croix=True):
    """Sarcophage sculpté (C4b, planche vue 6 et « objets ») : long axe x, face avant +z, hauteur H (dessus du couvercle).
    Socle à deux ressauts, cuve à pilastres d'angle et panneaux encadrés (croix et rosaces en relief), bandeau d'inscription,
    corniche, couvercle à deux degrés chanfreinés avec croix fleuronnée, givre sur les arêtes hautes, éclats."""
    rg = M.rg
    # socle à ressauts
    M.boite((L + 0.18, 0.1, W + 0.16), Vector((0, 0.05, 0)), bev=0.03, jit=0.01, ton=0.78)
    M.boite((L + 0.08, 0.08, W + 0.07), Vector((0, 0.14, 0)), bev=0.025, jit=0.008, ton=0.86)
    y0 = 0.18
    hc = H * cuve
    y1 = y0 + hc
    # noyau de la cuve (en retrait : les panneaux et pilastres avancent)
    M.boite((L - 0.06, hc, W - 0.06), Vector((0, y0 + hc * 0.5, 0)), bev=0.01, jit=0.004, ton=0.62)
    # pilastres d'angle
    for sx in (-1, 1):
        for sz in (-1, 1):
            M.boite((0.16, hc, 0.16), Vector((sx * (L * 0.5 - 0.07), y0 + hc * 0.5, sz * (W * 0.5 - 0.07))), bev=0.025, jit=0.006, ton=rg.uniform(0.9, 1.0))
    # panneaux encadrés, faces longues
    n = max(2, int(round((L - 0.3) / 0.75)))
    pw = (L - 0.32) / n
    for sz in (-1, 1):
        for k in range(n):
            x = -L * 0.5 + 0.16 + pw * (k + 0.5)
            zc = sz * (W * 0.5 - 0.01)
            yp = y0 + hc * 0.42
            hp = hc * 0.56
            # cadre : 4 baguettes
            M.boite((pw - 0.06, 0.05, 0.05), Vector((x, yp + hp * 0.5, zc)), bev=0.012, jit=0.003, ton=0.98)
            M.boite((pw - 0.06, 0.05, 0.05), Vector((x, yp - hp * 0.5, zc)), bev=0.012, jit=0.003, ton=0.9)
            for sx in (-1, 1):
                M.boite((0.05, hp, 0.05), Vector((x + sx * (pw * 0.5 - 0.055), yp, zc)), bev=0.012, jit=0.003, ton=0.95)
            # fond du panneau (en creux, plus sombre) et motif en relief
            M.boite((pw - 0.14, hp - 0.06, 0.02), Vector((x, yp, zc - sz * 0.005)), bev=0.0, jit=0.002, ton=0.5)
            if sz > 0 and k == n // 2 and n % 2 == 1 or (sz > 0 and n % 2 == 0 and k in (n // 2 - 1, n // 2)):
                # croix en relief au centre de la face avant
                M.boite((0.06, hp * 0.7, 0.05), Vector((x, yp, zc + 0.012)), bev=0.012, jit=0.002, ton=1.0)
                M.boite((min(0.36, pw * 0.55), 0.06, 0.05), Vector((x, yp + hp * 0.12, zc + 0.012)), bev=0.012, jit=0.002, ton=1.0)
            else:
                # rosace : losange de 4 pétales
                for a in range(4):
                    ang = a * math.pi * 0.5 + math.pi * 0.25
                    M.boite((0.07, 0.07, 0.04), Vector((x + math.cos(ang) * 0.06, yp + math.sin(ang) * 0.06, zc + 0.01)), yaw=0.0, incl=(0, 0), bev=0.014, jit=0.002, ton=0.97)
                M.boite((0.06, 0.06, 0.05), Vector((x, yp, zc + 0.016)), bev=0.014, jit=0.002, ton=1.0)
    # panneaux des petits côtés : croix simple en relief
    for sx in (-1, 1):
        xc = sx * (L * 0.5 - 0.01)
        M.boite((0.05, hc * 0.56, W - 0.38), Vector((xc, y0 + hc * 0.42, 0)), bev=0.012, jit=0.003, ton=0.55)
        M.boite((0.05, hc * 0.42, 0.06), Vector((xc + sx * 0.012, y0 + hc * 0.42, 0)), bev=0.012, jit=0.002, ton=1.0)
        M.boite((0.05, 0.06, min(0.3, W * 0.4)), Vector((xc + sx * 0.012, y0 + hc * 0.5, 0)), bev=0.012, jit=0.002, ton=1.0)
    # bandeau d'inscription (face avant, haut de la cuve) puis corniche
    if inscription:
        M.boite((L - 0.4, hc * 0.16, 0.03), Vector((0, y1 - hc * 0.1, W * 0.5 + 0.005)), "gravure", bev=0.006, jit=0.002, ton=0.9)
    M.boite((L + 0.04, 0.06, W + 0.04), Vector((0, y1 + 0.03, 0)), bev=0.022, jit=0.006, ton=0.95)
    # couvercle à deux degrés (légèrement déplacé), chanfrein (fruit) et croix fleuronnée
    yl = y1 + 0.06
    hl = H - yl
    dec = Vector((0.05, 0, 0.02))
    M.boite((L + 0.1, hl * 0.42, W + 0.1), Vector((0, yl + hl * 0.21, 0)) + dec, yaw=0.02, bev=0.035, jit=0.008, ton=0.92)
    M.boite((L - 0.04, hl * 0.4, W - 0.1), Vector((0, yl + hl * 0.42 + hl * 0.2, 0)) + dec, yaw=0.02, bev=0.03, jit=0.008, ton=0.97, haut_ratio=0.9)
    yt = yl + hl * 0.82
    lc = L * 0.62
    if not croix:       # Svanhild : dessus nu (la plaque runique lumineuse de tertre.gd s'y pose)
        _givre_plaques(M, -L * 0.5, L * 0.5, -W * 0.5, W * 0.5, yl + hl * 0.42, max(3, int(L * 2.2)), taille=(0.12, 0.3))
        M.boite((0.2, 0.12, 0.16), Vector((-L * 0.5 + 0.05, 0.06, W * 0.5 + 0.17)), yaw=0.6, incl=(0.2, 0.15), bev=0.02, jit=0.02, ton=0.8)
        return
    M.boite((lc, 0.06, 0.1), Vector((0, yt + 0.03, 0)) + dec, yaw=0.02, bev=0.014, jit=0.002, ton=1.0)
    M.boite((0.1, 0.06, min(0.5, W * 0.5)), Vector((-lc * 0.22, yt + 0.03, 0)) + dec, yaw=0.02, bev=0.014, jit=0.002, ton=1.0)
    for e in (-1, 1):       # fleurons aux bouts de la croix
        M.boite((0.12, 0.06, 0.16), Vector((e * lc * 0.5, yt + 0.03, 0)) + dec, yaw=0.02 + math.pi * 0.25, bev=0.016, jit=0.002, ton=1.0)
    # givre sur le couvercle et sur le socle (arêtes hautes claires de la planche)
    _givre_plaques(M, -L * 0.5, L * 0.5, -W * 0.5, W * 0.5, yl + hl * 0.42, max(3, int(L * 2.2)), taille=(0.12, 0.3))
    _givre_plaques(M, -L * 0.45, L * 0.45, -W * 0.3, W * 0.3, yt, max(2, int(L * 1.4)), taille=(0.1, 0.24))
    _givre_plaques(M, -L * 0.5, L * 0.5, W * 0.5 - 0.02, W * 0.5 + 0.05, 0.18, max(2, int(L * 1.5)), taille=(0.08, 0.2))
    # éclat au coin et fragments tombés
    M.boite((0.2, 0.12, 0.16), Vector((-L * 0.5 + 0.05, 0.06, W * 0.5 + 0.17)), yaw=0.6, incl=(0.2, 0.15), bev=0.02, jit=0.02, ton=0.8)
    M.boite((0.12, 0.08, 0.1), Vector((L * 0.45, 0.04, W * 0.5 + 0.22)), yaw=1.9, incl=(0.1, 0.3), bev=0.015, jit=0.015, ton=0.85)


def sarcophage(nom, graine):
    """Sarcophage de pierre (2,18 x 0,92 m, 1,08 m ; mêmes encombrements que la v2 de C4 : collisions inchangées)."""
    M = Module(nom, graine)
    _sarco(M, 2.18, 0.92, 1.06)
    return M


def sarcophage_svanhild(nom, graine):
    """Sarcophage de Svanhild (arène) : 3,2 x 1,8 m, 1,16 m de haut, long axe x (posé tourné d'un quart de tour)."""
    M = Module(nom, graine)
    _sarco(M, 3.2, 1.8, 1.16, cuve=0.5, croix=False)
    return M


def socle_v2(nom, graine):
    """Socle de 1 x 1 x 1 m (mis à la taille par CrypteDecor.socle) : plinthe à ressaut, fût en deux assises de blocs, corniche."""
    M = Module(nom, graine)
    rg = M.rg
    M.boite((1.12, 0.12, 1.12), Vector((0, 0.06, 0)), bev=0.03, jit=0.008, ton=0.8)
    M.boite((1.04, 0.08, 1.04), Vector((0, 0.16, 0)), bev=0.02, jit=0.006, ton=0.88)
    y = 0.2
    for j, hc in enumerate((0.38, 0.34)):
        cut = rg.uniform(-0.15, 0.15)
        for s_ in (-1, 1):
            a0, a1 = (-0.5, cut) if s_ < 0 else (cut, 0.5)
            lw = a1 - a0 - 0.02
            c = (a0 + a1) * 0.5
            dims = (lw, hc - 0.02, 0.98) if j % 2 == 0 else (0.98, hc - 0.02, lw)
            pos = Vector((c, y + hc * 0.5, 0)) if j % 2 == 0 else Vector((0, y + hc * 0.5, c))
            M.boite(dims, pos, bev=0.03, jit=0.01, ton=rg.uniform(0.76, 1.0))
        y += hc
    M.boite((1.06, 0.1, 1.06), Vector((0, y + 0.05, 0)), bev=0.025, jit=0.006, ton=0.92)
    M.boite((1.14, 0.08, 1.14), Vector((0, 0.96, 0)), bev=0.025, jit=0.006, ton=0.98)
    _givre_plaques(M, -0.55, 0.55, -0.55, 0.55, 1.0, 3, taille=(0.12, 0.3))
    return M


def statue_capuche(nom, graine):
    """Gardien encapuchonné en prière (C4b : plis profonds, manteau, capuche ample, givre aux épaules) : socle, robe, bras croisés,
    mains jointes, visage dans l'ombre. Hauteur 2,45 m, face avant +z."""
    M = Module(nom, graine)
    rg = M.rg
    M.boite((0.88, 0.14, 0.88), Vector((0, 0.07, 0)), bev=0.03, jit=0.01, ton=0.78)
    M.boite((0.72, 0.4, 0.72), Vector((0, 0.34, 0)), bev=0.03, jit=0.01, ton=0.84)
    M.boite((0.8, 0.1, 0.8), Vector((0, 0.59, 0)), bev=0.025, jit=0.008, ton=0.9)
    M.boite((0.4, 0.09, 0.03), Vector((0, 0.36, 0.37)), "gravure", bev=0.005, jit=0.002, ton=0.9)       # plaque gravée du socle
    base = 0.64
    # robe : révolution à rayon modulé, plis profonds et réguliers (lisibles de loin), ourlet évasé
    prof = [(0.0, 0.36), (0.12, 0.33), (0.4, 0.3), (0.7, 0.27), (0.95, 0.25), (1.15, 0.245), (1.3, 0.3), (1.42, 0.22)]
    n = 20
    anneaux = []
    for (yy, r) in prof:
        ring = []
        f = 1.0 if yy < 1.2 else 0.4
        for k in range(n):
            a = math.tau * k / n
            pli = 1.0 + f * (0.13 * math.sin(a * 7 + 0.3) + 0.04 * math.sin(a * 13 - yy * 3.0))
            ring.append(Vector((math.cos(a) * r * pli, base + yy, math.sin(a) * r * pli * 0.86)))
        anneaux.append(ring)
    bm = bmesh.new()
    vv = [[bm.verts.new(B(p)) for p in ring] for ring in anneaux]
    for i in range(len(vv) - 1):
        for k in range(n):
            bm.faces.new((vv[i][k], vv[i][(k + 1) % n], vv[i + 1][(k + 1) % n], vv[i + 1][k]))
    bm.faces.new(vv[-1][::-1])
    M._emettre(bm, "pierre", 0.88)
    # manteau tombant dans le dos (plaque inclinée), épaules, bras croisés, mains jointes
    M.boite((0.62, 1.2, 0.1), Vector((0, base + 0.78, -0.24)), incl=(0.1, 0.0), bev=0.04, jit=0.012, ton=0.8)
    M.boite((0.72, 0.2, 0.44), Vector((0, base + 1.32, 0)), bev=0.07, jit=0.014, ton=1.0)
    M.boite((0.22, 0.54, 0.21), Vector((-0.2, base + 0.98, 0.18)), incl=(-0.55, 0.0), yaw=0.3, bev=0.04, jit=0.01, ton=1.0)
    M.boite((0.22, 0.54, 0.21), Vector((0.2, base + 0.98, 0.18)), incl=(-0.55, 0.0), yaw=-0.3, bev=0.04, jit=0.01, ton=1.0)
    M.boite((0.24, 0.12, 0.08), Vector((0, base + 1.08, 0.3)), bev=0.03, jit=0.006, ton=0.7)       # pli des manches (ombre)
    M.boite((0.22, 0.15, 0.17), Vector((0, base + 0.82, 0.32)), bev=0.04, jit=0.01, ton=1.0)      # mains jointes
    M.boite((0.06, 0.5, 0.05), Vector((0, base + 0.5, 0.3)), bev=0.015, jit=0.006, ton=0.72)      # pan de la robe sous les mains (creux)
    # capuche ample : volume, bec, ouverture très sombre, bords épais
    M.sphere(0.22, Vector((0, base + 1.62, -0.02)), ech=(1.0, 1.22, 1.12), seg=12, ton=0.97, jit=0.01)
    M.boite((0.3, 0.13, 0.32), Vector((0, base + 1.85, -0.03)), incl=(0.45, 0.0), bev=0.04, jit=0.01, ton=0.97)
    M.boite((0.17, 0.26, 0.06), Vector((0, base + 1.59, 0.17)), bev=0.03, jit=0.003, ton=0.05)
    for sx in (-1, 1):
        M.boite((0.06, 0.32, 0.1), Vector((sx * 0.12, base + 1.6, 0.16)), yaw=sx * -0.25, bev=0.02, jit=0.004, ton=1.0)
    M.boite((0.36, 0.1, 0.09), Vector((0, base + 1.48, 0.16)), bev=0.03, jit=0.006, ton=1.0)
    # givre posé sur les épaules, le haut de la capuche et le socle
    _givre_plaques(M, -0.34, 0.34, -0.18, 0.18, base + 1.42, 4, ep=0.016, taille=(0.08, 0.2))
    _givre_plaques(M, -0.12, 0.12, -0.12, 0.08, base + 1.86, 2, ep=0.014, taille=(0.07, 0.14))
    _givre_plaques(M, -0.4, 0.4, -0.4, 0.4, 0.64, 3, ep=0.014, taille=(0.1, 0.24))
    return M


def candelabre(nom, graine, bras=3):
    """Candélabre de fer à pied (1,45 m) : trépied, fût, coupelle, bras relevés, bougies de cire ; points de flamme dans « pts »."""
    M = Module(nom, graine)
    rg = M.rg
    for k in range(3):
        a = math.tau * k / 3 + 0.4
        M.boite((0.04, 0.34, 0.04), Vector((math.cos(a) * 0.13, 0.15, math.sin(a) * 0.13)), "fer", yaw=-a, incl=(0.0, 0.38), bev=0.008, jit=0.002, ton=0.6)
    M.cylindre(0.065, 0.045, 0.2, Vector((0, 0.3, 0)), 8, "fer", ton=0.6, jit=0.002)
    M.cylindre(0.025, 0.025, 0.7, Vector((0, 0.5, 0)), 6, "fer", ton=0.55, jit=0.002)
    M.cylindre(0.1, 0.07, 0.07, Vector((0, 1.15, 0)), 8, "fer", ton=0.6, jit=0.002)
    for k in range(bras):
        a = math.tau * k / bras + 0.2
        c = Vector((math.cos(a) * 0.17, 1.28, math.sin(a) * 0.17))
        M.boite((0.03, 0.26, 0.03), Vector((math.cos(a) * 0.1, 1.24, math.sin(a) * 0.1)), "fer", incl=(0.0, 0.0), bev=0.005, jit=0.002, ton=0.55)
        M.cylindre(0.05, 0.035, 0.05, Vector((c.x, 1.36, c.z)), 8, "fer", ton=0.6, jit=0.002)
        hc = 0.13 + 0.05 * (k % 2)
        M.cylindre(0.024, 0.022, hc, Vector((c.x, 1.41, c.z)), 6, "cire", ton=0.95, jit=0.002, bev=0.0)
        M.pts.append(Vector((c.x, 1.41 + hc + 0.01, c.z)))
    # bougie centrale
    M.cylindre(0.026, 0.024, 0.2, Vector((0, 1.22, 0)), 6, "cire", ton=0.95, jit=0.002, bev=0.0)
    M.pts.append(Vector((0, 1.43, 0)))
    return M


def lustre(nom, graine, cierges=8):
    """Lustre de fer à bougies (origine = centre du cercle, point d'accroche de la chaîne à +0,55) : couronne, rayons, coupelles, bougies, pointe."""
    M = Module(nom, graine)
    rg = M.rg
    R = 0.6
    M.tore_polygonal(R, 0.045, Vector((0, 0.0, 0)), 14, "fer", 0.55, 0.07)
    M.tore_polygonal(R - 0.1, 0.03, Vector((0, 0.02, 0)), 12, "fer", 0.5, 0.04)
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        M.boite((0.03, 0.03, R * 0.98), Vector((math.cos(a) * R * 0.5, 0.03, math.sin(a) * R * 0.5)), "fer", yaw=-a, bev=0.005, jit=0.002, ton=0.5)
        M.barre(Vector((math.cos(a) * R * 0.95, 0.04, math.sin(a) * R * 0.95)), Vector((0, 0.56, 0)), 0.014, "fer", 0.5)
    M.cylindre(0.05, 0.02, 0.2, Vector((0, -0.2, 0)), 6, "fer", ton=0.55, jit=0.002)
    M.sphere(0.065, Vector((0, 0.0, 0)), mat="fer", seg=6, ton=0.55, jit=0.003)
    M.boite((0.12, 0.05, 0.12), Vector((0, 0.56, 0)), "fer", yaw=0.4, bev=0.01, jit=0.002, ton=0.55)
    for k in range(cierges):
        a = math.tau * (k + 0.5) / cierges
        c = Vector((math.cos(a) * R, 0.035, math.sin(a) * R))
        M.cylindre(0.055, 0.04, 0.06, c + Vector((0, 0.0, 0)), 8, "fer", ton=0.6, jit=0.002)
        hc = 0.12 + 0.05 * (k % 3)
        M.cylindre(0.026, 0.024, hc, c + Vector((0, 0.06, 0)), 6, "cire", ton=0.95, jit=0.002, bev=0.0)
        M.pts.append(Vector((c.x, 0.06 + hc + 0.02, c.z)))
    return M


def marches(nom, larg, nb, graine, contre=0.17, giron=0.36):
    """Volée de marches usées (descente vers -z, la 1re marche est la plus haute) : arêtes écornées, creux d'usure, bord épaufré."""
    M = Module(nom, graine)
    rg = M.rg
    for k in range(nb):
        h = contre * (nb - k)
        w = larg - rg.uniform(0.0, 0.08)
        M.boite((w, h, giron + 0.02), Vector((rg.uniform(-0.02, 0.02), h * 0.5, -k * giron)), bev=0.03, jit=0.014, ton=rg.uniform(0.82, 1.0), incl=(rg.uniform(-0.01, 0.01), rg.uniform(-0.01, 0.01)))
    return M


def pilier_libre(nom, h, graine, larg=1.0):
    """Pilier ISOLÉ (C4, 2026-10-23) : socle à deux ressauts, fût en assises de deux blocs croisés d'une assise à l'autre
    (joints alternés), chapiteau à trois ressauts. Centré sur l'origine, hauteur totale h. La collision reste celle du kit (boîte)."""
    M = Module(nom, graine)
    rg = M.rg
    w = larg
    M.boite((w + 0.36, 0.26, w + 0.36), Vector((0, 0.13, 0)), bev=0.03, jit=0.012)
    M.boite((w + 0.18, 0.16, w + 0.18), Vector((0, 0.34, 0)), bev=0.025, jit=0.01)
    y = 0.42
    fin = h - 0.62
    rang = 0
    while y < fin - 0.05:
        hc = min(rg.uniform(0.34, 0.56), fin - y)
        if fin - y - hc < 0.18:
            hc = fin - y
        cut = rg.uniform(-0.12, 0.12) * w
        for s_ in (-1, 1):
            a0 = -w * 0.5 if s_ < 0 else cut
            a1 = cut if s_ < 0 else w * 0.5
            lw = a1 - a0 - 0.02
            c = (a0 + a1) * 0.5
            dims = (lw, hc - 0.025, w + rg.uniform(-0.03, 0.015)) if rang % 2 == 0 else (w + rg.uniform(-0.03, 0.015), hc - 0.025, lw)
            pos = Vector((c, y + hc * 0.5, 0)) if rang % 2 == 0 else Vector((0, y + hc * 0.5, c))
            M.boite(dims, pos, bev=0.035, jit=0.012, ton=rg.uniform(0.74, 1.0), incl=(rg.uniform(-0.005, 0.005), rg.uniform(-0.005, 0.005)))
        y += hc
        rang += 1
    M.boite((w + 0.1, 0.16, w + 0.1), Vector((0, fin + 0.08, 0)), bev=0.025, jit=0.01)
    M.boite((w + 0.24, 0.2, w + 0.24), Vector((0, fin + 0.26, 0)), bev=0.03, jit=0.012)
    M.boite((w + 0.38, 0.26, w + 0.38), Vector((0, fin + 0.49, 0)), bev=0.03, jit=0.012)
    return M


def _octo(r, a):
    """Sommet d'octogone de rayon r (sommets à pi/8 + k pi/4, comme CrypteDecor.tour(..., 8, PI / 8))."""
    return Vector((math.cos(a) * r, 0, math.sin(a) * r))


def _anneau_octo(M, r_ext, r_int, y0, y1, ton=None, segs=8, par_cote=1, decal=0.0):
    """Anneau octogonal de blocs entre les apothèmes r_int et r_ext, de y0 à y1. C4b : chaque côté coupé en `par_cote` blocs
    (joints décalés de `decal` bloc d'une assise à l'autre), joints de 1,5 cm, dessus légèrement inégal."""
    rg = M.rg
    nb = segs * par_cote
    for k in range(nb):
        g = 0.016 / max(0.3, r_ext)
        a0 = math.tau * (k + decal) / nb + math.pi / 8 + g
        a1 = math.tau * (k + 1 + decal) / nb + math.pi / 8 - g
        yt = y1 + rg.uniform(-0.014, 0.006)
        pts = []
        # le bloc suit l'octogone (côtés droits) ; un bloc à cheval sur un angle prend aussi le sommet de l'angle
        angs = [a0]
        c = math.ceil((a0 - math.pi / 8) / (math.tau / 8))
        while math.tau * c / 8 + math.pi / 8 < a1:
            angs.append(math.tau * c / 8 + math.pi / 8)
            c += 1
        angs.append(a1)
        for a in angs:
            cote = math.floor((a - math.pi / 8) / (math.tau / 8) + 1e-6)
            c0 = math.tau * cote / 8 + math.pi / 8
            for r in (r_ext, r_int):
                p0 = _octo(r, c0)
                p1 = _octo(r, c0 + math.tau / 8)
                t = (a - c0) / (math.tau / 8)
                q = p0.lerp(p1, min(1.0, max(0.0, t)))
                pts.append(Vector((q.x, y0, q.z)))
                pts.append(Vector((q.x, yt, q.z)))
        M.coin(pts, bev=0.022, jit=0.006, ton=ton if ton is not None else rg.uniform(0.7, 1.0))


def _palier_octo(M, r, r_in, y0, y1):
    """Palier octogonal en assises de petits blocs (comme la maçonnerie des murs de la planche) + chaperon débordant."""
    rg = M.rg
    h = y1 - y0 - 0.07
    nas = max(1, int(round(h / 0.21)))
    ha = h / nas
    pc = max(2, int(round(r * 2 * math.tan(math.pi / 8) / 0.55)))
    for j in range(nas):
        _anneau_octo(M, r - 0.02, max(0.05, r_in), y0 + j * ha, y0 + (j + 1) * ha - 0.012, par_cote=pc, decal=0.5 * (j % 2))
    # chaperon : dalles débordantes de 4 cm, arête claire
    _anneau_octo(M, r + 0.04, max(0.05, r - 0.34), y1 - 0.07, y1, par_cote=max(2, pc - 1), decal=0.25, ton=None)


def plateforme_octo(nom, graine, paliers, bassin=None):
    """Plate-forme octogonale à degrés (vasque du rituel, autel des Os). C4b : paliers en assises de petits blocs à joints décalés,
    chaperons débordants, margelle en blocs, dessus en dalles rayonnantes sur deux couronnes, givre sur les arêtes ; ou BASSIN
    (margelle, fond sombre, emplacement d'eau) si `bassin` = (r_int, haut_margelle, fond)."""
    M = Module(nom, graine)
    rg = M.rg
    for i, (r, y0, y1) in enumerate(paliers):
        r_in = paliers[i + 1][0] - 0.12 if i + 1 < len(paliers) else (bassin[0] if bassin else r * 0.45)
        _palier_octo(M, r, r_in, y0, y1)
        # givre sur le chaperon (quelques plaques le long du bord)
        for k in range(9):
            a = rg.uniform(0, math.tau)
            q = _octo(r - 0.13, a)
            _givre_eclat(M, Vector((q.x, y1, q.z)), rg.uniform(0.04, 0.09))
    r, y0, y1 = paliers[-1]
    if bassin:
        ri, hm, fond = bassin
        _anneau_octo(M, ri + 0.05, ri - 0.22, y1 - 0.05, y1 + hm, par_cote=3, decal=0.0)          # margelle
        pts = []
        for k in range(8):
            q = _octo(ri - 0.2, math.tau * k / 8 + math.pi / 8)
            pts.append(Vector((q.x, fond - 0.1, q.z)))
            pts.append(Vector((q.x, fond, q.z)))
        M.coin(pts, bev=0.0, jit=0.0, ton=0.35)                                       # fond du bassin (l'eau du lot C5 viendra dessus)
    else:
        ri = r * 0.45
        _anneau_octo(M, r - 0.3, ri + 0.04, y1 - 0.08, y1, par_cote=2, decal=0.0)      # couronne extérieure de dalles
        for k in range(8):                                                             # dalles rayonnantes du centre
            a0 = math.tau * k / 8 + math.pi / 8 + 0.02
            a1 = math.tau * (k + 1) / 8 + math.pi / 8 - 0.02
            pts = [Vector((0, y1 - 0.08, 0)), Vector((0, y1, 0))]
            for a in (a0, a1):
                q = _octo(ri, a)
                pts += [Vector((q.x, y1 - 0.08, q.z)), Vector((q.x, y1 + rg.uniform(-0.01, 0.006), q.z))]
            M.coin(pts, bev=0.012, jit=0.004)
    return M


def _estrade(M, sx, sy, sz, y0=0.0, dalle=0.95):
    """Massif rectangulaire (centré, du sol y0 à y0 + sy) : parement de blocs en assises sur les 4 faces, dalles irrégulières dessus, bordure."""
    rg = M.rg
    # noyau caché (bouche les joints), en morceaux de 1,5 m au plus : un grand triangle élargirait l'AABB du maillage de sa case
    ix0, iz0 = sx - 0.3, sz - 0.3
    nx0, nz0 = max(1, math.ceil(ix0 / 1.5)), max(1, math.ceil(iz0 / 1.5))
    for i in range(nx0):
        for k in range(nz0):
            M.boite((ix0 / nx0, sy - 0.02, iz0 / nz0), Vector((-ix0 * 0.5 + ix0 * (i + 0.5) / nx0, y0 + sy * 0.5 - 0.01, -iz0 * 0.5 + iz0 * (k + 0.5) / nz0)), bev=0.0, jit=0.0, ton=0.3)
    nb_assises = max(1, int(round((sy - 0.1) / 0.42)))
    ha = (sy - 0.1) / nb_assises
    for face in range(4):
        L = sx if face < 2 else sz
        sgn = 1 if face % 2 == 0 else -1
        for j in range(nb_assises):
            x = -L * 0.5 + (rg.uniform(0.0, 0.3) if j % 2 else 0.0)
            while x < L * 0.5 - 0.05:
                w = rg.choice([0.45, 0.6, 0.75, 0.9])
                if x + w > L * 0.5 - 0.2:
                    w = L * 0.5 - x
                c = x + w * 0.5
                yc = y0 + j * ha + ha * 0.5
                if face < 2:
                    M.boite((w - 0.025, ha - 0.025, 0.3), Vector((c, yc, sgn * (sz * 0.5 - 0.15))), bev=0.025, jit=0.01, ton=rg.uniform(0.72, 1.0))
                else:
                    M.boite((0.3, ha - 0.025, w - 0.025), Vector((sgn * (sx * 0.5 - 0.15), yc, c)), bev=0.025, jit=0.01, ton=rg.uniform(0.72, 1.0))
                x += w
    # dessus : bordure de 0,3 m débordante puis dalles irrégulières
    yt = y0 + sy
    for face in range(4):
        L = sx + 0.08 if face < 2 else sz - 0.52
        sgn = 1 if face % 2 == 0 else -1
        x = -L * 0.5
        while x < L * 0.5 - 0.05:
            w = min(rg.choice([0.6, 0.8, 1.0]), L * 0.5 - x)
            c = x + w * 0.5
            if face < 2:
                M.boite((w - 0.02, 0.1, 0.34), Vector((c, yt - 0.05, sgn * (sz * 0.5 - 0.13))), bev=0.022, jit=0.008, ton=rg.uniform(0.78, 1.0))
            else:
                M.boite((0.34, 0.1, w - 0.02), Vector((sgn * (sx * 0.5 - 0.13), yt - 0.05, c)), bev=0.022, jit=0.008, ton=rg.uniform(0.78, 1.0))
            x += w
    # C4b : dalles en rangs de largeurs variées (joints décalés d'un rang à l'autre, comme le sol de la planche), quelques fissurées
    ix, iz = sx - 0.6, sz - 0.6
    nz = max(1, int(round(iz / dalle)))
    for k in range(nz):
        z0 = -iz * 0.5 + iz * k / nz
        z1 = -iz * 0.5 + iz * (k + 1) / nz
        x = -ix * 0.5
        while x < ix * 0.5 - 0.05:
            w = min(dalle * rg.choice([0.6, 0.8, 1.0, 1.25]), ix * 0.5 - x)
            if ix * 0.5 - x - w < 0.3:
                w = ix * 0.5 - x
            cx = x + w * 0.5
            cz = (z0 + z1) * 0.5
            ton = rg.uniform(0.7, 1.0)
            yy = yt - 0.04 + rg.uniform(-0.01, 0.006)
            if rg.random() < 0.12 and w > 0.5:      # dalle fendue en deux morceaux
                f = rg.uniform(0.35, 0.65)
                M.boite((w * f - 0.03, 0.08, z1 - z0 - 0.03), Vector((x + w * f * 0.5, yy, cz)), yaw=rg.uniform(-0.03, 0.03), bev=0.016, jit=0.008, ton=ton)
                M.boite((w * (1 - f) - 0.03, 0.08, z1 - z0 - 0.03), Vector((x + w * f + w * (1 - f) * 0.5, yy - 0.008, cz)), yaw=rg.uniform(-0.03, 0.03), bev=0.016, jit=0.008, ton=ton * 0.92)
            else:
                M.boite((w - 0.03, 0.08, z1 - z0 - 0.03), Vector((cx, yy, cz)), yaw=rg.uniform(-0.015, 0.015), bev=0.016, jit=0.006, ton=ton)
            x += w
    # givre en plaques le long de la bordure
    for face in range(4):
        L = sx if face < 2 else sz
        sgn = 1 if face % 2 == 0 else -1
        for _ in range(max(3, int(L / 0.8))):
            a = rg.uniform(-L * 0.47, L * 0.47)
            p = Vector((a, yt, sgn * (sz * 0.5 - 0.1))) if face < 2 else Vector((sgn * (sx * 0.5 - 0.1), yt, a))
            _givre_eclat(M, p, rg.uniform(0.04, 0.1))


def estrade(nom, graine, sx, sy, sz, y0=0.0):
    M = Module(nom, graine)
    _estrade(M, sx, sy, sz, y0)
    return M


def degres(nom, graine, paliers):
    """Estrade à degrés (arène) : paliers (largeur x, hauteur, profondeur z) empilés depuis le sol."""
    M = Module(nom, graine)
    y = 0.0
    for (sx, sy, sz) in paliers:
        _estrade(M, sx, sy, sz, y, dalle=0.9)
        y += sy
    return M


def piece_fer_chaine(nom, graine):
    M = Module(nom, graine)
    return M


# ------------------------------------------------------------------ D/crypte_restes : mécanismes de la galerie et de la citerne
def socle_pivot(nom, graine):
    """Socle FIXE des statues à orienter (Mecanisme.Statues, encombrement v1 : 1 x 0,3 x 1 m) : plinthe, assise de blocs, dalle
    de dessus creusée d'une rainure circulaire (la statue y tourne) et quatre crans gravés aux points cardinaux."""
    M = Module(nom, graine)
    rg = M.rg
    M.boite((1.1, 0.08, 1.1), Vector((0, 0.04, 0)), bev=0.025, jit=0.008, ton=0.78)
    cut = rg.uniform(-0.12, 0.12)
    for s_ in (-1, 1):
        a0, a1 = (-0.49, cut) if s_ < 0 else (cut, 0.49)
        M.boite((a1 - a0 - 0.02, 0.15, 0.98), Vector(((a0 + a1) * 0.5, 0.155, 0)), bev=0.03, jit=0.01, ton=rg.uniform(0.78, 0.98))
    M.boite((1.04, 0.07, 1.04), Vector((0, 0.265, 0)), bev=0.02, jit=0.005, ton=0.94)
    M.cylindre(0.47, 0.47, 0.012, Vector((0, 0.296, 0)), 16, "gravure", ton=0.35, jit=0.0)      # rainure sombre où tourne le plateau
    for k in range(4):      # crans des quatre directions (nord, est, sud, ouest du repère du module)
        a = k * math.pi / 2
        d = Vector((math.sin(a), 0, -math.cos(a)))
        M.boite((0.08, 0.014, 0.05), Vector((0, 0.302, 0)) + d * 0.5, "gravure", yaw=-a, bev=0.0, jit=0.0, ton=0.4)
    _givre_plaques(M, -0.52, 0.52, -0.52, 0.52, 0.3, 2, taille=(0.1, 0.22))
    return M


def statue_guide(nom, graine):
    """Ancêtre de pierre qui MONTRE une direction (statue à orienter de la galerie) : plateau tournant cranté (flèche gravée vers
    l'avant), robe à plis, manteau, capuche ouverte sur l'avant (visage dans l'ombre), bras droit tendu vers l'avant (index), main
    gauche sur la poitrine. Origine = dessus du socle fixe (0,3 m) ; hauteur 1,72 m ; face avant +z (le regard et le bras)."""
    M = Module(nom, graine)
    rg = M.rg
    M.cylindre(0.44, 0.44, 0.07, Vector((0, 0.0, 0)), 16, ton=0.86, jit=0.003)      # plateau tournant
    M.coin([Vector((0, 0.07, 0.43)), Vector((-0.09, 0.07, 0.27)), Vector((0.09, 0.07, 0.27)),
            Vector((0, 0.082, 0.43)), Vector((-0.09, 0.082, 0.27)), Vector((0.09, 0.082, 0.27))], "gravure", bev=0.0, ton=0.3)      # flèche
    M.boite((0.56, 0.2, 0.56), Vector((0, 0.17, 0)), bev=0.03, jit=0.008, ton=0.82)
    M.boite((0.62, 0.06, 0.62), Vector((0, 0.3, 0)), bev=0.02, jit=0.006, ton=0.9)
    base = 0.33
    prof = [(0.0, 0.3), (0.1, 0.28), (0.35, 0.26), (0.6, 0.24), (0.82, 0.22), (0.98, 0.215), (1.08, 0.26), (1.18, 0.19)]
    n = 18
    anneaux = []
    for (yy, r) in prof:
        ring = []
        f = 1.0 if yy < 1.0 else 0.4
        for k in range(n):
            a = math.tau * k / n
            pli = 1.0 + f * (0.12 * math.sin(a * 6 + 0.5) + 0.04 * math.sin(a * 11 - yy * 3.0))
            ring.append(Vector((math.cos(a) * r * pli, base + yy, math.sin(a) * r * pli * 0.88)))
        anneaux.append(ring)
    bm = bmesh.new()
    vv = [[bm.verts.new(B(p)) for p in ring] for ring in anneaux]
    for i in range(len(vv) - 1):
        for k in range(n):
            bm.faces.new((vv[i][k], vv[i][(k + 1) % n], vv[i + 1][(k + 1) % n], vv[i + 1][k]))
    bm.faces.new(vv[-1][::-1])
    M._emettre(bm, "pierre", 0.9)
    # manteau dans le dos, ceinture, épaules
    M.boite((0.56, 1.0, 0.09), Vector((0, base + 0.62, -0.22)), incl=(0.08, 0.0), bev=0.035, jit=0.01, ton=0.8)
    M.boite((0.5, 0.06, 0.42), Vector((0, base + 0.66, 0.0)), bev=0.02, jit=0.006, ton=0.72)
    M.boite((0.64, 0.18, 0.4), Vector((0, base + 1.1, 0)), bev=0.06, jit=0.012, ton=1.0)
    # bras droit tendu vers l'avant (le geste qui donne la direction) : épaule, bras, avant-bras, main, index ; manche pendante
    M.boite((0.17, 0.17, 0.2), Vector((-0.27, base + 1.08, 0.04)), bev=0.04, jit=0.008, ton=1.0)
    M.boite((0.15, 0.15, 0.36), Vector((-0.27, base + 1.07, 0.26)), incl=(0.06, 0.0), bev=0.04, jit=0.008, ton=0.98)
    M.boite((0.13, 0.13, 0.22), Vector((-0.27, base + 1.05, 0.52)), bev=0.035, jit=0.006, ton=1.0)
    M.boite((0.18, 0.2, 0.2), Vector((-0.27, base + 0.95, 0.34)), incl=(-0.25, 0.0), bev=0.04, jit=0.01, ton=0.85)      # manche
    M.boite((0.1, 0.11, 0.1), Vector((-0.27, base + 1.05, 0.67)), bev=0.025, jit=0.004, ton=1.0)      # main
    M.boite((0.035, 0.035, 0.12), Vector((-0.27, base + 1.07, 0.77)), bev=0.008, jit=0.002, ton=1.0)      # index tendu
    # bras gauche replié, main sur la poitrine
    M.boite((0.17, 0.42, 0.18), Vector((0.26, base + 0.9, 0.06)), incl=(-0.2, 0.0), bev=0.04, jit=0.008, ton=0.98)
    M.boite((0.3, 0.12, 0.13), Vector((0.12, base + 0.9, 0.22)), yaw=0.35, bev=0.035, jit=0.006, ton=1.0)
    # tête encapuchonnée : volume, ouverture très sombre vers l'avant, bords épais, pointe
    M.sphere(0.19, Vector((0, base + 1.36, -0.01)), ech=(1.0, 1.2, 1.1), seg=12, ton=0.97, jit=0.008)
    M.boite((0.26, 0.11, 0.28), Vector((0, base + 1.56, -0.03)), incl=(0.45, 0.0), bev=0.035, jit=0.008, ton=0.97)
    M.boite((0.15, 0.22, 0.05), Vector((0, base + 1.33, 0.16)), bev=0.025, jit=0.003, ton=0.05)      # visage dans l'ombre
    for sx in (-1, 1):
        M.boite((0.05, 0.28, 0.09), Vector((sx * 0.105, base + 1.34, 0.15)), yaw=sx * -0.25, bev=0.018, jit=0.004, ton=1.0)
    M.boite((0.3, 0.08, 0.08), Vector((0, base + 1.23, 0.15)), bev=0.025, jit=0.005, ton=1.0)
    M.boite((0.16, 0.05, 0.07), Vector((0, base + 1.47, 0.16)), bev=0.015, jit=0.003, ton=1.0)      # front de la capuche
    _givre_plaques(M, -0.3, 0.3, -0.16, 0.16, base + 1.19, 3, ep=0.014, taille=(0.07, 0.18))
    _givre_plaques(M, -0.3, 0.3, 0.05, 0.4, 0.07, 2, ep=0.012, taille=(0.08, 0.16))
    return M


def brasero_v2(nom, graine):
    """Brasero de la citerne (Mecanisme.Braseros, encombrement v1 : 0,7 m, vasque à 1,1 m) : plinthe carrée en blocs, fût octogonal
    en deux tambours, chapiteau, vasque de fer évasée tenue par quatre griffes, rebord cerclé. Les braises (matière changeante),
    la flamme et la lumière restent posées par le mécanisme (braises à 1,1 m, flamme à 1,14 m)."""
    M = Module(nom, graine)
    rg = M.rg
    M.boite((0.7, 0.1, 0.7), Vector((0, 0.05, 0)), bev=0.025, jit=0.008, ton=0.78)
    M.boite((0.58, 0.1, 0.58), Vector((0, 0.15, 0)), yaw=math.pi / 4 * 0.0, bev=0.025, jit=0.008, ton=0.86)
    M.cylindre(0.2, 0.18, 0.28, Vector((0, 0.2, 0)), 8, bev=0.02, jit=0.006, ton=rg.uniform(0.8, 0.95), rot=math.pi / 8)
    M.cylindre(0.18, 0.16, 0.26, Vector((0, 0.49, 0)), 8, bev=0.02, jit=0.006, ton=rg.uniform(0.82, 0.98), rot=math.pi / 8)
    M.boite((0.4, 0.08, 0.4), Vector((0, 0.79, 0)), bev=0.02, jit=0.006, ton=0.92)      # chapiteau
    M.cylindre(0.2, 0.2, 0.04, Vector((0, 0.83, 0)), 8, "fer", ton=0.5, jit=0.002)
    # vasque : tronc de cône de fer, rebord épais
    M.cylindre(0.2, 0.4, 0.24, Vector((0, 0.86, 0)), 12, "fer", ton=0.62, jit=0.003)
    M.tore_polygonal(0.42, 0.045, Vector((0, 1.11, 0)), 12, "fer", 0.72, haut=0.05)
    for k in range(4):      # griffes de fer qui tiennent la vasque
        a = math.tau * k / 4 + math.pi / 4
        d = Vector((math.cos(a), 0, math.sin(a)))
        M.barre(d * 0.17 + Vector((0, 0.8, 0)), d * 0.44 + Vector((0, 1.12, 0)), 0.018, "fer", 0.5)
        M.boite((0.05, 0.08, 0.05), d * 0.45 + Vector((0, 1.15, 0)), "fer", yaw=-a, bev=0.008, jit=0.002, ton=0.6)
    _givre_plaques(M, -0.36, 0.36, -0.36, 0.36, 0.1, 2, taille=(0.08, 0.18))
    return M


# ======================================================================= L4 objets (2026-10-26) : trône du Jarl, statuaire, autels, bassin
def _decaler(M, i0, d):
    """Décale de d (repère Godot) les triangles émis depuis l'indice i0."""
    M.tris[i0:] = [(m, tuple(p + d for p in ps), t) for (m, ps, t) in M.tris[i0:]]


def _pyramide(M, base_c, r, pointe, mat="pierre", ton=None, cotes=4, rot=0.0):
    """Pointe (corne, fleuron, dent de couronne) : base polygonale horizontale de rayon r en base_c, sommet en `pointe`."""
    pts = [base_c + Vector((math.cos(rot + math.tau * k / cotes) * r, 0, math.sin(rot + math.tau * k / cotes) * r)) for k in range(cotes)]
    M.coin(pts + [pointe], mat, bev=0.0, ton=ton)


def _anneau_vertical(M, c, r_ext, r_int, ep, segs=12, mat="pierre", ton=0.95, a0=0.0, a1=math.tau):
    """Anneau dans le plan xy (face vers +z), centré en c, épaisseur ep en z : tronçons convexes."""
    for k in range(segs):
        u0 = a0 + (a1 - a0) * k / segs
        u1 = a0 + (a1 - a0) * (k + 1) / segs
        pts = []
        for u in (u0, u1):
            for r in (r_ext, r_int):
                for dz in (-ep * 0.5, ep * 0.5):
                    pts.append(c + Vector((math.cos(u) * r, math.sin(u) * r, dz)))
        M.coin(pts, mat, bev=0.0, ton=ton)


def _disque_vertical(M, c, r, ep, segs=16, mat="pierre", ton=0.9):
    pts = []
    for k in range(segs):
        u = math.tau * k / segs
        for dz in (-ep * 0.5, ep * 0.5):
            pts.append(c + Vector((math.cos(u) * r, math.sin(u) * r, dz)))
    M.coin(pts, mat, bev=0.006, ton=ton)


def _glacons(M, x0, x1, y, z, n, long=(0.05, 0.16)):
    """Petits glaçons pendus sous une arête (cônes à 4 pans, pointe en bas)."""
    rg = M.rg
    for _ in range(n):
        h = rg.uniform(*long)
        x = rg.uniform(x0, x1)
        M.cylindre(0.0, rg.uniform(0.012, 0.024), h, Vector((x, y - h, z + rg.uniform(-0.01, 0.01))), 4, "givre", jit=0.0, ton=rg.uniform(0.55, 0.75), rot=rg.uniform(0, 1))


def _revolution(M, base, prof, n=18, plis=(7, 0.12), aplat=0.86, ton=0.9, haut_plis=None, mat="pierre", cx=0.0, cz=0.0):
    """Corps de révolution à rayon modulé (robes, cottes) : prof = [(y, r)], plis = (fréquence, amplitude)."""
    anneaux = []
    for (yy, r) in prof:
        ring = []
        f = 1.0 if haut_plis is None or yy < haut_plis else 0.35
        for k in range(n):
            a = math.tau * k / n
            pli = 1.0 + f * (plis[1] * math.sin(a * plis[0] + 0.3) + 0.03 * math.sin(a * 13 - yy * 3.0))
            ring.append(Vector((cx + math.cos(a) * r * pli, base + yy, cz + math.sin(a) * r * pli * aplat)))
        anneaux.append(ring)
    bm = bmesh.new()
    vv = [[bm.verts.new(B(p)) for p in ring] for ring in anneaux]
    for i in range(len(vv) - 1):
        for k in range(n):
            bm.faces.new((vv[i][k], vv[i][(k + 1) % n], vv[i + 1][(k + 1) % n], vv[i + 1][k]))
    bm.faces.new(vv[-1][::-1])
    bm.faces.new(vv[0])
    M._emettre(bm, mat, ton)


def _tete_dragon(M, p, sens, ech=1.0, mat="pierre"):
    """Tête de dragon sculptée au sommet d'un montant : cou qui se cambre, crâne, mâchoires ouvertes vers `sens` (x, z unitaire),
    crocs, yeux creusés, cornes rabattues, crête. p = pied du cou."""
    d = Vector((sens[0], 0, sens[1])).normalized()
    lat = Vector((-d.z, 0, d.x))
    e = ech
    yaw = math.atan2(d.x, d.z)
    c0 = p
    c1 = p + Vector((0, 0.16 * e, 0)) + d * 0.02 * e
    c2 = c1 + Vector((0, 0.1 * e, 0)) + d * 0.07 * e
    M.barre(c0, c1, 0.07 * e, "pierre", 0.9)
    M.barre(c1, c2, 0.062 * e, "pierre", 0.95)
    for k, cc in enumerate((c1, c2)):      # écailles du cou (collerettes)
        M.boite((0.17 * e, 0.035 * e, 0.17 * e), cc - Vector((0, 0.02 * e, 0)), yaw=yaw + 0.785, bev=0.01, jit=0.004, ton=0.8)
    t = c2 + d * 0.06 * e + Vector((0, 0.03 * e, 0))
    M.boite((0.15 * e, 0.12 * e, 0.17 * e), t, yaw=yaw, incl=(0.15, 0.0), bev=0.03 * e, jit=0.006, ton=1.0)      # crâne
    M.coin([t + d * 0.06 * e + lat * 0.06 * e + Vector((0, 0.03 * e, 0)), t + d * 0.06 * e - lat * 0.06 * e + Vector((0, 0.03 * e, 0)),
            t + d * 0.06 * e + lat * 0.055 * e - Vector((0, 0.0, 0)), t + d * 0.06 * e - lat * 0.055 * e,
            t + d * 0.27 * e + lat * 0.03 * e + Vector((0, 0.015 * e, 0)), t + d * 0.27 * e - lat * 0.03 * e + Vector((0, 0.015 * e, 0)),
            t + d * 0.27 * e + lat * 0.028 * e - Vector((0, 0.02 * e, 0)), t + d * 0.27 * e - lat * 0.028 * e - Vector((0, 0.02 * e, 0))],
           "pierre", bev=0.008, ton=0.98)      # mâchoire haute (museau)
    m0 = t + d * 0.05 * e - Vector((0, 0.05 * e, 0))
    M.coin([m0 + lat * 0.05 * e, m0 - lat * 0.05 * e, m0 + lat * 0.045 * e - Vector((0, 0.03 * e, 0)), m0 - lat * 0.045 * e - Vector((0, 0.03 * e, 0)),
            m0 + d * 0.19 * e + lat * 0.022 * e - Vector((0, 0.07 * e, 0)), m0 + d * 0.19 * e - lat * 0.022 * e - Vector((0, 0.07 * e, 0)),
            m0 + d * 0.19 * e + lat * 0.02 * e - Vector((0, 0.09 * e, 0)), m0 + d * 0.19 * e - lat * 0.02 * e - Vector((0, 0.09 * e, 0))],
           "pierre", bev=0.006, ton=0.85)      # mâchoire basse ouverte
    M.boite((0.07 * e, 0.05 * e, 0.12 * e), t + d * 0.15 * e - Vector((0, 0.04 * e, 0)), "gravure", yaw=yaw, incl=(0.3, 0), bev=0.0, jit=0.0, ton=0.25)      # gueule (ombre)
    for s in (-1, 1):
        _pyramide(M, t + d * 0.24 * e + lat * s * 0.022 * e - Vector((0, 0.005 * e, 0)), 0.01 * e, t + d * 0.235 * e + lat * s * 0.022 * e - Vector((0, 0.05 * e, 0)), "pierre", 1.0, 3)      # crocs
        M.boite((0.03 * e, 0.02 * e, 0.035 * e), t + d * 0.06 * e + lat * s * 0.075 * e + Vector((0, 0.025 * e, 0)), "gravure", yaw=yaw, bev=0.0, jit=0.0, ton=0.2)      # yeux
        _pyramide(M, t - d * 0.04 * e + lat * s * 0.05 * e + Vector((0, 0.05 * e, 0)), 0.025 * e, t - d * 0.2 * e + lat * s * 0.09 * e + Vector((0, 0.12 * e, 0)), "pierre", 0.92, 4)      # cornes
    for k in range(3):      # crête dorsale
        q = t - d * (0.08 + 0.08 * k) * e + Vector((0, (0.07 - 0.06 * k) * e, 0))
        _pyramide(M, q, 0.02 * e, q + Vector((0, 0.07 * e, 0)) - d * 0.04 * e, "pierre", 0.9, 3)
    return t


def trone_jarl(nom, graine):
    """Trône du Jarl (salle g4) en pierre runique ancienne et givrée. Origine = dessus de l'estrade, centre de l'assise ; face +z.
    Assise à panneau d'entrelacs, accoudoirs à têtes de dragon, haut dossier à montants runiques, médaillon à nœud, fronton à couronne
    et têtes de dragon, fourrure écrue jetée sur l'assise, givre en plaques et glaçons. Emprise 1,56 x 1,2 m, hauteur 3,3 m."""
    M = Module(nom, graine)
    rg = M.rg
    # plinthe et assise
    M.boite((1.5, 0.1, 1.16), Vector((0, 0.05, -0.04)), bev=0.03, jit=0.008, ton=0.76)
    M.boite((1.22, 0.36, 0.9), Vector((0, 0.28, -0.02)), bev=0.02, jit=0.006, ton=0.66)
    zf = 0.44
    for yy in (0.14, 0.44):      # cadre du panneau avant
        M.boite((1.12, 0.05, 0.05), Vector((0, yy, zf)), bev=0.012, jit=0.003, ton=0.98)
    for sx in (-1, 1):
        M.boite((0.07, 0.35, 0.06), Vector((sx * 0.53, 0.29, zf)), bev=0.014, jit=0.003, ton=0.96)
    M.boite((0.98, 0.25, 0.02), Vector((0, 0.29, zf - 0.012)), bev=0.0, jit=0.002, ton=0.42)      # fond en creux
    # entrelacs : deux rubans en zigzag qui se croisent (lecture « nœud » à distance)
    n = 6
    for s in (-1, 1):
        for k in range(n):
            x0 = -0.46 + 0.92 * k / n
            x1 = -0.46 + 0.92 * (k + 1) / n
            ya = 0.2 if (k % 2 == 0) == (s > 0) else 0.38
            yb = 0.38 if ya == 0.2 else 0.2
            M.barre(Vector((x0, ya, zf + 0.005)), Vector((x1, yb, zf + 0.005)), 0.017, "pierre", 0.95 if s > 0 else 0.85)
    # dalle d'assise débordante, bande runique sur la tranche avant
    M.boite((1.32, 0.08, 1.0), Vector((0, 0.5, 0.0)), bev=0.03, jit=0.006, ton=0.93)
    M.boite((1.0, 0.035, 0.02), Vector((0, 0.5, 0.505)), "gravure", bev=0.0, jit=0.0, ton=0.8)
    # fourrure écrue jetée sur l'assise, retombant devant en deux pans au bord irrégulier
    M.boite((0.98, 0.04, 0.78), Vector((0.02, 0.56, 0.0)), "fourrure", yaw=0.03, bev=0.018, jit=0.012, ton=0.6)
    M.boite((0.52, 0.26, 0.04), Vector((-0.2, 0.43, 0.53)), "fourrure", yaw=0.05, incl=(0.12, 0.0), bev=0.016, jit=0.014, ton=0.52)
    M.boite((0.46, 0.2, 0.04), Vector((0.24, 0.46, 0.535)), "fourrure", yaw=-0.04, incl=(0.1, 0.0), bev=0.016, jit=0.014, ton=0.56)
    # accoudoirs : flancs pleins à panneau, lisse, tête de dragon en bout
    for sx in (-1, 1):
        x = sx * 0.66
        M.boite((0.18, 0.72, 0.96), Vector((x, 0.42, -0.02)), bev=0.025, jit=0.006, ton=0.84)
        M.boite((0.02, 0.4, 0.62), Vector((x + sx * 0.09, 0.42, 0.0)), "gravure", bev=0.0, jit=0.0, ton=0.55)      # panneau runique du flanc
        for k in range(3):
            M.boite((0.03, 0.09, 0.03), Vector((x + sx * 0.1, 0.32 + k * 0.09, -0.12 + k * 0.12)), bev=0.006, jit=0.002, ton=1.0)
        M.boite((0.24, 0.08, 1.06), Vector((x, 0.82, 0.0)), bev=0.028, jit=0.006, ton=0.96)
        _tete_dragon(M, Vector((x, 0.82, 0.46)), (0.0, 1.0), ech=0.7)
        _givre_plaques(M, x - 0.1, x + 0.1, -0.45, 0.4, 0.86, 2, ep=0.012, taille=(0.08, 0.18))
        _glacons(M, x - 0.1, x + 0.1, 0.78, 0.53, 3)
    # dossier : dalle centrale encadrée, deux rubans d'entrelacs, montants runiques, médaillon haut (visible au-dessus du Jarl depuis l'entrée)
    zd = -0.42
    H = 2.7
    M.boite((1.1, H - 0.56, 0.2), Vector((0, (0.56 + H) * 0.5, zd)), bev=0.025, jit=0.006, ton=0.8, haut_ratio=0.96)
    zf = zd + 0.11
    M.boite((1.0, 0.07, 0.05), Vector((0, H - 0.12, zf)), bev=0.014, jit=0.003, ton=1.0)
    M.boite((1.0, 0.07, 0.05), Vector((0, 0.86, zf)), bev=0.014, jit=0.003, ton=0.95)
    for sx in (-1, 1):
        M.boite((0.06, H - 1.04, 0.05), Vector((sx * 0.47, (0.86 + H - 0.12) * 0.5, zf)), bev=0.014, jit=0.003, ton=0.98)
        n = 7      # ruban d'entrelacs vertical (deux brins croisés)
        for sb in (-1, 1):
            for k in range(n):
                y0_ = 0.95 + (H - 1.95) * k / n
                y1_ = 0.95 + (H - 1.95) * (k + 1) / n
                xa = sx * 0.36 + (0.06 if (k % 2 == 0) == (sb > 0) else -0.06)
                xb = sx * 0.36 + (-0.06 if xa > sx * 0.36 else 0.06)
                M.barre(Vector((xa, y0_, zf)), Vector((xb, y1_, zf)), 0.016, "pierre", 1.0 if sb > 0 else 0.88)
    for sx in (-1, 1):
        x = sx * 0.64
        M.boite((0.22, H - 0.05, 0.26), Vector((x, (H - 0.05) * 0.5 + 0.05, zd)), bev=0.03, jit=0.008, ton=0.92)
        for yy in (0.62, 1.3, 1.98, H - 0.02):      # bagues
            M.boite((0.27, 0.07, 0.31), Vector((x, yy, zd)), bev=0.016, jit=0.004, ton=1.0)
        for yy in (0.96, 1.64, 2.32):      # runes : traits gravés sur la face avant du montant
            M.boite((0.1, 0.4, 0.015), Vector((x, yy, zd + 0.131)), "gravure", bev=0.0, jit=0.0, ton=0.5)
        _tete_dragon(M, Vector((x, H + 0.02, zd)), (sx * 0.55, 0.84), ech=1.15)
    M.boite((0.9, 0.06, 0.02), Vector((0, 0.78, zd + 0.11)), "gravure", bev=0.0, jit=0.0, ton=0.7)      # frise runique basse
    # médaillon : anneau, croix à bras recourbés (nœud), bouton central
    c = Vector((0, H - 0.6, zd + 0.13))
    _anneau_vertical(M, c, 0.36, 0.29, 0.07, 16, "pierre", 1.0)
    _anneau_vertical(M, c + Vector((0, 0, -0.01)), 0.29, 0.07, 0.03, 12, "gravure", 0.4)      # fond sombre du médaillon
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        dd = Vector((math.cos(a), math.sin(a), 0))
        pe = Vector((-math.sin(a), math.cos(a), 0))
        M.barre(c + dd * 0.06 + Vector((0, 0, 0.02)), c + dd * 0.22 + Vector((0, 0, 0.02)), 0.022, "pierre", 1.0)
        _anneau_vertical(M, c + dd * 0.2 + pe * 0.04 + Vector((0, 0, 0.02)), 0.075, 0.045, 0.035, 6, "pierre", 0.95, a + math.pi * 0.5, a + math.pi * 1.6)
    _disque_vertical(M, c + Vector((0, 0, 0.03)), 0.07, 0.05, 10, "pierre", 1.0)
    # fronton : deux rampants qui se rejoignent au-dessus de la dalle, couronne à cinq fleurons
    for sx in (-1, 1):
        M.boite((0.7, 0.11, 0.24), Vector((sx * 0.29, H + 0.08, zd)), incl=(0.0, -sx * 0.32), bev=0.022, jit=0.005, ton=0.98)
    M.boite((0.66, 0.12, 0.22), Vector((0, H + 0.2, zd + 0.02)), bev=0.022, jit=0.004, ton=1.0)      # bandeau de couronne
    for k in range(5):
        x = (k - 2) * 0.15
        hk = 0.2 + (0.16 if k == 2 else (0.07 if k in (1, 3) else 0.0))
        _pyramide(M, Vector((x, H + 0.26, zd + 0.02)), 0.055, Vector((x, H + 0.26 + hk, zd + 0.02)), "pierre", 1.0, 4, rot=math.pi / 4)
        M.boite((0.045, 0.045, 0.03), Vector((x, H + 0.2, zd + 0.135)), "gravure", bev=0.0, jit=0.0, ton=0.35)      # gemmes creusées
    # givre : assise, dossier, couronne ; glaçons sous la lisse du fronton et la dalle d'assise
    _givre_plaques(M, -0.6, 0.6, -0.32, -0.12, 0.6, 3, ep=0.012, taille=(0.1, 0.24))
    _givre_plaques(M, -0.3, 0.3, zd - 0.08, zd + 0.12, H + 0.265, 2, ep=0.014, taille=(0.08, 0.18))
    _givre_plaques(M, -0.75, 0.75, -0.1, 0.12, 0.06, 4, ep=0.012, taille=(0.1, 0.26))
    for sx in (-1, 1):
        _givre_plaques(M, sx * 0.64 - 0.12, sx * 0.64 + 0.12, zd - 0.14, zd + 0.14, H + 0.02, 1, ep=0.014, taille=(0.1, 0.2))
        for k in range(3):      # givre sur les rampants (suit la pente)
            t_ = 0.2 + 0.25 * k
            _givre_eclat(M, Vector((sx * (0.6 - t_ * 0.9), H + 0.14 + t_ * 0.3, zd + rg.uniform(-0.06, 0.06))), rg.uniform(0.05, 0.08), 0.014)
    _glacons(M, -0.55, 0.55, 0.46, 0.5, 5)
    _glacons(M, -0.45, 0.45, H - 0.16, zd + 0.14, 5, long=(0.04, 0.1))
    return M


def _marche(M, sx, h, z0, z1, y0, couv=None, dalle=0.62):
    """Marche de l'estrade : massif x ∈ ±sx/2, z ∈ [z0, z1] (avant = z1), de y0 à y0 + h. Contremarche de blocs (avant et côtés),
    nez débordant en dalles chanfreinées, dalles seulement sur la partie VISIBLE (couv = (demi-largeur, z avant) de la marche du dessus)."""
    rg = M.rg
    yt = y0 + h
    ix, iz = sx - 0.4, (z1 - z0) - 0.3
    nx0, nz0 = max(1, math.ceil(ix / 1.4)), max(1, math.ceil(iz / 1.4))
    for i in range(nx0):
        for k in range(nz0):
            M.boite((ix / nx0, h - 0.03, iz / nz0), Vector((-ix * 0.5 + ix * (i + 0.5) / nx0, y0 + (h - 0.03) * 0.5, z0 + iz * (k + 0.5) / nz0)), bev=0.0, jit=0.0, ton=0.3)
    hr = h - 0.09
    # contremarche avant
    x = -sx * 0.5
    while x < sx * 0.5 - 0.05:
        w = min(rg.choice([0.42, 0.55, 0.7]), sx * 0.5 - x)
        if sx * 0.5 - x - w < 0.18:
            w = sx * 0.5 - x
        M.boite((w - 0.02, hr, 0.2), Vector((x + w * 0.5, y0 + hr * 0.5, z1 - 0.12)), bev=0.018, jit=0.006, ton=rg.uniform(0.55, 0.75))
        x += w
    # contremarches des côtés
    for sg in (-1, 1):
        z = z0
        while z < z1 - 0.2:
            w = min(rg.choice([0.5, 0.65, 0.8]), z1 - 0.2 - z)
            M.boite((0.2, hr, w - 0.02), Vector((sg * (sx * 0.5 - 0.12), y0 + hr * 0.5, z + w * 0.5)), bev=0.018, jit=0.006, ton=rg.uniform(0.55, 0.75))
            z += w
    # nez : dalles débordantes (3 cm) à l'avant et sur les côtés ; arête claire
    x = -sx * 0.5 - 0.03
    while x < sx * 0.5 + 0.03 - 0.05:
        w = min(rg.choice([0.55, 0.7, 0.85]), sx * 0.5 + 0.03 - x)
        if sx * 0.5 + 0.03 - x - w < 0.25:
            w = sx * 0.5 + 0.03 - x
        M.boite((w - 0.02, 0.09, 0.34), Vector((x + w * 0.5, yt - 0.045, z1 - 0.14)), bev=0.025, jit=0.005, ton=rg.uniform(0.88, 1.0))
        x += w
    for sg in (-1, 1):
        z = z0
        while z < z1 - 0.32:
            w = min(rg.choice([0.6, 0.8]), z1 - 0.31 - z)
            M.boite((0.3, 0.09, w - 0.02), Vector((sg * (sx * 0.5 - 0.12), yt - 0.045, z + w * 0.5)), bev=0.022, jit=0.005, ton=rg.uniform(0.82, 0.98))
            z += w
    # dalles du giron (partie visible seulement)
    gx0, gx1, gz0, gz1 = -sx * 0.5 + 0.27, sx * 0.5 - 0.27, z0, z1 - 0.31
    nz = max(1, int(round((gz1 - gz0) / dalle)))
    for k in range(nz):
        za = gz0 + (gz1 - gz0) * k / nz
        zb = gz0 + (gz1 - gz0) * (k + 1) / nz
        x = gx0
        while x < gx1 - 0.05:
            w = min(dalle * rg.choice([0.7, 1.0, 1.3]), gx1 - x)
            if gx1 - x - w < 0.2:
                w = gx1 - x
            cx, cz = x + w * 0.5, (za + zb) * 0.5
            x += w
            if couv is not None and abs(cx) + w * 0.5 < couv[0] - 0.02 and zb < couv[1] - 0.02:
                continue      # entièrement sous la marche du dessus
            M.boite((w - 0.025, 0.07, zb - za - 0.025), Vector((cx, yt - 0.035 + rg.uniform(-0.006, 0.004), cz)), yaw=rg.uniform(-0.015, 0.015), bev=0.014, jit=0.005, ton=rg.uniform(0.66, 0.92))
    # givre le long du nez
    for _ in range(max(3, int(sx / 0.6))):
        _givre_eclat(M, Vector((rg.uniform(-sx * 0.46, sx * 0.46), yt, z1 - rg.uniform(0.05, 0.25))), rg.uniform(0.04, 0.09))


def estrade_trone(nom, graine):
    """Estrade du trône du Jarl : trois marches lisibles (0,2 m de contremarche, girons de 0,45 m), plus profonde que large ;
    origine au sol sous le centre de l'assise, avant +z. Massifs : 2,9 x 3,4 / 2,4 x 2,95 / 2,0 x 2,5 m, dos commun en z = -1,9."""
    M = Module(nom, graine)
    marches_ = [(2.9, 1.5), (2.4, 1.05), (2.0, 0.6)]
    for i, (sx, z1) in enumerate(marches_):
        couv = (marches_[i + 1][0] * 0.5, marches_[i + 1][1]) if i + 1 < len(marches_) else None
        _marche(M, sx, 0.2, -1.9, z1, 0.2 * i, couv)
    # frise runique sur la contremarche haute, rosaces de givre au pied
    M.boite((1.3, 0.06, 0.02), Vector((0, 0.5, 0.6 - 0.015)), "gravure", bev=0.0, jit=0.0, ton=0.6)
    M.boite((1.0, 0.05, 0.02), Vector((0, 0.3, 1.05 - 0.015)), "gravure", bev=0.0, jit=0.0, ton=0.6)
    return M


# ------------------------------------------------------------------ statues guerrier et jarl (anciennes « tours et boîtes »)
def _socle_statue(M, plaque=True):
    """Socle des statues (encombrement v1 : 0,95 m, dessus à 0,58 m) : plinthe, dé en deux blocs, corniche, plaque gravée."""
    rg = M.rg
    M.boite((0.98, 0.14, 0.98), Vector((0, 0.07, 0)), bev=0.03, jit=0.008, ton=0.76)
    cut = rg.uniform(-0.15, 0.15)
    for s_ in (-1, 1):
        a0, a1 = (-0.43, cut) if s_ < 0 else (cut, 0.43)
        M.boite((a1 - a0 - 0.02, 0.38, 0.84), Vector(((a0 + a1) * 0.5, 0.33, 0)), bev=0.03, jit=0.008, ton=rg.uniform(0.76, 0.95))
    M.boite((0.96, 0.08, 0.96), Vector((0, 0.56, 0)), bev=0.025, jit=0.005, ton=0.92)
    if plaque:
        M.boite((0.44, 0.16, 0.03), Vector((0, 0.33, 0.425)), "gravure", bev=0.005, jit=0.002, ton=0.85)
    _givre_plaques(M, -0.46, 0.46, -0.46, 0.46, 0.6, 2, ep=0.014, taille=(0.1, 0.22))


def statue_guerrier(nom, graine):
    """Guerrier de pierre (C) : casque à nasal, barbe tressée, cotte à plis, ceinture, épaulières, cape, bouclier rond à umbo au
    bras gauche, lance tenue droite. Origine au pied du socle ; hauteur 2,42 m (à l'échelle 1) ; face avant +z."""
    M = Module(nom, graine)
    _socle_statue(M)
    b = 0.6
    _revolution(M, b, [(0.0, 0.3), (0.08, 0.29), (0.35, 0.27), (0.62, 0.25), (0.72, 0.26), (0.78, 0.25)], n=18, plis=(9, 0.06), ton=0.86)
    for sx in (-1, 1):      # pieds (bottes) sous l'ourlet
        M.boite((0.13, 0.08, 0.24), Vector((sx * 0.1, b + 0.04, 0.12)), bev=0.03, jit=0.005, ton=0.8)
    M.boite((0.52, 0.07, 0.4), Vector((0, b + 0.76, 0)), bev=0.02, jit=0.005, ton=0.72)      # ceinture
    M.boite((0.1, 0.08, 0.03), Vector((0, b + 0.76, 0.2)), bev=0.01, jit=0.002, ton=1.0)      # boucle
    M.boite((0.5, 0.44, 0.34), Vector((0, b + 1.0, 0)), bev=0.07, jit=0.008, ton=0.95, haut_ratio=1.12)      # torse
    M.boite((0.5, 1.06, 0.07), Vector((0, b + 0.78, -0.2)), incl=(0.06, 0.0), bev=0.03, jit=0.01, ton=0.72)      # cape
    for sx in (-1, 1):
        M.sphere(0.13, Vector((sx * 0.29, b + 1.2, 0)), ech=(1.0, 0.75, 1.0), seg=8, ton=1.0)      # épaulières
    # bras droit : le long du corps, poing serré sur la lance
    M.boite((0.13, 0.34, 0.14), Vector((0.33, b + 0.98, 0.02)), bev=0.035, jit=0.006, ton=0.95)
    M.boite((0.12, 0.13, 0.28), Vector((0.34, b + 0.82, 0.1)), incl=(0.2, 0), bev=0.035, jit=0.006, ton=0.95)
    M.sphere(0.065, Vector((0.36, b + 0.82, 0.24)), seg=6, ton=1.0)
    M.barre(Vector((0.36, 0.58, 0.24)), Vector((0.36, b + 1.86, 0.24)), 0.022, "pierre", 0.85)      # hampe
    q = Vector((0.36, b + 1.86, 0.24))
    M.coin([q + Vector((0.05, 0, 0)), q + Vector((-0.05, 0, 0)), q + Vector((0, 0, 0.012)), q + Vector((0, 0, -0.012)),
            q + Vector((0.035, 0.12, 0)), q + Vector((-0.035, 0.12, 0)), q + Vector((0, 0.26, 0))], "pierre", bev=0.0, ton=1.0)      # fer
    # bras gauche replié derrière le bouclier
    M.boite((0.13, 0.32, 0.14), Vector((-0.33, b + 1.0, 0.04)), bev=0.035, jit=0.006, ton=0.95)
    sc = Vector((-0.2, b + 0.88, 0.26))
    _disque_vertical(M, sc, 0.33, 0.05, 12, "pierre", 0.82)
    _anneau_vertical(M, sc + Vector((0, 0, 0.02)), 0.35, 0.3, 0.04, 12, "pierre", 0.98)
    M.sphere(0.075, sc + Vector((0, 0, 0.04)), ech=(1, 1, 0.7), seg=8, ton=1.0)      # umbo
    for k in range(4):      # planches du bouclier : sillons
        M.boite((0.015, 0.5 - 0.1 * abs(k - 1.5), 0.012), sc + Vector(((k - 1.5) * 0.13, 0, 0.026)), "gravure", bev=0.0, jit=0.0, ton=0.45)
    # cou, tête, barbe, casque
    M.cylindre(0.07, 0.065, 0.1, Vector((0, b + 1.2, 0)), 8, ton=0.9)
    M.sphere(0.115, Vector((0, b + 1.4, 0.0)), ech=(1.0, 1.15, 1.05), seg=8, ton=0.95)
    M.coin([Vector((-0.09, b + 1.36, 0.08)), Vector((0.09, b + 1.36, 0.08)), Vector((-0.08, b + 1.33, 0.0)), Vector((0.08, b + 1.33, 0.0)),
            Vector((-0.04, b + 1.14, 0.12)), Vector((0.04, b + 1.14, 0.12)), Vector((0, b + 1.12, 0.06))], "pierre", bev=0.01, ton=0.9)      # barbe
    M.sphere(0.135, Vector((0, b + 1.46, -0.01)), ech=(1.0, 0.9, 1.05), seg=8, ton=1.0)      # calotte
    M.boite((0.29, 0.04, 0.3), Vector((0, b + 1.41, -0.01)), bev=0.012, jit=0.003, ton=0.92)      # bord du casque
    M.boite((0.035, 0.12, 0.03), Vector((0, b + 1.37, 0.135)), bev=0.008, jit=0.002, ton=1.0)      # nasal
    M.boite((0.17, 0.045, 0.02), Vector((0, b + 1.4, 0.125)), "gravure", bev=0.0, jit=0.0, ton=0.15)      # fente des yeux
    M.boite((0.03, 0.2, 0.03), Vector((0, b + 1.52, 0.04)), incl=(-0.5, 0), bev=0.008, jit=0.002, ton=1.0)      # crête
    _givre_plaques(M, -0.36, 0.36, -0.12, 0.12, b + 1.27, 3, ep=0.014, taille=(0.07, 0.18))
    _givre_plaques(M, -0.08, 0.08, -0.08, 0.06, b + 1.58, 1, ep=0.012, taille=(0.06, 0.12))
    return M


def statue_jarl(nom, graine):
    """Jarl de pierre : couronne à fleurons, longue barbe, manteau à col de fourrure, robe à plis, mains croisées sur le pommeau
    d'une épée plantée pointe en bas. Origine au pied du socle ; hauteur 2,3 m ; face avant +z."""
    M = Module(nom, graine)
    _socle_statue(M)
    b = 0.6
    _revolution(M, b, [(0.0, 0.34), (0.1, 0.31), (0.4, 0.28), (0.7, 0.25), (0.86, 0.26), (0.95, 0.25)], n=20, plis=(7, 0.11), ton=0.86)
    M.boite((0.5, 0.42, 0.34), Vector((0, b + 1.08, -0.01)), bev=0.08, jit=0.008, ton=0.92, haut_ratio=1.1)
    M.boite((0.6, 1.2, 0.08), Vector((0, b + 0.66, -0.22)), incl=(0.05, 0.0), bev=0.035, jit=0.012, ton=0.74)      # manteau
    for k in range(9):      # col de fourrure : boudins autour des épaules
        a = math.pi * (k / 8.0)
        M.sphere(0.075, Vector((math.cos(a) * 0.27, b + 1.27, -math.sin(a) * 0.12 + 0.04)), ech=(1.2, 0.8, 1.0), seg=6, ton=0.82, jit=0.012)
    for sx in (-1, 1):      # bras vers l'avant, mains sur le pommeau
        M.boite((0.13, 0.36, 0.15), Vector((sx * 0.3, b + 1.04, 0.02)), incl=(-0.25, 0), bev=0.035, jit=0.006, ton=0.95)
        M.boite((0.12, 0.12, 0.24), Vector((sx * 0.17, b + 0.88, 0.17)), yaw=-sx * 0.6, bev=0.035, jit=0.006, ton=0.95)
    M.boite((0.2, 0.11, 0.12), Vector((0, b + 0.86, 0.29)), bev=0.035, jit=0.006, ton=1.0)      # mains jointes
    zl = 0.33
    M.sphere(0.04, Vector((0, b + 0.95, zl)), seg=6, ton=1.0)      # pommeau
    M.boite((0.04, 0.12, 0.04), Vector((0, b + 0.82, zl)), bev=0.008, jit=0.002, ton=0.9)
    M.boite((0.34, 0.05, 0.06), Vector((0, b + 0.74, zl)), bev=0.012, jit=0.002, ton=1.0)      # garde
    M.coin([Vector((-0.04, b + 0.72, zl - 0.012)), Vector((0.04, b + 0.72, zl - 0.012)), Vector((-0.04, b + 0.72, zl + 0.012)), Vector((0.04, b + 0.72, zl + 0.012)),
            Vector((-0.032, 0.68, zl - 0.01)), Vector((0.032, 0.68, zl - 0.01)), Vector((0, 0.6, zl))], "pierre", bev=0.0, ton=0.95)      # lame
    M.boite((0.012, 0.5, 0.01), Vector((0, b + 0.4, zl + 0.012)), "gravure", bev=0.0, jit=0.0, ton=0.4)      # gouttière
    M.cylindre(0.07, 0.065, 0.1, Vector((0, b + 1.24, 0)), 8, ton=0.9)
    M.sphere(0.115, Vector((0, b + 1.44, 0.0)), ech=(1.0, 1.15, 1.05), seg=10, ton=0.95)
    M.coin([Vector((-0.1, b + 1.42, 0.07)), Vector((0.1, b + 1.42, 0.07)), Vector((-0.09, b + 1.38, -0.01)), Vector((0.09, b + 1.38, -0.01)),
            Vector((-0.05, b + 1.06, 0.14)), Vector((0.05, b + 1.06, 0.14)), Vector((0, b + 1.0, 0.1))], "pierre", bev=0.01, ton=0.88)      # longue barbe
    M.boite((0.12, 0.025, 0.02), Vector((0, b + 1.33, 0.12)), "gravure", bev=0.0, jit=0.0, ton=0.25)      # bouche
    for sx in (-1, 1):
        M.boite((0.04, 0.025, 0.02), Vector((sx * 0.045, b + 1.47, 0.11)), "gravure", bev=0.0, jit=0.0, ton=0.15)      # yeux
    M.boite((0.03, 0.06, 0.04), Vector((0, b + 1.43, 0.12)), bev=0.008, jit=0.002, ton=1.0)      # nez
    yc = b + 1.53
    M.cylindre(0.13, 0.135, 0.07, Vector((0, yc, 0.0)), 10, ton=1.0)      # bandeau de couronne
    for k in range(6):
        a = math.tau * k / 6 + math.pi / 2
        p = Vector((math.cos(a) * 0.12, yc + 0.07, math.sin(a) * 0.12))
        _pyramide(M, p, 0.03, p + Vector((0, 0.1, 0)), "pierre", 1.0, 4, rot=a)
    _givre_plaques(M, -0.3, 0.3, -0.14, 0.12, b + 1.32, 3, ep=0.014, taille=(0.07, 0.18))
    return M


# ------------------------------------------------------------------ autels, table d'embaumement, sarcophage pillé, bassin
def autel_chapelle(nom, graine, L):
    """Autel de chapelle (L x 0,9 m, dessus à 0,99 m, comme la v1) : plinthe, massif en blocs assisés, pilastres d'angle, panneau
    d'inscription encadré sur la face avant (+z), table débordante chanfreinée, givre. La nappe et les bougies restent posées à part."""
    M = Module(nom, graine)
    rg = M.rg
    M.boite((L + 0.1, 0.1, 0.96), Vector((0, 0.05, 0)), bev=0.03, jit=0.008, ton=0.76)
    M.boite((L - 0.06, 0.78, 0.84), Vector((0, 0.49, 0)), bev=0.0, jit=0.0, ton=0.5)      # noyau
    y = 0.1
    for j, hc in enumerate((0.27, 0.27, 0.25)):
        for face in (-1, 1):
            x = -L * 0.5 + 0.18 + (rg.uniform(0.1, 0.3) if j % 2 else 0.0)
            while x < L * 0.5 - 0.2:
                w = min(rg.choice([0.45, 0.6, 0.75]), L * 0.5 - 0.18 - x)
                if L * 0.5 - 0.18 - x - w < 0.15:
                    w = L * 0.5 - 0.18 - x
                M.boite((w - 0.02, hc - 0.02, 0.12), Vector((x + w * 0.5, y + hc * 0.5, face * 0.405)), bev=0.02, jit=0.006, ton=rg.uniform(0.7, 0.92))
                x += w
        y += hc
    for sx in (-1, 1):
        for sz in (-1, 1):
            M.boite((0.2, 0.8, 0.2), Vector((sx * (L * 0.5 - 0.09), 0.5, sz * 0.36)), bev=0.025, jit=0.006, ton=rg.uniform(0.86, 1.0))
        M.boite((0.12, 0.76, 0.56), Vector((sx * (L * 0.5 - 0.03), 0.49, 0)), bev=0.02, jit=0.006, ton=0.8)
    # panneau avant : cadre, fond creux, inscription, rosaces
    pw = min(L * 0.62, 2.6)
    M.boite((pw + 0.1, 0.05, 0.05), Vector((0, 0.74, 0.47)), bev=0.012, jit=0.003, ton=0.98)
    M.boite((pw + 0.1, 0.05, 0.05), Vector((0, 0.22, 0.47)), bev=0.012, jit=0.003, ton=0.9)
    for sx in (-1, 1):
        M.boite((0.05, 0.52, 0.05), Vector((sx * (pw * 0.5 + 0.03), 0.48, 0.47)), bev=0.012, jit=0.003, ton=0.95)
        for a in range(4):      # rosace à quatre pétales de part et d'autre
            ang = a * math.pi * 0.5 + math.pi * 0.25
            M.boite((0.07, 0.07, 0.04), Vector((sx * (pw * 0.5 + 0.22) + math.cos(ang) * 0.06, 0.48 + math.sin(ang) * 0.06, 0.475)), bev=0.014, jit=0.002, ton=0.97)
    M.boite((pw, 0.46, 0.02), Vector((0, 0.48, 0.452)), "gravure", bev=0.0, jit=0.002, ton=0.75)
    # table débordante en deux dalles, givre
    cut = rg.uniform(-0.2, 0.2) * L * 0.3
    for s_ in (-1, 1):
        a0, a1 = (-(L + 0.16) * 0.5, cut) if s_ < 0 else (cut, (L + 0.16) * 0.5)
        M.boite((a1 - a0 - 0.015, 0.1, 1.06), Vector(((a0 + a1) * 0.5, 0.94, 0)), bev=0.03, jit=0.006, ton=rg.uniform(0.88, 1.0))
    M.boite((L + 0.04, 0.05, 0.98), Vector((0, 0.865, 0)), bev=0.015, jit=0.004, ton=0.7)      # filet sous la table
    _givre_plaques(M, -L * 0.5, L * 0.5, 0.3, 0.52, 0.99, max(2, int(L * 1.2)), ep=0.012, taille=(0.08, 0.22))
    _givre_plaques(M, -L * 0.5, L * 0.5, -0.52, 0.52, 0.1, max(2, int(L)), ep=0.012, taille=(0.1, 0.24))
    _glacons(M, -L * 0.45, L * 0.45, 0.89, 0.535, max(3, int(L * 2)))
    return M


def table_embaumement_v2(nom, graine):
    """Table d'embaumement (encombrement v1 : dalle 2,1 x 0,86 m, dessus à 0,95 m) : deux piliers moulurés, entretoise, dalle à
    rebord et rigole d'écoulement creusée qui se vide par un bec au bout (+x), éclats et givre. Bandelettes, bol, linceul : à part."""
    M = Module(nom, graine)
    rg = M.rg
    for sx in (-1, 1):
        x = sx * 0.7
        M.boite((0.44, 0.1, 0.8), Vector((x, 0.05, 0)), bev=0.025, jit=0.008, ton=0.76)
        M.boite((0.32, 0.58, 0.66), Vector((x, 0.39, 0)), bev=0.03, jit=0.008, ton=rg.uniform(0.78, 0.9), haut_ratio=0.92)
        M.boite((0.42, 0.08, 0.76), Vector((x, 0.72, 0)), bev=0.02, jit=0.006, ton=0.94)
        M.boite((0.02, 0.36, 0.3), Vector((x + sx * 0.0, 0.4, 0.33)), "gravure", bev=0.0, jit=0.0, ton=0.55)      # panneau gravé
    M.boite((1.0, 0.12, 0.4), Vector((0, 0.26, 0)), bev=0.025, jit=0.008, ton=0.8)      # entretoise
    M.boite((2.1, 0.11, 0.86), Vector((0, 0.82, 0)), bev=0.03, jit=0.006, ton=0.9)
    for sz in (-1, 1):      # rebords longs
        M.boite((2.06, 0.05, 0.22), Vector((0, 0.9, sz * 0.31)), bev=0.016, jit=0.003, ton=rg.uniform(0.92, 1.0))
    for sx in (-1, 1):      # rebords courts
        M.boite((0.18, 0.05, 0.4), Vector((sx * 0.94, 0.9, 0)), bev=0.016, jit=0.003, ton=0.95)
    M.boite((1.7, 0.012, 0.38), Vector((0, 0.881, 0)), "gravure", bev=0.0, jit=0.0, ton=0.35)      # fond de la rigole (sombre)
    M.boite((0.22, 0.05, 0.08), Vector((1.12, 0.87, 0)), bev=0.012, jit=0.003, ton=0.9)      # bec d'écoulement
    M.boite((0.18, 0.01, 0.04), Vector((1.12, 0.896, 0)), "gravure", bev=0.0, jit=0.0, ton=0.3)
    M.boite((0.16, 0.1, 0.14), Vector((-1.0, 0.86, 0.38)), yaw=0.5, incl=(0.2, 0.1), bev=0.02, jit=0.015, ton=0.82)      # éclat au coin
    _givre_plaques(M, -1.0, 1.0, 0.22, 0.42, 0.925, 3, ep=0.01, taille=(0.08, 0.2))
    _givre_plaques(M, -1.0, 1.0, -0.42, -0.22, 0.925, 2, ep=0.01, taille=(0.08, 0.2))
    return M


def sarcophage_pille(nom, graine):
    """Sarcophage pillé (encombrement v1 : cuve 2,2 x 0,9 x 0,7 m) : cuve sculptée ouverte (intérieur noir, fond de gravats),
    couvercle brisé repoussé de travers, un éclat tombé au sol, pied-de-biche de fer. Long axe x, avant +z."""
    M = Module(nom, graine)
    rg = M.rg
    L, W = 2.2, 0.9
    M.boite((L + 0.16, 0.1, W + 0.14), Vector((0, 0.05, 0)), bev=0.03, jit=0.01, ton=0.76)
    y0, hc = 0.1, 0.6
    ep = 0.1
    for sz in (-1, 1):      # parois longues
        M.boite((L, hc, ep), Vector((0, y0 + hc * 0.5, sz * (W * 0.5 - ep * 0.5))), bev=0.02, jit=0.006, ton=0.68)
    for sx in (-1, 1):
        M.boite((ep, hc, W - 2 * ep), Vector((sx * (L * 0.5 - ep * 0.5), y0 + hc * 0.5, 0)), bev=0.02, jit=0.006, ton=0.68)
        for sz in (-1, 1):      # pilastres d'angle
            M.boite((0.16, hc, 0.16), Vector((sx * (L * 0.5 - 0.07), y0 + hc * 0.5, sz * (W * 0.5 - 0.07))), bev=0.025, jit=0.006, ton=rg.uniform(0.9, 1.0))
    M.boite((L - 2 * ep, 0.02, W - 2 * ep), Vector((0, y0 + 0.15, 0)), "noir", bev=0.0, jit=0.0, ton=1.0)      # fond (ombre)
    for k in range(5):      # gravats et os brisés au fond
        M.boite((rg.uniform(0.08, 0.18), 0.06, rg.uniform(0.06, 0.14)), Vector((rg.uniform(-0.8, 0.8), y0 + 0.18, rg.uniform(-0.22, 0.22))), yaw=rg.uniform(0, 3), bev=0.012, jit=0.01, ton=rg.uniform(0.5, 0.7))
    # panneaux de la face avant (cadres + croix)
    n = 3
    pw = (L - 0.32) / n
    for k in range(n):
        x = -L * 0.5 + 0.16 + pw * (k + 0.5)
        zc = W * 0.5 + 0.01
        yp, hp = y0 + hc * 0.45, hc * 0.56
        M.boite((pw - 0.06, 0.05, 0.04), Vector((x, yp + hp * 0.5, zc)), bev=0.012, jit=0.003, ton=0.98)
        M.boite((pw - 0.06, 0.05, 0.04), Vector((x, yp - hp * 0.5, zc)), bev=0.012, jit=0.003, ton=0.9)
        for sx in (-1, 1):
            M.boite((0.05, hp, 0.04), Vector((x + sx * (pw * 0.5 - 0.055), yp, zc)), bev=0.012, jit=0.003, ton=0.95)
        if k == 1:
            M.boite((0.06, hp * 0.7, 0.04), Vector((x, yp, zc + 0.01)), bev=0.012, jit=0.002, ton=1.0)
            M.boite((0.3, 0.06, 0.04), Vector((x, yp + hp * 0.12, zc + 0.01)), bev=0.012, jit=0.002, ton=1.0)
    M.boite((L - 0.4, 0.07, 0.03), Vector((0, y0 + hc - 0.07, W * 0.5 + 0.005)), "gravure", bev=0.005, jit=0.002, ton=0.85)
    for sz in (-1, 1):      # corniche (bords épaufrés)
        M.boite((L + 0.04, 0.05, 0.14), Vector((0, y0 + hc + 0.025, sz * (W * 0.5 - 0.05))), bev=0.016, jit=0.008, ton=0.95)
    # couvercle brisé : grande moitié repoussée de travers (déborde à l'arrière et à droite), petite moitié tombée contre la cuve
    yl = y0 + hc + 0.05
    M.boite((L * 0.62, 0.16, W + 0.08), Vector((L * 0.28, yl + 0.08, 0.2)), yaw=0.25, incl=(0.0, 0.05), bev=0.035, jit=0.01, ton=0.9)
    M.boite((L * 0.5, 0.1, W - 0.14), Vector((L * 0.28, yl + 0.21, 0.2)), yaw=0.25, incl=(0.0, 0.05), bev=0.03, jit=0.008, ton=0.96, haut_ratio=0.9)
    M.boite((0.1, 0.06, 0.4), Vector((L * 0.2, yl + 0.29, 0.2)), yaw=0.25, bev=0.012, jit=0.002, ton=1.0)      # bras de la croix
    M.boite((L * 0.32, 0.14, W * 0.7), Vector((-L * 0.5 - 0.12, 0.32, 0.1)), yaw=-0.4, incl=(0.0, 1.15), bev=0.03, jit=0.012, ton=0.84)      # fragment appuyé
    M.boite((0.22, 0.1, 0.16), Vector((-0.3, 0.05, W * 0.5 + 0.22)), yaw=0.7, incl=(0.2, 0.1), bev=0.02, jit=0.02, ton=0.8)      # éclat
    M.barre(Vector((-L * 0.5 - 0.25, 0.03, 0.66)), Vector((-L * 0.5 + 0.35, 0.03, 0.5)), 0.016, "fer", 0.55)      # pied-de-biche
    _givre_plaques(M, -L * 0.5, -0.1, -W * 0.5, W * 0.5, yl, 2, ep=0.012, taille=(0.08, 0.2))
    _givre_plaques(M, -0.0, L * 0.55, -0.2, 0.6, yl + 0.26, 3, ep=0.012, taille=(0.08, 0.22))
    return M


def bassin_margelle(nom, graine, w=5.0, p=4.4, h=0.5, e=0.4):
    """Margelle du bassin de la citerne (encombrement v1 : w x p, h de haut, murets de e) : murets en blocs assisés, chaperon de
    dalles débordantes vers l'intérieur et l'extérieur, faces intérieures sombres (humides), givre et glaçons sur le bord."""
    M = Module(nom, graine)
    rg = M.rg
    def muret(x0, x1, zc, long_x):
        L = x1 - x0
        for j, hc in enumerate((h * 0.5, h * 0.5 - 0.02)):
            x = x0 + (rg.uniform(0.1, 0.3) if j % 2 else 0.0)
            yy = hc * 0.5 + (0.0 if j == 0 else h * 0.5)
            while x < x1 - 0.05:
                ww = min(rg.choice([0.5, 0.7, 0.9]), x1 - x)
                if x1 - x - ww < 0.2:
                    ww = x1 - x
                c = x + ww * 0.5
                if long_x:
                    M.boite((ww - 0.02, hc - 0.02, e - 0.02), Vector((c, yy, zc)), bev=0.02, jit=0.008, ton=rg.uniform(0.6, 0.85))
                else:
                    M.boite((e - 0.02, hc - 0.02, ww - 0.02), Vector((zc, yy, c)), bev=0.02, jit=0.008, ton=rg.uniform(0.6, 0.85))
                x += ww
        # chaperon
        x = x0 - 0.05
        while x < x1 + 0.05 - 0.05:
            ww = min(rg.choice([0.6, 0.8, 1.0]), x1 + 0.05 - x)
            if x1 + 0.05 - x - ww < 0.25:
                ww = x1 + 0.05 - x
            c = x + ww * 0.5
            if long_x:
                M.boite((ww - 0.02, 0.08, e + 0.1), Vector((c, h + 0.03, zc)), bev=0.025, jit=0.006, ton=rg.uniform(0.86, 1.0))
            else:
                M.boite((e + 0.1, 0.08, ww - 0.02), Vector((zc, h + 0.03, c)), bev=0.025, jit=0.006, ton=rg.uniform(0.86, 1.0))
            x += ww
    for sg in (-1, 1):
        muret(-w * 0.5, w * 0.5, sg * (p * 0.5 - e * 0.5), True)
        muret(-(p * 0.5 - e), p * 0.5 - e, sg * (w * 0.5 - e * 0.5), False)
    for _ in range(10):
        a = rg.uniform(-1, 1)
        side = rg.randint(0, 3)
        if side < 2:
            q = Vector((a * w * 0.45, h + 0.075, (1 if side == 0 else -1) * (p * 0.5 - e * 0.5)))
        else:
            q = Vector(((1 if side == 2 else -1) * (w * 0.5 - e * 0.5), h + 0.075, a * p * 0.4))
        _givre_eclat(M, q, rg.uniform(0.05, 0.12))
    for sg in (-1, 1):
        _glacons(M, -w * 0.4, w * 0.4, h - 0.01, sg * (p * 0.5 - e - 0.04), 5, long=(0.04, 0.1))
    return M


# ======================================================================= C2 (2026-10-28) : DALLAGE v3 (sol de salle en relief)
# Chantier « anti pâte à modeler » (docs/INSPIRATION_IGNITE.md §2.2, lot C2) : le sol des salles et couloirs de la crypte n'est plus
# une texture de dalles peinte sur un plan mais de VRAIES dalles en volume. Le sol est découpé (scripts/crypte_v2.gd : dallage) en
# RANGS parallèles à x ; chaque rang est une suite de BANDES (modules « dallage_v3_<p>_<l>_<k> » : profondeur p, longueur l,
# variante k) étirées de ±15 % au plus pour tomber juste sur la pièce (aucune découpe, aucune couture de tuile visible : les bouts de
# bande sont de simples joints, et les rangs voisins ne coupent pas aux mêmes abscisses).
# Une dalle = dessus plan légèrement incliné + 4 à 6 flancs en pente qui descendent jusqu'au fond de joint (−7,2 cm) : le joint est un
# V creux de 7 cm en haut, fermé en bas, dont les couleurs de sommet descendent au noir (règle §3.1 : creux au ton 0 de la rampe
# Ombre) ; le haut des flancs garde le ton de la dalle : face à la torche rasante, il s'éclaire plus que le dessus (arête claire).
# Accidents : coins éclatés (le fond sombre se voit), dalles fendues en 2-3 morceaux (fente fine en V), dalles soulevées (une arête
# remonte de 3-4,5 cm), dalles manquantes (terre sombre + éclats). Dessus à −2,2 cm (−1,2 à +1) sous le sol de COLLISION (inchangé, plan) :
# une dalle ordinaire ne dépasse pas +1 cm, l'arête d'une dalle soulevée +3,5 cm (visuel seul : AUCUNE collision, rien ne bloque) ;
# les décalques au sol (+0,7 à +2 cm : givre, cercles gravés, halos) et la plaque de piège enfoncée (−1 cm) restent visibles.
# Budget : 10 triangles par dalle (13 si coin éclaté), ≈ 1,6 dalle/m² (voir BUDGET_DALLAGE, contrôlé à l'export).
# Pas d'occlusion par rayons ici (finir surchargée) : couleurs écrites à la main (ton par dalle x dégradé des flancs).
# NB lot C4 (piliers, même fichier) : rien ici ne touche aux autres modules ; tout est préfixé _dal_ / dallage_.

DALLAGE_LONG = (1.6, 2.2, 2.8)      # longueurs nominales des bandes (m) — mêmes valeurs dans scripts/crypte_v2.gd (DALLAGE_LONG)
DALLAGE_PROF = (0.55, 0.7, 0.85)    # profondeurs nominales des rangs (m) — idem (DALLAGE_PROF)
DALLAGE_VAR = 4                     # variantes par couple (profondeur, longueur) — idem (DALLAGE_VAR)
DAL_HAUT = -0.022                   # dessus nominal des dalles sous le sol de collision
DAL_FOND = -0.072                   # fond des joints (pied des flancs)
DAL_JOINT = 0.034                   # retrait du dessus depuis la limite de la case (joint de 7 cm entre deux dalles : 2-3 px à 3 m)
DAL_JOINT_BAS = 0.002               # retrait du pied (le V se ferme en bas)
DAL_FENTE = 0.005                   # retrait du dessus le long d'une fente
BUDGET_DALLAGE = 14.0               # triangles par dalle en moyenne, au plus (contrôlé à l'export)


class ModuleSol(Module):
    """Module de dallage : triangles à couleurs de sommet explicites (pas d'occlusion par rayons, déjà réglée à la main)."""
    def __init__(self, nom, graine):
        super().__init__(nom, graine)
        self.nb_dalles = 0

    def tri_c(self, mat, p0, p1, p2, c0, c1, c2, sortant):
        """Triangle (repère Godot) tourné pour que sa normale suive `sortant` ; c* = (r, g, b)."""
        n = (p1 - p0).cross(p2 - p0)
        if n.length_squared < 1e-14:
            return
        if n.dot(sortant) < 0:
            p1, p2, c1, c2 = p2, p1, c2, c1
        self.tris.append((mat, (p0, p1, p2), (c0, c1, c2)))

    def finir(self, *a, **k):
        sortie = {}
        te = TEINTE["pierre"]
        for m, p, t in self.tris:
            if isinstance(t, tuple):
                cols = [(min(1.0, c[0]), min(1.0, c[1]), min(1.0, c[2]), 1.0) for c in t]
            else:      # éclats posés par Module.coin (ton scalaire)
                tt = TEINTE.get(m, (1, 1, 1))
                cols = [(min(1.0, t * tt[0]), min(1.0, t * tt[1]), min(1.0, t * tt[2]), 1.0)] * 3
            sortie.setdefault(m, []).append((p, cols))
        return sortie


def _dal_aire(poly):
    s = 0.0
    for i in range(len(poly)):
        x0, z0 = poly[i]
        x1, z1 = poly[(i + 1) % len(poly)]
        s += x0 * z1 - x1 * z0
    return s * 0.5


def _dal_retrait(poly, ret):
    """Polygone convexe (x, z) dans le sens trigonométrique ; ret[i] = retrait vers l'intérieur de l'arête i (poly[i] -> poly[i+1])."""
    n = len(poly)
    lignes = []
    for i in range(n):
        x0, z0 = poly[i]
        x1, z1 = poly[(i + 1) % n]
        ex, ez = x1 - x0, z1 - z0
        L = math.hypot(ex, ez)
        ex, ez = ex / L, ez / L
        nx, nz = -ez, ex      # normale intérieure (sens trigonométrique)
        lignes.append(((x0 + nx * ret[i], z0 + nz * ret[i]), (ex, ez)))
    out = []
    for i in range(n):
        (px, pz), (ax, az) = lignes[i - 1]
        (qx, qz), (bx, bz) = lignes[i]
        den = ax * bz - az * bx
        if abs(den) < 1e-9:
            out.append((qx, qz))
            continue
        t = ((qx - px) * bz - (qz - pz) * bx) / den
        out.append((px + ax * t, pz + az * t))
    return out


def _dal_couper(poly, types, p, d):
    """Coupe un polygone convexe par la droite (p, d) : deux polygones, l'arête de coupe est de type « fente »."""
    nx, nz = -d[1], d[0]
    s = [(q[0] - p[0]) * nx + (q[1] - p[1]) * nz for q in poly]
    A, TA, Bp, TB = [], [], [], []
    n = len(poly)
    for i in range(n):
        j = (i + 1) % n
        qi, qj = poly[i], poly[j]
        if s[i] >= 0:
            A.append(qi); TA.append(types[i])
        if s[i] <= 0:
            Bp.append(qi); TB.append(types[i])
        if (s[i] > 0 and s[j] < 0) or (s[i] < 0 and s[j] > 0):
            t = s[i] / (s[i] - s[j])
            x = (qi[0] + (qj[0] - qi[0]) * t, qi[1] + (qj[1] - qi[1]) * t)
            if s[i] > 0:      # on sort de A : l'arête suivante de A est la coupe ; B commence ici sur l'arête d'origine
                A.append(x); TA.append("fente")
                Bp.append(x); TB.append(types[i])
            else:
                Bp.append(x); TB.append("fente")
                A.append(x); TA.append(types[i])
    return [(A, TA), (Bp, TB)]


def _dal_dalle(M, poly, types, ton, h0=0.0, pente=(0.0, 0.0), chaleur=0.0):
    """Une dalle : poly = contour de la case (x, z), types[i] = « joint » | « fente » | « eclat » pour l'arête i."""
    if _dal_aire(poly) < 0:
        poly = poly[::-1]
        types = types[-2::-1] + types[-1:]
    if _dal_aire(poly) < 0.004:
        return
    haut = _dal_retrait(poly, [DAL_FENTE if t == "fente" else DAL_JOINT for t in types])
    bas = _dal_retrait(poly, [0.0 if t == "fente" else (0.012 if t == "eclat" else DAL_JOINT_BAS) for t in types])
    if _dal_aire(haut) < 0.002:
        return
    cx = sum(q[0] for q in haut) / len(haut)
    cz = sum(q[1] for q in haut) / len(haut)
    hy = lambda x, z: DAL_HAUT + h0 + pente[0] * (x - cx) + pente[1] * (z - cz)
    T = [Vector((x, hy(x, z), z)) for x, z in haut]
    Bv = [Vector((x, DAL_FOND, z)) for x, z in bas]
    k = (1.0 + 0.05 * chaleur, 1.0, 1.0 - 0.06 * chaleur)
    te = TEINTE["pierre"]
    col = lambda v: (v * te[0] * k[0], v * te[1] * k[1], v * te[2] * k[2])
    usure = [M.rg.uniform(0.8, 1.0) for _ in T]      # dessus inégal : un coin plus usé / plus sale que l'autre (masses claires et sombres)
    c_arete = col(ton * 0.85)                # haut des flancs : la torche rasante les éclaire plus que le dessus (arête claire)
    c_pied = col(0.0)                        # fond de joint au noir (ton 0 de la rampe Ombre)
    centre = Vector((cx, DAL_HAUT + h0, cz))
    for i in range(1, len(T) - 1):           # dessus en éventail
        M.tri_c("pierre", T[0], T[i], T[i + 1], col(ton * usure[0]), col(ton * usure[i]), col(ton * usure[i + 1]), Vector((0, 1, 0)))
    n = len(T)
    for i in range(n):                       # flancs en pente jusqu'au fond du joint
        j = (i + 1) % n
        mil = (T[i] + T[j]) * 0.5
        sortant = Vector((mil.x - centre.x, 0.0, mil.z - centre.z))
        ca = c_arete if types[i] != "fente" else col(ton * 0.7)
        M.tri_c("pierre", T[i], T[j], Bv[j], ca, ca, c_pied, sortant)
        M.tri_c("pierre", T[i], Bv[j], Bv[i], ca, c_pied, c_pied, sortant)
    M.nb_dalles += 1


def _dal_terre(M, poly):
    """Case d'une dalle manquante : fond de terre sombre et 2-3 éclats de pierre."""
    rg = M.rg
    y = DAL_FOND + 0.014
    pts = [Vector((x, y + rg.uniform(-0.004, 0.004), z)) for x, z in poly]
    t = rg.uniform(0.36, 0.46)      # terre : nettement plus sombre que les dalles, mais pas un trou noir
    c, c2 = (t * 1.0, t * 0.9, t * 0.78), (t * 0.8, t * 0.72, t * 0.62)
    for i in range(1, len(pts) - 1):
        M.tri_c("pierre", pts[0], pts[i], pts[i + 1], c, c2, c, Vector((0, 1, 0)))
    xs = [q[0] for q in poly]
    zs = [q[1] for q in poly]
    for _ in range(rg.randint(2, 3)):
        px, pz = rg.uniform(min(xs) + 0.08, max(xs) - 0.08), rg.uniform(min(zs) + 0.08, max(zs) - 0.08)
        r = rg.uniform(0.04, 0.09)
        ch = [Vector((px + rg.uniform(-r, r), y + rg.uniform(0.0, 0.012), pz + rg.uniform(-r, r))) for _ in range(4)]
        ch.append(Vector((px + rg.uniform(-r * 0.4, r * 0.4), y + rg.uniform(0.02, 0.035), pz + rg.uniform(-r * 0.4, r * 0.4))))
        M.coin(ch, "pierre", bev=0.0, ton=rg.uniform(0.45, 0.75))


def dallage_v3(nom, graine, longueur, prof):
    """Bande de dalles (longueur le long de x, profondeur le long de z, centrée sur l'origine, sol de collision à y = 0)."""
    M = ModuleSol(nom, graine)
    rg = M.rg
    x0, z0, z1 = -longueur * 0.5, -prof * 0.5, prof * 0.5
    # largeurs : 0,5 à 1,1 m, la dernière ajustée (jamais moins de 0,45 m)
    larg = []
    reste = longueur
    while reste > 1e-6:
        w = rg.uniform(0.5, 1.1)
        if reste - w < 0.45:
            w = reste if reste <= 1.1 else reste * 0.5
        larg.append(w)
        reste -= w
    x = x0
    for w in larg:
        poly = [(x, z0), (x + w, z0), (x + w, z1), (x, z1)]
        types = ["joint"] * 4
        x += w
        ton = rg.uniform(0.7, 1.0) * (0.68 if rg.random() < 0.18 else 1.0)      # dessus clairs (masses lisibles), 18 % de dalles sombres
        chaleur = rg.uniform(-1.0, 1.0)
        tirage = rg.random()
        if tirage < 0.04:                                   # dalle manquante
            _dal_terre(M, poly)
            if rg.random() < 0.5:                           # un morceau resté en place, de travers
                cut = _dal_couper(poly, types, (poly[0][0] + w * rg.uniform(0.3, 0.6), 0.0), (rg.uniform(-0.4, 0.4), 1.0))
                morceau, tm = cut[rg.randint(0, 1)]
                if len(morceau) >= 3:
                    _dal_dalle(M, morceau, ["joint"] * len(morceau), ton * 0.85, -0.012, (rg.uniform(-0.06, 0.06), rg.uniform(-0.06, 0.06)), chaleur)
            continue
        # coin éclaté (25 %) : le coin devient une petite arête, le fond sombre se voit
        if rg.random() < 0.25:
            i = rg.randint(0, 3)
            v = poly[i]
            a, b = poly[i - 1], poly[(i + 1) % 4]
            c1, c2 = rg.uniform(0.05, 0.16), rg.uniform(0.05, 0.16)
            da = (a[0] - v[0], a[1] - v[1]); la = math.hypot(*da)
            db = (b[0] - v[0], b[1] - v[1]); lb = math.hypot(*db)
            p1 = (v[0] + da[0] / la * c1, v[1] + da[1] / la * c1)
            p2 = (v[0] + db[0] / lb * c2, v[1] + db[1] / lb * c2)
            poly = poly[:i] + [p1, p2] + poly[i + 1:]
            types = types[:i] + ["eclat"] + types[i:]      # arête p1 -> p2 = éclat ; les autres gardent leur type
        h0 = rg.uniform(-0.012, 0.01)      # avec la pente, le dessus reste sous +0,8 cm (décalques au sol à +0,7 à +2 cm)
        pente = (rg.uniform(-0.035, 0.035), rg.uniform(-0.035, 0.035))      # ±2° : la torche voisine éclaire chaque dalle un peu différemment
        if tirage < 0.10:                                   # dalle fendue en 2 ou 3 morceaux
            cxm = (poly[0][0] + poly[1][0]) * 0.5
            morceaux = _dal_couper(poly, types, (cxm + rg.uniform(-0.1, 0.1) * w, 0.0), (rg.uniform(-0.6, 0.6) * w / prof, 1.0))
            if rg.random() < 0.4:
                gros = max(range(2), key=lambda q: abs(_dal_aire(morceaux[q][0])))
                pg, tg = morceaux.pop(gros)
                cz_ = sum(q[1] for q in pg) / len(pg)
                cx_ = sum(q[0] for q in pg) / len(pg)
                morceaux += _dal_couper(pg, tg, (cx_, cz_), (1.0, rg.uniform(-0.5, 0.5)))
            for pm, tm in morceaux:
                if len(pm) >= 3:
                    _dal_dalle(M, pm, tm, ton * rg.uniform(0.86, 1.0), h0 - rg.uniform(0.0, 0.008),
                               (pente[0] + rg.uniform(-0.03, 0.03), pente[1] + rg.uniform(-0.03, 0.03)), chaleur)
            continue
        if tirage < 0.15:                                   # dalle soulevée : une arête remonte de 3 à 4,5 cm (dessus à +2 cm au plus)
            demi = (w if rg.random() < 0.5 else prof) * 0.5
            g = rg.uniform(0.03, 0.045) / demi
            pente = (g * rg.choice((-1, 1)), 0.0) if demi == w * 0.5 else (0.0, g * rg.choice((-1, 1)))
            h0 = rg.uniform(0.004, 0.01)
        _dal_dalle(M, poly, types, ton, h0, pente, chaleur)
    return M


def construire_dallage():
    """Les 36 bandes de dallage (3 profondeurs x 3 longueurs x 4 variantes) ; graines 3000 + …"""
    mods = []
    for p, pr in enumerate(DALLAGE_PROF):
        for l, lo in enumerate(DALLAGE_LONG):
            for k in range(DALLAGE_VAR):
                mods.append(dallage_v3("dallage_v3_%d_%d_%d" % (p, l, k), 3000 + 100 * p + 10 * l + k, lo, pr))
    nb = sum(len(M.tris) for M in mods)
    dalles = sum(M.nb_dalles for M in mods)
    print("DALLAGE : %d bandes, %d dalles, %d triangles (%.1f par dalle, budget %.0f)" % (len(mods), dalles, nb, nb / max(1, dalles), BUDGET_DALLAGE))
    assert nb / max(1, dalles) <= BUDGET_DALLAGE, "dallage v3 : budget de triangles par dalle dépassé"
    return mods


# ======================================================================= C4 (2026-10-28) : PILIERS ET ARCHES v3
# Chantier « anti pâte à modeler » (docs/INSPIRATION_IGNITE.md §2.3, lot C4) : les piliers v2 (pilier_mur, pilier_libre) étaient des
# empilements de boîtes à biseau de 3 cm (sous le pixel à 3 m en 640x360 : « boîtes nettes ») et les arches des voussoirs réguliers.
# v3 = mêmes noms de modules, mêmes encombrements et points d'appui (scripts/crypte_decor.gd, crypte_v2.gd, crypte_donjon.gd,
# donjon_kit.gd inchangés ; collisions inchangées), mais :
#   - blocs taillés en ENVELOPPE CONVEXE explicite (_pil_bloc) : coins verticaux abattus LARGES (6-10 cm, un par coin : usure),
#     chanfrein haut de 4-5 cm, petit chanfrein bas ; pas de biseau bmesh (44 triangles par boîte) : 30-46 triangles par bloc, faces
#     cachées (dessous posé, dos contre le mur) non émises ;
#   - le relief vient de la GÉOMÉTRIE : constat C1, les tons de pierre montent déjà à 0,9-1 (plafond 8 bits) et la couleur de sommet
#     n'éclaircit presque plus. Le ton de base des blocs descend donc à 0,66-0,84 (PIL_TON, palette Pierre de BIBLE_VISUELLE inchangée :
#     c'est le facteur de sommet) et chaque face reçoit un facteur selon son orientation (PIL_FACE) : chanfreins verticaux +20 %,
#     chanfreins hauts +34 % (ce que la torche accroche), dessous -38 %, faces de JOINT au noir (0,32) ;
#   - pierres appareillées : assises de hauteurs inégales, deux blocs croisés par assise (pilier isolé) ou une assise sur deux coupée
#     (pilier engagé), joints de 2,6 cm devant un NOYAU sombre (rien ne transparaît entre deux blocs) ;
#   - base à plinthe + talon évasé, chapiteau à bague + corbeille évasée + tailloir à chanfrein bas ;
#   - éclats : 1-2 coins de bloc arrachés par pilier (sommets tirés vers l'intérieur et vers le bas, AUCUN triangle de plus) et
#     quelques éclats au pied (pilier isolé) ;
#   - pilier_libre_8 (grandes salles, arène) : variante RONDE en tambours octogonaux (pilier_rond_v3), même encombrement ;
#   - arches : claveaux à chanfrein avant large, joints au noir, 1 claveau sur 8 descendu de 1-3 cm, quelques arêtes épaufrées,
#     clé saillante (20 triangles par claveau au lieu de 44).
# Ces modules ne passent PAS par aretes.py (ARETES_SANS) : leurs tons d'arête sont posés ici, face par face.
# Les anciennes versions (pilier_mur, pilier_libre, arche plus haut) restent dans le fichier pour mémoire ; construire() appelle les v3.
ARETES_SANS = ARETES_SANS + ("pilier_mur_", "pilier_libre_", "arche_")
PIL_TON = (0.66, 0.84)       # ton de base d'un bloc (v2 : 0,74-1,0)
PIL_FACE = {"face": 0.96, "chanfrein": 1.26, "chanfrein_haut": 1.42, "dessus": 1.1, "dessous": 0.6, "joint": 0.22}
PIL_CHANF = (0.07, 0.12)     # coins verticaux abattus (m) : 4-6 px à 3 m
PIL_CH_HAUT = 0.05           # chanfrein de l'arête haute d'un bloc
PIL_CH_BAS = 0.03            # chanfrein de l'arête basse (le joint devient un V)
PIL_JOINT = 0.034            # joint entre deux blocs
PIL_NOYAU = 0.18             # ton du noyau sombre vu dans les joints
BAS, HAUT, DOS = Vector((0, -1, 0)), Vector((0, 1, 0)), Vector((0, 0, -1))


def _pil_emettre(M, pts, ton, joints=(), cacher=(), regles=None, mat="pierre"):
    """Enveloppe convexe des points (repère Godot), émise SANS biseau. Chaque triangle prend ton x PIL_FACE[orientation] :
    face (normale horizontale dans l'axe x ou z), chanfrein (horizontale en biais), chanfrein_haut (0,25 < ny <= 0,95), dessus, dessous ;
    « joint » si la normale suit une direction de `joints` ; les triangles dont la normale suit `cacher` ne sont pas émis."""
    fac = dict(PIL_FACE)
    if regles:
        fac.update(regles)
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(B(p))
    bmesh.ops.convex_hull(bm, input=bm.verts[:], use_existing_faces=False)
    interieur = [v for v in bm.verts if not v.link_faces]
    if interieur:
        bmesh.ops.delete(bm, geom=interieur, context='VERTS')
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    for f in bm.faces:
        p = [G(v.co) for v in f.verts]
        n = (p[1] - p[0]).cross(p[2] - p[0])
        if n.length_squared < 1e-12:
            continue
        n.normalize()
        if any(n.dot(c) > 0.95 for c in cacher):
            continue
        if any(n.dot(j) > 0.9 for j in joints):
            k = "joint"
        elif n.y > 0.95:
            k = "dessus"
        elif n.y < -0.5:
            k = "dessous"
        elif n.y > 0.25:
            k = "chanfrein_haut"
        else:
            hl = math.hypot(n.x, n.z)
            k = "face" if hl < 1e-6 or max(abs(n.x), abs(n.z)) / hl > 0.96 else "chanfrein"
        M.tris.append((mat, (p[0], p[1], p[2]), ton * fac[k]))
    bm.free()


def _pil_anneau(y, sx, sz, coins, c=Vector((0, 0, 0))):
    """Octogone à la hauteur y : rectangle sx x sz (centre c) aux coins abattus de coins[i] ; coins dans l'ordre (+x+z) (-x+z) (-x-z) (+x-z).
    Renvoie [(point, coin), ...]."""
    out = []
    for i, (ux, uz) in enumerate(((1, 1), (-1, 1), (-1, -1), (1, -1))):
        k = max(0.004, min(coins[i], 0.45 * min(sx, sz)))
        out.append((Vector((c.x + ux * sx * 0.5, y, c.z + uz * (sz * 0.5 - k))), i))
        out.append((Vector((c.x + ux * (sx * 0.5 - k), y, c.z + uz * sz * 0.5)), i))
    return out


def _pil_bloc(M, taille, pos, coins=None, ch=PIL_CH_HAUT, ch_bas=PIL_CH_BAS, haut=None, ton=None, eclat=None, joints=(),
              cacher=(BAS,), regles=None, usure=0.008, haut_dz=0.0):
    """Bloc taillé (assise de pilier, moulure) : taille (sx, sy, sz) centré en pos ; `haut` = (sx, sz) du dessus (talon, corbeille
    évasée) ; coins abattus `coins` (sinon tirés dans PIL_CHANF) ; eclat = (coin, profondeur) : coin arraché (haut du bloc)."""
    rg = M.rg
    sx, sy, sz = taille
    hx, hz = haut if haut else (sx, sz)
    if coins is None:
        coins = [rg.uniform(*PIL_CHANF) for _ in range(4)]
    if ton is None:
        ton = rg.uniform(*PIL_TON)
    y0, y1 = pos.y - sy * 0.5, pos.y + sy * 0.5
    c = Vector((pos.x, 0, pos.z))
    anneaux = []
    if ch_bas > 0.003:
        anneaux.append((_pil_anneau(y0, sx - 2 * ch_bas, sz - 2 * ch_bas, [k * 0.8 for k in coins], c), "bas"))
        anneaux.append((_pil_anneau(y0 + ch_bas, sx, sz, coins, c), "flanc"))
    else:
        anneaux.append((_pil_anneau(y0, sx, sz, coins, c), "flanc"))
    ch_ = c + Vector((0, 0, haut_dz))
    anneaux.append((_pil_anneau(y1 - ch, hx, hz, coins, ch_), "flanc_haut"))
    anneaux.append((_pil_anneau(y1, hx - 2 * ch, hz - 2 * ch, [k * 0.7 for k in coins], ch_), "dessus"))
    pts = []
    for an, role in anneaux:
        for p, i in an:
            q = p.copy()
            if role == "dessus" and usure > 0:        # arête haute usée : chanfrein irrégulier
                q += Vector((rg.uniform(-usure, usure), rg.uniform(-usure * 0.8, 0.0), rg.uniform(-usure, usure)))
            if eclat and i == eclat[0] and role in ("dessus", "flanc_haut"):
                d = eclat[1]
                vers = (c - Vector((q.x, 0, q.z)))
                vers.y = 0
                if vers.length > 1e-6:
                    vers.normalize()
                q += vers * d * (0.7 if role == "dessus" else 0.55) + Vector((0, -d * (1.0 if role == "dessus" else 0.35), 0))
            pts.append(q)
    _pil_emettre(M, pts, ton, joints, cacher, regles)


def _pil_noyau(M, sx, sy, sz, pos):
    """Noyau sombre derrière les joints (12 triangles, pas de biseau)."""
    M.boite((sx, sy, sz), pos, bev=0.0, jit=0.0, ton=PIL_NOYAU)


def _pil_eclats_pied(M, cx, cz, n):
    """Petits éclats tombés au pied d'un coin arraché (8-12 triangles chacun)."""
    rg = M.rg
    for _ in range(n):
        r = rg.uniform(0.035, 0.07)
        x, z = cx + rg.uniform(-0.15, 0.15), cz + rg.uniform(-0.15, 0.15)
        pts = [Vector((x + rg.uniform(-r, r), rg.uniform(0.0, 0.01), z + rg.uniform(-r, r))) for _ in range(3)]
        pts += [Vector((x + rg.uniform(-r, r) * 0.7, rg.uniform(r * 0.5, r * 1.1), z + rg.uniform(-r, r) * 0.7)) for _ in range(2)]
        _pil_emettre(M, pts, rg.uniform(0.7, 0.85), cacher=(BAS,))


def _pil_chapiteau(M, w, d, y, z=0.0, dos=False):
    """Bague + corbeille évasée + tailloir (chanfrein bas large) ; dessus du tailloir à y + 0,62. w x d = section du fût (centre z).
    dos : pilier engagé, le dos de chaque pièce reste à 2 cm derrière celui du fût (contre le mur) et n'est pas émis."""
    rg = M.rg
    cach = (BAS, DOS) if dos else (BAS,)
    arr = z - d * 0.5 - 0.02          # dos commun (pilier engagé)

    def zc(D):
        return arr + D * 0.5 if dos else z

    dz_b, dz_h = (d + 0.07, d + 0.03 + 0.2) if dos else (d + 0.07, d + 0.24)
    _pil_bloc(M, (w + 0.07, 0.09, dz_b), Vector((0, y + 0.045, zc(dz_b))), ch=0.025, ch_bas=0.01, cacher=cach)               # bague
    D0 = d + 0.03
    _pil_bloc(M, (w + 0.02, 0.24, D0), Vector((0, y + 0.21, zc(D0))), haut=(w + 0.24, dz_h), haut_dz=(zc(dz_h) - zc(D0)),
              ch=0.03, ch_bas=0.0, cacher=cach)                                                                                 # corbeille
    Dt = d + (0.24 if dos else 0.38)
    _pil_bloc(M, (w + 0.38, 0.29, Dt), Vector((0, y + 0.475, zc(Dt))), ch=0.03, ch_bas=0.08,
              coins=[rg.uniform(0.04, 0.07) for _ in range(4)], cacher=cach)                                                    # tailloir


def pilier_libre_v3(nom, h, graine, larg=1.0):
    """Pilier ISOLÉ v3 : plinthe + talon, fût en assises de deux blocs croisés (joints alternés, au noir), chapiteau bague / corbeille /
    tailloir, 1-2 coins arrachés et leurs éclats au pied. Centré sur l'origine, hauteur h, section larg (même encombrement que v2)."""
    M = Module(nom, graine)
    rg = M.rg
    w = larg
    J = PIL_JOINT
    _pil_noyau(M, w - 0.14, h - 0.6, w - 0.14, Vector((0, h * 0.5, 0)))
    _pil_bloc(M, (w + 0.36, 0.24, w + 0.36), Vector((0, 0.12, 0)), ch=0.07, ch_bas=0.0)                               # plinthe
    _pil_bloc(M, (w + 0.2, 0.17, w + 0.2), Vector((0, 0.24 + 0.085, 0)), haut=(w + 0.04, w + 0.04), ch=0.025, ch_bas=0.0)  # talon
    y = 0.41 + J
    fin = h - 0.62
    rang = 0
    blocs = []
    while y < fin - 0.05:
        hc = min(rg.uniform(0.34, 0.56), fin - y)
        if fin - y - hc < 0.18:
            hc = fin - y
        cut = rg.uniform(-0.12, 0.12) * w
        for s_ in (-1, 1):
            a0 = -w * 0.5 if s_ < 0 else cut + J * 0.5
            a1 = cut - J * 0.5 if s_ < 0 else w * 0.5
            lw = a1 - a0
            cc = (a0 + a1) * 0.5
            ep = w + rg.uniform(-0.025, 0.012)
            if rang % 2 == 0:       # joint perpendiculaire à x : coins extérieurs côté s_
                dims, pos = (lw, hc - J, ep), Vector((cc + rg.uniform(-0.006, 0.006), y + (hc - J) * 0.5, rg.uniform(-0.008, 0.008)))
                ext = (1, 2) if s_ < 0 else (0, 3)
                jn = (Vector((-s_, 0, 0)), HAUT)
            else:
                dims, pos = (ep, hc - J, lw), Vector((rg.uniform(-0.008, 0.008), y + (hc - J) * 0.5, cc + rg.uniform(-0.006, 0.006)))
                ext = (2, 3) if s_ < 0 else (0, 1)
                jn = (Vector((0, 0, -s_)), HAUT)
            coins = [rg.uniform(*PIL_CHANF) if i in ext else 0.012 for i in range(4)]
            blocs.append((dims, pos, coins, ext, jn))
        y += hc
        rang += 1
    # 1-2 coins arrachés, pas sur l'assise du bas (lisible à hauteur d'yeux) ; pas de bloc trop bas
    eclats = {}
    cand = [i for i, b in enumerate(blocs) if 0.6 < b[1].y < 2.4]
    for i in rg.sample(cand, min(len(cand), rg.choice((2, 3)))):
        eclats[i] = (rg.choice(blocs[i][3]), rg.uniform(0.08, 0.16))
    for i, (dims, pos, coins, ext, jn) in enumerate(blocs):
        e = eclats.get(i)
        _pil_bloc(M, dims, pos, coins=coins, eclat=e, joints=jn, regles={"dessus": PIL_FACE["joint"]})
        if e:
            k = e[0]
            ux, uz = ((1, 1), (-1, 1), (-1, -1), (1, -1))[k]
            _pil_eclats_pied(M, ux * (w * 0.5 + 0.36), uz * (w * 0.5 + 0.36), rg.choice((2, 3)))
    _pil_chapiteau(M, w, w, fin)
    return M


def pilier_rond_v3(nom, h, graine, larg=1.2):
    """Pilier ISOLÉ v3, variante RONDE des grandes salles (INSPIRATION_IGNITE §2.3) : fût en TAMBOURS octogonaux de hauteurs inégales
    (décalés de 1-2 cm, chanfreins haut / bas : joints en V au noir), une bague tous les 3-4 tambours, plinthe carrée + talon,
    chapiteau carré (le module s'appuie sur la même boîte de collision larg x h x larg, l'octogone y est inscrit), 2-3 tambours
    épaufrés et leurs éclats au pied."""
    M = Module(nom, graine)
    rg = M.rg
    w = larg * 0.92                  # diamètre du fût (octogone régulier : coin abattu = 0,293 w)
    J = PIL_JOINT
    _pil_noyau(M, w * 0.7, h - 0.6, w * 0.7, Vector((0, h * 0.5, 0)))
    _pil_bloc(M, (larg + 0.36, 0.26, larg + 0.36), Vector((0, 0.13, 0)), ch=0.08, ch_bas=0.0)                                  # plinthe
    _pil_bloc(M, (larg + 0.12, 0.18, larg + 0.12), Vector((0, 0.26 + 0.09, 0)), haut=(w + 0.08, w + 0.08), ch=0.03, ch_bas=0.0,
              coins=[0.06, 0.06, 0.06, 0.06])                                                                                  # talon
    y = 0.44 + J
    fin = h - 0.62
    tamb = []
    n_bague = rg.randint(3, 4)
    while y < fin - 0.05:
        hc = min(rg.uniform(0.42, 0.68), fin - y)
        if fin - y - hc < 0.2:
            hc = fin - y
        if len(tamb) % (n_bague + 1) == n_bague and fin - y > 0.6:           # bague
            tamb.append(("bague", (w + 0.1, 0.1, w + 0.1), Vector((0, y + 0.05, 0))))
            y += 0.1 + J
            continue
        r = w + rg.uniform(-0.03, 0.015)
        tamb.append(("tambour", (r, hc - J, r), Vector((rg.uniform(-0.012, 0.012), y + (hc - J) * 0.5, rg.uniform(-0.012, 0.012)))))
        y += hc
    cand = [i for i, t in enumerate(tamb) if t[0] == "tambour" and 0.6 < t[2].y < 3.0]
    epauf = {i: (rg.randrange(4), rg.uniform(0.1, 0.18)) for i in rg.sample(cand, min(len(cand), rg.choice((2, 3))))}
    for i, (sorte, dims, pos) in enumerate(tamb):
        k = 0.2929 * dims[0]
        if sorte == "bague":
            _pil_bloc(M, dims, pos, coins=[0.2929 * dims[0]] * 4, ch=0.025, ch_bas=0.02, regles={"dessus": PIL_FACE["joint"]})
            continue
        coins = [k + rg.uniform(-0.01, 0.01) for _ in range(4)]
        e = epauf.get(i)
        _pil_bloc(M, dims, pos, coins=coins, eclat=e, joints=(HAUT,), regles={"dessus": PIL_FACE["joint"]})
        if e:
            ux, uz = ((1, 1), (-1, 1), (-1, -1), (1, -1))[e[0]]
            _pil_eclats_pied(M, ux * (larg * 0.5 + 0.32), uz * (larg * 0.5 + 0.32), 3)
    _pil_chapiteau(M, w, w, fin)
    return M


def pilier_mur_v3(nom, h, graine, larg=0.62, prof=0.34):
    """Pilier ENGAGÉ v3 (demi-pilier contre le mur, +z vers la pièce) : plinthe + talon, fût en assises inégales (une sur deux coupée
    par un joint vertical décalé), chapiteau bague / corbeille / tailloir, un coin avant arraché. Saillie <= 0,35 m (hors moulures,
    comme v2) : aucune collision. Dos (contre le mur) et dessous non émis."""
    M = Module(nom, graine)
    rg = M.rg
    J = PIL_JOINT
    z0 = prof * 0.5 - 0.02
    cach = (BAS, DOS)
    _pil_noyau(M, larg - 0.12, h - 0.5, prof - 0.1, Vector((0, h * 0.5, z0 - 0.04)))
    _pil_bloc(M, (larg + 0.2, 0.2, prof + 0.12), Vector((0, 0.1, z0 + 0.04)), ch=0.06, ch_bas=0.0, cacher=cach)
    _pil_bloc(M, (larg + 0.12, 0.12, prof + 0.07), Vector((0, 0.26, z0 + 0.025)), haut=(larg + 0.01, prof + 0.01), ch=0.02, ch_bas=0.0, cacher=cach)
    y = 0.32 + J
    fin = h - 0.62
    blocs = []
    rang = 0
    while y < fin - 0.05:
        hc = min(rg.uniform(0.34, 0.56), fin - y)
        if fin - y - hc < 0.16:
            hc = fin - y
        ep = prof + rg.uniform(-0.025, 0.02)
        pz = z0 + rg.uniform(-0.006, 0.006)
        if rang % 2 == 1 and larg > 0.5:     # assise coupée : deux blocs, joint vertical décalé
            cut = rg.uniform(-0.15, 0.15) * larg
            for s_ in (-1, 1):
                a0 = -larg * 0.5 if s_ < 0 else cut + J * 0.5
                a1 = cut - J * 0.5 if s_ < 0 else larg * 0.5
                ext = (1,) if s_ < 0 else (0,)
                coins = [rg.uniform(*PIL_CHANF) if i in ext else 0.01 for i in range(4)]
                blocs.append(((a1 - a0, hc - J, ep), Vector(((a0 + a1) * 0.5, y + (hc - J) * 0.5, pz)), coins, ext, (Vector((-s_, 0, 0)), HAUT)))
        else:
            coins = [rg.uniform(*PIL_CHANF), rg.uniform(*PIL_CHANF), 0.01, 0.01]
            blocs.append(((larg + rg.uniform(-0.03, 0.02), hc - J, ep), Vector((rg.uniform(-0.012, 0.012), y + (hc - J) * 0.5, pz)), coins, (0, 1), (HAUT,)))
        y += hc
        rang += 1
    cand = [i for i, b in enumerate(blocs) if 0.5 < b[1].y < 2.4] or list(range(len(blocs)))
    ie = rg.sample(cand, min(len(cand), rg.choice((1, 2))))
    for i, (dims, pos, coins, ext, jn) in enumerate(blocs):
        e = (rg.choice(ext), rg.uniform(0.07, 0.13)) if i in ie else None
        _pil_bloc(M, dims, pos, coins=coins, eclat=e, joints=jn, cacher=cach, regles={"dessus": PIL_FACE["joint"]})
    _pil_chapiteau(M, larg, prof, fin, z=z0, dos=True)
    return M


def arche_v3(nom, portee, fleche, graine, epaisseur=0.34, prof=0.5, bloc=None):
    """Arc en claveaux v3 : même tracé et mêmes appuis que arche() (portée, flèche, naissance à y = 0, relief vers +z) ; claveaux à
    chanfrein avant large (usure : un par claveau), joints au noir, 1 claveau sur 8 descendu de 1-3 cm, quelques arêtes avant
    épaufrées, clé saillante (+5 cm). 20 triangles par claveau."""
    M = Module(nom, graine)
    rg = M.rg
    a = portee * 0.5
    f = fleche
    ep = epaisseur
    bloc = bloc or (0.36 + 0.012 * portee)
    regles = {"dessous": 0.85, "chanfrein_haut": 1.25}

    def vouss(cx, cy, R, t0, t1, miroir, cle):
        gap = 0.013 / R
        e_out = R + ep + rg.uniform(-0.02, 0.025) + (0.05 if cle else 0.0)
        cf = rg.uniform(0.045, 0.075)                       # chanfrein avant
        zb = -prof * 0.5 + rg.uniform(0, 0.02)
        zf = prof * 0.5 - rg.uniform(0, 0.02) + (0.05 if cle else 0.0)
        chute = rg.uniform(0.01, 0.03) if (not cle and rg.random() < 0.125) else 0.0
        epauf = (rg.randrange(4), rg.uniform(0.03, 0.06)) if rg.random() < 0.18 else None
        ton = rg.uniform(*PIL_TON)
        ta, tb = t0 + gap, t1 - gap
        pts = []
        for r_, t_ in ((R, ta), (R, tb), (e_out, tb), (e_out, ta)):
            pts.append((r_, t_, zb, 0))
            pts.append((r_, t_, zf - cf, 0))
        dt = cf / R
        for i, (r_, t_) in enumerate(((R + cf, ta + dt), (R + cf, tb - dt), (e_out - cf, tb - dt), (e_out - cf, ta + dt))):
            pts.append((r_, t_, zf, 1 + i))
        P = []
        for r_, t_, z, i in pts:
            x = cx + r_ * math.cos(t_)
            y = cy + r_ * math.sin(t_) - chute
            if epauf and i == 1 + epauf[0]:
                z -= epauf[1]
            P.append(Vector((-x if miroir else x, y, z)))
        # normales des faces de joint (sortantes) : -tangente en t0, +tangente en t1
        j0 = Vector((math.sin(ta), -math.cos(ta), 0))
        j1 = Vector((-math.sin(tb), math.cos(tb), 0))
        if miroir:
            j0.x, j1.x = -j0.x, -j1.x
        _pil_emettre(M, P, ton, joints=(j0, j1), regles=regles)

    if f >= a:
        xc = (f * f - a * a) / (2 * a)
        R = a + xc
        t_top = math.atan2(f, xc)
        n = max(3, int(round(R * t_top / bloc)))
        for s_ in (False, True):
            for k in range(n):
                vouss(-xc, 0.0, R, t_top * k / n, t_top * (k + 1) / n, s_, k == n - 1)
    else:
        yc = (f * f - a * a) / (2 * f)
        R = f - yc
        t_s = math.atan2(-yc, a)
        n = max(5, int(round(R * (math.pi - 2 * t_s) / bloc)))
        if n % 2 == 0:
            n += 1
        for k in range(n):
            vouss(0.0, yc, R, t_s + (math.pi - 2 * t_s) * k / n, t_s + (math.pi - 2 * t_s) * (k + 1) / n, False, k == n // 2)
    for sx in (-1, 1):                # sabots sous la naissance
        _pil_bloc(M, (0.34, 0.16, prof + 0.1), Vector((sx * (a + 0.02), -0.08, 0.02)), ch=0.035, ch_bas=0.03, cacher=())
    return M


# ======================================================================= PANS DE MUR v3 (lot C3, 2026-10-28)
# Chantier « anti pâte à modeler » (docs INSPIRATION_IGNITE §2.1, planche 01_murs_crypte). Constat : à distance de jeu (2-4 m) le
# pan_mur v2 se lisait comme une texture plane (tons 0,72-1,0 trop proches, joints gris à 0,32, aucune arête claire, couleur de sommet
# 8 bits déjà au plafond). Le relief passe donc par la GÉOMÉTRIE et l'orientation des faces, comme les piliers v3 (C4) :
#   - joints au NOIR : fond à 0,12 (rampe Ombre) et flancs de bloc (faces de joint) x 0,22 ;
#   - blocs contrastés : ton de base 0,52-0,86 (+ 1 bloc sur 7 plus sombre, 1 sur 10 plus clair), face x 0,96 ;
#   - ARÊTE CLAIRE : chanfrein haut de 4,5-6,5 cm (3-5 px à 3 m) x 1,42 ; PIED SOMBRE : chanfrein bas x 0,6 (= règle d'aretes.py, posée
#     face par face : aretes.appliquer ajouterait des liserés en double et assombrirait le cœur des faces) ;
#   - mur « essuyé » : tons x 0,82 au pied -> x 1 à 1,6 m ;
#   - assises : soubassement de 2 assises hautes à longs blocs, puis petites assises de 0,2-0,4 m (blocs de 0,3 à 0,95 m) ;
#   - accidents : 1 bloc sur 12 SORTI de 8-12 cm (plafonné à 0,315 m du mur : les objets accrochés sont posés à 0,33), 1 sur 12 TOURNÉ
#     de 2-4°, 1 sur 25 MANQUANT (trou noir, gravats au pied), 1 sur 3 avec un coin arraché (aucun triangle de plus) ;
#   - pan_mur_b : un corbeau (console à deux ressauts) ; pan_mur_c : une niche à arc brisé (jambages, tablette, écoinçons) ;
#     pan_mur_haut : deux corbeaux. Le gabarit étant posé à 1,8 / 2,6 / 3,4 m, cela fait un accident d'architecture tous les 4-6 m ;
#   - givre d'arête par TRONÇONS (30-70 % de l'arête haute d'un bloc sur 5, épaisseur variable, tons 0,45-0,66 : jamais le haut de la
#     rampe Glace) ; glaçons IRRÉGULIERS (0 à 4, longueurs tirées au carré, trous) sous les blocs sortis, les corbeaux et la tablette.
# Bloc = enveloppe convexe de 12 points (dos caché) : 18 triangles (44 pour le bloc biseauté v2) ; ~2 fois plus de blocs pour moins de
# triangles. Mêmes noms, mêmes encombrements (0 -> 0,32 m devant le mur), aucune collision.
ARETES_SANS = ARETES_SANS + ("pan_mur",)
MUR_TON = (0.52, 0.86)
MUR_FACE = {"face": 0.96, "chanfrein": 1.22, "chanfrein_haut": 1.42, "dessus": 1.0, "dessous": 0.6, "joint": 0.22}
MUR_FOND = 0.12
MUR_MAX = 0.315
X_P, X_M, Z_P = Vector((1, 0, 0)), Vector((-1, 0, 0)), Vector((0, 0, 1))


def _essuye(y):
    return 0.82 + 0.18 * min(1.0, max(0.0, y / 1.6))


def _mur_bloc(M, x0, x1, y0, y1, zf, ton, zb=0.03, ch_h=0.055, ch_b=0.025, ch_s=0.03, d=0.035, yaw=0.0, roll=0.0, eclat=None, jit=0.006):
    """Bloc de parement : face avant [x0, x1] x [y0, y1] à z = zf, chanfreins haut / bas / côtés (largeur ch_*, profondeur d), dos à zb
    (caché). eclat = (coin 0..3 : bas-g, bas-d, haut-d, haut-g ; taille) : coin avant arraché. 18 triangles."""
    rg = M.rg
    cx, cy = (x0 + x1) * 0.5, (y0 + y1) * 0.5
    pts = []
    for (x, y) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1)):
        pts.append(Vector((x, y, zb)))
        pts.append(Vector((x, y, zf - d)))
    face = [(x0 + ch_s, y0 + ch_b), (x1 - ch_s, y0 + ch_b), (x1 - ch_s, y1 - ch_h), (x0 + ch_s, y1 - ch_h)]
    for i, (x, y) in enumerate(face):
        q = Vector((x + rg.uniform(-jit, jit), y + rg.uniform(-jit, jit), zf + rg.uniform(-jit, jit * 0.5)))
        if eclat and i == eclat[0]:
            e = eclat[1]
            q += Vector(((cx - x) / max(1e-6, abs(cx - x)) * e * 0.8, (cy - y) / max(1e-6, abs(cy - y)) * e, -e * 0.7))
        pts.append(q)
    if yaw or roll:
        R = Matrix.Rotation(yaw, 3, 'Y') @ Matrix.Rotation(roll, 3, 'Z')
        c = Vector((cx, cy, zb))
        pts = [c + R @ (p - c) for p in pts]
        Rj = R
    else:
        Rj = Matrix.Identity(3)
    joints = tuple(Rj @ v for v in (X_P, X_M, HAUT, BAS))
    _pil_emettre(M, pts, ton, joints=joints, cacher=(Rj @ DOS,), regles=MUR_FACE)


def _mur_coin(M, pts, ton, joints=(), regles=None):
    """Pièce taillée quelconque (enveloppe convexe, dos caché) aux tons de face des murs."""
    r = dict(MUR_FACE)
    if regles:
        r.update(regles)
    _pil_emettre(M, pts, ton, joints=joints, cacher=(DOS,), regles=r)


def _givre_troncon(M, x0, x1, y, zf, ch_h=0.055, d=0.035):
    """Givre sur l'arête haute d'un bloc (dessus y, face avant zf, chanfrein haut ch_h x d), par TRONÇONS : 1 à 2 croûtes couvrant
    30-70 % de [x0, x1], couchées sur le chanfrein, épaisseur et avancée variables, tons 0,45-0,66 (jamais le haut de la rampe Glace)."""
    rg = M.rg
    L = x1 - x0
    if L < 0.1:
        return
    couvre = rg.uniform(0.3, 0.7) * L
    n = 1 if couvre < 0.3 or rg.random() < 0.5 else 2
    a = x0 + rg.uniform(0.0, L - couvre)
    for k in range(n):
        l = couvre / n * rg.uniform(0.7, 1.0)
        ep = rg.uniform(0.008, 0.02)
        pts = []
        m = rg.randint(3, 5)
        for i in range(m):
            t = i / (m - 1)
            x = a + l * t
            f = (0.3 + 0.7 * math.sin(math.pi * (0.15 + 0.7 * t))) * rg.uniform(0.6, 1.0)      # avancée sur le chanfrein
            e = ep * (0.4 + 0.6 * math.sin(math.pi * (0.1 + 0.8 * t)))
            pts += [Vector((x, y - 0.003, zf - d - 0.014)), Vector((x, y + e, zf - d - 0.004)),
                    Vector((x, y - ch_h * f + e * 0.5, zf - d + d * f + 0.004)), Vector((x, y - ch_h * f - 0.004, zf - d + d * f + 0.001))]
        M.coin(pts, "givre", bev=0.0, jit=0.0, ton=rg.uniform(0.45, 0.66))
        a += couvre / n + rg.uniform(0.04, 0.2)


def _glacons_irreg(M, x0, x1, y, z, nmax=4, lmax=0.24):
    """Glaçons irréguliers sous une arête : 0 à nmax, longueurs tirées au carré (un long, des courts), positions avec trous."""
    rg = M.rg
    n = rg.randint(0, nmax)
    xs = sorted(rg.uniform(x0, x1) for _ in range(n))
    for x in xs:
        h = 0.03 + lmax * rg.random() ** 2
        M.cylindre(0.0, rg.uniform(0.01, 0.022) + h * 0.05, h, Vector((x, y - h, z + rg.uniform(-0.012, 0.0))), 4, "givre", jit=0.003,
                   ton=rg.uniform(0.5, 0.7), rot=rg.uniform(0, 1.5))


def _gravats_pied(M, cx, n):
    """Éclats tombés au pied du mur (bloc manquant) : petits blocs inclinés, 12 triangles chacun."""
    rg = M.rg
    for _ in range(n):
        s = rg.uniform(0.05, 0.12)
        x = cx + rg.uniform(-0.35, 0.35)
        z = rg.uniform(0.12, 0.38)
        M.boite((s * rg.uniform(1.0, 1.8), s * rg.uniform(0.5, 0.9), s), Vector((x, s * 0.3, z)), yaw=rg.uniform(0, 6.2),
                incl=(rg.uniform(-0.4, 0.4), rg.uniform(-0.3, 0.3)), bev=0.0, jit=0.012, ton=rg.uniform(0.45, 0.75))


def _corbeau(M, cx, y_haut, larg=0.3):
    """Console à deux ressauts sous une tablette (corbeau) : dessous en biais (quart de rond taillé), tablette à arête claire,
    givre dessus, glaçons dessous. Saillie 0,46 m devant le mur, 0,5 m de haut."""
    rg = M.rg
    w = larg
    zt = 0.46
    # tablette
    _mur_bloc(M, cx - w * 0.75, cx + w * 0.75, y_haut - 0.11, y_haut, zt, rg.uniform(0.72, 0.86), zb=0.05, ch_h=0.04, ch_b=0.02, ch_s=0.025)
    # corbeau : profil en biais (haut à 0,42, bas à 0,2), deux ressauts
    for k, (ya, yb, za, zb_) in enumerate(((y_haut - 0.27, y_haut - 0.12, 0.42, 0.34), (y_haut - 0.5, y_haut - 0.28, 0.32, 0.2))):
        hw = w * (0.5 - 0.06 * k)
        pts = []
        for sx in (-1, 1):
            x = cx + sx * hw
            xi = cx + sx * (hw - 0.025)
            pts += [Vector((x, ya, 0.05)), Vector((x, yb, 0.05)), Vector((x, yb, za - 0.03)), Vector((x, ya, zb_ - 0.03)),
                    Vector((xi, yb - 0.035, za)), Vector((xi, ya + 0.02, zb_))]
        _mur_coin(M, pts, rg.uniform(0.62, 0.8), joints=(HAUT,))
    _givre_troncon(M, cx - w * 0.7, cx + w * 0.7, y_haut, zt, 0.04)
    _glacons_irreg(M, cx - w * 0.4, cx + w * 0.4, y_haut - 0.5, 0.2, 3, 0.2)


def _niche(M, cx, y0, w=0.62, h=0.82, fleche=0.26):
    """Niche à arc brisé : fond noir (le fond du pan), jambages en saillie, tablette, deux claveaux en mitre et écoinçons. Renvoie la
    zone exclue des assises (x0, x1, y0, y1)."""
    rg = M.rg
    jb = 0.15
    zj = 0.27
    x0, x1 = cx - w * 0.5, cx + w * 0.5
    y1 = y0 + h
    # tablette (seuil) : arête claire, givre, glaçons
    _mur_bloc(M, x0 - jb - 0.05, x1 + jb + 0.05, y0 - 0.1, y0, 0.32, rg.uniform(0.74, 0.86), ch_h=0.04, ch_b=0.02)
    _givre_troncon(M, x0, x1, y0, 0.32, 0.04)
    _glacons_irreg(M, x0 - 0.1, x1 + 0.1, y0 - 0.1, 0.3, 4, 0.22)
    # jambages : deux pierres chacun
    for sx, xa, xb in ((-1, x0 - jb, x0), (1, x1, x1 + jb)):
        ym = y0 + h * rg.uniform(0.42, 0.58)
        _mur_bloc(M, xa, xb, y0, ym - 0.015, zj, rg.uniform(0.66, 0.84), ch_s=0.025)
        _mur_bloc(M, xa, xb, ym + 0.015, y1, zj, rg.uniform(0.66, 0.84), ch_s=0.025)
    # fond de la niche : plus noir que les joints, un peu en retrait de la face des jambages (profondeur 0,22 m)
    M.boite((w + 0.02, h + fleche, 0.01), Vector((cx, y0 + (h + fleche) * 0.5, 0.045)), bev=0.0, jit=0.0, ton=0.06)
    # claveaux en mitre (arc brisé), clé au sommet
    yt = y1 + fleche
    e = 0.15
    for sx in (-1, 1):
        xe = cx + sx * (w * 0.5 + jb)
        xi = cx + sx * w * 0.5
        pts = []
        for z in (0.04, zj - 0.03):
            pts += [Vector((xi, y1, z)), Vector((xe, y1, z)), Vector((cx + sx * 0.06, yt + e, z)), Vector((cx + sx * 0.02, yt, z))]
        pts += [Vector((xi - sx * 0.02, y1 + 0.03, zj)), Vector((xe - sx * 0.025, y1 + 0.02, zj)), Vector((cx + sx * 0.055, yt + e - 0.035, zj)),
                Vector((cx + sx * 0.025, yt + 0.03, zj))]
        _mur_coin(M, pts, rg.uniform(0.7, 0.86), joints=(BAS,), regles={"dessous": 0.32})
    # clé
    _mur_coin(M, [Vector((cx + sx * 0.06, y, z)) for sx in (-1, 1) for y in (yt - 0.01, yt + e + 0.06) for z in (0.04, zj + 0.02)] +
              [Vector((cx + sx * 0.04, yt + e + 0.04, zj + 0.035)) for sx in (-1, 1)], 0.84)
    # écoinçons (au-dessus des claveaux, jusqu'au haut de la zone)
    yz = yt + e + 0.06
    for sx in (-1, 1):
        xe = cx + sx * (w * 0.5 + jb)
        pts = []
        for z in (0.03, 0.2):
            pts += [Vector((xe, y1 + 0.02, z)), Vector((xe, yz, z)), Vector((cx + sx * 0.075, yz, z))]
        _mur_coin(M, pts, rg.uniform(0.55, 0.72), joints=(HAUT,))
    return (x0 - jb - 0.03, x1 + jb + 0.03, y0 - 0.11, yz + 0.015)


def pan_mur_v3(nom, larg, haut, graine, corbeaux=0, niche=False):
    """Pan de maçonnerie v3 (voir l'en-tête de section) : +z vers la pièce, x dans [-larg/2, larg/2], y dans [0, haut]."""
    M = Module(nom, graine)
    rg = M.rg
    L2 = larg * 0.5
    M.boite((larg, haut, 0.04), Vector((0, haut * 0.5, 0.02)), bev=0.0, jit=0.0, ton=MUR_FOND)      # fond (joints au noir)
    zones = []
    if niche:
        zones.append(_niche(M, rg.uniform(-0.25, 0.25) * larg * 0.3, 0.98))
    for k in range(corbeaux):
        cxk = (-L2 + larg * (k + 0.5) / corbeaux) + rg.uniform(-0.2, 0.2)
        _corbeau(M, cxk, min(haut - 0.45, 2.45 + rg.uniform(-0.1, 0.1)), rg.uniform(0.26, 0.34))
    J = 0.032
    y = 0.0
    rang = 0
    trous = []
    while y < haut - 0.05:
        hc = rg.choice([0.42, 0.48, 0.54]) if rang < 2 else rg.choice([0.2, 0.24, 0.28, 0.3, 0.34, 0.4])
        hc = min(hc, haut - y)
        if haut - y - hc < 0.17:
            hc = haut - y
        ya, yb = y + J * 0.5, y + hc - J * 0.5
        # intervalles libres de l'assise (hors niche)
        libres = [(-L2, L2)]
        for (zx0, zx1, zy0, zy1) in zones:
            if yb > zy0 and ya < zy1:
                n_l = []
                for (a, b) in libres:
                    if zx0 > a:
                        n_l.append((a, min(b, zx0)))
                    if zx1 < b:
                        n_l.append((max(a, zx1), b))
                libres = [(a, b) for (a, b) in n_l if b - a > 0.06]
        for (a, b) in libres:
            x = a
            if rang % 2 and a == -L2:
                x = a - rg.uniform(0.1, 0.3)
            while x < b - 0.04:
                w = rg.choice([0.3, 0.38, 0.46, 0.55, 0.66, 0.8, 0.95] if rang >= 2 else [0.7, 0.9, 1.1, 1.3])
                if x + w > b - 0.18:
                    w = b - x
                xa, xb = max(a, x) + J * 0.5, min(b, x + w) - J * 0.5
                x += w
                if xb - xa < 0.06:
                    continue
                r = rg.random()
                if r < 0.04 and 0 < rang and yb < haut - 0.3 and xb - xa < 0.8:
                    trous.append(((xa + xb) * 0.5, ya))
                    continue
                ton = rg.uniform(*MUR_TON) * _essuye((ya + yb) * 0.5)
                tr = rg.random()
                if tr < 0.14:
                    ton *= 0.8
                elif tr > 0.9:
                    ton = min(1.0, ton * 1.15)
                zf = 0.04 + rg.uniform(0.16, 0.21)
                yaw = roll = 0.0
                sorti = False
                if r < 0.04 + 1.0 / 12:
                    zf = min(MUR_MAX, zf + rg.uniform(0.08, 0.12))
                    sorti = True
                elif r < 0.04 + 2.0 / 12:
                    yaw = rg.choice((-1, 1)) * math.radians(rg.uniform(2, 4))
                    roll = rg.choice((-1, 1)) * math.radians(rg.uniform(0.5, 1.5))
                    zf = min(MUR_MAX - 0.02, zf + 0.025)
                eclat = (rg.randrange(4), rg.uniform(0.03, 0.07)) if rg.random() < 0.33 else None
                chh = rg.uniform(0.045, 0.065)
                _mur_bloc(M, xa, xb, ya, yb, zf, ton, ch_h=chh, ch_b=rg.uniform(0.018, 0.03),
                          ch_s=rg.uniform(0.022, 0.038), yaw=yaw, roll=roll, eclat=eclat)
                if yb < 1.6 and not yaw and rg.random() < 0.2:
                    _givre_troncon(M, xa + 0.04, xb - 0.04, yb, zf, chh)
                if sorti and ya > 1.2 and rg.random() < 0.5:
                    _glacons_irreg(M, xa + 0.05, xb - 0.05, ya, zf - 0.02, 3, 0.16)
        y += hc
        rang += 1
    for (tx, ty) in trous:
        _gravats_pied(M, tx, rg.randint(3, 5))
    return M


# ======================================================================= table des modules exportés
def construire():
    mods = []
    # C4 v3 (2026-10-28) : piliers et arches taillés (section PILIERS ET ARCHES v3 plus haut) ; mêmes noms, mêmes encombrements
    mods.append(pilier_mur_v3("pilier_mur_1p6", 1.62, 101, 0.58, 0.32))
    mods.append(pilier_mur_v3("pilier_mur_3p2", 3.2, 102, 0.66, 0.34))
    mods.append(pilier_mur_v3("pilier_mur_6", 6.0, 103, 0.72, 0.34))
    mods.append(colonne_mur("colonne_mur_3p2", 3.2, 111))
    mods.append(colonne_mur("colonne_mur_6", 6.0, 112, 0.3))
    mods.append(arche_v3("arche_2p0", 2.0, 1.0, 121, 0.3, 0.5))
    mods.append(arche_v3("arche_4p0", 4.0, 2.2, 122, 0.36, 0.5))
    mods.append(arche_v3("arche_10p7", 10.7, 2.3, 123, 0.44, 0.5, bloc=0.52))
    # C3 v3 (2026-10-28) : pans de mur taillés (section PANS DE MUR v3) ; b = un corbeau, c = une niche, haut = deux corbeaux
    for i, (w, h) in enumerate([(1.8, 3.0), (2.6, 3.0), (3.4, 3.0)]):
        mods.append(pan_mur_v3("pan_mur_%s" % "abc"[i], w, h, 131 + i, corbeaux=1 if i == 1 else 0, niche=i == 2))
    mods.append(pan_mur_v3("pan_mur_haut", 2.6, 4.4, 141, corbeaux=2))
    for i in range(3):
        mods.append(eboulis("eboulis_%s" % "abc"[i], [0.8, 1.05, 0.6][i], [0.5, 0.7, 0.35][i], 151 + i, [11, 15, 8][i]))
    for i in range(3):
        mods.append(dalles_brisees("dalles_%s" % "abc"[i], 161 + i, 2 + i % 2))
    mods.append(sarcophage("sarcophage", 171))
    mods.append(statue_capuche("statue_capuche", 181))
    mods.append(candelabre("candelabre", 191, 3))
    mods.append(lustre("lustre_fer", 201))
    mods.append(marches("marches_3p0", 3.0, 4, 211))
    # C4 (2026-10-23) : généralisation à toutes les salles — piliers isolés, vasque, autel, estrades
    mods.append(pilier_libre_v3("pilier_libre_5", 5.0, 221, 1.0))
    mods.append(pilier_rond_v3("pilier_libre_8", 8.0, 222, 1.2))      # C4 v3 : variante ronde (tambours) des grandes salles
    mods.append(plateforme_octo("vasque_rituel", 231, [(2.2, 0.0, 0.4), (1.7, 0.4, 0.9)], bassin=(1.4, 0.1, 0.72)))
    mods.append(plateforme_octo("autel_octo", 232, [(2.6, 0.0, 0.25), (2.0, 0.25, 0.5)]))
    mods.append(estrade("estrade_3x4", 241, 3.2, 0.9, 4.0))
    mods.append(degres("degres_arene", 242, [(11.0, 0.2, 9.0), (8.0, 0.2, 7.0), (5.4, 0.2, 5.6)]))
    # C4b (2026-10-23) : sarcophage de Svanhild, socle des primitives v1
    mods.append(sarcophage_svanhild("sarcophage_svanhild", 172))
    mods.append(socle_v2("socle_v2", 251))
    # D/crypte_restes (2026-10-26) : statues à orienter de la galerie, braseros de la citerne (mécanismes restés en v1)
    mods.append(socle_pivot("socle_pivot", 261))
    mods.append(statue_guide("statue_guide", 262))
    mods.append(brasero_v2("brasero_v2", 271))
    # L4 objets (2026-10-26) : trône du Jarl et son estrade, statues guerrier et jarl, autels, table d'embaumement, sarcophage pillé, bassin
    mods.append(trone_jarl("trone_jarl", 281))
    mods.append(estrade_trone("estrade_trone", 282))
    mods.append(statue_guerrier("statue_guerrier", 283))
    mods.append(statue_jarl("statue_jarl", 284))
    mods.append(autel_chapelle("autel_2p4", 285, 2.4))
    mods.append(autel_chapelle("autel_5p2", 286, 5.2))
    mods.append(table_embaumement_v2("table_embaumement", 287))
    mods.append(sarcophage_pille("sarcophage_pille", 288))
    mods.append(bassin_margelle("bassin_margelle", 289))
    # C2 (2026-10-28) : dallage v3 du sol des salles et couloirs (voir la section DALLAGE v3 plus haut)
    mods += construire_dallage()
    return mods


def exporter(mods):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    donnees = {}
    objets = []
    nb_tris = {}
    st_ar = {}
    for M in mods:
        res = M.finir()
        if not M.nom.startswith(ARETES_SANS):
            res = aretes.appliquer(res, bandes="aucune", stats=st_ar)      # blocs chanfreinés : aucun triangle de plus (perf)
        nb_tris[M.nom] = len(M.tris)
        for mat, faces in res.items():
            nom = "%s__%s" % (M.nom, mat)
            donnees[nom] = faces
            # objet Blender (pour le .glb et le .blend)
            me = bpy.data.meshes.new(nom)
            vs, fs, cols = [], [], []
            for p, c in faces:
                i0 = len(vs)
                for q, cc in zip(p, c):
                    vs.append(tuple(B(q)))
                    cols.append(cc)
                fs.append((i0, i0 + 1, i0 + 2))
            me.from_pydata(vs, [], fs)
            me.update()
            ca = me.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
            for poly in me.polygons:
                for li in poly.loop_indices:
                    ca.data[li].color = cols[me.loops[li].vertex_index]
            me.color_attributes.active_color = ca
            for pl in me.polygons:
                pl.use_smooth = False
            ob = bpy.data.objects.new(nom, me)
            bpy.context.scene.collection.objects.link(ob)
            objets.append(ob)
        if M.pts:
            donnees["%s__pts" % M.nom] = [((p, p, p), [(1, 1, 1, 1)] * 3) for p in M.pts]
    # disposition en grille pour l'inspection dans Blender (les coordonnées du .dat restent celles des modules)
    with open(DAT, "wb") as f:      # [u32 nb objets] puis par objet : [u8 long][nom][u32 nb sommets][sommets : x y z r g b a float32 ; 3 par triangle]
        f.write(struct.pack("<I", len(donnees)))
        for nom, faces in donnees.items():
            nb = nom.encode()
            f.write(struct.pack("<B", len(nb)) + nb + struct.pack("<I", len(faces) * 3))
            for p, c in faces:
                for q, cc in zip(p, c):
                    f.write(struct.pack("<7f", q.x, q.y, q.z, cc[0], cc[1], cc[2], cc[3]))
    x = 0.0
    for ob in objets:
        pass
    bpy.ops.export_scene.gltf(filepath=GLB, export_format='GLB', export_apply=True, export_normals=True, export_vertex_color='ACTIVE',
                              export_active_vertex_color_when_no_material=True, export_materials='NONE', export_yup=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    total = sum(nb_tris.values())
    print("crypte v2 : %d modules, %d triangles ->" % (len(mods), total), DAT)
    print("aretes : %d -> %d triangles apres liseres" % (st_ar.get("avant", 0), st_ar.get("apres", 0)))
    for k, v in nb_tris.items():
        print("  %-18s %5d tris" % (k, v))


exporter(construire())
