"""Masques de silhouette (héros + pièces portées) en vue orthographique de face et de profil, pour superposer AVANT / APRÈS.
  blender -b --python silhouette.py -- <prefixe_sortie> <dossier_porte> <dossier_chausses> <chausses_famille|-> <id> [<id> ...]
Écrit <prefixe>_face.png et <prefixe>_profil.png (noir = silhouette, blanc = fond, 600x900)."""
import bpy, sys, os, math
argv = sys.argv[sys.argv.index("--") + 1:]
pref, porte, chausses, fam, ids = argv[0], argv[1], argv[2], argv[3], argv[4:]
ICI = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ICI, "..", "heros_reference.glb"))
for i in ids:
    bpy.ops.import_scene.gltf(filepath=os.path.join(porte, i + ".glb"))
if fam != "-":
    bpy.ops.import_scene.gltf(filepath=os.path.join(chausses, fam + ".glb"))
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "FLAT"
sc.display.shading.color_type = "SINGLE"
sc.display.shading.single_color = (0, 0, 0)
sc.world = bpy.data.worlds.new("w"); sc.world.color = (1, 1, 1)
sc.render.resolution_x, sc.render.resolution_y = 600, 900
sc.view_settings.view_transform = "Standard"
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.1
for nom, rot, pos in (("face", (math.pi / 2, 0, 0), (0, -5, 0.98)), ("profil", (math.pi / 2, 0, math.pi / 2), (5, 0, 0.98))):
    cam.location = pos; cam.rotation_euler = rot
    sc.render.filepath = pref + "_" + nom + ".png"
    bpy.ops.render.render(write_still=True)
    print("SILHOUETTE", sc.render.filepath)
