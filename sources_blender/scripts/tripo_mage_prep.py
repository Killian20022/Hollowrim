# Mage Tripo : extraction du personnage de FACE d'une feuille de 3 vues + mise à l'échelle + UV repackés + texture 512 recuite.
#   blender.exe -b --python tripo_mage_prep.py -- [--taille=1.82] [--tex=512] [--debug=<dossier de rendus>]
# Entrée : assets/essai_tripo/mage_tripo_source.glb (modèle de l'utilisateur : 3 personnages côte à côte = face / profil / dos, 9 648 tris,
# texture 4096 partagée). Sortie : assets/pnj/tripo_mage.glb (UN personnage, pieds à z=0, face -Y, centré en x/y, 1,82 m, texture 512 empaquetée).
# Le maillage n'est PAS décimé : le personnage de face ne fait que ~3 260 tris (budget PNJ 5-6 k) ; décimer ferait perdre capuche et visage.
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=""):
    return next((a.split("=", 1)[1] for a in ARGS if a.startswith("--" + n + "=")), d)
BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(BASE, "assets", "essai_tripo", "mage_tripo_source.glb")
OUT = os.path.join(BASE, "assets", "pnj", "tripo_mage.glb")
TAILLE = float(arg("taille", "1.82"))
TEX = int(arg("tex", "512"))
SS = 2      # sur-échantillonnage du recuit

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ob = next(o for o in bpy.data.objects if o.type == "MESH")
me = ob.data
src_img = next(n.image for n in me.materials[0].node_tree.nodes if n.type == "TEX_IMAGE")
W0, H0 = src_img.size
tex = np.empty(W0 * H0 * 4, dtype=np.float32)
src_img.pixels.foreach_get(tex)
tex = tex.reshape(H0, W0, 4)

# 1. personnage de face = celui de gauche (x < -0.17)
bm = bmesh.new(); bm.from_mesh(me)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if sum(v.co.x for v in f.verts) / len(f.verts) >= -0.17], context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(me); bm.free()
P = np.array([v.co[:] for v in me.vertices])
print("personnage de face :", len(me.vertices), "sommets,", len(me.polygons), "tris", "bbox", P.min(0).round(3), P.max(0).round(3))

# 2. centrage (bottes) et échelle
bas = P[P[:, 2] < 0.05]
cx, cy = (bas[:, 0].min() + bas[:, 0].max()) / 2, (bas[:, 1].min() + bas[:, 1].max()) / 2
s = TAILLE / float(P[:, 2].max())
for v in me.vertices:
    v.co = Vector(((v.co.x - cx) * s, (v.co.y - cy) * s, v.co.z * s))
print("échelle x%.3f" % s)

# 3. UV repackés (calque 2), puis recuit de la texture
old = me.uv_layers[0]
new = me.uv_layers.new(name="pack")
for i in range(len(me.loops)):
    new.data[i].uv = old.data[i].uv
# îlots (même sommet + même UV), puis rangement par étagères à densité commune (pack_islands de Blender renvoie des NaN sur ce maillage)
UVo = np.array([old.data[i].uv[:] for i in range(len(me.loops))])
par = list(range(len(me.polygons)))
def rac(i):
    while par[i] != i:
        par[i] = par[par[i]]; i = par[i]
    return i
cle = {}
for p in me.polygons:
    for li in p.loop_indices:
        k = (me.loops[li].vertex_index, round(UVo[li][0], 4), round(UVo[li][1], 4))
        if k in cle:
            par[rac(p.index)] = rac(cle[k])
        else:
            cle[k] = p.index
isl = {}
for p in me.polygons:
    isl.setdefault(rac(p.index), []).extend(p.loop_indices)
boites = []
for r_, lis in isl.items():
    q = UVo[lis]
    boites.append((r_, lis, q.min(0), q.max(0) - q.min(0)))
print("îlots UV :", len(boites))
MARGE = 3.0 / TEX
def ranger(f):
    pos = {}
    x = y = hh = 0.0
    for r_, lis, mn, sz in sorted(boites, key=lambda b: -b[3][1]):
        w, h = sz[0] * f + MARGE, sz[1] * f + MARGE
        if x + w > 1.0:
            x, y, hh = 0.0, y + hh, 0.0
        if y + h > 1.0 or w > 1.0:
            return None
        pos[r_] = (x, y)
        x += w; hh = max(hh, h)
    return pos
lo, hi = 0.001, 4.0
for _ in range(30):
    mid = (lo + hi) / 2
    if ranger(mid): lo = mid
    else: hi = mid
f = lo * 0.99
pos = ranger(f)
UVn = np.zeros_like(UVo)
for r_, lis, mn, sz in boites:
    ox, oy = pos[r_]
    UVn[lis] = (UVo[lis] - mn) * f + np.array([ox + MARGE / 2, oy + MARGE / 2])
for i in range(len(me.loops)):
    new.data[i].uv = UVn[i]
print("densité UV x%.3f, UV neufs : min" % f, UVn.min(0).round(3), "max", UVn.max(0).round(3))
R = TEX * SS
out = np.zeros((R, R, 4), dtype=np.float32)
cov = np.zeros((R, R), dtype=bool)
for p in me.polygons:
    li = list(p.loop_indices)
    for k in range(1, len(li) - 1):
        tri = [li[0], li[k], li[k + 1]]
        a, b, c = UVn[tri] * R
        x0, x1 = int(max(0, math.floor(min(a[0], b[0], c[0])))), int(min(R - 1, math.ceil(max(a[0], b[0], c[0]))))
        y0, y1 = int(max(0, math.floor(min(a[1], b[1], c[1])))), int(min(R - 1, math.ceil(max(a[1], b[1], c[1]))))
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-9:
            continue
        l1 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / d
        l2 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / d
        l3 = 1 - l1 - l2
        m = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
        if not m.any():
            continue
        oa, ob_, oc = UVo[tri]
        u = np.clip(l1[m] * oa[0] + l2[m] * ob_[0] + l3[m] * oc[0], 0, 0.9999)
        v = np.clip(l1[m] * oa[1] + l2[m] * ob_[1] + l3[m] * oc[1], 0, 0.9999)
        ys_, xs_ = gy[m].astype(int), gx[m].astype(int)
        out[ys_, xs_] = tex[(v * H0).astype(int), (u * W0).astype(int)]
        cov[ys_, xs_] = True
# réduction (moyenne sur les texels couverts), puis dilatation de 4 texels (pas de bord noir au filtrage)
cf = cov.astype(np.float32)
def pool(a):
    return a.reshape(TEX, SS, TEX, SS, *a.shape[2:]).sum(axis=(1, 3))
cs = pool(cf)
img = pool(out * cf[..., None]) / np.maximum(cs, 1e-6)[..., None]
ok = cs > 0
for _ in range(4):
    acc = np.zeros_like(img); n = np.zeros(ok.shape)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh = np.roll(np.roll(img, dy, 0), dx, 1); sm = np.roll(np.roll(ok, dy, 0), dx, 1)
        acc += sh * sm[..., None]; n += sm
    nw = (~ok) & (n > 0)
    img[nw] = acc[nw] / n[nw][:, None]
    ok = ok | nw
img[..., 3] = 1.0
print("couverture texture : %.1f %%" % (100 * float((cs > 0).mean())))
png = os.path.join(BASE, "assets", "pnj", "tripo_mage_%d.png" % TEX)
tmp = bpy.data.images.new("tmp", TEX, TEX, alpha=False)
tmp.pixels.foreach_set(img.astype(np.float32).ravel())
tmp.filepath_raw = png; tmp.file_format = "PNG"; tmp.save()
nimg = bpy.data.images.load(png)
nimg.name = "tripo_mage_%d" % TEX
nimg.pack()

# 4. calque UV unique (le neuf) + matériau simple
me.uv_layers.remove(old)
me.uv_layers[0].name = "UVMap"
mat = bpy.data.materials.new("tripo_mage")
mat.use_nodes = True
nt = mat.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = nimg; ti.interpolation = "Closest"
nt.links.new(ti.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 1.0
me.materials.clear(); me.materials.append(mat)
for p in me.polygons:
    p.use_smooth = True
ob.name = "tripo_mage"
for o in list(bpy.data.objects):
    if o != ob:
        bpy.data.objects.remove(o)
if arg("debug"):
    os.makedirs(arg("debug"), exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"; sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 400, 640
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.3, 0.3, 0.35)
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.6; sc.camera = cam
    for nom, deg in (("face", 0), ("profil", 90), ("dos", 180)):
        r = math.radians(deg)
        cam.location = Vector((0, 0, 1.1)) + Vector((math.sin(r), -math.cos(r), 0)) * 6
        cam.rotation_euler = (Vector((0, 0, 1.1)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(arg("debug"), nom + ".png")
        bpy.ops.render.render(write_still=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_animations=False)
print("EXPORT OK", OUT, "tris", len(me.polygons))
