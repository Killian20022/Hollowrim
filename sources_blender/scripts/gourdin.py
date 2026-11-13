"""Gourdin (arme commune des bandits et squelettes) : branche de chêne noueuse, poignée de cuir lié, tête épaisse.
Repère commun des armes (docs CATALOGUE) : +Y le long de l'arme, centre du poing à y = 0,03, tête vers +Y, pommeau vers -Y.
Matériaux par NOM (habillés en PS1 par EpeesLongues.habiller) : bois, cuir, fer (3 clous de la tête).
  blender -b --python sources_blender/scripts/gourdin.py -- <sortie.glb>
"""
import sys, math, random
import bpy, bmesh
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "gourdin.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
rnd = random.Random(7)

def mat(nom, col):
    m = bpy.data.materials.new(nom)
    m.diffuse_color = col
    return m

M_BOIS, M_CUIR, M_FER = mat("bois", (0.35, 0.22, 0.12, 1)), mat("cuir", (0.25, 0.15, 0.08, 1)), mat("fer", (0.3, 0.3, 0.32, 1))

# profil (y, rayon) : pommeau renflé, manche fin, évasement, tête massive arrondie
PROFIL = [(-0.095, 0.0), (-0.092, 0.018), (-0.075, 0.026), (-0.055, 0.021), (-0.02, 0.0165), (0.10, 0.0155), (0.20, 0.0175),
          (0.30, 0.026), (0.39, 0.037), (0.46, 0.047), (0.53, 0.053), (0.59, 0.052), (0.645, 0.044), (0.675, 0.028), (0.69, 0.0)]
SEG = 14
# anneaux intermédiaires : le bois noueux demande de la matière à déformer
_P = []
for (a, b) in zip(PROFIL, PROFIL[1:]):
    _P += [a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 if a[1] and b[1] else (a[1] + b[1]) * 0.75)]
_P.append(PROFIL[-1])
PROFIL = _P

def anneau(bm, y, r, k):
    vs = []
    for i in range(SEG):
        a = i / SEG * math.tau
        # bosses du bois : bruit stable selon la hauteur et l'angle
        bruit = 1.0 + 0.16 * math.sin(a * 2 + y * 17 + k) * math.cos(y * 9 + a) + rnd.uniform(-0.05, 0.05)
        rr = r * bruit
        # léger courbe du fût
        dx = 0.012 * math.sin(y * 3.6)
        vs.append(bm.verts.new((math.cos(a) * rr + dx, y, math.sin(a) * rr)))
    return vs

bm = bmesh.new()
anneaux = []
for k, (y, r) in enumerate(PROFIL):
    if r == 0.0:
        anneaux.append([bm.verts.new((0.012 * math.sin(y * 3.6) if False else 0.0, y, 0.0))])
    else:
        anneaux.append(anneau(bm, y, r, k))
for a, b in zip(anneaux, anneaux[1:]):
    if len(a) == 1:
        for i in range(SEG):
            bm.faces.new((a[0], b[(i + 1) % SEG], b[i]))
    elif len(b) == 1:
        for i in range(SEG):
            bm.faces.new((a[i], a[(i + 1) % SEG], b[0]))
    else:
        for i in range(SEG):
            bm.faces.new((a[i], a[(i + 1) % SEG], b[(i + 1) % SEG], b[i]))
# nœuds : deux bosses sur la tête (petites sphères aplaties fusionnées)
for (y, ang, r) in [(0.43, 0.9, 0.022), (0.56, 3.4, 0.024), (0.27, 5.3, 0.017)]:
    res = bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=4, radius=r)
    cx = math.cos(ang) * (0.047 if y > 0.4 else 0.024)
    cz = math.sin(ang) * (0.047 if y > 0.4 else 0.024)
    bmesh.ops.translate(bm, verts=res["verts"], vec=Vector((cx, y, cz)))
bm.normal_update()
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
me = bpy.data.meshes.new("gourdin_bois"); bm.to_mesh(me); bm.free()
ob = bpy.data.objects.new("gourdin", me); bpy.context.scene.collection.objects.link(ob)
me.materials.append(M_BOIS)

# cuir lié : manchon autour du manche (y 0 -> 0,2) avec spires
bm = bmesh.new()
y0, y1, n = -0.01, 0.20, 12
for j in range(n + 1):
    y = y0 + (y1 - y0) * j / n
    r = 0.0185 + (0.0025 if j % 2 == 0 else 0.0)
    for i in range(SEG):
        a = i / SEG * math.tau
        bm.verts.new((math.cos(a) * r + 0.012 * math.sin(y * 3.6), y, math.sin(a) * r))
bm.verts.ensure_lookup_table()
for j in range(n):
    for i in range(SEG):
        a0, a1 = j * SEG + i, j * SEG + (i + 1) % SEG
        bm.faces.new((bm.verts[a0], bm.verts[a1], bm.verts[a1 + SEG], bm.verts[a0 + SEG]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
me2 = bpy.data.meshes.new("gourdin_cuir"); bm.to_mesh(me2); bm.free()
ob2 = bpy.data.objects.new("gourdin_cuir", me2); bpy.context.scene.collection.objects.link(ob2)
me2.materials.append(M_CUIR)

# clous de fer dans la tête
bm = bmesh.new()
for (y, ang) in [(0.50, 0.2), (0.56, 2.3), (0.50, 4.2), (0.60, 5.6), (0.46, 3.1)]:
    rr = 0.052
    c = Vector((math.cos(ang) * rr, y, math.sin(ang) * rr))
    d = Vector((math.cos(ang), 0, math.sin(ang)))
    res = bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.011, radius2=0.002, depth=0.026)
    # le cône est le long de +Z : on l'oriente vers l'extérieur (d)
    q = Vector((0, 0, 1)).rotation_difference(d)
    bmesh.ops.rotate(bm, verts=res["verts"], cent=(0, 0, 0), matrix=q.to_matrix())
    bmesh.ops.translate(bm, verts=res["verts"], vec=c + d * 0.006)
me3 = bpy.data.meshes.new("gourdin_fer"); bm.to_mesh(me3); bm.free()
ob3 = bpy.data.objects.new("gourdin_fer", me3); bpy.context.scene.collection.objects.link(ob3)
me3.materials.append(M_FER)

# grain du bois : UV par projection intelligente
for o in (ob, ob2, ob3):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.cylinder_project() if o is ob else bpy.ops.uv.smart_project(angle_limit=1.2)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.shade_flat()
    o.select_set(False)

tris = sum(len(o.data.polygons) * (1 if False else 1) for o in (ob, ob2, ob3))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_yup=True, export_apply=True)
t = 0
for o in (ob, ob2, ob3):
    t += sum(len(p.vertices) - 2 for p in o.data.polygons)
print("GOURDIN tris=%d -> %s" % (t, out))
