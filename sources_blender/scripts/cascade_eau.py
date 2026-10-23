# Cascade du système d'eau : nappe d'eau qui tombe + falaise de blocs anguleux autour.
#   blender.exe -b --python cascade_eau.py
# Sortie : assets/modeles/eau/cascade.glb (objets « Chute » et « Falaise ») + sources_blender/cascade_eau.blend
# Repère (celui de Godot, converti en Blender (x, -z, y) puis ré-exporté Y haut) : la lèvre est en x = 0, y = 0 (haut de l'eau) ;
# l'eau coule vers +x et tombe de HAUTEUR m ; largeur LARGEUR (z de -L/2 à +L/2). Le nœud Godot fixe la hauteur réelle par son échelle en y.
# « Chute » : couleur de sommet R = fondu des bords (0 au bord, 1 au centre), G = progression de la chute (0 lèvre → 1 pied),
#             B = écume de lèvre (1 sur la lèvre, 0 ailleurs), A = 1 ; UV = (z en m, longueur d'arc en m) pour que les texels
#             d'eau aient la même taille que le reste du jeu.
# « Falaise » : blocs convexes à arêtes vives, couleur de sommet rgb = occlusion, a = 0 sur les faces tournées vers le ciel (neige).
import bpy, bmesh, math, os, random
from mathutils import Vector

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(BASE, "assets", "modeles", "eau", "cascade.glb")
BLEND = os.path.join(BASE, "sources_blender", "cascade_eau.blend")
os.makedirs(os.path.dirname(SORTIE), exist_ok=True)

HAUTEUR = 1.5
LARGEUR = 3.0


def b_of_g(v):
    return Vector((v[0], -v[2], v[1]))


def nappe():
    """Nappe d'eau : course sur la lèvre, arc, puis chute presque verticale qui s'écarte légèrement de la paroi."""
    nu, nv = 18, 16
    pts = []
    for j in range(nv + 1):
        v = j / nv
        if v < 0.2:                       # course sur la lèvre (0,7 m), légèrement inclinée
            s = v / 0.2
            x, y = -0.7 + 0.7 * s, -0.04 * s * s
        else:                             # arc de chute
            s = (v - 0.2) / 0.8
            y = -0.04 - (HAUTEUR - 0.04) * s
            x = 0.05 + 0.42 * s ** 1.5
        pts.append((x, y, v))
    arc = [0.0]
    for j in range(1, len(pts)):
        arc.append(arc[-1] + math.hypot(pts[j][0] - pts[j - 1][0], pts[j][1] - pts[j - 1][1]))
    rg = random.Random(77)
    # largeur qui ondule un peu (filets) et s'élargit vers le bas
    verts, cols, uvs, faces = [], [], [], []
    for j, (x, y, v) in enumerate(pts):
        for i in range(nu + 1):
            u = i / nu * 2.0 - 1.0        # -1 .. 1
            ond = 1.0 + 0.04 * math.sin(i * 1.7 + 0.8) + 0.03 * math.sin(i * 3.1)
            elarg = 1.0 + 0.18 * max(0.0, (v - 0.2) / 0.8)
            z = u * LARGEUR * 0.5 * ond * elarg
            verts.append((x, y, z))
            bord = 1.0 - max(0.0, (abs(u) - 0.72) / 0.28)
            cols.append((max(bord, 0.0), v, 1.0 if j <= 3 else 0.0, 1.0))
            uvs.append((z, arc[j]))
    for j in range(nv):
        for i in range(nu):
            a = j * (nu + 1) + i
            faces.append((a, a + 1, a + nu + 2, a + nu + 1))
    return verts, faces, cols, uvs


def hull(pts):
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(b_of_g(p))
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:], use_existing_faces=False)
    perdus = [g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)]
    if perdus:
        bmesh.ops.delete(bm, geom=list(set(perdus)), context='VERTS')
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    sommets = [Vector((v.co.x, v.co.z, -v.co.y)) for v in bm.verts]   # retour au repère Godot
    index = {v.index: k for k, v in enumerate(bm.verts)}
    tris = [[index[v.index] for v in f.verts] for f in bm.faces]
    bm.free()
    return sommets, tris


def bloc(rg, centre, taille, n=15, aplat_bas=0.55):
    pts = []
    for _ in range(n):
        while True:
            v = Vector((rg.gauss(0, 1), rg.gauss(0, 1), rg.gauss(0, 1)))
            if v.length > 0.05:
                break
        v.normalize()
        v *= rg.uniform(0.72, 1.28)
        if v.y < -aplat_bas:
            v.y = -aplat_bas
        pts.append(Vector((centre[0] + v.x * taille[0], centre[1] + v.y * taille[1], centre[2] + v.z * taille[2])))
    return hull(pts)


def falaise():
    rg = random.Random(5150)
    H = HAUTEUR
    W = LARGEUR
    blocs = []
    # paroi derrière la chute (l'eau glisse contre elle) : trois dalles empilées, front légèrement incliné
    for k in range(3):
        blocs.append(bloc(rg, (-0.55, -H * (0.12 + 0.38 * k) - 0.1, 0.0), (0.62, H * 0.34, W * 0.62), 16, 0.9))
    # joues : gros blocs de part et d'autre du couloir d'eau
    for sgn in (-1, 1):
        for k in range(3):
            blocs.append(bloc(rg, (-0.1 + rg.uniform(-0.1, 0.2), -H * (0.15 + 0.4 * k) - 0.1, sgn * (W * 0.5 + 0.55 + rg.uniform(0, 0.3))),
                              (0.75, H * 0.36, 0.7), 15, 0.8))
        # blocs de lèvre (au niveau de l'eau, saillie neigeuse)
        blocs.append(bloc(rg, (-0.25, -0.18, sgn * (W * 0.5 + 0.25)), (0.7, 0.34, 0.45), 14, 0.7))
        blocs.append(bloc(rg, (-1.0, -0.2, sgn * (W * 0.5 + 0.7)), (0.8, 0.35, 0.55), 14, 0.7))
    # seuil sous l'eau (le dessus affleure à 6 cm sous la surface)
    blocs.append(bloc(rg, (-0.3, -0.3, 0.0), (0.6, 0.22, W * 0.42), 14, 0.9))
    # éboulis au pied (dans le bassin)
    for k in range(5):
        a = -1.0 + k * 0.5
        blocs.append(bloc(rg, (0.7 + rg.uniform(0, 0.6), -H - 0.12, a * W * 0.5), (0.34 + rg.uniform(0, 0.2), 0.3, 0.38), 12, 0.6))
    return blocs


def colorier(me, tris_normales):
    ca = me.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
    for poly in me.polygons:
        n = poly.normal
        neige = 0.0 if n.z > 0.55 else 1.0           # normale Blender z = haut
        ao = 0.62 + 0.38 * max(0.0, min(1.0, (poly.center.z + 2.0) / 2.2))   # plus sombre vers le bas
        for li in poly.loop_indices:
            ca.data[li].color = (ao, ao, ao, neige)
    me.color_attributes.active_color = ca


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # --- chute ---
    verts, faces, cols, uvs = nappe()
    me = bpy.data.meshes.new("Chute")
    me.from_pydata([tuple(b_of_g(v)) for v in verts], [], faces)
    me.update()
    # sens des faces : la normale doit regarder vers +x (côté vide, devant la nappe)
    for poly in me.polygons:
        if poly.normal.y > 0:       # +x Godot = +x Blender ; la nappe fait face à -y Blender ?  on veut la face visible côté chute
            pass
    uv = me.uv_layers.new(name="UVMap")
    ca = me.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            uv.data[li].uv = uvs[vi]
            ca.data[li].color = cols[vi]
    me.color_attributes.active_color = ca
    for p in me.polygons:
        p.use_smooth = True
    ob_chute = bpy.data.objects.new("Chute", me)
    bpy.context.scene.collection.objects.link(ob_chute)
    # --- falaise ---
    bm_all = bmesh.new()
    for sommets, tris in falaise():
        base = len(bm_all.verts)
        vs = [bm_all.verts.new(b_of_g(s)) for s in sommets]
        for t in tris:
            try:
                bm_all.faces.new([vs[t[0]], vs[t[1]], vs[t[2]]])
            except ValueError:
                pass
    bmesh.ops.recalc_face_normals(bm_all, faces=bm_all.faces[:])
    mf = bpy.data.meshes.new("Falaise")
    bm_all.to_mesh(mf)
    bm_all.free()
    for p in mf.polygons:
        p.use_smooth = False
    colorier(mf, None)
    ob_f = bpy.data.objects.new("Falaise", mf)
    bpy.context.scene.collection.objects.link(ob_f)
    bpy.ops.object.select_all(action='DESELECT')
    ob_chute.select_set(True)
    ob_f.select_set(True)
    bpy.ops.export_scene.gltf(filepath=SORTIE, export_format='GLB', use_selection=True, export_apply=False,
                              export_normals=True, export_texcoords=True, export_vertex_color='ACTIVE',
                              export_active_vertex_color_when_no_material=True, export_materials='NONE', export_yup=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("cascade :", len(verts), "sommets de nappe,", len(mf.polygons), "faces de falaise ->", SORTIE)


main()
