# aperçu Workbench des pièces Quaternius de base et du héros (diagnostic)
import bpy, sys, os, math
from mathutils import Vector
ICI = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(ICI, "..", "..", ".."))
OUT = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/modeles/humains/homme_vetu.glb"))
garder = sys.argv[sys.argv.index("--") + 2].split(",")
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o.name not in garder:
        bpy.data.objects.remove(o)
for nom in sys.argv[sys.argv.index("--") + 3].split(",") if len(sys.argv) > sys.argv.index("--") + 3 else []:
    p = os.path.join(ROOT, "sources_blender/armures/heros", nom + ".obj")
    bpy.ops.wm.obj_import(filepath=p, forward_axis='NEGATIVE_Z', up_axis='Y')
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'
sc.display.shading.color_type = 'OBJECT'
sc.render.resolution_x = 900; sc.render.resolution_y = 900
import random
for o in bpy.data.objects:
    if o.type == 'MESH':
        o.color = (random.random(), random.random(), random.random(), 1)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = 'ORTHO'
cible = Vector(tuple(float(x) for x in sys.argv[sys.argv.index("--") + 4].split(","))) if len(sys.argv) > sys.argv.index("--") + 4 else Vector((0, 0, 1.0))
taille = float(sys.argv[sys.argv.index("--") + 5]) if len(sys.argv) > sys.argv.index("--") + 5 else 2.0
cam.data.ortho_scale = taille
for nom, d in [("face", Vector((0, -1, 0))), ("profil", Vector((1, 0, 0))), ("dos", Vector((0, 1, 0))), ("tq", Vector((0.7, -0.7, 0.25)))]:
    cam.location = cible + d.normalized() * 5
    cam.rotation_euler = (cible - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(OUT, nom + ".png")
    bpy.ops.render.render(write_still=True)
