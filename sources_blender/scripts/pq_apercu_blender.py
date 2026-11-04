# Aperçu rapide (Workbench, sans GPU) des glb convertis : blender -b --python pq_apercu_blender.py -- sortie=<dossier> glb1 glb2 ...
import bpy, sys, os, math
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:]
sortie = [a for a in args if a.startswith("sortie=")][0][7:]
files = [a for a in args if not a.startswith("sortie=")]
os.makedirs(sortie, exist_ok=True)
for f in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f)
    ms = [o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.startswith('Icosphere')]
    dg = bpy.context.evaluated_depsgraph_get()
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for o in ms:
        oe = o.evaluated_get(dg); me = oe.to_mesh()
        for v in me.vertices:
            w = oe.matrix_world @ v.co
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
        oe.to_mesh_clear()
    c = (mn + mx) / 2; size = mx - mn
    print("APERCU", os.path.basename(f), "taille(x,y,z blender)=", tuple(round(x, 2) for x in size))
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading
    sh.light = 'STUDIO'; sh.color_type = 'VERTEX'; sh.show_cavity = False
    sc.render.resolution_x = 520; sc.render.resolution_y = 520
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.42, 0.45, 0.55)
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = max(size) * 1.15
    d = max(size) * 3
    cam.location = c + Vector((math.sin(0.5) * d, -math.cos(0.5) * d, size.z * 0.05))
    direction = c - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(sortie, os.path.basename(f)[:-4] + ".png")
    bpy.ops.render.render(write_still=True)
