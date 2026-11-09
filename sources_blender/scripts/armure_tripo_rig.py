# Armure dorée Tripo -> armure COMPLÈTE habillée sur le squelette humain du jeu (65 os de homme_vetu.glb).
#   blender.exe -b --python armure_tripo_rig.py -- [--source=<planche.glb>] [--cache=<pieces.blend>] [--etape=ajuster|tout] [--debug=<dossier>]
# Source : « fantasy armor 3d model.glb » (Tripo) = PLANCHE de présentation, chaque pièce 3 fois (face, profil, dos), 1 M de sommets.
# On garde la vue de FACE de chaque pièce (modèle 3D complet tourné vers -y), on la pose à l'échelle d'un humain de 1,81 m (pose de repos
# des bras abaissée en A, l'angle des manches de la cuirasse), puis : allègement adaptatif, atlas 512 recuit, miroir des pièces paires
# (gantelet, jambière, botte), poids transférés du corps (lissés), export d'un GLB habillé (assets/essai_tripo/armure_complete.glb).
# Repère Blender : x = gauche du perso (os *_l), -y = devant, z = haut.
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=""):
    return next((a.split("=", 1)[1] for a in ARGS if a.startswith("--" + n + "=")), d)
BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = arg("source", r"C:\Users\lopezk19\Downloads\fantasy armor 3d model.glb")
CACHE = arg("cache", os.path.join(os.environ.get("TEMP", "C:\\Temp"), "armure_tripo_pieces.blend"))
HUMAIN = os.path.join(BASE, "assets", "modeles", "humains", "homme_vetu.glb")
OUT_GLB = arg("sortie", os.path.join(BASE, "assets", "essai_tripo", "armure_complete.glb"))
ETAPE = arg("etape", "tout")
DEBUG = arg("debug", "")

# Boîtes (x, z) de la vue de face de chaque pièce sur la planche.
BOITES = {"casque": (-0.495, -0.37, 0.44, 1), "cuirasse": (-0.055, 0.17, 0.44, 1), "gantelet": (-0.48, -0.36, 0.15, 0.44),
          "jambiere": (0.05, 0.16, 0.15, 0.44), "botte": (-0.195, -0.10, -1, 0.15)}
# Budget de triangles par pièce UNIQUE (les pièces paires sont doublées par miroir) : ~7 500 au total.
BUDGET = {"casque": 1300, "cuirasse": 2900, "gantelet": 750, "jambiere": 700, "botte": 400}
ALPHA = float(arg("alpha", "74"))     # bras abaissés de ALPHA degrés sous l'horizontale (angle des manches de la cuirasse)

# ---------------------------------------------------------------- 0. pièces de face (cache)
def extraire():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SOURCE)
    src = next(o for o in bpy.data.objects if o.type == "MESH")
    P = np.empty(len(src.data.vertices) * 3); src.data.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
    for nom, (x0, x1, z0, z1) in BOITES.items():
        sel = (P[:, 0] > x0) & (P[:, 0] < x1) & (P[:, 2] >= z0) & (P[:, 2] < z1)
        o = src.copy(); o.data = src.data.copy(); o.name = nom; o.data.name = nom
        bpy.context.collection.objects.link(o)
        bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not sel[v.index]], context="VERTS")
        bm.to_mesh(o.data); bm.free()
    bpy.data.objects.remove(src)
    for im in bpy.data.images:
        if im.size[0] > 0:
            im.pack()
    bpy.ops.wm.save_as_mainfile(filepath=CACHE)

if not os.path.exists(CACHE):
    extraire()
bpy.ops.wm.open_mainfile(filepath=CACHE)
PIECES = {o.name: o for o in bpy.data.objects if o.type == "MESH"}

def pts(o):
    P = np.empty(len(o.data.vertices) * 3); o.data.vertices.foreach_get("co", P); return P.reshape(-1, 3)
def set_pts(o, P):
    o.data.vertices.foreach_set("co", P.astype(np.float32).ravel()); o.data.update()

# ---------------------------------------------------------------- 1. squelette : bras abaissés en A, appliqué au repos
bpy.ops.import_scene.gltf(filepath=HUMAIN)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
corps = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("SuperHero"))
for o in list(bpy.data.objects):
    if o.type == "MESH" and o not in PIECES.values() and o != corps:
        bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
for s, sg in (("l", 1), ("r", -1)):
    pb = arm.pose.bones["upperarm_" + s]
    h = arm.matrix_world @ pb.head
    q = Matrix.Rotation(math.radians(ALPHA) * sg, 4, "Y")
    pb.matrix = Matrix.Translation(h) @ q @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.view_layer.objects.active = corps
for m in corps.modifiers:
    if m.type == "ARMATURE":
        bpy.ops.object.modifier_apply(modifier=m.name)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
bpy.ops.pose.armature_apply()
bpy.ops.object.mode_set(mode="OBJECT")
CORPS_P = np.array([v.co[:] for v in corps.data.vertices])
B = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones}
def tete(n): return np.array(B[n][0][:])
def queue(n): return np.array(B[n][1][:])

# ---------------------------------------------------------------- 2. pose des pièces (côté gauche pour les paires)
def normaliser(o):
    """Centre la pièce : x, y au milieu de la boîte, z min à 0."""
    P = pts(o)
    c = np.array([(P[:, 0].min() + P[:, 0].max()) / 2, (P[:, 1].min() + P[:, 1].max()) / 2, P[:, 2].min()])
    return P - c

def poser_casque(o):
    P = normaliser(o)
    s = float(arg("s_casque", "2.15"))
    P *= s
    # base de la tête : le menton ; le casque descend sur la nuque (bas du casque ~ 1,50)
    P += np.array([0, float(arg("y_casque", "-0.005")), float(arg("z_casque", "1.46"))])
    set_pts(o, P)

def poser_cuirasse(o):
    P = normaliser(o)          # z 0 = bas des tassettes ; taille (ceinture) à z 0,06 ; col à 0,205
    sx, sy, sz = (float(v) for v in arg("s_cuirasse", "4.1,3.7,4.0").split(","))
    P *= np.array([sx, sy, sz])
    P += np.array([0, float(arg("y_cuirasse", "0.005")), float(arg("z_cuirasse", "0.80"))])
    set_pts(o, P)

def poser_gantelet(o):
    # source = main DROITE pendante (doigts vers -z, dos de la main vers -y, pouce vers +x) -> main gauche par miroir x,
    # puis doigts le long de l'avant-bras gauche (abaissé de ALPHA), dos de la main vers le haut/l'extérieur
    P = normaliser(o)
    P[:, 0] *= -1                                            # main gauche
    z1 = P[:, 2].max()
    s = float(arg("s_gantelet", "2.5"))
    P *= s
    P[:, 2] -= z1 * s                                       # haut du canon (coude) à z 0, doigts vers -z
    # repère : doigts (-z) -> axe de l'avant-bras ; dos de la main (-y) -> haut/extérieur (perpendiculaire dans le plan frontal)
    coude, poignet = tete("lowerarm_l"), tete("hand_l")
    ax = (poignet - coude) / np.linalg.norm(poignet - coude)
    up = np.array([0, 0, 1.0]); dos = up - ax * ax.dot(up); dos /= np.linalg.norm(dos)
    av = np.cross(ax, dos)                                   # direction perpendiculaire restante
    # colonnes : image de (x, y, z) source
    #   -z (doigts) -> ax ; -y (dos) -> dos ; x (pouce, côté extérieur de la main gauche après miroir... ) -> complète le repère direct
    R = np.column_stack([np.cross(dos, ax) * 1.0, -dos, -ax])   # x' = ?, y -> -dos, z -> -ax
    if np.linalg.det(R) < 0:
        R[:, 0] *= -1
    P = P @ R.T
    P += coude + ax * float(arg("d_gantelet", "-0.08")) + dos * float(arg("h_gantelet", "0.0"))
    set_pts(o, P)

def poser_jambiere(o):
    P = normaliser(o)          # z 0 = bas du pied de la jambière
    zc = float(arg("coupe_jambe", "0.068"))                 # coupe au-dessus du soleret intégré (la botte le remplace)
    bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    garde = P[:, 2] >= zc
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not garde[v.index]], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    P = P[garde]
    # z : cheville (source 0,069) -> 0,20 (dans le revers de la botte), genou (0,142) -> 0,542, haut (0,242) -> 1,0
    ks = [float(v) for v in arg("k_jambe", "0.068,0.142,0.242").split(",")]
    kd = [float(v) for v in arg("k_jambe_d", "0.19,0.53,1.12").split(",")]
    P[:, 2] = np.interp(P[:, 2], ks, kd, left=None, right=None)
    sx, sy = (float(v) for v in arg("s_jambe", "3.25,3.4").split(","))
    P[:, 0] *= sx; P[:, 1] *= sy
    P[:, 0] += tete("thigh_l")[0] + float(arg("x_jambe", "0.0"))
    # axe de la jambière recalé sur celui de la jambe du corps (le mollet est en arrière de la cuisse) : décalage en y lissé par tranche
    C = CORPS_P[(CORPS_P[:, 0] > 0.02) & (CORPS_P[:, 0] < 0.35)]
    zs = np.arange(0.15, 1.05, 0.05); dec = []
    for z in zs:
        c = C[(C[:, 2] >= z - 0.05) & (C[:, 2] < z + 0.05)]; a = P[(P[:, 2] >= z - 0.05) & (P[:, 2] < z + 0.05)]
        dec.append(((c[:, 1].min() + c[:, 1].max()) - (a[:, 1].min() + a[:, 1].max())) / 2 if len(c) and len(a) else np.nan)
    dec = np.array(dec); ok = ~np.isnan(dec)
    dec = np.interp(zs, zs[ok], dec[ok]); dec = np.convolve(np.pad(dec, 2, mode="edge"), np.ones(5) / 5, mode="valid")
    P[:, 1] += np.interp(P[:, 2], zs, dec) + float(arg("y_jambe", "0.0"))
    set_pts(o, P)

def poser_botte(o):
    P = normaliser(o)
    s = float(arg("s_botte", "2.1"))
    P *= s
    P += np.array([tete("foot_l")[0] + float(arg("x_botte", "0.016")), float(arg("y_botte", "0.025")), float(arg("z_botte", "-0.008"))])
    set_pts(o, P)

for nom, f in (("casque", poser_casque), ("cuirasse", poser_cuirasse), ("gantelet", poser_gantelet), ("jambiere", poser_jambiere), ("botte", poser_botte)):
    f(PIECES[nom])
    P = pts(PIECES[nom])
    print("POSE %-9s %7d sommets  min %s  max %s" % (nom, len(P), P.min(0).round(3), P.max(0).round(3)))

def miroir(o, nom):
    m = o.copy(); m.data = o.data.copy(); m.name = nom; m.data.name = nom
    bpy.context.collection.objects.link(m)
    P = pts(m); P[:, 0] *= -1; set_pts(m, P)
    m.data.flip_normals()
    return m

if DEBUG:
    os.makedirs(DEBUG, exist_ok=True)
    for nom in ("gantelet", "jambiere", "botte"):
        miroir(PIECES[nom], nom + "_r")
    mat = bpy.data.materials.new("corps_gris"); mat.diffuse_color = (0.25, 0.3, 0.45, 1)
    corps.data.materials.clear(); corps.data.materials.append(mat)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading; sh.light = "STUDIO"; sh.color_type = "TEXTURE"
    sc.render.resolution_x = 700; sc.render.resolution_y = 900
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.0
    for v, d, c, os_ in (("face", (0, -1, 0), (0, 0, 0.92), 2.0), ("profil", (1, 0, 0), (0, 0, 0.92), 2.0), ("dos", (0, 1, 0), (0, 0, 0.92), 2.0),
                         ("q", (0.7, -0.7, 0.3), (0, 0, 0.92), 2.0), ("jambes", (0.5, -0.85, 0.1), (0.1, 0, 0.5), 1.1), ("bras", (0.3, -0.9, 0.2), (0.45, 0, 1.2), 0.9),
                         ("tete", (0.4, -0.9, 0.1), (0, 0, 1.6), 0.7), ("bras_dos", (0.2, 0.9, 0.3), (0.4, 0, 1.25), 0.9)):
        d = Vector(d).normalized()
        cam.data.ortho_scale = os_
        cam.location = Vector(c) + d * 6
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(DEBUG, "ajuste_%s.png" % v)
        bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DEBUG, "ajuste.blend"))
if ETAPE == "ajuster":
    sys.exit(0)

# ---------------------------------------------------------------- 3. allègement adaptatif (par pièce, budget de triangles)
def bords(o):
    bm = bmesh.new(); bm.from_mesh(o.data)
    n = sum(1 for e in bm.edges if e.is_boundary); bm.free(); return n
HD = {}
for nom, o in PIECES.items():
    h = o.copy(); h.data = o.data.copy(); h.name = nom + "_hd"; bpy.context.collection.objects.link(h); HD[nom] = h
for nom, o in PIECES.items():
    avant = len(o.data.polygons); b0 = bords(o)
    md = o.modifiers.new("dec", "DECIMATE"); md.decimate_type = "COLLAPSE"; md.ratio = BUDGET[nom] / avant
    md.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=md.name)
    print("ALLEGE %-9s %7d -> %5d tris ; arêtes de bord %d -> %d" % (nom, avant, len(o.data.polygons), b0, bords(o)))

# ---------------------------------------------------------------- 4. atlas commun 512 recuit depuis la texture 4K d'origine
for o in bpy.data.objects:
    o.select_set(False)
ordre = ["casque", "cuirasse", "gantelet", "jambiere", "botte"]
for i, nom in enumerate(ordre):
    o = PIECES[nom]
    vg = o.vertex_groups.new(name="piece_" + nom); vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    o.select_set(True)
bpy.context.view_layer.objects.active = PIECES["casque"]
bpy.ops.object.join()
armure = PIECES["casque"]; armure.name = "armure"; armure.data.name = "armure"
uv_src = armure.data.uv_layers[0].name
uv_at = armure.data.uv_layers.new(name="atlas", do_init=True)
armure.data.uv_layers.active = uv_at
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
# îlots d'UV d'origine (copiés de la carte source), mis à densité égale puis tassés dans un atlas neuf
bpy.ops.uv.select_all(action="SELECT")
bpy.ops.uv.average_islands_scale()
bpy.ops.uv.pack_islands(rotate=True, margin=0.004, shape_method="CONCAVE")
bpy.ops.object.mode_set(mode="OBJECT")
mats_src = [m for m in armure.data.materials if m]
def image_src(cle):
    return next(nd.image for m in mats_src for nd in m.node_tree.nodes if nd.type == "TEX_IMAGE" and cle in nd.image.name)
img_src, img_nor = image_src("basecolor"), image_src("normal")
img_nor.colorspace_settings.name = "Non-Color"
# matière de cuisson des pièces HD : couleur de base x éclairage du relief (carte normale, lumière haute de face) -> l'or reste lisible
# sur le maillage allégé (le shader ps1 n'a pas de carte normale)
mhd = bpy.data.materials.new("hd_cuisson"); mhd.use_nodes = True
nt = mhd.node_tree; nt.nodes.clear()
uvn = nt.nodes.new("ShaderNodeUVMap"); uvn.uv_map = uv_src
ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = img_src
tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img_nor
nm = nt.nodes.new("ShaderNodeNormalMap"); nm.uv_map = uv_src
dp = nt.nodes.new("ShaderNodeVectorMath"); dp.operation = "DOT_PRODUCT"; dp.inputs[1].default_value = Vector((0.35, -0.55, 0.76)).normalized()
mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs[1].default_value = -0.3; mr.inputs[2].default_value = 1.0
mr.inputs[3].default_value = float(arg("ombre", "0.4")); mr.inputs[4].default_value = float(arg("lumiere", "1.4"))
gm = nt.nodes.new("ShaderNodeGamma"); gm.inputs[1].default_value = float(arg("gamma", "1.1"))
mu = nt.nodes.new("ShaderNodeMix"); mu.data_type = "RGBA"; mu.blend_type = "MULTIPLY"; mu.inputs[0].default_value = 1.0
em = nt.nodes.new("ShaderNodeEmission"); out = nt.nodes.new("ShaderNodeOutputMaterial")
for a, b in ((uvn.outputs["UV"], ti.inputs["Vector"]), (uvn.outputs["UV"], tn.inputs["Vector"]), (tn.outputs["Color"], nm.inputs["Color"]),
             (nm.outputs["Normal"], dp.inputs[0]), (dp.outputs["Value"], mr.inputs[0]), (ti.outputs["Color"], gm.inputs[0]),
             (gm.outputs[0], mu.inputs[6]), (mr.outputs[0], mu.inputs[7]), (mu.outputs[2], em.inputs["Color"]), (em.outputs[0], out.inputs[0])):
    nt.links.new(a, b)
for h in HD.values():
    h.data.materials.clear(); h.data.materials.append(mhd)
CUIT = bpy.data.images.new("armure_cuit", 1024, 1024)
mat = bpy.data.materials.new("armure_cuisson"); mat.use_nodes = True
nt = mat.node_tree; nt.nodes.clear()
cible = nt.nodes.new("ShaderNodeTexImage"); cible.image = CUIT; nt.nodes.active = cible
em = nt.nodes.new("ShaderNodeEmission"); out = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(em.outputs[0], out.inputs[0])
armure.data.materials.clear(); armure.data.materials.append(mat)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 1
sc.render.bake.margin = 6; sc.render.bake.use_clear = True
sc.render.bake.use_selected_to_active = True; sc.render.bake.cage_extrusion = 0.03; sc.render.bake.max_ray_distance = 0.08
for o in bpy.data.objects:
    o.select_set(o == armure or o in HD.values())
bpy.context.view_layer.objects.active = armure
bpy.ops.object.bake(type="EMIT")
CUIT.scale(512, 512)
TEX = os.path.splitext(OUT_GLB)[0] + "_tex.png"
CUIT.filepath_raw = TEX; CUIT.file_format = "PNG"; CUIT.save()
print("ATLAS", TEX)
for h in HD.values():
    bpy.data.objects.remove(h)
armure.data.uv_layers.remove(armure.data.uv_layers[uv_src])
nt.nodes.clear()
bs = nt.nodes.new("ShaderNodeBsdfPrincipled"); out = nt.nodes.new("ShaderNodeOutputMaterial")
ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = CUIT; ti.interpolation = "Closest"
nt.links.new(ti.outputs["Color"], bs.inputs["Base Color"]); nt.links.new(bs.outputs[0], out.inputs[0])
bs.inputs["Roughness"].default_value = 0.8
mat.name = "armure_or"

# ---------------------------------------------------------------- 5. poids : k plus proches sommets du corps, os autorisés par pièce, lissés
from mathutils import kdtree
cnoms = [g.name for g in corps.vertex_groups]
W = np.zeros((len(corps.data.vertices), len(cnoms)))
for v in corps.data.vertices:
    for g in v.groups:
        W[v.index, g.group] = g.weight
kd = kdtree.KDTree(len(CORPS_P))
for i, p in enumerate(CORPS_P):
    kd.insert(Vector(p), i)
kd.balance()
DOIGTS = ("thumb", "index", "middle", "ring", "pinky")
def permis(nom, os_):
    if nom == "casque":
        return os_ in ("Head",)
    if nom == "cuirasse":
        return os_ in ("pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "thigh_l", "thigh_r") or os_.startswith(("clavicle", "upperarm", "lowerarm"))
    if nom == "gantelet":
        return os_.endswith("_l") and (os_.startswith(("lowerarm", "hand")) or os_.startswith(DOIGTS))
    if nom == "jambiere":
        return os_ in ("thigh_l", "calf_l", "foot_l")
    if nom == "botte":
        return os_ in ("calf_l", "foot_l", "ball_l")
    return False
me = armure.data
AP = np.array([v.co[:] for v in me.vertices])
piece_de = np.full(len(AP), "", dtype=object)
for nom in ordre:
    gi = armure.vertex_groups["piece_" + nom].index
    for v in me.vertices:
        if any(g.group == gi and g.weight > 0.5 for g in v.groups):
            piece_de[v.index] = nom
masques = {nom: np.array([permis(nom, n) for n in cnoms]) for nom in ordre}
# cuirasse : les MANCHES (sommets plus près de l'os du bras que de l'axe du torse) ne suivent que le bras (sinon elles restent au torse
# quand le bras se rabat et découvrent l'épaule) ; le torse ne prend pas les os des bras
def dseg(P, a, b):
    ab = b - a; t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1); return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)
d_tor = dseg(AP, tete("pelvis"), tete("neck_01"))
for s_ in ("l", "r"):
    d_bras = np.minimum(dseg(AP, tete("upperarm_" + s_), tete("lowerarm_" + s_)), dseg(AP, tete("lowerarm_" + s_), tete("hand_" + s_)))
    m_bras = np.array([n in ("upperarm_" + s_, "lowerarm_" + s_, "clavicle_" + s_) for n in cnoms])
    manche = (piece_de == "cuirasse") & (d_bras < d_tor * float(arg("manche", "0.75")))
    masques["manche_" + s_] = m_bras
    piece_de[manche] = "manche_" + s_
    print("MANCHE", s_, int(manche.sum()), "sommets")
masques["cuirasse"] = masques["cuirasse"] & ~np.array([n.startswith(("upperarm", "lowerarm")) for n in cnoms])
AW = np.zeros((len(AP), len(cnoms)))
for i, p in enumerate(AP):
    nom = piece_de[i]
    voisins = kd.find_n(Vector(p), 12)
    acc = np.zeros(len(cnoms))
    for co, j, d in voisins:
        acc += W[j] / (d + 0.01) ** 2
    acc *= masques[nom]
    if acc.sum() < 1e-9:
        acc = masques[nom].astype(float)
    AW[i] = acc / acc.sum()
# lissage laplacien sur les arêtes de l'armure (chaque pièce se lisse sur elle-même)
E = np.array([e.vertices[:] for e in me.edges])
for it in range(int(arg("lissage", "6"))):
    S = np.zeros_like(AW); n = np.zeros(len(AP))
    np.add.at(S, E[:, 0], AW[E[:, 1]]); np.add.at(S, E[:, 1], AW[E[:, 0]])
    np.add.at(n, E[:, 0], 1); np.add.at(n, E[:, 1], 1)
    AW = 0.5 * AW + 0.5 * S / np.maximum(n, 1)[:, None]
# 4 influences au plus, normalisé
idx = np.argsort(-AW, axis=1)[:, 4:]
np.put_along_axis(AW, idx, 0.0, axis=1)
AW /= AW.sum(1, keepdims=True)
for g in list(armure.vertex_groups):
    armure.vertex_groups.remove(g)
VG = [armure.vertex_groups.new(name=n) for n in cnoms]
for j in range(len(cnoms)):
    nz = np.nonzero(AW[:, j] > 1e-4)[0]
    for i in nz:
        VG[j].add([int(i)], float(AW[i, j]), "REPLACE")
print("POIDS ok ; os utilisés :", sorted({cnoms[j] for j in range(len(cnoms)) if AW[:, j].max() > 0.05}))

# ---------------------------------------------------------------- 6. miroir des pièces paires (gantelet, jambière, botte) -> côté droit
def nom_miroir(n):
    return n[:-2] + "_r" if n.endswith("_l") else (n[:-2] + "_l" if n.endswith("_r") else n)
bm = bmesh.new(); bm.from_mesh(me)
dl = bm.verts.layers.deform.verify()
bm.verts.ensure_lookup_table()
paires = {i for i in range(len(AP)) if piece_de[i] in ("gantelet", "jambiere", "botte")}
faces = [f for f in bm.faces if all(v.index in paires for v in f.verts)]
res = bmesh.ops.duplicate(bm, geom=faces)
remap = {armure.vertex_groups[n].index: armure.vertex_groups[nom_miroir(n)].index for n in cnoms}
nv = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
for v in nv:
    v.co.x = -v.co.x
    d = dict(v[dl]); v[dl].clear()
    for k, w in d.items():
        v[dl][remap.get(k, k)] = w
nf = [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]
bmesh.ops.reverse_faces(bm, faces=nf)
bm.to_mesh(me); bm.free()
me.update()
print("ARMURE %d sommets, %d triangles" % (len(me.vertices), len(me.polygons)))

# ---------------------------------------------------------------- 7. sous-couche de mailles : le corps, ramené DERRIÈRE l'armure
# (comble aisselles, coudes, genoux, cou entre les pièces ; mains et pieds retirés : gantelets et bottes les remplacent)
from mathutils.bvhtree import BVHTree
sous = corps; sous.name = "sous_couche"; sous.data.name = "sous_couche"
bvh = BVHTree.FromObject(armure, bpy.context.evaluated_depsgraph_get())
gn = [g.name for g in sous.vertex_groups]
RETIRE = ("hand_", "ball_", "foot_") + DOIGTS
bm = bmesh.new(); bm.from_mesh(sous.data)
dl = bm.verts.layers.deform.verify()
bm.verts.ensure_lookup_table(); bm.normal_update()
retire = []
marge = float(arg("marge", "0.012")); pousses = 0
for v in bm.verts:
    d = v[dl]
    if d:
        k = max(d.items(), key=lambda kv: kv[1])[0]
        if gn[k].startswith(RETIRE) and gn[k] not in ("foot_l", "foot_r") or (gn[k] in ("foot_l", "foot_r") and v.co.z < 0.12):
            retire.append(v); continue
    loc, nor, fi, dist = bvh.find_nearest(v.co, 0.08)
    if loc is not None and (v.co - loc).dot(nor) > -marge:
        v.co = loc - nor * marge; pousses += 1
bmesh.ops.delete(bm, geom=retire, context="VERTS")
bm.to_mesh(sous.data); bm.free()
print("SOUS-COUCHE %d sommets (%d retirés, %d ramenés derrière l'armure)" % (len(sous.data.vertices), len(retire), pousses))
msous = bpy.data.materials.new("sous_couche_mailles"); msous.diffuse_color = (0.12, 0.1, 0.09, 1)
sous.data.materials.clear(); sous.data.materials.append(msous)

# ---------------------------------------------------------------- 8. export habillé
for o in (armure, sous):
    o.parent = arm
    mo = o.modifiers.new("Armature", "ARMATURE"); mo.object = arm
for o in list(bpy.data.objects):
    if o not in (arm, armure, sous):
        bpy.data.objects.remove(o)
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, use_selection=True, export_format="GLB", export_skins=True, export_animations=False,
                          export_morph=False, export_yup=True, export_image_format="NONE")
print("EXPORT", OUT_GLB)
if DEBUG:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DEBUG, "final.blend"))
