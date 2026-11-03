"""Jambières POSÉES AU SOL : pour chaque famille de chausses (assets/modeles/armures/chausses/<famille>.glb, maillage skinné du héros),
écrit assets/modeles/armures/sol/jambieres_<id>.glb : le maillage en pose de repos, sans os, couché sur le dos (jambes vers -z),
pivot au sol (y min = 0), centré. Pas de couleur de sommet (export_vertex_color NONE) : le shader met neige_tient = 0 au sol.
  blender.exe -b --python sources_blender/armures/jambieres_sol.py
Familles -> identifiants d'objets : voir FAMILLES (data/objets/armures.json : jambieres_<id>).
"""
import bpy, os, sys, math
from mathutils import Matrix, Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import armures_lib as L

CHAUSSES = os.path.join(L.ROOT, "assets", "modeles", "armures", "chausses")
FAMILLES = {"cuir": "cuir", "fourrure": "fourrure", "os": "os", "fer": "fer", "acier": "acier_nordique", "gardiens": "gardiens",
            "braise": "braise", "verre": "verre", "obsidienne": "obsidienne", "or": "or"}

for fam, ident in FAMILLES.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(CHAUSSES, fam + ".glb"))
    mi = next(o for o in bpy.data.objects if o.type == 'MESH')
    me = mi.data.copy()
    mw = mi.matrix_world.copy()
    s = bpy.data.objects.new("jambieres_" + ident, me)
    bpy.context.scene.collection.objects.link(s)
    s.matrix_world = Matrix()
    me.transform(mw)
    # couchée sur le dos : repère Godot, rotation de -90 degrés autour de x (le haut des cuisses vers -z... les pieds vers +z)
    rot = Matrix.Rotation(-math.pi / 2, 4, 'X')
    for v in me.vertices:
        v.co = L.B(rot @ L.G(v.co))
    ys = [L.G(v.co).y for v in me.vertices]
    xs = [L.G(v.co).x for v in me.vertices]
    zs = [L.G(v.co).z for v in me.vertices]
    d = Vector(((min(xs) + max(xs)) / 2, min(ys), (min(zs) + max(zs)) / 2))
    for v in me.vertices:
        v.co = L.B(L.G(v.co) - d)
    me.update()
    for o in list(bpy.data.objects):
        if o != s:
            bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action='DESELECT')
    s.select_set(True)
    bpy.context.view_layer.objects.active = s
    bpy.ops.export_scene.gltf(filepath=os.path.join(L.SOL, "jambieres_" + ident + ".glb"), export_format='GLB', use_selection=True,
                              export_skins=False, export_animations=False, export_yup=True, export_materials='EXPORT',
                              export_image_format='AUTO', export_vertex_color='NONE')
    print("SOL jambieres_%s : %d triangles, hauteur %.2f m" % (ident, len(me.polygons), max(L.G(v.co).y for v in me.vertices)))
