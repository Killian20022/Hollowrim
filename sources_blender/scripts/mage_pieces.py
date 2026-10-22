"""Pièces modelées du Mage nordique (passe Blender, branche persos_blender/mage) :
  - PLASTRON en écailles en relief (+ perles), posé sur le devant du torse réel (tunique exportée par outils/exporter_torse_mage.gd) ;
  - FRANGE EFFILOCHÉE de la pèlerine (dents en lambeaux, deux couches) le long du bord bas réel de la mante.
Chaque pièce existe en deux versions : DÉTAILLÉE (bevel, nervure, fils) et LÉGÈRE (3 à 5 triangles par écaille / dent). Le relief du
détaillé est CUIT (Cycles : AO + pointiness) vers les UV du léger, ramené à 128 texels/m et QUANTIFIÉ en indices de ton (0-6) :
sources_blender/mage_bake_plastron.png / mage_bake_frange.png (niveaux de gris = indice de ton, alpha = couverture) ; le Godot
(MageTextures) les colorie avec ses palettes. Export : assets/persos/mage/blender/mage_pieces.glb (léger seulement, repère Godot).
  blender -b --python mage_pieces.py -- <dossier sources_blender> <dossier assets/persos/mage/blender>
Repère : tout est construit en repère GODOT (x, y haut, z devant) puis converti (x, -z, y) pour Blender ; l'export glTF (+Y haut)
le ramène tel quel.
"""
import bpy, bmesh, sys, math, os, json, random
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

_a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = _a[:2]
BAKE = _a[2] if len(_a) > 2 else SRC
os.makedirs(BAKE, exist_ok=True)
os.makedirs(OUT, exist_ok=True)
rnd = random.Random(20261022)

# ------------------------------------------------------------------ gabarits de texture (texels, 128 / m environ)
SS = 4                                   # sur-échantillonnage du cuit
CELL_P = (9, 10)                         # case d'une écaille
GRID_P = (15, 6)                         # 90 cases
REG_P = (CELL_P[0] * GRID_P[0], CELL_P[1] * GRID_P[1])        # 135 x 60
CELL_F = (10, 14)
GRID_F = (6, 4)
REG_F = (CELL_F[0] * GRID_F[0], CELL_F[1] * GRID_F[1])        # 60 x 56

def b(p):                                 # repère Godot -> Blender
    return (p[0], -p[2], p[1])

# ------------------------------------------------------------------ surfaces réelles
def lire_obj(nom):
    v, f = [], []
    for l in open(os.path.join(SRC, nom)):
        t = l.split()
        if not t:
            continue
        if t[0] == "v":
            v.append(Vector((float(t[1]), float(t[2]), float(t[3]))))
        elif t[0] == "f":
            f.append(tuple(int(q) - 1 for q in t[1:4]))
    return v, f

TV, TF = lire_obj("mage_tunique.obj")
bvh_t = BVHTree.FromPolygons([tuple(v) for v in TV], TF)
MV, MF = lire_obj("mage_mante.obj")

def surface(x, y):
    """Point et normale du devant de la tunique en (x, y) (rayon de devant vers l'arrière)."""
    h = bvh_t.ray_cast(Vector((x, y, 0.8)), Vector((0, 0, -1)), 2.0)
    if h[0] is None:
        return None
    n = h[1].normalized()
    if n.z < 0:
        n = -n
    return h[0], n

def surface_lisse(x, y, e=0.03):
    """Normale moyennée sur un voisinage (les écailles suivent le galbe, pas le bruit du maillage)."""
    p = surface(x, y)
    if p is None:
        return None
    n = Vector((0, 0, 0))
    z = 0.0
    k = 0
    for dx in (-e, 0, e):
        for dy in (-e, 0, e):
            q = surface(x + dx, y + dy)
            if q:
                n += q[1]
                z += q[0].z
                k += 1
    n.normalize()
    return Vector((x, y, z / k)), n

# ------------------------------------------------------------------ plastron : écailles
W_E, H_E = 0.056, 0.066
PAS_X, PAS_Y = 0.052, 0.033
Y_HAUT, Y_BAS = 1.435, 1.045
X_MAX = 0.165
ECART_PEAU = 0.008          # centre de l'écaille au-dessus de la tunique (épaisseur de la cotte)
TILT = math.radians(15.0)

def contour_ecaille():
    w, h = W_E, H_E
    return [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, -0.52 * h), (w * 0.26, -0.86 * h), (0.0, -h), (-w * 0.26, -0.86 * h), (-w / 2, -0.52 * h)]

def tri_fan_ecaille():
    # polygone convexe à 7 points : éventail depuis le coin 0 -> 5 triangles ; on garde 5 points (3 triangles) pour le léger
    return [(-W_E / 2, 0.0), (W_E / 2, 0.0), (W_E / 2, -0.55 * H_E), (0.0, -H_E), (-W_E / 2, -0.55 * H_E)]

def ecailles():
    """Liste de dicts {c: centre haut, n, u, v}: repère local de chaque écaille."""
    res = []
    r = 0
    y = Y_HAUT
    while y > Y_BAS - 1e-6:
        dec = 0.5 * PAS_X if r % 2 else 0.0
        xs = []
        x = dec
        while x <= X_MAX:
            xs.append(x)
            x += PAS_X
        xs = sorted(set([-q for q in xs] + xs))
        for x in xs:
            # sur les flancs : le centre de l'écaille se prend sur la surface, sa normale suit le galbe
            s = surface_lisse(x, y - H_E * 0.5)
            if s is None:
                continue
            p, n = s
            if n.z < 0.30:
                continue
            u = Vector((0, 1, 0)).cross(n).normalized()          # vers la droite du perso (x+)
            v = n.cross(u).normalized()                          # vers le haut
            # haut de l'écaille = point de la surface un demi-pas au-dessus
            c = p + v * (H_E * 0.5) + n * ECART_PEAU
            res.append({"c": c, "n": n, "u": u, "v": v, "r": r, "x": x})
        r += 1
        y -= PAS_Y
    return res

def repere_ecaille(e):
    """Matrice locale -> monde avec bascule (le bas sort de TILT)."""
    n, u, v, c = e["n"], e["u"], e["v"], e["c"]
    rot = Matrix.Rotation(-TILT, 3, u)
    # bascule autour du haut de l'écaille : le bas s'écarte de la peau
    n2, v2 = rot @ n, rot @ v
    return c, u, v2, n2

def cases(n, grille, cell, reg):
    """UV (Blender, v haut) des 4 coins de la case k : [texel0..]; retourne fonction texel local -> uv."""
    out = []
    for k in range(n):
        cx, cy = k % grille[0], k // grille[0]
        out.append((cx * cell[0], cy * cell[1]))
    return out

def uv_de(reg, tx, ty):
    return (tx / reg[0], 1.0 - ty / reg[1])

# ------------------------------------------------------------------ construction bmesh
def objet(nom, bm):
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob

def sommet(bm, p):
    return bm.verts.new(b(p))

def ecaille_legere(bm, uvl, e, k, cases_px):
    c, u, v, n = repere_ecaille(e)
    pts = tri_fan_ecaille()
    vs = []
    for (a, bb) in pts:
        p = c + u * a + v * bb + n * 0.0
        vs.append(sommet(bm, p))
    # UV : (a, bb) -> case k ; marge 0,5 texel
    ox, oy = cases_px[k]
    uvs = []
    for (a, bb) in pts:
        tx = ox + 0.5 + (a + W_E / 2) / W_E * (CELL_P[0] - 1.0)
        ty = oy + 0.5 + (-bb) / H_E * (CELL_P[1] - 1.0)
        uvs.append(uv_de(REG_P, tx, ty))
    # éventail depuis le point 0 : trois triangles, normales vers l'extérieur
    for i in (1, 2, 3):
        tri = (vs[0], vs[i], vs[i + 1])
        idx = (0, i, i + 1)
        try:
            f = bm.faces.new(tri)
        except ValueError:
            continue
        # orientation : normale du triangle ~ n (repère Godot -> blender)
        nb = Vector(b(n))
        if f.normal.dot(nb) < 0:
            f.normal_flip()
            order = [l.vert for l in f.loops]
        for l in f.loops:
            j = [id(x) for x in vs].index(id(l.vert)) if False else vs.index(l.vert)
            l[uvl].uv = uvs[j]

def ecaille_detaillee(bm, e):
    """Plaque bombée : contour à 7 points, centre relevé (nervure), épaisseur et bords adoucis (bevel + subdiv appliqués après)."""
    c, u, v, n = repere_ecaille(e)
    cont = tri_fan_ecaille()
    ring = [sommet(bm, c + u * a + v * bb) for (a, bb) in cont]
    cen = sommet(bm, c + u * 0 + v * (-0.45 * H_E) + n * 0.0035)
    for i in range(len(ring)):
        try:
            bm.faces.new((ring[i], ring[(i + 1) % len(ring)], cen))
        except ValueError:
            pass
    return

def finir_detail(ob):
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    m = ob.modifiers.new("sol", "SOLIDIFY")
    m.thickness = 0.0035
    m.offset = -1.0
    m2 = ob.modifiers.new("bev", "BEVEL")
    m2.width = 0.0010
    m2.segments = 2
    m2.limit_method = "ANGLE"
    m3 = ob.modifiers.new("sub", "SUBSURF")
    m3.levels = 1
    m3.render_levels = 1
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    ob.modifiers.clear()
    ob.data = me

def perles(bm_low, bm_high, ecs, uvl):
    """Chaîne de perles le long de l'axe (au bas de chaque rangée) + collier au col. Pyramide à 4 faces (légère), sphère (détaillée)."""
    pts = []
    for r in range(0, 12):
        y = Y_HAUT - r * PAS_Y - H_E * 0.80 + 0.012
        s = surface_lisse(0.0, y)
        if s:
            p, n = s
            pts.append((p + n * (ECART_PEAU + 0.012), n, 0.0105))
    # collier : arc au haut du plastron
    for i in range(-4, 5):
        x = i * 0.034
        y = Y_HAUT - 0.012 + 0.012 * (x / 0.136) ** 2 + 0.02
        s = surface_lisse(x, y)
        if s:
            p, n = s
            pts.append((p + n * (ECART_PEAU + 0.014), n, 0.0085))
    return pts

# ------------------------------------------------------------------ exécution plastron
def plastron():
    ecs = ecailles()
    print("ecailles:", len(ecs))
    assert len(ecs) <= GRID_P[0] * GRID_P[1], "trop d'écailles pour la région"
    cpx = cases(len(ecs), GRID_P, CELL_P, REG_P)
    bml = bmesh.new()
    uvl = bml.loops.layers.uv.new("UVMap")
    for k, e in enumerate(ecs):
        ecaille_legere(bml, uvl, e, k, cpx)
    low = objet("plastron_low", bml)
    # détaillé
    bmh = bmesh.new()
    for e in ecs:
        # une plaque par écaille : on la finit séparément pour que le solidify/bevel ne fusionne rien
        ecaille_detaillee(bmh, e)
    high = objet("plastron_high", bmh)
    finir_detail(high)
    return low, high, ecs

# ------------------------------------------------------------------ perles (objets séparés)
def perles_objets(pts):
    bml = bmesh.new()
    uvl = bml.loops.layers.uv.new("UVMap")
    for (c, n, r) in pts:
        cb = Vector(b(c))
        nb = Vector(b(n))
        u = nb.cross(Vector((0, 0, 1)))
        if u.length < 1e-3:
            u = Vector((1, 0, 0))
        u.normalize()
        v = nb.cross(u).normalized()
        apex = bml.verts.new(cb + nb * r * 0.9)
        base = [bml.verts.new(cb + u * math.cos(a) * r + v * math.sin(a) * r - nb * r * 0.1) for a in (0, math.pi / 2, math.pi, 3 * math.pi / 2)]
        for i in range(4):
            f = bml.faces.new((base[i], base[(i + 1) % 4], apex))
            if f.normal.dot(nb) < 0:
                f.normal_flip()
            for l in f.loops:
                l[uvl].uv = uv_de(PEARL_REG, 1.5, 1.5)
    return objet("perles", bml)

PEARL_REG = (3, 3)

# ------------------------------------------------------------------ frange : dents
def bord_bas_mante():
    """Arêtes libres BAS de la mante (y 1,10 - 1,47, hors ouverture du devant) : liste (milieu, direction, longueur, extérieur)."""
    aretes = {}
    for f in MF:
        ct = (MV[f[0]] + MV[f[1]] + MV[f[2]]) / 3.0
        for k in range(3):
            i0, i1 = f[k], f[(k + 1) % 3]
            cle = tuple(sorted((tuple(round(c, 3) for c in MV[i0]), tuple(round(c, 3) for c in MV[i1]))))
            d = aretes.setdefault(cle, [0, i0, i1, ct])
            d[0] += 1
    res = []
    for cle, (cnt, i0, i1, ct) in aretes.items():
        if cnt != 1:
            continue
        p0, p1 = MV[i0], MV[i1]
        m = (p0 + p1) / 2
        if m.y < 1.10 or m.y > 1.47 or ct.y < m.y + 0.004 or (m.z > 0.03 and abs(m.x) < 0.10):
            continue
        cote = p1 - p0
        lc = cote.length
        if lc < 0.004:
            continue
        res.append((m, cote / lc, lc))
    return res

def dents():
    bord = bord_bas_mante()
    print("aretes bord bas:", len(bord))
    # on trie par angle autour de l'axe et on fusionne les arêtes voisines (< 4 cm) pour limiter le nombre de dents
    bord.sort(key=lambda t: math.atan2(t[0].x, t[0].z + 0.02))
    dents = []
    dernier = None
    for m, cote, lc in bord:
        if dernier is not None and (m - dernier).length < 0.062:
            continue
        dents.append((m, cote, lc))
        dernier = m
    return dents

# variantes de dents (polygone dans le repère (a, b) de [-0.5, 0.5] x [0, -1] à l'échelle w x lg) et nombre de triangles
VARIANTES = [
    [(-0.5, 0), (0.5, 0), (0.42, -0.55), (0.05, -1.0), (-0.42, -0.62)],                                  # pointe simple
    [(-0.5, 0), (0.5, 0), (0.45, -0.70), (0.18, -1.0), (0.0, -0.58), (-0.22, -0.92), (-0.45, -0.66)],    # fourchue
    [(-0.5, 0), (0.5, 0), (0.38, -0.50), (-0.05, -0.95), (-0.40, -0.72)],                               # biaisée
    [(-0.5, 0), (0.5, 0), (0.48, -0.62), (0.28, -0.80), (0.0, -1.0), (-0.40, -0.70)],                    # tronquée
]

def dent_poly(var):
    return VARIANTES[var % len(VARIANTES)]

def frange():
    ds = dents()
    bml = bmesh.new()
    uvl = bml.loops.layers.uv.new("UVMap")
    nb_cases = GRID_F[0] * GRID_F[1]
    ncouches = 2
    infos = []
    for i, (m, cote, lc) in enumerate(ds):
        ext = Vector((m.x, 0.0, m.z + 0.02)).normalized()
        for couche in range(ncouches):
            if couche == 1 and i % 2:
                continue
            var = rnd.randrange(len(VARIANTES))
            w = max(lc * 1.5, 0.045) * (1.0 if couche == 0 else 0.85)
            lg = rnd.uniform(0.09, 0.15) if couche == 0 else rnd.uniform(0.06, 0.10)
            dirv = (Vector((0, -1, 0)) + ext * (0.20 if couche == 0 else 0.06)).normalized()
            dec = (0.0 if couche == 0 else 0.5 * w)
            c = m + cote * dec - dirv * 0.03 + ext * (0.004 if couche == 0 else 0.010)
            # profondeur : la couche arrière (0) légèrement plus proche du corps
            poly = dent_poly(var)
            k = var + GRID_F[0] * rnd.randrange(GRID_F[1])
            ox, oy = (k % GRID_F[0]) * CELL_F[0], (k // GRID_F[0]) * CELL_F[1]
            vs, uvs = [], []
            for (a, bb) in poly:
                p = c + cote * (a * w) + dirv * (-bb * lg)
                p = p + ext * (0.006 * math.sin(a * 5.0 + i))        # léger gauchissement : le tissu n'est pas plat
                vs.append(sommet(bml, p))
                tx = ox + 0.5 + (a + 0.5) * (CELL_F[0] - 1.0)
                ty = oy + 0.5 + (-bb) * (CELL_F[1] - 1.0)
                uvs.append(uv_de(REG_F, tx, ty))
            for j in range(1, len(poly) - 1):
                try:
                    f = bml.faces.new((vs[0], vs[j], vs[j + 1]))
                except ValueError:
                    continue
                if f.normal.dot(Vector(b(ext))) < 0:
                    f.normal_flip()
                for l in f.loops:
                    l[uvl].uv = uvs[vs.index(l.vert)]
            infos.append((var, k, couche))
    print("dents:", len(ds), "triangles frange:", len(bml.faces))
    return objet("frange_low", bml)

# ------------------------------------------------------------------ banc de cuisson de la frange (détaillé)
def banc_frange():
    """Une dent par case (variante x tirage) posée à plat à y=2 : légère (polygone) et détaillée (subdivisée, plis verticaux de tissu,
    bord qui s'enroule, fils irréguliers, épaisseur)."""
    low = bmesh.new()
    uvl = low.loops.layers.uv.new("UVMap")
    high = bmesh.new()
    W, L = 0.056, 0.12
    for k in range(GRID_F[0] * GRID_F[1]):
        col, row = k % GRID_F[0], k // GRID_F[0]
        var = col % len(VARIANTES)
        ox, oy = col * CELL_F[0], row * CELL_F[1]
        poly = dent_poly(var)
        base = Vector((k * 0.15, 2.0, 0.0))
        pts = [Vector((base.x + a * W, base.y + bb * L, 0.0)) for (a, bb) in poly]
        vs, uvs = [], []
        for (a, bb), p in zip(poly, pts):
            vs.append(low.verts.new(b(p)))
            tx = ox + 0.5 + (a + 0.5) * (CELL_F[0] - 1.0)
            ty = oy + 0.5 + (-bb) * (CELL_F[1] - 1.0)
            uvs.append(uv_de(REG_F, tx, ty))
        for j in range(1, len(poly) - 1):
            f = low.faces.new((vs[0], vs[j], vs[j + 1]))
            if f.normal.dot(Vector((0, -1, 0))) > 0:
                f.normal_flip()
            for l in f.loops:
                l[uvl].uv = uvs[vs.index(l.vert)]
        # détaillé
        hv = [high.verts.new(b(p)) for p in pts]
        fh = high.faces.new(hv)
        if fh.normal.dot(Vector((0, -1, 0))) > 0:
            fh.normal_flip()
        geo = bmesh.ops.triangulate(high, faces=[fh])
        for _ in range(3):
            bmesh.ops.subdivide_edges(high, edges=[e for e in high.edges if e.calc_length() > 0.007 and all(abs(v.co.x - base.x) < 0.075 and abs(v.co.z - base.y) < 0.2 for v in e.verts)], cuts=1, use_grid_fill=True)
        r2 = random.Random(100 + k)
        ph = r2.uniform(0, 6.28)
        for v in high.verts:
            if abs(v.co.x - base.x) > 0.075 or abs(v.co.z - (base.y - L / 2)) > 0.1:
                continue
            x = (v.co.x - base.x) / W
            y = (base.y - v.co.z) / L
            if not (-0.55 < x < 0.55 and -0.05 < y < 1.05):
                continue
            pli = 0.0030 * math.sin(x * 34.0 + ph) + 0.0016 * math.sin(x * 71.0 + 2.0 * ph + y * 6.0)
            enroule = 0.0035 * min(1.0, max(0.0, (abs(x) - 0.30) / 0.2))
            fil = 0.0025 * math.sin(y * 18.0 + x * 9.0)
            v.co.y -= (pli + fil) * (0.4 + y) - enroule     # (Blender : -y = devant)
    return low, high

# ------------------------------------------------------------------ cuisson
def cuire(low, high, reg, nom, ss=SS, ray=0.03, cage=0.012):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = False
    rb = sc.render.bake
    rb.use_selected_to_active = True
    rb.cage_extrusion = cage
    rb.max_ray_distance = ray
    rb.margin = 2
    rb.use_clear = True
    W, H = reg[0] * ss, reg[1] * ss
    res = {}
    for typ, mat_h in (("AO", None), ("EMIT", "point")):
        img = bpy.data.images.new("%s_%s" % (nom, typ), W, H, alpha=False)
        img.colorspace_settings.name = "Non-Color"
        # matériau du léger : une image active
        mat = bpy.data.materials.new("m_" + nom + typ)
        mat.use_nodes = True
        nt = mat.node_tree
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = img
        nt.nodes.active = tn
        low.data.materials.clear()
        low.data.materials.append(mat)
        if mat_h == "point":
            mh = bpy.data.materials.new("mh_" + nom)
            mh.use_nodes = True
            nh = mh.node_tree
            for n in list(nh.nodes):
                nh.nodes.remove(n)
            g = nh.nodes.new("ShaderNodeNewGeometry")
            cr = nh.nodes.new("ShaderNodeValToRGB")
            cr.color_ramp.elements[0].position = 0.35
            cr.color_ramp.elements[1].position = 0.65
            em = nh.nodes.new("ShaderNodeEmission")
            out = nh.nodes.new("ShaderNodeOutputMaterial")
            nh.links.new(g.outputs["Pointiness"], cr.inputs[0])
            nh.links.new(cr.outputs[0], em.inputs["Color"])
            nh.links.new(em.outputs[0], out.inputs["Surface"])
            high.data.materials.clear()
            high.data.materials.append(mh)
        bpy.ops.object.select_all(action="DESELECT")
        high.select_set(True)
        low.select_set(True)
        bpy.context.view_layer.objects.active = low
        bpy.ops.object.bake(type=typ)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1, :, 0]     # lignes du haut en premier
        res[typ] = px
    return res

def reduire(a, ss):
    H, W = a.shape
    return a.reshape(H // ss, ss, W // ss, ss).mean(axis=(1, 3))

def hash2(x, y, g):
    n = (x * 374761393 + y * 668265263 + g * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0

def masque_poly(reg, cell, grille, polys_cell, ss=1):
    """Couverture 0/1 : polygone de chaque case rasterisé au texel."""
    W, H = reg
    m = np.zeros((H, W), dtype=np.float32)
    for k, poly in enumerate(polys_cell):
        ox, oy = (k % grille[0]) * cell[0], (k // grille[0]) * cell[1]
        for ty in range(cell[1]):
            for tx in range(cell[0]):
                if in_poly((tx + 0.5 - 0.5, ty + 0.5 - 0.5), poly):
                    m[oy + ty, ox + tx] = 1.0
    return m

def in_poly(pt, poly):
    x, y = pt
    ins = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
            ins = not ins
        j = i
    return ins

def sauver_png(chemin, tons, alpha):
    h, w = tons.shape
    img = bpy.data.images.new("out_" + os.path.basename(chemin), w, h, alpha=True)
    arr = np.zeros((h, w, 4), dtype=np.float32)
    t = tons.astype(np.float32) / 6.0
    arr[..., 0] = arr[..., 1] = arr[..., 2] = t
    arr[..., 3] = alpha
    img.pixels = arr[::-1].reshape(-1).tolist()
    img.filepath_raw = chemin
    img.file_format = "PNG"
    img.save()

PAL = ["#0a0f16", "#141d29", "#1f2c3d", "#2d3f55", "#41597a", "#5f7fa5", "#8fb3d3"]

def apercu(chemin, tons, alpha, fois=6):
    pal = [tuple(int(p[i:i + 2], 16) / 255.0 for i in (1, 3, 5)) for p in PAL]
    h, w = tons.shape
    arr = np.zeros((h, w, 4), dtype=np.float32)
    for t in range(7):
        arr[tons == t, :3] = pal[t]
    arr[..., 3] = 1.0
    arr[alpha < 0.5, :3] = 0.0
    arr = np.repeat(np.repeat(arr, fois, axis=0), fois, axis=1)
    img = bpy.data.images.new("ap_" + os.path.basename(chemin), arr.shape[1], arr.shape[0], alpha=True)
    img.pixels = arr[::-1].reshape(-1).tolist()
    img.filepath_raw = chemin
    img.file_format = "PNG"
    img.save()

def quantifier(ao, pt, masque, graine, base=2.4, ampl=2.6, bord=True):
    """AO (1 = ouvert) et pointiness (0,5 = plat) à 128 texels/m -> indice de ton 0..6 (seuil bruité, jamais de damier).
    L'AO est normalisé sur ses percentiles (le bake dépend de la place de l'écaille) ; arête sombre sous la bordure basse,
    arête claire sur les bords gauches/hauts (lumière du ciel), la pointiness éclaire les arêtes vives."""
    h, w = ao.shape
    m = masque > 0.5
    v = ao[m]
    p10, p90 = np.percentile(v, 10), np.percentile(v, 90)
    a = np.clip((ao - p10) / max(p90 - p10, 1e-3), 0.0, 1.0)
    tons = np.zeros((h, w), dtype=np.int32)
    for y in range(h):
        for x in range(w):
            if not m[y, x]:
                continue
            l = base + (a[y, x] - 0.5) * 1.6 + (pt[y, x] - 0.35) * 5.0
            l += (hash2(x, y, graine) - 0.5) * 0.8
            tons[y, x] = int(min(6, max(0, round(l))))
    if bord:
        out = tons.copy()
        for y in range(h):
            for x in range(w):
                if not m[y, x]:
                    continue
                bas = y + 1 >= h or not m[y + 1, x]
                gauche = x == 0 or not m[y, x - 1]
                droite = x + 1 >= w or not m[y, x + 1]
                if bas:
                    out[y, x] = 0
                elif gauche:
                    out[y, x] = min(6, tons[y, x] + 2)
                elif droite:
                    out[y, x] = max(0, tons[y, x] - 1)
        # arête claire juste au-dessus de l'arête sombre du bas (reflet sur le tranchant)
        for y in range(h - 1):
            for x in range(w):
                if m[y, x] and m[y + 1, x] and (y + 2 >= h or not m[y + 2, x]):
                    out[y, x] = min(6, max(out[y, x], 4) + 1)
        tons = out
    return tons

# ------------------------------------------------------------------ main
def main():
    low_p, high_p, ecs = plastron()
    # perles
    pts = perles_objets(perles(None, None, ecs, None) if False else perles(None, None, ecs, None))
    bpy.context.scene.unit_settings.system = "METRIC"
    # cuisson du plastron
    res = cuire(low_p, high_p, REG_P, "plastron")
    ao = reduire(res["AO"], SS)
    pt = reduire(res["EMIT"], SS)
    print("AO plastron: min %.2f moy %.2f max %.2f | pt: min %.2f moy %.2f max %.2f" % (ao.min(), ao.mean(), ao.max(), pt.min(), pt.mean(), pt.max()))
    cont = tri_fan_ecaille()
    polys = []
    for k in range(len(ecs)):
        polys.append([((a + W_E / 2) / W_E * (CELL_P[0] - 1.0) + 0.5, (-bb) / H_E * (CELL_P[1] - 1.0) + 0.5) for (a, bb) in cont])
    masque = masque_poly(REG_P, CELL_P, GRID_P, polys)
    tons = quantifier(ao, pt, masque, 11)
    sauver_png(os.path.join(BAKE, "bake_plastron.png"), tons, masque)
    apercu(os.path.join(SRC, "apercu_plastron.png"), tons, masque)
    # frange : cuisson sur le banc
    lowb, highb = banc_frange()
    lo = objet("banc_low", lowb)
    hi = objet("banc_high", highb)
    for o in (hi,):
        bpy.context.view_layer.objects.active = o
        m = o.modifiers.new("sol", "SOLIDIFY")
        m.thickness = 0.0025
        m.offset = 1.0
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        o.modifiers.clear()
        o.data = me
    resf = cuire(lo, hi, REG_F, "frange", ray=0.02, cage=0.006)
    aof, ptf = reduire(resf["AO"], SS), reduire(resf["EMIT"], SS)
    polysf = []
    for k in range(GRID_F[0] * GRID_F[1]):
        polysf.append([((a + 0.5) * (CELL_F[0] - 1.0) + 0.5, (-bb) * (CELL_F[1] - 1.0) + 0.5) for (a, bb) in dent_poly(k % GRID_F[0])])
    mf = masque_poly(REG_F, CELL_F, GRID_F, polysf)
    tf = quantifier(aof, ptf, mf, 37, base=2.2, bord=False)
    sauver_png(os.path.join(BAKE, "bake_frange.png"), tf, mf)
    apercu(os.path.join(SRC, "apercu_frange.png"), tf, mf)
    fr = frange()
    # export glb (léger seulement)
    bpy.ops.object.select_all(action="DESELECT")
    for o in (low_p, pts, fr):
        o.select_set(True)
    low_p.data.materials.clear()
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "mage_pieces.glb"), use_selection=True, export_format="GLB", export_yup=True, export_apply=False, export_materials="NONE" if False else "EXPORT")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, "mage_pieces.blend"))
    print("TRIS plastron", len(low_p.data.polygons), "perles", len(pts.data.polygons), "frange", len(fr.data.polygons))

main()
