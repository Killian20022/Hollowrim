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

TEINTE = {"pierre": (1.0, 0.98, 0.95), "fer": (0.85, 0.88, 0.95), "cire": (1.0, 0.96, 0.85), "bois": (1.0, 0.95, 0.9)}


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


def sarcophage(nom, graine):
    """Sarcophage de pierre (long axe x, face avant +z) : socle à ressauts, cuve à panneaux, couvercle à croix en relief, légèrement décalé."""
    M = Module(nom, graine)
    rg = M.rg
    M.boite((2.34, 0.14, 1.06), Vector((0, 0.07, 0)), bev=0.03, jit=0.01)
    M.boite((2.18, 0.6, 0.92), Vector((0, 0.44, 0)), bev=0.035, jit=0.01)
    for k in range(3):                          # panneaux en relief sur la face avant
        x = (k - 1) * 0.66
        M.boite((0.5, 0.36, 0.04), Vector((x, 0.45, 0.47)), bev=0.012, jit=0.003, ton=0.95)
        M.boite((0.32, 0.2, 0.05), Vector((x, 0.47, 0.49)), bev=0.01, jit=0.002, ton=0.78)
    M.boite((2.26, 0.2, 1.0), Vector((0.07, 0.84, 0.03)), yaw=0.025, bev=0.04, jit=0.012, ton=0.92)
    M.boite((2.0, 0.1, 0.62), Vector((0.07, 1.0, 0.03)), yaw=0.025, bev=0.03, jit=0.008, ton=0.95)
    M.boite((1.3, 0.05, 0.1), Vector((0.07, 1.075, 0.03)), yaw=0.025, bev=0.012, jit=0.002, ton=1.0)      # croix : montant
    M.boite((0.1, 0.05, 0.44), Vector((-0.2, 1.075, 0.03)), yaw=0.025, bev=0.012, jit=0.002, ton=1.0)     # croix : traverse
    # éclat au coin et fragment tombé
    M.boite((0.2, 0.12, 0.16), Vector((-1.05, 0.06, 0.62)), yaw=0.6, incl=(0.2, 0.15), bev=0.02, jit=0.02, ton=0.8)
    M.boite((0.12, 0.08, 0.1), Vector((0.95, 0.04, 0.7)), yaw=1.9, incl=(0.1, 0.3), bev=0.015, jit=0.015, ton=0.85)
    return M


def statue_capuche(nom, graine):
    """Gardien encapuchonné en prière : socle, robe à plis, bras croisés, capuche, visage dans l'ombre, mains jointes. Hauteur 2,45 m, face avant +z."""
    M = Module(nom, graine)
    rg = M.rg
    M.boite((0.86, 0.14, 0.86), Vector((0, 0.07, 0)), bev=0.03, jit=0.01)
    M.boite((0.72, 0.4, 0.72), Vector((0, 0.34, 0)), bev=0.03, jit=0.01)
    M.boite((0.8, 0.1, 0.8), Vector((0, 0.59, 0)), bev=0.025, jit=0.008)
    # robe : anneaux de plis (révolution à rayon modulé)
    base = 0.64
    prof = [(0.0, 0.34), (0.35, 0.3), (0.8, 0.255), (1.15, 0.235), (1.32, 0.3), (1.42, 0.22)]
    n = 14
    anneaux = []
    for (yy, r) in prof:
        ring = []
        for k in range(n):
            a = math.tau * k / n
            pli = 1.0 + 0.09 * math.sin(a * 5 + yy * 2.0) + 0.05 * math.sin(a * 9 - yy)
            ring.append(Vector((math.cos(a) * r * pli, base + yy, math.sin(a) * r * pli * 0.9)))
        anneaux.append(ring)
    bm = bmesh.new()
    vv = [[bm.verts.new(B(p)) for p in ring] for ring in anneaux]
    for i in range(len(vv) - 1):
        for k in range(n):
            bm.faces.new((vv[i][k], vv[i][(k + 1) % n], vv[i + 1][(k + 1) % n], vv[i + 1][k]))
    bm.faces.new(vv[-1][::-1])
    M._emettre(bm, "pierre", 0.9)
    # épaules et manteau (bloc incliné), bras croisés devant
    M.boite((0.7, 0.2, 0.42), Vector((0, base + 1.32, 0)), bev=0.07, jit=0.014, ton=0.95)
    M.boite((0.22, 0.52, 0.2), Vector((-0.2, base + 0.98, 0.17)), incl=(-0.55, 0.0), yaw=0.3, bev=0.04, jit=0.01, ton=1.0)
    M.boite((0.22, 0.52, 0.2), Vector((0.2, base + 0.98, 0.17)), incl=(-0.55, 0.0), yaw=-0.3, bev=0.04, jit=0.01, ton=1.0)
    M.boite((0.22, 0.14, 0.16), Vector((0, base + 0.82, 0.31)), bev=0.04, jit=0.01, ton=1.0)      # mains jointes
    # capuche : volume + bec en avant, ouverture sombre
    M.sphere(0.2, Vector((0, base + 1.62, -0.01)), ech=(1.0, 1.25, 1.1), seg=10, ton=0.95, jit=0.01)
    M.boite((0.28, 0.12, 0.3), Vector((0, base + 1.84, -0.02)), incl=(0.45, 0.0), bev=0.04, jit=0.01, ton=0.95)       # pointe
    M.boite((0.16, 0.24, 0.06), Vector((0, base + 1.6, 0.16)), bev=0.03, jit=0.003, ton=0.07)                             # visage dans l'ombre
    M.boite((0.34, 0.1, 0.08), Vector((0, base + 1.5, 0.15)), bev=0.03, jit=0.006, ton=1.0)                                # bord du col
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


def piece_fer_chaine(nom, graine):
    M = Module(nom, graine)
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
