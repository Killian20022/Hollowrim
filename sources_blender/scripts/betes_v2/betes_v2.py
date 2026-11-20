# BÊTES V2 (art/animaux_v2, 2026-11-20) : passe « fourrure et détail » sur les animaux Quaternius du jeu.
#   blender.exe -b --python betes_v2.py -- espece=loup [config=<betes_v2.json>] [depot=<racine du worktree>]
# Base : le glb DU JEU (assets/modeles/persos_quat/<source>.glb : squelette, pondération, clips Idle/Walk/Run/Attack/Death/Hit/Eat/
# Idle_2/Jump). Le squelette et les animations sont gardés AU BIT PRÈS : le glb d'origine est recopié et SEUL son maillage est
# remplacé (nouveaux accessors), plus un second maillage « <nom>_loin » (LOD lointain) sur la même peau. Rien ne passe par
# l'exporteur glTF de Blender (pas de réorientation d'os : MortAraignee lit l'axe Y des os).
# Étapes :
#   1. maillage d'origine -> subdivision (Catmull-Clark 1) -> décimation (collapse) au budget « corps » : silhouette arrondie,
#      moins « jouet », facettes plates gardées au-delà de 50° ; léger gonflement qui compense le rétrécissement de la subdivision ;
#   2. couleurs : celles du modèle (marques Quaternius retouchées par pq_convertir) LISSÉES (fini les taches par face), yeux / truffe /
#      sabots gardés nets ;
#   3. dépliage UV (smart project) + TEXTURE PEINTE de poils (numpy) : mèches (basse fréquence) et poils (haute fréquence) étirés
#      dans le SENS DU POIL (vers la queue, vers le bas sur les pattes et les flancs, le long de la queue), BRUIT de valeur seulement
#      (jamais de tramage ordonné), puis accroche à la palette de la bible (oklab) ;
#   4. FOURRURE GÉOMÉTRIQUE : touffes / mèches fermées (pyramides à 3 pans, 1 ou 2 segments, courbées par la pesanteur) semées
#      par zone d'os (collerette du cou, poitrail, dos, queue touffue, joues, frange du ventre…), chacune rigide sur la pondération
#      de sa racine, couleur de la texture à sa racine, ombrée de la racine (sombre) à la pointe ; opaques (pas d'alpha, pas de discard) ;
#   5. LOD : le corps décimé (~1/3) sans touffes, même texture ;
#   6. sortie : assets/modeles/persos_quat/<id>.glb + <id>.png (+ .png.import sans perte) ; rapport JSON (tris).
import bpy, bmesh, sys, os, json, math, struct, re, colorsys
import numpy as np

ICI = os.path.dirname(os.path.abspath(__file__))
A = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:])
DEPOT = A.get("depot", os.path.normpath(os.path.join(ICI, "..", "..", "..")))
CFG_ALL = json.load(open(A.get("config", os.path.join(ICI, "betes_v2.json")), encoding="utf8"))
ESP = A["espece"]
CFG = dict(CFG_ALL["defaut"])
CFG.update(CFG_ALL["especes"][ESP])
for k in ("zones",):
    z = dict(CFG_ALL["defaut"].get(k, {}))
    z.update(CFG_ALL["especes"][ESP].get(k, {}))
    CFG[k] = z
SRC = os.path.join(DEPOT, "assets", "modeles", "persos_quat", CFG["source"] + ".glb")
ID = CFG["id"]
SORTIE = os.path.join(DEPOT, "assets", "modeles", "persos_quat")
RNG = np.random.default_rng(int(CFG.get("graine", 7)))


# ------------------------------------------------------------------ palette de la bible (pq_convertir.PALETTE)
def H(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


PALETTE = np.array([H(c) for c in (
    "#4a557f #6877a3 #8898bf #aab8d6 #cdd7ec #f0eff4 #33577f #4f86ae #86bfd3 #cfeef0 #08161a #10272a #1a3d32 #2c5a41 #5b866f #6e9172 "
    "#241a22 #3a2a2a #54402f #735b43 #947c5e #3b1f24 #6a3524 #9c5129 #cf7b3c #ecaa62 #3d3c4a #5b5a66 #7f7d82 #a7a19b #262a3b #3a4057 "
    "#565b72 #787d8e #a0a2ab #2b1a1e #472a21 #6a4229 #92613a #bb8a53 #211e1c #3b3322 #5c4e2d #82723f #b39d5d #1f1418 #3a261b #5b3d27 "
    "#86603a #1b2a52 #2a4382 #4468ac #7b9ad0 #351520 #5c1f2b #8a2f35 #b9504a #8e8688 #b9ae9f #dbd0b6 #efe7d0 #25262f #3d3e4a #5c5d68 "
    "#85848c #b3b0b4 #20252f #3a4256 #5b6680 #8a96ae #bcc6d8 #4a3419 #7b5a26 #a98638 #d3b25c #5a1a1c #b3341f #ec6a1f #fcb53a #fff0a8 "
    "#0c4a5e #14899b #3fd0d0 #b6fbf0 #030303 #090808 #0f0b08 #14161a").split()])


def lin(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, 12.92 * c, 1.055 * c ** (1 / 2.4) - 0.055)


def oklab(c):
    r, g, b = (lin(c)[..., i] for i in range(3))
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (np.cbrt(np.maximum(v, 0)) for v in (l, m, s))
    return np.stack([0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s], -1)


PAL_LAB = oklab(PALETTE)


def oklab_inv(lab):
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return srgb(np.stack([r, g, bb], -1))


def quantifier(c, pas_l, pas_c, sat, froid):
    """Paliers nets de luminance (oklab L) en gardant la teinte du modèle ; chroma réduite (virage nordique) et poussée froide."""
    lab = oklab(c)
    lab[..., 0] = np.round(lab[..., 0] / pas_l) * pas_l
    lab[..., 1:] = lab[..., 1:] * sat
    lab[..., 2] -= froid
    lab[..., 1:] = np.round(lab[..., 1:] / pas_c) * pas_c
    return np.clip(oklab_inv(lab), 0, 1)


def accrocher(c):
    """c : (n, 3) sRGB -> couleur de palette la plus proche (oklab, luminance pondérée 1,4 comme pq_convertir)."""
    lab = oklab(c)
    d = 1.4 * (lab[:, None, 0] - PAL_LAB[None, :, 0]) ** 2 + (lab[:, None, 1] - PAL_LAB[None, :, 1]) ** 2 \
        + (lab[:, None, 2] - PAL_LAB[None, :, 2]) ** 2
    return PALETTE[np.argmin(d, axis=1)]


# ------------------------------------------------------------------ bruit de valeur 3D (aucun tramage ordonné)
def _hash(ix, iy, iz, graine):
    h = (ix.astype(np.int64) * 73856093) ^ (iy.astype(np.int64) * 19349663) ^ (iz.astype(np.int64) * 83492791) ^ (graine * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF).astype(np.float64) / float(0xFFFFFF)


def bruit(q, graine=1):
    """q : (n, 3) -> valeur dans [0, 1], interpolation lissée (smoothstep) entre les noeuds d'un réseau aléatoire."""
    f = np.floor(q)
    t = q - f
    t = t * t * (3 - 2 * t)
    i = f.astype(np.int64)
    r = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (t[:, 0] if dx else 1 - t[:, 0]) * (t[:, 1] if dy else 1 - t[:, 1]) * (t[:, 2] if dz else 1 - t[:, 2])
                r = r + w * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, graine)
    return r


def norm(v):
    n = np.linalg.norm(v, axis=-1, keepdims=True)
    return v / np.maximum(n, 1e-9)


# ------------------------------------------------------------------ glb d'origine (JSON + BIN)
def lire_glb(chemin):
    b = open(chemin, "rb").read()
    l0 = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + l0])
    o = 20 + l0
    l1 = struct.unpack("<I", b[o:o + 4])[0]
    return j, bytearray(b[o + 8:o + 8 + l1])


def ecrire_glb(chemin, j, binr):
    while len(binr) % 4:
        binr += b"\0"
    j["buffers"] = [{"byteLength": len(binr)}]
    js = json.dumps(j, separators=(",", ":")).encode("utf8")
    while len(js) % 4:
        js += b" "
    tot = 12 + 8 + len(js) + 8 + len(binr)
    with open(chemin, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, tot))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(binr), 0x004E4942))
        f.write(binr)


def ajouter_accessor(j, binr, arr, ctype, typ, normalise=False, cible=None, minmax=False):
    while len(binr) % 4:
        binr += b"\0"
    off = len(binr)
    data = np.ascontiguousarray(arr).tobytes()
    binr += data
    bv = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
    if cible:
        bv["target"] = cible
    j["bufferViews"].append(bv)
    acc = {"bufferView": len(j["bufferViews"]) - 1, "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
    if normalise:
        acc["normalized"] = True
    if minmax:
        acc["min"] = [float(x) for x in arr.min(axis=0)]
        acc["max"] = [float(x) for x in arr.max(axis=0)]
    j["accessors"].append(acc)
    return len(j["accessors"]) - 1


def lire_accessor(j, binr, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt = {5126: np.float32, 5123: np.uint16, 5121: np.uint8, 5125: np.uint32}[a["componentType"]]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0)
    if stride and stride != n * np.dtype(dt).itemsize:
        raw = np.frombuffer(bytes(binr[off:off + stride * a["count"]]), dtype=np.uint8).reshape(a["count"], stride)
        return raw[:, :n * np.dtype(dt).itemsize].copy().view(dt).reshape(a["count"], n)
    return np.frombuffer(bytes(binr[off:off + a["count"] * n * np.dtype(dt).itemsize]), dtype=dt).reshape(a["count"], n)


def quat_mat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def positions_os(j):
    """Positions globales (repos) des noeuds du glb (repère glTF)."""
    parent = {}
    for i, n in enumerate(j["nodes"]):
        for c in n.get("children", []):
            parent[c] = i
    cache = {}

    def m(i):
        if i in cache:
            return cache[i]
        n = j["nodes"][i]
        M = np.eye(4)
        M[:3, :3] = quat_mat(n.get("rotation", [0, 0, 0, 1])) @ np.diag(n.get("scale", [1, 1, 1]))
        M[:3, 3] = n.get("translation", [0, 0, 0])
        if i in parent:
            M = m(parent[i]) @ M
        cache[i] = M
        return M
    return {n.get("name", str(i)): m(i)[:3, 3] for i, n in enumerate(j["nodes"])}, parent


# ------------------------------------------------------------------ Blender : maillage retravaillé
def b2g(v):            # repère Blender (Z haut, -Y avant) -> glTF (Y haut, +Z avant)
    v = np.asarray(v)
    return np.stack([v[..., 0], v[..., 2], -v[..., 1]], -1)


def tris_de(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


def preparer_blender():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    for o in list(bpy.context.scene.objects):
        if o.type == 'MESH' and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
    corps = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
    for m in list(corps.modifiers):
        corps.modifiers.remove(m)
    corps.parent = None
    bpy.context.view_layer.objects.active = corps
    for o in bpy.context.scene.objects:
        o.select_set(o == corps)
    return corps


def couleurs_coins(o):
    """Couleur sRGB par COIN (les yeux, la truffe, les sabots sont des faces de leur couleur : bords francs gardés)."""
    me = o.data
    ca = me.color_attributes.get("Col") or me.color_attributes[0]
    if ca.domain == 'POINT':
        cv = np.array([d.color_srgb[:3] for d in ca.data])
        return cv[[l.vertex_index for l in me.loops]]
    return np.array([d.color_srgb[:3] for d in ca.data])


def poser_couleurs(o, c):
    me = o.data
    while me.color_attributes:
        me.color_attributes.remove(me.color_attributes[0])
    ca = me.color_attributes.new("Col", 'FLOAT_COLOR', 'CORNER')
    cl = lin(c)
    for i, d in enumerate(ca.data):
        d.color = (cl[i, 0], cl[i, 1], cl[i, 2], 1.0)


def lumi(c):
    return c @ np.array([0.3, 0.59, 0.11])


def remodeler(o):
    t0 = tris_de(o)
    c0 = couleurs_coins(o)
    print("DETAIL source: coins<seuil=%d / %d  lum min=%.3f p1=%.3f" % ((lumi(c0) < CFG.get("seuil_detail", 0.07)).sum(), len(c0), lumi(c0).min(), np.percentile(lumi(c0), 1)))
    poser_couleurs(o, c0)
    # le glb d'origine est NON SOUDÉ (ombrage plat : sommets dupliqués par face) : on soude avant de subdiviser
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.to_mesh(o.data)
    bm.free()                      # attribut flottant par sommet : interpolé proprement par la subdivision
    if CFG["subdiv"] > 0:
        m = o.modifiers.new("sub", 'SUBSURF')
        m.levels = m.render_levels = CFG["subdiv"]
        m.uv_smooth = 'PRESERVE_BOUNDARIES'
        bpy.ops.object.modifier_apply(modifier="sub")
    t1 = tris_de(o)
    # zones de détail (yeux, truffe, sabots, bois) : poids 0 = protégées de la décimation
    cc = couleurs_coins(o)
    det = lumi(cc) < CFG.get("seuil_detail", 0.07)
    vg = o.vertex_groups.new(name="_libre")
    me = o.data
    print("DETAIL apres subdiv: %d" % det.sum())
    proteges = {me.loops[i].vertex_index for i in np.nonzero(det)[0]}
    vg.add([v.index for v in me.vertices if v.index not in proteges], 1.0, 'REPLACE')
    cible = CFG["tris_corps"]
    if t1 > cible:
        m = o.modifiers.new("dec", 'DECIMATE')
        m.decimate_type = 'COLLAPSE'
        m.ratio = cible / t1
        m.use_collapse_triangulate = True
        m.vertex_group = "_libre"
        m.vertex_group_factor = 1.0
        bpy.ops.object.modifier_apply(modifier="dec")
    # gonflement (compense le rétrécissement de Catmull-Clark)
    g = CFG.get("gonfle", 0.0)
    if g:
        me = o.data
        for v in me.vertices:
            v.co += v.normal * g
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(CFG.get("angle_lisse", 50)))
    o.vertex_groups.remove(o.vertex_groups["_libre"])
    return t0, tris_de(o)


def deplier(o):
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.012, area_weight=0.0, scale_to_bounds=False)
    try:
        bpy.ops.uv.pack_islands(rotate=True, margin=0.008, shape_method='CONCAVE')
    except TypeError:
        bpy.ops.uv.pack_islands(rotate=True, margin=0.008)
    bpy.ops.object.mode_set(mode='OBJECT')


def extraire(o, os_noms):
    """Triangles du maillage : par coin (position, normale, uv, couleur, poids des os) dans le repère glTF."""
    me = o.data
    me.calc_loop_triangles()
    nv = len(me.vertices)
    P = b2g(np.array([v.co[:] for v in me.vertices]))
    gid = {g.index: g.name for g in o.vertex_groups}
    W = np.zeros((nv, len(os_noms)))
    idx = {n: i for i, n in enumerate(os_noms)}
    for v in me.vertices:
        for g in v.groups:
            nm = gid.get(g.group)
            if nm in idx and g.weight > 0:
                W[v.index, idx[nm]] = g.weight
    C = couleurs_coins(o) if me.color_attributes else np.ones((len(me.loops), 3))
    uvl = me.uv_layers.active
    tri_v, tri_l = [], []
    for t in me.loop_triangles:
        tri_v.append(list(t.vertices))
        tri_l.append(list(t.loops))
    tri_v = np.array(tri_v)
    tri_l = np.array(tri_l)
    cn = np.array([me.corner_normals[i].vector[:] for i in range(len(me.loops))])
    N = b2g(cn)
    UV = np.array([uvl.data[i].uv[:] for i in range(len(me.loops))]) if uvl else np.zeros((len(me.loops), 2))
    UV = np.stack([UV[:, 0], 1.0 - UV[:, 1]], -1)     # glTF : v vers le bas
    VN = b2g(np.array([v.normal[:] for v in me.vertices]))
    return dict(P=P, W=W, C=C, tri_v=tri_v, tri_l=tri_l, N=N, UV=UV, VN=VN)


# ------------------------------------------------------------------ classes d'os, sens du poil
CLASSES = [("oreille", r"^Ear"), ("tete", r"^Head"), ("cou", r"^Neck"), ("poitrail", r"^Torso[23]$"), ("queue", r"^Tail"),
           ("patte_basse", r"LowerLeg|Leg[23]\.|Foot|^FF|^IK"), ("patte_haute", r"Shoulder|UpperLeg|BackLeg\.|FrontLeg\.|MidBackLeg\.|MidFrontLeg\."),
           ("abdomen", r"^Abdomen"), ("tronc", r".")]


def classes_os(os_noms):
    M = np.zeros((len(os_noms), len(CLASSES)))
    for i, n in enumerate(os_noms):
        for k, (_, rx) in enumerate(CLASSES):
            if re.search(rx, n):
                M[i, k] = 1
                break
    return M


def sens_du_poil(P, N, K, Wos, os_noms, pos_os):
    """Direction du poil par point (tangente) : P, N (n,3), K (n, classes) poids de classe, Wos (n, os)."""
    ci = {c: i for i, (c, _) in enumerate(CLASSES)}
    arr = np.array([0, 0, -1.0])           # vers l'arrière (la queue)
    bas = np.array([0, -1.0, 0])
    up = N[:, 1]
    tronc = norm(arr[None] + bas[None] * (0.45 * (1 - np.abs(up)))[:, None])
    d = np.zeros_like(P)
    d += K[:, [ci["tronc"]]] * tronc
    d += K[:, [ci["abdomen"]]] * norm(arr[None] + bas[None] * 0.3)
    d += K[:, [ci["tete"]]] * norm(arr[None] + bas[None] * 0.15)
    d += K[:, [ci["oreille"]]] * np.array([0, 1.0, 0])
    d += K[:, [ci["cou"]]] * norm(arr * 0.55 + bas * 0.85)[None]
    d += K[:, [ci["poitrail"]]] * norm(arr * 0.25 + bas)[None]
    d += K[:, [ci["patte_haute"]]] * norm(arr * 0.2 + bas)[None]
    d += K[:, [ci["patte_basse"]]] * bas[None]
    # queue : le long des os de la queue, vers la pointe
    tq = np.zeros_like(P)
    for i, n in enumerate(os_noms):
        if n.startswith("Tail"):
            enf = [m for m in os_noms if m.startswith("Tail") and (m == "Tail%d" % (int(re.sub(r"\D", "", n) or 0) + 1))]
            fin = enf[0] if enf else None
            if fin is None:
                fin = next((m for m in pos_os if m.startswith(n + "_end")), None)
            if fin is None or fin not in pos_os or n not in pos_os:
                continue
            dv = pos_os[fin] - pos_os[n]
            if np.linalg.norm(dv) < 1e-6:
                continue
            tq += Wos[:, [i]] * (dv / np.linalg.norm(dv))[None]
    d += K[:, [ci["queue"]]] * norm(tq + 1e-6 * arr[None])
    d = d - N * np.sum(d * N, axis=1, keepdims=True)
    bad = np.linalg.norm(d, axis=1) < 1e-4
    if bad.any():
        alt = np.cross(N[bad], np.array([1.0, 0, 0]))
        d[bad] = alt
    return norm(d)


# ------------------------------------------------------------------ couleurs lissées
def lisser_couleurs(o):
    """Lisse les aplats par face (taches) en gardant nets les coins de détail (yeux, truffe, sabots)."""
    me = o.data
    cc = couleurs_coins(o)
    fixe = lumi(cc) < CFG.get("seuil_detail", 0.07)
    lv = np.array([l.vertex_index for l in me.loops])
    nv = len(me.vertices)
    voisins = [[] for _ in range(nv)]
    for e in me.edges:
        a, b = e.vertices
        voisins[a].append(b)
        voisins[b].append(a)
    acc = np.zeros((nv, 3))
    cnt = np.zeros(nv)
    np.add.at(acc, lv[~fixe], cc[~fixe])
    np.add.at(cnt, lv[~fixe], 1)
    cv = acc / np.maximum(cnt, 1)[:, None]
    a_coul = cnt > 0
    for _ in range(CFG.get("lissage", 4)):
        nc = cv.copy()
        for i, vs in enumerate(voisins):
            if not a_coul[i]:
                continue
            vs2 = [v for v in vs if a_coul[v]]
            if vs2:
                nc[i] = 0.5 * cv[i] + 0.5 * cv[vs2].mean(axis=0)
        cv = nc
    out = np.where(fixe[:, None], cc, cv[lv])
    poser_couleurs(o, out)
    return fixe


# ------------------------------------------------------------------ texture peinte
def peindre(ex, flow_v, K_v, S):
    P, C, tri_v, tri_l, UV, N = ex["P"], ex["C"], ex["tri_v"], ex["tri_l"], ex["UV"], ex["N"]
    img = np.zeros((S, S, 3))
    rempli = np.zeros((S, S), bool)
    pts_P, pts_N, pts_C, pts_F, pts_K, pts_ij = [], [], [], [], [], []
    for t in range(len(tri_v)):
        uv = UV[tri_l[t]] * S
        x0, y0 = np.floor(uv.min(0)).astype(int)
        x1, y1 = np.ceil(uv.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, S - 1), min(y1, S - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        p = np.stack([xs.ravel(), ys.ravel()], -1)
        a, b, c = uv
        v0, v1 = b - a, c - a
        den = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(den) < 1e-12:
            continue
        v2 = p - a
        l1 = (v2[:, 0] * v1[1] - v1[0] * v2[:, 1]) / den
        l2 = (v0[0] * v2[:, 1] - v2[:, 0] * v0[1]) / den
        l0 = 1 - l1 - l2
        e = -0.7 / max(np.abs(den) ** 0.5, 1e-6)       # un demi-texel de marge : pas de trou entre triangles
        ok = (l0 >= e) & (l1 >= e) & (l2 >= e)
        if not ok.any():
            continue
        bc = np.stack([l0, l1, l2], -1)[ok]
        bc = np.clip(bc, 0, None)
        bc /= bc.sum(1, keepdims=True)
        vi = tri_v[t]
        pts_P.append(bc @ P[vi])
        pts_N.append(bc @ N[tri_l[t]])
        pts_C.append(bc @ C[tri_l[t]])
        pts_F.append(bc @ flow_v[vi])
        pts_K.append(bc @ K_v[vi])
        pts_ij.append(np.floor(p[ok]).astype(int))
    Pp = np.concatenate(pts_P)
    Np = norm(np.concatenate(pts_N))
    Cp = np.concatenate(pts_C)
    Fp = norm(np.concatenate(pts_F))
    Kp = np.concatenate(pts_K)
    ij = np.concatenate(pts_ij)
    Cp0 = Cp.copy()
    lum0 = lumi(Cp)
    detail = lum0 < CFG.get("seuil_detail", 0.07)
    Cp = manteau(Cp, Pp, Np, Kp)
    T1 = norm(np.cross(Np, Fp))
    f = CFG["poil"]
    ech = CFG.get("echelle_poil", 1.0)
    q1 = np.stack([np.sum(Pp * Fp, 1) * f["meche_long"], np.sum(Pp * T1, 1) * f["meche_trav"], np.sum(Pp * Np, 1) * f["meche_trav"]], -1) * ech
    q2 = np.stack([np.sum(Pp * Fp, 1) * f["poil_long"], np.sum(Pp * T1, 1) * f["poil_trav"], np.sum(Pp * Np, 1) * f["poil_trav"]], -1) * ech
    n1 = bruit(q1, 11)
    n2 = bruit(q2, 23)
    n3 = bruit(Pp * f["tache"] * ech, 37)               # variation lente de teinte (pelage pas uniforme)
    lum = 1 + f["amp_meche"] * (n1 - 0.5) * 2 + f["amp_poil"] * (n2 - 0.5) * 2
    lum = lum * (1 + f["amp_tache"] * (n3 - 0.5) * 2)
    col = Cp * lum[:, None]
    chaud = np.array(CFG.get("teinte_tache", [1.04, 1.0, 0.95]))
    col = col * (1 + (np.array(chaud) - 1)[None] * ((n3 - 0.5) * 2)[:, None])
    # pelage d'hiver : sous le ventre et l'intérieur des pattes un peu plus clair / plus sombre selon l'espèce
    vent = np.clip(-Np[:, 1], 0, 1)
    col = col * (1 + CFG.get("ventre", 0.0) * vent)[:, None]
    col[detail] = Cp0[detail]                              # yeux, truffe : sans poil
    col = np.clip(col, 0, 1)
    if CFG.get("palette", False):
        col = accrocher(col)
    else:
        q = CFG.get("quantif", {})
        col = quantifier(col, q.get("pas_l", 0.045), q.get("pas_c", 0.012), q.get("sat", 0.85), q.get("froid", 0.008))
    img[ij[:, 1], ij[:, 0]] = col
    rempli[ij[:, 1], ij[:, 0]] = True
    tuv = UV[tri_l]
    aire_uv = 0.5 * np.abs((tuv[:, 1, 0] - tuv[:, 0, 0]) * (tuv[:, 2, 1] - tuv[:, 0, 1]) - (tuv[:, 2, 0] - tuv[:, 0, 0]) * (tuv[:, 1, 1] - tuv[:, 0, 1]))
    print("AIRE_UV %.3f tris=%d" % (aire_uv.sum(), len(tri_l)))
    print("DETAIL texels: %d" % detail.sum())
    print("PEINT texels=%.3f uv=%s..%s base_lum=%.3f" % (rempli.mean(), UV.min(0), UV.max(0), float(lum0.mean())))
    # marge : on étend les îlots de 4 texels (mipmaps / texels nets sans couture noire)
    for _ in range(4):
        vide = ~rempli
        acc = np.zeros_like(img)
        cnt = np.zeros((S, S))
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sh = np.roll(np.roll(img * rempli[..., None], dy, 0), dx, 1)
            sr = np.roll(np.roll(rempli, dy, 0), dx, 1)
            acc += sh
            cnt += sr
        nouv = vide & (cnt > 0)
        img[nouv] = acc[nouv] / cnt[nouv][:, None]
        rempli |= nouv
    img[~rempli] = img[rempli].mean(0)
    return img


def manteau(C, P, N, K):
    """Marques de l'espèce (CFG « manteau ») : [{"classes": [...], "ou": "dos|ventre|face|cote|tout", "vers": "#hex", "part": 0.3,
    "seuil": 0.2}] -> la couleur est tirée vers « vers » en fondu doux selon la classe d'os et l'orientation de la surface."""
    noms = [c for c, _ in CLASSES]
    out = C.copy()
    for r in CFG.get("manteau", []):
        k = np.zeros(len(C))
        for c in r.get("classes", noms):
            k += K[:, noms.index(c)]
        ou = r.get("ou", "tout")
        s0 = r.get("seuil", 0.0)
        if ou == "dos":
            o = np.clip((N[:, 1] - s0) / (1 - s0), 0, 1)
        elif ou == "ventre":
            o = np.clip((-N[:, 1] - s0) / (1 - s0), 0, 1)
        elif ou == "face":
            o = np.clip((N[:, 2] - s0) / (1 - s0), 0, 1)
        elif ou == "dessous":                # sous une hauteur (fraction de la boîte) : bas des pattes
            h = (P[:, 1] - P[:, 1].min()) / max(np.ptp(P[:, 1]), 1e-6)
            o = np.clip((r.get("haut", 0.3) - h) / 0.12, 0, 1)
        else:
            o = np.ones(len(C))
        a = np.clip(k * o * r.get("part", 0.3), 0, 1)[:, None]
        out = out * (1 - a) + np.array(H(r["vers"]))[None] * a
    return out


def texture_au_point(img, uv):
    S = img.shape[0]
    x = np.clip((uv[:, 0] * S).astype(int), 0, S - 1)
    y = np.clip((uv[:, 1] * S).astype(int), 0, S - 1)
    return img[y, x]


# ------------------------------------------------------------------ fourrure géométrique
def semer_touffes(ex, flow_v, K_v, img):
    P, tri_v, tri_l, UV, N, W, C = ex["P"], ex["tri_v"], ex["tri_l"], ex["UV"], ex["N"], ex["W"], ex["C"]
    zones = CFG["zones"]
    noms_cl = [c for c, _ in CLASSES]
    dens_cl = np.array([zones.get(c, {}).get("densite", 0.0) for c in noms_cl])
    a = P[tri_v[:, 0]]
    b = P[tri_v[:, 1]]
    c = P[tri_v[:, 2]]
    aire = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    Kt = K_v[tri_v].mean(1)
    Nt = norm(N[tri_l].mean(1))
    Ct = C[tri_l].mean(1)
    lumt = Ct @ np.array([0.3, 0.59, 0.11])
    dens = Kt @ dens_cl
    dens = dens * (1 + CFG.get("bonus_dos", 0.0) * np.clip(Nt[:, 1], 0, 1)) * (1 + CFG.get("bonus_ventre", 0.0) * np.clip(-Nt[:, 1], 0, 1))
    face = Nt[:, 2]                                                    # tourné vers l'avant (museau, face)
    tete = Kt[:, noms_cl.index("tete")]
    dens = dens * np.where((tete > 0.5) & (face > CFG.get("face_libre", 0.55)), 0.0, 1.0)
    dens = dens * np.where(lumt < CFG.get("seuil_detail", 0.07), 0.0, 1.0)
    # jamais sous le sol (frange du ventre courte, sabots libres)
    dens = dens * np.where(P[tri_v].min(axis=(1, 2)) < CFG.get("sol_libre", 0.05), 0.0, 1.0) if False else dens
    poids = aire * dens
    if poids.sum() <= 0:
        return None
    n = int(CFG["touffes"])
    choix = RNG.choice(len(tri_v), size=n, p=poids / poids.sum())
    r1 = np.sqrt(RNG.random(n))
    r2 = RNG.random(n)
    bc = np.stack([1 - r1, r1 * (1 - r2), r1 * r2], -1)
    vi = tri_v[choix]
    li = tri_l[choix]
    Pr = np.einsum("nk,nkd->nd", bc, P[vi])
    Nr = norm(np.einsum("nk,nkd->nd", bc, N[li]))
    Ur = np.einsum("nk,nkd->nd", bc, UV[li])
    Wr = np.einsum("nk,nkd->nd", bc, W[vi])
    Kr = np.einsum("nk,nkd->nd", bc, K_v[vi])
    Fr = norm(np.einsum("nk,nkd->nd", bc, flow_v[vi]))
    Fr = norm(Fr - Nr * np.sum(Fr * Nr, 1, keepdims=True))
    # paramètres par zone (moyenne pondérée par la classe)
    def param(cle, defaut):
        v = np.array([zones.get(c, {}).get(cle, defaut) for c in noms_cl])
        k = Kr * (dens_cl > 0)[None]
        return (k @ v) / np.maximum(k.sum(1), 1e-6)
    L = param("longueur", 0.04) * RNG.uniform(0.7, 1.3, n)
    lift = np.radians(param("leve", 25.0)) * RNG.uniform(0.7, 1.3, n)
    seg = param("segments", 1.0)
    larg = param("largeur", CFG.get("largeur", 0.012)) * RNG.uniform(0.8, 1.2, n)
    pointe = param("pointe", 0.9)
    racine = CFG.get("ombre_racine", 0.62)
    # dos : la pointe de la frange du ventre et du dos un peu plus longue
    L = L * (1 + CFG.get("long_dos", 0.0) * np.clip(Nr[:, 1], 0, 1)) * (1 + CFG.get("long_ventre", 0.0) * np.clip(-Nr[:, 1], 0, 1))
    # jitter de direction (mèches pas toutes parallèles)
    jit = norm(RNG.normal(size=(n, 3)))
    Fr = norm(Fr + jit * CFG.get("desordre", 0.25))
    Fr = norm(Fr - Nr * np.sum(Fr * Nr, 1, keepdims=True))
    grav = np.array([0, -1.0, 0])
    Vs, Ns, Us, Cs, Ws, Fs = [], [], [], [], [], []
    col_tex = texture_au_point(img, Ur)
    for i in range(n):
        p, nn, f, l = Pr[i], Nr[i], Fr[i], L[i]
        d0 = norm(f * math.cos(lift[i]) + nn * math.sin(lift[i]))
        w = norm(np.cross(d0, nn))
        th = norm(np.cross(w, d0))
        if np.dot(th, nn) < 0:
            th = -th
        r = larg[i]
        base_c = p - nn * r * 0.35
        anneau0 = [base_c + w * r, base_c + th * r * 0.55, base_c - w * r]
        pg = CFG.get("pesanteur", 0.25)
        if seg[i] >= 1.5:
            d1 = norm(f * math.cos(lift[i] * 0.35) + nn * math.sin(lift[i] * 0.35) + grav * pg * 0.6)
            m = base_c + d0 * l * 0.5
            w1 = norm(np.cross(d1, nn))
            th1 = norm(np.cross(w1, d1))
            if np.dot(th1, nn) < 0:
                th1 = -th1
            r1_ = r * 0.62
            anneau1 = [m + w1 * r1_, m + th1 * r1_ * 0.55, m - w1 * r1_]
            tip = m + d1 * l * 0.5 + grav * pg * l * 0.25
            anneaux = [anneau0, anneau1]
            t_col = [racine, 0.5 * (racine + pointe[i]) + 0.1, pointe[i]]
        else:
            tip = base_c + norm(d0 + grav * pg) * l
            anneaux = [anneau0]
            t_col = [racine, pointe[i]]
        faces = []
        for k in range(len(anneaux)):
            ra = anneaux[k]
            if k + 1 < len(anneaux):
                rb = anneaux[k + 1]
                for s in range(3):
                    s2 = (s + 1) % 3
                    faces.append(((ra[s], t_col[k]), (ra[s2], t_col[k]), (rb[s2], t_col[k + 1])))
                    faces.append(((ra[s], t_col[k]), (rb[s2], t_col[k + 1]), (rb[s], t_col[k + 1])))
            else:
                for s in range(3):
                    s2 = (s + 1) % 3
                    faces.append(((ra[s], t_col[k]), (ra[s2], t_col[k]), (tip, t_col[-1])))
        axe_c = np.mean([q for an in anneaux for q in an], axis=0)
        for fv in faces:
            v = np.array([x[0] for x in fv])
            fn = np.cross(v[1] - v[0], v[2] - v[0])
            ln = np.linalg.norm(fn)
            if ln < 1e-12:
                continue
            fn /= ln
            cen = v.mean(0)
            if np.dot(fn, cen - axe_c) < 0:          # pans vers l'extérieur (le shader élimine les faces arrière)
                fv = (fv[0], fv[2], fv[1])
                v = v[[0, 2, 1]]
                fn = -fn
            for q, tc in fv:
                Vs.append(q)
                Ns.append(fn)
                Us.append(Ur[i])
                Cs.append([tc, tc, tc])
                Ws.append(Wr[i])
                Fs.append(i)
    return dict(P=np.array(Vs), N=np.array(Ns), UV=np.array(Us), C=np.array(Cs), W=np.array(Ws))


# ------------------------------------------------------------------ assemblage (sommets uniques) et écriture
def corps_en_tableaux(ex, vc_corps):
    """Sommets glTF par coin (triangles indépendants -> fusion des coins identiques)."""
    tri_v, tri_l = ex["tri_v"].ravel(), ex["tri_l"].ravel()
    cle = np.concatenate([tri_v[:, None].astype(np.float64), np.round(ex["UV"][tri_l] * 4096), np.round(ex["N"][tri_l] * 512)], 1)
    _, uniq, inv = np.unique(cle, axis=0, return_index=True, return_inverse=True)
    P = ex["P"][tri_v[uniq]]
    N = norm(ex["N"][tri_l[uniq]])
    UV = ex["UV"][tri_l[uniq]]
    W = ex["W"][tri_v[uniq]]
    C = np.repeat(np.array([[vc_corps] * 3]), len(uniq), 0)
    return dict(P=P, N=N, UV=UV, C=C, W=W, I=inv.reshape(-1).astype(np.int64))


def poids_top4(W):
    idx = np.argsort(-W, axis=1)[:, :4]
    w = np.take_along_axis(W, idx, 1)
    s = w.sum(1, keepdims=True)
    w = np.where(s > 0, w / np.maximum(s, 1e-9), np.array([[1.0, 0, 0, 0]]))
    idx = np.where(w > 0, idx, 0)
    return idx, w


def ajouter_maillage(j, binr, parts, joints_de_os, mat):
    P = np.concatenate([p["P"] for p in parts]).astype(np.float32)
    N = norm(np.concatenate([p["N"] for p in parts])).astype(np.float32)
    UV = np.concatenate([p["UV"] for p in parts]).astype(np.float32)
    C = np.concatenate([p["C"] for p in parts])
    W = np.concatenate([p["W"] for p in parts])
    I, base = [], 0
    for p in parts:
        I.append(p["I"] + base if "I" in p else np.arange(len(p["P"])) + base)
        base += len(p["P"])
    I = np.concatenate(I)
    idx, w = poids_top4(W)
    J = joints_de_os[idx].astype(np.uint8)
    C4 = np.concatenate([np.clip(C, 0, 1), np.ones((len(C), 1))], 1)
    C4 = (lin(C4) * 65535).round().astype(np.uint16) if False else (np.clip(C4, 0, 1) * 65535).round().astype(np.uint16)
    att = {
        "POSITION": ajouter_accessor(j, binr, P, 5126, "VEC3", cible=34962, minmax=True),
        "NORMAL": ajouter_accessor(j, binr, N, 5126, "VEC3", cible=34962),
        "TEXCOORD_0": ajouter_accessor(j, binr, UV, 5126, "VEC2", cible=34962),
        "COLOR_0": ajouter_accessor(j, binr, C4, 5123, "VEC4", normalise=True, cible=34962),
        "JOINTS_0": ajouter_accessor(j, binr, J, 5121, "VEC4", cible=34962),
        "WEIGHTS_0": ajouter_accessor(j, binr, w.astype(np.float32), 5126, "VEC4", cible=34962),
    }
    it = I.astype(np.uint16 if base < 65536 else np.uint32)
    ia = ajouter_accessor(j, binr, it.reshape(-1, 1), 5123 if base < 65536 else 5125, "SCALAR", cible=34963)
    j["meshes"].append({"name": "m", "primitives": [{"attributes": att, "indices": ia, "material": mat}]})
    return len(j["meshes"]) - 1, len(I) // 3


def main():
    j, binr = lire_glb(SRC)
    skin = j["skins"][0]
    os_noms = [j["nodes"][k]["name"] for k in skin["joints"]]
    pos_os, parent = positions_os(j)
    node_m = next(i for i, n in enumerate(j["nodes"]) if "mesh" in n and "skin" in n)
    prim0 = j["meshes"][j["nodes"][node_m]["mesh"]]["primitives"][0]
    pos_orig = lire_accessor(j, binr, prim0["attributes"]["POSITION"])
    corps = preparer_blender()
    t_orig, _ = tris_de(corps), 0
    # contrôle du repère : boîte du maillage Blender convertie == boîte de l'accessor d'origine
    Pb = b2g(np.array([v.co[:] for v in corps.data.vertices]))
    ecart = np.abs(Pb.min(0) - pos_orig.min(0)).max() + np.abs(Pb.max(0) - pos_orig.max(0)).max()
    assert ecart < 1e-3, "repère inattendu (écart %.4f)" % ecart
    t0, t1 = remodeler(corps)
    fixe = lisser_couleurs(corps)
    deplier(corps)
    ex = extraire(corps, os_noms)
    KO = classes_os(os_noms)
    K_v = ex["W"] @ KO
    K_v = K_v / np.maximum(K_v.sum(1, keepdims=True), 1e-6)
    flow_v = sens_du_poil(ex["P"], norm(ex["VN"]), K_v, ex["W"], os_noms, pos_os)
    S = int(CFG["texture"])
    img = peindre(ex, flow_v, K_v, S)
    touffes = semer_touffes(ex, flow_v, K_v, img)
    # LOD : copie du corps décimée (UV et poids gardés)
    lod = corps.copy()
    lod.data = corps.data.copy()
    bpy.context.scene.collection.objects.link(lod)
    for o in bpy.context.scene.objects:
        o.select_set(o == lod)
    bpy.context.view_layer.objects.active = lod
    m = lod.modifiers.new("dec", 'DECIMATE')
    m.decimate_type = 'COLLAPSE'
    m.ratio = min(1.0, CFG["tris_loin"] / tris_de(lod))
    m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier="dec")
    ex_lod = extraire(lod, os_noms)
    # glb : nouveaux maillages, squelette et clips d'origine intacts
    joints_de_os = np.arange(len(os_noms))
    mat = prim0.get("material", 0)
    vc = CFG.get("vc_corps", 1.0)
    parts = [corps_en_tableaux(ex, vc)]
    if touffes is not None:
        parts.append(touffes)
    mi, t_proche = ajouter_maillage(j, binr, parts, joints_de_os, mat)
    li, t_loin = ajouter_maillage(j, binr, [corps_en_tableaux(ex_lod, vc)], joints_de_os, mat)
    j["nodes"][node_m]["mesh"] = mi
    j["nodes"][node_m]["name"] = ID
    j["nodes"].append({"name": ID + "_loin", "mesh": li, "skin": j["nodes"][node_m]["skin"]})
    nouveau = len(j["nodes"]) - 1
    par = parent.get(node_m)
    if par is None:
        j["scenes"][j.get("scene", 0)]["nodes"].append(nouveau)
    else:
        j["nodes"][par]["children"].append(nouveau)
    ecrire_glb(os.path.join(SORTIE, ID + ".glb"), j, binr)
    # texture : PNG (lignes du haut en premier, comme les UV glTF)
    im = bpy.data.images.new(ID, S, S, alpha=False)
    px = np.ones((S, S, 4))
    px[..., :3] = img[::-1]                   # Blender : lignes du bas en premier
    im.pixels = px.ravel().tolist()
    im.filepath_raw = os.path.join(SORTIE, ID + ".png")
    im.file_format = 'PNG'
    im.save()
    imp = os.path.join(SORTIE, ID + ".png.import")
    if not os.path.exists(imp):
        open(imp, "w", encoding="utf8").write(IMPORT_PNG)
    rap = {"id": ID, "source": CFG["source"], "tris_source": t_orig, "tris_subdiv_decime": t1, "tris_touffes": t_proche - t1,
           "tris_proche": t_proche, "tris_loin": t_loin, "touffes": int(CFG["touffes"]), "texture": S}
    os.makedirs(os.path.join(ICI, "rapports"), exist_ok=True)
    json.dump(rap, open(os.path.join(ICI, "rapports", ID + ".json"), "w"), indent=1)
    print("BETES_V2", json.dumps(rap))


IMPORT_PNG = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""

main()
