# Ennemis Tripo : extraction du personnage de FACE d'une feuille de 3 vues (3 persos côte à côte, ~1,9 M tris, textures 4096), allègement ADAPTATIF
# (décimation + UV neufs + cuisson Cycles de la couleur sur une texture 512), mise à l'échelle, pieds à z=0, face -Y.
#   blender.exe -b --python tripo_ennemi_prep.py -- --modele=draugr|archer|squelette|gobelin [--taille=1.85] [--tris=6000] [--tex=512] [--gain=1.3]
#                                                   [--source=<glb>] [--debug=<dossier de rendus>]
# Entrée : _travail/src/<modele>.glb (non versionné : 65 Mo). Sortie : assets/pnj/ennemis/tripo_<modele>.glb (+ PNG de la texture).
# Bug récurrent Tripo : textures trop sombres -> --gain éclaircit (multiplicateur en espace sRGB, plafonné), yeux bleus lumineux nettoyés en bleu franc
# (reconnus par le shader d'ennemi, voir scripts/ennemi_tripo.gd).
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=""):
    return next((a.split("=", 1)[1] for a in ARGS if a.startswith("--" + n + "=")), d)
BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELE = arg("modele", "draugr")
SRC = arg("source", os.path.join(BASE, "_travail", "src", MODELE + ".glb"))
OUTD = os.path.join(BASE, "assets", "pnj", "ennemis")
os.makedirs(OUTD, exist_ok=True)
OUT = os.path.join(OUTD, "tripo_%s.glb" % MODELE)
TAILLE = float(arg("taille", "1.85"))
TRIS = int(arg("tris", "6000"))
TEX = int(arg("tex", "512"))
GAIN = float(arg("gain", "1.0"))
SS = 2

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
hp = next(o for o in bpy.data.objects if o.type == "MESH")
me = hp.data
P = np.empty(len(me.vertices) * 3, dtype=np.float32); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)

# 1. personnage de face = celui de gauche : coupure au premier vide en x après 0,2 m de matière
h, e = np.histogram(P[:, 0], bins=np.arange(P[:, 0].min(), P[:, 0].max() + 0.004, 0.002))
i0 = int(0.2 / 0.002)
vide = [i for i in range(i0, len(h)) if h[i] == 0]
cut = float(e[vide[0]]) + 0.001 if vide else float(P[:, 0].min() + 0.33)
print("coupure x = %.3f" % cut)
bm = bmesh.new(); bm.from_mesh(me)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x > cut], context="VERTS")
bm.to_mesh(me); bm.free()
P = np.empty(len(me.vertices) * 3, dtype=np.float32); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
print("personnage de face : %d sommets, %d faces, bbox" % (len(P), len(me.polygons)), P.min(0).round(3), P.max(0).round(3))

# 2. centrage (bottes) et échelle
bas = P[P[:, 2] < 0.02 * P[:, 2].max()]
cx, cy = (bas[:, 0].min() + bas[:, 0].max()) / 2, (bas[:, 1].min() + bas[:, 1].max()) / 2
s = TAILLE / float(P[:, 2].max())
P2 = (P - np.array([cx, cy, 0.0])) * s
me.vertices.foreach_set("co", P2.astype(np.float32).ravel()); me.update()
print("échelle x%.3f -> %.2f m" % (s, TAILLE))

# 3. allégement : copie décimée (collapse), puis UV neufs
lp = hp.copy(); lp.data = hp.data.copy(); lp.name = "lp"
bpy.context.scene.collection.objects.link(lp)
for o in bpy.context.selected_objects: o.select_set(False)
bpy.context.view_layer.objects.active = lp; lp.select_set(True)
ntri = len(me.polygons)
md = lp.modifiers.new("dec", "DECIMATE"); md.decimate_type = "COLLAPSE"; md.ratio = min(1.0, TRIS / (ntri * 1.0)); md.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier="dec")
lme = lp.data
print("décimé : %d tris (cible %d)" % (len(lme.polygons), TRIS))
# cohérence : plus de sommets isolés
bm = bmesh.new(); bm.from_mesh(lme)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(lme); bm.free()
lme.materials.clear()
while lme.uv_layers: lme.uv_layers.remove(lme.uv_layers[0])
lme.uv_layers.new(name="UVMap")
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(70), island_margin=0.004, area_weight=0.6, correct_aspect=True, scale_to_bounds=True)
bpy.ops.object.mode_set(mode="OBJECT")

# 4. cuisson : couleur du maillage haute définition -> texture 1024 (réduite en 512)
R = TEX * SS
img = bpy.data.images.new("bake", R, R, alpha=False)
mat = bpy.data.materials.new("lpm"); mat.use_nodes = True
nt = mat.node_tree
tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img; nt.nodes.active = tn
lme.materials.append(mat)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"; sc.cycles.samples = 4; sc.cycles.use_denoising = False
b = sc.render.bake
b.use_selected_to_active = True; b.cage_extrusion = 0.03 * TAILLE / 1.85; b.max_ray_distance = 0.0
b.margin = 8; b.margin_type = "EXTEND"; b.use_clear = True
b.target = "IMAGE_TEXTURES"
for o in bpy.context.selected_objects: o.select_set(False)
hp.select_set(True); lp.select_set(True)
bpy.context.view_layer.objects.active = lp
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_selected_to_active=True, cage_extrusion=b.cage_extrusion, margin=8, margin_type="EXTEND")
px = np.empty(R * R * 4, dtype=np.float32); img.pixels.foreach_get(px); px = px.reshape(R, R, 4)[..., :3]
# réduction 2x2 (moyenne en linéaire déjà : l'image de cuisson est en couleur non-colour), gain, yeux
px = px.reshape(TEX, SS, TEX, SS, 3).mean(axis=(1, 3))
def srgb(a): return np.where(a <= 0.0031308, a * 12.92, 1.055 * np.power(np.clip(a, 1e-8, 1), 1 / 2.4) - 0.055)
def lin(a): return np.where(a <= 0.04045, a / 12.92, np.power((a + 0.055) / 1.055, 2.4))
print("image cuite : moyenne lum. %.3f" % float(px.mean()))
# l'image cuite est dans l'espace de l'image (sRGB, octets) : le gain se fait directement dessus
out = np.clip(px * GAIN, 0, 1)
bleu = (px[..., 2] > 0.45) & (px[..., 2] > 1.5 * px[..., 0]) & (px[..., 2] > 1.1 * px[..., 1])
print("texels d'yeux bleus :", int(bleu.sum()))
out[bleu] = (0.35, 0.75, 1.0)
out = np.flipud(out) if False else out
rgba = np.concatenate([out, np.ones((TEX, TEX, 1), np.float32)], axis=2)
png = os.path.join(OUTD, "tripo_%s_%d.png" % (MODELE, TEX))
tmp = bpy.data.images.new("tmp", TEX, TEX, alpha=False)
tmp.colorspace_settings.name = img.colorspace_settings.name
tmp.pixels.foreach_set(rgba.ravel()); tmp.filepath_raw = png; tmp.file_format = "PNG"; tmp.save()
nimg = bpy.data.images.load(png); nimg.name = "tripo_%s_%d" % (MODELE, TEX); nimg.pack()
print("PNG", png)

# 5. matériau final, maillage final (low poly seul)
bpy.data.objects.remove(hp)
lme.materials.clear()
m2 = bpy.data.materials.new("tripo_" + MODELE); m2.use_nodes = True
n2 = m2.node_tree
bs = next(n for n in n2.nodes if n.type == "BSDF_PRINCIPLED")
ti = n2.nodes.new("ShaderNodeTexImage"); ti.image = nimg; ti.interpolation = "Closest"
n2.links.new(ti.outputs["Color"], bs.inputs["Base Color"]); bs.inputs["Roughness"].default_value = 1.0
lme.materials.append(m2)
for p in lme.polygons: p.use_smooth = True
lp.name = "tripo_" + MODELE
for o in list(bpy.data.objects):
    if o != lp: bpy.data.objects.remove(o)
if arg("debug"):
    os.makedirs(arg("debug"), exist_ok=True)
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"; sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 400, 640
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.3, 0.3, 0.35)
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"; cam.data.ortho_scale = TAILLE * 1.4; sc.camera = cam
    for nom, deg in (("face", 0), ("profil", 90), ("dos", 180)):
        r = math.radians(deg)
        c0 = Vector((0, 0, TAILLE * 0.55))
        cam.location = c0 + Vector((math.sin(r), -math.cos(r), 0)) * 6
        cam.rotation_euler = (c0 - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(arg("debug"), nom + ".png")
        bpy.ops.render.render(write_still=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_animations=False)
print("EXPORT OK", OUT, "tris", len(lme.polygons))
