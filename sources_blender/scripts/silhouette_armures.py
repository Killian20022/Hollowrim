# Silhouettes d'un ensemble d'armure PORTÉ (4 pièces + chausses, héros de référence en pose de repos), face et profil, en aplat.
#   blender.exe -b --python sources_blender/scripts/silhouette_armures.py -- <dossier_sortie> <prefixe> <glb1> <glb2> ...
# Écrit <prefixe>_face.png et <prefixe>_profil.png (noir sur blanc, caméra orthographique fixe : comparables d'un lot à l'autre).
import bpy, sys, os, math
from mathutils import Vector

ICI = os.path.dirname(os.path.abspath(__file__))
REF = os.path.normpath(os.path.join(ICI, "..", "armures", "heros_reference.glb"))
CACHE = {"tunique", "mante", "accessoires", "pantalon", "bottes", "Hair_Long", "brassards"}


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    sortie, prefixe, glbs = a[0], a[1], a[2:]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=REF)
    for o in bpy.data.objects:
        if o.type == "MESH" and (o.name.split(".")[0] in CACHE or o.name.startswith("Icosphere")):
            o.hide_render = True
    for g in glbs:
        avant = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=g)
        for o in bpy.data.objects:
            if o not in avant and o.type == "MESH" and o.name.startswith("Icosphere"):
                o.hide_render = True
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "SINGLE"
    sc.display.shading.single_color = (0, 0, 0)
    sc.display.shading.show_cavity = False
    sc.display.shading.show_object_outline = False
    sc.world = bpy.data.worlds.new("w") if sc.world is None else sc.world
    sc.world.color = (1, 1, 1)
    sc.display.shading.background_type = "VIEWPORT"
    sc.display.shading.background_color = (1, 1, 1)
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x, sc.render.resolution_y = 600, 1000
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.0
    sc.camera = cam
    c = Vector((0, 0, 0.92))
    for nom, d in (("face", Vector((0, -1, 0))), ("profil", Vector((1, 0, 0)))):
        cam.location = c + d * 4.0
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(sortie, "%s_%s.png" % (prefixe, nom))
        bpy.ops.render.render(write_still=True)


main()
