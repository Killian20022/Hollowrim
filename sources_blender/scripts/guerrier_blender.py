# Passe Blender du GUERRIER nordique : jupe de cuir (ourlet de fourrure modele) + panneau bleu/maille en pointe + cape a plis marques
# + bake AO/courbure (Cycles, CPU, sans fenetre) -> reliefs quantifies (PNG 5 tons) lus par scripts/guerrier_textures.gd.
#   blender.exe -b --python guerrier_blender.py -- <dossier du worktree> [--sans-bake]
# Sorties : assets/persos/guerrier/blender/guerrier_bl.glb (armature 65 os + jupe, tabard, cape_bl, skinnes) et relief_guerrier.png.
# Reperes : Blender Z haut, face = -Y (export glTF : Godot +Z devant). Le glb ne contient que les pieces NEUVES (le corps reste celui d'Humain).
import bpy, bmesh, math, os, sys, random
import numpy as np
from mathutils import Vector, kdtree
from mathutils.bvhtree import BVHTree

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RACINE = ARGS[0] if ARGS else r"C:\Users\lopezk19\Jeux\nordique_pb_guerrier"
BAKE = "--sans-bake" not in ARGS
SORTIE = os.path.join(RACINE, "assets", "persos", "guerrier", "blender")
os.makedirs(SORTIE, exist_ok=True)
TMP = os.path.join(os.environ.get("TEMP", RACINE), "pbg_bake")
os.makedirs(TMP, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(RACINE, "assets", "modeles", "humains", "homme_vetu.glb"))
ARM = bpy.data.objects["Armature"]
OB = bpy.data.objects
for n in ("Icosphere",):
    if n in OB:
        bpy.data.objects.remove(OB[n])

# ------------------------------------------------------------------ constantes de mise en page (alignees sur guerrier_textures.gd)
TUN_H = 224            # texture de la tunique : torse 0-127, jupe 128-175, panneau (tabard) 176-223
JUPE_Y0, JUPE_H = 128, 48
TAB_Y0, TAB_H = 176, 48
ZTOP, ZHEM = 0.965, 0.60          # jupe : de la ceinture a l'ourlet
ZTIP = 0.50                       # pointe du panneau
CX, CY = 0.0, 0.025
RAYON_UV = 0.23                   # m : arc -> texels (128 texels/m)

def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)

# ------------------------------------------------------------------ poids : copie du corps (Data Transfer par plus proche sommet)
def groupes(o):
    return {g.index: g.name for g in o.vertex_groups}

def kd_poids(objs):
    pts, ws = [], []
    for o in objs:
        gn = groupes(o)
        for v in o.data.vertices:
            w = {gn[g.group]: g.weight for g in v.groups if g.weight > 0.001}
            pts.append(v.co.copy()); ws.append(w)
    kd = kdtree.KDTree(len(pts))
    for i, p in enumerate(pts):
        kd.insert(p, i)
    kd.balance()
    return kd, ws

KD_CORPS = kd_poids([OB["pantalon"], OB["SuperHero_Male"]])

def poids_corps(p):
    _, i, _ = KD_CORPS[0].find(p)
    return dict(KD_CORPS[1][i])

def norm4(w):
    it = sorted(w.items(), key=lambda kv: -kv[1])[:4]
    s = sum(v for _, v in it) or 1.0
    return {k: v / s for k, v in it}

def melange(a, b, k):
    r = {}
    for n, v in a.items():
        r[n] = r.get(n, 0) + v * (1 - k)
    for n, v in b.items():
        r[n] = r.get(n, 0) + v * k
    return norm4(r)

# ------------------------------------------------------------------ fabrique d'objet
def objet(nom, verts, faces, uvs, poids, collection=None):
    """verts : [Vector], faces : [(i..)], uvs : [(u, v_gltf)] par sommet (v de haut en bas), poids : [{os: w}] par sommet."""
    me = bpy.data.meshes.new(nom)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            uvl.data[li].uv = (uvs[vi][0], 1.0 - uvs[vi][1])
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    names = set(k for w in poids for k in w)
    vg = {n: o.vertex_groups.new(name=n) for n in names}
    for i, w in enumerate(poids):
        for n, x in w.items():
            vg[n].add([i], x, 'REPLACE')
    for p in me.polygons:
        p.use_smooth = True
    return o

def orienter(o, centre_fn):
    """Normales vers l'exterieur (centre_fn(p) = point du cote interieur)."""
    me = o.data
    bm = bmesh.new(); bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    s = 0.0
    for f in bm.faces:
        s += f.normal.dot(f.calc_center_median() - centre_fn(f.calc_center_median()))
    if s < 0:
        for f in bm.faces:
            f.normal_flip()
    bm.normal_update()
    bm.to_mesh(me); bm.free()
    me.update()

def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)

# ------------------------------------------------------------------ JUPE
# anneaux : (t, bombement radial m, amplitude des plis m) ; t = 0 ceinture, 1 pointes de l'ourlet
RINGS_BAS = [(0.0, 0.0, 0.0), (0.30, 0.0, 0.012), (0.66, 0.0, 0.022), (0.75, 0.032, 0.0), (0.93, 0.028, 0.0)]
N_BAS = 28
PLIS = 14                         # plis de cuir autour (2 colonnes par pli en basse def)

def ring_par(t):
    """interpolation lineaire des anneaux (t) -> (bombement, amplitude plis)."""
    for (t0, b0, a0), (t1, b1, a1) in zip(RINGS_BAS, RINGS_BAS[1:]):
        if t <= t1:
            k = (t - t0) / (t1 - t0) if t1 > t0 else 0
            return b0 + (b1 - b0) * k, a0 + (a1 - a0) * k
    return RINGS_BAS[-1][1], 0.0

def rayons(z):
    k = (ZTOP - z) / (ZTOP - ZHEM)
    return 0.200 + 0.115 * k, 0.168 + 0.082 * k

def pos_jupe(theta, t, extra=0.0, z_force=None):
    z = z_force if z_force is not None else ZTOP - t * (ZTOP - ZHEM)
    rx, ry = rayons(z)
    b, a = ring_par(min(t, 0.93))
    fold = math.cos(PLIS * theta)
    off = b + a * fold + extra
    s, c = math.sin(theta), math.cos(theta)
    return Vector((CX + (rx + off) * s, CY - (ry + off) * c, z))

def arc_u(theta):
    """abscisse de texture (0..1) : arc depuis le milieu du devant, gauche = 1 + s."""
    s = RAYON_UV * theta / 2.0
    return s if s >= 0 else 1.0 + s

def jupe(N, hi, graine=7):
    rnd = random.Random(graine)
    if hi:
        sub = 3
        ts = []
        base = [r[0] for r in RINGS_BAS]
        for a, b in zip(base, base[1:]):
            for k in range(sub * 2):
                ts.append(a + (b - a) * k / (sub * 2))
        ts.append(base[-1])
    else:
        ts = [r[0] for r in RINGS_BAS]
    verts, uvs, pw, faces = [], [], [], []
    idx = {}
    def add(p, theta, t_uv, k_cuisse, cote):
        wc = poids_corps(p)
        w = melange({"pelvis": 1.0}, wc, k_cuisse)
        s_ = RAYON_UV * theta / 2.0
        u = (1.0 + s_) if cote == 'G' else s_
        verts.append(p); uvs.append((u, (JUPE_Y0 + t_uv * (JUPE_H - 1)) / TUN_H)); pw.append(w)
        return len(verts) - 1
    # colonnes : gauche (u = 1 + s) de -pi a 0, puis droite (u = s) de 0 a +pi ; le milieu du devant est DOUBLE (couture de l'image)
    cols = [(-math.pi + 2 * math.pi * i / N, 'G') for i in range(N // 2 + 1)] + [(2 * math.pi * i / N, 'D') for i in range(N // 2 + 1)]
    nc = len(cols)
    for r, t in enumerate(ts):
        for i, (th, cote) in enumerate(cols):
            p = pos_jupe(th, t)
            idx[(r, i)] = add(p, th, t, 0.55 * smooth(0.1, 1.0, t), cote)
    for r in range(len(ts) - 1):
        for i in range(nc - 1):
            if i == N // 2:
                continue
            faces.append((idx[(r, i)], idx[(r, i + 1)], idx[(r + 1, i + 1)], idx[(r + 1, i)]))
    # houppes de fourrure arrondies, groupees par 3 colonnes (longueur commune + petit ecart), bas de la houppe plus etroit que le haut
    r_last = len(ts) - 1
    grp = 12 if hi else 3
    long_g = {}
    for i in range(nc - 1):
        if i == N // 2:
            continue
        g = (i if i < N // 2 else i + 1) // grp
        if g not in long_g:
            long_g[g] = 0.040 + 0.030 * rnd.random()
        lg = long_g[g] + 0.008 * (rnd.random() - 0.5)
        t0, t1 = cols[i][0], cols[i + 1][0]
        thl, thr = t0 + 0.22 * (t1 - t0), t1 - 0.22 * (t1 - t0)
        zb = ZTOP - 0.93 * (ZTOP - ZHEM) - lg
        pl = pos_jupe(thl, 0.93, extra=0.007, z_force=zb)
        pr = pos_jupe(thr, 0.93, extra=0.007, z_force=zb)
        tv = 0.93 + 0.07 * min(1.0, lg / 0.07)
        kl = add(pl, thl, tv, 0.6, cols[i][1])
        kr = add(pr, thr, tv, 0.6, cols[i][1])
        faces.append((idx[(r_last, i)], idx[(r_last, i + 1)], kr, kl))
    o = objet("jupe_hi" if hi else "jupe", verts, faces, uvs, pw)
    orienter(o, lambda p: Vector((CX, CY, p.z)))
    return o

# ------------------------------------------------------------------ PANNEAU (tabard) bleu/maille en pointe
TAB_T = [0.0, 0.30, 0.60, 0.80, 1.0]
TAB_DEMI = 0.133                  # 17 texels / 128

def largeur_tab(t):
    return 1.0 if t <= 0.60 else max(0.0, 1.0 - (t - 0.60) / 0.40)

def pos_tab(dx, t, rel):
    """dx metres a droite du milieu, t 0..1 le long du panneau ; rel : relief (m) vers l'exterieur."""
    z = ZTOP - t * (ZTOP - ZTIP)
    zc = max(z, ZHEM)
    rx, ry = rayons(zc)
    ya = ry * math.sqrt(max(0.0, 1.0 - (dx / (rx + 0.03)) ** 2))
    tsk = (ZTOP - zc) / (ZTOP - ZHEM)
    bomb = 0.0 if tsk < 0.66 else 0.034
    if z < ZHEM:
        bomb = 0.034 + 0.01 * (ZHEM - z) / (ZHEM - ZTIP)      # le pan pend, legerement ecarte
    return Vector((CX + dx, CY - (ya + 0.012 + bomb + rel), z))

def tabard(hi):
    sub = 4 if hi else 1
    ts = []
    for a, b in zip(TAB_T, TAB_T[1:]):
        for k in range(sub):
            ts.append(a + (b - a) * k / sub)
    ts.append(1.0)
    cols = [-1.0, -0.82, 0.0, 0.82, 1.0]
    if hi:
        cols = [-1.0, -0.91, -0.82, -0.6, -0.3, 0.0, 0.3, 0.6, 0.82, 0.91, 1.0]
    def rel_col(c):
        a = abs(c)
        return 0.016 if a > 0.8 else (0.004 if a < 0.7 else 0.010)       # bordure de fourrure en bourrelet, centre en creux
    verts, uvs, pw, faces, idx = [], [], [], [], {}
    for r, t in enumerate(ts):
        w = largeur_tab(t)
        mid = len(cols) // 2
        for j in [mid] + [k for k in range(len(cols)) if k != mid]:
            c = cols[j]
            if w <= 0.0 and j != len(cols) // 2:
                idx[(r, j)] = idx[(r, len(cols) // 2)]
                continue
            dx = c * TAB_DEMI * w
            rel = rel_col(c) * (1.0 if w > 0.0 else 0.0)
            p = pos_tab(dx, t, rel)
            wt = melange({"pelvis": 1.0}, poids_corps(p), 0.15 + 0.3 * smooth(0.5, 1.0, t))
            xt = c * 17.0 * w
            u = (128.0 + xt) / 256.0
            verts.append(p); uvs.append((u, (TAB_Y0 + t * (TAB_H - 1)) / TUN_H)); pw.append(wt)
            idx[(r, j)] = len(verts) - 1
    for r in range(len(ts) - 1):
        for j in range(len(cols) - 1):
            q = [idx[(r, j)], idx[(r, j + 1)], idx[(r + 1, j + 1)], idx[(r + 1, j)]]
            u = []
            for a in q:
                if a not in u:
                    u.append(a)
            if len(u) >= 3:
                faces.append(tuple(u))
    o = objet("tabard_hi" if hi else "tabard", verts, faces, uvs, pw)
    orienter(o, lambda p: Vector((CX, CY + 0.2, p.z)))
    # devant = -Y : normales vers -Y
    return o

# ------------------------------------------------------------------ CAPE a plis marques (grille de la cape d'origine rebatie + plis)
def grille_cape():
    src = OB["cape"]
    me = src.data
    gn = groupes(src)
    uvl = me.uv_layers[0].data
    uv_v = {}
    for poly in me.polygons:
        for li in poly.loop_indices:
            uv_v[me.loops[li].vertex_index] = tuple(uvl[li].uv)
    vs = sorted(range(len(me.vertices)), key=lambda i: me.vertices[i].co.z)
    nr, nc = 10, 15
    G = []
    for r in range(nr):
        ch = sorted(vs[r * nc:(r + 1) * nc], key=lambda i: me.vertices[i].co.x)
        G.append(ch)
    # rangee 0 = ourlet (z bas) ; on renvoie de HAUT en bas
    G = G[::-1]
    pos = [[me.vertices[i].co.copy() for i in row] for row in G]
    uv = [[uv_v[i] for i in row] for row in G]
    wt = [[{gn[g.group]: g.weight for g in me.vertices[i].groups if g.weight > 0.001} for i in row] for row in G]
    return pos, uv, wt

def catmull(p0, p1, p2, p3, t):
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)

def evalue(grid, r, c, tr, tc, kind="v"):
    """Catmull-Rom bicubique d'une grille de Vector/ tuples."""
    nr, nc = len(grid), len(grid[0])
    def rowpt(rr):
        rr = max(0, min(nr - 1, rr))
        pts = [Vector(grid[rr][max(0, min(nc - 1, c + d))]) if kind == "v" else Vector((*grid[rr][max(0, min(nc - 1, c + d))], 0)) for d in (-1, 0, 1, 2)]
        return catmull(pts[0], pts[1], pts[2], pts[3], tc)
    rows = [rowpt(r + d) for d in (-1, 0, 1, 2)]
    return catmull(rows[0], rows[1], rows[2], rows[3], tr)

def pli(u01, z):
    """profil des plis (-1..1) : plis de laine marques, plus profonds vers le bas. u01 : abscisse 0..1 sur la cape."""
    ph = 2 * math.pi * (5.5 * u01 + 0.12 * math.sin(3.1 * u01 + z))
    a = 1.0 - 2.0 * abs(math.sin(0.5 * ph + 0.4))                  # creux en V, arete arrondie
    b = 0.35 * math.sin(2 * ph + 1.3)
    return max(-1.0, min(1.0, a + b))

def cape(sous_r, sous_c, hi, graine=3):
    pos, uv, wt = grille_cape()
    nr, nc = len(pos), len(pos[0])
    rnd = random.Random(graine)
    zs = [pos[r][nc // 2].z for r in range(nr)]
    zmin, zmax = min(zs), max(zs)
    verts, uvs, pw, faces, idx = [], [], [], [], {}
    NR = (nr - 1) * sous_r + 1
    NC = sous_c            # nombre de colonnes echantillonnees (la grille d'origine en a 15)
    for R in range(NR):
        r, tr = divmod(R, sous_r)
        if r >= nr - 1:
            r, tr = nr - 2, 1.0
        else:
            tr = tr / sous_r
        for C in range(NC):
            fc = C * (nc - 1) / (NC - 1)
            c = min(int(fc), nc - 2)
            tc = fc - c
            p = evalue(pos, r, c, tr, tc)
            u2 = evalue(uv, r, c, tr, tc, "uv")
            u, v = u2.x, u2.y
            zn = max(0.0, min(1.0, (p.z - zmin) / (zmax - zmin)))             # 0 ourlet, 1 epaules
            # evasement doux vers le bas
            p.x *= 1.0 + 0.22 * (1.0 - zn) ** 1.5
            # plis (le long de la normale : +Y = vers l'exterieur / dos)
            w01 = (u - 0.2202) / 0.4025
            amp = 0.004 + 0.040 * smooth(0.0, 1.0, 1.0 - zn)
            off = amp * pli(w01, p.z)
            if hi:
                off += 0.0035 * math.sin(97 * w01 + 40 * p.z) * (1 - zn) + 0.002 * (rnd.random() - 0.5)
            p.y += off
            p.z += -0.018 * (1 - zn) * abs(pli(w01, 0.0)) * 0.0
            # poids : bilineaires sur la grille d'origine
            r0 = r + (1 if tr >= 0.5 else 0); c0 = c + (1 if tc >= 0.5 else 0)
            w = {}
            for rr, kr in ((r, 1 - tr), (min(r + 1, nr - 1), tr)):
                for cc, kc in ((c, 1 - tc), (min(c + 1, nc - 1), tc)):
                    for n_, x_ in wt[rr][cc].items():
                        w[n_] = w.get(n_, 0) + x_ * kr * kc
            verts.append(p); uvs.append((u, v)); pw.append(norm4(w))
            idx[(R, C)] = len(verts) - 1
    for R in range(NR - 1):
        for C in range(NC - 1):
            faces.append((idx[(R, C)], idx[(R + 1, C)], idx[(R + 1, C + 1)], idx[(R, C + 1)]))
    o = objet("cape_hi" if hi else "cape_bl", verts, faces, uvs, pw)
    orienter(o, lambda p: Vector((0, -0.1, p.z)))      # cote exterieur = dos (+Y)
    return o

# ------------------------------------------------------------------ BAKE (Cycles, CPU)
def scene_bake():
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 48
    sc.cycles.use_denoising = False
    w = bpy.data.worlds.new("w"); sc.world = w
    w.use_nodes = True
    try:
        w.light_settings.distance = 0.10
        w.light_settings.ao_factor = 1.0
    except Exception as e:
        print("AO monde", e)
    for o in OB:
        if o.type == 'MESH' and o.name not in ("pantalon", "SuperHero_Male", "ceinture"):
            pass

def preparer_materiau(o, nom_img, W, H, fond):
    img = bpy.data.images.new(nom_img, W, H, alpha=False, float_buffer=True)
    px = np.empty((H, W, 4), np.float32); px[...] = (fond, fond, fond, 1.0)
    img.pixels = px.ravel()
    mat = bpy.data.materials.new("m_" + nom_img)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(em.outputs[0], out.inputs[0])
    nt.nodes.active = tex
    o.data.materials.clear(); o.data.materials.append(mat)
    return img, mat, em

def cuire(o, W, H, occulteurs=()):
    """Retourne (ao, pointe) tableaux (H, W) haut->bas, valeurs 0..1."""
    res = {}
    for kind in ("AO", "POINTE"):
        img, mat, em = preparer_materiau(o, "%s_%s" % (o.name, kind), W, H, 1.0 if kind == "AO" else 0.5)
        nt = mat.node_tree
        if kind == "POINTE":
            g = nt.nodes.new("ShaderNodeNewGeometry")
            nt.links.new(g.outputs["Pointiness"], em.inputs["Color"])
        bpy.ops.object.select_all(action='DESELECT')
        o.select_set(True); bpy.context.view_layer.objects.active = o
        bpy.ops.object.bake(type='AO' if kind == "AO" else 'EMIT', margin=6, use_clear=False)
        a = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[:, :, 0][::-1]
        res[kind] = a
    return res["AO"], res["POINTE"]

def reduire(a, f):
    H, W = a.shape
    return a.reshape(H // f, f, W // f, f).mean(axis=(1, 3))

def quantifier(ao, pt, seuils_ao=(0.40, 0.66), seuil_pt=None):
    # courbure : seuils adaptatifs (la pointiness cuite est tres resserree autour de 0.5) -> 7 % d'aretes, 9 % de creux
    vals = pt[np.abs(pt - 0.5) > 1e-4]
    if vals.size > 50:
        seuil_pt = (float(np.percentile(vals, 9)), float(np.percentile(vals, 93)))
    else:
        seuil_pt = (0.0, 2.0)
    off = np.zeros(ao.shape, np.int8)
    off[ao < seuils_ao[1]] = -1
    off[ao < seuils_ao[0]] = -2
    e = np.zeros(ao.shape, np.int8)
    e[pt > seuil_pt[1]] = 1
    e[pt < seuil_pt[0]] = -1
    r = np.clip(off + e, -2, 2)
    # median 3x3 (aplats, pas de poivre et sel)
    p = np.pad(r, 1, mode='edge')
    pile = np.stack([p[y:y + r.shape[0], x:x + r.shape[1]] for y in range(3) for x in range(3)])
    return np.median(pile, axis=0).astype(np.int8)

def sauver_png(nom, arr):
    """arr int8 -2..2 -> PNG gris 8 bits (valeur + 2) * 50, haut->bas (ecriture directe : pas de gestion de couleur)."""
    import zlib, struct
    H, W = arr.shape
    g = ((arr.astype(np.int32) + 2) * 50).astype(np.uint8)
    raw = b"".join(b"\x00" + g[y].tobytes() for y in range(H))
    def ck(t, c):
        return struct.pack(">I", len(c)) + t + c + struct.pack(">I", zlib.crc32(t + c) & 0xffffffff)
    chemin = os.path.join(SORTIE, nom)
    with open(chemin, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + ck(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 0, 0, 0, 0)) + ck(b"IDAT", zlib.compress(raw, 9)) + ck(b"IEND", b""))
    print("RELIEF", chemin, W, H, {int(k): int(v) for k, v in zip(*np.unique(arr, return_counts=True))})

# ------------------------------------------------------------------ apercu Workbench (controle visuel, sans fenetre)
def apercu(dossier, objs, nom):
    os.makedirs(dossier, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.render.resolution_x = 480; sc.render.resolution_y = 640
    sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'SINGLE'
    sc.display.shading.single_color = (0.7, 0.55, 0.4)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = 1.1
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = o not in objs and o.name not in ("pantalon",)
    for vue, (loc, rot) in {"face": ((0, -3, 0.75), (math.pi / 2, 0, 0)), "dos": ((0, 3, 0.75), (math.pi / 2, 0, math.pi)),
                            "cote": ((3, 0, 0.75), (math.pi / 2, 0, math.pi / 2)), "q34": ((2.1, -2.1, 0.75), (math.pi / 2, 0, math.pi / 4))}.items():
        cam.location = loc; cam.rotation_euler = rot
        sc.render.filepath = os.path.join(dossier, "%s_%s.png" % (nom, vue))
        bpy.ops.render.render(write_still=True)

# ------------------------------------------------------------------ main
for o in list(OB):
    pass
corps_pour_ao = [OB["pantalon"], OB["SuperHero_Male"]]

j_lo = jupe(N_BAS, False)
t_lo = tabard(False)
c_lo = cape(1, 22, False)
if "--apercu" in ARGS:
    apercu(os.path.join(TMP, "apercu"), [j_lo, t_lo, c_lo], "bl")
    sys.exit(0)
print("TRIANGLES jupe", tris(j_lo), "tabard", tris(t_lo), "cape", tris(c_lo))

if BAKE:
    scene_bake()
    for o in OB:
        if o.type == 'MESH' and o.name not in ("pantalon", "SuperHero_Male", "ceinture", "jupe", "tabard", "cape_bl"):
            o.hide_render = True
    for o in corps_pour_ao:
        o.hide_render = False
    j_hi = jupe(N_BAS * 4, True)
    t_hi = tabard(True)
    c_hi = cape(4, 113, True)
    print("TRIANGLES hi jupe", tris(j_hi), "tabard", tris(t_hi), "cape", tris(c_hi))
    # --- UV de bake locales : jupe/tabard en (u, 1 - t) sur 256 x 48 ; cape sur 112 x 128 ; brassards tels quels
    def uv_local(o, f):
        l = o.data.uv_layers[0].data
        for d in l:
            d.uv = f(d.uv[0], d.uv[1])
    # jupe : gltf v = (128 + t*47)/224 -> t ; Blender v = 1 - gltf v
    uv_local(j_hi, lambda u, v: (u, 1.0 - min(1.0, max(0.0, ((1 - v) * TUN_H - JUPE_Y0) / (JUPE_H - 1)))))
    uv_local(t_hi, lambda u, v: (u, 1.0 - min(1.0, max(0.0, ((1 - v) * TUN_H - TAB_Y0) / (TAB_H - 1)))))
    uv_local(c_hi, lambda u, v: ((u * 256.0 - 56.0) / 112.0, v))
    # occulteurs : la hi de l'autre piece est deja dans la scene ; on cache la basse def
    for o in (j_lo, t_lo, c_lo):
        o.hide_render = True
    # jupe (le tabard la couvre : il reste dans la scene comme occulteur)
    ao, pt = cuire(j_hi, 512, 96)
    j_rel = quantifier(reduire(ao, 2), reduire(pt, 2), (0.22, 0.50))
    ao, pt = cuire(t_hi, 512, 96)
    t_rel = quantifier(reduire(ao, 2), reduire(pt, 2), (0.30, 0.58))
    j_hi.hide_render = True
    t_hi.hide_render = True
    # cape (224 x 256 -> 112 x 128)
    ao, pt = cuire(c_hi, 224, 256)
    c_rel = quantifier(reduire(ao, 2), reduire(pt, 2), (0.50, 0.74))
    # brassards : sous-division + rides du cuir (bruit allonge) -> AO / courbure dans les UV d'origine (128 x 64)
    br = OB["brassards"].copy(); br.data = OB["brassards"].data.copy(); br.name = "brassards_hi"
    bpy.context.scene.collection.objects.link(br)
    br.parent = None; br.hide_render = False; br.hide_viewport = False
    for m in list(br.modifiers):
        br.modifiers.remove(m)
    bpy.context.view_layer.objects.active = br
    br.matrix_world = OB["brassards"].matrix_world.copy()
    ms = br.modifiers.new("sub", 'SUBSURF'); ms.levels = 3; ms.render_levels = 3; ms.subdivision_type = 'SIMPLE'
    tx = bpy.data.textures.new("rides", 'CLOUDS'); tx.noise_scale = 0.06; tx.noise_depth = 2
    md = br.modifiers.new("rides", 'DISPLACE'); md.texture = tx; md.strength = 0.006; md.mid_level = 0.5
    bpy.ops.object.select_all(action='DESELECT'); br.select_set(True); bpy.context.view_layer.objects.active = br
    bpy.ops.object.convert(target='MESH')
    OB["brassards"].hide_render = True
    ao, pt = cuire(br, 512, 256)
    b_rel = quantifier(reduire(ao, 4), reduire(pt, 4), (0.45, 0.70))
    # un seul PNG : jupe (256x48) / tabard (256x48) / cape (112x128 -> cadre 256) / brassards (128x64)
    atlas = np.zeros((48 + 48 + 128 + 64, 256), np.int8)
    atlas[0:48] = j_rel; atlas[48:96] = t_rel
    atlas[96:224, 0:112] = c_rel
    atlas[224:288, 0:128] = b_rel
    sauver_png("relief_guerrier.png", atlas)
    for o in (j_hi, t_hi, c_hi, br):
        bpy.data.objects.remove(o)
    for o in (j_lo, t_lo, c_lo):
        o.hide_render = False

# ------------------------------------------------------------------ export glb : armature + pieces neuves
for o in (j_lo, t_lo, c_lo):
    o.name = o.name.replace("_hi", "")
    o.parent = ARM
    m = o.modifiers.new("Armature", 'ARMATURE'); m.object = ARM
for o in list(OB):
    if o.type == 'MESH' and o not in (j_lo, t_lo, c_lo):
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action='DESELECT')
for o in (j_lo, t_lo, c_lo, ARM):
    o.select_set(True)
bpy.context.view_layer.objects.active = ARM
bpy.ops.export_scene.gltf(filepath=os.path.join(SORTIE, "guerrier_bl.glb"), export_format='GLB', use_selection=True,
                          export_skins=True, export_animations=False, export_apply=False, export_yup=True)
print("EXPORT", os.path.join(SORTIE, "guerrier_bl.glb"), "TRIANGLES", tris(j_lo), tris(t_lo), tris(c_lo))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(RACINE, "sources_blender", "guerrier_bl.blend"))
