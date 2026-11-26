# Rendu de référence d'un GLB (face, 3/4, profil, visage) en Workbench texturé, pour les planches de références.
#   blender -b --python rendu_reference_glb.py -- <entree.glb> <sortie_prefixe> [hauteur_cible_m]
import bpy, sys, math, mathutils
argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
hcible = float(argv[2]) if len(argv) > 2 else 1.75
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
mn = mathutils.Vector((1e9,) * 3); mx = -mn
for o in objs:
    for c in o.bound_box:
        w = o.matrix_world @ mathutils.Vector(c)
        mn = mathutils.Vector(map(min, mn, w)); mx = mathutils.Vector(map(max, mx, w))
h = mx.z - mn.z
print("BBOX", tuple(mn), tuple(mx), "hauteur", h, "tris", sum(len(o.data.polygons) for o in objs))
s = hcible / h
root = bpy.data.objects.new("racine", None); bpy.context.scene.collection.objects.link(root)
for o in bpy.context.scene.objects:
    if o.parent is None and o is not root:
        o.parent = root
root.scale = (s, s, s)
root.location = (-(mn.x + mx.x) / 2 * s, -(mn.y + mx.y) / 2 * s, -mn.z * s)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "TEXTURE"
sc.render.resolution_x, sc.render.resolution_y = 360, 640
sc.render.film_transparent = False
sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.35, 0.36, 0.40)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 50
def vue(nom, az, dist, hcam, hcible):
    a = math.radians(az)
    cam.location = (math.sin(a) * dist, -math.cos(a) * dist, hcam)
    d = mathutils.Vector((0, 0, hcible)) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = f"{out}_{nom}.png"
    bpy.ops.render.render(write_still=True)
vue("face", 0, 4.2, 1.0, hcible * 0.52)
vue("34", 40, 4.2, 1.0, hcible * 0.52)
vue("profil", 90, 4.2, 1.0, hcible * 0.52)
sc.render.resolution_x, sc.render.resolution_y = 400, 400
vue("visage", 15, 0.9, hcible * 0.93, hcible * 0.92)
