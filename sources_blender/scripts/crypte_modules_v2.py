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

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
DOSSIER = os.path.join(BASE, "assets", "crypte", "modules")
os.makedirs(DOSSIER, exist_ok=True)
DAT = os.path.join(DOSSIER, "crypte_v2.dat")
GLB = os.path.join(DOSSIER, "crypte_v2.glb")
BLEND = os.path.join(BASE, "sources_blender", "crypte_modules_v2.blend")

TEINTE = {"pierre": (1.0, 0.98, 0.95), "fer": (0.85, 0.88, 0.95), "cire": (1.0, 0.96, 0.85), "bois": (1.0, 0.95, 0.9),
          "givre": (0.92, 0.97, 1.0), "gravure": (1.0, 0.98, 0.95)}      # C4b : givre en plaques (matière « neige »), inscriptions (« gravure »)


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


# ======================================================================= table des modules exportés
def construire():
    mods = []
    mods.append(pilier_mur("pilier_mur_1p6", 1.62, 101, 0.58, 0.32))
    mods.append(pilier_mur("pilier_mur_3p2", 3.2, 102, 0.66, 0.34))
    mods.append(pilier_mur("pilier_mur_6", 6.0, 103, 0.72, 0.34))
    mods.append(colonne_mur("colonne_mur_3p2", 3.2, 111))
    mods.append(colonne_mur("colonne_mur_6", 6.0, 112, 0.3))
    mods.append(arche("arche_2p0", 2.0, 1.0, 121, 0.3, 0.5))
    mods.append(arche("arche_4p0", 4.0, 2.2, 122, 0.36, 0.5))
    mods.append(arche("arche_10p7", 10.7, 2.3, 123, 0.44, 0.5, bloc=0.52))
    for i, (w, h) in enumerate([(1.8, 3.0), (2.6, 3.0), (3.4, 3.0)]):
        mods.append(pan_mur("pan_mur_%s" % "abc"[i], w, h, 131 + i))
    mods.append(pan_mur("pan_mur_haut", 2.6, 4.4, 141))
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
    mods.append(pilier_libre("pilier_libre_5", 5.0, 221, 1.0))
    mods.append(pilier_libre("pilier_libre_8", 8.0, 222, 1.2))
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
    return mods


def exporter(mods):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    donnees = {}
    objets = []
    nb_tris = {}
    for M in mods:
        res = M.finir()
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
    for k, v in nb_tris.items():
        print("  %-18s %5d tris" % (k, v))


exporter(construire())
