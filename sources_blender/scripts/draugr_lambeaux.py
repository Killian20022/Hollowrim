# Draugr : jupe et cape en LAMBEAUX modelés (dents de scie, couches empilées, trous) puis bake du relief.
#   blender -b --python draugr_lambeaux.py -- <dossier de sortie>
# Repère de travail = repère Godot (x droite, y haut, z devant), converti en Blender (x, -z, y) à la création des sommets.
# - modèle DÉTAILLÉ : chaque lanière en grille fine (plis, ourlet qui se roule, dents secondaires effilochées, trous), solidifié ;
# - modèle LÉGER   : ~14 triangles par lanière, MÊMES formes générales (dents de scie), UV métriques empaquetés à 128 texels/m ;
# - bake (Cycles, sans fenêtre) detail -> léger : AO, courbure (pointiness), couverture (trous) ; la distance au sommet
#   (t) est tramée directement ; sortie : lambeaux.glb + lambeaux_bake.png (R = AO, G = courbure 128 neutre, B = t, A = couverture).
import bpy, bmesh, math, random, sys, os
import numpy as np
from mathutils import Vector

SORTIE = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "C:/Users/lopezk19/Jeux/nordique_pb_draugr/assets/persos/draugr/blender"
os.makedirs(SORTIE, exist_ok=True)
DENS = 128.0
AW = 256
AH = 512
PAD = 3
rng = random.Random(7)

YS = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
RX = [.36, .35, .34, .33, .31, .285, .22, .20]
ZF = [.19, .18, .17, .16, .15, .145, .14, .135]
ZB = [.28, .27, .26, .25, .235, .21, .185, .19]

def G2B(p):
    return Vector((p[0], -p[2], p[1]))

# ---------------------------------------------------------------- lanières
class Strip:
    pass

def ring_pos(phi, y, d):
    rx = np.interp(y, YS, RX) + d
    c = math.cos(phi)
    z = (np.interp(y, YS, ZF) + d) * c if c > 0 else (np.interp(y, YS, ZB) + d) * c
    return Vector((rx * math.sin(phi), y, z))

def make_jupe(i, phi0, dphi, ytop, L, d, kind):
    s = Strip()
    s.nom = "%s%d" % (kind, i)
    s.kind = "jupe"
    s.L = L
    s.out = rng.uniform(0.005, 0.03)
    s.twist = rng.uniform(-0.05, 0.05)
    def pos(u, t):
        k = t / L
        phi = phi0 + u * dphi + s.twist * k
        y = ytop - t * 0.985
        return ring_pos(phi, y, d + s.out * (k ** 1.5) + 0.012 * math.sin(u * 2.4 + i))
    s.pos = pos
    s.dir = lambda p: Vector((p.x, 0, p.z + 0.03)).normalized()
    return s

def make_cape(i, xc, hw, ytop, L, d, kind):
    s = Strip()
    s.nom = "%s%d" % (kind, i)
    s.kind = "cape"
    s.L = L
    s.out = rng.uniform(0.0, 0.015)
    s.sway = rng.uniform(-0.03, 0.03)
    def pos(u, t):
        k = t / L
        y = ytop - t * 0.985
        x = xc + u * hw * (1 + 0.06 * k) + s.sway * k
        z = -(0.222 + 0.06 * (1.42 - y) / 0.9 + d + s.out * (k ** 1.5)) + 0.55 * x * x
        return Vector((x, y, z))
    s.pos = pos
    s.dir = lambda p: Vector((0, 0, -1))
    return s

strips = []
# jupe : couche 1 = anneau de 18 lanières (courtes à moyennes) ; couche 2 = panneaux plus longs devant / derrière
n1 = 18
for i in range(n1):
    phi = 2 * math.pi * (i + 0.5) / n1
    strips.append(make_jupe(i, phi, math.pi / n1 * 0.80, 0.99, rng.uniform(0.24, 0.38), 0.02, "j1_"))
for k, centre in enumerate([0.0, math.pi]):
    for i in range(5):
        phi = centre + (i - 2) * 0.27 + rng.uniform(-0.03, 0.03)
        strips.append(make_jupe(k * 5 + i, phi, 0.082, 0.955, rng.uniform(0.38, 0.50) - (0.06 if abs(i - 2) == 2 else 0.0), 0.048, "j2_"))
# cape : 3 couches décalées, de plus en plus courtes et basses
for li, (n, ytop, lmin, lmax, d, hw) in enumerate([(9, 1.425, 0.60, 0.92, 0.0, 0.034), (8, 1.31, 0.42, 0.75, 0.03, 0.036), (7, 1.20, 0.30, 0.55, 0.06, 0.040)]):
    for i in range(n):
        xc = -0.31 + 0.62 * (i + 0.5) / n + rng.uniform(-0.008, 0.008) + (0.017 if li == 1 else 0.0)
        strips.append(make_cape(li * 20 + i, xc, hw * 0.95, ytop, rng.uniform(lmin, lmax), d, "c%d_" % li))

for s in strips:
    # bord bas : deux dents de profondeurs différentes ; valeur = profondeur supplémentaire (m)
    s.a = rng.uniform(0.04, 0.13)
    s.b = rng.uniform(0.035, 0.12)
    s.sa = rng.uniform(-0.62, -0.38)
    s.sb = rng.uniform(0.38, 0.62)
    s.ph = rng.uniform(0, 6.28)
    s.trous = []
    for _ in range(rng.choice([0, 1, 1, 2])):
        s.trous.append((rng.uniform(-0.5, 0.5), rng.uniform(0.25, 0.7) * s.L, rng.uniform(0.012, 0.03), rng.uniform(0.015, 0.045)))

def depth_edge(s, u):
    """profondeur du bord bas en fonction de u (-1..1) : sinusoïde de dents pointues."""
    pts = [(-1, 0.0), (s.sa, s.a), (0.0, 0.0), (s.sb, s.b), (1, 0.0)]
    for (u0, d0), (u1, d1) in zip(pts, pts[1:]):
        if u0 <= u <= u1:
            return d0 + (d1 - d0) * (u - u0) / max(u1 - u0, 1e-6)
    return 0.0

def largeur(s, t):
    return (s.pos(1, t) - s.pos(-1, t)).length

# ---------------------------------------------------------------- modèle léger
low_v, low_f, low_uv, low_obj = [], [], [], []
bboxes = []
for si, s in enumerate(strips):
    Lm = s.L
    rows = [0.0, 0.30 * Lm, 0.64 * Lm, Lm]
    idx = {}
    loc = []
    def add(u, t, extra=0.0):
        p = s.pos(u, t + extra) if extra == 0 else s.pos(u, t)
        loc.append((p, u, t))
        return len(loc) - 1
    grid = [[add(u, t) for u in (-1, 0, 1)] for t in rows]
    tip_a = add(s.sa, Lm + s.a)
    tip_b = add(s.sb, Lm + s.b)
    faces = []
    for r in range(3):
        for c in range(2):
            a, b, c2, d = grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]
            faces.append((a, b, c2)); faces.append((a, c2, d))
    faces.append((grid[3][0], tip_a, grid[3][1]))
    faces.append((grid[3][1], tip_b, grid[3][2]))
    # UV métriques locales (m) : u = abscisse curviligne en travers (centrée), v = t
    uvl = []
    for p, u, t in loc:
        w = largeur(s, min(t, Lm)) if t <= Lm else largeur(s, Lm)
        uvl.append((u * w * 0.5, t))
    s.loc, s.faces, s.uvl = loc, faces, uvl
    wmax = max(abs(a) for a, _ in uvl) * 2
    hmax = max(b for _, b in uvl)
    s.size = (wmax, hmax)

# empaquetage en étagères
order = sorted(range(len(strips)), key=lambda i: -strips[i].size[1])
x = y = rowh = 0
for i in order:
    s = strips[i]
    w = int(math.ceil(s.size[0] * DENS)) + 2 * PAD
    h = int(math.ceil(s.size[1] * DENS)) + 2 * PAD
    if x + w > AW:
        x = 0; y += rowh; rowh = 0
    s.ox, s.oy = x, y
    s.pw, s.ph_ = w, h
    x += w; rowh = max(rowh, h)
HAUT = y + rowh
print("ATLAS hauteur utilisée", HAUT, "px sur", AH)
assert HAUT <= AH, "atlas trop petit : %d" % HAUT

def mk_obj(nom, verts, faces, uvs=None):
    me = bpy.data.meshes.new(nom)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    ob = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
objs_low = {}
tri_uvs = []     # (u0,v0,u1,v1,u2,v2) en texels (origine haut-gauche), pour le raster de t et de masque
for kind in ("jupe", "cape"):
    verts, faces, uvs = [], [], []
    for si, s in enumerate(strips):
        if s.kind != kind:
            continue
        base = len(verts)
        for (p, u, t), (ul, vl) in zip(s.loc, s.uvl):
            verts.append(G2B(p))
            px = s.ox + PAD + (ul + s.size[0] * 0.5) * DENS
            py = s.oy + PAD + vl * DENS
            uvs.append((px, py, t, u, si))
        for f in s.faces:
            faces.append(tuple(base + k for k in f))
    ob = mk_obj("lambeaux_" + kind, verts, faces)
    uvl = ob.data.uv_layers.new(name="UV")
    for poly in ob.data.polygons:
        for li in poly.loop_indices:
            vi = ob.data.loops[li].vertex_index
            px, py = uvs[vi][0], uvs[vi][1]
            uvl.data[li].uv = (px / AW, 1.0 - py / AH)     # Blender : v vers le haut
    for poly in ob.data.polygons:
        tri_uvs.append([uvs[ob.data.loops[li].vertex_index] for li in poly.loop_indices])
    for p in ob.data.polygons:
        p.use_smooth = False
    objs_low[kind] = ob
ntris_low = sum(len(o.data.polygons) for o in objs_low.values())
print("TRIANGLES léger :", ntris_low)

# ---------------------------------------------------------------- modèle détaillé
def noise1(a):
    return math.sin(a * 12.9898 + 1.7) * 43758.5453 % 1.0

det_verts, det_faces = [], []
inside_fns = []
for s in strips:
    hw = largeur(s, s.L * 0.5) * 0.5
    ncol = 14
    step = 0.011
    nrow = int((s.L + s.a + 0.06) / step) + 1
    gid = {}
    def inside(u, t, s=s, hw=hw):
        e = s.L + depth_edge(s, u) * 1.0
        # dents secondaires effilochées
        e += 0.012 * (abs(((u * hw) / 0.012) % 2.0 - 1.0) - 0.5) * 2 + 0.01 * noise1(u * 17 + s.ph)
        if t > e:
            return False
        for (hu, ht, ru, rt) in s.trous:
            if ((u - hu) * hw / ru) ** 2 + ((t - ht) / rt) ** 2 < 1.0:
                return False
        return True
    inside_fns.append(inside)
    def dv(u, t):
        p = s.pos(u, t)
        k = t / s.L
        out = s.dir(p)
        f = 0.006 * math.sin((u * hw) / 0.022 * math.tau + s.ph) * min(1.0, t / 0.05)
        f += 0.0035 * math.sin(u * 7.3 + t * 21.0 + s.ph) * k
        f += 0.014 * (max(k - 0.7, 0) / 0.3) ** 2 * math.sin(s.ph * 3 + u)     # ourlet qui se roule
        return p + out * f
    def vid(i, j):
        if (i, j) not in gid:
            u = -1 + 2 * i / ncol
            t = min(j * step, s.L + s.a + 0.05)
            gid[(i, j)] = len(det_verts)
            det_verts.append(G2B(dv(u, t)))
        return gid[(i, j)]
    for i in range(ncol):
        for j in range(nrow - 1):
            uc = -1 + 2 * (i + 0.5) / ncol
            tc = (j + 0.5) * step
            if inside(uc, tc):
                a, b, c, d = vid(i, j), vid(i + 1, j), vid(i + 1, j + 1), vid(i, j + 1)
                det_faces.append((a, b, c, d))
det = mk_obj("detail", det_verts, det_faces)
for p in det.data.polygons:
    p.use_smooth = True
bpy.context.view_layer.objects.active = det
det.select_set(True)
mod = det.modifiers.new("sol", "SOLIDIFY")
mod.thickness = 0.004
mod.offset = 0.0
bpy.ops.object.modifier_apply(modifier="sol")
print("TRIANGLES détail environ :", sum(len(p.vertices) - 2 for p in det.data.polygons))

# ---------------------------------------------------------------- bake
scene.render.engine = 'CYCLES'
try:
    scene.cycles.device = 'CPU'
except Exception:
    pass
scene.cycles.samples = 48
scene.cycles.use_denoising = False
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.light_settings.distance = 0.12
bk = scene.render.bake
bk.use_selected_to_active = True
bk.cage_extrusion = 0.02
bk.max_ray_distance = 0.06
bk.margin = 6
bk.margin_type = 'EXTEND'
bk.use_clear = True

def image(nom):
    im = bpy.data.images.new(nom, AW, AH, alpha=False, float_buffer=True)
    im.colorspace_settings.name = 'Non-Color'
    return im

def mat_emission(nom, mode):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    em = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    if mode == "point":
        g = nt.nodes.new("ShaderNodeNewGeometry")
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.40
        ramp.color_ramp.elements[1].position = 0.60
        nt.links.new(g.outputs["Pointiness"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
    else:
        em.inputs["Color"].default_value = (1, 1, 1, 1)
    nt.links.new(em.outputs[0], out.inputs[0])
    return m

def bake_pass(type_, im, mat_detail):
    det.data.materials.clear()
    det.data.materials.append(mat_detail)
    low.data.materials.clear()
    m = bpy.data.materials.new("bk")
    m.use_nodes = True
    nt = m.node_tree
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = im
    nt.nodes.active = tn
    low.data.materials.append(m)
    # les deux pièces basses sont cuites ensemble dans la même image : on les fusionne le temps du bake
    bpy.ops.object.select_all(action='DESELECT')
    det.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type=type_)

# objet léger unique pour le bake (fusion des deux), ré-éclaté ensuite pour l'export
bpy.ops.object.select_all(action='DESELECT')
for lo in objs_low.values():
    lo.select_set(True)
bpy.context.view_layer.objects.active = objs_low["jupe"]
export_meshes = {k: v.data.copy() for k, v in objs_low.items()}
bpy.ops.object.join()
low = bpy.context.view_layer.objects.active
low.name = "low_bake"

im_ao = image("ao"); im_pt = image("pt"); im_cv = image("cv")
bake_pass('AO', im_ao, mat_emission("e0", "white"))
bake_pass('EMIT', im_pt, mat_emission("e1", "point"))
bake_pass('EMIT', im_cv, mat_emission("e2", "white"))

def lire(im):
    a = np.array(im.pixels[:], dtype=np.float32).reshape(AH, AW, 4)
    return a[:, :, 0]      # origine bas-gauche

ao = lire(im_ao); pt = lire(im_pt); cv = lire(im_cv)

# rasters analytiques : masque d'îlots (union des triangles UV) et t (distance au sommet), en origine bas-gauche
mask = np.zeros((AH, AW), bool)
tmap = np.zeros((AH, AW), np.float32)
umap = np.zeros((AH, AW), np.float32)
smap = np.full((AH, AW), -1, np.int32)
def rast(tri):
    (x0, y0, t0, u0, k0), (x1, y1, t1, u1, k1), (x2, y2, t2, u2, k2) = tri
    xmin = int(max(0, math.floor(min(x0, x1, x2)))); xmax = int(min(AW - 1, math.ceil(max(x0, x1, x2))))
    ymin = int(max(0, math.floor(min(y0, y1, y2)))); ymax = int(min(AH - 1, math.ceil(max(y0, y1, y2))))
    den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
    if abs(den) < 1e-9:
        return
    for yy in range(ymin, ymax + 1):
        for xx in range(xmin, xmax + 1):
            px, py = xx + 0.5, yy + 0.5
            a = ((y1 - y2) * (px - x2) + (x2 - x1) * (py - y2)) / den
            b = ((y2 - y0) * (px - x2) + (x0 - x2) * (py - y2)) / den
            c = 1 - a - b
            e = -0.6 / max(1.0, abs(den)) ** 0.5
            if a >= e and b >= e and c >= e:
                row = AH - 1 - yy
                mask[row, xx] = True
                tmap[row, xx] = a * t0 + b * t1 + c * t2
                umap[row, xx] = a * u0 + b * u1 + c * u2
                smap[row, xx] = k0
for tri in tri_uvs:
    rast(tri)

# couverture ANALYTIQUE (les rayons du bake traversent les autres couches) : mêmes formes que le détail (dents, trous)
trous = np.zeros_like(mask)
for row in range(AH):
    for col in range(AW):
        if mask[row, col]:
            if not bool(inside_fns[int(smap[row, col])](float(umap[row, col]), float(tmap[row, col]))):
                trous[row, col] = True
alpha = mask & ~trous
print("couverture : %d px ilots, %d px troués (%.1f %%)" % (mask.sum(), (mask & trous).sum(), 100.0 * (mask & trous).sum() / max(1, mask.sum())))

# pointiness -> courbure : 0..1 (0.5 neutre)
out = np.zeros((AH, AW, 4), np.float32)
out[:, :, 0] = np.clip(ao, 0, 1)
out[:, :, 1] = np.clip(pt, 0, 1)
out[:, :, 2] = np.clip(tmap / 1.2, 0, 1)
# A : 0 = trou / hors îlot, 1.0 = jupe, 0.5 = cape
kind_arr = np.array([1.0 if st.kind == "jupe" else 0.5 for st in strips] + [0.0], np.float32)
out[:, :, 3] = np.where(alpha, kind_arr[smap], 0.0)
APER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "apercus_draugr")
os.makedirs(APER, exist_ok=True)
def apercu(nom, plan):
    im2 = bpy.data.images.new(nom, AW, AH, alpha=False)
    im2.colorspace_settings.name = 'Non-Color'
    rgba = np.stack([plan, plan, plan, np.ones_like(plan)], -1)
    im2.pixels = rgba.reshape(-1).tolist()
    im2.filepath_raw = os.path.join(APER, nom + ".png"); im2.file_format = 'PNG'; im2.save()
apercu("ao", out[:, :, 0]); apercu("pointiness", out[:, :, 1]); apercu("alpha", out[:, :, 3]); apercu("t", out[:, :, 2])
for c, nm in enumerate("AO pointiness t alpha".split()):
    v = out[:, :, c][mask]
    print("canal", nm, "min %.2f p10 %.2f med %.2f p90 %.2f max %.2f" % (v.min(), np.percentile(v, 10), np.median(v), np.percentile(v, 90), v.max()))
png = bpy.data.images.new("out", AW, AH, alpha=True, float_buffer=False)
png.colorspace_settings.name = 'Non-Color'
png.pixels = out.reshape(-1).tolist()
png.filepath_raw = SORTIE + "/lambeaux_bake.png"
png.file_format = 'PNG'
png.save()

# ---------------------------------------------------------------- export glb (pièces légères, UV Blender -> glTF)
bpy.ops.object.select_all(action='DESELECT')
for k, me in export_meshes.items():
    ob = bpy.data.objects.new("lambeaux_" + k, me)
    scene.collection.objects.link(ob)
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=SORTIE + "/lambeaux.glb", export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
                          export_materials='NONE', export_normals=True, export_texcoords=True)
# sources
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "draugr_lambeaux.blend"))
print("OK triangles léger", ntris_low)
