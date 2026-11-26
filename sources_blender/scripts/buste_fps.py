# BUSTE 1re personne (chantier combat/bras_corps_1p, 2026-11-26). Retour utilisateur : « pour le bras, on dirait que je n'ai
# pas de corps, on voit mes bras se décoller à chaque fois que je frappe ».
# bras_fps.glb n'avait que les bras (manche_l/_r fermées en dôme à l'épaule, avant_bras_l/_r) : dès qu'un bras part loin
# (coups larges, deux mains, contre-attaque), son épaule — un dôme qui finit dans le vide — entre dans le champ et le bras
# flotte. Les bons jeux (Mordhau, Chivalry 2 : Jeux/references/bras_corps_1p/references.png) montrent alors l'épaule et le
# haut du torse dans le coin bas : le bras est toujours rattaché à un corps.
# Ajout : un BUSTE fermé (cotte de mailles « tunique », même matière que les manches : suit les armures portées comme elles)
# du bas des côtes au cou, épaules arrondies qui enveloppent la rotule des manches. Poids : colonne (spine_02/03) au torse,
# clavicules aux épaules, un peu d'humérus au deltoïde et à l'aisselle (l'épaule se soulève avec le bras), cou au col.
# Rien d'autre n'est touché (manches, avant-bras, squelette identiques).
#   blender.exe -b --python buste_fps.py
#   source : sources_blender/bras_fps_avant_buste.glb (copie de bras_fps.glb gardée la 1re fois, toujours reprise)
#   sortie : assets/modeles/joueur/bras_fps.glb
import bpy, bmesh, math, os, shutil
from mathutils import Vector

base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
glb = os.environ.get("BUSTE_SORTIE") or os.path.join(base, "assets", "modeles", "joueur", "bras_fps.glb")
SAUVE = os.path.join(base, "sources_blender", "bras_fps_avant_buste.glb")
if not os.path.exists(SAUVE) and not os.environ.get("BUSTE_SORTIE"):
    shutil.copy(glb, SAUVE)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SAUVE)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')

# Repère Blender du squelette : x = gauche du personnage (+x bras gauche), -y = devant, z = haut.
# Épaules (tête des humérus) (±0,212 ; 0,065 ; 1,455), clavicules (±0,031 ; -0,034 ; 1,495), cou (0 ; 0,041 ; 1,521).
# Œil de la caméra du jeu : (0 ; 0,157 ; 1,77) (mains.gd : yeux du squelette 0,24 m devant et 0,1 m sous la caméra).
# Anneaux horizontaux (z, demi-largeur, devant, dos, centre y) : superellipse (exposant 2,6 : épaules pleines).
ANNEAUX = [
    (1.020, 0.165, 0.100, 0.110, 0.000),
    (1.120, 0.172, 0.108, 0.115, 0.000),
    (1.220, 0.182, 0.118, 0.120, 0.000),
    (1.310, 0.196, 0.124, 0.122, 0.005),
    (1.380, 0.222, 0.122, 0.118, 0.012),
    (1.430, 0.246, 0.112, 0.112, 0.022),
    (1.475, 0.254, 0.100, 0.104, 0.030),
    (1.510, 0.236, 0.088, 0.094, 0.034),
    (1.535, 0.196, 0.078, 0.086, 0.036),
    (1.555, 0.140, 0.068, 0.074, 0.038),
    (1.570, 0.090, 0.060, 0.064, 0.040),
    (1.580, 0.066, 0.056, 0.058, 0.040),
]
SOMMET = (1.586, 0.040)
BAS = (1.000, 0.000)
N = 28
EXPO = 2.6


def h(i, j):
    x = (i * 73856093) ^ (j * 19349663)
    x = (x ^ (x >> 13)) * 1274126177
    return ((x ^ (x >> 16)) & 0xffff) / 65535.0


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def point(ang, a, f, b, yc, z):
    c, s = math.cos(ang), math.sin(ang)
    # ang = 0 : +x (gauche), pi/2 : devant (-y)
    sx = math.copysign(abs(c) ** (2.0 / EXPO), c)
    sy = math.copysign(abs(s) ** (2.0 / EXPO), s)
    prof = f if sy > 0 else b
    return Vector((a * sx, yc - prof * sy, z))


me = bpy.data.meshes.new("buste")
bm = bmesh.new()
uvl = bm.loops.layers.uv.new("UVMap")
col = bm.loops.layers.color.new("Col")
rangs = []
for j, (z, a, f, b, yc) in enumerate(ANNEAUX):
    r = []
    for i in range(N):
        ang = 2 * math.pi * i / N
        p = point(ang, a, f, b, yc, z)
        # mailles un peu inégales (3 mm au plus)
        if 0 < j < len(ANNEAUX) - 2:
            n = Vector((p.x, p.y - yc, 0)).normalized()
            p += n * (h(i, j) - 0.5) * 0.006
        r.append(bm.verts.new(p))
    rangs.append(r)
haut = bm.verts.new((0.0, SOMMET[1], SOMMET[0]))
bas = bm.verts.new((0.0, 0.0, BAS[0]))
UV_TOURS = 2.0
UV_M = 3.9    # répétitions par mètre de hauteur (même densité que les manches)


def occ(z, x):
    # creux sombres sous les aisselles et au col, épaules plus claires (couleurs de sommet, comme les manches)
    o = 0.70 + 0.10 * smooth(1.30, 1.47, z) - 0.06 * smooth(1.55, 1.58, z)
    o -= 0.08 * smooth(0.17, 0.23, abs(x)) * (1.0 - smooth(1.36, 1.44, z))
    return max(0.45, min(o, 0.86))


def face(vs, uvs):
    f = bm.faces.new(vs)
    f.smooth = True
    for lo, uv in zip(f.loops, uvs):
        lo[uvl].uv = uv
        c = occ(lo.vert.co.z, lo.vert.co.x)
        lo[col] = (c, c, c, 1.0)
    return f


for j in range(len(rangs) - 1):
    za, zb = ANNEAUX[j][0], ANNEAUX[j + 1][0]
    for i in range(N):
        i2 = (i + 1) % N
        face([rangs[j][i], rangs[j][i2], rangs[j + 1][i2], rangs[j + 1][i]],
             [(i / N * UV_TOURS, za * UV_M), ((i + 1) / N * UV_TOURS, za * UV_M), ((i + 1) / N * UV_TOURS, zb * UV_M), (i / N * UV_TOURS, zb * UV_M)])
zt = ANNEAUX[-1][0]
for i in range(N):
    i2 = (i + 1) % N
    face([rangs[-1][i], rangs[-1][i2], haut], [(i / N * UV_TOURS, zt * UV_M), ((i + 1) / N * UV_TOURS, zt * UV_M), ((i + 0.5) / N * UV_TOURS, SOMMET[0] * UV_M)])
    face([rangs[0][i2], rangs[0][i], bas], [((i + 1) / N * UV_TOURS, ANNEAUX[0][0] * UV_M), (i / N * UV_TOURS, ANNEAUX[0][0] * UV_M), ((i + 0.5) / N * UV_TOURS, BAS[0] * UV_M)])
bm.normal_update()
bords = [e for e in bm.edges if e.is_boundary or not e.is_manifold]
assert not bords, "buste : %d arêtes ouvertes" % len(bords)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
# normales vers l'extérieur (contrôle au torse)
for f in bm.faces:
    c = f.calc_center_median()
    if 1.15 < c.z < 1.45:
        assert f.normal.dot(Vector((c.x, c.y, 0))) > 0, "buste : face retournée"
bm.to_mesh(me)
bm.free()
me.materials.append(bpy.data.materials.get("tunique") or bpy.data.materials.new("tunique"))
o = bpy.data.objects.new("buste", me)
bpy.context.scene.collection.objects.link(o)
o.parent = arm
o.matrix_parent_inverse = arm.matrix_world.inverted()


def poser(v, w):
    w = dict(sorted(w.items(), key=lambda e: -e[1])[:4])
    s = sum(w.values()) or 1.0
    for g, ww in w.items():
        if ww / s > 1e-3:
            vg = o.vertex_groups.get(g) or o.vertex_groups.new(name=g)
            vg.add([v.index], ww / s, 'REPLACE')


for v in me.vertices:
    x, z = v.co.x, v.co.z
    cote = "_l" if x > 0 else "_r"
    ax = abs(x)
    w = {}
    k2 = 1.0 - smooth(1.12, 1.26, z)
    w["spine_02"] = k2
    w["spine_03"] = 1.0 - k2
    # épaule : la clavicule porte le haut de l'épaule (trapèze -> acromion)
    kc = smooth(0.05, 0.15, ax) * smooth(1.33, 1.46, z)
    # deltoïde et aisselle : l'humérus soulève l'épaule avec le bras (rotule comme le dôme des manches)
    ku = 0.55 * smooth(0.17, 0.25, ax) * smooth(1.34, 1.45, z)
    kn = 0.6 * smooth(1.55, 1.585, z) * (1.0 - smooth(0.03, 0.10, ax))
    reste = max(0.0, 1.0 - kc - kn)
    w = {g: q * reste for g, q in w.items()}
    w["clavicle" + cote] = kc * (1.0 - ku)
    w["upperarm" + cote] = kc * ku + (ku * 0.4 if kc < 0.2 else 0.0)
    w["neck_01"] = kn
    poser(v, w)
mod = o.modifiers.new("Armature", 'ARMATURE')
mod.object = arm
tris = sum(len(p.vertices) - 2 for p in me.polygons)
print("BUSTE", len(me.vertices), "sommets", tris, "triangles, étanche")

bpy.ops.object.select_all(action='DESELECT')
for ob in bpy.data.objects:
    ob.select_set(True)
bpy.context.view_layer.objects.active = arm
kw = dict(filepath=glb, export_format='GLB', use_selection=True, export_skins=True, export_animations=False,
          export_apply=False)
try:
    bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
except TypeError:
    bpy.ops.export_scene.gltf(**kw)
print("EXPORT OK", glb)
