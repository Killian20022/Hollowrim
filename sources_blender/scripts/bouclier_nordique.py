# Bouclier rond nordique tenu par le joueur (main gauche) : planches peintes, cerclage de fer, umbo de fer, poignée
# centrale (prise viking : le poing dans le creux de l'umbo).
#   blender.exe -b --python bouclier_nordique.py
# Exporte assets/modeles/armes/bouclier_nordique.glb.
#
# REPÈRE (convention DonneesArme / mains._calculer_prise) :
#   glTF : origine = centre du poing sur la poignée ; +Y le long de la poignée (de l'auriculaire vers l'index) ;
#          +X = vers les jointures = la FACE du bouclier (le côté peint, l'umbo) ; Z = X × Y (dans le plan du bouclier).
#   Blender : Z = poignée, X = face, Y = -Z glTF (export Y-up).
# NŒUDS VIDES : `prise` (centre du poing), `umbo` (sommet de l'umbo), `bord_haut` (bord dans l'axe de la poignée).
# MATÉRIAUX (habillés en PS1 dans Godot par scripts/objets/bouclier_nordique.gd) :
#   bouclier_face (planches peintes usées, UV plane du disque), bouclier_dos (planches brutes), fer (cerclage, umbo),
#   cuir (poignée).
# UV face et dos : projection plane du disque, u = 0,5 + y/(2R), v = 0,5 + z/(2R) (Blender), soit la texture 128 x 128
# entière sur le disque (~190 texels/m, comme les lames vues à 0,5 m).
import bpy, bmesh, math, os

ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(DEPOT, "assets", "modeles", "armes")

R = 0.34           # rayon (68 cm : un peu sous un bouclier viking réel, pour laisser la vue au repos)
COTES = 20         # silhouette : 20 pans (PS1)
X_FACE = 0.034     # plan de la face peinte (le poing est dans le creux de l'umbo)
X_DOS = 0.020      # plan du dos des planches
R_UMBO = 0.078
H_UMBO = 0.072
CERCLE = 0.022     # largeur du cerclage sur chaque face


def vider():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)


class Maille:
    def __init__(self, nom):
        self.nom = nom
        self.v = []
        self.f = []

    def s(self, p):
        self.v.append(tuple(p))
        return len(self.v) - 1

    def face(self, idx, mat, uvs, dehors=None):
        """dehors : vecteur vers lequel la normale doit pointer (sinon l'ordre donné est gardé)."""
        if dehors is not None:
            p = [self.v[i] for i in idx]
            a = [p[1][k] - p[0][k] for k in range(3)]
            b = [p[2][k] - p[0][k] for k in range(3)]
            n = (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
            if sum(n[k] * dehors[k] for k in range(3)) < 0.0:
                idx = list(reversed(idx))
                uvs = list(reversed(uvs))
        self.f.append((list(idx), mat, list(uvs)))

    def creer(self):
        me = bpy.data.meshes.new(self.nom)
        bm = bmesh.new()
        bv = [bm.verts.new(p) for p in self.v]
        uvl = bm.loops.layers.uv.new("UVMap")
        noms = []
        for _, mat, _ in self.f:
            if mat not in noms:
                noms.append(mat)
        for idx, mat, uvs in self.f:
            try:
                bf = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            bf.material_index = noms.index(mat)
            bf.smooth = False
            for lo, uv in zip(bf.loops, uvs):
                lo[uvl].uv = uv
        bm.to_mesh(me)
        bm.free()
        for n in noms:
            me.materials.append(bpy.data.materials.get(n) or bpy.data.materials.new(n))
        o = bpy.data.objects.new(self.nom, me)
        bpy.context.scene.collection.objects.link(o)
        return o


def anneau(r, x, n=COTES, phase=0.0):
    return [(x, r * math.cos(phase + 2 * math.pi * i / n), r * math.sin(phase + 2 * math.pi * i / n)) for i in range(n)]


def uv_plan(p):
    return (0.5 + p[1] / (2 * R), 0.5 + p[2] / (2 * R))


def relier(m, a, b, mat, uv, dehors):
    """Quads entre deux anneaux (même nombre de sommets). dehors(centre du quad) -> direction voulue de la normale."""
    ia = [m.s(p) for p in a]
    ib = [m.s(p) for p in b]
    n = len(a)
    for i in range(n):
        j = (i + 1) % n
        q = [ia[i], ia[j], ib[j], ib[i]]
        pts = [a[i], a[j], b[j], b[i]]
        c = [sum(p[k] for p in pts) / 4.0 for k in range(3)]
        m.face(q, mat, [uv(p, k) for k, p in enumerate(pts)], dehors(c))


def construire():
    vider()
    for n in ("bouclier_face", "bouclier_dos", "fer", "cuir"):
        bpy.data.materials.new(n)
    M = Maille("bouclier")
    plan = lambda p, k: uv_plan(p)
    # --- face peinte : de l'umbo au cerclage, trois anneaux (légèrement bombée : le centre ressort de 6 mm)
    r_int = R - CERCLE
    f0 = anneau(R_UMBO, X_FACE + 0.006)
    f1 = anneau(0.18, X_FACE + 0.004)
    f2 = anneau(r_int, X_FACE)
    # orientation : un quad (a[i], a[j], b[j], b[i]) de l'intérieur vers l'extérieur, sens trigo vu de +X -> normale +X
    relier(M, f0, f1, "bouclier_face", plan, lambda c: (1, 0, 0))
    relier(M, f1, f2, "bouclier_face", plan, lambda c: (1, 0, 0))
    # --- dos : planches brutes (et le creux de l'umbo, fermé par le dos des planches)
    d0 = anneau(R_UMBO, X_DOS)
    d1 = anneau(r_int, X_DOS)
    relier(M, d0, d1, "bouclier_dos", plan, lambda c: (-1, 0, 0))
    cdos = M.s((X_DOS, 0, 0))
    idd = [M.s(p) for p in d0]
    for i in range(COTES):
        j = (i + 1) % COTES
        M.face([cdos, idd[j], idd[i]], "bouclier_dos", [(0.5, 0.5), uv_plan(d0[j]), uv_plan(d0[i])])
    # --- cerclage de fer : face avant (bande), tranche, face arrière (bande) — section en U autour du bord
    e = 0.004
    c_av_int = anneau(r_int, X_FACE + e * 0.5)
    c_av_ext = anneau(R, X_FACE + e)
    c_ar_ext = anneau(R, X_DOS - e)
    c_ar_int = anneau(r_int, X_DOS - e * 0.5)
    tour = lambda p, k: ((math.atan2(p[2], p[1]) / (2 * math.pi)) % 1.0 * 6.0, 0.25 * (k in (2, 3)))
    relier(M, c_av_int, c_av_ext, "fer", plan, lambda c: (1, 0, 0))
    relier(M, c_av_ext, c_ar_ext, "fer", tour, lambda c: (0, c[1], c[2]))
    relier(M, c_ar_ext, c_ar_int, "fer", plan, lambda c: (-1, 0, 0))
    # rebord intérieur du cerclage (épaisseur visible au ras de la peinture)
    relier(M, f2, c_av_int, "fer", tour, lambda c: (0, -c[1], -c[2]))
    relier(M, c_ar_int, d1, "fer", tour, lambda c: (0, -c[1], -c[2]))
    # --- umbo : collerette puis dôme (12 pans)
    nu = 12
    prof = [(R_UMBO + 0.012, X_FACE + 0.006), (R_UMBO + 0.010, X_FACE + 0.012), (R_UMBO - 0.004, X_FACE + 0.014),
            (R_UMBO * 0.86, X_FACE + 0.040), (R_UMBO * 0.62, X_FACE + 0.060), (R_UMBO * 0.30, X_FACE + H_UMBO - 0.004)]
    anns = [anneau(r, x, nu) for r, x in prof]
    uv_u = lambda p, k: (0.5 + p[1] * 3.0, 0.5 + p[2] * 3.0)
    for a, b in zip(anns[:-1], anns[1:]):
        relier(M, a, b, "fer", uv_u, lambda c: (c[0] - X_FACE + 0.02, c[1], c[2]))
    som = M.s((X_FACE + H_UMBO, 0, 0))
    il = [M.s(p) for p in anns[-1]]
    for i in range(nu):
        j = (i + 1) % nu
        M.face([il[i], il[j], som], "fer", [uv_u(anns[-1][i], 0), uv_u(anns[-1][j], 0), (0.5, 0.5)])
    # rivets de la collerette (4 petites pyramides)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        cy, cz = (R_UMBO + 0.004) * math.cos(a), (R_UMBO + 0.004) * math.sin(a)
        b = [M.s((X_FACE + 0.013, cy + dy, cz + dz)) for dy, dz in ((-0.006, -0.006), (0.006, -0.006), (0.006, 0.006), (-0.006, 0.006))]
        t = M.s((X_FACE + 0.021, cy, cz))
        for i in range(4):
            M.face([b[i], b[(i + 1) % 4], t], "fer", [(0.1, 0.1), (0.3, 0.1), (0.2, 0.3)])
    # --- poignée (dans le poing) : barre de cuir le long de Z, ancrée au dos par deux pattes de fer
    def boite(x0, x1, y0, y1, z0, z1, mat, uv_l=1.0):
        P = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        ids = [M.s(p) for p in P]
        cx, cy, cz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
        for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            c = [sum(P[i][k] for i in q) / 4.0 for k in range(3)]
            M.face([ids[i] for i in q], mat, [(0, 0), (1, 0), (1, uv_l), (0, uv_l)], (c[0] - cx, c[1] - cy, c[2] - cz))
    boite(-0.012, 0.012, -0.013, 0.013, -0.085, 0.085, "cuir", 3.0)
    boite(-0.006, X_DOS, -0.016, 0.016, -0.100, -0.080, "fer")
    boite(-0.006, X_DOS, -0.016, 0.016, 0.080, 0.100, "fer")
    # latte de renfort au dos, en travers des planches (le long de la poignée)
    boite(X_DOS - 0.012, X_DOS, -0.03, 0.03, -r_int * 0.92, -0.10, "bouclier_dos", 2.0)
    boite(X_DOS - 0.012, X_DOS, -0.03, 0.03, 0.10, r_int * 0.92, "bouclier_dos", 2.0)
    o = M.creer()
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me)
    bm.free()
    for nom, p in (("prise", (0, 0, 0)), ("umbo", (X_FACE + H_UMBO, 0, 0)), ("bord_haut", (X_FACE, 0, R))):
        v = bpy.data.objects.new(nom, None)
        v.location = p
        v.empty_display_size = 0.02
        bpy.context.scene.collection.objects.link(v)
    os.makedirs(SORTIE, exist_ok=True)
    glb = os.path.join(SORTIE, "bouclier_nordique.glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_materials='EXPORT',
                              export_image_format='NONE', export_yup=True, use_selection=False)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print("BOUCLIER tris=%d rayon=%.2f m -> %s" % (tris, R, glb))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DEPOT, "sources_blender", "bouclier_nordique.blend"))


construire()
