# Bouclier rond nordique v2 (retour utilisateur 2026-11-25 : « un bloc de béton ») : DISQUE FIN de 7 planches (2 cm), cerclage
# de fer riveté, umbo bombé à collerette, poignée centrale derrière l'umbo + sangle d'avant-bras au dos.
#   blender.exe -b --python bouclier_nordique.py
# Exporte assets/modeles/armes/bouclier_nordique.glb (l'ancien : bouclier_nordique_v1.glb, même repère).
#
# REPÈRE (convention DonneesArme / mains._calculer_prise, inchangé) :
#   glTF : origine = centre du poing sur la poignée ; +Y le long de la poignée (de l'auriculaire vers l'index) ;
#          +X = vers les jointures = la FACE du bouclier (côté peint, umbo) ; Z = X x Y = sens des doigts (dans le plan du
#          bouclier) : l'AVANT-BRAS part vers -Z glTF, parallèle au plan du bouclier, la sangle l'y retient.
#   Blender : Z = poignée, X = face, Y = -Z glTF (export Y-up). L'avant-bras court donc le long de +Y Blender.
# NŒUDS VIDES : `prise` (centre du poing), `umbo` (sommet de l'umbo), `bord_haut` (bord dans l'axe de la poignée),
#   `sangle` (centre de la sangle d'avant-bras).
# MATÉRIAUX (habillés en PS1 par scripts/objets/bouclier_nordique.gd) : bouclier_face, bouclier_dos, fer, cuir.
# UV face et dos : projection plane du disque, u = 0,5 + z_blender/(2R), v = 0,5 + y_blender/(2R) (les planches courent le long
# de l'avant-bras ; la poignée les croise).
import bpy, bmesh, math, os

ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(DEPOT, "assets", "modeles", "armes")

R = 0.42           # rayon : 84 cm (bouclier viking 80-90 cm)
COTES = 32         # silhouette : 32 pans
X_DOS = 0.055      # plan du dos des planches (la main et l'avant-bras passent derrière, x < 0.05)
X_FACE = 0.075     # plan de la face peinte : planches de 2 cm
R_CER = 0.026      # largeur du cerclage de fer sur la face
R_UMBO = 0.074     # rayon du dôme
H_UMBO = 0.058     # hauteur du dôme au-dessus de la face
BORDS = [0, 17, 35, 54, 73, 92, 110, 128]   # joints des 7 planches (comme la texture)


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
    return (0.5 + p[2] / (2 * R), 0.5 + p[1] / (2 * R))


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
    tour_uv = lambda p, k: ((math.atan2(p[2], p[1]) / (2 * math.pi)) % 1.0 * 6.0, 0.25 * (k in (2, 3)))
    r_int = R - R_CER
    r_pl = R - 0.012            # les planches passent sous le cerclage
    # ---------------------------------------------------------------- 7 planches (relief : +-1,5 mm de l'une à l'autre)
    jit = [0.0012, -0.0010, 0.0015, -0.0014, 0.0008, -0.0012, 0.0010]
    for k in range(7):
        z0 = (BORDS[k] / 128.0 - 0.5) * 2 * r_pl
        z1 = (BORDS[k + 1] / 128.0 - 0.5) * 2 * r_pl
        zm = 0.5 * (z0 + z1)
        a = lambda z: math.sqrt(max(r_pl * r_pl - z * z, 1e-6))
        zs = [z0, zm, z1]
        # contour (y, z) dans le sens trigo vu de +X : bas (-y) de z0 à z1, puis haut (+y) de z1 à z0
        cont = [(-a(z), z) for z in zs] + [(a(z), z) for z in reversed(zs)]
        xf = X_FACE + jit[k]
        # petit jeu de 1 mm entre planches : les joints se creusent sous la lumière
        fa = [M.s((xf, y, z)) for y, z in cont]
        ba = [M.s((X_DOS, y, z)) for y, z in cont]
        pf = [(xf, y, z) for y, z in cont]
        pb = [(X_DOS, y, z) for y, z in cont]
        # triangulation en éventail depuis le premier point
        for i in range(1, len(cont) - 1):
            M.face([fa[0], fa[i], fa[i + 1]], "bouclier_face", [uv_plan(pf[0]), uv_plan(pf[i]), uv_plan(pf[i + 1])], (1, 0, 0))
            M.face([ba[0], ba[i], ba[i + 1]], "bouclier_dos", [uv_plan(pb[0]), uv_plan(pb[i]), uv_plan(pb[i + 1])], (-1, 0, 0))
        cy = sum(c[0] for c in cont) / len(cont)
        cz = sum(c[1] for c in cont) / len(cont)
        for i in range(len(cont)):
            j = (i + 1) % len(cont)
            # tranche : sur l'épaisseur du bord de planche (visible aux joints, les voisines étant décalées de 1-2 mm)
            M.face([fa[i], fa[j], ba[j], ba[i]], "bouclier_dos", [(0.1, 0.1), (0.2, 0.1), (0.2, 0.3), (0.1, 0.3)],
                   (0, 0.5 * (cont[i][0] + cont[j][0]) - cy, 0.5 * (cont[i][1] + cont[j][1]) - cz))
    # ---------------------------------------------------------------- cerclage de fer riveté (section en U autour du bord)
    e = 0.006
    xfr = X_FACE + 0.004       # dessus du cerclage côté face
    xbr = X_DOS - 0.004        # dessus côté dos
    c_av_int = anneau(r_int, xfr)
    c_av_ext = anneau(R, xfr - 0.002)
    c_ar_ext = anneau(R, xbr + 0.002)
    c_ar_int = anneau(r_int, xbr)
    relier(M, c_av_int, c_av_ext, "fer", plan, lambda c: (1, 0, 0))
    relier(M, c_av_ext, c_ar_ext, "fer", tour_uv, lambda c: (0, c[1], c[2]))
    relier(M, c_ar_ext, c_ar_int, "fer", plan, lambda c: (-1, 0, 0))
    # lèvre intérieure du cerclage (rebord qui plonge sur la face puis sur le dos)
    f_int = anneau(r_int - 0.002, X_FACE - 0.001)
    d_int = anneau(r_int - 0.002, X_DOS + 0.001)
    relier(M, f_int, c_av_int, "fer", tour_uv, lambda c: (0, 0, 0) if False else (0.6, -c[1], -c[2]))
    relier(M, c_ar_int, d_int, "fer", tour_uv, lambda c: (-0.6, -c[1], -c[2]))
    # rivets du cerclage : 16 petites pyramides sur la face
    for k in range(16):
        a = (k + 0.5) * 2 * math.pi / 16
        rr = R - R_CER * 0.5
        cy, cz = rr * math.cos(a), rr * math.sin(a)
        b = [M.s((xfr + 0.001, cy + dy, cz + dz)) for dy, dz in ((-0.006, -0.006), (0.006, -0.006), (0.006, 0.006), (-0.006, 0.006))]
        t = M.s((xfr + 0.009, cy, cz))
        for i in range(4):
            M.face([b[i], b[(i + 1) % 4], t], "fer", [(0.1, 0.1), (0.3, 0.1), (0.2, 0.3)], (1, 0, 0))
    # ---------------------------------------------------------------- umbo : collerette plate rivetée + dôme (16 pans)
    nu = 16
    prof = [(0.118, 0.0035), (0.112, 0.0060), (0.094, 0.0070), (R_UMBO + 0.004, 0.0100), (R_UMBO, 0.0300), (R_UMBO * 0.93, 0.0440),
            (R_UMBO * 0.72, 0.0540), (R_UMBO * 0.40, H_UMBO - 0.001)]
    anns = [anneau(r, X_FACE + h, nu) for r, h in prof]
    uv_u = lambda p, k: (0.5 + p[1] * 3.0, 0.5 + p[2] * 3.0)
    for a_, b_ in zip(anns[:-1], anns[1:]):
        relier(M, a_, b_, "fer", uv_u, lambda c: (c[0] - X_FACE + 0.03, c[1], c[2]))
    som = M.s((X_FACE + H_UMBO + 0.004, 0, 0))
    il = [M.s(p) for p in anns[-1]]
    for i in range(nu):
        j = (i + 1) % nu
        M.face([il[i], il[j], som], "fer", [uv_u(anns[-1][i], 0), uv_u(anns[-1][j], 0), (0.5, 0.5)], (1, 0, 0))
    # sous la collerette : fermeture jusqu'aux planches
    for k in range(8):
        a = (k + 0.5) * 2 * math.pi / 8
        cy, cz = 0.103 * math.cos(a), 0.103 * math.sin(a)
        b = [M.s((X_FACE + 0.0065, cy + dy, cz + dz)) for dy, dz in ((-0.006, -0.006), (0.006, -0.006), (0.006, 0.006), (-0.006, 0.006))]
        t = M.s((X_FACE + 0.0135, cy, cz))
        for i in range(4):
            M.face([b[i], b[(i + 1) % 4], t], "fer", [(0.1, 0.1), (0.3, 0.1), (0.2, 0.3)], (1, 0, 0))
    # ---------------------------------------------------------------- DOS : poignée, pattes, sangle d'avant-bras, lattes
    def boite(x0, x1, y0, y1, z0, z1, mat, uv_l=1.0):
        P = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        ids = [M.s(p) for p in P]
        cx, cy, cz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
        for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            c = [sum(P[i][k] for i in q) / 4.0 for k in range(3)]
            M.face([ids[i] for i in q], mat, [(0, 0), (1, 0), (1, uv_l), (0, uv_l)], (c[0] - cx, c[1] - cy, c[2] - cz))
    # poignée de bois (le poing la tient : centre en 0,0,0), le long de Z
    boite(-0.013, 0.013, -0.014, 0.014, -0.090, 0.090, "cuir", 3.0)
    # pattes de fer qui la rivent aux planches (x de la poignée au dos des planches)
    boite(-0.007, X_DOS + 0.001, -0.017, 0.017, -0.112, -0.086, "fer")
    boite(-0.007, X_DOS + 0.001, -0.017, 0.017, 0.086, 0.112, "fer")
    # lattes de renfort au dos, en travers des planches (le long de Z), de part et d'autre de la poignée
    ch = lambda y: math.sqrt(max(r_int * r_int - y * y, 1e-6)) * 0.97
    for y in (0.27, -0.27):
        boite(X_DOS - 0.014, X_DOS + 0.001, y - 0.032, y + 0.032, -ch(y), ch(y), "bouclier_dos", 2.0)
    # sangle d'avant-bras : arche de cuir qui enjambe l'avant-bras (il court le long de +Y, centré sur x = 0), à 17 cm du poing,
    # plus une seconde sangle près du coude (y = 0,30 : sur la latte)
    for y in (0.17,):
        boite(-0.070, -0.054, y - 0.022, y + 0.022, -0.062, 0.062, "cuir", 2.0)          # bande qui passe sous l'avant-bras
        boite(-0.070, X_DOS - 0.012, y - 0.022, y + 0.022, -0.074, -0.058, "cuir", 1.0)  # montants
        boite(-0.070, X_DOS - 0.012, y - 0.022, y + 0.022, 0.058, 0.074, "cuir", 1.0)
        boite(-0.007, X_DOS + 0.001, y - 0.030, y + 0.030, -0.080, -0.068, "fer")        # platines de fer
        boite(-0.007, X_DOS + 0.001, y - 0.030, y + 0.030, 0.068, 0.080, "fer")
        boite(-0.073, -0.067, y - 0.010, y + 0.010, 0.006, 0.030, "fer")                # boucle
    o = M.creer()
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me)
    bm.free()
    for nom, p in (("prise", (0, 0, 0)), ("umbo", (X_FACE + H_UMBO, 0, 0)), ("bord_haut", (X_FACE, 0, R)), ("sangle", (-0.06, 0.17, 0))):
        v = bpy.data.objects.new(nom, None)
        v.location = p
        v.empty_display_size = 0.02
        bpy.context.scene.collection.objects.link(v)
    os.makedirs(SORTIE, exist_ok=True)
    glb = os.path.join(SORTIE, "bouclier_nordique.glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_materials='EXPORT',
                              export_image_format='NONE', export_yup=True, use_selection=False)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print("BOUCLIER tris=%d rayon=%.2f m epaisseur=%.1f cm -> %s" % (tris, R, (X_FACE - X_DOS) * 100, glb))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DEPOT, "sources_blender", "bouclier_nordique.blend"))


construire()
