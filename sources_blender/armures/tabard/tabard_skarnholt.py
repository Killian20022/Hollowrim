"""TABARD DE LA GARDE DE SKARNHOLT (livrée du village, 2026-11-11).

Porté PAR-DESSUS les cuirasses de fer et d'acier nordique des gardes maison (GardeMaison, data/gardes.json « tabard ») : pan avant et pan
arrière rouge sombre (rouge des bannières du village, assombri comme les tabards Tripo), galon clair, arbre de Skarnholt brodé devant et
dans le dos, ceinture de cuir à boucle de fer qui le maintient à la taille, ourlet légèrement effiloché (dents + fils peints).

Construction (repère GODOT : x, y haut, z devant ; armures_lib.B/G convertissent) :
  - squelette : homme_vetu.glb (65 os, celui des pièces portées et du Gardien) ;
  - chaque pan = grille (colonnes x rangées) posée à `JEU` m au-dessus de la surface la plus EXTÉRIEURE des DEUX cuirasses
    (cuirasse_fer, cuirasse_acier_nordique, hors col de fourrure) : lancer de rayon de face (ou de dos), puis dilatation (max des voisins)
    et flou -> le pan ne rentre jamais dans une plaque, il les enjambe ; sous l'ourlet des cuirasses il tombe droit ; plis verticaux
    vers l'extérieur sous la ceinture ; épaisseur 5 mm (solidify + bords : maillage fermé, zéro trou) ;
  - poids d'os : copiés des sommets les plus proches de la cuirasse de fer (k = 6, lissés) -> le pan suit la cuirasse (torse, bassin,
    pans de jupe sur les cuisses) en marche / course / coups ; une cuirasse plus fine laisse simplement plus de jeu ;
  - texture 512² peinte dans l'espace des pans (UV posées à la construction) : drap tissé, plis, galon, arbre brodé, ourlet
    effiloché, crasse vers le bas ; ceinture de cuir piqué ; boucle de fer. Alpha = brillance (faible : drap).
Sortie : assets/modeles/armures/livrees/tabard_skarnholt.glb (skinné, armature complète), aperçus Workbench dans le dossier argv[1].
Lancement : blender.exe -b --python tabard_skarnholt.py -- [dossier_apercus]
"""
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import armures_lib as L
B, G = L.B, L.G

LIVREES = os.path.join(L.ROOT, "assets", "modeles", "armures", "livrees")
IDENT = "tabard_skarnholt"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
APERCUS = ARGS[0] if ARGS else os.path.join(L.ROOT, "sources_blender", "armures", "tabard", "apercus")

# ----------------------------------------------------------------------------------------------------------- réglages
NX = 14                 # colonnes d'un pan
Y_HAUT = 1.47           # haut des pans (glissé sous le col de fourrure)
Y_OURLET = 0.605        # ourlet (sous la jupe des cuirasses, qui finit à 0,64 ; genou à 0,54)
Y_OURLET_DOS = 0.685    # pan arrière plus court : le talon relevé à la course (Jog_Fwd) le traversait sous 0,68
PAS_Y = 0.024
JEU = 0.016             # au-dessus des plaques
JEU_BAS = 0.022         # sous la ceinture (pans de jupe mobiles)
EPAIS = 0.005
Y_CEINT = 0.995         # milieu de la ceinture
H_CEINT = 0.052
TEX = 512
SUIVI_CUISSE = 0.55     # part de la cuisse du côté dans le bas des pans
Y_FENTE = 0.84          # fente du pan arrière (sous la ceinture)
SUIVI_MOLLET = 0.30    # bas du pan arrière : part du mollet du côté (le talon relevé à la course soulève le pan)


def demi_largeur(y, dos=False):
    """Demi-largeur du pan à la hauteur y (épaules étroites sous les épaulières, évasé vers l'ourlet)."""
    pts = [(1.47, 0.125), (1.38, 0.160), (1.25, 0.170), (1.05, 0.160), (0.90, 0.172), (0.605, 0.200)]
    if dos:
        pts = [(1.47, 0.135), (1.38, 0.168), (1.25, 0.175), (1.05, 0.162), (0.90, 0.175), (0.605, 0.205)]
    for (y0, w0), (y1, w1) in zip(pts, pts[1:]):
        if y1 <= y <= y0:
            t = (y0 - y) / (y0 - y1)
            t = t * t * (3 - 2 * t)
            return w0 + (w1 - w0) * t
    return pts[-1][1] if y < pts[-1][0] else pts[0][1]


# ----------------------------------------------------------------------------------------------------------- scène
arm = L.scene_base()
# matériaux créés AVANT l'import des cuirasses (leurs « cuir » / « fer » prendraient sinon les noms simples)
IMG = bpy.data.images.new(IDENT, TEX, TEX, alpha=True)
MATS = [L.materiau(n, IMG) for n in ("tissu", "cuir", "fer")]


def importer(pid):
    avant = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(L.PORTE, pid + ".glb"))
    nouv = [o for o in bpy.data.objects if o not in avant]
    m = None
    for o in nouv:
        if o.type == 'MESH' and len(o.data.vertices) > 100:
            m = o
        elif o.type == 'MESH':
            bpy.data.objects.remove(o)
    return m


CUIRASSES = [importer("cuirasse_fer"), importer("cuirasse_acier_nordique")]


def bvh_cuirasses(fourrure=False):
    V, F = [], []
    for o in CUIRASSES:
        me = o.data
        off = len(V)
        V += [o.matrix_world @ v.co for v in me.vertices]
        for p in me.polygons:
            nom = me.materials[p.material_index].name if me.materials else ""
            if nom.startswith("fourrure") != fourrure:
                continue
            vs = list(p.vertices)
            for i in range(1, len(vs) - 1):
                F.append((vs[0] + off, vs[i] + off, vs[i + 1] + off))
    return BVHTree.FromPolygons(V, F, epsilon=0.0)


BVH = bvh_cuirasses(False)
BVH_F = bvh_cuirasses(True)


def surface_z(x, y, dos):
    """z de la surface la plus extérieure (de face ou de dos) des cuirasses, None sans touche."""
    s = -1.0 if dos else 1.0
    hit = BVH.ray_cast(B(x, y, 0.7 * s), B(0, 0, -s), 1.4)
    return G(hit[0]).z if hit[0] is not None else None


def fourrure_z(x, y, dos):
    s = -1.0 if dos else 1.0
    hit = BVH_F.ray_cast(B(x, y, 0.7 * s), B(0, 0, -s), 1.4)
    return G(hit[0]).z if hit[0] is not None else None


# diagnostic : bas du col de fourrure au milieu (le haut des pans doit glisser dessous)
for dos in (False, True):
    for y in (1.52, 1.50, 1.48, 1.46, 1.44, 1.42):
        print("COL %s y=%.2f plaque %s fourrure %s" % ("dos" if dos else "face", y, surface_z(0.0, y, dos), fourrure_z(0.0, y, dos)))


# ----------------------------------------------------------------------------------------------------------- pans
def rangees(fin=Y_OURLET):
    ys = []
    y = Y_HAUT
    while y > fin + 0.008:
        ys.append(y)
        y -= PAS_Y
    ys.append(fin)
    return ys


def pli(x, y):
    """Plis verticaux sous la ceinture (vers l'extérieur, 0..1)."""
    if y > Y_CEINT - 0.03:
        return 0.0
    t = min(1.0, (Y_CEINT - 0.03 - y) / 0.22)
    return t * (0.5 - 0.5 * math.cos(2 * math.pi * (x / 0.068 + 0.5)))


def construire_pan(dos):
    ys = rangees(Y_OURLET_DOS if dos else Y_OURLET)
    ny = len(ys)
    s = -1.0 if dos else 1.0
    Z = np.full((ny, NX + 1), np.nan)
    X = np.zeros((ny, NX + 1))
    for j, y in enumerate(ys):
        w = demi_largeur(y, dos)
        for i in range(NX + 1):
            x = w * (2.0 * i / NX - 1.0)
            X[j, i] = x
            # plusieurs rayons autour du sommet (pas d'arête de plaque glissée entre deux sommets)
            zs = [surface_z(x + dx, y + dy, dos) for dx in (-0.012, 0.0, 0.012) for dy in (-0.012, 0.0, 0.012)]
            zs = [z * s for z in zs if z is not None]
            if zs:
                Z[j, i] = max(zs)
    # sous l'ourlet des cuirasses (ou sans touche) : le pan tombe droit depuis la rangée du dessus
    # fente entre les pans de jupe (dos) : le rayon traverse jusqu'à la face interne d'en face -> pas de touche
    for j in range(1, ny):
        for i in range(NX + 1):
            if not np.isnan(Z[j, i]) and (Z[j, i] < 0.09 or (not np.isnan(Z[j - 1, i]) and Z[j, i] < Z[j - 1, i] - 0.03)):
                Z[j, i] = np.nan
    for j in range(ny):
        for i in range(NX + 1):
            if np.isnan(Z[j, i]) or (ys[j] < 0.66 and j > 0 and Z[j, i] < Z[j - 1, i] - 0.004):
                Z[j, i] = Z[j - 1, i] if j > 0 else np.nanmax(Z[j])
    jeu = np.array([JEU if y > Y_CEINT - 0.02 else JEU_BAS for y in ys])[:, None]
    base = Z + jeu
    # dilatation (max des voisins) puis flou, sans jamais repasser sous base
    D = base.copy()
    for _ in range(2):
        P = np.pad(D, 1, mode='edge')
        D = np.max([P[1 + a:P.shape[0] - 1 + a, 1 + b:P.shape[1] - 1 + b] for a in (-1, 0, 1) for b in (-1, 0, 1)], axis=0)
    for _ in range(4):
        P = np.pad(D, 1, mode='edge')
        D = (P[1:-1, 1:-1] * 4 + P[:-2, 1:-1] + P[2:, 1:-1] + P[1:-1, :-2] + P[1:-1, 2:]) / 8.0
        D = np.maximum(D, base)
    # bords : le pan s'enroule un peu vers le corps (pas une planche plate)
    for j in range(ny):
        for i in (0, NX):
            D[j, i] -= 0.006
        for i in (1, NX - 1):
            D[j, i] -= 0.002
    D = np.maximum(D, base - 0.004)
    print("PAN %s colonne du milieu (y, surface, pan) :" % ("dos" if dos else "face"),
          [(round(ys[j], 2), round(float(Z[j, NX // 2]), 3), round(float(D[j, NX // 2]), 3)) for j in range(0, ny, 3)])
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    part = bm.faces.layers.int.new("partie")
    V = []
    u0 = 0.52 if dos else 0.02
    for j, y in enumerate(ys):
        ligne = []
        for i in range(NX + 1):
            x = X[j, i]
            z = D[j, i] + 0.011 * pli(x, y)
            yy = y
            if j == ny - 1:
                # ourlet en dents (effiloché), légèrement irrégulier
                yy = y + (0.0 if i % 2 == 0 else 0.013) + 0.004 * math.sin(i * 2.3 + (1.7 if dos else 0.0))
            vv = (Y_HAUT - yy) / (Y_HAUT - Y_OURLET + 0.02)
            if dos and i == NX // 2 and y < Y_FENTE:
                # FENTE du pan arrière (comme la jupe des cuirasses) : deux sommets écartés, chaque moitié suit sa jambe
                ligne.append(((bm.verts.new(B(x - 0.004, yy, z * s)), i / NX, vv), (bm.verts.new(B(x + 0.004, yy, z * s)), i / NX, vv)))
            else:
                ligne.append((bm.verts.new(B(x, yy, z * s)), i / NX, vv))
        V.append(ligne)

    def sommet(j, i, cote):
        a = V[j][i]
        return a[cote] if isinstance(a[0], tuple) else a

    for j in range(ny - 1):
        for i in range(NX):
            q = [sommet(j, i, 1), sommet(j, i + 1, 0), sommet(j + 1, i + 1, 0), sommet(j + 1, i, 1)]
            f = bm.faces.new([a[0] for a in q])
            f[part] = 1 if dos else 0
            for lp, a in zip(f.loops, q):
                # UV : u de 0 à 0,46 sur la largeur, v = 1 en haut (texture : ligne 0 = bas)
                lp[uvl].uv = (u0 + a[1] * 0.46, 1.0 - 0.02 - a[2] * 0.96)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = L.bm_vers_objet(bm, "pan_dos" if dos else "pan_face")
    bm.free()
    # normales vers l'extérieur (+z devant, -z derrière)
    n = sum((p.normal for p in o.data.polygons), Vector())
    if G(n).z * s < 0:
        for p in o.data.polygons:
            p.flip()
    o.data.update()
    return o


PANS = [construire_pan(False), construire_pan(True)]


# ----------------------------------------------------------------------------------------------------------- ceinture
def bvh_objets(objs, avec_cuirasses=True):
    V, F = [], []
    for o in objs:
        me = o.data
        off = len(V)
        V += [o.matrix_world @ v.co for v in me.vertices]
        for p in me.polygons:
            vs = list(p.vertices)
            for i in range(1, len(vs) - 1):
                F.append((vs[0] + off, vs[i] + off, vs[i + 1] + off))
    if avec_cuirasses:
        for o in CUIRASSES:
            me = o.data
            off = len(V)
            V += [o.matrix_world @ v.co for v in me.vertices]
            for p in me.polygons:
                if me.materials and me.materials[p.material_index].name.startswith("fourrure"):
                    continue
                vs = list(p.vertices)
                for i in range(1, len(vs) - 1):
                    F.append((vs[0] + off, vs[i] + off, vs[i + 1] + off))
    return BVHTree.FromPolygons(V, F, epsilon=0.0)


def construire_ceinture():
    bvh = bvh_objets(PANS)
    NA = 56
    hs = [Y_CEINT + H_CEINT / 2, Y_CEINT, Y_CEINT - H_CEINT / 2]
    centre_z = -0.01
    R = np.zeros((len(hs), NA))
    for k, y in enumerate(hs):
        for a in range(NA):
            th = 2 * math.pi * a / NA
            d = (math.sin(th), 0.0, math.cos(th))     # th = 0 : devant
            r = 0.0
            for dy in (-0.012, 0.0, 0.012):
                c = B(0, y + dy, centre_z)
                hit = bvh.ray_cast(c + B(d) * 0.5, -B(d), 0.5)
                if hit[0] is not None:
                    r = max(r, (G(hit[0]) - Vector((0, y + dy, centre_z))).length)
            R[k, a] = r
    r_max = R.max(0)
    for _ in range(3):
        r_max = np.maximum(r_max, (np.roll(r_max, 1) + np.roll(r_max, -1) + 2 * r_max) / 4)
    r_max = r_max + 0.007
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    part = bm.faces.layers.int.new("partie")
    lignes = []
    for k, y in enumerate(hs):
        ligne = []
        for a in range(NA):
            th = 2 * math.pi * a / NA
            r = r_max[a] + (0.003 if k == 1 else 0.0)
            ligne.append(bm.verts.new(B(math.sin(th) * r, y, centre_z + math.cos(th) * r)))
        lignes.append(ligne)
    for k in range(len(hs) - 1):
        for a in range(NA):
            a2 = (a + 1) % NA
            q = [lignes[k][a], lignes[k][a2], lignes[k + 1][a2], lignes[k + 1][a]]
            f = bm.faces.new(q)
            f[part] = 2
            for lp, (kk, aa) in zip(f.loops, [(k, a), (k, a + 1), (k + 1, a + 1), (k + 1, a)]):
                lp[uvl].uv = (0.955 + 0.035 * (1 - kk / 2.0), 0.14 + 0.84 * aa / NA)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = L.bm_vers_objet(bm, "ceinture")
    bm.free()
    n = sum((p.normal * p.area for p in o.data.polygons), Vector())
    # normales vers l'extérieur : le centre des faces s'éloigne de l'axe
    p0 = o.data.polygons[0]
    c = G(p0.center)
    if G(p0.normal).dot(Vector((c.x, 0, c.z - centre_z))) < 0:
        for p in o.data.polygons:
            p.flip()
    o.data.update()
    # boucle de fer devant (cadre plein + ardillon : une plaque épaisse peinte)
    zf = centre_z + r_max[0] + 0.003
    bmb = bmesh.new()
    uvb = bmb.loops.layers.uv.new("UVMap")
    partb = bmb.faces.layers.int.new("partie")
    res = bmesh.ops.create_cube(bmb, size=1.0)
    for v in res["verts"]:
        g = G(v.co)
        v.co = B(g.x * 0.056, Y_CEINT + g.y * 0.062, zf + 0.004 + g.z * 0.010)
    for f in bmb.faces:
        f[partb] = 3
        nz = G(f.normal)
        for lp in f.loops:
            g = G(lp.vert.co)
            if abs(nz.z) > 0.5:
                lp[uvb].uv = (0.955 + 0.035 * (g.x / 0.056 + 0.5), 0.02 + 0.10 * ((g.y - Y_CEINT) / 0.062 + 0.5) - 0.0)
            else:
                lp[uvb].uv = (0.96, 0.03)
    ob = L.bm_vers_objet(bmb, "boucle")
    bmb.free()
    return o, ob


CEINT, BOUCLE = construire_ceinture()


# ----------------------------------------------------------------------------------------------------------- épaisseur
def epaissir(o, e):
    m = o.modifiers.new("ep", 'SOLIDIFY')
    m.thickness = e
    m.offset = -1.0
    m.use_rim = True
    m.use_even_offset = True
    bpy.context.view_layer.objects.active = o
    with bpy.context.temp_override(object=o, active_object=o):
        bpy.ops.object.modifier_apply(modifier=m.name)


for o in PANS:
    epaissir(o, EPAIS)
epaissir(CEINT, 0.006)

# matériaux par objet (0 tissu, 1 cuir, 2 fer)
for o, mi in ((PANS[0], 0), (PANS[1], 0), (CEINT, 1), (BOUCLE, 2)):
    o.data.materials.clear()
    for m in MATS:
        o.data.materials.append(m)
    for p in o.data.polygons:
        p.material_index = mi

TAB = L.joindre(PANS + [CEINT, BOUCLE], IDENT)
L.lisser_normales(TAB)
for p in TAB.data.polygons:
    p.use_smooth = False   # drap à facettes nettes (shader ps1)


# ----------------------------------------------------------------------------------------------------------- poids
src = CUIRASSES[0]
pw = L.poids_proches(TAB, src, k=6, filtre=lambda p: p.y > 0.60)
# le haut des pans ne suit pas les bras (épaulières) : poids des bras rendus aux clavicules
def sans_bras(d):
    r = {}
    for k_, w in d.items():
        k2 = k_.replace("upperarm", "clavicle") if k_.startswith("upperarm") else k_
        r[k2] = r.get(k2, 0.0) + w
    return r


pw = [sans_bras(d) for d in pw]
pw = L.normaliser(pw)
pw = L.lisser_poids(TAB, pw, iterations=3, force=0.5)
pw = L.normaliser(pw)


def cote_cuisse(d, p):
    """Bas des pans : chaque moitié suit davantage la cuisse de son côté (le genou levé pousse le drap au lieu de le traverser)."""
    if p.y > 0.92 or abs(p.z) < 0.08:
        return d
    t = min(1.0, (0.92 - p.y) / 0.26)
    k = SUIVI_CUISSE * t * min(1.0, abs(p.x) / 0.09)
    if k <= 0.0:
        return d
    os_c = "thigh_l" if p.x > 0 else "thigh_r"
    r = {n_: w * (1 - k) for n_, w in d.items()}
    r[os_c] = r.get(os_c, 0.0) + k
    if p.z < 0 and p.y < Y_FENTE:
        km = SUIVI_MOLLET * min(1.0, (Y_FENTE - p.y) / 0.22) * min(1.0, abs(p.x) / 0.05)
        os_m = "calf_l" if p.x > 0 else "calf_r"
        r = {n_: w * (1 - km) for n_, w in r.items()}
        r[os_m] = r.get(os_m, 0.0) + km
    return r


pw = [cote_cuisse(d, G(TAB.matrix_world @ v.co)) for d, v in zip(pw, TAB.data.vertices)]
pw = L.lisser_poids(TAB, pw, iterations=1, force=0.4)
pw = L.normaliser(pw)
L.ecrire_poids(TAB, pw)
os_utilises = {}
for d in pw:
    for k_, w in d.items():
        os_utilises[k_] = os_utilises.get(k_, 0.0) + w
print("POIDS os :", sorted(((k_, round(w, 1)) for k_, w in os_utilises.items()), key=lambda t: -t[1]))


# ----------------------------------------------------------------------------------------------------------- texture
def bruit2(x, y, f, g=0):
    """Bruit de valeur 2D lissé (numpy), x et y en mètres."""
    xi, yi = np.floor(x * f), np.floor(y * f)
    xf, yf = x * f - xi, y * f - yi
    def h(a, b):
        n = (a.astype(np.int64) * 73856093) ^ (b.astype(np.int64) * 19349663) ^ (g * 83492791)
        return ((n * 2654435761) % 1000003) / 1000003.0
    u = xf * xf * (3 - 2 * xf)
    v = yf * yf * (3 - 2 * yf)
    return (h(xi, yi) * (1 - u) * (1 - v) + h(xi + 1, yi) * u * (1 - v) + h(xi, yi + 1) * (1 - u) * v + h(xi + 1, yi + 1) * u * v)


def segs_arbre():
    """Arbre de Skarnholt (repère de l'emblème, m) : tronc, couronne de branches symétriques, racines. (a, b, épaisseur)."""
    s = []
    s.append(((0, -0.070), (0, 0.030), 0.0105))
    for sg in (-1, 1):
        s += [((0, 0.022), (sg * 0.048, 0.066), 0.0075),
              ((sg * 0.048, 0.066), (sg * 0.078, 0.060), 0.0055),
              ((sg * 0.048, 0.066), (sg * 0.060, 0.094), 0.0055),
              ((0, 0.010), (sg * 0.066, 0.034), 0.0065),
              ((sg * 0.066, 0.034), (sg * 0.090, 0.040), 0.0045),
              ((sg * 0.030, 0.050), (sg * 0.030, 0.090), 0.0050),
              ((sg * 0.030, 0.090), (sg * 0.020, 0.110), 0.0040),
              ((sg * 0.060, 0.094), (sg * 0.050, 0.112), 0.0040),
              ((0, -0.064), (sg * 0.040, -0.086), 0.0060),
              ((sg * 0.040, -0.086), (sg * 0.066, -0.090), 0.0045),
              ((0, -0.066), (sg * 0.018, -0.096), 0.0050),
              ((sg * 0.078, 0.060), (sg * 0.094, 0.074), 0.0032),
              ((sg * 0.090, 0.040), (sg * 0.102, 0.050), 0.0030),
              ((sg * 0.066, 0.034), (sg * 0.080, 0.022), 0.0030),
              ((sg * 0.060, 0.094), (sg * 0.074, 0.104), 0.0030),
              ((sg * 0.030, 0.090), (sg * 0.040, 0.104), 0.0030),
              ((sg * 0.020, 0.110), (sg * 0.010, 0.124), 0.0028),
              ((sg * 0.050, 0.112), (sg * 0.044, 0.124), 0.0028),
              ((sg * 0.066, -0.090), (sg * 0.080, -0.098), 0.0030)]
    s.append(((0, 0.030), (0, 0.118), 0.0060))
    return s


def dist_segs(px, py, segs):
    d = np.full(px.shape, 9.0)
    for (a, b, e) in segs:
        ax, ay = a
        bx, by = b
        vx, vy = bx - ax, by - ay
        l2 = vx * vx + vy * vy
        t = np.clip(((px - ax) * vx + (py - ay) * vy) / l2, 0, 1)
        dd = np.hypot(px - (ax + t * vx), py - (ay + t * vy)) - e * 0.5
        d = np.minimum(d, dd)
    return d


def srgb(h):
    h = h.lstrip("#")
    c = np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
    return c          # octets de l'image = valeurs sRGB (comme armures_lib.hexa)


ROUGE = srgb("4c0f17")
ROUGE_S = srgb("2a070c")
GALON = srgb("a9a79f")
FIL = srgb("c8c2b2")
FIL_S = srgb("6e675a")
CUIR = srgb("2e2119")
FER = srgb("6a6c70")

px_u = (np.arange(TEX) + 0.5) / TEX
U, Vv = np.meshgrid(px_u, px_u)       # Vv = 0 en bas de l'image (convention Blender)
RGBA = np.zeros((TEX, TEX, 4))
RGBA[..., :3] = ROUGE
RGBA[..., 3] = 0.08


def peindre_pan(dos):
    u0 = 0.52 if dos else 0.02
    m = (U >= u0 - 0.01) & (U <= u0 + 0.47)
    su = np.clip((U[m] - u0) / 0.46, 0, 1)
    # v -> y (inverse des UV de construction)
    a = (1.0 - 0.02 - Vv[m]) / 0.96
    y = Y_HAUT - a * (Y_HAUT - Y_OURLET + 0.02)
    w = np.array([demi_largeur(yy, dos) for yy in y])
    x = w * (2 * su - 1)
    # drap : trame fine + taches lentes ; plis ombrés en phase avec la géométrie
    trame = 0.5 + 0.5 * np.sin(x * 2 * math.pi / 0.0045) * np.sin(y * 2 * math.pi / 0.0045)
    lent = bruit2(x + (3.0 if dos else 0.0), y, 9.0)
    fin = bruit2(x, y + (5.0 if dos else 0.0), 70.0, 1)
    c = ROUGE[None, :] * (0.90 + 0.10 * trame[:, None] + 0.12 * lent[:, None] + 0.04 * fin[:, None])
    pl = np.array([pli(xx, yy) for xx, yy in zip(x, y)])
    c *= (0.78 + 0.30 * pl)[:, None]
    # ombre sous le col (haut) et autour de la ceinture
    c *= (1.0 - 0.35 * np.clip((y - (Y_HAUT - 0.05)) / 0.05, 0, 1))[:, None]
    c *= (1.0 - 0.28 * np.exp(-((y - Y_CEINT) / 0.04) ** 2))[:, None]
    # galon : liseré sombre au bord, filet clair double à l'intérieur
    oy = Y_OURLET_DOS if dos else Y_OURLET
    db = np.minimum(w - np.abs(x), np.minimum(Y_HAUT - y, (y - oy) + 0.02))
    dl = w - np.abs(x)                  # côtés seulement pour le filet intérieur bas
    bord = db < 0.005
    c[bord] = ROUGE_S * 0.8
    f1 = (db > 0.010) & (db < 0.0175)
    f2 = (db > 0.024) & (db < 0.027)
    gal = GALON[None, :] * (0.85 + 0.15 * fin[:, None])
    c[f1] = gal[f1]
    c[f2] = gal[f2] * 0.92
    # emblème : arbre brodé (fil clair, contour sombre, point lancé en diagonale)
    ye = 1.225 if not dos else 1.215
    sc = 1.10 if not dos else 1.18
    d = dist_segs(x / sc, (y - ye) / sc, [(a_, b_, e_ * 0.95) for (a_, b_, e_) in segs_arbre()])
    pt = 0.82 + 0.18 * (np.sin((x + y) * 2 * math.pi / 0.004) > 0)
    cont = (d > 0) & (d < 0.0032)
    c[cont] = c[cont] * 0.45 + FIL_S * 0.15
    dedans = d <= 0
    c[dedans] = FIL[None, :] * pt[dedans, None] * (0.88 + 0.12 * lent[dedans, None])
    # ourlet effiloché : fils clairs/sombres qui pendent, bas usé et sali
    hb = (y - oy)
    fils = bruit2(x * 3.0, np.zeros_like(x), 260.0, 7)
    zone = hb < 0.035
    k = np.clip(1 - hb / 0.035, 0, 1)
    c[zone] *= (1.0 - 0.35 * k[zone] * (fils[zone] > 0.55))[:, None]
    c[zone] += (np.array([0.05, 0.03, 0.02]) * k[zone, None] * (fils[zone, None] > 0.82))
    sale = np.clip((0.80 - y) / 0.22, 0, 1) * (0.5 + 0.5 * lent)
    c = c * (1 - 0.25 * sale[:, None]) + srgb("3a2e26")[None, :] * (0.25 * sale[:, None])
    RGBA[m, :3] = np.clip(c, 0, 1)
    RGBA[m, 3] = 0.05 + 0.06 * dedans + 0.04 * f1


peindre_pan(False)
peindre_pan(True)
# ceinture (bande u 0,955-0,99) : cuir sombre piqué, plus la boucle en bas de la bande
m = U >= 0.95
vv = Vv[m]
uu = (U[m] - 0.955) / 0.035
lc = bruit2(uu * 0.3, vv * 1.0, 40.0, 3)
c = CUIR[None, :] * (0.75 + 0.45 * lc[:, None])
piq = ((np.abs(uu - 0.12) < 0.05) | (np.abs(uu - 0.88) < 0.05)) & (np.sin(vv * 2 * math.pi * 90) > 0.2)
c[piq] = srgb("8a7a62")
RGBA[m, :3] = c
RGBA[m, 3] = 0.20
# boucle de fer (v 0,02-0,12) : cadre clair, creux sombre, ardillon
mb = (U >= 0.95) & (Vv < 0.125)
bu = (U[mb] - 0.955) / 0.035
bv = (Vv[mb] - 0.02) / 0.10
cadre = (np.abs(bu - 0.5) > 0.30) | (np.abs(bv - 0.5) > 0.30)
cb = np.where(cadre[:, None], FER[None, :] * (0.95 + 0.25 * bruit2(bu, bv, 12.0, 4)[:, None]), CUIR[None, :] * 0.6)
ard = (np.abs(bv - 0.5) < 0.06) & (bu > 0.2) & (bu < 0.62)
cb[ard] = FER * 1.2
RGBA[mb, :3] = cb
RGBA[mb, 3] = np.where(cadre | ard, 0.6, 0.15)

IMG.pixels = RGBA.reshape(-1).tolist()
dossier_tex = os.path.join(L.ROOT, "sources_blender", "armures", "textures")
os.makedirs(dossier_tex, exist_ok=True)
IMG.filepath_raw = os.path.join(dossier_tex, IDENT + ".png")
IMG.file_format = 'PNG'
IMG.save()
IMG.pack()

# ----------------------------------------------------------------------------------------------------------- contrôles
bm = bmesh.new()
bm.from_mesh(TAB.data)
ouvert = [e for e in bm.edges if not e.is_manifold]
print("CONTROLE tris", L.nb_tris(TAB), "aretes non manifold", len(ouvert), "sommets", len(bm.verts))
# pénétration : sommets extérieurs des pans sous la surface des cuirasses (de face / de dos)
sous = 0
for v in bm.verts:
    p = G(TAB.matrix_world @ v.co)
    if p.y < Y_OURLET - 0.02 or abs(p.y - Y_CEINT) < 0.04:
        continue
    for dos in (False, True):
        if (p.z < 0) != dos:
            continue
        z = surface_z(p.x, p.y, dos)
        if z is not None and (z - p.z) * (-1 if dos else 1) > 0.0005:
            sous += 1
print("CONTROLE sommets sous une cuirasse :", sous)
bm.free()

# ----------------------------------------------------------------------------------------------------------- export + aperçus
os.makedirs(LIVREES, exist_ok=True)
L.exporter(TAB, arm, IDENT, dossier=LIVREES)
os.makedirs(APERCUS, exist_ok=True)
IMG.alpha_mode = 'NONE'   # aperçu : l'alpha (brillance) ne doit pas rendre le drap transparent dans Workbench
for c in CUIRASSES:
    c.hide_render = False
L.apercu([TAB], APERCUS, cible_godot=(0, 1.05, 0), taille=1.25, prefixe="seul_")
for k, c in enumerate(CUIRASSES):
    L.apercu([TAB, c], APERCUS, cible_godot=(0, 1.05, 0), taille=1.25, prefixe=("fer_", "acier_")[k])
print("FINI", os.path.join(LIVREES, IDENT + ".glb"))
